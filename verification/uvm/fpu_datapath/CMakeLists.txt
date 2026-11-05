cmake_minimum_required(VERSION 3.20)
project(fpu_datapath_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(fpu_datapath fpu_datapath_tb_top fpu_datapath_test)
