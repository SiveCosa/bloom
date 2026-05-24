import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/cometchat_config.dart';

/// Loads CometChat App ID + region from Cloud Functions when dart-define is unset.
class CometChatConfigLoader {
  static Future<bool> loadFromServer() async {
    if (CometChatConfig.isConfigured &&
        CometChatConfig.appId != 'YOUR_APP_ID') {
      return true;
    }

    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'africa-south1');
      final result =
          await functions.httpsCallable('getCometChatClientConfig').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final appId = data['appId'] as String?;
      final region = data['region'] as String?;
      if (appId == null ||
          appId.isEmpty ||
          appId == 'YOUR_APP_ID' ||
          region == null ||
          region.isEmpty) {
        debugPrint('getCometChatClientConfig returned invalid config');
        return false;
      }
      CometChatConfig.applyResolved(appId: appId, region: region);
      debugPrint('CometChat config loaded from server (region: $region)');
      return true;
    } catch (e, stack) {
      debugPrint('Failed to load CometChat config: $e\n$stack');
      return false;
    }
  }
}