/// Core translation functionality and API integration.
///
/// Provides translation providers, variable substitution, and response
/// extraction for multiple translation APIs.
library;

// Exceptions
export 'src/exceptions/translation_exception.dart';

// Models
export 'src/models/provider_profile.dart';
export 'src/models/provider_type.dart';
export 'src/models/prompt_template.dart';
export 'src/models/translation_request.dart';
export 'src/models/translation_result.dart';
export 'src/models/translation_provider.dart';

// Providers
export 'src/providers/openrouter_provider.dart';
export 'src/providers/gemini_provider.dart';
export 'src/providers/openai_compatible_provider.dart';
export 'src/providers/provider_factory.dart';

// Utils
export 'src/utils/variable_substitutor.dart';
export 'src/utils/response_path_extractor.dart';
export 'src/utils/word_counter.dart';
export 'src/utils/sse_parser.dart';
