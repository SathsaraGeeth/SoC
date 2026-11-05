cmake_minimum_required(VERSION 3.20)
project(sram_bank_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(sram_bank sram_bank_tb_top sram_bank_test)

