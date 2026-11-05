cmake_minimum_required(VERSION 3.20)
project(uart_uvm LANGUAGES C CXX)

# --------------------------------------------------
# DSim configuration
# --------------------------------------------------
set(DSIM_EXECUTABLE dsim CACHE FILEPATH "Path to DSim binary")
set(DSIM_TOP        uart_tb_top CACHE STRING "Top-level module")
# DSim 2026 incorrectly reports ANSI module ports as implicit nets when the
# DUT uses `default_nettype none. Suppress that demotable diagnostic while
# retaining the stricter directive for other simulators.
set(DSIM_FLAGS      "-suppress;DefNetNone" CACHE STRING "Extra DSim flags")
set(DSIM_FILELIST   ${CMAKE_SOURCE_DIR}/filelist.f CACHE FILEPATH ".f file")
set(DSIM_UVM_VER    1.2 CACHE STRING "UVM version")
set(DSIM_HOME       $ENV{DSIM_HOME} CACHE PATH "DSim root")
set(DSIM_LICENSE    $ENV{DSIM_LICENSE} CACHE FILEPATH "DSim license file")
set(UVM_TESTNAME    uart_test CACHE STRING "UVM test name")

# --------------------------------------------------
# Safety checks
# --------------------------------------------------
if(NOT DSIM_HOME)
  message(FATAL_ERROR "DSIM_HOME is not set.")
endif()

if(NOT EXISTS "${DSIM_FILELIST}")
  message(FATAL_ERROR "DSIM_FILELIST not found: ${DSIM_FILELIST}")
endif()

if(NOT DSIM_LICENSE AND EXISTS "$ENV{HOME}/metrics-ca/dsim-license.json")
  set(DSIM_LICENSE "$ENV{HOME}/metrics-ca/dsim-license.json")
endif()
if(NOT EXISTS "${DSIM_LICENSE}")
  message(FATAL_ERROR "DSIM_LICENSE is not set to an existing license file.")
endif()

# DSim's executable depends on the LLVM runtime shipped with DSim.  Supply it
# for CMake-driven builds so this flow does not depend on the caller's shell.
set(DSIM_LD_LIBRARY_PATH "${DSIM_HOME}/llvm_small/lib:$ENV{LD_LIBRARY_PATH}")

# --------------------------------------------------
# Sources (for dependency tracking)
# --------------------------------------------------
file(GLOB_RECURSE SV_SOURCES
     CONFIGURE_DEPENDS
     ${CMAKE_SOURCE_DIR}/rtl/*.sv
     ${CMAKE_SOURCE_DIR}/verf/**/*.sv
     ${CMAKE_SOURCE_DIR}/*.svh
)

file(GLOB_RECURSE FILELISTS
     CONFIGURE_DEPENDS
     ${CMAKE_SOURCE_DIR}/*.f
)

# --------------------------------------------------
# Build image
# --------------------------------------------------
set(DSIM_IMG   sim_image)
set(DSIM_STAMP ${CMAKE_BINARY_DIR}/.dsim_built.stamp)

add_custom_command(
  OUTPUT ${DSIM_STAMP}
  COMMAND ${CMAKE_COMMAND} -E env "LD_LIBRARY_PATH=${DSIM_LD_LIBRARY_PATH}" "DSIM_LICENSE=${DSIM_LICENSE}" ${DSIM_EXECUTABLE}
          -work ${CMAKE_BINARY_DIR}
          -show-ld
          -genimage ${DSIM_IMG}
          -top ${DSIM_TOP}
          -uvm ${DSIM_UVM_VER}
          -F "${DSIM_FILELIST}"
          ${DSIM_FLAGS}
  COMMAND ${CMAKE_COMMAND} -E touch ${DSIM_STAMP}
  DEPENDS ${DSIM_FILELIST} ${FILELISTS} ${SV_SOURCES}
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  COMMENT "DSim: compiling TOP:[${DSIM_TOP}]"
  VERBATIM
)

add_custom_target(dsim_build ALL DEPENDS ${DSIM_STAMP})

# --------------------------------------------------
# Run simulation
# --------------------------------------------------
add_custom_target(dsim_run
  COMMAND ${CMAKE_COMMAND} -E env "LD_LIBRARY_PATH=${DSIM_LD_LIBRARY_PATH}" "DSIM_LICENSE=${DSIM_LICENSE}" ${DSIM_EXECUTABLE}
          -image ${DSIM_IMG}
          -work ${CMAKE_BINARY_DIR}
          -show-ld
          -uvm ${DSIM_UVM_VER}
          -trace-dpi
          -sv_seed random
          ${DSIM_FLAGS}
          +UVM_TESTNAME=${UVM_TESTNAME}
  DEPENDS dsim_build
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  COMMENT "Running UART UVM simulation"
  VERBATIM
)
