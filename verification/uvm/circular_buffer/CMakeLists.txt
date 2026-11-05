cmake_minimum_required(VERSION 3.20)
project(circular_buffer_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(circular_buffer circular_buffer_tb_top circular_buffer_test)

