/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "target.hpp"
#include "util.hpp"

static const ArchType arch_list[] = {
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8_1a},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7em},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7m},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7s},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6m},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6k},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6t2},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v5},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v5te},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v4t},

    {ZigLLVM_armeb, ZigLLVM_NoSubArch},
    {ZigLLVM_aarch64, ZigLLVM_NoSubArch},
    {ZigLLVM_aarch64_be, ZigLLVM_NoSubArch},
    {ZigLLVM_bpfel, ZigLLVM_NoSubArch},
    {ZigLLVM_bpfeb, ZigLLVM_NoSubArch},
    {ZigLLVM_hexagon, ZigLLVM_NoSubArch},
    {ZigLLVM_mips, ZigLLVM_NoSubArch},
    {ZigLLVM_mipsel, ZigLLVM_NoSubArch},
    {ZigLLVM_mips64, ZigLLVM_NoSubArch},
    {ZigLLVM_mips64el, ZigLLVM_NoSubArch},
    {ZigLLVM_msp430, ZigLLVM_NoSubArch},
    {ZigLLVM_ppc, ZigLLVM_NoSubArch},
    {ZigLLVM_ppc64, ZigLLVM_NoSubArch},
    {ZigLLVM_ppc64le, ZigLLVM_NoSubArch},
    {ZigLLVM_r600, ZigLLVM_NoSubArch},
    {ZigLLVM_amdgcn, ZigLLVM_NoSubArch},
    {ZigLLVM_sparc, ZigLLVM_NoSubArch},
    {ZigLLVM_sparcv9, ZigLLVM_NoSubArch},
    {ZigLLVM_sparcel, ZigLLVM_NoSubArch},
    {ZigLLVM_systemz, ZigLLVM_NoSubArch},
    {ZigLLVM_tce, ZigLLVM_NoSubArch},
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
    {ZigLLVM_wasm32, ZigLLVM_NoSubArch},
    {ZigLLVM_wasm64, ZigLLVM_NoSubArch},
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
};

static const ZigLLVM_OSType os_list[] = {
    ZigLLVM_UnknownOS,
    ZigLLVM_CloudABI,
    ZigLLVM_Darwin,
    ZigLLVM_DragonFly,
    ZigLLVM_FreeBSD,
    ZigLLVM_IOS,
    ZigLLVM_KFreeBSD,
    ZigLLVM_Linux,
    ZigLLVM_Lv2,
    ZigLLVM_MacOSX,
    ZigLLVM_NetBSD,
    ZigLLVM_OpenBSD,
    ZigLLVM_Solaris,
    ZigLLVM_Win32,
    ZigLLVM_Haiku,
    ZigLLVM_Minix,
    ZigLLVM_RTEMS,
    ZigLLVM_NaCl,
    ZigLLVM_CNK,
    ZigLLVM_Bitrig,
    ZigLLVM_AIX,
    ZigLLVM_CUDA,
    ZigLLVM_NVCL,
    ZigLLVM_AMDHSA,
    ZigLLVM_PS4,
};

static const ZigLLVM_EnvironmentType environ_list[] = {
    ZigLLVM_GNU,
    ZigLLVM_GNUEABI,
    ZigLLVM_GNUEABIHF,
    ZigLLVM_GNUX32,
    ZigLLVM_CODE16,
    ZigLLVM_EABI,
    ZigLLVM_EABIHF,
    ZigLLVM_Android,
    ZigLLVM_MSVC,
    ZigLLVM_Itanium,
    ZigLLVM_Cygnus,
};

int target_arch_count(void) {
    return array_length(arch_list);
}

const ArchType *get_target_arch(int index) {
    return &arch_list[index];
}

int target_vendor_count(void) {
    return array_length(vendor_list);
}

ZigLLVM_VendorType get_target_vendor(int index) {
    return vendor_list[index];
}

int target_os_count(void) {
    return array_length(os_list);
}
ZigLLVM_OSType get_target_os(int index) {
    return os_list[index];
}

const char *get_target_os_name(ZigLLVM_OSType os_type) {
    return (os_type == ZigLLVM_UnknownOS) ? "freestanding" : ZigLLVMGetOSTypeName(os_type);
}

int target_environ_count(void) {
    return array_length(environ_list);
}
ZigLLVM_EnvironmentType get_target_environ(int index) {
    return environ_list[index];
}
