# AgroLens

AI-powered crop and livestock disease diagnosis for African farmers.
A farmer photographs a sick animal or plant; an on-device model suggests the
likely disease, a short set of follow-up questions refines the risk level, and
the app explains what to do next, in the farmer's own language. AgroLens also
carries an agricultural news feed with disease outbreak alerts, and a small
farmer community (posts, pals and messaging).

> Repository and Firebase project still use the earlier name **Agri-Vet**
> (`agri-vet`, `com.tshimologo_intelligence.agri_vet`).

## What's in here

| Path | What it is |
|---|---|
| `lib/` | Flutter app (screens, providers, services, `theme/palette.dart`) |
| `assets/models/` | On-device TFLite models (EfficientNet-B0, 224×224 RGB input, rescaling built in) |
| `assets/data/` | Class labels, disease info and the behavioural-question knowledge base (English) |
| `assets/i18n/` | Languages list, English UI strings, machine translations, human overrides |
| `scripts/translate.py` | Generates the translations with Meta's NLLB-200 |
| `scraper/` | Python RSS scraper that fills the Firestore `news` collection and sends outbreak alerts |
| `functions/` | Cloud Functions: push notifications and account clean-up |
| `.github/workflows/` | Flutter CI, translation, and the scheduled news scraper |
| `firestore.rules`, `firestore.indexes.json` | Firestore security rules and indexes |
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

## Languages

Diagnosis results (and the diagnosis screens) are shown in the language picked
in **Settings → Language**: English, Setswana, Afrikaans, isiZulu, Sesotho,
Shona, Swahili, Portuguese, French or Spanish.

Only English is written by hand — in the knowledge base (`{"en": ...}` fields)
and `assets/i18n/en.json`. Everything else is generated:

```bash
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install -r scripts/requirements-translate.txt
python scripts/translate.py          # only new/changed English is re-translated
```

The **Translate content** workflow does this automatically on any pull request
that changes the English text, the language list or the overrides, and commits
the result.

- **Add a language:** add a line to `assets/i18n/languages.json` with its
  [NLLB code](https://github.com/facebookresearch/flores/blob/main/flores200/README.md#languages-in-flores-200)
  (e.g. `{"code": "ny", "name": "Chichewa", "native": "Chichewa", "nllb": "nya_Latn"}`).
- **Correct a translation:** put the fixed text under the same key in
  `assets/i18n/overrides/<code>.json`. Overrides always win over the machine.
  The current overrides are the hand-written Setswana, Swahili and Portuguese
  that used to live in the knowledge base.
- **Licence:** NLLB-200 is CC-BY-NC-4.0 (non-commercial). Before any
  commercial release, switch `NLLB_MODEL` to a commercially licensed model
  or have the files reviewed and rewritten.

## Notifications

- **In-app:** every like, comment, reply, pal/message request and chat message
  lands in `notifications/{uid}/items` and shows in the bell list.
- **Push:** the `pushNotification` Cloud Function sends each of those to the
  user's phones, unless they turned that kind off in **Settings → Notifications**.
  Phone tokens and switches live in the owner-only `users/{uid}/private/notifications`.
- **Disease outbreak alerts:** the scraper pushes new outbreak stories about
  diseases AgroLens diagnoses, in Botswana and the region, to the
  `disease_alerts` topic (max 3 per run).

## Firebase

```bash
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm install && cd ..
firebase deploy --only functions            # requires the Blaze plan
```

Push on iOS also needs an APNs key uploaded in the Firebase console and the
Push Notifications capability enabled in Xcode.

Collections: `users` (+ `private`), `posts` (+ `comments`), `diagnoses`, `news`,
`palRequests`, `pals`, `conversations` (+ `messages`),
`notifications/{uid}/items`.

Deleting an account (Settings → Delete account) removes the login; the
`cleanUpDeletedUser` function then deletes everything that user created.

## Sign in with Google

The login screen offers **Continue with Google** (email + password still
works). First-time Google users get a profile automatically; they can add
farm details later. One-time Firebase setup:

1. Firebase console → **Authentication → Sign-in method** → enable **Google**
   (pick a support email).
2. Get the app's signing fingerprints: `cd android && ./gradlew signingReport`
   (Windows: `gradlew signingReport`). Copy the **SHA-1** and **SHA-256** of
   the `debug` variant (and of your release key when you have one).
3. Firebase console → **Project settings → Your apps → Android** → *Add
   fingerprint* for each.
4. Download the new `google-services.json` and replace
   `android/app/google-services.json` (it now contains an `oauth_client`).
5. iOS: add `GoogleService-Info.plist` to `ios/Runner` and its
   `REVERSED_CLIENT_ID` as a URL scheme in `Info.plist` (see the
   google_sign_in package docs). Not set up yet.

## News scraper

The workflow needs a repository secret named `FIREBASE_SERVICE_ACCOUNT`
containing the full JSON of a Firebase service-account key.
Never commit that key; `.gitignore` blocks the usual filenames.

```bash
pip install -r scraper/requirements.txt
python scraper/test_relevance.py        # relevance rules
python scraper/news_scraper.py --test   # check each feed, no Firestore writes
```

What counts as agricultural is decided in `scraper/relevance.py`: an article
needs a clearly agricultural word (cattle, maize, farmers, foot and mouth…);
words like "disease", "rain" or "yield" only help pick its category. General
news sources also drop politics, sport, crime and markets.

To remove articles stored before these rules: **Actions → News Scraper →
Run workflow**, tick **prune**.

## Dark mode

Screens take their colours from `lib/theme/palette.dart`: `Bg.*` for
backgrounds, cards and lines, `Fg.*` for text and icons. Use those (not
`Colors.white` or hard-coded hex) in new UI so it works in both modes.
