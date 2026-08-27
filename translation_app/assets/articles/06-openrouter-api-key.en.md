# Get an OpenRouter API key

**OpenRouter** is a single provider that gives you access to hundreds of AI models — from OpenAI to Google, Meta, Mistral, and more — with one balance and one key. A great perk: free models (with the `:free` suffix) let you start at zero cost. This article covers creating the key and (optionally) adding credits.

## Step 1: Create an OpenRouter account

- Open [openrouter.ai](https://openrouter.ai).
- Sign in — you can use a Google account, GitHub, or email.
- Your account page shows a dashboard with your balance, usage, and keys.

## Step 2: Create an API key

1. Go to [openrouter.ai/keys](https://openrouter.ai/keys) (or account ← "Keys").
2. Press **"Create Key"**.
3. Give it a name (e.g. "Jusoor"); you can leave the Limits options empty for general use.
4. Copy the resulting key — it starts with `sk-or-...` — **it is only shown once**, so save it somewhere safe immediately.

## Step 3: Paste the key into Jusoor

1. Open Jusoor ← **Settings ← API Keys** ← "Add key".
2. Name it (e.g. "OpenRouter") and paste the key.
3. Save, then from **Settings ← Provider Profiles** verify that your provider of type **OpenRouter** is linked to this key.

## Step 4: Choose your model

In the provider profile, enter any OpenRouter model ID, for example:

- `openai/gpt-5.6-luna` — a strong text-and-image model (text + vision).
- `deepseek/deepseek-chat` — a fast, cheap text model.
- `mistralai/ministral-8b:free` — free models to get started.

Browse [all models](https://openrouter.ai/models) and filter by capabilities (image/text) and price. Most new non-`:free` models require credit on your account.

## Step 5 (optional): Add credits

To go beyond the free models:

1. From [openrouter.ai/settings/credits](https://openrouter.ai/settings/credits) press "Add Credits".
2. Choose an amount (starting from a few dollars) and a payment method.
3. Credits are consumed per model price per million tokens — light models cost fractions of a cent per translation.

## Why OpenRouter?

- **One provider, many models**: switch between Claude, Gemini, and DeepSeek without changing settings — just edit the model name in your profile.
- **Free models for testing**: ideal for trying Jusoor for the first time.
- **Unified usage log**: the "Usage" page shows every request and its exact cost.

## Troubleshooting common issues

| Problem | Solution |
| --- | --- |
| "Insufficient credits" | The free tier does not cover the chosen model; use a `:free` model or add credits. |
| "404 model not found" | Make sure you entered the model ID exactly as it appears in the [model list](https://openrouter.ai/models) — no spaces. |
| Slow translation | Some free models are congested; try a faster model or the default "Provider Routing" in the OpenRouter dashboard. |