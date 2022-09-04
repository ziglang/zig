set(STAGE1_SOURCES
    "analyze.cpp"
    "astgen.cpp"
    "bigfloat.cpp"
    "bigint.cpp"
    "buffer.cpp"
    "codegen.cpp"
    "errmsg.cpp"
    "error.cpp"
    "heap.cpp"
    "ir.cpp"
    "ir_print.cpp"
    "mem.cpp"
    "os.cpp"
    "parser.cpp"
    "range_set.cpp"
    "softfloat_ext.cpp"
    "stage1.cpp"
    "target.cpp"
    "tokenizer.cpp"
    "util.cpp"
)

add_library(zigstage1 STATIC ${STAGE1_SOURCES})
target_compile_features(zigstage1 PUBLIC cxx_std_14)
target_compile_options(zigstage1 PRIVATE ${EXE_CFLAGS})
target_link_options(zigstage1 PRIVATE ${EXE_LDFLAGS})
target_link_libraries(zigstage1 LINK_PUBLIC opt_c_util zigcpp)
if(NOT MSVC)
    target_link_libraries(zigstage1 LINK_PUBLIC ${LIBXML2})
endif()
if(ZIG_DIA_GUIDS_LIB)
    target_link_libraries(zigstage1 LINK_PUBLIC ${ZIG_DIA_GUIDS_LIB})
endif()
if(MSVC OR MINGW)
    target_link_libraries(zigstage1 LINK_PUBLIC version)
endif()
target_include_directories(zigstage1 PUBLIC
    "${CMAKE_BINARY_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../"
    "${CMAKE_CURRENT_SOURCE_DIR}"
)
