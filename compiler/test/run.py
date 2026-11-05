#!/usr/bin/env python3
"""Regression suite driven by rtl/isa/isa.yaml."""

from __future__ import annotations

import argparse
import importlib.util
import os
import random
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import yaml


TEST_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEST_DIR.parents[1]
ISA_DIR = REPO_ROOT / "rtl" / "isa"
TOOL_DIR = Path(os.environ.get(
    "DMCTP_LLVM_BIN",
    REPO_ROOT / "compiler" / "llvm-project" / "build" / "bin",
))
LLVM_VERSION = subprocess.run(
    [str(TOOL_DIR / "llc"), "--version"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    check=False,
).stdout
EXPERIMENTAL_TARGET = "dmctpArch" in LLVM_VERSION
TARGET_TRIPLE = "dmctpArch-dmctpVendor-dmctpOS" if EXPERIMENTAL_TARGET else "riscv64"
TARGET_NAME = "dmctpArch" if EXPERIMENTAL_TARGET else "dmctp64"
TARGET_FEATURES = "+i,+m,+a,+system,+f" if EXPERIMENTAL_TARGET else "+zalrsc,+zmmul"
BUILD_DIR = TEST_DIR / "build"
CASES_DIR = TEST_DIR / "cases"
OPT_LEVELS = ("O0", "O1", "O2", "O3", "Os", "Oz")
SMOKE_C_CASES = ("integer", "constants")
SMOKE_ASM_CASES = ("integer_alu", "immediates", "branches", "system")
EXTENDED_ASM_CASES = ("integer_word", "load_store", "atomics")
if EXPERIMENTAL_TARGET:
    # The experimental backend does not yet implement all handwritten
    # assembly syntax covered by the stable dmctp64 backend.
    SMOKE_ASM_CASES = ()
    EXTENDED_ASM_CASES = ()


def tool(name: str) -> Path:
    path = TOOL_DIR / name
    if not path.is_file():
        raise RuntimeError(f"missing compiler tool: {path}")
    return path


def run(command: list[str], *, expect_failure: bool = False) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    failed = result.returncode != 0
    if failed != expect_failure:
        sys.stdout.write(result.stdout)
        expectation = "failure" if expect_failure else "success"
        raise RuntimeError(f"expected {expectation}: {' '.join(command)}")
    return result


def load_isa():
    document = yaml.safe_load((ISA_DIR / "isa.yaml").read_text(encoding="utf-8"))
    spec = importlib.util.spec_from_file_location("dmctp_isa_gen", ISA_DIR / "isa_gen.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load ISA generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    params = module.collect_decode_params(document["groups"], document["opcodes"])
    encodings = [
        (entry["mnemonic"].lower(),
         *module.instruction_mask_match(entry, document["fields"], document["formats"]))
        for entry in params
    ]
    mnemonics = {name for name, _, _ in encodings}
    for entry in params:
        mnemonics.update(alias.lower() for alias in entry.get("pseudos", []))
    return mnemonics, encodings


ALLOWED_MNEMONICS, ENCODINGS = load_isa()


def compile_c(source: Path, optimization: str, stem: str) -> tuple[Path, Path]:
    ir = BUILD_DIR / f"{stem}.{optimization}.ll"
    assembly = BUILD_DIR / f"{stem}.{optimization}.s"
    obj = BUILD_DIR / f"{stem}.{optimization}.o"
    run([
        str(tool("clang")), f"--target={TARGET_TRIPLE}",
        *([] if EXPERIMENTAL_TARGET else ["-march=rv64im_zalrsc"]),
        "-ffreestanding", "-nostdlib", "-fno-builtin", "-fno-stack-protector",
        "-fno-vectorize", "-fno-slp-vectorize",
        f"-{optimization}", "-emit-llvm", "-S", str(source), "-o", str(ir),
    ])
    common = [str(tool("llc")), f"-march={TARGET_NAME}",
              f"-mattr={TARGET_FEATURES}", str(ir)]
    run(common + ["-filetype=asm", "-o", str(assembly)])
    run(common + ["-filetype=obj", "-o", str(obj)])
    validate_assembly(assembly)
    validate_object(obj)
    return assembly, obj


def assemble(source: Path, stem: str) -> Path:
    obj = BUILD_DIR / f"{stem}.o"
    run([str(tool("llvm-mc")), f"-triple={TARGET_TRIPLE}",
         f"-mattr={TARGET_FEATURES}",
         "-filetype=obj", str(source), "-o", str(obj)])
    validate_assembly(source)
    validate_object(obj)
    return obj


def validate_assembly(path: Path) -> None:
    unknown = []
    for number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.split("#", 1)[0].strip()
        if not line or line.endswith(":") or line.startswith("."):
            continue
        mnemonic = line.split(None, 1)[0].lower()
        if mnemonic not in ALLOWED_MNEMONICS:
            unknown.append(f"{path.name}:{number}: {mnemonic}")
    if unknown:
        raise RuntimeError("assembly mnemonic is absent from isa.yaml:\n" + "\n".join(unknown))


def validate_object(path: Path) -> None:
    binary = path.with_suffix(".text.bin")
    run([str(tool("llvm-objcopy")), "--only-section=.text", "-O", "binary",
         str(path), str(binary)])
    data = binary.read_bytes()
    if not data or len(data) % 4 != 0:
        raise RuntimeError(f"invalid text section size in {path}: {len(data)}")
    for offset in range(0, len(data), 4):
        word = struct.unpack_from("<I", data, offset)[0]
        if not any((word & mask) == match for _, mask, match in ENCODINGS):
            raise RuntimeError(
                f"{path.name} contains encoding 0x{word:08x} at .text+0x{offset:x} "
                "which is absent from isa.yaml"
            )


def write_random_case(seed: int, index: int) -> Path:
    generator = random.Random((seed << 16) | index)
    constants = [generator.randrange(1, 1 << 16) for _ in range(8)]
    operators = ("+", "-", "^", "|", "&", "*")
    statements = []
    for step, constant in enumerate(constants):
        operator = operators[generator.randrange(len(operators))]
        statements.append(f"    value = (value {operator} UINT64_C({constant}));")
        statements.append(f"    value ^= UINT64_C({constants[-step - 1]});")
    source = BUILD_DIR / f"random_{index}.c"
    source.write_text(
        "#include <stdint.h>\n\n"
        f"uint64_t random_{index}(uint64_t value)\n{{\n"
        + "\n".join(statements)
        + "\n    return value;\n}\n",
        encoding="utf-8",
    )
    return source


def smoke() -> None:
    for name in SMOKE_C_CASES:
        compile_c(CASES_DIR / f"{name}.c", "O2", name)
    for name in SMOKE_ASM_CASES:
        assemble(CASES_DIR / f"{name}.s", name)

    invalid = run([str(tool("llvm-mc")), f"-triple={TARGET_TRIPLE}",
                   str(CASES_DIR / "invalid.s"), "-o", str(BUILD_DIR / "invalid.o")],
                  expect_failure=True)
    if "unrecognized instruction mnemonic" not in invalid.stdout:
        raise RuntimeError("invalid-instruction test failed for the wrong reason")


def extended(seed: int) -> None:
    for optimization in OPT_LEVELS:
        compile_c(CASES_DIR / "integer.c", optimization, "optimization")
    compile_c(CASES_DIR / "control.c", "O2", "control")
    for name in EXTENDED_ASM_CASES:
        assemble(CASES_DIR / f"{name}.s", name)

    for index in range(12):
        source = write_random_case(seed, index)
        compile_c(source, ("O0", "O2", "O3", "Os")[index % 4], f"random_{index}")

    first_asm, first_obj = compile_c(CASES_DIR / "constants.c", "O2", "determinism_a")
    second_asm, second_obj = compile_c(CASES_DIR / "constants.c", "O2", "determinism_b")
    if first_asm.read_bytes() != second_asm.read_bytes():
        raise RuntimeError("identical compiler inputs produced different assembly")
    if first_obj.read_bytes() != second_obj.read_bytes():
        raise RuntimeError("identical compiler inputs produced different objects")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--suite", choices=("smoke", "extended", "all"), default="all")
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()

    shutil.rmtree(BUILD_DIR, ignore_errors=True)
    BUILD_DIR.mkdir(parents=True)
    selected = ("smoke", "extended") if args.suite == "all" else (args.suite,)
    for name in selected:
        print(f"[compiler-test] {name}", flush=True)
        smoke() if name == "smoke" else extended(args.seed)
    print(f"[compiler-test] PASS: {', '.join(selected)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
