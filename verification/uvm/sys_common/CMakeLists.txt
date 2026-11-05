cmake_minimum_required(VERSION 3.20)
project(sys_common_uvm LANGUAGES C CXX)
include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(sys_common sys_common_tb_top sys_common_test)

