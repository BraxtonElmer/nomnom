# nomnom

Type what you ate, get the macros.

> nomnom 2 replaces FitCore AI (v1, Flutter + FastAPI with photo scanning). The backend is gone: everything now runs on the phone with your own AI key.

nomnom is a calorie and macro tracker that runs entirely on your phone. You write meals the way you'd say them, "120g grilled chicken, 2 rotis and a bowl of dal", and nomnom turns that into items, grams, calories, protein, carbs and fat, estimated for the country you live in.

There is no backend and no account. The app calls the AI directly with your own key.

## How it works

```
"2 rotis and a bowl of dal"
        │
        ▼
  AI reads the sentence ──► items, amounts, grams, search terms
        │
        ▼
  bundled food tables ────► nutrition per 100 g (USDA + regional dishes)
        │
        ▼
  app does the maths ─────► totals you can adjust with exact arithmetic
```

The AI is good at understanding language and unreliable at remembering numbers, so it is only trusted with the first step. Calories and macros come from real nutrition tables bundled in the app:

- **USDA FoodData Central, SR Legacy**: about 7,300 generic foods with household portion weights. Public domain.
- **Dish table (India)**: about 95 common dishes with per-100 g values and typical serving weights.
- **Open Food Facts**: packaged products, searched live when you name a brand ("a glass of Amul lassi") or search in the item sheet.

Exact dish names ("poha", "2 idli with sambar") are matched on the phone without a second AI request, which matters on small free tiers.

When nothing in the tables matches, the item keeps the AI's own estimate and is labelled **AI estimate**. If a table value and the AI's estimate disagree wildly, the item is marked **Check this one**. Every item shows its source, and you can rematch it to another food in one tap.

Foods you confirm are remembered, so repeat meals come out the same every time and don't need a lookup.

## Features

- Onboarding: country and units, body stats, goal and pace, macro split, and a daily target that is either suggested (Mifflin–St Jeor) or set by you
- Typed logging with a review screen: steppers per item, gram overrides, rematching, add or remove items, meal and time
- Today: week strip, calorie ring, macro split, and the day laid out as a menu
- Nutrition details: calories and macros up front; fibre, sugar, saturated fat, sodium, potassium, calcium, iron, vitamin C and B12 against daily values one tap away, per day, plate or item
- A one-line note on each plate from the model
- One-tap re-logging of favourites and recent plates, with no AI call
- Follow-up questions: when a missing amount would swing the numbers ("rice and rajma"), one tap-to-answer question instead of a guess
- Save for later: if the AI can't be reached, the text is kept and logged automatically once it can be
- Meal reminders for breakfast, lunch and dinner, skipped for meals you've already logged
- History: month calendar shaded by how close each day was to goal, with day detail
- Progress: weight log with a smoothed trend and BMI, calorie bars against goal, 7-day macro averages, streak
- Health Connect (Android): steps, active calories and sleep, with an option to add exercise to the day's budget
- BMI with WHO bands, using the lower Asian cut-offs for countries where they apply
- Backup: export everything to a JSON file and restore it on any phone (API keys are never included)

## AI providers

Pick one during setup, or later under **You → AI model**.

| Provider | Key | Notes |
| --- | --- | --- |
| Groq | Free at [console.groq.com/keys](https://console.groq.com/keys) | Fastest. Defaults to `llama-3.3-70b-versatile`. |
| Gemini | Free at [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | Defaults to `gemini-3.5-flash-lite`. The free tier can be as low as 20 requests a day per model, so it suits trying things out more than daily use. |
| Custom | Optional | Any OpenAI-compatible server: Ollama, LM Studio, OpenRouter, vLLM… |

The app lists the models your key can use, and you can switch at any time. Bigger models read meals more accurately.

### Running a local model

Local servers already speak the OpenAI API, so no extra backend is needed. For Ollama on your computer:

```bash
OLLAMA_HOST=0.0.0.0 ollama serve
```

Then choose **Custom** in nomnom and use `http://<your-computer's-wifi-ip>:11434/v1` as the endpoint. Phone and computer need to be on the same network.

## Privacy

- Your log, weights, favourites and goals are stored only on the device (Hive).
- API keys are kept in the platform keystore (`flutter_secure_storage`) and never written to backups.
- Only the text you type is sent, and only to the provider you chose.

## Development

```bash
flutter pub get
flutter run
```

Tests:

```bash
flutter test
```

Screenshots of every screen at phone size, rendered with the real fonts into `build/shots/`:

```bash
flutter test tool/shots --update-goldens
```

Run real sentences through a live model (spends free-tier requests) and probe food search:

```bash
GEMINI_KEY=... MODEL=gemini-3.5-flash-lite flutter test tool/live/live_test.dart
Q='whole milk|poha' flutter test tool/live/search_probe_test.dart
```

Rebuild the USDA table from the [SR Legacy CSV download](https://fdc.nal.usda.gov/download-datasets):

```bash
python tool/build_usda.py path/to/FoodData_Central_sr_legacy_food_csv_2018-04
```

### Release builds

Create an upload key once and keep it somewhere safe (losing it means you can't update the app on the Play Store):

```bash
keytool -genkey -v -keystore nomnom-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` to `android/key.properties` and fill in the path and passwords. It is git-ignored; without it, release builds are signed with the debug key.

```bash
flutter build appbundle            # for the Play Store
flutter build apk --split-per-abi  # smaller APKs to share directly
```

### Layout

```
lib/
├── ai/            provider clients (OpenAI-compatible, Gemini) and the meal parser
├── data/          models, the in-memory store over Hive, key vault
├── nutrition/     food table search, targets, countries
├── screens/       setup, today, log, history, progress, you
├── theme/         Paper design tokens and theme
└── ui/            shared widgets: ring, week strip, charts, controls
assets/data/       usda.json, dishes_in.json
tool/              data build script, screenshot harness
```

## Credits

Typography: Clash Grotesk (Indian Type Foundry, Fontshare licence) and Instrument Serif (SIL Open Font Licence). Nutrition data: USDA FoodData Central and Open Food Facts (ODbL).

Estimates, not medical advice.
