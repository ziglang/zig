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

#include <stdio.h>

static const ArchType arch_list[] = {
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8_3a},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8_2a},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8_1a},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8r},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8m_baseline},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8m_mainline},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7em},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7m},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7s},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7k},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7ve},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6m},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6k},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6t2},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v5},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v5te},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v4t},

    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v8_3a},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v8_2a},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v8_1a},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v8},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v8r},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v8m_baseline},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v8m_mainline},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v7},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v7em},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v7m},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v7s},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v7k},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v7ve},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v6},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v6m},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v6k},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v6t2},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v5},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v5te},
    {ZigLLVM_armeb, ZigLLVM_ARMSubArch_v4t},

    {ZigLLVM_aarch64, ZigLLVM_ARMSubArch_v8_3a},
    {ZigLLVM_aarch64, ZigLLVM_ARMSubArch_v8_2a},
    {ZigLLVM_aarch64, ZigLLVM_ARMSubArch_v8_1a},
    {ZigLLVM_aarch64, ZigLLVM_ARMSubArch_v8},
    {ZigLLVM_aarch64, ZigLLVM_ARMSubArch_v8r},
    {ZigLLVM_aarch64, ZigLLVM_ARMSubArch_v8m_baseline},
    {ZigLLVM_aarch64, ZigLLVM_ARMSubArch_v8m_mainline},

    {ZigLLVM_aarch64_be, ZigLLVM_ARMSubArch_v8_3a},
    {ZigLLVM_aarch64_be, ZigLLVM_ARMSubArch_v8_2a},
    {ZigLLVM_aarch64_be, ZigLLVM_ARMSubArch_v8_1a},
    {ZigLLVM_aarch64_be, ZigLLVM_ARMSubArch_v8},
    {ZigLLVM_aarch64_be, ZigLLVM_ARMSubArch_v8r},
    {ZigLLVM_aarch64_be, ZigLLVM_ARMSubArch_v8m_baseline},
    {ZigLLVM_aarch64_be, ZigLLVM_ARMSubArch_v8m_mainline},

    {ZigLLVM_arc, ZigLLVM_NoSubArch},
    {ZigLLVM_avr, ZigLLVM_NoSubArch},
    {ZigLLVM_bpfel, ZigLLVM_NoSubArch},
    {ZigLLVM_bpfeb, ZigLLVM_NoSubArch},
    {ZigLLVM_hexagon, ZigLLVM_NoSubArch},
    {ZigLLVM_mips, ZigLLVM_NoSubArch},
    {ZigLLVM_mipsel, ZigLLVM_NoSubArch},
    {ZigLLVM_mips64, ZigLLVM_NoSubArch},
    {ZigLLVM_mips64el, ZigLLVM_NoSubArch},
    {ZigLLVM_msp430, ZigLLVM_NoSubArch},
    {ZigLLVM_nios2, ZigLLVM_NoSubArch},
    {ZigLLVM_ppc, ZigLLVM_NoSubArch},
    {ZigLLVM_ppc64, ZigLLVM_NoSubArch},
    {ZigLLVM_ppc64le, ZigLLVM_NoSubArch},
    {ZigLLVM_r600, ZigLLVM_NoSubArch},
    {ZigLLVM_amdgcn, ZigLLVM_NoSubArch},
    {ZigLLVM_riscv32, ZigLLVM_NoSubArch},
    {ZigLLVM_riscv64, ZigLLVM_NoSubArch},
    {ZigLLVM_sparc, ZigLLVM_NoSubArch},
    {ZigLLVM_sparcv9, ZigLLVM_NoSubArch},
    {ZigLLVM_sparcel, ZigLLVM_NoSubArch},
    {ZigLLVM_systemz, ZigLLVM_NoSubArch},
    {ZigLLVM_tce, ZigLLVM_NoSubArch},
    {ZigLLVM_tcele, ZigLLVM_NoSubArch},
    {ZigLLVM_thumb, ZigLLVM_NoSubArch},
    {ZigLLVM_thumbeb, ZigLLVM_NoSubArch},
    {ZigLLVM_x86, ZigLLVM_NoSubArch},
    {ZigLLVM_x86_64, ZigLLVM_NoSubArch},
    {ZigLLVM_xcore, ZigLLVM_NoSubArch},
    {ZigLLVM_nvptx, ZigLLVM_NoSubArch},
    {ZigLLVM_nvptx64, ZigLLVM_NoSubArch},
    {ZigLLVM_le32, ZigLLVM_NoSubArch},
    {ZigLLVM_le64, ZigLLVM_NoSubArch},
    {ZigLLVM_amdil, ZigLLVM_NoSubArch},
    {ZigLLVM_amdil64, ZigLLVM_NoSubArch},
    {ZigLLVM_hsail, ZigLLVM_NoSubArch},
    {ZigLLVM_hsail64, ZigLLVM_NoSubArch},
    {ZigLLVM_spir, ZigLLVM_NoSubArch},
    {ZigLLVM_spir64, ZigLLVM_NoSubArch},

    {ZigLLVM_kalimba, ZigLLVM_KalimbaSubArch_v3},
    {ZigLLVM_kalimba, ZigLLVM_KalimbaSubArch_v4},
    {ZigLLVM_kalimba, ZigLLVM_KalimbaSubArch_v5},

    {ZigLLVM_shave, ZigLLVM_NoSubArch},
    {ZigLLVM_lanai, ZigLLVM_NoSubArch},
    {ZigLLVM_wasm32, ZigLLVM_NoSubArch},
    {ZigLLVM_wasm64, ZigLLVM_NoSubArch},
    {ZigLLVM_renderscript32, ZigLLVM_NoSubArch},
    {ZigLLVM_renderscript64, ZigLLVM_NoSubArch},
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

// Synchronize with target.hpp enum Os
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
    // The following are custom OSes understood by Zig
    OsZen,
};

// Coordinate with zig_llvm.h
static const ZigLLVM_EnvironmentType environ_list[] = {
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

const ZigLLVM_ObjectFormatType get_target_oformat(size_t index) {
    return oformat_list[index];
}

const char *get_target_oformat_name(ZigLLVM_ObjectFormatType oformat) {
    switch (oformat) {
        case ZigLLVM_UnknownObjectFormat: return "unknown";
        case ZigLLVM_COFF: return "coff";
        case ZigLLVM_ELF: return "elf";
        case ZigLLVM_MachO: return "macho";
        case ZigLLVM_Wasm: return "wasm";
    }
    zig_unreachable();
}

size_t target_arch_count(void) {
    return array_length(arch_list);
}

const ArchType *get_target_arch(size_t index) {
    return &arch_list[index];
}

size_t target_vendor_count(void) {
    return array_length(vendor_list);
}

ZigLLVM_VendorType get_target_vendor(size_t index) {
    return vendor_list[index];
}

size_t target_os_count(void) {
    return array_length(os_list);
}
Os get_target_os(size_t index) {
    return os_list[index];
}

ZigLLVM_OSType get_llvm_os_type(Os os_type) {
    switch (os_type) {
        case OsFreestanding:
        case OsZen:
            // fake OsHermitCore and Hurd until 7.0.1 lands
            // https://github.com/ziglang/zig/issues/1788
        case OsHermitCore:
        case OsHurd:
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
    }
    zig_unreachable();
}

static Os get_zig_os_type(ZigLLVM_OSType os_type) {
    switch (os_type) {
        case ZigLLVM_UnknownOS:
            return OsFreestanding;
        case ZigLLVM_Ananas:
            return OsAnanas;
        case ZigLLVM_CloudABI:
            return OsCloudABI;
        case ZigLLVM_DragonFly:
            return OsDragonFly;
        case ZigLLVM_FreeBSD:
            return OsFreeBSD;
        case ZigLLVM_Fuchsia:
            return OsFuchsia;
        case ZigLLVM_IOS:
            return OsIOS;
        case ZigLLVM_KFreeBSD:
            return OsKFreeBSD;
        case ZigLLVM_Linux:
            return OsLinux;
        case ZigLLVM_Lv2:
            return OsLv2;
        case ZigLLVM_Darwin:
        case ZigLLVM_MacOSX:
            return OsMacOSX;
        case ZigLLVM_NetBSD:
            return OsNetBSD;
        case ZigLLVM_OpenBSD:
            return OsOpenBSD;
        case ZigLLVM_Solaris:
            return OsSolaris;
        case ZigLLVM_Win32:
            return OsWindows;
        case ZigLLVM_Haiku:
            return OsHaiku;
        case ZigLLVM_Minix:
            return OsMinix;
        case ZigLLVM_RTEMS:
            return OsRTEMS;
        case ZigLLVM_NaCl:
            return OsNaCl;
        case ZigLLVM_CNK:
            return OsCNK;
        case ZigLLVM_AIX:
            return OsAIX;
        case ZigLLVM_CUDA:
            return OsCUDA;
        case ZigLLVM_NVCL:
            return OsNVCL;
        case ZigLLVM_AMDHSA:
            return OsAMDHSA;
        case ZigLLVM_PS4:
            return OsPS4;
        case ZigLLVM_ELFIAMCU:
            return OsELFIAMCU;
        case ZigLLVM_TvOS:
            return OsTvOS;
        case ZigLLVM_WatchOS:
            return OsWatchOS;
        case ZigLLVM_Mesa3D:
            return OsMesa3D;
        case ZigLLVM_Contiki:
            return OsContiki;
        case ZigLLVM_AMDPAL:
            return OsAMDPAL;
#if defined(__linux__)
        // Remove ifdef once 7.0.1 lands
        // https://github.com/ziglang/zig/issues/1788
        case ZigLLVM_HermitCore:
            return OsHermitCore;
#endif
    }
    zig_unreachable();
}

const char *get_target_os_name(Os os_type) {
    switch (os_type) {
        case OsFreestanding:
            return "freestanding";
        case OsZen:
            return "zen";
            // fake OsHermitCore and Hurd until 7.0.1 lands
            // https://github.com/ziglang/zig/issues/1788
        case OsHermitCore:
            return "hermit";
        case OsHurd:
            return "hurd";
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
            return ZigLLVMGetOSTypeName(get_llvm_os_type(os_type));
    }
    zig_unreachable();
}

size_t target_environ_count(void) {
    return array_length(environ_list);
}
ZigLLVM_EnvironmentType get_target_environ(size_t index) {
    return environ_list[index];
}

void get_native_target(ZigTarget *target) {
    ZigLLVM_OSType os_type;
    ZigLLVMGetNativeTarget(
            &target->arch.arch,
            &target->arch.sub_arch,
            &target->vendor,
            &os_type,
            &target->env_type,
            &target->oformat);
    target->os = get_zig_os_type(os_type);
}

void get_unknown_target(ZigTarget *target) {
    target->arch.arch = ZigLLVM_UnknownArch;
    target->arch.sub_arch = ZigLLVM_NoSubArch;
    target->vendor = ZigLLVM_UnknownVendor;
    target->os = OsFreestanding;
    target->env_type = ZigLLVM_UnknownEnvironment;
    target->oformat = ZigLLVM_UnknownObjectFormat;
}

static void get_arch_name_raw(char *out_str, ZigLLVM_ArchType arch, ZigLLVM_SubArchType sub_arch) {
    const char *sub_str = (sub_arch == ZigLLVM_NoSubArch) ? "" : ZigLLVMGetSubArchTypeName(sub_arch);
    sprintf(out_str, "%s%s", ZigLLVMGetArchTypeName(arch), sub_str);
}

void get_arch_name(char *out_str, const ArchType *arch) {
    return get_arch_name_raw(out_str, arch->arch, arch->sub_arch);
}

int parse_target_arch(const char *str, ArchType *out_arch) {
    for (size_t i = 0; i < array_length(arch_list); i += 1) {
        const ArchType *arch = &arch_list[i];
        char arch_name[50];
        get_arch_name_raw(arch_name, arch->arch, arch->sub_arch);
        if (strcmp(arch_name, str) == 0) {
            *out_arch = *arch;
            return 0;
        }
    }
    return ErrorFileNotFound;
}

int parse_target_os(const char *str, Os *out_os) {
    for (size_t i = 0; i < array_length(os_list); i += 1) {
        Os os = os_list[i];
        const char *os_name = get_target_os_name(os);
        if (strcmp(os_name, str) == 0) {
            *out_os = os;
            return 0;
        }
    }
    return ErrorFileNotFound;
}

int parse_target_environ(const char *str, ZigLLVM_EnvironmentType *out_environ) {
    for (size_t i = 0; i < array_length(environ_list); i += 1) {
        ZigLLVM_EnvironmentType env_type = environ_list[i];
        const char *environ_name = ZigLLVMGetEnvironmentTypeName(env_type);
        if (strcmp(environ_name, str) == 0) {
            *out_environ = env_type;
            return 0;
        }
    }
    return ErrorFileNotFound;
}

void init_all_targets(void) {
    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetInfos();
    LLVMInitializeAllTargetMCs();
    LLVMInitializeAllAsmPrinters();
    LLVMInitializeAllAsmParsers();
}

void get_target_triple(Buf *triple, const ZigTarget *target) {
    char arch_name[50];
    get_arch_name(arch_name, &target->arch);

    buf_resize(triple, 0);

    // LLVM WebAssembly output support requires the target to be activated at
    // build type with -DCMAKE_LLVM_EXPIERMENTAL_TARGETS_TO_BUILD=WebAssembly.
    //
    // LLVM determines the output format based on the environment suffix,
    // defaulting to an object based on the architecture. The default format in
    // LLVM 6 sets the wasm arch output incorrectly to ELF. We need to
    // explicitly set this ourself in order for it to work.
    //
    // This is fixed in LLVM 7 and you will be able to get wasm output by
    // using the target triple `wasm32-unknown-unknown-unknown`.
    if (!strncmp(arch_name, "wasm", 4)) {
        buf_appendf(triple, "%s-%s-%s-wasm", arch_name,
                ZigLLVMGetVendorTypeName(target->vendor),
                ZigLLVMGetOSTypeName(get_llvm_os_type(target->os)));
    } else {
        buf_appendf(triple, "%s-%s-%s-%s", arch_name,
                ZigLLVMGetVendorTypeName(target->vendor),
                ZigLLVMGetOSTypeName(get_llvm_os_type(target->os)),
                ZigLLVMGetEnvironmentTypeName(target->env_type));
    }
}

static bool is_os_darwin(ZigTarget *target) {
    switch (target->os) {
        case OsMacOSX:
        case OsIOS:
            return true;
        default:
            return false;
    }
}

void resolve_target_object_format(ZigTarget *target) {
    if (target->oformat != ZigLLVM_UnknownObjectFormat) {
        return;
    }

    switch (target->arch.arch) {
        case ZigLLVM_UnknownArch:
        case ZigLLVM_aarch64:
        case ZigLLVM_arm:
        case ZigLLVM_thumb:
        case ZigLLVM_x86:
        case ZigLLVM_x86_64:
            if (is_os_darwin(target)) {
                target->oformat = ZigLLVM_MachO;
            } else if (target->os == OsWindows) {
                target->oformat = ZigLLVM_COFF;
            } else {
                target->oformat = ZigLLVM_ELF;
            }
            return;

        case ZigLLVM_aarch64_be:
        case ZigLLVM_amdgcn:
        case ZigLLVM_amdil:
        case ZigLLVM_amdil64:
        case ZigLLVM_armeb:
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
        case ZigLLVM_nios2:
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
        case ZigLLVM_thumbeb:
        case ZigLLVM_xcore:
            target->oformat= ZigLLVM_ELF;
            return;

        case ZigLLVM_wasm32:
        case ZigLLVM_wasm64:
            target->oformat = ZigLLVM_Wasm;
            return;

        case ZigLLVM_ppc:
        case ZigLLVM_ppc64:
            if (is_os_darwin(target)) {
                target->oformat = ZigLLVM_MachO;
            } else {
                target->oformat= ZigLLVM_ELF;
            }
            return;
    }
}

// See lib/Support/Triple.cpp in LLVM for the source of this data.
// getArchPointerBitWidth
static int get_arch_pointer_bit_width(ZigLLVM_ArchType arch) {
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
        case ZigLLVM_nios2:
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
            return 64;
    }
    zig_unreachable();
}

uint32_t target_c_type_size_in_bits(const ZigTarget *target, CIntType id) {
    switch (target->os) {
        case OsFreestanding:
            switch (target->arch.arch) {
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
                            return get_arch_pointer_bit_width(target->arch.arch);
                        case CIntTypeLongLong:
                        case CIntTypeULongLong:
                            return 64;
                        case CIntTypeCount:
                            zig_unreachable();
                    }
            }
        case OsLinux:
        case OsMacOSX:
        case OsZen:
        case OsOpenBSD:
            switch (id) {
                case CIntTypeShort:
                case CIntTypeUShort:
                    return 16;
                case CIntTypeInt:
                case CIntTypeUInt:
                    return 32;
                case CIntTypeLong:
                case CIntTypeULong:
                    return get_arch_pointer_bit_width(target->arch.arch);
                case CIntTypeLongLong:
                case CIntTypeULongLong:
                    return 64;
                case CIntTypeCount:
                    zig_unreachable();
            }
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
        case OsAnanas:
        case OsCloudABI:
        case OsDragonFly:
        case OsFreeBSD:
        case OsIOS:
        case OsKFreeBSD:
        case OsLv2:
        case OsNetBSD:
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

const char *target_o_file_ext(ZigTarget *target) {
    if (target->env_type == ZigLLVM_MSVC || target->os == OsWindows) {
        return ".obj";
    } else {
        return ".o";
    }
}

const char *target_asm_file_ext(ZigTarget *target) {
    return ".s";
}

const char *target_llvm_ir_file_ext(ZigTarget *target) {
    return ".ll";
}

const char *target_exe_file_ext(ZigTarget *target) {
    if (target->os == OsWindows) {
        return ".exe";
    } else {
        return "";
    }
}

const char *target_lib_file_ext(ZigTarget *target, bool is_static, size_t version_major, size_t version_minor, size_t version_patch) {
    if (target->os == OsWindows) {
        if (is_static) {
            return ".lib";
        } else {
            return ".dll";
        }
    } else {
        if (is_static) {
            return ".a";
        } else {
            return buf_ptr(buf_sprintf(".so.%zu", version_major));
        }
    }
}

enum FloatAbi {
    FloatAbiHard,
    FloatAbiSoft,
    FloatAbiSoftFp,
};

static FloatAbi get_float_abi(ZigTarget *target) {
    const ZigLLVM_EnvironmentType env = target->env_type;
    if (env == ZigLLVM_GNUEABIHF ||
        env == ZigLLVM_EABIHF ||
        env == ZigLLVM_MuslEABIHF)
    {
        return FloatAbiHard;
    } else {
        return FloatAbiSoft;
    }
}

static bool is_64_bit(ZigLLVM_ArchType arch) {
    return get_arch_pointer_bit_width(arch) == 64;
}

Buf *target_dynamic_linker(ZigTarget *target) {
    const ZigLLVM_ArchType arch = target->arch.arch;
    const ZigLLVM_EnvironmentType env = target->env_type;

    if (env == ZigLLVM_Android) {
        if (is_64_bit(arch)) {
            return buf_create_from_str("/system/bin/linker64");
        } else {
            return buf_create_from_str("/system/bin/linker");
        }
    } else if (arch == ZigLLVM_x86 ||
            arch == ZigLLVM_sparc ||
            arch == ZigLLVM_sparcel)
    {
        return buf_create_from_str("/lib/ld-linux.so.2");
    } else if (arch == ZigLLVM_aarch64) {
        return buf_create_from_str("/lib/ld-linux-aarch64.so.1");
    } else if (arch == ZigLLVM_aarch64_be) {
        return buf_create_from_str("/lib/ld-linux-aarch64_be.so.1");
    } else if (arch == ZigLLVM_arm || arch == ZigLLVM_thumb) {
        if (get_float_abi(target) == FloatAbiHard) {
            return buf_create_from_str("/lib/ld-linux-armhf.so.3");
        } else {
            return buf_create_from_str("/lib/ld-linux.so.3");
        }
    } else if (arch == ZigLLVM_armeb || arch == ZigLLVM_thumbeb) {
        if (get_float_abi(target) == FloatAbiHard) {
            return buf_create_from_str("/lib/ld-linux-armhf.so.3");
        } else {
            return buf_create_from_str("/lib/ld-linux.so.3");
        }
    } else if (arch == ZigLLVM_mips || arch == ZigLLVM_mipsel ||
            arch == ZigLLVM_mips64 || arch == ZigLLVM_mips64el)
    {
        // when you want to solve this TODO, grep clang codebase for
        // getLinuxDynamicLinker
        zig_panic("TODO figure out MIPS dynamic linker name");
    } else if (arch == ZigLLVM_ppc) {
        return buf_create_from_str("/lib/ld.so.1");
    } else if (arch == ZigLLVM_ppc64) {
        return buf_create_from_str("/lib64/ld64.so.2");
    } else if (arch == ZigLLVM_ppc64le) {
        return buf_create_from_str("/lib64/ld64.so.2");
    } else if (arch == ZigLLVM_systemz) {
        return buf_create_from_str("/lib64/ld64.so.1");
    } else if (arch == ZigLLVM_sparcv9) {
        return buf_create_from_str("/lib64/ld-linux.so.2");
    } else if (arch == ZigLLVM_x86_64 &&
            env == ZigLLVM_GNUX32)
    {
        return buf_create_from_str("/libx32/ld-linux-x32.so.2");
    } else if (arch == ZigLLVM_x86_64 &&
            (env == ZigLLVM_Musl || env == ZigLLVM_MuslEABI || env == ZigLLVM_MuslEABIHF))
    {
        return buf_create_from_str("/lib/ld-musl-x86_64.so.1");
    } else {
        return buf_create_from_str("/lib64/ld-linux-x86-64.so.2");
    }
}

bool target_can_exec(const ZigTarget *host_target, const ZigTarget *guest_target) {
    assert(host_target != nullptr);

    if (guest_target == nullptr) {
        // null guest target means that the guest target is native
        return true;
    }

    if (guest_target->os == host_target->os && guest_target->arch.arch == host_target->arch.arch &&
        guest_target->arch.sub_arch == host_target->arch.sub_arch)
    {
        // OS, arch, and sub-arch match
        return true;
    }

    if (guest_target->os == OsWindows && host_target->os == OsWindows &&
        host_target->arch.arch == ZigLLVM_x86_64 && guest_target->arch.arch == ZigLLVM_x86)
    {
        // 64-bit windows can run 32-bit programs
        return true;
    }

    return false;
}

const char *arch_stack_pointer_register_name(const ArchType *arch) {
    switch (arch->arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();
        case ZigLLVM_x86:
            return "esp";
        case ZigLLVM_x86_64:
            return "rsp";
        case ZigLLVM_aarch64:
            return "sp";

        case ZigLLVM_arm:
        case ZigLLVM_thumb:
        case ZigLLVM_aarch64_be:
        case ZigLLVM_amdgcn:
        case ZigLLVM_amdil:
        case ZigLLVM_amdil64:
        case ZigLLVM_armeb:
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
        case ZigLLVM_nios2:
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
        case ZigLLVM_thumbeb:
        case ZigLLVM_wasm32:
        case ZigLLVM_wasm64:
        case ZigLLVM_xcore:
        case ZigLLVM_ppc:
        case ZigLLVM_ppc64:
            zig_panic("TODO populate this table with stack pointer register name for this CPU architecture");
    }
    zig_unreachable();
}

bool target_is_arm(const ZigTarget *target) {
    switch (target->arch.arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();
        case ZigLLVM_aarch64:
        case ZigLLVM_arm:
        case ZigLLVM_thumb:
        case ZigLLVM_aarch64_be:
        case ZigLLVM_armeb:
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
        case ZigLLVM_nios2:
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
            return false;
    }
    zig_unreachable();
}
