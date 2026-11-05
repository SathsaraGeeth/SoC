# Since the simulator wont exit
# it is own this make act as a
# non zero returning program on
# error

import importlib.util
import io
from pathlib import Path
from unittest import mock
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "simulator_matrix.py"
SPEC = importlib.util.spec_from_file_location("simulator_matrix", MODULE_PATH)
simulator_matrix = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(simulator_matrix)


class SimulatorMatrixTests(unittest.TestCase):
    def test_detects_normal_userspace_prompt(self):
        output = "DMCTP userspace init\nDMCTP shell\n\ndmctp$ "
        self.assertTrue(simulator_matrix.shell_prompt_seen(output))

    def test_does_not_accept_boot_output_without_shell_prompt(self):
        output = "[INIT] entering U-mode\nDMCTP userspace init\n"
        self.assertFalse(simulator_matrix.shell_prompt_seen(output))

    def test_boot_completes_on_shell_banner_without_buffered_prompt(self):
        output = "[INIT] entering U-mode\nDMCTP userspace init\nDMCTP shell\n"
        self.assertTrue(simulator_matrix.boot_complete("boot", output))

    def test_usertests_do_not_complete_at_shell_banner(self):
        self.assertFalse(simulator_matrix.boot_complete("usertests", "DMCTP shell\n"))

    def test_shell_commands_are_sent_one_byte_at_a_time(self):
        stream = io.BytesIO()
        with mock.patch.object(simulator_matrix.time, "sleep") as sleep:
            simulator_matrix.send_shell_command(stream, "run /bin/test.elf")
        self.assertEqual(stream.getvalue(), b"run /bin/test.elf\n")
        self.assertEqual(sleep.call_count, len(stream.getvalue()))

    def test_no_sys_array_excludes_both_accelerator_tests(self):
        excluded = simulator_matrix.excluded_usertests(0, simulator_matrix.SYSARR_MAC_INT8)
        self.assertIn("test_sys_dense", excluded)
        self.assertIn("test_sys_fp8", excluded)

    def test_int8_only_array_excludes_fp8_test(self):
        excluded = simulator_matrix.excluded_usertests(1, simulator_matrix.SYSARR_MAC_INT8)
        self.assertNotIn("test_sys_dense", excluded)
        self.assertIn("test_sys_fp8", excluded)

    def test_fp8_only_array_excludes_int8_test(self):
        excluded = simulator_matrix.excluded_usertests(1, simulator_matrix.SYSARR_MAC_FP8)
        self.assertIn("test_sys_dense", excluded)
        self.assertNotIn("test_sys_fp8", excluded)

    def test_runtime_array_runs_both_accelerator_tests(self):
        excluded = simulator_matrix.excluded_usertests(1, simulator_matrix.SYSARR_MAC_RUNTIME)
        self.assertNotIn("test_sys_dense", excluded)
        self.assertNotIn("test_sys_fp8", excluded)

    def test_truth_int_requires_requested_setting(self):
        self.assertEqual(simulator_matrix.truth_int("sys_array_mac_t: 2\n", "sys_array_mac_t"), 2)
        with self.assertRaisesRegex(ValueError, "missing truth setting"):
            simulator_matrix.truth_int("grid_x: 2\n", "sys_array_mac_t")


if __name__ == "__main__":
    unittest.main()
