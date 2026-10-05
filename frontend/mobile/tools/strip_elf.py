#!/usr/bin/env python3
"""Retire les symboles de debogage des bibliotheques natives ELF.

Flutter livre `libflutter.so` avec sa table de symboles complete (~156 Mo par
ABI) et compte sur le plugin Gradle Android pour la retirer — operation qui
exige le NDK. Lorsque le NDK n'est pas installable, ce script realise le meme
travail : il supprime les sections non allouees (`.symtab`, `.strtab`,
`.debug_*`, `.comment`), qui ne servent qu'aux outils de developpement et ne
sont jamais chargees en memoire par l'editeur de liens dynamique.

Principe de securite : les sections marquees SHF_ALLOC conservent leur decalage
d'origine dans le fichier, si bien que les en-tetes de programme (les seuls que
le chargeur Android consulte) restent valides a l'octet pres. Seules les
donnees situees au-dela du dernier segment chargeable sont supprimees.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

SHF_ALLOC = 0x2
SHT_NULL = 0
SHT_NOBITS = 8
SHT_STRTAB = 3


class ElfError(RuntimeError):
    pass


class Elf:
    def __init__(self, data: bytes) -> None:
        if len(data) < 64 or data[:4] != b"\x7fELF":
            raise ElfError("ce fichier n'est pas un objet ELF")
        self.data = data
        self.is64 = data[4] == 2
        endian = "<" if data[5] == 1 else ">"
        self.e = endian

        if self.is64:
            fmt = endian + "16sHHIQQQIHHHHHH"
        else:
            fmt = endian + "16sHHIIIIIHHHHHH"
        size = struct.calcsize(fmt)
        (
            self.ident,
            self.e_type,
            self.e_machine,
            self.e_version,
            self.e_entry,
            self.e_phoff,
            self.e_shoff,
            self.e_flags,
            self.e_ehsize,
            self.e_phentsize,
            self.e_phnum,
            self.e_shentsize,
            self.e_shnum,
            self.e_shstrndx,
        ) = struct.unpack(fmt, data[:size])
        self.ehdr_fmt = fmt
        self.ehdr_size = size

        self.phdrs = self._read_phdrs()
        self.shdrs = self._read_shdrs()

    # ---------------------------------------------------------------- lecture

    def _read_phdrs(self) -> list[dict]:
        out = []
        if self.e_phoff == 0 or self.e_phnum == 0:
            return out
        for i in range(self.e_phnum):
            off = self.e_phoff + i * self.e_phentsize
            raw = self.data[off : off + self.e_phentsize]
            if self.is64:
                (p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz,
                 p_memsz, p_align) = struct.unpack(self.e + "IIQQQQQQ", raw[:56])
            else:
                (p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz,
                 p_flags, p_align) = struct.unpack(self.e + "IIIIIIII", raw[:32])
            out.append({"type": p_type, "offset": p_offset, "filesz": p_filesz})
        return out

    def _read_shdrs(self) -> list[dict]:
        out = []
        if self.e_shoff == 0 or self.e_shnum == 0:
            raise ElfError("table des sections absente")
        for i in range(self.e_shnum):
            off = self.e_shoff + i * self.e_shentsize
            raw = self.data[off : off + self.e_shentsize]
            if self.is64:
                (name, typ, flags, addr, offset, size, link, info,
                 align, entsize) = struct.unpack(self.e + "IIQQQQIIQQ", raw[:64])
            else:
                (name, typ, flags, addr, offset, size, link, info,
                 align, entsize) = struct.unpack(self.e + "IIIIIIIIII", raw[:40])
            out.append({
                "name": name, "type": typ, "flags": flags, "addr": addr,
                "offset": offset, "size": size, "link": link, "info": info,
                "align": align, "entsize": entsize, "index": i,
            })
        return out

    def section_name(self, sh: dict) -> str:
        strtab = self.shdrs[self.e_shstrndx]
        base = strtab["offset"] + sh["name"]
        end = self.data.index(b"\0", base)
        return self.data[base:end].decode("utf-8", "replace")

    # ---------------------------------------------------------------- ecriture

    def strip(self) -> bytes:
        keep: list[dict] = []
        for sh in self.shdrs:
            if sh["type"] == SHT_NULL:
                keep.append(sh)
            elif sh["flags"] & SHF_ALLOC:
                keep.append(sh)

        # Toutes les donnees referencees par un segment doivent survivre.
        data_end = 0
        for ph in self.phdrs:
            data_end = max(data_end, ph["offset"] + ph["filesz"])
        for sh in keep:
            if sh["type"] != SHT_NOBITS:
                data_end = max(data_end, sh["offset"] + sh["size"])

        if data_end > len(self.data):
            raise ElfError("en-tetes incoherents : donnees hors du fichier")

        body = bytearray(self.data[:data_end])

        # Nouvelle table de chaines, limitee aux sections conservees.
        names = bytearray(b"\0")
        name_offsets: dict[int, int] = {}
        for sh in keep:
            if sh["type"] == SHT_NULL:
                name_offsets[sh["index"]] = 0
                continue
            label = self.section_name(sh).encode()
            name_offsets[sh["index"]] = len(names)
            names += label + b"\0"
        shstrtab_name_off = len(names)
        names += b".shstrtab\0"

        while len(body) % 8:
            body.append(0)
        shstrtab_offset = len(body)
        body += names

        while len(body) % 8:
            body.append(0)
        shoff = len(body)

        # Correspondance ancien index -> nouvel index, pour sh_link/sh_info.
        remap = {sh["index"]: i for i, sh in enumerate(keep)}
        shstrtab_index = len(keep)

        entries = []
        for sh in keep:
            link = remap.get(sh["link"], 0)
            info = sh["info"] if sh["type"] not in (2, 11) else remap.get(sh["info"], sh["info"])
            entries.append({
                **sh,
                "name": name_offsets[sh["index"]],
                "link": link,
                "info": info,
            })
        entries.append({
            "name": shstrtab_name_off, "type": SHT_STRTAB, "flags": 0,
            "addr": 0, "offset": shstrtab_offset, "size": len(names),
            "link": 0, "info": 0, "align": 1, "entsize": 0,
        })

        for sh in entries:
            if self.is64:
                body += struct.pack(
                    self.e + "IIQQQQIIQQ", sh["name"], sh["type"], sh["flags"],
                    sh["addr"], sh["offset"], sh["size"], sh["link"],
                    sh["info"], sh["align"], sh["entsize"])
            else:
                body += struct.pack(
                    self.e + "IIIIIIIIII", sh["name"], sh["type"], sh["flags"],
                    sh["addr"], sh["offset"], sh["size"], sh["link"],
                    sh["info"], sh["align"], sh["entsize"])

        header = struct.pack(
            self.ehdr_fmt, self.ident, self.e_type, self.e_machine,
            self.e_version, self.e_entry, self.e_phoff, shoff, self.e_flags,
            self.e_ehsize, self.e_phentsize, self.e_phnum, self.e_shentsize,
            len(entries), shstrtab_index)
        body[: self.ehdr_size] = header
        return bytes(body)


def verify(original: bytes, stripped: bytes) -> None:
    """Controle que le chargeur retrouvera exactement les memes octets."""
    src, dst = Elf(original), Elf(stripped)

    # Seules les references a la table des sections ont le droit de changer :
    # le chargeur dynamique ne les consulte jamais.
    for field in ("ident", "e_type", "e_machine", "e_version", "e_entry",
                  "e_phoff", "e_flags", "e_ehsize", "e_phentsize", "e_phnum",
                  "e_shentsize"):
        if getattr(src, field) != getattr(dst, field):
            raise ElfError(f"en-tete ELF altere : {field}")

    for a, b in zip(src.phdrs, dst.phdrs):
        if (a["offset"], a["filesz"], a["type"]) != (b["offset"], b["filesz"], b["type"]):
            raise ElfError("segment altere")
        end = a["offset"] + a["filesz"]
        if end > len(stripped):
            raise ElfError("segment tronque")
        # L'en-tete ELF lui-meme est exclu : il vient d'etre valide champ par
        # champ ci-dessus, et il est le seul octet modifie dans un segment.
        start = max(a["offset"], src.ehdr_size)
        if end > start and original[start:end] != stripped[start:end]:
            raise ElfError("contenu de segment modifie")

    kept = {dst.section_name(s) for s in dst.shdrs if s["type"] != SHT_NULL}
    for required in (".dynsym", ".dynstr", ".text"):
        if required not in kept:
            raise ElfError(f"section indispensable perdue : {required}")
    for banned in (".symtab", ".strtab"):
        if banned in kept:
            raise ElfError(f"section de debogage conservee : {banned}")


def strip_file(path: Path) -> tuple[int, int]:
    original = path.read_bytes()
    stripped = Elf(original).strip()
    verify(original, stripped)
    path.write_bytes(stripped)
    return len(original), len(stripped)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: strip_elf.py <fichier.so> [...]", file=sys.stderr)
        return 2
    total_before = total_after = 0
    for arg in argv[1:]:
        path = Path(arg)
        try:
            before, after = strip_file(path)
        except ElfError as exc:
            print(f"  ECHEC  {path.name}: {exc}", file=sys.stderr)
            return 1
        total_before += before
        total_after += after
        print(f"  {path.name:24} {before/1048576:7.1f} Mo -> {after/1048576:6.1f} Mo")
    if total_before:
        saved = (total_before - total_after) / 1048576
        print(f"  {'TOTAL':24} {total_before/1048576:7.1f} Mo -> "
              f"{total_after/1048576:6.1f} Mo  ({saved:.1f} Mo retires)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
