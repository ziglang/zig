cmake_minimum_required(VERSION 2.8.12)

# Use ccache if possible
FIND_PROGRAM(CCACHE_PROGRAM ccache)
IF(CCACHE_PROGRAM)
    MESSAGE(STATUS "Found ccache ${CCACHE_PROGRAM}")
ENDIF()

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

if(NOT CMAKE_INSTALL_PREFIX)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/stage3" CACHE STRING
      "Directory to install zig to" FORCE)
endif()

set(CMAKE_USER_MAKE_RULES_OVERRIDE
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/c_flag_overrides.cmake)
set(CMAKE_USER_MAKE_RULES_OVERRIDE_CXX
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/cxx_flag_overrides.cmake)

project(zig C CXX)
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 10)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "" CACHE STRING "Override Zig version string. Default is to find out with git.")

if("${ZIG_VERSION}" STREQUAL "")
    set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")
    find_program(GIT_EXE NAMES git NAMES_PER_DIR)
    if(GIT_EXE)
        execute_process(
            COMMAND ${GIT_EXE} -C ${CMAKE_SOURCE_DIR} describe --match *.*.* --tags
            RESULT_VARIABLE EXIT_STATUS
            OUTPUT_VARIABLE GIT_DESCRIBE
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        if(EXIT_STATUS EQUAL "0")
            if(GIT_DESCRIBE MATCHES "^v?([0-9]+\\.[0-9]+\\.[0-9]+)$")
                # Tagged release version.
                set(GIT_TAG ${CMAKE_MATCH_1})
                if(NOT GIT_TAG VERSION_EQUAL ZIG_VERSION)
                    message(SEND_ERROR "Zig version (${ZIG_VERSION}) does not match Git tag (${GIT_TAG}).")
                endif()
            elseif(GIT_DESCRIBE MATCHES "^v?([0-9]+\\.[0-9]+\\.[0-9]+)-([0-9]+)-g(.+)$")
                # Untagged pre-release. The Zig version is updated to include the number of commits
                # since the last tagged version and the commit hash. The version is formatted in
                # accordance with the https://semver.org specification.
                set(GIT_TAG ${CMAKE_MATCH_1})
                set(GIT_COMMITS_AFTER_TAG ${CMAKE_MATCH_2})
                set(GIT_COMMIT ${CMAKE_MATCH_3})
                if(NOT ZIG_VERSION VERSION_GREATER GIT_TAG)
                    message(SEND_ERROR "Zig version (${ZIG_VERSION}) must be greater than tagged ancestor (${GIT_TAG}).")
                endif()
                set(ZIG_VERSION "${ZIG_VERSION}-dev.${GIT_COMMITS_AFTER_TAG}+${GIT_COMMIT}")
            else()
                message(WARNING "Failed to parse version from output of `git describe`.")
            endif()
        endif()
    endif()
endif()
message(STATUS "Configuring zig version ${ZIG_VERSION}")

set(ZIG_SKIP_INSTALL_LIB_FILES off CACHE BOOL
    "Disable copying lib/ files to install prefix during the build phase")

set(ZIG_STATIC off CACHE BOOL "Attempt to build a static zig executable (not compatible with glibc)")
set(ZIG_SHARED_LLVM off CACHE BOOL "Prefer linking against shared LLVM libraries")
set(ZIG_STATIC_LLVM off CACHE BOOL "Prefer linking against static LLVM libraries")
set(ZIG_STATIC_ZLIB off CACHE BOOL "Prefer linking against static zlib")
set(ZIG_USE_CCACHE off CACHE BOOL "Use ccache if available")

if(CCACHE_PROGRAM AND ZIG_USE_CCACHE)
    SET_PROPERTY(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${CCACHE_PROGRAM}")
endif()

if(ZIG_STATIC)
    set(ZIG_STATIC_LLVM ON)
    set(ZIG_STATIC_ZLIB ON)
endif()

if (ZIG_SHARED_LLVM AND ZIG_STATIC_LLVM)
    message(SEND_ERROR "-DZIG_SHARED_LLVM and -DZIG_STATIC_LLVM cannot both be enabled simultaneously")
endif()

string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_LIB_DIR_ESCAPED "${ZIG_LIBC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_STATIC_LIB_DIR_ESCAPED "${ZIG_LIBC_STATIC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_INCLUDE_DIR_ESCAPED "${ZIG_LIBC_INCLUDE_DIR}")

option(ZIG_TEST_COVERAGE "Build Zig with test coverage instrumentation" OFF)

set(ZIG_TARGET_TRIPLE "native" CACHE STRING "arch-os-abi to output binaries for")
set(ZIG_TARGET_MCPU "baseline" CACHE STRING "-mcpu parameter to output binaries for")
set(ZIG_EXECUTABLE "" CACHE STRING "(when cross compiling) path to already-built zig binary")
set(ZIG_SINGLE_THREADED off CACHE BOOL "limit the zig compiler to use only 1 thread")
set(ZIG_OMIT_STAGE2 off CACHE BOOL "omit the stage2 backend from stage1")

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(ZIG_ENABLE_LOGGING ON CACHE BOOL "enable logging")
else()
    set(ZIG_ENABLE_LOGGING OFF CACHE BOOL "enable logging")
endif()

if("${ZIG_TARGET_TRIPLE}" STREQUAL "native")
    set(ZIG_USE_LLVM_CONFIG ON CACHE BOOL "use llvm-config to find LLVM libraries")
else()
    set(ZIG_USE_LLVM_CONFIG OFF CACHE BOOL "use llvm-config to find LLVM libraries")
endif()

find_package(llvm 15)
find_package(clang 15)
find_package(lld 15)

if(ZIG_STATIC_ZLIB)
    list(REMOVE_ITEM LLVM_LIBRARIES "-lz")
    find_library(ZLIB NAMES libz.a libzlibstatic.a z zlib libz NAMES_PER_DIR)
    list(APPEND LLVM_LIBRARIES "${ZLIB}")
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
endforeach(CONFIG_TYPE CMAKE_CONFIGURATION_TYPES)

include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${LLD_INCLUDE_DIRS})
include_directories(${CLANG_INCLUDE_DIRS})

# No patches have been applied to SoftFloat-3e
set(EMBEDDED_SOFTFLOAT_SOURCES
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/f128M_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/extF80M_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF16UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF32UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF64UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f128MToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_extF80MToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f16UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f32UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f64UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_propagateNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_propagateNaNExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_propagateNaNF16UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/softfloat_raiseFlags.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_add.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_div.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_eq.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_eq_signaling.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_le.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_le_quiet.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_lt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_lt_quiet.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_mul.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_rem.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_roundToInt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_sqrt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_sub.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_f16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_f32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_f64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_extF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i64_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui64_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_add.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_div.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_eq.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_le.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_lt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_mul.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_rem.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_roundToInt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_sqrt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_sub.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_to_f16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_to_f32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_to_f64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/extF80M_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_add.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_div.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_eq.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_lt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_mul.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_rem.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_roundToInt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_sqrt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_sub.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_to_extF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_to_f64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f32_to_extF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_extF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_f16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/i32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_add256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addComplCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addMagsF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addMagsF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addMagsF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecip32_1.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecipSqrt32_1.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecipSqrt_1Ks.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_approxRecip_1Ks.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_compare128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_compare96M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_compareNonnormExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros8.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_eq128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_invalidF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_invalidExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_isNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_le128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_lt128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mul128MTo256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mul64To128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_mulAddF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_negXM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normExtF80SigM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackMToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackMToExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackToF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackToF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackToF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF128SigM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF16Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF32Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normSubnormalF64Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_remStepMBy32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundMToI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundMToUI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackMToExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackMToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackToF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackToF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundPackToF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToI32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToUI32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_roundToUI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftLeftM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftNormSigF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJam256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJam32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJam64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightJamM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shiftRightM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftLeft64To96M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftLeftM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightExtendM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightJam64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightJamM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_shortShiftRightM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_sub1XM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_sub256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subMagsF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subMagsF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_subMagsF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_tryPropagateNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_tryPropagateNaNExtF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/softfloat_state.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui64_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui32_to_extF80M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui64_to_extF80M.c"
)
add_library(embedded_softfloat STATIC ${EMBEDDED_SOFTFLOAT_SOURCES})
if(MSVC)
    set(SOFTFLOAT_CFLAGS "/w")

    if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
        set(SOFTFLOAT_CFLAGS "${SOFTFLOAT_CFLAGS} /O2")
    endif()

    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS ${SOFTFLOAT_CFLAGS}
    )
else()
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "-std=c99 -O3"
    )
endif()
target_include_directories(embedded_softfloat PUBLIC
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e-prebuilt"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086"
)
include_directories("${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/include")
set(SOFTFLOAT_LIBRARIES embedded_softfloat)

find_package(Threads)

set(ZIG_LIB_DIR "lib/zig")
set(C_HEADERS_DEST "${ZIG_LIB_DIR}/include")
set(LIBC_FILES_DEST "${ZIG_LIB_DIR}/libc")
set(LIBUNWIND_FILES_DEST "${ZIG_LIB_DIR}/libunwind")
set(LIBCXX_FILES_DEST "${ZIG_LIB_DIR}/libcxx")
set(ZIG_STD_DEST "${ZIG_LIB_DIR}/std")
set(ZIG_CONFIG_H_OUT "${CMAKE_BINARY_DIR}/config.h")
set(ZIG_CONFIG_ZIG_OUT "${CMAKE_BINARY_DIR}/config.zig")

# This is our shim which will be replaced by stage1.zig.
set(ZIG1_SOURCES
    "${CMAKE_SOURCE_DIR}/src/stage1/zig0.cpp"
)

set(STAGE1_SOURCES
    "${CMAKE_SOURCE_DIR}/src/stage1/analyze.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/astgen.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/bigfloat.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/bigint.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/buffer.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/codegen.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/errmsg.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/error.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/heap.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/ir.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/ir_print.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/mem.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/os.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/parser.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/range_set.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/softfloat_ext.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/stage1.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/target.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/tokenizer.cpp"
    "${CMAKE_SOURCE_DIR}/src/stage1/util.cpp"
)
set(OPTIMIZED_C_SOURCES
    "${CMAKE_SOURCE_DIR}/src/stage1/parse_f128.c"
)
set(ZIG_CPP_SOURCES
    # These are planned to stay even when we are self-hosted.
    "${CMAKE_SOURCE_DIR}/src/zig_llvm.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_llvm-ar.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_driver.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1_main.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1as_main.cpp"
    # https://github.com/ziglang/zig/issues/6363
    "${CMAKE_SOURCE_DIR}/src/windows_sdk.cpp"
)
# Needed because we use cmake, not the zig build system, to build zig2.o.
# This list is generated by building zig and then clearing the zig-cache directory,
# then manually running the build-obj command (see BUILD_ZIG2_ARGS), and then looking
# in the zig-cache directory for the compiler-generated list of zig file dependencies.
set(ZIG_STAGE2_SOURCES
    "${ZIG_CONFIG_ZIG_OUT}"
    "${CMAKE_SOURCE_DIR}/lib/std/array_hash_map.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/array_list.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/ascii.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/atomic.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/atomic/Atomic.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/atomic/queue.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/atomic/stack.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/base64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/buf_map.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/builtin.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/c.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/c/linux.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/c/tokenizer.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/child_process.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/coff.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/comptime_string_map.zig"
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
    "${CMAKE_SOURCE_DIR}/lib/std/event.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/event/batch.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/event/loop.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fifo.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt/errol.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt/errol/enum3.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt/errol/lookup.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fmt/parse_float.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/fs/file.zig"
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
    "${CMAKE_SOURCE_DIR}/lib/std/io/reader.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/seekable_stream.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/io/writer.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/json.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/json/write_stream.zig"
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
    "${CMAKE_SOURCE_DIR}/lib/std/math/ln.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/log.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/log10.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/log2.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/nan.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/signbit.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/math/sqrt.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/mem.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/mem/Allocator.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/meta.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/meta/trailer_flags.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/meta/trait.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/multi_array_list.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/darwin.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/errno/generic.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/x86_64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/io_uring.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/linux/x86_64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/posix_spawn.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/windows.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/windows/ntstatus.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/os/windows/win32error.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Progress.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/pdb.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/process.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/rand.zig"
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
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/float_to_int.zig"
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
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/int_to_float.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/log.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/log10.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/log2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/modti3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/muldf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/muldi3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulo.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/mulsf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/multf3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/multi3.zig"
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
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/udivmodti4.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/udivti3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/umodti3.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/unorddf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/unordsf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/compiler_rt/unordtf2.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/start.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/std.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/aarch64.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/amdgpu.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/arm.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/avr.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/bpf.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/hexagon.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/mips.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/msp430.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/nvptx.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/powerpc.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/riscv.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/sparc.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/s390x.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/wasm.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/target/x86.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/Futex.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/Mutex.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/Thread/ResetEvent.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/time.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/treap.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/unicode.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/Ast.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/CrossTarget.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/c_builtins.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/parse.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/render.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/string_literal.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/system.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/system/NativePaths.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/system/NativeTargetInfo.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/system/x86.zig"
    "${CMAKE_SOURCE_DIR}/lib/std/zig/tokenizer.zig"
    "${CMAKE_SOURCE_DIR}/src/Air.zig"
    "${CMAKE_SOURCE_DIR}/src/AstGen.zig"
    "${CMAKE_SOURCE_DIR}/src/Cache.zig"
    "${CMAKE_SOURCE_DIR}/src/Compilation.zig"
    "${CMAKE_SOURCE_DIR}/src/DepTokenizer.zig"
    "${CMAKE_SOURCE_DIR}/src/Liveness.zig"
    "${CMAKE_SOURCE_DIR}/src/Module.zig"
    "${CMAKE_SOURCE_DIR}/src/Package.zig"
    "${CMAKE_SOURCE_DIR}/src/RangeSet.zig"
    "${CMAKE_SOURCE_DIR}/src/Sema.zig"
    "${CMAKE_SOURCE_DIR}/src/ThreadPool.zig"
    "${CMAKE_SOURCE_DIR}/src/TypedValue.zig"
    "${CMAKE_SOURCE_DIR}/src/WaitGroup.zig"
    "${CMAKE_SOURCE_DIR}/src/Zir.zig"
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
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/Emit.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/Mir.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/bits.zig"
    "${CMAKE_SOURCE_DIR}/src/arch/x86_64/abi.zig"
    "${CMAKE_SOURCE_DIR}/src/clang.zig"
    "${CMAKE_SOURCE_DIR}/src/clang_options.zig"
    "${CMAKE_SOURCE_DIR}/src/clang_options_data.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen/c.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen/llvm.zig"
    "${CMAKE_SOURCE_DIR}/src/codegen/llvm/bindings.zig"
    "${CMAKE_SOURCE_DIR}/src/glibc.zig"
    "${CMAKE_SOURCE_DIR}/src/introspect.zig"
    "${CMAKE_SOURCE_DIR}/src/libc_installation.zig"
    "${CMAKE_SOURCE_DIR}/src/libcxx.zig"
    "${CMAKE_SOURCE_DIR}/src/libtsan.zig"
    "${CMAKE_SOURCE_DIR}/src/libunwind.zig"
    "${CMAKE_SOURCE_DIR}/src/link.zig"
    "${CMAKE_SOURCE_DIR}/src/link/C.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff/Atom.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff/Object.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Coff/lld.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Elf.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Archive.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Atom.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/CodeSignature.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/DebugSymbols.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Dylib.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Object.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/Trie.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/bind.zig"
    "${CMAKE_SOURCE_DIR}/src/link/MachO/dead_strip.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Plan9.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Plan9/aout.zig"
    "${CMAKE_SOURCE_DIR}/src/link/Wasm.zig"
    "${CMAKE_SOURCE_DIR}/src/link/msdos-stub.bin"
    "${CMAKE_SOURCE_DIR}/src/link/strtab.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi/Tokenizer.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi/parse.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi/parse/test.zig"
    "${CMAKE_SOURCE_DIR}/src/link/tapi/yaml.zig"
    "${CMAKE_SOURCE_DIR}/src/main.zig"
    "${CMAKE_SOURCE_DIR}/src/mingw.zig"
    "${CMAKE_SOURCE_DIR}/src/musl.zig"
    "${CMAKE_SOURCE_DIR}/src/print_air.zig"
    "${CMAKE_SOURCE_DIR}/src/print_env.zig"
    "${CMAKE_SOURCE_DIR}/src/print_targets.zig"
    "${CMAKE_SOURCE_DIR}/src/print_zir.zig"
    "${CMAKE_SOURCE_DIR}/src/register_manager.zig"
    "${CMAKE_SOURCE_DIR}/src/stage1.zig"
    "${CMAKE_SOURCE_DIR}/src/target.zig"
    "${CMAKE_SOURCE_DIR}/src/tracy.zig"
    "${CMAKE_SOURCE_DIR}/src/translate_c.zig"
    "${CMAKE_SOURCE_DIR}/src/translate_c/ast.zig"
    "${CMAKE_SOURCE_DIR}/src/type.zig"
    "${CMAKE_SOURCE_DIR}/src/value.zig"
    "${CMAKE_SOURCE_DIR}/src/wasi_libc.zig"
    "${CMAKE_SOURCE_DIR}/src/windows_sdk.zig"
)

if(MSVC)
    set(MSVC_DIA_SDK_DIR "$ENV{VSINSTALLDIR}DIA SDK")
    if(IS_DIRECTORY ${MSVC_DIA_SDK_DIR})
        set(ZIG_DIA_GUIDS_LIB "${MSVC_DIA_SDK_DIR}/lib/amd64/diaguids.lib")
        string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_DIA_GUIDS_LIB_ESCAPED "${ZIG_DIA_GUIDS_LIB}")
    endif()
endif()

if(ZIG_OMIT_STAGE2)
  set(ZIG_OMIT_STAGE2_BOOL "true")
else()
  set(ZIG_OMIT_STAGE2_BOOL "false")
endif()

if(ZIG_ENABLE_LOGGING)
  set(ZIG_ENABLE_LOGGING_BOOL "true")
else()
  set(ZIG_ENABLE_LOGGING_BOOL "false")
endif()

configure_file (
    "${CMAKE_SOURCE_DIR}/src/stage1/config.h.in"
    "${ZIG_CONFIG_H_OUT}"
)
configure_file (
    "${CMAKE_SOURCE_DIR}/src/config.zig.in"
    "${ZIG_CONFIG_ZIG_OUT}"
)

include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
    "${CMAKE_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/src/stage1"
)

# These have to go before the -Wno- flags
if(MSVC)
  set(EXE_CFLAGS "/std:c++14")
else(MSVC)
  set(EXE_CFLAGS "-std=c++14")
endif(MSVC)

if(ZIG_STATIC)
    set(EXE_CFLAGS "${EXE_CFLAGS} -DZIG_LINK_MODE=Static")
else()
    set(EXE_CFLAGS "${EXE_CFLAGS} -DZIG_LINK_MODE=Dynamic")
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    if(MSVC)
        set(EXE_CFLAGS "${EXE_CFLAGS} /w")
    else()
        set(EXE_CFLAGS "${EXE_CFLAGS} -Werror -Wall")
        # fallthrough support was added in GCC 7.0
        if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 7.0)
            set(EXE_CFLAGS "${EXE_CFLAGS} -Werror=implicit-fallthrough")
        endif()
        # GCC 9.2 and older are unable to detect valid variable initialization in some cases
        if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS_EQUAL 9.2)
            set(EXE_CFLAGS "${EXE_CFLAGS} -Wno-maybe-uninitialized")
        endif()
    endif()
endif()

if(MSVC)
    set(EXE_CFLAGS "${EXE_CFLAGS}")
else()
    set(EXE_CFLAGS "${EXE_CFLAGS} -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -D_GNU_SOURCE -fvisibility-inlines-hidden -fno-exceptions -fno-rtti -Werror=type-limits -Wno-missing-braces -Wno-comment")
    if(MINGW)
        set(EXE_CFLAGS "${EXE_CFLAGS} -Wno-format")
    endif()
endif()

if(MSVC)
  if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(OPTIMIZED_C_FLAGS "/O2")
  endif()
else(MSVC)
  set(OPTIMIZED_C_FLAGS "-std=c99 -O3")
endif(MSVC)

set(EXE_LDFLAGS " ")
if(MSVC)
    set(EXE_LDFLAGS "${EXE_LDFLAGS} /STACK:16777216")
    if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Release" AND NOT "${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")
        set(EXE_LDFLAGS "${EXE_LDFLAGS} /debug:fastlink")
    endif()
elseif(MINGW)
    set(EXE_LDFLAGS "${EXE_LDFLAGS} -Wl,--stack,16777216")
endif()

if(ZIG_STATIC)
    if(APPLE)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static-libgcc -static-libstdc++")
    elseif(MINGW)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static-libgcc -static-libstdc++ -Wl,-Bstatic, -lwinpthread -lz3 -lz -lgomp")
    elseif(NOT MSVC)
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -static")
    endif()
else()
    if(MINGW)
        set(EXE_LDFLAGS "${EXE_LDFLAGS}")
    endif()
endif()

if(ZIG_TEST_COVERAGE)
    set(EXE_CFLAGS "${EXE_CFLAGS} -fprofile-arcs -ftest-coverage")
    set(EXE_LDFLAGS "${EXE_LDFLAGS} -fprofile-arcs -ftest-coverage")
endif()

add_library(zigcpp STATIC ${ZIG_CPP_SOURCES})
set_target_properties(zigcpp PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
)

target_link_libraries(zigcpp LINK_PUBLIC
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)

add_library(opt_c_util STATIC ${OPTIMIZED_C_SOURCES})
set_target_properties(opt_c_util PROPERTIES
    COMPILE_FLAGS "${OPTIMIZED_C_FLAGS}"
)
target_include_directories(opt_c_util PRIVATE
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e-prebuilt"
)

add_library(zigstage1 STATIC ${STAGE1_SOURCES})
set_target_properties(zigstage1 PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zigstage1 LINK_PUBLIC
    opt_c_util
    ${SOFTFLOAT_LIBRARIES}
    zigcpp
)
if(NOT MSVC)
    target_link_libraries(zigstage1 LINK_PUBLIC ${LIBXML2})
endif()

if(ZIG_DIA_GUIDS_LIB)
    target_link_libraries(zigstage1 LINK_PUBLIC ${ZIG_DIA_GUIDS_LIB})
endif()

if(MSVC OR MINGW)
    target_link_libraries(zigstage1 LINK_PUBLIC version)
endif()

if("${ZIG_EXECUTABLE}" STREQUAL "")
  add_executable(zig1 ${ZIG1_SOURCES})
  set_target_properties(zig1 PROPERTIES
      COMPILE_FLAGS ${EXE_CFLAGS}
      LINK_FLAGS ${EXE_LDFLAGS}
  )
  target_link_libraries(zig1 zigstage1)
endif()

if(MSVC)
  set(ZIG2_OBJECT "${CMAKE_BINARY_DIR}/zig2.obj")
else()
  set(ZIG2_OBJECT "${CMAKE_BINARY_DIR}/zig2.o")
endif()
if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  set(ZIG_RELEASE_ARG "")
elseif("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
  set(ZIG_RELEASE_ARG -Drelease)
else()
  set(ZIG_RELEASE_ARG -Drelease -Dstrip)
endif()
if(ZIG_SKIP_INSTALL_LIB_FILES)
  set(ZIG_SKIP_INSTALL_LIB_FILES_ARG "-Dskip-install-lib-files")
else()
  set(ZIG_SKIP_INSTALL_LIB_FILES_ARG "-Dskip-install-lib-files=false")
endif()
if(ZIG_SINGLE_THREADED)
  set(ZIG_SINGLE_THREADED_ARG "-fsingle-threaded")
else()
  set(ZIG_SINGLE_THREADED_ARG "")
endif()
if(ZIG_STATIC)
  set(ZIG_STATIC_ARG "-Duse-zig-libcxx")
else()
  set(ZIG_STATIC_ARG "")
endif()

set(BUILD_ZIG2_ARGS
    "src/stage1.zig"
    --name zig2
    --zig-lib-dir "${CMAKE_SOURCE_DIR}/lib"
    "-femit-bin=${ZIG2_OBJECT}"
    -fcompiler-rt
    ${ZIG_SINGLE_THREADED_ARG}
    -target "${ZIG_TARGET_TRIPLE}"
    -mcpu "${ZIG_TARGET_MCPU}"
    -lc
    --pkg-begin build_options "${ZIG_CONFIG_ZIG_OUT}"
    --pkg-end
    --pkg-begin compiler_rt "${CMAKE_SOURCE_DIR}/lib/compiler_rt.zig"
    --pkg-end
)

if("${ZIG_EXECUTABLE}" STREQUAL "")
  add_custom_command(
    OUTPUT "${ZIG2_OBJECT}"
    COMMAND zig1 ${BUILD_ZIG2_ARGS}
    DEPENDS zig1 "${ZIG_STAGE2_SOURCES}"
    COMMENT STATUS "Building stage2 object ${ZIG2_OBJECT}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  )
  if (WIN32)
    set(ZIG_EXECUTABLE "${zig2_BINARY_DIR}/zig2.exe")
  else()
    set(ZIG_EXECUTABLE "${zig2_BINARY_DIR}/zig2")
  endif()
else()
  add_custom_command(
    OUTPUT "${ZIG2_OBJECT}"
    COMMAND "${ZIG_EXECUTABLE}" "build-obj" ${BUILD_ZIG2_ARGS}
    DEPENDS ${ZIG_STAGE2_SOURCES}
    COMMENT STATUS "Building stage2 component ${ZIG2_OBJECT}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  )
endif()

# cmake won't let us configure an executable without C sources.
add_executable(zig2 "${CMAKE_SOURCE_DIR}/src/stage1/empty.cpp" "${ZIG2_OBJECT}")

set_target_properties(zig2 PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zig2 zigstage1)
if(MSVC)
  target_link_libraries(zig2 ntdll.lib)
elseif(MINGW)
  target_link_libraries(zig2 ntdll)
endif()

# Dummy install command so that the "install" target is not missing.
# This is redundant from the "stage3" custom target below.
if(NOT ZIG_SKIP_INSTALL_LIB_FILES)
  install(FILES "lib/compiler_rt.zig" DESTINATION "lib/zig")
endif()

set(ZIG_INSTALL_ARGS "build"
    --zig-lib-dir "${CMAKE_SOURCE_DIR}/lib"
    --prefix "${CMAKE_INSTALL_PREFIX}"
    "-Dconfig_h=${ZIG_CONFIG_H_OUT}"
    "-Denable-llvm"
    "-Denable-stage1"
    ${ZIG_RELEASE_ARG}
    ${ZIG_STATIC_ARG}
    ${ZIG_SKIP_INSTALL_LIB_FILES_ARG}
    ${ZIG_SINGLE_THREADED_ARG}
    "-Dtarget=${ZIG_TARGET_TRIPLE}"
    "-Dcpu=${ZIG_TARGET_MCPU}"
    "-Dversion-string=${ZIG_VERSION}"
)

add_custom_target(stage3 ALL
    COMMAND zig2 ${ZIG_INSTALL_ARGS}
    DEPENDS zig2
    COMMENT STATUS "Building stage3"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)
