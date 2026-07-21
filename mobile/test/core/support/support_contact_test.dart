import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/support/support_contact.dart';

void main() {
  test('accepts a plain support email and canonical mailto URI', () {
    final plain = SupportContact.resolve(' support@example.com ');
    final mailto = SupportContact.resolve('mailto:help@example.org');

    expect(plain?.kind, SupportContactKind.email);
    expect(plain?.uri, Uri.parse('mailto:support@example.com'));
    expect(plain?.displayValue, 'support@example.com');
    expect(mailto?.kind, SupportContactKind.email);
    expect(mailto?.uri, Uri.parse('mailto:help@example.org'));
  });

  test('accepts public HTTPS support pages without exposing the full URL', () {
    final contact = SupportContact.resolve(
      'https://support.example.com/mayhem?locale=ru',
    );

    expect(contact?.kind, SupportContactKind.web);
    expect(
      contact?.uri,
      Uri.parse('https://support.example.com/mayhem?locale=ru'),
    );
    expect(contact?.displayValue, 'support.example.com');
  });

  test('rejects missing, unsafe, credentialed, and malformed contacts', () {
    for (final value in [
      '',
      'support@example',
      'http://support.example.com',
      'https://user:secret@support.example.com',
      'mailto:support@example.com?body=private',
      'tel:+15550100',
      'javascript:alert(1)',
    ]) {
      expect(SupportContact.resolve(value), isNull, reason: value);
    }
  });
}
