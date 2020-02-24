cmake_minimum_required(VERSION 2.8.5)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

if(NOT CMAKE_INSTALL_PREFIX)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}" CACHE STRING
      "Directory to install zig to" FORCE)
endif()

set(CMAKE_USER_MAKE_RULES_OVERRIDE
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/c_flag_overrides.cmake)
set(CMAKE_USER_MAKE_RULES_OVERRIDE_CXX
   ${CMAKE_CURRENT_SOURCE_DIR}/cmake/cxx_flag_overrides.cmake)

project(zig C CXX)
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 5)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")

find_program(GIT_EXE NAMES git)
if(GIT_EXE)
    execute_process(
        COMMAND ${GIT_EXE} -C ${CMAKE_SOURCE_DIR} name-rev HEAD --tags --name-only --no-undefined --always
        RESULT_VARIABLE EXIT_STATUS
        OUTPUT_VARIABLE ZIG_GIT_REV
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    if(EXIT_STATUS EQUAL "0")
        if(ZIG_GIT_REV MATCHES "\\^0$")
            if(NOT("${ZIG_GIT_REV}" STREQUAL "${ZIG_VERSION}^0"))
                message("WARNING: Tag does not match configured Zig version")
            endif()
        else()
            set(ZIG_VERSION "${ZIG_VERSION}+${ZIG_GIT_REV}")
        endif()
    endif()
endif()
message("Configuring zig version ${ZIG_VERSION}")

set(ZIG_STATIC off CACHE BOOL "Attempt to build a static zig executable (not compatible with glibc)")
set(ZIG_STATIC_LLVM off CACHE BOOL "Prefer linking against static LLVM libraries")
set(ZIG_ENABLE_MEM_PROFILE off CACHE BOOL "Activate memory usage instrumentation")

if(ZIG_STATIC)
    set(ZIG_STATIC_LLVM "on")
endif()

string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_LIB_DIR_ESCAPED "${ZIG_LIBC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_STATIC_LIB_DIR_ESCAPED "${ZIG_LIBC_STATIC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_INCLUDE_DIR_ESCAPED "${ZIG_LIBC_INCLUDE_DIR}")

option(ZIG_TEST_COVERAGE "Build Zig with test coverage instrumentation" OFF)

# To see what patches have been applied to LLD in this repository:
# git log -p -- deps/lld
option(ZIG_FORCE_EXTERNAL_LLD "If your system has the LLD patches use it instead of the embedded LLD" OFF)

find_package(llvm)
find_package(clang)

if(APPLE AND ZIG_STATIC)
    list(REMOVE_ITEM LLVM_LIBRARIES "-lz")
    find_library(ZLIB NAMES z zlib libz)
    list(APPEND LLVM_LIBRARIES "${ZLIB}")
endif()

set(ZIG_CPP_LIB_DIR "${CMAKE_BINARY_DIR}/zig_cpp")

# Handle multi-config builds and place each into a common lib. The VS generator
# for example will append a Debug folder by default if not explicitly specified.
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${ZIG_CPP_LIB_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${ZIG_CPP_LIB_DIR})
foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG_TYPE} CONFIG_TYPE)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${ZIG_CPP_LIB_DIR})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CONFIG_TYPE} ${ZIG_CPP_LIB_DIR})
endforeach(CONFIG_TYPE CMAKE_CONFIGURATION_TYPES)

if(ZIG_FORCE_EXTERNAL_LLD)
    find_package(lld)
    include_directories(${LLVM_INCLUDE_DIRS})
    include_directories(${LLD_INCLUDE_DIRS})
    include_directories(${CLANG_INCLUDE_DIRS})
else()
    # This goes first so that we find embedded LLD instead
    # of system LLD.
    include_directories("${CMAKE_SOURCE_DIR}/deps/lld/include")

    include_directories(${LLVM_INCLUDE_DIRS})
    include_directories(${CLANG_INCLUDE_DIRS})
    set(EMBEDDED_LLD_LIB_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Args.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/ErrorHandler.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Filesystem.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Memory.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Reproduce.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Strings.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/TargetOptionsCommandFlags.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Threads.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Timer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Version.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/DefinedAtom.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Error.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/File.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/LinkingContext.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Reader.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Resolver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Writer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Driver/DarwinLdDriver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/FileArchive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_arm.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_arm64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_x86.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_x86_64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/CompactUnwindPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/GOTPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/LayoutPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachOLinkingContext.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileBinaryReader.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileBinaryWriter.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileFromAtoms.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileToAtoms.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileYAML.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ObjCPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ShimPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/StubsPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/TLVPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/WriterMachO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/YAML/ReaderWriterYAML.cpp"
    )

    set(EMBEDDED_LLD_ELF_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/AArch64ErrataFix.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/AArch64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/AMDGPU.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/ARM.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/AVR.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/Hexagon.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/MSP430.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/Mips.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/MipsArchTree.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/PPC.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/PPC64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/RISCV.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/SPARCV9.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/X86.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/X86_64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/CallGraphSort.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/DWARF.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/DriverUtils.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/EhFrame.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/ICF.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/InputFiles.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/InputSection.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/LTO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/LinkerScript.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/MapFile.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/MarkLive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/OutputSections.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Relocations.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/ScriptLexer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/ScriptParser.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Symbols.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/SyntheticSections.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Target.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Thunks.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Writer.cpp"
    )

    set(EMBEDDED_LLD_COFF_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Chunks.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/DLL.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/DebugTypes.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/DriverUtils.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/ICF.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/InputFiles.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/LTO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MapFile.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MarkLive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MinGW.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/PDB.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Symbols.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Writer.cpp"
    )
    set(EMBEDDED_LLD_MINGW_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/MinGW/Driver.cpp"
    )
    set(EMBEDDED_LLD_WASM_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/InputChunks.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/InputFiles.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/LTO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/MarkLive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/OutputSections.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/Relocations.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/Symbols.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/SyntheticSections.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/Writer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/WriterUtils.cpp"
    )
    add_library(embedded_lld_lib STATIC ${EMBEDDED_LLD_LIB_SOURCES})
    add_library(embedded_lld_elf STATIC ${EMBEDDED_LLD_ELF_SOURCES})
    add_library(embedded_lld_coff STATIC ${EMBEDDED_LLD_COFF_SOURCES})
    add_library(embedded_lld_mingw STATIC ${EMBEDDED_LLD_MINGW_SOURCES})
    add_library(embedded_lld_wasm STATIC ${EMBEDDED_LLD_WASM_SOURCES})
    if(MSVC)
        set(ZIG_LLD_COMPILE_FLAGS "-std=c++11 -D_CRT_SECURE_NO_WARNINGS /w")
    else()
      set(ZIG_LLD_COMPILE_FLAGS "-std=c++11 -fvisibility-inlines-hidden -fno-exceptions -fno-rtti -Wno-comment")
      if(MINGW)
        set(ZIG_LLD_COMPILE_FLAGS "${ZIG_LLD_COMPILE_FLAGS} -D__STDC_FORMAT_MACROS -D__USE_MINGW_ANSI_STDIO")
      endif()
    endif()
    set_target_properties(embedded_lld_lib PROPERTIES
        COMPILE_FLAGS ${ZIG_LLD_COMPILE_FLAGS}
        LINK_FLAGS " "
    )
    set_target_properties(embedded_lld_elf PROPERTIES
        COMPILE_FLAGS ${ZIG_LLD_COMPILE_FLAGS}
        LINK_FLAGS " "
    )
    set_target_properties(embedded_lld_coff PROPERTIES
        COMPILE_FLAGS ${ZIG_LLD_COMPILE_FLAGS}
        LINK_FLAGS " "
    )
    set_target_properties(embedded_lld_mingw PROPERTIES
        COMPILE_FLAGS ${ZIG_LLD_COMPILE_FLAGS}
        LINK_FLAGS " "
    )
    set_target_properties(embedded_lld_wasm PROPERTIES
        COMPILE_FLAGS ${ZIG_LLD_COMPILE_FLAGS}
        LINK_FLAGS " "
    )
    target_include_directories(embedded_lld_lib PRIVATE
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    target_include_directories(embedded_lld_elf PRIVATE
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF"
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt/ELF"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    target_include_directories(embedded_lld_coff PRIVATE
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF"
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt/COFF"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    target_include_directories(embedded_lld_mingw PRIVATE
        "${CMAKE_SOURCE_DIR}/deps/lld/MinGW"
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt/MinGW"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    target_include_directories(embedded_lld_wasm PRIVATE
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm"
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt/wasm"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    set(LLD_INCLUDE_DIRS "")
    set(LLD_LIBRARIES
        embedded_lld_elf
        embedded_lld_coff
        embedded_lld_mingw
        embedded_lld_wasm
        embedded_lld_lib
    )
endif()

# No patches have been applied to SoftFloat-3e
set(EMBEDDED_SOFTFLOAT_SOURCES
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/f128M_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF16UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF32UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF64UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f128MToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f16UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f32UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f64UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_propagateNaNF128M.c"
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
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_i64_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_to_ui64_r_minMag.c"
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
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_to_f64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_f16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/i32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_add256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addComplCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_addF128M.c"
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
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_countLeadingZeros8.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_eq128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_invalidF128M.c"
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
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/s_normRoundPackMToF128M.c"
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
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f16_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f128M_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/softfloat_state.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui64_to_f128M.c"
)
add_library(embedded_softfloat STATIC ${EMBEDDED_SOFTFLOAT_SOURCES})
if(MSVC)
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "-std=c99 /w"
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

# CMake doesn't let us create an empty executable, so we hang on to this one separately.
set(ZIG_MAIN_SRC "${CMAKE_SOURCE_DIR}/src/main.cpp")

# This is our shim which will be replaced by libstage2 written in Zig.
set(ZIG0_SHIM_SRC "${CMAKE_SOURCE_DIR}/src/stage2.cpp")

if(ZIG_ENABLE_MEM_PROFILE)
    set(ZIG_SOURCES_MEM_PROFILE "${CMAKE_SOURCE_DIR}/src/mem_profile.cpp")
endif()

set(ZIG_SOURCES
    "${CMAKE_SOURCE_DIR}/src/analyze.cpp"
    "${CMAKE_SOURCE_DIR}/src/ast_render.cpp"
    "${CMAKE_SOURCE_DIR}/src/bigfloat.cpp"
    "${CMAKE_SOURCE_DIR}/src/bigint.cpp"
    "${CMAKE_SOURCE_DIR}/src/buffer.cpp"
    "${CMAKE_SOURCE_DIR}/src/cache_hash.cpp"
    "${CMAKE_SOURCE_DIR}/src/codegen.cpp"
    "${CMAKE_SOURCE_DIR}/src/compiler.cpp"
    "${CMAKE_SOURCE_DIR}/src/dump_analysis.cpp"
    "${CMAKE_SOURCE_DIR}/src/errmsg.cpp"
    "${CMAKE_SOURCE_DIR}/src/error.cpp"
    "${CMAKE_SOURCE_DIR}/src/glibc.cpp"
    "${CMAKE_SOURCE_DIR}/src/heap.cpp"
    "${CMAKE_SOURCE_DIR}/src/ir.cpp"
    "${CMAKE_SOURCE_DIR}/src/ir_print.cpp"
    "${CMAKE_SOURCE_DIR}/src/link.cpp"
    "${CMAKE_SOURCE_DIR}/src/mem.cpp"
    "${CMAKE_SOURCE_DIR}/src/os.cpp"
    "${CMAKE_SOURCE_DIR}/src/parser.cpp"
    "${CMAKE_SOURCE_DIR}/src/range_set.cpp"
    "${CMAKE_SOURCE_DIR}/src/target.cpp"
    "${CMAKE_SOURCE_DIR}/src/tokenizer.cpp"
    "${CMAKE_SOURCE_DIR}/src/util.cpp"
    "${ZIG_SOURCES_MEM_PROFILE}"
)
set(OPTIMIZED_C_SOURCES
    "${CMAKE_SOURCE_DIR}/src/blake2b.c"
    "${CMAKE_SOURCE_DIR}/src/parse_f128.c"
)
set(ZIG_CPP_SOURCES
    "${CMAKE_SOURCE_DIR}/src/zig_llvm.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_driver.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1_main.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_clang_cc1as_main.cpp"
    "${CMAKE_SOURCE_DIR}/src/windows_sdk.cpp"
)

if(MSVC)
    set(MSVC_DIA_SDK_DIR "$ENV{VSINSTALLDIR}DIA SDK")
    if(IS_DIRECTORY ${MSVC_DIA_SDK_DIR})
        set(ZIG_DIA_GUIDS_LIB "${MSVC_DIA_SDK_DIR}/lib/amd64/diaguids.lib")
        string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_DIA_GUIDS_LIB_ESCAPED "${ZIG_DIA_GUIDS_LIB}")
    endif()
endif()

set(ZIG_LIB_DIR "lib/zig")
set(C_HEADERS_DEST "${ZIG_LIB_DIR}/include")
set(LIBC_FILES_DEST "${ZIG_LIB_DIR}/libc")
set(LIBUNWIND_FILES_DEST "${ZIG_LIB_DIR}/libunwind")
set(LIBCXX_FILES_DEST "${ZIG_LIB_DIR}/libcxx")
set(ZIG_STD_DEST "${ZIG_LIB_DIR}/std")
configure_file (
    "${CMAKE_SOURCE_DIR}/src/config.h.in"
    "${CMAKE_BINARY_DIR}/config.h"
)

include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
    "${CMAKE_SOURCE_DIR}/src"
)

# These have to go before the -Wno- flags
set(EXE_CFLAGS "-std=c++11")
if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    if(MSVC)
        set(EXE_CFLAGS "${EXE_CFLAGS} /w")
    else()
        set(EXE_CFLAGS "${EXE_CFLAGS} -Werror -Wall")
    endif()
endif()

if(MSVC)
    set(EXE_CFLAGS "${EXE_CFLAGS}")
else()
    set(EXE_CFLAGS "${EXE_CFLAGS} -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -D_GNU_SOURCE -fvisibility-inlines-hidden -fno-exceptions -fno-rtti -Werror=type-limits -Wno-missing-braces")
    if(MINGW)
        set(EXE_CFLAGS "${EXE_CFLAGS} -Wno-format")
    endif()
endif()

set(OPTIMIZED_C_FLAGS "-std=c99 -O3")

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
        set(EXE_LDFLAGS "${EXE_LDFLAGS} -lz3")
    endif() 
endif()

if(ZIG_TEST_COVERAGE)
    set(EXE_CFLAGS "${EXE_CFLAGS} -fprofile-arcs -ftest-coverage")
    set(EXE_LDFLAGS "${EXE_LDFLAGS} -fprofile-arcs -ftest-coverage")
endif()

add_library(zig_cpp STATIC ${ZIG_CPP_SOURCES})
set_target_properties(zig_cpp PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
)

add_library(opt_c_util STATIC ${OPTIMIZED_C_SOURCES})
set_target_properties(opt_c_util PROPERTIES
    COMPILE_FLAGS "${OPTIMIZED_C_FLAGS}"
)

add_library(zigcompiler STATIC ${ZIG_SOURCES})
set_target_properties(zigcompiler PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zigcompiler LINK_PUBLIC
    zig_cpp
    opt_c_util
    ${SOFTFLOAT_LIBRARIES}
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)
if(NOT MSVC)
    target_link_libraries(zigcompiler LINK_PUBLIC ${LIBXML2})
endif()

if(ZIG_DIA_GUIDS_LIB)
    target_link_libraries(zigcompiler LINK_PUBLIC ${ZIG_DIA_GUIDS_LIB})
endif()

if(MSVC OR MINGW)
    target_link_libraries(zigcompiler LINK_PUBLIC version)
endif()

add_executable(zig0 "${ZIG_MAIN_SRC}" "${ZIG0_SHIM_SRC}")
set_target_properties(zig0 PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zig0 zigcompiler)

if(MSVC)
    set(LIBSTAGE2 "${CMAKE_BINARY_DIR}/zigstage2.lib")
else()
    set(LIBSTAGE2 "${CMAKE_BINARY_DIR}/libzigstage2.a")
endif()
if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(LIBSTAGE2_RELEASE_ARG "")
else()
    set(LIBSTAGE2_RELEASE_ARG --release-fast --strip)
endif()
if(WIN32)
    set(LIBSTAGE2_WINDOWS_ARGS "-lntdll")
else()
    set(LIBSTAGE2_WINDOWS_ARGS "")
endif()

set(BUILD_LIBSTAGE2_ARGS "build-lib"
    "src-self-hosted/stage2.zig"
    -mcpu=baseline
    --name zigstage2
    --override-lib-dir "${CMAKE_SOURCE_DIR}/lib"
    --cache on
    --output-dir "${CMAKE_BINARY_DIR}"
    ${LIBSTAGE2_RELEASE_ARG}
    --disable-gen-h
    --bundle-compiler-rt
    -fPIC
    -lc
    ${LIBSTAGE2_WINDOWS_ARGS}
)

add_custom_target(zig_build_libstage2 ALL
    COMMAND zig0 ${BUILD_LIBSTAGE2_ARGS}
    DEPENDS zig0
    BYPRODUCTS "${LIBSTAGE2}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)
add_executable(zig "${ZIG_MAIN_SRC}")

set_target_properties(zig PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)
target_link_libraries(zig zigcompiler "${LIBSTAGE2}")
if(MSVC)
  target_link_libraries(zig ntdll.lib)
elseif(MINGW) 
  target_link_libraries(zig ntdll)
endif()
add_dependencies(zig zig_build_libstage2)

install(TARGETS zig DESTINATION bin)

set(ZIG_INSTALL_ARGS "build"
    --override-lib-dir "${CMAKE_SOURCE_DIR}/lib"
    "-Dlib-files-only"
    --prefix "${CMAKE_INSTALL_PREFIX}"
    install
)

# CODE has no effect with Visual Studio build system generator, therefore
# when using Visual Studio build system generator we resort to running
# `zig build install` during the build phase.
if(MSVC)
    set(ZIG_SKIP_INSTALL_LIB_FILES off CACHE BOOL
        "Windows-only: Disable copying lib/ files to install prefix during the build phase")
    if(NOT ZIG_SKIP_INSTALL_LIB_FILES)
        add_custom_target(zig_install_lib_files ALL
            COMMAND zig ${ZIG_INSTALL_ARGS}
            DEPENDS zig
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        )
    endif()
else()
    get_target_property(zig_BINARY_DIR zig BINARY_DIR)
    install(CODE "set(zig_EXE \"${zig_BINARY_DIR}/zig\")")
    install(CODE "set(ZIG_INSTALL_ARGS \"${ZIG_INSTALL_ARGS}\")")
    install(CODE "set(CMAKE_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")")
    install(SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/cmake/install.cmake)
endif()
