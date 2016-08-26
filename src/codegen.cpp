/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "codegen.hpp"
#include "hash_map.hpp"
#include "zig_llvm.hpp"
#include "os.hpp"
#include "config.h"
#include "error.hpp"
#include "analyze.hpp"
#include "errmsg.hpp"
#include "parseh.hpp"
#include "ast_render.hpp"
#include "target.hpp"
#include "link.hpp"

#include <stdio.h>
#include <errno.h>


static void init_darwin_native(CodeGen *g) {
    char *osx_target = getenv("MACOSX_DEPLOYMENT_TARGET");
    char *ios_target = getenv("IPHONEOS_DEPLOYMENT_TARGET");

    // Allow conflicts among OSX and iOS, but choose the default platform.
    if (osx_target && ios_target) {
        if (g->zig_target.arch.arch == ZigLLVM_arm ||
            g->zig_target.arch.arch == ZigLLVM_aarch64 ||
            g->zig_target.arch.arch == ZigLLVM_thumb)
        {
            osx_target = nullptr;
        } else {
            ios_target = nullptr;
        }
    }

    if (osx_target) {
        g->mmacosx_version_min = buf_create_from_str(osx_target);
    } else if (ios_target) {
        g->mios_version_min = buf_create_from_str(ios_target);
    } else {
        zig_panic("unable to determine -mmacosx-version-min or -mios-version-min");
    }
}

static PackageTableEntry *new_package(const char *root_src_dir, const char *root_src_path) {
    PackageTableEntry *entry = allocate<PackageTableEntry>(1);
    entry->package_table.init(4);
    buf_init_from_str(&entry->root_src_dir, root_src_dir);
    buf_init_from_str(&entry->root_src_path, root_src_path);
    return entry;
}

CodeGen *codegen_create(Buf *root_source_dir, const ZigTarget *target) {
    CodeGen *g = allocate<CodeGen>(1);
    g->import_table.init(32);
    g->builtin_fn_table.init(32);
    g->primitive_type_table.init(32);
    g->fn_type_table.init(32);
    g->error_table.init(16);
    g->generic_table.init(16);
    g->is_release_build = false;
    g->is_test_build = false;

    // the error.Ok value
    g->error_decls.append(nullptr);

    g->root_package = new_package(buf_ptr(root_source_dir), "");
    g->std_package = new_package(ZIG_STD_DIR, "index.zig");
    g->root_package->package_table.put(buf_create_from_str("std"), g->std_package);
    g->zig_std_dir = buf_create_from_str(ZIG_STD_DIR);


    if (target) {
        // cross compiling, so we can't rely on all the configured stuff since
        // that's for native compilation
        g->zig_target = *target;
        resolve_target_object_format(&g->zig_target);

        g->dynamic_linker = buf_create_from_str("");
        g->libc_lib_dir = buf_create_from_str("");
        g->libc_static_lib_dir = buf_create_from_str("");
        g->libc_include_dir = buf_create_from_str("");
        g->linker_path = buf_create_from_str("");
        g->ar_path = buf_create_from_str("");
        g->darwin_linker_version = buf_create_from_str("");
    } else {
        // native compilation, we can rely on the configuration stuff
        g->is_native_target = true;
        get_native_target(&g->zig_target);

        g->dynamic_linker = buf_create_from_str(ZIG_DYNAMIC_LINKER);
        g->libc_lib_dir = buf_create_from_str(ZIG_LIBC_LIB_DIR);
        g->libc_static_lib_dir = buf_create_from_str(ZIG_LIBC_STATIC_LIB_DIR);
        g->libc_include_dir = buf_create_from_str(ZIG_LIBC_INCLUDE_DIR);
        g->linker_path = buf_create_from_str(ZIG_LD_PATH);
        g->ar_path = buf_create_from_str(ZIG_AR_PATH);
        g->darwin_linker_version = buf_create_from_str(ZIG_HOST_LINK_VERSION);

        if (g->zig_target.os == ZigLLVM_Darwin ||
            g->zig_target.os == ZigLLVM_MacOSX ||
            g->zig_target.os == ZigLLVM_IOS)
        {
            init_darwin_native(g);
        }

    }

    return g;
}

void codegen_set_clang_argv(CodeGen *g, const char **args, int len) {
    g->clang_argv = args;
    g->clang_argv_len = len;
}

void codegen_set_is_release(CodeGen *g, bool is_release_build) {
    g->is_release_build = is_release_build;
}

void codegen_set_is_test(CodeGen *g, bool is_test_build) {
    g->is_test_build = is_test_build;
}

void codegen_set_is_static(CodeGen *g, bool is_static) {
    g->is_static = is_static;
}

void codegen_set_verbose(CodeGen *g, bool verbose) {
    g->verbose = verbose;
}

void codegen_set_check_unused(CodeGen *g, bool check_unused) {
    g->check_unused = check_unused;
}

void codegen_set_errmsg_color(CodeGen *g, ErrColor err_color) {
    g->err_color = err_color;
}

void codegen_set_strip(CodeGen *g, bool strip) {
    g->strip_debug_symbols = strip;
}

void codegen_set_out_type(CodeGen *g, OutType out_type) {
    g->out_type = out_type;
}

void codegen_set_out_name(CodeGen *g, Buf *out_name) {
    g->root_out_name = out_name;
}

void codegen_set_libc_lib_dir(CodeGen *g, Buf *libc_lib_dir) {
    g->libc_lib_dir = libc_lib_dir;
}

void codegen_set_libc_static_lib_dir(CodeGen *g, Buf *libc_static_lib_dir) {
    g->libc_static_lib_dir = libc_static_lib_dir;
}

void codegen_set_libc_include_dir(CodeGen *g, Buf *libc_include_dir) {
    g->libc_include_dir = libc_include_dir;
}

void codegen_set_zig_std_dir(CodeGen *g, Buf *zig_std_dir) {
    g->zig_std_dir = zig_std_dir;
    g->std_package->root_src_dir = *zig_std_dir;
}

void codegen_set_dynamic_linker(CodeGen *g, Buf *dynamic_linker) {
    g->dynamic_linker = dynamic_linker;
}

void codegen_set_linker_path(CodeGen *g, Buf *linker_path) {
    g->linker_path = linker_path;
}

void codegen_set_ar_path(CodeGen *g, Buf *ar_path) {
    g->ar_path = ar_path;
}

void codegen_add_lib_dir(CodeGen *g, const char *dir) {
    g->lib_dirs.append(dir);
}

void codegen_add_link_lib(CodeGen *g, const char *lib) {
    if (strcmp(lib, "c") == 0) {
        g->link_libc = true;
    } else {
        g->link_libs.append(buf_create_from_str(lib));
    }
}

void codegen_set_windows_subsystem(CodeGen *g, bool mwindows, bool mconsole) {
    g->windows_subsystem_windows = mwindows;
    g->windows_subsystem_console = mconsole;
}

void codegen_set_windows_unicode(CodeGen *g, bool municode) {
    g->windows_linker_unicode = municode;
}

void codegen_set_mlinker_version(CodeGen *g, Buf *darwin_linker_version) {
    g->darwin_linker_version = darwin_linker_version;
}

void codegen_set_mmacosx_version_min(CodeGen *g, Buf *mmacosx_version_min) {
    g->mmacosx_version_min = mmacosx_version_min;
}

void codegen_set_mios_version_min(CodeGen *g, Buf *mios_version_min) {
    g->mios_version_min = mios_version_min;
}

void codegen_set_rdynamic(CodeGen *g, bool rdynamic) {
    g->linker_rdynamic = rdynamic;
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *expr_node);
static LLVMValueRef gen_lvalue(CodeGen *g, AstNode *expr_node, AstNode *node, TypeTableEntry **out_type_entry);
static LLVMValueRef gen_field_access_expr(CodeGen *g, AstNode *node, bool is_lvalue);
static LLVMValueRef gen_var_decl_raw(CodeGen *g, AstNode *source_node, AstNodeVariableDeclaration *var_decl,
        bool unwrap_maybe, LLVMValueRef *init_val, TypeTableEntry **init_val_type, bool var_is_ptr);
static LLVMValueRef gen_assign_raw(CodeGen *g, AstNode *source_node, BinOpType bin_op,
        LLVMValueRef target_ref, LLVMValueRef value,
        TypeTableEntry *op1_type, TypeTableEntry *op2_type);
static LLVMValueRef gen_unwrap_maybe(CodeGen *g, AstNode *node, LLVMValueRef maybe_struct_ref);
static LLVMValueRef gen_div(CodeGen *g, AstNode *source_node, LLVMValueRef val1, LLVMValueRef val2,
        TypeTableEntry *type_entry, bool exact);

static TypeTableEntry *get_type_for_type_node(AstNode *node) {
    Expr *expr = get_resolved_expr(node);
    assert(expr->type_entry->id == TypeTableEntryIdMetaType);
    ConstExprValue *const_val = &expr->const_val;
    assert(const_val->ok);
    return const_val->data.x_type;
}

static void set_debug_source_node(CodeGen *g, AstNode *node) {
    assert(node->block_context);
    ZigLLVMSetCurrentDebugLocation(g->builder, node->line + 1, node->column + 1, node->block_context->di_scope);
}

static void clear_debug_source_node(CodeGen *g) {
    ZigLLVMClearCurrentDebugLocation(g->builder);
}

static TypeTableEntry *get_expr_type(AstNode *node) {
    return get_resolved_expr(node)->type_entry;
}

enum AddSubMul {
    AddSubMulAdd = 0,
    AddSubMulSub = 1,
    AddSubMulMul = 2,
};

static int bits_index(int size_in_bits) {
    switch (size_in_bits) {
        case 8:
            return 0;
        case 16:
            return 1;
        case 32:
            return 2;
        case 64:
            return 3;
        default:
            zig_unreachable();
    }
}

static LLVMValueRef get_arithmetic_overflow_fn(CodeGen *g, TypeTableEntry *type_entry,
        const char *signed_name, const char *unsigned_name)
{
    assert(type_entry->id == TypeTableEntryIdInt);
    const char *signed_str = type_entry->data.integral.is_signed ? signed_name : unsigned_name;
    Buf *llvm_name = buf_sprintf("llvm.%s.with.overflow.i%d", signed_str, type_entry->data.integral.bit_count);

    LLVMTypeRef return_elem_types[] = {
        type_entry->type_ref,
        LLVMInt1Type(),
    };
    LLVMTypeRef param_types[] = {
        type_entry->type_ref,
        type_entry->type_ref,
    };
    LLVMTypeRef return_struct_type = LLVMStructType(return_elem_types, 2, false);
    LLVMTypeRef fn_type = LLVMFunctionType(return_struct_type, param_types, 2, false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(llvm_name), fn_type);
    assert(LLVMGetIntrinsicID(fn_val));
    return fn_val;
}

static LLVMValueRef get_int_overflow_fn(CodeGen *g, TypeTableEntry *type_entry, AddSubMul add_sub_mul) {
    assert(type_entry->id == TypeTableEntryIdInt);
    // [0-signed,1-unsigned][0-add,1-sub,2-mul][0-8,1-16,2-32,3-64]
    int index0 = type_entry->data.integral.is_signed ? 0 : 1;
    int index1 = add_sub_mul;
    int index2 = bits_index(type_entry->data.integral.bit_count);
    LLVMValueRef *fn = &g->int_overflow_fns[index0][index1][index2];
    if (*fn) {
        return *fn;
    }
    switch (add_sub_mul) {
        case AddSubMulAdd:
            *fn = get_arithmetic_overflow_fn(g, type_entry, "sadd", "uadd");
            break;
        case AddSubMulSub:
            *fn = get_arithmetic_overflow_fn(g, type_entry, "ssub", "usub");
            break;
        case AddSubMulMul:
            *fn = get_arithmetic_overflow_fn(g, type_entry, "smul", "umul");
            break;

    }
    return *fn;
}

static LLVMValueRef get_int_builtin_fn(CodeGen *g, TypeTableEntry *int_type, BuiltinFnId fn_id) {
    // [0-ctz,1-clz][0-8,1-16,2-32,3-64]
    int index0 = (fn_id == BuiltinFnIdCtz) ? 0 : 1;
    int index1 = bits_index(int_type->data.integral.bit_count);
    LLVMValueRef *fn = &g->int_builtin_fns[index0][index1];
    if (!*fn) {
        const char *fn_name = (fn_id == BuiltinFnIdCtz) ? "cttz" : "ctlz";
        Buf *llvm_name = buf_sprintf("llvm.%s.i%d", fn_name, int_type->data.integral.bit_count);
        LLVMTypeRef param_types[] = {
            int_type->type_ref,
            LLVMInt1Type(),
        };
        LLVMTypeRef fn_type = LLVMFunctionType(int_type->type_ref, param_types, 2, false);
        *fn = LLVMAddFunction(g->module, buf_ptr(llvm_name), fn_type);
    }
    return *fn;
}

static LLVMValueRef get_handle_value(CodeGen *g, AstNode *source_node, LLVMValueRef ptr, TypeTableEntry *type) {
    if (handle_is_ptr(type)) {
        return ptr;
    } else {
        set_debug_source_node(g, source_node);
        return LLVMBuildLoad(g->builder, ptr, "");
    }
}

static bool want_debug_safety(CodeGen *g, AstNode *node) {
    return !g->is_release_build && !node->block_context->safety_off;
}

static void gen_debug_safety_crash(CodeGen *g) {
    LLVMBuildCall(g->builder, g->trap_fn_val, nullptr, 0, "");
    LLVMBuildUnreachable(g->builder);
}

static void add_bounds_check(CodeGen *g, AstNode *source_node, LLVMValueRef target_val,
        LLVMIntPredicate lower_pred, LLVMValueRef lower_value,
        LLVMIntPredicate upper_pred, LLVMValueRef upper_value)
{
    if (!lower_value && !upper_value) {
        return;
    }
    if (upper_value && !lower_value) {
        lower_value = upper_value;
        lower_pred = upper_pred;
        upper_value = nullptr;
    }

    set_debug_source_node(g, source_node);

    LLVMBasicBlockRef bounds_check_fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoundsCheckFail");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoundsCheckOk");
    LLVMBasicBlockRef lower_ok_block = upper_value ?
        LLVMAppendBasicBlock(g->cur_fn->fn_value, "FirstBoundsCheckOk") : ok_block;

    LLVMValueRef lower_ok_val = LLVMBuildICmp(g->builder, lower_pred, target_val, lower_value, "");
    LLVMBuildCondBr(g->builder, lower_ok_val, lower_ok_block, bounds_check_fail_block);

    LLVMPositionBuilderAtEnd(g->builder, bounds_check_fail_block);
    gen_debug_safety_crash(g);

    if (upper_value) {
        LLVMPositionBuilderAtEnd(g->builder, lower_ok_block);
        LLVMValueRef upper_ok_val = LLVMBuildICmp(g->builder, upper_pred, target_val, upper_value, "");
        LLVMBuildCondBr(g->builder, upper_ok_val, ok_block, bounds_check_fail_block);
    }

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
}

static LLVMValueRef gen_err_name(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);
    assert(g->generate_error_name_table);

    if (g->error_decls.length == 1) {
        LLVMBuildUnreachable(g->builder);
        return nullptr;
    }


    AstNode *err_val_node = node->data.fn_call_expr.params.at(0);
    LLVMValueRef err_val = gen_expr(g, err_val_node);
    set_debug_source_node(g, node);

    if (want_debug_safety(g, node)) {
        LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(err_val));
        LLVMValueRef end_val = LLVMConstInt(LLVMTypeOf(err_val), g->error_decls.length, false);
        add_bounds_check(g, node, err_val, LLVMIntNE, zero, LLVMIntULT, end_val);
    }

    LLVMValueRef indices[] = {
        LLVMConstNull(g->builtin_types.entry_usize->type_ref),
        err_val,
    };
    return LLVMBuildInBoundsGEP(g->builder, g->err_name_table, indices, 2, "");
}

static LLVMAtomicOrdering to_LLVMAtomicOrdering(AtomicOrder atomic_order) {
    switch (atomic_order) {
        case AtomicOrderUnordered: return LLVMAtomicOrderingUnordered;
        case AtomicOrderMonotonic: return LLVMAtomicOrderingMonotonic;
        case AtomicOrderAcquire: return LLVMAtomicOrderingAcquire;
        case AtomicOrderRelease: return LLVMAtomicOrderingRelease;
        case AtomicOrderAcqRel: return LLVMAtomicOrderingAcquireRelease;
        case AtomicOrderSeqCst: return LLVMAtomicOrderingSequentiallyConsistent;
    }
    zig_unreachable();
}

static LLVMValueRef gen_cmp_exchange(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *ptr_arg = node->data.fn_call_expr.params.at(0);
    AstNode *cmp_arg = node->data.fn_call_expr.params.at(1);
    AstNode *new_arg = node->data.fn_call_expr.params.at(2);
    AstNode *success_order_arg = node->data.fn_call_expr.params.at(3);
    AstNode *failure_order_arg = node->data.fn_call_expr.params.at(4);

    LLVMValueRef ptr_val = gen_expr(g, ptr_arg);
    LLVMValueRef cmp_val = gen_expr(g, cmp_arg);
    LLVMValueRef new_val = gen_expr(g, new_arg);

    ConstExprValue *success_order_val = &get_resolved_expr(success_order_arg)->const_val;
    ConstExprValue *failure_order_val = &get_resolved_expr(failure_order_arg)->const_val;

    assert(success_order_val->ok);
    assert(failure_order_val->ok);

    LLVMAtomicOrdering success_order = to_LLVMAtomicOrdering((AtomicOrder)success_order_val->data.x_enum.tag);
    LLVMAtomicOrdering failure_order = to_LLVMAtomicOrdering((AtomicOrder)failure_order_val->data.x_enum.tag);

    LLVMValueRef result_val = ZigLLVMBuildCmpXchg(g->builder, ptr_val, cmp_val, new_val,
            success_order, failure_order);

    return LLVMBuildExtractValue(g->builder, result_val, 1, "");
}

static LLVMValueRef gen_fence(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *atomic_order_arg = node->data.fn_call_expr.params.at(0);
    ConstExprValue *atomic_order_val = &get_resolved_expr(atomic_order_arg)->const_val;

    assert(atomic_order_val->ok);

    LLVMAtomicOrdering atomic_order = to_LLVMAtomicOrdering((AtomicOrder)atomic_order_val->data.x_enum.tag);

    LLVMBuildFence(g->builder, atomic_order, false, "");
    return nullptr;
}

static LLVMValueRef gen_div_exact(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *op1_node = node->data.fn_call_expr.params.at(0);
    AstNode *op2_node = node->data.fn_call_expr.params.at(1);

    LLVMValueRef op1_val = gen_expr(g, op1_node);
    LLVMValueRef op2_val = gen_expr(g, op2_node);

    return gen_div(g, node, op1_val, op2_val, get_expr_type(op1_node), true);
}

static LLVMValueRef gen_truncate(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    TypeTableEntry *dest_type = get_type_for_type_node(node->data.fn_call_expr.params.at(0));
    AstNode *src_node = node->data.fn_call_expr.params.at(1);

    LLVMValueRef src_val = gen_expr(g, src_node);

    set_debug_source_node(g, node);
    return LLVMBuildTrunc(g->builder, src_val, dest_type->type_ref, "");
}

static LLVMValueRef gen_shl_with_overflow(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    int fn_call_param_count = node->data.fn_call_expr.params.length;
    assert(fn_call_param_count == 4);

    TypeTableEntry *int_type = get_type_for_type_node(node->data.fn_call_expr.params.at(0));
    assert(int_type->id == TypeTableEntryIdInt);

    LLVMValueRef val1 = gen_expr(g, node->data.fn_call_expr.params.at(1));
    LLVMValueRef val2 = gen_expr(g, node->data.fn_call_expr.params.at(2));
    LLVMValueRef ptr_result = gen_expr(g, node->data.fn_call_expr.params.at(3));

    set_debug_source_node(g, node);
    LLVMValueRef result = LLVMBuildShl(g->builder, val1, val2, "");
    LLVMValueRef orig_val;
    if (int_type->data.integral.is_signed) {
        orig_val = LLVMBuildAShr(g->builder, result, val2, "");
    } else {
        orig_val = LLVMBuildLShr(g->builder, result, val2, "");
    }
    LLVMValueRef overflow_bit = LLVMBuildICmp(g->builder, LLVMIntNE, val1, orig_val, "");

    LLVMBuildStore(g->builder, result, ptr_result);

    return overflow_bit;
}

static LLVMValueRef gen_builtin_fn_call_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);
    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
    assert(fn_ref_expr->type == NodeTypeSymbol);
    BuiltinFnEntry *builtin_fn = node->data.fn_call_expr.builtin_fn;

    switch (builtin_fn->id) {
        case BuiltinFnIdInvalid:
        case BuiltinFnIdTypeof:
        case BuiltinFnIdCInclude:
        case BuiltinFnIdCDefine:
        case BuiltinFnIdCUndef:
        case BuiltinFnIdImport:
        case BuiltinFnIdCImport:
        case BuiltinFnIdCompileErr:
        case BuiltinFnIdIntType:
            zig_unreachable();
        case BuiltinFnIdCtz:
        case BuiltinFnIdClz:
            {
                int fn_call_param_count = node->data.fn_call_expr.params.length;
                assert(fn_call_param_count == 2);
                TypeTableEntry *int_type = get_type_for_type_node(node->data.fn_call_expr.params.at(0));
                assert(int_type->id == TypeTableEntryIdInt);
                LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, builtin_fn->id);
                LLVMValueRef operand = gen_expr(g, node->data.fn_call_expr.params.at(1));
                LLVMValueRef params[] {
                    operand,
                    LLVMConstNull(LLVMInt1Type()),
                };
                set_debug_source_node(g, node);
                return LLVMBuildCall(g->builder, fn_val, params, 2, "");
            }
        case BuiltinFnIdAddWithOverflow:
        case BuiltinFnIdSubWithOverflow:
        case BuiltinFnIdMulWithOverflow:
            {
                int fn_call_param_count = node->data.fn_call_expr.params.length;
                assert(fn_call_param_count == 4);

                TypeTableEntry *int_type = get_type_for_type_node(node->data.fn_call_expr.params.at(0));
                AddSubMul add_sub_mul;
                if (builtin_fn->id == BuiltinFnIdAddWithOverflow) {
                    add_sub_mul = AddSubMulAdd;
                } else if (builtin_fn->id == BuiltinFnIdSubWithOverflow) {
                    add_sub_mul = AddSubMulSub;
                } else if (builtin_fn->id == BuiltinFnIdMulWithOverflow) {
                    add_sub_mul = AddSubMulMul;
                } else {
                    zig_unreachable();
                }
                LLVMValueRef fn_val = get_int_overflow_fn(g, int_type, add_sub_mul);

                LLVMValueRef op1 = gen_expr(g, node->data.fn_call_expr.params.at(1));
                LLVMValueRef op2 = gen_expr(g, node->data.fn_call_expr.params.at(2));
                LLVMValueRef ptr_result = gen_expr(g, node->data.fn_call_expr.params.at(3));

                LLVMValueRef params[] = {
                    op1,
                    op2,
                };

                set_debug_source_node(g, node);
                LLVMValueRef result_struct = LLVMBuildCall(g->builder, fn_val, params, 2, "");
                LLVMValueRef result = LLVMBuildExtractValue(g->builder, result_struct, 0, "");
                LLVMValueRef overflow_bit = LLVMBuildExtractValue(g->builder, result_struct, 1, "");
                LLVMBuildStore(g->builder, result, ptr_result);

                return overflow_bit;
            }
        case BuiltinFnIdShlWithOverflow:
            return gen_shl_with_overflow(g, node);
        case BuiltinFnIdMemcpy:
            {
                int fn_call_param_count = node->data.fn_call_expr.params.length;
                assert(fn_call_param_count == 3);

                AstNode *dest_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *dest_type = get_expr_type(dest_node);

                LLVMValueRef dest_ptr = gen_expr(g, dest_node);
                LLVMValueRef src_ptr = gen_expr(g, node->data.fn_call_expr.params.at(1));
                LLVMValueRef len_val = gen_expr(g, node->data.fn_call_expr.params.at(2));

                LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

                set_debug_source_node(g, node);
                LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");
                LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr, ptr_u8, "");

                uint64_t align_in_bytes = get_memcpy_align(g, dest_type->data.pointer.child_type);

                LLVMValueRef params[] = {
                    dest_ptr_casted, // dest pointer
                    src_ptr_casted, // source pointer
                    len_val, // byte count
                    LLVMConstInt(LLVMInt32Type(), align_in_bytes, false), // align in bytes
                    LLVMConstNull(LLVMInt1Type()), // is volatile
                };

                LLVMBuildCall(g->builder, builtin_fn->fn_val, params, 5, "");
                return nullptr;
            }
        case BuiltinFnIdMemset:
            {
                int fn_call_param_count = node->data.fn_call_expr.params.length;
                assert(fn_call_param_count == 3);

                AstNode *dest_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *dest_type = get_expr_type(dest_node);

                LLVMValueRef dest_ptr = gen_expr(g, dest_node);
                LLVMValueRef char_val = gen_expr(g, node->data.fn_call_expr.params.at(1));
                LLVMValueRef len_val = gen_expr(g, node->data.fn_call_expr.params.at(2));

                LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

                set_debug_source_node(g, node);
                LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");

                uint64_t align_in_bytes = get_memcpy_align(g, dest_type->data.pointer.child_type);

                LLVMValueRef params[] = {
                    dest_ptr_casted, // dest pointer
                    char_val, // source pointer
                    len_val, // byte count
                    LLVMConstInt(LLVMInt32Type(), align_in_bytes, false), // align in bytes
                    LLVMConstNull(LLVMInt1Type()), // is volatile
                };

                LLVMBuildCall(g->builder, builtin_fn->fn_val, params, 5, "");
                return nullptr;
            }
        case BuiltinFnIdSizeof:
        case BuiltinFnIdAlignof:
        case BuiltinFnIdMinValue:
        case BuiltinFnIdMaxValue:
        case BuiltinFnIdMemberCount:
        case BuiltinFnIdConstEval:
        case BuiltinFnIdEmbedFile:
            // caught by constant expression eval codegen
            zig_unreachable();
        case BuiltinFnIdCompileVar:
            return nullptr;
        case BuiltinFnIdErrName:
            return gen_err_name(g, node);
        case BuiltinFnIdBreakpoint:
            set_debug_source_node(g, node);
            return LLVMBuildCall(g->builder, g->trap_fn_val, nullptr, 0, "");
        case BuiltinFnIdFrameAddress:
        case BuiltinFnIdReturnAddress:
            {
                LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->type_ref);
                set_debug_source_node(g, node);
                return LLVMBuildCall(g->builder, builtin_fn->fn_val, &zero, 1, "");
            }
        case BuiltinFnIdCmpExchange:
            return gen_cmp_exchange(g, node);
        case BuiltinFnIdFence:
            return gen_fence(g, node);
        case BuiltinFnIdDivExact:
            return gen_div_exact(g, node);
        case BuiltinFnIdTruncate:
            return gen_truncate(g, node);
    }
    zig_unreachable();
}

static LLVMValueRef gen_enum_value_expr(CodeGen *g, AstNode *node, TypeTableEntry *enum_type,
        AstNode *arg_node)
{
    assert(node->type == NodeTypeFieldAccessExpr);

    uint64_t value = node->data.field_access_expr.type_enum_field->value;
    LLVMTypeRef tag_type_ref = enum_type->data.enumeration.tag_type->type_ref;
    LLVMValueRef tag_value = LLVMConstInt(tag_type_ref, value, false);

    if (enum_type->data.enumeration.gen_field_count == 0) {
        return tag_value;
    } else {
        TypeTableEntry *arg_node_type = nullptr;
        LLVMValueRef new_union_val = gen_expr(g, arg_node);
        if (arg_node) {
            arg_node_type = get_expr_type(arg_node);
            new_union_val = gen_expr(g, arg_node);
        } else {
            arg_node_type = g->builtin_types.entry_void;
        }

        LLVMValueRef tmp_struct_ptr = node->data.field_access_expr.resolved_struct_val_expr.ptr;

        // populate the new tag value
        set_debug_source_node(g, node);
        LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, 0, "");
        LLVMBuildStore(g->builder, tag_value, tag_field_ptr);

        if (arg_node_type->id != TypeTableEntryIdVoid) {
            // populate the union value
            TypeTableEntry *union_val_type = get_expr_type(arg_node);
            LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, 1, "");
            LLVMValueRef bitcasted_union_field_ptr = LLVMBuildBitCast(g->builder, union_field_ptr,
                    LLVMPointerType(union_val_type->type_ref, 0), "");

            gen_assign_raw(g, arg_node, BinOpTypeAssign, bitcasted_union_field_ptr, new_union_val,
                    union_val_type, union_val_type);

        }

        return tmp_struct_ptr;
    }
}

static LLVMValueRef gen_widen_or_shorten(CodeGen *g, AstNode *source_node, TypeTableEntry *actual_type_non_canon,
        TypeTableEntry *wanted_type_non_canon, LLVMValueRef expr_val)
{
    TypeTableEntry *actual_type = get_underlying_type(actual_type_non_canon);
    TypeTableEntry *wanted_type = get_underlying_type(wanted_type_non_canon);

    assert(actual_type->id == wanted_type->id);

    uint64_t actual_bits;
    uint64_t wanted_bits;
    if (actual_type->id == TypeTableEntryIdFloat) {
        actual_bits = actual_type->data.floating.bit_count;
        wanted_bits = wanted_type->data.floating.bit_count;
    } else if (actual_type->id == TypeTableEntryIdInt) {
        actual_bits = actual_type->data.integral.bit_count;
        wanted_bits = wanted_type->data.integral.bit_count;
    } else {
        zig_unreachable();
    }

    if (actual_bits >= wanted_bits && actual_type->id == TypeTableEntryIdInt &&
        !wanted_type->data.integral.is_signed && actual_type->data.integral.is_signed &&
        want_debug_safety(g, source_node))
    {
        set_debug_source_node(g, source_node);
        LLVMValueRef zero = LLVMConstNull(actual_type->type_ref);
        LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntSGE, expr_val, zero, "");

        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "SignCastOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "SignCastFail");
        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_debug_safety_crash(g);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    if (actual_bits == wanted_bits) {
        return expr_val;
    } else if (actual_bits < wanted_bits) {
        if (actual_type->id == TypeTableEntryIdFloat) {
            set_debug_source_node(g, source_node);
            return LLVMBuildFPExt(g->builder, expr_val, wanted_type->type_ref, "");
        } else if (actual_type->id == TypeTableEntryIdInt) {
            if (actual_type->data.integral.is_signed) {
                set_debug_source_node(g, source_node);
                return LLVMBuildSExt(g->builder, expr_val, wanted_type->type_ref, "");
            } else {
                set_debug_source_node(g, source_node);
                return LLVMBuildZExt(g->builder, expr_val, wanted_type->type_ref, "");
            }
        } else {
            zig_unreachable();
        }
    } else if (actual_bits > wanted_bits) {
        if (actual_type->id == TypeTableEntryIdFloat) {
            set_debug_source_node(g, source_node);
            return LLVMBuildFPTrunc(g->builder, expr_val, wanted_type->type_ref, "");
        } else if (actual_type->id == TypeTableEntryIdInt) {
            set_debug_source_node(g, source_node);
            LLVMValueRef trunc_val = LLVMBuildTrunc(g->builder, expr_val, wanted_type->type_ref, "");
            if (!want_debug_safety(g, source_node)) {
                return trunc_val;
            }
            LLVMValueRef orig_val;
            if (actual_type->data.integral.is_signed) {
                orig_val = LLVMBuildSExt(g->builder, trunc_val, actual_type->type_ref, "");
            } else {
                orig_val = LLVMBuildZExt(g->builder, trunc_val, actual_type->type_ref, "");
            }
            LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, expr_val, orig_val, "");
            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "CastShortenOk");
            LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "CastShortenFail");
            LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

            LLVMPositionBuilderAtEnd(g->builder, fail_block);
            gen_debug_safety_crash(g);

            LLVMPositionBuilderAtEnd(g->builder, ok_block);
            return trunc_val;
        } else {
            zig_unreachable();
        }
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef gen_cast_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *expr_node = node->data.fn_call_expr.params.at(0);

    LLVMValueRef expr_val = gen_expr(g, expr_node);

    TypeTableEntry *actual_type = get_expr_type(expr_node);
    TypeTableEntry *wanted_type = get_expr_type(node);

    AstNodeFnCallExpr *cast_expr = &node->data.fn_call_expr;

    switch (cast_expr->cast_op) {
        case CastOpNoCast:
            zig_unreachable();
        case CastOpNoop:
            return expr_val;
        case CastOpErrToInt:
            assert(actual_type->id == TypeTableEntryIdErrorUnion);
            if (!type_has_bits(actual_type->data.error.child_type)) {
                return gen_widen_or_shorten(g, node, g->err_tag_type, wanted_type, expr_val);
            } else {
                zig_panic("TODO");
            }
        case CastOpMaybeWrap:
            {
                assert(cast_expr->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdMaybe);
                assert(actual_type);

                TypeTableEntry *child_type = wanted_type->data.maybe.child_type;

                if (child_type->id == TypeTableEntryIdPointer ||
                    child_type->id == TypeTableEntryIdFn)
                {
                    return expr_val;
                } else {
                    set_debug_source_node(g, node);
                    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, 0, "");
                    gen_assign_raw(g, node, BinOpTypeAssign,
                            val_ptr, expr_val, child_type, actual_type);

                    set_debug_source_node(g, node);
                    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, 1, "");
                    LLVMBuildStore(g->builder, LLVMConstAllOnes(LLVMInt1Type()), maybe_ptr);
                }

                return cast_expr->tmp_ptr;
            }
        case CastOpNullToMaybe:
            // handled by constant expression evaluator
            zig_unreachable();
        case CastOpErrorWrap:
            {
                assert(wanted_type->id == TypeTableEntryIdErrorUnion);
                TypeTableEntry *child_type = wanted_type->data.error.child_type;
                LLVMValueRef ok_err_val = LLVMConstNull(g->err_tag_type->type_ref);

                if (!type_has_bits(child_type)) {
                    return ok_err_val;
                } else {
                    assert(cast_expr->tmp_ptr);
                    assert(wanted_type->id == TypeTableEntryIdErrorUnion);
                    assert(actual_type);

                    set_debug_source_node(g, node);
                    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, 0, "");
                    LLVMBuildStore(g->builder, ok_err_val, err_tag_ptr);

                    LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, 1, "");
                    gen_assign_raw(g, node, BinOpTypeAssign,
                            payload_ptr, expr_val, child_type, actual_type);

                    return cast_expr->tmp_ptr;
                }
            }
        case CastOpPureErrorWrap:
            assert(wanted_type->id == TypeTableEntryIdErrorUnion);

            if (!type_has_bits(wanted_type->data.error.child_type)) {
                return expr_val;
            } else {
                zig_panic("TODO");
            }
        case CastOpPtrToInt:
            set_debug_source_node(g, node);
            return LLVMBuildPtrToInt(g->builder, expr_val, wanted_type->type_ref, "");
        case CastOpIntToPtr:
            set_debug_source_node(g, node);
            return LLVMBuildIntToPtr(g->builder, expr_val, wanted_type->type_ref, "");
        case CastOpPointerReinterpret:
            set_debug_source_node(g, node);
            return LLVMBuildBitCast(g->builder, expr_val, wanted_type->type_ref, "");
        case CastOpWidenOrShorten:
            return gen_widen_or_shorten(g, node, actual_type, wanted_type, expr_val);
        case CastOpToUnknownSizeArray:
            {
                assert(cast_expr->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdStruct);
                assert(wanted_type->data.structure.is_slice);

                TypeTableEntry *pointer_type = wanted_type->data.structure.fields[0].type_entry;

                set_debug_source_node(g, node);

                int ptr_index = wanted_type->data.structure.fields[0].gen_index;
                if (ptr_index >= 0) {
                    LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, ptr_index, "");
                    LLVMValueRef expr_bitcast = LLVMBuildBitCast(g->builder, expr_val, pointer_type->type_ref, "");
                    LLVMBuildStore(g->builder, expr_bitcast, ptr_ptr);
                }

                int len_index = wanted_type->data.structure.fields[1].gen_index;
                LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, len_index, "");
                LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        actual_type->data.array.len, false);
                LLVMBuildStore(g->builder, len_val, len_ptr);

                return cast_expr->tmp_ptr;
            }
        case CastOpResizeSlice:
            {
                assert(cast_expr->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdStruct);
                assert(wanted_type->data.structure.is_slice);
                assert(actual_type->id == TypeTableEntryIdStruct);
                assert(actual_type->data.structure.is_slice);

                TypeTableEntry *actual_pointer_type = actual_type->data.structure.fields[0].type_entry;
                TypeTableEntry *actual_child_type = actual_pointer_type->data.pointer.child_type;
                TypeTableEntry *wanted_pointer_type = wanted_type->data.structure.fields[0].type_entry;
                TypeTableEntry *wanted_child_type = wanted_pointer_type->data.pointer.child_type;

                set_debug_source_node(g, node);

                int actual_ptr_index = actual_type->data.structure.fields[0].gen_index;
                int actual_len_index = actual_type->data.structure.fields[1].gen_index;
                int wanted_ptr_index = wanted_type->data.structure.fields[0].gen_index;
                int wanted_len_index = wanted_type->data.structure.fields[1].gen_index;

                LLVMValueRef src_ptr_ptr = LLVMBuildStructGEP(g->builder, expr_val, actual_ptr_index, "");
                LLVMValueRef src_ptr = LLVMBuildLoad(g->builder, src_ptr_ptr, "");
                LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr,
                        wanted_type->data.structure.fields[0].type_entry->type_ref, "");
                LLVMValueRef dest_ptr_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr,
                        wanted_ptr_index, "");
                LLVMBuildStore(g->builder, src_ptr_casted, dest_ptr_ptr);

                LLVMValueRef src_len_ptr = LLVMBuildStructGEP(g->builder, expr_val, actual_len_index, "");
                LLVMValueRef src_len = LLVMBuildLoad(g->builder, src_len_ptr, "");
                uint64_t src_size = type_size(g, actual_child_type);
                uint64_t dest_size = type_size(g, wanted_child_type);

                LLVMValueRef new_len;
                if (dest_size == 1) {
                    LLVMValueRef src_size_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref, src_size, false);
                    new_len = LLVMBuildMul(g->builder, src_len, src_size_val, "");
                } else if (src_size == 1) {
                    LLVMValueRef dest_size_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref, dest_size, false);
                    if (want_debug_safety(g, node)) {
                        LLVMValueRef remainder_val = LLVMBuildURem(g->builder, src_len, dest_size_val, "");
                        LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_usize->type_ref);
                        LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, remainder_val, zero, "");
                        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "SliceWidenOk");
                        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "SliceWidenFail");
                        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

                        LLVMPositionBuilderAtEnd(g->builder, fail_block);
                        gen_debug_safety_crash(g);

                        LLVMPositionBuilderAtEnd(g->builder, ok_block);
                    }
                    new_len = ZigLLVMBuildExactUDiv(g->builder, src_len, dest_size_val, "");
                } else {
                    zig_unreachable();
                }

                LLVMValueRef dest_len_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr,
                        wanted_len_index, "");
                LLVMBuildStore(g->builder, new_len, dest_len_ptr);


                return cast_expr->tmp_ptr;
            }
        case CastOpBytesToSlice:
            {
                assert(cast_expr->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdStruct);
                assert(wanted_type->data.structure.is_slice);
                assert(actual_type->id == TypeTableEntryIdArray);

                TypeTableEntry *wanted_pointer_type = wanted_type->data.structure.fields[0].type_entry;
                TypeTableEntry *wanted_child_type = wanted_pointer_type->data.pointer.child_type;

                set_debug_source_node(g, node);

                int wanted_ptr_index = wanted_type->data.structure.fields[0].gen_index;
                LLVMValueRef dest_ptr_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, wanted_ptr_index, "");
                LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, expr_val, wanted_pointer_type->type_ref, "");
                LLVMBuildStore(g->builder, src_ptr_casted, dest_ptr_ptr);

                int wanted_len_index = wanted_type->data.structure.fields[1].gen_index;
                LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, cast_expr->tmp_ptr, wanted_len_index, "");
                LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        actual_type->data.array.len / type_size(g, wanted_child_type), false);
                LLVMBuildStore(g->builder, len_val, len_ptr);

                return cast_expr->tmp_ptr;
            }
        case CastOpIntToFloat:
            assert(actual_type->id == TypeTableEntryIdInt);
            if (actual_type->data.integral.is_signed) {
                set_debug_source_node(g, node);
                return LLVMBuildSIToFP(g->builder, expr_val, wanted_type->type_ref, "");
            } else {
                set_debug_source_node(g, node);
                return LLVMBuildUIToFP(g->builder, expr_val, wanted_type->type_ref, "");
            }
        case CastOpFloatToInt:
            assert(wanted_type->id == TypeTableEntryIdInt);
            if (wanted_type->data.integral.is_signed) {
                set_debug_source_node(g, node);
                return LLVMBuildFPToSI(g->builder, expr_val, wanted_type->type_ref, "");
            } else {
                set_debug_source_node(g, node);
                return LLVMBuildFPToUI(g->builder, expr_val, wanted_type->type_ref, "");
            }

        case CastOpBoolToInt:
            assert(wanted_type->id == TypeTableEntryIdInt);
            assert(actual_type->id == TypeTableEntryIdBool);
            set_debug_source_node(g, node);
            return LLVMBuildZExt(g->builder, expr_val, wanted_type->type_ref, "");

        case CastOpIntToEnum:
            return gen_widen_or_shorten(g, node, actual_type, wanted_type->data.enumeration.tag_type, expr_val);
        case CastOpEnumToInt:
            return gen_widen_or_shorten(g, node, actual_type->data.enumeration.tag_type, wanted_type, expr_val);
    }
    zig_unreachable();
}


static LLVMValueRef gen_fn_call_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    if (node->data.fn_call_expr.is_builtin) {
        return gen_builtin_fn_call_expr(g, node);
    } else if (node->data.fn_call_expr.cast_op != CastOpNoCast) {
        return gen_cast_expr(g, node);
    }

    FnTableEntry *fn_table_entry = node->data.fn_call_expr.fn_entry;
    TypeTableEntry *struct_type = nullptr;
    AstNode *first_param_expr = nullptr;

    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
    if (fn_ref_expr->type == NodeTypeFieldAccessExpr &&
        fn_ref_expr->data.field_access_expr.is_member_fn)
    {
        first_param_expr = fn_ref_expr->data.field_access_expr.struct_expr;
        struct_type = get_expr_type(first_param_expr);
    }

    TypeTableEntry *fn_type;
    LLVMValueRef fn_val;
    AstNode *generic_proto_node;
    if (fn_table_entry) {
        fn_val = fn_table_entry->fn_value;
        fn_type = fn_table_entry->type_entry;
        generic_proto_node = fn_table_entry->proto_node->data.fn_proto.generic_proto_node;
    } else {
        fn_val = gen_expr(g, fn_ref_expr);
        fn_type = get_expr_type(fn_ref_expr);
        generic_proto_node = nullptr;
    }

    TypeTableEntry *src_return_type = fn_type->data.fn.fn_type_id.return_type;

    bool ret_has_bits = type_has_bits(src_return_type);

    int fn_call_param_count = node->data.fn_call_expr.params.length;
    bool first_arg_ret = ret_has_bits && handle_is_ptr(src_return_type);
    int actual_param_count = fn_call_param_count + (struct_type ? 1 : 0) + (first_arg_ret ? 1 : 0);
    bool is_var_args = fn_type->data.fn.fn_type_id.is_var_args;

    // don't really include void values
    LLVMValueRef *gen_param_values = allocate<LLVMValueRef>(actual_param_count);

    int gen_param_index = 0;
    if (first_arg_ret) {
        gen_param_values[gen_param_index] = node->data.fn_call_expr.tmp_ptr;
        gen_param_index += 1;
    }
    if (struct_type && type_has_bits(struct_type)) {
        gen_param_values[gen_param_index] = gen_expr(g, first_param_expr);
        assert(gen_param_values[gen_param_index]);
        gen_param_index += 1;
    }

    for (int call_i = 0; call_i < fn_call_param_count; call_i += 1) {
        int proto_i = call_i + (struct_type ? 1 : 0);
        if (generic_proto_node &&
            generic_proto_node->data.fn_proto.params.at(proto_i)->data.param_decl.is_inline)
        {
            continue;
        }
        AstNode *expr_node = node->data.fn_call_expr.params.at(call_i);
        LLVMValueRef param_value = gen_expr(g, expr_node);
        assert(param_value);
        TypeTableEntry *param_type = get_expr_type(expr_node);
        if (is_var_args || type_has_bits(param_type)) {
            gen_param_values[gen_param_index] = param_value;
            gen_param_index += 1;
        }
    }

    set_debug_source_node(g, node);
    LLVMValueRef result = LLVMZigBuildCall(g->builder, fn_val,
            gen_param_values, gen_param_index, fn_type->data.fn.calling_convention, "");

    if (src_return_type->id == TypeTableEntryIdUnreachable) {
        return LLVMBuildUnreachable(g->builder);
    } else if (!ret_has_bits) {
        return nullptr;
    } else if (first_arg_ret) {
        return node->data.fn_call_expr.tmp_ptr;
    } else {
        return result;
    }
}

static LLVMValueRef gen_array_base_ptr(CodeGen *g, AstNode *node) {
    TypeTableEntry *type_entry = get_expr_type(node);

    LLVMValueRef array_ptr;
    if (node->type == NodeTypeFieldAccessExpr) {
        array_ptr = gen_field_access_expr(g, node, true);
        if (type_entry->id == TypeTableEntryIdPointer) {
            // we have a double pointer so we must dereference it once
            set_debug_source_node(g, node);
            array_ptr = LLVMBuildLoad(g->builder, array_ptr, "");
        }
    } else {
        array_ptr = gen_expr(g, node);
    }

    assert(!array_ptr || LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);

    return array_ptr;
}

static LLVMValueRef gen_array_elem_ptr(CodeGen *g, AstNode *source_node, LLVMValueRef array_ptr,
        TypeTableEntry *array_type, LLVMValueRef subscript_value)
{
    assert(subscript_value);

    if (!type_has_bits(array_type)) {
        return nullptr;
    }

    if (array_type->id == TypeTableEntryIdArray) {
        if (want_debug_safety(g, source_node)) {
            LLVMValueRef end = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                    array_type->data.array.len, false);
            add_bounds_check(g, source_node, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, end);
        }
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->type_ref),
            subscript_value
        };
        set_debug_source_node(g, source_node);
        return LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
    } else if (array_type->id == TypeTableEntryIdPointer) {
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        LLVMValueRef indices[] = {
            subscript_value
        };
        set_debug_source_node(g, source_node);
        return LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 1, "");
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        if (want_debug_safety(g, source_node)) {
            set_debug_source_node(g, source_node);
            int len_index = array_type->data.structure.fields[1].gen_index;
            assert(len_index >= 0);
            LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, len_index, "");
            LLVMValueRef len = LLVMBuildLoad(g->builder, len_ptr, "");
            add_bounds_check(g, source_node, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, len);
        }

        set_debug_source_node(g, source_node);
        int ptr_index = array_type->data.structure.fields[0].gen_index;
        assert(ptr_index >= 0);
        LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, ptr_index, "");
        LLVMValueRef ptr = LLVMBuildLoad(g->builder, ptr_ptr, "");
        return LLVMBuildInBoundsGEP(g->builder, ptr, &subscript_value, 1, "");
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef gen_array_ptr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeArrayAccessExpr);

    AstNode *array_expr_node = node->data.array_access_expr.array_ref_expr;
    TypeTableEntry *array_type = get_expr_type(array_expr_node);

    LLVMValueRef array_ptr = gen_array_base_ptr(g, array_expr_node);

    LLVMValueRef subscript_value = gen_expr(g, node->data.array_access_expr.subscript);
    return gen_array_elem_ptr(g, node, array_ptr, array_type, subscript_value);
}

static LLVMValueRef gen_field_ptr(CodeGen *g, AstNode *node, TypeTableEntry **out_type_entry) {
    assert(node->type == NodeTypeFieldAccessExpr);

    AstNode *struct_expr_node = node->data.field_access_expr.struct_expr;

    *out_type_entry = node->data.field_access_expr.type_struct_field->type_entry;
    if (!type_has_bits(*out_type_entry)) {
        return nullptr;
    }

    LLVMValueRef struct_ptr;
    if (struct_expr_node->type == NodeTypeSymbol) {
        VariableTableEntry *var = get_resolved_expr(struct_expr_node)->variable;
        assert(var);

        if (var->type->id == TypeTableEntryIdPointer) {
            set_debug_source_node(g, node);
            struct_ptr = LLVMBuildLoad(g->builder, var->value_ref, "");
        } else {
            struct_ptr = var->value_ref;
        }
    } else if (struct_expr_node->type == NodeTypeFieldAccessExpr) {
        struct_ptr = gen_field_access_expr(g, struct_expr_node, true);
        TypeTableEntry *field_type = get_expr_type(struct_expr_node);
        if (field_type->id == TypeTableEntryIdPointer) {
            // we have a double pointer so we must dereference it once
            set_debug_source_node(g, node);
            struct_ptr = LLVMBuildLoad(g->builder, struct_ptr, "");
        }
    } else {
        struct_ptr = gen_expr(g, struct_expr_node);
    }

    assert(LLVMGetTypeKind(LLVMTypeOf(struct_ptr)) == LLVMPointerTypeKind);
    assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(struct_ptr))) == LLVMStructTypeKind);

    int gen_field_index = node->data.field_access_expr.type_struct_field->gen_index;
    assert(gen_field_index >= 0);

    set_debug_source_node(g, node);
    return LLVMBuildStructGEP(g->builder, struct_ptr, gen_field_index, "");
}

static LLVMValueRef gen_slice_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeSliceExpr);

    AstNode *array_ref_node = node->data.slice_expr.array_ref_expr;
    TypeTableEntry *array_type = get_expr_type(array_ref_node);

    LLVMValueRef tmp_struct_ptr = node->data.slice_expr.resolved_struct_val_expr.ptr;
    LLVMValueRef array_ptr = gen_array_base_ptr(g, array_ref_node);

    if (array_type->id == TypeTableEntryIdArray) {
        LLVMValueRef start_val = gen_expr(g, node->data.slice_expr.start);
        LLVMValueRef end_val;
        if (node->data.slice_expr.end) {
            end_val = gen_expr(g, node->data.slice_expr.end);
        } else {
            end_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref, array_type->data.array.len, false);
        }

        if (want_debug_safety(g, node)) {
            add_bounds_check(g, node, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
            if (node->data.slice_expr.end) {
                LLVMValueRef array_end = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        array_type->data.array.len, false);
                add_bounds_check(g, node, end_val, LLVMIntEQ, nullptr, LLVMIntULE, array_end);
            }
        }

        set_debug_source_node(g, node);
        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, 0, "");
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->type_ref),
            start_val,
        };
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
        LLVMBuildStore(g->builder, slice_start_ptr, ptr_field_ptr);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, 1, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        LLVMBuildStore(g->builder, len_value, len_field_ptr);

        return tmp_struct_ptr;
    } else if (array_type->id == TypeTableEntryIdPointer) {
        LLVMValueRef start_val = gen_expr(g, node->data.slice_expr.start);
        LLVMValueRef end_val = gen_expr(g, node->data.slice_expr.end);

        if (want_debug_safety(g, node)) {
            add_bounds_check(g, node, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
        }

        set_debug_source_node(g, node);
        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, 0, "");
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, &start_val, 1, "");
        LLVMBuildStore(g->builder, slice_start_ptr, ptr_field_ptr);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, 1, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        LLVMBuildStore(g->builder, len_value, len_field_ptr);

        return tmp_struct_ptr;
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        int ptr_index = array_type->data.structure.fields[0].gen_index;
        assert(ptr_index >= 0);
        int len_index = array_type->data.structure.fields[1].gen_index;
        assert(len_index >= 0);

        LLVMValueRef prev_end = nullptr;
        if (!node->data.slice_expr.end || want_debug_safety(g, node)) {
            set_debug_source_node(g, node);
            LLVMValueRef src_len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, len_index, "");
            prev_end = LLVMBuildLoad(g->builder, src_len_ptr, "");
        }

        LLVMValueRef start_val = gen_expr(g, node->data.slice_expr.start);
        LLVMValueRef end_val;
        if (node->data.slice_expr.end) {
            end_val = gen_expr(g, node->data.slice_expr.end);
        } else {
            end_val = prev_end;
        }

        if (want_debug_safety(g, node)) {
            assert(prev_end);
            add_bounds_check(g, node, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
            if (node->data.slice_expr.end) {
                add_bounds_check(g, node, end_val, LLVMIntEQ, nullptr, LLVMIntULE, prev_end);
            }
        }

        set_debug_source_node(g, node);
        LLVMValueRef src_ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, ptr_index, "");
        LLVMValueRef src_ptr = LLVMBuildLoad(g->builder, src_ptr_ptr, "");
        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, ptr_index, "");
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, src_ptr, &start_val, len_index, "");
        LLVMBuildStore(g->builder, slice_start_ptr, ptr_field_ptr);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        LLVMBuildStore(g->builder, len_value, len_field_ptr);

        return tmp_struct_ptr;
    } else {
        zig_unreachable();
    }
}


static LLVMValueRef gen_array_access_expr(CodeGen *g, AstNode *node, bool is_lvalue) {
    assert(node->type == NodeTypeArrayAccessExpr);

    LLVMValueRef ptr = gen_array_ptr(g, node);
    TypeTableEntry *child_type;
    TypeTableEntry *array_type = get_expr_type(node->data.array_access_expr.array_ref_expr);
    if (array_type->id == TypeTableEntryIdPointer) {
        child_type = array_type->data.pointer.child_type;
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);
        TypeTableEntry *child_ptr_type = array_type->data.structure.fields[0].type_entry;
        assert(child_ptr_type->id == TypeTableEntryIdPointer);
        child_type = child_ptr_type->data.pointer.child_type;
    } else if (array_type->id == TypeTableEntryIdArray) {
        child_type = array_type->data.array.child_type;
    } else {
        zig_unreachable();
    }

    if (is_lvalue || !ptr || handle_is_ptr(child_type)) {
        return ptr;
    } else {
        set_debug_source_node(g, node);
        return LLVMBuildLoad(g->builder, ptr, "");
    }
}

static LLVMValueRef gen_variable(CodeGen *g, AstNode *source_node, VariableTableEntry *variable) {
    if (!type_has_bits(variable->type)) {
        return nullptr;
    } else {
        assert(variable->value_ref);
        return get_handle_value(g, source_node, variable->value_ref, variable->type);
    }
}

static LLVMValueRef gen_field_access_expr(CodeGen *g, AstNode *node, bool is_lvalue) {
    assert(node->type == NodeTypeFieldAccessExpr);

    AstNode *struct_expr = node->data.field_access_expr.struct_expr;
    TypeTableEntry *struct_type = get_expr_type(struct_expr);

    if (struct_type->id == TypeTableEntryIdArray) {
        Buf *name = node->data.field_access_expr.field_name;
        assert(buf_eql_str(name, "len"));
        return LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                struct_type->data.array.len, false);
    } else if (struct_type->id == TypeTableEntryIdStruct || (struct_type->id == TypeTableEntryIdPointer &&
               struct_type->data.pointer.child_type->id == TypeTableEntryIdStruct))
    {
        TypeTableEntry *type_entry;
        LLVMValueRef ptr = gen_field_ptr(g, node, &type_entry);
        if (is_lvalue || handle_is_ptr(type_entry)) {
            return ptr;
        } else {
            set_debug_source_node(g, node);
            return LLVMBuildLoad(g->builder, ptr, "");
        }
    } else if (struct_type->id == TypeTableEntryIdMetaType) {
        assert(!is_lvalue);
        TypeTableEntry *child_type = get_type_for_type_node(struct_expr);
        if (child_type->id == TypeTableEntryIdEnum) {
            return gen_enum_value_expr(g, node, child_type, nullptr);
        } else {
            zig_unreachable();
        }
    } else if (struct_type->id == TypeTableEntryIdNamespace) {
        VariableTableEntry *variable = get_resolved_expr(node)->variable;
        assert(variable);
        return gen_variable(g, node, variable);
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef gen_lvalue(CodeGen *g, AstNode *expr_node, AstNode *node,
        TypeTableEntry **out_type_entry)
{
    LLVMValueRef target_ref;

    if (node->type == NodeTypeSymbol) {
        VariableTableEntry *var = get_resolved_expr(node)->variable;
        assert(var);

        *out_type_entry = var->type;
        target_ref = var->value_ref;
    } else if (node->type == NodeTypeArrayAccessExpr) {
        TypeTableEntry *array_type = get_expr_type(node->data.array_access_expr.array_ref_expr);
        if (array_type->id == TypeTableEntryIdArray) {
            *out_type_entry = array_type->data.array.child_type;
            target_ref = gen_array_ptr(g, node);
        } else if (array_type->id == TypeTableEntryIdPointer) {
            *out_type_entry = array_type->data.pointer.child_type;
            target_ref = gen_array_ptr(g, node);
        } else if (array_type->id == TypeTableEntryIdStruct) {
            assert(array_type->data.structure.is_slice);
            *out_type_entry = array_type->data.structure.fields[0].type_entry->data.pointer.child_type;
            target_ref = gen_array_ptr(g, node);
        } else {
            zig_unreachable();
        }
    } else if (node->type == NodeTypeFieldAccessExpr) {
        AstNode *struct_expr_node = node->data.field_access_expr.struct_expr;
        TypeTableEntry *struct_type = get_expr_type(struct_expr_node);
        if (struct_type->id == TypeTableEntryIdNamespace) {
            target_ref = gen_field_access_expr(g, node, true);
            *out_type_entry = get_expr_type(node);
        } else {
            target_ref = gen_field_ptr(g, node, out_type_entry);
        }
    } else if (node->type == NodeTypePrefixOpExpr) {
        assert(node->data.prefix_op_expr.prefix_op == PrefixOpDereference);
        AstNode *target_expr = node->data.prefix_op_expr.primary_expr;
        TypeTableEntry *type_entry = get_expr_type(target_expr);
        assert(type_entry->id == TypeTableEntryIdPointer);
        *out_type_entry = type_entry->data.pointer.child_type;
        return gen_expr(g, target_expr);
    } else {
        zig_panic("bad assign target");
    }

    return target_ref;
}

static LLVMValueRef gen_overflow_op(CodeGen *g, TypeTableEntry *type_entry, AddSubMul op,
        LLVMValueRef val1, LLVMValueRef val2)
{
    LLVMValueRef fn_val = get_int_overflow_fn(g, type_entry, op);
    LLVMValueRef params[] = {
        val1,
        val2,
    };
    LLVMValueRef result_struct = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    LLVMValueRef result = LLVMBuildExtractValue(g->builder, result_struct, 0, "");
    LLVMValueRef overflow_bit = LLVMBuildExtractValue(g->builder, result_struct, 1, "");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "OverflowFail");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "OverflowOk");
    LLVMBuildCondBr(g->builder, overflow_bit, fail_block, ok_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_debug_safety_crash(g);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_overflow_shl_op(CodeGen *g, TypeTableEntry *type_entry,
        LLVMValueRef val1, LLVMValueRef val2)
{
    // for unsigned left shifting, we do the wrapping shift, then logically shift
    // right the same number of bits
    // if the values don't match, we have an overflow
    // for signed left shifting we do the same except arithmetic shift right

    assert(type_entry->id == TypeTableEntryIdInt);

    LLVMValueRef result = LLVMBuildShl(g->builder, val1, val2, "");
    LLVMValueRef orig_val;
    if (type_entry->data.integral.is_signed) {
        orig_val = LLVMBuildAShr(g->builder, result, val2, "");
    } else {
        orig_val = LLVMBuildLShr(g->builder, result, val2, "");
    }
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, orig_val, "");

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "OverflowOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "OverflowFail");
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_debug_safety_crash(g);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_prefix_op_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypePrefixOpExpr);
    assert(node->data.prefix_op_expr.primary_expr);

    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;
    TypeTableEntry *expr_type = get_expr_type(expr_node);

    PrefixOp op = node->data.prefix_op_expr.prefix_op;

    switch (op) {
        case PrefixOpInvalid:
            zig_unreachable();
        case PrefixOpNegation:
        case PrefixOpNegationWrap:
            {
                LLVMValueRef expr = gen_expr(g, expr_node);
                set_debug_source_node(g, node);
                if (expr_type->id == TypeTableEntryIdFloat) {
                    return LLVMBuildFNeg(g->builder, expr, "");
                } else if (expr_type->id == TypeTableEntryIdInt) {
                    if (op == PrefixOpNegationWrap) {
                        return LLVMBuildNeg(g->builder, expr, "");
                    } else if (want_debug_safety(g, expr_node)) {
                        LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(expr));
                        return gen_overflow_op(g, expr_type, AddSubMulSub, zero, expr);
                    } else if (expr_type->data.integral.is_signed) {
                        return LLVMBuildNSWNeg(g->builder, expr, "");
                    } else {
                        return LLVMBuildNUWNeg(g->builder, expr, "");
                    }
                } else {
                    zig_unreachable();
                }
            }
        case PrefixOpBoolNot:
            {
                LLVMValueRef expr = gen_expr(g, expr_node);
                LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(expr));
                set_debug_source_node(g, node);
                return LLVMBuildICmp(g->builder, LLVMIntEQ, expr, zero, "");
            }
        case PrefixOpBinNot:
            {
                LLVMValueRef expr = gen_expr(g, expr_node);
                set_debug_source_node(g, node);
                return LLVMBuildNot(g->builder, expr, "");
            }
        case PrefixOpAddressOf:
        case PrefixOpConstAddressOf:
            {
                TypeTableEntry *lvalue_type;
                return gen_lvalue(g, node, expr_node, &lvalue_type);
            }

        case PrefixOpDereference:
            {
                LLVMValueRef expr = gen_expr(g, expr_node);
                assert(expr_type->id == TypeTableEntryIdPointer);
                if (!type_has_bits(expr_type)) {
                    return nullptr;
                } else {
                    TypeTableEntry *child_type = expr_type->data.pointer.child_type;
                    return get_handle_value(g, node, expr, child_type);
                }
            }
        case PrefixOpMaybe:
            {
                zig_panic("TODO codegen PrefixOpMaybe");
            }
        case PrefixOpError:
            {
                zig_panic("TODO codegen PrefixOpError");
            }
        case PrefixOpUnwrapError:
            {
                LLVMValueRef expr_val = gen_expr(g, expr_node);
                TypeTableEntry *expr_type = get_expr_type(expr_node);
                assert(expr_type->id == TypeTableEntryIdErrorUnion);
                TypeTableEntry *child_type = expr_type->data.error.child_type;

                if (want_debug_safety(g, node)) {
                    LLVMValueRef err_val;
                    if (type_has_bits(child_type)) {
                        set_debug_source_node(g, node);
                        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, expr_val, 0, "");
                        err_val = LLVMBuildLoad(g->builder, err_val_ptr, "");
                    } else {
                        err_val = expr_val;
                    }
                    set_debug_source_node(g, node);
                    LLVMValueRef zero = LLVMConstNull(g->err_tag_type->type_ref);
                    LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, zero, "");
                    LLVMBasicBlockRef err_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapErrError");
                    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapErrOk");
                    LLVMBuildCondBr(g->builder, cond_val, ok_block, err_block);

                    LLVMPositionBuilderAtEnd(g->builder, err_block);
                    gen_debug_safety_crash(g);

                    LLVMPositionBuilderAtEnd(g->builder, ok_block);
                }

                if (type_has_bits(child_type)) {
                    LLVMValueRef child_val_ptr = LLVMBuildStructGEP(g->builder, expr_val, 1, "");
                    return get_handle_value(g, expr_node, child_val_ptr, child_type);
                } else {
                    return nullptr;
                }
            }
        case PrefixOpUnwrapMaybe:
            {
                LLVMValueRef expr_val = gen_expr(g, expr_node);

                TypeTableEntry *expr_type = get_expr_type(expr_node);
                assert(expr_type->id == TypeTableEntryIdMaybe);
                TypeTableEntry *child_type = expr_type->data.maybe.child_type;

                if (want_debug_safety(g, node)) {
                    set_debug_source_node(g, node);
                    LLVMValueRef cond_val;
                    if (child_type->id == TypeTableEntryIdPointer ||
                        child_type->id == TypeTableEntryIdFn)
                    {
                        cond_val = LLVMBuildICmp(g->builder, LLVMIntNE, expr_val,
                                LLVMConstNull(child_type->type_ref), "");
                    } else {
                        LLVMValueRef maybe_null_ptr = LLVMBuildStructGEP(g->builder, expr_val, 1, "");
                        cond_val = LLVMBuildLoad(g->builder, maybe_null_ptr, "");
                    }

                    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapMaybeOk");
                    LLVMBasicBlockRef null_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapMaybeNull");
                    LLVMBuildCondBr(g->builder, cond_val, ok_block, null_block);

                    LLVMPositionBuilderAtEnd(g->builder, null_block);
                    gen_debug_safety_crash(g);

                    LLVMPositionBuilderAtEnd(g->builder, ok_block);
                }


                if (child_type->id == TypeTableEntryIdPointer ||
                    child_type->id == TypeTableEntryIdFn)
                {
                    return expr_val;
                } else {
                    set_debug_source_node(g, node);
                    LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, expr_val, 0, "");
                    return get_handle_value(g, node, maybe_field_ptr, child_type);
                }
            }
    }
    zig_unreachable();
}

static LLVMValueRef gen_div(CodeGen *g, AstNode *source_node, LLVMValueRef val1, LLVMValueRef val2,
        TypeTableEntry *type_entry, bool exact)
{
    set_debug_source_node(g, source_node);

    if (want_debug_safety(g, source_node)) {
        LLVMValueRef zero = LLVMConstNull(type_entry->type_ref);
        LLVMValueRef is_zero_bit;
        if (type_entry->id == TypeTableEntryIdInt) {
            is_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");
        } else if (type_entry->id == TypeTableEntryIdFloat) {
            is_zero_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, val2, zero, "");
        } else {
            zig_unreachable();
        }
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "DivZeroOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "DivZeroFail");
        LLVMBuildCondBr(g->builder, is_zero_bit, fail_block, ok_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_debug_safety_crash(g);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    if (type_entry->id == TypeTableEntryIdFloat) {
        assert(!exact);
        return LLVMBuildFDiv(g->builder, val1, val2, "");
    }

    assert(type_entry->id == TypeTableEntryIdInt);

    if (exact) {
        if (want_debug_safety(g, source_node)) {
            LLVMValueRef remainder_val;
            if (type_entry->data.integral.is_signed) {
                remainder_val = LLVMBuildSRem(g->builder, val1, val2, "");
            } else {
                remainder_val = LLVMBuildURem(g->builder, val1, val2, "");
            }
            LLVMValueRef zero = LLVMConstNull(type_entry->type_ref);
            LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, remainder_val, zero, "");

            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "DivExactOk");
            LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "DivExactFail");
            LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

            LLVMPositionBuilderAtEnd(g->builder, fail_block);
            gen_debug_safety_crash(g);

            LLVMPositionBuilderAtEnd(g->builder, ok_block);
        }
        if (type_entry->data.integral.is_signed) {
            return LLVMBuildExactSDiv(g->builder, val1, val2, "");
        } else {
            return ZigLLVMBuildExactUDiv(g->builder, val1, val2, "");
        }
    } else {
        if (type_entry->data.integral.is_signed) {
            return LLVMBuildSDiv(g->builder, val1, val2, "");
        } else {
            return LLVMBuildUDiv(g->builder, val1, val2, "");
        }
    }
}

static LLVMValueRef gen_arithmetic_bin_op(CodeGen *g, AstNode *source_node,
    LLVMValueRef val1, LLVMValueRef val2,
    TypeTableEntry *op1_type, TypeTableEntry *op2_type,
    BinOpType bin_op)
{
    assert(op1_type == op2_type);

    switch (bin_op) {
        case BinOpTypeBinOr:
        case BinOpTypeAssignBitOr:
            set_debug_source_node(g, source_node);
            return LLVMBuildOr(g->builder, val1, val2, "");
        case BinOpTypeBinXor:
        case BinOpTypeAssignBitXor:
            set_debug_source_node(g, source_node);
            return LLVMBuildXor(g->builder, val1, val2, "");
        case BinOpTypeBinAnd:
        case BinOpTypeAssignBitAnd:
            set_debug_source_node(g, source_node);
            return LLVMBuildAnd(g->builder, val1, val2, "");
        case BinOpTypeBitShiftLeft:
        case BinOpTypeBitShiftLeftWrap:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftLeftWrap:
            {
                set_debug_source_node(g, source_node);
                assert(op1_type->id == TypeTableEntryIdInt);
                bool is_wrapping = (bin_op == BinOpTypeBitShiftLeftWrap) ||
                    (bin_op == BinOpTypeAssignBitShiftLeftWrap);
                if (is_wrapping) {
                    return LLVMBuildShl(g->builder, val1, val2, "");
                } else if (want_debug_safety(g, source_node)) {
                    return gen_overflow_shl_op(g, op1_type, val1, val2);
                } else if (op1_type->data.integral.is_signed) {
                    return ZigLLVMBuildNSWShl(g->builder, val1, val2, "");
                } else {
                    return ZigLLVMBuildNUWShl(g->builder, val1, val2, "");
                }
            }
        case BinOpTypeBitShiftRight:
        case BinOpTypeAssignBitShiftRight:
            assert(op1_type->id == TypeTableEntryIdInt);
            assert(op2_type->id == TypeTableEntryIdInt);

            set_debug_source_node(g, source_node);
            if (op1_type->data.integral.is_signed) {
                return LLVMBuildAShr(g->builder, val1, val2, "");
            } else {
                return LLVMBuildLShr(g->builder, val1, val2, "");
            }
        case BinOpTypeAdd:
        case BinOpTypeAddWrap:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignPlusWrap:
            set_debug_source_node(g, source_node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFAdd(g->builder, val1, val2, "");
            } else if (op1_type->id == TypeTableEntryIdInt) {
                bool is_wrapping = (bin_op == BinOpTypeAddWrap) || (bin_op == BinOpTypeAssignPlusWrap);
                if (is_wrapping) {
                    return LLVMBuildAdd(g->builder, val1, val2, "");
                } else if (want_debug_safety(g, source_node)) {
                    return gen_overflow_op(g, op1_type, AddSubMulAdd, val1, val2);
                } else if (op1_type->data.integral.is_signed) {
                    return LLVMBuildNSWAdd(g->builder, val1, val2, "");
                } else {
                    return LLVMBuildNUWAdd(g->builder, val1, val2, "");
                }
            } else {
                zig_unreachable();
            }
        case BinOpTypeSub:
        case BinOpTypeSubWrap:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignMinusWrap:
            set_debug_source_node(g, source_node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFSub(g->builder, val1, val2, "");
            } else if (op1_type->id == TypeTableEntryIdInt) {
                bool is_wrapping = (bin_op == BinOpTypeSubWrap || bin_op == BinOpTypeAssignMinusWrap);
                if (is_wrapping) {
                    return LLVMBuildSub(g->builder, val1, val2, "");
                } else if (want_debug_safety(g, source_node)) {
                    return gen_overflow_op(g, op1_type, AddSubMulSub, val1, val2);
                } else if (op1_type->data.integral.is_signed) {
                    return LLVMBuildNSWSub(g->builder, val1, val2, "");
                } else {
                    return LLVMBuildNUWSub(g->builder, val1, val2, "");
                }
            } else {
                zig_unreachable();
            }
        case BinOpTypeMult:
        case BinOpTypeMultWrap:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignTimesWrap:
            set_debug_source_node(g, source_node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFMul(g->builder, val1, val2, "");
            } else if (op1_type->id == TypeTableEntryIdInt) {
                bool is_wrapping = (bin_op == BinOpTypeMultWrap || bin_op == BinOpTypeAssignTimesWrap);
                if (is_wrapping) {
                    return LLVMBuildMul(g->builder, val1, val2, "");
                } else if (want_debug_safety(g, source_node)) {
                    return gen_overflow_op(g, op1_type, AddSubMulMul, val1, val2);
                } else if (op1_type->data.integral.is_signed) {
                    return LLVMBuildNSWMul(g->builder, val1, val2, "");
                } else {
                    return LLVMBuildNUWMul(g->builder, val1, val2, "");
                }
            } else {
                zig_unreachable();
            }
        case BinOpTypeDiv:
        case BinOpTypeAssignDiv:
            return gen_div(g, source_node, val1, val2, op1_type, false);
        case BinOpTypeMod:
        case BinOpTypeAssignMod:
            set_debug_source_node(g, source_node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFRem(g->builder, val1, val2, "");
            } else {
                assert(op1_type->id == TypeTableEntryIdInt);
                if (op1_type->data.integral.is_signed) {
                    return LLVMBuildSRem(g->builder, val1, val2, "");
                } else {
                    return LLVMBuildURem(g->builder, val1, val2, "");
                }
            }
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
        case BinOpTypeInvalid:
        case BinOpTypeAssign:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
        case BinOpTypeUnwrapMaybe:
        case BinOpTypeArrayCat:
        case BinOpTypeArrayMult:
            zig_unreachable();
    }
    zig_unreachable();
}
static LLVMValueRef gen_arithmetic_bin_op_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    TypeTableEntry *op1_type = get_expr_type(node->data.bin_op_expr.op1);
    TypeTableEntry *op2_type = get_expr_type(node->data.bin_op_expr.op2);
    return gen_arithmetic_bin_op(g, node, val1, val2, op1_type, op2_type, node->data.bin_op_expr.bin_op);

}

static LLVMIntPredicate cmp_op_to_int_predicate(BinOpType cmp_op, bool is_signed) {
    switch (cmp_op) {
        case BinOpTypeCmpEq:
            return LLVMIntEQ;
        case BinOpTypeCmpNotEq:
            return LLVMIntNE;
        case BinOpTypeCmpLessThan:
            return is_signed ? LLVMIntSLT : LLVMIntULT;
        case BinOpTypeCmpGreaterThan:
            return is_signed ? LLVMIntSGT : LLVMIntUGT;
        case BinOpTypeCmpLessOrEq:
            return is_signed ? LLVMIntSLE : LLVMIntULE;
        case BinOpTypeCmpGreaterOrEq:
            return is_signed ? LLVMIntSGE : LLVMIntUGE;
        default:
            zig_unreachable();
    }
}

static LLVMRealPredicate cmp_op_to_real_predicate(BinOpType cmp_op) {
    switch (cmp_op) {
        case BinOpTypeCmpEq:
            return LLVMRealOEQ;
        case BinOpTypeCmpNotEq:
            return LLVMRealONE;
        case BinOpTypeCmpLessThan:
            return LLVMRealOLT;
        case BinOpTypeCmpGreaterThan:
            return LLVMRealOGT;
        case BinOpTypeCmpLessOrEq:
            return LLVMRealOLE;
        case BinOpTypeCmpGreaterOrEq:
            return LLVMRealOGE;
        default:
            zig_unreachable();
    }
}

static LLVMValueRef gen_cmp_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    TypeTableEntry *op1_type = get_expr_type(node->data.bin_op_expr.op1);
    TypeTableEntry *op2_type = get_expr_type(node->data.bin_op_expr.op2);
    assert(op1_type == op2_type);

    set_debug_source_node(g, node);
    if (op1_type->id == TypeTableEntryIdFloat) {
        LLVMRealPredicate pred = cmp_op_to_real_predicate(node->data.bin_op_expr.bin_op);
        return LLVMBuildFCmp(g->builder, pred, val1, val2, "");
    } else if (op1_type->id == TypeTableEntryIdInt) {
        LLVMIntPredicate pred = cmp_op_to_int_predicate(node->data.bin_op_expr.bin_op,
                op1_type->data.integral.is_signed);
        return LLVMBuildICmp(g->builder, pred, val1, val2, "");
    } else if (op1_type->id == TypeTableEntryIdEnum) {
        if (op1_type->data.enumeration.gen_field_count == 0) {
            LLVMIntPredicate pred = cmp_op_to_int_predicate(node->data.bin_op_expr.bin_op, false);
            return LLVMBuildICmp(g->builder, pred, val1, val2, "");
        } else {
            zig_unreachable();
        }
    } else if (op1_type->id == TypeTableEntryIdPureError ||
               op1_type->id == TypeTableEntryIdPointer ||
               op1_type->id == TypeTableEntryIdBool)
    {
        LLVMIntPredicate pred = cmp_op_to_int_predicate(node->data.bin_op_expr.bin_op, false);
        return LLVMBuildICmp(g->builder, pred, val1, val2, "");
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef gen_bool_and_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMBasicBlockRef post_val1_block = LLVMGetInsertBlock(g->builder);

    // block for when val1 == true
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolAndTrue");
    // block for when val1 == false (don't even evaluate the second part)
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolAndFalse");

    set_debug_source_node(g, node);
    LLVMBuildCondBr(g->builder, val1, true_block, false_block);

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);
    LLVMBasicBlockRef post_val2_block = LLVMGetInsertBlock(g->builder);

    set_debug_source_node(g, node);
    LLVMBuildBr(g->builder, false_block);

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    set_debug_source_node(g, node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef incoming_values[2] = {val1, val2};
    LLVMBasicBlockRef incoming_blocks[2] = {post_val1_block, post_val2_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_bool_or_expr(CodeGen *g, AstNode *expr_node) {
    assert(expr_node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, expr_node->data.bin_op_expr.op1);
    LLVMBasicBlockRef post_val1_block = LLVMGetInsertBlock(g->builder);

    // block for when val1 == false
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolOrFalse");
    // block for when val1 == true (don't even evaluate the second part)
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolOrTrue");

    set_debug_source_node(g, expr_node);
    LLVMBuildCondBr(g->builder, val1, true_block, false_block);

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    LLVMValueRef val2 = gen_expr(g, expr_node->data.bin_op_expr.op2);

    LLVMBasicBlockRef post_val2_block = LLVMGetInsertBlock(g->builder);

    set_debug_source_node(g, expr_node);
    LLVMBuildBr(g->builder, true_block);

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    set_debug_source_node(g, expr_node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef incoming_values[2] = {val1, val2};
    LLVMBasicBlockRef incoming_blocks[2] = {post_val1_block, post_val2_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_struct_memcpy(CodeGen *g, AstNode *source_node, LLVMValueRef src, LLVMValueRef dest,
        TypeTableEntry *type_entry)
{
    assert(handle_is_ptr(type_entry));

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    set_debug_source_node(g, source_node);
    LLVMValueRef src_ptr = LLVMBuildBitCast(g->builder, src, ptr_u8, "");
    LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, dest, ptr_u8, "");

    TypeTableEntry *usize = g->builtin_types.entry_usize;
    uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, type_entry->type_ref);
    uint64_t align_bytes = get_memcpy_align(g, type_entry);
    assert(size_bytes > 0);
    assert(align_bytes > 0);

    LLVMValueRef params[] = {
        dest_ptr, // dest pointer
        src_ptr, // source pointer
        LLVMConstInt(usize->type_ref, size_bytes, false),
        LLVMConstInt(LLVMInt32Type(), align_bytes, false),
        LLVMConstNull(LLVMInt1Type()), // is volatile
    };

    return LLVMBuildCall(g->builder, g->memcpy_fn_val, params, 5, "");
}

static LLVMValueRef gen_assign_raw(CodeGen *g, AstNode *source_node, BinOpType bin_op,
        LLVMValueRef target_ref, LLVMValueRef value,
        TypeTableEntry *op1_type, TypeTableEntry *op2_type)
{
    if (!type_has_bits(op1_type)) {
        return nullptr;
    }
    if (handle_is_ptr(op1_type)) {
        assert(op1_type == op2_type);
        assert(bin_op == BinOpTypeAssign);

        return gen_struct_memcpy(g, source_node, value, target_ref, op1_type);
    }

    if (bin_op != BinOpTypeAssign) {
        assert(source_node->type == NodeTypeBinOpExpr);
        set_debug_source_node(g, source_node->data.bin_op_expr.op1);
        LLVMValueRef left_value = LLVMBuildLoad(g->builder, target_ref, "");

        value = gen_arithmetic_bin_op(g, source_node, left_value, value, op1_type, op2_type, bin_op);
    }

    set_debug_source_node(g, source_node);
    LLVMBuildStore(g->builder, value, target_ref);
    return nullptr;
}

static LLVMValueRef gen_assign_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    AstNode *lhs_node = node->data.bin_op_expr.op1;

    TypeTableEntry *op1_type;

    LLVMValueRef target_ref = gen_lvalue(g, node, lhs_node, &op1_type);

    TypeTableEntry *op2_type = get_expr_type(node->data.bin_op_expr.op2);

    LLVMValueRef value = gen_expr(g, node->data.bin_op_expr.op2);

    gen_assign_raw(g, node, node->data.bin_op_expr.bin_op, target_ref, value, op1_type, op2_type);
    return nullptr;
}

static LLVMValueRef gen_unwrap_maybe(CodeGen *g, AstNode *node, LLVMValueRef maybe_struct_ref) {
    TypeTableEntry *type_entry = get_expr_type(node);
    assert(type_entry->id == TypeTableEntryIdMaybe);
    TypeTableEntry *child_type = type_entry->data.maybe.child_type;
    if (child_type->id == TypeTableEntryIdPointer ||
        child_type->id == TypeTableEntryIdFn)
    {
        return maybe_struct_ref;
    } else {
        set_debug_source_node(g, node);
        LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, maybe_struct_ref, 0, "");
        return get_handle_value(g, node, maybe_field_ptr, child_type);
    }
}

static LLVMValueRef gen_unwrap_maybe_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);
    assert(node->data.bin_op_expr.bin_op == BinOpTypeUnwrapMaybe);

    AstNode *op1_node = node->data.bin_op_expr.op1;
    AstNode *op2_node = node->data.bin_op_expr.op2;

    LLVMValueRef maybe_struct_ref = gen_expr(g, op1_node);

    TypeTableEntry *maybe_type = get_expr_type(op1_node);
    assert(maybe_type->id == TypeTableEntryIdMaybe);
    TypeTableEntry *child_type = maybe_type->data.maybe.child_type;

    LLVMValueRef cond_value;
    if (child_type->id == TypeTableEntryIdPointer ||
        child_type->id == TypeTableEntryIdFn)
    {
        cond_value = LLVMBuildICmp(g->builder, LLVMIntNE, maybe_struct_ref,
                LLVMConstNull(child_type->type_ref), "");
    } else {
        set_debug_source_node(g, node);
        LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, maybe_struct_ref, 1, "");
        cond_value = LLVMBuildLoad(g->builder, maybe_field_ptr, "");
    }

    LLVMBasicBlockRef non_null_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeNonNull");
    LLVMBasicBlockRef null_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeNull");
    LLVMBasicBlockRef end_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeEnd");

    bool null_reachable = get_expr_type(op2_node)->id != TypeTableEntryIdUnreachable;

    LLVMBuildCondBr(g->builder, cond_value, non_null_block, null_block);

    LLVMPositionBuilderAtEnd(g->builder, non_null_block);
    LLVMValueRef non_null_result = gen_unwrap_maybe(g, op1_node, maybe_struct_ref);
    set_debug_source_node(g, node);
    LLVMBuildBr(g->builder, end_block);
    LLVMBasicBlockRef post_non_null_result_block = LLVMGetInsertBlock(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, null_block);
    LLVMValueRef null_result = gen_expr(g, op2_node);
    if (null_reachable) {
        set_debug_source_node(g, node);
        LLVMBuildBr(g->builder, end_block);
    }
    LLVMBasicBlockRef post_null_result_block = LLVMGetInsertBlock(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, end_block);
    if (null_reachable) {
        set_debug_source_node(g, node);
        LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMTypeOf(non_null_result), "");
        LLVMValueRef incoming_values[2] = {non_null_result, null_result};
        LLVMBasicBlockRef incoming_blocks[2] = {post_non_null_result_block, post_null_result_block};
        LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);
        return phi;
    } else {
        return non_null_result;
    }

    return nullptr;
}

static LLVMValueRef gen_bin_op_expr(CodeGen *g, AstNode *node) {
    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeInvalid:
        case BinOpTypeArrayCat:
        case BinOpTypeArrayMult:
            zig_unreachable();
        case BinOpTypeAssign:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignTimesWrap:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignPlusWrap:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignMinusWrap:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftLeftWrap:
        case BinOpTypeAssignBitShiftRight:
        case BinOpTypeAssignBitAnd:
        case BinOpTypeAssignBitXor:
        case BinOpTypeAssignBitOr:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            return gen_assign_expr(g, node);
        case BinOpTypeBoolOr:
            return gen_bool_or_expr(g, node);
        case BinOpTypeBoolAnd:
            return gen_bool_and_expr(g, node);
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
            return gen_cmp_expr(g, node);
        case BinOpTypeUnwrapMaybe:
            return gen_unwrap_maybe_expr(g, node);
        case BinOpTypeBinOr:
        case BinOpTypeBinXor:
        case BinOpTypeBinAnd:
        case BinOpTypeBitShiftLeft:
        case BinOpTypeBitShiftLeftWrap:
        case BinOpTypeBitShiftRight:
        case BinOpTypeAdd:
        case BinOpTypeAddWrap:
        case BinOpTypeSub:
        case BinOpTypeSubWrap:
        case BinOpTypeMult:
        case BinOpTypeMultWrap:
        case BinOpTypeDiv:
        case BinOpTypeMod:
            return gen_arithmetic_bin_op_expr(g, node);
    }
    zig_unreachable();
}

static LLVMValueRef gen_unwrap_err_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeUnwrapErrorExpr);

    AstNode *op1 = node->data.unwrap_err_expr.op1;
    AstNode *op2 = node->data.unwrap_err_expr.op2;
    VariableTableEntry *var = node->data.unwrap_err_expr.var;

    LLVMValueRef expr_val = gen_expr(g, op1);
    TypeTableEntry *expr_type = get_expr_type(op1);
    TypeTableEntry *op2_type = get_expr_type(op2);
    assert(expr_type->id == TypeTableEntryIdErrorUnion);
    TypeTableEntry *child_type = expr_type->data.error.child_type;
    LLVMValueRef err_val;
    set_debug_source_node(g, node);
    if (handle_is_ptr(expr_type)) {
        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, expr_val, 0, "");
        err_val = LLVMBuildLoad(g->builder, err_val_ptr, "");
    } else {
        err_val = expr_val;
    }
    LLVMValueRef zero = LLVMConstNull(g->err_tag_type->type_ref);
    LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, zero, "");

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapErrOk");
    LLVMBasicBlockRef err_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapErrError");
    LLVMBasicBlockRef end_block;
    bool err_reachable = op2_type->id != TypeTableEntryIdUnreachable;
    bool have_end_block = err_reachable && type_has_bits(child_type);
    if (have_end_block) {
        end_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapErrEnd");
    }

    LLVMBuildCondBr(g->builder, cond_val, ok_block, err_block);

    LLVMPositionBuilderAtEnd(g->builder, err_block);
    if (var) {
        LLVMBuildStore(g->builder, err_val, var->value_ref);
    }
    LLVMValueRef err_result = gen_expr(g, op2);
    set_debug_source_node(g, node);
    if (have_end_block) {
        LLVMBuildBr(g->builder, end_block);
    } else if (err_reachable) {
        LLVMBuildBr(g->builder, ok_block);
    }

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    if (!type_has_bits(child_type)) {
        return nullptr;
    }
    LLVMValueRef child_val_ptr = LLVMBuildStructGEP(g->builder, expr_val, 1, "");
    LLVMValueRef child_val = get_handle_value(g, node, child_val_ptr, child_type);

    if (!have_end_block) {
        return child_val;
    }

    LLVMBuildBr(g->builder, end_block);

    LLVMPositionBuilderAtEnd(g->builder, end_block);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMTypeOf(err_result), "");
    LLVMValueRef incoming_values[2] = {child_val, err_result};
    LLVMBasicBlockRef incoming_blocks[2] = {ok_block, err_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);
    return phi;
}

static void gen_defers_for_block(CodeGen *g, BlockContext *inner_block, BlockContext *outer_block,
        bool gen_error_defers, bool gen_maybe_defers)
{
    while (inner_block != outer_block) {
        if (inner_block->node->type == NodeTypeDefer &&
           ((inner_block->node->data.defer.kind == ReturnKindUnconditional) ||
            (gen_error_defers && inner_block->node->data.defer.kind == ReturnKindError) ||
            (gen_maybe_defers && inner_block->node->data.defer.kind == ReturnKindMaybe)))
        {
            gen_expr(g, inner_block->node->data.defer.expr);
        }
        inner_block = inner_block->parent;
    }
}

static int get_conditional_defer_count(BlockContext *inner_block, BlockContext *outer_block) {
    int result = 0;
    while (inner_block != outer_block) {
        if (inner_block->node->type == NodeTypeDefer &&
           (inner_block->node->data.defer.kind == ReturnKindError ||
            inner_block->node->data.defer.kind == ReturnKindMaybe))
        {
            result += 1;
        }
        inner_block = inner_block->parent;
    }
    return result;
}

static LLVMValueRef gen_return(CodeGen *g, AstNode *source_node, LLVMValueRef value, ReturnKnowledge rk) {
    BlockContext *defer_inner_block = source_node->block_context;
    BlockContext *defer_outer_block = source_node->block_context->fn_entry->fn_def_node->block_context;
    if (rk == ReturnKnowledgeUnknown) {
        if (get_conditional_defer_count(defer_inner_block, defer_outer_block) > 0) {
            // generate branching code that checks the return value and generates defers
            // if the return value is error
            zig_panic("TODO");
        }
    } else if (rk != ReturnKnowledgeSkipDefers) {
        gen_defers_for_block(g, defer_inner_block, defer_outer_block,
                rk == ReturnKnowledgeKnownError, rk == ReturnKnowledgeKnownNull);
    }

    TypeTableEntry *return_type = g->cur_fn->type_entry->data.fn.fn_type_id.return_type;
    bool is_extern = g->cur_fn->type_entry->data.fn.fn_type_id.is_extern;
    if (handle_is_ptr(return_type)) {
        if (is_extern) {
            set_debug_source_node(g, source_node);
            LLVMValueRef by_val_value = LLVMBuildLoad(g->builder, value, "");
            LLVMBuildRet(g->builder, by_val_value);
        } else {
            assert(g->cur_ret_ptr);
            gen_assign_raw(g, source_node, BinOpTypeAssign, g->cur_ret_ptr, value, return_type, return_type);
            set_debug_source_node(g, source_node);
            LLVMBuildRetVoid(g->builder);
        }
    } else {
        set_debug_source_node(g, source_node);
        LLVMBuildRet(g->builder, value);
    }
    return nullptr;
}

static LLVMValueRef gen_return_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeReturnExpr);
    AstNode *param_node = node->data.return_expr.expr;
    assert(param_node);
    LLVMValueRef value = gen_expr(g, param_node);
    TypeTableEntry *value_type = get_expr_type(param_node);

    switch (node->data.return_expr.kind) {
        case ReturnKindUnconditional:
            {
                Expr *expr = get_resolved_expr(param_node);
                if (expr->const_val.ok) {
                    if (value_type->id == TypeTableEntryIdErrorUnion) {
                        if (expr->const_val.data.x_err.err) {
                            expr->return_knowledge = ReturnKnowledgeKnownError;
                        } else {
                            expr->return_knowledge = ReturnKnowledgeKnownNonError;
                        }
                    } else if (value_type->id == TypeTableEntryIdMaybe) {
                        if (expr->const_val.data.x_maybe) {
                            expr->return_knowledge = ReturnKnowledgeKnownNonNull;
                        } else {
                            expr->return_knowledge = ReturnKnowledgeKnownNull;
                        }
                    }
                }
                return gen_return(g, node, value, expr->return_knowledge);
            }
        case ReturnKindError:
            {
                assert(value_type->id == TypeTableEntryIdErrorUnion);
                TypeTableEntry *child_type = value_type->data.error.child_type;

                LLVMBasicBlockRef return_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "ErrRetReturn");
                LLVMBasicBlockRef continue_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "ErrRetContinue");

                set_debug_source_node(g, node);
                LLVMValueRef err_val;
                if (type_has_bits(child_type)) {
                    LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, value, 0, "");
                    err_val = LLVMBuildLoad(g->builder, err_val_ptr, "");
                } else {
                    err_val = value;
                }
                LLVMValueRef zero = LLVMConstNull(g->err_tag_type->type_ref);
                LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, zero, "");
                LLVMBuildCondBr(g->builder, cond_val, continue_block, return_block);

                LLVMPositionBuilderAtEnd(g->builder, return_block);
                TypeTableEntry *return_type = g->cur_fn->type_entry->data.fn.fn_type_id.return_type;
                if (return_type->id == TypeTableEntryIdPureError) {
                    gen_return(g, node, err_val, ReturnKnowledgeKnownError);
                } else if (return_type->id == TypeTableEntryIdErrorUnion) {
                    if (type_has_bits(return_type->data.error.child_type)) {
                        assert(g->cur_ret_ptr);

                        set_debug_source_node(g, node);
                        LLVMValueRef tag_ptr = LLVMBuildStructGEP(g->builder, g->cur_ret_ptr, 0, "");
                        LLVMBuildStore(g->builder, err_val, tag_ptr);
                        LLVMBuildRetVoid(g->builder);
                    } else {
                        gen_return(g, node, err_val, ReturnKnowledgeKnownError);
                    }
                } else {
                    zig_unreachable();
                }

                LLVMPositionBuilderAtEnd(g->builder, continue_block);
                if (type_has_bits(child_type)) {
                    set_debug_source_node(g, node);
                    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, value, 1, "");
                    return get_handle_value(g, node, val_ptr, child_type);
                } else {
                    return nullptr;
                }
            }
        case ReturnKindMaybe:
            {
                assert(value_type->id == TypeTableEntryIdMaybe);
                TypeTableEntry *child_type = value_type->data.maybe.child_type;

                LLVMBasicBlockRef return_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeRetReturn");
                LLVMBasicBlockRef continue_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeRetContinue");

                set_debug_source_node(g, node);
                LLVMValueRef maybe_val_ptr = LLVMBuildStructGEP(g->builder, value, 1, "");
                LLVMValueRef is_non_null = LLVMBuildLoad(g->builder, maybe_val_ptr, "");

                LLVMValueRef zero = LLVMConstNull(LLVMInt1Type());
                LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntNE, is_non_null, zero, "");
                LLVMBuildCondBr(g->builder, cond_val, continue_block, return_block);

                LLVMPositionBuilderAtEnd(g->builder, return_block);
                TypeTableEntry *return_type = g->cur_fn->type_entry->data.fn.fn_type_id.return_type;
                assert(return_type->id == TypeTableEntryIdMaybe);
                if (handle_is_ptr(return_type)) {
                    assert(g->cur_ret_ptr);

                    set_debug_source_node(g, node);
                    LLVMValueRef maybe_bit_ptr = LLVMBuildStructGEP(g->builder, g->cur_ret_ptr, 1, "");
                    LLVMBuildStore(g->builder, zero, maybe_bit_ptr);
                    LLVMBuildRetVoid(g->builder);
                } else {
                    LLVMValueRef ret_zero_value = LLVMConstNull(return_type->type_ref);
                    gen_return(g, node, ret_zero_value, ReturnKnowledgeKnownNull);
                }

                LLVMPositionBuilderAtEnd(g->builder, continue_block);
                if (type_has_bits(child_type)) {
                    set_debug_source_node(g, node);
                    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, value, 0, "");
                    return get_handle_value(g, node, val_ptr, child_type);
                } else {
                    return nullptr;
                }
            }
    }
    zig_unreachable();
}

static LLVMValueRef gen_if_bool_expr_raw(CodeGen *g, AstNode *source_node, LLVMValueRef cond_value,
        AstNode *then_node, AstNode *else_node)
{
    assert(then_node);
    assert(else_node);

    TypeTableEntry *then_type = get_expr_type(then_node);
    TypeTableEntry *else_type = get_expr_type(else_node);

    bool use_then_value = type_has_bits(then_type);
    bool use_else_value = type_has_bits(else_type);

    LLVMBasicBlockRef then_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "Then");
    LLVMBasicBlockRef else_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "Else");

    LLVMBasicBlockRef endif_block;
    bool then_endif_reachable = then_type->id != TypeTableEntryIdUnreachable;
    bool else_endif_reachable = else_type->id != TypeTableEntryIdUnreachable;
    if (then_endif_reachable || else_endif_reachable) {
        endif_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "EndIf");
    }

    set_debug_source_node(g, source_node);
    LLVMBuildCondBr(g->builder, cond_value, then_block, else_block);

    LLVMPositionBuilderAtEnd(g->builder, then_block);
    LLVMValueRef then_expr_result = gen_expr(g, then_node);
    if (then_endif_reachable) {
        clear_debug_source_node(g);
        LLVMBuildBr(g->builder, endif_block);
    }
    LLVMBasicBlockRef after_then_block = LLVMGetInsertBlock(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, else_block);
    LLVMValueRef else_expr_result = gen_expr(g, else_node);
    if (else_endif_reachable) {
        clear_debug_source_node(g);
        LLVMBuildBr(g->builder, endif_block);
    }
    LLVMBasicBlockRef after_else_block = LLVMGetInsertBlock(g->builder);

    if (then_endif_reachable || else_endif_reachable) {
        LLVMPositionBuilderAtEnd(g->builder, endif_block);
        if (use_then_value && use_else_value) {
            set_debug_source_node(g, source_node);
            LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMTypeOf(then_expr_result), "");
            LLVMValueRef incoming_values[2] = {then_expr_result, else_expr_result};
            LLVMBasicBlockRef incoming_blocks[2] = {after_then_block, after_else_block};
            LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);
            return phi;
        } else if (use_then_value) {
            return then_expr_result;
        } else if (use_else_value) {
            return else_expr_result;
        }
    }

    return nullptr;
}

static LLVMValueRef gen_if_bool_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeIfBoolExpr);
    assert(node->data.if_bool_expr.condition);
    assert(node->data.if_bool_expr.then_block);

    ConstExprValue *const_val = &get_resolved_expr(node->data.if_bool_expr.condition)->const_val;
    if (const_val->ok) {
        if (const_val->data.x_bool) {
            return gen_expr(g, node->data.if_bool_expr.then_block);
        } else if (node->data.if_bool_expr.else_node) {
            return gen_expr(g, node->data.if_bool_expr.else_node);
        } else {
            return nullptr;
        }
    } else {
        LLVMValueRef cond_value = gen_expr(g, node->data.if_bool_expr.condition);

        return gen_if_bool_expr_raw(g, node, cond_value,
                node->data.if_bool_expr.then_block,
                node->data.if_bool_expr.else_node);
    }
}

static void gen_var_debug_decl(CodeGen *g, VariableTableEntry *var) {
    BlockContext *block_context = var->block_context;
    AstNode *source_node = var->decl_node;
    LLVMZigDILocation *debug_loc = LLVMZigGetDebugLoc(source_node->line + 1, source_node->column + 1,
            block_context->di_scope);
    LLVMZigInsertDeclareAtEnd(g->dbuilder, var->value_ref, var->di_loc_var, debug_loc,
            LLVMGetInsertBlock(g->builder));
}

static LLVMValueRef gen_if_var_then_block(CodeGen *g, AstNode *node, VariableTableEntry *variable, bool maybe_is_ptr,
        LLVMValueRef init_val, TypeTableEntry *child_type, AstNode *then_node)
{
    if (node->data.if_var_expr.var_is_ptr) {
        LLVMValueRef payload_ptr;
        if (maybe_is_ptr) {
            zig_panic("TODO");
        } else {
            payload_ptr = LLVMBuildStructGEP(g->builder, init_val, 0, "");
        }
        LLVMBuildStore(g->builder, payload_ptr, variable->value_ref);
    } else {
        LLVMValueRef payload_val;
        if (maybe_is_ptr) {
            payload_val = init_val;
        } else {
            LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, init_val, 0, "");
            payload_val = get_handle_value(g, node, payload_ptr, child_type);
        }
        gen_assign_raw(g, node, BinOpTypeAssign, variable->value_ref, payload_val,
                variable->type, child_type);
    }
    gen_var_debug_decl(g, variable);

    return gen_expr(g, then_node);
}

static LLVMValueRef gen_if_var_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeIfVarExpr);
    assert(node->data.if_var_expr.var_decl.expr);

    AstNodeVariableDeclaration *var_decl = &node->data.if_var_expr.var_decl;
    VariableTableEntry *variable = var_decl->variable;

    // test if value is the maybe state
    TypeTableEntry *expr_type = get_expr_type(var_decl->expr);
    TypeTableEntry *child_type = expr_type->data.maybe.child_type;

    LLVMValueRef init_val = gen_expr(g, var_decl->expr);


    AstNode *then_node = node->data.if_var_expr.then_block;
    AstNode *else_node = node->data.if_var_expr.else_node;
    bool maybe_is_ptr = child_type->id == TypeTableEntryIdPointer || child_type->id == TypeTableEntryIdFn;

    ConstExprValue *const_val = &get_resolved_expr(var_decl->expr)->const_val;
    if (const_val->ok) {
        if (const_val->data.x_maybe) {
            return gen_if_var_then_block(g, node, variable, maybe_is_ptr, init_val, child_type, then_node);
        } else {
            return gen_expr(g, else_node);
        }
    }

    LLVMValueRef cond_value;
    if (maybe_is_ptr) {
        set_debug_source_node(g, node);
        cond_value = LLVMBuildICmp(g->builder, LLVMIntNE, init_val, LLVMConstNull(child_type->type_ref), "");
    } else {
        set_debug_source_node(g, node);
        LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, init_val, 1, "");
        cond_value = LLVMBuildLoad(g->builder, maybe_field_ptr, "");
    }

    TypeTableEntry *then_type = get_expr_type(then_node);
    TypeTableEntry *else_type = get_expr_type(else_node);

    bool use_then_value = type_has_bits(then_type);
    bool use_else_value = type_has_bits(else_type);

    LLVMBasicBlockRef then_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeThen");
    LLVMBasicBlockRef else_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeElse");

    LLVMBasicBlockRef endif_block;
    bool then_endif_reachable = then_type->id != TypeTableEntryIdUnreachable;
    bool else_endif_reachable = else_type->id != TypeTableEntryIdUnreachable;
    if (then_endif_reachable || else_endif_reachable) {
        endif_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "MaybeEndIf");
    }

    set_debug_source_node(g, node);
    LLVMBuildCondBr(g->builder, cond_value, then_block, else_block);

    LLVMPositionBuilderAtEnd(g->builder, then_block);
    LLVMValueRef then_expr_result = gen_if_var_then_block(g, node, variable, maybe_is_ptr, init_val, child_type, then_node);

    if (then_endif_reachable) {
        LLVMBuildBr(g->builder, endif_block);
    }
    LLVMBasicBlockRef after_then_block = LLVMGetInsertBlock(g->builder);


    LLVMPositionBuilderAtEnd(g->builder, else_block);
    LLVMValueRef else_expr_result = gen_expr(g, else_node);
    if (else_endif_reachable) {
        LLVMBuildBr(g->builder, endif_block);
    }
    LLVMBasicBlockRef after_else_block = LLVMGetInsertBlock(g->builder);

    if (then_endif_reachable || else_endif_reachable) {
        LLVMPositionBuilderAtEnd(g->builder, endif_block);
        if (use_then_value && use_else_value) {
            LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMTypeOf(then_expr_result), "");
            LLVMValueRef incoming_values[2] = {then_expr_result, else_expr_result};
            LLVMBasicBlockRef incoming_blocks[2] = {after_then_block, after_else_block};
            LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);
            return phi;
        } else if (use_then_value) {
            return then_expr_result;
        } else if (use_else_value) {
            return else_expr_result;
        }
    }

    return nullptr;
}

static LLVMValueRef gen_block(CodeGen *g, AstNode *block_node, TypeTableEntry *implicit_return_type) {
    assert(block_node->type == NodeTypeBlock);

    LLVMValueRef return_value;
    for (int i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        return_value = gen_expr(g, statement_node);
    }

    bool end_unreachable = implicit_return_type && implicit_return_type->id == TypeTableEntryIdUnreachable;
    if (end_unreachable) {
        return nullptr;
    }

    gen_defers_for_block(g, block_node->data.block.nested_block, block_node->data.block.child_block,
            false, false);

    if (implicit_return_type) {
        return gen_return(g, block_node, return_value, ReturnKnowledgeSkipDefers);
    } else {
        return return_value;
    }
}

static int find_asm_index(CodeGen *g, AstNode *node, AsmToken *tok) {
    const char *ptr = buf_ptr(node->data.asm_expr.asm_template) + tok->start + 2;
    int len = tok->end - tok->start - 2;
    int result = 0;
    for (int i = 0; i < node->data.asm_expr.output_list.length; i += 1, result += 1) {
        AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
        if (buf_eql_mem(asm_output->asm_symbolic_name, ptr, len)) {
            return result;
        }
    }
    for (int i = 0; i < node->data.asm_expr.input_list.length; i += 1, result += 1) {
        AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
        if (buf_eql_mem(asm_input->asm_symbolic_name, ptr, len)) {
            return result;
        }
    }
    return -1;
}

static LLVMValueRef gen_asm_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeAsmExpr);

    AstNodeAsmExpr *asm_expr = &node->data.asm_expr;

    Buf *src_template = asm_expr->asm_template;

    Buf llvm_template = BUF_INIT;
    buf_resize(&llvm_template, 0);

    for (int token_i = 0; token_i < asm_expr->token_list.length; token_i += 1) {
        AsmToken *asm_token = &asm_expr->token_list.at(token_i);
        switch (asm_token->id) {
            case AsmTokenIdTemplate:
                for (int offset = asm_token->start; offset < asm_token->end; offset += 1) {
                    uint8_t c = *((uint8_t*)(buf_ptr(src_template) + offset));
                    if (c == '$') {
                        buf_append_str(&llvm_template, "$$");
                    } else {
                        buf_append_char(&llvm_template, c);
                    }
                }
                break;
            case AsmTokenIdPercent:
                buf_append_char(&llvm_template, '%');
                break;
            case AsmTokenIdVar:
                int index = find_asm_index(g, node, asm_token);
                assert(index >= 0);
                buf_appendf(&llvm_template, "$%d", index);
                break;
        }
    }

    Buf constraint_buf = BUF_INIT;
    buf_resize(&constraint_buf, 0);

    assert(asm_expr->return_count == 0 || asm_expr->return_count == 1);

    int total_constraint_count = asm_expr->output_list.length +
                                 asm_expr->input_list.length +
                                 asm_expr->clobber_list.length;
    int input_and_output_count = asm_expr->output_list.length +
                                 asm_expr->input_list.length -
                                 asm_expr->return_count;
    int total_index = 0;
    int param_index = 0;
    LLVMTypeRef *param_types = allocate<LLVMTypeRef>(input_and_output_count);
    LLVMValueRef *param_values = allocate<LLVMValueRef>(input_and_output_count);
    for (int i = 0; i < asm_expr->output_list.length; i += 1, total_index += 1) {
        AsmOutput *asm_output = asm_expr->output_list.at(i);
        bool is_return = (asm_output->return_type != nullptr);
        assert(*buf_ptr(asm_output->constraint) == '=');
        if (is_return) {
            buf_appendf(&constraint_buf, "=%s", buf_ptr(asm_output->constraint) + 1);
        } else {
            buf_appendf(&constraint_buf, "=*%s", buf_ptr(asm_output->constraint) + 1);
        }
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        if (!is_return) {
            VariableTableEntry *variable = asm_output->variable;
            assert(variable);
            param_types[param_index] = LLVMTypeOf(variable->value_ref);
            param_values[param_index] = variable->value_ref;
            param_index += 1;
        }
    }
    for (int i = 0; i < asm_expr->input_list.length; i += 1, total_index += 1, param_index += 1) {
        AsmInput *asm_input = asm_expr->input_list.at(i);
        buf_append_buf(&constraint_buf, asm_input->constraint);
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        TypeTableEntry *expr_type = get_expr_type(asm_input->expr);
        param_types[param_index] = expr_type->type_ref;
        param_values[param_index] = gen_expr(g, asm_input->expr);
    }
    for (int i = 0; i < asm_expr->clobber_list.length; i += 1, total_index += 1) {
        Buf *clobber_buf = asm_expr->clobber_list.at(i);
        buf_appendf(&constraint_buf, "~{%s}", buf_ptr(clobber_buf));
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }
    }

    LLVMTypeRef ret_type;
    if (asm_expr->return_count == 0) {
        ret_type = LLVMVoidType();
    } else {
        ret_type = get_expr_type(node)->type_ref;
    }
    LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, input_and_output_count, false);

    bool is_volatile = asm_expr->is_volatile || (asm_expr->output_list.length == 0);
    LLVMValueRef asm_fn = LLVMConstInlineAsm(function_type, buf_ptr(&llvm_template),
            buf_ptr(&constraint_buf), is_volatile, false);

    set_debug_source_node(g, node);
    return LLVMBuildCall(g->builder, asm_fn, param_values, input_and_output_count, "");
}

static LLVMValueRef gen_container_init_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeContainerInitExpr);

    TypeTableEntry *type_entry = get_expr_type(node);


    if (node->data.container_init_expr.enum_type) {
        int param_count = node->data.container_init_expr.entries.length;
        AstNode *arg1_node;
        if (param_count == 1) {
            arg1_node = node->data.container_init_expr.entries.at(0);
        } else {
            assert(param_count == 0);
            arg1_node = nullptr;
        }
        return gen_enum_value_expr(g, node->data.container_init_expr.type,
                node->data.container_init_expr.enum_type, arg1_node);
    }


    if (type_entry->id == TypeTableEntryIdStruct) {
        assert(node->data.container_init_expr.kind == ContainerInitKindStruct);

        int src_field_count = type_entry->data.structure.src_field_count;
        assert(src_field_count == node->data.container_init_expr.entries.length);

        StructValExprCodeGen *struct_val_expr_node = &node->data.container_init_expr.resolved_struct_val_expr;
        LLVMValueRef tmp_struct_ptr = struct_val_expr_node->ptr;

        for (int i = 0; i < src_field_count; i += 1) {
            AstNode *field_node = node->data.container_init_expr.entries.at(i);
            assert(field_node->type == NodeTypeStructValueField);
            TypeStructField *type_struct_field = field_node->data.struct_val_field.type_struct_field;
            if (type_struct_field->type_entry->id == TypeTableEntryIdVoid) {
                continue;
            }
            assert(buf_eql_buf(type_struct_field->name, field_node->data.struct_val_field.name));

            set_debug_source_node(g, field_node);
            LLVMValueRef field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, type_struct_field->gen_index, "");
            AstNode *expr_node = field_node->data.struct_val_field.expr;
            LLVMValueRef value = gen_expr(g, expr_node);
            gen_assign_raw(g, field_node, BinOpTypeAssign, field_ptr, value,
                    type_struct_field->type_entry, get_expr_type(expr_node));
        }

        return tmp_struct_ptr;
    } else if (type_entry->id == TypeTableEntryIdUnreachable) {
        assert(node->data.container_init_expr.entries.length == 0);
        set_debug_source_node(g, node);
        if (want_debug_safety(g, node) || g->is_test_build) {
            gen_debug_safety_crash(g);
        } else {
            LLVMBuildUnreachable(g->builder);
        }
        return nullptr;
    } else if (type_entry->id == TypeTableEntryIdVoid) {
        assert(node->data.container_init_expr.entries.length == 0);
        return nullptr;
    } else if (type_entry->id == TypeTableEntryIdArray) {
        StructValExprCodeGen *struct_val_expr_node = &node->data.container_init_expr.resolved_struct_val_expr;
        LLVMValueRef tmp_array_ptr = struct_val_expr_node->ptr;

        int field_count = type_entry->data.array.len;
        assert(field_count == node->data.container_init_expr.entries.length);

        TypeTableEntry *child_type = type_entry->data.array.child_type;

        for (int i = 0; i < field_count; i += 1) {
            AstNode *field_node = node->data.container_init_expr.entries.at(i);
            LLVMValueRef elem_val = gen_expr(g, field_node);

            LLVMValueRef indices[] = {
                LLVMConstNull(g->builtin_types.entry_usize->type_ref),
                LLVMConstInt(g->builtin_types.entry_usize->type_ref, i, false),
            };
            set_debug_source_node(g, field_node);
            LLVMValueRef elem_ptr = LLVMBuildInBoundsGEP(g->builder, tmp_array_ptr, indices, 2, "");
            gen_assign_raw(g, field_node, BinOpTypeAssign, elem_ptr, elem_val,
                    child_type, get_expr_type(field_node));
        }

        return tmp_array_ptr;
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef gen_while_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeWhileExpr);
    assert(node->data.while_expr.condition);
    assert(node->data.while_expr.body);

    AstNode *continue_expr_node = node->data.while_expr.continue_expr;

    bool condition_always_true = node->data.while_expr.condition_always_true;
    bool contains_break = node->data.while_expr.contains_break;
    if (condition_always_true) {
        // generate a forever loop

        LLVMBasicBlockRef body_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "WhileBody");
        LLVMBasicBlockRef continue_block = continue_expr_node ?
            LLVMAppendBasicBlock(g->cur_fn->fn_value, "WhileContinue") : body_block;
        LLVMBasicBlockRef end_block = nullptr;
        if (contains_break) {
            end_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "WhileEnd");
        }

        set_debug_source_node(g, node);
        LLVMBuildBr(g->builder, body_block);

        if (continue_expr_node) {
            LLVMPositionBuilderAtEnd(g->builder, continue_block);

            gen_expr(g, continue_expr_node);

            set_debug_source_node(g, node);
            LLVMBuildBr(g->builder, body_block);
        }

        LLVMPositionBuilderAtEnd(g->builder, body_block);
        g->break_block_stack.append(end_block);
        g->continue_block_stack.append(continue_block);
        gen_expr(g, node->data.while_expr.body);
        g->break_block_stack.pop();
        g->continue_block_stack.pop();

        if (get_expr_type(node->data.while_expr.body)->id != TypeTableEntryIdUnreachable) {
            set_debug_source_node(g, node);
            LLVMBuildBr(g->builder, continue_block);
        }

        if (contains_break) {
            LLVMPositionBuilderAtEnd(g->builder, end_block);
        }
    } else {
        // generate a normal while loop

        LLVMBasicBlockRef cond_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "WhileCond");
        LLVMBasicBlockRef body_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "WhileBody");
        LLVMBasicBlockRef continue_block = continue_expr_node ?
            LLVMAppendBasicBlock(g->cur_fn->fn_value, "WhileContinue") : cond_block;
        LLVMBasicBlockRef end_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "WhileEnd");

        set_debug_source_node(g, node);
        LLVMBuildBr(g->builder, cond_block);

        if (continue_expr_node) {
            LLVMPositionBuilderAtEnd(g->builder, continue_block);

            gen_expr(g, continue_expr_node);

            set_debug_source_node(g, node);
            LLVMBuildBr(g->builder, cond_block);
        }

        LLVMPositionBuilderAtEnd(g->builder, cond_block);
        LLVMValueRef cond_val = gen_expr(g, node->data.while_expr.condition);
        set_debug_source_node(g, node->data.while_expr.condition);
        LLVMBuildCondBr(g->builder, cond_val, body_block, end_block);

        LLVMPositionBuilderAtEnd(g->builder, body_block);
        g->break_block_stack.append(end_block);
        g->continue_block_stack.append(continue_block);
        gen_expr(g, node->data.while_expr.body);
        g->break_block_stack.pop();
        g->continue_block_stack.pop();
        if (get_expr_type(node->data.while_expr.body)->id != TypeTableEntryIdUnreachable) {
            set_debug_source_node(g, node);
            LLVMBuildBr(g->builder, continue_block);
        }

        LLVMPositionBuilderAtEnd(g->builder, end_block);
    }

    return nullptr;
}

static LLVMValueRef gen_for_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeForExpr);
    assert(node->data.for_expr.array_expr);
    assert(node->data.for_expr.body);

    VariableTableEntry *elem_var = node->data.for_expr.elem_var;
    assert(elem_var);

    TypeTableEntry *array_type = get_expr_type(node->data.for_expr.array_expr);

    VariableTableEntry *index_var = node->data.for_expr.index_var;
    assert(index_var);
    LLVMValueRef index_ptr = index_var->value_ref;
    LLVMValueRef one_const = LLVMConstInt(g->builtin_types.entry_usize->type_ref, 1, false);

    LLVMBasicBlockRef cond_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "ForCond");
    LLVMBasicBlockRef body_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "ForBody");
    LLVMBasicBlockRef end_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "ForEnd");
    LLVMBasicBlockRef continue_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "ForContinue");

    LLVMValueRef array_val = gen_array_base_ptr(g, node->data.for_expr.array_expr);
    set_debug_source_node(g, node);
    LLVMBuildStore(g->builder, LLVMConstNull(index_var->type->type_ref), index_ptr);

    gen_var_debug_decl(g, index_var);

    LLVMValueRef len_val;
    TypeTableEntry *child_type;
    if (array_type->id == TypeTableEntryIdArray) {
        len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                array_type->data.array.len, false);
        child_type = array_type->data.array.child_type;
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);
        TypeTableEntry *child_ptr_type = array_type->data.structure.fields[0].type_entry;
        assert(child_ptr_type->id == TypeTableEntryIdPointer);
        child_type = child_ptr_type->data.pointer.child_type;
        int len_index = array_type->data.structure.fields[1].gen_index;
        assert(len_index >= 0);
        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, array_val, len_index, "");
        len_val = LLVMBuildLoad(g->builder, len_field_ptr, "");
    } else {
        zig_unreachable();
    }
    LLVMBuildBr(g->builder, cond_block);

    LLVMPositionBuilderAtEnd(g->builder, cond_block);
    LLVMValueRef index_val = LLVMBuildLoad(g->builder, index_ptr, "");
    LLVMValueRef cond = LLVMBuildICmp(g->builder, LLVMIntSLT, index_val, len_val, "");
    LLVMBuildCondBr(g->builder, cond, body_block, end_block);

    LLVMPositionBuilderAtEnd(g->builder, body_block);
    LLVMValueRef elem_ptr = gen_array_elem_ptr(g, node, array_val, array_type, index_val);

    LLVMValueRef elem_val;
    if (node->data.for_expr.elem_is_ptr) {
        elem_val = elem_ptr;
    } else {
        elem_val = handle_is_ptr(child_type) ? elem_ptr : LLVMBuildLoad(g->builder, elem_ptr, "");
    }
    gen_assign_raw(g, node, BinOpTypeAssign, elem_var->value_ref, elem_val, elem_var->type, child_type);
    gen_var_debug_decl(g, elem_var);
    g->break_block_stack.append(end_block);
    g->continue_block_stack.append(continue_block);
    gen_expr(g, node->data.for_expr.body);
    g->break_block_stack.pop();
    g->continue_block_stack.pop();
    if (get_expr_type(node->data.for_expr.body)->id != TypeTableEntryIdUnreachable) {
        set_debug_source_node(g, node);
        LLVMBuildBr(g->builder, continue_block);
    }

    LLVMPositionBuilderAtEnd(g->builder, continue_block);
    set_debug_source_node(g, node);
    LLVMValueRef new_index_val = LLVMBuildNSWAdd(g->builder, index_val, one_const, "");
    LLVMBuildStore(g->builder, new_index_val, index_ptr);
    LLVMBuildBr(g->builder, cond_block);

    LLVMPositionBuilderAtEnd(g->builder, end_block);
    return nullptr;
}

static LLVMValueRef gen_break(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBreak);
    LLVMBasicBlockRef dest_block = g->break_block_stack.last();

    set_debug_source_node(g, node);
    return LLVMBuildBr(g->builder, dest_block);
}

static LLVMValueRef gen_continue(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeContinue);
    LLVMBasicBlockRef dest_block = g->continue_block_stack.last();

    set_debug_source_node(g, node);
    return LLVMBuildBr(g->builder, dest_block);
}

static LLVMValueRef gen_var_decl_raw(CodeGen *g, AstNode *source_node, AstNodeVariableDeclaration *var_decl,
        bool unwrap_maybe, LLVMValueRef *init_value, TypeTableEntry **expr_type, bool var_is_ptr)
{
    VariableTableEntry *variable = var_decl->variable;

    assert(variable);

    if (var_decl->expr) {
        *init_value = gen_expr(g, var_decl->expr);
        *expr_type = get_expr_type(var_decl->expr);
    }
    if (!type_has_bits(variable->type)) {
        return nullptr;
    }

    bool have_init_expr = false;
    bool want_zeroes = false;
    if (var_decl->expr) {
        ConstExprValue *const_val = &get_resolved_expr(var_decl->expr)->const_val;
        if (!const_val->ok || const_val->special == ConstValSpecialOther) {
            have_init_expr = true;
        }
        if (const_val->ok && const_val->special == ConstValSpecialZeroes) {
            want_zeroes = true;
        }
    }
    if (have_init_expr) {
        TypeTableEntry *expr_type = get_expr_type(var_decl->expr);
        LLVMValueRef value;
        if (unwrap_maybe) {
            assert(var_decl->expr);
            assert(expr_type->id == TypeTableEntryIdMaybe);
            value = gen_unwrap_maybe(g, var_decl->expr, *init_value);
            expr_type = expr_type->data.maybe.child_type;
        } else {
            value = *init_value;
        }
        gen_assign_raw(g, var_decl->expr, BinOpTypeAssign, variable->value_ref,
                value, variable->type, expr_type);
    } else {
        bool ignore_uninit = false;
        // handle runtime stack allocation
        if (var_decl->type) {
            TypeTableEntry *var_type = get_type_for_type_node(var_decl->type);
            if (var_type->id == TypeTableEntryIdStruct &&
                var_type->data.structure.is_slice)
            {
                assert(var_decl->type->type == NodeTypeArrayType);
                AstNode *size_node = var_decl->type->data.array_type.size;
                if (size_node) {
                    ConstExprValue *const_val = &get_resolved_expr(size_node)->const_val;
                    if (!const_val->ok) {
                        TypeTableEntry *ptr_type = var_type->data.structure.fields[0].type_entry;
                        assert(ptr_type->id == TypeTableEntryIdPointer);
                        TypeTableEntry *child_type = ptr_type->data.pointer.child_type;

                        LLVMValueRef size_val = gen_expr(g, size_node);

                        set_debug_source_node(g, source_node);
                        LLVMValueRef ptr_val = LLVMBuildArrayAlloca(g->builder, child_type->type_ref,
                                size_val, "");

                        int ptr_index = var_type->data.structure.fields[0].gen_index;
                        assert(ptr_index >= 0);
                        int len_index = var_type->data.structure.fields[1].gen_index;
                        assert(len_index >= 0);

                        // store the freshly allocated pointer in the unknown size array struct
                        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder,
                                variable->value_ref, ptr_index, "");
                        LLVMBuildStore(g->builder, ptr_val, ptr_field_ptr);

                        // store the size in the len field
                        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder,
                                variable->value_ref, len_index, "");
                        LLVMBuildStore(g->builder, size_val, len_field_ptr);

                        // don't clobber what we just did with debug initialization
                        ignore_uninit = true;
                    }
                }
            }
        }
        bool want_safe = want_debug_safety(g, source_node);
        if (!ignore_uninit && (want_safe || want_zeroes)) {
            TypeTableEntry *usize = g->builtin_types.entry_usize;
            uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, variable->type->type_ref);
            uint64_t align_bytes = get_memcpy_align(g, variable->type);

            // memset uninitialized memory to 0xa
            set_debug_source_node(g, source_node);
            LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
            LLVMValueRef fill_char = LLVMConstInt(LLVMInt8Type(), want_zeroes ? 0x00 : 0xaa, false);
            LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, variable->value_ref, ptr_u8, "");
            LLVMValueRef byte_count = LLVMConstInt(usize->type_ref, size_bytes, false);
            LLVMValueRef align_in_bytes = LLVMConstInt(LLVMInt32Type(), align_bytes, false);
            LLVMValueRef params[] = {
                dest_ptr,
                fill_char,
                byte_count,
                align_in_bytes,
                LLVMConstNull(LLVMInt1Type()), // is volatile
            };

            LLVMBuildCall(g->builder, g->memset_fn_val, params, 5, "");
        }
    }

    gen_var_debug_decl(g, variable);
    return nullptr;
}

static LLVMValueRef gen_var_decl_expr(CodeGen *g, AstNode *node) {
    AstNode *init_expr = node->data.variable_declaration.expr;
    if (node->data.variable_declaration.is_const && init_expr) {
        TypeTableEntry *init_expr_type = get_expr_type(init_expr);
        if (init_expr_type->id == TypeTableEntryIdNumLitFloat ||
            init_expr_type->id == TypeTableEntryIdNumLitInt)
        {
            return nullptr;
        }
    }

    LLVMValueRef init_val;
    TypeTableEntry *init_val_type;
    return gen_var_decl_raw(g, node, &node->data.variable_declaration, false, &init_val, &init_val_type, false);
}

static LLVMValueRef gen_symbol(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeSymbol);
    VariableTableEntry *variable = get_resolved_expr(node)->variable;
    if (variable) {
        return gen_variable(g, node, variable);
    }

    zig_unreachable();
}

static LLVMValueRef gen_switch_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeSwitchExpr);

    if (node->data.switch_expr.const_chosen_prong_index >= 0) {
        AstNode *prong_node = node->data.switch_expr.prongs.at(node->data.switch_expr.const_chosen_prong_index);
        assert(prong_node->type == NodeTypeSwitchProng);
        AstNode *prong_expr = prong_node->data.switch_prong.expr;
        return gen_expr(g, prong_expr);
    }

    TypeTableEntry *target_type = get_expr_type(node->data.switch_expr.expr);
    LLVMValueRef target_value_handle = gen_expr(g, node->data.switch_expr.expr);
    LLVMValueRef target_value;
    if (handle_is_ptr(target_type)) {
        if (target_type->id == TypeTableEntryIdEnum) {
            set_debug_source_node(g, node);
            LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, target_value_handle, 0, "");
            target_value = LLVMBuildLoad(g->builder, tag_field_ptr, "");
        } else if (target_type->id == TypeTableEntryIdErrorUnion) {
            set_debug_source_node(g, node);
            LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, target_value_handle, 0, "");
            target_value = LLVMBuildLoad(g->builder, tag_field_ptr, "");
        } else {
            zig_unreachable();
        }
    } else {
        target_value = target_value_handle;
    }


    TypeTableEntry *switch_type = get_expr_type(node);
    bool result_has_bits = type_has_bits(switch_type);
    bool end_unreachable = (switch_type->id == TypeTableEntryIdUnreachable);

    LLVMBasicBlockRef end_block = end_unreachable ?
        nullptr : LLVMAppendBasicBlock(g->cur_fn->fn_value, "SwitchEnd");
    LLVMBasicBlockRef else_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "SwitchElse");
    int prong_count = node->data.switch_expr.prongs.length;

    set_debug_source_node(g, node);
    LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, target_value, else_block, prong_count);

    ZigList<LLVMValueRef> incoming_values = {0};
    ZigList<LLVMBasicBlockRef> incoming_blocks = {0};

    AstNode *else_prong = nullptr;
    for (int prong_i = 0; prong_i < prong_count; prong_i += 1) {
        AstNode *prong_node = node->data.switch_expr.prongs.at(prong_i);
        VariableTableEntry *prong_var = prong_node->data.switch_prong.var;

        LLVMBasicBlockRef prong_block;
        if (prong_node->data.switch_prong.items.length == 0) {
            assert(!else_prong);
            else_prong = prong_node;
            prong_block = else_block;
        } else {
            prong_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "SwitchProng");
            int prong_item_count = prong_node->data.switch_prong.items.length;
            bool make_item_blocks = prong_var && prong_item_count > 1;

            for (int item_i = 0; item_i < prong_item_count; item_i += 1) {
                AstNode *item_node = prong_node->data.switch_prong.items.at(item_i);

                assert(item_node->type != NodeTypeSwitchRange);
                LLVMValueRef val;
                if (target_type->id == TypeTableEntryIdEnum ||
                    target_type->id == TypeTableEntryIdErrorUnion)
                {
                    assert(item_node->type == NodeTypeSymbol);
                    TypeEnumField *enum_field = nullptr;
                    uint32_t err_value = 0;
                    if (target_type->id == TypeTableEntryIdEnum) {
                        enum_field = item_node->data.symbol_expr.enum_field;
                        assert(enum_field);
                        val = LLVMConstInt(target_type->data.enumeration.tag_type->type_ref,
                                enum_field->value, false);
                    } else if (target_type->id == TypeTableEntryIdErrorUnion) {
                        err_value = item_node->data.symbol_expr.err_value;
                        val = LLVMConstInt(g->err_tag_type->type_ref, err_value, false);
                    } else {
                        zig_unreachable();
                    }

                    if (prong_var && type_has_bits(prong_var->type)) {
                        LLVMBasicBlockRef item_block;

                        if (make_item_blocks) {
                            item_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "SwitchProngItem");
                            LLVMAddCase(switch_instr, val, item_block);
                            LLVMPositionBuilderAtEnd(g->builder, item_block);
                        } else {
                            LLVMAddCase(switch_instr, val, prong_block);
                            LLVMPositionBuilderAtEnd(g->builder, prong_block);
                        }

                        AstNode *var_node = prong_node->data.switch_prong.var_symbol;
                        set_debug_source_node(g, var_node);
                        if (prong_node->data.switch_prong.var_is_target_expr) {
                            gen_assign_raw(g, var_node, BinOpTypeAssign,
                                    prong_var->value_ref, target_value, prong_var->type, target_type);
                        } else if (target_type->id == TypeTableEntryIdEnum) {
                            assert(enum_field);
                            assert(type_has_bits(enum_field->type_entry));
                            LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, target_value_handle,
                                    1, "");
                            LLVMValueRef bitcasted_union_field_ptr = LLVMBuildBitCast(g->builder, union_field_ptr,
                                    LLVMPointerType(enum_field->type_entry->type_ref, 0), "");
                            LLVMValueRef handle_val = get_handle_value(g, var_node, bitcasted_union_field_ptr,
                                    enum_field->type_entry);

                            gen_assign_raw(g, var_node, BinOpTypeAssign,
                                    prong_var->value_ref, handle_val, prong_var->type, enum_field->type_entry);
                        } else if (target_type->id == TypeTableEntryIdErrorUnion) {
                            if (err_value == 0) {
                                // variable is the payload
                                LLVMValueRef err_payload_ptr = LLVMBuildStructGEP(g->builder,
                                        target_value_handle, 1, "");
                                LLVMValueRef handle_val = get_handle_value(g, var_node,
                                        err_payload_ptr, prong_var->type);
                                gen_assign_raw(g, var_node, BinOpTypeAssign,
                                        prong_var->value_ref, handle_val, prong_var->type, prong_var->type);
                            } else {
                                // variable is the pure error value
                                LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder,
                                        target_value_handle, 0, "");
                                LLVMValueRef handle_val = LLVMBuildLoad(g->builder, err_tag_ptr, "");
                                gen_assign_raw(g, var_node, BinOpTypeAssign,
                                        prong_var->value_ref, handle_val, prong_var->type, g->err_tag_type);
                            }
                        } else {
                            zig_unreachable();
                        }
                        if (make_item_blocks) {
                            LLVMBuildBr(g->builder, prong_block);
                        }
                    } else {
                        LLVMAddCase(switch_instr, val, prong_block);
                    }
                } else {
                    assert(get_resolved_expr(item_node)->const_val.ok);
                    val = gen_expr(g, item_node);
                    LLVMAddCase(switch_instr, val, prong_block);
                }
            }
        }

        LLVMPositionBuilderAtEnd(g->builder, prong_block);
        AstNode *prong_expr = prong_node->data.switch_prong.expr;
        LLVMValueRef prong_val = gen_expr(g, prong_expr);

        if (get_expr_type(prong_expr)->id != TypeTableEntryIdUnreachable) {
            set_debug_source_node(g, prong_expr);
            LLVMBuildBr(g->builder, end_block);
            incoming_values.append(prong_val);
            incoming_blocks.append(LLVMGetInsertBlock(g->builder));
        }
    }

    if (!else_prong) {
        LLVMPositionBuilderAtEnd(g->builder, else_block);
        set_debug_source_node(g, node);
        if (want_debug_safety(g, node)) {
            gen_debug_safety_crash(g);
        } else {
            LLVMBuildUnreachable(g->builder);
        }
    }

    if (end_unreachable) {
        return nullptr;
    }

    LLVMPositionBuilderAtEnd(g->builder, end_block);

    if (result_has_bits) {
        set_debug_source_node(g, node);
        LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMTypeOf(incoming_values.at(0)), "");
        LLVMAddIncoming(phi, incoming_values.items, incoming_blocks.items, incoming_values.length);
        return phi;
    } else {
        return nullptr;
    }
}

static LLVMValueRef gen_goto(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeGoto);

    // generate defers for blocks that we exit
    LabelTableEntry *label = node->data.goto_expr.label_entry;
    BlockContext *this_context = node->block_context;
    BlockContext *target_context = label->decl_node->block_context;
    gen_defers_for_block(g, this_context, target_context, false, false);

    set_debug_source_node(g, node);
    LLVMBuildBr(g->builder, node->data.goto_expr.label_entry->basic_block);
    return nullptr;
}

static LLVMValueRef gen_label(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeLabel);

    LabelTableEntry *label = node->data.label.label_entry;
    assert(label);

    LLVMBasicBlockRef basic_block = label->basic_block;
    if (label->entered_from_fallthrough) {
        set_debug_source_node(g, node);
        LLVMBuildBr(g->builder, basic_block);
    }
    LLVMPositionBuilderAtEnd(g->builder, basic_block);
    return nullptr;
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *node) {
    Expr *expr = get_resolved_expr(node);
    if (expr->const_val.ok) {
        if (!type_has_bits(expr->type_entry)) {
            return nullptr;
        } else {
            assert(expr->const_llvm_val);
            return expr->const_llvm_val;
        }
    }
    switch (node->type) {
        case NodeTypeBinOpExpr:
            return gen_bin_op_expr(g, node);
        case NodeTypeUnwrapErrorExpr:
            return gen_unwrap_err_expr(g, node);
        case NodeTypeReturnExpr:
            return gen_return_expr(g, node);
        case NodeTypeDefer:
            // nothing to do
            return nullptr;
        case NodeTypeVariableDeclaration:
            return gen_var_decl_expr(g, node);
        case NodeTypePrefixOpExpr:
            return gen_prefix_op_expr(g, node);
        case NodeTypeFnCallExpr:
            return gen_fn_call_expr(g, node);
        case NodeTypeArrayAccessExpr:
            return gen_array_access_expr(g, node, false);
        case NodeTypeSliceExpr:
            return gen_slice_expr(g, node);
        case NodeTypeFieldAccessExpr:
            return gen_field_access_expr(g, node, false);
        case NodeTypeIfBoolExpr:
            return gen_if_bool_expr(g, node);
        case NodeTypeIfVarExpr:
            return gen_if_var_expr(g, node);
        case NodeTypeWhileExpr:
            return gen_while_expr(g, node);
        case NodeTypeForExpr:
            return gen_for_expr(g, node);
        case NodeTypeAsmExpr:
            return gen_asm_expr(g, node);
        case NodeTypeSymbol:
            return gen_symbol(g, node);
        case NodeTypeBlock:
            return gen_block(g, node, nullptr);
        case NodeTypeGoto:
            return gen_goto(g, node);
        case NodeTypeBreak:
            return gen_break(g, node);
        case NodeTypeContinue:
            return gen_continue(g, node);
        case NodeTypeLabel:
            return gen_label(g, node);
        case NodeTypeContainerInitExpr:
            return gen_container_init_expr(g, node);
        case NodeTypeSwitchExpr:
            return gen_switch_expr(g, node);
        case NodeTypeNumberLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeZeroesLiteral:
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
        case NodeTypeArrayType:
            // caught by constant expression eval codegen
            zig_unreachable();
        case NodeTypeRoot:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeDirective:
        case NodeTypeUse:
        case NodeTypeContainerDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeErrorValueDecl:
        case NodeTypeTypeDecl:
            zig_unreachable();
    }
    zig_unreachable();
}

static LLVMValueRef gen_const_val(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val) {
    assert(const_val->ok);

    switch (const_val->special) {
        case ConstValSpecialUndef:
            return LLVMGetUndef(type_entry->type_ref);
        case ConstValSpecialZeroes:
            return LLVMConstNull(type_entry->type_ref);
        case ConstValSpecialOther:
            break;

    }

    switch (type_entry->id) {
        case TypeTableEntryIdTypeDecl:
            return gen_const_val(g, type_entry->data.type_decl.canonical_type, const_val);
        case TypeTableEntryIdInt:
            return LLVMConstInt(type_entry->type_ref, bignum_to_twos_complement(&const_val->data.x_bignum), false);
        case TypeTableEntryIdPureError:
            assert(const_val->data.x_err.err);
            return LLVMConstInt(g->builtin_types.entry_pure_error->type_ref,
                    const_val->data.x_err.err->value, false);
        case TypeTableEntryIdFloat:
            if (const_val->data.x_bignum.kind == BigNumKindFloat) {
                return LLVMConstReal(type_entry->type_ref, const_val->data.x_bignum.data.x_float);
            } else {
                int64_t x = const_val->data.x_bignum.data.x_uint;
                if (const_val->data.x_bignum.is_negative) {
                    x = -x;
                }
                return LLVMConstReal(type_entry->type_ref, x);
            }
        case TypeTableEntryIdBool:
            if (const_val->data.x_bool) {
                return LLVMConstAllOnes(LLVMInt1Type());
            } else {
                return LLVMConstNull(LLVMInt1Type());
            }
        case TypeTableEntryIdMaybe:
            {
                TypeTableEntry *child_type = type_entry->data.maybe.child_type;
                if (child_type->id == TypeTableEntryIdPointer ||
                    child_type->id == TypeTableEntryIdFn)
                {
                    if (const_val->data.x_maybe) {
                        return gen_const_val(g, child_type, const_val->data.x_maybe);
                    } else {
                        return LLVMConstNull(child_type->type_ref);
                    }
                } else {
                    LLVMValueRef child_val;
                    LLVMValueRef maybe_val;
                    if (const_val->data.x_maybe) {
                        child_val = gen_const_val(g, child_type, const_val->data.x_maybe);
                        maybe_val = LLVMConstAllOnes(LLVMInt1Type());
                    } else {
                        child_val = LLVMConstNull(child_type->type_ref);
                        maybe_val = LLVMConstNull(LLVMInt1Type());
                    }
                    LLVMValueRef fields[] = {
                        child_val,
                        maybe_val,
                    };
                    return LLVMConstStruct(fields, 2, false);
                }
            }
        case TypeTableEntryIdStruct:
            {
                LLVMValueRef *fields = allocate<LLVMValueRef>(type_entry->data.structure.gen_field_count);
                for (uint32_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
                    TypeStructField *type_struct_field = &type_entry->data.structure.fields[i];
                    if (type_struct_field->gen_index == -1) {
                        continue;
                    }
                    fields[type_struct_field->gen_index] = gen_const_val(g, type_struct_field->type_entry,
                            const_val->data.x_struct.fields[i]);
                }
                return LLVMConstNamedStruct(type_entry->type_ref, fields,
                        type_entry->data.structure.gen_field_count);
            }
        case TypeTableEntryIdUnion:
            {
                zig_panic("TODO");
            }
        case TypeTableEntryIdArray:
            {
                TypeTableEntry *child_type = type_entry->data.array.child_type;
                uint64_t len = type_entry->data.array.len;
                LLVMValueRef *values = allocate<LLVMValueRef>(len);
                for (uint64_t i = 0; i < len; i += 1) {
                    ConstExprValue *field_value = const_val->data.x_array.fields[i];
                    values[i] = gen_const_val(g, child_type, field_value);
                }
                return LLVMConstArray(child_type->type_ref, values, len);
            }
        case TypeTableEntryIdEnum:
            {
                LLVMTypeRef tag_type_ref = type_entry->data.enumeration.tag_type->type_ref;
                LLVMValueRef tag_value = LLVMConstInt(tag_type_ref, const_val->data.x_enum.tag, false);
                if (type_entry->data.enumeration.gen_field_count == 0) {
                    return tag_value;
                } else {
                    TypeTableEntry *union_type = type_entry->data.enumeration.union_type;
                    TypeEnumField *enum_field = &type_entry->data.enumeration.fields[const_val->data.x_enum.tag];
                    assert(enum_field->value == const_val->data.x_enum.tag);
                    LLVMValueRef union_value;
                    if (type_has_bits(enum_field->type_entry)) {
                        uint64_t union_type_bytes = LLVMStoreSizeOfType(g->target_data_ref,
                                union_type->type_ref);
                        uint64_t field_type_bytes = LLVMStoreSizeOfType(g->target_data_ref,
                                enum_field->type_entry->type_ref);
                        uint64_t pad_bytes = union_type_bytes - field_type_bytes;

                        LLVMValueRef correctly_typed_value = gen_const_val(g, enum_field->type_entry,
                                const_val->data.x_enum.payload);
                        if (pad_bytes == 0) {
                            union_value = correctly_typed_value;
                        } else {
                            LLVMValueRef fields[] = {
                                correctly_typed_value,
                                LLVMGetUndef(LLVMArrayType(LLVMInt8Type(), pad_bytes)),
                            };
                            union_value = LLVMConstStruct(fields, 2, false);
                        }
                    } else {
                        union_value = LLVMGetUndef(union_type->type_ref);
                    }
                    LLVMValueRef fields[] = {
                        tag_value,
                        union_value,
                    };
                    return LLVMConstNamedStruct(type_entry->type_ref, fields, 2);
                }
            }
        case TypeTableEntryIdFn:
            return const_val->data.x_fn->fn_value;
        case TypeTableEntryIdPointer:
            {
                TypeTableEntry *child_type = type_entry->data.pointer.child_type;
                int len = const_val->data.x_ptr.len;
                LLVMValueRef target_val;
                if (len == 1) {
                    target_val = gen_const_val(g, child_type, const_val->data.x_ptr.ptr[0]);
                } else if (len > 1) {
                    LLVMValueRef *values = allocate<LLVMValueRef>(len);
                    for (int i = 0; i < len; i += 1) {
                        values[i] = gen_const_val(g, child_type, const_val->data.x_ptr.ptr[i]);
                    }
                    target_val = LLVMConstArray(child_type->type_ref, values, len);
                } else {
                    return LLVMGetUndef(type_entry->type_ref);
                }
                LLVMValueRef global_value = LLVMAddGlobal(g->module, LLVMTypeOf(target_val), "");
                LLVMSetInitializer(global_value, target_val);
                LLVMSetLinkage(global_value, LLVMPrivateLinkage);
                LLVMSetGlobalConstant(global_value, type_entry->data.pointer.is_const);
                LLVMSetUnnamedAddr(global_value, true);

                if (len > 1) {
                    return LLVMConstBitCast(global_value, type_entry->type_ref);
                } else {
                    return global_value;
                }
            }
        case TypeTableEntryIdErrorUnion:
            {
                TypeTableEntry *child_type = type_entry->data.error.child_type;
                if (!type_has_bits(child_type)) {
                    uint64_t value = const_val->data.x_err.err ? const_val->data.x_err.err->value : 0;
                    return LLVMConstInt(g->err_tag_type->type_ref, value, false);
                } else {
                    LLVMValueRef err_tag_value;
                    LLVMValueRef err_payload_value;
                    if (const_val->data.x_err.err) {
                        err_tag_value = LLVMConstInt(g->err_tag_type->type_ref, const_val->data.x_err.err->value, false);
                        err_payload_value = LLVMConstNull(child_type->type_ref);
                    } else {
                        err_tag_value = LLVMConstNull(g->err_tag_type->type_ref);
                        err_payload_value = gen_const_val(g, child_type, const_val->data.x_err.payload);
                    }
                    LLVMValueRef fields[] = {
                        err_tag_value,
                        err_payload_value,
                    };
                    return LLVMConstStruct(fields, 2, false);
                }
            }
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdGenericFn:
            zig_unreachable();

    }
    zig_unreachable();
}

static void gen_const_globals(CodeGen *g) {
    for (int i = 0; i < g->global_const_list.length; i += 1) {
        AstNode *expr_node = g->global_const_list.at(i);
        Expr *expr = get_resolved_expr(expr_node);
        ConstExprValue *const_val = &expr->const_val;
        assert(const_val->ok);
        TypeTableEntry *type_entry = expr->type_entry;

        if (handle_is_ptr(type_entry)) {
            LLVMValueRef init_val = gen_const_val(g, type_entry, const_val);
            LLVMValueRef global_value = LLVMAddGlobal(g->module, LLVMTypeOf(init_val), "");
            LLVMSetInitializer(global_value, init_val);
            LLVMSetLinkage(global_value, LLVMPrivateLinkage);
            LLVMSetGlobalConstant(global_value, true);
            LLVMSetUnnamedAddr(global_value, true);
            expr->const_llvm_val = global_value;
        } else {
            expr->const_llvm_val = gen_const_val(g, type_entry, const_val);
        }
        assert(expr->const_llvm_val);
    }
}

static void delete_unused_builtin_fns(CodeGen *g) {
    auto it = g->builtin_fn_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        BuiltinFnEntry *builtin_fn = entry->value;
        if (builtin_fn->ref_count == 0 &&
            builtin_fn->fn_val)
        {
            LLVMDeleteFunction(entry->value->fn_val);
        }
    }
}

static bool should_skip_fn_codegen(CodeGen *g, FnTableEntry *fn_entry) {
    if (g->is_test_build) {
        if (fn_entry->is_test) {
            return false;
        }
        if (fn_entry == g->main_fn) {
            return true;
        }
        return false;
    }

    if (fn_entry->is_test) {
        return true;
    }

    return false;
}

static LLVMValueRef gen_test_fn_val(CodeGen *g, FnTableEntry *fn_entry) {
    // Must match TestFn struct from test_runner.zig
    Buf *fn_name = &fn_entry->symbol_name;
    LLVMValueRef str_init = LLVMConstString(buf_ptr(fn_name), buf_len(fn_name), true);
    LLVMValueRef str_global_val = LLVMAddGlobal(g->module, LLVMTypeOf(str_init), "");
    LLVMSetInitializer(str_global_val, str_init);
    LLVMSetLinkage(str_global_val, LLVMPrivateLinkage);
    LLVMSetGlobalConstant(str_global_val, true);
    LLVMSetUnnamedAddr(str_global_val, true);

    LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref, buf_len(fn_name), false);

    LLVMTypeRef ptr_type = LLVMPointerType(g->builtin_types.entry_u8->type_ref, 0);
    LLVMValueRef name_fields[] = {
        LLVMConstBitCast(str_global_val, ptr_type),
        len_val,
    };

    LLVMValueRef name_val = LLVMConstStruct(name_fields, 2, false);
    LLVMValueRef fields[] = {
        name_val,
        fn_entry->fn_value,
    };
    return LLVMConstStruct(fields, 2, false);
}

static void generate_error_name_table(CodeGen *g) {
    if (!g->generate_error_name_table || g->error_decls.length == 1) {
        return;
    }

    assert(g->error_decls.length > 0);

    TypeTableEntry *str_type = get_slice_type(g, g->builtin_types.entry_u8, true);
    TypeTableEntry *u8_ptr_type = str_type->data.structure.fields[0].type_entry;

    LLVMValueRef *values = allocate<LLVMValueRef>(g->error_decls.length);
    values[0] = LLVMGetUndef(str_type->type_ref);
    for (int i = 1; i < g->error_decls.length; i += 1) {
        AstNode *error_decl_node = g->error_decls.at(i);
        assert(error_decl_node->type == NodeTypeErrorValueDecl);
        Buf *name = error_decl_node->data.error_value_decl.name;

        LLVMValueRef str_init = LLVMConstString(buf_ptr(name), buf_len(name), true);
        LLVMValueRef str_global = LLVMAddGlobal(g->module, LLVMTypeOf(str_init), "");
        LLVMSetInitializer(str_global, str_init);
        LLVMSetLinkage(str_global, LLVMPrivateLinkage);
        LLVMSetGlobalConstant(str_global, true);
        LLVMSetUnnamedAddr(str_global, true);

        LLVMValueRef fields[] = {
            LLVMConstBitCast(str_global, u8_ptr_type->type_ref),
            LLVMConstInt(g->builtin_types.entry_usize->type_ref, buf_len(name), false),
        };
        values[i] = LLVMConstNamedStruct(str_type->type_ref, fields, 2);
    }

    LLVMValueRef err_name_table_init = LLVMConstArray(str_type->type_ref, values, g->error_decls.length);

    g->err_name_table = LLVMAddGlobal(g->module, LLVMTypeOf(err_name_table_init), "err_name_table");
    LLVMSetInitializer(g->err_name_table, err_name_table_init);
    LLVMSetLinkage(g->err_name_table, LLVMPrivateLinkage);
    LLVMSetGlobalConstant(g->err_name_table, true);
    LLVMSetUnnamedAddr(g->err_name_table, true);
}

static void build_label_blocks(CodeGen *g, FnTableEntry *fn) {
    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn->fn_value, "entry");
    for (int i = 0; i < fn->all_labels.length; i += 1) {
        LabelTableEntry *label = fn->all_labels.at(i);
        Buf *name = label->decl_node->data.label.name;
        label->basic_block = LLVMAppendBasicBlock(fn->fn_value, buf_ptr(name));
    }
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
}

static void do_code_gen(CodeGen *g) {
    assert(!g->errors.length);

    delete_unused_builtin_fns(g);


    gen_const_globals(g);
    generate_error_name_table(g);

    // Generate module level variables
    for (int i = 0; i < g->global_vars.length; i += 1) {
        VariableTableEntry *var = g->global_vars.at(i);

        if (var->type->id == TypeTableEntryIdNumLitFloat ||
            var->type->id == TypeTableEntryIdNumLitInt ||
            !type_has_bits(var->type))
        {
            continue;
        }

        assert(var->decl_node);
        assert(var->decl_node->type == NodeTypeVariableDeclaration);

        LLVMValueRef global_value;
        if (var->decl_node->data.variable_declaration.is_extern) {
            global_value = LLVMAddGlobal(g->module, var->type->type_ref, buf_ptr(&var->name));

            LLVMSetLinkage(global_value, LLVMExternalLinkage);
        } else {
            AstNode *expr_node = var->decl_node->data.variable_declaration.expr;
            LLVMValueRef init_val;
            if (expr_node) {
                Expr *expr = get_resolved_expr(expr_node);
                ConstExprValue *const_val = &expr->const_val;
                assert(const_val->ok);
                TypeTableEntry *type_entry = expr->type_entry;
                init_val = gen_const_val(g, type_entry, const_val);
            } else {
                init_val = LLVMConstNull(var->type->type_ref);
            }

            global_value = LLVMAddGlobal(g->module, LLVMTypeOf(init_val), buf_ptr(&var->name));
            LLVMSetInitializer(global_value, init_val);
            LLVMSetLinkage(global_value, LLVMInternalLinkage);
            LLVMSetUnnamedAddr(global_value, true);
        }

        LLVMSetGlobalConstant(global_value, var->is_const);

        var->value_ref = global_value;
    }

    LLVMValueRef *test_fn_vals = nullptr;
    uint32_t next_test_index = 0;
    if (g->is_test_build) {
        test_fn_vals = allocate<LLVMValueRef>(g->test_fn_count);
    }

    // Generate function prototypes
    for (int fn_proto_i = 0; fn_proto_i < g->fn_protos.length; fn_proto_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_protos.at(fn_proto_i);
        if (should_skip_fn_codegen(g, fn_table_entry)) {
            // huge time saver
            LLVMDeleteFunction(fn_table_entry->fn_value);
            fn_table_entry->fn_value = nullptr;
            continue;
        }

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        TypeTableEntry *fn_type = fn_table_entry->type_entry;

        bool is_sret = false;
        if (!type_has_bits(fn_type->data.fn.fn_type_id.return_type)) {
            // nothing to do
        } else if (fn_type->data.fn.fn_type_id.return_type->id == TypeTableEntryIdPointer) {
            LLVMZigAddNonNullAttr(fn_table_entry->fn_value, 0);
        } else if (handle_is_ptr(fn_type->data.fn.fn_type_id.return_type) &&
                !fn_type->data.fn.fn_type_id.is_extern)
        {
            LLVMValueRef first_arg = LLVMGetParam(fn_table_entry->fn_value, 0);
            LLVMAddAttribute(first_arg, LLVMStructRetAttribute);
            LLVMZigAddNonNullAttr(fn_table_entry->fn_value, 1);
            is_sret = true;
        }
        if (fn_table_entry->is_pure && !is_sret && g->is_release_build) {
            LLVMAddFunctionAttr(fn_table_entry->fn_value, LLVMReadOnlyAttribute);
        }


        // set parameter attributes
        for (int param_decl_i = 0; param_decl_i < fn_proto->params.length; param_decl_i += 1) {
            AstNode *param_node = fn_proto->params.at(param_decl_i);
            assert(param_node->type == NodeTypeParamDecl);

            FnGenParamInfo *info = &fn_type->data.fn.gen_param_info[param_decl_i];
            int gen_index = info->gen_index;
            bool is_byval = info->is_byval;

            if (gen_index < 0) {
                continue;
            }

            TypeTableEntry *param_type = info->type;
            LLVMValueRef argument_val = LLVMGetParam(fn_table_entry->fn_value, gen_index);
            bool param_is_noalias = param_node->data.param_decl.is_noalias;
            if (param_is_noalias) {
                LLVMAddAttribute(argument_val, LLVMNoAliasAttribute);
            }
            if ((param_type->id == TypeTableEntryIdPointer && (param_type->data.pointer.is_const || fn_table_entry->is_pure)) ||
                is_byval)
            {
                LLVMAddAttribute(argument_val, LLVMReadOnlyAttribute);
            }
            if (param_type->id == TypeTableEntryIdPointer) {
                LLVMZigAddNonNullAttr(fn_table_entry->fn_value, gen_index + 1);
            }
            if (is_byval) {
                // TODO
                //LLVMAddAttribute(argument_val, LLVMByValAttribute);
            }
        }

        if (fn_table_entry->is_test) {
            test_fn_vals[next_test_index] = gen_test_fn_val(g, fn_table_entry);
            next_test_index += 1;
        }
    }

    // Generate the list of test function pointers.
    if (g->is_test_build) {
        if (g->test_fn_count == 0) {
            fprintf(stderr, "No tests to run.\n");
            exit(0);
        }
        assert(g->test_fn_count > 0);
        assert(next_test_index == g->test_fn_count);

        LLVMValueRef test_fn_array_init = LLVMConstArray(LLVMTypeOf(test_fn_vals[0]),
                test_fn_vals, g->test_fn_count);
        LLVMValueRef test_fn_array_val = LLVMAddGlobal(g->module,
                LLVMTypeOf(test_fn_array_init), "");
        LLVMSetInitializer(test_fn_array_val, test_fn_array_init);
        LLVMSetLinkage(test_fn_array_val, LLVMInternalLinkage);
        LLVMSetGlobalConstant(test_fn_array_val, true);
        LLVMSetUnnamedAddr(test_fn_array_val, true);

        LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref, g->test_fn_count, false);
        LLVMTypeRef ptr_type = LLVMPointerType(LLVMTypeOf(test_fn_vals[0]), 0);
        LLVMValueRef fields[] = {
            LLVMConstBitCast(test_fn_array_val, ptr_type),
            len_val,
        };
        LLVMValueRef test_fn_slice_init = LLVMConstStruct(fields, 2, false);
        LLVMValueRef test_fn_slice_val = LLVMAddGlobal(g->module,
                LLVMTypeOf(test_fn_slice_init), "zig_test_fn_list");
        LLVMSetInitializer(test_fn_slice_val, test_fn_slice_init);
        LLVMSetLinkage(test_fn_slice_val, LLVMExternalLinkage);
        LLVMSetGlobalConstant(test_fn_slice_val, true);
        LLVMSetUnnamedAddr(test_fn_slice_val, true);
    }

    // Generate function definitions.
    for (int fn_i = 0; fn_i < g->fn_defs.length; fn_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(fn_i);
        if (should_skip_fn_codegen(g, fn_table_entry)) {
            // huge time saver
            continue;
        }

        ImportTableEntry *import = fn_table_entry->import_entry;
        AstNode *fn_def_node = fn_table_entry->fn_def_node;
        LLVMValueRef fn = fn_table_entry->fn_value;
        g->cur_fn = fn_table_entry;
        if (handle_is_ptr(fn_table_entry->type_entry->data.fn.fn_type_id.return_type)) {
            g->cur_ret_ptr = LLVMGetParam(fn, 0);
        } else {
            g->cur_ret_ptr = nullptr;
        }

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        build_label_blocks(g, fn_table_entry);


        // Set up debug info for blocks
        for (int bc_i = 0; bc_i < fn_table_entry->all_block_contexts.length; bc_i += 1) {
            BlockContext *block_context = fn_table_entry->all_block_contexts.at(bc_i);

            if (!block_context->di_scope) {
                LLVMZigDILexicalBlock *di_block = LLVMZigCreateLexicalBlock(g->dbuilder,
                    block_context->parent->di_scope,
                    import->di_file,
                    block_context->node->line + 1,
                    block_context->node->column + 1);
                block_context->di_scope = LLVMZigLexicalBlockToScope(di_block);
            }


        }

        clear_debug_source_node(g);

        // allocate structs which are the result of casts
        for (int cea_i = 0; cea_i < fn_table_entry->cast_alloca_list.length; cea_i += 1) {
            AstNode *fn_call_node = fn_table_entry->cast_alloca_list.at(cea_i);
            Expr *expr = &fn_call_node->data.fn_call_expr.resolved_expr;
            fn_call_node->data.fn_call_expr.tmp_ptr = LLVMBuildAlloca(g->builder,
                    expr->type_entry->type_ref, "");
        }

        // allocate structs which are struct value expressions
        for (int alloca_i = 0; alloca_i < fn_table_entry->struct_val_expr_alloca_list.length; alloca_i += 1) {
            StructValExprCodeGen *struct_val_expr_node = fn_table_entry->struct_val_expr_alloca_list.at(alloca_i);
            struct_val_expr_node->ptr = LLVMBuildAlloca(g->builder,
                    struct_val_expr_node->type_entry->type_ref, "");
        }

        // create debug variable declarations for variables and allocate all local variables
        for (int var_i = 0; var_i < fn_table_entry->variable_list.length; var_i += 1) {
            VariableTableEntry *var = fn_table_entry->variable_list.at(var_i);

            if (!type_has_bits(var->type)) {
                continue;
            }

            if (var->block_context->node->type == NodeTypeFnDef) {
                assert(var->gen_arg_index >= 0);
                TypeTableEntry *gen_type;
                if (handle_is_ptr(var->type)) {
                    gen_type = fn_table_entry->type_entry->data.fn.gen_param_info[var->src_arg_index].type;
                    var->value_ref = LLVMGetParam(fn, var->gen_arg_index);
                } else {
                    gen_type = var->type;
                    var->value_ref = LLVMBuildAlloca(g->builder, var->type->type_ref, buf_ptr(&var->name));
                    unsigned align_bytes = ZigLLVMGetPrefTypeAlignment(g->target_data_ref, var->type->type_ref);
                    LLVMSetAlignment(var->value_ref, align_bytes);
                }
                var->di_loc_var = LLVMZigCreateParameterVariable(g->dbuilder, var->block_context->di_scope,
                        buf_ptr(&var->name), import->di_file, var->decl_node->line + 1,
                        gen_type->di_type, !g->strip_debug_symbols, 0, var->gen_arg_index + 1);

            } else {
                var->value_ref = LLVMBuildAlloca(g->builder, var->type->type_ref, buf_ptr(&var->name));


                unsigned align_bytes = ZigLLVMGetPrefTypeAlignment(g->target_data_ref, var->type->type_ref);
                LLVMSetAlignment(var->value_ref, align_bytes);

                var->di_loc_var = LLVMZigCreateAutoVariable(g->dbuilder, var->block_context->di_scope,
                        buf_ptr(&var->name), import->di_file, var->decl_node->line + 1,
                        var->type->di_type, !g->strip_debug_symbols, 0);
            }
        }

        // create debug variable declarations for parameters
        for (int param_i = 0; param_i < fn_proto->params.length; param_i += 1) {
            AstNode *param_decl = fn_proto->params.at(param_i);
            assert(param_decl->type == NodeTypeParamDecl);

            FnGenParamInfo *info = &fn_table_entry->type_entry->data.fn.gen_param_info[param_i];

            if (info->gen_index < 0) {
                continue;
            }

            VariableTableEntry *variable = param_decl->data.param_decl.variable;
            assert(variable);

            if (!handle_is_ptr(variable->type)) {
                clear_debug_source_node(g);
                LLVMBuildStore(g->builder, LLVMGetParam(fn, variable->gen_arg_index), variable->value_ref);
            }

            gen_var_debug_decl(g, variable);
        }


        TypeTableEntry *implicit_return_type = fn_def_node->data.fn_def.implicit_return_type;
        gen_block(g, fn_def_node->data.fn_def.body, implicit_return_type);

    }
    assert(!g->errors.length);

    LLVMZigDIBuilderFinalize(g->dbuilder);

    if (g->verbose) {
        LLVMDumpModule(g->module);
    }

    // in release mode, we're sooooo confident that we've generated correct ir,
    // that we skip the verify module step in order to get better performance.
#ifndef NDEBUG
    char *error = nullptr;
    LLVMVerifyModule(g->module, LLVMAbortProcessAction, &error);
#endif
}

static const int int_sizes_in_bits[] = {
    8,
    16,
    32,
    64,
};

struct CIntTypeInfo {
    CIntType id;
    const char *name;
    bool is_signed;
};

static const CIntTypeInfo c_int_type_infos[] = {
    {CIntTypeShort, "c_short", true},
    {CIntTypeUShort, "c_ushort", false},
    {CIntTypeInt, "c_int", true},
    {CIntTypeUInt, "c_uint", false},
    {CIntTypeLong, "c_long", true},
    {CIntTypeULong, "c_ulong", false},
    {CIntTypeLongLong, "c_longlong", true},
    {CIntTypeULongLong, "c_ulonglong", false},
};

static const bool is_signed_list[] = { false, true, };

static void define_builtin_types(CodeGen *g) {
    {
        // if this type is anywhere in the AST, we should never hit codegen.
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInvalid);
        buf_init_from_str(&entry->name, "(invalid)");
        entry->zero_bits = true;
        g->builtin_types.entry_invalid = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNamespace);
        buf_init_from_str(&entry->name, "(namespace)");
        entry->zero_bits = true;
        entry->deep_const = true;
        g->builtin_types.entry_namespace = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNumLitFloat);
        buf_init_from_str(&entry->name, "(float literal)");
        entry->zero_bits = true;
        entry->deep_const = true;
        g->builtin_types.entry_num_lit_float = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNumLitInt);
        buf_init_from_str(&entry->name, "(integer literal)");
        entry->zero_bits = true;
        entry->deep_const = true;
        g->builtin_types.entry_num_lit_int = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdUndefLit);
        buf_init_from_str(&entry->name, "(undefined)");
        entry->deep_const = true;
        g->builtin_types.entry_undef = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNullLit);
        buf_init_from_str(&entry->name, "(null)");
        entry->deep_const = true;
        g->builtin_types.entry_null = entry;
    }

    for (int int_size_i = 0; int_size_i < array_length(int_sizes_in_bits); int_size_i += 1) {
        int size_in_bits = int_sizes_in_bits[int_size_i];
        for (int is_sign_i = 0; is_sign_i < array_length(is_signed_list); is_sign_i += 1) {
            bool is_signed = is_signed_list[is_sign_i];

            TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
            entry->type_ref = LLVMIntType(size_in_bits);
            entry->deep_const = true;

            const char u_or_i = is_signed ? 'i' : 'u';
            buf_resize(&entry->name, 0);
            buf_appendf(&entry->name, "%c%d", u_or_i, size_in_bits);

            unsigned dwarf_tag;
            if (is_signed) {
                if (size_in_bits == 8) {
                    dwarf_tag = LLVMZigEncoding_DW_ATE_signed_char();
                } else {
                    dwarf_tag = LLVMZigEncoding_DW_ATE_signed();
                }
            } else {
                if (size_in_bits == 8) {
                    dwarf_tag = LLVMZigEncoding_DW_ATE_unsigned_char();
                } else {
                    dwarf_tag = LLVMZigEncoding_DW_ATE_unsigned();
                }
            }

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
            entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                    debug_size_in_bits, debug_align_in_bits, dwarf_tag);
            entry->data.integral.is_signed = is_signed;
            entry->data.integral.bit_count = size_in_bits;
            g->primitive_type_table.put(&entry->name, entry);

            get_int_type_ptr(g, is_signed, size_in_bits)[0] = entry;
        }
    }

    for (int i = 0; i < array_length(c_int_type_infos); i += 1) {
        const CIntTypeInfo *info = &c_int_type_infos[i];
        uint64_t size_in_bits = get_c_type_size_in_bits(&g->zig_target, info->id);
        bool is_signed = info->is_signed;

        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMIntType(size_in_bits);
        entry->deep_const = true;

        buf_init_from_str(&entry->name, info->name);

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                is_signed ? LLVMZigEncoding_DW_ATE_signed() : LLVMZigEncoding_DW_ATE_unsigned());
        entry->data.integral.is_signed = is_signed;
        entry->data.integral.bit_count = size_in_bits;
        g->primitive_type_table.put(&entry->name, entry);

        get_c_int_type_ptr(g, info->id)[0] = entry;
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdBool);
        entry->type_ref = LLVMInt1Type();
        entry->deep_const = true;
        buf_init_from_str(&entry->name, "bool");
        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                LLVMZigEncoding_DW_ATE_boolean());
        g->builtin_types.entry_bool = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    for (int sign_i = 0; sign_i < array_length(is_signed_list); sign_i += 1) {
        bool is_signed = is_signed_list[sign_i];

        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->deep_const = true;
        entry->type_ref = LLVMIntType(g->pointer_size_bytes * 8);

        const char u_or_i = is_signed ? 'i' : 'u';
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "%csize", u_or_i);

        entry->data.integral.is_signed = is_signed;
        entry->data.integral.bit_count = g->pointer_size_bytes * 8;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                is_signed ? LLVMZigEncoding_DW_ATE_signed() : LLVMZigEncoding_DW_ATE_unsigned());
        g->primitive_type_table.put(&entry->name, entry);

        if (is_signed) {
            g->builtin_types.entry_isize = entry;
        } else {
            g->builtin_types.entry_usize = entry;
        }
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->deep_const = true;
        entry->type_ref = LLVMFloatType();
        buf_init_from_str(&entry->name, "f32");
        entry->data.floating.bit_count = 32;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                LLVMZigEncoding_DW_ATE_float());
        g->builtin_types.entry_f32 = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->deep_const = true;
        entry->type_ref = LLVMDoubleType();
        buf_init_from_str(&entry->name, "f64");
        entry->data.floating.bit_count = 64;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                LLVMZigEncoding_DW_ATE_float());
        g->builtin_types.entry_f64 = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->deep_const = true;
        entry->type_ref = LLVMX86FP80Type();
        buf_init_from_str(&entry->name, "c_long_double");
        entry->data.floating.bit_count = 80;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                LLVMZigEncoding_DW_ATE_float());
        g->builtin_types.entry_c_long_double = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdVoid);
        entry->deep_const = true;
        entry->type_ref = LLVMVoidType();
        entry->zero_bits = true;
        buf_init_from_str(&entry->name, "void");
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                0,
                0,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->builtin_types.entry_void = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdUnreachable);
        entry->deep_const = true;
        entry->type_ref = LLVMVoidType();
        entry->zero_bits = true;
        buf_init_from_str(&entry->name, "unreachable");
        entry->di_type = g->builtin_types.entry_void->di_type;
        g->builtin_types.entry_unreachable = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdMetaType);
        entry->deep_const = true;
        buf_init_from_str(&entry->name, "type");
        entry->zero_bits = true;
        g->builtin_types.entry_type = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    g->builtin_types.entry_u8 = get_int_type(g, false, 8);
    g->builtin_types.entry_u16 = get_int_type(g, false, 16);
    g->builtin_types.entry_u32 = get_int_type(g, false, 32);
    g->builtin_types.entry_u64 = get_int_type(g, false, 64);
    g->builtin_types.entry_i8 = get_int_type(g, true, 8);
    g->builtin_types.entry_i16 = get_int_type(g, true, 16);
    g->builtin_types.entry_i32 = get_int_type(g, true, 32);
    g->builtin_types.entry_i64 = get_int_type(g, true, 64);

    {
        g->builtin_types.entry_c_void = get_typedecl_type(g, "c_void", g->builtin_types.entry_u8);
        g->primitive_type_table.put(&g->builtin_types.entry_c_void->name, g->builtin_types.entry_c_void);
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdPureError);
        entry->deep_const = true;
        buf_init_from_str(&entry->name, "error");

        // TODO allow overriding this type and keep track of max value and emit an
        // error if there are too many errors declared
        g->err_tag_type = g->builtin_types.entry_u16;

        g->builtin_types.entry_pure_error = entry;
        entry->type_ref = g->err_tag_type->type_ref;
        entry->di_type = g->err_tag_type->di_type;

        g->primitive_type_table.put(&entry->name, entry);
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->deep_const = true;
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "@OS");
        uint32_t field_count = target_os_count();
        entry->data.enumeration.field_count = field_count;
        entry->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        for (uint32_t i = 0; i < field_count; i += 1) {
            TypeEnumField *type_enum_field = &entry->data.enumeration.fields[i];
            ZigLLVM_OSType os_type = get_target_os(i);
            type_enum_field->name = buf_create_from_str(get_target_os_name(os_type));
            type_enum_field->value = i;

            if (os_type == g->zig_target.os) {
                g->target_os_index = i;
            }
        }
        entry->data.enumeration.complete = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_os_enum = entry;
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->deep_const = true;
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "@Arch");
        uint32_t field_count = target_arch_count();
        entry->data.enumeration.field_count = field_count;
        entry->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        for (uint32_t i = 0; i < field_count; i += 1) {
            TypeEnumField *type_enum_field = &entry->data.enumeration.fields[i];
            const ArchType *arch_type = get_target_arch(i);
            type_enum_field->name = buf_alloc();
            buf_resize(type_enum_field->name, 50);
            get_arch_name(buf_ptr(type_enum_field->name), arch_type);
            buf_resize(type_enum_field->name, strlen(buf_ptr(type_enum_field->name)));

            type_enum_field->value = i;

            if (arch_type->arch == g->zig_target.arch.arch &&
                arch_type->sub_arch == g->zig_target.arch.sub_arch)
            {
                g->target_arch_index = i;
            }
        }
        entry->data.enumeration.complete = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_arch_enum = entry;
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->deep_const = true;
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "@Environ");
        uint32_t field_count = target_environ_count();
        entry->data.enumeration.field_count = field_count;
        entry->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        for (uint32_t i = 0; i < field_count; i += 1) {
            TypeEnumField *type_enum_field = &entry->data.enumeration.fields[i];
            ZigLLVM_EnvironmentType environ_type = get_target_environ(i);
            type_enum_field->name = buf_create_from_str(ZigLLVMGetEnvironmentTypeName(environ_type));
            type_enum_field->value = i;
            type_enum_field->type_entry = g->builtin_types.entry_void;

            if (environ_type == g->zig_target.env_type) {
                g->target_environ_index = i;
            }
        }
        entry->data.enumeration.complete = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_environ_enum = entry;
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->deep_const = true;
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "@ObjectFormat");
        uint32_t field_count = target_oformat_count();
        entry->data.enumeration.field_count = field_count;
        entry->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        for (uint32_t i = 0; i < field_count; i += 1) {
            TypeEnumField *type_enum_field = &entry->data.enumeration.fields[i];
            ZigLLVM_ObjectFormatType oformat = get_target_oformat(i);
            type_enum_field->name = buf_create_from_str(get_target_oformat_name(oformat));
            type_enum_field->value = i;
            type_enum_field->type_entry = g->builtin_types.entry_void;

            if (oformat == g->zig_target.oformat) {
                g->target_oformat_index = i;
            }
        }
        entry->data.enumeration.complete = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_oformat_enum = entry;
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->deep_const = true;
        buf_init_from_str(&entry->name, "AtomicOrder");
        uint32_t field_count = 6;
        entry->data.enumeration.field_count = field_count;
        entry->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        entry->data.enumeration.fields[0].name = buf_create_from_str("Unordered");
        entry->data.enumeration.fields[0].value = AtomicOrderUnordered;
        entry->data.enumeration.fields[0].type_entry = g->builtin_types.entry_void;
        entry->data.enumeration.fields[1].name = buf_create_from_str("Monotonic");
        entry->data.enumeration.fields[1].value = AtomicOrderMonotonic;
        entry->data.enumeration.fields[1].type_entry = g->builtin_types.entry_void;
        entry->data.enumeration.fields[2].name = buf_create_from_str("Acquire");
        entry->data.enumeration.fields[2].value = AtomicOrderAcquire;
        entry->data.enumeration.fields[2].type_entry = g->builtin_types.entry_void;
        entry->data.enumeration.fields[3].name = buf_create_from_str("Release");
        entry->data.enumeration.fields[3].value = AtomicOrderRelease;
        entry->data.enumeration.fields[3].type_entry = g->builtin_types.entry_void;
        entry->data.enumeration.fields[4].name = buf_create_from_str("AcqRel");
        entry->data.enumeration.fields[4].value = AtomicOrderAcqRel;
        entry->data.enumeration.fields[4].type_entry = g->builtin_types.entry_void;
        entry->data.enumeration.fields[5].name = buf_create_from_str("SeqCst");
        entry->data.enumeration.fields[5].value = AtomicOrderSeqCst;
        entry->data.enumeration.fields[5].type_entry = g->builtin_types.entry_void;

        entry->data.enumeration.complete = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_atomic_order_enum = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
}


static BuiltinFnEntry *create_builtin_fn(CodeGen *g, BuiltinFnId id, const char *name) {
    BuiltinFnEntry *builtin_fn = allocate<BuiltinFnEntry>(1);
    buf_init_from_str(&builtin_fn->name, name);
    builtin_fn->id = id;
    g->builtin_fn_table.put(&builtin_fn->name, builtin_fn);
    return builtin_fn;
}

static BuiltinFnEntry *create_builtin_fn_with_arg_count(CodeGen *g, BuiltinFnId id, const char *name, int count) {
    BuiltinFnEntry *builtin_fn = create_builtin_fn(g, id, name);
    builtin_fn->param_count = count;
    builtin_fn->param_types = allocate<TypeTableEntry *>(count);
    return builtin_fn;
}

static void define_builtin_fns(CodeGen *g) {
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn_with_arg_count(g, BuiltinFnIdBreakpoint, "breakpoint", 0);
        builtin_fn->return_type = g->builtin_types.entry_void;
        builtin_fn->ref_count = 1;

        LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), nullptr, 0, false);
        builtin_fn->fn_val = LLVMAddFunction(g->module, "llvm.debugtrap", fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));

        g->trap_fn_val = builtin_fn->fn_val;
    }
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn_with_arg_count(g, BuiltinFnIdReturnAddress,
                "returnAddress", 0);
        builtin_fn->return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

        LLVMTypeRef fn_type = LLVMFunctionType(builtin_fn->return_type->type_ref,
                &g->builtin_types.entry_i32->type_ref, 1, false);
        builtin_fn->fn_val = LLVMAddFunction(g->module, "llvm.returnaddress", fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));
    }
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn_with_arg_count(g, BuiltinFnIdFrameAddress,
                "frameAddress", 0);
        builtin_fn->return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

        LLVMTypeRef fn_type = LLVMFunctionType(builtin_fn->return_type->type_ref,
                &g->builtin_types.entry_i32->type_ref, 1, false);
        builtin_fn->fn_val = LLVMAddFunction(g->module, "llvm.frameaddress", fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));
    }
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn(g, BuiltinFnIdMemcpy, "memcpy");
        builtin_fn->return_type = g->builtin_types.entry_void;
        builtin_fn->param_count = 3;
        builtin_fn->param_types = allocate<TypeTableEntry *>(builtin_fn->param_count);
        builtin_fn->param_types[0] = nullptr; // manually checked later
        builtin_fn->param_types[1] = nullptr; // manually checked later
        builtin_fn->param_types[2] = g->builtin_types.entry_usize;
        builtin_fn->ref_count = 1;

        LLVMTypeRef param_types[] = {
            LLVMPointerType(LLVMInt8Type(), 0),
            LLVMPointerType(LLVMInt8Type(), 0),
            LLVMIntType(g->pointer_size_bytes * 8),
            LLVMInt32Type(),
            LLVMInt1Type(),
        };
        LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), param_types, 5, false);
        Buf *name = buf_sprintf("llvm.memcpy.p0i8.p0i8.i%d", g->pointer_size_bytes * 8);
        builtin_fn->fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));

        g->memcpy_fn_val = builtin_fn->fn_val;
    }
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn(g, BuiltinFnIdMemset, "memset");
        builtin_fn->return_type = g->builtin_types.entry_void;
        builtin_fn->param_count = 3;
        builtin_fn->param_types = allocate<TypeTableEntry *>(builtin_fn->param_count);
        builtin_fn->param_types[0] = nullptr; // manually checked later
        builtin_fn->param_types[1] = g->builtin_types.entry_u8;
        builtin_fn->param_types[2] = g->builtin_types.entry_usize;
        builtin_fn->ref_count = 1;

        LLVMTypeRef param_types[] = {
            LLVMPointerType(LLVMInt8Type(), 0),
            LLVMInt8Type(),
            LLVMIntType(g->pointer_size_bytes * 8),
            LLVMInt32Type(),
            LLVMInt1Type(),
        };
        LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), param_types, 5, false);
        Buf *name = buf_sprintf("llvm.memset.p0i8.i%d", g->pointer_size_bytes * 8);
        builtin_fn->fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));

        g->memset_fn_val = builtin_fn->fn_val;
    }
    create_builtin_fn_with_arg_count(g, BuiltinFnIdSizeof, "sizeOf", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdAlignof, "alignOf", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdMaxValue, "maxValue", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdMinValue, "minValue", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdMemberCount, "memberCount", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdTypeof, "typeOf", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdAddWithOverflow, "addWithOverflow", 4);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdSubWithOverflow, "subWithOverflow", 4);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdMulWithOverflow, "mulWithOverflow", 4);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdShlWithOverflow, "shlWithOverflow", 4);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCInclude, "cInclude", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCDefine, "cDefine", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCUndef, "cUndef", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCompileVar, "compileVar", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdConstEval, "constEval", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCtz, "ctz", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdClz, "clz", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdImport, "import", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCImport, "cImport", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdErrName, "errName", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdEmbedFile, "embedFile", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCmpExchange, "cmpxchg", 5);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdFence, "fence", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdDivExact, "divExact", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdTruncate, "truncate", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCompileErr, "compileErr", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdIntType, "intType", 2);
}

static void init(CodeGen *g, Buf *source_path) {
    g->module = LLVMModuleCreateWithName(buf_ptr(source_path));

    get_target_triple(&g->triple_str, &g->zig_target);

    LLVMSetTarget(g->module, buf_ptr(&g->triple_str));

    ZigLLVMAddModuleDebugInfoFlag(g->module);

    LLVMTargetRef target_ref;
    char *err_msg = nullptr;
    if (LLVMGetTargetFromTriple(buf_ptr(&g->triple_str), &target_ref, &err_msg)) {
        zig_panic("unable to create target based on: %s", buf_ptr(&g->triple_str));
    }


    LLVMCodeGenOptLevel opt_level = g->is_release_build ? LLVMCodeGenLevelAggressive : LLVMCodeGenLevelNone;

    LLVMRelocMode reloc_mode = g->is_static ? LLVMRelocStatic : LLVMRelocPIC;

    const char *target_specific_cpu_args;
    const char *target_specific_features;
    if (g->is_native_target) {
        target_specific_cpu_args = LLVMZigGetHostCPUName();
        target_specific_features = LLVMZigGetNativeFeatures();
    } else {
        target_specific_cpu_args = "";
        target_specific_features = "";
    }

    g->target_machine = LLVMCreateTargetMachine(target_ref, buf_ptr(&g->triple_str),
            target_specific_cpu_args, target_specific_features, opt_level, reloc_mode, LLVMCodeModelDefault);

    g->target_data_ref = LLVMGetTargetMachineData(g->target_machine);

    char *layout_str = LLVMCopyStringRepOfTargetData(g->target_data_ref);
    LLVMSetDataLayout(g->module, layout_str);


    g->pointer_size_bytes = LLVMPointerSize(g->target_data_ref);
    g->is_big_endian = (LLVMByteOrder(g->target_data_ref) == LLVMBigEndian);

    g->builder = LLVMCreateBuilder();
    g->dbuilder = LLVMZigCreateDIBuilder(g->module, true);

    LLVMZigSetFastMath(g->builder, true);


    Buf *producer = buf_sprintf("zig %s", ZIG_VERSION_STRING);
    bool is_optimized = g->is_release_build;
    const char *flags = "";
    unsigned runtime_version = 0;
    g->compile_unit = LLVMZigCreateCompileUnit(g->dbuilder, LLVMZigLang_DW_LANG_C99(),
            buf_ptr(source_path), buf_ptr(&g->root_package->root_src_dir),
            buf_ptr(producer), is_optimized, flags, runtime_version,
            "", 0, !g->strip_debug_symbols);

    // This is for debug stuff that doesn't have a real file.
    g->dummy_di_file = nullptr;

    define_builtin_types(g);
    define_builtin_fns(g);

}

void codegen_parseh(CodeGen *g, Buf *src_dirname, Buf *src_basename, Buf *source_code) {
    find_libc_include_path(g);
    Buf *full_path = buf_alloc();
    os_path_join(src_dirname, src_basename, full_path);

    ImportTableEntry *import = allocate<ImportTableEntry>(1);
    import->source_code = source_code;
    import->path = full_path;
    g->root_import = import;

    init(g, full_path);

    import->di_file = LLVMZigCreateFile(g->dbuilder, buf_ptr(src_basename), buf_ptr(src_dirname));

    ZigList<ErrorMsg *> errors = {0};
    int err = parse_h_buf(import, &errors, source_code, g, nullptr);
    if (err) {
        fprintf(stderr, "unable to parse .h file: %s\n", err_str(err));
        exit(1);
    }

    if (errors.length > 0) {
        for (int i = 0; i < errors.length; i += 1) {
            ErrorMsg *err_msg = errors.at(i);
            print_err_msg(err_msg, g->err_color);
        }
        exit(1);
    }
}

void codegen_render_ast(CodeGen *g, FILE *f, int indent_size) {
    ast_render(stdout, g->root_import->root, 4);
}


static ImportTableEntry *add_special_code(CodeGen *g, PackageTableEntry *package, const char *basename) {
    Buf *std_dir = g->zig_std_dir;
    Buf *code_basename = buf_create_from_str(basename);
    Buf path_to_code_src = BUF_INIT;
    os_path_join(std_dir, code_basename, &path_to_code_src);
    Buf *abs_full_path = buf_alloc();
    int err;
    if ((err = os_path_real(&path_to_code_src, abs_full_path))) {
        zig_panic("unable to open '%s': %s", buf_ptr(&path_to_code_src), err_str(err));
    }
    Buf *import_code = buf_alloc();
    if ((err = os_fetch_file_path(abs_full_path, import_code))) {
        zig_panic("unable to open '%s': %s", buf_ptr(&path_to_code_src), err_str(err));
    }

    return add_source_file(g, package, abs_full_path, std_dir, code_basename, import_code);
}

static PackageTableEntry *create_bootstrap_pkg(CodeGen *g) {
    PackageTableEntry *package = new_package(buf_ptr(g->zig_std_dir), "");
    package->package_table.put(buf_create_from_str("std"), g->std_package);
    package->package_table.put(buf_create_from_str("@root"), g->root_package);
    return package;
}

void codegen_add_root_code(CodeGen *g, Buf *src_dir, Buf *src_basename, Buf *source_code) {
    Buf source_path = BUF_INIT;
    os_path_join(src_dir, src_basename, &source_path);

    buf_init_from_buf(&g->root_package->root_src_path, src_basename);

    init(g, &source_path);

    Buf *abs_full_path = buf_alloc();
    int err;
    if ((err = os_path_real(&source_path, abs_full_path))) {
        zig_panic("unable to open '%s': %s", buf_ptr(&source_path), err_str(err));
    }

    g->root_import = add_source_file(g, g->root_package, abs_full_path, src_dir, src_basename, source_code);

    assert(g->root_out_name);
    assert(g->out_type != OutTypeUnknown);

    if (!g->link_libc && !g->is_test_build) {
        if (g->have_exported_main && (g->out_type == OutTypeObj || g->out_type == OutTypeExe)) {
            g->bootstrap_import = add_special_code(g, create_bootstrap_pkg(g), "bootstrap.zig");
        }
    }

    if (g->verbose) {
        fprintf(stderr, "\nSemantic Analysis:\n");
        fprintf(stderr, "--------------------\n");
    }
    if (!g->error_during_imports) {
        semantic_analyze(g);
    }

    if (g->errors.length == 0) {
        if (g->verbose) {
            fprintf(stderr, "OK\n");
        }
    } else {
        for (int i = 0; i < g->errors.length; i += 1) {
            ErrorMsg *err = g->errors.at(i);
            print_err_msg(err, g->err_color);
        }
        exit(1);
    }

    if (g->verbose) {
        fprintf(stderr, "\nCode Generation:\n");
        fprintf(stderr, "------------------\n");
    }

    do_code_gen(g);
}

static void to_c_type(CodeGen *g, AstNode *type_node, Buf *out_buf) {
    zig_panic("TODO this function needs some love");
    TypeTableEntry *type_entry = get_resolved_expr(type_node)->type_entry;
    assert(type_entry);

    if (type_entry == g->builtin_types.entry_u8) {
        g->c_stdint_used = true;
        buf_init_from_str(out_buf, "uint8_t");
    } else if (type_entry == g->builtin_types.entry_i32) {
        g->c_stdint_used = true;
        buf_init_from_str(out_buf, "int32_t");
    } else if (type_entry == g->builtin_types.entry_isize) {
        g->c_stdint_used = true;
        buf_init_from_str(out_buf, "intptr_t");
    } else if (type_entry == g->builtin_types.entry_f32) {
        buf_init_from_str(out_buf, "float");
    } else if (type_entry == g->builtin_types.entry_unreachable) {
        buf_init_from_str(out_buf, "__attribute__((__noreturn__)) void");
    } else if (type_entry == g->builtin_types.entry_bool) {
        buf_init_from_str(out_buf, "unsigned char");
    } else if (type_entry == g->builtin_types.entry_void) {
        buf_init_from_str(out_buf, "void");
    } else {
        zig_panic("TODO to_c_type");
    }
}

void codegen_generate_h_file(CodeGen *g) {
    assert(!g->is_test_build);

    Buf *h_file_out_path = buf_sprintf("%s.h", buf_ptr(g->root_out_name));
    FILE *out_h = fopen(buf_ptr(h_file_out_path), "wb");
    if (!out_h)
        zig_panic("unable to open %s: %s", buf_ptr(h_file_out_path), strerror(errno));

    Buf *export_macro = buf_sprintf("%s_EXPORT", buf_ptr(g->root_out_name));
    buf_upcase(export_macro);

    Buf *extern_c_macro = buf_sprintf("%s_EXTERN_C", buf_ptr(g->root_out_name));
    buf_upcase(extern_c_macro);

    Buf h_buf = BUF_INIT;
    buf_resize(&h_buf, 0);
    for (int fn_def_i = 0; fn_def_i < g->fn_defs.length; fn_def_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(fn_def_i);
        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        if (fn_proto->top_level_decl.visib_mod != VisibModExport)
            continue;

        Buf return_type_c = BUF_INIT;
        to_c_type(g, fn_proto->return_type, &return_type_c);

        buf_appendf(&h_buf, "%s %s %s(",
                buf_ptr(export_macro),
                buf_ptr(&return_type_c),
                buf_ptr(fn_proto->name));

        Buf param_type_c = BUF_INIT;
        if (fn_proto->params.length) {
            for (int param_i = 0; param_i < fn_proto->params.length; param_i += 1) {
                AstNode *param_decl_node = fn_proto->params.at(param_i);
                AstNode *param_type = param_decl_node->data.param_decl.type;
                to_c_type(g, param_type, &param_type_c);
                buf_appendf(&h_buf, "%s %s",
                        buf_ptr(&param_type_c),
                        buf_ptr(param_decl_node->data.param_decl.name));
                if (param_i < fn_proto->params.length - 1)
                    buf_appendf(&h_buf, ", ");
            }
            buf_appendf(&h_buf, ")");
        } else {
            buf_appendf(&h_buf, "void)");
        }

        buf_appendf(&h_buf, ";\n");

    }

    Buf *ifdef_dance_name = buf_sprintf("%s_%s_H",
            buf_ptr(g->root_out_name), buf_ptr(g->root_out_name));
    buf_upcase(ifdef_dance_name);

    fprintf(out_h, "#ifndef %s\n", buf_ptr(ifdef_dance_name));
    fprintf(out_h, "#define %s\n\n", buf_ptr(ifdef_dance_name));

    if (g->c_stdint_used)
        fprintf(out_h, "#include <stdint.h>\n");

    fprintf(out_h, "\n");

    fprintf(out_h, "#ifdef __cplusplus\n");
    fprintf(out_h, "#define %s extern \"C\"\n", buf_ptr(extern_c_macro));
    fprintf(out_h, "#else\n");
    fprintf(out_h, "#define %s\n", buf_ptr(extern_c_macro));
    fprintf(out_h, "#endif\n");
    fprintf(out_h, "\n");
    fprintf(out_h, "#if defined(_WIN32)\n");
    fprintf(out_h, "#define %s %s __declspec(dllimport)\n", buf_ptr(export_macro), buf_ptr(extern_c_macro));
    fprintf(out_h, "#else\n");
    fprintf(out_h, "#define %s %s __attribute__((visibility (\"default\")))\n",
            buf_ptr(export_macro), buf_ptr(extern_c_macro));
    fprintf(out_h, "#endif\n");
    fprintf(out_h, "\n");

    fprintf(out_h, "%s", buf_ptr(&h_buf));

    fprintf(out_h, "\n#endif\n");

    if (fclose(out_h))
        zig_panic("unable to close h file: %s", strerror(errno));
}
