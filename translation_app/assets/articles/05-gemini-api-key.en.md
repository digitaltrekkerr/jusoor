# Get a free Gemini API key

Google offers Gemini models to developers through **Google AI Studio** with a generous free tier — no credit card needed to start, though some models require linking a billing account. This article walks you through getting the key and pasting it into Jusoor.

## Step 1: Open Google AI Studio

- Browse to [aistudio.google.com](https://aistudio.google.com) from any browser on your computer or phone.
- Sign in with your Google account. Do not have one? Create it — it does not have to be an old Gmail; any valid Google account works.

## Step 2: Create an API key

1. Press the **"Get API key"** icon or open the page from the menu at [aistudio.google.com/apikey](https://aistudio.google.com/apikey).
2. Press **"Create API key"**.
3. Choose the Google Cloud project to link the key to (you can create a new project in one press or use the default).
4. The key is shown as a long string that usually starts with `AIza...` — **copy it immediately**, because it is not shown in full again after you close the dialog.

## Step 3: Paste the key into Jusoor

1. Open Jusoor ← **Settings ← API Keys**.
2. Press "Add key", name it (e.g. "Gemini"), and paste the key.
3. Save.

Then make sure your provider profile uses it:

- **Settings ← Provider Profiles**: pick a provider of type **Gemini** and link it to this key.
- Model name: keep the default (`gemini-3.5-flash-lite`, for example) or enter an available model from [Gemini models](https://ai.google.dev/gemini-api/docs/models).

## What is "linking a billing account" and why does it appear?

Since 2025, Google requires linking a billing account in Google Cloud for some newer Gemini models — even with a free tier remaining. That does not mean you will necessarily pay:

- Free credits are consumed first every day.
- You are only billed if you exceed the free limit and explicitly opt into paid tiers.
- In Google Cloud, choose "Billing" and add a payment method — you can stay within the free limits and the account stays free.

## Troubleshooting common issues

| Problem | Solution |
| --- | --- |
| "API key not valid" when translating | Make sure you copied the key in full without spaces or newlines, and that it comes from the same Google account linked to Jusoor. |
| Error 429 (too many requests) | The free tier has per-minute limits; wait a few seconds and retry, or use a lighter model such as `gemini-3.5-flash-lite`. |
| The key does not show after saving | Jusoor never displays full keys for security reasons — verify that the provider profile is linked to the right key by name. |