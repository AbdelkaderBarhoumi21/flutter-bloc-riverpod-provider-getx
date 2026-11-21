/// Thrown by the remote data source when the server answers with an error
/// or cannot be reached.
class ServerException implements Exception {}

/// Thrown by the local data source when nothing is cached yet.
class CacheException implements Exception {}
  