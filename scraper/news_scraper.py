import os
import json
import hashlib
import re
import feedparser
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, firestore

import sys

TEST_MODE = "--test" in sys.argv

if not TEST_MODE:
    service_account = json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT"])
    cred = credentials.Certificate(service_account)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

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

# Sources whose feeds are agriculture-specific end-to-end (a dedicated agri
# publication, or an org/feed already pre-filtered to agribusiness, like
# FAO/WOAH or Bizcommunity's Agribusiness verticals). Everything from these
# is trusted without needing a keyword match.
ALWAYS_IN_SCOPE_SOURCES = {
    "FAO",
    "WOAH",
    "Botswana Agriculture",
    "Farmer's Weekly Zimbabwe",
    "Farmer's Weekly South Africa",
    "Bizcommunity Agribusiness Botswana",
    "Bizcommunity Agribusiness Southern Africa",
    "AgriFocus Africa",
}

# Sources whose feeds are GENERAL national news (politics, sports, war,
# crime, etc.) mixed in with the occasional agri story. Every entry from
# these MUST pass the keyword classifier below, or it gets dropped.
GENERAL_NEWS_SOURCES = {"AllAfrica", "SABC News", "Botswana Daily News", "ReliefWeb"}

# Restricted to agriculture (livestock + crop) and weather only, per scope
# decision — 'policy' and 'alert' keyword buckets have been removed, so
# trade/regulation/emergency-only articles with no agri or weather keyword
# hit are dropped rather than classified. Note: the Flutter app still has
# 'Alerts' and 'Policy' tabs (home_screen.dart _categories) — with no
# scraper output landing in those categories, those tabs will show empty.
# Remove them from the UI, or reintroduce a keyword bucket, if that's not
# what you want.
CATEGORY_KEYWORDS = {
    "livestock": [
        "cattle", "livestock", "poultry", "herd", "dairy", "beef", "sheep", "goat",
        "foot and mouth", "fmd", "avian influenza", "bird flu", "vaccination",
        "veterinary", "abattoir", "disease outbreak", "anthrax", "rabies", "disease",
    ],
    "weather": [
        "rainfall", "rain", "drought", "forecast", "flood", "flooding", "climate",
        "temperature", "heatwave", "cyclone", "storm", "el nino", "la nina", "monsoon",
    ],
    "crop": [
        "harvest", "crop", "maize", "sorghum", "wheat", "irrigation", "planting",
        "seed", "fertilizer", "pest", "locust", "yield", "tomato", "potato"
    ],
}

# Whole-word matching (with an optional plural "s"), so "rain" doesn't match
# "Ukraine"/"train", "pest" doesn't match "Budapest", "herd" doesn't match
# "shepherd", etc. Multi-word keywords like "foot and mouth" still work.
_CATEGORY_PATTERNS = {
    cat: re.compile(r"\b(?:" + "|".join(re.escape(kw) for kw in keywords) + r")s?\b")
    for cat, keywords in CATEGORY_KEYWORDS.items()
}


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
    if hasattr(entry, "published_parsed") and entry.published_parsed:
        return datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
    if hasattr(entry, "updated_parsed") and entry.updated_parsed:
        return datetime(*entry.updated_parsed[:6], tzinfo=timezone.utc)
    return datetime.now(timezone.utc)


def classify(title: str, summary: str) -> list:
    """Return all matching agri categories based on keyword hits in title+summary.
    Returns an empty list if nothing matches — callers decide what to do with that,
    rather than this function inventing a fallback 'general' bucket."""
    text = f"{title} {summary}".lower()
    return [cat for cat, pattern in _CATEGORY_PATTERNS.items() if pattern.search(text)]


def test_feeds():
    """Check each feed URL without touching Firestore. Run this first if scrapes are coming up empty."""
    for feed_config in FEEDS:
        source = feed_config["source"]
        url = feed_config["url"]
        feed = feedparser.parse(url)
        status = getattr(feed, "status", "N/A")
        print(f"{source:25s} | entries: {len(feed.entries):3d} | bozo: {feed.bozo} | status: {status}")
        if feed.bozo:
            print(f"    bozo_exception: {feed.bozo_exception}")
        if feed.entries:
            print(f"    sample title: {feed.entries[0].get('title', '')[:80]}")


def scrape():
    batch = db.batch()
    count = 0
    skipped = 0

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

            for entry in feed.entries[:20]:
                url = entry.get("link", "")
                if not url:
                    continue

                title = strip_html(entry.get("title", ""))
                summary = strip_html(entry.get("summary", ""))[:300]
                categories = classify(title, summary)

                # Only ALWAYS_IN_SCOPE_SOURCES get a free pass when nothing
                # matches (tagged 'crop' as a safe generic-agriculture
                # default, since these sources are dedicated agri
                # publications end-to-end). Everything else — especially
                # GENERAL_NEWS_SOURCES — is dropped outright if it doesn't
                # hit an agri/weather keyword, so war, politics, sports,
                # trade/regulation-only stories, etc. never reach Firestore.
                if not categories:
                    if source in ALWAYS_IN_SCOPE_SOURCES:
                        categories = ["crop"]
                    else:
                        skipped += 1
                        continue

                doc_id = make_id(url)
                ref = db.collection("news").document(doc_id)

                data = {
                    "title": title,
                    "summary": summary,
                    "url": url,
                    "source": source,
                    "categories": categories,
                    "category": categories[0],
                    "publishedAt": parse_date(entry),
                }

                batch.set(ref, data, merge=True)
                count += 1

        except Exception as e:
            print(f"Error fetching {source}: {e}")

    batch.commit()
    print(f"Written {count} articles to Firestore. Skipped {skipped} off-topic articles.")


if __name__ == "__main__":
    if TEST_MODE:
        test_feeds()
    else:
        scrape()