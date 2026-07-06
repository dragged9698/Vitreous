import 'package:emby_player/media/library_filter_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseItemsFilterStringList', () {
    test('accepts plain strings', () {
      expect(parseItemsFilterStringList(['Drama', 'Action']), ['Drama', 'Action']);
    });

    test('accepts NameGuidPair objects', () {
      expect(
        parseItemsFilterStringList([
          {'Name': 'Action', 'Id': 'a'},
          {'name': 'Drama', 'id': 'b'},
        ]),
        ['Action', 'Drama'],
      );
    });
  });
}
