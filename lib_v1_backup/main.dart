import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/trade_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the local database before the UI starts.
  await TradeDatabase.instance.database;

  runApp(const JInvestmentApp());
}
