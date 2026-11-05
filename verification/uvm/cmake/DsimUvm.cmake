# SPDX-License-Identifier: Apache-2.0

function(add_dsim_uvm_suite suite_name top_name test_name)
  set(DSIM_EXECUTABLE dsim CACHE FILEPATH "Path to DSim binary")
  set(DSIM_TOP        ${top_name} CACHE STRING "Top-level module")
  set(DSIM_FLAGS      "-suppress;DefNetNone;-suppress;MissingTimescale;-suppress;Homographs" CACHE STRING "Extra DSim flags")
  set(DSIM_FILELIST   ${CMAKE_SOURCE_DIR}/filelist.f CACHE FILEPATH ".f file")
  set(DSIM_UVM_VER    1.2 CACHE STRING "UVM version")
  set(DSIM_HOME       $ENV{DSIM_HOME} CACHE PATH "DSim root")
  set(DSIM_LICENSE    $ENV{DSIM_LICENSE} CACHE FILEPATH "DSim license file")
  set(UVM_TESTNAME    ${test_name} CACHE STRING "UVM test name")

  if(NOT DSIM_HOME)
    find_program(DSIM_DISCOVERED ${DSIM_EXECUTABLE})
    if(DSIM_DISCOVERED)
      get_filename_component(DSIM_BIN_DIR "${DSIM_DISCOVERED}" DIRECTORY)
      get_filename_component(DSIM_HOME "${DSIM_BIN_DIR}/.." ABSOLUTE)
    else()
      message(FATAL_ERROR "DSIM_HOME is not set and dsim is not in PATH.")
    endif()
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

  set(DSIM_LD_LIBRARY_PATH "${DSIM_HOME}/llvm_small/lib:$ENV{LD_LIBRARY_PATH}")
  file(GLOB_RECURSE SV_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/*.sv)
  file(GLOB_RECURSE FILELISTS CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/*.f)

  set(DSIM_IMG sim_image)
  set(DSIM_STAMP ${CMAKE_BINARY_DIR}/.dsim_built.stamp)
  add_custom_command(
    OUTPUT ${DSIM_STAMP}
    COMMAND ${CMAKE_COMMAND} -E env "LD_LIBRARY_PATH=${DSIM_LD_LIBRARY_PATH}" "DSIM_LICENSE=${DSIM_LICENSE}" ${DSIM_EXECUTABLE}
            -work ${CMAKE_BINARY_DIR} -show-ld -genimage ${DSIM_IMG}
            -top ${DSIM_TOP} -uvm ${DSIM_UVM_VER} -F "${DSIM_FILELIST}" ${DSIM_FLAGS}
    COMMAND ${CMAKE_COMMAND} -E touch ${DSIM_STAMP}
    DEPENDS ${DSIM_FILELIST} ${FILELISTS} ${SV_SOURCES}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "DSim: compiling TOP:[${DSIM_TOP}]"
    VERBATIM
  )
  add_custom_target(dsim_build ALL DEPENDS ${DSIM_STAMP})
  add_custom_target(dsim_run
    COMMAND ${CMAKE_COMMAND} -E env "LD_LIBRARY_PATH=${DSIM_LD_LIBRARY_PATH}" "DSIM_LICENSE=${DSIM_LICENSE}" ${DSIM_EXECUTABLE}
            -image ${DSIM_IMG} -work ${CMAKE_BINARY_DIR} -show-ld
            -uvm ${DSIM_UVM_VER} -trace-dpi -sv_seed random ${DSIM_FLAGS}
            +UVM_TESTNAME=${UVM_TESTNAME} +UVM_NO_RELNOTES
    DEPENDS dsim_build
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running ${suite_name} UVM simulation"
    VERBATIM
  )
endfunction()
