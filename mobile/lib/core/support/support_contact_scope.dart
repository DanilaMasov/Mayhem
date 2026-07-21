import 'package:flutter/widgets.dart';

import 'support_contact.dart';

class MayhemSupportContactScope extends InheritedWidget {
  const MayhemSupportContactScope({
    super.key,
    required this.contact,
    required this.opener,
    required super.child,
  });

  final SupportContact? contact;
  final SupportContactOpener? opener;

  bool get isConfigured => contact != null && opener != null;

  static MayhemSupportContactScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MayhemSupportContactScope>();

  Future<bool> open() async {
    final currentContact = contact;
    final currentOpener = opener;
    if (currentContact == null || currentOpener == null) return false;
    return currentOpener(currentContact.uri);
  }

  @override
  bool updateShouldNotify(MayhemSupportContactScope oldWidget) =>
      oldWidget.contact?.uri != contact?.uri || oldWidget.opener != opener;
}
