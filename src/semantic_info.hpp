/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_SEMANTIC_INFO_HPP
#define ZIG_SEMANTIC_INFO_HPP

#include "codegen.hpp"
#include "hash_map.hpp"
#include "zig_llvm.hpp"

struct FnTableEntry {
    LLVMValueRef fn_value;
    AstNode *proto_node;
    AstNode *fn_def_node;
    bool is_extern;
    bool internal_linkage;
    unsigned calling_convention;
};

struct TypeTableEntry {
    LLVMTypeRef type_ref;
    LLVMZigDIType *di_type;

    TypeTableEntry *pointer_child;
    bool pointer_is_const;
    int user_defined_id;
    Buf name;
    TypeTableEntry *pointer_const_parent;
    TypeTableEntry *pointer_mut_parent;
};

struct CodeGen {
    LLVMModuleRef module;
    AstNode *root;
    ZigList<ErrorMsg> errors;
    LLVMBuilderRef builder;
    LLVMZigDIBuilder *dbuilder;
    LLVMZigDICompileUnit *compile_unit;
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;
    HashMap<Buf *, LLVMValueRef, buf_hash, buf_eql_buf> str_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> type_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> link_table;

    struct {
        TypeTableEntry *entry_u8;
        TypeTableEntry *entry_i32;
        TypeTableEntry *entry_void;
        TypeTableEntry *entry_unreachable;
        TypeTableEntry *entry_invalid;
    } builtin_types;

    LLVMTargetDataRef target_data_ref;
    unsigned pointer_size_bytes;
    bool is_static;
    bool strip_debug_symbols;
    CodeGenBuildType build_type;
    LLVMTargetMachineRef target_machine;
    bool is_native_target;
    Buf in_file;
    Buf in_dir;
    ZigList<LLVMZigDIScope *> block_scopes;
    LLVMZigDIFile *di_file;
    ZigList<FnTableEntry *> fn_defs;
    Buf *out_name;
    OutType out_type;
    FnTableEntry *cur_fn;
    bool c_stdint_used;
    AstNode *root_export_decl;
    int version_major;
    int version_minor;
    int version_patch;
};

struct TypeNode {
    TypeTableEntry *entry;
};

struct FnDefNode {
    bool add_implicit_return;
    bool skip;
    LLVMValueRef *params;
};

struct CodeGenNode {
    union {
        TypeNode type_node; // for NodeTypeType
        FnDefNode fn_def_node; // for NodeTypeFnDef
    } data;
};

static inline Buf *hack_get_fn_call_name(CodeGen *g, AstNode *node) {
    // Assume that the expression evaluates to a simple name and return the buf
    // TODO after type checking works we should be able to remove this hack
    assert(node->type == NodeTypeSymbol);
    return &node->data.symbol;
}

#endif
