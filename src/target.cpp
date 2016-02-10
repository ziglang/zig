/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "target.hpp"
#include "util.hpp"

static const ArchType arch_list[] = {
    {ZigLLVM_arm},
    {ZigLLVM_armeb},
    {ZigLLVM_aarch64},
    {ZigLLVM_aarch64_be},
    {ZigLLVM_bpfel},
    {ZigLLVM_bpfeb},
    {ZigLLVM_hexagon},
    {ZigLLVM_mips},
    {ZigLLVM_mipsel},
    {ZigLLVM_mips64},
    {ZigLLVM_mips64el},
    {ZigLLVM_msp430},
    {ZigLLVM_ppc},
    {ZigLLVM_ppc64},
    {ZigLLVM_ppc64le},
    {ZigLLVM_r600},
    {ZigLLVM_amdgcn},
    {ZigLLVM_sparc},
    {ZigLLVM_sparcv9},
    {ZigLLVM_sparcel},
    {ZigLLVM_systemz},
    {ZigLLVM_tce},
    {ZigLLVM_thumb},
    {ZigLLVM_thumbeb},
    {ZigLLVM_x86},
    {ZigLLVM_x86_64},
    {ZigLLVM_xcore},
    {ZigLLVM_nvptx},
    {ZigLLVM_nvptx64},
    {ZigLLVM_le32},
    {ZigLLVM_le64},
    {ZigLLVM_amdil},
    {ZigLLVM_amdil64},
    {ZigLLVM_hsail},
    {ZigLLVM_hsail64},
    {ZigLLVM_spir},
    {ZigLLVM_spir64},
    {ZigLLVM_kalimba},
    {ZigLLVM_shave},
    {ZigLLVM_wasm32},
    {ZigLLVM_wasm64},
};

static const SubArchType sub_arch_list[] = {
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8_1a, "v8_1a"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v8, "v8"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7, "v7"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7em, "v7em"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7m, "v7m"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v7s, "v7s"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6, "v6"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6m, "v6m"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6k, "v6k"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v6t2, "v6t2"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v5, "v5"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v5te, "v5te"},
    {ZigLLVM_arm, ZigLLVM_ARMSubArch_v4t, "v4t"},

    {ZigLLVM_kalimba, ZigLLVM_KalimbaSubArch_v3, "v3"},
    {ZigLLVM_kalimba, ZigLLVM_KalimbaSubArch_v4, "v4"},
    {ZigLLVM_kalimba, ZigLLVM_KalimbaSubArch_v5, "v5"},
};

static const VendorType vendor_list[] = {
    {ZigLLVM_Apple},
    {ZigLLVM_PC},
    {ZigLLVM_SCEI},
    {ZigLLVM_BGP},
    {ZigLLVM_BGQ},
    {ZigLLVM_Freescale},
    {ZigLLVM_IBM},
    {ZigLLVM_ImaginationTechnologies},
    {ZigLLVM_MipsTechnologies},
    {ZigLLVM_NVIDIA},
    {ZigLLVM_CSR},
};

static const OsType os_list[] = {
    {ZigLLVM_UnknownOS},
    {ZigLLVM_CloudABI},
    {ZigLLVM_Darwin},
    {ZigLLVM_DragonFly},
    {ZigLLVM_FreeBSD},
    {ZigLLVM_IOS},
    {ZigLLVM_KFreeBSD},
    {ZigLLVM_Linux},
    {ZigLLVM_Lv2},
    {ZigLLVM_MacOSX},
    {ZigLLVM_NetBSD},
    {ZigLLVM_OpenBSD},
    {ZigLLVM_Solaris},
    {ZigLLVM_Win32},
    {ZigLLVM_Haiku},
    {ZigLLVM_Minix},
    {ZigLLVM_RTEMS},
    {ZigLLVM_NaCl},
    {ZigLLVM_CNK},
    {ZigLLVM_Bitrig},
    {ZigLLVM_AIX},
    {ZigLLVM_CUDA},
    {ZigLLVM_NVCL},
    {ZigLLVM_AMDHSA},
    {ZigLLVM_PS4},
};

static const EnvironmentType environ_list[] = {
    {ZigLLVM_GNU},
    {ZigLLVM_GNUEABI},
    {ZigLLVM_GNUEABIHF},
    {ZigLLVM_GNUX32},
    {ZigLLVM_CODE16},
    {ZigLLVM_EABI},
    {ZigLLVM_EABIHF},
    {ZigLLVM_Android},
    {ZigLLVM_MSVC},
    {ZigLLVM_Itanium},
    {ZigLLVM_Cygnus},
};

int target_arch_count(void) {
    return array_length(arch_list);
}

const ArchType *get_target_arch(int index) {
    return &arch_list[index];
}

int target_sub_arch_count(void) {
    return array_length(sub_arch_list);
}
const SubArchType *get_target_sub_arch(int index) {
    return &sub_arch_list[index];
}

int target_vendor_count(void) {
    return array_length(vendor_list);
}

const VendorType *get_target_vendor(int index) {
    return &vendor_list[index];
}

int target_os_count(void) {
    return array_length(os_list);
}
const OsType *get_target_os(int index) {
    return &os_list[index];
}
const char *get_target_os_name(const OsType *os_type) {
    return (os_type->llvm_os == ZigLLVM_UnknownOS) ? "freestanding" : ZigLLVMGetOSTypeName(os_type->llvm_os);
}

int target_environ_count(void) {
    return array_length(environ_list);
}
const EnvironmentType *get_target_environ(int index) {
    return &environ_list[index];
}
