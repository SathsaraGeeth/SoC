# validates manifests, generated 
# file lists and reports

import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
import subprocess


MODULE_PATH = Path(__file__).resolve().parents[1] / "run_suite.py"
SPEC = importlib.util.spec_from_file_location("run_suite", MODULE_PATH)
run_suite = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(run_suite)


class RunSuiteTests(unittest.TestCase):
    def test_jenkins_uses_sparse_disposable_workspaces(self):
        jenkinsfile = (run_suite.REGRESSIONS_DIR / "Jenkinsfile").read_text(encoding="utf-8")
        self.assertIn("SparseCheckoutPaths", jenkinsfile)
        self.assertIn("!compiler/llvm-project/", jenkinsfile)
        self.assertIn("buildRevision = sh", jenkinsfile)
        self.assertIn("checkoutSparse(buildRevision)", jenkinsfile)
        self.assertGreaterEqual(jenkinsfile.count("deleteDir()"), 3)

    def test_jenkins_suite_selector_matches_smoke_manifest(self):
        selector = run_suite.REGRESSIONS_DIR / "ci" / "select_suites.py"
        result = subprocess.run(
            ["python3", str(selector), str(run_suite.MANIFEST)],
            cwd=run_suite.REGRESSIONS_DIR.parent,
            env={**os.environ, "CI_SELECT_TIER": "smoke", "CI_SELECT_SUITES": ""},
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            {line.split("\t", 1)[0] for line in result.stdout.splitlines()},
            {
                "ci-selftest",
                "truth-sync",
                "host-smoke",
                "rtl-filelists",
                "rtl-core-verilator",
                "sim-small-compile",
                "compiler-smoke",
            },
        )

    def test_manifest_ids_are_unique_and_well_formed(self):
        document = json.loads(run_suite.MANIFEST.read_text(encoding="utf-8"))
        suites = document["suites"]
        ids = [suite["id"] for suite in suites]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(all(identifier.replace("-", "").isalnum() for identifier in ids))
        self.assertTrue(
            all(suite["tier"] in {"smoke", "presubmit", "nightly", "weekly"} for suite in suites)
        )
        self.assertTrue(all(isinstance(suite["command"], list) for suite in suites))
        self.assertTrue(all(isinstance(suite["timeout_minutes"], int) for suite in suites))
        self.assertTrue(all(suite["timeout_minutes"] > 0 for suite in suites))
        self.assertTrue(all(suite["agent"] for suite in suites))

    def test_junit_failure_is_parseable(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            run_suite.write_junit(output, {"id": "example"}, 1.25, 7)
            report = ET.parse(output / "junit.xml").getroot()
            self.assertEqual(report.attrib["failures"], "1")
            self.assertIsNotNone(report.find("./testcase/failure"))

    def test_configuration_catalog_is_well_formed(self):
        path = run_suite.REGRESSIONS_DIR / "configurations.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        configurations = document["configurations"]
        ids = [config["id"] for config in configurations]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(all(config["tiers"] for config in configurations))
        self.assertTrue(
            all(set(config["tiers"]) <= {"smoke", "nightly", "weekly"} for config in configurations)
        )
        required = {
            "grid_x", "grid_y", "single_region", "cores_per_cluster",
            "threads_per_core", "mesh_coord_bits", "page_words_bits",
            "num_pages_bits", "sys_cores_per_cluster", "sys_array_mac_t",
            "sys_array_m", "sys_array_max_dense_mat_sz", "clock_freq_hz",
        }
        self.assertTrue(all(set(config["soc"]) == required for config in configurations))

    def test_lint_filelists_have_no_stale_paths(self):
        checker = run_suite.REGRESSIONS_DIR.parent / "verification/lint/scripts/check_filelists.py"
        result = subprocess.run(["python3", str(checker)], cwd=run_suite.REGRESSIONS_DIR.parent)
        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
