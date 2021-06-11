/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TARGET_HPP
#define ZIG_TARGET_HPP

#include "stage2.h"

struct Buf;

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

Error target_parse_arch(ZigLLVM_ArchType *arch, const char *arch_ptr, size_t arch_len);
Error target_parse_os(Os *os, const char *os_ptr, size_t os_len);
Error target_parse_abi(ZigLLVM_EnvironmentType *abi, const char *abi_ptr, size_t abi_len);

size_t target_arch_count(void);
ZigLLVM_ArchType target_arch_enum(size_t index);
const char *target_arch_name(ZigLLVM_ArchType arch);

const char *arch_stack_pointer_register_name(ZigLLVM_ArchType arch);

size_t target_vendor_count(void);
ZigLLVM_VendorType target_vendor_enum(size_t index);

size_t target_os_count(void);
Os target_os_enum(size_t index);
const char *target_os_name(Os os_type);

size_t target_abi_count(void);
ZigLLVM_EnvironmentType target_abi_enum(size_t index);
const char *target_abi_name(ZigLLVM_EnvironmentType abi);
ZigLLVM_EnvironmentType target_default_abi(ZigLLVM_ArchType arch, Os os);


size_t target_oformat_count(void);
ZigLLVM_ObjectFormatType target_oformat_enum(size_t index);
const char *target_oformat_name(ZigLLVM_ObjectFormatType oformat);
ZigLLVM_ObjectFormatType target_object_format(const ZigTarget *target);

void target_triple_llvm(Buf *triple, const ZigTarget *target);
void target_triple_zig(Buf *triple, const ZigTarget *target);

void init_all_targets(void);

void resolve_target_object_format(ZigTarget *target);

uint32_t target_c_type_size_in_bits(const ZigTarget *target, CIntType id);

const char *target_o_file_ext(const ZigTarget *target);
const char *target_asm_file_ext(const ZigTarget *target);
const char *target_llvm_ir_file_ext(const ZigTarget *target);

ZigLLVM_OSType get_llvm_os_type(Os os_type);

bool target_is_arm(const ZigTarget *target);
bool target_is_mips(const ZigTarget *target);
bool target_is_ppc(const ZigTarget *target);
bool target_allows_addr_zero(const ZigTarget *target);
bool target_has_valgrind_support(const ZigTarget *target);
bool target_os_is_darwin(Os os);
bool target_is_wasm(const ZigTarget *target);
bool target_is_riscv(const ZigTarget *target);
bool target_is_sparc(const ZigTarget *target);
bool target_is_android(const ZigTarget *target);
bool target_has_debug_info(const ZigTarget *target);

uint32_t target_arch_pointer_bit_width(ZigLLVM_ArchType arch);
uint32_t target_arch_largest_atomic_bits(ZigLLVM_ArchType arch);

unsigned target_fn_ptr_align(const ZigTarget *target);
unsigned target_fn_align(const ZigTarget *target);

#endif
