import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  test('Kuaforum QR payload strips its prefix and normalizes the code', () {
    expect(normalizeBusinessJoinCode('KUAFORUM: ab12cd '), 'AB12CD');
  });

  test('manual business code is normalized', () {
    expect(normalizeBusinessJoinCode(' ab12cd '), 'AB12CD');
  });

  test('customer upcoming appointments are sorted soonest first', () {
    final rows = <Map<String, dynamic>>[
      {'id':'later','status':'confirmed','starts_at':'2026-11-23T12:00:00Z'},
      {'id':'done','status':'completed','starts_at':'2026-11-20T12:00:00Z'},
      {'id':'soon','status':'pending','starts_at':'2026-11-22T12:00:00Z'},
      {'id':'cancelled','status':'cancelled','starts_at':'2026-11-21T12:00:00Z'},
    ];
    final result=filterCustomerAppointments(rows,'upcoming');
    expect(result.map((row)=>row['id']).toList(),['soon','later']);
  });
}
