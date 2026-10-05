import 'package:flutter/material.dart';

import '../../controllers/onboarding_flow_controller.dart';
import 'onboarding_flow_screen.dart';

/// Inscription complète : découverte, choix du profil, puis parcours du profil.
///
/// ```
/// intro.json ─ role_select ─┬→ teacher_onboarding.json
///                           ├→ institution_onboarding.json
///                           ├→ parent_onboarding.json
///                           └→ student_onboarding.json
/// ```
///
/// Les quatre profils suivent le meme chemin depuis le 24/09. Le professeur
/// passait par une page unique, ecrite le 21/09 : elle tenait sous le pouce,
/// mais elle ne demandait ni matieres ni classes — un professeur inscrit par
/// la n'avait donc aucune offre a voir, puisque la liste des offres est
/// filtree par ses matieres. Et elle ne pouvait pas poser les questions
/// conditionnelles : les disponibilites pour cours a domicile n'existent que
/// si l'on a declare en donner.
///
/// Deux parcours enchaînés plutôt qu'un seul gros fichier : les écrans de
/// découverte sont communs aux trois profils, et une question ajoutée côté
/// enseignant n'a pas à être relue par un établissement.
///
/// Pendant exact de `Signup.tsx` côté web — les deux lisent les mêmes JSON.
class SignupFlowScreen extends StatefulWidget {
  const SignupFlowScreen({super.key, this.presetRole, this.onCompleted});

  /// Profil imposé par l'entrée utilisée : on saute alors la découverte.
  final String? presetRole;

  /// Profil retenu et réponses collectées, en fin de parcours.
  final void Function(String role, Map<String, dynamic> answers)? onCompleted;

  @override
  State<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends State<SignupFlowScreen> {
  OnboardingAudience? _audience;
  String? _role;
  Map<String, dynamic> _introAnswers = const {};

  @override
  void initState() {
    super.initState();
    if (widget.presetRole != null) {
      _role = widget.presetRole;
      _audience = OnboardingAudience.forRole(widget.presetRole);
      _introAnswers = {'role': widget.presetRole};
    }
  }

  @override
  Widget build(BuildContext context) {
    final audience = _audience;

    if (audience == null) {
      return OnboardingFlowScreen(
        audience: OnboardingAudience.intro,
        onCompleted: (answers) {
          final role = answers['role'];
          final next = OnboardingAudience.forRole(role);
          // Sans profil reconnu on ne peut pas continuer : `role_select` est
          // obligatoire, donc ce cas ne devrait pas se presenter.
          if (next == null) return;
          setState(() {
            _role = role as String;
            _introAnswers = Map<String, dynamic>.from(answers);
            _audience = next;
          });
        },
      );
    }

    return PopScope(
      // Revenir depuis le premier écran du profil ramène au choix du profil
      // plutôt que de sortir de l'inscription sans prévenir.
      canPop: widget.presetRole != null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.presetRole != null) return;
        setState(() {
          _audience = null;
          _role = null;
        });
      },
      child: OnboardingFlowScreen(
        // La clé remet le moteur a zéro sur le nouveau fichier.
        key: ValueKey(audience),
        audience: audience,
        initialAnswers: _introAnswers,
        onCompleted: (answers) => widget.onCompleted?.call(_role!, answers),
      ),
    );
  }
}
