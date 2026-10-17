import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/validators.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Modification des informations personnelles (§5.1, §15).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();

  String? _city;
  String? _photoPath;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_firstName, _lastName, _email, _headline, _bio]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentTeacherProfileProvider).valueOrNull;
    final cities = ref.watch(citiesProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_initialized) {
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName;
      _email.text = profile.email ?? '';
      _headline.text = profile.headline ?? '';
      _bio.text = profile.bio ?? '';
      _city = profile.city;
      _photoPath = profile.photoPath;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          ProfileAvatar(
                            firstName: _firstName.text,
                            lastName: _lastName.text,
                            photoPath: _photoPath,
                            size: 92,
                          ),
                          const Gap(AppSpacing.md),
                          TextButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _photoPath == null
                                  ? 'Ajouter une photo'
                                  : 'Changer la photo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppSpacing.xl),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstName,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Prenom',
                            ),
                            validator: (v) => Validators.name(v, 'Le prenom'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _lastName,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(labelText: 'Nom'),
                            validator: (v) => Validators.name(v, 'Le nom'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (facultatif)',
                      ),
                      validator: (v) => Validators.email(v),
                    ),
                    const Gap(AppSpacing.lg),

                    DropdownButtonFormField<String>(
                      initialValue: _city,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      items: [
                        for (final city in cities)
                          DropdownMenuItem(value: city, child: Text(city)),
                      ],
                      onChanged: (value) => setState(() => _city = value),
                      validator: (value) =>
                          value == null ? 'Selectionnez votre ville' : null,
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _headline,
                      decoration: const InputDecoration(
                        labelText: 'Titre professionnel',
                        hintText: 'Enseignant en Mathématiques',
                      ),
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _bio,
                      maxLines: 4,
                      maxLength: 400,
                      decoration: const InputDecoration(
                        labelText: 'Presentation',
                        alignLabelWithHint: true,
                        hintText:
                            'Decrivez votre parcours et vos specialites en '
                            'quelques lignes.',
                      ),
                    ),

                    const Gap(AppSpacing.md),
                    AppCard(
                      color: AppColors.surfaceMuted,
                      borderColor: AppColors.surfaceMuted,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile.phone, style: text.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  'Votre numéro n’est jamais visible avant '
                                  'recrutement.',
                                  style: text.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _saving
                    ? null
                    : () => _save(profile.teacherId, profile.userId),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enregistrer mon profil'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final captured = await ref
        .read(documentPipelineProvider)
        .pickFromGallery(DocumentType.other);
    if (captured != null && mounted) {
      setState(() => _photoPath = captured.path);
    }
  }

  Future<void> _save(String teacherId, String userId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    await ref
        .read(teacherRepositoryProvider)
        .updatePersonalInfo(
          teacherId: teacherId,
          userId: userId,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          city: _city,
          headline: _headline.text.trim().isEmpty
              ? null
              : _headline.text.trim(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          photoPath: _photoPath,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }
}
