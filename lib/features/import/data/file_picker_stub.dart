import 'picked_file.dart';

/// Fora do navegador não há escolha de arquivo (importação só na Web, RN046).
bool get canPickFiles => false;

Future<PickedFile?> pickCsvFile() async =>
    throw UnsupportedError('Escolha de arquivo só existe na Web.');
