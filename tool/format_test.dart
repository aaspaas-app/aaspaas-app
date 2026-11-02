import 'dart:io';
import '../lib/core/format.dart';

int pass = 0, fail = 0;
void t(String n, Object? got, Object? want) {
  if (got == want) {
    pass++;
  } else {
    fail++;
    print('FAIL: $n got "$got" wanted "$want"');
  }
}

void main() {
  t('rs small', rs(999), 'Rs 999');
  t('rs thousands', rs(1200), 'Rs 1,200');
  t('rs lakh', rs(1234567), 'Rs 1,234,567');
  t('rs zero', rs(0), 'Rs 0');
  t('rs negative', rs(-4500), 'Rs -4,500');
  t('shortDate', shortDate('2026-10-24'), '24 Oct');
  t('shortDate first', shortDate('2026-01-05'), '5 Jan');
  t('shortDate bad month', shortDate('2026-13-05'), '2026-13-05');
  t('shortDate junk', shortDate('soon'), 'soon');
  t('shortDate empty', shortDate(''), '');
  t('distance metres', distanceText(0.4), '400 m');
  t('distance zero', distanceText(0), '0 m');
  t('distance km', distanceText(2.34), '2.3 km');
  t('distance exactly 1', distanceText(1), '1.0 km');
  final now = DateTime(2026, 10, 24, 12);
  t('ago now', savedAgo(now, now: now), 'just now');
  t(
    'ago min',
    savedAgo(now.subtract(const Duration(minutes: 5)), now: now),
    '5 min ago',
  );
  t(
    'ago hours',
    savedAgo(now.subtract(const Duration(hours: 3)), now: now),
    '3 h ago',
  );
  t(
    'ago days',
    savedAgo(now.subtract(const Duration(days: 2)), now: now),
    '2 d ago',
  );
  t(
    'deal message',
    dealMessage('Sugar 5Kg', 999),
    'Hi, I saw your deal on Aas Paas: Sugar 5Kg at Rs 999. Is it available?',
  );
  print('$pass passed, $fail failed');
  exit(fail == 0 ? 0 : 1);
}
