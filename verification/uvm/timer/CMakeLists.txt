cmake_minimum_required(VERSION 3.20)
project(timer_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(timer timer_tb_top timer_test)

