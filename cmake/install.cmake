set(ZIG_INSTALL_ARGS build ${ZIG_BUILD_ARGS} --prefix "${CMAKE_INSTALL_PREFIX}")
execute_process(
  COMMAND "${ZIG_EXECUTABLE}" ${ZIG_INSTALL_ARGS}
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  RESULT_VARIABLE _result)

if(_result)
    message("::")
    message(":: ERROR: ${_result}")
    message(":: (execute_process)")

    list(JOIN ZIG_INSTALL_ARGS " " s_INSTALL_LIBSTAGE2_ARGS)
    message("::")
    message(":: argv: ${ZIG_EXECUTABLE} ${s_INSTALL_LIBSTAGE2_ARGS}")

    set(_args ${ZIG_EXECUTABLE} ${ZIG_INSTALL_ARGS})
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
