import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 31 — Signature du contrat (§27).
///
/// La signature manuscrite est capturee puis enregistree comme image et
/// annexee au contrat. Sa portee juridique doit etre validee au regard du
/// cadre applicable.
class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final _strokes = <List<Offset>>[];
  final _canvasKey = GlobalKey();
  bool _accepted = false;
  bool _saving = false;

  bool get _hasSignature => _strokes.any((stroke) => stroke.length > 1);

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(recruitmentRoomProvider(widget.roomId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature'),
        leading: const BackButton(),
        actions: [
          if (_hasSignature)
            TextButton(
              onPressed: () => setState(_strokes.clear),
              child: const Text('Effacer'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Contrat indisponible',
          message: '$error',
        ),
        data: (room) {
          final contract = room?.contract;
          if (contract == null) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: 'Aucun contrat a signer',
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Text(
                      'Signature du contrat ${contract.reference}',
                      style: text.titleMedium,
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      'Tracez votre signature dans le cadre ci-dessous.',
                      style: text.bodyMedium,
                    ),
                    const Gap(AppSpacing.lg),

                    // Zone de capture de la signature.
                    RepaintBoundary(
                      key: _canvasKey,
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: _hasSignature
                                ? AppColors.primary
                                : AppColors.borderStrong,
                            width: _hasSignature ? 1.6 : 1,
                          ),
                        ),
                        child: GestureDetector(
                          onPanStart: (details) => setState(
                            () => _strokes.add([details.localPosition]),
                          ),
                          onPanUpdate: (details) => setState(() {
                            if (_strokes.isEmpty) {
                              _strokes.add([details.localPosition]);
                            } else {
                              _strokes.last.add(details.localPosition);
                            }
                          }),
                          child: CustomPaint(
                            painter: _SignaturePainter(_strokes),
                            size: Size.infinite,
                            child: _hasSignature
                                ? null
                                : Center(
                                    child: Text(
                                      'Signez ici',
                                      style: text.bodySmall,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const Gap(AppSpacing.xl),

                    // Consentement explicite avant apposition (§27).
                    InkWell(
                      onTap: () => setState(() => _accepted = !_accepted),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _accepted,
                            onChanged: (value) =>
                                setState(() => _accepted = value ?? false),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Je declare avoir lu l’integralite du contrat '
                                'et j’en accepte les termes.',
                                style: text.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Gap(AppSpacing.lg),
                    const InfoBanner(
                      message:
                          'Votre signature sera annexee au contrat conserve '
                          'dans l’espace de recrutement. Les coordonnées des '
                          'deux parties seront alors accessibles.',
                      tone: StatusTone.info,
                    ),
                  ],
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
                    onPressed: _hasSignature && _accepted && !_saving
                        ? () => _sign(contract.id)
                        : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Apposer ma signature'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sign(String contractId) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    setState(() => _saving = true);
    try {
      final path = await _captureSignature();
      await ref
          .read(recruitmentRepositoryProvider)
          .signContract(
            contractId: contractId,
            signer: session.role,
            signaturePath: path,
          );

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signature enregistree.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signature impossible : $error')));
    }
  }

  /// Rasterise le trace et l'enregistre en PNG dans le stockage prive.
  Future<String> _captureSignature() async {
    final boundary =
        _canvasKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        directory.path,
        'signature_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file.path;
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.strokes.length != strokes.length;
}
