cmake_minimum_required(VERSION 3.20)
project(regfile_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(regfile regfile_tb_top regfile_test)

