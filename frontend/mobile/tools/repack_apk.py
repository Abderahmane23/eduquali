#!/usr/bin/env python3
"""Allege un APK en retirant les symboles de debogage des bibliotheques natives.

A executer apres `flutter build apk --release` tant que le NDK n'est pas
installe sur la machine : sans lui, le plugin Gradle Android ne peut pas
retirer les symboles de `libflutter.so`, et l'APK depasse 500 Mo.

Le script reconstruit l'archive, la realigne puis la resigne. La cle utilisee
est celle de debogage, la meme que celle appliquee par Gradle a la variante
`release` de ce projet ; elle devra etre remplacee par une cle de publication
avant toute mise en ligne.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from strip_elf import Elf, ElfError, verify  # noqa: E402

SDK = Path(
    os.environ.get(
        "ANDROID_SDK_ROOT",
        "C:/Users/HP/Desktop/App_Maison_Blanche/_toolchain/android-sdk",
    )
)
BUILD_TOOLS = SDK / "build-tools" / "36.0.0"
def signing_config() -> tuple[Path, str, str, str]:
    """La cle a utiliser : celle de publication si elle est declaree.

    Ce script **resigne** l'archive apres l'avoir reconstruite, donc c'est lui
    qui decide, au bout du compte, de la cle du fichier distribue. Il a longtemps
    resigne avec la cle de debogage en dur : brancher une cle de publication dans
    Gradle sans toucher a ce fichier n'aurait rien change, et l'APK serait sorti
    signe en debogage sans que rien ne le dise.

    `android/key.properties` est la meme source que celle lue par Gradle : une
    seule declaration, donc pas de divergence possible entre les deux etapes.
    """
    proprietes = Path(__file__).resolve().parent.parent / "android" / "key.properties"
    if proprietes.exists():
        valeurs: dict[str, str] = {}
        for ligne in proprietes.read_text(encoding="utf-8").splitlines():
            if "=" in ligne and not ligne.lstrip().startswith("#"):
                cle, _, valeur = ligne.partition("=")
                valeurs[cle.strip()] = valeur.strip()
        depot = Path(valeurs.get("storeFile", ""))
        if depot.exists():
            return (
                depot,
                valeurs.get("storePassword", ""),
                valeurs.get("keyAlias", ""),
                valeurs.get("keyPassword", ""),
            )
    return (Path.home() / ".android" / "debug.keystore", "android", "androiddebugkey", "android")


KEYSTORE, STORE_PASS, KEY_ALIAS, KEY_PASS = signing_config()
IS_RELEASE_KEY = KEY_ALIAS != "androiddebugkey"

# Fichiers de signature : ils sont regeneres, les conserver invaliderait l'APK.
SIGNATURE_PREFIXES = ("META-INF/MANIFEST.MF", "META-INF/CERT.", "META-INF/BNDLTOOL.")
SIGNATURE_SUFFIXES = (".SF", ".RSA", ".DSA", ".EC")


def is_signature_entry(name: str) -> bool:
    if not name.startswith("META-INF/"):
        return False
    return name.startswith(SIGNATURE_PREFIXES) or name.endswith(SIGNATURE_SUFFIXES)


def strip_bytes(name: str, data: bytes) -> bytes:
    try:
        stripped = Elf(data).strip()
        verify(data, stripped)
    except ElfError as exc:
        print(f"    {name}: conserve tel quel ({exc})")
        return data
    return stripped


def repack(src: Path, dst: Path) -> tuple[int, int]:
    before = after = 0
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
        for item in zin.infolist():
            if is_signature_entry(item.filename):
                continue
            data = zin.read(item.filename)
            if item.filename.endswith(".so"):
                before += len(data)
                data = strip_bytes(item.filename, data)
                after += len(data)
                print(f"    {item.filename:44} {len(data) / 1048576:6.1f} Mo")
            # Le mode de compression d'origine est conserve : les .so sont
            # stockes non compresses et charges directement depuis l'APK.
            info = zipfile.ZipInfo(item.filename, date_time=item.date_time)
            info.compress_type = item.compress_type
            info.external_attr = item.external_attr
            info.create_system = item.create_system
            zout.writestr(info, data)
    return before, after


def run(cmd: list[str]) -> None:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout + result.stderr)
        raise SystemExit(f"echec: {' '.join(cmd[:2])}")


def main(argv: list[str]) -> int:
    apk = Path(argv[1] if len(argv) > 1 else
               "build/app/outputs/flutter-apk/app-release.apk")
    if not apk.exists():
        print(f"APK introuvable : {apk}", file=sys.stderr)
        return 1

    original_size = apk.stat().st_size
    work = apk.with_suffix(".repack.apk")
    aligned = apk.with_suffix(".aligned.apk")

    print(f"  Source : {apk.name} ({original_size / 1048576:.1f} Mo)")
    print("  Allegement des bibliotheques natives :")
    before, after = repack(apk, work)
    print(f"    {'symboles retires':44} {(before - after) / 1048576:6.1f} Mo")

    # Les bibliotheques non compressees doivent rester alignees sur la taille
    # de page, sans quoi Android 15 refuse de les charger directement.
    zipalign = BUILD_TOOLS / "zipalign.exe"
    print("  Realignement (pages de 16 Ko)...")
    run([str(zipalign), "-P", "16", "-f", "4", str(work), str(aligned)])

    print(
        "  Signature ("
        + ("cle de publication" if IS_RELEASE_KEY else "CLE DE DEBOGAGE")
        + ")..."
    )
    apksigner = BUILD_TOOLS / "apksigner.bat"
    run([str(apksigner), "sign",
         "--ks", str(KEYSTORE),
         "--ks-pass", f"pass:{STORE_PASS}",
         "--ks-key-alias", KEY_ALIAS,
         "--key-pass", f"pass:{KEY_PASS}",
         "--v1-signing-enabled", "true",
         "--v2-signing-enabled", "true",
         "--v3-signing-enabled", "true",
         str(aligned)])

    print("  Verification de la signature...")
    run([str(apksigner), "verify", "--print-certs", str(aligned)])

    shutil.move(str(aligned), str(apk))
    work.unlink(missing_ok=True)
    Path(str(aligned) + ".idsig").unlink(missing_ok=True)

    final = apk.stat().st_size
    print(f"\n  {apk.name} : {original_size / 1048576:.1f} Mo -> "
          f"{final / 1048576:.1f} Mo")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
