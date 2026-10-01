import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/data/qamvio_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QamvioDatabase.instance.database;
  runApp(const QamvioApp());
}
