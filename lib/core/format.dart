// Small text helpers shared by the screens. Plain Dart so they can be tested without Flutter.

/// 1999 -> "Rs 1,999"
String rs(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'Rs ${n < 0 ? '-' : ''}$b';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "2026-10-24" -> "24 Oct". Anything unexpected is returned unchanged.
String shortDate(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (m == null || d == null || m < 1 || m > 12) return iso;
  return '$d ${_months[m - 1]}';
}

/// 0.4 -> "400 m", 2.34 -> "2.3 km"
String distanceText(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// How long ago something was saved, for the "showing saved results" banner.
String savedAgo(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

/// The message typed into WhatsApp when someone taps a deal and the server cannot be reached.
String dealMessage(String title, int price) =>
    'Hi, I saw your deal on Aas Paas: $title at ${rs(price)}. Is it available?';
