cmake_minimum_required(VERSION 2.8.5)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

project(zig C CXX)
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})


set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 1)
set(ZIG_VERSION_PATCH 1)
set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")

find_program(GIT_EXE NAMES git)
if(GIT_EXE)
    execute_process(
        COMMAND ${GIT_EXE} name-rev HEAD --tags --name-only --no-undefined --always
        OUTPUT_VARIABLE ZIG_GIT_REV
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(ZIG_GIT_REV MATCHES "\\^0$")
        if(NOT("${ZIG_GIT_REV}" STREQUAL "${ZIG_VERSION}^0"))
            message("WARNING: Tag does not match configured Zig version")
        endif()
    else()
        set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}.${ZIG_GIT_REV}")
    endif()
endif()
message("Configuring zig version ${ZIG_VERSION}")

set(ZIG_LIBC_LIB_DIR "" CACHE STRING "Default native target libc directory where crt1.o can be found")
set(ZIG_LIBC_STATIC_LIB_DIR "" CACHE STRING "Default native target libc directory where crtbeginT.o can be found")
set(ZIG_LIBC_INCLUDE_DIR "/usr/include" CACHE STRING "Default native target libc include directory")
set(ZIG_DYNAMIC_LINKER "" CACHE STRING "Override dynamic linker for native target")
set(ZIG_EACH_LIB_RPATH off CACHE BOOL "Add each dynamic library to rpath for native target")

string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_LIB_DIR_ESCAPED "${ZIG_LIBC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_STATIC_LIB_DIR_ESCAPED "${ZIG_LIBC_STATIC_LIB_DIR}")
string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_LIBC_INCLUDE_DIR_ESCAPED "${ZIG_LIBC_INCLUDE_DIR}")

option(ZIG_TEST_COVERAGE "Build Zig with test coverage instrumentation" OFF)

# To see what patches have been applied to LLD in this repository:
# git log -p -- deps/lld
option(ZIG_FORCE_EXTERNAL_LLD "If your system has the LLD patches use it instead of the embedded LLD" OFF)

find_package(llvm)
find_package(clang)

set(ZIG_CPP_LIB_DIR "${CMAKE_BINARY_DIR}/zig_cpp")

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
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Memory.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Reproduce.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Strings.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/TargetOptionsCommandFlags.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/Common/Threads.cpp"
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
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/Mips.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/MipsArchTree.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/PPC.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/PPC64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/SPARCV9.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/X86.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/X86_64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/DriverUtils.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/EhFrame.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Filesystem.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/GdbIndex.cpp"
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
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Strings.cpp"
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
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/DriverUtils.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/ICF.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/InputFiles.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/LTO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MapFile.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MarkLive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MinGW.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/PDB.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Strings.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Symbols.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Writer.cpp"
    )
    set(EMBEDDED_LLD_MINGW_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/MinGW/Driver.cpp"
    )
    set(EMBEDDED_LLD_WASM_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/InputFiles.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/InputSegment.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/OutputSections.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/Symbols.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/Writer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/wasm/WriterUtils.cpp"
    )
    add_library(embedded_lld_lib ${EMBEDDED_LLD_LIB_SOURCES})
    add_library(embedded_lld_elf ${EMBEDDED_LLD_ELF_SOURCES})
    add_library(embedded_lld_coff ${EMBEDDED_LLD_COFF_SOURCES})
    add_library(embedded_lld_mingw ${EMBEDDED_LLD_MINGW_SOURCES})
    add_library(embedded_lld_wasm ${EMBEDDED_LLD_WASM_SOURCES})
    if(MSVC)
        set(ZIG_LLD_COMPILE_FLAGS "-std=c++11 -D_CRT_SECURE_NO_WARNINGS /w")
    else()
        set(ZIG_LLD_COMPILE_FLAGS "-std=c++11 -fno-exceptions -fno-rtti -Wno-comment")
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
    install(TARGETS embedded_lld_elf embedded_lld_coff embedded_lld_mingw embedded_lld_wasm embedded_lld_lib DESTINATION "${ZIG_CPP_LIB_DIR}")
endif()

# No patches have been applied to SoftFloat-3e
set(EMBEDDED_SOFTFLOAT_SOURCES
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/f128M_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF32UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_commonNaNToF64UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f128MToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f32UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_f64UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086/s_propagateNaNF128M.c"
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
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/f64_to_f128M.c"
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
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/softfloat_state.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/ui64_to_f128M.c"
)
add_library(embedded_softfloat ${EMBEDDED_SOFTFLOAT_SOURCES})
if(MSVC)
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "-std=c99 /w"
    )
else()
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "-std=c99"
    )
endif()
target_include_directories(embedded_softfloat PUBLIC
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e-prebuilt"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/8086"
)
include_directories("${CMAKE_SOURCE_DIR}/deps/SoftFloat-3e/source/include")
set(SOFTFLOAT_LIBRARIES embedded_softfloat)

find_package(Threads)

set(ZIG_SOURCES
    "${CMAKE_SOURCE_DIR}/src/analyze.cpp"
    "${CMAKE_SOURCE_DIR}/src/ast_render.cpp"
    "${CMAKE_SOURCE_DIR}/src/bigfloat.cpp"
    "${CMAKE_SOURCE_DIR}/src/bigint.cpp"
    "${CMAKE_SOURCE_DIR}/src/buffer.cpp"
    "${CMAKE_SOURCE_DIR}/src/c_tokenizer.cpp"
    "${CMAKE_SOURCE_DIR}/src/codegen.cpp"
    "${CMAKE_SOURCE_DIR}/src/errmsg.cpp"
    "${CMAKE_SOURCE_DIR}/src/error.cpp"
    "${CMAKE_SOURCE_DIR}/src/ir.cpp"
    "${CMAKE_SOURCE_DIR}/src/ir_print.cpp"
    "${CMAKE_SOURCE_DIR}/src/link.cpp"
    "${CMAKE_SOURCE_DIR}/src/main.cpp"
    "${CMAKE_SOURCE_DIR}/src/os.cpp"
    "${CMAKE_SOURCE_DIR}/src/parser.cpp"
    "${CMAKE_SOURCE_DIR}/src/range_set.cpp"
    "${CMAKE_SOURCE_DIR}/src/metadata_render.cpp"
    "${CMAKE_SOURCE_DIR}/src/target.cpp"
    "${CMAKE_SOURCE_DIR}/src/tokenizer.cpp"
    "${CMAKE_SOURCE_DIR}/src/util.cpp"
    "${CMAKE_SOURCE_DIR}/src/translate_c.cpp"
)
set(ZIG_CPP_SOURCES
    "${CMAKE_SOURCE_DIR}/src/zig_llvm.cpp"
)

set(ZIG_STD_FILES
    "array_list.zig"
    "base64.zig"
    "buf_map.zig"
    "buf_set.zig"
    "buffer.zig"
    "build.zig"
    "c/darwin.zig"
    "c/index.zig"
    "c/linux.zig"
    "c/windows.zig"
    "crypto/index.zig"
    "crypto/md5.zig"
    "crypto/sha1.zig"
    "crypto/sha2.zig"
    "crypto/sha3.zig"
    "crypto/blake2.zig"
    "cstr.zig"
    "debug/failing_allocator.zig"
    "debug/index.zig"
    "dwarf.zig"
    "elf.zig"
    "empty.zig"
    "endian.zig"
    "fmt/errol/enum3.zig"
    "fmt/errol/index.zig"
    "fmt/errol/lookup.zig"
    "fmt/index.zig"
    "hash_map.zig"
    "heap.zig"
    "index.zig"
    "io.zig"
    "linked_list.zig"
    "macho.zig"
    "math/acos.zig"
    "math/acosh.zig"
    "math/asin.zig"
    "math/asinh.zig"
    "math/atan.zig"
    "math/atan2.zig"
    "math/atanh.zig"
    "math/cbrt.zig"
    "math/ceil.zig"
    "math/copysign.zig"
    "math/cos.zig"
    "math/cosh.zig"
    "math/exp.zig"
    "math/exp2.zig"
    "math/expm1.zig"
    "math/expo2.zig"
    "math/fabs.zig"
    "math/floor.zig"
    "math/fma.zig"
    "math/frexp.zig"
    "math/hypot.zig"
    "math/ilogb.zig"
    "math/index.zig"
    "math/inf.zig"
    "math/isfinite.zig"
    "math/isinf.zig"
    "math/isnan.zig"
    "math/isnormal.zig"
    "math/ln.zig"
    "math/log.zig"
    "math/log10.zig"
    "math/log1p.zig"
    "math/log2.zig"
    "math/modf.zig"
    "math/nan.zig"
    "math/pow.zig"
    "math/round.zig"
    "math/scalbn.zig"
    "math/signbit.zig"
    "math/sin.zig"
    "math/sinh.zig"
    "math/sqrt.zig"
    "math/tan.zig"
    "math/tanh.zig"
    "math/trunc.zig"
    "math/x86_64/sqrt.zig"
    "mem.zig"
    "net.zig"
    "os/child_process.zig"
    "os/darwin.zig"
    "os/darwin_errno.zig"
    "os/file.zig"
    "os/get_user_id.zig"
    "os/index.zig"
    "os/linux/errno.zig"
    "os/linux/i386.zig"
    "os/linux/index.zig"
    "os/linux/x86_64.zig"
    "os/path.zig"
    "os/windows/error.zig"
    "os/windows/index.zig"
    "os/windows/util.zig"
    "os/zen.zig"
    "rand.zig"
    "sort.zig"
    "special/bootstrap.zig"
    "special/bootstrap_lib.zig"
    "special/build_file_template.zig"
    "special/build_runner.zig"
    "special/builtin.zig"
    "special/compiler_rt/aulldiv.zig"
    "special/compiler_rt/aullrem.zig"
    "special/compiler_rt/comparetf2.zig"
    "special/compiler_rt/fixuint.zig"
    "special/compiler_rt/fixunsdfdi.zig"
    "special/compiler_rt/fixunsdfsi.zig"
    "special/compiler_rt/fixunsdfti.zig"
    "special/compiler_rt/fixunssfdi.zig"
    "special/compiler_rt/fixunssfsi.zig"
    "special/compiler_rt/fixunssfti.zig"
    "special/compiler_rt/fixunstfdi.zig"
    "special/compiler_rt/fixunstfsi.zig"
    "special/compiler_rt/fixunstfti.zig"
    "special/compiler_rt/index.zig"
    "special/compiler_rt/udivmod.zig"
    "special/compiler_rt/udivmoddi4.zig"
    "special/compiler_rt/udivmodti4.zig"
    "special/compiler_rt/udivti3.zig"
    "special/compiler_rt/umodti3.zig"
    "special/panic.zig"
    "special/test_runner.zig"
    "unicode.zig"
    "zig/ast.zig"
    "zig/index.zig"
    "zig/parser.zig"
    "zig/tokenizer.zig"
)

set(ZIG_C_HEADER_FILES
    "__clang_cuda_builtin_vars.h"
    "__clang_cuda_cmath.h"
    "__clang_cuda_complex_builtins.h"
    "__clang_cuda_intrinsics.h"
    "__clang_cuda_math_forward_declares.h"
    "__clang_cuda_runtime_wrapper.h"
    "__stddef_max_align_t.h"
    "__wmmintrin_aes.h"
    "__wmmintrin_pclmul.h"
    "adxintrin.h"
    "altivec.h"
    "ammintrin.h"
    "arm64intr.h"
    "arm_acle.h"
    "arm_neon.h"
    "armintr.h"
    "avx2intrin.h"
    "avx512bitalgintrin.h"
    "avx512bwintrin.h"
    "avx512cdintrin.h"
    "avx512dqintrin.h"
    "avx512erintrin.h"
    "avx512fintrin.h"
    "avx512ifmaintrin.h"
    "avx512ifmavlintrin.h"
    "avx512pfintrin.h"
    "avx512vbmi2intrin.h"
    "avx512vbmiintrin.h"
    "avx512vbmivlintrin.h"
    "avx512vlbitalgintrin.h"
    "avx512vlbwintrin.h"
    "avx512vlcdintrin.h"
    "avx512vldqintrin.h"
    "avx512vlintrin.h"
    "avx512vlvbmi2intrin.h"
    "avx512vlvnniintrin.h"
    "avx512vnniintrin.h"
    "avx512vpopcntdqintrin.h"
    "avx512vpopcntdqvlintrin.h"
    "avxintrin.h"
    "bmi2intrin.h"
    "bmiintrin.h"
    "cetintrin.h"
    "clflushoptintrin.h"
    "clwbintrin.h"
    "clzerointrin.h"
    "cpuid.h"
    "cuda_wrappers/algorithm"
    "cuda_wrappers/complex"
    "cuda_wrappers/new"
    "emmintrin.h"
    "f16cintrin.h"
    "float.h"
    "fma4intrin.h"
    "fmaintrin.h"
    "fxsrintrin.h"
    "gfniintrin.h"
    "htmintrin.h"
    "htmxlintrin.h"
    "ia32intrin.h"
    "immintrin.h"
    "intrin.h"
    "inttypes.h"
    "iso646.h"
    "limits.h"
    "lwpintrin.h"
    "lzcntintrin.h"
    "mm3dnow.h"
    "mm_malloc.h"
    "mmintrin.h"
    "module.modulemap"
    "msa.h"
    "mwaitxintrin.h"
    "nmmintrin.h"
    "opencl-c.h"
    "pkuintrin.h"
    "pmmintrin.h"
    "popcntintrin.h"
    "prfchwintrin.h"
    "rdseedintrin.h"
    "rtmintrin.h"
    "s390intrin.h"
    "shaintrin.h"
    "smmintrin.h"
    "stdalign.h"
    "stdarg.h"
    "stdatomic.h"
    "stdbool.h"
    "stddef.h"
    "stdint.h"
    "stdnoreturn.h"
    "tbmintrin.h"
    "tgmath.h"
    "tmmintrin.h"
    "unwind.h"
    "vadefs.h"
    "vaesintrin.h"
    "varargs.h"
    "vecintrin.h"
    "vpclmulqdqintrin.h"
    "wmmintrin.h"
    "x86intrin.h"
    "xmmintrin.h"
    "xopintrin.h"
    "xsavecintrin.h"
    "xsaveintrin.h"
    "xsaveoptintrin.h"
    "xsavesintrin.h"
    "xtestintrin.h"
)

if(MSVC)
    set(MSVC_DIA_SDK_DIR "$ENV{VSINSTALLDIR}DIA SDK")
    if (IS_DIRECTORY ${MSVC_DIA_SDK_DIR})
        set(ZIG_DIA_GUIDS_LIB "${MSVC_DIA_SDK_DIR}/lib/amd64/diaguids.lib")
        string(REGEX REPLACE "\\\\" "\\\\\\\\" ZIG_DIA_GUIDS_LIB_ESCAPED "${ZIG_DIA_GUIDS_LIB}")
    endif()
endif()

set(ZIG_LIB_DIR "lib/zig")
set(C_HEADERS_DEST "${ZIG_LIB_DIR}/include")
set(ZIG_STD_DEST "${ZIG_LIB_DIR}/std")
set(CONFIGURE_OUT_FILE "${CMAKE_BINARY_DIR}/config.h")
configure_file (
    "${CMAKE_SOURCE_DIR}/src/config.h.in"
    ${CONFIGURE_OUT_FILE}
)

include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
    "${CMAKE_SOURCE_DIR}/src"
)

if(MSVC)
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /w")
elseif(MINGW)
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wall -Werror -Wno-error=format= -Wno-error=format -Wno-error=format-extra-args")
else()
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Werror -Wall")
endif()

if(MSVC)
  set(EXE_CFLAGS "-std=c++11")
else()
  set(EXE_CFLAGS "-std=c++11 -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -D_GNU_SOURCE -fno-exceptions -fno-rtti  -Werror=strict-prototypes -Werror=old-style-definition -Werror=type-limits -Wno-missing-braces")
endif()

set(EXE_LDFLAGS " ")
if(MINGW)
    set(EXE_LDFLAGS "-static -static-libgcc -static-libstdc++")
elseif(MSVC)
    set(EXE_LDFLAGS "/STACK:16777216")
else()
    set(EXE_LDFLAGS " ")
endif()
if(ZIG_TEST_COVERAGE)
    set(EXE_CFLAGS "${EXE_CFLAGS} -fprofile-arcs -ftest-coverage")
    set(EXE_LDFLAGS "${EXE_LDFLAGS} -fprofile-arcs -ftest-coverage")
endif()

add_library(zig_cpp STATIC ${ZIG_CPP_SOURCES})
set_target_properties(zig_cpp PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
)

add_executable(zig ${ZIG_SOURCES})
set_target_properties(zig PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)

target_link_libraries(zig LINK_PUBLIC
    zig_cpp
    ${SOFTFLOAT_LIBRARIES}
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)
if(NOT MSVC)
    target_link_libraries(zig LINK_PUBLIC xml2)
endif()
if(ZIG_DIA_GUIDS_LIB)
    target_link_libraries(zig LINK_PUBLIC ${ZIG_DIA_GUIDS_LIB})
endif()

if(MSVC OR MINGW)
    target_link_libraries(zig LINK_PUBLIC version)
endif()
install(TARGETS zig DESTINATION bin)
install(TARGETS zig_cpp DESTINATION "${ZIG_CPP_LIB_DIR}")

foreach(file ${ZIG_C_HEADER_FILES})
    get_filename_component(file_dir "${C_HEADERS_DEST}/${file}" DIRECTORY)
    install(FILES "${CMAKE_SOURCE_DIR}/c_headers/${file}" DESTINATION "${file_dir}")
endforeach()

foreach(file ${ZIG_STD_FILES})
    get_filename_component(file_dir "${ZIG_STD_DEST}/${file}" DIRECTORY)
    install(FILES "${CMAKE_SOURCE_DIR}/std/${file}" DESTINATION "${file_dir}")
endforeach()
