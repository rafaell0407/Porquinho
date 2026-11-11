@TestOn('vm')
// ignore_for_file: avoid_relative_lib_imports
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/local_database/app_database.dart';

import 'database_contract.dart';

/// Mesmo contrato do teste Web, sobre SQLite nativo em arquivo temporário.
void main() {
  late Directory dir;
  File file() => File('${dir.path}${Platform.pathSeparator}contract.db');

  setUpAll(() => dir = Directory.systemTemp.createTempSync('porquinho_db_'));
  tearDownAll(() => dir.deleteSync(recursive: true));

  runDatabaseContract(
    open: () => PorquinhoDatabase(NativeDatabase(file())),
    reset: () async {
      if (file().existsSync()) file().deleteSync();
    },
  );
}
