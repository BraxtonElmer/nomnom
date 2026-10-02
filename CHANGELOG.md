# Changelog

Each release's section becomes its GitHub release notes and the "what's new" text in the in-app update prompt.

## [2.7.0] - 2026-10-02

The first release of nomnom on GitHub.

nomnom is a calorie and macro tracker you talk to in plain words: type "grilled chicken, a cup of quinoa and a Greek salad" and get the items, grams and macros. There's no account and no server. It uses your own free AI key (Groq or Gemini, or a local model through Ollama or LM Studio), and the numbers come from real food tables, not the AI's memory.

### Logging
- Type a meal the way you'd say it, in grams, pieces, cups, bowls or plates. Simple meals are read on the phone without any AI.
- Numbers from USDA FoodData Central, tables of about 300 dishes across 16 cuisines, and Open Food Facts for branded products.
- Every item shows where its numbers came from. Anything uncertain is flagged or asked about, not guessed.
- Log from a photo, re-log favourites, repeat yesterday's meal, copy a whole day, and save meals for later when you're offline.
- Reply to a meal reminder straight from the notification to log it.

### Tracking
- Today's calories, macros and the main micronutrients (fibre, sugar, sodium, potassium, calcium, iron, vitamin C, B12).
- Weight for any day, with a smoothed trend and BMI (using the lower Asian cut-offs where they apply).
- Goal check-in: after a few weeks it measures your real maintenance calories from what you eat and weigh, and suggests a better target. Nothing changes until you accept.
- A weekly recap, a note on each plate, a home-screen widget, and steps and active calories from Health Connect.

### Pantry
- Add what you buy ("10 eggs, 450 g chicken breast") and it counts down as you log. Cooked weights are worked back to raw.
- Alerts when something runs low, runs out or nears its use-by date.

### Updates
- nomnom checks for new versions here once a day and offers them in the app. Android asks you to confirm the install, and your log stays as it is.

### Privacy
- Your log stays on your phone. Only what you log (text or a photo) is sent, and only to the AI provider you chose. Backups never include your API key.
