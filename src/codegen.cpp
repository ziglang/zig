/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ast_render.hpp"
#include "codegen.hpp"
#include "config.h"
#include "errmsg.hpp"
#include "error.hpp"
#include "hash_map.hpp"
#include "ir.hpp"
#include "link.hpp"
#include "os.hpp"
#include "parseh.hpp"
#include "target.hpp"
#include "zig_llvm.hpp"

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
    g->want_h_file = true;

    g->len_buf = buf_create_from_str("len");

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

void codegen_set_clang_argv(CodeGen *g, const char **args, size_t len) {
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

void codegen_add_framework(CodeGen *g, const char *framework) {
    g->darwin_frameworks.append(buf_create_from_str(framework));
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

static void render_const_val(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val);
static void render_const_val_global(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val);

static void set_debug_source_node(CodeGen *g, AstNode *node) {
    assert(node->block_context);
    ZigLLVMSetCurrentDebugLocation(g->builder, node->line + 1, node->column + 1, node->block_context->di_scope);
}

static void clear_debug_source_node(CodeGen *g) {
    ZigLLVMClearCurrentDebugLocation(g->builder);
}

enum AddSubMul {
    AddSubMulAdd = 0,
    AddSubMulSub = 1,
    AddSubMulMul = 2,
};

static size_t bits_index(size_t size_in_bits) {
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
    Buf *llvm_name = buf_sprintf("llvm.%s.with.overflow.i%zu", signed_str, type_entry->data.integral.bit_count);

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
    size_t index0 = type_entry->data.integral.is_signed ? 0 : 1;
    size_t index1 = add_sub_mul;
    size_t index2 = bits_index(type_entry->data.integral.bit_count);
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

static LLVMValueRef get_handle_value(CodeGen *g, LLVMValueRef ptr, TypeTableEntry *type) {
    if (handle_is_ptr(type)) {
        return ptr;
    } else {
        return LLVMBuildLoad(g->builder, ptr, "");
    }
}

static bool want_debug_safety_recursive(CodeGen *g, BlockContext *context) {
    if (context->safety_set_node || !context->parent) {
        return !context->safety_off;
    }
    context->safety_off = !want_debug_safety_recursive(g, context->parent);
    context->safety_set_node = context->parent->safety_set_node;
    return !context->safety_off;
}

static bool want_debug_safety(CodeGen *g, AstNode *node) {
    if (g->is_release_build) {
        return false;
    }
    return want_debug_safety_recursive(g, node->block_context);
}

static bool ir_want_debug_safety(CodeGen *g, IrInstruction *instruction) {
    return want_debug_safety(g, instruction->source_node);
}

static void gen_debug_safety_crash(CodeGen *g) {
    LLVMBuildCall(g->builder, g->trap_fn_val, nullptr, 0, "");
    LLVMBuildUnreachable(g->builder);
}

static void add_bounds_check(CodeGen *g, LLVMValueRef target_val,
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
            return LLVMBuildFPExt(g->builder, expr_val, wanted_type->type_ref, "");
        } else if (actual_type->id == TypeTableEntryIdInt) {
            if (actual_type->data.integral.is_signed) {
                return LLVMBuildSExt(g->builder, expr_val, wanted_type->type_ref, "");
            } else {
                return LLVMBuildZExt(g->builder, expr_val, wanted_type->type_ref, "");
            }
        } else {
            zig_unreachable();
        }
    } else if (actual_bits > wanted_bits) {
        if (actual_type->id == TypeTableEntryIdFloat) {
            return LLVMBuildFPTrunc(g->builder, expr_val, wanted_type->type_ref, "");
        } else if (actual_type->id == TypeTableEntryIdInt) {
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

static LLVMIntPredicate cmp_op_to_int_predicate(IrBinOp cmp_op, bool is_signed) {
    switch (cmp_op) {
        case IrBinOpCmpEq:
            return LLVMIntEQ;
        case IrBinOpCmpNotEq:
            return LLVMIntNE;
        case IrBinOpCmpLessThan:
            return is_signed ? LLVMIntSLT : LLVMIntULT;
        case IrBinOpCmpGreaterThan:
            return is_signed ? LLVMIntSGT : LLVMIntUGT;
        case IrBinOpCmpLessOrEq:
            return is_signed ? LLVMIntSLE : LLVMIntULE;
        case IrBinOpCmpGreaterOrEq:
            return is_signed ? LLVMIntSGE : LLVMIntUGE;
        default:
            zig_unreachable();
    }
}

static LLVMRealPredicate cmp_op_to_real_predicate(IrBinOp cmp_op) {
    switch (cmp_op) {
        case IrBinOpCmpEq:
            return LLVMRealOEQ;
        case IrBinOpCmpNotEq:
            return LLVMRealONE;
        case IrBinOpCmpLessThan:
            return LLVMRealOLT;
        case IrBinOpCmpGreaterThan:
            return LLVMRealOGT;
        case IrBinOpCmpLessOrEq:
            return LLVMRealOLE;
        case IrBinOpCmpGreaterOrEq:
            return LLVMRealOGE;
        default:
            zig_unreachable();
    }
}

static LLVMValueRef gen_struct_memcpy(CodeGen *g, LLVMValueRef src, LLVMValueRef dest,
        TypeTableEntry *type_entry)
{
    assert(handle_is_ptr(type_entry));

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

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

static LLVMValueRef gen_assign_raw(CodeGen *g, AstNode *source_node,
        LLVMValueRef target_ref, LLVMValueRef value,
        TypeTableEntry *op1_type, TypeTableEntry *op2_type)
{
    if (!type_has_bits(op1_type)) {
        return nullptr;
    }
    if (handle_is_ptr(op1_type)) {
        assert(op1_type == op2_type);

        return gen_struct_memcpy(g, value, target_ref, op1_type);
    }

    LLVMBuildStore(g->builder, value, target_ref);
    return nullptr;
}

static void gen_var_debug_decl(CodeGen *g, VariableTableEntry *var) {
    BlockContext *block_context = var->block_context;
    AstNode *source_node = var->decl_node;
    ZigLLVMDILocation *debug_loc = ZigLLVMGetDebugLoc(source_node->line + 1, source_node->column + 1,
            block_context->di_scope);
    ZigLLVMInsertDeclareAtEnd(g->dbuilder, var->value_ref, var->di_loc_var, debug_loc,
            LLVMGetInsertBlock(g->builder));
}

static LLVMValueRef ir_llvm_value(CodeGen *g, IrInstruction *instruction) {
    if (!type_has_bits(instruction->type_entry))
        return nullptr;
    if (!instruction->llvm_value) {
        assert(instruction->static_value.special != ConstValSpecialRuntime);
        assert(instruction->type_entry);
        render_const_val(g, instruction->type_entry, &instruction->static_value);
        instruction->llvm_value = instruction->static_value.llvm_value;
        assert(instruction->llvm_value);
    }
    if (instruction->static_value.special != ConstValSpecialRuntime) {
        if (instruction->type_entry->id == TypeTableEntryIdPointer) {
            return LLVMBuildLoad(g->builder, instruction->static_value.llvm_global, "");
        }
    }
    return instruction->llvm_value;
}

static LLVMValueRef ir_render_return(CodeGen *g, IrExecutable *executable, IrInstructionReturn *return_instruction) {
    LLVMBuildRet(g->builder, ir_llvm_value(g, return_instruction->value));
    return nullptr;
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

static LLVMValueRef gen_div(CodeGen *g, AstNode *source_node, LLVMValueRef val1, LLVMValueRef val2,
        TypeTableEntry *type_entry, bool exact)
{

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

static LLVMValueRef ir_render_bin_op(CodeGen *g, IrExecutable *executable,
        IrInstructionBinOp *bin_op_instruction)
{
    IrBinOp op_id = bin_op_instruction->op_id;
    IrInstruction *op1 = bin_op_instruction->op1;
    IrInstruction *op2 = bin_op_instruction->op2;
    AstNode *source_node = bin_op_instruction->base.source_node;

    assert(op1->type_entry == op2->type_entry);

    LLVMValueRef op1_value = ir_llvm_value(g, op1);
    LLVMValueRef op2_value = ir_llvm_value(g, op2);
    switch (op_id) {
        case IrBinOpInvalid:
        case IrBinOpArrayCat:
        case IrBinOpArrayMult:
            zig_unreachable();
        case IrBinOpBoolOr:
            return LLVMBuildOr(g->builder, op1_value, op2_value, "");
        case IrBinOpBoolAnd:
            return LLVMBuildAnd(g->builder, op1_value, op2_value, "");
        case IrBinOpCmpEq:
        case IrBinOpCmpNotEq:
        case IrBinOpCmpLessThan:
        case IrBinOpCmpGreaterThan:
        case IrBinOpCmpLessOrEq:
        case IrBinOpCmpGreaterOrEq:
            if (op1->type_entry->id == TypeTableEntryIdFloat) {
                LLVMRealPredicate pred = cmp_op_to_real_predicate(op_id);
                return LLVMBuildFCmp(g->builder, pred, op1_value, op2_value, "");
            } else if (op1->type_entry->id == TypeTableEntryIdInt) {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, op1->type_entry->data.integral.is_signed);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else if (op1->type_entry->id == TypeTableEntryIdEnum) {
                if (op1->type_entry->data.enumeration.gen_field_count == 0) {
                    LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, false);
                    return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
                } else {
                    zig_unreachable();
                }
            } else if (op1->type_entry->id == TypeTableEntryIdPureError ||
                    op1->type_entry->id == TypeTableEntryIdPointer ||
                    op1->type_entry->id == TypeTableEntryIdBool)
            {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, false);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else {
                zig_unreachable();
            }
        case IrBinOpAdd:
        case IrBinOpAddWrap:
            if (op1->type_entry->id == TypeTableEntryIdFloat) {
                return LLVMBuildFAdd(g->builder, op1_value, op2_value, "");
            } else if (op1->type_entry->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpAddWrap);
                if (is_wrapping) {
                    return LLVMBuildAdd(g->builder, op1_value, op2_value, "");
                } else if (ir_want_debug_safety(g, &bin_op_instruction->base)) {
                    return gen_overflow_op(g, op1->type_entry, AddSubMulAdd, op1_value, op2_value);
                } else if (op1->type_entry->data.integral.is_signed) {
                    return LLVMBuildNSWAdd(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildNUWAdd(g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
        case IrBinOpBinOr:
            return LLVMBuildOr(g->builder, op1_value, op2_value, "");
        case IrBinOpBinXor:
            return LLVMBuildXor(g->builder, op1_value, op2_value, "");
        case IrBinOpBinAnd:
            return LLVMBuildAnd(g->builder, op1_value, op2_value, "");
        case IrBinOpBitShiftLeft:
        case IrBinOpBitShiftLeftWrap:
            {
                assert(op1->type_entry->id == TypeTableEntryIdInt);
                bool is_wrapping = (op_id == IrBinOpBitShiftLeftWrap);
                if (is_wrapping) {
                    return LLVMBuildShl(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety(g, source_node)) {
                    return gen_overflow_shl_op(g, op1->type_entry, op1_value, op2_value);
                } else if (op1->type_entry->data.integral.is_signed) {
                    return ZigLLVMBuildNSWShl(g->builder, op1_value, op2_value, "");
                } else {
                    return ZigLLVMBuildNUWShl(g->builder, op1_value, op2_value, "");
                }
            }
        case IrBinOpBitShiftRight:
            assert(op1->type_entry->id == TypeTableEntryIdInt);
            if (op1->type_entry->data.integral.is_signed) {
                return LLVMBuildAShr(g->builder, op1_value, op2_value, "");
            } else {
                return LLVMBuildLShr(g->builder, op1_value, op2_value, "");
            }
        case IrBinOpSub:
        case IrBinOpSubWrap:
            if (op1->type_entry->id == TypeTableEntryIdFloat) {
                return LLVMBuildFSub(g->builder, op1_value, op2_value, "");
            } else if (op1->type_entry->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpSubWrap);
                if (is_wrapping) {
                    return LLVMBuildSub(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety(g, source_node)) {
                    return gen_overflow_op(g, op1->type_entry, AddSubMulSub, op1_value, op2_value);
                } else if (op1->type_entry->data.integral.is_signed) {
                    return LLVMBuildNSWSub(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildNUWSub(g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
        case IrBinOpMult:
        case IrBinOpMultWrap:
            if (op1->type_entry->id == TypeTableEntryIdFloat) {
                return LLVMBuildFMul(g->builder, op1_value, op2_value, "");
            } else if (op1->type_entry->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpMultWrap);
                if (is_wrapping) {
                    return LLVMBuildMul(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety(g, source_node)) {
                    return gen_overflow_op(g, op1->type_entry, AddSubMulMul, op1_value, op2_value);
                } else if (op1->type_entry->data.integral.is_signed) {
                    return LLVMBuildNSWMul(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildNUWMul(g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
        case IrBinOpDiv:
            return gen_div(g, source_node, op1_value, op2_value, op1->type_entry, false);
        case IrBinOpMod:
            if (op1->type_entry->id == TypeTableEntryIdFloat) {
                return LLVMBuildFRem(g->builder, op1_value, op2_value, "");
            } else {
                assert(op1->type_entry->id == TypeTableEntryIdInt);
                if (op1->type_entry->data.integral.is_signed) {
                    return LLVMBuildSRem(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildURem(g->builder, op1_value, op2_value, "");
                }
            }
    }
    zig_unreachable();
}

static LLVMValueRef ir_render_cast(CodeGen *g, IrExecutable *executable,
        IrInstructionCast *cast_instruction)
{
    TypeTableEntry *actual_type = cast_instruction->value->type_entry;
    TypeTableEntry *wanted_type = cast_instruction->base.type_entry;
    LLVMValueRef expr_val = ir_llvm_value(g, cast_instruction->value);
    assert(expr_val);

    switch (cast_instruction->cast_op) {
        case CastOpNoCast:
            zig_unreachable();
        case CastOpNoop:
            return expr_val;
        case CastOpErrToInt:
            assert(actual_type->id == TypeTableEntryIdErrorUnion);
            if (!type_has_bits(actual_type->data.error.child_type)) {
                return gen_widen_or_shorten(g, cast_instruction->base.source_node,
                        g->err_tag_type, wanted_type, expr_val);
            } else {
                zig_panic("TODO");
            }
        case CastOpMaybeWrap:
            {
                assert(cast_instruction->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdMaybe);
                assert(actual_type);

                TypeTableEntry *child_type = wanted_type->data.maybe.child_type;

                if (child_type->id == TypeTableEntryIdPointer ||
                    child_type->id == TypeTableEntryIdFn)
                {
                    return expr_val;
                } else {
                    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, 0, "");
                    gen_assign_raw(g, cast_instruction->base.source_node,
                            val_ptr, expr_val, child_type, actual_type);

                    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, 1, "");
                    LLVMBuildStore(g->builder, LLVMConstAllOnes(LLVMInt1Type()), maybe_ptr);
                }

                return cast_instruction->tmp_ptr;
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
                    assert(cast_instruction->tmp_ptr);
                    assert(wanted_type->id == TypeTableEntryIdErrorUnion);
                    assert(actual_type);

                    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, 0, "");
                    LLVMBuildStore(g->builder, ok_err_val, err_tag_ptr);

                    LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, 1, "");
                    gen_assign_raw(g, cast_instruction->base.source_node,
                            payload_ptr, expr_val, child_type, actual_type);

                    return cast_instruction->tmp_ptr;
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
            return LLVMBuildPtrToInt(g->builder, expr_val, wanted_type->type_ref, "");
        case CastOpIntToPtr:
            return LLVMBuildIntToPtr(g->builder, expr_val, wanted_type->type_ref, "");
        case CastOpPointerReinterpret:
            return LLVMBuildBitCast(g->builder, expr_val, wanted_type->type_ref, "");
        case CastOpWidenOrShorten:
            return gen_widen_or_shorten(g, cast_instruction->base.source_node, actual_type, wanted_type, expr_val);
        case CastOpToUnknownSizeArray:
            {
                assert(cast_instruction->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdStruct);
                assert(wanted_type->data.structure.is_slice);

                TypeTableEntry *pointer_type = wanted_type->data.structure.fields[0].type_entry;


                size_t ptr_index = wanted_type->data.structure.fields[0].gen_index;
                if (ptr_index != SIZE_MAX) {
                    LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, ptr_index, "");
                    LLVMValueRef expr_bitcast = LLVMBuildBitCast(g->builder, expr_val, pointer_type->type_ref, "");
                    LLVMBuildStore(g->builder, expr_bitcast, ptr_ptr);
                }

                size_t len_index = wanted_type->data.structure.fields[1].gen_index;
                LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, len_index, "");
                LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        actual_type->data.array.len, false);
                LLVMBuildStore(g->builder, len_val, len_ptr);

                return cast_instruction->tmp_ptr;
            }
        case CastOpResizeSlice:
            {
                assert(cast_instruction->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdStruct);
                assert(wanted_type->data.structure.is_slice);
                assert(actual_type->id == TypeTableEntryIdStruct);
                assert(actual_type->data.structure.is_slice);

                TypeTableEntry *actual_pointer_type = actual_type->data.structure.fields[0].type_entry;
                TypeTableEntry *actual_child_type = actual_pointer_type->data.pointer.child_type;
                TypeTableEntry *wanted_pointer_type = wanted_type->data.structure.fields[0].type_entry;
                TypeTableEntry *wanted_child_type = wanted_pointer_type->data.pointer.child_type;


                size_t actual_ptr_index = actual_type->data.structure.fields[0].gen_index;
                size_t actual_len_index = actual_type->data.structure.fields[1].gen_index;
                size_t wanted_ptr_index = wanted_type->data.structure.fields[0].gen_index;
                size_t wanted_len_index = wanted_type->data.structure.fields[1].gen_index;

                LLVMValueRef src_ptr_ptr = LLVMBuildStructGEP(g->builder, expr_val, actual_ptr_index, "");
                LLVMValueRef src_ptr = LLVMBuildLoad(g->builder, src_ptr_ptr, "");
                LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr,
                        wanted_type->data.structure.fields[0].type_entry->type_ref, "");
                LLVMValueRef dest_ptr_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr,
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
                    if (ir_want_debug_safety(g, &cast_instruction->base)) {
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

                LLVMValueRef dest_len_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr,
                        wanted_len_index, "");
                LLVMBuildStore(g->builder, new_len, dest_len_ptr);


                return cast_instruction->tmp_ptr;
            }
        case CastOpBytesToSlice:
            {
                assert(cast_instruction->tmp_ptr);
                assert(wanted_type->id == TypeTableEntryIdStruct);
                assert(wanted_type->data.structure.is_slice);
                assert(actual_type->id == TypeTableEntryIdArray);

                TypeTableEntry *wanted_pointer_type = wanted_type->data.structure.fields[0].type_entry;
                TypeTableEntry *wanted_child_type = wanted_pointer_type->data.pointer.child_type;


                size_t wanted_ptr_index = wanted_type->data.structure.fields[0].gen_index;
                LLVMValueRef dest_ptr_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, wanted_ptr_index, "");
                LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, expr_val, wanted_pointer_type->type_ref, "");
                LLVMBuildStore(g->builder, src_ptr_casted, dest_ptr_ptr);

                size_t wanted_len_index = wanted_type->data.structure.fields[1].gen_index;
                LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr, wanted_len_index, "");
                LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        actual_type->data.array.len / type_size(g, wanted_child_type), false);
                LLVMBuildStore(g->builder, len_val, len_ptr);

                return cast_instruction->tmp_ptr;
            }
        case CastOpIntToFloat:
            assert(actual_type->id == TypeTableEntryIdInt);
            if (actual_type->data.integral.is_signed) {
                return LLVMBuildSIToFP(g->builder, expr_val, wanted_type->type_ref, "");
            } else {
                return LLVMBuildUIToFP(g->builder, expr_val, wanted_type->type_ref, "");
            }
        case CastOpFloatToInt:
            assert(wanted_type->id == TypeTableEntryIdInt);
            if (wanted_type->data.integral.is_signed) {
                return LLVMBuildFPToSI(g->builder, expr_val, wanted_type->type_ref, "");
            } else {
                return LLVMBuildFPToUI(g->builder, expr_val, wanted_type->type_ref, "");
            }

        case CastOpBoolToInt:
            assert(wanted_type->id == TypeTableEntryIdInt);
            assert(actual_type->id == TypeTableEntryIdBool);
            return LLVMBuildZExt(g->builder, expr_val, wanted_type->type_ref, "");

        case CastOpIntToEnum:
            return gen_widen_or_shorten(g, cast_instruction->base.source_node,
                    actual_type, wanted_type->data.enumeration.tag_type, expr_val);
        case CastOpEnumToInt:
            return gen_widen_or_shorten(g, cast_instruction->base.source_node,
                    actual_type->data.enumeration.tag_type, wanted_type, expr_val);
    }
    zig_unreachable();
}

static LLVMValueRef ir_render_unreachable(CodeGen *g, IrExecutable *executable,
        IrInstructionUnreachable *unreachable_instruction)
{
    if (ir_want_debug_safety(g, &unreachable_instruction->base) || g->is_test_build) {
        gen_debug_safety_crash(g);
    } else {
        LLVMBuildUnreachable(g->builder);
    }
    return nullptr;
}

static LLVMValueRef ir_render_cond_br(CodeGen *g, IrExecutable *executable,
        IrInstructionCondBr *cond_br_instruction)
{
    LLVMBuildCondBr(g->builder,
            ir_llvm_value(g, cond_br_instruction->condition),
            cond_br_instruction->then_block->llvm_block,
            cond_br_instruction->else_block->llvm_block);
    return nullptr;
}

static LLVMValueRef ir_render_br(CodeGen *g, IrExecutable *executable, IrInstructionBr *br_instruction) {
    LLVMBuildBr(g->builder, br_instruction->dest_block->llvm_block);
    return nullptr;
}

static LLVMValueRef ir_render_un_op(CodeGen *g, IrExecutable *executable, IrInstructionUnOp *un_op_instruction) {
    IrUnOp op_id = un_op_instruction->op_id;
    LLVMValueRef expr = ir_llvm_value(g, un_op_instruction->value);
    TypeTableEntry *expr_type = un_op_instruction->value->type_entry;

    switch (op_id) {
        case IrUnOpInvalid:
            zig_unreachable();
        case IrUnOpNegation:
        case IrUnOpNegationWrap:
            {
                if (expr_type->id == TypeTableEntryIdFloat) {
                    return LLVMBuildFNeg(g->builder, expr, "");
                } else if (expr_type->id == TypeTableEntryIdInt) {
                    if (op_id == IrUnOpNegationWrap) {
                        return LLVMBuildNeg(g->builder, expr, "");
                    } else if (ir_want_debug_safety(g, &un_op_instruction->base)) {
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
        case IrUnOpBoolNot:
            {
                LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(expr));
                return LLVMBuildICmp(g->builder, LLVMIntEQ, expr, zero, "");
            }
        case IrUnOpBinNot:
            return LLVMBuildNot(g->builder, expr, "");
        case IrUnOpAddressOf:
        case IrUnOpConstAddressOf:
            zig_panic("TODO address of codegen");
            //{
            //    TypeTableEntry *lvalue_type;
            //    return gen_lvalue(g, node, expr_node, &lvalue_type);
            //}
        case IrUnOpDereference:
            {
                assert(expr_type->id == TypeTableEntryIdPointer);
                if (!type_has_bits(expr_type)) {
                    return nullptr;
                } else {
                    TypeTableEntry *child_type = expr_type->data.pointer.child_type;
                    return get_handle_value(g, expr, child_type);
                }
            }
        case IrUnOpError:
            {
                zig_panic("TODO codegen PrefixOpError");
            }
        case IrUnOpMaybe:
            {
                zig_panic("TODO codegen PrefixOpMaybe");
            }
        case IrUnOpUnwrapError:
            {
                assert(expr_type->id == TypeTableEntryIdErrorUnion);
                TypeTableEntry *child_type = expr_type->data.error.child_type;

                if (ir_want_debug_safety(g, &un_op_instruction->base)) {
                    LLVMValueRef err_val;
                    if (type_has_bits(child_type)) {
                        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, expr, 0, "");
                        err_val = LLVMBuildLoad(g->builder, err_val_ptr, "");
                    } else {
                        err_val = expr;
                    }
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
                    LLVMValueRef child_val_ptr = LLVMBuildStructGEP(g->builder, expr, 1, "");
                    return get_handle_value(g, child_val_ptr, child_type);
                } else {
                    return nullptr;
                }
            }
        case IrUnOpUnwrapMaybe:
            {
                assert(expr_type->id == TypeTableEntryIdMaybe);
                TypeTableEntry *child_type = expr_type->data.maybe.child_type;

                if (ir_want_debug_safety(g, &un_op_instruction->base)) {
                    LLVMValueRef cond_val;
                    if (child_type->id == TypeTableEntryIdPointer ||
                        child_type->id == TypeTableEntryIdFn)
                    {
                        cond_val = LLVMBuildICmp(g->builder, LLVMIntNE, expr,
                                LLVMConstNull(child_type->type_ref), "");
                    } else {
                        LLVMValueRef maybe_null_ptr = LLVMBuildStructGEP(g->builder, expr, 1, "");
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
                    return expr;
                } else {
                    LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, expr, 0, "");
                    return get_handle_value(g, maybe_field_ptr, child_type);
                }
            }
        case IrUnOpErrorReturn:
        case IrUnOpMaybeReturn:
            zig_panic("TODO codegen more un ops");
    }

    zig_unreachable();
}

static LLVMValueRef ir_render_decl_var(CodeGen *g, IrExecutable *executable,
        IrInstructionDeclVar *decl_var_instruction)
{
    VariableTableEntry *var = decl_var_instruction->var;

    if (!type_has_bits(var->type))
        return nullptr;

    if (var->ref_count == 0)
        return nullptr;

    IrInstruction *init_value = decl_var_instruction->init_value;

    bool have_init_expr = false;
    bool want_zeroes = false;

    ConstExprValue *const_val = &init_value->static_value;
    if (const_val->special == ConstValSpecialRuntime || const_val->special == ConstValSpecialStatic)
        have_init_expr = true;
    if (const_val->special == ConstValSpecialZeroes)
        want_zeroes = true;

    if (have_init_expr) {
        gen_assign_raw(g, init_value->source_node, var->value_ref,
                ir_llvm_value(g, init_value), var->type, init_value->type_entry);
    } else {
        bool ignore_uninit = false;
        // handle runtime stack allocation
        bool want_safe = ir_want_debug_safety(g, &decl_var_instruction->base);
        if (!ignore_uninit && (want_safe || want_zeroes)) {
            TypeTableEntry *usize = g->builtin_types.entry_usize;
            uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, var->type->type_ref);
            uint64_t align_bytes = get_memcpy_align(g, var->type);

            // memset uninitialized memory to 0xa
            LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
            LLVMValueRef fill_char = LLVMConstInt(LLVMInt8Type(), want_zeroes ? 0x00 : 0xaa, false);
            LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, var->value_ref, ptr_u8, "");
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

    gen_var_debug_decl(g, var);
    return nullptr;
}

static LLVMValueRef ir_render_load_ptr(CodeGen *g, IrExecutable *executable, IrInstructionLoadPtr *instruction) {
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    return get_handle_value(g, ptr, instruction->base.type_entry);
}

static LLVMValueRef ir_render_store_ptr(CodeGen *g, IrExecutable *executable, IrInstructionStorePtr *instruction) {
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef value = ir_llvm_value(g, instruction->value);

    assert(instruction->ptr->type_entry->id == TypeTableEntryIdPointer);
    TypeTableEntry *op1_type = instruction->ptr->type_entry->data.pointer.child_type;
    TypeTableEntry *op2_type = instruction->value->type_entry;

    if (!type_has_bits(op1_type)) {
        return nullptr;
    }
    if (handle_is_ptr(op1_type)) {
        assert(op1_type == op2_type);
        return gen_struct_memcpy(g, value, ptr, op1_type);
    }

    LLVMBuildStore(g->builder, value, ptr);
    return nullptr;
}

static LLVMValueRef ir_render_var_ptr(CodeGen *g, IrExecutable *executable, IrInstructionVarPtr *instruction) {
    VariableTableEntry *var = instruction->var;
    if (type_has_bits(var->type)) {
        assert(var->value_ref);
        return var->value_ref;
    } else {
        return nullptr;
    }
}

static LLVMValueRef ir_render_elem_ptr(CodeGen *g, IrExecutable *executable, IrInstructionElemPtr *instruction) {
    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->array_ptr);
    TypeTableEntry *array_ptr_type = instruction->array_ptr->type_entry;
    assert(array_ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type);
    LLVMValueRef subscript_value = ir_llvm_value(g, instruction->elem_index);
    assert(subscript_value);

    if (!type_has_bits(array_type))
        return nullptr;

    bool safety_check_on = ir_want_debug_safety(g, &instruction->base) && instruction->safety_check_on;

    if (array_type->id == TypeTableEntryIdArray) {
        if (safety_check_on) {
            LLVMValueRef end = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                    array_type->data.array.len, false);
            add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, end);
        }
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->type_ref),
            subscript_value
        };
        return LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
    } else if (array_type->id == TypeTableEntryIdPointer) {
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        LLVMValueRef indices[] = {
            subscript_value
        };
        return LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 1, "");
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        if (safety_check_on) {
            size_t len_index = array_type->data.structure.fields[1].gen_index;
            assert(len_index != SIZE_MAX);
            LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, len_index, "");
            LLVMValueRef len = LLVMBuildLoad(g->builder, len_ptr, "");
            add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, len);
        }

        size_t ptr_index = array_type->data.structure.fields[0].gen_index;
        assert(ptr_index != SIZE_MAX);
        LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, ptr_index, "");
        LLVMValueRef ptr = LLVMBuildLoad(g->builder, ptr_ptr, "");
        return LLVMBuildInBoundsGEP(g->builder, ptr, &subscript_value, 1, "");
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef ir_render_call(CodeGen *g, IrExecutable *executable, IrInstructionCall *instruction) {
    LLVMValueRef fn_val = ir_llvm_value(g, instruction->fn);
    TypeTableEntry *fn_type = instruction->fn->type_entry;
    TypeTableEntry *src_return_type = fn_type->data.fn.fn_type_id.return_type;
    bool ret_has_bits = type_has_bits(src_return_type);
    size_t fn_call_param_count = instruction->arg_count;
    bool first_arg_ret = ret_has_bits && handle_is_ptr(src_return_type);
    size_t actual_param_count = fn_call_param_count + (first_arg_ret ? 1 : 0);
    bool is_var_args = fn_type->data.fn.fn_type_id.is_var_args;
    LLVMValueRef *gen_param_values = allocate<LLVMValueRef>(actual_param_count);
    size_t gen_param_index = 0;
    if (first_arg_ret) {
        zig_panic("TODO");
        //gen_param_values[gen_param_index] = node->data.fn_call_expr.tmp_ptr;
        //gen_param_index += 1;
    }
    for (size_t call_i = 0; call_i < fn_call_param_count; call_i += 1) {
        IrInstruction *param_instruction = instruction->args[call_i];
        LLVMValueRef param_value = ir_llvm_value(g, param_instruction);
        assert(param_value);
        TypeTableEntry *param_type = param_instruction->type_entry;
        if (is_var_args || type_has_bits(param_type)) {
            gen_param_values[gen_param_index] = param_value;
            gen_param_index += 1;
        }
    }

    LLVMValueRef result = ZigLLVMBuildCall(g->builder, fn_val,
            gen_param_values, gen_param_index, fn_type->data.fn.calling_convention, "");

    if (src_return_type->id == TypeTableEntryIdUnreachable) {
        return LLVMBuildUnreachable(g->builder);
    } else if (!ret_has_bits) {
        return nullptr;
    } else if (first_arg_ret) {
        zig_panic("TODO");
        //return node->data.fn_call_expr.tmp_ptr;
    } else {
        return result;
    }
}

static LLVMValueRef ir_render_struct_field_ptr(CodeGen *g, IrExecutable *executable,
    IrInstructionStructFieldPtr *instruction)
{
    LLVMValueRef struct_ptr = ir_llvm_value(g, instruction->struct_ptr);
    TypeStructField *field = instruction->field;

    if (!type_has_bits(field->type_entry))
        return nullptr;

    assert(field->gen_index != SIZE_MAX);
    return LLVMBuildStructGEP(g->builder, struct_ptr, field->gen_index, "");
}

static size_t find_asm_index(CodeGen *g, AstNode *node, AsmToken *tok) {
    const char *ptr = buf_ptr(node->data.asm_expr.asm_template) + tok->start + 2;
    size_t len = tok->end - tok->start - 2;
    size_t result = 0;
    for (size_t i = 0; i < node->data.asm_expr.output_list.length; i += 1, result += 1) {
        AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
        if (buf_eql_mem(asm_output->asm_symbolic_name, ptr, len)) {
            return result;
        }
    }
    for (size_t i = 0; i < node->data.asm_expr.input_list.length; i += 1, result += 1) {
        AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
        if (buf_eql_mem(asm_input->asm_symbolic_name, ptr, len)) {
            return result;
        }
    }
    return SIZE_MAX;
}

static LLVMValueRef ir_render_asm(CodeGen *g, IrExecutable *executable, IrInstructionAsm *instruction) {
    AstNode *asm_node = instruction->base.source_node;
    assert(asm_node->type == NodeTypeAsmExpr);
    AstNodeAsmExpr *asm_expr = &asm_node->data.asm_expr;

    Buf *src_template = asm_expr->asm_template;

    Buf llvm_template = BUF_INIT;
    buf_resize(&llvm_template, 0);

    for (size_t token_i = 0; token_i < asm_expr->token_list.length; token_i += 1) {
        AsmToken *asm_token = &asm_expr->token_list.at(token_i);
        switch (asm_token->id) {
            case AsmTokenIdTemplate:
                for (size_t offset = asm_token->start; offset < asm_token->end; offset += 1) {
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
                size_t index = find_asm_index(g, asm_node, asm_token);
                assert(index < SIZE_MAX);
                buf_appendf(&llvm_template, "$%zu", index);
                break;
        }
    }

    Buf constraint_buf = BUF_INIT;
    buf_resize(&constraint_buf, 0);

    assert(instruction->return_count == 0 || instruction->return_count == 1);

    size_t total_constraint_count = asm_expr->output_list.length +
                                 asm_expr->input_list.length +
                                 asm_expr->clobber_list.length;
    size_t input_and_output_count = asm_expr->output_list.length +
                                 asm_expr->input_list.length -
                                 instruction->return_count;
    size_t total_index = 0;
    size_t param_index = 0;
    LLVMTypeRef *param_types = allocate<LLVMTypeRef>(input_and_output_count);
    LLVMValueRef *param_values = allocate<LLVMValueRef>(input_and_output_count);
    for (size_t i = 0; i < asm_expr->output_list.length; i += 1, total_index += 1) {
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
    for (size_t i = 0; i < asm_expr->input_list.length; i += 1, total_index += 1, param_index += 1) {
        AsmInput *asm_input = asm_expr->input_list.at(i);
        IrInstruction *ir_input = instruction->input_list[i];
        buf_append_buf(&constraint_buf, asm_input->constraint);
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        param_types[param_index] = ir_input->type_entry->type_ref;
        param_values[param_index] = ir_llvm_value(g, ir_input);
    }
    for (size_t i = 0; i < asm_expr->clobber_list.length; i += 1, total_index += 1) {
        Buf *clobber_buf = asm_expr->clobber_list.at(i);
        buf_appendf(&constraint_buf, "~{%s}", buf_ptr(clobber_buf));
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }
    }

    LLVMTypeRef ret_type;
    if (instruction->return_count == 0) {
        ret_type = LLVMVoidType();
    } else {
        ret_type = instruction->base.type_entry->type_ref;
    }
    LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, input_and_output_count, false);

    bool is_volatile = asm_expr->is_volatile || (asm_expr->output_list.length == 0);
    LLVMValueRef asm_fn = LLVMConstInlineAsm(function_type, buf_ptr(&llvm_template),
            buf_ptr(&constraint_buf), is_volatile, false);

    return LLVMBuildCall(g->builder, asm_fn, param_values, input_and_output_count, "");
}

// 0 - null, 1 - non null
static LLVMValueRef gen_null_bit(CodeGen *g, TypeTableEntry *ptr_type, LLVMValueRef maybe_ptr) {
    assert(ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *maybe_type = ptr_type->data.pointer.child_type;
    assert(maybe_type->id == TypeTableEntryIdMaybe);
    TypeTableEntry *child_type = maybe_type->data.maybe.child_type;
    LLVMValueRef maybe_struct_ref = get_handle_value(g, maybe_ptr, maybe_type);
    bool maybe_is_ptr = (child_type->id == TypeTableEntryIdPointer || child_type->id == TypeTableEntryIdFn);
    if (maybe_is_ptr) {
        return LLVMBuildICmp(g->builder, LLVMIntNE, maybe_struct_ref, LLVMConstNull(child_type->type_ref), "");
    } else {
        LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, maybe_struct_ref, maybe_null_index, "");
        return LLVMBuildLoad(g->builder, maybe_field_ptr, "");
    }
}

static LLVMValueRef ir_render_test_null(CodeGen *g, IrExecutable *executable, IrInstructionTestNull *instruction) {
    TypeTableEntry *ptr_type = instruction->value->type_entry;
    assert(ptr_type->id == TypeTableEntryIdPointer);
    return gen_null_bit(g, ptr_type, ir_llvm_value(g, instruction->value));
}

static LLVMValueRef ir_render_unwrap_maybe(CodeGen *g, IrExecutable *executable,
        IrInstructionUnwrapMaybe *instruction)
{
    TypeTableEntry *ptr_type = instruction->value->type_entry;
    assert(ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *maybe_type = ptr_type->data.pointer.child_type;
    assert(maybe_type->id == TypeTableEntryIdMaybe);
    TypeTableEntry *child_type = maybe_type->data.maybe.child_type;
    bool maybe_is_ptr = (child_type->id == TypeTableEntryIdPointer || child_type->id == TypeTableEntryIdFn);
    LLVMValueRef maybe_ptr = ir_llvm_value(g, instruction->value);
    if (ir_want_debug_safety(g, &instruction->base) && instruction->safety_check_on) {
        LLVMValueRef nonnull_bit = gen_null_bit(g, ptr_type, maybe_ptr);
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapMaybeOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "UnwrapMaybeFail");
        LLVMBuildCondBr(g->builder, nonnull_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_debug_safety_crash(g);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }
    if (maybe_is_ptr) {
        return maybe_ptr;
    } else {
        LLVMValueRef maybe_struct_ref = get_handle_value(g, maybe_ptr, maybe_type);
        return LLVMBuildStructGEP(g->builder, maybe_struct_ref, maybe_child_index, "");
    }
}

static LLVMValueRef get_int_builtin_fn(CodeGen *g, TypeTableEntry *int_type, BuiltinFnId fn_id) {
    // [0-ctz,1-clz][0-8,1-16,2-32,3-64]
    size_t index0 = (fn_id == BuiltinFnIdCtz) ? 0 : 1;
    size_t index1 = bits_index(int_type->data.integral.bit_count);
    LLVMValueRef *fn = &g->int_builtin_fns[index0][index1];
    if (!*fn) {
        const char *fn_name = (fn_id == BuiltinFnIdCtz) ? "cttz" : "ctlz";
        Buf *llvm_name = buf_sprintf("llvm.%s.i%zu", fn_name, int_type->data.integral.bit_count);
        LLVMTypeRef param_types[] = {
            int_type->type_ref,
            LLVMInt1Type(),
        };
        LLVMTypeRef fn_type = LLVMFunctionType(int_type->type_ref, param_types, 2, false);
        *fn = LLVMAddFunction(g->module, buf_ptr(llvm_name), fn_type);
    }
    return *fn;
}

static LLVMValueRef ir_render_clz(CodeGen *g, IrExecutable *executable, IrInstructionClz *instruction) {
    TypeTableEntry *int_type = instruction->base.type_entry;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdClz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->value);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    return LLVMBuildCall(g->builder, fn_val, params, 2, "");
}

static LLVMValueRef ir_render_ctz(CodeGen *g, IrExecutable *executable, IrInstructionCtz *instruction) {
    TypeTableEntry *int_type = instruction->base.type_entry;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdCtz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->value);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    return LLVMBuildCall(g->builder, fn_val, params, 2, "");
}

static LLVMValueRef ir_render_instruction(CodeGen *g, IrExecutable *executable, IrInstruction *instruction) {
    set_debug_source_node(g, instruction->source_node);

    switch (instruction->id) {
        case IrInstructionIdInvalid:
        case IrInstructionIdConst:
        case IrInstructionIdTypeOf:
        case IrInstructionIdToPtrType:
        case IrInstructionIdPtrTypeChild:
        case IrInstructionIdFieldPtr:
        case IrInstructionIdSetFnTest:
        case IrInstructionIdSetFnVisible:
        case IrInstructionIdSetDebugSafety:
        case IrInstructionIdArrayType:
        case IrInstructionIdSliceType:
        case IrInstructionIdCompileVar:
        case IrInstructionIdSizeOf:
            zig_unreachable();
        case IrInstructionIdReturn:
            return ir_render_return(g, executable, (IrInstructionReturn *)instruction);
        case IrInstructionIdDeclVar:
            return ir_render_decl_var(g, executable, (IrInstructionDeclVar *)instruction);
        case IrInstructionIdBinOp:
            return ir_render_bin_op(g, executable, (IrInstructionBinOp *)instruction);
        case IrInstructionIdCast:
            return ir_render_cast(g, executable, (IrInstructionCast *)instruction);
        case IrInstructionIdUnreachable:
            return ir_render_unreachable(g, executable, (IrInstructionUnreachable *)instruction);
        case IrInstructionIdCondBr:
            return ir_render_cond_br(g, executable, (IrInstructionCondBr *)instruction);
        case IrInstructionIdBr:
            return ir_render_br(g, executable, (IrInstructionBr *)instruction);
        case IrInstructionIdUnOp:
            return ir_render_un_op(g, executable, (IrInstructionUnOp *)instruction);
        case IrInstructionIdLoadPtr:
            return ir_render_load_ptr(g, executable, (IrInstructionLoadPtr *)instruction);
        case IrInstructionIdStorePtr:
            return ir_render_store_ptr(g, executable, (IrInstructionStorePtr *)instruction);
        case IrInstructionIdVarPtr:
            return ir_render_var_ptr(g, executable, (IrInstructionVarPtr *)instruction);
        case IrInstructionIdElemPtr:
            return ir_render_elem_ptr(g, executable, (IrInstructionElemPtr *)instruction);
        case IrInstructionIdCall:
            return ir_render_call(g, executable, (IrInstructionCall *)instruction);
        case IrInstructionIdStructFieldPtr:
            return ir_render_struct_field_ptr(g, executable, (IrInstructionStructFieldPtr *)instruction);
        case IrInstructionIdAsm:
            return ir_render_asm(g, executable, (IrInstructionAsm *)instruction);
        case IrInstructionIdTestNull:
            return ir_render_test_null(g, executable, (IrInstructionTestNull *)instruction);
        case IrInstructionIdUnwrapMaybe:
            return ir_render_unwrap_maybe(g, executable, (IrInstructionUnwrapMaybe *)instruction);
        case IrInstructionIdClz:
            return ir_render_clz(g, executable, (IrInstructionClz *)instruction);
        case IrInstructionIdCtz:
            return ir_render_ctz(g, executable, (IrInstructionCtz *)instruction);
        case IrInstructionIdSwitchBr:
        case IrInstructionIdSwitchTarget:
        case IrInstructionIdSwitchVar:
        case IrInstructionIdPhi:
        case IrInstructionIdContainerInitList:
        case IrInstructionIdContainerInitFields:
        case IrInstructionIdReadField:
            zig_panic("TODO render more IR instructions to LLVM");
    }
    zig_unreachable();
}

static void ir_render(CodeGen *g, FnTableEntry *fn_entry) {
    assert(fn_entry);
    IrExecutable *executable = &fn_entry->analyzed_executable;
    assert(executable->basic_block_list.length > 0);
    for (size_t block_i = 0; block_i < executable->basic_block_list.length; block_i += 1) {
        IrBasicBlock *current_block = executable->basic_block_list.at(block_i);
        assert(current_block->ref_count > 0);
        assert(current_block->llvm_block);
        LLVMPositionBuilderAtEnd(g->builder, current_block->llvm_block);
        for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
            IrInstruction *instruction = current_block->instruction_list.at(instr_i);
            if (instruction->ref_count == 0 && !ir_has_side_effects(instruction))
                continue;
            instruction->llvm_value = ir_render_instruction(g, executable, instruction);
        }
    }
}

static LLVMValueRef gen_const_val(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val) {
    switch (const_val->special) {
        case ConstValSpecialRuntime:
            zig_unreachable();
        case ConstValSpecialUndef:
            return LLVMGetUndef(type_entry->type_ref);
        case ConstValSpecialZeroes:
            return LLVMConstNull(type_entry->type_ref);
        case ConstValSpecialStatic:
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
                    if (type_struct_field->gen_index == SIZE_MAX) {
                        continue;
                    }
                    fields[type_struct_field->gen_index] = gen_const_val(g, type_struct_field->type_entry,
                            &const_val->data.x_struct.fields[i]);
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
                    ConstExprValue *elem_value = &const_val->data.x_array.elements[i];
                    values[i] = gen_const_val(g, child_type, elem_value);
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

                render_const_val_global(g, type_entry, const_val);
                size_t index = const_val->data.x_ptr.index;
                if (index == SIZE_MAX) {
                    render_const_val(g, child_type, const_val->data.x_ptr.base_ptr);
                    render_const_val_global(g, child_type, const_val->data.x_ptr.base_ptr);
                    return const_val->data.x_ptr.base_ptr->llvm_global;
                } else {
                    ConstExprValue *array_const_val = const_val->data.x_ptr.base_ptr;
                    TypeTableEntry *array_type = get_array_type(g, child_type,
                            array_const_val->data.x_array.size);
                    render_const_val(g, array_type, array_const_val);
                    render_const_val_global(g, array_type, array_const_val);
                    TypeTableEntry *usize = g->builtin_types.entry_usize;
                    LLVMValueRef indices[] = {
                        LLVMConstNull(usize->type_ref),
                        LLVMConstInt(usize->type_ref, index, false),
                    };
                    LLVMValueRef ptr_val = LLVMConstInBoundsGEP(array_const_val->llvm_global, indices, 2);
                    return ptr_val;
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
        case TypeTableEntryIdVoid:
            return nullptr;
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdVar:
            zig_unreachable();

    }
    zig_unreachable();
}

static void render_const_val(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val) {
    if (!const_val->llvm_value)
        const_val->llvm_value = gen_const_val(g, type_entry, const_val);

    if (const_val->llvm_global)
        LLVMSetInitializer(const_val->llvm_global, const_val->llvm_value);
}

static void render_const_val_global(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val) {
    if (!const_val->llvm_global) {
        LLVMValueRef global_value = LLVMAddGlobal(g->module, type_entry->type_ref, "");
        LLVMSetLinkage(global_value, LLVMInternalLinkage);
        LLVMSetGlobalConstant(global_value, true);
        LLVMSetUnnamedAddr(global_value, true);

        const_val->llvm_global = global_value;
    }

    if (const_val->llvm_value)
        LLVMSetInitializer(const_val->llvm_global, const_val->llvm_value);
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
    for (size_t i = 1; i < g->error_decls.length; i += 1) {
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

static void build_all_basic_blocks(CodeGen *g, FnTableEntry *fn) {
    IrExecutable *executable = &fn->analyzed_executable;
    assert(executable->basic_block_list.length > 0);
    for (size_t block_i = 0; block_i < executable->basic_block_list.length; block_i += 1) {
        IrBasicBlock *bb = executable->basic_block_list.at(block_i);
        bb->llvm_block = LLVMAppendBasicBlock(fn->fn_value, bb->name_hint);
    }
    IrBasicBlock *entry_bb = executable->basic_block_list.at(0);
    LLVMPositionBuilderAtEnd(g->builder, entry_bb->llvm_block);
}

static void gen_global_var(CodeGen *g, VariableTableEntry *var, LLVMValueRef init_val,
    TypeTableEntry *type_entry)
{
    assert(var->gen_is_const);
    assert(var->import);
    assert(type_entry);
    bool is_local_to_unit = true;
    ZigLLVMCreateGlobalVariable(g->dbuilder,
        var->block_context->di_scope, buf_ptr(&var->name),
        buf_ptr(&var->name), var->import->di_file, var->decl_node->line + 1,
        type_entry->di_type, is_local_to_unit, init_val);
}

static void do_code_gen(CodeGen *g) {
    assert(!g->errors.length);

    delete_unused_builtin_fns(g);
    generate_error_name_table(g);

    // Generate module level variables
    for (size_t i = 0; i < g->global_vars.length; i += 1) {
        VariableTableEntry *var = g->global_vars.at(i);

        if (var->type->id == TypeTableEntryIdNumLitFloat) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = &get_resolved_expr(var->val_node)->instruction->static_value;
            assert(const_val->special != ConstValSpecialRuntime);
            TypeTableEntry *var_type = g->builtin_types.entry_f64;
            LLVMValueRef init_val = LLVMConstReal(var_type->type_ref, const_val->data.x_bignum.data.x_float);
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (var->type->id == TypeTableEntryIdNumLitInt) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = &get_resolved_expr(var->val_node)->instruction->static_value;
            assert(const_val->special != ConstValSpecialRuntime);
            TypeTableEntry *var_type = const_val->data.x_bignum.is_negative ?
                g->builtin_types.entry_isize : g->builtin_types.entry_usize;
            LLVMValueRef init_val = LLVMConstInt(var_type->type_ref,
                bignum_to_twos_complement(&const_val->data.x_bignum), false);
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (!type_has_bits(var->type)) {
            continue;
        }

        assert(var->decl_node);
        assert(var->decl_node->type == NodeTypeVariableDeclaration);

        LLVMValueRef global_value;
        if (var->decl_node->data.variable_declaration.is_extern) {
            global_value = LLVMAddGlobal(g->module, var->type->type_ref, buf_ptr(&var->name));

            // TODO debug info for the extern variable

            LLVMSetLinkage(global_value, LLVMExternalLinkage);
        } else {
            AstNode *expr_node = var->decl_node->data.variable_declaration.expr;
            IrInstruction *instruction = get_resolved_expr(expr_node)->instruction;
            render_const_val(g, instruction->type_entry, &instruction->static_value);
            render_const_val_global(g, instruction->type_entry, &instruction->static_value);
            global_value = instruction->static_value.llvm_global;
            // TODO debug info for function pointers
            if (var->gen_is_const && var->type->id != TypeTableEntryIdFn) {
                gen_global_var(g, var, instruction->static_value.llvm_value, var->type);
            }
        }

        LLVMSetGlobalConstant(global_value, var->gen_is_const);

        var->value_ref = global_value;
    }

    LLVMValueRef *test_fn_vals = nullptr;
    uint32_t next_test_index = 0;
    if (g->is_test_build) {
        test_fn_vals = allocate<LLVMValueRef>(g->test_fn_count);
    }

    // Generate function prototypes
    for (size_t fn_proto_i = 0; fn_proto_i < g->fn_protos.length; fn_proto_i += 1) {
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
            ZigLLVMAddNonNullAttr(fn_table_entry->fn_value, 0);
        } else if (handle_is_ptr(fn_type->data.fn.fn_type_id.return_type) &&
                !fn_type->data.fn.fn_type_id.is_extern)
        {
            LLVMValueRef first_arg = LLVMGetParam(fn_table_entry->fn_value, 0);
            LLVMAddAttribute(first_arg, LLVMStructRetAttribute);
            ZigLLVMAddNonNullAttr(fn_table_entry->fn_value, 1);
            is_sret = true;
        }
        if (fn_table_entry->is_pure && !is_sret && g->is_release_build) {
            LLVMAddFunctionAttr(fn_table_entry->fn_value, LLVMReadOnlyAttribute);
        }


        // set parameter attributes
        for (size_t param_decl_i = 0; param_decl_i < fn_proto->params.length; param_decl_i += 1) {
            AstNode *param_node = fn_proto->params.at(param_decl_i);
            assert(param_node->type == NodeTypeParamDecl);

            FnGenParamInfo *info = &fn_type->data.fn.gen_param_info[param_decl_i];
            size_t gen_index = info->gen_index;
            bool is_byval = info->is_byval;

            if (gen_index == SIZE_MAX) {
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
                ZigLLVMAddNonNullAttr(fn_table_entry->fn_value, gen_index + 1);
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
    for (size_t fn_i = 0; fn_i < g->fn_defs.length; fn_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(fn_i);
        if (should_skip_fn_codegen(g, fn_table_entry)) {
            // huge time saver
            continue;
        }

        ImportTableEntry *import = fn_table_entry->import_entry;
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

        build_all_basic_blocks(g, fn_table_entry);


        // Set up debug info for blocks
        for (size_t bc_i = 0; bc_i < fn_table_entry->all_block_contexts.length; bc_i += 1) {
            BlockContext *block_context = fn_table_entry->all_block_contexts.at(bc_i);

            if (!block_context->di_scope) {
                ZigLLVMDILexicalBlock *di_block = ZigLLVMCreateLexicalBlock(g->dbuilder,
                    block_context->parent->di_scope,
                    import->di_file,
                    block_context->node->line + 1,
                    block_context->node->column + 1);
                block_context->di_scope = ZigLLVMLexicalBlockToScope(di_block);
            }


        }

        clear_debug_source_node(g);

        // allocate structs which are the result of casts
        for (size_t cea_i = 0; cea_i < fn_table_entry->cast_alloca_list.length; cea_i += 1) {
            IrInstructionCast *cast_instruction = fn_table_entry->cast_alloca_list.at(cea_i);
            cast_instruction->tmp_ptr = LLVMBuildAlloca(g->builder, cast_instruction->base.type_entry->type_ref, "");
        }

        // allocate structs which are struct value expressions
        for (size_t alloca_i = 0; alloca_i < fn_table_entry->struct_val_expr_alloca_list.length; alloca_i += 1) {
            StructValExprCodeGen *struct_val_expr_node = fn_table_entry->struct_val_expr_alloca_list.at(alloca_i);
            struct_val_expr_node->ptr = LLVMBuildAlloca(g->builder,
                    struct_val_expr_node->type_entry->type_ref, "");
        }

        // create debug variable declarations for variables and allocate all local variables
        for (size_t var_i = 0; var_i < fn_table_entry->variable_list.length; var_i += 1) {
            VariableTableEntry *var = fn_table_entry->variable_list.at(var_i);

            if (!type_has_bits(var->type)) {
                continue;
            }
            if (var->is_inline)
                continue;

            if (var->block_context->node->type == NodeTypeFnDef) {
                assert(var->gen_arg_index != SIZE_MAX);
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
                var->di_loc_var = ZigLLVMCreateParameterVariable(g->dbuilder, var->block_context->di_scope,
                        buf_ptr(&var->name), import->di_file, var->decl_node->line + 1,
                        gen_type->di_type, !g->strip_debug_symbols, 0, var->gen_arg_index + 1);

            } else {
                var->value_ref = LLVMBuildAlloca(g->builder, var->type->type_ref, buf_ptr(&var->name));


                unsigned align_bytes = ZigLLVMGetPrefTypeAlignment(g->target_data_ref, var->type->type_ref);
                LLVMSetAlignment(var->value_ref, align_bytes);

                var->di_loc_var = ZigLLVMCreateAutoVariable(g->dbuilder, var->block_context->di_scope,
                        buf_ptr(&var->name), import->di_file, var->decl_node->line + 1,
                        var->type->di_type, !g->strip_debug_symbols, 0);
            }
        }

        // create debug variable declarations for parameters
        for (size_t param_i = 0; param_i < fn_proto->params.length; param_i += 1) {
            AstNode *param_decl = fn_proto->params.at(param_i);
            assert(param_decl->type == NodeTypeParamDecl);

            FnGenParamInfo *info = &fn_table_entry->type_entry->data.fn.gen_param_info[param_i];

            if (info->gen_index == SIZE_MAX) {
                continue;
            }

            VariableTableEntry *variable = param_decl->data.param_decl.variable;
            assert(variable);
            assert(variable->value_ref);

            if (!handle_is_ptr(variable->type)) {
                clear_debug_source_node(g);
                LLVMBuildStore(g->builder, LLVMGetParam(fn, variable->gen_arg_index), variable->value_ref);
            }

            gen_var_debug_decl(g, variable);
        }

        ir_render(g, fn_table_entry);

    }
    assert(!g->errors.length);

    ZigLLVMDIBuilderFinalize(g->dbuilder);

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

static const size_t int_sizes_in_bits[] = {
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
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdBlock);
        buf_init_from_str(&entry->name, "(block)");
        entry->zero_bits = true;
        entry->deep_const = true;
        g->builtin_types.entry_block = entry;
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
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdVar);
        buf_init_from_str(&entry->name, "(var)");
        entry->deep_const = true;
        g->builtin_types.entry_var = entry;
    }

    for (size_t int_size_i = 0; int_size_i < array_length(int_sizes_in_bits); int_size_i += 1) {
        size_t size_in_bits = int_sizes_in_bits[int_size_i];
        for (size_t is_sign_i = 0; is_sign_i < array_length(is_signed_list); is_sign_i += 1) {
            bool is_signed = is_signed_list[is_sign_i];

            TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
            entry->type_ref = LLVMIntType(size_in_bits);
            entry->deep_const = true;

            const char u_or_i = is_signed ? 'i' : 'u';
            buf_resize(&entry->name, 0);
            buf_appendf(&entry->name, "%c%zu", u_or_i, size_in_bits);

            unsigned dwarf_tag;
            if (is_signed) {
                if (size_in_bits == 8) {
                    dwarf_tag = ZigLLVMEncoding_DW_ATE_signed_char();
                } else {
                    dwarf_tag = ZigLLVMEncoding_DW_ATE_signed();
                }
            } else {
                if (size_in_bits == 8) {
                    dwarf_tag = ZigLLVMEncoding_DW_ATE_unsigned_char();
                } else {
                    dwarf_tag = ZigLLVMEncoding_DW_ATE_unsigned();
                }
            }

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
            entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                    debug_size_in_bits, debug_align_in_bits, dwarf_tag);
            entry->data.integral.is_signed = is_signed;
            entry->data.integral.bit_count = size_in_bits;
            g->primitive_type_table.put(&entry->name, entry);

            get_int_type_ptr(g, is_signed, size_in_bits)[0] = entry;
        }
    }

    for (size_t i = 0; i < array_length(c_int_type_infos); i += 1) {
        const CIntTypeInfo *info = &c_int_type_infos[i];
        uint64_t size_in_bits = get_c_type_size_in_bits(&g->zig_target, info->id);
        bool is_signed = info->is_signed;

        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMIntType(size_in_bits);
        entry->deep_const = true;

        buf_init_from_str(&entry->name, info->name);

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                is_signed ? ZigLLVMEncoding_DW_ATE_signed() : ZigLLVMEncoding_DW_ATE_unsigned());
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
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                ZigLLVMEncoding_DW_ATE_boolean());
        g->builtin_types.entry_bool = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    for (size_t sign_i = 0; sign_i < array_length(is_signed_list); sign_i += 1) {
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
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                is_signed ? ZigLLVMEncoding_DW_ATE_signed() : ZigLLVMEncoding_DW_ATE_unsigned());
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
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
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
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
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
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                debug_align_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
        g->builtin_types.entry_c_long_double = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdVoid);
        entry->deep_const = true;
        entry->type_ref = LLVMVoidType();
        entry->zero_bits = true;
        buf_init_from_str(&entry->name, "void");
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                0,
                0,
                ZigLLVMEncoding_DW_ATE_unsigned());
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
        entry->data.enumeration.src_field_count = field_count;
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
        entry->data.enumeration.src_field_count = field_count;
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
        entry->data.enumeration.src_field_count = field_count;
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
        entry->data.enumeration.src_field_count = field_count;
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
        entry->data.enumeration.src_field_count = field_count;
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

static BuiltinFnEntry *create_builtin_fn_with_arg_count(CodeGen *g, BuiltinFnId id, const char *name, size_t count) {
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
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCtz, "ctz", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdClz, "clz", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdImport, "import", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCImport, "cImport", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdErrName, "errorName", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdEmbedFile, "embedFile", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCmpExchange, "cmpxchg", 5);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdFence, "fence", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdDivExact, "divExact", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdTruncate, "truncate", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdCompileErr, "compileError", 1);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdIntType, "intType", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdUnreachable, "unreachable", 0);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdSetFnTest, "setFnTest", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdSetFnVisible, "setFnVisible", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdSetFnStaticEval, "setFnStaticEval", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdSetFnNoInline, "setFnNoInline", 2);
    create_builtin_fn_with_arg_count(g, BuiltinFnIdSetDebugSafety, "setDebugSafety", 2);
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
        target_specific_cpu_args = ZigLLVMGetHostCPUName();
        target_specific_features = ZigLLVMGetNativeFeatures();
    } else {
        target_specific_cpu_args = "";
        target_specific_features = "";
    }

    g->target_machine = LLVMCreateTargetMachine(target_ref, buf_ptr(&g->triple_str),
            target_specific_cpu_args, target_specific_features, opt_level, reloc_mode, LLVMCodeModelDefault);

    g->target_data_ref = LLVMCreateTargetDataLayout(g->target_machine);

    char *layout_str = LLVMCopyStringRepOfTargetData(g->target_data_ref);
    LLVMSetDataLayout(g->module, layout_str);


    g->pointer_size_bytes = LLVMPointerSize(g->target_data_ref);
    g->is_big_endian = (LLVMByteOrder(g->target_data_ref) == LLVMBigEndian);

    g->builder = LLVMCreateBuilder();
    g->dbuilder = ZigLLVMCreateDIBuilder(g->module, true);

    ZigLLVMSetFastMath(g->builder, true);


    Buf *producer = buf_sprintf("zig %s", ZIG_VERSION_STRING);
    bool is_optimized = g->is_release_build;
    const char *flags = "";
    unsigned runtime_version = 0;
    g->compile_unit = ZigLLVMCreateCompileUnit(g->dbuilder, ZigLLVMLang_DW_LANG_C99(),
            buf_ptr(source_path), buf_ptr(&g->root_package->root_src_dir),
            buf_ptr(producer), is_optimized, flags, runtime_version,
            "", 0, !g->strip_debug_symbols);

    // This is for debug stuff that doesn't have a real file.
    g->dummy_di_file = nullptr;

    define_builtin_types(g);
    define_builtin_fns(g);

    g->invalid_instruction = allocate<IrInstruction>(1);
    g->invalid_instruction->type_entry = g->builtin_types.entry_invalid;
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

    import->di_file = ZigLLVMCreateFile(g->dbuilder, buf_ptr(src_basename), buf_ptr(src_dirname));

    ZigList<ErrorMsg *> errors = {0};
    int err = parse_h_buf(import, &errors, source_code, g, nullptr);
    if (err) {
        fprintf(stderr, "unable to parse .h file: %s\n", err_str(err));
        exit(1);
    }

    if (errors.length > 0) {
        for (size_t i = 0; i < errors.length; i += 1) {
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
        fprintf(stderr, "\nIR Generation and Semantic Analysis:\n");
        fprintf(stderr, "--------------------------------------\n");
    }
    if (!g->error_during_imports) {
        semantic_analyze(g);
    }

    if (g->errors.length == 0) {
        if (g->verbose) {
            fprintf(stderr, "OK\n");
        }
    } else {
        for (size_t i = 0; i < g->errors.length; i += 1) {
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

static const char *c_int_type_names[] = {
    [CIntTypeShort] = "short",
    [CIntTypeUShort] = "unsigned short",
    [CIntTypeInt] = "int",
    [CIntTypeUInt] = "unsigned int",
    [CIntTypeLong] = "long",
    [CIntTypeULong] = "unsigned long",
    [CIntTypeLongLong] = "long long",
    [CIntTypeULongLong] = "unsigned long long",
};

static void get_c_type(CodeGen *g, TypeTableEntry *type_entry, Buf *out_buf) {
    assert(type_entry);

    for (size_t i = 0; i < array_length(c_int_type_names); i += 1) {
        if (type_entry == g->builtin_types.entry_c_int[i]) {
            buf_init_from_str(out_buf, c_int_type_names[i]);
            return;
        }
    }
    if (type_entry == g->builtin_types.entry_c_long_double) {
        buf_init_from_str(out_buf, "long double");
        return;
    }
    if (type_entry == g->builtin_types.entry_c_void) {
        buf_init_from_str(out_buf, "void");
        return;
    }
    if (type_entry == g->builtin_types.entry_isize) {
        g->c_want_stdint = true;
        buf_init_from_str(out_buf, "intptr_t");
        return;
    }
    if (type_entry == g->builtin_types.entry_usize) {
        g->c_want_stdint = true;
        buf_init_from_str(out_buf, "uintptr_t");
        return;
    }

    switch (type_entry->id) {
        case TypeTableEntryIdVoid:
            buf_init_from_str(out_buf, "void");
            break;
        case TypeTableEntryIdBool:
            buf_init_from_str(out_buf, "bool");
            g->c_want_stdbool = true;
            break;
        case TypeTableEntryIdUnreachable:
            buf_init_from_str(out_buf, "__attribute__((__noreturn__)) void");
            break;
        case TypeTableEntryIdFloat:
            switch (type_entry->data.floating.bit_count) {
                case 32:
                    buf_init_from_str(out_buf, "float");
                    break;
                case 64:
                    buf_init_from_str(out_buf, "double");
                    break;
                default:
                    zig_unreachable();
            }
            break;
        case TypeTableEntryIdInt:
            g->c_want_stdint = true;
            buf_resize(out_buf, 0);
            buf_appendf(out_buf, "%sint%zu_t",
                    type_entry->data.integral.is_signed ? "" : "u",
                    type_entry->data.integral.bit_count);
            break;
        case TypeTableEntryIdPointer:
            {
                Buf child_buf = BUF_INIT;
                TypeTableEntry *child_type = type_entry->data.pointer.child_type;
                get_c_type(g, child_type, &child_buf);

                const char *const_str = type_entry->data.pointer.is_const ? "const " : "";
                buf_resize(out_buf, 0);
                buf_appendf(out_buf, "%s%s *", const_str, buf_ptr(&child_buf));
                break;
            }
        case TypeTableEntryIdMaybe:
            {
                TypeTableEntry *child_type = type_entry->data.maybe.child_type;
                if (child_type->id == TypeTableEntryIdPointer ||
                    child_type->id == TypeTableEntryIdFn)
                {
                    return get_c_type(g, child_type, out_buf);
                } else {
                    zig_unreachable();
                }
            }
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
            zig_panic("TODO");
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdVar:
            zig_unreachable();
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
    for (size_t fn_def_i = 0; fn_def_i < g->fn_defs.length; fn_def_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(fn_def_i);
        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        if (fn_proto->top_level_decl.visib_mod != VisibModExport)
            continue;

        FnTypeId *fn_type_id = &fn_table_entry->type_entry->data.fn.fn_type_id;
        Buf return_type_c = BUF_INIT;
        get_c_type(g, fn_type_id->return_type, &return_type_c);

        buf_appendf(&h_buf, "%s %s %s(",
                buf_ptr(export_macro),
                buf_ptr(&return_type_c),
                buf_ptr(&fn_table_entry->symbol_name));

        Buf param_type_c = BUF_INIT;
        if (fn_type_id->param_count > 0) {
            for (size_t param_i = 0; param_i < fn_type_id->param_count; param_i += 1) {
                FnTypeParamInfo *param_info = &fn_type_id->param_info[param_i];
                AstNode *param_decl_node = fn_proto->params.at(param_i);
                Buf *param_name = param_decl_node->data.param_decl.name;

                const char *comma_str = (param_i == 0) ? "" : ", ";
                const char *restrict_str = param_info->is_noalias ? "restrict" : "";
                get_c_type(g, param_info->type, &param_type_c);
                buf_appendf(&h_buf, "%s%s%s %s", comma_str, buf_ptr(&param_type_c),
                        restrict_str, buf_ptr(param_name));
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

    if (g->c_want_stdbool)
        fprintf(out_h, "#include <stdbool.h>\n");
    if (g->c_want_stdint)
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
