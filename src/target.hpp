/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TARGET_HPP
#define ZIG_TARGET_HPP

#include <zig_llvm.hpp>

struct ArchType {
    ZigLLVM_ArchType llvm_arch;
};

struct SubArchType {
    ZigLLVM_ArchType arch; // which arch it applies to
    ZigLLVM_SubArchType sub_arch;
    const char *name;
};

struct VendorType {
    ZigLLVM_VendorType llvm_vendor;
};

struct OsType {
    ZigLLVM_OSType llvm_os;
};

struct EnvironmentType {
    ZigLLVM_EnvironmentType llvm_environment;
};

int target_arch_count(void);
const ArchType *get_target_arch(int index);

int target_sub_arch_count(void);
const SubArchType *get_target_sub_arch(int index);

int target_vendor_count(void);
const VendorType *get_target_vendor(int index);

int target_os_count(void);
const OsType *get_target_os(int index);
const char *get_target_os_name(const OsType *os_type);

int target_environ_count(void);
const EnvironmentType *get_target_environ(int index);

#endif
