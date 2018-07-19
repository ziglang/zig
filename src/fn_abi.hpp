#ifndef ZIG_FN_ABI_HPP
#define ZIG_FN_ABI_HPP

#include "all_types.hpp"
#include "list.hpp"
#include "zig_llvm.h"

struct FnAbiHook;
struct FnAbiReturnEmitter;

enum AttrValueKind {
    AttrValueKindNone,
    AttrValueKindStr,
    AttrValueKindInt,
};

struct FnAbiAttr {
    const char *name;
    union {
        const char *s;
        uint64_t i;
    } value;
};

struct FnAbi {
    LLVMValueRef fn_type;
    unsigned int llvm_call_conv;
    ZigList<FnAbiAttr> fn_attrs;
    ZigList<ZigList<FnAbiAttr>> args_attrs;
    ZigList<FnAbiAttr> return_attrs;

    ZigList<FnAbiHook*> hooks;
    FnAbiReturnEmitter *return_emitter;

    static FnAbi *init(void);
};

struct FnAbiBodyData {
    FnTableEntry *fn_entry;
};

struct FnAbiCallData {
    IrInstruction **args;
    IrExecutable *executable;
    LLVMValueRef *llvm_args;
    LLVMValueRef call_instr;
    LLVMValueRef returned_value;
};

struct FnAbiReturnData {
    IrExecutable *executable;
    LLVMValueRef ret_value;
};

// FnAbiHook
typedef void (*FnAbiHookHandlePreBody1Fn)(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data);
typedef void (*FnAbiHookHandlePreBody2Fn)(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data);
typedef void (*FnAbiHookHandlePreCallFn)(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data);
typedef void (*FnAbiHookHandlePostCallFn)(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data);

struct FnAbiHook {
    FnAbiHookHandlePreBody1Fn handle_pre_body1_fn;
    FnAbiHookHandlePreBody2Fn handle_pre_body2_fn;
    FnAbiHookHandlePreCallFn handle_pre_call_fn;
    FnAbiHookHandlePostCallFn handle_post_call_fn;
};

struct FnAbiHookArgByValue {
    FnAbiHook base;

    size_t src_arg_index;
    size_t llvm_arg_index;
    TypeTableEntry *arg_type;

    static FnAbiHookArgByValue *init(void);
};

struct FnAbiHookArgByRef {
    FnAbiHook base;

    size_t src_arg_index;
    size_t llvm_arg_index;
    TypeTableEntry *arg_type;
    bool caller_makes_copy;
    bool callee_makes_copy;

    static FnAbiHookArgByRef *init(void);
};

struct FnAbiHookRetByValue {
    FnAbiHook base;

    TypeTableEntry *ret_type;

    static FnAbiHookRetByValue *init(void);
};

struct FnAbiHookRetByPtr {
    FnAbiHook base;

    size_t llvm_arg_index;
    TypeTableEntry *ret_type;

    static FnAbiHookRetByPtr *init(void);
};

// FnAbiReturnEmitter
typedef void (*FnAbiReturnEmitterEmitFn)(FnAbiReturnEmitter *emitter, CodeGen *g, FnAbiReturnData *ret_data);

struct FnAbiReturnEmitter {
    FnAbiReturnEmitterEmitFn emit_fn;
};

struct FnAbiReturnEmitterVoid {
    FnAbiReturnEmitter base;

    static FnAbiReturnEmitterVoid *init(void);
};

struct FnAbiReturnEmitterByValue {
    FnAbiReturnEmitter base;

    TypeTableEntry *ret_type;

    static FnAbiReturnEmitterByValue *init(void);
};

struct FnAbiReturnEmitterByRef {
    FnAbiReturnEmitter base;

    size_t llvm_arg_index;
    TypeTableEntry *ret_type;

    static FnAbiReturnEmitterByRef *init(void);
};

// ABIs
void fn_abi_visit_fn_type(CodeGen *g, FnTypeId *fn_type_id);

void fn_abi_basic_visit_fn_type(CodeGen *g, FnTypeId *fn_type_id);

#endif
