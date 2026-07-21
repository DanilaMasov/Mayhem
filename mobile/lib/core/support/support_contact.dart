enum SupportContactKind { email, web }

typedef SupportContactOpener = Future<bool> Function(Uri uri);

final class SupportContact {
  const SupportContact._({required this.uri, required this.kind});

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  final Uri uri;
  final SupportContactKind kind;

  String get displayValue => switch (kind) {
    SupportContactKind.email => uri.path,
    SupportContactKind.web => uri.host,
  };

  static SupportContact? resolve(String configured) {
    final value = configured.trim();
    if (value.isEmpty) return null;

    if (_emailPattern.hasMatch(value)) {
      return SupportContact._(
        uri: Uri(scheme: 'mailto', path: value),
        kind: SupportContactKind.email,
      );
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != uri.scheme) return null;
    return switch (uri.scheme) {
      'https'
          when uri.hasAuthority &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty =>
        SupportContact._(uri: uri, kind: SupportContactKind.web),
      'mailto'
          when !uri.hasAuthority &&
              uri.query.isEmpty &&
              uri.fragment.isEmpty &&
              _emailPattern.hasMatch(uri.path) =>
        SupportContact._(uri: uri, kind: SupportContactKind.email),
      _ => null,
    };
  }
}
