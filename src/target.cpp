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

static const SubArchList subarch_list_list[] = {
    SubArchListNone,
    SubArchListArm32,
    SubArchListArm64,
    SubArchListKalimba,
};

static const ZigLLVM_SubArchType subarch_list_arm32[] = {
    ZigLLVM_ARMSubArch_v8_4a,
    ZigLLVM_ARMSubArch_v8_3a,
    ZigLLVM_ARMSubArch_v8_2a,
    ZigLLVM_ARMSubArch_v8_1a,
    ZigLLVM_ARMSubArch_v8,
    ZigLLVM_ARMSubArch_v8r,
    ZigLLVM_ARMSubArch_v8m_baseline,
    ZigLLVM_ARMSubArch_v8m_mainline,
    ZigLLVM_ARMSubArch_v7,
    ZigLLVM_ARMSubArch_v7em,
    ZigLLVM_ARMSubArch_v7m,
    ZigLLVM_ARMSubArch_v7s,
    ZigLLVM_ARMSubArch_v7k,
    ZigLLVM_ARMSubArch_v7ve,
    ZigLLVM_ARMSubArch_v6,
    ZigLLVM_ARMSubArch_v6m,
    ZigLLVM_ARMSubArch_v6k,
    ZigLLVM_ARMSubArch_v6t2,
    ZigLLVM_ARMSubArch_v5,
    ZigLLVM_ARMSubArch_v5te,
    ZigLLVM_ARMSubArch_v4t,
};

static const ZigLLVM_SubArchType subarch_list_arm64[] = {
    ZigLLVM_ARMSubArch_v8_4a,
    ZigLLVM_ARMSubArch_v8_3a,
    ZigLLVM_ARMSubArch_v8_2a,
    ZigLLVM_ARMSubArch_v8_1a,
    ZigLLVM_ARMSubArch_v8,
    ZigLLVM_ARMSubArch_v8r,
    ZigLLVM_ARMSubArch_v8m_baseline,
    ZigLLVM_ARMSubArch_v8m_mainline,
};

static const ZigLLVM_SubArchType subarch_list_kalimba[] = {
    ZigLLVM_KalimbaSubArch_v5,
    ZigLLVM_KalimbaSubArch_v4,
    ZigLLVM_KalimbaSubArch_v3,
};

static const ZigLLVM_ArchType arch_list[] = {
    ZigLLVM_arm,
    ZigLLVM_armeb,
    ZigLLVM_aarch64,
    ZigLLVM_aarch64_be,
    ZigLLVM_arc,
    ZigLLVM_avr,
    ZigLLVM_bpfel,
    ZigLLVM_bpfeb,
    ZigLLVM_hexagon,
    ZigLLVM_mips,
    ZigLLVM_mipsel,
    ZigLLVM_mips64,
    ZigLLVM_mips64el,
    ZigLLVM_msp430,
    ZigLLVM_nios2,
    ZigLLVM_ppc,
    ZigLLVM_ppc64,
    ZigLLVM_ppc64le,
    ZigLLVM_r600,
    ZigLLVM_amdgcn,
    ZigLLVM_riscv32,
    ZigLLVM_riscv64,
    ZigLLVM_sparc,
    ZigLLVM_sparcv9,
    ZigLLVM_sparcel,
    ZigLLVM_systemz,
    ZigLLVM_tce,
    ZigLLVM_tcele,
    ZigLLVM_thumb,
    ZigLLVM_thumbeb,
    ZigLLVM_x86,
    ZigLLVM_x86_64,
    ZigLLVM_xcore,
    ZigLLVM_nvptx,
    ZigLLVM_nvptx64,
    ZigLLVM_le32,
    ZigLLVM_le64,
    ZigLLVM_amdil,
    ZigLLVM_amdil64,
    ZigLLVM_hsail,
    ZigLLVM_hsail64,
    ZigLLVM_spir,
    ZigLLVM_spir64,
    ZigLLVM_kalimba,
    ZigLLVM_shave,
    ZigLLVM_lanai,
    ZigLLVM_wasm32,
    ZigLLVM_wasm64,
    ZigLLVM_renderscript32,
    ZigLLVM_renderscript64,
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
    OsZen,
    OsUefi,
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
        case OsZen:
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
    }
    zig_unreachable();
}

const char *target_os_name(Os os_type) {
    switch (os_type) {
        case OsFreestanding:
            return "freestanding";
        case OsZen:
            return "zen";
        case OsUefi:
            return "uefi";
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

void get_native_target(ZigTarget *target) {
    ZigLLVM_OSType os_type;
    ZigLLVM_ObjectFormatType oformat; // ignored; based on arch/os
    ZigLLVMGetNativeTarget(
            &target->arch,
            &target->sub_arch,
            &target->vendor,
            &os_type,
            &target->abi,
            &oformat);
    target->os = get_zig_os_type(os_type);
    target->is_native = true;
    if (target->abi == ZigLLVM_UnknownEnvironment) {
        target->abi = target_default_abi(target->arch, target->os);
    }
}

Error target_parse_archsub(ZigLLVM_ArchType *out_arch, ZigLLVM_SubArchType *out_sub,
        const char *archsub_ptr, size_t archsub_len)
{
    for (size_t arch_i = 0; arch_i < array_length(arch_list); arch_i += 1) {
        ZigLLVM_ArchType arch = arch_list[arch_i];
        SubArchList sub_arch_list = target_subarch_list(arch);
        size_t subarch_count = target_subarch_count(sub_arch_list);
        if (subarch_count == 0) {
            if (mem_eql_str(archsub_ptr, archsub_len, target_arch_name(arch))) {
                *out_arch = arch;
                *out_sub = ZigLLVM_NoSubArch;
                return ErrorNone;
            }
            continue;
        }
        for (size_t sub_i = 0; sub_i < subarch_count; sub_i += 1) {
            ZigLLVM_SubArchType sub = target_subarch_enum(sub_arch_list, sub_i);
            char arch_name[64];
            int n = sprintf(arch_name, "%s%s", target_arch_name(arch), target_subarch_name(sub));
            if (mem_eql_mem(arch_name, n, archsub_ptr, archsub_len)) {
                *out_arch = arch;
                *out_sub = sub;
                return ErrorNone;
            }
        }
    }
    return ErrorUnknownArchitecture;
}

SubArchList target_subarch_list(ZigLLVM_ArchType arch) {
    switch (arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
        case ZigLLVM_thumb:
        case ZigLLVM_thumbeb:
            return SubArchListArm32;

        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
            return SubArchListArm64;

        case ZigLLVM_kalimba:
            return SubArchListKalimba;

        case ZigLLVM_arc:
        case ZigLLVM_avr:
        case ZigLLVM_bpfel:
        case ZigLLVM_bpfeb:
        case ZigLLVM_hexagon:
        case ZigLLVM_mips:
        case ZigLLVM_mipsel:
        case ZigLLVM_mips64:
        case ZigLLVM_mips64el:
        case ZigLLVM_msp430:
        case ZigLLVM_nios2:
        case ZigLLVM_ppc:
        case ZigLLVM_ppc64:
        case ZigLLVM_ppc64le:
        case ZigLLVM_r600:
        case ZigLLVM_amdgcn:
        case ZigLLVM_riscv32:
        case ZigLLVM_riscv64:
        case ZigLLVM_sparc:
        case ZigLLVM_sparcv9:
        case ZigLLVM_sparcel:
        case ZigLLVM_systemz:
        case ZigLLVM_tce:
        case ZigLLVM_tcele:
        case ZigLLVM_x86:
        case ZigLLVM_x86_64:
        case ZigLLVM_xcore:
        case ZigLLVM_nvptx:
        case ZigLLVM_nvptx64:
        case ZigLLVM_le32:
        case ZigLLVM_le64:
        case ZigLLVM_amdil:
        case ZigLLVM_amdil64:
        case ZigLLVM_hsail:
        case ZigLLVM_hsail64:
        case ZigLLVM_spir:
        case ZigLLVM_spir64:
        case ZigLLVM_shave:
        case ZigLLVM_lanai:
        case ZigLLVM_wasm32:
        case ZigLLVM_wasm64:
        case ZigLLVM_renderscript32:
        case ZigLLVM_renderscript64:
            return SubArchListNone;
    }
    zig_unreachable();
}

size_t target_subarch_count(SubArchList sub_arch_list) {
    switch (sub_arch_list) {
        case SubArchListNone:
            return 0;
        case SubArchListArm32:
            return array_length(subarch_list_arm32);
        case SubArchListArm64:
            return array_length(subarch_list_arm64);
        case SubArchListKalimba:
            return array_length(subarch_list_kalimba);
    }
    zig_unreachable();
}

ZigLLVM_SubArchType target_subarch_enum(SubArchList sub_arch_list, size_t i) {
    switch (sub_arch_list) {
        case SubArchListNone:
            zig_unreachable();
        case SubArchListArm32:
            assert(i < array_length(subarch_list_arm32));
            return subarch_list_arm32[i];
        case SubArchListArm64:
            assert(i < array_length(subarch_list_arm64));
            return subarch_list_arm64[i];
        case SubArchListKalimba:
            assert(i < array_length(subarch_list_kalimba));
            return subarch_list_kalimba[i];
    }
    zig_unreachable();
}

const char *target_subarch_name(ZigLLVM_SubArchType subarch) {
    return ZigLLVMGetSubArchTypeName(subarch);
}

size_t target_subarch_list_count(void) {
    return array_length(subarch_list_list);
}

SubArchList target_subarch_list_enum(size_t index) {
    assert(index < array_length(subarch_list_list));
    return subarch_list_list[index];
}

const char *target_subarch_list_name(SubArchList sub_arch_list) {
    switch (sub_arch_list) {
        case SubArchListNone:
            return "None";
        case SubArchListArm32:
            return "Arm32";
        case SubArchListArm64:
            return "Arm64";
        case SubArchListKalimba:
            return "Kalimba";
    }
    zig_unreachable();
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

Error target_parse_triple(ZigTarget *target, const char *triple) {
    Error err;
    SplitIterator it = memSplit(str(triple), str("-"));

    Optional<Slice<uint8_t>> opt_archsub = SplitIterator_next(&it);
    Optional<Slice<uint8_t>> opt_os = SplitIterator_next(&it);
    Optional<Slice<uint8_t>> opt_abi = SplitIterator_next(&it);

    if (!opt_archsub.is_some)
        return ErrorMissingArchitecture;

    if ((err = target_parse_archsub(&target->arch, &target->sub_arch,
                    (char*)opt_archsub.value.ptr, opt_archsub.value.len)))
    {
        return err;
    }

    if (!opt_os.is_some)
        return ErrorMissingOperatingSystem;

    if ((err = target_parse_os(&target->os, (char*)opt_os.value.ptr, opt_os.value.len))) {
        return err;
    }

    if (opt_abi.is_some) {
        if ((err = target_parse_abi(&target->abi, (char*)opt_abi.value.ptr, opt_abi.value.len))) {
            return err;
        }
    } else {
        target->abi = target_default_abi(target->arch, target->os);
    }

    target->vendor = ZigLLVM_UnknownVendor;
    target->is_native = false;
    return ErrorNone;
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

void get_target_triple(Buf *triple, const ZigTarget *target) {
    buf_resize(triple, 0);
    buf_appendf(triple, "%s%s-%s-%s-%s",
            ZigLLVMGetArchTypeName(target->arch),
            ZigLLVMGetSubArchTypeName(target->sub_arch),
            ZigLLVMGetVendorTypeName(target->vendor),
            ZigLLVMGetOSTypeName(get_llvm_os_type(target->os)),
            ZigLLVMGetEnvironmentTypeName(target->abi));
}

bool target_is_darwin(const ZigTarget *target) {
    switch (target->os) {
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
    } else if (target_is_darwin(target)) {
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
        case OsLinux:
        case OsMacOSX:
        case OsZen:
        case OsFreeBSD:
	case OsNetBSD:
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
                    return target_arch_pointer_bit_width(target->arch);
                case CIntTypeLongLong:
                case CIntTypeULongLong:
                    return 64;
                case CIntTypeCount:
                    zig_unreachable();
            }
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
        case OsAnanas:
        case OsCloudABI:
        case OsDragonFly:
        case OsIOS:
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
            zig_panic("TODO c type size in bits for this target");
    }
    zig_unreachable();
}

bool target_allows_addr_zero(const ZigTarget *target) {
    return target->os == OsFreestanding;
}

const char *target_o_file_ext(const ZigTarget *target) {
    if (target->abi == ZigLLVM_MSVC || target->os == OsWindows || target->os == OsUefi) {
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

const char *target_exe_file_ext(const ZigTarget *target) {
    if (target->os == OsWindows) {
        return ".exe";
    } else if (target->os == OsUefi) {
        return ".efi";
    } else {
        return "";
    }
}

const char *target_lib_file_prefix(const ZigTarget *target) {
    if (target->os == OsWindows || target->os == OsUefi) {
        return "";
    } else {
        return "lib";
    }
}

const char *target_lib_file_ext(const ZigTarget *target, bool is_static,
        size_t version_major, size_t version_minor, size_t version_patch)
{
    if (target->os == OsWindows || target->os == OsUefi) {
        if (is_static) {
            return ".lib";
        } else {
            return ".dll";
        }
    } else {
        if (is_static) {
            return ".a";
        } else if (target_is_darwin(target)) {
            return buf_ptr(buf_sprintf(".%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".dylib",
                        version_major, version_minor, version_patch));
        } else {
            return buf_ptr(buf_sprintf(".so.%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize,
                        version_major, version_minor, version_patch));
        }
    }
}

enum FloatAbi {
    FloatAbiHard,
    FloatAbiSoft,
    FloatAbiSoftFp,
};

static FloatAbi get_float_abi(const ZigTarget *target) {
    const ZigLLVM_EnvironmentType env = target->abi;
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
    return target_arch_pointer_bit_width(arch) == 64;
}

const char *target_dynamic_linker(const ZigTarget *target) {
    switch (target->os) {
        case OsFreeBSD:
            return "/libexec/ld-elf.so.1";
        case OsNetBSD:
            return "/libexec/ld.elf_so";
        case OsLinux: {
            const ZigLLVM_EnvironmentType abi = target->abi;
            if (abi == ZigLLVM_Android) {
                if (is_64_bit(target->arch)) {
                    return "/system/bin/linker64";
                } else {
                    return "/system/bin/linker";
                }
            }

            switch (target->arch) {
                case ZigLLVM_UnknownArch:
                    zig_unreachable();
                case ZigLLVM_x86:
                case ZigLLVM_sparc:
                case ZigLLVM_sparcel:
                    return "/lib/ld-linux.so.2";

                case ZigLLVM_aarch64:
                    return "/lib/ld-linux-aarch64.so.1";

                case ZigLLVM_aarch64_be:
                    return "/lib/ld-linux-aarch64_be.so.1";

                case ZigLLVM_arm:
                case ZigLLVM_thumb:
                    if (get_float_abi(target) == FloatAbiHard) {
                        return "/lib/ld-linux-armhf.so.3";
                    } else {
                        return "/lib/ld-linux.so.3";
                    }

                case ZigLLVM_armeb:
                case ZigLLVM_thumbeb:
                    if (get_float_abi(target) == FloatAbiHard) {
                        return "/lib/ld-linux-armhf.so.3";
                    } else {
                        return "/lib/ld-linux.so.3";
                    }

                case ZigLLVM_mips:
                case ZigLLVM_mipsel:
                case ZigLLVM_mips64:
                case ZigLLVM_mips64el:
                    zig_panic("TODO implement target_dynamic_linker for mips");

                case ZigLLVM_ppc:
                    return "/lib/ld.so.1";

                case ZigLLVM_ppc64:
                    return "/lib64/ld64.so.2";

                case ZigLLVM_ppc64le:
                    return "/lib64/ld64.so.2";

                case ZigLLVM_systemz:
                    return "/lib64/ld64.so.1";

                case ZigLLVM_sparcv9:
                    return "/lib64/ld-linux.so.2";

                case ZigLLVM_x86_64:
                    if (abi == ZigLLVM_GNUX32) {
                        return "/libx32/ld-linux-x32.so.2";
                    }
                    if (abi == ZigLLVM_Musl || abi == ZigLLVM_MuslEABI || abi == ZigLLVM_MuslEABIHF) {
                        return "/lib/ld-musl-x86_64.so.1";
                    }
                    return "/lib64/ld-linux-x86-64.so.2";

                case ZigLLVM_wasm32:
                case ZigLLVM_wasm64:
                    return nullptr;

                case ZigLLVM_arc:
                case ZigLLVM_avr:
                case ZigLLVM_bpfel:
                case ZigLLVM_bpfeb:
                case ZigLLVM_hexagon:
                case ZigLLVM_msp430:
                case ZigLLVM_nios2:
                case ZigLLVM_r600:
                case ZigLLVM_amdgcn:
                case ZigLLVM_riscv32:
                case ZigLLVM_riscv64:
                case ZigLLVM_tce:
                case ZigLLVM_tcele:
                case ZigLLVM_xcore:
                case ZigLLVM_nvptx:
                case ZigLLVM_nvptx64:
                case ZigLLVM_le32:
                case ZigLLVM_le64:
                case ZigLLVM_amdil:
                case ZigLLVM_amdil64:
                case ZigLLVM_hsail:
                case ZigLLVM_hsail64:
                case ZigLLVM_spir:
                case ZigLLVM_spir64:
                case ZigLLVM_kalimba:
                case ZigLLVM_shave:
                case ZigLLVM_lanai:
                case ZigLLVM_renderscript32:
                case ZigLLVM_renderscript64:
                    zig_panic("TODO implement target_dynamic_linker for this arch");
            }
            zig_unreachable();
        }
        case OsFreestanding:
        case OsIOS:
        case OsTvOS:
        case OsWatchOS:
        case OsMacOSX:
        case OsUefi:
            return nullptr;

        case OsWindows:
            switch (target->abi) {
                case ZigLLVM_GNU:
                case ZigLLVM_GNUABIN32:
                case ZigLLVM_GNUABI64:
                case ZigLLVM_GNUEABI:
                case ZigLLVM_GNUEABIHF:
                case ZigLLVM_GNUX32:
                case ZigLLVM_Cygnus:
                    zig_panic("TODO implement target_dynamic_linker for mingw/cygwin");
                default:
                    return nullptr;
            }
            zig_unreachable();

        case OsAnanas:
        case OsCloudABI:
        case OsDragonFly:
        case OsFuchsia:
        case OsKFreeBSD:
        case OsLv2:
        case OsOpenBSD:
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
        case OsZen:
            zig_panic("TODO implement target_dynamic_linker for this OS");
    }
    zig_unreachable();
}

bool target_can_exec(const ZigTarget *host_target, const ZigTarget *guest_target) {
    assert(host_target != nullptr);

    if (guest_target == nullptr) {
        // null guest target means that the guest target is native
        return true;
    }

    if (guest_target->os == host_target->os && guest_target->arch == host_target->arch &&
        guest_target->sub_arch == host_target->sub_arch)
    {
        // OS, arch, and sub-arch match
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
    switch (target->arch) {
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

// Valgrind supports more, but Zig does not support them yet.
bool target_has_valgrind_support(const ZigTarget *target) {
    switch (target->arch) {
        case ZigLLVM_UnknownArch:
            zig_unreachable();
        case ZigLLVM_x86_64:
            return (target->os == OsLinux || target_is_darwin(target) || target->os == OsSolaris ||
                (target->os == OsWindows && target->abi != ZigLLVM_MSVC));
        default:
            return false;
    }
    zig_unreachable();
}

bool target_requires_libc(const ZigTarget *target) {
    // On Darwin, we always link libSystem which contains libc.
    // Similarly on FreeBSD and NetBSD we always link system libc
    // since this is the stable syscall interface.
    return (target_is_darwin(target) || target->os == OsFreeBSD || target->os == OsNetBSD);
}

bool target_supports_fpic(const ZigTarget *target) {
  // This is not whether the target supports Position Independent Code, but whether the -fPIC
  // C compiler argument is valid.
  return target->os != OsWindows;
}

ZigLLVM_EnvironmentType target_default_abi(ZigLLVM_ArchType arch, Os os) {
    switch (os) {
        case OsFreestanding:
        case OsAnanas:
        case OsCloudABI:
        case OsDragonFly:
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
        case OsZen:
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
            return ZigLLVM_GNU;
        case OsWindows:
        case OsUefi:
            return ZigLLVM_MSVC;
        case OsLinux:
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
