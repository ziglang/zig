/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "buffer.hpp"
#include "error.hpp"
#include "target.hpp"
#include "util.hpp"
#include "os.hpp"

#include <stdio.h>

static const ZigLLVM_ArchType arch_list[] = {
    ZigLLVM_arm,            // ARM (little endian): arm, armv.*, xscale
    ZigLLVM_armeb,          // ARM (big endian): armeb
    ZigLLVM_aarch64,        // AArch64 (little endian): aarch64
    ZigLLVM_aarch64_be,     // AArch64 (big endian): aarch64_be
    ZigLLVM_aarch64_32,     // AArch64 (little endian) ILP32: aarch64_32
    ZigLLVM_arc,            // ARC: Synopsys ARC
    ZigLLVM_avr,            // AVR: Atmel AVR microcontroller
    ZigLLVM_bpfel,          // eBPF or extended BPF or 64-bit BPF (little endian)
    ZigLLVM_bpfeb,          // eBPF or extended BPF or 64-bit BPF (big endian)
    ZigLLVM_hexagon,        // Hexagon: hexagon
    ZigLLVM_mips,           // MIPS: mips, mipsallegrex, mipsr6
    ZigLLVM_mipsel,         // MIPSEL: mipsel, mipsallegrexe, mipsr6el
    ZigLLVM_mips64,         // MIPS64: mips64, mips64r6, mipsn32, mipsn32r6
    ZigLLVM_mips64el,       // MIPS64EL: mips64el, mips64r6el, mipsn32el, mipsn32r6el
    ZigLLVM_msp430,         // MSP430: msp430
    ZigLLVM_ppc,            // PPC: powerpc
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
    ZigLLVM_kalimba,        // Kalimba: generic kalimba
    ZigLLVM_shave,          // SHAVE: Movidius vector VLIW processors
    ZigLLVM_lanai,          // Lanai: Lanai 32-bit
    ZigLLVM_wasm32,         // WebAssembly with 32-bit pointers
    ZigLLVM_wasm64,         // WebAssembly with 64-bit pointers
    ZigLLVM_renderscript32, // 32-bit RenderScript
    ZigLLVM_renderscript64, // 64-bit RenderScript
    ZigLLVM_ve,             // NEC SX-Aurora Vector Engine
};

static const ZigLLVM_VendorType vendor_list[] = {
    ZigLLVM_Apple,
    ZigLLVM_PC,
    ZigLLVM_SCEI,
    ZigLLVM_BGP,
    ZigLLVM_BGQ,
    ZigLLVM_Freescale,
    ZigLLVM_IBM,
    ZigLLVM_ImaginationTechnologies,
    ZigLLVM_MipsTechnologies,
    ZigLLVM_NVIDIA,
    ZigLLVM_CSR,
    ZigLLVM_Myriad,
    ZigLLVM_AMD,
    ZigLLVM_Mesa,
    ZigLLVM_SUSE,
};

static const Os os_list[] = {
    OsFreestanding,
    OsAnanas,
    OsCloudABI,
    OsDragonFly,
    OsFreeBSD,
    OsFuchsia,
    OsIOS,
    OsKFreeBSD,
    OsLinux,
    OsLv2,        // PS3
    OsMacOSX,
    OsNetBSD,
    OsOpenBSD,
    OsSolaris,
    OsWindows,
    OsHaiku,
    OsMinix,
    OsRTEMS,
    OsNaCl,       // Native Client
    OsCNK,        // BG/P Compute-Node Kernel
    OsAIX,
    OsCUDA,       // NVIDIA CUDA
    OsNVCL,       // NVIDIA OpenCL
    OsAMDHSA,     // AMD HSA Runtime
    OsPS4,
    OsELFIAMCU,
    OsTvOS,       // Apple tvOS
    OsWatchOS,    // Apple watchOS
    OsMesa3D,
    OsContiki,
    OsAMDPAL,
    OsHermitCore,
    OsHurd,
    OsWASI,
    OsEmscripten,
    OsUefi,
    OsOther,
};

// Coordinate with zig_llvm.h
static const ZigLLVM_EnvironmentType abi_list[] = {
    ZigLLVM_UnknownEnvironment,

    ZigLLVM_GNU,
    ZigLLVM_GNUABIN32,
    ZigLLVM_GNUABI64,
    ZigLLVM_GNUEABI,
    ZigLLVM_GNUEABIHF,
    ZigLLVM_GNUX32,
    ZigLLVM_CODE16,
    ZigLLVM_EABI,
    ZigLLVM_EABIHF,
    ZigLLVM_Android,
    ZigLLVM_Musl,
    ZigLLVM_MuslEABI,
    ZigLLVM_MuslEABIHF,

    ZigLLVM_MSVC,
    ZigLLVM_Itanium,
    ZigLLVM_Cygnus,
    ZigLLVM_CoreCLR,
    ZigLLVM_Simulator,
    ZigLLVM_MacABI,
};

static const ZigLLVM_ObjectFormatType oformat_list[] = {
    ZigLLVM_UnknownObjectFormat,
    ZigLLVM_COFF,
    ZigLLVM_ELF,
    ZigLLVM_MachO,
    ZigLLVM_Wasm,
};

size_t target_oformat_count(void) {
    return array_length(oformat_list);
}

ZigLLVM_ObjectFormatType target_oformat_enum(size_t index) {
    assert(index < array_length(oformat_list));
    return oformat_list[index];
}

const char *target_oformat_name(ZigLLVM_ObjectFormatType oformat) {
    switch (oformat) {
        case ZigLLVM_UnknownObjectFormat: return "unknown";
        case ZigLLVM_COFF: return "coff";
        case ZigLLVM_ELF: return "elf";
        case ZigLLVM_MachO: return "macho";
        case ZigLLVM_Wasm: return "wasm";
        case ZigLLVM_XCOFF: return "xcoff";
    }
    zig_unreachable();
}

size_t target_arch_count(void) {
    return array_length(arch_list);
}

ZigLLVM_ArchType target_arch_enum(size_t index) {
    assert(index < array_length(arch_list));
    return arch_list[index];
}

size_t target_vendor_count(void) {
    return array_length(vendor_list);
}

ZigLLVM_VendorType target_vendor_enum(size_t index) {
    assert(index < array_length(vendor_list));
    return vendor_list[index];
}

size_t target_os_count(void) {
    return array_length(os_list);
}
Os target_os_enum(size_t index) {
    assert(index < array_length(os_list));
    return os_list[index];
}

ZigLLVM_OSType get_llvm_os_type(Os os_type) {
    switch (os_type) {
        case OsFreestanding:
        case OsOther:
            return ZigLLVM_UnknownOS;
        case OsAnanas:
            return ZigLLVM_Ananas;
        case OsCloudABI:
            return ZigLLVM_CloudABI;
        case OsDragonFly:
            return ZigLLVM_DragonFly;
        case OsFreeBSD:
            return ZigLLVM_FreeBSD;
        case OsFuchsia:
            return ZigLLVM_Fuchsia;
        case OsIOS:
            return ZigLLVM_IOS;
        case OsKFreeBSD:
            return ZigLLVM_KFreeBSD;
        case OsLinux:
            return ZigLLVM_Linux;
        case OsLv2:
            return ZigLLVM_Lv2;
        case OsMacOSX:
            return ZigLLVM_MacOSX;
        case OsNetBSD:
            return ZigLLVM_NetBSD;
        case OsOpenBSD:
            return ZigLLVM_OpenBSD;
        case OsSolaris:
            return ZigLLVM_Solaris;
        case OsWindows:
        case OsUefi:
            return ZigLLVM_Win32;
        case OsHaiku:
            return ZigLLVM_Haiku;
        case OsMinix:
            return ZigLLVM_Minix;
        case OsRTEMS:
            return ZigLLVM_RTEMS;
        case OsNaCl:
            return ZigLLVM_NaCl;
        case OsCNK:
            return ZigLLVM_CNK;
        case OsAIX:
            return ZigLLVM_AIX;
        case OsCUDA:
            return ZigLLVM_CUDA;
        case OsNVCL:
            return ZigLLVM_NVCL;
        case OsAMDHSA:
            return ZigLLVM_AMDHSA;
        case OsPS4:
            return ZigLLVM_PS4;
        case OsELFIAMCU:
            return ZigLLVM_ELFIAMCU;
        case OsTvOS:
            return ZigLLVM_TvOS;
        case OsWatchOS:
            return ZigLLVM_WatchOS;
        case OsMesa3D:
            return ZigLLVM_Mesa3D;
        case OsContiki:
            return ZigLLVM_Contiki;
        case OsAMDPAL:
            return ZigLLVM_AMDPAL;
        case OsHermitCore:
            return ZigLLVM_HermitCore;
        case OsHurd:
            return ZigLLVM_Hurd;
        case OsWASI:
            return ZigLLVM_WASI;
        case OsEmscripten:
            return ZigLLVM_Emscripten;
    }
    zig_unreachable();
}

const char *target_os_name(Os os_type) {
    switch (os_type) {
        case OsFreestanding:
            return "freestanding";
        case OsUefi:
            return "uefi";
        case OsOther:
            return "other";
        case OsAnanas:
        case OsCloudABI:
        case OsDragonFly:
        case OsFreeBSD:
        case OsFuchsia:
        case OsIOS:
        case OsKFreeBSD:
        case OsLinux:
        case OsLv2:        // PS3
        case OsMacOSX:
        case OsNetBSD:
        case OsOpenBSD:
        case OsSolaris:
        case OsWindows:
        case OsHaiku:
        case OsMinix:
        case OsRTEMS:
        case OsNaCl:       // Native Client
        case OsCNK:        // BG/P Compute-Node Kernel
        case OsAIX:
        case OsCUDA:       // NVIDIA CUDA
        case OsNVCL:       // NVIDIA OpenCL
        case OsAMDHSA:     // AMD HSA Runtime
        case OsPS4:
        case OsELFIAMCU:
        case OsTvOS:       // Apple tvOS
        case OsWatchOS:    // Apple watchOS
        case OsMesa3D:
        case OsContiki:
        case OsAMDPAL:
        case OsHermitCore:
        case OsHurd:
        case OsWASI:
        case OsEmscripten:
            return ZigLLVMGetOSTypeName(get_llvm_os_type(os_type));
    }
    zig_unreachable();
}

size_t target_abi_count(void) {
    return array_length(abi_list);
}
ZigLLVM_EnvironmentType target_abi_enum(size_t index) {
    assert(index < array_length(abi_list));
    return abi_list[index];
}
const char *target_abi_name(ZigLLVM_EnvironmentType abi) {
    if (abi == ZigLLVM_UnknownEnvironment)
        return "none";
    return ZigLLVMGetEnvironmentTypeName(abi);
}

Error target_parse_arch(ZigLLVM_ArchType *out_arch, const char *arch_ptr, size_t arch_len) {
    *out_arch = ZigLLVM_UnknownArch;
    for (size_t arch_i = 0; arch_i < array_length(arch_list); arch_i += 1) {
        ZigLLVM_ArchType arch = arch_list[arch_i];
        if (mem_eql_str(arch_ptr, arch_len, target_arch_name(arch))) {
            *out_arch = arch;
            return ErrorNone;
        }
    }
    return ErrorUnknownArchitecture;
}

Error target_parse_os(Os *out_os, const char *os_ptr, size_t os_len) {
    for (size_t i = 0; i < array_length(os_list); i += 1) {
        Os os = os_list[i];
        const char *os_name = target_os_name(os);
        if (mem_eql_str(os_ptr, os_len, os_name)) {
            *out_os = os;
            return ErrorNone;
        }
    }
    return ErrorUnknownOperatingSystem;
}

Error target_parse_abi(ZigLLVM_EnvironmentType *out_abi, const char *abi_ptr, size_t abi_len) {
    for (size_t i = 0; i < array_length(abi_list); i += 1) {
        ZigLLVM_EnvironmentType abi = abi_list[i];
        const char *abi_name = target_abi_name(abi);
        if (mem_eql_str(abi_ptr, abi_len, abi_name)) {
            *out_abi = abi;
            return ErrorNone;
        }
    }
    return ErrorUnknownABI;
}

const char *target_arch_name(ZigLLVM_ArchType arch) {
    return ZigLLVMGetArchTypeName(arch);
}

void init_all_targets(void) {
    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetInfos();
    LLVMInitializeAllTargetMCs();
    LLVMInitializeAllAsmPrinters();
    LLVMInitializeAllAsmParsers();
}

void target_triple_zig(Buf *triple, const ZigTarget *target) {
    buf_resize(triple, 0);
    buf_appendf(triple, "%s-%s-%s",
            target_arch_name(target->arch),
            target_os_name(target->os),
            target_abi_name(target->abi));
}

void target_triple_llvm(Buf *triple, const ZigTarget *target) {
    buf_resize(triple, 0);
    buf_appendf(triple, "%s-%s-%s-%s",
            ZigLLVMGetArchTypeName(target->arch),
            ZigLLVMGetVendorTypeName(ZigLLVM_UnknownVendor),
            ZigLLVMGetOSTypeName(get_llvm_os_type(target->os)),
            ZigLLVMGetEnvironmentTypeName(target->abi));
}

bool target_os_is_darwin(Os os) {
    switch (os) {
        case OsMacOSX:
        case OsIOS:
        case OsWatchOS:
        case OsTvOS:
            return true;
        default:
            return false;
    }
}

ZigLLVM_ObjectFormatType target_object_format(const ZigTarget *target) {
    if (target->os == OsUefi || target->os == OsWindows) {
        return ZigLLVM_COFF;
    } else if (target_os_is_darwin(target->os)) {
        return ZigLLVM_MachO;
    }
    if (target->arch == ZigLLVM_wasm32 ||
        target->arch == ZigLLVM_wasm64)
    {
        return ZigLLVM_Wasm;
    }
    return ZigLLVM_ELF;
}

// See lib/Support/Triple.cpp in LLVM for the source of this data.
// getArchPointerBitWidth
uint32_t target_arch_pointer_bit_width(ZigLLVM_ArchType arch) {
    switch (arch) {
        case ZigLLVM_UnknownArch:
            return 0;

        case ZigLLVM_avr:
        case ZigLLVM_msp430:
            return 16;

        case ZigLLVM_arc:
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
        case ZigLLVM_hexagon:
        case ZigLLVM_le32:
        case ZigLLVM_mips:
        case ZigLLVM_mipsel:
        case ZigLLVM_nvptx:
        case ZigLLVM_ppc:
        case ZigLLVM_r600:
        case ZigLLVM_riscv32:
        case ZigLLVM_sparc:
        case ZigLLVM_sparcel:
        case ZigLLVM_tce:
        case ZigLLVM_tcele:
        case ZigLLVM_thumb:
        case ZigLLVM_thumbeb:
        case ZigLLVM_x86:
        case ZigLLVM_xcore:
        case ZigLLVM_amdil:
        case ZigLLVM_hsail:
        case ZigLLVM_spir:
        case ZigLLVM_kalimba:
        case ZigLLVM_lanai:
        case ZigLLVM_shave:
        case ZigLLVM_wasm32:
        case ZigLLVM_renderscript32:
        case ZigLLVM_aarch64_32:
            return 32;

        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
        case ZigLLVM_amdgcn:
        case ZigLLVM_bpfel:
        case ZigLLVM_bpfeb:
        case ZigLLVM_le64:
        case ZigLLVM_mips64:
        case ZigLLVM_mips64el:
        case ZigLLVM_nvptx64:
        case ZigLLVM_ppc64:
        case ZigLLVM_ppc64le:
        case ZigLLVM_riscv64:
        case ZigLLVM_sparcv9:
        case ZigLLVM_systemz:
        case ZigLLVM_x86_64:
        case ZigLLVM_amdil64:
        case ZigLLVM_hsail64:
        case ZigLLVM_spir64:
        case ZigLLVM_wasm64:
        case ZigLLVM_renderscript64:
        case ZigLLVM_ve:
            return 64;
    }
    zig_unreachable();
}

uint32_t target_arch_largest_atomic_bits(ZigLLVM_ArchType arch) {
    switch (arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();

        case ZigLLVM_avr:
        case ZigLLVM_msp430:
            return 16;

        case ZigLLVM_arc:
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
        case ZigLLVM_hexagon:
        case ZigLLVM_le32:
        case ZigLLVM_mips:
        case ZigLLVM_mipsel:
        case ZigLLVM_nvptx:
        case ZigLLVM_ppc:
        case ZigLLVM_r600:
        case ZigLLVM_riscv32:
        case ZigLLVM_sparc:
        case ZigLLVM_sparcel:
        case ZigLLVM_tce:
        case ZigLLVM_tcele:
        case ZigLLVM_thumb:
        case ZigLLVM_thumbeb:
        case ZigLLVM_x86:
        case ZigLLVM_xcore:
        case ZigLLVM_amdil:
        case ZigLLVM_hsail:
        case ZigLLVM_spir:
        case ZigLLVM_kalimba:
        case ZigLLVM_lanai:
        case ZigLLVM_shave:
        case ZigLLVM_wasm32:
        case ZigLLVM_renderscript32:
            return 32;

        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
        case ZigLLVM_aarch64_32:
        case ZigLLVM_amdgcn:
        case ZigLLVM_bpfel:
        case ZigLLVM_bpfeb:
        case ZigLLVM_le64:
        case ZigLLVM_mips64:
        case ZigLLVM_mips64el:
        case ZigLLVM_nvptx64:
        case ZigLLVM_ppc64:
        case ZigLLVM_ppc64le:
        case ZigLLVM_riscv64:
        case ZigLLVM_sparcv9:
        case ZigLLVM_systemz:
        case ZigLLVM_amdil64:
        case ZigLLVM_hsail64:
        case ZigLLVM_spir64:
        case ZigLLVM_wasm64:
        case ZigLLVM_renderscript64:
        case ZigLLVM_ve:
            return 64;

        case ZigLLVM_x86_64:
            return 128;
    }
    zig_unreachable();
}

uint32_t target_c_type_size_in_bits(const ZigTarget *target, CIntType id) {
    switch (target->os) {
        case OsFreestanding:
        case OsOther:
            switch (target->arch) {
                case ZigLLVM_msp430:
                    switch (id) {
                        case CIntTypeShort:
                        case CIntTypeUShort:
                            return 16;
                        case CIntTypeInt:
                        case CIntTypeUInt:
                            return 16;
                        case CIntTypeLong:
                        case CIntTypeULong:
                            return 32;
                        case CIntTypeLongLong:
                        case CIntTypeULongLong:
                            return 64;
                        case CIntTypeCount:
                            zig_unreachable();
                    }
                    zig_unreachable();
                default:
                    switch (id) {
                        case CIntTypeShort:
                        case CIntTypeUShort:
                            return 16;
                        case CIntTypeInt:
                        case CIntTypeUInt:
                            return 32;
                        case CIntTypeLong:
                        case CIntTypeULong:
                            return target_arch_pointer_bit_width(target->arch);
                        case CIntTypeLongLong:
                        case CIntTypeULongLong:
                            return 64;
                        case CIntTypeCount:
                            zig_unreachable();
                    }
            }
            zig_unreachable();
        case OsLinux:
        case OsMacOSX:
        case OsFreeBSD:
        case OsNetBSD:
        case OsDragonFly:
        case OsOpenBSD:
        case OsWASI:
        case OsEmscripten:
            switch (id) {
                case CIntTypeShort:
                case CIntTypeUShort:
                    return 16;
                case CIntTypeInt:
                case CIntTypeUInt:
                    return 32;
                case CIntTypeLong:
                case CIntTypeULong:
                    return target_arch_pointer_bit_width(target->arch);
                case CIntTypeLongLong:
                case CIntTypeULongLong:
                    return 64;
                case CIntTypeCount:
                    zig_unreachable();
            }
            zig_unreachable();
        case OsUefi:
        case OsWindows:
            switch (id) {
                case CIntTypeShort:
                case CIntTypeUShort:
                    return 16;
                case CIntTypeInt:
                case CIntTypeUInt:
                case CIntTypeLong:
                case CIntTypeULong:
                    return 32;
                case CIntTypeLongLong:
                case CIntTypeULongLong:
                    return 64;
                case CIntTypeCount:
                    zig_unreachable();
            }
            zig_unreachable();
        case OsIOS:
            switch (id) {
                case CIntTypeShort:
                case CIntTypeUShort:
                    return 16;
                case CIntTypeInt:
                case CIntTypeUInt:
                    return 32;
                case CIntTypeLong:
                case CIntTypeULong:
                case CIntTypeLongLong:
                case CIntTypeULongLong:
                    return 64;
                case CIntTypeCount:
                    zig_unreachable();
            }
            zig_unreachable();
        case OsAnanas:
        case OsCloudABI:
        case OsKFreeBSD:
        case OsLv2:
        case OsSolaris:
        case OsHaiku:
        case OsMinix:
        case OsRTEMS:
        case OsNaCl:
        case OsCNK:
        case OsAIX:
        case OsCUDA:
        case OsNVCL:
        case OsAMDHSA:
        case OsPS4:
        case OsELFIAMCU:
        case OsTvOS:
        case OsWatchOS:
        case OsMesa3D:
        case OsFuchsia:
        case OsContiki:
        case OsAMDPAL:
        case OsHermitCore:
        case OsHurd:
            zig_panic("TODO c type size in bits for this target");
    }
    zig_unreachable();
}

bool target_allows_addr_zero(const ZigTarget *target) {
    return target->os == OsFreestanding || target->os == OsUefi;
}

const char *target_o_file_ext(const ZigTarget *target) {
    if (target->abi == ZigLLVM_MSVC ||
        (target->os == OsWindows && !target_abi_is_gnu(target->abi)) ||
        target->os == OsUefi)
    {
        return ".obj";
    } else {
        return ".o";
    }
}

const char *target_asm_file_ext(const ZigTarget *target) {
    return ".s";
}

const char *target_llvm_ir_file_ext(const ZigTarget *target) {
    return ".ll";
}

bool target_is_android(const ZigTarget *target) {
    return target->abi == ZigLLVM_Android;
}

bool target_can_exec(const ZigTarget *host_target, const ZigTarget *guest_target) {
    assert(host_target != nullptr);

    if (guest_target == nullptr) {
        // null guest target means that the guest target is native
        return true;
    }

    if (guest_target->os == host_target->os && guest_target->arch == host_target->arch) {
        // OS and arch match
        return true;
    }

    if (guest_target->os == OsWindows && host_target->os == OsWindows &&
        host_target->arch == ZigLLVM_x86_64 && guest_target->arch == ZigLLVM_x86)
    {
        // 64-bit windows can run 32-bit programs
        return true;
    }

    return false;
}

const char *arch_stack_pointer_register_name(ZigLLVM_ArchType arch) {
    switch (arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();
        case ZigLLVM_x86:
            return "esp";
        case ZigLLVM_x86_64:
            return "rsp";
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
        case ZigLLVM_thumb:
        case ZigLLVM_thumbeb:
        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
        case ZigLLVM_aarch64_32:
        case ZigLLVM_riscv32:
        case ZigLLVM_riscv64:
        case ZigLLVM_mipsel:
        case ZigLLVM_ppc:
        case ZigLLVM_ppc64:
        case ZigLLVM_ppc64le:
            return "sp";

        case ZigLLVM_wasm32:
        case ZigLLVM_wasm64:
            return nullptr; // known to be not available

        case ZigLLVM_amdgcn:
        case ZigLLVM_amdil:
        case ZigLLVM_amdil64:
        case ZigLLVM_arc:
        case ZigLLVM_avr:
        case ZigLLVM_bpfeb:
        case ZigLLVM_bpfel:
        case ZigLLVM_hexagon:
        case ZigLLVM_lanai:
        case ZigLLVM_hsail:
        case ZigLLVM_hsail64:
        case ZigLLVM_kalimba:
        case ZigLLVM_le32:
        case ZigLLVM_le64:
        case ZigLLVM_mips:
        case ZigLLVM_mips64:
        case ZigLLVM_mips64el:
        case ZigLLVM_msp430:
        case ZigLLVM_nvptx:
        case ZigLLVM_nvptx64:
        case ZigLLVM_r600:
        case ZigLLVM_renderscript32:
        case ZigLLVM_renderscript64:
        case ZigLLVM_shave:
        case ZigLLVM_sparc:
        case ZigLLVM_sparcel:
        case ZigLLVM_sparcv9:
        case ZigLLVM_spir:
        case ZigLLVM_spir64:
        case ZigLLVM_systemz:
        case ZigLLVM_tce:
        case ZigLLVM_tcele:
        case ZigLLVM_xcore:
        case ZigLLVM_ve:
            zig_panic("TODO populate this table with stack pointer register name for this CPU architecture");
    }
    zig_unreachable();
}

bool target_is_arm(const ZigTarget *target) {
    switch (target->arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();
        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
        case ZigLLVM_aarch64_32:
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
        case ZigLLVM_thumb:
        case ZigLLVM_thumbeb:
            return true;

        case ZigLLVM_x86:
        case ZigLLVM_x86_64:
        case ZigLLVM_amdgcn:
        case ZigLLVM_amdil:
        case ZigLLVM_amdil64:
        case ZigLLVM_arc:
        case ZigLLVM_avr:
        case ZigLLVM_bpfeb:
        case ZigLLVM_bpfel:
        case ZigLLVM_hexagon:
        case ZigLLVM_lanai:
        case ZigLLVM_hsail:
        case ZigLLVM_hsail64:
        case ZigLLVM_kalimba:
        case ZigLLVM_le32:
        case ZigLLVM_le64:
        case ZigLLVM_mips:
        case ZigLLVM_mips64:
        case ZigLLVM_mips64el:
        case ZigLLVM_mipsel:
        case ZigLLVM_msp430:
        case ZigLLVM_nvptx:
        case ZigLLVM_nvptx64:
        case ZigLLVM_ppc64le:
        case ZigLLVM_r600:
        case ZigLLVM_renderscript32:
        case ZigLLVM_renderscript64:
        case ZigLLVM_riscv32:
        case ZigLLVM_riscv64:
        case ZigLLVM_shave:
        case ZigLLVM_sparc:
        case ZigLLVM_sparcel:
        case ZigLLVM_sparcv9:
        case ZigLLVM_spir:
        case ZigLLVM_spir64:
        case ZigLLVM_systemz:
        case ZigLLVM_tce:
        case ZigLLVM_tcele:
        case ZigLLVM_wasm32:
        case ZigLLVM_wasm64:
        case ZigLLVM_xcore:
        case ZigLLVM_ppc:
        case ZigLLVM_ppc64:
        case ZigLLVM_ve:
            return false;
    }
    zig_unreachable();
}

// Valgrind supports more, but Zig does not support them yet.
bool target_has_valgrind_support(const ZigTarget *target) {
    switch (target->arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();
        case ZigLLVM_x86_64:
            return (target->os == OsLinux || target_os_is_darwin(target->os) || target->os == OsSolaris ||
                (target->os == OsWindows && target->abi != ZigLLVM_MSVC));
        default:
            return false;
    }
    zig_unreachable();
}

bool target_os_requires_libc(Os os) {
    // On Darwin, we always link libSystem which contains libc.
    // Similarly on FreeBSD and NetBSD we always link system libc
    // since this is the stable syscall interface.
    return (target_os_is_darwin(os) || os == OsFreeBSD || os == OsNetBSD || os == OsDragonFly);
}

bool target_is_glibc(const ZigTarget *target) {
    return target->os == OsLinux && target_abi_is_gnu(target->abi);
}

bool target_is_musl(const ZigTarget *target) {
    return target->os == OsLinux && target_abi_is_musl(target->abi);
}

bool target_is_wasm(const ZigTarget *target) {
    return target->arch == ZigLLVM_wasm32 || target->arch == ZigLLVM_wasm64;
}

ZigLLVM_EnvironmentType target_default_abi(ZigLLVM_ArchType arch, Os os) {
    if (arch == ZigLLVM_wasm32 || arch == ZigLLVM_wasm64) {
        return ZigLLVM_Musl;
    }
    switch (os) {
        case OsFreestanding:
        case OsAnanas:
        case OsCloudABI:
        case OsLv2:
        case OsSolaris:
        case OsHaiku:
        case OsMinix:
        case OsRTEMS:
        case OsNaCl:
        case OsCNK:
        case OsAIX:
        case OsCUDA:
        case OsNVCL:
        case OsAMDHSA:
        case OsPS4:
        case OsELFIAMCU:
        case OsMesa3D:
        case OsContiki:
        case OsAMDPAL:
        case OsHermitCore:
        case OsOther:
            return ZigLLVM_EABI;
        case OsOpenBSD:
        case OsMacOSX:
        case OsFreeBSD:
        case OsIOS:
        case OsTvOS:
        case OsWatchOS:
        case OsFuchsia:
        case OsKFreeBSD:
        case OsNetBSD:
        case OsDragonFly:
        case OsHurd:
            return ZigLLVM_GNU;
        case OsUefi:
        case OsWindows:
            return ZigLLVM_MSVC;
        case OsLinux:
        case OsWASI:
        case OsEmscripten:
            return ZigLLVM_Musl;
    }
    zig_unreachable();
}

bool target_abi_is_gnu(ZigLLVM_EnvironmentType abi) {
    switch (abi) {
        case ZigLLVM_GNU:
        case ZigLLVM_GNUABIN32:
        case ZigLLVM_GNUABI64:
        case ZigLLVM_GNUEABI:
        case ZigLLVM_GNUEABIHF:
        case ZigLLVM_GNUX32:
            return true;
        default:
            return false;
    }
}

bool target_abi_is_musl(ZigLLVM_EnvironmentType abi) {
    switch (abi) {
        case ZigLLVM_Musl:
        case ZigLLVM_MuslEABI:
        case ZigLLVM_MuslEABIHF:
            return true;
        default:
            return false;
    }
}

struct AvailableLibC {
    ZigLLVM_ArchType arch;
    Os os;
    ZigLLVM_EnvironmentType abi;
};

static const AvailableLibC libcs_available[] = {
    {ZigLLVM_aarch64_be, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_aarch64_be, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_aarch64_be, OsWindows, ZigLLVM_GNU},
    {ZigLLVM_aarch64, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_aarch64, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_aarch64, OsWindows, ZigLLVM_GNU},
    {ZigLLVM_armeb, OsLinux, ZigLLVM_GNUEABI},
    {ZigLLVM_armeb, OsLinux, ZigLLVM_GNUEABIHF},
    {ZigLLVM_armeb, OsLinux, ZigLLVM_MuslEABI},
    {ZigLLVM_armeb, OsLinux, ZigLLVM_MuslEABIHF},
    {ZigLLVM_armeb, OsWindows, ZigLLVM_GNU},
    {ZigLLVM_arm, OsLinux, ZigLLVM_GNUEABI},
    {ZigLLVM_arm, OsLinux, ZigLLVM_GNUEABIHF},
    {ZigLLVM_arm, OsLinux, ZigLLVM_MuslEABI},
    {ZigLLVM_arm, OsLinux, ZigLLVM_MuslEABIHF},
    {ZigLLVM_arm, OsWindows, ZigLLVM_GNU},
    {ZigLLVM_x86, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_x86, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_x86, OsWindows, ZigLLVM_GNU},
    {ZigLLVM_mips64el, OsLinux, ZigLLVM_GNUABI64},
    {ZigLLVM_mips64el, OsLinux, ZigLLVM_GNUABIN32},
    {ZigLLVM_mips64el, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_mips64, OsLinux, ZigLLVM_GNUABI64},
    {ZigLLVM_mips64, OsLinux, ZigLLVM_GNUABIN32},
    {ZigLLVM_mips64, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_mipsel, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_mipsel, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_mips, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_mips, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_ppc64le, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_ppc64le, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_ppc64, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_ppc64, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_ppc, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_ppc, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_riscv64, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_riscv64, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_systemz, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_systemz, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_sparc, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_sparcv9, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_wasm32, OsFreestanding, ZigLLVM_Musl},
    {ZigLLVM_x86_64, OsLinux, ZigLLVM_GNU},
    {ZigLLVM_x86_64, OsLinux, ZigLLVM_GNUX32},
    {ZigLLVM_x86_64, OsLinux, ZigLLVM_Musl},
    {ZigLLVM_x86_64, OsWindows, ZigLLVM_GNU},
};

bool target_can_build_libc(const ZigTarget *target) {
    for (size_t i = 0; i < array_length(libcs_available); i += 1) {
        if (target->arch == libcs_available[i].arch &&
            target->os == libcs_available[i].os &&
            target->abi == libcs_available[i].abi)
        {
            return true;
        }
    }
    return false;
}

const char *target_libc_generic_name(const ZigTarget *target) {
    if (target->os == OsWindows) {
        return "mingw";
    }
    switch (target->abi) {
        case ZigLLVM_GNU:
        case ZigLLVM_GNUABIN32:
        case ZigLLVM_GNUABI64:
        case ZigLLVM_GNUEABI:
        case ZigLLVM_GNUEABIHF:
        case ZigLLVM_GNUX32:
            return "glibc";
        case ZigLLVM_Musl:
        case ZigLLVM_MuslEABI:
        case ZigLLVM_MuslEABIHF:
        case ZigLLVM_UnknownEnvironment:
            return "musl";
        case ZigLLVM_CODE16:
        case ZigLLVM_EABI:
        case ZigLLVM_EABIHF:
        case ZigLLVM_Android:
        case ZigLLVM_MSVC:
        case ZigLLVM_Itanium:
        case ZigLLVM_Cygnus:
        case ZigLLVM_CoreCLR:
        case ZigLLVM_Simulator:
        case ZigLLVM_MacABI:
            zig_unreachable();
    }
    zig_unreachable();
}

bool target_is_libc_lib_name(const ZigTarget *target, const char *name) {
    auto equal = str_eql_str;
    if (target->os == OsMacOSX)
        equal = str_eql_str_ignore_case;

    if (equal(name, "c"))
        return true;

    if (target_abi_is_gnu(target->abi) && target->os == OsWindows) {
        // mingw-w64

        if (equal(name, "m"))
            return true;

        return false;
    }

    if (target_abi_is_gnu(target->abi) || target_abi_is_musl(target->abi) || target_os_is_darwin(target->os)) {
        if (equal(name, "m"))
            return true;
        if (equal(name, "rt"))
            return true;
        if (equal(name, "pthread"))
            return true;
        if (equal(name, "crypt"))
            return true;
        if (equal(name, "util"))
            return true;
        if (equal(name, "xnet"))
            return true;
        if (equal(name, "resolv"))
            return true;
        if (equal(name, "dl"))
            return true;
        if (equal(name, "util"))
            return true;
    }

    if (target_os_is_darwin(target->os) && equal(name, "System"))
        return true;

    return false;
}

bool target_is_libcpp_lib_name(const ZigTarget *target, const char *name) {
    if (strcmp(name, "c++") == 0 || strcmp(name, "c++abi") == 0)
        return true;

    return false;
}

size_t target_libc_count(void) {
    return array_length(libcs_available);
}

void target_libc_enum(size_t index, ZigTarget *out_target) {
    assert(index < array_length(libcs_available));
    out_target->arch = libcs_available[index].arch;
    out_target->os = libcs_available[index].os;
    out_target->abi = libcs_available[index].abi;
    out_target->is_native_os = false;
    out_target->is_native_cpu = false;
}

bool target_has_debug_info(const ZigTarget *target) {
    return !target_is_wasm(target);
}

const char *target_arch_musl_name(ZigLLVM_ArchType arch) {
    switch (arch) {
        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
            return "aarch64";
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
            return "arm";
        case ZigLLVM_mips:
        case ZigLLVM_mipsel:
            return "mips";
        case ZigLLVM_mips64el:
        case ZigLLVM_mips64:
            return "mips64";
        case ZigLLVM_ppc:
            return "powerpc";
        case ZigLLVM_ppc64:
        case ZigLLVM_ppc64le:
            return "powerpc64";
        case ZigLLVM_systemz:
            return "s390x";
        case ZigLLVM_x86:
            return "i386";
        case ZigLLVM_x86_64:
            return "x86_64";
        case ZigLLVM_riscv64:
            return "riscv64";
        default:
            zig_unreachable();
    }
}

bool target_libc_needs_crti_crtn(const ZigTarget *target) {
    if (target->arch == ZigLLVM_riscv32 || target->arch == ZigLLVM_riscv64 || target_is_android(target)) {
        return false;
    }
    return true;
}

bool target_is_riscv(const ZigTarget *target) {
    return target->arch == ZigLLVM_riscv32 || target->arch == ZigLLVM_riscv64;
}

bool target_is_mips(const ZigTarget *target) {
    return target->arch == ZigLLVM_mips || target->arch == ZigLLVM_mipsel ||
        target->arch == ZigLLVM_mips64 || target->arch == ZigLLVM_mips64el;
}

bool target_is_ppc(const ZigTarget *target) {
    return target->arch == ZigLLVM_ppc || target->arch == ZigLLVM_ppc64 ||
        target->arch == ZigLLVM_ppc64le;
}

unsigned target_fn_align(const ZigTarget *target) {
    return 16;
}
