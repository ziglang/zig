/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ANALYZE_HPP
#define ZIG_ANALYZE_HPP

#include "codegen.hpp"
#include "hash_map.hpp"
#include "zig_llvm.hpp"
#include "errmsg.hpp"

struct FnTableEntry;
struct BlockContext;
struct TypeTableEntry;
struct VariableTableEntry;
struct CastNode;
struct StructValExprNode;

struct TypeTableEntryPointer {
    TypeTableEntry *child_type;
    bool is_const;
};

struct TypeTableEntryInt {
    bool is_signed;
};

struct TypeTableEntryArray {
    TypeTableEntry *child_type;
    uint64_t len;
};

struct TypeStructField {
    Buf *name;
    TypeTableEntry *type_entry;
};

struct TypeTableEntryStruct {
    AstNode *decl_node;
    bool is_packed;
    int field_count;
    TypeStructField *fields;
    uint64_t size_bytes;
    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
};

struct TypeTableEntryNumLit {
    NumLit kind;
};

struct TypeTableEntryMaybe {
    TypeTableEntry *child_type;
};

enum TypeTableEntryId {
    TypeTableEntryIdInvalid,
    TypeTableEntryIdVoid,
    TypeTableEntryIdBool,
    TypeTableEntryIdUnreachable,
    TypeTableEntryIdInt,
    TypeTableEntryIdFloat,
    TypeTableEntryIdPointer,
    TypeTableEntryIdArray,
    TypeTableEntryIdStruct,
    TypeTableEntryIdNumberLiteral,
    TypeTableEntryIdMaybe,
};

struct TypeTableEntry {
    TypeTableEntryId id;

    LLVMTypeRef type_ref;
    LLVMZigDIType *di_type;
    uint64_t size_in_bits;
    uint64_t align_in_bits;

    Buf name;

    union {
        TypeTableEntryPointer pointer;
        TypeTableEntryInt integral;
        TypeTableEntryArray array;
        TypeTableEntryStruct structure;
        TypeTableEntryNumLit num_lit;
        TypeTableEntryMaybe maybe;
    } data;

    // use these fields to make sure we don't duplicate type table entries for the same type
    TypeTableEntry *pointer_const_parent;
    TypeTableEntry *pointer_mut_parent;
    HashMap<uint64_t, TypeTableEntry *, uint64_hash, uint64_eq> arrays_by_size;
    TypeTableEntry *maybe_parent;

};

struct ImportTableEntry {
    AstNode *root;
    Buf *path; // relative to root_source_dir
    LLVMZigDIFile *di_file;
    Buf *source_code;
    ZigList<int> *line_offsets;
    BlockContext *block_context;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> type_table;
};

struct LabelTableEntry {
    AstNode *label_node;
    LLVMBasicBlockRef basic_block;
    bool used;
    bool entered_from_fallthrough;
};

enum FnAttrId {
    FnAttrIdNaked,
    FnAttrIdAlwaysInline,
};

struct FnTableEntry {
    LLVMValueRef fn_value;
    AstNode *proto_node;
    AstNode *fn_def_node;
    bool is_extern;
    bool internal_linkage;
    unsigned calling_convention;
    ImportTableEntry *import_entry;
    ZigList<FnAttrId> fn_attr_list;
    // Required to be a pre-order traversal of the AST. (parents must come before children)
    ZigList<BlockContext *> all_block_contexts;
    TypeTableEntry *member_of_struct;
    Buf symbol_name;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, LabelTableEntry *, buf_hash, buf_eql_buf> label_table;
};

struct CodeGen {
    LLVMModuleRef module;
    ZigList<ErrorMsg*> errors;
    LLVMBuilderRef builder;
    LLVMZigDIBuilder *dbuilder;
    LLVMZigDICompileUnit *compile_unit;

    ZigList<Buf *> lib_search_paths;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, LLVMValueRef, buf_hash, buf_eql_buf> str_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> link_table;
    HashMap<Buf *, ImportTableEntry *, buf_hash, buf_eql_buf> import_table;

    struct {
        TypeTableEntry *entry_bool;
        TypeTableEntry *entry_u8;
        TypeTableEntry *entry_u16;
        TypeTableEntry *entry_u32;
        TypeTableEntry *entry_u64;
        TypeTableEntry *entry_i8;
        TypeTableEntry *entry_i16;
        TypeTableEntry *entry_i32;
        TypeTableEntry *entry_i64;
        TypeTableEntry *entry_isize;
        TypeTableEntry *entry_usize;
        TypeTableEntry *entry_f32;
        TypeTableEntry *entry_f64;
        TypeTableEntry *entry_c_string_literal;
        TypeTableEntry *entry_string;
        TypeTableEntry *entry_void;
        TypeTableEntry *entry_unreachable;
        TypeTableEntry *entry_invalid;
    } builtin_types;

    TypeTableEntry *num_lit_types[NumLitCount];

    LLVMTargetDataRef target_data_ref;
    unsigned pointer_size_bytes;
    bool is_static;
    bool strip_debug_symbols;
    bool have_exported_main;
    bool link_libc;
    Buf *libc_path;
    CodeGenBuildType build_type;
    LLVMTargetMachineRef target_machine;
    LLVMZigDIFile *dummy_di_file;
    bool is_native_target;
    Buf *root_source_dir;
    Buf *root_out_name;

    // The function definitions this module includes. There must be a corresponding
    // fn_protos entry.
    ZigList<FnTableEntry *> fn_defs;
    // The function prototypes this module includes. In the case of external declarations,
    // there will not be a corresponding fn_defs entry.
    ZigList<FnTableEntry *> fn_protos;
    ZigList<VariableTableEntry *> global_vars;

    OutType out_type;
    FnTableEntry *cur_fn;
    LLVMBasicBlockRef cur_basic_block;
    BlockContext *cur_block_context;
    ZigList<LLVMBasicBlockRef> break_block_stack;
    ZigList<LLVMBasicBlockRef> continue_block_stack;
    bool c_stdint_used;
    AstNode *root_export_decl;
    int version_major;
    int version_minor;
    int version_patch;
    bool verbose;
    ErrColor err_color;
    ImportTableEntry *root_import;
    ImportTableEntry *bootstrap_import;
    LLVMValueRef memcpy_fn_val;
    bool error_during_imports;
};

struct VariableTableEntry {
    Buf name;
    TypeTableEntry *type;
    LLVMValueRef value_ref;
    bool is_const;
    bool is_ptr; // if true, value_ref is a pointer
    AstNode *decl_node;
    LLVMZigDILocalVariable *di_loc_var;
    int arg_index;
};

struct BlockContext {
    AstNode *node; // either NodeTypeFnDef or NodeTypeBlock or NodeTypeRoot
    FnTableEntry *fn_entry; // null at the module scope
    BlockContext *parent; // null when this is the root
    HashMap<Buf *, VariableTableEntry *, buf_hash, buf_eql_buf> variable_table;
    ZigList<CastNode *> cast_expr_alloca_list;
    ZigList<StructValExprNode *> struct_val_expr_alloca_list;
    bool break_allowed;
    bool next_child_break_allowed;
    LLVMZigDIScope *di_scope;
};

struct TypeNode {
    TypeTableEntry *entry;
};

struct FnProtoNode {
    FnTableEntry *fn_table_entry;
};

struct FnDefNode {
    TypeTableEntry *implicit_return_type;
    BlockContext *block_context;
    bool skip;
};


struct AssignNode {
    VariableTableEntry *var_entry;
};

struct BlockNode {
    BlockContext *block_context;
};

struct StructDeclNode {
    TypeTableEntry *type_entry;
};

struct FieldAccessNode {
    int field_index;
    TypeStructField *type_struct_field;
};

enum CastOp {
    CastOpNothing,
    CastOpPtrToInt,
    CastOpIntWidenOrShorten,
    CastOpArrayToString,
    CastOpMaybeWrap,
    CastOpPointerReinterpret,
};

struct CastNode {
    CastOp op;
    // if op is CastOpArrayToString, this will be a pointer to
    // the string struct on the stack
    LLVMValueRef ptr;
    TypeTableEntry *after_type;
    AstNode *source_node;
};

struct ExprNode {
    TypeTableEntry *type_entry;
    // the context in which this expression is evaluated.
    // for blocks, this points to the containing scope, not the block's own scope for its children.
    BlockContext *block_context;

    // may be null for no cast
    CastNode implicit_cast; // happens first
    CastNode implicit_maybe_cast; // happens second
};

struct NumberLiteralNode {
    TypeTableEntry *resolved_type;
};

struct VarDeclNode {
    TypeTableEntry *type;
};

struct StructValFieldNode {
    int index;
};

struct StructValExprNode {
    TypeTableEntry *type_entry;
    LLVMValueRef ptr;
    AstNode *source_node;
};

struct IfVarNode {
    BlockContext *block_context;
};

struct ParamDeclNode {
    VariableTableEntry *variable;
};

struct ImportNode {
    ImportTableEntry *import;
};

struct CodeGenNode {
    union {
        TypeNode type_node; // for NodeTypeType
        FnDefNode fn_def_node; // for NodeTypeFnDef
        FnProtoNode fn_proto_node; // for NodeTypeFnProto
        LabelTableEntry *label_entry; // for NodeTypeGoto and NodeTypeLabel
        AssignNode assign_node; // for NodeTypeBinOpExpr where op is BinOpTypeAssign
        BlockNode block_node; // for NodeTypeBlock
        StructDeclNode struct_decl_node; // for NodeTypeStructDecl
        FieldAccessNode field_access_node; // for NodeTypeFieldAccessExpr
        CastNode cast_node; // for NodeTypeCastExpr
        NumberLiteralNode num_lit_node; // for NodeTypeNumberLiteral
        VarDeclNode var_decl_node; // for NodeTypeVariableDeclaration
        StructValFieldNode struct_val_field_node; // for NodeTypeStructValueField
        StructValExprNode struct_val_expr_node; // for NodeTypeStructValueExpr
        IfVarNode if_var_node; // for NodeTypeStructValueExpr
        ParamDeclNode param_decl_node; // for NodeTypeParamDecl
        ImportNode import_node; // for NodeTypeUse
    } data;
    ExprNode expr_node; // for all the expression nodes
};

static inline Buf *hack_get_fn_call_name(CodeGen *g, AstNode *node) {
    // Assume that the expression evaluates to a simple name and return the buf
    // TODO after type checking works we should be able to remove this hack
    assert(node->type == NodeTypeSymbol);
    return &node->data.symbol;
}

void semantic_analyze(CodeGen *g);
void add_node_error(CodeGen *g, AstNode *node, Buf *msg);
void alloc_codegen_node(AstNode *node);
TypeTableEntry *new_type_table_entry(TypeTableEntryId id);
TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const);
VariableTableEntry *find_variable(BlockContext *context, Buf *name);
BlockContext *new_block_context(AstNode *node, BlockContext *parent);

#endif
