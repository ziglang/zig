/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_GLIBC_HPP
#define ZIG_GLIBC_HPP

#include "all_types.hpp"

struct ZigGLibCLib {
    const char *name;
    uint8_t sover;
};

struct ZigGLibCFn {
    Buf *name;
    const ZigGLibCLib *lib;
};

struct ZigGLibCVerList {
    uint8_t versions[8]; // 8 is just the max number, we know statically it's big enough
    uint8_t len;
};

uint32_t hash_glibc_target(const ZigTarget *x);
bool eql_glibc_target(const ZigTarget *a, const ZigTarget *b);

struct ZigGLibCAbi {
    Buf *abi_txt_path;
    Buf *vers_txt_path;
    Buf *fns_txt_path;
    ZigList<Stage2SemVer> all_versions;
    ZigList<ZigGLibCFn> all_functions;
    // The value is a pointer to all_functions.length items and each item is an index
    // into all_functions.
    HashMap<const ZigTarget *, ZigGLibCVerList *, hash_glibc_target, eql_glibc_target> version_table;
};

Error glibc_load_metadata(ZigGLibCAbi **out_result, Buf *zig_lib_dir, bool verbose);
Error glibc_build_dummies_and_maps(CodeGen *codegen, const ZigGLibCAbi *glibc_abi, const ZigTarget *target,
        Buf **out_dir, bool verbose, Stage2ProgressNode *progress_node);

size_t glibc_lib_count(void);
const ZigGLibCLib *glibc_lib_enum(size_t index);
const ZigGLibCLib *glibc_lib_find(const char *name);

#endif
