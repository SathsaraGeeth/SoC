cmake_minimum_required(VERSION 3.20)
project(sys_address_generator_uvm LANGUAGES C CXX)
include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(sys_address_generator sys_address_generator_tb_top sys_address_generator_test)
