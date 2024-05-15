/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ZIG_LLVM_HPP
#define ZIG_ZIG_LLVM_HPP

#include <stdbool.h>
#include <stddef.h>
#include <llvm-c/Core.h>
#include <llvm-c/Analysis.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

// ATTENTION: If you modify this file, be sure to update the corresponding
// extern function declarations in the self-hosted compiler.

ZIG_EXTERN_C bool ZigLLVMTargetMachineEmitToFile(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref,
        char **error_message, bool is_debug,
        bool is_small, bool time_report, bool tsan, bool lto,
        const char *asm_filename, const char *bin_filename,
        const char *llvm_ir_filename, const char *bitcode_filename);


enum ZigLLVMABIType {
    ZigLLVMABITypeDefault, // Target-specific (either soft or hard depending on triple, etc).
    ZigLLVMABITypeSoft,    // Soft float.
    ZigLLVMABITypeHard     // Hard float.
};

ZIG_EXTERN_C LLVMTargetMachineRef ZigLLVMCreateTargetMachine(LLVMTargetRef T, const char *Triple,
    const char *CPU, const char *Features, LLVMCodeGenOptLevel Level, LLVMRelocMode Reloc,
    LLVMCodeModel CodeModel, bool function_sections, bool data_sections, enum ZigLLVMABIType float_abi, 
    const char *abi_name);

ZIG_EXTERN_C void ZigLLVMSetOptBisectLimit(LLVMContextRef context_ref, int limit);

ZIG_EXTERN_C void ZigLLVMEnableBrokenDebugInfoCheck(LLVMContextRef context_ref);
ZIG_EXTERN_C bool ZigLLVMGetBrokenDebugInfo(LLVMContextRef context_ref);

enum ZigLLVMTailCallKind {
    ZigLLVMTailCallKindNone,
    ZigLLVMTailCallKindTail,
    ZigLLVMTailCallKindMustTail,
    ZigLLVMTailCallKindNoTail,
};

enum ZigLLVM_CallingConv {
    ZigLLVM_C = 0,
    ZigLLVM_Fast = 8,
    ZigLLVM_Cold = 9,
    ZigLLVM_GHC = 10,
    ZigLLVM_HiPE = 11,
    ZigLLVM_AnyReg = 13,
    ZigLLVM_PreserveMost = 14,
    ZigLLVM_PreserveAll = 15,
    ZigLLVM_Swift = 16,
    ZigLLVM_CXX_FAST_TLS = 17,
    ZigLLVM_Tail = 18,
    ZigLLVM_CFGuard_Check = 19,
    ZigLLVM_SwiftTail = 20,
    ZigLLVM_FirstTargetCC = 64,
    ZigLLVM_X86_StdCall = 64,
    ZigLLVM_X86_FastCall = 65,
    ZigLLVM_ARM_APCS = 66,
    ZigLLVM_ARM_AAPCS = 67,
    ZigLLVM_ARM_AAPCS_VFP = 68,
    ZigLLVM_MSP430_INTR = 69,
    ZigLLVM_X86_ThisCall = 70,
    ZigLLVM_PTX_Kernel = 71,
    ZigLLVM_PTX_Device = 72,
    ZigLLVM_SPIR_FUNC = 75,
    ZigLLVM_SPIR_KERNEL = 76,
    ZigLLVM_Intel_OCL_BI = 77,
    ZigLLVM_X86_64_SysV = 78,
    ZigLLVM_Win64 = 79,
    ZigLLVM_X86_VectorCall = 80,
    ZigLLVM_DUMMY_HHVM = 81,
    ZigLLVM_DUMMY_HHVM_C = 82,
    ZigLLVM_X86_INTR = 83,
    ZigLLVM_AVR_INTR = 84,
    ZigLLVM_AVR_SIGNAL = 85,
    ZigLLVM_AVR_BUILTIN = 86,
    ZigLLVM_AMDGPU_VS = 87,
    ZigLLVM_AMDGPU_GS = 88,
    ZigLLVM_AMDGPU_PS = 89,
    ZigLLVM_AMDGPU_CS = 90,
    ZigLLVM_AMDGPU_KERNEL = 91,
    ZigLLVM_X86_RegCall = 92,
    ZigLLVM_AMDGPU_HS = 93,
    ZigLLVM_MSP430_BUILTIN = 94,
    ZigLLVM_AMDGPU_LS = 95,
    ZigLLVM_AMDGPU_ES = 96,
    ZigLLVM_AArch64_VectorCall = 97,
    ZigLLVM_AArch64_SVE_VectorCall = 98,
    ZigLLVM_WASM_EmscriptenInvoke = 99,
    ZigLLVM_AMDGPU_Gfx = 100,
    ZigLLVM_M68k_INTR = 101,
    ZigLLVM_AArch64_SME_ABI_Support_Routines_PreserveMost_From_X0 = 102,
    ZigLLVM_AArch64_SME_ABI_Support_Routines_PreserveMost_From_X2 = 103,
    ZigLLVM_AMDGPU_CS_Chain = 104,
    ZigLLVM_AMDGPU_CS_ChainPreserve = 105,
    ZigLLVM_M68k_RTD = 106,
    ZigLLVM_GRAAL = 107,
    ZigLLVM_ARM64EC_Thunk_X64 = 108,
    ZigLLVM_ARM64EC_Thunk_Native = 109,
    ZigLLVM_MaxID = 1023,
};

ZIG_EXTERN_C void ZigLLVMSetModulePICLevel(LLVMModuleRef module);
ZIG_EXTERN_C void ZigLLVMSetModulePIELevel(LLVMModuleRef module);
ZIG_EXTERN_C void ZigLLVMSetModuleCodeModel(LLVMModuleRef module, LLVMCodeModel code_model);

ZIG_EXTERN_C void ZigLLVMParseCommandLineOptions(size_t argc, const char *const *argv);

// synchronize with llvm/include/ADT/Triple.h::ArchType
// synchronize with std.Target.Cpu.Arch
// synchronize with codegen/llvm/bindings.zig::ArchType
enum ZigLLVM_ArchType {
    ZigLLVM_UnknownArch,

    ZigLLVM_arm,            // ARM (little endian): arm, armv.*, xscale
    ZigLLVM_armeb,          // ARM (big endian): armeb
    ZigLLVM_aarch64,        // AArch64 (little endian): aarch64
    ZigLLVM_aarch64_be,     // AArch64 (big endian): aarch64_be
    ZigLLVM_aarch64_32,     // AArch64 (little endian) ILP32: aarch64_32
    ZigLLVM_arc,            // ARC: Synopsys ARC
    ZigLLVM_avr,            // AVR: Atmel AVR microcontroller
    ZigLLVM_bpfel,          // eBPF or extended BPF or 64-bit BPF (little endian)
    ZigLLVM_bpfeb,          // eBPF or extended BPF or 64-bit BPF (big endian)
    ZigLLVM_csky,           // CSKY: csky
    ZigLLVM_dxil,           // DXIL 32-bit DirectX bytecode
    ZigLLVM_hexagon,        // Hexagon: hexagon
    ZigLLVM_loongarch32,    // LoongArch (32-bit): loongarch32
    ZigLLVM_loongarch64,    // LoongArch (64-bit): loongarch64
    ZigLLVM_m68k,           // M68k: Motorola 680x0 family
    ZigLLVM_mips,           // MIPS: mips, mipsallegrex, mipsr6
    ZigLLVM_mipsel,         // MIPSEL: mipsel, mipsallegrexe, mipsr6el
    ZigLLVM_mips64,         // MIPS64: mips64, mips64r6, mipsn32, mipsn32r6
    ZigLLVM_mips64el,       // MIPS64EL: mips64el, mips64r6el, mipsn32el, mipsn32r6el
    ZigLLVM_msp430,         // MSP430: msp430
    ZigLLVM_ppc,            // PPC: powerpc
    ZigLLVM_ppcle,          // PPCLE: powerpc (little endian)
    ZigLLVM_ppc64,          // PPC64: powerpc64, ppu
    ZigLLVM_ppc64le,        // PPC64LE: powerpc64le
    ZigLLVM_r600,           // R600: AMD GPUs HD2XXX - HD6XXX
    ZigLLVM_amdgcn,         // AMDGCN: AMD GCN GPUs
    ZigLLVM_riscv32,        // RISC-V (32-bit): riscv32
    ZigLLVM_riscv64,        // RISC-V (64-bit): riscv64
    ZigLLVM_sparc,          // Sparc: sparc
    ZigLLVM_sparcv9,        // Sparcv9: Sparcv9
    ZigLLVM_sparcel,        // Sparc: (endianness = little). NB: 'Sparcle' is a CPU variant
    ZigLLVM_systemz,        // SystemZ: s390x
    ZigLLVM_tce,            // TCE (http://tce.cs.tut.fi/): tce
    ZigLLVM_tcele,          // TCE little endian (http://tce.cs.tut.fi/): tcele
    ZigLLVM_thumb,          // Thumb (little endian): thumb, thumbv.*
    ZigLLVM_thumbeb,        // Thumb (big endian): thumbeb
    ZigLLVM_x86,            // X86: i[3-9]86
    ZigLLVM_x86_64,         // X86-64: amd64, x86_64
    ZigLLVM_xcore,          // XCore: xcore
    ZigLLVM_xtensa,         // Tensilica: Xtensa
    ZigLLVM_nvptx,          // NVPTX: 32-bit
    ZigLLVM_nvptx64,        // NVPTX: 64-bit
    ZigLLVM_le32,           // le32: generic little-endian 32-bit CPU (PNaCl)
    ZigLLVM_le64,           // le64: generic little-endian 64-bit CPU (PNaCl)
    ZigLLVM_amdil,          // AMDIL
    ZigLLVM_amdil64,        // AMDIL with 64-bit pointers
    ZigLLVM_hsail,          // AMD HSAIL
    ZigLLVM_hsail64,        // AMD HSAIL with 64-bit pointers
    ZigLLVM_spir,           // SPIR: standard portable IR for OpenCL 32-bit version
    ZigLLVM_spir64,         // SPIR: standard portable IR for OpenCL 64-bit version
    ZigLLVM_spirv,          // SPIR-V with logical memory layout.
    ZigLLVM_spirv32,        // SPIR-V with 32-bit pointers
    ZigLLVM_spirv64,        // SPIR-V with 64-bit pointers
    ZigLLVM_kalimba,        // Kalimba: generic kalimba
    ZigLLVM_shave,          // SHAVE: Movidius vector VLIW processors
    ZigLLVM_lanai,          // Lanai: Lanai 32-bit
    ZigLLVM_wasm32,         // WebAssembly with 32-bit pointers
    ZigLLVM_wasm64,         // WebAssembly with 64-bit pointers
    ZigLLVM_renderscript32, // 32-bit RenderScript
    ZigLLVM_renderscript64, // 64-bit RenderScript
    ZigLLVM_ve,             // NEC SX-Aurora Vector Engine
    ZigLLVM_LastArchType = ZigLLVM_ve
};

enum ZigLLVM_VendorType {
    ZigLLVM_UnknownVendor,

    ZigLLVM_Apple,
    ZigLLVM_PC,
    ZigLLVM_SCEI,
    ZigLLVM_Freescale,
    ZigLLVM_IBM,
    ZigLLVM_ImaginationTechnologies,
    ZigLLVM_MipsTechnologies,
    ZigLLVM_NVIDIA,
    ZigLLVM_CSR,
    ZigLLVM_AMD,
    ZigLLVM_Mesa,
    ZigLLVM_SUSE,
    ZigLLVM_OpenEmbedded,

    ZigLLVM_LastVendorType = ZigLLVM_OpenEmbedded
};

// synchronize with llvm/include/ADT/Triple.h::OsType
// synchronize with std.Target.Os.Tag
// synchronize with codegen/llvm/bindings.zig::OsType
enum ZigLLVM_OSType {
    ZigLLVM_UnknownOS,

    ZigLLVM_Darwin,
    ZigLLVM_DragonFly,
    ZigLLVM_FreeBSD,
    ZigLLVM_Fuchsia,
    ZigLLVM_IOS,
    ZigLLVM_KFreeBSD,
    ZigLLVM_Linux,
    ZigLLVM_Lv2,        // PS3
    ZigLLVM_MacOSX,
    ZigLLVM_NetBSD,
    ZigLLVM_OpenBSD,
    ZigLLVM_Solaris,
    ZigLLVM_UEFI,
    ZigLLVM_Win32,
    ZigLLVM_ZOS,
    ZigLLVM_Haiku,
    ZigLLVM_RTEMS,
    ZigLLVM_NaCl,       // Native Client
    ZigLLVM_AIX,
    ZigLLVM_CUDA,       // NVIDIA CUDA
    ZigLLVM_NVCL,       // NVIDIA OpenCL
    ZigLLVM_AMDHSA,     // AMD HSA Runtime
    ZigLLVM_PS4,
    ZigLLVM_PS5,
    ZigLLVM_ELFIAMCU,
    ZigLLVM_TvOS,       // Apple tvOS
    ZigLLVM_WatchOS,    // Apple watchOS
    ZigLLVM_DriverKit,  // Apple DriverKit
    ZigLLVM_XROS,       // Apple XROS
    ZigLLVM_Mesa3D,
    ZigLLVM_AMDPAL,     // AMD PAL Runtime
    ZigLLVM_HermitCore, // HermitCore Unikernel/Multikernel
    ZigLLVM_Hurd,       // GNU/Hurd
    ZigLLVM_WASI,       // Experimental WebAssembly OS
    ZigLLVM_Emscripten,
    ZigLLVM_ShaderModel, // DirectX ShaderModel
    ZigLLVM_LiteOS,
    ZigLLVM_Serenity,
    ZigLLVM_Vulkan,      // Vulkan SPIR-V
    ZigLLVM_LastOSType = ZigLLVM_Vulkan
};

// Synchronize with target.cpp::abi_list
enum ZigLLVM_EnvironmentType {
    ZigLLVM_UnknownEnvironment,

    ZigLLVM_GNU,
    ZigLLVM_GNUABIN32,
    ZigLLVM_GNUABI64,
    ZigLLVM_GNUEABI,
    ZigLLVM_GNUEABIHF,
    ZigLLVM_GNUF32,
    ZigLLVM_GNUF64,
    ZigLLVM_GNUSF,
    ZigLLVM_GNUX32,
    ZigLLVM_GNUILP32,
    ZigLLVM_CODE16,
    ZigLLVM_EABI,
    ZigLLVM_EABIHF,
    ZigLLVM_Android,
    ZigLLVM_Musl,
    ZigLLVM_MuslEABI,
    ZigLLVM_MuslEABIHF,
    ZigLLVM_MuslX32,

    ZigLLVM_MSVC,
    ZigLLVM_Itanium,
    ZigLLVM_Cygnus,
    ZigLLVM_CoreCLR,
    ZigLLVM_Simulator, // Simulator variants of other systems, e.g., Apple's iOS
    ZigLLVM_MacABI, // Mac Catalyst variant of Apple's iOS deployment target.

    ZigLLVM_Pixel,
    ZigLLVM_Vertex,
    ZigLLVM_Geometry,
    ZigLLVM_Hull,
    ZigLLVM_Domain,
    ZigLLVM_Compute,
    ZigLLVM_Library,
    ZigLLVM_RayGeneration,
    ZigLLVM_Intersection,
    ZigLLVM_AnyHit,
    ZigLLVM_ClosestHit,
    ZigLLVM_Miss,
    ZigLLVM_Callable,
    ZigLLVM_Mesh,
    ZigLLVM_Amplification,
    ZigLLVM_OpenHOS,

    ZigLLVM_LastEnvironmentType = ZigLLVM_OpenHOS
};

enum ZigLLVM_ObjectFormatType {
    ZigLLVM_UnknownObjectFormat,

    ZigLLVM_COFF,
    ZigLLVM_DXContainer,
    ZigLLVM_ELF,
    ZigLLVM_GOFF,
    ZigLLVM_MachO,
    ZigLLVM_SPIRV,
    ZigLLVM_Wasm,
    ZigLLVM_XCOFF,
};

#define ZigLLVM_DIFlags_Zero 0U
#define ZigLLVM_DIFlags_Private 1U
#define ZigLLVM_DIFlags_Protected 2U
#define ZigLLVM_DIFlags_Public 3U
#define ZigLLVM_DIFlags_FwdDecl (1U << 2)
#define ZigLLVM_DIFlags_AppleBlock (1U << 3)
#define ZigLLVM_DIFlags_BlockByrefStruct (1U << 4)
#define ZigLLVM_DIFlags_Virtual (1U << 5)
#define ZigLLVM_DIFlags_Artificial (1U << 6)
#define ZigLLVM_DIFlags_Explicit (1U << 7)
#define ZigLLVM_DIFlags_Prototyped (1U << 8)
#define ZigLLVM_DIFlags_ObjcClassComplete (1U << 9)
#define ZigLLVM_DIFlags_ObjectPointer (1U << 10)
#define ZigLLVM_DIFlags_Vector (1U << 11)
#define ZigLLVM_DIFlags_StaticMember (1U << 12)
#define ZigLLVM_DIFlags_LValueReference (1U << 13)
#define ZigLLVM_DIFlags_RValueReference (1U << 14)
#define ZigLLVM_DIFlags_Reserved (1U << 15)
#define ZigLLVM_DIFlags_SingleInheritance (1U << 16)
#define ZigLLVM_DIFlags_MultipleInheritance (2 << 16)
#define ZigLLVM_DIFlags_VirtualInheritance (3 << 16)
#define ZigLLVM_DIFlags_IntroducedVirtual (1U << 18)
#define ZigLLVM_DIFlags_BitField (1U << 19)
#define ZigLLVM_DIFlags_NoReturn (1U << 20)
#define ZigLLVM_DIFlags_TypePassByValue (1U << 22)
#define ZigLLVM_DIFlags_TypePassByReference (1U << 23)
#define ZigLLVM_DIFlags_EnumClass (1U << 24)
#define ZigLLVM_DIFlags_Thunk (1U << 25)
#define ZigLLVM_DIFlags_NonTrivial (1U << 26)
#define ZigLLVM_DIFlags_BigEndian (1U << 27)
#define ZigLLVM_DIFlags_LittleEndian (1U << 28)
#define ZigLLVM_DIFlags_AllCallsDescribed (1U << 29)

ZIG_EXTERN_C bool ZigLLDLinkCOFF(int argc, const char **argv, bool can_exit_early, bool disable_output);
ZIG_EXTERN_C bool ZigLLDLinkELF(int argc, const char **argv, bool can_exit_early, bool disable_output);
ZIG_EXTERN_C bool ZigLLDLinkWasm(int argc, const char **argv, bool can_exit_early, bool disable_output);

ZIG_EXTERN_C bool ZigLLVMWriteArchive(const char *archive_name, const char **file_names, size_t file_name_count,
        enum ZigLLVM_OSType os_type);

ZIG_EXTERN_C bool ZigLLVMWriteImportLibrary(const char *def_path, const enum ZigLLVM_ArchType arch,
                               const char *output_lib_path, bool kill_at);

#endif
