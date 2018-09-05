#include "fn_abi.hpp"
#include "util.hpp"
#include "analyze.hpp"
#include "codegen.hpp"
#include "zig_llvm.h"

static LLVMValueRef build_alloca_in_entry_block(IrExecutable *executable, LLVMTypeRef type_ref, const char *name, uint32_t align_bytes) {
    auto builder = LLVMCreateBuilder();
    LLVMPositionBuilderAtEnd(builder, executable->basic_block_list.at(0)->llvm_block);
    auto alloca_instr = LLVMBuildAlloca(builder, type_ref, name);
    LLVMSetAlignment(alloca_instr, align_bytes);
    LLVMDisposeBuilder(builder);
    return alloca_instr;
}

static VariableTableEntry *get_var_by_src_arg_index(FnTableEntry *fn_entry, size_t src_arg_index) {
    for (size_t i = 0; i < fn_entry->variable_list.length; i++) {
        auto var = fn_entry->variable_list.at(i);
        if (var->src_arg_index == src_arg_index) {
            return var;
        }
    }
    zig_unreachable();
}

FnAbi *FnAbi::init(void) {
    auto fn_abi = allocate<FnAbi>(1);

    fn_abi->fn_attrs = {nullptr, 0, 0};
    fn_abi->args_attrs = {nullptr, 0, 0};
    fn_abi->return_attrs = {nullptr, 0, 0};
    fn_abi->hooks = {nullptr, 0, 0};

    return fn_abi;
}

// FnAbiHookArgByValue
void fn_abi_hook_arg_by_value_handle_pre_body1(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    auto h = (FnAbiHookArgByValue*)abi_hook;
    auto var = get_var_by_src_arg_index(body_data->fn_entry, h->src_arg_index);
    var->value_ref = LLVMBuildAlloca(g->builder, h->arg_type->type_ref, buf_ptr(&var->name));
    LLVMSetAlignment(var->value_ref, var->align_bytes);
}

void fn_abi_hook_arg_by_value_handle_pre_body2(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    auto h = (FnAbiHookArgByValue*)abi_hook;
    auto var = get_var_by_src_arg_index(body_data->fn_entry, h->src_arg_index);
    auto param = LLVMGetParam(body_data->fn_entry->llvm_value, h->llvm_arg_index);
    auto store_instr = LLVMBuildStore(g->builder, param, var->value_ref);
    LLVMSetAlignment(store_instr, var->align_bytes);
}

void fn_abi_hook_arg_by_value_handle_pre_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    auto h = (FnAbiHookArgByValue*)abi_hook;
    LLVMValueRef arg_value = call_data->args[h->src_arg_index]->llvm_value;
    LLVMValueRef arg_pass_value;
    if (handle_is_ptr(h->arg_type)) {
        arg_pass_value = LLVMBuildLoad(g->builder, arg_value, "");
        LLVMSetAlignment(arg_pass_value, LLVMABIAlignmentOfType(g->target_data_ref, h->arg_type->type_ref));
    } else {
        arg_pass_value = arg_value;
    }
    call_data->llvm_args[h->llvm_arg_index] = arg_pass_value;
}

void fn_abi_hook_arg_by_value_handle_post_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    // nothing to do...
}

FnAbiHookArgByValue *FnAbiHookArgByValue::init(void) {
    auto abi_hook = allocate<FnAbiHookArgByValue>(1);
    abi_hook->base.handle_pre_body1_fn = fn_abi_hook_arg_by_value_handle_pre_body1;
    abi_hook->base.handle_pre_body2_fn = fn_abi_hook_arg_by_value_handle_pre_body2;
    abi_hook->base.handle_pre_call_fn = fn_abi_hook_arg_by_value_handle_pre_call;
    abi_hook->base.handle_post_call_fn = fn_abi_hook_arg_by_value_handle_post_call;
    return abi_hook;
}

// FnAbiHookArgByRef
void fn_abi_hook_arg_by_ref_handle_pre_body1(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    auto h = (FnAbiHookArgByRef*)abi_hook;
    auto var = get_var_by_src_arg_index(body_data->fn_entry, h->src_arg_index);
    if (h->callee_makes_copy) {
        var->value_ref = LLVMBuildAlloca(g->builder, h->arg_type->type_ref, buf_ptr(&var->name));
        LLVMSetAlignment(var->value_ref, var->align_bytes);
    } else {
        var->value_ref = LLVMGetParam(body_data->fn_entry->llvm_value, h->llvm_arg_index);
    }
}

void fn_abi_hook_arg_by_ref_handle_pre_body2(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    auto h = (FnAbiHookArgByRef*)abi_hook;
    if (h->callee_makes_copy) {
        auto var = get_var_by_src_arg_index(body_data->fn_entry, h->src_arg_index);
        auto param = LLVMGetParam(body_data->fn_entry->llvm_value, h->llvm_arg_index);
        if (handle_is_ptr(h->arg_type)) {
            uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, h->arg_type->type_ref);
            uint32_t align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, h->arg_type->type_ref);
            LLVMValueRef memcpy_params[] = {
                var->value_ref, // dest pointer
                param, // source pointer
                LLVMConstInt(g->builtin_types.entry_usize->type_ref, size_bytes, false), // size bytes
                LLVMConstInt(LLVMInt32Type(), align_bytes, false), // align bytes
                LLVMConstNull(LLVMInt1Type()), // is volatile
            };
            LLVMBuildCall(g->builder, get_memcpy_fn_val(g), memcpy_params, 5, "");
        } else {
            auto load_instr = LLVMBuildLoad(g->builder, param, "");
            LLVMSetAlignment(load_instr, var->align_bytes);
            auto store_instr = LLVMBuildStore(g->builder, load_instr, var->value_ref);
            LLVMSetAlignment(store_instr, var->align_bytes);
        }
    }
}

void fn_abi_hook_arg_by_ref_handle_pre_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    auto h = (FnAbiHookArgByRef*)abi_hook;
    LLVMValueRef arg_value = call_data->args[h->src_arg_index]->llvm_value;
    LLVMValueRef arg_pass_value;
    if (handle_is_ptr(h->arg_type)) {
        if (h->caller_makes_copy) {
            uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, h->arg_type->type_ref);
            uint32_t align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, h->arg_type->type_ref);
            auto tmp_alloca = build_alloca_in_entry_block(call_data->executable, h->arg_type->type_ref, "", align_bytes);
            LLVMSetAlignment(tmp_alloca, align_bytes);
            LLVMValueRef memcpy_params[] = {
                tmp_alloca, // dest pointer
                arg_value, // source pointer
                LLVMConstInt(g->builtin_types.entry_usize->type_ref, size_bytes, false), // size bytes
                LLVMConstInt(LLVMInt32Type(), align_bytes, false), // align bytes
                LLVMConstNull(LLVMInt1Type()), // is volatile
            };
            LLVMBuildCall(g->builder, get_memcpy_fn_val(g), memcpy_params, 5, "");
            arg_pass_value = tmp_alloca;
        } else {
            arg_pass_value = arg_value;
        }
    } else {
        auto align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, h->arg_type->type_ref);
        auto tmp_alloca = build_alloca_in_entry_block(call_data->executable, h->arg_type->type_ref, "", align_bytes);
        auto store_instr = LLVMBuildStore(g->builder, arg_value, tmp_alloca);
        LLVMSetAlignment(store_instr, align_bytes);
        arg_pass_value = tmp_alloca;
    }
    call_data->llvm_args[h->llvm_arg_index] = arg_pass_value;
}

void fn_abi_hook_arg_by_ref_handle_post_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    // nothing to do...
}

FnAbiHookArgByRef *FnAbiHookArgByRef::init(void) {
    auto abi_hook = allocate<FnAbiHookArgByRef>(1);
    abi_hook->base.handle_pre_body1_fn = fn_abi_hook_arg_by_ref_handle_pre_body1;
    abi_hook->base.handle_pre_body2_fn = fn_abi_hook_arg_by_ref_handle_pre_body2;
    abi_hook->base.handle_pre_call_fn = fn_abi_hook_arg_by_ref_handle_pre_call;
    abi_hook->base.handle_post_call_fn = fn_abi_hook_arg_by_ref_handle_post_call;
    return abi_hook;
}

// FnAbiHookRetByValue
void fn_abi_hook_ret_by_value_handle_pre_body1(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    // nothing to do
}

void fn_abi_hook_ret_by_value_handle_pre_body2(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    // nothing to do
}

void fn_abi_hook_ret_by_value_handle_pre_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    // nothing to do
}

void fn_abi_hook_ret_by_value_handle_post_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    auto h = (FnAbiHookRetByValue*)abi_hook;
    if (handle_is_ptr(h->ret_type)) {
        uint32_t align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, h->ret_type->type_ref);
        auto value_ptr = build_alloca_in_entry_block(call_data->executable, h->ret_type->type_ref, "", align_bytes);
        auto store_instr = LLVMBuildStore(g->builder, call_data->call_instr, value_ptr);
        LLVMSetAlignment(store_instr, align_bytes);
        call_data->returned_value = value_ptr;
    } else {
        call_data->returned_value = call_data->call_instr;
    }
}

FnAbiHookRetByValue *FnAbiHookRetByValue::init(void) {
    auto abi_hook = allocate<FnAbiHookRetByValue>(1);
    abi_hook->base.handle_pre_body1_fn = fn_abi_hook_ret_by_value_handle_pre_body1;
    abi_hook->base.handle_pre_body2_fn = fn_abi_hook_ret_by_value_handle_pre_body2;
    abi_hook->base.handle_pre_call_fn = fn_abi_hook_ret_by_value_handle_pre_call;
    abi_hook->base.handle_post_call_fn = fn_abi_hook_ret_by_value_handle_post_call;

    return abi_hook;
}

// FnAbiHookRetByPtr
void fn_abi_hook_ret_by_ptr_handle_pre_body1(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    // nothing to do
}

void fn_abi_hook_ret_by_ptr_handle_pre_body2(FnAbiHook *abi_hook, CodeGen *g, FnAbiBodyData *body_data) {
    // nothing to do
}

void fn_abi_hook_ret_by_ptr_handle_pre_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    auto h = (FnAbiHookRetByPtr*)abi_hook;
    uint32_t align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, h->ret_type->type_ref);
    auto ret_ptr = build_alloca_in_entry_block(call_data->executable, h->ret_type->type_ref, "", align_bytes);
    call_data->llvm_args[h->llvm_arg_index] = ret_ptr;
}

void fn_abi_hook_ret_by_ptr_handle_post_call(FnAbiHook *abi_hook, CodeGen *g, FnAbiCallData *call_data) {
    auto h = (FnAbiHookRetByPtr*)abi_hook;
    auto ret_ptr = call_data->llvm_args[h->llvm_arg_index];
    if (handle_is_ptr(h->ret_type)) {
        call_data->returned_value = ret_ptr;
    } else {
        uint32_t align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, h->ret_type->type_ref);
        auto load_instr = LLVMBuildLoad(g->builder, ret_ptr, "");
        LLVMSetAlignment(load_instr, align_bytes);
        call_data->returned_value = load_instr;
    }
}

FnAbiHookRetByPtr *FnAbiHookRetByPtr::init(void) {
    auto abi_hook = allocate<FnAbiHookRetByPtr>(1);
    abi_hook->base.handle_pre_body1_fn = fn_abi_hook_ret_by_ptr_handle_pre_body1;
    abi_hook->base.handle_pre_body2_fn = fn_abi_hook_ret_by_ptr_handle_pre_body2;
    abi_hook->base.handle_pre_call_fn = fn_abi_hook_ret_by_ptr_handle_pre_call;
    abi_hook->base.handle_post_call_fn = fn_abi_hook_ret_by_ptr_handle_post_call;

    return abi_hook;
}

// FnAbiReturnEmitterVoid
void fn_abi_return_emitter_void_emit(FnAbiReturnEmitter *emitter, CodeGen *g, FnAbiReturnData *ret_data) {
    LLVMBuildRetVoid(g->builder);
}

FnAbiReturnEmitterVoid *FnAbiReturnEmitterVoid::init(void) {
    auto return_emitter = allocate<FnAbiReturnEmitterVoid>(1);
    return_emitter->base.emit_fn = fn_abi_return_emitter_void_emit;
    return return_emitter;
}


// FnAbiReturnEmitterByValue
void fn_abi_return_emitter_by_value_emit(FnAbiReturnEmitter *emitter, CodeGen *g, FnAbiReturnData *ret_data) {
    auto e = (FnAbiReturnEmitterByValue*)emitter;
    LLVMValueRef ret_arg;
    if (handle_is_ptr(e->ret_type)) {
        uint32_t align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, e->ret_type->type_ref);
        auto load_instr = LLVMBuildLoad(g->builder, ret_data->ret_value, "");
        LLVMSetAlignment(load_instr, align_bytes);
    } else {
        ret_arg = ret_data->ret_value;
    }
    LLVMBuildRet(g->builder, ret_arg);
}

FnAbiReturnEmitterByValue *FnAbiReturnEmitterByValue::init(void) {
    auto return_emitter = allocate<FnAbiReturnEmitterByValue>(1);
    return_emitter->base.emit_fn = fn_abi_return_emitter_by_value_emit;
    return return_emitter;
}

// FnAbiReturnEmitterByRef
void fn_abi_return_emitter_by_ref_emit(FnAbiReturnEmitter *emitter, CodeGen *g, FnAbiReturnData *ret_data) {
    auto e = (FnAbiReturnEmitterByRef*)emitter;
    auto ret_param = LLVMGetParam(ret_data->executable->fn_entry->llvm_value, e->llvm_arg_index);
    uint32_t align_bytes = LLVMABIAlignmentOfType(g->target_data_ref, e->ret_type->type_ref);
    if (handle_is_ptr(e->ret_type)) {
        uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, e->ret_type->type_ref);
        LLVMValueRef memcpy_params[] = {
            ret_param, // dest pointer
            ret_data->ret_value, // source pointer
            LLVMConstInt(g->builtin_types.entry_usize->type_ref, size_bytes, false), // size bytes
            LLVMConstInt(LLVMInt32Type(), align_bytes, false), // align bytes
            LLVMConstNull(LLVMInt1Type()), // is volatile
        };
        LLVMBuildCall(g->builder, get_memcpy_fn_val(g), memcpy_params, 5, "");
    } else {
        auto store_instr = LLVMBuildStore(g->builder, ret_data->ret_value, ret_param);
        LLVMSetAlignment(store_instr, align_bytes);
    }
    LLVMBuildRetVoid(g->builder);
}

FnAbiReturnEmitterByRef *FnAbiReturnEmitterByRef::init(void) {
    auto return_emitter = allocate<FnAbiReturnEmitterByRef>(1);
    return_emitter->base.emit_fn = fn_abi_return_emitter_by_ref_emit;
    return return_emitter;
}

void fn_abi_visit_fn_type(CodeGen *g, FnTypeId *fn_type_id) {
    fn_abi_basic_visit_fn_type(g, fn_type_id);
}

// "basic" ABI
void fn_abi_basic_visit_fn_type(CodeGen *g, FnTypeId *fn_type_id) {
    auto abi_data = FnAbi::init();
    abi_data->llvm_call_conv = LLVMFastCallConv;

    ZigList<LLVMTypeRef> llvm_fn_params = {nullptr, 0, 0};
    if (type_has_bits(fn_type_id->return_type)) {
        if (handle_is_ptr(fn_type_id->return_type)) {
            llvm_fn_params.append(LLVMPointerType(fn_type_id->return_type->type_ref, 0));

            auto abi_hook = FnAbiHookRetByPtr::init();
            abi_hook->llvm_arg_index = llvm_fn_params.length - 1;
            abi_hook->ret_type = fn_type_id->return_type;
            abi_data->hooks.append(&abi_hook->base);

            auto return_emitter = FnAbiReturnEmitterByRef::init();
            return_emitter->llvm_arg_index = llvm_fn_params.length - 1;
            return_emitter->ret_type = fn_type_id->return_type;
            abi_data->return_emitter = &return_emitter->base;
        } else {
            llvm_fn_params.append(fn_type_id->return_type->type_ref);

            auto abi_hook = FnAbiHookRetByValue::init();
            abi_hook->ret_type = fn_type_id->return_type;
            abi_data->hooks.append(&abi_hook->base);

            auto return_emitter = FnAbiReturnEmitterByValue::init();
            return_emitter->ret_type = fn_type_id->return_type;
            abi_data->return_emitter = &return_emitter->base;
        }
    } else {
        auto return_emitter = FnAbiReturnEmitterVoid::init();
        abi_data->return_emitter = &return_emitter->base;
    }

    size_t param_count = fn_type_id->param_count;
    auto param_info = fn_type_id->param_info;
    for (size_t i = 0; i < param_count; i++) {
        if (!type_has_bits(fn_type_id->return_type)) {
            continue;
        }
        if (handle_is_ptr(fn_type_id->return_type)) {
            llvm_fn_params.append(LLVMPointerType(param_info[i].type->type_ref, 0));

            auto abi_hook = FnAbiHookArgByRef::init();
            abi_hook->src_arg_index = i;
            abi_hook->llvm_arg_index = llvm_fn_params.length - 1;
            abi_hook->arg_type = param_info[i].type;
            abi_hook->caller_makes_copy = true;
            abi_hook->callee_makes_copy = false;
            abi_data->hooks.append(&abi_hook->base);
        } else {
            llvm_fn_params.append(param_info[i].type->type_ref);

            auto abi_hook = FnAbiHookArgByValue::init();
            abi_hook->src_arg_index = i;
            abi_hook->llvm_arg_index = llvm_fn_params.length - 1;
            abi_hook->arg_type = param_info[i].type;
            abi_data->hooks.append(&abi_hook->base);
        }
    }

    abi_data->llvm_call_conv = LLVMFastCallConv;

    fn_type_id->abi_data = abi_data;
}
