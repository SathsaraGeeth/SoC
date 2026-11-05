#!/usr/bin/env python3

# runs a manifest suite and 
# writes logs, JUnit, status reports

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import traceback
import xml.etree.ElementTree as ET


REGRESSIONS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = REGRESSIONS_DIR.parent
MANIFEST = REGRESSIONS_DIR / "suites.json"


def result_directory(suite_id: str) -> Path:
    """Return the workspace-local result directory used by Jenkins or a developer."""
    base = Path(
        os.environ.get(
            "CI_WORKSPACE_RESULTS_DIR",
            str(REGRESSIONS_DIR / "results" / "local" / "latest"),
        )
    )
    if not base.is_absolute():
        base = REPO_ROOT / base
    return base / "suites" / suite_id


def load_suite(suite_id: str) -> dict:
    document = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1:
        raise ValueError("unsupported suites.json schema_version")

    matches = [suite for suite in document.get("suites", []) if suite.get("id") == suite_id]
    if len(matches) != 1:
        raise ValueError(f"expected exactly one suite named {suite_id!r}, found {len(matches)}")

    suite = matches[0]
    command = suite.get("command")
    if not isinstance(command, list) or not command or not all(
        isinstance(item, str) and item for item in command
    ):
        raise ValueError(f"suite {suite_id!r} must define a non-empty string command array")
    return suite


def write_junit(
    result_dir: Path,
    suite: dict,
    elapsed: float,
    return_code: int,
    error: str | None = None,
) -> None:
    testsuite = ET.Element(
        "testsuite",
        {
            "name": str(suite.get("id", "manifest-error")),
            "tests": "1",
            "failures": "1" if return_code else "0",
            "errors": "0",
            "time": f"{elapsed:.3f}",
        },
    )
    testcase = ET.SubElement(
        testsuite,
        "testcase",
        {
            "classname": "dmctp.regressions",
            "name": str(suite.get("id", "manifest-error")),
            "time": f"{elapsed:.3f}",
        },
    )
    if return_code:
        failure = ET.SubElement(
            testcase,
            "failure",
            {
                "message": error or f"command exited with status {return_code}",
                "type": "RegressionFailure",
            },
        )
        failure.text = error or f"See {result_dir / 'console.log'}"

    tree = ET.ElementTree(testsuite)
    ET.indent(tree, space="  ")
    tree.write(result_dir / "junit.xml", encoding="utf-8", xml_declaration=True)


def write_status(
    result_dir: Path,
    suite: dict,
    elapsed: float,
    return_code: int,
    command: list[str] | None,
) -> None:
    status = {
        "suite": suite.get("id", "manifest-error"),
        "description": suite.get("description", ""),
        "tier": suite.get("tier", os.environ.get("CI_TIER", "unknown")),
        "status": "PASS" if return_code == 0 else "FAIL",
        "exit_code": return_code,
        "duration_seconds": round(elapsed, 3),
        "command": command or [],
    }
    (result_dir / "status.json").write_text(
        json.dumps(status, indent=2) + "\n", encoding="utf-8"
    )


def refresh_summary(build_dir: Path) -> None:
    """Create a human-readable build index, safely across parallel suites."""
    build_dir.mkdir(parents=True, exist_ok=True)
    with (build_dir / ".summary.lock").open("w", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        statuses = []
        for path in sorted((build_dir / "suites").glob("*/status.json")):
            try:
                statuses.append(json.loads(path.read_text(encoding="utf-8")))
            except (OSError, json.JSONDecodeError):
                continue

        passed = sum(item["status"] == "PASS" for item in statuses)
        failed = len(statuses) - passed
        lines = [
            "# DMCTP CI results",
            "",
            f"- Job: `{os.environ.get('JOB_NAME', 'local')}`",
            f"- Build: `{os.environ.get('BUILD_NUMBER', 'local')}`",
            f"- Tier: `{os.environ.get('CI_TIER', 'local')}`",
            f"- Completed suites: **{len(statuses)}** ({passed} passed, {failed} failed)",
            "",
            "| Status | Suite | Duration | What it checks |",
            "|---|---|---:|---|",
        ]
        for item in statuses:
            suite_id = item["suite"]
            lines.append(
                f"| **{item['status']}** | "
                f"[{suite_id}](suites/{suite_id}/console.log) | "
                f"{item['duration_seconds']:.1f}s | {item['description']} |"
            )
        temporary = build_dir / f".SUMMARY-{os.getpid()}.md"
        temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
        os.replace(temporary, build_dir / "SUMMARY.md")


def publish_readable_copy(result_dir: Path, suite_id: str) -> None:
    """Mirror Jenkins results outside its disposable @suite workspaces."""
    shared = os.environ.get("CI_SHARED_BUILD_DIR")
    if not shared:
        return

    build_dir = Path(shared)
    destination = build_dir / "suites" / suite_id
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(result_dir, destination, dirs_exist_ok=True)
    refresh_summary(build_dir)

    # Updating this link is idempotent; parallel suites all point it at this build.
    latest = build_dir.parent / "latest"
    temporary = build_dir.parent / f".latest-{os.getpid()}"
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(build_dir.name)
    os.replace(temporary, latest)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} SUITE_ID", file=sys.stderr)
        return 2

    suite_id = argv[1]
    result_dir = result_directory(suite_id)
    result_dir.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    suite: dict = {"id": suite_id}
    command: list[str] | None = None
    return_code = 1
    error = None

    try:
        suite = load_suite(suite_id)
        command = suite["command"]
        env = os.environ.copy()
        env.update({str(key): str(value) for key, value in suite.get("environment", {}).items()})

        print(f"[{suite_id}] {suite.get('description', '')}", flush=True)
        print(f"[{suite_id}] command: {command!r}", flush=True)
        with (result_dir / "console.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                command,
                cwd=REPO_ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
            assert process.stdout is not None
            for line in process.stdout:
                sys.stdout.write(line)
                sys.stdout.flush()
                log.write(line)
                log.flush()
            return_code = process.wait()
    except Exception:
        error = traceback.format_exc()
        print(error, file=sys.stderr)
        (result_dir / "console.log").write_text(error, encoding="utf-8")
    finally:
        elapsed = time.monotonic() - started
        write_junit(result_dir, suite, elapsed, return_code, error)
        write_status(result_dir, suite, elapsed, return_code, command)
        refresh_summary(result_dir.parents[1])
        publish_readable_copy(result_dir, suite_id)

    print(f"[{suite_id}] finished in {elapsed:.1f}s with status {return_code}", flush=True)
    return return_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
