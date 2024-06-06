cmake_minimum_required(VERSION 3.15)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

if(NOT CMAKE_INSTALL_PREFIX)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/stage3" CACHE PATH
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

list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

project(zig
  DESCRIPTION
    "Zig is a general-purpose programming language and toolchain for maintaining robust, optimal and reusable software"
  HOMEPAGE_URL
    "https://ziglang.org"
  LANGUAGES
    C CXX
)

set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 14)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "" CACHE STRING "Override Zig version string. Default is to find out with git.")

if("${ZIG_VERSION}" STREQUAL "")
    set(RESOLVED_ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")
    find_program(GIT_EXE NAMES git NAMES_PER_DIR)
    if(GIT_EXE AND EXISTS "${PROJECT_SOURCE_DIR}/.git")
        execute_process(
            COMMAND ${GIT_EXE} -C "${PROJECT_SOURCE_DIR}" describe --match *.*.* --tags --abbrev=9
            RESULT_VARIABLE EXIT_STATUS
            OUTPUT_VARIABLE GIT_DESCRIBE
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        if(EXIT_STATUS EQUAL "0")
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/.git/HEAD")
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

set(ZIG_STATIC off CACHE BOOL "Attempt to build a static zig executable (not compatible with glibc)")
set(ZIG_SHARED_LLVM off CACHE BOOL "Prefer linking against shared LLVM libraries")
set(ZIG_STATIC_LLVM ${ZIG_STATIC} CACHE BOOL "Prefer linking against static LLVM libraries")
set(ZIG_STATIC_ZLIB ${ZIG_STATIC} CACHE BOOL "Prefer linking against static zlib")
set(ZIG_STATIC_ZSTD ${ZIG_STATIC} CACHE BOOL "Prefer linking against static zstd")
if(APPLE AND ZIG_STATIC)
  set(ZIG_STATIC_CURSES on)
else()
  set(ZIG_STATIC_CURSES off)
endif()
set(ZIG_STATIC_CURSES ${ZIG_STATIC_CURSES} CACHE BOOL "Prefer linking against static curses")

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


option(ZIG_PIE "Produce a position independent zig executable" ${CMAKE_POSITION_INDEPENDENT_CODE})
include(CheckPIESupported)
check_pie_supported(
  OUTPUT_VARIABLE ZIG_PIE_SUPPORTED_BY_CMAKE
  LANGUAGES C CXX
)
if(ZIG_PIE AND NOT ZIG_PIE_SUPPORTED_BY_CMAKE)
  message(SEND_ERROR "ZIG_PIE was requested but CMake does not support it for \"zigcpp\" target")
endif()


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

if(ZIG_STATIC_CURSES)
    list(REMOVE_ITEM LLVM_LIBRARIES "-lcurses")
    find_library(CURSES NAMES libcurses.a libncurses.a NAMES_PER_DIR
      PATHS
        /usr/local/opt/ncurses/lib
        /opt/homebrew/opt/ncurses/lib)
    list(APPEND LLVM_LIBRARIES "${CURSES}")
endif()

find_package(Threads)

set(ZIG_CONFIG_H_OUT "${PROJECT_BINARY_DIR}/config.h")
set(ZIG_CONFIG_ZIG_OUT "${PROJECT_BINARY_DIR}/config.zig")

set(ZIG_WASM2C_SOURCES
    stage1/wasm2c.c
)
# Sync with "zig_cpp_sources" in build.zig
set(ZIG_CPP_SOURCES
    # These are planned to stay even when we are self-hosted.
    src/zig_llvm.cpp
    src/zig_llvm-ar.cpp
    src/zig_clang.cpp
    src/zig_clang_driver.cpp
    src/zig_clang_cc1_main.cpp
    src/zig_clang_cc1as_main.cpp
)
# Needed because we use cmake, not the zig build system, to build zig2.o.
set(ZIG_STAGE2_SOURCES
    "${ZIG_CONFIG_ZIG_OUT}"
    lib/compiler_rt.zig
    lib/compiler_rt/absv.zig
    lib/compiler_rt/absvdi2.zig
    lib/compiler_rt/absvsi2.zig
    lib/compiler_rt/absvti2.zig
    lib/compiler_rt/adddf3.zig
    lib/compiler_rt/addf3.zig
    lib/compiler_rt/addo.zig
    lib/compiler_rt/addsf3.zig
    lib/compiler_rt/addtf3.zig
    lib/compiler_rt/addxf3.zig
    lib/compiler_rt/arm.zig
    lib/compiler_rt/atomics.zig
    lib/compiler_rt/aulldiv.zig
    lib/compiler_rt/aullrem.zig
    lib/compiler_rt/bswap.zig
    lib/compiler_rt/ceil.zig
    lib/compiler_rt/clear_cache.zig
    lib/compiler_rt/cmp.zig
    lib/compiler_rt/cmpdf2.zig
    lib/compiler_rt/cmpsf2.zig
    lib/compiler_rt/cmptf2.zig
    lib/compiler_rt/cmpxf2.zig
    lib/compiler_rt/common.zig
    lib/compiler_rt/comparef.zig
    lib/compiler_rt/cos.zig
    lib/compiler_rt/count0bits.zig
    lib/compiler_rt/divdf3.zig
    lib/compiler_rt/divsf3.zig
    lib/compiler_rt/divtf3.zig
    lib/compiler_rt/divti3.zig
    lib/compiler_rt/divxf3.zig
    lib/compiler_rt/emutls.zig
    lib/compiler_rt/exp.zig
    lib/compiler_rt/exp2.zig
    lib/compiler_rt/extenddftf2.zig
    lib/compiler_rt/extenddfxf2.zig
    lib/compiler_rt/extendf.zig
    lib/compiler_rt/extendhfsf2.zig
    lib/compiler_rt/extendhftf2.zig
    lib/compiler_rt/extendhfxf2.zig
    lib/compiler_rt/extendsfdf2.zig
    lib/compiler_rt/extendsftf2.zig
    lib/compiler_rt/extendsfxf2.zig
    lib/compiler_rt/extendxftf2.zig
    lib/compiler_rt/fabs.zig
    lib/compiler_rt/fixdfdi.zig
    lib/compiler_rt/fixdfsi.zig
    lib/compiler_rt/fixdfti.zig
    lib/compiler_rt/fixhfdi.zig
    lib/compiler_rt/fixhfsi.zig
    lib/compiler_rt/fixhfti.zig
    lib/compiler_rt/fixsfdi.zig
    lib/compiler_rt/fixsfsi.zig
    lib/compiler_rt/fixsfti.zig
    lib/compiler_rt/fixtfdi.zig
    lib/compiler_rt/fixtfsi.zig
    lib/compiler_rt/fixtfti.zig
    lib/compiler_rt/fixunsdfdi.zig
    lib/compiler_rt/fixunsdfsi.zig
    lib/compiler_rt/fixunsdfti.zig
    lib/compiler_rt/fixunshfdi.zig
    lib/compiler_rt/fixunshfsi.zig
    lib/compiler_rt/fixunshfti.zig
    lib/compiler_rt/fixunssfdi.zig
    lib/compiler_rt/fixunssfsi.zig
    lib/compiler_rt/fixunssfti.zig
    lib/compiler_rt/fixunstfdi.zig
    lib/compiler_rt/fixunstfsi.zig
    lib/compiler_rt/fixunstfti.zig
    lib/compiler_rt/fixunsxfdi.zig
    lib/compiler_rt/fixunsxfsi.zig
    lib/compiler_rt/fixunsxfti.zig
    lib/compiler_rt/fixxfdi.zig
    lib/compiler_rt/fixxfsi.zig
    lib/compiler_rt/fixxfti.zig
    lib/compiler_rt/float_from_int.zig
    lib/compiler_rt/floatdidf.zig
    lib/compiler_rt/floatdihf.zig
    lib/compiler_rt/floatdisf.zig
    lib/compiler_rt/floatditf.zig
    lib/compiler_rt/floatdixf.zig
    lib/compiler_rt/floatsidf.zig
    lib/compiler_rt/floatsihf.zig
    lib/compiler_rt/floatsisf.zig
    lib/compiler_rt/floatsitf.zig
    lib/compiler_rt/floatsixf.zig
    lib/compiler_rt/floattidf.zig
    lib/compiler_rt/floattihf.zig
    lib/compiler_rt/floattisf.zig
    lib/compiler_rt/floattitf.zig
    lib/compiler_rt/floattixf.zig
    lib/compiler_rt/floatundidf.zig
    lib/compiler_rt/floatundihf.zig
    lib/compiler_rt/floatundisf.zig
    lib/compiler_rt/floatunditf.zig
    lib/compiler_rt/floatundixf.zig
    lib/compiler_rt/floatunsidf.zig
    lib/compiler_rt/floatunsihf.zig
    lib/compiler_rt/floatunsisf.zig
    lib/compiler_rt/floatunsitf.zig
    lib/compiler_rt/floatunsixf.zig
    lib/compiler_rt/floatuntidf.zig
    lib/compiler_rt/floatuntihf.zig
    lib/compiler_rt/floatuntisf.zig
    lib/compiler_rt/floatuntitf.zig
    lib/compiler_rt/floatuntixf.zig
    lib/compiler_rt/floor.zig
    lib/compiler_rt/fma.zig
    lib/compiler_rt/fmax.zig
    lib/compiler_rt/fmin.zig
    lib/compiler_rt/fmod.zig
    lib/compiler_rt/gedf2.zig
    lib/compiler_rt/gesf2.zig
    lib/compiler_rt/getf2.zig
    lib/compiler_rt/gexf2.zig
    lib/compiler_rt/int.zig
    lib/compiler_rt/int_from_float.zig
    lib/compiler_rt/log.zig
    lib/compiler_rt/log10.zig
    lib/compiler_rt/log2.zig
    lib/compiler_rt/modti3.zig
    lib/compiler_rt/mulXi3.zig
    lib/compiler_rt/muldf3.zig
    lib/compiler_rt/mulf3.zig
    lib/compiler_rt/mulo.zig
    lib/compiler_rt/mulsf3.zig
    lib/compiler_rt/multf3.zig
    lib/compiler_rt/mulxf3.zig
    lib/compiler_rt/negXi2.zig
    lib/compiler_rt/negdf2.zig
    lib/compiler_rt/negsf2.zig
    lib/compiler_rt/negtf2.zig
    lib/compiler_rt/negv.zig
    lib/compiler_rt/negxf2.zig
    lib/compiler_rt/os_version_check.zig
    lib/compiler_rt/parity.zig
    lib/compiler_rt/popcount.zig
    lib/compiler_rt/rem_pio2.zig
    lib/compiler_rt/rem_pio2_large.zig
    lib/compiler_rt/rem_pio2f.zig
    lib/compiler_rt/round.zig
    lib/compiler_rt/shift.zig
    lib/compiler_rt/sin.zig
    lib/compiler_rt/sincos.zig
    lib/compiler_rt/sqrt.zig
    lib/compiler_rt/stack_probe.zig
    lib/compiler_rt/subdf3.zig
    lib/compiler_rt/subo.zig
    lib/compiler_rt/subsf3.zig
    lib/compiler_rt/subtf3.zig
    lib/compiler_rt/subxf3.zig
    lib/compiler_rt/tan.zig
    lib/compiler_rt/trig.zig
    lib/compiler_rt/trunc.zig
    lib/compiler_rt/truncdfhf2.zig
    lib/compiler_rt/truncdfsf2.zig
    lib/compiler_rt/truncf.zig
    lib/compiler_rt/truncsfhf2.zig
    lib/compiler_rt/trunctfdf2.zig
    lib/compiler_rt/trunctfhf2.zig
    lib/compiler_rt/trunctfsf2.zig
    lib/compiler_rt/trunctfxf2.zig
    lib/compiler_rt/truncxfdf2.zig
    lib/compiler_rt/truncxfhf2.zig
    lib/compiler_rt/truncxfsf2.zig
    lib/compiler_rt/udivmod.zig
    lib/compiler_rt/udivmodei4.zig
    lib/compiler_rt/udivmodti4.zig
    lib/compiler_rt/udivti3.zig
    lib/compiler_rt/umodti3.zig
    lib/compiler_rt/unorddf2.zig
    lib/compiler_rt/unordsf2.zig
    lib/compiler_rt/unordtf2.zig
    lib/std/BitStack.zig
    lib/std/Build.zig
    lib/std/Build/Cache.zig
    lib/std/Build/Cache/DepTokenizer.zig
    lib/std/Progress.zig
    lib/std/Random.zig
    lib/std/Target.zig
    lib/std/Target/Query.zig
    lib/std/Target/aarch64.zig
    lib/std/Target/amdgpu.zig
    lib/std/Target/arm.zig
    lib/std/Target/avr.zig
    lib/std/Target/bpf.zig
    lib/std/Target/hexagon.zig
    lib/std/Target/mips.zig
    lib/std/Target/msp430.zig
    lib/std/Target/nvptx.zig
    lib/std/Target/powerpc.zig
    lib/std/Target/riscv.zig
    lib/std/Target/s390x.zig
    lib/std/Target/sparc.zig
    lib/std/Target/wasm.zig
    lib/std/Target/x86.zig
    lib/std/Thread.zig
    lib/std/Thread/Futex.zig
    lib/std/Thread/Mutex.zig
    lib/std/Thread/Pool.zig
    lib/std/Thread/ResetEvent.zig
    lib/std/Thread/WaitGroup.zig
    lib/std/array_hash_map.zig
    lib/std/array_list.zig
    lib/std/ascii.zig
    lib/std/atomic.zig
    lib/std/base64.zig
    lib/std/buf_map.zig
    lib/std/builtin.zig
    lib/std/c.zig
    lib/std/c/linux.zig
    lib/std/coff.zig
    lib/std/crypto.zig
    lib/std/crypto/blake3.zig
    lib/std/crypto/siphash.zig
    lib/std/debug.zig
    lib/std/dwarf.zig
    lib/std/dwarf/AT.zig
    lib/std/dwarf/ATE.zig
    lib/std/dwarf/FORM.zig
    lib/std/dwarf/LANG.zig
    lib/std/dwarf/OP.zig
    lib/std/dwarf/TAG.zig
    lib/std/elf.zig
    lib/std/fifo.zig
    lib/std/fmt.zig
    lib/std/fmt/format_float.zig
    lib/std/fmt/parse_float.zig
    lib/std/fs.zig
    lib/std/fs/AtomicFile.zig
    lib/std/fs/Dir.zig
    lib/std/fs/File.zig
    lib/std/fs/get_app_data_dir.zig
    lib/std/fs/path.zig
    lib/std/hash.zig
    lib/std/hash/auto_hash.zig
    lib/std/hash/wyhash.zig
    lib/std/hash_map.zig
    lib/std/heap.zig
    lib/std/heap/arena_allocator.zig
    lib/std/io.zig
    lib/std/io/Reader.zig
    lib/std/io/Writer.zig
    lib/std/io/buffered_atomic_file.zig
    lib/std/io/buffered_writer.zig
    lib/std/io/change_detection_stream.zig
    lib/std/io/counting_reader.zig
    lib/std/io/counting_writer.zig
    lib/std/io/find_byte_writer.zig
    lib/std/io/fixed_buffer_stream.zig
    lib/std/io/limited_reader.zig
    lib/std/io/seekable_stream.zig
    lib/std/json.zig
    lib/std/json/stringify.zig
    lib/std/leb128.zig
    lib/std/linked_list.zig
    lib/std/log.zig
    lib/std/macho.zig
    lib/std/math.zig
    lib/std/math/big.zig
    lib/std/math/big/int.zig
    lib/std/math/float.zig
    lib/std/math/frexp.zig
    lib/std/math/isinf.zig
    lib/std/math/isnan.zig
    lib/std/math/log.zig
    lib/std/math/log10.zig
    lib/std/math/log2.zig
    lib/std/math/signbit.zig
    lib/std/math/sqrt.zig
    lib/std/mem.zig
    lib/std/mem/Allocator.zig
    lib/std/meta.zig
    lib/std/meta/trailer_flags.zig
    lib/std/multi_array_list.zig
    lib/std/os.zig
    lib/std/os/linux.zig
    lib/std/os/linux.zig
    lib/std/os/linux/IoUring.zig
    lib/std/os/linux/io_uring_sqe.zig
    lib/std/os/linux/x86_64.zig
    lib/std/os/linux/x86_64.zig
    lib/std/os/windows.zig
    lib/std/os/windows/ntstatus.zig
    lib/std/os/windows/win32error.zig
    lib/std/pdb.zig
    lib/std/process.zig
    lib/std/process/Child.zig
    lib/std/sort.zig
    lib/std/start.zig
    lib/std/static_string_map.zig
    lib/std/std.zig
    lib/std/time.zig
    lib/std/treap.zig
    lib/std/unicode.zig
    lib/std/zig.zig
    lib/std/zig/Ast.zig
    lib/std/zig/AstGen.zig
    lib/std/zig/AstRlAnnotate.zig
    lib/std/zig/LibCInstallation.zig
    lib/std/zig/Parse.zig
    lib/std/zig/Server.zig
    lib/std/zig/WindowsSdk.zig
    lib/std/zig/Zir.zig
    lib/std/zig/c_builtins.zig
    lib/std/zig/render.zig
    lib/std/zig/string_literal.zig
    lib/std/zig/system.zig
    lib/std/zig/system/NativePaths.zig
    lib/std/zig/system/x86.zig
    lib/std/zig/tokenizer.zig
    src/Air.zig
    src/Builtin.zig
    src/Compilation.zig
    src/Compilation/Config.zig
    src/DarwinPosixSpawn.zig
    src/InternPool.zig
    src/Liveness.zig
    src/Liveness/Verify.zig
    src/Module.zig
    src/Package.zig
    src/Package/Fetch.zig
    src/Package/Fetch/git.zig
    src/Package/Manifest.zig
    src/Package/Module.zig
    src/RangeSet.zig
    src/Sema.zig
    src/Sema/bitcast.zig
    src/Sema/comptime_ptr_access.zig
    src/Value.zig
    src/arch/aarch64/CodeGen.zig
    src/arch/aarch64/Emit.zig
    src/arch/aarch64/Mir.zig
    src/arch/aarch64/abi.zig
    src/arch/aarch64/bits.zig
    src/arch/arm/CodeGen.zig
    src/arch/arm/Emit.zig
    src/arch/arm/Mir.zig
    src/arch/arm/abi.zig
    src/arch/arm/bits.zig
    src/arch/riscv64/CodeGen.zig
    src/arch/riscv64/Emit.zig
    src/arch/riscv64/Mir.zig
    src/arch/riscv64/abi.zig
    src/arch/riscv64/bits.zig
    src/arch/sparc64/CodeGen.zig
    src/arch/sparc64/Emit.zig
    src/arch/sparc64/Mir.zig
    src/arch/sparc64/abi.zig
    src/arch/sparc64/bits.zig
    src/arch/wasm/CodeGen.zig
    src/arch/wasm/Emit.zig
    src/arch/wasm/Mir.zig
    src/arch/wasm/abi.zig
    src/arch/x86/bits.zig
    src/arch/x86_64/CodeGen.zig
    src/arch/x86_64/Disassembler.zig
    src/arch/x86_64/Emit.zig
    src/arch/x86_64/Encoding.zig
    src/arch/x86_64/Lower.zig
    src/arch/x86_64/Mir.zig
    src/arch/x86_64/abi.zig
    src/arch/x86_64/bits.zig
    src/arch/x86_64/encoder.zig
    src/arch/x86_64/encodings.zig
    src/clang.zig
    src/clang_options.zig
    src/clang_options_data.zig
    src/codegen.zig
    src/codegen/c.zig
    src/codegen/c/Type.zig
    src/codegen/llvm.zig
    src/codegen/llvm/BitcodeReader.zig
    src/codegen/llvm/Builder.zig
    src/codegen/llvm/bindings.zig
    src/codegen/llvm/bitcode_writer.zig
    src/codegen/llvm/ir.zig
    src/codegen/spirv.zig
    src/codegen/spirv/Assembler.zig
    src/codegen/spirv/Module.zig
    src/codegen/spirv/Section.zig
    src/codegen/spirv/spec.zig
    src/crash_report.zig
    src/glibc.zig
    src/introspect.zig
    src/libcxx.zig
    src/libtsan.zig
    src/libunwind.zig
    src/link.zig
    src/link/C.zig
    src/link/Coff.zig
    src/link/Coff/Atom.zig
    src/link/Coff/ImportTable.zig
    src/link/Coff/Object.zig
    src/link/Coff/Relocation.zig
    src/link/Coff/lld.zig
    src/link/Dwarf.zig
    src/link/Elf.zig
    src/link/Elf/Archive.zig
    src/link/Elf/Atom.zig
    src/link/Elf/LdScript.zig
    src/link/Elf/LinkerDefined.zig
    src/link/Elf/Object.zig
    src/link/Elf/SharedObject.zig
    src/link/Elf/Symbol.zig
    src/link/Elf/ZigObject.zig
    src/link/Elf/eh_frame.zig
    src/link/Elf/file.zig
    src/link/Elf/gc.zig
    src/link/Elf/merge_section.zig
    src/link/Elf/relocatable.zig
    src/link/Elf/relocation.zig
    src/link/Elf/synthetic_sections.zig
    src/link/Elf/thunks.zig
    src/link/MachO.zig
    src/link/MachO/Archive.zig
    src/link/MachO/Atom.zig
    src/link/MachO/CodeSignature.zig
    src/link/MachO/DebugSymbols.zig
    src/link/MachO/Dylib.zig
    src/link/MachO/InternalObject.zig
    src/link/MachO/Object.zig
    src/link/MachO/Relocation.zig
    src/link/MachO/Symbol.zig
    src/link/MachO/UnwindInfo.zig
    src/link/MachO/ZigObject.zig
    src/link/MachO/dead_strip.zig
    src/link/MachO/dyld_info/Rebase.zig
    src/link/MachO/dyld_info/Trie.zig
    src/link/MachO/dyld_info/bind.zig
    src/link/MachO/dwarf.zig
    src/link/MachO/eh_frame.zig
    src/link/MachO/fat.zig
    src/link/MachO/file.zig
    src/link/MachO/hasher.zig
    src/link/MachO/load_commands.zig
    src/link/MachO/relocatable.zig
    src/link/MachO/synthetic.zig
    src/link/MachO/thunks.zig
    src/link/MachO/uuid.zig
    src/link/NvPtx.zig
    src/link/Plan9.zig
    src/link/Plan9/aout.zig
    src/link/SpirV.zig
    src/link/SpirV/BinaryModule.zig
    src/link/SpirV/deduplicate.zig
    src/link/SpirV/lower_invocation_globals.zig
    src/link/SpirV/prune_unused.zig
    src/link/StringTable.zig
    src/link/Wasm.zig
    src/link/Wasm/Archive.zig
    src/link/Wasm/Atom.zig
    src/link/Wasm/Object.zig
    src/link/Wasm/Symbol.zig
    src/link/Wasm/ZigObject.zig
    src/link/Wasm/file.zig
    src/link/Wasm/types.zig
    src/link/aarch64.zig
    src/link/riscv.zig
    src/link/table_section.zig
    src/link/tapi.zig
    src/link/tapi/Tokenizer.zig
    src/link/tapi/parse.zig
    src/link/tapi/parse/test.zig
    src/link/tapi/yaml.zig
    src/link/tapi/yaml/test.zig
    src/main.zig
    src/mingw.zig
    src/musl.zig
    src/mutable_value.zig
    src/print_air.zig
    src/print_env.zig
    src/print_targets.zig
    src/print_value.zig
    src/print_zir.zig
    src/register_manager.zig
    src/target.zig
    src/tracy.zig
    src/translate_c.zig
    src/type.zig
    src/wasi_libc.zig
)

if(MSVC)
    set(MSVC_DIA_SDK_DIR "$ENV{VSINSTALLDIR}DIA SDK")
    if(IS_DIRECTORY ${MSVC_DIA_SDK_DIR})
        set(ZIG_DIA_GUIDS_LIB "${MSVC_DIA_SDK_DIR}/lib/amd64/diaguids.lib")
        string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_DIA_GUIDS_LIB_ESCAPED "${ZIG_DIA_GUIDS_LIB}")
    endif()
endif()

configure_file (
    stage1/config.h.in
    "${ZIG_CONFIG_H_OUT}"
)
configure_file (
    stage1/config.zig.in
    "${ZIG_CONFIG_ZIG_OUT}"
)

# zigcpp target

set(ZIGCPP_OUTPUT_DIR "${PROJECT_BINARY_DIR}/zigcpp")

add_library(zigcpp STATIC ${ZIG_CPP_SOURCES})

# Sync with minimum C++ standard required to build LLVM
# and with "exe_cflags" in build.zig
target_compile_features(zigcpp PRIVATE cxx_std_17)
set_target_properties(zigcpp PROPERTIES POSITION_INDEPENDENT_CODE ${ZIG_PIE})

if(NOT MSVC)
  if(MINGW)
    target_compile_options(zigcpp PRIVATE -Wno-format)
  endif()
  # Sync content below with "exe_cflags" in build.zig
  target_compile_definitions(zigcpp PUBLIC
    __STDC_CONSTANT_MACROS
    __STDC_FORMAT_MACROS
    __STDC_LIMIT_MACROS

    _GNU_SOURCE
  )
  target_compile_options(zigcpp PRIVATE
    -fno-exceptions
    -fno-rtti
    -fno-stack-protector

    -fvisibility-inlines-hidden

    -Wno-type-limits
    -Wno-missing-braces
    -Wno-comment
  )
else()
target_compile_options(zigcpp PRIVATE /Zc:preprocessor)
set_property(TARGET zigcpp PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded")
endif()

target_include_directories(zigcpp PUBLIC
    ${CLANG_INCLUDE_DIRS}
    ${LLVM_INCLUDE_DIRS}
    ${LLD_INCLUDE_DIRS}
)
target_link_libraries(zigcpp PUBLIC
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)

# Handle multi-config builds and place each into a common lib. The VS generator
# for example will append a Debug folder by default if not explicitly specified.
set_target_properties(zigcpp PROPERTIES ARCHIVE_OUTPUT_DIRECTORY ${ZIGCPP_OUTPUT_DIR})
foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG_TYPE} CONFIG_TYPE)
    set_target_properties(zigcpp PROPERTIES ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${ZIGCPP_OUTPUT_DIR})
endforeach()

# end of zigcpp target

include(CheckSymbolExists)

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

set(ZIG1_WASM_MODULE "${PROJECT_SOURCE_DIR}/stage1/zig1.wasm")
set(ZIG1_C_SOURCE "${PROJECT_BINARY_DIR}/zig1.c")
set(ZIG2_C_SOURCE "${PROJECT_BINARY_DIR}/zig2.c")
set(ZIG_COMPILER_RT_C_SOURCE "${PROJECT_BINARY_DIR}/compiler_rt.c")

add_executable(zig-wasm2c ${ZIG_WASM2C_SOURCES})
set_target_properties(zig-wasm2c PROPERTIES COMPILE_FLAGS "${ZIG_WASM2C_COMPILE_FLAGS}")

add_custom_command(
  OUTPUT "${ZIG1_C_SOURCE}"
  COMMAND zig-wasm2c "${ZIG1_WASM_MODULE}" "${ZIG1_C_SOURCE}"
  DEPENDS zig-wasm2c "${ZIG1_WASM_MODULE}"
  COMMENT STATUS "Converting ${ZIG1_WASM_MODULE} to ${ZIG1_C_SOURCE}"
  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
)

add_executable(zig1 ${ZIG1_C_SOURCE} stage1/wasi.c)
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
  "${PROJECT_SOURCE_DIR}/lib"
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
  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
)

set(BUILD_COMPILER_RT_ARGS
  "${PROJECT_SOURCE_DIR}/lib"
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
  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
)

add_executable(zig2 ${ZIG2_C_SOURCE} ${ZIG_COMPILER_RT_C_SOURCE})
set_target_properties(zig2 PROPERTIES
  COMPILE_FLAGS ${ZIG2_COMPILE_FLAGS}
  LINK_FLAGS "${ZIG2_LINK_FLAGS}"
)
target_include_directories(zig2 PUBLIC stage1)
target_link_libraries(zig2 LINK_PUBLIC zigcpp)

if(MSVC)
  target_link_libraries(zig2 LINK_PUBLIC ntdll.lib ws2_32.lib)
elseif(MINGW)
  target_link_libraries(zig2 LINK_PUBLIC ntdll ws2_32)
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


# "-Dno-langref" and "-Dstd-docs=false" are hardcoded because they take too long to build.
# To obtain these two forms of documentation, run zig build against stage3 rather than stage2.
set(ZIG_BUILD_ARGS
  --zig-lib-dir "${PROJECT_SOURCE_DIR}/lib"

  "-Dversion-string=${RESOLVED_ZIG_VERSION}"
  "-Dtarget=${ZIG_TARGET_TRIPLE}"
  "-Dcpu=${ZIG_TARGET_MCPU}"

  -Denable-llvm
  "-Dconfig_h=${ZIG_CONFIG_H_OUT}"

  -Dno-langref
  -Dstd-docs=false
)

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  list(APPEND ZIG_BUILD_ARGS -Doptimize=Debug)
elseif("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
  list(APPEND ZIG_BUILD_ARGS -Doptimize=ReleaseFast)
else()
  list(APPEND ZIG_BUILD_ARGS -Doptimize=ReleaseFast -Dstrip)
endif()

if(ZIG_STATIC AND NOT MSVC)
  list(APPEND ZIG_BUILD_ARGS -Duse-zig-libcxx)
endif()

if(ZIG_NO_LIB)
  list(APPEND ZIG_BUILD_ARGS -Dno-lib)
endif()

if(ZIG_SINGLE_THREADED)
  list(APPEND ZIG_BUILD_ARGS -Dsingle-threaded)
endif()

if(ZIG_PIE)
  list(APPEND ZIG_BUILD_ARGS -Dpie)
endif()

if(NOT "${ZIG_TARGET_DYNAMIC_LINKER}" STREQUAL "")
  list(APPEND ZIG_BUILD_ARGS "-Ddynamic-linker=${ZIG_TARGET_DYNAMIC_LINKER}")
endif()


add_custom_target(stage3 ALL
  DEPENDS "${PROJECT_BINARY_DIR}/stage3/bin/zig"
)

set(ZIG2_WORKING_DIR "${PROJECT_SOURCE_DIR}")

add_custom_command(
  OUTPUT "${PROJECT_BINARY_DIR}/stage3/bin/zig"
  COMMAND zig2 build --prefix "${PROJECT_BINARY_DIR}/stage3" ${ZIG_BUILD_ARGS}
  COMMENT STATUS "Building stage3"
  WORKING_DIRECTORY "${ZIG2_WORKING_DIR}"
)

if(WIN32)
  set(ZIG_EXECUTABLE "${PROJECT_BINARY_DIR}/zig2.exe")
else()
  set(ZIG_EXECUTABLE "${PROJECT_BINARY_DIR}/zig2")
endif()

install(CODE "set(ZIG_EXECUTABLE \"${ZIG_EXECUTABLE}\")")
install(CODE "set(ZIG_BUILD_ARGS \"${ZIG_BUILD_ARGS}\")")
install(CODE "set(ZIG2_WORKING_DIR \"${ZIG2_WORKING_DIR}\")")
install(CODE "set(CMAKE_INSTALL_PREFIX \"${CMAKE_INSTALL_PREFIX}\")")
install(SCRIPT cmake/install.cmake)
