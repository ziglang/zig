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
#include "compiler.hpp"
#include "glibc.hpp"

#include <stdio.h>

static const SubArchList subarch_list_list[] = {
    SubArchListNone,
    SubArchListArm32,
    SubArchListArm64,
    SubArchListKalimba,
    SubArchListMips,
};

static const ZigLLVM_SubArchType subarch_list_arm32[] = {
    ZigLLVM_ARMSubArch_v8_5a,
    ZigLLVM_ARMSubArch_v8_4a,
    ZigLLVM_ARMSubArch_v8_3a,
    ZigLLVM_ARMSubArch_v8_2a,
    ZigLLVM_ARMSubArch_v8_1a,
    ZigLLVM_ARMSubArch_v8,
    ZigLLVM_ARMSubArch_v8r,
    ZigLLVM_ARMSubArch_v8m_baseline,
    ZigLLVM_ARMSubArch_v8m_mainline,
    ZigLLVM_ARMSubArch_v8_1m_mainline,
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
    ZigLLVM_ARMSubArch_v8_5a,
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

static const ZigLLVM_SubArchType subarch_list_mips[] = {
    ZigLLVM_MipsSubArch_r6,
};

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
    ZigLLVM_ELFv1,
    ZigLLVM_ELFv2,
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
        case ZigLLVM_HermitCore:
            return OsHermitCore;
        case ZigLLVM_Hurd:
            return OsHurd;
        case ZigLLVM_WASI:
            return OsWASI;
        case ZigLLVM_Emscripten:
            return OsEmscripten;
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

Error target_parse_glibc_version(ZigGLibCVersion *glibc_ver, const char *text) {
    glibc_ver->major = 2;
    glibc_ver->minor = 0;
    glibc_ver->patch = 0;
    SplitIterator it = memSplit(str(text), str("GLIBC_."));
    {
        Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
        if (!opt_component.is_some) return ErrorUnknownABI;
        glibc_ver->major = strtoul(buf_ptr(buf_create_from_slice(opt_component.value)), nullptr, 10);
    }
    {
        Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
        if (!opt_component.is_some) return ErrorNone;
        glibc_ver->minor = strtoul(buf_ptr(buf_create_from_slice(opt_component.value)), nullptr, 10);
    }
    {
        Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
        if (!opt_component.is_some) return ErrorNone;
        glibc_ver->patch = strtoul(buf_ptr(buf_create_from_slice(opt_component.value)), nullptr, 10);
    }
    return ErrorNone;
}

void get_native_target(ZigTarget *target) {
    // first zero initialize
    *target = {};

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
    if (target_is_glibc(target)) {
        target->glibc_version = allocate<ZigGLibCVersion>(1);
        target_init_default_glibc_version(target);
#ifdef ZIG_OS_LINUX
        Error err;
        if ((err = glibc_detect_native_version(target->glibc_version))) {
            // Fall back to the default version.
        }
#endif
    }
}

void target_init_default_glibc_version(ZigTarget *target) {
    *target->glibc_version = {2, 17, 0};
}

Error target_parse_archsub(ZigLLVM_ArchType *out_arch, ZigLLVM_SubArchType *out_sub,
        const char *archsub_ptr, size_t archsub_len)
{
    *out_arch = ZigLLVM_UnknownArch;
    *out_sub = ZigLLVM_NoSubArch;
    for (size_t arch_i = 0; arch_i < array_length(arch_list); arch_i += 1) {
        ZigLLVM_ArchType arch = arch_list[arch_i];
        SubArchList sub_arch_list = target_subarch_list(arch);
        size_t subarch_count = target_subarch_count(sub_arch_list);
        if (mem_eql_str(archsub_ptr, archsub_len, target_arch_name(arch))) {
            *out_arch = arch;
            if (subarch_count == 0) {
                return ErrorNone;
            }
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
        case ZigLLVM_aarch64_32:
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
        case SubArchListMips:
            return array_length(subarch_list_mips);
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
        case SubArchListMips:
            assert(i < array_length(subarch_list_mips));
            return subarch_list_mips[i];
    }
    zig_unreachable();
}

const char *target_subarch_name(ZigLLVM_SubArchType subarch) {
    switch (subarch) {
        case ZigLLVM_NoSubArch:
            return "";
        case ZigLLVM_ARMSubArch_v8_5a:
            return "v8_5a";
        case ZigLLVM_ARMSubArch_v8_4a:
            return "v8_4a";
        case ZigLLVM_ARMSubArch_v8_3a:
            return "v8_3a";
        case ZigLLVM_ARMSubArch_v8_2a:
            return "v8_2a";
        case ZigLLVM_ARMSubArch_v8_1a:
            return "v8_1a";
        case ZigLLVM_ARMSubArch_v8:
            return "v8";
        case ZigLLVM_ARMSubArch_v8r:
            return "v8r";
        case ZigLLVM_ARMSubArch_v8m_baseline:
            return "v8m_baseline";
        case ZigLLVM_ARMSubArch_v8m_mainline:
            return "v8m_mainline";
        case ZigLLVM_ARMSubArch_v8_1m_mainline:
            return "v8_1m_mainline";
        case ZigLLVM_ARMSubArch_v7:
            return "v7";
        case ZigLLVM_ARMSubArch_v7em:
            return "v7em";
        case ZigLLVM_ARMSubArch_v7m:
            return "v7m";
        case ZigLLVM_ARMSubArch_v7s:
            return "v7s";
        case ZigLLVM_ARMSubArch_v7k:
            return "v7k";
        case ZigLLVM_ARMSubArch_v7ve:
            return "v7ve";
        case ZigLLVM_ARMSubArch_v6:
            return "v6";
        case ZigLLVM_ARMSubArch_v6m:
            return "v6m";
        case ZigLLVM_ARMSubArch_v6k:
            return "v6k";
        case ZigLLVM_ARMSubArch_v6t2:
            return "v6t2";
        case ZigLLVM_ARMSubArch_v5:
            return "v5";
        case ZigLLVM_ARMSubArch_v5te:
            return "v5te";
        case ZigLLVM_ARMSubArch_v4t:
            return "v4t";
        case ZigLLVM_KalimbaSubArch_v3:
            return "v3";
        case ZigLLVM_KalimbaSubArch_v4:
            return "v4";
        case ZigLLVM_KalimbaSubArch_v5:
            return "v5";
        case ZigLLVM_MipsSubArch_r6:
            return "r6";
    }
    zig_unreachable();
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
        case SubArchListMips:
            return "Mips";
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

    // first initialize all to zero
    *target = {};

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

void target_triple_zig(Buf *triple, const ZigTarget *target) {
    buf_resize(triple, 0);
    buf_appendf(triple, "%s%s-%s-%s",
            ZigLLVMGetArchTypeName(target->arch),
            ZigLLVMGetSubArchTypeName(target->sub_arch),
            ZigLLVMGetOSTypeName(get_llvm_os_type(target->os)),
            ZigLLVMGetEnvironmentTypeName(target->abi));
}

void target_triple_llvm(Buf *triple, const ZigTarget *target) {
    buf_resize(triple, 0);
    buf_appendf(triple, "%s%s-%s-%s-%s",
            ZigLLVMGetArchTypeName(target->arch),
            ZigLLVMGetSubArchTypeName(target->sub_arch),
            ZigLLVMGetVendorTypeName(target->vendor),
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

const char *target_exe_file_ext(const ZigTarget *target) {
    if (target->os == OsWindows) {
        return ".exe";
    } else if (target->os == OsUefi) {
        return ".efi";
    } else if (target_is_wasm(target)) {
        return ".wasm";
    } else {
        return "";
    }
}

const char *target_lib_file_prefix(const ZigTarget *target) {
    if ((target->os == OsWindows && !target_abi_is_gnu(target->abi)) ||
        target->os == OsUefi ||
        target_is_wasm(target))
    {
        return "";
    } else {
        return "lib";
    }
}

const char *target_lib_file_ext(const ZigTarget *target, bool is_static,
        size_t version_major, size_t version_minor, size_t version_patch)
{
    if (target_is_wasm(target)) {
        return ".wasm";
    }
    if (target->os == OsWindows || target->os == OsUefi) {
        if (is_static) {
            if (target->os == OsWindows && target_abi_is_gnu(target->abi)) {
                return ".a";
            } else {
                return ".lib";
            }
        } else {
            return ".dll";
        }
    } else {
        if (is_static) {
            return ".a";
        } else if (target_os_is_darwin(target->os)) {
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

bool target_is_android(const ZigTarget *target) {
    return target->abi == ZigLLVM_Android;
}

const char *target_dynamic_linker(const ZigTarget *target) {
    if (target_is_android(target)) {
        return is_64_bit(target->arch) ? "/system/bin/linker64" : "/system/bin/linker";
    }

    if (target_is_musl(target)) {
        Buf buf = BUF_INIT;
        buf_init_from_str(&buf, "/lib/ld-musl-");
        bool is_arm = false;
        switch (target->arch) {
            case ZigLLVM_arm:
            case ZigLLVM_thumb:
                buf_append_str(&buf, "arm");
                is_arm = true;
                break;
            case ZigLLVM_armeb:
            case ZigLLVM_thumbeb:
                buf_append_str(&buf, "armeb");
                is_arm = true;
                break;
            default:
                buf_append_str(&buf, target_arch_name(target->arch));
        }
        if (is_arm && get_float_abi(target) == FloatAbiHard) {
            buf_append_str(&buf, "hf");
        }
        buf_append_str(&buf, ".so.1");
        return buf_ptr(&buf);
    }

    switch (target->os) {
        case OsFreeBSD:
            return "/libexec/ld-elf.so.1";
        case OsNetBSD:
            return "/libexec/ld.elf_so";
        case OsDragonFly:
            return "/libexec/ld-elf.so.2";
        case OsLinux: {
            const ZigLLVM_EnvironmentType abi = target->abi;
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

                case ZigLLVM_aarch64_32:
                    return "/lib/ld-linux-aarch64_32.so.1";

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

                case ZigLLVM_riscv32:
                    return "/lib/ld-linux-riscv32-ilp32.so.1";
                case ZigLLVM_riscv64:
                    return "/lib/ld-linux-riscv64-lp64.so.1";

                case ZigLLVM_arc:
                case ZigLLVM_avr:
                case ZigLLVM_bpfel:
                case ZigLLVM_bpfeb:
                case ZigLLVM_hexagon:
                case ZigLLVM_msp430:
                case ZigLLVM_r600:
                case ZigLLVM_amdgcn:
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
        case OsWindows:
        case OsEmscripten:
        case OsOther:
            return nullptr;

        case OsAnanas:
        case OsCloudABI:
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
        case OsHermitCore:
        case OsHurd:
        case OsWASI:
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
        case ZigLLVM_ppc64le:
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

bool target_supports_fpic(const ZigTarget *target) {
    // This is not whether the target supports Position Independent Code, but whether the -fPIC
    // C compiler argument is valid.
    return target->os != OsWindows;
}

bool target_supports_clang_march_native(const ZigTarget *target) {
    // Whether clang supports -march=native on this target.
    // Arguably it should always work, but in reality it gives:
    // error: the clang compiler does not support '-march=native'
    // If we move CPU detection logic into Zig itelf, we will not need this,
    // instead we will always pass target features and CPU configuration explicitly.
    return target->arch != ZigLLVM_aarch64 &&
        target->arch != ZigLLVM_aarch64_be;
}

bool target_supports_stack_probing(const ZigTarget *target) {
    return target->os != OsWindows && target->os != OsUefi && (target->arch == ZigLLVM_x86 || target->arch == ZigLLVM_x86_64);
}

bool target_supports_sanitize_c(const ZigTarget *target) {
    return true;
}

bool target_requires_pic(const ZigTarget *target, bool linking_libc) {
  // This function returns whether non-pic code is completely invalid on the given target.
  return target_is_android(target) || target->os == OsWindows || target->os == OsUefi || target_os_requires_libc(target->os) ||
      (linking_libc && target_is_glibc(target));
}

bool target_requires_pie(const ZigTarget *target) {
    return target_is_android(target);
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

bool target_is_single_threaded(const ZigTarget *target) {
    return target_is_wasm(target);
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
        case ZigLLVM_ELFv1:
        case ZigLLVM_ELFv2:
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
    if (strcmp(name, "c") == 0)
        return true;

    if (target_abi_is_gnu(target->abi) || target_abi_is_musl(target->abi) || target_os_is_darwin(target->os)) {
        if (strcmp(name, "m") == 0)
            return true;
        if (strcmp(name, "rt") == 0)
            return true;
        if (strcmp(name, "pthread") == 0)
            return true;
        if (strcmp(name, "crypt") == 0)
            return true;
        if (strcmp(name, "util") == 0)
            return true;
        if (strcmp(name, "xnet") == 0)
            return true;
        if (strcmp(name, "resolv") == 0)
            return true;
        if (strcmp(name, "dl") == 0)
            return true;
    }

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
    out_target->sub_arch = ZigLLVM_NoSubArch;
    out_target->vendor = ZigLLVM_UnknownVendor;
    out_target->is_native = false;
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

bool target_supports_libunwind(const ZigTarget *target) {
    switch (target->arch) {
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
        case ZigLLVM_riscv32:
        case ZigLLVM_riscv64:
            return false;
        default:
            return true;
    }
    return true;
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

unsigned target_fn_align(const ZigTarget *target) {
    return 16;
}
