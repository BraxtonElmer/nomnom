import 'package:flutter_test/flutter_test.dart';
import 'support/db.dart';

void main() {
  final db = loadTestDb();

  void top(String q, String want, {String? country = 'IN'}) {
    final hits = db.search(q, country: country);
    // ignore: avoid_print
    print('$q -> ${hits.take(3).map((h) => h.name).join(' | ')}');
    expect(
      hits.take(5).map((h) => h.name.toLowerCase()).any((n) => n.contains(want)),
      isTrue,
      reason: '"$q" should surface "$want"',
    );
  }

  test('loads both tables', () => expect(db.size, greaterThan(7000)));

  test('common foods surface the right candidates', () {
    top('chicken breast roasted', 'breast');
    top('roti', 'roti');
    top('dal tadka', 'dal tadka');
    top('rice white cooked', 'rice, white');
    top('banana', 'banana');
    top('almonds', 'almonds');
    top('egg boiled', 'hard-boiled');
    top('chapati', 'roti');
    top('whole milk', 'milk');
    top('peanut butter', 'peanut butter');
    top('oats', 'oat');
    top('apple', 'apple');
  });

  test('every cuisine is found from every country', () {
    void first(String q, String country, String id) {
      final hits = db.search(q, country: country);
      expect(hits.take(3).map((h) => h.id), contains(id), reason: '"$q" from $country');
    }

    first('kung pao chicken', 'IN', 'cn-kung-pao');
    first('chilli chicken', 'IN', 'cn-chilli-chicken');
    first('butter chicken', 'GB', 'in-butter-chicken');
    first('pad thai', 'US', 'th-pad-thai');
    first('jollof rice', 'GB', 'af-jollof');
    first('salmon nigiri', 'IN', 'jp-salmon-nigiri');
    first('margherita pizza', 'IN', 'it-margherita');
    first('chicken shawarma', 'IN', 'me-shawarma');
    first('fish and chips', 'IN', 'gb-fish-chips');
    first('pho', 'AU', 'vn-pho');
  });
}
