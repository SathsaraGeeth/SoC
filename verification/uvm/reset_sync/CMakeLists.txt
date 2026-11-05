cmake_minimum_required(VERSION 3.20)
project(reset_sync_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(reset_sync reset_sync_tb_top reset_sync_test)

