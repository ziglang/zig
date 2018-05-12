/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TARGET_HPP
#define ZIG_TARGET_HPP

#include <zig_llvm.h>

struct Buf;

struct ArchType {
    ZigLLVM_ArchType arch;
    ZigLLVM_SubArchType sub_arch;
};

enum Os {
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
    OsBitrig,
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
    OsZen,
};

struct ZigTarget {
    ArchType arch;
    ZigLLVM_VendorType vendor;
    Os os;
    ZigLLVM_EnvironmentType env_type;
    ZigLLVM_ObjectFormatType oformat;
};

enum CIntType {
    CIntTypeShort,
    CIntTypeUShort,
    CIntTypeInt,
    CIntTypeUInt,
    CIntTypeLong,
    CIntTypeULong,
    CIntTypeLongLong,
    CIntTypeULongLong,

    CIntTypeCount,
};

size_t target_arch_count(void);
const ArchType *get_target_arch(size_t index);
void get_arch_name(char *out_str, const ArchType *arch);

const char *arch_stack_pointer_register_name(const ArchType *arch);

size_t target_vendor_count(void);
ZigLLVM_VendorType get_target_vendor(size_t index);

size_t target_os_count(void);
Os get_target_os(size_t index);
const char *get_target_os_name(Os os_type);

size_t target_environ_count(void);
ZigLLVM_EnvironmentType get_target_environ(size_t index);


size_t target_oformat_count(void);
const ZigLLVM_ObjectFormatType get_target_oformat(size_t index);
const char *get_target_oformat_name(ZigLLVM_ObjectFormatType oformat);

void get_native_target(ZigTarget *target);
void get_unknown_target(ZigTarget *target);

int parse_target_arch(const char *str, ArchType *arch);
int parse_target_os(const char *str, Os *os);
int parse_target_environ(const char *str, ZigLLVM_EnvironmentType *env_type);

void init_all_targets(void);

void get_target_triple(Buf *triple, const ZigTarget *target);

void resolve_target_object_format(ZigTarget *target);

uint32_t target_c_type_size_in_bits(const ZigTarget *target, CIntType id);

const char *target_o_file_ext(ZigTarget *target);
const char *target_asm_file_ext(ZigTarget *target);
const char *target_llvm_ir_file_ext(ZigTarget *target);
const char *target_exe_file_ext(ZigTarget *target);

Buf *target_dynamic_linker(ZigTarget *target);

bool target_can_exec(const ZigTarget *host_target, const ZigTarget *guest_target);


#endif
