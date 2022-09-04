cmake_minimum_required(VERSION 3.15)

set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 10)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "" CACHE STRING "Override Zig version string. Default is to find out with git.")

if("${ZIG_VERSION}" STREQUAL "")
    set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")
    find_program(GIT_EXE NAMES git NAMES_PER_DIR)
    if(GIT_EXE AND EXISTS "${CMAKE_SOURCE_DIR}/.git")
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
                if(ZIG_VERSION VERSION_LESS_EQUAL GIT_TAG)
                    message(SEND_ERROR "Zig version (${ZIG_VERSION}) must be greater than tagged ancestor (${GIT_TAG}).")
                endif()
                set(ZIG_VERSION "${ZIG_VERSION}-dev.${GIT_COMMITS_AFTER_TAG}+${GIT_COMMIT}")
            else()
                message(WARNING "Failed to parse version from output of `git describe`.")
            endif()
        endif()
    endif()
endif()

project(zig
  VERSION
    "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}"
  DESCRIPTION
    "Zig is a general-purpose programming language and toolchain for maintaining robust, optimal and reusable software"
  HOMEPAGE_URL
    "https://ziglang.org"
  LANGUAGES
    C CXX
)

set(CMAKE_USER_MAKE_RULES_OVERRIDE "${PROJECT_SOURCE_DIR}/cmake/c_flag_overrides.cmake")
set(CMAKE_USER_MAKE_RULES_OVERRIDE_CXX "${PROJECT_SOURCE_DIR}/cmake/cxx_flag_overrides.cmake")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: Debug, Release, RelWithDebInfo, MinSizeRel" FORCE)
endif()

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${PROJECT_BINARY_DIR}/stage3" CACHE PATH "Install directory for Zig" FORCE)
endif()

set(ZIG_TARGET_TRIPLE "native" CACHE STRING "The CPU architecture, OS, and ABI to build for")
set(ZIG_TARGET_MCPU "baseline" CACHE STRING "The target CPU and feature set")
set(ZIG_LLVM "auto" CACHE STRING "Select shared or static linking of LLVM libraries, options are: shared, static, auto")
set(ZIG_LLVM_POSSIBLE_MODE "shared" "static" "auto")
set_property(CACHE ZIG_LLVM PROPERTY STRINGS ${ZIG_LLVM_POSSIBLE_MODE})
if(NOT ZIG_LLVM IN_LIST ZIG_LLVM_POSSIBLE_MODE)
  message(FATAL_ERROR "ZIG_LLVM must be one of ${ZIG_LLVM_POSSIBLE_MODE}")
endif()

set(ZIG_EXECUTABLE "" CACHE FILEPATH "(when cross compiling) path to already-built Zig binary")

option(ZIG_SKIP_INSTALL_LIB_FILES "Skip installing lib/ files" OFF)
option(ZIG_SINGLE_THREADED "Limit the zig compiler to use only 1 thread" OFF)
option(ZIG_STATIC "Attempt to build a static Zig executable (not compatible with glibc)" OFF)
option(ZIG_STATIC_ZLIB "Prefer linking against static zlib" OFF)

set(ZIG_CONFIG_H_OUT "${PROJECT_BINARY_DIR}/config.h")  # See https://github.com/ziglang/zig/issues/12685
set(ZIG_CONFIG_ZIG_OUT "${PROJECT_BINARY_DIR}/config.zig")

if(ZIG_STATIC)
    set(ZIG_LLVM "static")
    set(ZIG_STATIC_ZLIB ON)
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    option(ZIG_ENABLE_LOGGING "Enable logging" ON)
else()
    option(ZIG_ENABLE_LOGGING "Enable logging" OFF)
endif()

if("${ZIG_TARGET_TRIPLE}" STREQUAL "native")
    option(ZIG_USE_LLVM_CONFIG "Use llvm-config to find LLVM libraries" ON)
else()
    option(ZIG_USE_LLVM_CONFIG "Use llvm-config to find LLVM libraries" OFF)
endif()

# Install libraries to zigcpp

set(ZIG_CPP_LIB_DIR "${PROJECT_BINARY_DIR}/zigcpp")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${ZIG_CPP_LIB_DIR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${ZIG_CPP_LIB_DIR}")
# Handle multi-config builds and place each into a common lib. The VS generator
# for example will append a Debug folder by default if not explicitly specified.
foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG_TYPE} CONFIG_TYPE)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_TYPE} "${ZIG_CPP_LIB_DIR}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CONFIG_TYPE} "${ZIG_CPP_LIB_DIR}")
endforeach(CONFIG_TYPE CMAKE_CONFIGURATION_TYPES)

# embedded_softfloat library

add_subdirectory("deps")

# opt_c_util library

add_library(opt_c_util STATIC "src/stage1/parse_f128.c")
target_compile_features(opt_c_util PUBLIC c_std_99)
if(MSVC)
    target_compile_options(opt_c_util PRIVATE "/02")
else()
    target_compile_options(opt_c_util PRIVATE "-O3")
endif()
target_link_libraries(opt_c_util LINK_PUBLIC embedded_softfloat)

set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})
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

find_package(Threads)

set(ZIG_CPP_SOURCES
    # These are planned to stay even when we are self-hosted.
    "src/zig_llvm.cpp"
    "src/zig_llvm-ar.cpp"
    "src/zig_clang.cpp"
    "src/zig_clang_driver.cpp"
    "src/zig_clang_cc1_main.cpp"
    "src/zig_clang_cc1as_main.cpp"
    # https://github.com/ziglang/zig/issues/6363
    "src/windows_sdk.cpp"
)
# Needed because we use cmake, not the zig build system, to build zig2.o.
# This list is generated by building zig and then clearing the zig-cache directory,
# then manually running the build-obj command (see BUILD_ZIG2_ARGS), and then looking
# in the zig-cache directory for the compiler-generated list of zig file dependencies.
set(ZIG_STAGE2_SOURCES
    "${ZIG_CONFIG_ZIG_OUT}"
    "lib/std/array_hash_map.zig"
    "lib/std/array_list.zig"
    "lib/std/ascii.zig"
    "lib/std/atomic.zig"
    "lib/std/atomic/Atomic.zig"
    "lib/std/atomic/queue.zig"
    "lib/std/atomic/stack.zig"
    "lib/std/base64.zig"
    "lib/std/buf_map.zig"
    "lib/std/builtin.zig"
    "lib/std/c.zig"
    "lib/std/c/linux.zig"
    "lib/std/c/tokenizer.zig"
    "lib/std/child_process.zig"
    "lib/std/coff.zig"
    "lib/std/comptime_string_map.zig"
    "lib/std/crypto.zig"
    "lib/std/crypto/blake3.zig"
    "lib/std/crypto/siphash.zig"
    "lib/std/debug.zig"
    "lib/std/dwarf.zig"
    "lib/std/dwarf/AT.zig"
    "lib/std/dwarf/ATE.zig"
    "lib/std/dwarf/FORM.zig"
    "lib/std/dwarf/LANG.zig"
    "lib/std/dwarf/OP.zig"
    "lib/std/dwarf/TAG.zig"
    "lib/std/elf.zig"
    "lib/std/event.zig"
    "lib/std/event/batch.zig"
    "lib/std/event/loop.zig"
    "lib/std/fifo.zig"
    "lib/std/fmt.zig"
    "lib/std/fmt/errol.zig"
    "lib/std/fmt/errol/enum3.zig"
    "lib/std/fmt/errol/lookup.zig"
    "lib/std/fmt/parse_float.zig"
    "lib/std/fs.zig"
    "lib/std/fs/file.zig"
    "lib/std/fs/get_app_data_dir.zig"
    "lib/std/fs/path.zig"
    "lib/std/hash.zig"
    "lib/std/hash/auto_hash.zig"
    "lib/std/hash/wyhash.zig"
    "lib/std/hash_map.zig"
    "lib/std/heap.zig"
    "lib/std/heap/arena_allocator.zig"
    "lib/std/io.zig"
    "lib/std/io/buffered_atomic_file.zig"
    "lib/std/io/buffered_writer.zig"
    "lib/std/io/change_detection_stream.zig"
    "lib/std/io/counting_reader.zig"
    "lib/std/io/counting_writer.zig"
    "lib/std/io/find_byte_writer.zig"
    "lib/std/io/fixed_buffer_stream.zig"
    "lib/std/io/limited_reader.zig"
    "lib/std/io/reader.zig"
    "lib/std/io/seekable_stream.zig"
    "lib/std/io/writer.zig"
    "lib/std/json.zig"
    "lib/std/json/write_stream.zig"
    "lib/std/leb128.zig"
    "lib/std/linked_list.zig"
    "lib/std/log.zig"
    "lib/std/macho.zig"
    "lib/std/math.zig"
    "lib/std/math/big.zig"
    "lib/std/math/big/int.zig"
    "lib/std/math/float.zig"
    "lib/std/math/frexp.zig"
    "lib/std/math/isinf.zig"
    "lib/std/math/isnan.zig"
    "lib/std/math/ln.zig"
    "lib/std/math/log.zig"
    "lib/std/math/log10.zig"
    "lib/std/math/log2.zig"
    "lib/std/math/nan.zig"
    "lib/std/math/signbit.zig"
    "lib/std/math/sqrt.zig"
    "lib/std/mem.zig"
    "lib/std/mem/Allocator.zig"
    "lib/std/meta.zig"
    "lib/std/meta/trailer_flags.zig"
    "lib/std/meta/trait.zig"
    "lib/std/multi_array_list.zig"
    "lib/std/os.zig"
    "lib/std/os/darwin.zig"
    "lib/std/os/linux.zig"
    "lib/std/os/linux/errno/generic.zig"
    "lib/std/os/linux/x86_64.zig"
    "lib/std/os/linux.zig"
    "lib/std/os/linux/io_uring.zig"
    "lib/std/os/linux/x86_64.zig"
    "lib/std/os/posix_spawn.zig"
    "lib/std/os/windows.zig"
    "lib/std/os/windows/ntstatus.zig"
    "lib/std/os/windows/win32error.zig"
    "lib/std/Progress.zig"
    "lib/std/pdb.zig"
    "lib/std/process.zig"
    "lib/std/rand.zig"
    "lib/std/sort.zig"
    "lib/compiler_rt.zig"
    "lib/compiler_rt/absv.zig"
    "lib/compiler_rt/absvdi2.zig"
    "lib/compiler_rt/absvsi2.zig"
    "lib/compiler_rt/absvti2.zig"
    "lib/compiler_rt/adddf3.zig"
    "lib/compiler_rt/addf3.zig"
    "lib/compiler_rt/addo.zig"
    "lib/compiler_rt/addsf3.zig"
    "lib/compiler_rt/addtf3.zig"
    "lib/compiler_rt/addxf3.zig"
    "lib/compiler_rt/arm.zig"
    "lib/compiler_rt/atomics.zig"
    "lib/compiler_rt/aulldiv.zig"
    "lib/compiler_rt/aullrem.zig"
    "lib/compiler_rt/bswap.zig"
    "lib/compiler_rt/ceil.zig"
    "lib/compiler_rt/clear_cache.zig"
    "lib/compiler_rt/cmp.zig"
    "lib/compiler_rt/cmpdf2.zig"
    "lib/compiler_rt/cmpsf2.zig"
    "lib/compiler_rt/cmptf2.zig"
    "lib/compiler_rt/cmpxf2.zig"
    "lib/compiler_rt/common.zig"
    "lib/compiler_rt/comparef.zig"
    "lib/compiler_rt/cos.zig"
    "lib/compiler_rt/count0bits.zig"
    "lib/compiler_rt/divdf3.zig"
    "lib/compiler_rt/divsf3.zig"
    "lib/compiler_rt/divtf3.zig"
    "lib/compiler_rt/divti3.zig"
    "lib/compiler_rt/divxf3.zig"
    "lib/compiler_rt/emutls.zig"
    "lib/compiler_rt/exp.zig"
    "lib/compiler_rt/exp2.zig"
    "lib/compiler_rt/extenddftf2.zig"
    "lib/compiler_rt/extenddfxf2.zig"
    "lib/compiler_rt/extendf.zig"
    "lib/compiler_rt/extendhfsf2.zig"
    "lib/compiler_rt/extendhftf2.zig"
    "lib/compiler_rt/extendhfxf2.zig"
    "lib/compiler_rt/extendsfdf2.zig"
    "lib/compiler_rt/extendsftf2.zig"
    "lib/compiler_rt/extendsfxf2.zig"
    "lib/compiler_rt/extendxftf2.zig"
    "lib/compiler_rt/fabs.zig"
    "lib/compiler_rt/fixdfdi.zig"
    "lib/compiler_rt/fixdfsi.zig"
    "lib/compiler_rt/fixdfti.zig"
    "lib/compiler_rt/fixhfdi.zig"
    "lib/compiler_rt/fixhfsi.zig"
    "lib/compiler_rt/fixhfti.zig"
    "lib/compiler_rt/fixsfdi.zig"
    "lib/compiler_rt/fixsfsi.zig"
    "lib/compiler_rt/fixsfti.zig"
    "lib/compiler_rt/fixtfdi.zig"
    "lib/compiler_rt/fixtfsi.zig"
    "lib/compiler_rt/fixtfti.zig"
    "lib/compiler_rt/fixunsdfdi.zig"
    "lib/compiler_rt/fixunsdfsi.zig"
    "lib/compiler_rt/fixunsdfti.zig"
    "lib/compiler_rt/fixunshfdi.zig"
    "lib/compiler_rt/fixunshfsi.zig"
    "lib/compiler_rt/fixunshfti.zig"
    "lib/compiler_rt/fixunssfdi.zig"
    "lib/compiler_rt/fixunssfsi.zig"
    "lib/compiler_rt/fixunssfti.zig"
    "lib/compiler_rt/fixunstfdi.zig"
    "lib/compiler_rt/fixunstfsi.zig"
    "lib/compiler_rt/fixunstfti.zig"
    "lib/compiler_rt/fixunsxfdi.zig"
    "lib/compiler_rt/fixunsxfsi.zig"
    "lib/compiler_rt/fixunsxfti.zig"
    "lib/compiler_rt/fixxfdi.zig"
    "lib/compiler_rt/fixxfsi.zig"
    "lib/compiler_rt/fixxfti.zig"
    "lib/compiler_rt/float_to_int.zig"
    "lib/compiler_rt/floatdidf.zig"
    "lib/compiler_rt/floatdihf.zig"
    "lib/compiler_rt/floatdisf.zig"
    "lib/compiler_rt/floatditf.zig"
    "lib/compiler_rt/floatdixf.zig"
    "lib/compiler_rt/floatsidf.zig"
    "lib/compiler_rt/floatsihf.zig"
    "lib/compiler_rt/floatsisf.zig"
    "lib/compiler_rt/floatsitf.zig"
    "lib/compiler_rt/floatsixf.zig"
    "lib/compiler_rt/floattidf.zig"
    "lib/compiler_rt/floattihf.zig"
    "lib/compiler_rt/floattisf.zig"
    "lib/compiler_rt/floattitf.zig"
    "lib/compiler_rt/floattixf.zig"
    "lib/compiler_rt/floatundidf.zig"
    "lib/compiler_rt/floatundihf.zig"
    "lib/compiler_rt/floatundisf.zig"
    "lib/compiler_rt/floatunditf.zig"
    "lib/compiler_rt/floatundixf.zig"
    "lib/compiler_rt/floatunsidf.zig"
    "lib/compiler_rt/floatunsihf.zig"
    "lib/compiler_rt/floatunsisf.zig"
    "lib/compiler_rt/floatunsitf.zig"
    "lib/compiler_rt/floatunsixf.zig"
    "lib/compiler_rt/floatuntidf.zig"
    "lib/compiler_rt/floatuntihf.zig"
    "lib/compiler_rt/floatuntisf.zig"
    "lib/compiler_rt/floatuntitf.zig"
    "lib/compiler_rt/floatuntixf.zig"
    "lib/compiler_rt/floor.zig"
    "lib/compiler_rt/fma.zig"
    "lib/compiler_rt/fmax.zig"
    "lib/compiler_rt/fmin.zig"
    "lib/compiler_rt/fmod.zig"
    "lib/compiler_rt/gedf2.zig"
    "lib/compiler_rt/gesf2.zig"
    "lib/compiler_rt/getf2.zig"
    "lib/compiler_rt/gexf2.zig"
    "lib/compiler_rt/int.zig"
    "lib/compiler_rt/int_to_float.zig"
    "lib/compiler_rt/log.zig"
    "lib/compiler_rt/log10.zig"
    "lib/compiler_rt/log2.zig"
    "lib/compiler_rt/modti3.zig"
    "lib/compiler_rt/muldf3.zig"
    "lib/compiler_rt/muldi3.zig"
    "lib/compiler_rt/mulf3.zig"
    "lib/compiler_rt/mulo.zig"
    "lib/compiler_rt/mulsf3.zig"
    "lib/compiler_rt/multf3.zig"
    "lib/compiler_rt/multi3.zig"
    "lib/compiler_rt/mulxf3.zig"
    "lib/compiler_rt/negXi2.zig"
    "lib/compiler_rt/negv.zig"
    "lib/compiler_rt/os_version_check.zig"
    "lib/compiler_rt/parity.zig"
    "lib/compiler_rt/popcount.zig"
    "lib/compiler_rt/rem_pio2.zig"
    "lib/compiler_rt/rem_pio2_large.zig"
    "lib/compiler_rt/rem_pio2f.zig"
    "lib/compiler_rt/round.zig"
    "lib/compiler_rt/shift.zig"
    "lib/compiler_rt/sin.zig"
    "lib/compiler_rt/sincos.zig"
    "lib/compiler_rt/sqrt.zig"
    "lib/compiler_rt/stack_probe.zig"
    "lib/compiler_rt/subo.zig"
    "lib/compiler_rt/subsf3.zig"
    "lib/compiler_rt/subdf3.zig"
    "lib/compiler_rt/subtf3.zig"
    "lib/compiler_rt/subxf3.zig"
    "lib/compiler_rt/negsf2.zig"
    "lib/compiler_rt/negdf2.zig"
    "lib/compiler_rt/negtf2.zig"
    "lib/compiler_rt/negxf2.zig"
    "lib/compiler_rt/tan.zig"
    "lib/compiler_rt/trig.zig"
    "lib/compiler_rt/trunc.zig"
    "lib/compiler_rt/truncdfhf2.zig"
    "lib/compiler_rt/truncdfsf2.zig"
    "lib/compiler_rt/truncf.zig"
    "lib/compiler_rt/truncsfhf2.zig"
    "lib/compiler_rt/trunctfdf2.zig"
    "lib/compiler_rt/trunctfhf2.zig"
    "lib/compiler_rt/trunctfsf2.zig"
    "lib/compiler_rt/trunctfxf2.zig"
    "lib/compiler_rt/truncxfdf2.zig"
    "lib/compiler_rt/truncxfhf2.zig"
    "lib/compiler_rt/truncxfsf2.zig"
    "lib/compiler_rt/udivmod.zig"
    "lib/compiler_rt/udivmodti4.zig"
    "lib/compiler_rt/udivti3.zig"
    "lib/compiler_rt/umodti3.zig"
    "lib/compiler_rt/unorddf2.zig"
    "lib/compiler_rt/unordsf2.zig"
    "lib/compiler_rt/unordtf2.zig"
    "lib/std/start.zig"
    "lib/std/std.zig"
    "lib/std/target.zig"
    "lib/std/target/aarch64.zig"
    "lib/std/target/amdgpu.zig"
    "lib/std/target/arm.zig"
    "lib/std/target/avr.zig"
    "lib/std/target/bpf.zig"
    "lib/std/target/hexagon.zig"
    "lib/std/target/mips.zig"
    "lib/std/target/msp430.zig"
    "lib/std/target/nvptx.zig"
    "lib/std/target/powerpc.zig"
    "lib/std/target/riscv.zig"
    "lib/std/target/sparc.zig"
    "lib/std/target/s390x.zig"
    "lib/std/target/wasm.zig"
    "lib/std/target/x86.zig"
    "lib/std/Thread.zig"
    "lib/std/Thread/Futex.zig"
    "lib/std/Thread/Mutex.zig"
    "lib/std/Thread/ResetEvent.zig"
    "lib/std/time.zig"
    "lib/std/treap.zig"
    "lib/std/unicode.zig"
    "lib/std/zig.zig"
    "lib/std/zig/Ast.zig"
    "lib/std/zig/CrossTarget.zig"
    "lib/std/zig/c_builtins.zig"
    "lib/std/zig/parse.zig"
    "lib/std/zig/render.zig"
    "lib/std/zig/string_literal.zig"
    "lib/std/zig/system.zig"
    "lib/std/zig/system/NativePaths.zig"
    "lib/std/zig/system/NativeTargetInfo.zig"
    "lib/std/zig/system/x86.zig"
    "lib/std/zig/tokenizer.zig"
    "src/Air.zig"
    "src/AstGen.zig"
    "src/Cache.zig"
    "src/Compilation.zig"
    "src/DepTokenizer.zig"
    "src/Liveness.zig"
    "src/Module.zig"
    "src/Package.zig"
    "src/RangeSet.zig"
    "src/Sema.zig"
    "src/ThreadPool.zig"
    "src/TypedValue.zig"
    "src/WaitGroup.zig"
    "src/Zir.zig"
    "src/arch/aarch64/CodeGen.zig"
    "src/arch/aarch64/Emit.zig"
    "src/arch/aarch64/Mir.zig"
    "src/arch/aarch64/bits.zig"
    "src/arch/aarch64/abi.zig"
    "src/arch/arm/CodeGen.zig"
    "src/arch/arm/Emit.zig"
    "src/arch/arm/Mir.zig"
    "src/arch/arm/bits.zig"
    "src/arch/arm/abi.zig"
    "src/arch/riscv64/CodeGen.zig"
    "src/arch/riscv64/Emit.zig"
    "src/arch/riscv64/Mir.zig"
    "src/arch/riscv64/bits.zig"
    "src/arch/riscv64/abi.zig"
    "src/arch/sparc64/CodeGen.zig"
    "src/arch/sparc64/Emit.zig"
    "src/arch/sparc64/Mir.zig"
    "src/arch/sparc64/bits.zig"
    "src/arch/sparc64/abi.zig"
    "src/arch/wasm/CodeGen.zig"
    "src/arch/wasm/Emit.zig"
    "src/arch/wasm/Mir.zig"
    "src/arch/x86_64/CodeGen.zig"
    "src/arch/x86_64/Emit.zig"
    "src/arch/x86_64/Mir.zig"
    "src/arch/x86_64/bits.zig"
    "src/arch/x86_64/abi.zig"
    "src/clang.zig"
    "src/clang_options.zig"
    "src/clang_options_data.zig"
    "src/codegen.zig"
    "src/codegen/c.zig"
    "src/codegen/llvm.zig"
    "src/codegen/llvm/bindings.zig"
    "src/glibc.zig"
    "src/introspect.zig"
    "src/libc_installation.zig"
    "src/libcxx.zig"
    "src/libtsan.zig"
    "src/libunwind.zig"
    "src/link.zig"
    "src/link/C.zig"
    "src/link/Coff.zig"
    "src/link/Coff/Atom.zig"
    "src/link/Coff/Object.zig"
    "src/link/Coff/lld.zig"
    "src/link/Elf.zig"
    "src/link/MachO.zig"
    "src/link/MachO/Archive.zig"
    "src/link/MachO/Atom.zig"
    "src/link/MachO/CodeSignature.zig"
    "src/link/MachO/DebugSymbols.zig"
    "src/link/MachO/Dylib.zig"
    "src/link/MachO/Object.zig"
    "src/link/MachO/Trie.zig"
    "src/link/MachO/bind.zig"
    "src/link/MachO/dead_strip.zig"
    "src/link/Plan9.zig"
    "src/link/Plan9/aout.zig"
    "src/link/Wasm.zig"
    "src/link/msdos-stub.bin"
    "src/link/strtab.zig"
    "src/link/tapi.zig"
    "src/link/tapi/Tokenizer.zig"
    "src/link/tapi/parse.zig"
    "src/link/tapi/parse/test.zig"
    "src/link/tapi/yaml.zig"
    "src/main.zig"
    "src/mingw.zig"
    "src/musl.zig"
    "src/print_air.zig"
    "src/print_env.zig"
    "src/print_targets.zig"
    "src/print_zir.zig"
    "src/register_manager.zig"
    "src/stage1.zig"
    "src/target.zig"
    "src/tracy.zig"
    "src/translate_c.zig"
    "src/translate_c/ast.zig"
    "src/type.zig"
    "src/value.zig"
    "src/wasi_libc.zig"
    "src/windows_sdk.zig"
)

if(MSVC)
    set(MSVC_DIA_SDK_DIR "$ENV{VSINSTALLDIR}DIA SDK")
    if(IS_DIRECTORY ${MSVC_DIA_SDK_DIR})
        set(ZIG_DIA_GUIDS_LIB "${MSVC_DIA_SDK_DIR}/lib/amd64/diaguids.lib")
        string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_DIA_GUIDS_LIB_ESCAPED "${ZIG_DIA_GUIDS_LIB}")
    endif()
endif()

if(ZIG_ENABLE_LOGGING)
  set(ZIG_ENABLE_LOGGING_BOOL "true")
else()
  set(ZIG_ENABLE_LOGGING_BOOL "false")
endif()

configure_file(
    src/stage1/config.h.in
    "${ZIG_CONFIG_H_OUT}"
)
configure_file(
    src/config.zig.in
    "${ZIG_CONFIG_ZIG_OUT}"
    NEWLINE_STYLE LF
)

if(ZIG_STATIC)
    set(EXE_CFLAGS -DZIG_LINK_MODE=Static)
else()
    set(EXE_CFLAGS -DZIG_LINK_MODE=Dynamic)
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    if(MSVC)
        list(APPEND EXE_CFLAGS /w)
    else()
        list(APPEND EXE_CFLAGS -Werror -Wall)
        # fallthrough support was added in GCC 7.0
        if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS_EQUAL 7.0)
            list(APPEND EXE_CFLAGS -Werror=implicit-fallthrough)
        endif()
        # GCC 9.2 and older are unable to detect valid variable initialization in some cases
        if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS_EQUAL 9.2)
            list(APPEND EXE_CFLAGS -Wno-maybe-uninitialized)
        endif()
    endif()
endif()

if(NOT MSVC)
    list(APPEND EXE_CFLAGS -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -D_GNU_SOURCE)
    list(APPEND EXE_CFLAGS -fvisibility-inlines-hidden -fno-exceptions -fno-rtti -Werror=type-limits -Wno-missing-braces -Wno-comment)
    if(MINGW)
        list(APPEND EXE_CFLAGS -Wno-format)
    endif()
endif()

if(MSVC)
    set(EXE_LDFLAGS /STACK:16777216)
    if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Release" AND NOT "${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")
        list(APPEND EXE_LDFLAGS /debug:fastlink)
    endif()
elseif(MINGW)
    set(EXE_LDFLAGS -Wl,--stack,16777216)
endif()

if(ZIG_STATIC)
    if(APPLE)
        list(APPEND EXE_LDFLAGS -static-libgcc -static-libstdc++)
    elseif(MINGW)
        list(APPEND EXE_LDFLAGS -static-libgcc -static-libstdc++ -Wl,-Bstatic, -lwinpthread -lz3 -lz -lgomp)
    elseif(NOT MSVC)
        list(APPEND EXE_LDFLAGS -static)
    endif()
endif()

if(ZIG_TEST_COVERAGE)
    list(APPEND EXE_CFLAGS -fprofile-arcs -ftest-coverage)
    list(APPEND EXE_LDFLAGS -fprofile-arcs -ftest-coverage)
endif()

# zigcpp library

add_library(zigcpp STATIC ${ZIG_CPP_SOURCES})
target_compile_features(zigcpp PUBLIC cxx_std_14)
target_compile_options(zigcpp PRIVATE ${EXE_CFLAGS})
target_link_libraries(zigcpp LINK_PUBLIC
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)
target_include_directories(zigcpp PUBLIC
    ${LLVM_INCLUDE_DIRS}
    ${LLD_INCLUDE_DIRS}
    ${CLANG_INCLUDE_DIRS}
)

# zigstage1 library

add_subdirectory("src/stage1")

set(ZIG2_OBJECT "${PROJECT_BINARY_DIR}/zig2${CMAKE_C_OUTPUT_EXTENSION}")

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  set(ZIG_RELEASE_ARG "")
elseif("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
  set(ZIG_RELEASE_ARG -Drelease)
else()
  set(ZIG_RELEASE_ARG -Drelease -Dstrip)
endif()

set(BUILD_ZIG2_ARGS
    "${PROJECT_SOURCE_DIR}/src/stage1.zig"
    --name zig2
    --zig-lib-dir "${PROJECT_SOURCE_DIR}/lib"
    "-femit-bin=${ZIG2_OBJECT}"
    -fcompiler-rt
    "$<$<BOOL:${ZIG_SINGLE_THREADED}>:-fsingle-threaded>"
    -target "${ZIG_TARGET_TRIPLE}"
    -mcpu "${ZIG_TARGET_MCPU}"
    -lc
    --pkg-begin build_options "${ZIG_CONFIG_ZIG_OUT}" --pkg-end
    --pkg-begin compiler_rt "${PROJECT_SOURCE_DIR}/lib/compiler_rt.zig" --pkg-end
)

if(ZIG_EXECUTABLE STREQUAL "")
    # This is our shim which will be replaced by stage1.zig.
  add_executable(zig1 "src/stage1/zig0.cpp")
  target_compile_features(zig1 PUBLIC cxx_std_14)
  target_compile_options(zig1 PRIVATE ${EXE_CFLAGS})
  target_link_options(zig1 PRIVATE ${EXE_LDFLAGS})
  target_link_libraries(zig1 zigstage1)

  add_custom_command(
    OUTPUT "${ZIG2_OBJECT}"
    COMMAND zig1 ${BUILD_ZIG2_ARGS}
    DEPENDS zig1 "${ZIG_STAGE2_SOURCES}"
    COMMENT STATUS "Building stage2 object ${ZIG2_OBJECT}"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
  )
else()
  add_custom_command(
    OUTPUT "${ZIG2_OBJECT}"
    COMMAND "${ZIG_EXECUTABLE}" "build-obj" ${BUILD_ZIG2_ARGS}
    DEPENDS ${ZIG_STAGE2_SOURCES}
    COMMENT STATUS "Building stage2 component ${ZIG2_OBJECT}"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
  )
endif()

# cmake won't let us configure an executable without C sources.
add_executable(zig2 "src/stage1/empty.cpp" "${ZIG2_OBJECT}")
target_compile_features(zig2 PUBLIC cxx_std_14)
target_compile_options(zig2 PRIVATE ${EXE_CFLAGS})
target_link_options(zig2 PRIVATE ${EXE_LDFLAGS})
target_link_libraries(zig2 zigstage1)
if(MSVC)
  target_link_libraries(zig2 ntdll.lib)
elseif(MINGW)
  target_link_libraries(zig2 ntdll)
endif()

if(WIN32)
  set(ZIG_EXECUTABLE "${PROJECT_BINARY_DIR}/zig2.exe")
else()
  set(ZIG_EXECUTABLE "${PROJECT_BINARY_DIR}/zig2")
endif()

set(ZIG_BUILD_ARGS "build"
    --zig-lib-dir "${PROJECT_SOURCE_DIR}/lib"
    "-Dconfig_h=${ZIG_CONFIG_H_OUT}"
    "-Denable-llvm"
    "-Denable-stage1"
    ${ZIG_RELEASE_ARG}
    "$<$<BOOL:${ZIG_STATIC}>:-Duse-zig-libcxx>"
    "$<$<BOOL:${ZIG_SKIP_INSTALL_LIB_FILES}>:-Dskip-install-lib-files>"
    "$<$<BOOL:${ZIG_SINGLE_THREADED}>:-Dsingle-threaded>"
    "-Dtarget=${ZIG_TARGET_TRIPLE}"
    "-Dcpu=${ZIG_TARGET_MCPU}"
    "-Dversion-string=${ZIG_VERSION}"
)

add_custom_target(stage3 ALL
    COMMAND "${ZIG_EXECUTABLE}" ${ZIG_BUILD_ARGS}
    DEPENDS zig2
    COMMENT STATUS "Building stage3"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
)

install(CODE "set(ZIG_EXECUTABLE \"${ZIG_EXECUTABLE}\")")
install(CODE "set(ZIG_BUILD_ARGS \"${ZIG_BUILD_ARGS}\")")
install(CODE "set(CMAKE_INSTALL_PREFIX \"${CMAKE_INSTALL_PREFIX}\")")
install(CODE "set(PROJECT_BINARY_DIR \"${PROJECT_BINARY_DIR}\")")

install(SCRIPT "${PROJECT_SOURCE_DIR}/cmake/install.cmake")
