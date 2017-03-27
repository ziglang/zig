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
    } else if (g->zig_target.os != ZigLLVM_IOS) {
        g->mmacosx_version_min = buf_create_from_str("10.10");
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
    g->type_table.init(32);
    g->fn_type_table.init(32);
    g->error_table.init(16);
    g->generic_table.init(16);
    g->llvm_fn_table.init(16);
    g->memoized_fn_eval_table.init(16);
    g->compile_vars.init(16);
    g->exported_symbol_names.init(8);
    g->external_prototypes.init(8);
    g->is_release_build = false;
    g->is_test_build = false;
    g->want_h_file = true;

    // reserve index 0 to indicate no error
    g->error_decls.append(nullptr);

    g->root_package = new_package(buf_ptr(root_source_dir), "");
    g->std_package = new_package(ZIG_STD_DIR, "index.zig");
    g->root_package->package_table.put(buf_create_from_str("std"), g->std_package);
    g->zig_std_dir = buf_create_from_str(ZIG_STD_DIR);

    g->zig_std_special_dir = buf_alloc();
    os_path_join(g->zig_std_dir, buf_sprintf("special"), g->zig_std_special_dir);


    if (target) {
        // cross compiling, so we can't rely on all the configured stuff since
        // that's for native compilation
        g->zig_target = *target;
        resolve_target_object_format(&g->zig_target);

        g->dynamic_linker = buf_create_from_str("");
        g->libc_lib_dir = buf_create_from_str("");
        g->libc_static_lib_dir = buf_create_from_str("");
        g->libc_include_dir = buf_create_from_str("");
        g->darwin_linker_version = buf_create_from_str("");
        g->each_lib_rpath = false;
    } else {
        // native compilation, we can rely on the configuration stuff
        g->is_native_target = true;
        get_native_target(&g->zig_target);

        g->dynamic_linker = buf_create_from_str(ZIG_DYNAMIC_LINKER);
        g->libc_lib_dir = buf_create_from_str(ZIG_LIBC_LIB_DIR);
        g->libc_static_lib_dir = buf_create_from_str(ZIG_LIBC_STATIC_LIB_DIR);
        g->libc_include_dir = buf_create_from_str(ZIG_LIBC_INCLUDE_DIR);
        g->darwin_linker_version = buf_create_from_str(ZIG_HOST_LINK_VERSION);
#ifdef ZIG_EACH_LIB_RPATH
        g->each_lib_rpath = true;
#endif

        if (g->zig_target.os == ZigLLVM_Darwin ||
            g->zig_target.os == ZigLLVM_MacOSX ||
            g->zig_target.os == ZigLLVM_IOS)
        {
            init_darwin_native(g);
        }

    }

    // On Darwin/MacOS/iOS, we always link libSystem which contains libc.
    if (g->zig_target.os == ZigLLVM_Darwin ||
        g->zig_target.os == ZigLLVM_MacOSX ||
        g->zig_target.os == ZigLLVM_IOS)
    {
        g->link_libc = true;
        g->link_libs.append(buf_create_from_str("c"));
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

void codegen_set_omit_zigrt(CodeGen *g, bool omit_zigrt) {
    g->omit_zigrt = omit_zigrt;
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

void codegen_set_each_lib_rpath(CodeGen *g, bool each_lib_rpath) {
    g->each_lib_rpath = each_lib_rpath;
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

void codegen_add_lib_dir(CodeGen *g, const char *dir) {
    g->lib_dirs.append(dir);
}

void codegen_add_rpath(CodeGen *g, const char *name) {
    g->rpath_list.append(buf_create_from_str(name));
}

void codegen_add_link_lib(CodeGen *g, const char *lib) {
    if (strcmp(lib, "c") == 0) {
        if (g->link_libc)
            return;
        g->link_libc = true;
    }
    g->link_libs.append(buf_create_from_str(lib));
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

void codegen_set_linker_script(CodeGen *g, const char *linker_script) {
    g->linker_script = linker_script;
}


static void render_const_val(CodeGen *g, ConstExprValue *const_val);
static void render_const_val_global(CodeGen *g, ConstExprValue *const_val, const char *name);
static LLVMValueRef gen_const_val(CodeGen *g, ConstExprValue *const_val);

static void addLLVMAttr(LLVMValueRef val, LLVMAttributeIndex attr_index, const char *attr_name) {
    unsigned kind_id = LLVMGetEnumAttributeKindForName(attr_name, strlen(attr_name));
    assert(kind_id != 0);
    LLVMAttributeRef llvm_attr = LLVMCreateEnumAttribute(LLVMGetGlobalContext(), kind_id, 0);
    LLVMAddAttributeAtIndex(val, attr_index, llvm_attr);
}

static void addLLVMAttrStr(LLVMValueRef val, LLVMAttributeIndex attr_index,
        const char *attr_name, const char *attr_val)
{
    LLVMAttributeRef llvm_attr = LLVMCreateStringAttribute(LLVMGetGlobalContext(),
            attr_name, strlen(attr_name), attr_val, strlen(attr_val));
    LLVMAddAttributeAtIndex(val, attr_index, llvm_attr);
}

static void addLLVMFnAttr(LLVMValueRef fn_val, const char *attr_name) {
    return addLLVMAttr(fn_val, -1, attr_name);
}

static void addLLVMFnAttrStr(LLVMValueRef fn_val, const char *attr_name, const char *attr_val) {
    return addLLVMAttrStr(fn_val, -1, attr_name, attr_val);
}

static void addLLVMArgAttr(LLVMValueRef arg_val, unsigned param_index, const char *attr_name) {
    return addLLVMAttr(arg_val, param_index + 1, attr_name);
}

static void addLLVMCallsiteAttr(LLVMValueRef call_instr, unsigned param_index, const char *attr_name) {
    unsigned kind_id = LLVMGetEnumAttributeKindForName(attr_name, strlen(attr_name));
    assert(kind_id != 0);
    LLVMAttributeRef llvm_attr = LLVMCreateEnumAttribute(LLVMGetGlobalContext(), kind_id, 0);
    LLVMAddCallSiteAttribute(call_instr, param_index + 1, llvm_attr);
}

static bool is_symbol_available(CodeGen *g, Buf *name) {
    return g->exported_symbol_names.maybe_get(name) == nullptr && g->external_prototypes.maybe_get(name) == nullptr;
}

static Buf *get_mangled_name(CodeGen *g, Buf *original_name, bool external_linkage) {
    if (external_linkage || is_symbol_available(g, original_name)) {
        return original_name;
    }

    int n = 0;
    for (;; n += 1) {
        Buf *new_name = buf_sprintf("%s.%d", buf_ptr(original_name), n);
        if (is_symbol_available(g, new_name)) {
            return new_name;
        }
    }
}

static LLVMValueRef fn_llvm_value(CodeGen *g, FnTableEntry *fn_table_entry) {
    if (fn_table_entry->llvm_value)
        return fn_table_entry->llvm_value;

    bool external_linkage = (fn_table_entry->linkage != GlobalLinkageIdInternal);
    Buf *symbol_name = get_mangled_name(g, &fn_table_entry->symbol_name, external_linkage);

    TypeTableEntry *fn_type = fn_table_entry->type_entry;
    LLVMTypeRef fn_llvm_type = fn_type->data.fn.raw_type_ref;
    if (external_linkage && fn_table_entry->body_node == nullptr) {
        LLVMValueRef existing_llvm_fn = LLVMGetNamedFunction(g->module, buf_ptr(symbol_name));
        if (existing_llvm_fn) {
            fn_table_entry->llvm_value = LLVMConstBitCast(existing_llvm_fn, LLVMPointerType(fn_llvm_type, 0));
        } else {
            fn_table_entry->llvm_value = LLVMAddFunction(g->module, buf_ptr(symbol_name), fn_llvm_type);
        }
    } else {
        fn_table_entry->llvm_value = LLVMAddFunction(g->module, buf_ptr(symbol_name), fn_llvm_type);
    }

    switch (fn_table_entry->fn_inline) {
        case FnInlineAlways:
            addLLVMFnAttr(fn_table_entry->llvm_value, "alwaysinline");
            break;
        case FnInlineNever:
            addLLVMFnAttr(fn_table_entry->llvm_value, "noinline");
            break;
        case FnInlineAuto:
            break;
    }
    if (fn_type->data.fn.fn_type_id.is_naked) {
        addLLVMFnAttr(fn_table_entry->llvm_value, "naked");
    }

    switch (fn_table_entry->linkage) {
        case GlobalLinkageIdInternal:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMInternalLinkage);
            break;
        case GlobalLinkageIdStrong:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMExternalLinkage);
            break;
        case GlobalLinkageIdWeak:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMWeakODRLinkage);
            break;
        case GlobalLinkageIdLinkOnce:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMLinkOnceODRLinkage);
            break;
    }

    if (fn_type->data.fn.fn_type_id.return_type->id == TypeTableEntryIdUnreachable) {
        addLLVMFnAttr(fn_table_entry->llvm_value, "noreturn");
    }

    if (fn_table_entry->body_node != nullptr) {
        bool want_fn_safety = !g->is_release_build && !fn_table_entry->def_scope->safety_off;
        if (want_fn_safety) {
            if (g->link_libc) {
                addLLVMFnAttr(fn_table_entry->llvm_value, "sspstrong");
                addLLVMFnAttrStr(fn_table_entry->llvm_value, "stack-protector-buffer-size", "4");
            }
        }
    }

    LLVMSetFunctionCallConv(fn_table_entry->llvm_value, fn_type->data.fn.calling_convention);
    if (fn_type->data.fn.fn_type_id.is_cold) {
        ZigLLVMAddFunctionAttrCold(fn_table_entry->llvm_value);
    }
    addLLVMFnAttr(fn_table_entry->llvm_value, "nounwind");
    if (!g->is_release_build && fn_table_entry->fn_inline != FnInlineAlways) {
        ZigLLVMAddFunctionAttr(fn_table_entry->llvm_value, "no-frame-pointer-elim", "true");
        ZigLLVMAddFunctionAttr(fn_table_entry->llvm_value, "no-frame-pointer-elim-non-leaf", nullptr);
    }
    if (fn_table_entry->section_name) {
        LLVMSetSection(fn_table_entry->llvm_value, buf_ptr(fn_table_entry->section_name));
    }
    if (fn_table_entry->alignment) {
        LLVMSetAlignment(fn_table_entry->llvm_value, fn_table_entry->alignment);
    }

    return fn_table_entry->llvm_value;
}

static ZigLLVMDIScope *get_di_scope(CodeGen *g, Scope *scope) {
    if (scope->di_scope)
        return scope->di_scope;

    ImportTableEntry *import = get_scope_import(scope);
    switch (scope->id) {
        case ScopeIdCImport:
            zig_unreachable();
        case ScopeIdFnDef:
        {
            assert(scope->parent);
            ScopeFnDef *fn_scope = (ScopeFnDef *)scope;
            FnTableEntry *fn_table_entry = fn_scope->fn_entry;
            if (!fn_table_entry->proto_node)
                return get_di_scope(g, scope->parent);
            unsigned line_number = fn_table_entry->proto_node->line + 1;
            unsigned scope_line = line_number;
            bool is_definition = fn_table_entry->body_node != nullptr;
            unsigned flags = 0;
            bool is_optimized = g->is_release_build;
            bool is_internal_linkage = (fn_table_entry->linkage == GlobalLinkageIdInternal);
            ZigLLVMDISubprogram *subprogram = ZigLLVMCreateFunction(g->dbuilder,
                get_di_scope(g, scope->parent), buf_ptr(&fn_table_entry->symbol_name), "",
                import->di_file, line_number,
                fn_table_entry->type_entry->di_type, is_internal_linkage,
                is_definition, scope_line, flags, is_optimized, nullptr);

            scope->di_scope = ZigLLVMSubprogramToScope(subprogram);
            ZigLLVMFnSetSubprogram(fn_llvm_value(g, fn_table_entry), subprogram);
            return scope->di_scope;
        }
        case ScopeIdDecls:
            if (scope->parent) {
                ScopeDecls *decls_scope = (ScopeDecls *)scope;
                assert(decls_scope->container_type);
                scope->di_scope = ZigLLVMTypeToScope(decls_scope->container_type->di_type);
            } else {
                scope->di_scope = ZigLLVMFileToScope(import->di_file);
            }
            return scope->di_scope;
        case ScopeIdBlock:
        case ScopeIdDefer:
        case ScopeIdVarDecl:
        {
            assert(scope->parent);
            ZigLLVMDILexicalBlock *di_block = ZigLLVMCreateLexicalBlock(g->dbuilder,
                get_di_scope(g, scope->parent),
                import->di_file,
                scope->source_node->line + 1,
                scope->source_node->column + 1);
            scope->di_scope = ZigLLVMLexicalBlockToScope(di_block);
            return scope->di_scope;
        }
        case ScopeIdDeferExpr:
        case ScopeIdLoop:
        case ScopeIdCompTime:
            return get_di_scope(g, scope->parent);
    }
    zig_unreachable();
}

static void clear_debug_source_node(CodeGen *g) {
    ZigLLVMClearCurrentDebugLocation(g->builder);
}

static LLVMValueRef get_arithmetic_overflow_fn(CodeGen *g, TypeTableEntry *type_entry,
        const char *signed_name, const char *unsigned_name)
{
    char fn_name[64];

    assert(type_entry->id == TypeTableEntryIdInt);
    const char *signed_str = type_entry->data.integral.is_signed ? signed_name : unsigned_name;
    sprintf(fn_name, "llvm.%s.with.overflow.i%zu", signed_str, type_entry->data.integral.bit_count);

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
    LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type);
    assert(LLVMGetIntrinsicID(fn_val));
    return fn_val;
}

static LLVMValueRef get_int_overflow_fn(CodeGen *g, TypeTableEntry *type_entry, AddSubMul add_sub_mul) {
    assert(type_entry->id == TypeTableEntryIdInt);

    ZigLLVMFnKey key = {};
    key.id = ZigLLVMFnIdOverflowArithmetic;
    key.data.overflow_arithmetic.is_signed = type_entry->data.integral.is_signed;
    key.data.overflow_arithmetic.add_sub_mul = add_sub_mul;
    key.data.overflow_arithmetic.bit_count = type_entry->data.integral.bit_count;

    auto existing_entry = g->llvm_fn_table.maybe_get(key);
    if (existing_entry)
        return existing_entry->value;

    LLVMValueRef fn_val;
    switch (add_sub_mul) {
        case AddSubMulAdd:
            fn_val = get_arithmetic_overflow_fn(g, type_entry, "sadd", "uadd");
            break;
        case AddSubMulSub:
            fn_val = get_arithmetic_overflow_fn(g, type_entry, "ssub", "usub");
            break;
        case AddSubMulMul:
            fn_val = get_arithmetic_overflow_fn(g, type_entry, "smul", "umul");
            break;
    }

    g->llvm_fn_table.put(key, fn_val);
    return fn_val;
}

static LLVMValueRef get_handle_value(CodeGen *g, LLVMValueRef ptr, TypeTableEntry *type, bool is_volatile) {
    if (type_has_bits(type)) {
        if (handle_is_ptr(type)) {
            return ptr;
        } else {
            LLVMValueRef result = LLVMBuildLoad(g->builder, ptr, "");
            LLVMSetVolatile(result, is_volatile);
            return result;
        }
    } else {
        return nullptr;
    }
}

static bool ir_want_debug_safety(CodeGen *g, IrInstruction *instruction) {
    if (g->is_release_build)
        return false;

    // TODO memoize
    Scope *scope = instruction->scope;
    while (scope) {
        if (scope->id == ScopeIdBlock) {
            ScopeBlock *block_scope = (ScopeBlock *)scope;
            if (block_scope->safety_set_node)
                return !block_scope->safety_off;
        } else if (scope->id == ScopeIdDecls) {
            ScopeDecls *decls_scope = (ScopeDecls *)scope;
            if (decls_scope->safety_set_node)
                return !decls_scope->safety_off;
        }
        scope = scope->parent;
    }
    return true;
}

static Buf *panic_msg_buf(PanicMsgId msg_id) {
    switch (msg_id) {
        case PanicMsgIdCount:
            zig_unreachable();
        case PanicMsgIdBoundsCheckFailure:
            return buf_create_from_str("index out of bounds");
        case PanicMsgIdCastNegativeToUnsigned:
            return buf_create_from_str("attempt to cast negative value to unsigned integer");
        case PanicMsgIdCastTruncatedData:
            return buf_create_from_str("integer cast truncated bits");
        case PanicMsgIdIntegerOverflow:
            return buf_create_from_str("integer overflow");
        case PanicMsgIdShiftOverflowedBits:
            return buf_create_from_str("left shift overflowed bits");
        case PanicMsgIdDivisionByZero:
            return buf_create_from_str("division by zero");
        case PanicMsgIdRemainderDivisionByZero:
            return buf_create_from_str("remainder division by zero");
        case PanicMsgIdExactDivisionRemainder:
            return buf_create_from_str("exact division produced remainder");
        case PanicMsgIdSliceWidenRemainder:
            return buf_create_from_str("slice widening size mismatch");
        case PanicMsgIdUnwrapMaybeFail:
            return buf_create_from_str("attempt to unwrap null");
        case PanicMsgIdUnwrapErrFail:
            return buf_create_from_str("attempt to unwrap error");
        case PanicMsgIdUnreachable:
            return buf_create_from_str("reached unreachable code");
    }
    zig_unreachable();
}

static LLVMValueRef get_panic_msg_ptr_val(CodeGen *g, PanicMsgId msg_id) {
    ConstExprValue *val = &g->panic_msg_vals[msg_id];
    if (val->llvm_global)
        return val->llvm_global;

    Buf *buf_msg = panic_msg_buf(msg_id);
    ConstExprValue *array_val = create_const_str_lit(g, buf_msg);
    init_const_slice(g, val, array_val, 0, buf_len(buf_msg), true);

    render_const_val_global(g, val, "");
    render_const_val(g, val);

    assert(val->llvm_global);
    return val->llvm_global;
}

static void gen_panic(CodeGen *g, LLVMValueRef msg_arg) {
    FnTableEntry *panic_fn = get_extern_panic_fn(g);
    LLVMValueRef fn_val = fn_llvm_value(g, panic_fn);

    TypeTableEntry *str_type = get_slice_type(g, g->builtin_types.entry_u8, true);
    size_t ptr_index = str_type->data.structure.fields[slice_ptr_index].gen_index;
    size_t len_index = str_type->data.structure.fields[slice_len_index].gen_index;
    LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, msg_arg, ptr_index, "");
    LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, msg_arg, len_index, "");

    LLVMValueRef args[] = {
        LLVMBuildLoad(g->builder, ptr_ptr, ""),
        LLVMBuildLoad(g->builder, len_ptr, ""),
    };
    ZigLLVMBuildCall(g->builder, fn_val, args, 2, panic_fn->type_entry->data.fn.calling_convention, "");
    LLVMBuildUnreachable(g->builder);
}

static void gen_debug_safety_crash(CodeGen *g, PanicMsgId msg_id) {
    gen_panic(g, get_panic_msg_ptr_val(g, msg_id));
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

    LLVMBasicBlockRef bounds_check_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "BoundsCheckFail");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "BoundsCheckOk");
    LLVMBasicBlockRef lower_ok_block = upper_value ?
        LLVMAppendBasicBlock(g->cur_fn_val, "FirstBoundsCheckOk") : ok_block;

    LLVMValueRef lower_ok_val = LLVMBuildICmp(g->builder, lower_pred, target_val, lower_value, "");
    LLVMBuildCondBr(g->builder, lower_ok_val, lower_ok_block, bounds_check_fail_block);

    LLVMPositionBuilderAtEnd(g->builder, bounds_check_fail_block);
    gen_debug_safety_crash(g, PanicMsgIdBoundsCheckFailure);

    if (upper_value) {
        LLVMPositionBuilderAtEnd(g->builder, lower_ok_block);
        LLVMValueRef upper_ok_val = LLVMBuildICmp(g->builder, upper_pred, target_val, upper_value, "");
        LLVMBuildCondBr(g->builder, upper_ok_val, ok_block, bounds_check_fail_block);
    }

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
}

static LLVMValueRef gen_widen_or_shorten(CodeGen *g, bool want_debug_safety, TypeTableEntry *actual_type_non_canon,
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
        want_debug_safety)
    {
        LLVMValueRef zero = LLVMConstNull(actual_type->type_ref);
        LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntSGE, expr_val, zero, "");

        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "SignCastOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "SignCastFail");
        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_debug_safety_crash(g, PanicMsgIdCastNegativeToUnsigned);

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
            if (!want_debug_safety) {
                return trunc_val;
            }
            LLVMValueRef orig_val;
            if (actual_type->data.integral.is_signed) {
                orig_val = LLVMBuildSExt(g->builder, trunc_val, actual_type->type_ref, "");
            } else {
                orig_val = LLVMBuildZExt(g->builder, trunc_val, actual_type->type_ref, "");
            }
            LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, expr_val, orig_val, "");
            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "CastShortenOk");
            LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "CastShortenFail");
            LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

            LLVMPositionBuilderAtEnd(g->builder, fail_block);
            gen_debug_safety_crash(g, PanicMsgIdCastTruncatedData);

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
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowFail");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowOk");
    LLVMBuildCondBr(g->builder, overflow_bit, fail_block, ok_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_debug_safety_crash(g, PanicMsgIdIntegerOverflow);

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

static bool is_array_of_at_least_n_bytes(CodeGen *g, TypeTableEntry *type_entry, uint32_t n) {
    if (type_entry->id != TypeTableEntryIdArray)
        return false;

    TypeTableEntry *child_type = type_entry->data.array.child_type;
    if (child_type->id != TypeTableEntryIdInt)
        return false;

    if (child_type != g->builtin_types.entry_u8)
        return false;

    if (type_entry->data.array.len < n)
        return false;

    return true;
}

static uint32_t get_type_alignment(CodeGen *g, TypeTableEntry *type_entry) {
    uint32_t alignment = ZigLLVMGetPrefTypeAlignment(g->target_data_ref, type_entry->type_ref);
    uint32_t dbl_ptr_bytes = g->pointer_size_bytes * 2;
    if (is_array_of_at_least_n_bytes(g, type_entry, dbl_ptr_bytes)) {
        return (alignment < dbl_ptr_bytes) ? dbl_ptr_bytes : alignment;
    } else {
        return alignment;
    }
}

static LLVMValueRef gen_struct_memcpy(CodeGen *g, LLVMValueRef src, LLVMValueRef dest,
        TypeTableEntry *type_entry)
{
    assert(handle_is_ptr(type_entry));

    assert(LLVMGetTypeKind(LLVMTypeOf(src)) == LLVMPointerTypeKind);
    assert(LLVMGetTypeKind(LLVMTypeOf(dest)) == LLVMPointerTypeKind);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    LLVMValueRef src_ptr = LLVMBuildBitCast(g->builder, src, ptr_u8, "");
    LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, dest, ptr_u8, "");

    TypeTableEntry *usize = g->builtin_types.entry_usize;
    uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, type_entry->type_ref);
    uint64_t align_bytes = get_type_alignment(g, type_entry);
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

static LLVMValueRef gen_assign_raw(CodeGen *g, LLVMValueRef target_ref, LLVMValueRef value,
        TypeTableEntry *child_type)
{
    if (!type_has_bits(child_type))
        return nullptr;

    if (handle_is_ptr(child_type))
        return gen_struct_memcpy(g, value, target_ref, child_type);

    LLVMBuildStore(g->builder, value, target_ref);
    return nullptr;
}

static void gen_var_debug_decl(CodeGen *g, VariableTableEntry *var) {
    AstNode *source_node = var->decl_node;
    ZigLLVMDILocation *debug_loc = ZigLLVMGetDebugLoc(source_node->line + 1, source_node->column + 1,
        get_di_scope(g, var->parent_scope));
    ZigLLVMInsertDeclareAtEnd(g->dbuilder, var->value_ref, var->di_loc_var, debug_loc,
            LLVMGetInsertBlock(g->builder));
}

static LLVMValueRef ir_llvm_value(CodeGen *g, IrInstruction *instruction) {
    if (!type_has_bits(instruction->value.type))
        return nullptr;
    if (!instruction->llvm_value) {
        assert(instruction->value.special != ConstValSpecialRuntime);
        assert(instruction->value.type);
        render_const_val(g, &instruction->value);
        // we might have to do some pointer casting here due to the way union
        // values are rendered with a type other than the one we expect
        if (handle_is_ptr(instruction->value.type)) {
            render_const_val_global(g, &instruction->value, "");
            TypeTableEntry *ptr_type = get_pointer_to_type(g, instruction->value.type, true);
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value.llvm_global, ptr_type->type_ref, "");
        } else if (instruction->value.type->id == TypeTableEntryIdPointer) {
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value.llvm_value, instruction->value.type->type_ref, "");
        } else {
            instruction->llvm_value = instruction->value.llvm_value;
        }
        assert(instruction->llvm_value);
    }
    return instruction->llvm_value;
}

static LLVMValueRef ir_render_return(CodeGen *g, IrExecutable *executable, IrInstructionReturn *return_instruction) {
    LLVMValueRef value = ir_llvm_value(g, return_instruction->value);
    TypeTableEntry *return_type = return_instruction->value->value.type;
    bool is_extern = g->cur_fn->type_entry->data.fn.fn_type_id.is_extern;
    if (handle_is_ptr(return_type)) {
        if (is_extern) {
            LLVMValueRef by_val_value = LLVMBuildLoad(g->builder, value, "");
            LLVMBuildRet(g->builder, by_val_value);
        } else {
            assert(g->cur_ret_ptr);
            gen_assign_raw(g, g->cur_ret_ptr, value, return_type);
            LLVMBuildRetVoid(g->builder);
        }
    } else {
        LLVMBuildRet(g->builder, value);
    }
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

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowFail");
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_debug_safety_crash(g, PanicMsgIdShiftOverflowedBits);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_div(CodeGen *g, bool want_debug_safety, LLVMValueRef val1, LLVMValueRef val2,
        TypeTableEntry *type_entry, bool exact)
{

    if (want_debug_safety) {
        LLVMValueRef zero = LLVMConstNull(type_entry->type_ref);
        LLVMValueRef is_zero_bit;
        if (type_entry->id == TypeTableEntryIdInt) {
            is_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");
        } else if (type_entry->id == TypeTableEntryIdFloat) {
            is_zero_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, val2, zero, "");
        } else {
            zig_unreachable();
        }
        LLVMBasicBlockRef div_zero_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivZeroOk");
        LLVMBasicBlockRef div_zero_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivZeroFail");
        LLVMBuildCondBr(g->builder, is_zero_bit, div_zero_fail_block, div_zero_ok_block);

        LLVMPositionBuilderAtEnd(g->builder, div_zero_fail_block);
        gen_debug_safety_crash(g, PanicMsgIdDivisionByZero);

        LLVMPositionBuilderAtEnd(g->builder, div_zero_ok_block);

        if (type_entry->id == TypeTableEntryIdInt && type_entry->data.integral.is_signed) {
            LLVMValueRef neg_1_value = LLVMConstInt(type_entry->type_ref, -1, true);
            LLVMValueRef int_min_value = LLVMConstInt(type_entry->type_ref, min_signed_val(type_entry), true);
            LLVMBasicBlockRef overflow_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivOverflowOk");
            LLVMBasicBlockRef overflow_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivOverflowFail");
            LLVMValueRef num_is_int_min = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, int_min_value, "");
            LLVMValueRef den_is_neg_1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, neg_1_value, "");
            LLVMValueRef overflow_fail_bit = LLVMBuildAnd(g->builder, num_is_int_min, den_is_neg_1, "");
            LLVMBuildCondBr(g->builder, overflow_fail_bit, overflow_fail_block, overflow_ok_block);

            LLVMPositionBuilderAtEnd(g->builder, overflow_fail_block);
            gen_debug_safety_crash(g, PanicMsgIdIntegerOverflow);

            LLVMPositionBuilderAtEnd(g->builder, overflow_ok_block);
        }
    }

    if (type_entry->id == TypeTableEntryIdFloat) {
        assert(!exact);
        return LLVMBuildFDiv(g->builder, val1, val2, "");
    }

    assert(type_entry->id == TypeTableEntryIdInt);

    if (exact) {
        if (want_debug_safety) {
            LLVMValueRef remainder_val;
            if (type_entry->data.integral.is_signed) {
                remainder_val = LLVMBuildSRem(g->builder, val1, val2, "");
            } else {
                remainder_val = LLVMBuildURem(g->builder, val1, val2, "");
            }
            LLVMValueRef zero = LLVMConstNull(type_entry->type_ref);
            LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, remainder_val, zero, "");

            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactOk");
            LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactFail");
            LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

            LLVMPositionBuilderAtEnd(g->builder, fail_block);
            gen_debug_safety_crash(g, PanicMsgIdExactDivisionRemainder);

            LLVMPositionBuilderAtEnd(g->builder, ok_block);
        }
        if (type_entry->data.integral.is_signed) {
            return LLVMBuildExactSDiv(g->builder, val1, val2, "");
        } else {
            return LLVMBuildExactUDiv(g->builder, val1, val2, "");
        }
    } else {
        if (type_entry->data.integral.is_signed) {
            return LLVMBuildSDiv(g->builder, val1, val2, "");
        } else {
            return LLVMBuildUDiv(g->builder, val1, val2, "");
        }
    }
}

static LLVMValueRef gen_rem(CodeGen *g, bool want_debug_safety, LLVMValueRef val1, LLVMValueRef val2,
        TypeTableEntry *type_entry)
{

    if (want_debug_safety) {
        LLVMValueRef zero = LLVMConstNull(type_entry->type_ref);
        LLVMValueRef is_zero_bit;
        if (type_entry->id == TypeTableEntryIdInt) {
            is_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");
        } else if (type_entry->id == TypeTableEntryIdFloat) {
            is_zero_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, val2, zero, "");
        } else {
            zig_unreachable();
        }
        LLVMBasicBlockRef rem_zero_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemZeroOk");
        LLVMBasicBlockRef rem_zero_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemZeroFail");
        LLVMBuildCondBr(g->builder, is_zero_bit, rem_zero_fail_block, rem_zero_ok_block);

        LLVMPositionBuilderAtEnd(g->builder, rem_zero_fail_block);
        gen_debug_safety_crash(g, PanicMsgIdRemainderDivisionByZero);

        LLVMPositionBuilderAtEnd(g->builder, rem_zero_ok_block);

        if (type_entry->id == TypeTableEntryIdInt && type_entry->data.integral.is_signed) {
            LLVMValueRef neg_1_value = LLVMConstInt(type_entry->type_ref, -1, true);
            LLVMValueRef int_min_value = LLVMConstInt(type_entry->type_ref, min_signed_val(type_entry), true);
            LLVMBasicBlockRef overflow_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemOverflowOk");
            LLVMBasicBlockRef overflow_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemOverflowFail");
            LLVMValueRef num_is_int_min = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, int_min_value, "");
            LLVMValueRef den_is_neg_1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, neg_1_value, "");
            LLVMValueRef overflow_fail_bit = LLVMBuildAnd(g->builder, num_is_int_min, den_is_neg_1, "");
            LLVMBuildCondBr(g->builder, overflow_fail_bit, overflow_fail_block, overflow_ok_block);

            LLVMPositionBuilderAtEnd(g->builder, overflow_fail_block);
            gen_debug_safety_crash(g, PanicMsgIdIntegerOverflow);

            LLVMPositionBuilderAtEnd(g->builder, overflow_ok_block);
        }
    }

    if (type_entry->id == TypeTableEntryIdFloat) {
        return LLVMBuildFRem(g->builder, val1, val2, "");
    } else {
        assert(type_entry->id == TypeTableEntryIdInt);
        if (type_entry->data.integral.is_signed) {
            return LLVMBuildSRem(g->builder, val1, val2, "");
        } else {
            return LLVMBuildURem(g->builder, val1, val2, "");
        }
    }

}

static LLVMValueRef ir_render_bin_op(CodeGen *g, IrExecutable *executable,
        IrInstructionBinOp *bin_op_instruction)
{
    IrBinOp op_id = bin_op_instruction->op_id;
    IrInstruction *op1 = bin_op_instruction->op1;
    IrInstruction *op2 = bin_op_instruction->op2;

    assert(op1->value.type == op2->value.type);
    TypeTableEntry *canon_type = get_underlying_type(op1->value.type);

    bool want_debug_safety = bin_op_instruction->safety_check_on &&
        ir_want_debug_safety(g, &bin_op_instruction->base);

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
            if (canon_type->id == TypeTableEntryIdFloat) {
                LLVMRealPredicate pred = cmp_op_to_real_predicate(op_id);
                return LLVMBuildFCmp(g->builder, pred, op1_value, op2_value, "");
            } else if (canon_type->id == TypeTableEntryIdInt) {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, canon_type->data.integral.is_signed);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else if (canon_type->id == TypeTableEntryIdEnum) {
                if (canon_type->data.enumeration.gen_field_count == 0) {
                    LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, false);
                    return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
                } else {
                    zig_unreachable();
                }
            } else if (canon_type->id == TypeTableEntryIdPureError ||
                    canon_type->id == TypeTableEntryIdPointer ||
                    canon_type->id == TypeTableEntryIdBool)
            {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, false);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else {
                zig_unreachable();
            }
        case IrBinOpAdd:
        case IrBinOpAddWrap:
            if (canon_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFAdd(g->builder, op1_value, op2_value, "");
            } else if (canon_type->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpAddWrap);
                if (is_wrapping) {
                    return LLVMBuildAdd(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety) {
                    return gen_overflow_op(g, canon_type, AddSubMulAdd, op1_value, op2_value);
                } else if (canon_type->data.integral.is_signed) {
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
                assert(canon_type->id == TypeTableEntryIdInt);
                bool is_wrapping = (op_id == IrBinOpBitShiftLeftWrap);
                if (is_wrapping) {
                    return LLVMBuildShl(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety) {
                    return gen_overflow_shl_op(g, canon_type, op1_value, op2_value);
                } else if (canon_type->data.integral.is_signed) {
                    return ZigLLVMBuildNSWShl(g->builder, op1_value, op2_value, "");
                } else {
                    return ZigLLVMBuildNUWShl(g->builder, op1_value, op2_value, "");
                }
            }
        case IrBinOpBitShiftRight:
            assert(canon_type->id == TypeTableEntryIdInt);
            if (canon_type->data.integral.is_signed) {
                return LLVMBuildAShr(g->builder, op1_value, op2_value, "");
            } else {
                return LLVMBuildLShr(g->builder, op1_value, op2_value, "");
            }
        case IrBinOpSub:
        case IrBinOpSubWrap:
            if (canon_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFSub(g->builder, op1_value, op2_value, "");
            } else if (canon_type->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpSubWrap);
                if (is_wrapping) {
                    return LLVMBuildSub(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety) {
                    return gen_overflow_op(g, canon_type, AddSubMulSub, op1_value, op2_value);
                } else if (canon_type->data.integral.is_signed) {
                    return LLVMBuildNSWSub(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildNUWSub(g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
        case IrBinOpMult:
        case IrBinOpMultWrap:
            if (canon_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFMul(g->builder, op1_value, op2_value, "");
            } else if (canon_type->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpMultWrap);
                if (is_wrapping) {
                    return LLVMBuildMul(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety) {
                    return gen_overflow_op(g, canon_type, AddSubMulMul, op1_value, op2_value);
                } else if (canon_type->data.integral.is_signed) {
                    return LLVMBuildNSWMul(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildNUWMul(g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
        case IrBinOpDiv:
            return gen_div(g, want_debug_safety, op1_value, op2_value, canon_type, false);
        case IrBinOpRem:
            return gen_rem(g, want_debug_safety, op1_value, op2_value, canon_type);
    }
    zig_unreachable();
}

static LLVMValueRef ir_render_cast(CodeGen *g, IrExecutable *executable,
        IrInstructionCast *cast_instruction)
{
    TypeTableEntry *actual_type = cast_instruction->value->value.type;
    TypeTableEntry *wanted_type = cast_instruction->base.value.type;
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
                return gen_widen_or_shorten(g, ir_want_debug_safety(g, &cast_instruction->base),
                    g->err_tag_type, wanted_type, expr_val);
            } else {
                zig_panic("TODO");
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
                        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "SliceWidenOk");
                        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "SliceWidenFail");
                        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

                        LLVMPositionBuilderAtEnd(g->builder, fail_block);
                        gen_debug_safety_crash(g, PanicMsgIdSliceWidenRemainder);

                        LLVMPositionBuilderAtEnd(g->builder, ok_block);
                    }
                    new_len = LLVMBuildExactUDiv(g->builder, src_len, dest_size_val, "");
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
    }
    zig_unreachable();
}

static LLVMValueRef ir_render_pointer_reinterpret(CodeGen *g, IrExecutable *executable,
        IrInstructionPointerReinterpret *instruction)
{
    TypeTableEntry *wanted_type = instruction->base.value.type;
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    return LLVMBuildBitCast(g->builder, ptr, wanted_type->type_ref, "");
}

static LLVMValueRef ir_render_widen_or_shorten(CodeGen *g, IrExecutable *executable,
        IrInstructionWidenOrShorten *instruction)
{
    TypeTableEntry *actual_type = instruction->target->value.type;
    // TODO instead of this logic, use the Noop instruction to change the type from
    // enum_tag to the underlying int type
    TypeTableEntry *int_type;
    if (actual_type->id == TypeTableEntryIdEnum) {
        TypeTableEntry *tag_type = actual_type->data.enumeration.tag_type;
        assert(tag_type->id == TypeTableEntryIdEnumTag);
        int_type = tag_type->data.enum_tag.int_type;
    } else {
        int_type = actual_type;
    }
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    return gen_widen_or_shorten(g, ir_want_debug_safety(g, &instruction->base), int_type,
            instruction->base.value.type, target_val);
}

static LLVMValueRef ir_render_int_to_ptr(CodeGen *g, IrExecutable *executable, IrInstructionIntToPtr *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    return LLVMBuildIntToPtr(g->builder, target_val, wanted_type->type_ref, "");
}

static LLVMValueRef ir_render_ptr_to_int(CodeGen *g, IrExecutable *executable, IrInstructionPtrToInt *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    return LLVMBuildPtrToInt(g->builder, target_val, wanted_type->type_ref, "");
}

static LLVMValueRef ir_render_int_to_enum(CodeGen *g, IrExecutable *executable, IrInstructionIntToEnum *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;
    assert(wanted_type->id == TypeTableEntryIdEnum);
    TypeTableEntry *tag_type = wanted_type->data.enumeration.tag_type;
    TypeTableEntry *wanted_int_type;
    if (tag_type->id == TypeTableEntryIdEnumTag) {
        wanted_int_type = tag_type->data.enum_tag.int_type;
    } else if (tag_type->id == TypeTableEntryIdInt) {
        wanted_int_type = tag_type;
    } else {
        zig_unreachable();
    }

    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    return gen_widen_or_shorten(g, ir_want_debug_safety(g, &instruction->base),
            instruction->target->value.type, wanted_int_type, target_val);
}

static LLVMValueRef ir_render_unreachable(CodeGen *g, IrExecutable *executable,
        IrInstructionUnreachable *unreachable_instruction)
{
    if (ir_want_debug_safety(g, &unreachable_instruction->base) || g->is_test_build) {
        gen_debug_safety_crash(g, PanicMsgIdUnreachable);
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
    TypeTableEntry *expr_type = un_op_instruction->value->value.type;

    switch (op_id) {
        case IrUnOpInvalid:
        case IrUnOpError:
        case IrUnOpMaybe:
        case IrUnOpDereference:
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
        case IrUnOpBinNot:
            return LLVMBuildNot(g->builder, expr, "");
    }

    zig_unreachable();
}

static LLVMValueRef ir_render_bool_not(CodeGen *g, IrExecutable *executable, IrInstructionBoolNot *instruction) {
    LLVMValueRef value = ir_llvm_value(g, instruction->value);
    LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(value));
    return LLVMBuildICmp(g->builder, LLVMIntEQ, value, zero, "");
}

static LLVMValueRef ir_render_decl_var(CodeGen *g, IrExecutable *executable,
        IrInstructionDeclVar *decl_var_instruction)
{
    VariableTableEntry *var = decl_var_instruction->var;

    if (!type_has_bits(var->value->type))
        return nullptr;

    if (var->ref_count == 0 && g->is_release_build)
        return nullptr;

    IrInstruction *init_value = decl_var_instruction->init_value;

    bool have_init_expr = false;

    ConstExprValue *const_val = &init_value->value;
    if (const_val->special == ConstValSpecialRuntime || const_val->special == ConstValSpecialStatic)
        have_init_expr = true;

    if (have_init_expr) {
        assert(var->value->type == init_value->value.type);
        gen_assign_raw(g, var->value_ref, ir_llvm_value(g, init_value), var->value->type);
    } else {
        bool ignore_uninit = false;
        // handle runtime stack allocation
        bool want_safe = ir_want_debug_safety(g, &decl_var_instruction->base);
        if (!ignore_uninit && want_safe) {
            TypeTableEntry *usize = g->builtin_types.entry_usize;
            uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, var->value->type->type_ref);
            uint64_t align_bytes = get_type_alignment(g, var->value->type);

            // memset uninitialized memory to 0xa
            LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
            LLVMValueRef fill_char = LLVMConstInt(LLVMInt8Type(), 0xaa, false);
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
    TypeTableEntry *child_type = instruction->base.value.type;
    if (!type_has_bits(child_type))
        return nullptr;

    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    TypeTableEntry *ptr_type = instruction->ptr->value.type;
    assert(ptr_type->id == TypeTableEntryIdPointer);
    bool is_volatile = ptr_type->data.pointer.is_volatile;

    uint32_t unaligned_bit_count = ptr_type->data.pointer.unaligned_bit_count;
    if (unaligned_bit_count == 0)
        return get_handle_value(g, ptr, child_type, is_volatile);

    assert(!handle_is_ptr(child_type));
    LLVMValueRef containing_int = LLVMBuildLoad(g->builder, ptr, "");
    LLVMSetVolatile(containing_int, is_volatile);

    uint32_t bit_offset = ptr_type->data.pointer.bit_offset;
    uint32_t host_bit_count = LLVMGetIntTypeWidth(LLVMTypeOf(containing_int));
    uint32_t shift_amt = host_bit_count - bit_offset - unaligned_bit_count;

    LLVMValueRef shift_amt_val = LLVMConstInt(LLVMTypeOf(containing_int), shift_amt, false);
    LLVMValueRef shifted_value = LLVMBuildLShr(g->builder, containing_int, shift_amt_val, "");

    return LLVMBuildTrunc(g->builder, shifted_value, child_type->type_ref, "");
}

static LLVMValueRef ir_render_store_ptr(CodeGen *g, IrExecutable *executable, IrInstructionStorePtr *instruction) {
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef value = ir_llvm_value(g, instruction->value);

    assert(instruction->ptr->value.type->id == TypeTableEntryIdPointer);
    TypeTableEntry *ptr_type = get_underlying_type(instruction->ptr->value.type);
    TypeTableEntry *child_type = get_underlying_type(ptr_type->data.pointer.child_type);

    if (!type_has_bits(child_type))
        return nullptr;

    if (handle_is_ptr(child_type))
        return gen_struct_memcpy(g, value, ptr, child_type);

    uint32_t unaligned_bit_count = ptr_type->data.pointer.unaligned_bit_count;
    if (unaligned_bit_count == 0) {
        LLVMValueRef llvm_instruction = LLVMBuildStore(g->builder, value, ptr);
        LLVMSetVolatile(llvm_instruction, ptr_type->data.pointer.is_volatile);
        return nullptr;
    }

    LLVMValueRef containing_int = LLVMBuildLoad(g->builder, ptr, "");

    uint32_t bit_offset = ptr_type->data.pointer.bit_offset;
    uint32_t host_bit_count = LLVMGetIntTypeWidth(LLVMTypeOf(containing_int));
    uint32_t shift_amt = host_bit_count - bit_offset - unaligned_bit_count;
    LLVMValueRef shift_amt_val = LLVMConstInt(LLVMTypeOf(containing_int), shift_amt, false);

    LLVMValueRef mask_val = LLVMConstAllOnes(child_type->type_ref);
    mask_val = LLVMConstZExt(mask_val, LLVMTypeOf(containing_int));
    mask_val = LLVMConstShl(mask_val, shift_amt_val);
    mask_val = LLVMConstNot(mask_val);

    LLVMValueRef anded_containing_int = LLVMBuildAnd(g->builder, containing_int, mask_val, "");
    LLVMValueRef extended_value = LLVMBuildZExt(g->builder, value, LLVMTypeOf(containing_int), "");
    LLVMValueRef shifted_value = LLVMBuildShl(g->builder, extended_value, shift_amt_val, "");
    LLVMValueRef ored_value = LLVMBuildOr(g->builder, shifted_value, anded_containing_int, "");

    LLVMValueRef llvm_instruction = LLVMBuildStore(g->builder, ored_value, ptr);
    LLVMSetVolatile(llvm_instruction, ptr_type->data.pointer.is_volatile);
    return nullptr;
}

static LLVMValueRef ir_render_var_ptr(CodeGen *g, IrExecutable *executable, IrInstructionVarPtr *instruction) {
    VariableTableEntry *var = instruction->var;
    if (type_has_bits(var->value->type)) {
        assert(var->value_ref);
        return var->value_ref;
    } else {
        return nullptr;
    }
}

static LLVMValueRef ir_render_elem_ptr(CodeGen *g, IrExecutable *executable, IrInstructionElemPtr *instruction) {
    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->array_ptr);
    TypeTableEntry *array_ptr_type = instruction->array_ptr->value.type;
    assert(array_ptr_type->id == TypeTableEntryIdPointer);
    bool is_volatile = array_ptr_type->data.pointer.is_volatile;
    TypeTableEntry *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, is_volatile);
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
        if (array_ptr_type->data.pointer.unaligned_bit_count != 0) {
            return array_ptr_ptr;
        }
        TypeTableEntry *canon_child_type = get_underlying_type(array_type->data.array.child_type);
        if (canon_child_type->id == TypeTableEntryIdStruct &&
            canon_child_type->data.structure.layout == ContainerLayoutPacked)
        {
            size_t unaligned_bit_count = instruction->base.value.type->data.pointer.unaligned_bit_count;
            if (unaligned_bit_count != 0) {
                LLVMTypeRef ptr_u8_type_ref = LLVMPointerType(LLVMInt8Type(), 0);
                LLVMValueRef u8_array_ptr = LLVMBuildBitCast(g->builder, array_ptr, ptr_u8_type_ref, "");
                assert(unaligned_bit_count % 8 == 0);
                LLVMValueRef elem_size_bytes = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        unaligned_bit_count / 8, false);
                LLVMValueRef byte_offset = LLVMBuildNUWMul(g->builder, subscript_value, elem_size_bytes, "");
                LLVMValueRef indices[] = {
                    byte_offset
                };
                LLVMValueRef elem_byte_ptr = LLVMBuildInBoundsGEP(g->builder, u8_array_ptr, indices, 1, "");
                return LLVMBuildBitCast(g->builder, elem_byte_ptr, LLVMPointerType(canon_child_type->type_ref, 0), "");
            }
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
    LLVMValueRef fn_val;
    TypeTableEntry *fn_type;
    if (instruction->fn_entry) {
        fn_val = fn_llvm_value(g, instruction->fn_entry);
        fn_type = instruction->fn_entry->type_entry;
    } else {
        assert(instruction->fn_ref);
        fn_val = ir_llvm_value(g, instruction->fn_ref);
        fn_type = instruction->fn_ref->value.type;
    }

    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;
    TypeTableEntry *src_return_type = fn_type_id->return_type;
    bool ret_has_bits = type_has_bits(src_return_type);
    bool first_arg_ret = ret_has_bits && handle_is_ptr(src_return_type);
    size_t actual_param_count = instruction->arg_count + (first_arg_ret ? 1 : 0);
    bool is_var_args = fn_type_id->is_var_args;
    LLVMValueRef *gen_param_values = allocate<LLVMValueRef>(actual_param_count);
    size_t gen_param_index = 0;
    if (first_arg_ret) {
        gen_param_values[gen_param_index] = instruction->tmp_ptr;
        gen_param_index += 1;
    }
    for (size_t call_i = 0; call_i < instruction->arg_count; call_i += 1) {
        IrInstruction *param_instruction = instruction->args[call_i];
        TypeTableEntry *param_type = param_instruction->value.type;
        if (is_var_args || type_has_bits(param_type)) {
            LLVMValueRef param_value = ir_llvm_value(g, param_instruction);
            assert(param_value);
            gen_param_values[gen_param_index] = param_value;
            gen_param_index += 1;
        }
    }

    LLVMValueRef result = ZigLLVMBuildCall(g->builder, fn_val,
            gen_param_values, gen_param_index, fn_type->data.fn.calling_convention, "");

    for (size_t param_i = 0; param_i < fn_type_id->param_count; param_i += 1) {
        FnGenParamInfo *gen_info = &fn_type->data.fn.gen_param_info[param_i];
        if (gen_info->is_byval) {
            addLLVMCallsiteAttr(result, gen_info->gen_index, "byval");
        }
    }

    if (src_return_type->id == TypeTableEntryIdUnreachable) {
        return LLVMBuildUnreachable(g->builder);
    } else if (!ret_has_bits) {
        return nullptr;
    } else if (first_arg_ret) {
        return instruction->tmp_ptr;
    } else {
        return result;
    }
}

static LLVMValueRef ir_render_struct_field_ptr(CodeGen *g, IrExecutable *executable,
    IrInstructionStructFieldPtr *instruction)
{
    LLVMValueRef struct_ptr = ir_llvm_value(g, instruction->struct_ptr);
    // not necessarily a pointer. could be TypeTableEntryIdStruct
    TypeTableEntry *struct_ptr_type = instruction->struct_ptr->value.type;
    TypeStructField *field = instruction->field;

    if (!type_has_bits(field->type_entry))
        return nullptr;

    if (struct_ptr_type->id == TypeTableEntryIdPointer &&
        struct_ptr_type->data.pointer.unaligned_bit_count != 0)
    {
        return struct_ptr;
    }

    assert(field->gen_index != SIZE_MAX);
    return LLVMBuildStructGEP(g->builder, struct_ptr, field->gen_index, "");
}

static LLVMValueRef ir_render_enum_field_ptr(CodeGen *g, IrExecutable *executable,
    IrInstructionEnumFieldPtr *instruction)
{
    TypeEnumField *field = instruction->field;

    if (!type_has_bits(field->type_entry))
        return nullptr;

    LLVMValueRef enum_ptr = ir_llvm_value(g, instruction->enum_ptr);
    LLVMTypeRef field_type_ref = LLVMPointerType(field->type_entry->type_ref, 0);
    LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, enum_ptr, enum_gen_union_index, "");
    LLVMValueRef bitcasted_union_field_ptr = LLVMBuildBitCast(g->builder, union_field_ptr, field_type_ref, "");

    return bitcasted_union_field_ptr;
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
                {
                    size_t index = find_asm_index(g, asm_node, asm_token);
                    assert(index < SIZE_MAX);
                    buf_appendf(&llvm_template, "$%zu", index);
                    break;
                }
            case AsmTokenIdUniqueId:
                buf_append_str(&llvm_template, "${:uid}");
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
            VariableTableEntry *variable = instruction->output_vars[i];
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

        param_types[param_index] = ir_input->value.type->type_ref;
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
        ret_type = instruction->base.value.type->type_ref;
    }
    LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, input_and_output_count, false);

    bool is_x86 = (g->zig_target.arch.arch == ZigLLVM_x86 || g->zig_target.arch.arch == ZigLLVM_x86_64);
    bool is_volatile = asm_expr->is_volatile || (asm_expr->output_list.length == 0);
    LLVMValueRef asm_fn = ZigLLVMConstInlineAsm(function_type, buf_ptr(&llvm_template),
            buf_ptr(&constraint_buf), is_volatile, false, is_x86);

    return LLVMBuildCall(g->builder, asm_fn, param_values, input_and_output_count, "");
}

static LLVMValueRef gen_non_null_bit(CodeGen *g, TypeTableEntry *maybe_type, LLVMValueRef maybe_handle) {
    assert(maybe_type->id == TypeTableEntryIdMaybe);
    TypeTableEntry *child_type = maybe_type->data.maybe.child_type;
    if (child_type->zero_bits) {
        return maybe_handle;
    } else {
        bool maybe_is_ptr = (child_type->id == TypeTableEntryIdPointer || child_type->id == TypeTableEntryIdFn);
        if (maybe_is_ptr) {
            return LLVMBuildICmp(g->builder, LLVMIntNE, maybe_handle, LLVMConstNull(maybe_type->type_ref), "");
        } else {
            LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, maybe_handle, maybe_null_index, "");
            return LLVMBuildLoad(g->builder, maybe_field_ptr, "");
        }
    }
}

static LLVMValueRef ir_render_test_non_null(CodeGen *g, IrExecutable *executable,
    IrInstructionTestNonNull *instruction)
{
    return gen_non_null_bit(g, instruction->value->value.type, ir_llvm_value(g, instruction->value));
}

static LLVMValueRef ir_render_unwrap_maybe(CodeGen *g, IrExecutable *executable,
        IrInstructionUnwrapMaybe *instruction)
{
    TypeTableEntry *ptr_type = instruction->value->value.type;
    assert(ptr_type->id == TypeTableEntryIdPointer);
    bool is_volatile = ptr_type->data.pointer.is_volatile;
    TypeTableEntry *maybe_type = ptr_type->data.pointer.child_type;
    assert(maybe_type->id == TypeTableEntryIdMaybe);
    TypeTableEntry *child_type = maybe_type->data.maybe.child_type;
    LLVMValueRef maybe_ptr = ir_llvm_value(g, instruction->value);
    LLVMValueRef maybe_handle = get_handle_value(g, maybe_ptr, maybe_type, is_volatile);
    if (ir_want_debug_safety(g, &instruction->base) && instruction->safety_check_on) {
        LLVMValueRef non_null_bit = gen_non_null_bit(g, maybe_type, maybe_handle);
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapMaybeOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapMaybeFail");
        LLVMBuildCondBr(g->builder, non_null_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_debug_safety_crash(g, PanicMsgIdUnwrapMaybeFail);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }
    if (child_type->zero_bits) {
        return nullptr;
    } else {
        bool maybe_is_ptr = (child_type->id == TypeTableEntryIdPointer || child_type->id == TypeTableEntryIdFn);
        if (maybe_is_ptr) {
            return maybe_ptr;
        } else {
            LLVMValueRef maybe_struct_ref = get_handle_value(g, maybe_ptr, maybe_type, is_volatile);
            return LLVMBuildStructGEP(g->builder, maybe_struct_ref, maybe_child_index, "");
        }
    }
}

static LLVMValueRef get_int_builtin_fn(CodeGen *g, TypeTableEntry *int_type, BuiltinFnId fn_id) {
    ZigLLVMFnKey key = {};
    const char *fn_name;
    if (fn_id == BuiltinFnIdCtz) {
        fn_name = "cttz";
        key.id = ZigLLVMFnIdCtz;
        key.data.ctz.bit_count = int_type->data.integral.bit_count;
    } else {
        fn_name = "ctlz";
        key.id = ZigLLVMFnIdClz;
        key.data.clz.bit_count = int_type->data.integral.bit_count;
    }

    auto existing_entry = g->llvm_fn_table.maybe_get(key);
    if (existing_entry)
        return existing_entry->value;

    char llvm_name[64];
    sprintf(llvm_name, "llvm.%s.i%zu", fn_name, int_type->data.integral.bit_count);
    LLVMTypeRef param_types[] = {
        int_type->type_ref,
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(int_type->type_ref, param_types, 2, false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, llvm_name, fn_type);

    g->llvm_fn_table.put(key, fn_val);

    return fn_val;
}

static LLVMValueRef ir_render_clz(CodeGen *g, IrExecutable *executable, IrInstructionClz *instruction) {
    TypeTableEntry *int_type = instruction->base.value.type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdClz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->value);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    return LLVMBuildCall(g->builder, fn_val, params, 2, "");
}

static LLVMValueRef ir_render_ctz(CodeGen *g, IrExecutable *executable, IrInstructionCtz *instruction) {
    TypeTableEntry *int_type = instruction->base.value.type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdCtz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->value);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    return LLVMBuildCall(g->builder, fn_val, params, 2, "");
}

static LLVMValueRef ir_render_switch_br(CodeGen *g, IrExecutable *executable, IrInstructionSwitchBr *instruction) {
    LLVMValueRef target_value = ir_llvm_value(g, instruction->target_value);
    LLVMBasicBlockRef else_block = instruction->else_block->llvm_block;
    LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, target_value, else_block, instruction->case_count);
    for (size_t i = 0; i < instruction->case_count; i += 1) {
        IrInstructionSwitchBrCase *this_case = &instruction->cases[i];
        LLVMAddCase(switch_instr, ir_llvm_value(g, this_case->value), this_case->block->llvm_block);
    }
    return nullptr;
}

static LLVMValueRef ir_render_phi(CodeGen *g, IrExecutable *executable, IrInstructionPhi *instruction) {
    if (!type_has_bits(instruction->base.value.type))
        return nullptr;

    LLVMTypeRef phi_type;
    if (handle_is_ptr(instruction->base.value.type)) {
        phi_type = LLVMPointerType(instruction->base.value.type->type_ref, 0);
    } else {
        phi_type = instruction->base.value.type->type_ref;
    }

    LLVMValueRef phi = LLVMBuildPhi(g->builder, phi_type, "");
    LLVMValueRef *incoming_values = allocate<LLVMValueRef>(instruction->incoming_count);
    LLVMBasicBlockRef *incoming_blocks = allocate<LLVMBasicBlockRef>(instruction->incoming_count);
    for (size_t i = 0; i < instruction->incoming_count; i += 1) {
        incoming_values[i] = ir_llvm_value(g, instruction->incoming_values[i]);
        incoming_blocks[i] = instruction->incoming_blocks[i]->llvm_exit_block;
    }
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, instruction->incoming_count);
    return phi;
}

static LLVMValueRef ir_render_ref(CodeGen *g, IrExecutable *executable, IrInstructionRef *instruction) {
    LLVMValueRef value = ir_llvm_value(g, instruction->value);
    if (handle_is_ptr(instruction->value->value.type)) {
        return value;
    } else {
        assert(instruction->tmp_ptr);
        LLVMBuildStore(g->builder, value, instruction->tmp_ptr);
        return instruction->tmp_ptr;
    }
}

static LLVMValueRef ir_render_err_name(CodeGen *g, IrExecutable *executable, IrInstructionErrName *instruction) {
    assert(g->generate_error_name_table);

    if (g->error_decls.length == 1) {
        LLVMBuildUnreachable(g->builder);
        return nullptr;
    }

    LLVMValueRef err_val = ir_llvm_value(g, instruction->value);
    if (ir_want_debug_safety(g, &instruction->base)) {
        LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(err_val));
        LLVMValueRef end_val = LLVMConstInt(LLVMTypeOf(err_val), g->error_decls.length, false);
        add_bounds_check(g, err_val, LLVMIntNE, zero, LLVMIntULT, end_val);
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

static LLVMValueRef ir_render_cmpxchg(CodeGen *g, IrExecutable *executable, IrInstructionCmpxchg *instruction) {
    LLVMValueRef ptr_val = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef cmp_val = ir_llvm_value(g, instruction->cmp_value);
    LLVMValueRef new_val = ir_llvm_value(g, instruction->new_value);

    LLVMAtomicOrdering success_order = to_LLVMAtomicOrdering(instruction->success_order);
    LLVMAtomicOrdering failure_order = to_LLVMAtomicOrdering(instruction->failure_order);

    LLVMValueRef result_val = ZigLLVMBuildCmpXchg(g->builder, ptr_val, cmp_val, new_val,
            success_order, failure_order);

    return LLVMBuildExtractValue(g->builder, result_val, 1, "");
}

static LLVMValueRef ir_render_fence(CodeGen *g, IrExecutable *executable, IrInstructionFence *instruction) {
    LLVMAtomicOrdering atomic_order = to_LLVMAtomicOrdering(instruction->order);
    LLVMBuildFence(g->builder, atomic_order, false, "");
    return nullptr;
}

static LLVMValueRef ir_render_div_exact(CodeGen *g, IrExecutable *executable, IrInstructionDivExact *instruction) {
    LLVMValueRef op1_val = ir_llvm_value(g, instruction->op1);
    LLVMValueRef op2_val = ir_llvm_value(g, instruction->op2);

    bool want_debug_safety = ir_want_debug_safety(g, &instruction->base);
    return gen_div(g, want_debug_safety, op1_val, op2_val, instruction->base.value.type, true);
}

static LLVMValueRef ir_render_truncate(CodeGen *g, IrExecutable *executable, IrInstructionTruncate *instruction) {
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    TypeTableEntry *dest_type = get_underlying_type(instruction->base.value.type);
    TypeTableEntry *src_type = get_underlying_type(instruction->target->value.type);
    if (dest_type == src_type) {
        // no-op
        return target_val;
    } if (src_type->data.integral.bit_count == dest_type->data.integral.bit_count) {
        return LLVMBuildBitCast(g->builder, target_val, dest_type->type_ref, "");
    } else {
        LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
        return LLVMBuildTrunc(g->builder, target_val, dest_type->type_ref, "");
    }
}

static LLVMValueRef ir_render_alloca(CodeGen *g, IrExecutable *executable, IrInstructionAlloca *instruction) {
    TypeTableEntry *slice_type = get_underlying_type(instruction->base.value.type);
    TypeTableEntry *ptr_type = slice_type->data.structure.fields[slice_ptr_index].type_entry;
    TypeTableEntry *child_type = ptr_type->data.pointer.child_type;
    LLVMValueRef size_val = ir_llvm_value(g, instruction->count);
    LLVMValueRef ptr_val = LLVMBuildArrayAlloca(g->builder, child_type->type_ref, size_val, "");

    // TODO in debug mode, initialize all the bytes to 0xaa

    // store the freshly allocated pointer in the slice
    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, slice_ptr_index, "");
    LLVMBuildStore(g->builder, ptr_val, ptr_field_ptr);

    // store the size in the len field
    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, slice_len_index, "");
    LLVMBuildStore(g->builder, size_val, len_field_ptr);

    return instruction->tmp_ptr;
}

static LLVMValueRef ir_render_memset(CodeGen *g, IrExecutable *executable, IrInstructionMemset *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef char_val = ir_llvm_value(g, instruction->byte);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");

    TypeTableEntry *ptr_type = get_underlying_type(instruction->dest_ptr->value.type);
    assert(ptr_type->id == TypeTableEntryIdPointer);

    LLVMValueRef is_volatile = ptr_type->data.pointer.is_volatile ?
        LLVMConstAllOnes(LLVMInt1Type()) : LLVMConstNull(LLVMInt1Type());

    LLVMValueRef params[] = {
        dest_ptr_casted, // dest pointer
        char_val, // source pointer
        len_val, // byte count
        LLVMConstInt(LLVMInt32Type(), 1, false), // align in bytes
        is_volatile,
    };

    LLVMBuildCall(g->builder, g->memset_fn_val, params, 5, "");
    return nullptr;
}

static LLVMValueRef ir_render_memcpy(CodeGen *g, IrExecutable *executable, IrInstructionMemcpy *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef src_ptr = ir_llvm_value(g, instruction->src_ptr);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");
    LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr, ptr_u8, "");

    TypeTableEntry *dest_ptr_type = get_underlying_type(instruction->dest_ptr->value.type);
    TypeTableEntry *src_ptr_type = get_underlying_type(instruction->src_ptr->value.type);

    assert(dest_ptr_type->id == TypeTableEntryIdPointer);
    assert(src_ptr_type->id == TypeTableEntryIdPointer);

    LLVMValueRef is_volatile = (dest_ptr_type->data.pointer.is_volatile || src_ptr_type->data.pointer.is_volatile) ?
        LLVMConstAllOnes(LLVMInt1Type()) : LLVMConstNull(LLVMInt1Type());

    LLVMValueRef params[] = {
        dest_ptr_casted, // dest pointer
        src_ptr_casted, // source pointer
        len_val, // byte count
        LLVMConstInt(LLVMInt32Type(), 1, false), // align in bytes
        is_volatile,
    };

    LLVMBuildCall(g->builder, g->memcpy_fn_val, params, 5, "");
    return nullptr;
}

static LLVMValueRef ir_render_slice(CodeGen *g, IrExecutable *executable, IrInstructionSlice *instruction) {
    assert(instruction->tmp_ptr);

    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->ptr);
    TypeTableEntry *array_ptr_type = instruction->ptr->value.type;
    assert(array_ptr_type->id == TypeTableEntryIdPointer);
    bool is_volatile = array_ptr_type->data.pointer.is_volatile;
    TypeTableEntry *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, is_volatile);

    LLVMValueRef tmp_struct_ptr = instruction->tmp_ptr;

    bool want_debug_safety = instruction->safety_check_on && ir_want_debug_safety(g, &instruction->base);

    if (array_type->id == TypeTableEntryIdArray) {
        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val;
        if (instruction->end) {
            end_val = ir_llvm_value(g, instruction->end);
        } else {
            end_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref, array_type->data.array.len, false);
        }

        if (want_debug_safety) {
            add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
            if (instruction->end) {
                LLVMValueRef array_end = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        array_type->data.array.len, false);
                add_bounds_check(g, end_val, LLVMIntEQ, nullptr, LLVMIntULE, array_end);
            }
        }

        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_ptr_index, "");
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->type_ref),
            start_val,
        };
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
        LLVMBuildStore(g->builder, slice_start_ptr, ptr_field_ptr);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        LLVMBuildStore(g->builder, len_value, len_field_ptr);

        return tmp_struct_ptr;
    } else if (array_type->id == TypeTableEntryIdPointer) {
        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val = ir_llvm_value(g, instruction->end);

        if (want_debug_safety) {
            add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
        }

        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_ptr_index, "");
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, &start_val, 1, "");
        LLVMBuildStore(g->builder, slice_start_ptr, ptr_field_ptr);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        LLVMBuildStore(g->builder, len_value, len_field_ptr);

        return tmp_struct_ptr;
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        size_t ptr_index = array_type->data.structure.fields[0].gen_index;
        assert(ptr_index != SIZE_MAX);
        size_t len_index = array_type->data.structure.fields[1].gen_index;
        assert(len_index != SIZE_MAX);

        LLVMValueRef prev_end = nullptr;
        if (!instruction->end || want_debug_safety) {
            LLVMValueRef src_len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, len_index, "");
            prev_end = LLVMBuildLoad(g->builder, src_len_ptr, "");
        }

        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val;
        if (instruction->end) {
            end_val = ir_llvm_value(g, instruction->end);
        } else {
            end_val = prev_end;
        }

        if (want_debug_safety) {
            assert(prev_end);
            add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
            if (instruction->end) {
                add_bounds_check(g, end_val, LLVMIntEQ, nullptr, LLVMIntULE, prev_end);
            }
        }

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

static LLVMValueRef ir_render_breakpoint(CodeGen *g, IrExecutable *executable, IrInstructionBreakpoint *instruction) {
    LLVMBuildCall(g->builder, g->trap_fn_val, nullptr, 0, "");
    return nullptr;
}

static LLVMValueRef ir_render_return_address(CodeGen *g, IrExecutable *executable,
        IrInstructionReturnAddress *instruction)
{
    LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->type_ref);
    return LLVMBuildCall(g->builder, g->return_address_fn_val, &zero, 1, "");
}

static LLVMValueRef ir_render_frame_address(CodeGen *g, IrExecutable *executable,
        IrInstructionFrameAddress *instruction)
{
    LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->type_ref);
    return LLVMBuildCall(g->builder, g->frame_address_fn_val, &zero, 1, "");
}

static LLVMValueRef render_shl_with_overflow(CodeGen *g, IrInstructionOverflowOp *instruction) {
    TypeTableEntry *int_type = get_underlying_type(instruction->result_ptr_type);
    assert(int_type->id == TypeTableEntryIdInt);

    LLVMValueRef op1 = ir_llvm_value(g, instruction->op1);
    LLVMValueRef op2 = ir_llvm_value(g, instruction->op2);
    LLVMValueRef ptr_result = ir_llvm_value(g, instruction->result_ptr);

    LLVMValueRef result = LLVMBuildShl(g->builder, op1, op2, "");
    LLVMValueRef orig_val;
    if (int_type->data.integral.is_signed) {
        orig_val = LLVMBuildAShr(g->builder, result, op2, "");
    } else {
        orig_val = LLVMBuildLShr(g->builder, result, op2, "");
    }
    LLVMValueRef overflow_bit = LLVMBuildICmp(g->builder, LLVMIntNE, op1, orig_val, "");

    LLVMBuildStore(g->builder, result, ptr_result);

    return overflow_bit;
}

static LLVMValueRef ir_render_overflow_op(CodeGen *g, IrExecutable *executable, IrInstructionOverflowOp *instruction) {
    AddSubMul add_sub_mul;
    switch (instruction->op) {
        case IrOverflowOpAdd:
            add_sub_mul = AddSubMulAdd;
            break;
        case IrOverflowOpSub:
            add_sub_mul = AddSubMulSub;
            break;
        case IrOverflowOpMul:
            add_sub_mul = AddSubMulMul;
            break;
        case IrOverflowOpShl:
            return render_shl_with_overflow(g, instruction);
    }

    TypeTableEntry *int_type = get_underlying_type(instruction->result_ptr_type);
    assert(int_type->id == TypeTableEntryIdInt);

    LLVMValueRef fn_val = get_int_overflow_fn(g, int_type, add_sub_mul);

    LLVMValueRef op1 = ir_llvm_value(g, instruction->op1);
    LLVMValueRef op2 = ir_llvm_value(g, instruction->op2);
    LLVMValueRef ptr_result = ir_llvm_value(g, instruction->result_ptr);

    LLVMValueRef params[] = {
        op1,
        op2,
    };

    LLVMValueRef result_struct = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    LLVMValueRef result = LLVMBuildExtractValue(g->builder, result_struct, 0, "");
    LLVMValueRef overflow_bit = LLVMBuildExtractValue(g->builder, result_struct, 1, "");
    LLVMBuildStore(g->builder, result, ptr_result);

    return overflow_bit;
}

static LLVMValueRef ir_render_test_err(CodeGen *g, IrExecutable *executable, IrInstructionTestErr *instruction) {
    TypeTableEntry *err_union_type = get_underlying_type(instruction->value->value.type);
    TypeTableEntry *child_type = get_underlying_type(err_union_type->data.error.child_type);
    LLVMValueRef err_union_handle = ir_llvm_value(g, instruction->value);

    LLVMValueRef err_val;
    if (type_has_bits(child_type)) {
        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
        err_val = LLVMBuildLoad(g->builder, err_val_ptr, "");
    } else {
        err_val = err_union_handle;
    }

    LLVMValueRef zero = LLVMConstNull(g->err_tag_type->type_ref);
    return LLVMBuildICmp(g->builder, LLVMIntNE, err_val, zero, "");
}

static LLVMValueRef ir_render_unwrap_err_code(CodeGen *g, IrExecutable *executable, IrInstructionUnwrapErrCode *instruction) {
    TypeTableEntry *ptr_type = get_underlying_type(instruction->value->value.type);
    assert(ptr_type->id == TypeTableEntryIdPointer);
    bool is_volatile = ptr_type->data.pointer.is_volatile;
    TypeTableEntry *err_union_type = get_underlying_type(ptr_type->data.pointer.child_type);
    TypeTableEntry *child_type = get_underlying_type(err_union_type->data.error.child_type);
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->value);
    LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, is_volatile);

    if (type_has_bits(child_type)) {
        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
        return LLVMBuildLoad(g->builder, err_val_ptr, "");
    } else {
        return err_union_handle;
    }
}

static LLVMValueRef ir_render_unwrap_err_payload(CodeGen *g, IrExecutable *executable, IrInstructionUnwrapErrPayload *instruction) {
    TypeTableEntry *ptr_type = get_underlying_type(instruction->value->value.type);
    assert(ptr_type->id == TypeTableEntryIdPointer);
    bool is_volatile = ptr_type->data.pointer.is_volatile;
    TypeTableEntry *err_union_type = get_underlying_type(ptr_type->data.pointer.child_type);
    TypeTableEntry *child_type = get_underlying_type(err_union_type->data.error.child_type);
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->value);
    LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, is_volatile);

    if (ir_want_debug_safety(g, &instruction->base) && instruction->safety_check_on) {
        LLVMValueRef err_val;
        if (type_has_bits(child_type)) {
            LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
            err_val = LLVMBuildLoad(g->builder, err_val_ptr, "");
        } else {
            err_val = err_union_handle;
        }
        LLVMValueRef zero = LLVMConstNull(g->err_tag_type->type_ref);
        LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, zero, "");
        LLVMBasicBlockRef err_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrError");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrOk");
        LLVMBuildCondBr(g->builder, cond_val, ok_block, err_block);

        LLVMPositionBuilderAtEnd(g->builder, err_block);
        gen_debug_safety_crash(g, PanicMsgIdUnwrapErrFail);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    if (type_has_bits(child_type)) {
        return LLVMBuildStructGEP(g->builder, err_union_handle, err_union_payload_index, "");
    } else {
        return nullptr;
    }
}

static LLVMValueRef ir_render_maybe_wrap(CodeGen *g, IrExecutable *executable, IrInstructionMaybeWrap *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;

    assert(wanted_type->id == TypeTableEntryIdMaybe);

    TypeTableEntry *child_type = wanted_type->data.maybe.child_type;

    if (child_type->zero_bits) {
        return LLVMConstInt(LLVMInt1Type(), 1, false);
    }

    LLVMValueRef payload_val = ir_llvm_value(g, instruction->value);
    if (child_type->id == TypeTableEntryIdPointer ||
        child_type->id == TypeTableEntryIdFn)
    {
        return payload_val;
    }

    assert(instruction->tmp_ptr);

    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, maybe_child_index, "");
    assert(child_type == instruction->value->value.type);
    gen_assign_raw(g, val_ptr, payload_val, child_type);
    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, maybe_null_index, "");
    LLVMBuildStore(g->builder, LLVMConstAllOnes(LLVMInt1Type()), maybe_ptr);

    return instruction->tmp_ptr;
}

static LLVMValueRef ir_render_err_wrap_code(CodeGen *g, IrExecutable *executable, IrInstructionErrWrapCode *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;

    assert(wanted_type->id == TypeTableEntryIdErrorUnion);

    TypeTableEntry *child_type = wanted_type->data.error.child_type;
    LLVMValueRef err_val = ir_llvm_value(g, instruction->value);

    if (!type_has_bits(child_type))
        return err_val;

    assert(instruction->tmp_ptr);

    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, err_union_err_index, "");
    LLVMBuildStore(g->builder, err_val, err_tag_ptr);

    return instruction->tmp_ptr;
}

static LLVMValueRef ir_render_err_wrap_payload(CodeGen *g, IrExecutable *executable, IrInstructionErrWrapPayload *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;

    assert(wanted_type->id == TypeTableEntryIdErrorUnion);

    TypeTableEntry *child_type = wanted_type->data.error.child_type;

    LLVMValueRef ok_err_val = LLVMConstNull(g->err_tag_type->type_ref);

    if (!type_has_bits(child_type))
        return ok_err_val;

    assert(instruction->tmp_ptr);

    LLVMValueRef payload_val = ir_llvm_value(g, instruction->value);

    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, err_union_err_index, "");
    LLVMBuildStore(g->builder, ok_err_val, err_tag_ptr);

    LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, err_union_payload_index, "");
    gen_assign_raw(g, payload_ptr, payload_val, child_type);

    return instruction->tmp_ptr;
}

static LLVMValueRef ir_render_enum_tag(CodeGen *g, IrExecutable *executable, IrInstructionEnumTag *instruction) {
    TypeTableEntry *enum_type = instruction->value->value.type;
    TypeTableEntry *tag_type = enum_type->data.enumeration.tag_type;
    if (!type_has_bits(tag_type))
        return nullptr;

    LLVMValueRef enum_val = ir_llvm_value(g, instruction->value);
    if (enum_type->data.enumeration.gen_field_count == 0)
        return enum_val;

    LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, enum_val, enum_gen_tag_index, "");
    return get_handle_value(g, tag_field_ptr, tag_type, false);
}

static LLVMValueRef ir_render_init_enum(CodeGen *g, IrExecutable *executable, IrInstructionInitEnum *instruction) {
    TypeTableEntry *enum_type = instruction->enum_type;
    uint32_t value = instruction->field->value;
    LLVMTypeRef tag_type_ref = enum_type->data.enumeration.tag_type->type_ref;
    LLVMValueRef tag_value = LLVMConstInt(tag_type_ref, value, false);

    if (enum_type->data.enumeration.gen_field_count == 0)
        return tag_value;

    LLVMValueRef tmp_struct_ptr = instruction->tmp_ptr;

    LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, enum_gen_tag_index, "");
    LLVMBuildStore(g->builder, tag_value, tag_field_ptr);

    TypeTableEntry *union_val_type = instruction->field->type_entry;
    if (type_has_bits(union_val_type)) {
        LLVMValueRef new_union_val = ir_llvm_value(g, instruction->init_value);
        LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, enum_gen_union_index, "");
        LLVMValueRef bitcasted_union_field_ptr = LLVMBuildBitCast(g->builder, union_field_ptr,
                LLVMPointerType(union_val_type->type_ref, 0), "");

        gen_assign_raw(g, bitcasted_union_field_ptr, new_union_val, union_val_type);
    }

    return tmp_struct_ptr;
}

static LLVMValueRef ir_render_struct_init(CodeGen *g, IrExecutable *executable, IrInstructionStructInit *instruction) {
    for (size_t i = 0; i < instruction->field_count; i += 1) {
        IrInstructionStructInitField *field = &instruction->fields[i];
        TypeStructField *type_struct_field = field->type_struct_field;
        if (!type_has_bits(type_struct_field->type_entry))
            continue;

        LLVMValueRef field_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, type_struct_field->gen_index, "");
        LLVMValueRef value = ir_llvm_value(g, field->value);
        gen_assign_raw(g, field_ptr, value, type_struct_field->type_entry);
    }
    return instruction->tmp_ptr;
}

static LLVMValueRef ir_render_container_init_list(CodeGen *g, IrExecutable *executable,
        IrInstructionContainerInitList *instruction)
{
    TypeTableEntry *array_type = instruction->base.value.type;
    assert(array_type->id == TypeTableEntryIdArray);
    LLVMValueRef tmp_array_ptr = instruction->tmp_ptr;
    assert(tmp_array_ptr);

    size_t field_count = instruction->item_count;

    TypeTableEntry *child_type = array_type->data.array.child_type;
    for (size_t i = 0; i < field_count; i += 1) {
        LLVMValueRef elem_val = ir_llvm_value(g, instruction->items[i]);
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->type_ref),
            LLVMConstInt(g->builtin_types.entry_usize->type_ref, i, false),
        };
        LLVMValueRef elem_ptr = LLVMBuildInBoundsGEP(g->builder, tmp_array_ptr, indices, 2, "");
        gen_assign_raw(g, elem_ptr, elem_val, child_type);
    }

    return tmp_array_ptr;
}

static LLVMValueRef ir_render_panic(CodeGen *g, IrExecutable *executable, IrInstructionPanic *instruction) {
    gen_panic(g, ir_llvm_value(g, instruction->msg));
    return nullptr;
}

static void set_debug_location(CodeGen *g, IrInstruction *instruction) {
    AstNode *source_node = instruction->source_node;
    Scope *scope = instruction->scope;

    assert(source_node);
    assert(scope);

    ZigLLVMSetCurrentDebugLocation(g->builder, source_node->line + 1, source_node->column + 1, get_di_scope(g, scope));
}

static LLVMValueRef ir_render_instruction(CodeGen *g, IrExecutable *executable, IrInstruction *instruction) {
    set_debug_location(g, instruction);

    switch (instruction->id) {
        case IrInstructionIdInvalid:
        case IrInstructionIdConst:
        case IrInstructionIdTypeOf:
        case IrInstructionIdToPtrType:
        case IrInstructionIdPtrTypeChild:
        case IrInstructionIdFieldPtr:
        case IrInstructionIdSetDebugSafety:
        case IrInstructionIdArrayType:
        case IrInstructionIdSliceType:
        case IrInstructionIdCompileVar:
        case IrInstructionIdSizeOf:
        case IrInstructionIdSwitchTarget:
        case IrInstructionIdContainerInitFields:
        case IrInstructionIdMinValue:
        case IrInstructionIdMaxValue:
        case IrInstructionIdCompileErr:
        case IrInstructionIdCompileLog:
        case IrInstructionIdArrayLen:
        case IrInstructionIdImport:
        case IrInstructionIdCImport:
        case IrInstructionIdCInclude:
        case IrInstructionIdCDefine:
        case IrInstructionIdCUndef:
        case IrInstructionIdEmbedFile:
        case IrInstructionIdIntType:
        case IrInstructionIdMemberCount:
        case IrInstructionIdAlignOf:
        case IrInstructionIdFnProto:
        case IrInstructionIdTestComptime:
        case IrInstructionIdGeneratedCode:
        case IrInstructionIdCheckSwitchProngs:
        case IrInstructionIdTestType:
        case IrInstructionIdTypeName:
        case IrInstructionIdCanImplicitCast:
        case IrInstructionIdSetGlobalAlign:
        case IrInstructionIdSetGlobalSection:
        case IrInstructionIdSetGlobalLinkage:
        case IrInstructionIdDeclRef:
        case IrInstructionIdSwitchVar:
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
        case IrInstructionIdEnumFieldPtr:
            return ir_render_enum_field_ptr(g, executable, (IrInstructionEnumFieldPtr *)instruction);
        case IrInstructionIdAsm:
            return ir_render_asm(g, executable, (IrInstructionAsm *)instruction);
        case IrInstructionIdTestNonNull:
            return ir_render_test_non_null(g, executable, (IrInstructionTestNonNull *)instruction);
        case IrInstructionIdUnwrapMaybe:
            return ir_render_unwrap_maybe(g, executable, (IrInstructionUnwrapMaybe *)instruction);
        case IrInstructionIdClz:
            return ir_render_clz(g, executable, (IrInstructionClz *)instruction);
        case IrInstructionIdCtz:
            return ir_render_ctz(g, executable, (IrInstructionCtz *)instruction);
        case IrInstructionIdSwitchBr:
            return ir_render_switch_br(g, executable, (IrInstructionSwitchBr *)instruction);
        case IrInstructionIdPhi:
            return ir_render_phi(g, executable, (IrInstructionPhi *)instruction);
        case IrInstructionIdRef:
            return ir_render_ref(g, executable, (IrInstructionRef *)instruction);
        case IrInstructionIdErrName:
            return ir_render_err_name(g, executable, (IrInstructionErrName *)instruction);
        case IrInstructionIdCmpxchg:
            return ir_render_cmpxchg(g, executable, (IrInstructionCmpxchg *)instruction);
        case IrInstructionIdFence:
            return ir_render_fence(g, executable, (IrInstructionFence *)instruction);
        case IrInstructionIdDivExact:
            return ir_render_div_exact(g, executable, (IrInstructionDivExact *)instruction);
        case IrInstructionIdTruncate:
            return ir_render_truncate(g, executable, (IrInstructionTruncate *)instruction);
        case IrInstructionIdBoolNot:
            return ir_render_bool_not(g, executable, (IrInstructionBoolNot *)instruction);
        case IrInstructionIdAlloca:
            return ir_render_alloca(g, executable, (IrInstructionAlloca *)instruction);
        case IrInstructionIdMemset:
            return ir_render_memset(g, executable, (IrInstructionMemset *)instruction);
        case IrInstructionIdMemcpy:
            return ir_render_memcpy(g, executable, (IrInstructionMemcpy *)instruction);
        case IrInstructionIdSlice:
            return ir_render_slice(g, executable, (IrInstructionSlice *)instruction);
        case IrInstructionIdBreakpoint:
            return ir_render_breakpoint(g, executable, (IrInstructionBreakpoint *)instruction);
        case IrInstructionIdReturnAddress:
            return ir_render_return_address(g, executable, (IrInstructionReturnAddress *)instruction);
        case IrInstructionIdFrameAddress:
            return ir_render_frame_address(g, executable, (IrInstructionFrameAddress *)instruction);
        case IrInstructionIdOverflowOp:
            return ir_render_overflow_op(g, executable, (IrInstructionOverflowOp *)instruction);
        case IrInstructionIdTestErr:
            return ir_render_test_err(g, executable, (IrInstructionTestErr *)instruction);
        case IrInstructionIdUnwrapErrCode:
            return ir_render_unwrap_err_code(g, executable, (IrInstructionUnwrapErrCode *)instruction);
        case IrInstructionIdUnwrapErrPayload:
            return ir_render_unwrap_err_payload(g, executable, (IrInstructionUnwrapErrPayload *)instruction);
        case IrInstructionIdMaybeWrap:
            return ir_render_maybe_wrap(g, executable, (IrInstructionMaybeWrap *)instruction);
        case IrInstructionIdErrWrapCode:
            return ir_render_err_wrap_code(g, executable, (IrInstructionErrWrapCode *)instruction);
        case IrInstructionIdErrWrapPayload:
            return ir_render_err_wrap_payload(g, executable, (IrInstructionErrWrapPayload *)instruction);
        case IrInstructionIdEnumTag:
            return ir_render_enum_tag(g, executable, (IrInstructionEnumTag *)instruction);
        case IrInstructionIdInitEnum:
            return ir_render_init_enum(g, executable, (IrInstructionInitEnum *)instruction);
        case IrInstructionIdStructInit:
            return ir_render_struct_init(g, executable, (IrInstructionStructInit *)instruction);
        case IrInstructionIdPointerReinterpret:
            return ir_render_pointer_reinterpret(g, executable, (IrInstructionPointerReinterpret *)instruction);
        case IrInstructionIdWidenOrShorten:
            return ir_render_widen_or_shorten(g, executable, (IrInstructionWidenOrShorten *)instruction);
        case IrInstructionIdPtrToInt:
            return ir_render_ptr_to_int(g, executable, (IrInstructionPtrToInt *)instruction);
        case IrInstructionIdIntToPtr:
            return ir_render_int_to_ptr(g, executable, (IrInstructionIntToPtr *)instruction);
        case IrInstructionIdIntToEnum:
            return ir_render_int_to_enum(g, executable, (IrInstructionIntToEnum *)instruction);
        case IrInstructionIdContainerInitList:
            return ir_render_container_init_list(g, executable, (IrInstructionContainerInitList *)instruction);
        case IrInstructionIdPanic:
            return ir_render_panic(g, executable, (IrInstructionPanic *)instruction);
    }
    zig_unreachable();
}

static void ir_render(CodeGen *g, FnTableEntry *fn_entry) {
    assert(fn_entry);
    IrExecutable *executable = &fn_entry->analyzed_executable;
    assert(executable->basic_block_list.length > 0);
    for (size_t block_i = 0; block_i < executable->basic_block_list.length; block_i += 1) {
        IrBasicBlock *current_block = executable->basic_block_list.at(block_i);
        //assert(current_block->ref_count > 0);
        assert(current_block->llvm_block);
        LLVMPositionBuilderAtEnd(g->builder, current_block->llvm_block);
        for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
            IrInstruction *instruction = current_block->instruction_list.at(instr_i);
            if (instruction->ref_count == 0 && !ir_has_side_effects(instruction))
                continue;
            instruction->llvm_value = ir_render_instruction(g, executable, instruction);
        }
        current_block->llvm_exit_block = LLVMGetInsertBlock(g->builder);
    }
}

static LLVMValueRef gen_const_ptr_struct_recursive(CodeGen *g, ConstExprValue *struct_const_val, size_t field_index);
static LLVMValueRef gen_const_ptr_array_recursive(CodeGen *g, ConstExprValue *array_const_val, size_t index);

static LLVMValueRef gen_parent_ptr(CodeGen *g, ConstExprValue *val, ConstParent *parent) {
    switch (parent->id) {
        case ConstParentIdNone:
            render_const_val(g, val);
            render_const_val_global(g, val, "");
            return val->llvm_global;
        case ConstParentIdStruct:
            return gen_const_ptr_struct_recursive(g, parent->data.p_struct.struct_val,
                    parent->data.p_struct.field_index);
        case ConstParentIdArray:
            return gen_const_ptr_array_recursive(g, parent->data.p_array.array_val,
                    parent->data.p_array.elem_index);
    }
    zig_unreachable();
}

static LLVMValueRef gen_const_ptr_array_recursive(CodeGen *g, ConstExprValue *array_const_val, size_t index) {
    ConstParent *parent = &array_const_val->data.x_array.parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, array_const_val, parent);

    TypeTableEntry *usize = g->builtin_types.entry_usize;
    LLVMValueRef indices[] = {
        LLVMConstNull(usize->type_ref),
        LLVMConstInt(usize->type_ref, index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_struct_recursive(CodeGen *g, ConstExprValue *struct_const_val, size_t field_index) {
    ConstParent *parent = &struct_const_val->data.x_struct.parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, struct_const_val, parent);

    TypeTableEntry *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(u32->type_ref),
        LLVMConstInt(u32->type_ref, field_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef pack_const_int(CodeGen *g, LLVMTypeRef big_int_type_ref, ConstExprValue *const_val) { 
    switch (const_val->special) {
        case ConstValSpecialRuntime:
            zig_unreachable();
        case ConstValSpecialUndef:
            return LLVMConstInt(big_int_type_ref, 0, false);
        case ConstValSpecialStatic:
            break;
    }

    TypeTableEntry *canon_type = get_underlying_type(const_val->type);
    assert(!canon_type->zero_bits);
    switch (canon_type->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdEnumTag:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdVoid:
            zig_unreachable();
        case TypeTableEntryIdBool:
            return LLVMConstInt(big_int_type_ref, const_val->data.x_bool ? 1 : 0, false);
        case TypeTableEntryIdInt:
            {
                LLVMValueRef int_val = gen_const_val(g, const_val);
                return LLVMConstZExt(int_val, big_int_type_ref);
            }
            return LLVMConstInt(big_int_type_ref, bignum_to_twos_complement(&const_val->data.x_bignum), false);
        case TypeTableEntryIdFloat:
            {
                LLVMValueRef float_val = gen_const_val(g, const_val);
                LLVMValueRef int_val = LLVMConstFPToUI(float_val, LLVMIntType(canon_type->data.floating.bit_count));
                return LLVMConstZExt(int_val, big_int_type_ref);
            }
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdMaybe:
            {
                LLVMValueRef ptr_val = gen_const_val(g, const_val);
                LLVMValueRef ptr_size_int_val = LLVMConstPtrToInt(ptr_val, g->builtin_types.entry_usize->type_ref);
                return LLVMConstZExt(ptr_size_int_val, big_int_type_ref);
            }
        case TypeTableEntryIdArray:
            zig_panic("TODO bit pack an array");
        case TypeTableEntryIdUnion:
            zig_panic("TODO bit pack a union");
        case TypeTableEntryIdStruct:
            {
                assert(canon_type->data.structure.layout == ContainerLayoutPacked);

                LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
                for (size_t i = 0; i < canon_type->data.structure.src_field_count; i += 1) {
                    TypeStructField *field = &canon_type->data.structure.fields[i];
                    if (field->gen_index == SIZE_MAX) {
                        continue;
                    }
                    LLVMValueRef child_val = pack_const_int(g, big_int_type_ref, &const_val->data.x_struct.fields[i]);
                    LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref, field->packed_bits_size, false);
                    val = LLVMConstShl(val, shift_amt);
                    val = LLVMConstOr(val, child_val);
                }
                return val;
            }
    }
    zig_unreachable();
}

static LLVMValueRef gen_const_val(CodeGen *g, ConstExprValue *const_val) {
    TypeTableEntry *canon_type = get_underlying_type(const_val->type);
    assert(!canon_type->zero_bits);

    switch (const_val->special) {
        case ConstValSpecialRuntime:
            zig_unreachable();
        case ConstValSpecialUndef:
            return LLVMGetUndef(canon_type->type_ref);
        case ConstValSpecialStatic:
            break;
    }

    switch (canon_type->id) {
        case TypeTableEntryIdTypeDecl:
            zig_unreachable();
        case TypeTableEntryIdInt:
        case TypeTableEntryIdEnumTag:
            return LLVMConstInt(canon_type->type_ref, bignum_to_twos_complement(&const_val->data.x_bignum), false);
        case TypeTableEntryIdPureError:
            assert(const_val->data.x_pure_err);
            return LLVMConstInt(g->builtin_types.entry_pure_error->type_ref,
                    const_val->data.x_pure_err->value, false);
        case TypeTableEntryIdFloat:
            if (const_val->data.x_bignum.kind == BigNumKindFloat) {
                return LLVMConstReal(canon_type->type_ref, const_val->data.x_bignum.data.x_float);
            } else {
                int64_t x = const_val->data.x_bignum.data.x_uint;
                if (const_val->data.x_bignum.is_negative) {
                    x = -x;
                }
                return LLVMConstReal(canon_type->type_ref, x);
            }
        case TypeTableEntryIdBool:
            if (const_val->data.x_bool) {
                return LLVMConstAllOnes(LLVMInt1Type());
            } else {
                return LLVMConstNull(LLVMInt1Type());
            }
        case TypeTableEntryIdMaybe:
            {
                TypeTableEntry *child_type = canon_type->data.maybe.child_type;
                if (child_type->zero_bits) {
                    return LLVMConstInt(LLVMInt1Type(), const_val->data.x_maybe ? 1 : 0, false);
                } else if (child_type->id == TypeTableEntryIdPointer ||
                    child_type->id == TypeTableEntryIdFn)
                {
                    if (const_val->data.x_maybe) {
                        return gen_const_val(g, const_val->data.x_maybe);
                    } else {
                        return LLVMConstNull(child_type->type_ref);
                    }
                } else {
                    LLVMValueRef child_val;
                    LLVMValueRef maybe_val;
                    if (const_val->data.x_maybe) {
                        child_val = gen_const_val(g, const_val->data.x_maybe);
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
                LLVMValueRef *fields = allocate<LLVMValueRef>(canon_type->data.structure.gen_field_count);
                size_t src_field_count = canon_type->data.structure.src_field_count;
                if (canon_type->data.structure.layout == ContainerLayoutPacked) {
                    size_t src_field_index = 0;
                    while (src_field_index < src_field_count) {
                        TypeStructField *type_struct_field = &canon_type->data.structure.fields[src_field_index];
                        if (type_struct_field->gen_index == SIZE_MAX) {
                            src_field_index += 1;
                            continue;
                        }

                        size_t src_field_index_end = src_field_index + 1;
                        for (; src_field_index_end < src_field_count; src_field_index_end += 1) {
                            TypeStructField *it_field = &canon_type->data.structure.fields[src_field_index_end];
                            if (it_field->gen_index != type_struct_field->gen_index)
                                break;
                        }

                        if (src_field_index + 1 == src_field_index_end) {
                            fields[type_struct_field->gen_index] =
                                gen_const_val(g, &const_val->data.x_struct.fields[src_field_index]);
                        } else {
                            LLVMTypeRef big_int_type_ref = LLVMStructGetTypeAtIndex(canon_type->type_ref,
                                    type_struct_field->gen_index);
                            LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
                            for (size_t i = src_field_index; i < src_field_index_end; i += 1) {
                                TypeStructField *it_field = &canon_type->data.structure.fields[i];
                                if (it_field->gen_index == SIZE_MAX) {
                                    continue;
                                }
                                LLVMValueRef child_val = pack_const_int(g, big_int_type_ref,
                                        &const_val->data.x_struct.fields[i]);
                                LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref,
                                        it_field->packed_bits_size, false);
                                val = LLVMConstShl(val, shift_amt);
                                val = LLVMConstOr(val, child_val);
                            }
                            fields[type_struct_field->gen_index] = val;
                        }

                        src_field_index = src_field_index_end;
                    }
                } else {
                    for (uint32_t i = 0; i < src_field_count; i += 1) {
                        TypeStructField *type_struct_field = &canon_type->data.structure.fields[i];
                        if (type_struct_field->gen_index == SIZE_MAX) {
                            continue;
                        }
                        fields[type_struct_field->gen_index] = gen_const_val(g, &const_val->data.x_struct.fields[i]);
                    }
                }
                return LLVMConstNamedStruct(canon_type->type_ref, fields, canon_type->data.structure.gen_field_count);
            }
        case TypeTableEntryIdUnion:
            {
                zig_panic("TODO");
            }
        case TypeTableEntryIdArray:
            {
                uint64_t len = canon_type->data.array.len;
                LLVMValueRef *values = allocate<LLVMValueRef>(len);
                for (uint64_t i = 0; i < len; i += 1) {
                    ConstExprValue *elem_value = &const_val->data.x_array.elements[i];
                    values[i] = gen_const_val(g, elem_value);
                }
                return LLVMConstArray(LLVMTypeOf(values[0]), values, len);
            }
        case TypeTableEntryIdEnum:
            {
                LLVMTypeRef tag_type_ref = canon_type->data.enumeration.tag_type->type_ref;
                LLVMValueRef tag_value = LLVMConstInt(tag_type_ref, const_val->data.x_enum.tag, false);
                if (canon_type->data.enumeration.gen_field_count == 0) {
                    return tag_value;
                } else {
                    TypeTableEntry *union_type = canon_type->data.enumeration.union_type;
                    TypeEnumField *enum_field = &canon_type->data.enumeration.fields[const_val->data.x_enum.tag];
                    assert(enum_field->value == const_val->data.x_enum.tag);
                    LLVMValueRef union_value;
                    if (type_has_bits(enum_field->type_entry)) {
                        uint64_t union_type_bytes = LLVMStoreSizeOfType(g->target_data_ref,
                                union_type->type_ref);
                        uint64_t field_type_bytes = LLVMStoreSizeOfType(g->target_data_ref,
                                enum_field->type_entry->type_ref);
                        uint64_t pad_bytes = union_type_bytes - field_type_bytes;

                        LLVMValueRef correctly_typed_value = gen_const_val(g, const_val->data.x_enum.payload);
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
                    return LLVMConstStruct(fields, 2, false);
                }
            }
        case TypeTableEntryIdFn:
            return fn_llvm_value(g, const_val->data.x_fn);
        case TypeTableEntryIdPointer:
            {
                render_const_val_global(g, const_val, "");
                switch (const_val->data.x_ptr.special) {
                    case ConstPtrSpecialInvalid:
                    case ConstPtrSpecialDiscard:
                        zig_unreachable();
                    case ConstPtrSpecialRef:
                        {
                            ConstExprValue *pointee = const_val->data.x_ptr.data.ref.pointee;
                            render_const_val(g, pointee);
                            render_const_val_global(g, pointee, "");
                            ConstExprValue *other_val = pointee;
                            const_val->llvm_value = LLVMConstBitCast(other_val->llvm_global, const_val->type->type_ref);
                            render_const_val_global(g, const_val, "");
                            return const_val->llvm_value;
                        }
                    case ConstPtrSpecialBaseArray:
                        {
                            ConstExprValue *array_const_val = const_val->data.x_ptr.data.base_array.array_val;
                            size_t elem_index = const_val->data.x_ptr.data.base_array.elem_index;
                            assert(array_const_val->type->id == TypeTableEntryIdArray);
                            if (array_const_val->type->zero_bits) {
                                // make this a null pointer
                                TypeTableEntry *usize = g->builtin_types.entry_usize;
                                const_val->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->type_ref),
                                        const_val->type->type_ref);
                                render_const_val_global(g, const_val, "");
                                return const_val->llvm_value;
                            }
                            LLVMValueRef uncasted_ptr_val = gen_const_ptr_array_recursive(g, array_const_val,
                                    elem_index);
                            LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, const_val->type->type_ref);
                            const_val->llvm_value = ptr_val;
                            render_const_val_global(g, const_val, "");
                            return ptr_val;
                        }
                    case ConstPtrSpecialBaseStruct:
                        {
                            ConstExprValue *struct_const_val = const_val->data.x_ptr.data.base_struct.struct_val;
                            assert(struct_const_val->type->id == TypeTableEntryIdStruct);
                            if (struct_const_val->type->zero_bits) {
                                // make this a null pointer
                                TypeTableEntry *usize = g->builtin_types.entry_usize;
                                const_val->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->type_ref),
                                        const_val->type->type_ref);
                                render_const_val_global(g, const_val, "");
                                return const_val->llvm_value;
                            }
                            size_t src_field_index = const_val->data.x_ptr.data.base_struct.field_index;
                            size_t gen_field_index =
                                struct_const_val->type->data.structure.fields[src_field_index].gen_index;
                            LLVMValueRef uncasted_ptr_val = gen_const_ptr_struct_recursive(g, struct_const_val,
                                    gen_field_index);
                            LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, const_val->type->type_ref);
                            const_val->llvm_value = ptr_val;
                            render_const_val_global(g, const_val, "");
                            return ptr_val;
                        }
                    case ConstPtrSpecialHardCodedAddr:
                        {
                            uint64_t addr_value = const_val->data.x_ptr.data.hard_coded_addr.addr;
                            TypeTableEntry *usize = g->builtin_types.entry_usize;
                            const_val->llvm_value = LLVMConstIntToPtr(LLVMConstInt(usize->type_ref, addr_value, false),
                                    const_val->type->type_ref);
                            render_const_val_global(g, const_val, "");
                            return const_val->llvm_value;
                        }
                }
            }
        case TypeTableEntryIdErrorUnion:
            {
                TypeTableEntry *child_type = canon_type->data.error.child_type;
                if (!type_has_bits(child_type)) {
                    uint64_t value = const_val->data.x_err_union.err ? const_val->data.x_err_union.err->value : 0;
                    return LLVMConstInt(g->err_tag_type->type_ref, value, false);
                } else {
                    LLVMValueRef err_tag_value;
                    LLVMValueRef err_payload_value;
                    if (const_val->data.x_err_union.err) {
                        err_tag_value = LLVMConstInt(g->err_tag_type->type_ref, const_val->data.x_err_union.err->value, false);
                        err_payload_value = LLVMConstNull(child_type->type_ref);
                    } else {
                        err_tag_value = LLVMConstNull(g->err_tag_type->type_ref);
                        err_payload_value = gen_const_val(g, const_val->data.x_err_union.payload);
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
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdArgTuple:
            zig_unreachable();

    }
    zig_unreachable();
}

static void render_const_val(CodeGen *g, ConstExprValue *const_val) {
    if (!const_val->llvm_value)
        const_val->llvm_value = gen_const_val(g, const_val);

    if (const_val->llvm_global)
        LLVMSetInitializer(const_val->llvm_global, const_val->llvm_value);
}

static void render_const_val_global(CodeGen *g, ConstExprValue *const_val, const char *name) {
    if (!const_val->llvm_global) {
        LLVMTypeRef type_ref = const_val->llvm_value ? LLVMTypeOf(const_val->llvm_value) : const_val->type->type_ref;
        LLVMValueRef global_value = LLVMAddGlobal(g->module, type_ref, name);
        LLVMSetLinkage(global_value, LLVMInternalLinkage);
        LLVMSetGlobalConstant(global_value, true);
        LLVMSetUnnamedAddr(global_value, true);
        LLVMSetAlignment(global_value, get_type_alignment(g, const_val->type));

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
        fn_llvm_value(g, fn_entry),
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
        bb->llvm_block = LLVMAppendBasicBlock(fn_llvm_value(g, fn), bb->name_hint);
    }
    IrBasicBlock *entry_bb = executable->basic_block_list.at(0);
    LLVMPositionBuilderAtEnd(g->builder, entry_bb->llvm_block);
}

static void gen_global_var(CodeGen *g, VariableTableEntry *var, LLVMValueRef init_val,
    TypeTableEntry *type_entry)
{
    assert(var->gen_is_const);
    assert(type_entry);

    ImportTableEntry *import = get_scope_import(var->parent_scope);
    assert(import);

    bool is_local_to_unit = true;
    ZigLLVMCreateGlobalVariable(g->dbuilder, get_di_scope(g, var->parent_scope), buf_ptr(&var->name),
        buf_ptr(&var->name), import->di_file, var->decl_node->line + 1,
        type_entry->di_type, is_local_to_unit);
    // TODO ^^ make an actual global variable
}

static LLVMValueRef build_alloca(CodeGen *g, TypeTableEntry *type_entry, const char *name) {
    LLVMValueRef result = LLVMBuildAlloca(g->builder, type_entry->type_ref, name);
    LLVMSetAlignment(result, get_type_alignment(g, type_entry));
    return result;
}

static void do_code_gen(CodeGen *g) {
    assert(!g->errors.length);

    delete_unused_builtin_fns(g);
    generate_error_name_table(g);

    // Generate module level variables
    for (size_t i = 0; i < g->global_vars.length; i += 1) {
        TldVar *tld_var = g->global_vars.at(i);
        VariableTableEntry *var = tld_var->var;

        if (var->value->type->id == TypeTableEntryIdNumLitFloat) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = var->value;
            assert(const_val->special != ConstValSpecialRuntime);
            TypeTableEntry *var_type = g->builtin_types.entry_f64;
            LLVMValueRef init_val = LLVMConstReal(var_type->type_ref, const_val->data.x_bignum.data.x_float);
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (var->value->type->id == TypeTableEntryIdNumLitInt) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = var->value;
            assert(const_val->special != ConstValSpecialRuntime);
            TypeTableEntry *var_type = const_val->data.x_bignum.is_negative ?
                g->builtin_types.entry_isize : g->builtin_types.entry_usize;
            LLVMValueRef init_val = LLVMConstInt(var_type->type_ref,
                bignum_to_twos_complement(&const_val->data.x_bignum), false);
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (!type_has_bits(var->value->type))
            continue;

        assert(var->decl_node);

        LLVMValueRef global_value;
        if (var->linkage == VarLinkageExternal) {
            global_value = LLVMAddGlobal(g->module, var->value->type->type_ref, buf_ptr(&var->name));

            // TODO debug info for the extern variable

            LLVMSetLinkage(global_value, LLVMExternalLinkage);
        } else {
            render_const_val(g, var->value);
            render_const_val_global(g, var->value, buf_ptr(get_mangled_name(g, &var->name, false)));
            global_value = var->value->llvm_global;

            if (var->linkage == VarLinkageExport) {
                LLVMSetLinkage(global_value, LLVMExternalLinkage);
            }
            if (tld_var->section_name) {
                LLVMSetSection(global_value, buf_ptr(tld_var->section_name));
            }
            LLVMSetAlignment(global_value, tld_var->alignment ?
                    tld_var->alignment : get_type_alignment(g, var->value->type));

            // TODO debug info for function pointers
            if (var->gen_is_const && var->value->type->id != TypeTableEntryIdFn) {
                gen_global_var(g, var, var->value->llvm_value, var->value->type);
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
        if (should_skip_fn_codegen(g, fn_table_entry))
            continue;

        TypeTableEntry *fn_type = fn_table_entry->type_entry;
        FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;

        LLVMValueRef fn_val = fn_llvm_value(g, fn_table_entry);

        if (!type_has_bits(fn_type->data.fn.fn_type_id.return_type)) {
            // nothing to do
        } else if (fn_type->data.fn.fn_type_id.return_type->id == TypeTableEntryIdPointer ||
                   fn_type->data.fn.fn_type_id.return_type->id == TypeTableEntryIdFn)
        {
            addLLVMAttr(fn_val, 0, "nonnull");
        } else if (handle_is_ptr(fn_type->data.fn.fn_type_id.return_type) &&
                !fn_type->data.fn.fn_type_id.is_extern)
        {
            addLLVMArgAttr(fn_val, 0, "sret");
            addLLVMArgAttr(fn_val, 0, "nonnull");
        }


        // set parameter attributes
        for (size_t param_i = 0; param_i < fn_type_id->param_count; param_i += 1) {
            FnGenParamInfo *gen_info = &fn_type->data.fn.gen_param_info[param_i];
            size_t gen_index = gen_info->gen_index;
            bool is_byval = gen_info->is_byval;

            if (gen_index == SIZE_MAX) {
                continue;
            }

            FnTypeParamInfo *param_info = &fn_type_id->param_info[param_i];

            TypeTableEntry *param_type = gen_info->type;
            if (param_info->is_noalias) {
                addLLVMArgAttr(fn_val, gen_index, "noalias");
            }
            if ((param_type->id == TypeTableEntryIdPointer && param_type->data.pointer.is_const) || is_byval) {
                addLLVMArgAttr(fn_val, gen_index, "readonly");
            }
            if (param_type->id == TypeTableEntryIdPointer) {
                addLLVMArgAttr(fn_val, gen_index, "nonnull");
            }
            if (is_byval) {
                addLLVMArgAttr(fn_val, gen_index, "byval");
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
        if (should_skip_fn_codegen(g, fn_table_entry))
            continue;

        LLVMValueRef fn = fn_llvm_value(g, fn_table_entry);
        g->cur_fn = fn_table_entry;
        g->cur_fn_val = fn;
        if (handle_is_ptr(fn_table_entry->type_entry->data.fn.fn_type_id.return_type)) {
            g->cur_ret_ptr = LLVMGetParam(fn, 0);
        } else {
            g->cur_ret_ptr = nullptr;
        }

        build_all_basic_blocks(g, fn_table_entry);
        clear_debug_source_node(g);

        // allocate temporary stack data
        for (size_t alloca_i = 0; alloca_i < fn_table_entry->alloca_list.length; alloca_i += 1) {
            IrInstruction *instruction = fn_table_entry->alloca_list.at(alloca_i);
            LLVMValueRef *slot;
            TypeTableEntry *slot_type = instruction->value.type;
            if (instruction->id == IrInstructionIdCast) {
                IrInstructionCast *cast_instruction = (IrInstructionCast *)instruction;
                slot = &cast_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdRef) {
                IrInstructionRef *ref_instruction = (IrInstructionRef *)instruction;
                slot = &ref_instruction->tmp_ptr;
                assert(instruction->value.type->id == TypeTableEntryIdPointer);
                slot_type = instruction->value.type->data.pointer.child_type;
            } else if (instruction->id == IrInstructionIdContainerInitList) {
                IrInstructionContainerInitList *container_init_list_instruction = (IrInstructionContainerInitList *)instruction;
                slot = &container_init_list_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdStructInit) {
                IrInstructionStructInit *struct_init_instruction = (IrInstructionStructInit *)instruction;
                slot = &struct_init_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdCall) {
                IrInstructionCall *call_instruction = (IrInstructionCall *)instruction;
                slot = &call_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdAlloca) {
                IrInstructionAlloca *alloca_instruction = (IrInstructionAlloca *)instruction;
                slot = &alloca_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdSlice) {
                IrInstructionSlice *slice_instruction = (IrInstructionSlice *)instruction;
                slot = &slice_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdMaybeWrap) {
                IrInstructionMaybeWrap *maybe_wrap_instruction = (IrInstructionMaybeWrap *)instruction;
                slot = &maybe_wrap_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdErrWrapPayload) {
                IrInstructionErrWrapPayload *err_wrap_payload_instruction = (IrInstructionErrWrapPayload *)instruction;
                slot = &err_wrap_payload_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdErrWrapCode) {
                IrInstructionErrWrapCode *err_wrap_code_instruction = (IrInstructionErrWrapCode *)instruction;
                slot = &err_wrap_code_instruction->tmp_ptr;
            } else if (instruction->id == IrInstructionIdInitEnum) {
                IrInstructionInitEnum *init_enum_instruction = (IrInstructionInitEnum *)instruction;
                slot = &init_enum_instruction->tmp_ptr;
            } else {
                zig_unreachable();
            }
            *slot = build_alloca(g, slot_type, "");
        }

        ImportTableEntry *import = get_scope_import(&fn_table_entry->fndef_scope->base);

        // create debug variable declarations for variables and allocate all local variables
        for (size_t var_i = 0; var_i < fn_table_entry->variable_list.length; var_i += 1) {
            VariableTableEntry *var = fn_table_entry->variable_list.at(var_i);

            if (!type_has_bits(var->value->type)) {
                continue;
            }
            if (ir_get_var_is_comptime(var))
                continue;
            if (type_requires_comptime(var->value->type))
                continue;

            if (var->src_arg_index == SIZE_MAX) {
                var->value_ref = build_alloca(g, var->value->type, buf_ptr(&var->name));

                var->di_loc_var = ZigLLVMCreateAutoVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                        buf_ptr(&var->name), import->di_file, var->decl_node->line + 1,
                        var->value->type->di_type, !g->strip_debug_symbols, 0);

            } else {
                assert(var->gen_arg_index != SIZE_MAX);
                TypeTableEntry *gen_type;
                if (handle_is_ptr(var->value->type)) {
                    gen_type = fn_table_entry->type_entry->data.fn.gen_param_info[var->src_arg_index].type;
                    var->value_ref = LLVMGetParam(fn, var->gen_arg_index);
                } else {
                    gen_type = var->value->type;
                    var->value_ref = build_alloca(g, var->value->type, buf_ptr(&var->name));
                }
                if (var->decl_node) {
                    var->di_loc_var = ZigLLVMCreateParameterVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                            buf_ptr(&var->name), import->di_file, var->decl_node->line + 1,
                            gen_type->di_type, !g->strip_debug_symbols, 0, var->gen_arg_index + 1);
                }

            }
        }

        FnTypeId *fn_type_id = &fn_table_entry->type_entry->data.fn.fn_type_id;

        // create debug variable declarations for parameters
        // rely on the first variables in the variable_list being parameters.
        size_t next_var_i = 0;
        for (size_t param_i = 0; param_i < fn_type_id->param_count; param_i += 1) {
            FnGenParamInfo *info = &fn_table_entry->type_entry->data.fn.gen_param_info[param_i];
            if (info->gen_index == SIZE_MAX)
                continue;

            VariableTableEntry *variable = fn_table_entry->variable_list.at(next_var_i);
            assert(variable->src_arg_index != SIZE_MAX);
            next_var_i += 1;

            assert(variable);
            assert(variable->value_ref);

            if (!handle_is_ptr(variable->value->type)) {
                clear_debug_source_node(g);
                LLVMBuildStore(g->builder, LLVMGetParam(fn, variable->gen_arg_index), variable->value_ref);
            }

            if (variable->decl_node) {
                gen_var_debug_decl(g, variable);
            }
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

struct GlobalLinkageValue {
    GlobalLinkageId id;
    const char *name;
};

static const GlobalLinkageValue global_linkage_values[] = {
    {GlobalLinkageIdInternal, "Internal"},
    {GlobalLinkageIdStrong, "Strong"},
    {GlobalLinkageIdWeak, "Weak"},
    {GlobalLinkageIdLinkOnce, "LinkOnce"},
};

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
        g->builtin_types.entry_namespace = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdBlock);
        buf_init_from_str(&entry->name, "(block)");
        entry->zero_bits = true;
        g->builtin_types.entry_block = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNumLitFloat);
        buf_init_from_str(&entry->name, "(float literal)");
        entry->zero_bits = true;
        g->builtin_types.entry_num_lit_float = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNumLitInt);
        buf_init_from_str(&entry->name, "(integer literal)");
        entry->zero_bits = true;
        g->builtin_types.entry_num_lit_int = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdUndefLit);
        buf_init_from_str(&entry->name, "(undefined)");
        g->builtin_types.entry_undef = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNullLit);
        buf_init_from_str(&entry->name, "(null)");
        g->builtin_types.entry_null = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdVar);
        buf_init_from_str(&entry->name, "(var)");
        g->builtin_types.entry_var = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdArgTuple);
        buf_init_from_str(&entry->name, "(args)");
        entry->zero_bits = true;
        g->builtin_types.entry_arg_tuple = entry;
    }

    for (size_t int_size_i = 0; int_size_i < array_length(int_sizes_in_bits); int_size_i += 1) {
        size_t size_in_bits = int_sizes_in_bits[int_size_i];
        for (size_t is_sign_i = 0; is_sign_i < array_length(is_signed_list); is_sign_i += 1) {
            bool is_signed = is_signed_list[is_sign_i];
            TypeTableEntry *entry = make_int_type(g, is_signed, size_in_bits);
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

        buf_init_from_str(&entry->name, info->name);

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                is_signed ? ZigLLVMEncoding_DW_ATE_signed() : ZigLLVMEncoding_DW_ATE_unsigned());
        entry->data.integral.is_signed = is_signed;
        entry->data.integral.bit_count = size_in_bits;
        g->primitive_type_table.put(&entry->name, entry);

        get_c_int_type_ptr(g, info->id)[0] = entry;
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdBool);
        entry->type_ref = LLVMInt1Type();
        buf_init_from_str(&entry->name, "bool");
        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                ZigLLVMEncoding_DW_ATE_boolean());
        g->builtin_types.entry_bool = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    for (size_t sign_i = 0; sign_i < array_length(is_signed_list); sign_i += 1) {
        bool is_signed = is_signed_list[sign_i];

        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMIntType(g->pointer_size_bytes * 8);

        const char u_or_i = is_signed ? 'i' : 'u';
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "%csize", u_or_i);

        entry->data.integral.is_signed = is_signed;
        entry->data.integral.bit_count = g->pointer_size_bytes * 8;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
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
        entry->type_ref = LLVMFloatType();
        buf_init_from_str(&entry->name, "f32");
        entry->data.floating.bit_count = 32;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
        g->builtin_types.entry_f32 = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->type_ref = LLVMDoubleType();
        buf_init_from_str(&entry->name, "f64");
        entry->data.floating.bit_count = 64;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
        g->builtin_types.entry_f64 = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->type_ref = LLVMX86FP80Type();
        buf_init_from_str(&entry->name, "c_long_double");
        entry->data.floating.bit_count = 80;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
        g->builtin_types.entry_c_long_double = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdVoid);
        entry->type_ref = LLVMVoidType();
        entry->zero_bits = true;
        buf_init_from_str(&entry->name, "void");
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                0,
                ZigLLVMEncoding_DW_ATE_unsigned());
        g->builtin_types.entry_void = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdUnreachable);
        entry->type_ref = LLVMVoidType();
        entry->zero_bits = true;
        buf_init_from_str(&entry->name, "noreturn");
        entry->di_type = g->builtin_types.entry_void->di_type;
        g->builtin_types.entry_unreachable = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdMetaType);
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
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "Os");
        uint32_t field_count = target_os_count();
        entry->data.enumeration.src_field_count = field_count;
        entry->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        for (uint32_t i = 0; i < field_count; i += 1) {
            TypeEnumField *type_enum_field = &entry->data.enumeration.fields[i];
            ZigLLVM_OSType os_type = get_target_os(i);
            type_enum_field->name = buf_create_from_str(get_target_os_name(os_type));
            type_enum_field->value = i;
            type_enum_field->type_entry = g->builtin_types.entry_void;

            if (os_type == g->zig_target.os) {
                g->target_os_index = i;
            }
        }
        entry->data.enumeration.complete = true;
        entry->data.enumeration.zero_bits_known = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_os_enum = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "Arch");
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
            type_enum_field->type_entry = g->builtin_types.entry_void;

            if (arch_type->arch == g->zig_target.arch.arch &&
                arch_type->sub_arch == g->zig_target.arch.sub_arch)
            {
                g->target_arch_index = i;
            }
        }
        entry->data.enumeration.complete = true;
        entry->data.enumeration.zero_bits_known = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_arch_enum = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "Environ");
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
        entry->data.enumeration.zero_bits_known = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_environ_enum = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "ObjectFormat");
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
        entry->data.enumeration.zero_bits_known = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_oformat_enum = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->zero_bits = true; // only allowed at compile time
        buf_init_from_str(&entry->name, "GlobalLinkage");
        uint32_t field_count = array_length(global_linkage_values);
        entry->data.enumeration.src_field_count = field_count;
        entry->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        for (uint32_t i = 0; i < field_count; i += 1) {
            TypeEnumField *type_enum_field = &entry->data.enumeration.fields[i];
            const GlobalLinkageValue *value = &global_linkage_values[i];
            type_enum_field->name = buf_create_from_str(value->name);
            type_enum_field->value = i;
            type_enum_field->type_entry = g->builtin_types.entry_void;
        }
        entry->data.enumeration.complete = true;
        entry->data.enumeration.zero_bits_known = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_global_linkage_enum = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdEnum);
        entry->zero_bits = true; // only allowed at compile time
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
        entry->data.enumeration.zero_bits_known = true;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
        entry->data.enumeration.tag_type = tag_type_entry;

        g->builtin_types.entry_atomic_order_enum = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
}


static BuiltinFnEntry *create_builtin_fn(CodeGen *g, BuiltinFnId id, const char *name, size_t count) {
    BuiltinFnEntry *builtin_fn = allocate<BuiltinFnEntry>(1);
    buf_init_from_str(&builtin_fn->name, name);
    builtin_fn->id = id;
    builtin_fn->param_count = count;
    g->builtin_fn_table.put(&builtin_fn->name, builtin_fn);
    return builtin_fn;
}

static void define_builtin_fns(CodeGen *g) {
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn(g, BuiltinFnIdBreakpoint, "breakpoint", 0);
        builtin_fn->ref_count = 1;

        LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), nullptr, 0, false);
        builtin_fn->fn_val = LLVMAddFunction(g->module, "llvm.debugtrap", fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));

        g->trap_fn_val = builtin_fn->fn_val;
    }
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn(g, BuiltinFnIdReturnAddress,
                "returnAddress", 0);
        TypeTableEntry *return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

        LLVMTypeRef fn_type = LLVMFunctionType(return_type->type_ref,
                &g->builtin_types.entry_i32->type_ref, 1, false);
        builtin_fn->fn_val = LLVMAddFunction(g->module, "llvm.returnaddress", fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));

        g->return_address_fn_val = builtin_fn->fn_val;
    }
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn(g, BuiltinFnIdFrameAddress,
                "frameAddress", 0);
        TypeTableEntry *return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

        LLVMTypeRef fn_type = LLVMFunctionType(return_type->type_ref,
                &g->builtin_types.entry_i32->type_ref, 1, false);
        builtin_fn->fn_val = LLVMAddFunction(g->module, "llvm.frameaddress", fn_type);
        assert(LLVMGetIntrinsicID(builtin_fn->fn_val));

        g->frame_address_fn_val = builtin_fn->fn_val;
    }
    {
        BuiltinFnEntry *builtin_fn = create_builtin_fn(g, BuiltinFnIdMemcpy, "memcpy", 3);
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
        BuiltinFnEntry *builtin_fn = create_builtin_fn(g, BuiltinFnIdMemset, "memset", 3);
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
    create_builtin_fn(g, BuiltinFnIdSizeof, "sizeOf", 1);
    create_builtin_fn(g, BuiltinFnIdAlignof, "alignOf", 1);
    create_builtin_fn(g, BuiltinFnIdMaxValue, "maxValue", 1);
    create_builtin_fn(g, BuiltinFnIdMinValue, "minValue", 1);
    create_builtin_fn(g, BuiltinFnIdMemberCount, "memberCount", 1);
    create_builtin_fn(g, BuiltinFnIdTypeof, "typeOf", 1);
    create_builtin_fn(g, BuiltinFnIdAddWithOverflow, "addWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdSubWithOverflow, "subWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdMulWithOverflow, "mulWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdShlWithOverflow, "shlWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdCInclude, "cInclude", 1);
    create_builtin_fn(g, BuiltinFnIdCDefine, "cDefine", 2);
    create_builtin_fn(g, BuiltinFnIdCUndef, "cUndef", 1);
    create_builtin_fn(g, BuiltinFnIdCompileVar, "compileVar", 1);
    create_builtin_fn(g, BuiltinFnIdGeneratedCode, "generatedCode", 1);
    create_builtin_fn(g, BuiltinFnIdCtz, "ctz", 1);
    create_builtin_fn(g, BuiltinFnIdClz, "clz", 1);
    create_builtin_fn(g, BuiltinFnIdImport, "import", 1);
    create_builtin_fn(g, BuiltinFnIdCImport, "cImport", 1);
    create_builtin_fn(g, BuiltinFnIdErrName, "errorName", 1);
    create_builtin_fn(g, BuiltinFnIdTypeName, "typeName", 1);
    create_builtin_fn(g, BuiltinFnIdIsInteger, "isInteger", 1);
    create_builtin_fn(g, BuiltinFnIdIsFloat, "isFloat", 1);
    create_builtin_fn(g, BuiltinFnIdCanImplicitCast, "canImplicitCast", 2);
    create_builtin_fn(g, BuiltinFnIdEmbedFile, "embedFile", 1);
    create_builtin_fn(g, BuiltinFnIdCmpExchange, "cmpxchg", 5);
    create_builtin_fn(g, BuiltinFnIdFence, "fence", 1);
    create_builtin_fn(g, BuiltinFnIdDivExact, "divExact", 2);
    create_builtin_fn(g, BuiltinFnIdTruncate, "truncate", 2);
    create_builtin_fn(g, BuiltinFnIdCompileErr, "compileError", 1);
    create_builtin_fn(g, BuiltinFnIdCompileLog, "compileLog", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdIntType, "intType", 2);
    create_builtin_fn(g, BuiltinFnIdSetDebugSafety, "setDebugSafety", 2);
    create_builtin_fn(g, BuiltinFnIdAlloca, "alloca", 2);
    create_builtin_fn(g, BuiltinFnIdSetGlobalAlign, "setGlobalAlign", 2);
    create_builtin_fn(g, BuiltinFnIdSetGlobalSection, "setGlobalSection", 2);
    create_builtin_fn(g, BuiltinFnIdSetGlobalLinkage, "setGlobalLinkage", 2);
    create_builtin_fn(g, BuiltinFnIdPanic, "panic", 1);
}

static void add_compile_var(CodeGen *g, const char *name, ConstExprValue *value) {
    g->compile_vars.put_unique(buf_create_from_str(name), value);
}

static void define_builtin_compile_vars(CodeGen *g) {
    add_compile_var(g, "is_big_endian", create_const_bool(g, g->is_big_endian));
    add_compile_var(g, "is_release", create_const_bool(g, g->is_release_build));
    add_compile_var(g, "is_test", create_const_bool(g, g->is_test_build));
    add_compile_var(g, "os", create_const_enum_tag(g->builtin_types.entry_os_enum, g->target_os_index));
    add_compile_var(g, "arch", create_const_enum_tag(g->builtin_types.entry_arch_enum, g->target_arch_index));
    add_compile_var(g, "environ", create_const_enum_tag(g->builtin_types.entry_environ_enum, g->target_environ_index));
    add_compile_var(g, "object_format", create_const_enum_tag(
                g->builtin_types.entry_oformat_enum, g->target_oformat_index));

    {
        TypeTableEntry *str_type = get_slice_type(g, g->builtin_types.entry_u8, true);
        ConstExprValue *const_val = allocate<ConstExprValue>(1);
        const_val->special = ConstValSpecialStatic;
        const_val->type = get_array_type(g, str_type, g->link_libs.length);
        const_val->data.x_array.elements = allocate<ConstExprValue>(g->link_libs.length);
        for (size_t i = 0; i < g->link_libs.length; i += 1) {
            Buf *link_lib_buf = g->link_libs.at(i);
            ConstExprValue *array_val = create_const_str_lit(g, link_lib_buf);
            init_const_slice(g, &const_val->data.x_array.elements[i], array_val, 0, buf_len(link_lib_buf), true);
        }

        add_compile_var(g, "link_libs", const_val);
    }
    add_compile_var(g, "panic_implementation_provided", create_const_bool(g, false));
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
    ZigLLVMDIFile *compile_unit_file = ZigLLVMCreateFile(g->dbuilder, buf_ptr(source_path),
            buf_ptr(&g->root_package->root_src_dir));
    g->compile_unit = ZigLLVMCreateCompileUnit(g->dbuilder, ZigLLVMLang_DW_LANG_C99(),
            compile_unit_file, buf_ptr(producer), is_optimized, flags, runtime_version,
            "", 0, !g->strip_debug_symbols);

    // This is for debug stuff that doesn't have a real file.
    g->dummy_di_file = nullptr;

    define_builtin_types(g);
    define_builtin_fns(g);
    define_builtin_compile_vars(g);

    g->invalid_instruction = allocate<IrInstruction>(1);
    g->invalid_instruction->value.type = g->builtin_types.entry_invalid;

    g->const_void_val.special = ConstValSpecialStatic;
    g->const_void_val.type = g->builtin_types.entry_void;
}

void codegen_parseh(CodeGen *g, Buf *src_dirname, Buf *src_basename, Buf *source_code) {
    find_libc_include_path(g);
    Buf *full_path = buf_alloc();
    os_path_join(src_dirname, src_basename, full_path);

    ImportTableEntry *import = allocate<ImportTableEntry>(1);
    import->source_code = source_code;
    import->path = full_path;
    g->root_import = import;
    import->decls_scope = create_decls_scope(nullptr, nullptr, nullptr, import);

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

static ImportTableEntry *add_special_code(CodeGen *g, PackageTableEntry *package, const char *basename) {
    Buf *code_basename = buf_create_from_str(basename);
    Buf path_to_code_src = BUF_INIT;
    os_path_join(g->zig_std_special_dir, code_basename, &path_to_code_src);
    Buf *abs_full_path = buf_alloc();
    int err;
    if ((err = os_path_real(&path_to_code_src, abs_full_path))) {
        zig_panic("unable to open '%s': %s", buf_ptr(&path_to_code_src), err_str(err));
    }
    Buf *import_code = buf_alloc();
    if ((err = os_fetch_file_path(abs_full_path, import_code))) {
        zig_panic("unable to open '%s': %s", buf_ptr(&path_to_code_src), err_str(err));
    }

    return add_source_file(g, package, abs_full_path, g->zig_std_special_dir, code_basename, import_code);
}

static PackageTableEntry *create_bootstrap_pkg(CodeGen *g) {
    PackageTableEntry *package = new_package(buf_ptr(g->zig_std_special_dir), "");
    package->package_table.put(buf_create_from_str("std"), g->std_package);
    package->package_table.put(buf_create_from_str("@root"), g->root_package);
    return package;
}

static PackageTableEntry *create_zigrt_pkg(CodeGen *g) {
    PackageTableEntry *package = new_package(buf_ptr(g->zig_std_special_dir), "");
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

    if (!g->is_test_build && g->have_pub_main && (g->out_type == OutTypeObj || g->out_type == OutTypeExe)) {
        g->bootstrap_import = add_special_code(g, create_bootstrap_pkg(g), "bootstrap.zig");
    }
    if (!g->omit_zigrt) {
        g->zigrt_package = create_zigrt_pkg(g);
        add_special_code(g, g->zigrt_package, "zigrt.zig");
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
                if (child_type->zero_bits) {
                    buf_init_from_str(out_buf, "bool");
                    return;
                } else if (child_type->id == TypeTableEntryIdPointer ||
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
        case TypeTableEntryIdEnumTag:
            zig_panic("TODO implement get_c_type for more types");
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdArgTuple:
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

        if (fn_table_entry->linkage == GlobalLinkageIdInternal)
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
                AstNode *param_decl_node = get_param_decl_node(fn_table_entry, param_i);
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
