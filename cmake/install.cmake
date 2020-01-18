message("-- Installing: ${CMAKE_INSTALL_PREFIX}/lib")

if(NOT EXISTS ${zig0_EXE})
    message("::")
    message(":: ERROR: Executable not found")
    message(":: (execute_process)")
    message("::")
    message(":: executable: ${zig0_EXE}")
    message("::")
    message(FATAL_ERROR)
endif()

execute_process(COMMAND ${zig0_EXE} ${INSTALL_LIBUSERLAND_ARGS}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    RESULT_VARIABLE _result
)
if(_result)
    message("::")
    message(":: ERROR: ${_result}")
    message(":: (execute_process)")

    string(REPLACE ";" " " s_INSTALL_LIBUSERLAND_ARGS "${INSTALL_LIBUSERLAND_ARGS}")
    message("::")
    message(":: argv: ${zig0_EXE} ${s_INSTALL_LIBUSERLAND_ARGS} install")

    set(_args ${zig0_EXE} ${INSTALL_LIBUSERLAND_ARGS})
    list(LENGTH _args _len)
    math(EXPR _len "${_len} - 1")
    message("::")
    foreach(_i RANGE 0 ${_len})
        list(GET _args ${_i} _arg)
        message(":: argv[${_i}]: ${_arg}")
    endforeach()

    message("::")
    message(FATAL_ERROR)
endif()
