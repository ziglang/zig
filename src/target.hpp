/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TARGET_HPP
#define ZIG_TARGET_HPP

#include <zig_llvm.hpp>

struct Buf;

struct ArchType {
    ZigLLVM_ArchType arch;
    ZigLLVM_SubArchType sub_arch;
};

struct ZigTarget {
    ArchType arch;
    ZigLLVM_VendorType vendor;
    ZigLLVM_OSType os;
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

int target_arch_count(void);
const ArchType *get_target_arch(int index);
void get_arch_name(char *out_str, const ArchType *arch);

int target_vendor_count(void);
ZigLLVM_VendorType get_target_vendor(int index);

int target_os_count(void);
ZigLLVM_OSType get_target_os(int index);
const char *get_target_os_name(ZigLLVM_OSType os_type);

int target_environ_count(void);
ZigLLVM_EnvironmentType get_target_environ(int index);

void get_native_target(ZigTarget *target);
void get_unknown_target(ZigTarget *target);

int parse_target_arch(const char *str, ArchType *arch);
int parse_target_os(const char *str, ZigLLVM_OSType *os);
int parse_target_environ(const char *str, ZigLLVM_EnvironmentType *env_type);

void init_all_targets(void);

void get_target_triple(Buf *triple, const ZigTarget *target);

void resolve_target_object_format(ZigTarget *target);

int get_c_type_size_in_bits(const ZigTarget *target, CIntType id);

#endif
