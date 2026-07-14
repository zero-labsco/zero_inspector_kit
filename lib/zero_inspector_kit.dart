export 'src/ui/floating_button.dart';
export 'src/ui/inspector_panel.dart';
export 'src/ui/network_viewer.dart';
export 'src/ui/log_viewer.dart';
export 'src/ui/database_viewer.dart';
export 'src/ui/route_viewer.dart';

export 'src/services/inspector_service.dart';
export 'src/services/database_service.dart';
export 'src/services/database_provider.dart';
export 'src/services/sqlite_provider.dart';

export 'src/interceptors/log_interceptor.dart';
export 'src/interceptors/route_observer.dart';
export 'src/interceptors/dio_interceptor.dart';
export 'src/interceptors/http_interceptor.dart';

export 'src/models/network_request.dart';
export 'src/models/log_entry.dart';
export 'src/models/route_entry.dart';
export 'src/models/database_info.dart';

export 'src/platform/platform_channel.dart';

import 'src/platform/platform_channel.dart';

class ZeroInspectorKit {
  Future<String?> getPlatformVersion() {
    return PlatformChannel.getPlatformVersion();
  }
}