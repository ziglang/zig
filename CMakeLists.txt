cmake_minimum_required(VERSION 2.8)

set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
    "Choose the type of build, options are: Debug Release RelWithDebInfo MinSizeRel." FORCE)

project(zig C CXX)
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 0)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")
message("Configuring zig version ${ZIG_VERSION}")

find_package(llvm)
include_directories(${LLVM_INCLUDE_DIR})

include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
)

set(GRAMMAR_TXT "${CMAKE_BINARY_DIR}/simple.txt")

set(ZIG_SOURCES
    "${CMAKE_SOURCE_DIR}/src/buffer.cpp"
    "${CMAKE_SOURCE_DIR}/src/error.cpp"
    "${CMAKE_SOURCE_DIR}/src/main.cpp"
    "${CMAKE_SOURCE_DIR}/src/parser.cpp"
    "${CMAKE_SOURCE_DIR}/src/tokenizer.cpp"
    "${CMAKE_SOURCE_DIR}/src/util.cpp"
    "${CMAKE_SOURCE_DIR}/src/codegen.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_llvm.cpp"
)

set(CONFIGURE_OUT_FILE "${CMAKE_BINARY_DIR}/config.h")
configure_file (
    "${CMAKE_SOURCE_DIR}/src/config.h.in"
    ${CONFIGURE_OUT_FILE}
)

set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -Wno-unused-variable -Wno-unused-but-set-variable")

set(EXE_CFLAGS "-std=c++11 -Werror -Wall -Werror=strict-prototypes -Werror=old-style-definition -Werror=missing-prototypes")


add_executable(zig ${ZIG_SOURCES})
set_target_properties(zig PROPERTIES
    LINKER_LANGUAGE C
    COMPILE_FLAGS ${EXE_CFLAGS})
target_link_libraries(zig LINK_PUBLIC
    ${LLVM_LIBRARIES}
)
install(TARGETS zig DESTINATION bin)

