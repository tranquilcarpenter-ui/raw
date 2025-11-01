// Development configuration - DO NOT COMMIT
// Copy this to dev_config.local.dart and set your machine's IP address
//
// To find your IP:
// - Windows: ipconfig (look for IPv4 Address)
// - Mac/Linux: ifconfig or ip addr
// - Usually starts with 192.168.x.x or 10.0.x.x

class DevConfig {
  /// Your machine's local IP address for Firebase emulators
  /// Leave as 'auto' to use defaults:
  /// - Android Emulator: 10.0.2.2
  /// - iOS Simulator: localhost
  /// - Physical Device: You MUST set this to your machine's IP
  static const String emulatorHost = 'auto';

  /// Example values (uncomment and update for physical devices):
  /// static const String emulatorHost = '192.168.0.45';
  /// static const String emulatorHost = '192.168.1.12';
}
