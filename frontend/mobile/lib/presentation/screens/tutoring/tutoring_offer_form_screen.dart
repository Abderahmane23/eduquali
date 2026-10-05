import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/tutoring_repository.dart';
import '../../../domain/usecases/tutoring_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Publier une offre de cours à domicile.
///
/// La matière se choisit parmi celles que le professeur a déclarées : une
/// offre dans une matière non déclarée ne correspondrait à rien sur son profil.
class TutoringOfferFormScreen extends ConsumerStatefulWidget {
  const TutoringOfferFormScreen({super.key});

  @override
  ConsumerState<TutoringOfferFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<TutoringOfferFormScreen> {
  final _rate = TextEditingController();
  final _districts = TextEditingController();
  final _availability = TextEditingController();
  final _description = TextEditingController();

  String? _subjectId;
  final Set<String> _levelIds = {};
  TutoringMode _mode = TutoringMode.atStudent;
  String? _city;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    _districts.dispose();
    _availability.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(currentTeacherProfileProvider).valueOrNull;
    final levels = ref.watch(levelsProvider).valueOrNull ?? const [];
    final cities = ref.watch(citiesProvider).valueOrNull ?? const [];
    final subjects = [for (final c in profile?.capabilities ?? []) c.subject];

    _city ??= profile?.city;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle offre de cours')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (subjects.isEmpty)
              InfoBanner(
                title: 'Ajoutez d’abord vos matières',
                message:
                    'Une offre de cours porte sur une matière que vous '
                    'enseignez.',
                tone: StatusTone.warning,
                icon: Icons.menu_book_outlined,
              ),

            _Label('Matière', text),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in subjects)
                  ChoiceChip(
                    label: Text(s.name),
                    selected: _subjectId == s.id,
                    onSelected: (_) => setState(() => _subjectId = s.id),
                  ),
              ],
            ),

            _Label('Pour quelles classes ?', text),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final l in levels)
                  FilterChip(
                    label: Text(l.name),
                    selected: _levelIds.contains(l.id),
                    onSelected: (on) => setState(
                      () => on ? _levelIds.add(l.id) : _levelIds.remove(l.id),
                    ),
                  ),
              ],
            ),

            _Label('Où se passent les cours ?', text),
            SegmentedButton<TutoringMode>(
              segments: [
                for (final m in TutoringMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),

            _Label('Tarif', text),
            TextField(
              controller: _rate,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '50000',
                suffixText: 'GNF / heure',
              ),
            ),

            if (_mode != TutoringMode.online) ...[
              _Label('Ville', text),
              DropdownButtonFormField<String>(
                initialValue: cities.contains(_city) ? _city : null,
                items: [
                  for (final c in cities)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _city = v),
              ),
              _Label('Quartiers (facultatif)', text),
              TextField(
                controller: _districts,
                decoration: const InputDecoration(
                  hintText: 'Ratoma, Kaloum, Dixinn',
                ),
              ),
            ],

            _Label('Vos disponibilités (facultatif)', text),
            TextField(
              controller: _availability,
              decoration: const InputDecoration(
                hintText: 'Mercredi après-midi, samedi matin',
              ),
            ),

            _Label('Ce que vous proposez (facultatif)', text),
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Préparation au bac, méthode, exercices corrigés…',
              ),
            ),

            if (_error != null) ...[
              const Gap(AppSpacing.md),
              InfoBanner(
                message: _error!,
                tone: StatusTone.danger,
                icon: Icons.error_outline,
              ),
            ],
          ],
        ),
      ),
      // Colle en bas : le formulaire est long, et le bouton en etait le
      // dernier element — on ne savait qu'il existait qu'apres avoir tout
      // deroule.
      bottomNavigationBar: StickyActionBar(
        label: 'Publier mon offre',
        busy: _busy,
        note: subjects.isEmpty
            ? 'Déclarez d’abord les matières que vous enseignez'
            : null,
        onPressed: subjects.isEmpty ? null : _publish,
      ),
    );
  }

  Future<void> _publish() async {
    final teacherId = ref.read(currentTeacherIdProvider);
    final rate = int.tryParse(_rate.text);

    final missing = [
      if (_subjectId == null) 'la matière',
      if (_levelIds.isEmpty) 'au moins une classe',
      if (rate == null || rate <= 0) 'le tarif',
      if (_mode != TutoringMode.online && _city == null) 'la ville',
    ];
    if (teacherId == null || missing.isNotEmpty) {
      setState(() => _error = 'Il manque ${missing.join(', ')}.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(tutoringRepositoryProvider)
          .publishOffer(
            teacherId: teacherId,
            subjectId: _subjectId!,
            levelIds: _levelIds.toList(),
            mode: _mode,
            hourlyRate: rate!,
            city: _city ?? '',
            districts: [
              for (final d in _districts.text.split(','))
                if (d.trim().isNotEmpty) d.trim(),
            ],
            availabilityNote: _availability.text,
            description: _description.text,
          );
      refreshTutoring(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offre publiée. Les parents la voient.')),
      );
      context.pop();
    } on TutoringException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.text);

  final String label;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
    child: Text(label, style: text.titleSmall),
  );
}
