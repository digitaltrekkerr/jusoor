# What is Jusoor — instant on-screen translation for Android?

Picture a familiar scene: you are reading a foreign-language article and hit a paragraph you do not understand, or a message arrives inside a chat app in a language you do not know. The classic routine is known to everyone: select the text, copy it, leave the app, open a translator app, paste, wait for the result, then go back. And when the content is an image — a menu in a foreign language, or a screenshot from a game with English menus — the process gets much harder.

**Jusoor** exists to collapse that whole cycle into a single tap.

## What is Jusoor?

Jusoor — Arabic for "bridges" — is a free, open-source Android app built with Flutter that puts the power of AI translation into a **floating window (overlay)** that hovers above any other app you are using. Instead of hopping between apps, you summon the Jusoor window over what you are working on, get the translation instantly, and carry on.

The core idea behind Jusoor is that **you are in control**: you enter your own API keys once, and the connection stays direct between your phone and the provider you chose — with no intermediary server in the middle.

## A quick tour of the features

### Translate above everything: the floating overlay

Jusoor's headline feature is the floating window that works on top of other apps. You launch it from the "Translate" tile in Quick Settings or from inside the app, and it stays available while you move between apps. You dismiss it with a tap when you are done.

### Text and image input

You can type or paste text directly, pick an image from your device to have its visual text translated, or share content into Jusoor from any app via the system share sheet — text, links, and images are all supported.

### 29 target languages to choose from

Jusoor offers 29 common languages as targets — just pick the language you want to translate into, and the AI provider figures out the source language on its own.

### Customizable prompt templates

Translation in Jusoor is driven by system prompts you can edit or build new templates from. Each template uses the `{{target_language}}` variable, which is replaced automatically with the target language when sent; with the **"Auto-substitute target language"** option you can also send the variable literally if your workflow calls for it. Templates let you set tone, domain, and output style — from precise technical translation to fluid copywriting.

### Choose your own AI provider

Jusoor works with **Google Gemini**, **OpenRouter**, and any OpenAI-compatible endpoint — including local services such as Ollama, LM Studio, and vLLM if you prefer running models on your own hardware. Create multiple provider profiles with different keys and switch between them anytime; you can even set a **fallback profile** that takes over translation automatically if the primary provider fails.

### A complete, searchable translation history

Every translation result is saved to the **local history** on your device; you can search it, return to entries later, or copy and share them with one tap. Beneath each result on the home screen, a small line shows the model used and the translation time in seconds — full transparency about what happens behind the scenes.

## Little details that make a difference

Beyond the headline features, Jusoor carries thoughtful touches that show up in daily use:

- **Long-file translation**: upload an entire text file and Jusoor will split it into batches and translate it without breaking your focus.
- **Smart word limit**: if the text exceeds the limit you set, the app asks before continuing instead of silently trimming your content.
- **Two overlay modes**: a compact card in the middle of the screen, or a full view that fills the space between the status and navigation bars — your choice.
- **Full output view**: open the resulting translation in a dedicated reading screen when you need more visual focus.
- **Restore built-ins**: one button brings back the default templates and provider profiles if you delete them by accident.

### Arabic-first interface

Jusoor is an Arabic-origin app: its interface is fully right-to-left (RTL) from day one, with English as a secondary option you can switch to instantly from Settings — no app restart required.

## Who is Jusoor for?

- **The curious reader**: someone browsing articles and sites in foreign languages who wants quick understanding without interrupting their reading flow.
- **The chat user**: someone talking to people in different languages who needs quick, passing message translation.
- **Gamers and foreign-app fans**: people using games and apps that lack their native language, where menus and text are translated from a screenshot.
- **Learners**: language students who want to see an instant translation beside the original text while practising.
- **The technical user**: someone with an API key from an LLM provider, or running a local model via Ollama, who wants a polished Arabic interface in front of them.

## Getting started in minutes

Your first Jusoor translation does not take long:

1. Download and install the app on your phone (Android 8.0 and above).
2. Open **Settings** and enter your provider's API key on the **API Keys** screen.
3. Choose a target language — the AI provider estimates the source language automatically.
4. Type some text or paste an image, then press **Translate**.

To enable the most powerful feature — the floating window above any app — read our detailed guide in the second article below. And if security questions are your first concern, the third article explains every permission the app asks for and why.

## Download Jusoor and try it now

Jusoor is completely free and open source, published under the MIT license, and any developer can review its code or contribute to it. Download it from the GitHub releases page:

- Download from [GitHub Releases](https://github.com/digitaltrekkerr/jusoor/releases)

If Jusoor has saved you time and effort, consider supporting its continued development:

- Join as a supporting member on [Patreon](https://www.patreon.com/cw/DigitalTrekkerr/membership)
- Star ⭐ the [repository on GitHub](https://github.com/digitaltrekkerr/jusoor) — it is a big encouragement for the team