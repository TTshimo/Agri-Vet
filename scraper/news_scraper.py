"""Fills the Firestore `news` collection with agricultural news for AgroLens.

  python scraper/news_scraper.py           # scrape (what the scheduled workflow runs)
  python scraper/news_scraper.py --test    # check each feed, no Firestore access
  python scraper/news_scraper.py --prune   # delete stored articles that fail today's rules

Which articles are kept, and how they're tagged, is decided in relevance.py.
When a NEW article reports an outbreak of a disease AgroLens diagnoses, in
Botswana or the region, a push notification goes to the `disease_alerts`
topic (users opt in/out with Settings → Notifications → Disease outbreak alerts).
"""

import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone

import feedparser

from relevance import AGRI_SOURCES, assess, outbreak_diseases

TEST_MODE = "--test" in sys.argv
PRUNE_MODE = "--prune" in sys.argv

ALERT_TOPIC = "disease_alerts"
MAX_ALERTS_PER_RUN = 3          # never flood phones, even if a feed re-publishes
ENTRIES_PER_FEED = 20

FEEDS = [
    {"url": "https://www.fao.org/news/rss-feed/en/", "source": "FAO"},
    {"url": "https://reliefweb.int/updates/rss.xml?primary_country=72&source=0&theme=0", "source": "ReliefWeb"},
    {"url": "https://allafrica.com/tools/headlines/rdf/botswana/headlines.rdf", "source": "AllAfrica"},
    {"url": "https://www.farmer.co.zw/feed/", "source": "Farmer's Weekly Zimbabwe"},
    {"url": "https://www.agriculture.gov.bw/rss", "source": "Botswana Agriculture"},
    {"url": "https://www.woah.org/en/news/feed/", "source": "WOAH"},
    {"url": "https://www.sabcnews.com/sabcnews/feed/", "source": "SABC News"},
    {"url": "https://www.dailynews.gov.bw/feed", "source": "Botswana Daily News"},
    {"url": "https://www.bizcommunity.com/rss/29/741.html", "source": "Bizcommunity Agribusiness Botswana"},
    {"url": "https://www.bizcommunity.com/rss/416/741.html", "source": "Bizcommunity Agribusiness Southern Africa"},
    {"url": "https://www.farmersweekly.co.za/feed", "source": "Farmer's Weekly South Africa"},
    {"url": "https://agrifocusafrica.com/feed", "source": "AgriFocus Africa"},
]

_unknown_sources = {f["source"] for f in FEEDS} - AGRI_SOURCES - {
    "AllAfrica", "SABC News", "Botswana Daily News", "ReliefWeb",
}
assert not _unknown_sources, f"Classify these sources in relevance.py: {_unknown_sources}"


def strip_html(text: str) -> str:
    """Remove HTML tags and decode common entities."""
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    text = text.replace("&quot;", '"').replace("&#39;", "'").replace("&nbsp;", " ")
    return re.sub(r"\s+", " ", text).strip()


def make_id(url: str) -> str:
    """Stable doc ID from URL so duplicates are overwritten."""
    return hashlib.md5(url.encode()).hexdigest()


def parse_date(entry) -> datetime:
    """Try to extract a published date, fall back to now."""
    if getattr(entry, "published_parsed", None):
        return datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
    if getattr(entry, "updated_parsed", None):
        return datetime(*entry.updated_parsed[:6], tzinfo=timezone.utc)
    return datetime.now(timezone.utc)


def connect():
    import firebase_admin
    from firebase_admin import credentials, firestore

    service_account = json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT"])
    firebase_admin.initialize_app(credentials.Certificate(service_account))
    return firestore.client()


def test_feeds():
    """Check each feed URL without touching Firestore. Run this first if scrapes come up empty."""
    for feed_config in FEEDS:
        source = feed_config["source"]
        feed = feedparser.parse(feed_config["url"])
        kept = sum(
            1 for e in feed.entries[:ENTRIES_PER_FEED]
            if assess(strip_html(e.get("title", "")), strip_html(e.get("summary", "")), source)
        )
        status = getattr(feed, "status", "N/A")
        print(f"{source:42s} | entries: {len(feed.entries):3d} | kept: {kept:3d} | status: {status}")
        if feed.bozo:
            print(f"    bozo_exception: {feed.bozo_exception}")


def send_alerts(articles: list[dict]) -> None:
    from firebase_admin import messaging

    for article in articles[:MAX_ALERTS_PER_RUN]:
        disease = article["diseases"][0].title()
        message = messaging.Message(
            topic=ALERT_TOPIC,
            notification=messaging.Notification(
                title=f"Outbreak alert: {disease}",
                body=article["title"][:180],
            ),
            data={"type": "disease_alert", "newsId": article["id"], "url": article["url"]},
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(channel_id="disease_alerts"),
            ),
        )
        try:
            messaging.send(message)
            print(f"  Alert sent: {article['title'][:80]}")
        except Exception as e:  # an alert failing must never stop the scrape
            print(f"  WARNING: alert failed: {e}")


def scrape(db):
    batch = db.batch()
    count = skipped = 0
    alert_candidates: list[dict] = []

    for feed_config in FEEDS:
        source = feed_config["source"]
        print(f"Fetching {source} ...")
        try:
            feed = feedparser.parse(feed_config["url"])
            if feed.bozo:
                print(f"  WARNING: {source} feed may be malformed or unreachable: {feed.bozo_exception}")
            if not feed.entries:
                print(f"  No entries found for {source} — feed URL may be wrong or empty.")
                continue

            for entry in feed.entries[:ENTRIES_PER_FEED]:
                url = entry.get("link", "")
                if not url:
                    continue
                title = strip_html(entry.get("title", ""))
                summary = strip_html(entry.get("summary", ""))[:300]

                categories = assess(title, summary, source)
                if not categories:
                    skipped += 1
                    continue

                doc_id = make_id(url)
                diseases = outbreak_diseases(title, summary)
                data = {
                    "title": title,
                    "summary": summary,
                    "url": url,
                    "source": source,
                    "categories": categories,
                    "category": categories[0],
                    "publishedAt": parse_date(entry),
                }
                if diseases:
                    data["diseases"] = diseases
                    alert_candidates.append({"id": doc_id, "title": title, "url": url, "diseases": diseases})

                batch.set(db.collection("news").document(doc_id), data, merge=True)
                count += 1
        except Exception as e:
            print(f"Error fetching {source}: {e}")

    # Only alert on articles we haven't stored before (checked before commit).
    new_alerts = []
    if alert_candidates:
        refs = [db.collection("news").document(a["id"]) for a in alert_candidates]
        existing = {snap.id for snap in db.get_all(refs) if snap.exists}
        new_alerts = [a for a in alert_candidates if a["id"] not in existing]

    batch.commit()
    print(f"Written {count} articles to Firestore. Skipped {skipped} off-topic articles.")

    if new_alerts:
        send_alerts(new_alerts)


def prune(db):
    """Delete stored articles that today's rules would reject (one-off clean-up)."""
    removed = 0
    batch = db.batch()
    pending = 0
    for snap in db.collection("news").stream():
        d = snap.to_dict() or {}
        if assess(d.get("title", ""), d.get("summary", ""), d.get("source", "")):
            continue
        print(f"  removing: [{d.get('source', '?')}] {d.get('title', '')[:90]}")
        batch.delete(snap.reference)
        removed += 1
        pending += 1
        if pending == 400:  # Firestore batches cap at 500 writes
            batch.commit()
            batch, pending = db.batch(), 0
    if pending:
        batch.commit()
    print(f"Pruned {removed} off-topic articles.")


if __name__ == "__main__":
    if TEST_MODE:
        test_feeds()
    elif PRUNE_MODE:
        prune(connect())
    else:
        scrape(connect())
