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
    ZigLLVM_ArchType arch;
    ZigLLVM_SubArchType sub_arch;
};

int target_arch_count(void);
const ArchType *get_target_arch(int index);

int target_vendor_count(void);
ZigLLVM_VendorType get_target_vendor(int index);

int target_os_count(void);
ZigLLVM_OSType get_target_os(int index);
const char *get_target_os_name(ZigLLVM_OSType os_type);

int target_environ_count(void);
ZigLLVM_EnvironmentType get_target_environ(int index);

#endif
