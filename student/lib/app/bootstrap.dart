import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import 'pragyu_app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const PragyuApp());
}
