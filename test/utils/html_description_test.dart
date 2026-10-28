import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/html_description.dart';

void main() {
  group('cleanHtmlDescription', () {
    test('turns common HTML blocks and breaks into readable paragraphs', () {
      expect(
        cleanHtmlDescription('<p>Pierwszy<br>ciąg</p><div>Drugi</div>'),
        'Pierwszy\nciąg\n\nDrugi',
      );
    });

    test('decodes named and numeric entities', () {
      expect(
        cleanHtmlDescription('A&nbsp;&amp; B &#x1F642; &#65;'),
        'A & B 🙂 A',
      );
    });

    test('removes comments and script/style contents', () {
      expect(
        cleanHtmlDescription(
          'Opis<!-- ukryte --><script>alert(1)</script><style>.x{}</style> koniec',
        ),
        'Opis koniec',
      );
    });

    test('handles null and whitespace-only descriptions', () {
      expect(cleanHtmlDescription(null), isEmpty);
      expect(cleanHtmlDescription(' \n\t '), isEmpty);
    });
  });
}
