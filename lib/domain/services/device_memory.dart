/// How much RAM this device has, to decide which AI it can run well.
abstract interface class DeviceMemory {
  /// Total physical memory in bytes, or null when it cannot be read.
  Future<int?> totalBytes();
}
