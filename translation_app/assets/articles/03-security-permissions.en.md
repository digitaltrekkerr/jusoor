# Jusoor security & privacy — why does it need those permissions?

When an app asks for screen capture and display-over-apps permissions, it is your right — even your duty — to stop and ask: why? And what will it do with these capabilities? At Jusoor we believe the question deserves a complete answer, not general statements, and because the app is open source you can verify every word we say here yourself.

## Jusoor's permission philosophy

Jusoor's rule is simple: **the app only asks for what its features genuinely need, and it explains every request before you agree to it**. That is why we dedicated a **Permissions** page inside Settings; it shows the live status of every permission (granted / not granted / granted at install), with an explicit explanation of its role and a one-tap enable button.

Here is the complete list, transparently:

## The full permission table

| Permission or feature | Why Jusoor needs it | How it is granted |
| --- | --- | --- |
| Display over other apps (`SYSTEM_ALERT_WINDOW`) | Drawing the floating window above other apps — the app's core feature | From system settings on the first launch of the floating window |
| Screen capture (MediaProjection) | Translating screenshots: text inside images and non-copyable content | A system consent dialog **before every capture** |
| Notifications (`POST_NOTIFICATIONS`) | The persistent floating-service notification required by Android 13+ | A system dialog on first launch |
| Background service (`FOREGROUND_SERVICE` + `SPECIAL_USE`) | Keeping the floating window working while you use other apps | Automatic — never asked from you |
| Internet access (`INTERNET`) | Sending what you translate to the AI provider you chose | Automatic at install |
| Clipboard | The "Paste" button in the floating window to translate copied text | No permission needed — governed by the Android platform itself |
| Sharing from other apps | Receiving text, links, and images via the share sheet | No permission needed — a standard sharing mechanism |
| File import | Selecting a file to translate through the system file picker | No permission needed — you choose every file |

Note something important: **Jusoor does not request access to your storage**. Reading images and files happens exclusively through the system picker, meaning Jusoor only sees what you choose and never scans your files.

## A detailed look at the sensitive permissions

### Display over other apps

Jusoor draws the floating translation window above other apps, and it only opens when you tap the "Translate" tile in Quick Settings or the floating-window button. While it is open, touches inside its area are handled by Jusoor alone — **the window never operates hidden** without your knowledge.

### Screen capture — the most important and most sensitive permission

This permission deserves first place in any privacy discussion, so here is its full picture:

- When you press "Screenshot" in the floating window, Jusoor hides its own window, then captures **everything visible on screen — including other apps** — and sends this image to the translation provider you configured yourself to extract and translate the text.
- **The image is not saved on your device**; what is saved in history is only the translated text.
- Android shows its own consent dialog **before any capture**, and capture stops completely when the floating window closes.

And here is the honest warning we owe you: since capture includes the whole screen, **avoid translating while sensitive screens are showing** (a banking app, private messages, password fields) unless you want their visual content to reach the translation provider.

### Notifications and the background service

Android requires a visible notification while the floating overlay service is running, showing "Floating translation overlay is active", which disappears when the overlay closes. The small background service's job is keeping the window alive while you move between apps: it starts when the window opens, stops when it closes, and Android always shows it in the running-apps list — nothing runs hidden.

### Internet access and the clipboard

Jusoor sends the content you translate (text you type, files you share, screenshots) over an encrypted connection to the translation provider you chose. Also, anyone who holds your API key can read what is sent to that provider — so keep your keys secret and be mindful of what you translate.

The "Paste" button reads your clipboard to translate text copied from other apps; on modern Android a brief transparent window may appear once to satisfy platform restrictions. The content is held in memory only, for at most one minute, **then erased automatically** — nothing is stored permanently.

## How does Jusoor protect your data?

### Your keys never leave your device except to your provider

The app only sends your keys to the AI provider you choose. Practically, this means:

- Keys are stored in a **secure encrypted vault backed by the Android Keystore** on your device, not in an exposed plain-text file.
- Requests go **directly from your phone to your provider** — there is no Jusoor intermediary server in the middle.
- **The app enforces HTTPS for every remote provider URL.** When you save a custom endpoint in Settings, Jusoor requires an `https://` address and refuses to save plain `http://` URLs — the single exception is local machine addresses (`localhost`, `127.0.0.1`) so you can keep using local models such as Ollama on your own device.

### The translation history stays on your device

The translation history is stored in a local database on your phone, and the app's backup rules explicitly exclude history, settings, and API keys from **cloud backup and device-to-device transfer** — so your translations never reach your cloud account without your knowledge, even if you enable full Android system backup.

### No analytics, no tracking

The declared dependency list of Jusoor contains no analytics or user-tracking packages. And because the app is fully open source, this is not a marketing promise but **something anyone can verify** in the code.

## What you should know

Transparency also means stating what is *not* secret:

- What you translate — text or image — **actually travels** to the AI provider you chose for processing; that is how AI translation works.
- Your translation history is stored locally on your device, so its security equals your device's security.
- If you share content into Jusoor from another app, that content is sent to the translation provider as the feature implies.

## Open source: verify it yourself

None of the above is an invitation to blind trust. Jusoor's code is available for public review under the MIT license on GitHub: [github.com/digitaltrekkerr/jusoor](https://github.com/digitaltrekkerr/jusoor). Read it, review it — even contact us if you find a vulnerability; we have a dedicated security disclosure policy ([SECURITY.md](https://github.com/digitaltrekkerr/jusoor/blob/main/SECURITY.md)) and welcome responsible security reports.

## Summary

The permissions Jusoor requests are the same ones its features require: a floating window needs display-over-apps, screenshots need explicit capture consent, and cloud translation needs internet. What the features do not require — like access to your storage — is not on the list at all.