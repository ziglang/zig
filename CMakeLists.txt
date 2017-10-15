cmake_minimum_required(VERSION 2.8.5)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Choose the type of build, options are: Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif()

project(zig C CXX)
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})


set(ZIG_VERSION_MAJOR 0)
set(ZIG_VERSION_MINOR 0)
set(ZIG_VERSION_PATCH 0)
set(ZIG_VERSION "${ZIG_VERSION_MAJOR}.${ZIG_VERSION_MINOR}.${ZIG_VERSION_PATCH}")

find_program(GIT_EXE NAMES git)
if(GIT_EXE)
    execute_process(
        COMMAND ${GIT_EXE} name-rev HEAD --tags --name-only --no-undefined --always
        OUTPUT_VARIABLE ZIG_GIT_REV
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(ZIG_GIT_REV MATCHES "\\\\^0$")
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
include_directories(${LLVM_INCLUDE_DIRS})

find_package(clang)
include_directories(${CLANG_INCLUDE_DIRS})

if(ZIG_FORCE_EXTERNAL_LLD)
    find_package(lld)
    include_directories(${LLD_INCLUDE_DIRS})
else()
    set(EMBEDDED_LLD_LIB_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Driver/DarwinLdDriver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Config/Version.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/YAML/ReaderWriterYAML.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/LayoutPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_arm64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ObjCPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileBinaryReader.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/CompactUnwindPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileToAtoms.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/TLVPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileYAML.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/GOTPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_x86.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileBinaryWriter.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_x86_64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachOLinkingContext.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ShimPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/WriterMachO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/StubsPass.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/ArchHandler_arm.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/MachO/MachONormalizedFileFromAtoms.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/ReaderWriter/FileArchive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/TargetOptionsCommandFlags.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/File.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Error.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Reader.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Reproduce.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Writer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/LinkingContext.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/Resolver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/lib/Core/DefinedAtom.cpp"
    )
    set(EMBEDDED_LLD_ELF_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/ScriptLexer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/AMDGPU.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/PPC.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/ARM.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/AVR.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/SPARCV9.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/Mips.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/AArch64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/X86_64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/PPC64.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/MipsArchTree.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Arch/X86.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/GdbIndex.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Relocations.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Error.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/LTO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Strings.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/ScriptParser.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/MarkLive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/SyntheticSections.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/LinkerScript.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/EhFrame.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Target.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Filesystem.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/OutputSections.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Symbols.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/ICF.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/InputFiles.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Thunks.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/DriverUtils.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/Writer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/InputSection.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF/MapFile.cpp"
    )
    set(EMBEDDED_LLD_COFF_SOURCES
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/DLL.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Driver.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Chunks.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/PDB.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Error.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/LTO.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Strings.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MarkLive.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/SymbolTable.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Symbols.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/ICF.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/InputFiles.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/DriverUtils.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/Writer.cpp"
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF/MapFile.cpp"
    )
    add_library(embedded_lld_lib ${EMBEDDED_LLD_LIB_SOURCES})
    add_library(embedded_lld_elf ${EMBEDDED_LLD_ELF_SOURCES})
    add_library(embedded_lld_coff ${EMBEDDED_LLD_COFF_SOURCES})
    if(MSVC)
        set(ZIG_LLD_COMPILE_FLAGS "-std=c++11 -D_CRT_SECURE_NO_WARNINGS")
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
    target_include_directories(embedded_lld_lib PUBLIC
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    target_include_directories(embedded_lld_elf PUBLIC
        "${CMAKE_SOURCE_DIR}/deps/lld/ELF"
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt/ELF"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    target_include_directories(embedded_lld_coff PUBLIC
        "${CMAKE_SOURCE_DIR}/deps/lld/COFF"
        "${CMAKE_SOURCE_DIR}/deps/lld/include"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt/COFF"
        "${CMAKE_SOURCE_DIR}/deps/lld-prebuilt"
    )
    set(LLD_INCLUDE_DIRS "")
    set(LLD_LIBRARIES
        embedded_lld_elf
        embedded_lld_coff
        embedded_lld_lib
    )
endif()

# No patches have been applied to SoftFloat-3d
set(EMBEDDED_SOFTFLOAT_SOURCES
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/f128M_isSignalingNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/s_commonNaNToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/s_commonNaNToF32UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/s_commonNaNToF64UI.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/s_f128MToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/s_f32UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/s_f64UIToCommonNaN.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/s_propagateNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086/softfloat_raiseFlags.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_add.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_div.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_eq.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_eq_signaling.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_le.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_le_quiet.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_lt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_lt_quiet.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_mul.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_mulAdd.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_rem.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_roundToInt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_sqrt.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_sub.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_f16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_f32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_f64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_i32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_i32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_i64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_i64_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_ui32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_ui32_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_ui64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f128M_to_ui64_r_minMag.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/f64_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_add256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_addCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_addComplCarryM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_addF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_addM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_addMagsF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_addMagsF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_addMagsF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_approxRecip32_1.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_approxRecipSqrt32_1.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_approxRecipSqrt_1Ks.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_approxRecip_1Ks.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_compare128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_compare96M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_countLeadingZeros16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_countLeadingZeros32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_countLeadingZeros64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_countLeadingZeros8.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_eq128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_invalidF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_isNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_le128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_lt128.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_mul128MTo256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_mul64To128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_mulAddF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_mulAddF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_mulAddF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_mulAddF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_negXM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normRoundPackMToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normRoundPackToF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normRoundPackToF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normRoundPackToF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normSubnormalF128SigM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normSubnormalF16Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normSubnormalF32Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_normSubnormalF64Sig.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_remStepMBy32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundMToI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundMToUI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundPackMToF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundPackToF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundPackToF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundPackToF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundToI32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundToI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundToUI32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_roundToUI64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shiftLeftM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shiftNormSigF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shiftRightJam256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shiftRightJam32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shiftRightJam64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shiftRightJamM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shiftRightM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shortShiftLeft64To96M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shortShiftLeftM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shortShiftRightExtendM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shortShiftRightJam64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shortShiftRightJamM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_shortShiftRightM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_sub1XM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_sub256M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_subM.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_subMagsF16.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_subMagsF32.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_subMagsF64.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/s_tryPropagateNaNF128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/softfloat_state.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/ui32_to_f128M.c"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/ui64_to_f128M.c"
)
add_library(embedded_softfloat ${EMBEDDED_SOFTFLOAT_SOURCES})
if(MSVC)
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "-std=c99"
    )
else()
    set_target_properties(embedded_softfloat PROPERTIES
        COMPILE_FLAGS "-std=c99"
    )
endif()
target_include_directories(embedded_softfloat PUBLIC
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d-prebuilt"
    "${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/8086"
)
include_directories("${CMAKE_SOURCE_DIR}/deps/SoftFloat-3d/source/include")
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
    "${CMAKE_SOURCE_DIR}/src/target.cpp"
    "${CMAKE_SOURCE_DIR}/src/tokenizer.cpp"
    "${CMAKE_SOURCE_DIR}/src/util.cpp"
    "${CMAKE_SOURCE_DIR}/src/parsec.cpp"
    "${CMAKE_SOURCE_DIR}/src/zig_llvm.cpp"
)

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
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
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

add_executable(zig ${ZIG_SOURCES})
set_target_properties(zig PROPERTIES
    COMPILE_FLAGS ${EXE_CFLAGS}
    LINK_FLAGS ${EXE_LDFLAGS}
)

target_link_libraries(zig LINK_PUBLIC
    ${SOFTFLOAT_LIBRARIES}
    ${CLANG_LIBRARIES}
    ${LLD_LIBRARIES}
    ${LLVM_LIBRARIES}
    ${CMAKE_THREAD_LIBS_INIT}
)
if(MSVC OR MINGW)
    target_link_libraries(zig LINK_PUBLIC version)
endif()
install(TARGETS zig DESTINATION bin)

install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__clang_cuda_builtin_vars.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__clang_cuda_cmath.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__clang_cuda_complex_builtins.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__clang_cuda_intrinsics.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__clang_cuda_math_forward_declares.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__clang_cuda_runtime_wrapper.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__stddef_max_align_t.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__wmmintrin_aes.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/__wmmintrin_pclmul.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/adxintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/altivec.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/ammintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/arm_acle.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/arm_neon.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/armintr.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx2intrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512bwintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512cdintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512dqintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512erintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512fintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512ifmaintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512ifmavlintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512pfintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512vbmiintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512vbmivlintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512vlbwintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512vlcdintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512vldqintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512vlintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avx512vpopcntdqintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/avxintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/bmi2intrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/bmiintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/clflushoptintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/clzerointrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/cpuid.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/cuda_wrappers/algorithm" DESTINATION "${C_HEADERS_DEST}/cuda_wrappers")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/cuda_wrappers/complex" DESTINATION "${C_HEADERS_DEST}/cuda_wrappers")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/cuda_wrappers/new" DESTINATION "${C_HEADERS_DEST}/cuda_wrappers")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/emmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/f16cintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/float.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/fma4intrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/fmaintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/fxsrintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/htmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/htmxlintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/ia32intrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/immintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/intrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/inttypes.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/iso646.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/limits.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/lwpintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/lzcntintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/mm3dnow.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/mm_malloc.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/mmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/module.modulemap" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/msa.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/mwaitxintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/nmmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/opencl-c.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/pkuintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/pmmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/popcntintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/prfchwintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/rdseedintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/rtmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/s390intrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/shaintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/smmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/stdalign.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/stdarg.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/stdatomic.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/stdbool.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/stddef.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/stdint.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/stdnoreturn.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/tbmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/tgmath.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/tmmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/unwind.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/vadefs.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/varargs.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/vecintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/wmmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/x86intrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/xmmintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/xopintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/xsavecintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/xsaveintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/xsaveoptintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/xsavesintrin.h" DESTINATION "${C_HEADERS_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/c_headers/xtestintrin.h" DESTINATION "${C_HEADERS_DEST}")

install(FILES "${CMAKE_SOURCE_DIR}/std/array_list.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/base64.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/buf_map.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/buf_set.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/buffer.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/build.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/c/darwin.zig" DESTINATION "${ZIG_STD_DEST}/c")
install(FILES "${CMAKE_SOURCE_DIR}/std/c/index.zig" DESTINATION "${ZIG_STD_DEST}/c")
install(FILES "${CMAKE_SOURCE_DIR}/std/c/linux.zig" DESTINATION "${ZIG_STD_DEST}/c")
install(FILES "${CMAKE_SOURCE_DIR}/std/c/windows.zig" DESTINATION "${ZIG_STD_DEST}/c")
install(FILES "${CMAKE_SOURCE_DIR}/std/cstr.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/debug.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/dwarf.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/elf.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/empty.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/endian.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/fmt/errol/enum3.zig" DESTINATION "${ZIG_STD_DEST}/fmt/errol")
install(FILES "${CMAKE_SOURCE_DIR}/std/fmt/errol/index.zig" DESTINATION "${ZIG_STD_DEST}/fmt/errol")
install(FILES "${CMAKE_SOURCE_DIR}/std/fmt/errol/lookup.zig" DESTINATION "${ZIG_STD_DEST}/fmt/errol")
install(FILES "${CMAKE_SOURCE_DIR}/std/fmt/index.zig" DESTINATION "${ZIG_STD_DEST}/fmt")
install(FILES "${CMAKE_SOURCE_DIR}/std/hash_map.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/index.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/io.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/linked_list.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/acos.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/acosh.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/asin.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/asinh.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/atan.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/atan2.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/atanh.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/cbrt.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/ceil.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/copysign.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/cos.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/cosh.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/exp.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/exp2.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/expm1.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/expo2.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/fabs.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/floor.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/fma.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/frexp.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/hypot.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/ilogb.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/index.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/inf.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/isfinite.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/isinf.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/isnan.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/isnormal.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/ln.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/log.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/log10.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/log1p.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/log2.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/modf.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/nan.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/pow.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/round.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/scalbn.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/signbit.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/sin.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/sinh.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/sqrt.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/tan.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/tanh.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/math/trunc.zig" DESTINATION "${ZIG_STD_DEST}/math")
install(FILES "${CMAKE_SOURCE_DIR}/std/mem.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/net.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/child_process.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/darwin.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/darwin_errno.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/get_user_id.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/index.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/linux.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/linux_errno.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/linux_i386.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/linux_x86_64.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/path.zig" DESTINATION "${ZIG_STD_DEST}/os")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/windows/error.zig" DESTINATION "${ZIG_STD_DEST}/os/windows")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/windows/index.zig" DESTINATION "${ZIG_STD_DEST}/os/windows")
install(FILES "${CMAKE_SOURCE_DIR}/std/os/windows/util.zig" DESTINATION "${ZIG_STD_DEST}/os/windows")
install(FILES "${CMAKE_SOURCE_DIR}/std/rand.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/sort.zig" DESTINATION "${ZIG_STD_DEST}")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/bootstrap.zig" DESTINATION "${ZIG_STD_DEST}/special")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/build_file_template.zig" DESTINATION "${ZIG_STD_DEST}/special")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/build_runner.zig" DESTINATION "${ZIG_STD_DEST}/special")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/builtin.zig" DESTINATION "${ZIG_STD_DEST}/special")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/aulldiv.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/aullrem.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/comparetf2.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixuint.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunsdfdi.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunsdfsi.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunsdfti.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunssfdi.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunssfsi.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunssfti.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunstfdi.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunstfsi.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/fixunstfti.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/index.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/udivti3.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/udivmod.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/udivmoddi4.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/udivmodti4.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/compiler_rt/umodti3.zig" DESTINATION "${ZIG_STD_DEST}/special/compiler_rt")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/panic.zig" DESTINATION "${ZIG_STD_DEST}/special")
install(FILES "${CMAKE_SOURCE_DIR}/std/special/test_runner.zig" DESTINATION "${ZIG_STD_DEST}/special")

if (ZIG_TEST_COVERAGE)
    add_custom_target(coverage
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMAND lcov --directory . --zerocounters --rc lcov_branch_coverage=1
        COMMAND ./zig build --build-file ../build.zig test
        COMMAND lcov --directory . --capture --output-file coverage.info --rc lcov_branch_coverage=1
        COMMAND lcov --remove coverage.info '/usr/*' --output-file coverage.info.cleaned --rc lcov_branch_coverage=1
        COMMAND genhtml -o coverage coverage.info.cleaned --rc lcov_branch_coverage=1
        COMMAND rm coverage.info coverage.info.cleaned
    )
endif()

