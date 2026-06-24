import os
import json
import hashlib
import re
import feedparser
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, firestore

# ── Firebase init ─────────────────────────────────────────────────────────────
service_account = json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT"])
cred = credentials.Certificate(service_account)
firebase_admin.initialize_app(cred)
db = firestore.client()

# ── RSS feeds by category ─────────────────────────────────────────────────────
FEEDS = [
    {
        "url": "https://www.fao.org/news/rss-feed/en/",
        "source": "FAO",
        "category": "livestock",
    },
    {
        "url": "https://reliefweb.int/updates/rss.xml?primary_country=72&source=0&theme=0",
        "source": "ReliefWeb",
        "category": "alert",
    },
    {
        "url": "https://allafrica.com/tools/headlines/rdf/botswana/headlines.rdf",
        "source": "AllAfrica",
        "category": "crop",
    },
    {
        "url": "https://www.farmer.co.zw/feed/",
        "source": "Farmer's Weekly",
        "category": "livestock",
    },
    {
        "url": "https://www.agriculture.gov.bw/rss",
        "source": "Botswana Agriculture",
        "category": "policy",
    },
]

# ── Helpers ───────────────────────────────────────────────────────────────────
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
    return datetime.now(timezone.utc)


# ── Main ──────────────────────────────────────────────────────────────────────
def scrape():
    batch = db.batch()
    count = 0

    for feed_config in FEEDS:
        print(f"Fetching {feed_config['source']} ...")
        try:
            feed = feedparser.parse(feed_config["url"])
            for entry in feed.entries[:10]:  # max 10 per source
                url = entry.get("link", "")
                if not url:
                    continue

                doc_id = make_id(url)
                ref = db.collection("news").document(doc_id)

                data = {
                    "title": strip_html(entry.get("title", "")),
                    "summary": strip_html(entry.get("summary", ""))[:300],
                    "url": url,
                    "source": feed_config["source"],
                    "category": feed_config["category"],
                    "publishedAt": parse_date(entry),
                }

                batch.set(ref, data, merge=True)
                count += 1

        except Exception as e:
            print(f"Error fetching {feed_config['source']}: {e}")

    batch.commit()
    print(f"Written {count} articles to Firestore.")


if __name__ == "__main__":
    scrape()