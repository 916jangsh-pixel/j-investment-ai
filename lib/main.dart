import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/supabase_sync_service.dart';
import 'services/trade_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TradeDatabase.instance.database;
  await SupabaseSyncService.instance.initialize();

  runApp(const JInvestmentApp());
}
