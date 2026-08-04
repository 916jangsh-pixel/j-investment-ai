import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/trade_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TradeDatabase.instance.database;
  runApp(const JInvestmentApp());
}
