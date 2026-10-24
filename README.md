# AgroLens

AI-powered crop and livestock disease diagnosis for African farmers.
A farmer photographs a sick animal or plant; an on-device model suggests the
likely disease, a short set of follow-up questions refines the risk level, and
the app explains what to do next. AgroLens also carries a farming news feed
and a small farmer community (posts, pals and messaging).

> Repository and Firebase project still use the earlier name **Agri-Vet**
> (`agri-vet`, `com.tshimologo_intelligence.agri_vet`).

## What's in here

| Path | What it is |
|---|---|
| `lib/` | Flutter app (screens, providers, services) |
| `assets/models/` | On-device TFLite models (EfficientNet-B0, 224×224 RGB input, rescaling built in) |
| `assets/data/` | Class labels, disease info and the behavioural-question knowledge base |
| `assets/translation/` | Setswana strings |
| `scraper/` | Python RSS scraper that fills the Firestore `news` collection |
| `.github/workflows/news_scraper.yml` | Runs the scraper on a schedule |
| `firestore.rules`, `firestore.indexes.json` | Firestore security rules and composite indexes |
| `test/` | Unit tests |

### Models

| Model | Classes |
|---|---|
| Animal | foot and mouth, goat pox, healthy, lumpy cow disease |
| Plant | healthy, potato late blight, sorghum cereal grain mold, tomato late blight, watermelon mosaic virus |

Every label must have a matching entry in `assets/data/disease_knowledge_base.json`.

## Running the app

Requires Flutter (Dart ≥ 3.0) and access to the `agri-vet` Firebase project.

```bash
flutter pub get
flutter run
flutter test
```

## Firebase

Deploy rules and indexes after changing either file:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Collections: `users`, `posts` (+ `comments`), `diagnoses`, `news`,
`palRequests`, `pals`, `conversations` (+ `messages`),
`notifications/{uid}/items`.

## News scraper

The workflow needs a repository secret named `FIREBASE_SERVICE_ACCOUNT`
containing the full JSON of a Firebase service-account key.
Never commit that key; `.gitignore` blocks the usual filenames.

```bash
pip install -r scraper/requirements.txt
python scraper/news_scraper.py --test   # check each feed, no Firestore writes
```

Articles are kept only if they match an agriculture or weather keyword
(whole-word match), except for sources that are agriculture-only end to end.
