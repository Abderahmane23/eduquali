#!/usr/bin/env bash
# Rend les captures de l'application pour la presentation.
#
# Le menage prealable n'est pas une precaution de style : `flutter test`
# recopie `sqlite3.dll` dans `build/native_assets` a chaque lancement, et un
# `flutter_tester` resté en vie du run precedent tient le fichier ouvert.
# Windows refuse alors la suppression, et l'outil s'arrete sur un rapport de
# plantage qui n'a rien a voir avec le test.
set -e
taskkill //F //IM flutter_tester.exe >/dev/null 2>&1 || true
rm -rf build/native_assets 2>/dev/null || true
PATH="/c/src/flutter/bin:$PATH" flutter test test/captures_test.dart "$@"
