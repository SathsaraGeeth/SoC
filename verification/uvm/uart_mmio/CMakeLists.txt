cmake_minimum_required(VERSION 3.20)
project(uart_mmio_uvm LANGUAGES C CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../cmake/DsimUvm.cmake)
add_dsim_uvm_suite(uart_mmio uart_mmio_tb_top uart_mmio_test)

