import 'package:flutter_test/flutter_test.dart';
import 'package:emby_player/utils/json_utils.dart';

void main() {
  test('jsonStringField reads PascalCase and camelCase keys', () {
    expect(jsonStringField({'ChannelId': 'abc'}, 'ChannelId'), 'abc');
    expect(jsonStringField({'channelId': 'def'}, 'ChannelId'), 'def');
    expect(jsonStringField({'Name': 'News'}, 'Name'), 'News');
  });

  test('jsonIdsEqual ignores case, braces, and dashes', () {
    expect(jsonIdsEqual('ABCD1234EFGH5678IJKL9012MNOP3456', 'abcd1234efgh5678ijkl9012mnop3456'), isTrue);
    expect(
      jsonIdsEqual('{ABCD1234-EFGH-5678-IJKL-9012MNOP3456}', 'abcd1234efgh5678ijkl9012mnop3456'),
      isTrue,
    );
    expect(jsonIdsEqual('abc', 'xyz'), isFalse);
  });

  group('flexibleCsvStringList', () {
    test('passes a list of strings through', () {
      expect(flexibleCsvStringList(<dynamic>['en', 'sv']), ['en', 'sv']);
    });

    test('wraps a bare string in a list', () {
      expect(flexibleCsvStringList('en'), ['en']);
    });

    test('splits a CSV string', () {
      expect(flexibleCsvStringList('en,sv'), ['en', 'sv']);
    });

    test('trims parts and drops empties', () {
      expect(flexibleCsvStringList('en, sv , ,fr'), ['en', 'sv', 'fr']);
      expect(flexibleCsvStringList(','), isNull);
      expect(flexibleCsvStringList(''), isNull);
    });

    test('splits CSV inside list elements and drops non-strings', () {
      expect(flexibleCsvStringList(<dynamic>['en,sv', 'fr']), ['en', 'sv', 'fr']);
      expect(flexibleCsvStringList(<dynamic>[1, 'en']), ['en']);
    });

    test('returns null for null and empty input', () {
      expect(flexibleCsvStringList(null), isNull);
      expect(flexibleCsvStringList(<dynamic>[]), isNull);
    });
  });
}
