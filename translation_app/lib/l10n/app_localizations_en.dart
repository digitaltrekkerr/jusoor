// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Jusoor';

  @override
  String get appCancel => 'Cancel';

  @override
  String get appProceed => 'Proceed';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeSelectTextTemplate => 'Select text template';

  @override
  String get homeSelectImageTemplate => 'Select image template';

  @override
  String get homeTextTemplateTitle => 'Text Template';

  @override
  String get homeImageTemplateTitle => 'Image Template';

  @override
  String get homeTargetLanguageHint => 'Target';

  @override
  String get langRow_targetTooltip => 'Target language';

  @override
  String get langAuto_selectTitle => 'Select Language';

  @override
  String get langAuto_searchHint => 'Search languages...';

  @override
  String get homeInputHint => 'Enter text to translate...';

  @override
  String get homePasteTooltip => 'Paste from clipboard';

  @override
  String get homePickImageTooltip => 'Pick image';

  @override
  String get homeUploadFileTooltip => 'Upload file';

  @override
  String homeWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
      zero: '0 words',
    );
    return '$_temp0';
  }

  @override
  String get homeTranslateButton => 'Translate';

  @override
  String get homeClearButton => 'Clear';

  @override
  String get homeShareTooltip => 'Share translation';

  @override
  String get homeShareText => 'Translation result';

  @override
  String get homeShareSubject => 'Jusoor Result';

  @override
  String get homeOutputTitle => 'Translation';

  @override
  String get homeCopyTooltip => 'Copy translation';

  @override
  String get homeCopiedToClipboard => 'Copied to clipboard';

  @override
  String homeModelInfo(String model, int seconds) {
    return 'Model: $model · ${seconds}s';
  }

  @override
  String get homeWordLimitTitle => 'Word Limit Exceeded';

  @override
  String homeWordLimitBody(int count, int limit) {
    return 'Your text has $count words, which exceeds the limit of $limit words. Do you want to proceed anyway?';
  }

  @override
  String get homeErrorSharedContent => 'Could not read shared content.';

  @override
  String get homeErrorFileBytes => 'Could not read file bytes.';

  @override
  String get homeFileWillBeChunked => 'File will be translated in chunks';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsApiKeys => 'API Keys';

  @override
  String get settingsProviderProfiles => 'Provider Profiles';

  @override
  String get settingsTemplates => 'Templates';

  @override
  String get settingsSectionOverlay => 'Overlay';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionAdvanced => 'Advanced';

  @override
  String get settingsDefaultTargetLanguage => 'Default Target Language';

  @override
  String get settingsWordLimit => 'Word Limit';

  @override
  String get settingsWordLimitHint => '5000';

  @override
  String get settingsTargetLanguageHint => 'Target language';

  @override
  String get settingsAppLanguage => 'App Language';

  @override
  String get settingsAppLanguageSystem => 'System default';

  @override
  String get settingsAppLanguageTitle => 'App Language';

  @override
  String get settingsFallbackProfile => 'Fallback Profile';

  @override
  String get settingsNoneOption => '(None)';

  @override
  String get settingsRestoreBuiltIn => 'Restore Built-in Items';

  @override
  String get settingsAlreadyPresent =>
      'All built-in items are already present.';

  @override
  String settingsRestoredSnackbar(int profiles, int templates) {
    return 'Restored $profiles profile(s) and $templates template(s).';
  }

  @override
  String get settingsOverlayTemplate => 'Overlay Template';

  @override
  String get settingsSelectOverlayTemplate => 'Select overlay template';

  @override
  String get settingsOverlayTemplateDescription =>
      'Used for both text and image translation in the overlay.';

  @override
  String get settingsOverlayTextAndImage => 'Text & Image';

  @override
  String get settingsOverlayTextOnly => 'Text only';

  @override
  String get settingsOverlayImageOnly => 'Image only';

  @override
  String get settingsSizeMode => 'Size Mode';

  @override
  String get settingsOverlaySizeModeTitle => 'Overlay Size Mode';

  @override
  String get settingsOverlaySizeModeDescription =>
      'Choose how the overlay fills the screen.';

  @override
  String get settingsOverlaySizeCompressed => 'Compressed';

  @override
  String get settingsOverlaySizeFull => 'Full';

  @override
  String get settingsOverlaySizeCompressedDescription =>
      'Floating card in the center, ~75% of screen height. Dark background dims the rest.';

  @override
  String get settingsOverlaySizeFullDescription =>
      'Fills the entire content area between status bar and navigation bar. No borders or shadow.';

  @override
  String get settingsSupport => 'Support';

  @override
  String get settingsPermissions => 'Permissions';

  @override
  String get settingsInstructions => 'Instructions';

  @override
  String get settingsSectionHelp => 'Help & Support';

  @override
  String get settingsArticles => 'Articles';

  @override
  String get settingsArticlesSubtitle => 'Quick guides & how-it-works';

  @override
  String get articleLoadError => 'Could not load the article.';

  @override
  String get articleRetry => 'Retry';

  @override
  String get pagesSupportTitle => 'Support Jusoor';

  @override
  String get pagesPatreonTitle => 'Support on Patreon';

  @override
  String get pagesPatreonSubtitle =>
      'Become a member to help fund ongoing development and unlock supporter perks.';

  @override
  String get pagesGithubTitle => 'Star on GitHub';

  @override
  String get pagesGithubSubtitle =>
      'Show your support by starring the project and following new releases.';

  @override
  String get pagesWebsiteTitle => 'Website';

  @override
  String get pagesWebsiteSubtitle =>
      'Visit digitaltrekkerr.com for more about the project.';

  @override
  String get pagesEmailTitle => 'Email';

  @override
  String get pagesEmailSubtitle => 'support@digitaltrekkerr.com';

  @override
  String get pagesOpeningLink => 'Opening in your browser...';

  @override
  String get supportInvalidUrl => 'Invalid URL';

  @override
  String get pagesPermissionsTitle => 'Permissions';

  @override
  String get pagesPermissionScreenCaptureTitle =>
      'Screen capture (screenshot translation)';

  @override
  String get pagesPermissionScreenCaptureBody =>
      'When you tap Screenshot in the overlay, Jusoor hides its own window and captures everything currently visible on the screen — including other apps — then sends that image to the translation provider you configured (e.g. OpenRouter/Gemini/OpenAI/custom) to translate the text in it. The image is not saved to your device; only the translated text is kept in History. Android shows a consent dialog before any capture, and capture stops when the overlay closes.';

  @override
  String get pagesPermissionScreenCaptureGrant => 'Try now';

  @override
  String get pagesPermissionOverlayTitle => 'Overlay (Display over other apps)';

  @override
  String get pagesPermissionOverlayBody =>
      'Jusoor draws its floating translation window on top of other apps. It opens only when you tap the Quick Settings \'Translate\' tile or the overlay button. While it is open, touches inside the shaded top area are handled by the overlay; it never runs invisibly.';

  @override
  String get pagesPermissionOverlayGrant => 'Enable';

  @override
  String get pagesPermissionNotificationsTitle => 'Notifications';

  @override
  String get pagesPermissionNotificationsBody =>
      'Android requires a visible notification while the translation overlay service is running. This notification shows \'Translator Overlay is active\' and disappears when the overlay closes. It is only used to keep the overlay alive.';

  @override
  String get pagesPermissionNotificationsGrant => 'Enable';

  @override
  String get pagesPermissionFgsTitle => 'Background service (overlay engine)';

  @override
  String get pagesPermissionFgsBody =>
      'A small background service keeps the overlay working while you use other apps. Android always shows it in the active-apps list with a notification. It starts when the overlay is opened and stops when the overlay is closed.';

  @override
  String get pagesPermissionInternetTitle => 'Internet access';

  @override
  String get pagesPermissionInternetBody =>
      'Jusoor sends the content you translate (text you type, files you share, or screenshots) over an encrypted connection to the translation provider you chose in Settings. Anyone with your API key can read what is sent to that provider — keep your keys private and be mindful of what you translate.';

  @override
  String get pagesPermissionClipboardTitle =>
      'Clipboard (Paste in the overlay)';

  @override
  String get pagesPermissionClipboardBody =>
      'The Paste button in the overlay reads your device clipboard so you can translate text copied from other apps. On modern Android this may briefly open a transparent window once, and Jusoor keeps the text in memory for up to a minute as a fallback. Cached content auto-clears after a minute. Nothing is stored permanently.';

  @override
  String get pagesPermissionShareTitle => 'Share from other apps';

  @override
  String get pagesPermissionShareBody =>
      'Any app can open Jusoor through the system Share menu to translate text, links or files. Shared content is uploaded to the translation provider for processing. This is how quick-translate works and cannot be disabled without losing the feature.';

  @override
  String get pagesPermissionQuickSettingsTitle =>
      'Quick Settings \'Translate\' tile';

  @override
  String get pagesPermissionQuickSettingsBody =>
      'Jusoor adds a tile to your Quick Settings (Android 7+) that opens the overlay directly. Requires the overlay permission to be enabled.';

  @override
  String get pagesPermissionFilesTitle => 'Importing files';

  @override
  String get pagesPermissionFilesBody =>
      'Files are imported through the system file picker — you choose each file, and Jusoor never scans your storage. The chosen file\'s text is uploaded to the translation provider for translation.';

  @override
  String get pagesGrantedAtInstall => 'Granted at install';

  @override
  String get pagesPermissionStatusGranted => 'Granted';

  @override
  String get pagesPermissionStatusDenied => 'Not granted';

  @override
  String get pagesPermissionStatusPermanent =>
      'Permanently denied — open Settings';

  @override
  String get pagesPermissionStatusInformational => 'Always on';

  @override
  String get pagesPermissionOpenSettings => 'Open Settings';

  @override
  String get pagesPermissionSettingsHint =>
      'If the system dialog does not appear, open Android Settings → Apps → Jusoor → Permissions.';

  @override
  String get pagesInstructionsTitle => 'Instructions';

  @override
  String get pagesHowToUseHeader => 'How to use the app';

  @override
  String get pagesHowToUseStep1 =>
      'Open Jusoor and pick a source text or image template from the top of the Home screen.';

  @override
  String get pagesHowToUseStep2 =>
      'Choose your target language, then type or paste text (or pick an image) in the input area.';

  @override
  String get pagesHowToUseStep3 =>
      'Tap Translate to see the result below. You can copy, share, or open it in the full output view.';

  @override
  String get pagesHowToUseStep4 =>
      'To translate from another app, use the system Share menu and pick Jusoor — text, links, and images are supported.';

  @override
  String get pagesHowToUseStep5 =>
      'For a floating translator on top of any app, add the Quick Settings \'Translate\' tile and tap it to open the overlay.';

  @override
  String get pagesHowToWritePromptsHeader => 'How to write good prompts';

  @override
  String get pagesHowToWritePromptsTip1 =>
      'State the desired tone and register (formal, casual, technical, marketing, etc.) so the model matches your audience.';

  @override
  String get pagesHowToWritePromptsTip2 =>
      'Mention the domain (medical, legal, software, gaming) so the model uses the right vocabulary and conventions.';

  @override
  String get pagesHowToWritePromptsTip3 =>
      'List any terms, brand names, or product names that must be kept untranslated.';

  @override
  String get pagesHowToWritePromptsTip4 =>
      'Tell the model what to do with ambiguity: prefer literal, prefer natural, ask for clarification, or pick the most common reading.';

  @override
  String get pagesHowToWritePromptsTip5 =>
      'Specify the output format you want: plain text, markdown, JSON, or line-by-line preserving the source structure.';

  @override
  String get pagesHowToWritePromptsTip6 =>
      'Include short examples of the style you want — one or two before/after pairs are usually more effective than a long rule list.';

  @override
  String get tplEditNewTitle => 'New Template';

  @override
  String get tplEditExistingTitle => 'Edit Template';

  @override
  String get tplEditNameLabel => 'Name';

  @override
  String get tplEditNameHint => 'e.g. Professional Translator';

  @override
  String get tplEditProfileLabel => 'Profile';

  @override
  String get tplEditSystemPromptLabel => 'System Prompt';

  @override
  String tplEditWarningMissingTarget(String target_language) {
    return 'The system prompt does not contain $target_language. Translations may not know which language to use.';
  }

  @override
  String get tplEditResetToDefault => 'Reset to Default';

  @override
  String get tplEditSupportsText => 'Supports Text';

  @override
  String get tplEditSupportsTextSubtitle =>
      'This template can be used for text translation.';

  @override
  String get tplEditSupportsImage => 'Supports Image';

  @override
  String get tplEditSupportsImageSubtitle =>
      'This template can be used for image/vision translation.';

  @override
  String get tplSubTitle => 'Auto-substitute target language';

  @override
  String tplSubSubtitle(String target_language) {
    return 'Replace the $target_language placeholder in the prompt with the chosen language before sending.';
  }

  @override
  String get tplEditSaveButton => 'Save';

  @override
  String get tplEditErrorNameRequired => 'Template name is required.';

  @override
  String get tplEditErrorProfileRequired => 'Please select a profile.';

  @override
  String get tplEditErrorPromptRequired => 'System prompt is required.';

  @override
  String get tplEditErrorCapabilityRequired =>
      'Enable at least one capability (Text or Image).';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableAction => 'Download';

  @override
  String updateAvailableSubtitle(String version) {
    return 'Version $version is available.';
  }
}
