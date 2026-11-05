cmake_minimum_required(VERSION 3.20)
project(fp_iter_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(fp_iter fp_iter_tb_top fp_iter_test)
