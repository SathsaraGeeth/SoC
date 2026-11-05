#!/usr/bin/env python3

# This file builds, boots
# tests the SoC in approved
# configurations in 
# /mnt/fileserver/prj/dmctp/regressions/configurations.json

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time
import re


REGRESSIONS = Path(__file__).resolve().parents[1]
ROOT = REGRESSIONS.parent
TRUTH = REGRESSIONS / "truth" / "soc.yaml"
CONFIGS = REGRESSIONS / "configurations.json"
TOOLCHAIN = Path(
    os.environ.get(
        "DMCTP_TOOLCHAIN",
        os.environ.get(
            "DMCTP_LLVM_BIN",
            "/mnt/fileserver/prj/dmctp/compiler/llvm-project/build-experimental/bin",
        ),
    )
)
SHELL_PROMPTS = ("dmctp$ ", "dmctp# ")
SYSARR_MAC_INT8 = 0
SYSARR_MAC_FP8 = 1
SYSARR_MAC_RUNTIME = 2


def shell_prompt_seen(output: str) -> bool:
    return any(prompt in output for prompt in SHELL_PROMPTS)


def boot_complete(mode: str, output: str) -> bool:
    # The shell banner is newline-terminated and therefore observable even when
    # a transport layer temporarily holds the non-newline-terminated prompt.
    return mode == "boot" and "DMCTP shell" in output


def excluded_usertests(sys_cores: int, mac_type: int) -> set[str]:
    """Return tests unsupported by a configuration's accelerator hardware."""
    excluded = {"fb_demo"}
    if sys_cores <= 0:
        excluded.update(("test_sys_dense", "test_sys_fp8"))
    elif mac_type == SYSARR_MAC_INT8:
        excluded.add("test_sys_fp8")
    elif mac_type == SYSARR_MAC_FP8:
        excluded.add("test_sys_dense")
    elif mac_type != SYSARR_MAC_RUNTIME:
        raise ValueError(f"unsupported sys_array_mac_t: {mac_type}")
    return excluded


def truth_int(text: str, key: str) -> int:
    match = re.search(rf"^{re.escape(key)}:\s*(\d+)", text, re.MULTILINE)
    if match is None:
        raise ValueError(f"missing truth setting: {key}")
    return int(match.group(1))


def yaml_text(values: dict) -> str:
    return "".join(
        f"{key}: {str(value).lower() if isinstance(value, bool) else value}\n"
        for key, value in values.items()
    )


def run(command: list[str], env: dict[str, str]) -> None:
    print(f"[sim-matrix] command={command!r}", flush=True)
    subprocess.run(command, cwd=ROOT, env=env, check=True)


def send_shell_command(stream, command: str, delay_seconds: float = 0.01) -> None:
    """Pace input so the simulated UART cannot lose back-to-back characters."""
    for byte in (command + "\n").encode():
        stream.write(bytes((byte,)))
        stream.flush()
        time.sleep(delay_seconds)


def simulator(mode: str, timeout_seconds: int, commands: list[str], env: dict[str, str]) -> None:
    args = ["./verification/simulator/run"]
    if mode == "compile":
        run(args + ["--build-only"], env)
        return

    process = subprocess.Popen(
        args,
        cwd=ROOT,
        env=env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
        start_new_session=True,
    )
    assert process.stdin is not None and process.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout_seconds
    pending = list(commands)
    active_command: str | None = None
    buffer = ""
    reached_userspace = False

    try:
        while time.monotonic() < deadline:
            events = selector.select(timeout=1)
            if process.poll() is not None:
                raise RuntimeError(f"simulator exited before completion: {process.returncode}")
            for key, _ in events:
                raw = os.read(key.fileobj.fileno(), 4096)
                if not raw:
                    continue
                chunk = raw.decode("utf-8", errors="replace")
                sys.stdout.write(chunk)
                sys.stdout.flush()
                buffer = (buffer + chunk)[-8192:]
                if "[INIT] entering U-mode" in buffer:
                    reached_userspace = True
                if boot_complete(mode, buffer):
                    reached_userspace = True
                    return
                if shell_prompt_seen(buffer):
                    reached_userspace = True
                    if active_command is not None and "exited status=0" not in buffer:
                        raise RuntimeError(f"userspace test failed: {active_command}")
                    buffer = ""
                    if pending:
                        command = pending.pop(0)
                        active_command = command
                        print(f"\n[sim-matrix] shell-command={command}", flush=True)
                        send_shell_command(process.stdin, command)
                    else:
                        return
        raise TimeoutError(f"simulator did not complete within {timeout_seconds}s")
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
        if not reached_userspace and mode != "compile":
            print("[sim-matrix] userspace was not reached", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("compile", "boot", "usertests"), required=True)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--configs", nargs="+")
    group.add_argument("--tier", choices=("smoke", "nightly", "weekly"))
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=900,
        help="per-configuration timeout; must be positive",
    )
    args = parser.parse_args()
    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be positive")

    document = json.loads(CONFIGS.read_text(encoding="utf-8"))
    catalog = {item["id"]: item for item in document["configurations"]}
    if args.configs:
        selected = []
        for config_id in args.configs:
            if config_id == "current":
                selected.append({"id": "current", "soc": None})
            elif config_id in catalog:
                selected.append(catalog[config_id])
            else:
                parser.error(f"unknown configuration: {config_id}")
    else:
        selected = [item for item in catalog.values() if args.tier in item["tiers"]]

    original = TRUTH.read_text(encoding="utf-8")
    env = os.environ.copy()
    env.update(
        {
            "LLVM_BIN": str(TOOLCHAIN),
            "DMCTP_CC": str(TOOLCHAIN / "clang"),
            "DMCTP_LD": str(TOOLCHAIN / "ld.lld"),
        }
    )
    try:
        for config in selected:
            print(f"[sim-matrix] configuration={config['id']} mode={args.mode}", flush=True)
            TRUTH.write_text(original if config["soc"] is None else yaml_text(config["soc"]), encoding="utf-8")
            run(["./regressions/truth/sync.sh"], env)
            run(["make", "-C", "kernel", "clean"], env)
            run(["make", "-C", "kernel", f"-j{os.cpu_count() or 1}"], env)
            values = config["soc"]
            if values is None:
                sys_cores = truth_int(original, "sys_cores_per_cluster")
                mac_type = truth_int(original, "sys_array_mac_t")
            else:
                sys_cores = int(values["sys_cores_per_cluster"])
                mac_type = int(values["sys_array_mac_t"])
            excluded = excluded_usertests(sys_cores, mac_type)
            user_commands = [
                f"/bin/{path.stem}.elf"
                for path in sorted((ROOT / "user" / "src" / "test_dmctp").glob("*.c"))
                if path.stem not in excluded
            ]
            commands = user_commands if args.mode == "usertests" else []
            simulator(args.mode, args.timeout_seconds, commands, env)
    finally:
        TRUTH.write_text(original, encoding="utf-8")
        run(["./regressions/truth/sync.sh"], env)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
