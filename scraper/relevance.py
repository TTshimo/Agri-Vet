"""Decides whether a news article belongs in AgroLens, and how to tag it.

Kept free of Firebase so it can be unit-tested (see test_relevance.py).

The rule, in plain words:
  * An article is in scope only if it contains at least one clearly
    agricultural term (STRONG_TERMS), e.g. "cattle", "maize", "farmers",
    "foot and mouth". Words that are agricultural only sometimes — "disease",
    "rain", "yield", "vaccination", "seed" — never qualify an article on
    their own; they only help pick its category once it's in.
  * General-news sources (national papers, SABC, ReliefWeb) also drop
    anything about politics, sport, crime, markets etc. unless agriculture
    is clearly the main subject (2+ strong hits, one of them in the title).
  * Trusted agriculture-only sources skip the off-topic check, but still
    need one strong term, so their occasional non-farm post is dropped too.
"""

from __future__ import annotations

import re

# Feeds that publish agriculture and nothing else.
AGRI_SOURCES = {
    "FAO",
    "WOAH",
    "Botswana Agriculture",
    "Farmer's Weekly Zimbabwe",
    "Farmer's Weekly South Africa",
    "Bizcommunity Agribusiness Botswana",
    "Bizcommunity Agribusiness Southern Africa",
    "AgriFocus Africa",
}

# Clearly agricultural on their own.
STRONG_TERMS = {
    "livestock": [
        "livestock", "cattle", "cow", "cows", "calf", "calves", "heifer", "heifers",
        "goat", "goats", "sheep", "poultry", "chicken", "chickens", "broiler", "broilers",
        "laying hens", "pig", "pigs", "piggery", "dairy farm", "dairy farmers", "beef farmers",
        "beef exports", "beef industry", "abattoir", "abattoirs", "herdsman", "herdsmen",
        "kraal", "cattlepost", "cattle post", "rangeland", "rangelands", "grazing", "pasture",
        "veterinary", "vet services", "animal health", "foot and mouth", "foot-and-mouth",
        "fmd", "lumpy skin", "goat pox", "sheep pox", "anthrax", "blackleg", "heartwater",
        "brucellosis", "newcastle disease", "avian influenza", "bird flu",
        "african swine fever", "rift valley fever", "tick-borne", "dip tank", "dip tanks",
    ],
    "crop": [
        "crop", "crops", "maize", "sorghum", "millet", "wheat", "groundnut", "groundnuts",
        "cowpea", "cowpeas", "beans", "cassava", "tomato", "tomatoes", "potato", "potatoes",
        "watermelon", "horticulture", "horticultural", "vegetable farmers", "orchard",
        "irrigation", "fertiliser", "fertilizer", "fertilisers", "fertilizers", "agrochemical",
        "pesticide", "pesticides", "herbicide", "herbicides", "weed control", "weeds",
        "soil health", "tractor", "tractors", "locust", "locusts", "armyworm", "fall armyworm",
        "late blight", "mosaic virus", "grain mold", "grain mould", "planting season",
        "ploughing", "plowing", "harvest season", "smallholder", "smallholders",
        "arable", "grain silo", "grain silos", "food security",
    ],
    "general": [
        "farm", "farms", "farmer", "farmers", "farming", "agriculture", "agricultural",
        "agribusiness", "agri", "agronomy", "agronomist", "extension officer",
        "ministry of agriculture", "lands and agriculture", "agricultural show",
    ],
}

# Agricultural only in context: never qualify an article, but steer its category.
CONTEXT_TERMS = {
    "livestock": ["herd", "herds", "dairy", "beef", "vaccination", "vaccine", "disease", "outbreak"],
    "crop": ["harvest", "yield", "yields", "seed", "seeds", "pest", "pests", "planting"],
    "weather": [
        "rain", "rains", "rainfall", "drought", "dry spell", "forecast", "flood", "floods",
        "flooding", "climate", "temperature", "temperatures", "heatwave", "heat wave",
        "cyclone", "storm", "el nino", "el niño", "la nina", "la niña", "frost", "hail",
    ],
}

# Weather that matters to farmers even with no farm word in the text.
FARM_WEATHER_TERMS = ["drought", "dry spell", "rainy season", "rainfall season", "el nino", "el niño", "la nina", "la niña"]

# Topics that are off-limits for general-news sources.
OFF_TOPIC_TERMS = [
    "election", "elections", "parliament", "mp", "president", "minister of finance", "cabinet",
    "party", "opposition", "political", "politics", "court", "trial", "murder", "killed", "shooting",
    "police", "arrested", "crime", "football", "soccer", "rugby", "cricket", "athletics", "olympics",
    "match", "league", "coach", "stock market", "jse", "shares", "bond", "bonds", "rand", "currency",
    "celebrity", "music", "concert", "movie", "film", "war", "military", "army", "covid", "hiv",
    "school", "schools", "university", "exam", "exams",
]

# Diseases AgroLens diagnoses (plus close synonyms) and the words that make a
# story about them an outbreak rather than, say, a vaccine announcement.
TRACKED_DISEASES = {
    "foot and mouth": ["foot and mouth", "foot-and-mouth", "fmd"],
    "lumpy skin disease": ["lumpy skin"],
    "goat pox": ["goat pox", "sheep and goat pox"],
    "late blight": ["late blight"],
    "watermelon mosaic virus": ["watermelon mosaic", "mosaic virus"],
    "sorghum grain mold": ["grain mold", "grain mould"],
}
OUTBREAK_TERMS = [
    "outbreak", "outbreaks", "confirmed", "cases", "case", "detected", "suspected",
    "spread", "spreading", "quarantine", "cordon", "movement ban", "ban on", "reported",
    "infected", "infection", "infections",
]
# Only alert on outbreaks close enough to matter to AgroLens users.
REGION_TERMS = [
    "botswana", "gaborone", "maun", "francistown", "ngamiland", "kgalagadi", "ghanzi",
    "central district", "chobe", "south africa", "zimbabwe", "namibia", "zambia",
    "lesotho", "eswatini", "mozambique", "angola", "malawi", "sadc", "southern africa",
]


def _pattern(terms: list[str]) -> re.Pattern:
    """Whole-word, case-insensitive match for any of the terms."""
    alternatives = "|".join(re.escape(t) for t in sorted(terms, key=len, reverse=True))
    return re.compile(rf"(?<![\w-])(?:{alternatives})(?![\w-])", re.IGNORECASE)


_STRONG = {cat: _pattern(terms) for cat, terms in STRONG_TERMS.items()}
_CONTEXT = {cat: _pattern(terms) for cat, terms in CONTEXT_TERMS.items()}
_FARM_WEATHER = _pattern(FARM_WEATHER_TERMS)
_OFF_TOPIC = _pattern(OFF_TOPIC_TERMS)
_OUTBREAK = _pattern(OUTBREAK_TERMS)
_REGION = _pattern(REGION_TERMS)
_DISEASES = {name: _pattern(terms) for name, terms in TRACKED_DISEASES.items()}


def _hits(pattern: re.Pattern, text: str) -> int:
    return len(pattern.findall(text))


# "farm" phrases that have nothing to do with agriculture.
_NOT_FARMING = re.compile(
    r"\b(?:solar|wind|server|troll|data|content|click|tax|energy|battery)\s+farms?\b",
    re.IGNORECASE,
)


def _clean(text: str) -> str:
    return _NOT_FARMING.sub(" ", text)


def assess(title: str, summary: str, source: str) -> list[str]:
    """Return the article's categories (first = primary), or [] to drop it."""
    title, summary = _clean(title), _clean(summary)
    text = f"{title}. {summary}"
    strong = {cat: _hits(p, text) for cat, p in _STRONG.items()}
    strong_total = sum(strong.values())
    farm_weather = _hits(_FARM_WEATHER, text)

    if strong_total == 0 and farm_weather == 0:
        return []

    if source not in AGRI_SOURCES and _OFF_TOPIC.search(text):
        agri_in_title = any(p.search(title) for p in _STRONG.values())
        if strong_total < 2 or not agri_in_title:
            return []

    # Headline words count double: the headline says what the story is about.
    weighted = f"{title}. {title}. {summary}"
    scores = {
        "livestock": _hits(_STRONG["livestock"], weighted) * 2 + _hits(_CONTEXT["livestock"], weighted),
        "crop": _hits(_STRONG["crop"], weighted) * 2 + _hits(_CONTEXT["crop"], weighted),
        "weather": _hits(_FARM_WEATHER, weighted) * 2 + _hits(_CONTEXT["weather"], weighted),
    }
    categories = [c for c, s in sorted(scores.items(), key=lambda kv: -kv[1]) if s > 0]
    if outbreak_diseases(title, summary):
        categories.insert(0, "alert")
    return categories or ["crop"]  # agricultural, but no specific signal


def outbreak_diseases(title: str, summary: str) -> list[str]:
    """Tracked diseases this article reports an outbreak of, in our region."""
    text = f"{title}. {summary}"
    if not (_OUTBREAK.search(text) and _REGION.search(text)):
        return []
    return [name for name, p in _DISEASES.items() if p.search(text)]
