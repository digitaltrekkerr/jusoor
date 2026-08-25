import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application display name.
  ///
  /// In en, this message translates to:
  /// **'Jusoor'**
  String get appName;

  /// Generic cancel button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get appCancel;

  /// Generic proceed / continue button label.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get appProceed;

  /// Bottom navigation tab label for the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation tab label for the history screen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// Bottom navigation tab label for the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Placeholder label for the text template selector before a template is picked.
  ///
  /// In en, this message translates to:
  /// **'Select text template'**
  String get homeSelectTextTemplate;

  /// Placeholder label for the image template selector before a template is picked.
  ///
  /// In en, this message translates to:
  /// **'Select image template'**
  String get homeSelectImageTemplate;

  /// Title of the bottom sheet that lets the user pick a text template.
  ///
  /// In en, this message translates to:
  /// **'Text Template'**
  String get homeTextTemplateTitle;

  /// Title of the bottom sheet that lets the user pick an image template.
  ///
  /// In en, this message translates to:
  /// **'Image Template'**
  String get homeImageTemplateTitle;

  /// Hint text shown inside the target language dropdown on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get homeTargetLanguageHint;

  /// Accessibility / semantics label for the target language dropdown on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get langRow_targetTooltip;

  /// Title of the bottom sheet shown when picking a language.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get langAuto_selectTitle;

  /// Hint text of the search field inside the language picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Search languages...'**
  String get langAuto_searchHint;

  /// Placeholder text shown in the main input field on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Enter text to translate...'**
  String get homeInputHint;

  /// Tooltip for the paste-from-clipboard icon button.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get homePasteTooltip;

  /// Tooltip for the pick-image icon button.
  ///
  /// In en, this message translates to:
  /// **'Pick image'**
  String get homePickImageTooltip;

  /// Tooltip for the upload-file icon button.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get homeUploadFileTooltip;

  /// Word count chip shown below the input field.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 words} one{1 word} other{{count} words}}'**
  String homeWordCount(int count);

  /// Primary action button label for starting a translation.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get homeTranslateButton;

  /// Clear-input secondary button label.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get homeClearButton;

  /// Tooltip for the share-translation icon button.
  ///
  /// In en, this message translates to:
  /// **'Share translation'**
  String get homeShareTooltip;

  /// Body text attached when the translation result is shared.
  ///
  /// In en, this message translates to:
  /// **'Translation result'**
  String get homeShareText;

  /// Subject line used when the translation result is shared.
  ///
  /// In en, this message translates to:
  /// **'Jusoor Result'**
  String get homeShareSubject;

  /// Header shown above the translated output area.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get homeOutputTitle;

  /// Tooltip for the copy-translation icon button.
  ///
  /// In en, this message translates to:
  /// **'Copy translation'**
  String get homeCopyTooltip;

  /// Snackbar message shown after copying the translation.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get homeCopiedToClipboard;

  /// Subtitle line shown under the translation output, naming the model and duration.
  ///
  /// In en, this message translates to:
  /// **'Model: {model} · {seconds}s'**
  String homeModelInfo(String model, int seconds);

  /// Title of the dialog shown when input exceeds the configured word limit.
  ///
  /// In en, this message translates to:
  /// **'Word Limit Exceeded'**
  String get homeWordLimitTitle;

  /// Body of the word-limit dialog, asking the user to confirm proceeding.
  ///
  /// In en, this message translates to:
  /// **'Your text has {count} words, which exceeds the limit of {limit} words. Do you want to proceed anyway?'**
  String homeWordLimitBody(int count, int limit);

  /// Snackbar message when shared content cannot be parsed.
  ///
  /// In en, this message translates to:
  /// **'Could not read shared content.'**
  String get homeErrorSharedContent;

  /// Snackbar message when a picked file has no readable bytes.
  ///
  /// In en, this message translates to:
  /// **'Could not read file bytes.'**
  String get homeErrorFileBytes;

  /// Snackbar message warning the user that a large file will be split into chunks.
  ///
  /// In en, this message translates to:
  /// **'File will be translated in chunks'**
  String get homeFileWillBeChunked;

  /// Title of the settings screen and its AppBar.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings list-tile label that opens the API Keys screen.
  ///
  /// In en, this message translates to:
  /// **'API Keys'**
  String get settingsApiKeys;

  /// Settings list-tile label that opens the Provider Profiles screen.
  ///
  /// In en, this message translates to:
  /// **'Provider Profiles'**
  String get settingsProviderProfiles;

  /// Settings list-tile label that opens the Templates screen.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get settingsTemplates;

  /// Settings section header for the overlay-related options.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get settingsSectionOverlay;

  /// Settings section header for general options.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// Settings section header for advanced options.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsSectionAdvanced;

  /// Label for the default target language list-tile.
  ///
  /// In en, this message translates to:
  /// **'Default Target Language'**
  String get settingsDefaultTargetLanguage;

  /// Label for the word-limit text field.
  ///
  /// In en, this message translates to:
  /// **'Word Limit'**
  String get settingsWordLimit;

  /// Hint text shown inside the word-limit text field.
  ///
  /// In en, this message translates to:
  /// **'5000'**
  String get settingsWordLimitHint;

  /// Hint text shown inside the default-target-language dropdown.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get settingsTargetLanguageHint;

  /// Label for the app-UI language list tile in Settings.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguage;

  /// Option that makes the app UI follow the device's system language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsAppLanguageSystem;

  /// Title of the bottom sheet for picking the app UI language.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguageTitle;

  /// Label for the fallback-provider-profile dropdown.
  ///
  /// In en, this message translates to:
  /// **'Fallback Profile'**
  String get settingsFallbackProfile;

  /// Dropdown option that explicitly selects no fallback profile.
  ///
  /// In en, this message translates to:
  /// **'(None)'**
  String get settingsNoneOption;

  /// Button label that re-creates any missing built-in profiles and templates.
  ///
  /// In en, this message translates to:
  /// **'Restore Built-in Items'**
  String get settingsRestoreBuiltIn;

  /// Snackbar message shown when no built-ins needed restoration.
  ///
  /// In en, this message translates to:
  /// **'All built-in items are already present.'**
  String get settingsAlreadyPresent;

  /// Snackbar message shown after restoring built-in items, with counts.
  ///
  /// In en, this message translates to:
  /// **'Restored {profiles} profile(s) and {templates} template(s).'**
  String settingsRestoredSnackbar(int profiles, int templates);

  /// Label for the overlay-template selector.
  ///
  /// In en, this message translates to:
  /// **'Overlay Template'**
  String get settingsOverlayTemplate;

  /// Placeholder label for the overlay-template selector when nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select overlay template'**
  String get settingsSelectOverlayTemplate;

  /// Subtitle of the overlay-template picker explaining its role.
  ///
  /// In en, this message translates to:
  /// **'Used for both text and image translation in the overlay.'**
  String get settingsOverlayTemplateDescription;

  /// Subtitle shown for a template that supports both text and image translation.
  ///
  /// In en, this message translates to:
  /// **'Text & Image'**
  String get settingsOverlayTextAndImage;

  /// Subtitle shown for a template that supports text translation only.
  ///
  /// In en, this message translates to:
  /// **'Text only'**
  String get settingsOverlayTextOnly;

  /// Subtitle shown for a template that supports image translation only.
  ///
  /// In en, this message translates to:
  /// **'Image only'**
  String get settingsOverlayImageOnly;

  /// Label for the overlay-size-mode selector.
  ///
  /// In en, this message translates to:
  /// **'Size Mode'**
  String get settingsSizeMode;

  /// Title of the bottom sheet for picking the overlay size mode.
  ///
  /// In en, this message translates to:
  /// **'Overlay Size Mode'**
  String get settingsOverlaySizeModeTitle;

  /// Subtitle of the overlay-size-mode bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose how the overlay fills the screen.'**
  String get settingsOverlaySizeModeDescription;

  /// Label for the compressed overlay-size option.
  ///
  /// In en, this message translates to:
  /// **'Compressed'**
  String get settingsOverlaySizeCompressed;

  /// Label for the full overlay-size option.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get settingsOverlaySizeFull;

  /// Subtitle for the compressed overlay-size option.
  ///
  /// In en, this message translates to:
  /// **'Floating card in the center, ~75% of screen height. Dark background dims the rest.'**
  String get settingsOverlaySizeCompressedDescription;

  /// Subtitle for the full overlay-size option.
  ///
  /// In en, this message translates to:
  /// **'Fills the entire content area between status bar and navigation bar. No borders or shadow.'**
  String get settingsOverlaySizeFullDescription;

  /// Settings list-tile label that opens the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport;

  /// Settings list-tile label that opens the Permissions screen.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsPermissions;

  /// Settings list-tile label that opens the Instructions screen.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get settingsInstructions;

  /// Settings section header for the help, support, and articles entries.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsSectionHelp;

  /// Title of the articles list page and of the tile that opens it from Settings → Help & Support.
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get settingsArticles;

  /// Subtitle under the 'Articles' tile in Settings → Help & Support, describing what the page contains.
  ///
  /// In en, this message translates to:
  /// **'Quick guides & how-it-works'**
  String get settingsArticlesSubtitle;

  /// Error message shown inside the article reader screen when its Markdown fails to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load the article.'**
  String get articleLoadError;

  /// Label for the retry button shown alongside the article load error on the reader screen.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get articleRetry;

  /// Title of the Support screen and its AppBar.
  ///
  /// In en, this message translates to:
  /// **'Support Jusoor'**
  String get pagesSupportTitle;

  /// Title of the Patreon support card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Support on Patreon'**
  String get pagesPatreonTitle;

  /// Subtitle of the Patreon support card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Become a member to help fund ongoing development and unlock supporter perks.'**
  String get pagesPatreonSubtitle;

  /// Title of the GitHub support card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Star on GitHub'**
  String get pagesGithubTitle;

  /// Subtitle of the GitHub support card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Show your support by starring the project and following new releases.'**
  String get pagesGithubSubtitle;

  /// Title of the Website contact card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get pagesWebsiteTitle;

  /// Subtitle of the Website contact card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Visit digitaltrekkerr.com for more about the project.'**
  String get pagesWebsiteSubtitle;

  /// Title of the Email contact card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get pagesEmailTitle;

  /// Subtitle of the Email contact card on the Support screen.
  ///
  /// In en, this message translates to:
  /// **'support@digitaltrekkerr.com'**
  String get pagesEmailSubtitle;

  /// Snackbar message shown when an external link is being opened.
  ///
  /// In en, this message translates to:
  /// **'Opening in your browser...'**
  String get pagesOpeningLink;

  /// Snackbar message shown when a support link cannot be parsed.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get supportInvalidUrl;

  /// Title of the Permissions screen and its AppBar.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get pagesPermissionsTitle;

  /// Friendly title for the screen-capture / MediaProjection permission row.
  ///
  /// In en, this message translates to:
  /// **'Screen capture (screenshot translation)'**
  String get pagesPermissionScreenCaptureTitle;

  /// Explanation of the screen-capture / MediaProjection permission.
  ///
  /// In en, this message translates to:
  /// **'When you tap Screenshot in the overlay, Jusoor hides its own window and captures everything currently visible on the screen — including other apps — then sends that image to the translation provider you configured (e.g. OpenRouter/Gemini/OpenAI/custom) to translate the text in it. The image is not saved to your device; only the translated text is kept in History. Android shows a consent dialog before any capture, and capture stops when the overlay closes.'**
  String get pagesPermissionScreenCaptureBody;

  /// Label for the Grant button on the screen-capture permission row.
  ///
  /// In en, this message translates to:
  /// **'Try now'**
  String get pagesPermissionScreenCaptureGrant;

  /// Friendly title for the SYSTEM_ALERT_WINDOW permission row.
  ///
  /// In en, this message translates to:
  /// **'Overlay (Display over other apps)'**
  String get pagesPermissionOverlayTitle;

  /// Explanation of the SYSTEM_ALERT_WINDOW permission.
  ///
  /// In en, this message translates to:
  /// **'Jusoor draws its floating translation window on top of other apps. It opens only when you tap the Quick Settings \'Translate\' tile or the overlay button. While it is open, touches inside the shaded top area are handled by the overlay; it never runs invisibly.'**
  String get pagesPermissionOverlayBody;

  /// Label for the Grant button on the overlay permission row.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get pagesPermissionOverlayGrant;

  /// Friendly title for the POST_NOTIFICATIONS permission row.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get pagesPermissionNotificationsTitle;

  /// Explanation of the POST_NOTIFICATIONS permission.
  ///
  /// In en, this message translates to:
  /// **'Android requires a visible notification while the translation overlay service is running. This notification shows \'Translator Overlay is active\' and disappears when the overlay closes. It is only used to keep the overlay alive.'**
  String get pagesPermissionNotificationsBody;

  /// Label for the Grant button on the notifications permission row.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get pagesPermissionNotificationsGrant;

  /// Friendly title for the FOREGROUND_SERVICE permission row.
  ///
  /// In en, this message translates to:
  /// **'Background service (overlay engine)'**
  String get pagesPermissionFgsTitle;

  /// Explanation of the FOREGROUND_SERVICE permission.
  ///
  /// In en, this message translates to:
  /// **'A small background service keeps the overlay working while you use other apps. Android always shows it in the active-apps list with a notification. It starts when the overlay is opened and stops when the overlay is closed.'**
  String get pagesPermissionFgsBody;

  /// Friendly title for the INTERNET permission row.
  ///
  /// In en, this message translates to:
  /// **'Internet access'**
  String get pagesPermissionInternetTitle;

  /// Explanation of the INTERNET permission.
  ///
  /// In en, this message translates to:
  /// **'Jusoor sends the content you translate (text you type, files you share, or screenshots) over an encrypted connection to the translation provider you chose in Settings. Anyone with your API key can read what is sent to that provider — keep your keys private and be mindful of what you translate.'**
  String get pagesPermissionInternetBody;

  /// Friendly title for the clipboard access description row.
  ///
  /// In en, this message translates to:
  /// **'Clipboard (Paste in the overlay)'**
  String get pagesPermissionClipboardTitle;

  /// Explanation of how the overlay accesses the clipboard.
  ///
  /// In en, this message translates to:
  /// **'The Paste button in the overlay reads your device clipboard so you can translate text copied from other apps. On modern Android this may briefly open a transparent window once, and Jusoor keeps the text in memory for up to a minute as a fallback. Cached content auto-clears after a minute. Nothing is stored permanently.'**
  String get pagesPermissionClipboardBody;

  /// Friendly title for the share-from-other-apps description row.
  ///
  /// In en, this message translates to:
  /// **'Share from other apps'**
  String get pagesPermissionShareTitle;

  /// Explanation of the share intent entry point.
  ///
  /// In en, this message translates to:
  /// **'Any app can open Jusoor through the system Share menu to translate text, links or files. Shared content is uploaded to the translation provider for processing. This is how quick-translate works and cannot be disabled without losing the feature.'**
  String get pagesPermissionShareBody;

  /// Friendly title for the Quick Settings Tile description row.
  ///
  /// In en, this message translates to:
  /// **'Quick Settings \'Translate\' tile'**
  String get pagesPermissionQuickSettingsTitle;

  /// Explanation of the Quick Settings Tile feature.
  ///
  /// In en, this message translates to:
  /// **'Jusoor adds a tile to your Quick Settings (Android 7+) that opens the overlay directly. Requires the overlay permission to be enabled.'**
  String get pagesPermissionQuickSettingsBody;

  /// Friendly title for the file-import description row.
  ///
  /// In en, this message translates to:
  /// **'Importing files'**
  String get pagesPermissionFilesTitle;

  /// Explanation of how file import works and its privacy implications.
  ///
  /// In en, this message translates to:
  /// **'Files are imported through the system file picker — you choose each file, and Jusoor never scans your storage. The chosen file\'s text is uploaded to the translation provider for translation.'**
  String get pagesPermissionFilesBody;

  /// Status label shown for install-time permissions that cannot be revoked at runtime.
  ///
  /// In en, this message translates to:
  /// **'Granted at install'**
  String get pagesGrantedAtInstall;

  /// Status label shown when a runtime permission is currently granted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get pagesPermissionStatusGranted;

  /// Status label shown when a runtime permission is denied or has not been requested.
  ///
  /// In en, this message translates to:
  /// **'Not granted'**
  String get pagesPermissionStatusDenied;

  /// Status label shown when a runtime permission is permanently denied.
  ///
  /// In en, this message translates to:
  /// **'Permanently denied — open Settings'**
  String get pagesPermissionStatusPermanent;

  /// Status label for non-grantable, informational permission rows.
  ///
  /// In en, this message translates to:
  /// **'Always on'**
  String get pagesPermissionStatusInformational;

  /// Label for the fallback button that opens the system app settings page.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get pagesPermissionOpenSettings;

  /// Hint shown beneath the Grant button as a fallback instruction.
  ///
  /// In en, this message translates to:
  /// **'If the system dialog does not appear, open Android Settings → Apps → Jusoor → Permissions.'**
  String get pagesPermissionSettingsHint;

  /// Title of the Instructions screen and its AppBar.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get pagesInstructionsTitle;

  /// Section header for the app-usage instructions.
  ///
  /// In en, this message translates to:
  /// **'How to use the app'**
  String get pagesHowToUseHeader;

  /// Step 1 of the how-to-use instructions.
  ///
  /// In en, this message translates to:
  /// **'Open Jusoor and pick a source text or image template from the top of the Home screen.'**
  String get pagesHowToUseStep1;

  /// Step 2 of the how-to-use instructions.
  ///
  /// In en, this message translates to:
  /// **'Choose your target language, then type or paste text (or pick an image) in the input area.'**
  String get pagesHowToUseStep2;

  /// Step 3 of the how-to-use instructions.
  ///
  /// In en, this message translates to:
  /// **'Tap Translate to see the result below. You can copy, share, or open it in the full output view.'**
  String get pagesHowToUseStep3;

  /// Step 4 of the how-to-use instructions.
  ///
  /// In en, this message translates to:
  /// **'To translate from another app, use the system Share menu and pick Jusoor — text, links, and images are supported.'**
  String get pagesHowToUseStep4;

  /// Step 5 of the how-to-use instructions.
  ///
  /// In en, this message translates to:
  /// **'For a floating translator on top of any app, add the Quick Settings \'Translate\' tile and tap it to open the overlay.'**
  String get pagesHowToUseStep5;

  /// Section header for prompt-writing tips.
  ///
  /// In en, this message translates to:
  /// **'How to write good prompts'**
  String get pagesHowToWritePromptsHeader;

  /// Tip 1 for writing good translation prompts.
  ///
  /// In en, this message translates to:
  /// **'State the desired tone and register (formal, casual, technical, marketing, etc.) so the model matches your audience.'**
  String get pagesHowToWritePromptsTip1;

  /// Tip 2 for writing good translation prompts.
  ///
  /// In en, this message translates to:
  /// **'Mention the domain (medical, legal, software, gaming) so the model uses the right vocabulary and conventions.'**
  String get pagesHowToWritePromptsTip2;

  /// Tip 3 for writing good translation prompts.
  ///
  /// In en, this message translates to:
  /// **'List any terms, brand names, or product names that must be kept untranslated.'**
  String get pagesHowToWritePromptsTip3;

  /// Tip 4 for writing good translation prompts.
  ///
  /// In en, this message translates to:
  /// **'Tell the model what to do with ambiguity: prefer literal, prefer natural, ask for clarification, or pick the most common reading.'**
  String get pagesHowToWritePromptsTip4;

  /// Tip 5 for writing good translation prompts.
  ///
  /// In en, this message translates to:
  /// **'Specify the output format you want: plain text, markdown, JSON, or line-by-line preserving the source structure.'**
  String get pagesHowToWritePromptsTip5;

  /// Tip 6 for writing good translation prompts.
  ///
  /// In en, this message translates to:
  /// **'Include short examples of the style you want — one or two before/after pairs are usually more effective than a long rule list.'**
  String get pagesHowToWritePromptsTip6;

  /// AppBar title of the template editor when creating a template.
  ///
  /// In en, this message translates to:
  /// **'New Template'**
  String get tplEditNewTitle;

  /// AppBar title of the template editor when editing an existing template.
  ///
  /// In en, this message translates to:
  /// **'Edit Template'**
  String get tplEditExistingTitle;

  /// Label of the template-name text field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tplEditNameLabel;

  /// Hint text of the template-name text field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Professional Translator'**
  String get tplEditNameHint;

  /// Label of the provider-profile dropdown in the template editor.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tplEditProfileLabel;

  /// Label of the system-prompt text field.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get tplEditSystemPromptLabel;

  /// Warning banner shown when the prompt lacks the target-language placeholder.
  ///
  /// In en, this message translates to:
  /// **'The system prompt does not contain {target_language}. Translations may not know which language to use.'**
  String tplEditWarningMissingTarget(String target_language);

  /// Button label that restores the default system prompt.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get tplEditResetToDefault;

  /// Title of the switch that enables text translation for the template.
  ///
  /// In en, this message translates to:
  /// **'Supports Text'**
  String get tplEditSupportsText;

  /// Subtitle of the supports-text switch.
  ///
  /// In en, this message translates to:
  /// **'This template can be used for text translation.'**
  String get tplEditSupportsTextSubtitle;

  /// Title of the switch that enables image translation for the template.
  ///
  /// In en, this message translates to:
  /// **'Supports Image'**
  String get tplEditSupportsImage;

  /// Subtitle of the supports-image switch.
  ///
  /// In en, this message translates to:
  /// **'This template can be used for image/vision translation.'**
  String get tplEditSupportsImageSubtitle;

  /// Title of the switch that controls automatic substitution of the target language into the prompt.
  ///
  /// In en, this message translates to:
  /// **'Auto-substitute target language'**
  String get tplSubTitle;

  /// Subtitle of the substitute-target-language switch.
  ///
  /// In en, this message translates to:
  /// **'Replace the {target_language} placeholder in the prompt with the chosen language before sending.'**
  String tplSubSubtitle(String target_language);

  /// Label of the floating save button in the template editor.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tplEditSaveButton;

  /// Snackbar error when saving a template without a name.
  ///
  /// In en, this message translates to:
  /// **'Template name is required.'**
  String get tplEditErrorNameRequired;

  /// Snackbar error when saving a template without a provider profile.
  ///
  /// In en, this message translates to:
  /// **'Please select a profile.'**
  String get tplEditErrorProfileRequired;

  /// Snackbar error when saving a template without a system prompt.
  ///
  /// In en, this message translates to:
  /// **'System prompt is required.'**
  String get tplEditErrorPromptRequired;

  /// Snackbar error when saving a template with both capabilities disabled.
  ///
  /// In en, this message translates to:
  /// **'Enable at least one capability (Text or Image).'**
  String get tplEditErrorCapabilityRequired;

  /// Label for the theme-mode selector (system / light / dark) in Settings.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// Theme option that follows the device's system brightness setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Theme option that forces a light color scheme regardless of system setting.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option that forces a dark color scheme regardless of system setting.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Title of the banner shown at the top of Settings when a newer GitHub release exists.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// Action button on the update-available banner that opens the GitHub release page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateAvailableAction;

  /// Subtitle of the update-available banner, naming the latest release version.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String updateAvailableSubtitle(String version);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
