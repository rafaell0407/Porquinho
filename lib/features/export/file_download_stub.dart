/// Fora do navegador não há download de arquivo (CSV só na Web, decisão D4).
bool get canDownloadFiles => false;

void downloadTextFile(String fileName, String content, {String? mimeType}) {
  throw UnsupportedError('Download de arquivo só existe na Web.');
}
