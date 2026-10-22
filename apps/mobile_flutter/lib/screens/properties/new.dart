import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

const _types = ['residential', 'commercial', 'mixed_use'];

class NewPropertyScreen extends ConsumerStatefulWidget {
  const NewPropertyScreen({super.key});

  @override
  ConsumerState<NewPropertyScreen> createState() => _NewPropertyScreenState();
}

class _NewPropertyScreenState extends ConsumerState<NewPropertyScreen> {
  final _name = TextEditingController();
  final _addressLine = TextEditingController();
  final _subCity = TextEditingController();
  final _city = TextEditingController();
  final _floors = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'residential';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _addressLine.dispose();
    _subCity.dispose();
    _city.dispose();
    _floors.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final orgId = ref.read(orgProvider).orgId;
    if (orgId == null) {
      setState(() => _error = 'No active organization.');
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await createProperty(orgId, {
        'name': _name.text.trim(),
        'type': _type,
        'addressLine': _addressLine.text.trim().isEmpty ? null : _addressLine.text.trim(),
        'subCity': _subCity.text.trim().isEmpty ? null : _subCity.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'floors': _floors.text.trim().isEmpty ? null : int.tryParse(_floors.text.trim()),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) context.pop();
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FamPage(
      title: 'New property',
      subtitle: 'A building or a block of shops',
      child: ListView(
        children: [
          if (_error != null) ...[
            FamNotice.error(_error!),
            const SizedBox(height: 14),
          ],
          const FamSectionHeader(title: 'Details'),
          const SizedBox(height: 10),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FamField(
                  label: 'Name',
                  hint: 'e.g. Bole Tower',
                  controller: _name,
                  prefixIcon: Icons.apartment_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type',
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FamColors.textLabel,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: _types
                      .map((t) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _type == t
                                  ? FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 44),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      onPressed: () => setState(() => _type = t),
                                      child: Text(
                                        t.replaceAll('_', ' '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 44),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      onPressed: () => setState(() => _type = t),
                                      child: Text(
                                        t.replaceAll('_', ' '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                FamField(
                  label: 'Address line',
                  hint: 'Street or landmark',
                  controller: _addressLine,
                  prefixIcon: Icons.place_outlined,
                ),
                const SizedBox(height: 14),
                FamField(label: 'Sub-city', controller: _subCity, prefixIcon: Icons.map_outlined),
                const SizedBox(height: 14),
                FamField(label: 'City', controller: _city, prefixIcon: Icons.location_city_outlined),
                const SizedBox(height: 14),
                FamField(
                  label: 'Floors',
                  controller: _floors,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.stairs_outlined,
                ),
                const SizedBox(height: 14),
                FamField(label: 'Notes', controller: _notes, maxLines: 3, prefixIcon: Icons.notes_rounded),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FamPrimaryButton(
            label: 'Create property',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
