import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
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
      child: ListView(
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: FamColors.danger)),
            const SizedBox(height: 12),
          ],
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FamField(label: 'Name', controller: _name),
                const SizedBox(height: 12),
                const Text('Type', style: TextStyle(fontWeight: FontWeight.w600, color: FamColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: _types
                      .map((t) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _type == t
                                  ? FilledButton(onPressed: () => setState(() => _type = t), child: Text(t.replaceAll('_', ' ')))
                                  : OutlinedButton(onPressed: () => setState(() => _type = t), child: Text(t.replaceAll('_', ' '))),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                FamField(label: 'Address line', controller: _addressLine),
                const SizedBox(height: 12),
                FamField(label: 'Sub-city', controller: _subCity),
                const SizedBox(height: 12),
                FamField(label: 'City', controller: _city),
                const SizedBox(height: 12),
                FamField(label: 'Floors', controller: _floors, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                FamField(label: 'Notes', controller: _notes, maxLines: 3),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _submit, child: const Text('Create property')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
