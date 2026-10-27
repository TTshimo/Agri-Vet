"""Run with: python -m pytest scraper/  (or python scraper/test_relevance.py)"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))

from relevance import assess, outbreak_diseases  # noqa: E402

GENERAL = "SABC News"
AGRI = "Farmer's Weekly South Africa"

DROP = [
    ("Ruling party wins by-election in Gaborone", "Voters turned out in large numbers despite the rain."),
    ("Zebras beat Namibia 2-1 in World Cup qualifier", "The coach praised the team's yield of chances."),
    ("War in Ukraine escalates", "Missile strikes continued overnight."),
    ("Solar farm to power 10,000 homes", "The wind farm and solar farm projects will feed the grid."),
    ("JSE closes higher as rand firms", "Bond yields fell and shares rallied."),
    ("Minister urges calm over cholera outbreak", "Health officials confirmed new cases of the disease."),
    ("Heavy rains expected this weekend", "Motorists are urged to drive carefully."),
    ("Teams work in silos, report finds", "Layers of red tape slow down the bull market."),
    ("Covid vaccination drive reaches schools", "Learners received the vaccine."),
    ("Bulls, Stormers hold on to win after strong fightbacks", ""),
    ("Hyundai takes on Chinese rivals with new, cheaper Creta", ""),
    ("We are very confident of ANC victory in Eastern Cape: Ramaphosa", ""),
    ("Russia and Ukraine swap 270 prisoners each", ""),
]

KEEP = [
    ("Foot and mouth outbreak confirmed in Ngamiland", "Movement of cattle has been banned.", ["alert", "livestock"]),
    ("Maize prices rise as harvest falls short", "Smallholder farmers report low yields.", ["crop"]),
    ("Drought declared in Kgalagadi district", "Government to assess water points.", ["weather"]),
    ("Farmers warned of heavy rains", "Planting should wait until the soil drains.", ["weather", "crop"]),
    ("Botswana resumes beef exports to the EU", "The beef industry welcomed the decision.", ["livestock"]),
    ("Fall armyworm spotted in sorghum fields", "Extension officers advise pesticides.", ["crop"]),
    ("Beyond the spray: Rethinking weed control", "", ["crop"]),
]


def test_drops_off_topic_general_news():
    for title, summary in DROP:
        assert assess(title, summary, GENERAL) == [], title


def test_keeps_agricultural_stories():
    for title, summary, expected_first in KEEP:
        got = assess(title, summary, GENERAL)
        assert got, title
        assert got[0] == expected_first[0], (title, got)


def test_agri_source_still_needs_an_agri_term():
    assert assess("Our offices close for the holidays", "Season's greetings.", AGRI) == []
    assert assess("New tractor range launched", "Farmers can test drive it.", AGRI) != []


def test_politics_with_agriculture_as_the_subject_is_kept():
    got = assess("Parliament debates livestock subsidy for cattle farmers", "", GENERAL)
    assert got and got[0] == "livestock"


def test_outbreak_alerts_need_outbreak_words_and_region():
    assert outbreak_diseases("FMD outbreak confirmed in Botswana", "") == ["foot and mouth"]
    assert outbreak_diseases("New FMD vaccine developed", "Trials in Botswana") == []
    assert outbreak_diseases("FMD outbreak confirmed in the UK", "") == []
    assert outbreak_diseases("Lumpy skin cases detected in Zimbabwe", "") == ["lumpy skin disease"]


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok", name)
