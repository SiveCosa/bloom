/// Client-safe CometChat identifiers for SDK init.
/// Must match functions COMETCHAT_APP_ID / COMETCHAT_REGION (see functions/.env.example).
///
/// Override at build time:
///   flutter run --dart-define=COMETCHAT_APP_ID=... --dart-define=COMETCHAT_REGION=us
///
/// Or rely on [CometChatConfigLoader] fetching getCometChatClientConfig from Cloud Functions.
class CometChatConfig {
  static const String appId = String.fromEnvironment(
    'COMETCHAT_APP_ID',
    defaultValue: 'YOUR_APP_ID',
  );

  static const String region = String.fromEnvironment(
    'COMETCHAT_REGION',
    defaultValue: 'us',
  );

  static String? _resolvedAppId;
  static String? _resolvedRegion;

  static String get effectiveAppId => _resolvedAppId ?? appId;
  static String get effectiveRegion => _resolvedRegion ?? region;

  static bool get isConfigured =>
      effectiveAppId.isNotEmpty && effectiveAppId != 'YOUR_APP_ID';

  static void applyResolved({required String appId, required String region}) {
    _resolvedAppId = appId;
    _resolvedRegion = region;
  }

  static void clearResolved() {
    _resolvedAppId = null;
    _resolvedRegion = null;
  }
}