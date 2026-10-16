#!/usr/bin/env python3
"""Inject compiled ESignShareFix dylib into the verified ESign 5.0.2 IPA.

Unsigned output must be re-signed before installation.
"""
import os
import pathlib
import plistlib
import shutil
import struct
import sys
import tempfile
import zipfile

MACHO_MAGIC = 0xFEEDFACF
ARM64 = 0x0100000C
LOAD_DYLIB = 0xC
SEGMENT64 = 0x19
DYLIB_ID = 0xD
NAME = "@executable_path/Frameworks/ESignShareFix.dylib"


def commands(binary):
    if len(binary) < 32:
        raise ValueError("Mach-O is too small")
    hdr = struct.unpack_from("<8I", binary)
    if hdr[0] != MACHO_MAGIC or hdr[1] != ARM64:
        raise ValueError("Expected thin arm64 Mach-O")
    ncmds, sizecmds = hdr[4:6]
    offset = 32
    result = []
    for i in range(ncmds):
        if offset + 8 > 32 + sizecmds:
            raise ValueError("Malformed load commands")
        cmd, size = struct.unpack_from("<II", binary, offset)
        if size < 8 or offset + size > 32 + sizecmds:
            raise ValueError(f"Malformed command {i}")
        result.append((offset, cmd, size))
        offset += size
    if offset != 32 + sizecmds:
        raise ValueError("Load-command size mismatch")
    return hdr, result


def name_at(binary, position):
    name_offset = struct.unpack_from("<I", binary, position + 8)[0]
    start = position + name_offset
    end = binary.find(b"\x00", start)
    if end < 0:
        raise ValueError("Unterminated dylib name")
    return binary[start:end].decode("utf-8")


def validate_dylib(binary):
    header, cmd = commands(binary)
    if header[3] != 6 or not any(c == DYLIB_ID for _, c, _ in cmd):
        raise ValueError("Input is not a loadable MH_DYLIB")


def add_load_command(original):
    binary = bytearray(original)
    header, cmds = commands(binary)
    if header[3] != 2:
        raise ValueError("Expected MH_EXECUTE main binary")
    if any(c == LOAD_DYLIB and name_at(binary, o) == NAME for o, c, _ in cmds):
        raise ValueError("Dylib already loaded")
    sections = []
    for offset, cmd, size in cmds:
        if cmd != SEGMENT64:
            continue
        nsects = struct.unpack_from("<I", binary, offset + 64)[0]
        for j in range(nsects):
            sect = offset + 72 + j * 80
            size_file = struct.unpack_from("<Q", binary, sect + 40)[0]
            fileoffset = struct.unpack_from("<I", binary, sect + 48)[0]
            if size_file and fileoffset:
                sections.append(fileoffset)
    if not sections:
        raise ValueError("No Mach-O content sections")
    path = NAME.encode() + b"\x00"
    length = (24 + len(path) + 7) & ~7
    begin = 32 + header[5]
    if begin + length > min(sections) or any(binary[begin:begin + length]):
        raise ValueError("No free space for LC_LOAD_DYLIB")
    new_cmd = struct.pack("<6I", LOAD_DYLIB, length, 24, 0, 0, 0)
    new_cmd += path
    binary[begin:begin + length] = new_cmd.ljust(length, b"\x00")
    struct.pack_into("<I", binary, 16, header[4] + 1)
    struct.pack_into("<I", binary, 20, header[5] + length)
    hdr2, cmds2 = commands(binary)
    assert any(c == LOAD_DYLIB and name_at(binary, o) == NAME for o, c, _ in cmds2)
    return bytes(binary)


def main():
    source, library, output = map(pathlib.Path, sys.argv[1:4])
    validate_dylib(library.read_bytes())
    with tempfile.TemporaryDirectory(prefix="esign_502_") as temp:
        root = pathlib.Path(temp)
        with zipfile.ZipFile(source) as z:
            for entry in z.infolist():
                dest = (root / entry.filename).resolve()
                if not dest.is_relative_to(root.resolve()):
                    raise ValueError("Unsafe zip entry")
                z.extract(entry, root)
        app = root / "Payload/ESign.app"
        info = plistlib.loads((app / "Info.plist").read_bytes())
        if (info.get("CFBundleIdentifier") != "p3.xyz.yyyue.esign" or
                info.get("CFBundleExecutable") != "ESign" or
                info.get("CFBundleShortVersionString") != "5.0.2"):
            raise ValueError("IPA version / bundle mismatch")
        exe = app / "ESign"
        exe.write_bytes(add_load_command(exe.read_bytes()))
        exe.chmod(0o755)
        frameworks = app / "Frameworks"
        frameworks.mkdir(exist_ok=True)
        target = frameworks / "ESignShareFix.dylib"
        shutil.copy2(library, target)
        target.chmod(0o755)
        shutil.rmtree(app / "_CodeSignature", ignore_errors=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=8) as z:
            for item in root.rglob("*"):
                if item.is_file():
                    z.write(item, item.relative_to(root).as_posix())
        with zipfile.ZipFile(output) as z:
            assert "Payload/ESign.app/Frameworks/ESignShareFix.dylib" in z.namelist()
            _, after = commands(z.read("Payload/ESign.app/ESign"))
            assert any(c == LOAD_DYLIB for o, c, s in after)
    print("Built unsigned IPA:", output)
    print("RE-SIGN APP AND DYLIB BEFORE INSTALLING!")


if __name__ == "__main__":
    main()
