# How to use the translation overlay on any app

Jusoor's most powerful feature is not the translation engine itself but where it works from: a floating window (overlay) that appears above any app you are using, giving you instant translation without leaving your screen and without the usual copy-and-paste dance. In this guide we explain how to enable and use it step by step.

## Before you start

Make sure of the following:

- Your device runs **Android 8.0** or above.
- Jusoor is installed: [download it from GitHub Releases](https://github.com/digitaltrekkerr/jusoor/releases)
- You added an AI provider API key from **Settings ← API Keys**, and created a valid provider profile.
- You selected a default target language in Settings — the source language is estimated automatically by the AI provider.

## Step 1: Allow "Display over other apps"

Drawing a window above other apps requires a special Android permission that is granted from system settings, not with a simple tap:

1. The first time you launch the floating window, Jusoor will take you to the relevant permission page automatically.
2. You can also open it manually from inside the app: **Settings ← Permissions ← Display over other apps (floating window)**, then tap **"Enable"**.
3. On the system screen that appears, allow Jusoor to display windows over other apps.

The **Permissions** page inside the app shows the live status of every permission, with a one-tap enable button — if you are ever unsure, that page is your first reference.

## Step 2: Allow notifications (Android 13 and above)

Jusoor requests the **notification** permission automatically on first launch on newer devices. The reason is simple: Android requires a persistent notification for as long as the floating overlay service is running, showing "Floating translation overlay is active", which disappears when the overlay closes. This notification is never used for ads — its only job is keeping the service alive.

## Step 3: Launch the floating window

You have two ways to launch it:

- **The "Translate" tile in Quick Settings**: swipe down the Quick Settings panel, add the Jusoor tile if it is not there (via the edit/pencil button), then tap it at any time, in any app.
- **From inside the app**: open Jusoor and start the floating translation from there directly.

The service notification will appear in the status bar, and the floating window will be ready to work.

## Step 4: Grant screen capture only when needed

The screen-capture permission (MediaProjection) is different from the others: it is not requested up front but **only at the moment of need**. When you press the "Screenshot" button inside the floating window to translate what is on the screen, Android shows its own consent dialog, and no capture happens until you explicitly agree. Jusoor hides its own window during capture so it does not appear in the image, and capture stops entirely when the floating window closes.

## Step 5: Read the result above any app

Now for the fun part. While inside any app:

1. Copy the text you want to translate from the other app.
2. Press **"Paste"** in the floating window — or take a screenshot if the content is an image or non-selectable text.
3. The translation appears inside the window, formatted and organized with full Markdown and BiDi (bidirectional) support, so you can read it clearly over the original content.

Done? Close the window and the service and notification stop with it.

## Practical scenarios

### Translating conversations without leaving them

Got an English message while inside your chat app? Swipe down the "Translate" tile, paste the message text, read the translation, then copy your translated reply and return to the conversation — all without actually leaving the screen you are working on.

### Foreign articles and websites

While reading a long article, take a screenshot of the confusing paragraph instead of copying it word by word. Image mode is especially useful here: text embedded in article images and infographics gets translated too.

## Tips for a better experience

- **Pick the right mode for each content type**: text mode is faster and more accurate for selectable text, while image mode is the only option for visual or non-selectable content.
- **Set your floating translation template**: from **Settings ← Floating Overlay**, choose the template used inside the window — whether it supports text and images together or only one of them ("text & image", "text only", "image only").
- **Control the window size**: from Settings you can choose the size mode — "compact", a floating card in the middle of the screen taking up about 75% of its height with a dimmed background, or "full" to fill the space between the status and navigation bars.
- **Customize the translation style**: edit the system prompts in your templates to set the tone and domain, for example "translate with formal medical terminology".

## Troubleshooting common issues

| Problem | Solution |
| --- | --- |
| The floating window does not appear | Open **Settings ← Permissions** inside Jusoor and confirm "Display over other apps" is granted; if it shows "permanently denied", use the "Open settings" button. |
| The "Translate" tile is missing from Quick Settings | Swipe down the Quick Settings panel and press the edit button to add the Jusoor tile to the active tiles. |
| Screenshot does not work | Make sure the floating window is active, and accept the Android screen-capture dialog that appears on first use. |
| Translation does not arrive or fails | Check your provider profile and API key in Settings, and your internet connection. |
| The result is in an unexpected language | Review your "Target language" selection — the source language is estimated automatically by the AI provider, and may need clarifying in the input text for mixed-language content. |