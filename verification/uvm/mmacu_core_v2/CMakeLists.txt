cmake_minimum_required(VERSION 3.20)
project(mmacu_core_v2_uvm LANGUAGES C CXX)
include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
execute_process(
  COMMAND ${CMAKE_COMMAND} -E env "DMCTP_BUILD_DIR=${CMAKE_BINARY_DIR}"
          python3 ${CMAKE_CURRENT_LIST_DIR}/../isa/scripts/prepare_rtl.py
  COMMAND_ERROR_IS_FATAL ANY
)
add_dsim_uvm_suite(mmacu_core_v2 mmacu_core_v2_tb_top mmacu_core_v2_test)

