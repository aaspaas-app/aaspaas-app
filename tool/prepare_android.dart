// Run after `flutter create`: gives the generated Android project the permissions and settings Aas Paas needs.
// Usage (from the app folder): dart tool/prepare_android.dart
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln(
      'AndroidManifest.xml not found. Run flutter create first (see tool/setup_dev).',
    );
    exit(1);
  }
  var s = manifest.readAsStringSync();

  // 1. Permissions: internet for the API, coarse/fine location for "Nearest first".
  const perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
  ];
  final add = perms
      .where((p) => !s.contains(p))
      .map((p) => '    <uses-permission android:name="$p"/>\n')
      .join();
  if (add.isNotEmpty) {
    s = s.replaceFirst('<application', '$add    <application');
  }

  // 2. Android 11+ only lets an app open links, calls and WhatsApp if it declares what it wants to open.
  const intents =
      '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
      '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="http"/></intent>\n'
      '        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n';
  if (!s.contains('android:scheme="tel"')) {
    if (s.contains('<queries>')) {
      s = s.replaceFirst('<queries>', '<queries>\n$intents');
    } else {
      s = s.replaceFirst(
        '</manifest>',
        '    <queries>\n$intents    </queries>\n</manifest>',
      );
    }
  }

  // 3. Name under the icon.
  s = s.replaceFirst(
    RegExp(r'android:label="[^"]*"'),
    'android:label="Aas Paas"',
  );
  manifest.writeAsStringSync(s);

  // 4. The secure storage plugin needs Android 6 (API 23) or newer.
  for (final name in ['build.gradle.kts', 'build.gradle']) {
    final g = File('android/app/$name');
    if (g.existsSync()) {
      final t = g.readAsStringSync();
      final t2 = t.replaceAll('flutter.minSdkVersion', '23');
      if (t2 != t) {
        g.writeAsStringSync(t2);
        stdout.writeln('minSdk set to 23 in $name');
      }
    }
  }
  stdout.writeln('Android project prepared.');
}
