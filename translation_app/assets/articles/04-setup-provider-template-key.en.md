# Setup from scratch: provider, template, and API key

How do you get your first Jusoor translation from zero? You need three things: a **translation provider** (the service running the AI model), a **translation template** (the system instructions steering the model), and an **API key** (your pass to the provider). This article ties them all together step by step.

## Step 1: Add an API key

Open **Settings ← API Keys** and press the add-new-key button:

- Give the key a clear name (e.g. "Primary OpenRouter" or "Home Gemini").
- Paste the key value from the provider's page (see articles 5 and 6 for getting a Gemini and an OpenRouter key).
- Save. The key is stored in the encrypted secure vault on your device and is never shown in full again.

## Step 2: Create a provider profile

The provider is the "connection account" that links your key to a specific model:

1. From **Settings ← Provider Profiles** press "Add provider".
2. Choose the provider type: **OpenRouter**, **Gemini**, **OpenAI**, or **OpenAI-compatible** (for local endpoints such as Ollama and LM Studio).
3. Link the key you created in step 1.
4. Enter the model name (e.g. `openai/gpt-5.6-luna` for OpenRouter, or `gemini-3.5-flash-lite` for Gemini models).
5. If the provider supports images, choose a **Vision Model** — leave it empty and the text model is used for images too.
6. For custom providers: set the **Base URL** — it must start with `https://` unless it is a local address such as `http://localhost:11434`.

## Step 3: Create the translation template

The template defines *how* the model translates — tone, domain, output formatting:

1. From **Settings ← Translation Templates** press "Add template".
2. Pick the provider profile you created.
3. Write the **system prompt**: "You are a professional translator. Translate into {{target_language}} accurately while preserving Markdown formatting."
4. Choose what the template supports: text, image, or both.
5. Set a fixed target language if you want one — or leave it free and let the model detect the source language.

## Step 4: Set the template as your active one

- Open the **home screen** and pick the new template from the template dropdown at the top.
- Set your **target language** from the dropdown.
- Press "Translate" and watch the result stream into the app.

## Step 5 (optional): A fallback profile

From **Settings ← Provider Profiles** you can set a **fallback profile**: if the primary provider fails (bad key, service outage, unavailable model), the fallback takes over automatically. Great for reliability — use two different providers with two different keys.

## Quick reference

| Component | Where to find it | Role |
| --- | --- | --- |
| API key | Settings ← API Keys | Your pass to the provider |
| Provider profile | Settings ← Provider Profiles | Links the key to the model and endpoint |
| Template | Settings ← Translation Templates | Defines the translation style and system prompt |
| Active template | Home screen | What actually runs when you press "Translate" |

That's it — you are ready. To enable the floating window over other apps, see the article "How to use the translation overlay on any app".