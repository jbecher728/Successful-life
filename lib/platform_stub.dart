class Disk {
  Future<bool> exists(String name) => throw UnsupportedError('no storage');
  Future<List<int>?> read(String name) => throw UnsupportedError('no storage');
  Future<void> write(String name, List<int> bytes) => throw UnsupportedError('no storage');
  Future<void> delete(String name) => throw UnsupportedError('no storage');
  Future<void> rename(String from, String to) => throw UnsupportedError('no storage');
}

final Disk disk = Disk();

Future<void> saveDownload(String name, List<int> bytes, String mime, String subject) => throw UnsupportedError('no export');
