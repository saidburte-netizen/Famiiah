import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/page.dart';
import '../properties/list.dart';
import 'form.dart';

/// Global "New unit" entry point (dashboard quick action). The form asks which
/// property the unit belongs to; from a property screen we pass the id instead.
class NewUnitScreen extends ConsumerWidget {
  const NewUnitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FamPage(
      title: 'New unit',
      child: UnitForm(
        onCreated: () async => ref.invalidate(propertiesProvider),
      ),
    );
  }
}
