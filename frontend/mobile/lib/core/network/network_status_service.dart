import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../constants/app_enums.dart';

/// États réseau progressifs (§42).
///
/// Le service ne considere jamais « Wi-Fi = Internet » : il distingue
/// l'absence de réseau, un réseau sans Internet, un Internet accessible et
/// un serveur applicatif reellement joignable.
class NetworkStatusService {
  NetworkStatusService({Dio? probeClient, Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity(),
      _probe =
          probeClient ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.apiBaseUrl,
              // Court expres : une sonde n'a pas a faire patienter. Si le
              // serveur met plus de trois secondes a dire bonjour, on le
              // considere injoignable et on reessaie dans 45 secondes.
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
              validateStatus: (code) => code != null && code < 500,
            ),
          );

  final Connectivity _connectivity;
  final Dio _probe;

  final _controller = StreamController<NetworkState>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicProbe;

  NetworkState _state = NetworkState.noNetwork;

  NetworkState get state => _state;
  Stream<NetworkState> get stream => _controller.stream;

  /// Met le service en route **sans attendre** la premiere mesure.
  ///
  /// La mesure demande jusqu'a neuf secondes sur un reseau lent : les
  /// attendre au demarrage laisserait l'utilisateur devant un ecran fige,
  /// pour une information dont aucun ecran n'a besoin pour s'afficher.
  void start() {
    _subscription = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(refresh());
    });
    _periodicProbe = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  /// Recalcule l'état courant en escaladant les quatre niveaux.
  Future<NetworkState> refresh() async {
    final next = await _evaluate();
    if (next != _state) {
      _state = next;
      if (!_controller.isClosed) _controller.add(next);
    }
    return next;
  }

  Future<NetworkState> _evaluate() async {
    final results = await _connectivity.checkConnectivity();
    final hasInterface =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (!hasInterface) return NetworkState.noNetwork;

    // Une interface active ne garantit pas l'acces a Internet.
    if (!await _hasInternet()) return NetworkState.networkAvailable;

    // Sans serveur configure, rien a sonder : l'application travaille en
    // local. Sonder une adresse vide ne ferait qu'attendre dans le vide.
    if (!AppConstants.hasBackend) return NetworkState.internetReachable;

    // Internet fonctionne, mais l'API peut rester indisponible.
    if (!await _hasServer()) return NetworkState.internetReachable;

    return NetworkState.serverAvailable;
  }

  Future<bool> _hasInternet() async {
    try {
      final lookup = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasServer() async {
    try {
      final response = await _probe.get<dynamic>(AppConstants.healthPath);
      return response.statusCode != null && response.statusCode! < 400;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[network] serveur injoignable: ${error.runtimeType}');
      }
      return false;
    }
  }

  Future<void> dispose() async {
    _periodicProbe?.cancel();
    await _subscription?.cancel();
    await _controller.close();
  }
}
