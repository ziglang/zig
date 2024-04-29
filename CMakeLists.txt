cmake_minimum_required(VERSION 3.5)
include(CheckSymbolExists)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

if(NOT CMAKE_INSTALL_PREFIX)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/stage3" CACHE STRING
      "Directory to install zig to" FORCE)
endif()

# CMake recognizes the CMAKE_PREFIX_PATH environment variable for some things,
# and also the CMAKE_PREFIX_PATH cache variable for other things. However, it
# does not relate these two things, i.e. if the environment variable is set,
# CMake does not populate the cache variable in a corresponding manner. Some
# package systems, such as Homebrew, set the environment variable but not the
# cache variable. Furthermore, the environment variable follows the system path
# separator, such as ':' on POSIX and ';' on Windows, but the cache variable
# follows CMake's array behavior, i.e. always ';' for a separator.
list(APPEND ZIG_CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}")
if(WIN32)
  list(APPEND ZIG_CMAKE_PREFIX_PATH $ENV{CMAKE_PREFIX_PATH})
else()
  string(REGEX REPLACE ":" ";" ZIG_CMAKE_PREFIX_PATH_STRING "$ENV{CMAKE_PREFIX_PATH}")
  list(APPEND ZIG_CMAKE_PREFIX_PATH "${ZIG_CMAKE_PREFIX_PATH_STRING}")
endif()

set(CMAKE_USER_MAKE_RULES_OVERRIDE
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/c_flag_overrides.cmake)
set(CMAKE_USER_MAKE_RULES_OVERRIDE_CXX
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/cxx_flag_overrides.cmake)

project(zig C CXX)
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 13)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "" CACHE STRING "Override Zig version string. Default is to find out with git.")

if("${ZIG_VERSION}" STREQUAL "")
    set(RESOLVED_ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")
    find_program(GIT_EXE NAMES git NAMES_PER_DIR)
    if(GIT_EXE)
        execute_process(
            COMMAND ${GIT_EXE} -C ${CMAKE_SOURCE_DIR} describe --match *.*.* --tags --abbrev=9
            RESULT_VARIABLE EXIT_STATUS
            OUTPUT_VARIABLE GIT_DESCRIBE
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        if(EXIT_STATUS EQUAL "0")
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/.git/HEAD)
            if(GIT_DESCRIBE MATCHES "^v?([0-9]+\\.[0-9]+\\.[0-9]+)$")
                # Tagged release version.
                set(GIT_TAG ${CMAKE_MATCH_1})
                if(NOT GIT_TAG VERSION_EQUAL RESOLVED_ZIG_VERSION)
                    message(SEND_ERROR "Zig version (${RESOLVED_ZIG_VERSION}) does not match Git tag (${GIT_TAG}).")
                endif()
            elseif(GIT_DESCRIBE MATCHES "^v?([0-9]+\\.[0-9]+\\.[0-9]+)-([0-9]+)-g(.+)$")
                # Untagged pre-release. The Zig version is updated to include the number of commits
                # since the last tagged version and the commit hash. The version is formatted in
                # accordance with the https://semver.org specification.
                set(GIT_TAG ${CMAKE_MATCH_1})
                set(GIT_COMMITS_AFTER_TAG ${CMAKE_MATCH_2})
                set(GIT_COMMIT ${CMAKE_MATCH_3})
                if(NOT RESOLVED_ZIG_VERSION VERSION_GREATER GIT_TAG)
                    message(SEND_ERROR "Zig version (${RESOLVED_ZIG_VERSION}) must be greater than tagged ancestor (${GIT_TAG}).")
                endif()
                set(RESOLVED_ZIG_VERSION "${RESOLVED_ZIG_VERSION}-dev.${GIT_COMMITS_AFTER_TAG}+${GIT_COMMIT}")
            else()
                message(WARNING "Failed to parse version from output of `git describe`.")
            endif()
        endif()
    endif()
else()
    set(RESOLVED_ZIG_VERSION "${ZIG_VERSION}")
endif()
message(STATUS "Configuring zig version ${RESOLVED_ZIG_VERSION}")

set(ZIG_NO_LIB off CACHE BOOL
    "Disable copying lib/ files to install prefix during the build phase")

# This used to do something and it may or may not do something in the future.
# Right now it does nothing.
set(ZIG_NO_LANGREF off CACHE BOOL
    "Disable copying of langref to the install prefix during the build phase")

set(ZIG_STATIC off CACHE BOOL "Attempt to build a static zig executable (not compatible with glibc)")
set(ZIG_SHARED_LLVM off CACHE BOOL "Prefer linking against shared LLVM libraries")
set(ZIG_STATIC_LLVM ${ZIG_STATIC} CACHE BOOL "Prefer linking against static LLVM libraries")
set(ZIG_STATIC_ZLIB ${ZIG_STATIC} CACHE BOOL "Prefer linking against static zlib")
set(ZIG_STATIC_ZSTD ${ZIG_STATIC} CACHE BOOL "Prefer linking against static zstd")
set(ZIG_USE_CCACHE off CACHE BOOL "Use ccache")

if(ZIG_USE_CCACHE)
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
      set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${CCACHE_PROGRAM}")
    else()
      message(SEND_ERROR "ccache requested but not found")
    endif()
endif()

if (ZIG_SHARED_LLVM AND ZIG_STATIC_LLVM)
    message(SEND_ERROR "-DZIG_SHARED_LLVM and -DZIG_STATIC_LLVM cannot both be enabled simultaneously")
endif()

set(ZIG_TARGET_TRIPLE "native" CACHE STRING "arch-os-abi to output binaries for")
set(ZIG_TARGET_MCPU "native" CACHE STRING "-mcpu parameter to output binaries for")
set(ZIG_TARGET_DYNAMIC_LINKER "" CACHE STRING
  "Override the dynamic linker used by the Zig binary. Default is to auto-detect the dynamic linker.")
set(ZIG_SINGLE_THREADED off CACHE BOOL "limit the zig compiler to use only 1 thread")
set(ZIG_AR_WORKAROUND off CACHE BOOL "append 'ar' subcommand to CMAKE_AR")

if("${ZIG_TARGET_TRIPLE}" STREQUAL "native")
    set(ZIG_USE_LLVM_CONFIG ON CACHE BOOL "use llvm-config to find LLVM libraries")
else()
    set(ZIG_USE_LLVM_CONFIG OFF CACHE BOOL "use llvm-config to find LLVM libraries")
endif()

if(ZIG_AR_WORKAROUND)
  string(REPLACE "<CMAKE_AR>" "<CMAKE_AR> ar" CMAKE_C_ARCHIVE_CREATE ${CMAKE_C_ARCHIVE_CREATE})
  string(REPLACE "<CMAKE_AR>" "<CMAKE_AR> ar" CMAKE_CXX_ARCHIVE_CREATE ${CMAKE_CXX_ARCHIVE_CREATE})
endif()

set(ZIG_PIE off CACHE BOOL "produce a position independent zig executable")

# Detect system libcxx name.
if ("c++" IN_LIST CMAKE_CXX_IMPLICIT_LINK_LIBRARIES)
    set(ZIG_SYSTEM_LIBCXX "c++" CACHE STRING "system libcxx name for build.zig")
else()
    set(ZIG_SYSTEM_LIBCXX "stdc++" CACHE STRING "system libcxx name for build.zig")
endif()

find_package(llvm 18)
find_package(clang 18)
find_package(lld 18)

if(ZIG_STATIC_ZLIB)
    if (MSVC)
        list(REMOVE_ITEM LLVM_LIBRARIES "z.lib")
    else()
        list(REMOVE_ITEM LLVM_LIBRARIES "-lz")
    endif()

    find_library(ZLIB NAMES libz.a libzlibstatic.a z zlib libz NAMES_PER_DIR)
    list(APPEND LLVM_LIBRARIES "${ZLIB}")
endif()

if(ZIG_STATIC_ZSTD)
    if (MSVC)
        list(REMOVE_ITEM LLVM_LIBRARIES "zstd.lib")
    else()
        list(REMOVE_ITEM LLVM_LIBRARIES "-lzstd")
    endif()

    find_library(ZSTD NAMES libzstd.a libzstdstatic.a zstd NAMES_PER_DIR)
    list(APPEND LLVM_LIBRARIES "${ZSTD}")
endif()

if(APPLE AND ZIG_STATIC)
    list(REMOVE_ITEM LLVM_LIBRARIES "-lcurses")
    find_library(CURSES NAMES libcurses.a libncurses.a NAMES_PER_DIR
      PATHS
        /usr/local/opt/ncurses/lib
        /opt/homebrew/opt/ncurses/lib)
    list(APPEND LLVM_LIBRARIES "${CURSES}")
endif()

set(ZIG_CPP_LIB_DIR "${CMAKE_BINARY_DIR}/zigcpp")

# Handle multi-config builds and place each into a common lib. The VS generator
# for example will append a Debug folder by default if not explicitly specified.
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${ZIG_CPP_LIB_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${ZIG_CPP_LIB_DIR})
foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG_TYPE} CONFIG_TYPE)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${ZIG_CPP_LIB_DIR})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${ZIG_CPP_LIB_DIR})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${CMAKE_BINARY_DIR})
endforeach(CONFIG_TYPE CMAKE_CONFIGURATION_TYPES)

include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${LLD_INCLUDE_DIRS})
include_directories(${CLANG_INCLUDE_DIRS})

find_package(Threads)

set(ZIG_LIB_DIR "lib/zig")
set(ZIG_CONFIG_H_OUT "${CMAKE_BINARY_DIR}/config.h")
set(ZIG_CONFIG_ZIG_OUT "${CMAKE_BINARY_DIR}/config.zig")

set(ZIG_WASM2C_SOURCES
    "${CMAKE_SOURCE_DIR}/stage1/wasm2c.c"
)
set(ZIG_CPP_SOURCES
    # These are planned to stay even when we are self-hosted.
    "${CMAKE_SOURCE_DIR}/src/zig_llvm.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_llvm-ar.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_driver.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1_main.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1as_main.cpp"
)
# Needed because we use cmake, not the zig build system, to build zig2.o.
set(ZIG_STAGE2_SOURCES
    "${ZIG_CONFIG_ZIG_OUT}"
    "${CMAKE_SOURCE_DIR}/lib/std/array_hash_map.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/array_list.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/ascii.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/atomic.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/base64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/BitStack.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/buf_map.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Build.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Build/Cache.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Build/Cache/DepTokenizer.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/builtin.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/c.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/c/linux.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/child_process.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/coff.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/static_string_map.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/crypto.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/crypto/blake3.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/crypto/siphash.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/debug.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/dwarf.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/dwarf/AT.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/dwarf/ATE.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/dwarf/FORM.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/dwarf/LANG.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/dwarf/OP.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/dwarf/TAG.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/elf.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fifo.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt/format_float.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt/parse_float.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs/AtomicFile.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs/Dir.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs/File.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs/get_app_data_dir.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs/path.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/hash.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/hash/auto_hash.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/hash/wyhash.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/hash_map.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/heap.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/heap/arena_allocator.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/buffered_atomic_file.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/buffered_writer.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/change_detection_stream.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/counting_reader.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/counting_writer.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/find_byte_writer.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/fixed_buffer_stream.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/limited_reader.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/Reader.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/seekable_stream.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/Writer.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/json.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/json/stringify.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/leb128.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/linked_list.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/log.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/macho.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/big.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/big/int.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/float.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/frexp.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/isinf.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/isnan.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/log.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/log10.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/log2.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/signbit.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/sqrt.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/mem.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/mem/Allocator.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/meta.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/meta/trailer_flags.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/multi_array_list.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/x86_64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/IoUring.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/io_uring_sqe.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/x86_64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/windows.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/windows/ntstatus.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/windows/win32error.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Progress.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/pdb.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/process.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Random.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/sort.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/absv.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/absvdi2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/absvsi2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/absvti2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/adddf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/addf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/addo.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/addsf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/addtf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/addxf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/arm.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/atomics.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/aulldiv.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/aullrem.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/bswap.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/ceil.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/clear_cache.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/cmp.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/cmpdf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/cmpsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/cmptf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/cmpxf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/common.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/comparef.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/cos.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/count0bits.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/divdf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/divsf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/divtf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/divti3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/divxf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/emutls.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/exp.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/exp2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extenddftf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extenddfxf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendhfsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendhftf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendhfxf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendsfdf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendsftf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendsfxf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/extendxftf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fabs.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixdfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixdfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixdfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixhfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixhfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixhfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixsfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixsfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixsfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixtfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixtfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixtfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunsdfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunsdfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunsdfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunshfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunshfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunshfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunssfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunssfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunssfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunstfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunstfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunstfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunsxfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunsxfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixunsxfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixxfdi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixxfsi.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fixxfti.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/int_from_float.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatdidf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatdihf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatdisf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatditf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatdixf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatsidf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatsihf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatsisf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatsitf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatsixf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floattidf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floattihf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floattisf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floattitf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floattixf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatundidf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatundihf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatundisf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatunditf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatundixf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatunsidf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatunsihf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatunsisf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatunsitf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatunsixf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatuntidf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatuntihf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatuntisf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatuntitf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floatuntixf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/floor.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fma.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fmax.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fmin.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/fmod.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/gedf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/gesf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/getf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/gexf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/int.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/float_from_int.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/log.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/log10.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/log2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/modti3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulXi3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/muldf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulo.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulsf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/multf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulxf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/negXi2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/negv.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/os_version_check.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/parity.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/popcount.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/rem_pio2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/rem_pio2_large.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/rem_pio2f.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/round.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/shift.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/sin.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/sincos.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/sqrt.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/stack_probe.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/subo.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/subsf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/subdf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/subtf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/subxf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/negsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/negdf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/negtf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/negxf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/tan.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/trig.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/trunc.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/truncdfhf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/truncdfsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/truncf.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/truncsfhf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/trunctfdf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/trunctfhf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/trunctfsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/trunctfxf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/truncxfdf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/truncxfhf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/truncxfsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/udivmod.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/udivmodei4.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/udivmodti4.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/udivti3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/umodti3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/unorddf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/unordsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/unordtf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/start.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/std.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/Query.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/aarch64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/amdgpu.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/arm.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/avr.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/bpf.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/hexagon.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/mips.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/msp430.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/nvptx.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/powerpc.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/riscv.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/sparc.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/s390x.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/wasm.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Target/x86.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/Futex.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/Mutex.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/Pool.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/ResetEvent.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/WaitGroup.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/time.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/treap.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/unicode.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/Ast.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/AstGen.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/AstRlAnnotate.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/LibCInstallation.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/Parse.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/Server.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/WindowsSdk.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/Zir.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/c_builtins.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/render.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/string_literal.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/system.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/system/NativePaths.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/system/x86.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/tokenizer.zig"
    "${CMAKE_SOURCE_DIR}/src/Air.zig"
    "${CMAKE_SOURCE_DIR}/src/Compilation.zig"
    "${CMAKE_SOURCE_DIR}/src/Compilation/Config.zig"
    "${CMAKE_SOURCE_DIR}/src/Liveness.zig"
    "${CMAKE_SOURCE_DIR}/src/Module.zig"
    "${CMAKE_SOURCE_DIR}/src/Package.zig"
    "${CMAKE_SOURCE_DIR}/src/Package/Fetch.zig"
    "${CMAKE_SOURCE_DIR}/src/RangeSet.zig"
    "${CMAKE_SOURCE_DIR}/src/Sema.zig"
    "${CMAKE_SOURCE_DIR}/src/Value.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/aarch64/CodeGen.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/aarch64/Emit.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/aarch64/Mir.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/aarch64/bits.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/aarch64/abi.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/arm/CodeGen.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/arm/Emit.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/arm/Mir.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/arm/bits.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/arm/abi.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/riscv64/CodeGen.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/riscv64/Emit.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/riscv64/Mir.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/riscv64/bits.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/riscv64/abi.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/sparc64/CodeGen.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/sparc64/Emit.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/sparc64/Mir.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/sparc64/bits.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/sparc64/abi.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/wasm/CodeGen.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/wasm/Emit.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/wasm/Mir.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/CodeGen.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/Disassembler.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/Emit.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/Encoding.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/Mir.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/abi.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/bits.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/encoder.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/encodings.zig"
    "${CMAKE_SOURCE_DIR}/src/clang.zig"
    "${CMAKE_SOURCE_DIR}/src/clang_options.zig"
    "${CMAKE_SOURCE_DIR}/src/clang_options_data.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen/c.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen/c/Type.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen/llvm.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen/llvm/bindings.zig"
    "${CMAKE_SOURCE_DIR}/src/glibc.zig"
    "${CMAKE_SOURCE_DIR}/src/introspect.zig"
    "${CMAKE_SOURCE_DIR}/src/libcxx.zig"
    "${CMAKE_SOURCE_DIR}/src/libtsan.zig"
    "${CMAKE_SOURCE_DIR}/src/libunwind.zig"
    "${CMAKE_SOURCE_DIR}/src/link.zig"
    "${CMAKE_SOURCE_DIR}/src/link/C.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff/Atom.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff/ImportTable.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff/Object.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff/lld.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/Archive.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/Atom.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/LdScript.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/LinkerDefined.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/Object.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/SharedObject.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/Symbol.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/ZigObject.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/eh_frame.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/file.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/gc.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/relocatable.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/relocation.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/synthetic_sections.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf/thunks.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Archive.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Atom.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/CodeSignature.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/DebugSymbols.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/DwarfInfo.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Dylib.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/InternalObject.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Object.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Relocation.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Symbol.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/UnwindInfo.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/ZigObject.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/dead_strip.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/dyld_info/bind.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/dyld_info/Rebase.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/dyld_info/Trie.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/eh_frame.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/fat.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/file.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/hasher.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/load_commands.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/relocatable.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/synthetic.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/thunks.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/uuid.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Plan9.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Plan9/aout.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Wasm.zig"
    "${CMAKE_SOURCE_DIR}/src/link/msdos-stub.bin"
    "${CMAKE_SOURCE_DIR}/src/link/StringTable.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi/Tokenizer.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi/parse.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi/yaml.zig"
    "${CMAKE_SOURCE_DIR}/src/main.zig"
    "${CMAKE_SOURCE_DIR}/src/mingw.zig"
    "${CMAKE_SOURCE_DIR}/src/musl.zig"
    "${CMAKE_SOURCE_DIR}/src/mutable_value.zig"
    "${CMAKE_SOURCE_DIR}/src/print_air.zig"
    "${CMAKE_SOURCE_DIR}/src/print_env.zig"
    "${CMAKE_SOURCE_DIR}/src/print_targets.zig"
    "${CMAKE_SOURCE_DIR}/src/print_value.zig"
    "${CMAKE_SOURCE_DIR}/src/print_zir.zig"
    "${CMAKE_SOURCE_DIR}/src/register_manager.zig"
    "${CMAKE_SOURCE_DIR}/src/target.zig"
    "${CMAKE_SOURCE_DIR}/src/tracy.zig"
    "${CMAKE_SOURCE_DIR}/src/translate_c.zig"
    "${CMAKE_SOURCE_DIR}/src/type.zig"
    "${CMAKE_SOURCE_DIR}/src/wasi_libc.zig"
)

if(MSVC)
    set(MSVC_DIA_SDK_DIR "$ENV{VSINSTALLDIR}DIA SDK")
    if(IS_DIRECTORY ${MSVC_DIA_SDK_DIR})
        set(ZIG_DIA_GUIDS_LIB "${MSVC_DIA_SDK_DIR}/lib/amd64/diaguids.lib")
        string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_DIA_GUIDS_LIB_ESCAPED "${ZIG_DIA_GUIDS_LIB}")
    endif()
endif()

configure_file (
    "${CMAKE_SOURCE_DIR}/stage1/config.h.in"
    "${ZIG_CONFIG_H_OUT}"
)
configure_file (
    "${CMAKE_SOURCE_DIR}/stage1/config.zig.in"
    "${ZIG_CONFIG_ZIG_OUT}"
)

include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
    "${CMAKE_SOURCE_DIR}/src"
)

if(MSVC)
  set(EXE_CXX_FLAGS "/std:c++17")
  set(EXE_LDFLAGS "/STACK:16777216")
  if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Release" AND NOT "${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")
    set(EXE_LDFLAGS "${EXE_LDFLAGS} /debug:fastlink")
  endif()
else()
  set(EXE_CXX_FLAGS "-std=c++17 -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -D_GNU_SOURCE -fvisibility-inlines-hidden -fno-exceptions -fno-rtti -Wno-type-limits -Wno-missing-braces -Wno-comment")
  set(EXE_LDFLAGS " ")
  if(MINGW)
    set(EXE_CXX_FLAGS "${EXE_CXX_FLAGS} -Wno-format")
    set(EXE_LDFLAGS "${EXE_LDFLAGS} -Wl,--stack,16777216")
  endif()
endif()

if(ZIG_STATIC)
    if(APPLE)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static-libgcc -static-libstdc++")
    elseif(MINGW)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static-libgcc -static-libstdc++ -Wl,-Bstatic, -lwinpthread -lz3 -lz -lgomp")
    elseif(NOT MSVC)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static")
    endif()
endif()

add_library(zigcpp STATIC ${ZIG_CPP_SOURCES})
if(ZIG_PIE)
    set(ZIGCPP_CXX_FLAGS "${EXE_CXX_FLAGS} -fno-stack-protector -fPIC")
else()
    set(ZIGCPP_CXX_FLAGS "${EXE_CXX_FLAGS} -fno-stack-protector")
endif()
set_target_properties(zigcpp PROPERTIES COMPILE_FLAGS ${ZIGCPP_CXX_FLAGS})

target_link_libraries(zigcpp LINK_PUBLIC
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)

string(TOLOWER "${CMAKE_HOST_SYSTEM_NAME}" ZIG_HOST_TARGET_OS)
if(ZIG_HOST_TARGET_OS STREQUAL "darwin")
  set(ZIG_HOST_TARGET_OS "macos")
elseif(ZIG_HOST_TARGET_OS STREQUAL "sunos")
  check_symbol_exists(__illumos__ "" ZIG_HOST_TARGET_HAS_ILLUMOS_MACRO)
  if (ZIG_HOST_TARGET_HAS_ILLUMOS_MACRO)
    set(ZIG_HOST_TARGET_OS "illumos")
  else()
    set(ZIG_HOST_TARGET_OS "solaris")
  endif()
endif()

string(TOLOWER "${CMAKE_HOST_SYSTEM_PROCESSOR}" ZIG_HOST_TARGET_ARCH)
if(ZIG_HOST_TARGET_ARCH MATCHES "^i[3-9]86$")
  if (ZIG_HOST_TARGET_OS MATCHES "(solaris|illumos)")
    set(ZIG_HOST_TARGET_ARCH "x86_64")
  else()
    set(ZIG_HOST_TARGET_ARCH "x86")
  endif()
elseif(ZIG_HOST_TARGET_ARCH STREQUAL "amd64")
  set(ZIG_HOST_TARGET_ARCH "x86_64")
elseif(ZIG_HOST_TARGET_ARCH STREQUAL "arm64")
  set(ZIG_HOST_TARGET_ARCH "aarch64")
elseif(ZIG_HOST_TARGET_ARCH STREQUAL "armv7l")
  set(ZIG_HOST_TARGET_ARCH "arm")
elseif(ZIG_HOST_TARGET_ARCH STREQUAL "armv7b")
  set(ZIG_HOST_TARGET_ARCH "armeb")
endif()
string(REGEX REPLACE "^((arm|thumb)(hf?)?)el$" "\\1" ZIG_HOST_TARGET_ARCH "${ZIG_HOST_TARGET_ARCH}")
if(ZIG_HOST_TARGET_ARCH MATCHES "^arm(hf?)?(eb)?$")
  check_symbol_exists(__thumb__ "" ZIG_HOST_TARGET_DEFAULTS_TO_THUMB)
  if(ZIG_HOST_TARGET_DEFAULTS_TO_THUMB)
    string(REGEX REPLACE "^arm" "thumb" ZIG_HOST_TARGET_ARCH "${ZIG_HOST_TARGET_ARCH}")
  endif()
endif()
string(REGEX REPLACE "^ppc((64)?(le)?)$" "powerpc\\1" ZIG_HOST_TARGET_ARCH "${ZIG_HOST_TARGET_ARCH}")

if(MSVC)
  set(ZIG_HOST_TARGET_ABI "-msvc")
elseif(MINGW)
  set(ZIG_HOST_TARGET_ABI "-gnu")
elseif(ZIG_HOST_TARGET_ARCH MATCHES "^(arm|thumb)hf?(eb)?$")
  string(REGEX REPLACE "^(arm|thumb)hf?((eb)?)$" "\\1\\2" ZIG_HOST_TARGET_ARCH "${ZIG_HOST_TARGET_ARCH}")
  set(ZIG_HOST_TARGET_ABI "-eabihf")
else()
  set(ZIG_HOST_TARGET_ABI "")
endif()

set(ZIG_HOST_TARGET_TRIPLE "${ZIG_HOST_TARGET_ARCH}-${ZIG_HOST_TARGET_OS}${ZIG_HOST_TARGET_ABI}" CACHE STRING "Host zig target triple.")

if(MSVC)
  set(ZIG_WASM2C_COMPILE_FLAGS "")
  set(ZIG1_COMPILE_FLAGS "/Os")
  set(ZIG2_COMPILE_FLAGS "/Od")
  set(ZIG2_LINK_FLAGS "/STACK:16777216 /FORCE:MULTIPLE")
else()
  set(ZIG_WASM2C_COMPILE_FLAGS "-std=c99 -O2")
  set(ZIG1_COMPILE_FLAGS "-std=c99 -Os")
  set(ZIG2_COMPILE_FLAGS "-std=c99 -O0 -fno-stack-protector")
  if(APPLE)
    set(ZIG2_LINK_FLAGS "-Wl,-stack_size,0x10000000")
  elseif(MINGW)
    set(ZIG2_LINK_FLAGS "-Wl,--stack,0x10000000")
  # Solaris/illumos ld(1) does not provide a --stack-size option.
  elseif(CMAKE_HOST_SOLARIS)
    unset(ZIG2_LINK_FLAGS)
  else()
    set(ZIG2_LINK_FLAGS "-Wl,-z,stack-size=0x10000000")
  endif()
endif()

set(ZIG1_WASM_MODULE "${CMAKE_SOURCE_DIR}/stage1/zig1.wasm")
set(ZIG1_C_SOURCE "${CMAKE_BINARY_DIR}/zig1.c")
set(ZIG2_C_SOURCE "${CMAKE_BINARY_DIR}/zig2.c")
set(ZIG_COMPILER_RT_C_SOURCE "${CMAKE_BINARY_DIR}/compiler_rt.c")

add_executable(zig-wasm2c ${ZIG_WASM2C_SOURCES})
set_target_properties(zig-wasm2c PROPERTIES COMPILE_FLAGS "${ZIG_WASM2C_COMPILE_FLAGS}")

add_custom_command(
  OUTPUT "${ZIG1_C_SOURCE}"
  COMMAND zig-wasm2c "${ZIG1_WASM_MODULE}" "${ZIG1_C_SOURCE}"
  DEPENDS zig-wasm2c "${ZIG1_WASM_MODULE}"
  COMMENT STATUS "Converting ${ZIG1_WASM_MODULE} to ${ZIG1_C_SOURCE}"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

add_executable(zig1 ${ZIG1_C_SOURCE} "${CMAKE_SOURCE_DIR}/stage1/wasi.c")
set_target_properties(zig1 PROPERTIES COMPILE_FLAGS ${ZIG1_COMPILE_FLAGS})

if(MSVC)
  target_link_options(zig1 PRIVATE /STACK:0x10000000)
else()
  target_link_libraries(zig1 LINK_PUBLIC m)
  if(MINGW)
    target_link_options(zig1 PRIVATE -Wl,--stack,0x10000000)
  endif()
endif()

set(BUILD_ZIG2_ARGS
  "${CMAKE_SOURCE_DIR}/lib"
  build-exe -ofmt=c -lc -OReleaseSmall
  --name zig2
  -femit-bin="${ZIG2_C_SOURCE}"
  -target "${ZIG_HOST_TARGET_TRIPLE}"
  --dep "build_options"
  --dep "aro"
  --mod "root" "src/main.zig"
  --mod "build_options" "${ZIG_CONFIG_ZIG_OUT}"
  --mod "aro" "lib/compiler/aro/aro.zig"
)

add_custom_command(
  OUTPUT "${ZIG2_C_SOURCE}"
  COMMAND zig1 ${BUILD_ZIG2_ARGS}
  DEPENDS zig1 "${ZIG_STAGE2_SOURCES}"
  COMMENT STATUS "Running zig1.wasm to produce ${ZIG2_C_SOURCE}"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

set(BUILD_COMPILER_RT_ARGS
  "${CMAKE_SOURCE_DIR}/lib"
  build-obj -ofmt=c -OReleaseSmall
  --name compiler_rt
  -femit-bin="${ZIG_COMPILER_RT_C_SOURCE}"
  -target "${ZIG_HOST_TARGET_TRIPLE}"
  --dep "build_options"
  --mod "root" "lib/compiler_rt.zig"
  --mod "build_options" "${ZIG_CONFIG_ZIG_OUT}"
)

add_custom_command(
  OUTPUT "${ZIG_COMPILER_RT_C_SOURCE}"
  COMMAND zig1 ${BUILD_COMPILER_RT_ARGS}
  DEPENDS zig1 "${ZIG_STAGE2_SOURCES}"
  COMMENT STATUS "Running zig1.wasm to produce ${ZIG_COMPILER_RT_C_SOURCE}"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

add_executable(zig2 ${ZIG2_C_SOURCE} ${ZIG_COMPILER_RT_C_SOURCE})
set_target_properties(zig2 PROPERTIES
  COMPILE_FLAGS ${ZIG2_COMPILE_FLAGS}
  LINK_FLAGS "${ZIG2_LINK_FLAGS}"
)
target_include_directories(zig2 PUBLIC "${CMAKE_SOURCE_DIR}/stage1")
target_link_libraries(zig2 LINK_PUBLIC zigcpp)

if(MSVC)
  target_link_libraries(zig2 LINK_PUBLIC ntdll.lib)
elseif(MINGW)
  target_link_libraries(zig2 LINK_PUBLIC ntdll)
endif()

if(NOT MSVC)
    target_link_libraries(zig2 LINK_PUBLIC ${LIBXML2})
endif()

if(ZIG_DIA_GUIDS_LIB)
    target_link_libraries(zig2 LINK_PUBLIC ${ZIG_DIA_GUIDS_LIB})
endif()

if(MSVC OR MINGW)
    target_link_libraries(zig2 LINK_PUBLIC version)
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  set(ZIG_RELEASE_ARG "")
elseif("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
  set(ZIG_RELEASE_ARG -Doptimize=ReleaseFast)
else()
  set(ZIG_RELEASE_ARG -Doptimize=ReleaseFast -Dstrip)
endif()
if(ZIG_NO_LIB)
  set(ZIG_NO_LIB_ARG "-Dno-lib")
else()
  set(ZIG_NO_LIB_ARG "")
endif()
if(ZIG_SINGLE_THREADED)
  set(ZIG_SINGLE_THREADED_ARG "-Dsingle-threaded")
else()
  set(ZIG_SINGLE_THREADED_ARG "")
endif()
if(ZIG_STATIC AND NOT MSVC)
  set(ZIG_STATIC_ARG "-Duse-zig-libcxx")
else()
  set(ZIG_STATIC_ARG "")
endif()
if(CMAKE_POSITION_INDEPENDENT_CODE OR ZIG_PIE)
  set(ZIG_PIE_ARG "-Dpie")
else()
  set(ZIG_PIE_ARG "")
endif()
if("${ZIG_TARGET_DYNAMIC_LINKER}" STREQUAL "")
  set(ZIG_DYNAMIC_LINKER_ARG "")
else()
  set(ZIG_DYNAMIC_LINKER_ARG "-Ddynamic-linker=${ZIG_TARGET_DYNAMIC_LINKER}")
endif()

# -Dno-langref is currently hardcoded because building the langref takes too damn long
# To obtain these two forms of documentation, run zig build against stage3 rather than stage2.
set(ZIG_BUILD_ARGS
  --zig-lib-dir "${CMAKE_SOURCE_DIR}/lib"
  "-Dconfig_h=${ZIG_CONFIG_H_OUT}"
  "-Denable-llvm"
  ${ZIG_RELEASE_ARG}
  ${ZIG_STATIC_ARG}
  ${ZIG_NO_LIB_ARG}
  "-Dno-langref"
  ${ZIG_SINGLE_THREADED_ARG}
  ${ZIG_PIE_ARG}
  "-Dtarget=${ZIG_TARGET_TRIPLE}"
  "-Dcpu=${ZIG_TARGET_MCPU}"
  ${ZIG_DYNAMIC_LINKER_ARG}
  "-Dversion-string=${RESOLVED_ZIG_VERSION}"
)

add_custom_target(stage3 ALL
  DEPENDS "${CMAKE_BINARY_DIR}/stage3/bin/zig"
)

add_custom_command(
  OUTPUT "${CMAKE_BINARY_DIR}/stage3/bin/zig"
  COMMAND zig2 build --prefix "${CMAKE_BINARY_DIR}/stage3" ${ZIG_BUILD_ARGS}
  COMMENT STATUS "Building stage3"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

if(WIN32)
  set(ZIG_EXECUTABLE "${CMAKE_BINARY_DIR}/zig2.exe")
else()
  set(ZIG_EXECUTABLE "${CMAKE_BINARY_DIR}/zig2")
endif()

install(CODE "set(ZIG_EXECUTABLE \"${ZIG_EXECUTABLE}\")")
install(CODE "set(ZIG_BUILD_ARGS \"${ZIG_BUILD_ARGS}\")")
install(CODE "set(CMAKE_INSTALL_PREFIX \"${CMAKE_INSTALL_PREFIX}\")")
install(CODE "set(CMAKE_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")")
install(SCRIPT "${CMAKE_SOURCE_DIR}/cmake/install.cmake")
