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
#include "parsec.hpp"
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

CodeGen *codegen_create(Buf *root_src_path, const ZigTarget *target, OutType out_type, BuildMode build_mode,
    Buf *zig_lib_dir)
{
    CodeGen *g = allocate<CodeGen>(1);

    codegen_add_time_event(g, "Initialize");

    g->zig_lib_dir = zig_lib_dir;

    g->zig_std_dir = buf_alloc();
    os_path_join(zig_lib_dir, buf_create_from_str("std"), g->zig_std_dir);

    g->zig_c_headers_dir = buf_alloc();
    os_path_join(zig_lib_dir, buf_create_from_str("include"), g->zig_c_headers_dir);

    g->build_mode = build_mode;
    g->out_type = out_type;
    g->import_table.init(32);
    g->builtin_fn_table.init(32);
    g->primitive_type_table.init(32);
    g->type_table.init(32);
    g->fn_type_table.init(32);
    g->error_table.init(16);
    g->generic_table.init(16);
    g->llvm_fn_table.init(16);
    g->memoized_fn_eval_table.init(16);
    g->exported_symbol_names.init(8);
    g->external_prototypes.init(8);
    g->is_test_build = false;
    g->want_h_file = (out_type == OutTypeObj || out_type == OutTypeLib);

    buf_resize(&g->global_asm, 0);

    // reserve index 0 to indicate no error
    g->error_decls.append(nullptr);

    if (root_src_path) {
        Buf *src_basename = buf_alloc();
        Buf *src_dir = buf_alloc();
        os_path_split(root_src_path, src_dir, src_basename);

        g->root_package = new_package(buf_ptr(src_dir), buf_ptr(src_basename));
        g->std_package = new_package(buf_ptr(g->zig_std_dir), "index.zig");
        g->root_package->package_table.put(buf_create_from_str("std"), g->std_package);
    } else {
        g->root_package = new_package(".", "");
    }

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
        g->each_lib_rpath = false;
    } else {
        // native compilation, we can rely on the configuration stuff
        g->is_native_target = true;
        get_native_target(&g->zig_target);

        g->dynamic_linker = buf_create_from_str(ZIG_DYNAMIC_LINKER);
        g->libc_lib_dir = buf_create_from_str(ZIG_LIBC_LIB_DIR);
        g->libc_static_lib_dir = buf_create_from_str(ZIG_LIBC_STATIC_LIB_DIR);
        g->libc_include_dir = buf_create_from_str(ZIG_LIBC_INCLUDE_DIR);
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
        g->libc_link_lib = create_link_lib(buf_create_from_str("c"));
        g->link_libs_list.append(g->libc_link_lib);
    }

    return g;
}

void codegen_set_output_h_path(CodeGen *g, Buf *h_path) {
    g->out_h_path = h_path;
}

void codegen_set_clang_argv(CodeGen *g, const char **args, size_t len) {
    g->clang_argv = args;
    g->clang_argv_len = len;
}

void codegen_set_llvm_argv(CodeGen *g, const char **args, size_t len) {
    g->llvm_argv = args;
    g->llvm_argv_len = len;
}

void codegen_set_test_filter(CodeGen *g, Buf *filter) {
    g->test_filter = filter;
}

void codegen_set_test_name_prefix(CodeGen *g, Buf *prefix) {
    g->test_name_prefix = prefix;
}

void codegen_set_lib_version(CodeGen *g, size_t major, size_t minor, size_t patch) {
    g->version_major = major;
    g->version_minor = minor;
    g->version_patch = patch;
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

void codegen_set_out_name(CodeGen *g, Buf *out_name) {
    g->root_out_name = out_name;
}

void codegen_set_cache_dir(CodeGen *g, Buf *cache_dir) {
    g->cache_dir = cache_dir;
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

void codegen_set_dynamic_linker(CodeGen *g, Buf *dynamic_linker) {
    g->dynamic_linker = dynamic_linker;
}

void codegen_add_lib_dir(CodeGen *g, const char *dir) {
    g->lib_dirs.append(dir);
}

void codegen_add_rpath(CodeGen *g, const char *name) {
    g->rpath_list.append(buf_create_from_str(name));
}

LinkLib *codegen_add_link_lib(CodeGen *g, Buf *name) {
    return add_link_lib(g, name);
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
static void generate_error_name_table(CodeGen *g);

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
            attr_name, (unsigned)strlen(attr_name), attr_val, (unsigned)strlen(attr_val));
    LLVMAddAttributeAtIndex(val, attr_index, llvm_attr);
}

static void addLLVMAttrInt(LLVMValueRef val, LLVMAttributeIndex attr_index,
        const char *attr_name, uint64_t attr_val)
{
    unsigned kind_id = LLVMGetEnumAttributeKindForName(attr_name, strlen(attr_name));
    assert(kind_id != 0);
    LLVMAttributeRef llvm_attr = LLVMCreateEnumAttribute(LLVMGetGlobalContext(), kind_id, attr_val);
    LLVMAddAttributeAtIndex(val, attr_index, llvm_attr);
}

static void addLLVMFnAttr(LLVMValueRef fn_val, const char *attr_name) {
    return addLLVMAttr(fn_val, -1, attr_name);
}

static void addLLVMFnAttrStr(LLVMValueRef fn_val, const char *attr_name, const char *attr_val) {
    return addLLVMAttrStr(fn_val, -1, attr_name, attr_val);
}

static void addLLVMFnAttrInt(LLVMValueRef fn_val, const char *attr_name, uint64_t attr_val) {
    return addLLVMAttrInt(fn_val, -1, attr_name, attr_val);
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

static LLVMCallConv get_llvm_cc(CodeGen *g, CallingConvention cc) {
    switch (cc) {
        case CallingConventionUnspecified: return LLVMFastCallConv;
        case CallingConventionC: return LLVMCCallConv;
        case CallingConventionCold:
            // cold calling convention only works on x86.
            if (g->zig_target.arch.arch == ZigLLVM_x86 ||
                g->zig_target.arch.arch == ZigLLVM_x86_64)
            {
                // cold calling convention is not supported on windows
                if (g->zig_target.os == ZigLLVM_Win32) {
                    return LLVMCCallConv;
                } else {
                    return LLVMColdCallConv;
                }
            } else {
                return LLVMCCallConv;
            }
            break;
        case CallingConventionNaked:
            zig_unreachable();
        case CallingConventionStdcall:
            // stdcall calling convention only works on x86.
            if (g->zig_target.arch.arch == ZigLLVM_x86) {
                return LLVMX86StdcallCallConv;
            } else {
                return LLVMCCallConv;
            }
    }
    zig_unreachable();
}

static LLVMValueRef fn_llvm_value(CodeGen *g, FnTableEntry *fn_table_entry) {
    if (fn_table_entry->llvm_value)
        return fn_table_entry->llvm_value;

    bool external_linkage = (fn_table_entry->linkage != GlobalLinkageIdInternal);
    Buf *symbol_name = get_mangled_name(g, &fn_table_entry->symbol_name, external_linkage);

    if (fn_table_entry->type_entry->data.fn.fn_type_id.cc == CallingConventionStdcall && external_linkage &&
        g->zig_target.arch.arch == ZigLLVM_x86)
    {
        // prevent name mangling
        symbol_name = buf_sprintf("\x01_%s", buf_ptr(symbol_name));
    }


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
    fn_table_entry->llvm_name = LLVMGetValueName(fn_table_entry->llvm_value);

    switch (fn_table_entry->fn_inline) {
        case FnInlineAlways:
            addLLVMFnAttr(fn_table_entry->llvm_value, "alwaysinline");
            g->inline_fns.append(fn_table_entry);
            break;
        case FnInlineNever:
            addLLVMFnAttr(fn_table_entry->llvm_value, "noinline");
            break;
        case FnInlineAuto:
            if (fn_table_entry->alignstack_value != 0) {
                addLLVMFnAttr(fn_table_entry->llvm_value, "noinline");
            }
            break;
    }

    if (fn_type->data.fn.fn_type_id.cc == CallingConventionNaked) {
        addLLVMFnAttr(fn_table_entry->llvm_value, "naked");
    } else {
        LLVMSetFunctionCallConv(fn_table_entry->llvm_value, get_llvm_cc(g, fn_type->data.fn.fn_type_id.cc));
        if (fn_type->data.fn.fn_type_id.cc == CallingConventionCold) {
            ZigLLVMAddFunctionAttrCold(fn_table_entry->llvm_value);
        }
    }

    switch (fn_table_entry->linkage) {
        case GlobalLinkageIdInternal:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMInternalLinkage);
            LLVMSetUnnamedAddr(fn_table_entry->llvm_value, true);
            break;
        case GlobalLinkageIdStrong:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMExternalLinkage);
            break;
        case GlobalLinkageIdWeak:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMWeakAnyLinkage);
            break;
        case GlobalLinkageIdLinkOnce:
            LLVMSetLinkage(fn_table_entry->llvm_value, LLVMLinkOnceAnyLinkage);
            break;
    }

    if (fn_type->data.fn.fn_type_id.return_type->id == TypeTableEntryIdUnreachable) {
        addLLVMFnAttr(fn_table_entry->llvm_value, "noreturn");
    }

    if (fn_table_entry->body_node != nullptr) {
        bool want_fn_safety = g->build_mode != BuildModeFastRelease && !fn_table_entry->def_scope->safety_off;
        if (want_fn_safety) {
            if (g->libc_link_lib != nullptr) {
                addLLVMFnAttr(fn_table_entry->llvm_value, "sspstrong");
                addLLVMFnAttrStr(fn_table_entry->llvm_value, "stack-protector-buffer-size", "4");
            }
        }
    }

    if (fn_table_entry->alignstack_value != 0) {
        addLLVMFnAttrInt(fn_table_entry->llvm_value, "alignstack", fn_table_entry->alignstack_value);
    }

    addLLVMFnAttr(fn_table_entry->llvm_value, "nounwind");
    addLLVMFnAttr(fn_table_entry->llvm_value, "nobuiltin");
    if (g->build_mode == BuildModeDebug && fn_table_entry->fn_inline != FnInlineAlways) {
        ZigLLVMAddFunctionAttr(fn_table_entry->llvm_value, "no-frame-pointer-elim", "true");
        ZigLLVMAddFunctionAttr(fn_table_entry->llvm_value, "no-frame-pointer-elim-non-leaf", nullptr);
    }
    if (fn_table_entry->section_name) {
        LLVMSetSection(fn_table_entry->llvm_value, buf_ptr(fn_table_entry->section_name));
    }
    if (fn_table_entry->align_bytes > 0) {
        LLVMSetAlignment(fn_table_entry->llvm_value, (unsigned)fn_table_entry->align_bytes);
    } else {
        // We'd like to set the best alignment for the function here, but on Darwin LLVM gives
        // "Cannot getTypeInfo() on a type that is unsized!" assertion failure when calling
        // any of the functions for getting alignment. Not specifying the alignment should
        // use the ABI alignment, which is fine.
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
            unsigned line_number = (unsigned)(fn_table_entry->proto_node->line == 0) ?
                0 : (fn_table_entry->proto_node->line + 1);
            unsigned scope_line = line_number;
            bool is_definition = fn_table_entry->body_node != nullptr;
            unsigned flags = 0;
            bool is_optimized = g->build_mode != BuildModeDebug;
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
                (unsigned)scope->source_node->line + 1,
                (unsigned)scope->source_node->column + 1);
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
    sprintf(fn_name, "llvm.%s.with.overflow.i%" PRIu32, signed_str, type_entry->data.integral.bit_count);

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
    key.data.overflow_arithmetic.bit_count = (uint32_t)type_entry->data.integral.bit_count;

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

static LLVMValueRef get_floor_ceil_fn(CodeGen *g, TypeTableEntry *type_entry, ZigLLVMFnId fn_id) {
    assert(type_entry->id == TypeTableEntryIdFloat);

    ZigLLVMFnKey key = {};
    key.id = fn_id;
    key.data.floor_ceil.bit_count = (uint32_t)type_entry->data.floating.bit_count;

    auto existing_entry = g->llvm_fn_table.maybe_get(key);
    if (existing_entry)
        return existing_entry->value;

    const char *name;
    if (fn_id == ZigLLVMFnIdFloor) {
        name = "floor";
    } else if (fn_id == ZigLLVMFnIdCeil) {
        name = "ceil";
    } else {
        zig_unreachable();
    }

    char fn_name[64];
    sprintf(fn_name, "llvm.%s.f%" ZIG_PRI_usize "", name, type_entry->data.floating.bit_count);
    LLVMTypeRef fn_type = LLVMFunctionType(type_entry->type_ref, &type_entry->type_ref, 1, false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type);
    assert(LLVMGetIntrinsicID(fn_val));

    g->llvm_fn_table.put(key, fn_val);
    return fn_val;
}

static LLVMValueRef gen_store_untyped(CodeGen *g, LLVMValueRef value, LLVMValueRef ptr,
        uint32_t alignment, bool is_volatile)
{
    LLVMValueRef instruction = LLVMBuildStore(g->builder, value, ptr);
    if (is_volatile) LLVMSetVolatile(instruction, true);
    if (alignment == 0) {
        LLVMSetAlignment(instruction, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(value)));
    } else {
        LLVMSetAlignment(instruction, alignment);
    }
    return instruction;
}

static LLVMValueRef gen_store(CodeGen *g, LLVMValueRef value, LLVMValueRef ptr, TypeTableEntry *ptr_type) {
    assert(ptr_type->id == TypeTableEntryIdPointer);
    return gen_store_untyped(g, value, ptr, ptr_type->data.pointer.alignment, ptr_type->data.pointer.is_volatile);
}

static LLVMValueRef gen_load_untyped(CodeGen *g, LLVMValueRef ptr, uint32_t alignment, bool is_volatile,
        const char *name)
{
    LLVMValueRef result = LLVMBuildLoad(g->builder, ptr, name);
    if (is_volatile) LLVMSetVolatile(result, true);
    if (alignment == 0) {
        LLVMSetAlignment(result, LLVMABIAlignmentOfType(g->target_data_ref, LLVMGetElementType(LLVMTypeOf(ptr))));
    } else {
        LLVMSetAlignment(result, alignment);
    }
    return result;
}

static LLVMValueRef gen_load(CodeGen *g, LLVMValueRef ptr, TypeTableEntry *ptr_type, const char *name) {
    assert(ptr_type->id == TypeTableEntryIdPointer);
    return gen_load_untyped(g, ptr, ptr_type->data.pointer.alignment, ptr_type->data.pointer.is_volatile, name);
}

static LLVMValueRef get_handle_value(CodeGen *g, LLVMValueRef ptr, TypeTableEntry *type, TypeTableEntry *ptr_type) {
    if (type_has_bits(type)) {
        if (handle_is_ptr(type)) {
            return ptr;
        } else {
            assert(ptr_type->id == TypeTableEntryIdPointer);
            return gen_load(g, ptr, ptr_type, "");
        }
    } else {
        return nullptr;
    }
}

static bool ir_want_fast_math(CodeGen *g, IrInstruction *instruction) {
    // TODO memoize
    Scope *scope = instruction->scope;
    while (scope) {
        if (scope->id == ScopeIdBlock) {
            ScopeBlock *block_scope = (ScopeBlock *)scope;
            if (block_scope->fast_math_set_node)
                return !block_scope->fast_math_off;
        } else if (scope->id == ScopeIdDecls) {
            ScopeDecls *decls_scope = (ScopeDecls *)scope;
            if (decls_scope->fast_math_set_node)
                return !decls_scope->fast_math_off;
        }
        scope = scope->parent;
    }
    return true;
}

static bool ir_want_debug_safety(CodeGen *g, IrInstruction *instruction) {
    if (g->build_mode == BuildModeFastRelease)
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
        case PanicMsgIdShlOverflowedBits:
            return buf_create_from_str("left shift overflowed bits");
        case PanicMsgIdShrOverflowedBits:
            return buf_create_from_str("right shift overflowed bits");
        case PanicMsgIdDivisionByZero:
            return buf_create_from_str("division by zero");
        case PanicMsgIdRemainderDivisionByZero:
            return buf_create_from_str("remainder division by zero or negative value");
        case PanicMsgIdExactDivisionRemainder:
            return buf_create_from_str("exact division produced remainder");
        case PanicMsgIdSliceWidenRemainder:
            return buf_create_from_str("slice widening size mismatch");
        case PanicMsgIdUnwrapMaybeFail:
            return buf_create_from_str("attempt to unwrap null");
        case PanicMsgIdUnreachable:
            return buf_create_from_str("reached unreachable code");
        case PanicMsgIdInvalidErrorCode:
            return buf_create_from_str("invalid error code");
        case PanicMsgIdIncorrectAlignment:
            return buf_create_from_str("incorrect alignment");
    }
    zig_unreachable();
}

static LLVMValueRef get_panic_msg_ptr_val(CodeGen *g, PanicMsgId msg_id) {
    ConstExprValue *val = &g->panic_msg_vals[msg_id];
    if (!val->global_refs->llvm_global) {

        Buf *buf_msg = panic_msg_buf(msg_id);
        ConstExprValue *array_val = create_const_str_lit(g, buf_msg);
        init_const_slice(g, val, array_val, 0, buf_len(buf_msg), true);

        render_const_val(g, val);
        render_const_val_global(g, val, "");

        assert(val->global_refs->llvm_global);
    }

    TypeTableEntry *u8_ptr_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);
    TypeTableEntry *str_type = get_slice_type(g, u8_ptr_type);
    return LLVMConstBitCast(val->global_refs->llvm_global, LLVMPointerType(str_type->type_ref, 0));
}

static void gen_panic(CodeGen *g, LLVMValueRef msg_arg) {
    assert(g->panic_fn != nullptr);
    LLVMValueRef fn_val = fn_llvm_value(g, g->panic_fn);
    LLVMCallConv llvm_cc = get_llvm_cc(g, g->panic_fn->type_entry->data.fn.fn_type_id.cc);
    ZigLLVMBuildCall(g->builder, fn_val, &msg_arg, 1, llvm_cc, false, "");
    LLVMBuildUnreachable(g->builder);
}

static void gen_debug_safety_crash(CodeGen *g, PanicMsgId msg_id) {
    gen_panic(g, get_panic_msg_ptr_val(g, msg_id));
}

static LLVMValueRef get_memcpy_fn_val(CodeGen *g) {
    if (g->memcpy_fn_val)
        return g->memcpy_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMPointerType(LLVMInt8Type(), 0),
        LLVMPointerType(LLVMInt8Type(), 0),
        LLVMIntType(g->pointer_size_bytes * 8),
        LLVMInt32Type(),
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), param_types, 5, false);
    Buf *name = buf_sprintf("llvm.memcpy.p0i8.p0i8.i%d", g->pointer_size_bytes * 8);
    g->memcpy_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->memcpy_fn_val));

    return g->memcpy_fn_val;
}

static LLVMValueRef get_safety_crash_err_fn(CodeGen *g) {
    if (g->safety_crash_err_fn != nullptr)
        return g->safety_crash_err_fn;

    static const char *unwrap_err_msg_text = "attempt to unwrap error: ";

    g->generate_error_name_table = true;
    generate_error_name_table(g);
    assert(g->err_name_table != nullptr);

    size_t unwrap_err_msg_text_len = strlen(unwrap_err_msg_text);
    size_t err_buf_len = strlen(unwrap_err_msg_text) + g->largest_err_name_len;
    LLVMValueRef *err_buf_vals = allocate<LLVMValueRef>(err_buf_len);
    size_t i = 0;
    for (; i < unwrap_err_msg_text_len; i += 1) {
        err_buf_vals[i] = LLVMConstInt(LLVMInt8Type(), unwrap_err_msg_text[i], false);
    }
    for (; i < err_buf_len; i += 1) {
        err_buf_vals[i] = LLVMGetUndef(LLVMInt8Type());
    }
    uint32_t u8_align_bytes = get_abi_alignment(g, g->builtin_types.entry_u8);
    LLVMValueRef init_value = LLVMConstArray(LLVMInt8Type(), err_buf_vals, err_buf_len);
    LLVMValueRef global_array = LLVMAddGlobal(g->module, LLVMTypeOf(init_value), "");
    LLVMSetInitializer(global_array, init_value);
    LLVMSetLinkage(global_array, LLVMInternalLinkage);
    LLVMSetGlobalConstant(global_array, false);
    LLVMSetUnnamedAddr(global_array, true);
    LLVMSetAlignment(global_array, u8_align_bytes);

    TypeTableEntry *usize = g->builtin_types.entry_usize;
    LLVMValueRef full_buf_ptr_indices[] = {
        LLVMConstNull(usize->type_ref),
        LLVMConstNull(usize->type_ref),
    };
    LLVMValueRef full_buf_ptr = LLVMConstInBoundsGEP(global_array, full_buf_ptr_indices, 2);


    TypeTableEntry *u8_ptr_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);
    TypeTableEntry *str_type = get_slice_type(g, u8_ptr_type);
    LLVMValueRef global_slice_fields[] = {
        full_buf_ptr,
        LLVMConstNull(usize->type_ref),
    };
    LLVMValueRef slice_init_value = LLVMConstNamedStruct(str_type->type_ref, global_slice_fields, 2);
    LLVMValueRef global_slice = LLVMAddGlobal(g->module, LLVMTypeOf(slice_init_value), "");
    LLVMSetInitializer(global_slice, slice_init_value);
    LLVMSetLinkage(global_slice, LLVMInternalLinkage);
    LLVMSetGlobalConstant(global_slice, false);
    LLVMSetUnnamedAddr(global_slice, true);
    LLVMSetAlignment(global_slice, get_abi_alignment(g, str_type));

    LLVMValueRef offset_ptr_indices[] = {
        LLVMConstNull(usize->type_ref),
        LLVMConstInt(usize->type_ref, unwrap_err_msg_text_len, false),
    };
    LLVMValueRef offset_buf_ptr = LLVMConstInBoundsGEP(global_array, offset_ptr_indices, 2);

    Buf *fn_name = get_mangled_name(g, buf_create_from_str("__zig_fail_unwrap"), false);
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMVoidType(), &g->err_tag_type->type_ref, 1, false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(fn_name), fn_type_ref);
    addLLVMFnAttr(fn_val, "noreturn");
    addLLVMFnAttr(fn_val, "cold");
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    LLVMSetFunctionCallConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    if (g->build_mode == BuildModeDebug) {
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim", "true");
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim-non-leaf", nullptr);
    }
    // Not setting alignment here. See the comment above about
    // "Cannot getTypeInfo() on a type that is unsized!"
    // assertion failure on Darwin.

    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn_val, "Entry");
    LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
    LLVMValueRef prev_debug_location = LLVMGetCurrentDebugLocation(g->builder);
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
    ZigLLVMClearCurrentDebugLocation(g->builder);

    LLVMValueRef err_val = LLVMGetParam(fn_val, 0);

    LLVMValueRef err_table_indices[] = {
        LLVMConstNull(g->builtin_types.entry_usize->type_ref),
        err_val,
    };
    LLVMValueRef err_name_val = LLVMBuildInBoundsGEP(g->builder, g->err_name_table, err_table_indices, 2, "");

    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, err_name_val, slice_ptr_index, "");
    LLVMValueRef err_name_ptr = gen_load_untyped(g, ptr_field_ptr, 0, false, "");

    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, err_name_val, slice_len_index, "");
    LLVMValueRef err_name_len = gen_load_untyped(g, len_field_ptr, 0, false, "");

    LLVMValueRef params[] = {
        offset_buf_ptr, // dest pointer
        err_name_ptr, // source pointer
        err_name_len, // size bytes
        LLVMConstInt(LLVMInt32Type(), u8_align_bytes, false), // align bytes
        LLVMConstNull(LLVMInt1Type()), // is volatile
    };

    LLVMBuildCall(g->builder, get_memcpy_fn_val(g), params, 5, "");

    LLVMValueRef const_prefix_len = LLVMConstInt(LLVMTypeOf(err_name_len), strlen(unwrap_err_msg_text), false);
    LLVMValueRef full_buf_len = LLVMBuildNUWAdd(g->builder, const_prefix_len, err_name_len, "");

    LLVMValueRef global_slice_len_field_ptr = LLVMBuildStructGEP(g->builder, global_slice, slice_len_index, "");
    gen_store(g, full_buf_len, global_slice_len_field_ptr, u8_ptr_type);

    gen_panic(g, global_slice);

    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);

    g->safety_crash_err_fn = fn_val;
    return fn_val;
}

static void gen_debug_safety_crash_for_err(CodeGen *g, LLVMValueRef err_val) {
    LLVMValueRef safety_crash_err_fn = get_safety_crash_err_fn(g);
    ZigLLVMBuildCall(g->builder, safety_crash_err_fn, &err_val, 1, get_llvm_cc(g, CallingConventionUnspecified),
        false, "");
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

static LLVMValueRef gen_widen_or_shorten(CodeGen *g, bool want_debug_safety, TypeTableEntry *actual_type,
        TypeTableEntry *wanted_type, LLVMValueRef expr_val)
{
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

static LLVMValueRef gen_assign_raw(CodeGen *g, LLVMValueRef ptr, TypeTableEntry *ptr_type,
        LLVMValueRef value)
{
    assert(ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *child_type = ptr_type->data.pointer.child_type;

    if (!type_has_bits(child_type))
        return nullptr;

    if (handle_is_ptr(child_type)) {
        assert(LLVMGetTypeKind(LLVMTypeOf(value)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMTypeOf(ptr)) == LLVMPointerTypeKind);

        LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

        LLVMValueRef src_ptr = LLVMBuildBitCast(g->builder, value, ptr_u8, "");
        LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, ptr, ptr_u8, "");

        TypeTableEntry *usize = g->builtin_types.entry_usize;
        uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, child_type->type_ref);
        uint64_t align_bytes = ptr_type->data.pointer.alignment;
        assert(size_bytes > 0);
        assert(align_bytes > 0);

        LLVMValueRef volatile_bit = ptr_type->data.pointer.is_volatile ?
            LLVMConstAllOnes(LLVMInt1Type()) : LLVMConstNull(LLVMInt1Type());

        LLVMValueRef params[] = {
            dest_ptr, // dest pointer
            src_ptr, // source pointer
            LLVMConstInt(usize->type_ref, size_bytes, false),
            LLVMConstInt(LLVMInt32Type(), align_bytes, false),
            volatile_bit,
        };

        LLVMBuildCall(g->builder, get_memcpy_fn_val(g), params, 5, "");
        return nullptr;
    }

    uint32_t unaligned_bit_count = ptr_type->data.pointer.unaligned_bit_count;
    if (unaligned_bit_count == 0) {
        gen_store(g, value, ptr, ptr_type);
        return nullptr;
    }

    LLVMValueRef containing_int = gen_load(g, ptr, ptr_type, "");

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

    gen_store(g, ored_value, ptr, ptr_type);
    return nullptr;
}

static void gen_var_debug_decl(CodeGen *g, VariableTableEntry *var) {
    AstNode *source_node = var->decl_node;
    ZigLLVMDILocation *debug_loc = ZigLLVMGetDebugLoc((unsigned)source_node->line + 1,
            (unsigned)source_node->column + 1, get_di_scope(g, var->parent_scope));
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
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value.global_refs->llvm_global, ptr_type->type_ref, "");
        } else if (instruction->value.type->id == TypeTableEntryIdPointer) {
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value.global_refs->llvm_value, instruction->value.type->type_ref, "");
        } else {
            instruction->llvm_value = instruction->value.global_refs->llvm_value;
        }
        assert(instruction->llvm_value);
    }
    return instruction->llvm_value;
}

static LLVMValueRef ir_render_return(CodeGen *g, IrExecutable *executable, IrInstructionReturn *return_instruction) {
    LLVMValueRef value = ir_llvm_value(g, return_instruction->value);
    TypeTableEntry *return_type = return_instruction->value->value.type;
    if (handle_is_ptr(return_type)) {
        if (calling_convention_does_first_arg_return(g->cur_fn->type_entry->data.fn.fn_type_id.cc)) {
            assert(g->cur_ret_ptr);
            gen_assign_raw(g, g->cur_ret_ptr, get_pointer_to_type(g, return_type, false), value);
            LLVMBuildRetVoid(g->builder);
        } else {
            LLVMValueRef by_val_value = gen_load_untyped(g, value, 0, false, "");
            LLVMBuildRet(g->builder, by_val_value);
        }
    } else {
        LLVMBuildRet(g->builder, value);
    }
    return nullptr;
}

static LLVMValueRef gen_overflow_shl_op(CodeGen *g, TypeTableEntry *type_entry,
        LLVMValueRef val1, LLVMValueRef val2)
{
    // for unsigned left shifting, we do the lossy shift, then logically shift
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
    gen_debug_safety_crash(g, PanicMsgIdShlOverflowedBits);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_overflow_shr_op(CodeGen *g, TypeTableEntry *type_entry,
        LLVMValueRef val1, LLVMValueRef val2)
{
    assert(type_entry->id == TypeTableEntryIdInt);

    LLVMValueRef result;
    if (type_entry->data.integral.is_signed) {
        result = LLVMBuildAShr(g->builder, val1, val2, "");
    } else {
        result = LLVMBuildLShr(g->builder, val1, val2, "");
    }
    LLVMValueRef orig_val = LLVMBuildShl(g->builder, result, val2, "");
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, orig_val, "");

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowFail");
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_debug_safety_crash(g, PanicMsgIdShrOverflowedBits);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_floor(CodeGen *g, LLVMValueRef val, TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdInt)
        return val;

    LLVMValueRef floor_fn = get_floor_ceil_fn(g, type_entry, ZigLLVMFnIdFloor);
    return LLVMBuildCall(g->builder, floor_fn, &val, 1, "");
}

static LLVMValueRef gen_ceil(CodeGen *g, LLVMValueRef val, TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdInt)
        return val;

    LLVMValueRef ceil_fn = get_floor_ceil_fn(g, type_entry, ZigLLVMFnIdCeil);
    return LLVMBuildCall(g->builder, ceil_fn, &val, 1, "");
}

enum DivKind {
    DivKindFloat,
    DivKindTrunc,
    DivKindFloor,
    DivKindExact,
};

static LLVMValueRef bigint_to_llvm_const(LLVMTypeRef type_ref, BigInt *bigint) {
    if (bigint->digit_count == 0) {
        return LLVMConstNull(type_ref);
    }
    LLVMValueRef unsigned_val = LLVMConstIntOfArbitraryPrecision(type_ref,
            bigint->digit_count, bigint_ptr(bigint));
    if (bigint->is_negative) {
        return LLVMConstNeg(unsigned_val);
    } else {
        return unsigned_val;
    }
}

static LLVMValueRef gen_div(CodeGen *g, bool want_debug_safety, bool want_fast_math,
        LLVMValueRef val1, LLVMValueRef val2,
        TypeTableEntry *type_entry, DivKind div_kind)
{
    ZigLLVMSetFastMath(g->builder, want_fast_math);

    LLVMValueRef zero = LLVMConstNull(type_entry->type_ref);
    if (want_debug_safety && (want_fast_math || type_entry->id != TypeTableEntryIdFloat)) {
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
            BigInt int_min_bi = {0};
            eval_min_max_value_int(g, type_entry, &int_min_bi, false);
            LLVMValueRef int_min_value = bigint_to_llvm_const(type_entry->type_ref, &int_min_bi);
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
        LLVMValueRef result = LLVMBuildFDiv(g->builder, val1, val2, "");
        switch (div_kind) {
            case DivKindFloat:
                return result;
            case DivKindExact:
                if (want_debug_safety) {
                    LLVMValueRef floored = gen_floor(g, result, type_entry);
                    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactOk");
                    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactFail");
                    LLVMValueRef ok_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, floored, result, "");

                    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

                    LLVMPositionBuilderAtEnd(g->builder, fail_block);
                    gen_debug_safety_crash(g, PanicMsgIdExactDivisionRemainder);

                    LLVMPositionBuilderAtEnd(g->builder, ok_block);
                }
                return result;
            case DivKindTrunc:
                {
                    LLVMBasicBlockRef ltz_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivTruncLTZero");
                    LLVMBasicBlockRef gez_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivTruncGEZero");
                    LLVMBasicBlockRef end_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivTruncEnd");
                    LLVMValueRef ltz = LLVMBuildFCmp(g->builder, LLVMRealOLT, val1, zero, "");
                    LLVMBuildCondBr(g->builder, ltz, ltz_block, gez_block);

                    LLVMPositionBuilderAtEnd(g->builder, ltz_block);
                    LLVMValueRef ceiled = gen_ceil(g, result, type_entry);
                    LLVMBasicBlockRef ceiled_end_block = LLVMGetInsertBlock(g->builder);
                    LLVMBuildBr(g->builder, end_block);

                    LLVMPositionBuilderAtEnd(g->builder, gez_block);
                    LLVMValueRef floored = gen_floor(g, result, type_entry);
                    LLVMBasicBlockRef floored_end_block = LLVMGetInsertBlock(g->builder);
                    LLVMBuildBr(g->builder, end_block);

                    LLVMPositionBuilderAtEnd(g->builder, end_block);
                    LLVMValueRef phi = LLVMBuildPhi(g->builder, type_entry->type_ref, "");
                    LLVMValueRef incoming_values[] = { ceiled, floored };
                    LLVMBasicBlockRef incoming_blocks[] = { ceiled_end_block, floored_end_block };
                    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);
                    return phi;
                }
            case DivKindFloor:
                return gen_floor(g, result, type_entry);
        }
        zig_unreachable();
    }

    assert(type_entry->id == TypeTableEntryIdInt);

    switch (div_kind) {
        case DivKindFloat:
            zig_unreachable();
        case DivKindTrunc:
            if (type_entry->data.integral.is_signed) {
                return LLVMBuildSDiv(g->builder, val1, val2, "");
            } else {
                return LLVMBuildUDiv(g->builder, val1, val2, "");
            }
        case DivKindExact:
            if (want_debug_safety) {
                LLVMValueRef remainder_val;
                if (type_entry->data.integral.is_signed) {
                    remainder_val = LLVMBuildSRem(g->builder, val1, val2, "");
                } else {
                    remainder_val = LLVMBuildURem(g->builder, val1, val2, "");
                }
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
        case DivKindFloor:
            {
                if (!type_entry->data.integral.is_signed) {
                    return LLVMBuildUDiv(g->builder, val1, val2, "");
                }
                // const result = @divTrunc(a, b);
                // if (result >= 0 or result * b == a)
                //     return result;
                // else
                //     return result - 1;

                LLVMValueRef result = LLVMBuildSDiv(g->builder, val1, val2, "");
                LLVMValueRef is_pos = LLVMBuildICmp(g->builder, LLVMIntSGE, result, zero, "");
                LLVMValueRef orig_num = LLVMBuildNSWMul(g->builder, result, val2, "");
                LLVMValueRef orig_ok = LLVMBuildICmp(g->builder, LLVMIntEQ, orig_num, val1, "");
                LLVMValueRef ok_bit = LLVMBuildOr(g->builder, orig_ok, is_pos, "");
                LLVMValueRef one = LLVMConstInt(type_entry->type_ref, 1, true);
                LLVMValueRef result_minus_1 = LLVMBuildNSWSub(g->builder, result, one, "");
                return LLVMBuildSelect(g->builder, ok_bit, result, result_minus_1, "");
            }
    }
    zig_unreachable();
}

enum RemKind {
    RemKindRem,
    RemKindMod,
};

static LLVMValueRef gen_rem(CodeGen *g, bool want_debug_safety, bool want_fast_math,
        LLVMValueRef val1, LLVMValueRef val2,
        TypeTableEntry *type_entry, RemKind rem_kind)
{
    ZigLLVMSetFastMath(g->builder, want_fast_math);

    LLVMValueRef zero = LLVMConstNull(type_entry->type_ref);
    if (want_debug_safety) {
        LLVMValueRef is_zero_bit;
        if (type_entry->id == TypeTableEntryIdInt) {
            LLVMIntPredicate pred = type_entry->data.integral.is_signed ? LLVMIntSLE : LLVMIntEQ;
            is_zero_bit = LLVMBuildICmp(g->builder, pred, val2, zero, "");
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
    }

    if (type_entry->id == TypeTableEntryIdFloat) {
        if (rem_kind == RemKindRem) {
            return LLVMBuildFRem(g->builder, val1, val2, "");
        } else {
            LLVMValueRef a = LLVMBuildFRem(g->builder, val1, val2, "");
            LLVMValueRef b = LLVMBuildFAdd(g->builder, a, val2, "");
            LLVMValueRef c = LLVMBuildFRem(g->builder, b, val2, "");
            LLVMValueRef ltz = LLVMBuildFCmp(g->builder, LLVMRealOLT, val1, zero, "");
            return LLVMBuildSelect(g->builder, ltz, c, a, "");
        }
    } else {
        assert(type_entry->id == TypeTableEntryIdInt);
        if (type_entry->data.integral.is_signed) {
            if (rem_kind == RemKindRem) {
                return LLVMBuildSRem(g->builder, val1, val2, "");
            } else {
                LLVMValueRef a = LLVMBuildSRem(g->builder, val1, val2, "");
                LLVMValueRef b = LLVMBuildNSWAdd(g->builder, a, val2, "");
                LLVMValueRef c = LLVMBuildSRem(g->builder, b, val2, "");
                LLVMValueRef ltz = LLVMBuildICmp(g->builder, LLVMIntSLT, val1, zero, "");
                return LLVMBuildSelect(g->builder, ltz, c, a, "");
            }
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

    assert(op1->value.type == op2->value.type || op_id == IrBinOpBitShiftLeftLossy ||
            op_id == IrBinOpBitShiftLeftExact || op_id == IrBinOpBitShiftRightLossy ||
            op_id == IrBinOpBitShiftRightExact);
    TypeTableEntry *type_entry = op1->value.type;

    bool want_debug_safety = bin_op_instruction->safety_check_on &&
        ir_want_debug_safety(g, &bin_op_instruction->base);

    LLVMValueRef op1_value = ir_llvm_value(g, op1);
    LLVMValueRef op2_value = ir_llvm_value(g, op2);
    switch (op_id) {
        case IrBinOpInvalid:
        case IrBinOpArrayCat:
        case IrBinOpArrayMult:
        case IrBinOpRemUnspecified:
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
            if (type_entry->id == TypeTableEntryIdFloat) {
                ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &bin_op_instruction->base));
                LLVMRealPredicate pred = cmp_op_to_real_predicate(op_id);
                return LLVMBuildFCmp(g->builder, pred, op1_value, op2_value, "");
            } else if (type_entry->id == TypeTableEntryIdInt) {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, type_entry->data.integral.is_signed);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else if (type_entry->id == TypeTableEntryIdEnum) {
                if (type_entry->data.enumeration.gen_field_count == 0) {
                    LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, false);
                    return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
                } else {
                    zig_unreachable();
                }
            } else if (type_entry->id == TypeTableEntryIdPureError ||
                    type_entry->id == TypeTableEntryIdPointer ||
                    type_entry->id == TypeTableEntryIdBool)
            {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, false);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else {
                zig_unreachable();
            }
        case IrBinOpAdd:
        case IrBinOpAddWrap:
            if (type_entry->id == TypeTableEntryIdFloat) {
                ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &bin_op_instruction->base));
                return LLVMBuildFAdd(g->builder, op1_value, op2_value, "");
            } else if (type_entry->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpAddWrap);
                if (is_wrapping) {
                    return LLVMBuildAdd(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety) {
                    return gen_overflow_op(g, type_entry, AddSubMulAdd, op1_value, op2_value);
                } else if (type_entry->data.integral.is_signed) {
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
        case IrBinOpBitShiftLeftLossy:
        case IrBinOpBitShiftLeftExact:
            {
                assert(type_entry->id == TypeTableEntryIdInt);
                LLVMValueRef op2_casted = gen_widen_or_shorten(g, false, op2->value.type,
                        type_entry, op2_value);
                bool is_sloppy = (op_id == IrBinOpBitShiftLeftLossy);
                if (is_sloppy) {
                    return LLVMBuildShl(g->builder, op1_value, op2_casted, "");
                } else if (want_debug_safety) {
                    return gen_overflow_shl_op(g, type_entry, op1_value, op2_casted);
                } else if (type_entry->data.integral.is_signed) {
                    return ZigLLVMBuildNSWShl(g->builder, op1_value, op2_casted, "");
                } else {
                    return ZigLLVMBuildNUWShl(g->builder, op1_value, op2_casted, "");
                }
            }
        case IrBinOpBitShiftRightLossy:
        case IrBinOpBitShiftRightExact:
            {
                assert(type_entry->id == TypeTableEntryIdInt);
                LLVMValueRef op2_casted = gen_widen_or_shorten(g, false, op2->value.type,
                        type_entry, op2_value);
                bool is_sloppy = (op_id == IrBinOpBitShiftRightLossy);
                if (is_sloppy) {
                    if (type_entry->data.integral.is_signed) {
                        return LLVMBuildAShr(g->builder, op1_value, op2_casted, "");
                    } else {
                        return LLVMBuildLShr(g->builder, op1_value, op2_casted, "");
                    }
                } else if (want_debug_safety) {
                    return gen_overflow_shr_op(g, type_entry, op1_value, op2_casted);
                } else if (type_entry->data.integral.is_signed) {
                    return ZigLLVMBuildAShrExact(g->builder, op1_value, op2_casted, "");
                } else {
                    return ZigLLVMBuildLShrExact(g->builder, op1_value, op2_casted, "");
                }
            }
        case IrBinOpSub:
        case IrBinOpSubWrap:
            if (type_entry->id == TypeTableEntryIdFloat) {
                ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &bin_op_instruction->base));
                return LLVMBuildFSub(g->builder, op1_value, op2_value, "");
            } else if (type_entry->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpSubWrap);
                if (is_wrapping) {
                    return LLVMBuildSub(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety) {
                    return gen_overflow_op(g, type_entry, AddSubMulSub, op1_value, op2_value);
                } else if (type_entry->data.integral.is_signed) {
                    return LLVMBuildNSWSub(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildNUWSub(g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
        case IrBinOpMult:
        case IrBinOpMultWrap:
            if (type_entry->id == TypeTableEntryIdFloat) {
                ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &bin_op_instruction->base));
                return LLVMBuildFMul(g->builder, op1_value, op2_value, "");
            } else if (type_entry->id == TypeTableEntryIdInt) {
                bool is_wrapping = (op_id == IrBinOpMultWrap);
                if (is_wrapping) {
                    return LLVMBuildMul(g->builder, op1_value, op2_value, "");
                } else if (want_debug_safety) {
                    return gen_overflow_op(g, type_entry, AddSubMulMul, op1_value, op2_value);
                } else if (type_entry->data.integral.is_signed) {
                    return LLVMBuildNSWMul(g->builder, op1_value, op2_value, "");
                } else {
                    return LLVMBuildNUWMul(g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
        case IrBinOpDivUnspecified:
            return gen_div(g, want_debug_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, type_entry, DivKindFloat);
        case IrBinOpDivExact:
            return gen_div(g, want_debug_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, type_entry, DivKindExact);
        case IrBinOpDivTrunc:
            return gen_div(g, want_debug_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, type_entry, DivKindTrunc);
        case IrBinOpDivFloor:
            return gen_div(g, want_debug_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, type_entry, DivKindFloor);
        case IrBinOpRemRem:
            return gen_rem(g, want_debug_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, type_entry, RemKindRem);
        case IrBinOpRemMod:
            return gen_rem(g, want_debug_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, type_entry, RemKindMod);
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
        case CastOpNumLitToConcrete:
            zig_unreachable();
        case CastOpNoop:
            return expr_val;
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


                size_t actual_ptr_index = actual_type->data.structure.fields[slice_ptr_index].gen_index;
                size_t actual_len_index = actual_type->data.structure.fields[slice_len_index].gen_index;
                size_t wanted_ptr_index = wanted_type->data.structure.fields[slice_ptr_index].gen_index;
                size_t wanted_len_index = wanted_type->data.structure.fields[slice_len_index].gen_index;

                LLVMValueRef src_ptr_ptr = LLVMBuildStructGEP(g->builder, expr_val, (unsigned)actual_ptr_index, "");
                LLVMValueRef src_ptr = gen_load_untyped(g, src_ptr_ptr, 0, false, "");
                LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr,
                        wanted_type->data.structure.fields[0].type_entry->type_ref, "");
                LLVMValueRef dest_ptr_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr,
                        (unsigned)wanted_ptr_index, "");
                gen_store_untyped(g, src_ptr_casted, dest_ptr_ptr, 0, false);

                LLVMValueRef src_len_ptr = LLVMBuildStructGEP(g->builder, expr_val, (unsigned)actual_len_index, "");
                LLVMValueRef src_len = gen_load_untyped(g, src_len_ptr, 0, false, "");
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
                        (unsigned)wanted_len_index, "");
                gen_store_untyped(g, new_len, dest_len_ptr, 0, false);


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
                LLVMValueRef dest_ptr_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr,
                        (unsigned)wanted_ptr_index, "");
                LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, expr_val, wanted_pointer_type->type_ref, "");
                gen_store_untyped(g, src_ptr_casted, dest_ptr_ptr, 0, false);

                size_t wanted_len_index = wanted_type->data.structure.fields[1].gen_index;
                LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, cast_instruction->tmp_ptr,
                        (unsigned)wanted_len_index, "");
                LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        actual_type->data.array.len / type_size(g, wanted_child_type), false);
                gen_store_untyped(g, len_val, len_ptr, 0, false);

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
            ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &cast_instruction->base));
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

static LLVMValueRef ir_render_ptr_cast(CodeGen *g, IrExecutable *executable,
        IrInstructionPtrCast *instruction)
{
    TypeTableEntry *wanted_type = instruction->base.value.type;
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    return LLVMBuildBitCast(g->builder, ptr, wanted_type->type_ref, "");
}

static LLVMValueRef ir_render_bit_cast(CodeGen *g, IrExecutable *executable,
        IrInstructionBitCast *instruction)
{
    TypeTableEntry *wanted_type = instruction->base.value.type;
    LLVMValueRef value = ir_llvm_value(g, instruction->value);
    return LLVMBuildBitCast(g->builder, value, wanted_type->type_ref, "");
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

static LLVMValueRef ir_render_int_to_err(CodeGen *g, IrExecutable *executable, IrInstructionIntToErr *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;
    assert(wanted_type->id == TypeTableEntryIdPureError);

    TypeTableEntry *actual_type = instruction->target->value.type;
    assert(actual_type->id == TypeTableEntryIdInt);
    assert(!actual_type->data.integral.is_signed);

    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);

    if (ir_want_debug_safety(g, &instruction->base)) {
        LLVMValueRef zero = LLVMConstNull(actual_type->type_ref);
        LLVMValueRef neq_zero_bit = LLVMBuildICmp(g->builder, LLVMIntNE, target_val, zero, "");
        LLVMValueRef ok_bit;

        BigInt biggest_possible_err_val = {0};
        eval_min_max_value_int(g, actual_type, &biggest_possible_err_val, true);

        if (bigint_fits_in_bits(&biggest_possible_err_val, 64, false) &&
            bigint_as_unsigned(&biggest_possible_err_val) < g->error_decls.length)
        {
            ok_bit = neq_zero_bit;
        } else {
            LLVMValueRef error_value_count = LLVMConstInt(actual_type->type_ref, g->error_decls.length, false);
            LLVMValueRef in_bounds_bit = LLVMBuildICmp(g->builder, LLVMIntULT, target_val, error_value_count, "");
            ok_bit = LLVMBuildAnd(g->builder, neq_zero_bit, in_bounds_bit, "");
        }

        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "IntToErrOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "IntToErrFail");

        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_debug_safety_crash(g, PanicMsgIdInvalidErrorCode);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    return gen_widen_or_shorten(g, false, actual_type, g->err_tag_type, target_val);
}

static LLVMValueRef ir_render_err_to_int(CodeGen *g, IrExecutable *executable, IrInstructionErrToInt *instruction) {
    TypeTableEntry *wanted_type = instruction->base.value.type;
    assert(wanted_type->id == TypeTableEntryIdInt);
    assert(!wanted_type->data.integral.is_signed);

    TypeTableEntry *actual_type = instruction->target->value.type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);

    if (actual_type->id == TypeTableEntryIdPureError) {
        return gen_widen_or_shorten(g, ir_want_debug_safety(g, &instruction->base),
            g->err_tag_type, wanted_type, target_val);
    } else if (actual_type->id == TypeTableEntryIdErrorUnion) {
        if (!type_has_bits(actual_type->data.error.child_type)) {
            return gen_widen_or_shorten(g, ir_want_debug_safety(g, &instruction->base),
                g->err_tag_type, wanted_type, target_val);
        } else {
            zig_panic("TODO");
        }
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef ir_render_unreachable(CodeGen *g, IrExecutable *executable,
        IrInstructionUnreachable *unreachable_instruction)
{
    if (ir_want_debug_safety(g, &unreachable_instruction->base)) {
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
                    ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &un_op_instruction->base));
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

static LLVMValueRef get_memset_fn_val(CodeGen *g) {
    if (g->memset_fn_val)
        return g->memset_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMPointerType(LLVMInt8Type(), 0),
        LLVMInt8Type(),
        LLVMIntType(g->pointer_size_bytes * 8),
        LLVMInt32Type(),
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), param_types, 5, false);
    Buf *name = buf_sprintf("llvm.memset.p0i8.i%d", g->pointer_size_bytes * 8);
    g->memset_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->memset_fn_val));

    return g->memset_fn_val;
}

static LLVMValueRef ir_render_decl_var(CodeGen *g, IrExecutable *executable,
        IrInstructionDeclVar *decl_var_instruction)
{
    VariableTableEntry *var = decl_var_instruction->var;

    if (!type_has_bits(var->value->type))
        return nullptr;

    if (var->ref_count == 0 && g->build_mode != BuildModeDebug)
        return nullptr;

    IrInstruction *init_value = decl_var_instruction->init_value;

    bool have_init_expr = false;

    ConstExprValue *const_val = &init_value->value;
    if (const_val->special == ConstValSpecialRuntime || const_val->special == ConstValSpecialStatic)
        have_init_expr = true;

    if (have_init_expr) {
        assert(var->value->type == init_value->value.type);
        TypeTableEntry *var_ptr_type = get_pointer_to_type_extra(g, var->value->type, false, false,
                var->align_bytes, 0, 0);
        gen_assign_raw(g, var->value_ref, var_ptr_type, ir_llvm_value(g, init_value));
    } else {
        bool want_safe = ir_want_debug_safety(g, &decl_var_instruction->base);
        if (want_safe) {
            TypeTableEntry *usize = g->builtin_types.entry_usize;
            uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, var->value->type->type_ref);
            assert(size_bytes > 0);

            assert(var->align_bytes > 0);

            // memset uninitialized memory to 0xa
            LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
            LLVMValueRef fill_char = LLVMConstInt(LLVMInt8Type(), 0xaa, false);
            LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, var->value_ref, ptr_u8, "");
            LLVMValueRef byte_count = LLVMConstInt(usize->type_ref, size_bytes, false);
            LLVMValueRef align_in_bytes = LLVMConstInt(LLVMInt32Type(), var->align_bytes, false);
            LLVMValueRef params[] = {
                dest_ptr,
                fill_char,
                byte_count,
                align_in_bytes,
                LLVMConstNull(LLVMInt1Type()), // is volatile
            };

            LLVMBuildCall(g->builder, get_memset_fn_val(g), params, 5, "");
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

    uint32_t unaligned_bit_count = ptr_type->data.pointer.unaligned_bit_count;
    if (unaligned_bit_count == 0)
        return get_handle_value(g, ptr, child_type, ptr_type);

    assert(!handle_is_ptr(child_type));
    LLVMValueRef containing_int = gen_load(g, ptr, ptr_type, "");

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
    TypeTableEntry *ptr_type = instruction->ptr->value.type;

    gen_assign_raw(g, ptr, ptr_type, value);

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
    TypeTableEntry *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);
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
        TypeTableEntry *child_type = array_type->data.array.child_type;
        if (child_type->id == TypeTableEntryIdStruct &&
            child_type->data.structure.layout == ContainerLayoutPacked)
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
                return LLVMBuildBitCast(g->builder, elem_byte_ptr, LLVMPointerType(child_type->type_ref, 0), "");
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
            LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)len_index, "");
            LLVMValueRef len = gen_load_untyped(g, len_ptr, 0, false, "");
            add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, len);
        }

        size_t ptr_index = array_type->data.structure.fields[0].gen_index;
        assert(ptr_index != SIZE_MAX);
        LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)ptr_index, "");
        LLVMValueRef ptr = gen_load_untyped(g, ptr_ptr, 0, false, "");
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

    bool want_always_inline = (instruction->fn_entry != nullptr &&
            instruction->fn_entry->fn_inline == FnInlineAlways) || instruction->is_inline;

    LLVMCallConv llvm_cc = get_llvm_cc(g, fn_type->data.fn.fn_type_id.cc);
    LLVMValueRef result = ZigLLVMBuildCall(g->builder, fn_val,
            gen_param_values, (unsigned)gen_param_index, llvm_cc, want_always_inline, "");

    for (size_t param_i = 0; param_i < fn_type_id->param_count; param_i += 1) {
        FnGenParamInfo *gen_info = &fn_type->data.fn.gen_param_info[param_i];
        if (gen_info->is_byval) {
            addLLVMCallsiteAttr(result, (unsigned)gen_info->gen_index, "byval");
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
    return LLVMBuildStructGEP(g->builder, struct_ptr, (unsigned)field->gen_index, "");
}

static LLVMValueRef ir_render_enum_field_ptr(CodeGen *g, IrExecutable *executable,
    IrInstructionEnumFieldPtr *instruction)
{
    TypeTableEntry *enum_ptr_type = instruction->enum_ptr->value.type;
    assert(enum_ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *enum_type = enum_ptr_type->data.pointer.child_type;
    assert(enum_type->id == TypeTableEntryIdEnum);

    TypeEnumField *field = instruction->field;

    if (!type_has_bits(field->type_entry))
        return nullptr;

    LLVMValueRef enum_ptr = ir_llvm_value(g, instruction->enum_ptr);
    LLVMTypeRef field_type_ref = LLVMPointerType(field->type_entry->type_ref, 0);
    LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, enum_ptr, enum_type->data.enumeration.gen_union_index, "");
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
                    buf_appendf(&llvm_template, "$%" ZIG_PRI_usize "", index);
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
    LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, (unsigned)input_and_output_count, false);

    bool is_volatile = asm_expr->is_volatile || (asm_expr->output_list.length == 0);
    LLVMValueRef asm_fn = LLVMConstInlineAsm(function_type, buf_ptr(&llvm_template),
            buf_ptr(&constraint_buf), is_volatile, false);

    return LLVMBuildCall(g->builder, asm_fn, param_values, (unsigned)input_and_output_count, "");
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
            return gen_load_untyped(g, maybe_field_ptr, 0, false, "");
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
    TypeTableEntry *maybe_type = ptr_type->data.pointer.child_type;
    assert(maybe_type->id == TypeTableEntryIdMaybe);
    TypeTableEntry *child_type = maybe_type->data.maybe.child_type;
    LLVMValueRef maybe_ptr = ir_llvm_value(g, instruction->value);
    LLVMValueRef maybe_handle = get_handle_value(g, maybe_ptr, maybe_type, ptr_type);
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
            LLVMValueRef maybe_struct_ref = get_handle_value(g, maybe_ptr, maybe_type, ptr_type);
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
        key.data.ctz.bit_count = (uint32_t)int_type->data.integral.bit_count;
    } else {
        fn_name = "ctlz";
        key.id = ZigLLVMFnIdClz;
        key.data.clz.bit_count = (uint32_t)int_type->data.integral.bit_count;
    }

    auto existing_entry = g->llvm_fn_table.maybe_get(key);
    if (existing_entry)
        return existing_entry->value;

    char llvm_name[64];
    sprintf(llvm_name, "llvm.%s.i%" PRIu32, fn_name, int_type->data.integral.bit_count);
    LLVMTypeRef param_types[] = {
        int_type->type_ref,
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(int_type->type_ref, param_types, 2, false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, llvm_name, fn_type);
    assert(LLVMGetIntrinsicID(fn_val));

    g->llvm_fn_table.put(key, fn_val);

    return fn_val;
}

static LLVMValueRef ir_render_clz(CodeGen *g, IrExecutable *executable, IrInstructionClz *instruction) {
    TypeTableEntry *int_type = instruction->value->value.type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdClz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->value);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    return gen_widen_or_shorten(g, false, int_type, instruction->base.value.type, wrong_size_int);
}

static LLVMValueRef ir_render_ctz(CodeGen *g, IrExecutable *executable, IrInstructionCtz *instruction) {
    TypeTableEntry *int_type = instruction->value->value.type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdCtz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->value);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    return gen_widen_or_shorten(g, false, int_type, instruction->base.value.type, wrong_size_int);
}

static LLVMValueRef ir_render_switch_br(CodeGen *g, IrExecutable *executable, IrInstructionSwitchBr *instruction) {
    LLVMValueRef target_value = ir_llvm_value(g, instruction->target_value);
    LLVMBasicBlockRef else_block = instruction->else_block->llvm_block;
    LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, target_value, else_block,
            (unsigned)instruction->case_count);
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
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, (unsigned)instruction->incoming_count);
    return phi;
}

static LLVMValueRef ir_render_ref(CodeGen *g, IrExecutable *executable, IrInstructionRef *instruction) {
    LLVMValueRef value = ir_llvm_value(g, instruction->value);
    if (handle_is_ptr(instruction->value->value.type)) {
        return value;
    } else {
        assert(instruction->tmp_ptr);
        gen_store_untyped(g, value, instruction->tmp_ptr, 0, false);
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

static LLVMValueRef ir_render_enum_tag_name(CodeGen *g, IrExecutable *executable,
        IrInstructionEnumTagName *instruction)
{
    TypeTableEntry *enum_tag_type = instruction->target->value.type;
    assert(enum_tag_type->data.enum_tag.generate_name_table);

    LLVMValueRef enum_tag_value = ir_llvm_value(g, instruction->target);
    if (ir_want_debug_safety(g, &instruction->base)) {
        TypeTableEntry *enum_type = enum_tag_type->data.enum_tag.enum_type;
        size_t field_count = enum_type->data.enumeration.src_field_count;
        LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(enum_tag_value));
        LLVMValueRef end_val = LLVMConstInt(LLVMTypeOf(enum_tag_value), field_count, false);
        add_bounds_check(g, enum_tag_value, LLVMIntUGE, zero, LLVMIntULT, end_val);
    }

    LLVMValueRef indices[] = {
        LLVMConstNull(g->builtin_types.entry_usize->type_ref),
        gen_widen_or_shorten(g, false, enum_tag_type->data.enum_tag.int_type,
                g->builtin_types.entry_usize, enum_tag_value),
    };
    return LLVMBuildInBoundsGEP(g->builder, enum_tag_type->data.enum_tag.name_table, indices, 2, "");
}

static LLVMValueRef ir_render_field_parent_ptr(CodeGen *g, IrExecutable *executable,
        IrInstructionFieldParentPtr *instruction)
{
    TypeTableEntry *container_ptr_type = instruction->base.value.type;
    assert(container_ptr_type->id == TypeTableEntryIdPointer);

    TypeTableEntry *container_type = container_ptr_type->data.pointer.child_type;

    size_t byte_offset = LLVMOffsetOfElement(g->target_data_ref,
            container_type->type_ref, instruction->field->gen_index);

    LLVMValueRef field_ptr_val = ir_llvm_value(g, instruction->field_ptr);

    if (byte_offset == 0) {
        return LLVMBuildBitCast(g->builder, field_ptr_val, container_ptr_type->type_ref, "");
    } else {
        TypeTableEntry *usize = g->builtin_types.entry_usize;

        LLVMValueRef field_ptr_int = LLVMBuildPtrToInt(g->builder, field_ptr_val,
                usize->type_ref, "");

        LLVMValueRef base_ptr_int = LLVMBuildNUWSub(g->builder, field_ptr_int,
                LLVMConstInt(usize->type_ref, byte_offset, false), "");

        return LLVMBuildIntToPtr(g->builder, base_ptr_int, container_ptr_type->type_ref, "");
    }
}

static LLVMValueRef ir_render_align_cast(CodeGen *g, IrExecutable *executable, IrInstructionAlignCast *instruction) {
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    assert(target_val);

    bool want_debug_safety = ir_want_debug_safety(g, &instruction->base);
    if (!want_debug_safety) {
        return target_val;
    }

    TypeTableEntry *target_type = instruction->base.value.type;
    uint32_t align_bytes;
    LLVMValueRef ptr_val;

    if (target_type->id == TypeTableEntryIdPointer) {
        align_bytes = target_type->data.pointer.alignment;
        ptr_val = target_val;
    } else if (target_type->id == TypeTableEntryIdFn) {
        align_bytes = target_type->data.fn.fn_type_id.alignment;
        ptr_val = target_val;
    } else if (target_type->id == TypeTableEntryIdMaybe &&
            target_type->data.maybe.child_type->id == TypeTableEntryIdPointer)
    {
        align_bytes = target_type->data.maybe.child_type->data.pointer.alignment;
        ptr_val = target_val;
    } else if (target_type->id == TypeTableEntryIdMaybe &&
            target_type->data.maybe.child_type->id == TypeTableEntryIdFn)
    {
        align_bytes = target_type->data.maybe.child_type->data.fn.fn_type_id.alignment;
        ptr_val = target_val;
    } else if (target_type->id == TypeTableEntryIdStruct && target_type->data.structure.is_slice) {
        TypeTableEntry *slice_ptr_type = target_type->data.structure.fields[slice_ptr_index].type_entry;
        align_bytes = slice_ptr_type->data.pointer.alignment;

        size_t ptr_index = target_type->data.structure.fields[slice_ptr_index].gen_index;
        LLVMValueRef ptr_val_ptr = LLVMBuildStructGEP(g->builder, target_val, (unsigned)ptr_index, "");
        ptr_val = gen_load_untyped(g, ptr_val_ptr, 0, false, "");
    } else {
        zig_unreachable();
    }

    assert(align_bytes != 1);

    TypeTableEntry *usize = g->builtin_types.entry_usize;
    LLVMValueRef ptr_as_int_val = LLVMBuildPtrToInt(g->builder, ptr_val, usize->type_ref, "");
    LLVMValueRef alignment_minus_1 = LLVMConstInt(usize->type_ref, align_bytes - 1, false);
    LLVMValueRef anded_val = LLVMBuildAnd(g->builder, ptr_as_int_val, alignment_minus_1, "");
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, anded_val, LLVMConstNull(usize->type_ref), "");

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "AlignCastOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "AlignCastFail");

    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_debug_safety_crash(g, PanicMsgIdIncorrectAlignment);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);

    return target_val;
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

static LLVMValueRef ir_render_truncate(CodeGen *g, IrExecutable *executable, IrInstructionTruncate *instruction) {
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    TypeTableEntry *dest_type = instruction->base.value.type;
    TypeTableEntry *src_type = instruction->target->value.type;
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

static LLVMValueRef ir_render_memset(CodeGen *g, IrExecutable *executable, IrInstructionMemset *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef char_val = ir_llvm_value(g, instruction->byte);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");

    TypeTableEntry *ptr_type = instruction->dest_ptr->value.type;
    assert(ptr_type->id == TypeTableEntryIdPointer);

    LLVMValueRef is_volatile = ptr_type->data.pointer.is_volatile ?
        LLVMConstAllOnes(LLVMInt1Type()) : LLVMConstNull(LLVMInt1Type());

    LLVMValueRef align_val = LLVMConstInt(LLVMInt32Type(), ptr_type->data.pointer.alignment, false);

    LLVMValueRef params[] = {
        dest_ptr_casted,
        char_val,
        len_val,
        align_val,
        is_volatile,
    };

    LLVMBuildCall(g->builder, get_memset_fn_val(g), params, 5, "");
    return nullptr;
}

static LLVMValueRef ir_render_memcpy(CodeGen *g, IrExecutable *executable, IrInstructionMemcpy *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef src_ptr = ir_llvm_value(g, instruction->src_ptr);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");
    LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr, ptr_u8, "");

    TypeTableEntry *dest_ptr_type = instruction->dest_ptr->value.type;
    TypeTableEntry *src_ptr_type = instruction->src_ptr->value.type;

    assert(dest_ptr_type->id == TypeTableEntryIdPointer);
    assert(src_ptr_type->id == TypeTableEntryIdPointer);

    LLVMValueRef is_volatile = (dest_ptr_type->data.pointer.is_volatile || src_ptr_type->data.pointer.is_volatile) ?
        LLVMConstAllOnes(LLVMInt1Type()) : LLVMConstNull(LLVMInt1Type());

    uint32_t min_align_bytes = min(src_ptr_type->data.pointer.alignment, dest_ptr_type->data.pointer.alignment);
    LLVMValueRef align_val = LLVMConstInt(LLVMInt32Type(), min_align_bytes, false);

    LLVMValueRef params[] = {
        dest_ptr_casted,
        src_ptr_casted,
        len_val,
        align_val,
        is_volatile,
    };

    LLVMBuildCall(g->builder, get_memcpy_fn_val(g), params, 5, "");
    return nullptr;
}

static LLVMValueRef ir_render_slice(CodeGen *g, IrExecutable *executable, IrInstructionSlice *instruction) {
    assert(instruction->tmp_ptr);

    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->ptr);
    TypeTableEntry *array_ptr_type = instruction->ptr->value.type;
    assert(array_ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);

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
        gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        gen_store_untyped(g, len_value, len_field_ptr, 0, false);

        return tmp_struct_ptr;
    } else if (array_type->id == TypeTableEntryIdPointer) {
        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val = ir_llvm_value(g, instruction->end);

        if (want_debug_safety) {
            add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
        }

        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_ptr_index, "");
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, &start_val, 1, "");
        gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        gen_store_untyped(g, len_value, len_field_ptr, 0, false);

        return tmp_struct_ptr;
    } else if (array_type->id == TypeTableEntryIdStruct) {
        assert(array_type->data.structure.is_slice);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        size_t ptr_index = array_type->data.structure.fields[slice_ptr_index].gen_index;
        assert(ptr_index != SIZE_MAX);
        size_t len_index = array_type->data.structure.fields[slice_len_index].gen_index;
        assert(len_index != SIZE_MAX);

        LLVMValueRef prev_end = nullptr;
        if (!instruction->end || want_debug_safety) {
            LLVMValueRef src_len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)len_index, "");
            prev_end = gen_load_untyped(g, src_len_ptr, 0, false, "");
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

        LLVMValueRef src_ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)ptr_index, "");
        LLVMValueRef src_ptr = gen_load_untyped(g, src_ptr_ptr, 0, false, "");
        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, (unsigned)ptr_index, "");
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, src_ptr, &start_val, (unsigned)len_index, "");
        gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, (unsigned)len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        gen_store_untyped(g, len_value, len_field_ptr, 0, false);

        return tmp_struct_ptr;
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef get_trap_fn_val(CodeGen *g) {
    if (g->trap_fn_val)
        return g->trap_fn_val;

    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), nullptr, 0, false);
    g->trap_fn_val = LLVMAddFunction(g->module, "llvm.debugtrap", fn_type);
    assert(LLVMGetIntrinsicID(g->trap_fn_val));

    return g->trap_fn_val;
}


static LLVMValueRef ir_render_breakpoint(CodeGen *g, IrExecutable *executable, IrInstructionBreakpoint *instruction) {
    LLVMBuildCall(g->builder, get_trap_fn_val(g), nullptr, 0, "");
    return nullptr;
}

static LLVMValueRef get_return_address_fn_val(CodeGen *g) {
    if (g->return_address_fn_val)
        return g->return_address_fn_val;

    TypeTableEntry *return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

    LLVMTypeRef fn_type = LLVMFunctionType(return_type->type_ref,
            &g->builtin_types.entry_i32->type_ref, 1, false);
    g->return_address_fn_val = LLVMAddFunction(g->module, "llvm.returnaddress", fn_type);
    assert(LLVMGetIntrinsicID(g->return_address_fn_val));

    return g->return_address_fn_val;
}

static LLVMValueRef ir_render_return_address(CodeGen *g, IrExecutable *executable,
        IrInstructionReturnAddress *instruction)
{
    LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->type_ref);
    return LLVMBuildCall(g->builder, get_return_address_fn_val(g), &zero, 1, "");
}

static LLVMValueRef get_frame_address_fn_val(CodeGen *g) {
    if (g->frame_address_fn_val)
        return g->frame_address_fn_val;

    TypeTableEntry *return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

    LLVMTypeRef fn_type = LLVMFunctionType(return_type->type_ref,
            &g->builtin_types.entry_i32->type_ref, 1, false);
    g->frame_address_fn_val = LLVMAddFunction(g->module, "llvm.frameaddress", fn_type);
    assert(LLVMGetIntrinsicID(g->frame_address_fn_val));

    return g->frame_address_fn_val;
}

static LLVMValueRef ir_render_frame_address(CodeGen *g, IrExecutable *executable,
        IrInstructionFrameAddress *instruction)
{
    LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->type_ref);
    return LLVMBuildCall(g->builder, get_frame_address_fn_val(g), &zero, 1, "");
}

static LLVMValueRef render_shl_with_overflow(CodeGen *g, IrInstructionOverflowOp *instruction) {
    TypeTableEntry *int_type = instruction->result_ptr_type;
    assert(int_type->id == TypeTableEntryIdInt);

    LLVMValueRef op1 = ir_llvm_value(g, instruction->op1);
    LLVMValueRef op2 = ir_llvm_value(g, instruction->op2);
    LLVMValueRef ptr_result = ir_llvm_value(g, instruction->result_ptr);

    LLVMValueRef op2_casted = gen_widen_or_shorten(g, false, instruction->op2->value.type,
            instruction->op1->value.type, op2);

    LLVMValueRef result = LLVMBuildShl(g->builder, op1, op2_casted, "");
    LLVMValueRef orig_val;
    if (int_type->data.integral.is_signed) {
        orig_val = LLVMBuildAShr(g->builder, result, op2_casted, "");
    } else {
        orig_val = LLVMBuildLShr(g->builder, result, op2_casted, "");
    }
    LLVMValueRef overflow_bit = LLVMBuildICmp(g->builder, LLVMIntNE, op1, orig_val, "");

    gen_store(g, result, ptr_result, instruction->result_ptr->value.type);

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

    TypeTableEntry *int_type = instruction->result_ptr_type;
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
    gen_store(g, result, ptr_result, instruction->result_ptr->value.type);

    return overflow_bit;
}

static LLVMValueRef ir_render_test_err(CodeGen *g, IrExecutable *executable, IrInstructionTestErr *instruction) {
    TypeTableEntry *err_union_type = instruction->value->value.type;
    TypeTableEntry *child_type = err_union_type->data.error.child_type;
    LLVMValueRef err_union_handle = ir_llvm_value(g, instruction->value);

    LLVMValueRef err_val;
    if (type_has_bits(child_type)) {
        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
        err_val = gen_load_untyped(g, err_val_ptr, 0, false, "");
    } else {
        err_val = err_union_handle;
    }

    LLVMValueRef zero = LLVMConstNull(g->err_tag_type->type_ref);
    return LLVMBuildICmp(g->builder, LLVMIntNE, err_val, zero, "");
}

static LLVMValueRef ir_render_unwrap_err_code(CodeGen *g, IrExecutable *executable, IrInstructionUnwrapErrCode *instruction) {
    TypeTableEntry *ptr_type = instruction->value->value.type;
    assert(ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *err_union_type = ptr_type->data.pointer.child_type;
    TypeTableEntry *child_type = err_union_type->data.error.child_type;
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->value);
    LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, ptr_type);

    if (type_has_bits(child_type)) {
        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
        return gen_load_untyped(g, err_val_ptr, 0, false, "");
    } else {
        return err_union_handle;
    }
}

static LLVMValueRef ir_render_unwrap_err_payload(CodeGen *g, IrExecutable *executable, IrInstructionUnwrapErrPayload *instruction) {
    TypeTableEntry *ptr_type = instruction->value->value.type;
    assert(ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *err_union_type = ptr_type->data.pointer.child_type;
    TypeTableEntry *child_type = err_union_type->data.error.child_type;
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->value);
    LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, ptr_type);

    if (ir_want_debug_safety(g, &instruction->base) && instruction->safety_check_on && g->error_decls.length > 1) {
        LLVMValueRef err_val;
        if (type_has_bits(child_type)) {
            LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
            err_val = gen_load_untyped(g, err_val_ptr, 0, false, "");
        } else {
            err_val = err_union_handle;
        }
        LLVMValueRef zero = LLVMConstNull(g->err_tag_type->type_ref);
        LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, zero, "");
        LLVMBasicBlockRef err_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrError");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrOk");
        LLVMBuildCondBr(g->builder, cond_val, ok_block, err_block);

        LLVMPositionBuilderAtEnd(g->builder, err_block);
        gen_debug_safety_crash_for_err(g, err_val);

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
    // child_type and instruction->value->value.type may differ by constness
    gen_assign_raw(g, val_ptr, get_pointer_to_type(g, child_type, false), payload_val);
    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, maybe_null_index, "");
    gen_store_untyped(g, LLVMConstAllOnes(LLVMInt1Type()), maybe_ptr, 0, false);

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
    gen_store_untyped(g, err_val, err_tag_ptr, 0, false);

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
    gen_store_untyped(g, ok_err_val, err_tag_ptr, 0, false);

    LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr, err_union_payload_index, "");
    gen_assign_raw(g, payload_ptr, get_pointer_to_type(g, child_type, false), payload_val);

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

    LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, enum_val, enum_type->data.enumeration.gen_tag_index, "");
    TypeTableEntry *ptr_type = get_pointer_to_type(g, tag_type, false);
    return get_handle_value(g, tag_field_ptr, tag_type, ptr_type);
}

static LLVMValueRef ir_render_init_enum(CodeGen *g, IrExecutable *executable, IrInstructionInitEnum *instruction) {
    TypeTableEntry *enum_type = instruction->enum_type;
    uint32_t value = instruction->field->value;
    LLVMTypeRef tag_type_ref = enum_type->data.enumeration.tag_type->type_ref;
    LLVMValueRef tag_value = LLVMConstInt(tag_type_ref, value, false);

    if (enum_type->data.enumeration.gen_field_count == 0)
        return tag_value;

    LLVMValueRef tmp_struct_ptr = instruction->tmp_ptr;

    LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, enum_type->data.enumeration.gen_tag_index, "");
    gen_store_untyped(g, tag_value, tag_field_ptr, 0, false);

    TypeTableEntry *union_val_type = instruction->field->type_entry;
    if (type_has_bits(union_val_type)) {
        LLVMValueRef new_union_val = ir_llvm_value(g, instruction->init_value);
        LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, enum_type->data.enumeration.gen_union_index, "");
        LLVMValueRef bitcasted_union_field_ptr = LLVMBuildBitCast(g->builder, union_field_ptr,
                LLVMPointerType(union_val_type->type_ref, 0), "");

        gen_assign_raw(g, bitcasted_union_field_ptr, get_pointer_to_type(g, union_val_type, false), new_union_val);
    }

    return tmp_struct_ptr;
}

static LLVMValueRef ir_render_struct_init(CodeGen *g, IrExecutable *executable, IrInstructionStructInit *instruction) {
    for (size_t i = 0; i < instruction->field_count; i += 1) {
        IrInstructionStructInitField *field = &instruction->fields[i];
        TypeStructField *type_struct_field = field->type_struct_field;
        if (!type_has_bits(type_struct_field->type_entry))
            continue;

        LLVMValueRef field_ptr = LLVMBuildStructGEP(g->builder, instruction->tmp_ptr,
                (unsigned)type_struct_field->gen_index, "");
        LLVMValueRef value = ir_llvm_value(g, field->value);

        uint32_t field_align_bytes = get_abi_alignment(g, type_struct_field->type_entry);

        TypeTableEntry *ptr_type = get_pointer_to_type_extra(g, type_struct_field->type_entry,
                false, false, field_align_bytes,
                (uint32_t)type_struct_field->packed_bits_offset, (uint32_t)type_struct_field->unaligned_bit_count);

        gen_assign_raw(g, field_ptr, ptr_type, value);
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
        gen_assign_raw(g, elem_ptr, get_pointer_to_type(g, child_type, false), elem_val);
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

    ZigLLVMSetCurrentDebugLocation(g->builder, (int)source_node->line + 1,
            (int)source_node->column + 1, get_di_scope(g, scope));
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
        case IrInstructionIdSetFloatMode:
        case IrInstructionIdArrayType:
        case IrInstructionIdSliceType:
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
        case IrInstructionIdCheckSwitchProngs:
        case IrInstructionIdCheckStatementIsVoid:
        case IrInstructionIdTypeName:
        case IrInstructionIdCanImplicitCast:
        case IrInstructionIdSetGlobalSection:
        case IrInstructionIdSetGlobalLinkage:
        case IrInstructionIdDeclRef:
        case IrInstructionIdSwitchVar:
        case IrInstructionIdOffsetOf:
        case IrInstructionIdTypeId:
        case IrInstructionIdSetEvalBranchQuota:
        case IrInstructionIdPtrTypeOf:
        case IrInstructionIdOpaqueType:
        case IrInstructionIdSetAlignStack:
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
        case IrInstructionIdTruncate:
            return ir_render_truncate(g, executable, (IrInstructionTruncate *)instruction);
        case IrInstructionIdBoolNot:
            return ir_render_bool_not(g, executable, (IrInstructionBoolNot *)instruction);
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
        case IrInstructionIdPtrCast:
            return ir_render_ptr_cast(g, executable, (IrInstructionPtrCast *)instruction);
        case IrInstructionIdBitCast:
            return ir_render_bit_cast(g, executable, (IrInstructionBitCast *)instruction);
        case IrInstructionIdWidenOrShorten:
            return ir_render_widen_or_shorten(g, executable, (IrInstructionWidenOrShorten *)instruction);
        case IrInstructionIdPtrToInt:
            return ir_render_ptr_to_int(g, executable, (IrInstructionPtrToInt *)instruction);
        case IrInstructionIdIntToPtr:
            return ir_render_int_to_ptr(g, executable, (IrInstructionIntToPtr *)instruction);
        case IrInstructionIdIntToEnum:
            return ir_render_int_to_enum(g, executable, (IrInstructionIntToEnum *)instruction);
        case IrInstructionIdIntToErr:
            return ir_render_int_to_err(g, executable, (IrInstructionIntToErr *)instruction);
        case IrInstructionIdErrToInt:
            return ir_render_err_to_int(g, executable, (IrInstructionErrToInt *)instruction);
        case IrInstructionIdContainerInitList:
            return ir_render_container_init_list(g, executable, (IrInstructionContainerInitList *)instruction);
        case IrInstructionIdPanic:
            return ir_render_panic(g, executable, (IrInstructionPanic *)instruction);
        case IrInstructionIdEnumTagName:
            return ir_render_enum_tag_name(g, executable, (IrInstructionEnumTagName *)instruction);
        case IrInstructionIdFieldParentPtr:
            return ir_render_field_parent_ptr(g, executable, (IrInstructionFieldParentPtr *)instruction);
        case IrInstructionIdAlignCast:
            return ir_render_align_cast(g, executable, (IrInstructionAlignCast *)instruction);
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
            return val->global_refs->llvm_global;
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
    expand_undef_array(g, array_const_val);
    ConstParent *parent = &array_const_val->data.x_array.s_none.parent;
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

    TypeTableEntry *type_entry = const_val->type;
    assert(!type_entry->zero_bits);
    switch (type_entry->id) {
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
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdOpaque:
            zig_unreachable();
        case TypeTableEntryIdBool:
            return LLVMConstInt(big_int_type_ref, const_val->data.x_bool ? 1 : 0, false);
        case TypeTableEntryIdInt:
            {
                LLVMValueRef int_val = gen_const_val(g, const_val);
                return LLVMConstZExt(int_val, big_int_type_ref);
            }
        case TypeTableEntryIdFloat:
            {
                LLVMValueRef float_val = gen_const_val(g, const_val);
                LLVMValueRef int_val = LLVMConstFPToUI(float_val,
                        LLVMIntType((unsigned)type_entry->data.floating.bit_count));
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
                assert(type_entry->data.structure.layout == ContainerLayoutPacked);

                LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
                for (size_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
                    TypeStructField *field = &type_entry->data.structure.fields[i];
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
    TypeTableEntry *type_entry = const_val->type;
    assert(!type_entry->zero_bits);

    switch (const_val->special) {
        case ConstValSpecialRuntime:
            zig_unreachable();
        case ConstValSpecialUndef:
            return LLVMGetUndef(type_entry->type_ref);
        case ConstValSpecialStatic:
            break;
    }

    switch (type_entry->id) {
        case TypeTableEntryIdInt:
        case TypeTableEntryIdEnumTag:
            return bigint_to_llvm_const(type_entry->type_ref, &const_val->data.x_bigint);
        case TypeTableEntryIdPureError:
            assert(const_val->data.x_pure_err);
            return LLVMConstInt(g->builtin_types.entry_pure_error->type_ref,
                    const_val->data.x_pure_err->value, false);
        case TypeTableEntryIdFloat:
            switch (type_entry->data.floating.bit_count) {
                case 32:
                    return LLVMConstReal(type_entry->type_ref, const_val->data.x_f32);
                case 64:
                    return LLVMConstReal(type_entry->type_ref, const_val->data.x_f64);
                case 128:
                    {
                        // TODO make sure this is correct on big endian targets too
                        uint8_t buf[16];
                        memcpy(buf, &const_val->data.x_f128, 16);
                        LLVMValueRef as_int = LLVMConstIntOfArbitraryPrecision(LLVMInt128Type(), 2,
                                (uint64_t*)buf);
                        return LLVMConstBitCast(as_int, type_entry->type_ref);
                    }
                default:
                    zig_unreachable();
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
                LLVMValueRef *fields = allocate<LLVMValueRef>(type_entry->data.structure.gen_field_count);
                size_t src_field_count = type_entry->data.structure.src_field_count;
                if (type_entry->data.structure.layout == ContainerLayoutPacked) {
                    size_t src_field_index = 0;
                    while (src_field_index < src_field_count) {
                        TypeStructField *type_struct_field = &type_entry->data.structure.fields[src_field_index];
                        if (type_struct_field->gen_index == SIZE_MAX) {
                            src_field_index += 1;
                            continue;
                        }

                        size_t src_field_index_end = src_field_index + 1;
                        for (; src_field_index_end < src_field_count; src_field_index_end += 1) {
                            TypeStructField *it_field = &type_entry->data.structure.fields[src_field_index_end];
                            if (it_field->gen_index != type_struct_field->gen_index)
                                break;
                        }

                        if (src_field_index + 1 == src_field_index_end) {
                            fields[type_struct_field->gen_index] =
                                gen_const_val(g, &const_val->data.x_struct.fields[src_field_index]);
                        } else {
                            LLVMTypeRef big_int_type_ref = LLVMStructGetTypeAtIndex(type_entry->type_ref,
                                    (unsigned)type_struct_field->gen_index);
                            LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
                            for (size_t i = src_field_index; i < src_field_index_end; i += 1) {
                                TypeStructField *it_field = &type_entry->data.structure.fields[i];
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
                        TypeStructField *type_struct_field = &type_entry->data.structure.fields[i];
                        if (type_struct_field->gen_index == SIZE_MAX) {
                            continue;
                        }
                        fields[type_struct_field->gen_index] = gen_const_val(g, &const_val->data.x_struct.fields[i]);
                    }
                }
                return LLVMConstStruct(fields, type_entry->data.structure.gen_field_count,
                    type_entry->data.structure.layout == ContainerLayoutPacked);
            }
        case TypeTableEntryIdUnion:
            {
                zig_panic("TODO");
            }
        case TypeTableEntryIdArray:
            {
                uint64_t len = type_entry->data.array.len;
                if (const_val->data.x_array.special == ConstArraySpecialUndef) {
                    return LLVMGetUndef(type_entry->type_ref);
                }

                LLVMValueRef *values = allocate<LLVMValueRef>(len);
                for (uint64_t i = 0; i < len; i += 1) {
                    ConstExprValue *elem_value = &const_val->data.x_array.s_none.elements[i];
                    values[i] = gen_const_val(g, elem_value);
                }
                return LLVMConstArray(LLVMTypeOf(values[0]), values, (unsigned)len);
            }
        case TypeTableEntryIdEnum:
            {
                LLVMTypeRef tag_type_ref = type_entry->data.enumeration.tag_type->type_ref;
                LLVMValueRef tag_value = LLVMConstInt(tag_type_ref, const_val->data.x_enum.tag, false);
                if (type_entry->data.enumeration.gen_field_count == 0) {
                    return tag_value;
                } else {
                    LLVMTypeRef union_type_ref = type_entry->data.enumeration.union_type_ref;
                    TypeEnumField *enum_field = &type_entry->data.enumeration.fields[const_val->data.x_enum.tag];
                    assert(enum_field->value == const_val->data.x_enum.tag);
                    LLVMValueRef union_value;
                    if (type_has_bits(enum_field->type_entry)) {
                        uint64_t union_type_bytes = LLVMStoreSizeOfType(g->target_data_ref,
                                union_type_ref);
                        uint64_t field_type_bytes = LLVMStoreSizeOfType(g->target_data_ref,
                                enum_field->type_entry->type_ref);
                        uint64_t pad_bytes = union_type_bytes - field_type_bytes;

                        LLVMValueRef correctly_typed_value = gen_const_val(g, const_val->data.x_enum.payload);
                        if (pad_bytes == 0) {
                            union_value = correctly_typed_value;
                        } else {
                            LLVMValueRef fields[] = {
                                correctly_typed_value,
                                LLVMGetUndef(LLVMArrayType(LLVMInt8Type(), (unsigned)pad_bytes)),
                            };
                            union_value = LLVMConstStruct(fields, 2, false);
                        }
                    } else {
                        union_value = LLVMGetUndef(union_type_ref);
                    }
                    LLVMValueRef fields[2];
                    fields[type_entry->data.enumeration.gen_tag_index] = tag_value;
                    fields[type_entry->data.enumeration.gen_union_index] = union_value;
                    return LLVMConstStruct(fields, 2, false);
                }
            }
        case TypeTableEntryIdFn:
            return fn_llvm_value(g, const_val->data.x_fn.fn_entry);
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
                            const_val->global_refs->llvm_value = LLVMConstBitCast(other_val->global_refs->llvm_global, const_val->type->type_ref);
                            render_const_val_global(g, const_val, "");
                            return const_val->global_refs->llvm_value;
                        }
                    case ConstPtrSpecialBaseArray:
                        {
                            ConstExprValue *array_const_val = const_val->data.x_ptr.data.base_array.array_val;
                            size_t elem_index = const_val->data.x_ptr.data.base_array.elem_index;
                            assert(array_const_val->type->id == TypeTableEntryIdArray);
                            if (array_const_val->type->zero_bits) {
                                // make this a null pointer
                                TypeTableEntry *usize = g->builtin_types.entry_usize;
                                const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->type_ref),
                                        const_val->type->type_ref);
                                render_const_val_global(g, const_val, "");
                                return const_val->global_refs->llvm_value;
                            }
                            LLVMValueRef uncasted_ptr_val = gen_const_ptr_array_recursive(g, array_const_val,
                                    elem_index);
                            LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, const_val->type->type_ref);
                            const_val->global_refs->llvm_value = ptr_val;
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
                                const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->type_ref),
                                        const_val->type->type_ref);
                                render_const_val_global(g, const_val, "");
                                return const_val->global_refs->llvm_value;
                            }
                            size_t src_field_index = const_val->data.x_ptr.data.base_struct.field_index;
                            size_t gen_field_index =
                                struct_const_val->type->data.structure.fields[src_field_index].gen_index;
                            LLVMValueRef uncasted_ptr_val = gen_const_ptr_struct_recursive(g, struct_const_val,
                                    gen_field_index);
                            LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, const_val->type->type_ref);
                            const_val->global_refs->llvm_value = ptr_val;
                            render_const_val_global(g, const_val, "");
                            return ptr_val;
                        }
                    case ConstPtrSpecialHardCodedAddr:
                        {
                            uint64_t addr_value = const_val->data.x_ptr.data.hard_coded_addr.addr;
                            TypeTableEntry *usize = g->builtin_types.entry_usize;
                            const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstInt(usize->type_ref, addr_value, false),
                                    const_val->type->type_ref);
                            render_const_val_global(g, const_val, "");
                            return const_val->global_refs->llvm_value;
                        }
                }
            }
        case TypeTableEntryIdErrorUnion:
            {
                TypeTableEntry *child_type = type_entry->data.error.child_type;
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
        case TypeTableEntryIdOpaque:
            zig_unreachable();

    }
    zig_unreachable();
}

static void render_const_val(CodeGen *g, ConstExprValue *const_val) {
    if (!const_val->global_refs)
        const_val->global_refs = allocate<ConstGlobalRefs>(1);
    if (!const_val->global_refs->llvm_value)
        const_val->global_refs->llvm_value = gen_const_val(g, const_val);

    if (const_val->global_refs->llvm_global)
        LLVMSetInitializer(const_val->global_refs->llvm_global, const_val->global_refs->llvm_value);
}

static void render_const_val_global(CodeGen *g, ConstExprValue *const_val, const char *name) {
    if (!const_val->global_refs)
        const_val->global_refs = allocate<ConstGlobalRefs>(1);

    if (!const_val->global_refs->llvm_global) {
        LLVMTypeRef type_ref = const_val->global_refs->llvm_value ? LLVMTypeOf(const_val->global_refs->llvm_value) : const_val->type->type_ref;
        LLVMValueRef global_value = LLVMAddGlobal(g->module, type_ref, name);
        LLVMSetLinkage(global_value, LLVMInternalLinkage);
        LLVMSetGlobalConstant(global_value, true);
        LLVMSetUnnamedAddr(global_value, true);
        LLVMSetAlignment(global_value, get_abi_alignment(g, const_val->type));

        const_val->global_refs->llvm_global = global_value;
    }

    if (const_val->global_refs->llvm_value)
        LLVMSetInitializer(const_val->global_refs->llvm_global, const_val->global_refs->llvm_value);
}

static void generate_error_name_table(CodeGen *g) {
    if (g->err_name_table != nullptr || !g->generate_error_name_table || g->error_decls.length == 1) {
        return;
    }

    assert(g->error_decls.length > 0);

    TypeTableEntry *u8_ptr_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);
    TypeTableEntry *str_type = get_slice_type(g, u8_ptr_type);

    LLVMValueRef *values = allocate<LLVMValueRef>(g->error_decls.length);
    values[0] = LLVMGetUndef(str_type->type_ref);
    for (size_t i = 1; i < g->error_decls.length; i += 1) {
        AstNode *error_decl_node = g->error_decls.at(i);
        assert(error_decl_node->type == NodeTypeErrorValueDecl);
        Buf *name = error_decl_node->data.error_value_decl.name;

        g->largest_err_name_len = max(g->largest_err_name_len, buf_len(name));

        LLVMValueRef str_init = LLVMConstString(buf_ptr(name), (unsigned)buf_len(name), true);
        LLVMValueRef str_global = LLVMAddGlobal(g->module, LLVMTypeOf(str_init), "");
        LLVMSetInitializer(str_global, str_init);
        LLVMSetLinkage(str_global, LLVMPrivateLinkage);
        LLVMSetGlobalConstant(str_global, true);
        LLVMSetUnnamedAddr(str_global, true);
        LLVMSetAlignment(str_global, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(str_init)));

        LLVMValueRef fields[] = {
            LLVMConstBitCast(str_global, u8_ptr_type->type_ref),
            LLVMConstInt(g->builtin_types.entry_usize->type_ref, buf_len(name), false),
        };
        values[i] = LLVMConstNamedStruct(str_type->type_ref, fields, 2);
    }

    LLVMValueRef err_name_table_init = LLVMConstArray(str_type->type_ref, values, (unsigned)g->error_decls.length);

    g->err_name_table = LLVMAddGlobal(g->module, LLVMTypeOf(err_name_table_init),
            buf_ptr(get_mangled_name(g, buf_create_from_str("__zig_err_name_table"), false)));
    LLVMSetInitializer(g->err_name_table, err_name_table_init);
    LLVMSetLinkage(g->err_name_table, LLVMPrivateLinkage);
    LLVMSetGlobalConstant(g->err_name_table, true);
    LLVMSetUnnamedAddr(g->err_name_table, true);
    LLVMSetAlignment(g->err_name_table, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(err_name_table_init)));
}

static void generate_enum_name_tables(CodeGen *g) {
    TypeTableEntry *u8_ptr_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);
    TypeTableEntry *str_type = get_slice_type(g, u8_ptr_type);

    for (size_t enum_i = 0; enum_i < g->name_table_enums.length; enum_i += 1) {
        TypeTableEntry *enum_tag_type = g->name_table_enums.at(enum_i);
        assert(enum_tag_type->id == TypeTableEntryIdEnumTag);
        TypeTableEntry *enum_type = enum_tag_type->data.enum_tag.enum_type;

        size_t field_count = enum_type->data.enumeration.src_field_count;
        LLVMValueRef *values = allocate<LLVMValueRef>(field_count);
        for (size_t field_i = 0; field_i < field_count; field_i += 1) {
            Buf *name = enum_type->data.enumeration.fields[field_i].name;

            LLVMValueRef str_init = LLVMConstString(buf_ptr(name), (unsigned)buf_len(name), true);
            LLVMValueRef str_global = LLVMAddGlobal(g->module, LLVMTypeOf(str_init), "");
            LLVMSetInitializer(str_global, str_init);
            LLVMSetLinkage(str_global, LLVMPrivateLinkage);
            LLVMSetGlobalConstant(str_global, true);
            LLVMSetUnnamedAddr(str_global, true);
            LLVMSetAlignment(str_global, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(str_init)));

            LLVMValueRef fields[] = {
                LLVMConstBitCast(str_global, u8_ptr_type->type_ref),
                LLVMConstInt(g->builtin_types.entry_usize->type_ref, buf_len(name), false),
            };
            values[field_i] = LLVMConstNamedStruct(str_type->type_ref, fields, 2);
        }

        LLVMValueRef name_table_init = LLVMConstArray(str_type->type_ref, values, (unsigned)field_count);

        Buf *table_name = get_mangled_name(g, buf_sprintf("%s_name_table", buf_ptr(&enum_type->name)), false);
        LLVMValueRef name_table = LLVMAddGlobal(g->module, LLVMTypeOf(name_table_init), buf_ptr(table_name));
        LLVMSetInitializer(name_table, name_table_init);
        LLVMSetLinkage(name_table, LLVMPrivateLinkage);
        LLVMSetGlobalConstant(name_table, true);
        LLVMSetUnnamedAddr(name_table, true);
        LLVMSetAlignment(name_table, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(name_table_init)));
        enum_tag_type->data.enum_tag.name_table = name_table;
    }
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
    if (g->strip_debug_symbols) {
        return;
    }

    assert(var->gen_is_const);
    assert(type_entry);

    ImportTableEntry *import = get_scope_import(var->parent_scope);
    assert(import);

    bool is_local_to_unit = true;
    ZigLLVMCreateGlobalVariable(g->dbuilder, get_di_scope(g, var->parent_scope), buf_ptr(&var->name),
        buf_ptr(&var->name), import->di_file,
        (unsigned)(var->decl_node->line + 1),
        type_entry->di_type, is_local_to_unit);

    // TODO ^^ make an actual global variable
}

static LLVMValueRef build_alloca(CodeGen *g, TypeTableEntry *type_entry, const char *name, uint32_t alignment) {
    assert(alignment > 0);
    LLVMValueRef result = LLVMBuildAlloca(g->builder, type_entry->type_ref, name);
    LLVMSetAlignment(result, alignment);
    return result;
}

static void ensure_cache_dir(CodeGen *g) {
    int err;
    if ((err = os_make_path(g->cache_dir))) {
        zig_panic("unable to make cache dir: %s", err_str(err));
    }
}

static void report_errors_and_maybe_exit(CodeGen *g) {
    if (g->errors.length != 0) {
        for (size_t i = 0; i < g->errors.length; i += 1) {
            ErrorMsg *err = g->errors.at(i);
            print_err_msg(err, g->err_color);
        }
        exit(1);
    }
}

static void validate_inline_fns(CodeGen *g) {
    for (size_t i = 0; i < g->inline_fns.length; i += 1) {
        FnTableEntry *fn_entry = g->inline_fns.at(i);
        LLVMValueRef fn_val = LLVMGetNamedFunction(g->module, fn_entry->llvm_name);
        if (fn_val != nullptr) {
            add_node_error(g, fn_entry->proto_node, buf_sprintf("unable to inline function"));
        }
    }
    report_errors_and_maybe_exit(g);
}

static void do_code_gen(CodeGen *g) {
    if (g->verbose) {
        fprintf(stderr, "\nCode Generation:\n");
        fprintf(stderr, "------------------\n");
    }
    assert(!g->errors.length);

    codegen_add_time_event(g, "Code Generation");

    generate_error_name_table(g);
    generate_enum_name_tables(g);

    // Generate module level variables
    for (size_t i = 0; i < g->global_vars.length; i += 1) {
        TldVar *tld_var = g->global_vars.at(i);
        VariableTableEntry *var = tld_var->var;

        if (var->value->type->id == TypeTableEntryIdNumLitFloat) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = var->value;
            assert(const_val->special != ConstValSpecialRuntime);
            TypeTableEntry *var_type = g->builtin_types.entry_f128;
            ConstExprValue coerced_value;
            coerced_value.special = ConstValSpecialStatic;
            coerced_value.type = var_type;
            coerced_value.data.x_f128 = bigfloat_to_f128(&const_val->data.x_bigfloat);
            LLVMValueRef init_val = gen_const_val(g, &coerced_value);
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (var->value->type->id == TypeTableEntryIdNumLitInt) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = var->value;
            assert(const_val->special != ConstValSpecialRuntime);
            size_t bits_needed = bigint_bits_needed(&const_val->data.x_bigint);
            if (bits_needed < 8) {
                bits_needed = 8;
            }
            TypeTableEntry *var_type = get_int_type(g, const_val->data.x_bigint.is_negative, bits_needed);
            LLVMValueRef init_val = bigint_to_llvm_const(var_type->type_ref, &const_val->data.x_bigint);
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
            LLVMSetAlignment(global_value, var->align_bytes);
        } else {
            bool exported = (var->linkage == VarLinkageExport);
            render_const_val(g, var->value);
            render_const_val_global(g, var->value, buf_ptr(get_mangled_name(g, &var->name, exported)));
            global_value = var->value->global_refs->llvm_global;

            if (exported) {
                LLVMSetLinkage(global_value, LLVMExternalLinkage);
            }
            if (tld_var->section_name) {
                LLVMSetSection(global_value, buf_ptr(tld_var->section_name));
            }
            LLVMSetAlignment(global_value, var->align_bytes);

            // TODO debug info for function pointers
            if (var->gen_is_const && var->value->type->id != TypeTableEntryIdFn) {
                gen_global_var(g, var, var->value->global_refs->llvm_value, var->value->type);
            }
        }

        LLVMSetGlobalConstant(global_value, var->gen_is_const);

        var->value_ref = global_value;
    }

    // Generate function prototypes
    for (size_t fn_proto_i = 0; fn_proto_i < g->fn_protos.length; fn_proto_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_protos.at(fn_proto_i);

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
                calling_convention_does_first_arg_return(fn_type->data.fn.fn_type_id.cc))
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
                addLLVMArgAttr(fn_val, (unsigned)gen_index, "noalias");
            }
            if ((param_type->id == TypeTableEntryIdPointer && param_type->data.pointer.is_const) || is_byval) {
                addLLVMArgAttr(fn_val, (unsigned)gen_index, "readonly");
            }
            if (param_type->id == TypeTableEntryIdPointer) {
                addLLVMArgAttr(fn_val, (unsigned)gen_index, "nonnull");
            }
            if (is_byval) {
                addLLVMArgAttr(fn_val, (unsigned)gen_index, "byval");
            }
        }
    }

    // Generate function definitions.
    for (size_t fn_i = 0; fn_i < g->fn_defs.length; fn_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(fn_i);

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
            *slot = build_alloca(g, slot_type, "", get_abi_alignment(g, slot_type));
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
                var->value_ref = build_alloca(g, var->value->type, buf_ptr(&var->name), var->align_bytes);

                var->di_loc_var = ZigLLVMCreateAutoVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                        buf_ptr(&var->name), import->di_file, (unsigned)(var->decl_node->line + 1),
                        var->value->type->di_type, !g->strip_debug_symbols, 0);

            } else {
                assert(var->gen_arg_index != SIZE_MAX);
                TypeTableEntry *gen_type;
                FnGenParamInfo *gen_info = &fn_table_entry->type_entry->data.fn.gen_param_info[var->src_arg_index];

                if (handle_is_ptr(var->value->type)) {
                    if (gen_info->is_byval) {
                        gen_type = var->value->type;
                    } else {
                        gen_type = gen_info->type;
                    }
                    var->value_ref = LLVMGetParam(fn, (unsigned)var->gen_arg_index);
                } else {
                    gen_type = var->value->type;
                    var->value_ref = build_alloca(g, var->value->type, buf_ptr(&var->name), var->align_bytes);
                }
                if (var->decl_node) {
                    var->di_loc_var = ZigLLVMCreateParameterVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                            buf_ptr(&var->name), import->di_file,
                            (unsigned)(var->decl_node->line + 1),
                            gen_type->di_type, !g->strip_debug_symbols, 0, (unsigned)(var->gen_arg_index + 1));
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
                gen_store_untyped(g, LLVMGetParam(fn, (unsigned)variable->gen_arg_index), variable->value_ref,
                        variable->align_bytes, false);
            }

            if (variable->decl_node) {
                gen_var_debug_decl(g, variable);
            }
        }

        ir_render(g, fn_table_entry);

    }
    assert(!g->errors.length);

    if (buf_len(&g->global_asm) != 0) {
        LLVMSetModuleInlineAsm(g->module, buf_ptr(&g->global_asm));
    }

    ZigLLVMDIBuilderFinalize(g->dbuilder);

    if (g->verbose || g->verbose_ir) {
        LLVMDumpModule(g->module);
    }

    // in release mode, we're sooooo confident that we've generated correct ir,
    // that we skip the verify module step in order to get better performance.
#ifndef NDEBUG
    char *error = nullptr;
    LLVMVerifyModule(g->module, LLVMAbortProcessAction, &error);
#endif

    codegen_add_time_event(g, "LLVM Emit Object");

    char *err_msg = nullptr;
    Buf *o_basename = buf_create_from_buf(g->root_out_name);
    const char *o_ext = target_o_file_ext(&g->zig_target);
    buf_append_str(o_basename, o_ext);
    Buf *output_path = buf_alloc();
    os_path_join(g->cache_dir, o_basename, output_path);
    ensure_cache_dir(g);
    if (ZigLLVMTargetMachineEmitToFile(g->target_machine, g->module, buf_ptr(output_path),
                LLVMObjectFile, &err_msg, g->build_mode == BuildModeDebug))
    {
        zig_panic("unable to write object file: %s", err_msg);
    }

    validate_inline_fns(g);

    g->link_objects.append(output_path);
}

static const uint8_t int_sizes_in_bits[] = {
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    16,
    32,
    64,
    128,
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
        entry->zero_bits = true;
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
        uint8_t size_in_bits = int_sizes_in_bits[int_size_i];
        for (size_t is_sign_i = 0; is_sign_i < array_length(is_signed_list); is_sign_i += 1) {
            bool is_signed = is_signed_list[is_sign_i];
            TypeTableEntry *entry = make_int_type(g, is_signed, size_in_bits);
            g->primitive_type_table.put(&entry->name, entry);
            get_int_type_ptr(g, is_signed, size_in_bits)[0] = entry;
        }
    }

    for (size_t i = 0; i < array_length(c_int_type_infos); i += 1) {
        const CIntTypeInfo *info = &c_int_type_infos[i];
        uint32_t size_in_bits = target_c_type_size_in_bits(&g->zig_target, info->id);
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
        entry->type_ref = LLVMFP128Type();
        buf_init_from_str(&entry->name, "f128");
        entry->data.floating.bit_count = 128;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
        g->builtin_types.entry_f128 = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->type_ref = LLVMX86FP80Type();
        buf_init_from_str(&entry->name, "c_longdouble");
        entry->data.floating.bit_count = 80;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                debug_size_in_bits,
                ZigLLVMEncoding_DW_ATE_float());
        g->builtin_types.entry_c_longdouble = entry;
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
    g->builtin_types.entry_u128 = get_int_type(g, false, 128);
    g->builtin_types.entry_i8 = get_int_type(g, true, 8);
    g->builtin_types.entry_i16 = get_int_type(g, true, 16);
    g->builtin_types.entry_i32 = get_int_type(g, true, 32);
    g->builtin_types.entry_i64 = get_int_type(g, true, 64);
    g->builtin_types.entry_i128 = get_int_type(g, true, 128);

    {
        g->builtin_types.entry_c_void = get_opaque_type(g, nullptr, nullptr, "c_void");
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
    create_builtin_fn(g, BuiltinFnIdBreakpoint, "breakpoint", 0);
    create_builtin_fn(g, BuiltinFnIdReturnAddress, "returnAddress", 0);
    create_builtin_fn(g, BuiltinFnIdFrameAddress, "frameAddress", 0);
    create_builtin_fn(g, BuiltinFnIdMemcpy, "memcpy", 3);
    create_builtin_fn(g, BuiltinFnIdMemset, "memset", 3);
    create_builtin_fn(g, BuiltinFnIdSizeof, "sizeOf", 1);
    create_builtin_fn(g, BuiltinFnIdAlignOf, "alignOf", 1);
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
    create_builtin_fn(g, BuiltinFnIdCtz, "ctz", 1);
    create_builtin_fn(g, BuiltinFnIdClz, "clz", 1);
    create_builtin_fn(g, BuiltinFnIdImport, "import", 1);
    create_builtin_fn(g, BuiltinFnIdCImport, "cImport", 1);
    create_builtin_fn(g, BuiltinFnIdErrName, "errorName", 1);
    create_builtin_fn(g, BuiltinFnIdTypeName, "typeName", 1);
    create_builtin_fn(g, BuiltinFnIdCanImplicitCast, "canImplicitCast", 2);
    create_builtin_fn(g, BuiltinFnIdEmbedFile, "embedFile", 1);
    create_builtin_fn(g, BuiltinFnIdCmpExchange, "cmpxchg", 5);
    create_builtin_fn(g, BuiltinFnIdFence, "fence", 1);
    create_builtin_fn(g, BuiltinFnIdTruncate, "truncate", 2);
    create_builtin_fn(g, BuiltinFnIdCompileErr, "compileError", 1);
    create_builtin_fn(g, BuiltinFnIdCompileLog, "compileLog", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdIntType, "IntType", 2);
    create_builtin_fn(g, BuiltinFnIdSetDebugSafety, "setDebugSafety", 2);
    create_builtin_fn(g, BuiltinFnIdSetFloatMode, "setFloatMode", 2);
    create_builtin_fn(g, BuiltinFnIdSetGlobalSection, "setGlobalSection", 2);
    create_builtin_fn(g, BuiltinFnIdSetGlobalLinkage, "setGlobalLinkage", 2);
    create_builtin_fn(g, BuiltinFnIdPanic, "panic", 1);
    create_builtin_fn(g, BuiltinFnIdPtrCast, "ptrCast", 2);
    create_builtin_fn(g, BuiltinFnIdBitCast, "bitCast", 2);
    create_builtin_fn(g, BuiltinFnIdIntToPtr, "intToPtr", 2);
    create_builtin_fn(g, BuiltinFnIdPtrToInt, "ptrToInt", 1);
    create_builtin_fn(g, BuiltinFnIdEnumTagName, "enumTagName", 1);
    create_builtin_fn(g, BuiltinFnIdFieldParentPtr, "fieldParentPtr", 3);
    create_builtin_fn(g, BuiltinFnIdOffsetOf, "offsetOf", 2);
    create_builtin_fn(g, BuiltinFnIdDivExact, "divExact", 2);
    create_builtin_fn(g, BuiltinFnIdDivTrunc, "divTrunc", 2);
    create_builtin_fn(g, BuiltinFnIdDivFloor, "divFloor", 2);
    create_builtin_fn(g, BuiltinFnIdRem, "rem", 2);
    create_builtin_fn(g, BuiltinFnIdMod, "mod", 2);
    create_builtin_fn(g, BuiltinFnIdInlineCall, "inlineCall", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdTypeId, "typeId", 1);
    create_builtin_fn(g, BuiltinFnIdShlExact, "shlExact", 2);
    create_builtin_fn(g, BuiltinFnIdShrExact, "shrExact", 2);
    create_builtin_fn(g, BuiltinFnIdSetEvalBranchQuota, "setEvalBranchQuota", 1);
    create_builtin_fn(g, BuiltinFnIdAlignCast, "alignCast", 2);
    create_builtin_fn(g, BuiltinFnIdOpaqueType, "OpaqueType", 0);
    create_builtin_fn(g, BuiltinFnIdSetAlignStack, "setAlignStack", 1);
}

static const char *bool_to_str(bool b) {
    return b ? "true" : "false";
}

static const char *build_mode_to_str(BuildMode build_mode) {
    switch (build_mode) {
        case BuildModeDebug: return "Mode.Debug";
        case BuildModeSafeRelease: return "Mode.ReleaseSafe";
        case BuildModeFastRelease: return "Mode.ReleaseFast";
    }
    zig_unreachable();
}

static void define_builtin_compile_vars(CodeGen *g) {
    if (g->std_package == nullptr)
        return;

    const char *builtin_zig_basename = "builtin.zig";
    Buf *builtin_zig_path = buf_alloc();
    os_path_join(g->cache_dir, buf_create_from_str(builtin_zig_basename), builtin_zig_path);
    Buf *contents = buf_alloc();

    const char *cur_os = nullptr;
    {
        buf_appendf(contents, "pub const Os = enum {\n");
        uint32_t field_count = (uint32_t)target_os_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            ZigLLVM_OSType os_type = get_target_os(i);
            const char *name = get_target_os_name(os_type);
            buf_appendf(contents, "    %s,\n", name);

            if (os_type == g->zig_target.os) {
                g->target_os_index = i;
                cur_os = name;
            }
        }
        buf_appendf(contents, "};\n\n");
    }
    assert(cur_os != nullptr);

    const char *cur_arch = nullptr;
    {
        buf_appendf(contents, "pub const Arch = enum {\n");
        uint32_t field_count = (uint32_t)target_arch_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            const ArchType *arch_type = get_target_arch(i);
            Buf *arch_name = buf_alloc();
            buf_resize(arch_name, 50);
            get_arch_name(buf_ptr(arch_name), arch_type);
            buf_resize(arch_name, strlen(buf_ptr(arch_name)));

            buf_appendf(contents, "    %s,\n", buf_ptr(arch_name));

            if (arch_type->arch == g->zig_target.arch.arch &&
                arch_type->sub_arch == g->zig_target.arch.sub_arch)
            {
                g->target_arch_index = i;
                cur_arch = buf_ptr(arch_name);
            }
        }
        buf_appendf(contents, "};\n\n");
    }
    assert(cur_arch != nullptr);

    const char *cur_environ = nullptr;
    {
        buf_appendf(contents, "pub const Environ = enum {\n");
        uint32_t field_count = (uint32_t)target_environ_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            ZigLLVM_EnvironmentType environ_type = get_target_environ(i);
            const char *name = ZigLLVMGetEnvironmentTypeName(environ_type);
            buf_appendf(contents, "    %s,\n", name);

            if (environ_type == g->zig_target.env_type) {
                g->target_environ_index = i;
                cur_environ = name;
            }
        }
        buf_appendf(contents, "};\n\n");
    }
    assert(cur_environ != nullptr);

    const char *cur_obj_fmt = nullptr;
    {
        buf_appendf(contents, "pub const ObjectFormat = enum {\n");
        uint32_t field_count = (uint32_t)target_oformat_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            ZigLLVM_ObjectFormatType oformat = get_target_oformat(i);
            const char *name = get_target_oformat_name(oformat);
            buf_appendf(contents, "    %s,\n", name);

            if (oformat == g->zig_target.oformat) {
                g->target_oformat_index = i;
                cur_obj_fmt = name;
            }
        }

        buf_appendf(contents, "};\n\n");
    }
    assert(cur_obj_fmt != nullptr);

    {
        buf_appendf(contents, "pub const GlobalLinkage = enum {\n");
        uint32_t field_count = array_length(global_linkage_values);
        for (uint32_t i = 0; i < field_count; i += 1) {
            const GlobalLinkageValue *value = &global_linkage_values[i];
            buf_appendf(contents, "    %s,\n", value->name);
        }
        buf_appendf(contents, "};\n\n");
    }
    {
        buf_appendf(contents,
            "pub const AtomicOrder = enum {\n"
            "    Unordered,\n"
            "    Monotonic,\n"
            "    Acquire,\n"
            "    Release,\n"
            "    AcqRel,\n"
            "    SeqCst,\n"
            "};\n\n");
    }
    {
        buf_appendf(contents,
            "pub const Mode = enum {\n"
            "    Debug,\n"
            "    ReleaseSafe,\n"
            "    ReleaseFast,\n"
            "};\n\n");
    }
    {
        buf_appendf(contents, "pub const TypeId = enum {\n");
        size_t field_count = type_id_len();
        for (size_t i = 0; i < field_count; i += 1) {
            const TypeTableEntryId id = type_id_at_index(i);
            buf_appendf(contents, "    %s,\n", type_id_name(id));
        }
        buf_appendf(contents, "};\n\n");
    }
    {
        buf_appendf(contents,
            "pub const FloatMode = enum {\n"
            "    Optimized,\n"
            "    Strict,\n"
            "};\n\n");
        assert(FloatModeOptimized == 0);
        assert(FloatModeStrict == 1);
    }
    buf_appendf(contents, "pub const is_big_endian = %s;\n", bool_to_str(g->is_big_endian));
    buf_appendf(contents, "pub const is_test = %s;\n", bool_to_str(g->is_test_build));
    buf_appendf(contents, "pub const os = Os.%s;\n", cur_os);
    buf_appendf(contents, "pub const arch = Arch.%s;\n", cur_arch);
    buf_appendf(contents, "pub const environ = Environ.%s;\n", cur_environ);
    buf_appendf(contents, "pub const object_format = ObjectFormat.%s;\n", cur_obj_fmt);
    buf_appendf(contents, "pub const mode = %s;\n", build_mode_to_str(g->build_mode));
    buf_appendf(contents, "pub const link_libc = %s;\n", bool_to_str(g->libc_link_lib != nullptr));

    buf_appendf(contents, "pub const __zig_test_fn_slice = {}; // overwritten later\n");

    ensure_cache_dir(g);
    os_write_file(builtin_zig_path, contents);

    int err;
    Buf *abs_full_path = buf_alloc();
    if ((err = os_path_real(builtin_zig_path, abs_full_path))) {
        zig_panic("unable to open '%s': %s", buf_ptr(builtin_zig_path), err_str(err));
    }

    assert(g->root_package);
    assert(g->std_package);
    g->compile_var_package = new_package(buf_ptr(g->cache_dir), builtin_zig_basename);
    g->root_package->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    g->std_package->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    g->compile_var_import = add_source_file(g, g->compile_var_package, abs_full_path, contents);
}

static void init(CodeGen *g) {
    if (g->module)
        return;


    if (g->llvm_argv_len > 0) {
        const char **args = allocate_nonzero<const char *>(g->llvm_argv_len + 2);
        args[0] = "zig (LLVM option parsing)";
        for (size_t i = 0; i < g->llvm_argv_len; i += 1) {
            args[i + 1] = g->llvm_argv[i];
        }
        args[g->llvm_argv_len + 1] = nullptr;
        ZigLLVMParseCommandLineOptions(g->llvm_argv_len + 1, args);
    }

    if (g->is_test_build) {
        g->windows_subsystem_windows = false;
        g->windows_subsystem_console = true;
    }

    assert(g->root_out_name);
    g->module = LLVMModuleCreateWithName(buf_ptr(g->root_out_name));

    get_target_triple(&g->triple_str, &g->zig_target);

    LLVMSetTarget(g->module, buf_ptr(&g->triple_str));

    ZigLLVMAddModuleDebugInfoFlag(g->module);

    LLVMTargetRef target_ref;
    char *err_msg = nullptr;
    if (LLVMGetTargetFromTriple(buf_ptr(&g->triple_str), &target_ref, &err_msg)) {
        zig_panic("unable to create target based on: %s", buf_ptr(&g->triple_str));
    }

    bool is_optimized = g->build_mode != BuildModeDebug;
    LLVMCodeGenOptLevel opt_level = is_optimized ? LLVMCodeGenLevelAggressive : LLVMCodeGenLevelNone;

    LLVMRelocMode reloc_mode = g->is_static ? LLVMRelocStatic : LLVMRelocPIC;

    const char *target_specific_cpu_args;
    const char *target_specific_features;
    if (g->is_native_target) {
        // LLVM creates invalid binaries on Windows sometimes.
        // See https://github.com/zig-lang/zig/issues/508
        // As a workaround we do not use target native features on Windows.
        if (g->zig_target.os == ZigLLVM_Win32) {
            target_specific_cpu_args = "";
            target_specific_features = "";
        } else {
            target_specific_cpu_args = ZigLLVMGetHostCPUName();
            target_specific_features = ZigLLVMGetNativeFeatures();
        }
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

    Buf *producer = buf_sprintf("zig %s", ZIG_VERSION_STRING);
    const char *flags = "";
    unsigned runtime_version = 0;
    ZigLLVMDIFile *compile_unit_file = ZigLLVMCreateFile(g->dbuilder, buf_ptr(g->root_out_name),
            buf_ptr(&g->root_package->root_src_dir));
    g->compile_unit = ZigLLVMCreateCompileUnit(g->dbuilder, ZigLLVMLang_DW_LANG_C99(),
            compile_unit_file, buf_ptr(producer), is_optimized, flags, runtime_version,
            "", 0, !g->strip_debug_symbols);

    // This is for debug stuff that doesn't have a real file.
    g->dummy_di_file = nullptr;

    define_builtin_types(g);

    g->invalid_instruction = allocate<IrInstruction>(1);
    g->invalid_instruction->value.type = g->builtin_types.entry_invalid;
    g->invalid_instruction->value.global_refs = allocate<ConstGlobalRefs>(1);

    g->const_void_val.special = ConstValSpecialStatic;
    g->const_void_val.type = g->builtin_types.entry_void;
    g->const_void_val.global_refs = allocate<ConstGlobalRefs>(1);

    {
        ConstGlobalRefs *global_refs = allocate<ConstGlobalRefs>(PanicMsgIdCount);
        for (size_t i = 0; i < PanicMsgIdCount; i += 1) {
            g->panic_msg_vals[i].global_refs = &global_refs[i];
        }
    }

    define_builtin_fns(g);
    define_builtin_compile_vars(g);
}

void codegen_parsec(CodeGen *g, Buf *full_path) {
    find_libc_include_path(g);

    Buf *src_basename = buf_alloc();
    Buf *src_dirname = buf_alloc();
    os_path_split(full_path, src_dirname, src_basename);

    ImportTableEntry *import = allocate<ImportTableEntry>(1);
    import->source_code = nullptr;
    import->path = full_path;
    g->root_import = import;
    import->decls_scope = create_decls_scope(nullptr, nullptr, nullptr, import);

    init(g);

    import->di_file = ZigLLVMCreateFile(g->dbuilder, buf_ptr(src_basename), buf_ptr(src_dirname));

    ZigList<ErrorMsg *> errors = {0};
    int err = parse_h_file(import, &errors, buf_ptr(full_path), g, nullptr);
    if (err) {
        fprintf(stderr, "unable to parse C file: %s\n", err_str(err));
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

    return add_source_file(g, package, abs_full_path, import_code);
}

static PackageTableEntry *create_bootstrap_pkg(CodeGen *g, PackageTableEntry *pkg_with_main) {
    PackageTableEntry *package = codegen_create_package(g, buf_ptr(g->zig_std_special_dir), "bootstrap.zig");
    package->package_table.put(buf_create_from_str("@root"), pkg_with_main);
    return package;
}

static PackageTableEntry *create_test_runner_pkg(CodeGen *g) {
    return codegen_create_package(g, buf_ptr(g->zig_std_special_dir), "test_runner.zig");
}

static PackageTableEntry *create_panic_pkg(CodeGen *g) {
    return codegen_create_package(g, buf_ptr(g->zig_std_special_dir), "panic.zig");
}

static void create_test_compile_var_and_add_test_runner(CodeGen *g) {
    assert(g->is_test_build);

    if (g->test_fns.length == 0) {
        fprintf(stderr, "No tests to run.\n");
        exit(0);
    }

    TypeTableEntry *u8_ptr_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);
    TypeTableEntry *str_type = get_slice_type(g, u8_ptr_type);
    TypeTableEntry *fn_type = get_test_fn_type(g);

    const char *field_names[] = { "name", "func", };
    TypeTableEntry *field_types[] = { str_type, fn_type, };
    TypeTableEntry *struct_type = get_struct_type(g, "ZigTestFn", field_names, field_types, 2);

    ConstExprValue *test_fn_array = create_const_vals(1);
    test_fn_array->type = get_array_type(g, struct_type, g->test_fns.length);
    test_fn_array->special = ConstValSpecialStatic;
    test_fn_array->data.x_array.s_none.elements = create_const_vals(g->test_fns.length);

    for (size_t i = 0; i < g->test_fns.length; i += 1) {
        FnTableEntry *test_fn_entry = g->test_fns.at(i);

        ConstExprValue *this_val = &test_fn_array->data.x_array.s_none.elements[i];
        this_val->special = ConstValSpecialStatic;
        this_val->type = struct_type;
        this_val->data.x_struct.parent.id = ConstParentIdArray;
        this_val->data.x_struct.parent.data.p_array.array_val = test_fn_array;
        this_val->data.x_struct.parent.data.p_array.elem_index = i;
        this_val->data.x_struct.fields = create_const_vals(2);

        ConstExprValue *name_field = &this_val->data.x_struct.fields[0];
        ConstExprValue *name_array_val = create_const_str_lit(g, &test_fn_entry->symbol_name);
        init_const_slice(g, name_field, name_array_val, 0, buf_len(&test_fn_entry->symbol_name), true);

        ConstExprValue *fn_field = &this_val->data.x_struct.fields[1];
        fn_field->type = fn_type;
        fn_field->special = ConstValSpecialStatic;
        fn_field->data.x_fn.fn_entry = test_fn_entry;
    }

    ConstExprValue *test_fn_slice = create_const_slice(g, test_fn_array, 0, g->test_fns.length, true);

    update_compile_var(g, buf_create_from_str("__zig_test_fn_slice"), test_fn_slice);
    g->test_runner_package = create_test_runner_pkg(g);
    g->test_runner_import = add_special_code(g, g->test_runner_package, "test_runner.zig");
}

static void gen_root_source(CodeGen *g) {
    if (buf_len(&g->root_package->root_src_path) == 0)
        return;

    codegen_add_time_event(g, "Semantic Analysis");

    Buf *rel_full_path = buf_alloc();
    os_path_join(&g->root_package->root_src_dir, &g->root_package->root_src_path, rel_full_path);

    Buf *abs_full_path = buf_alloc();
    int err;
    if ((err = os_path_real(rel_full_path, abs_full_path))) {
        zig_panic("unable to open '%s': %s", buf_ptr(rel_full_path), err_str(err));
    }

    Buf *source_code = buf_alloc();
    if ((err = os_fetch_file_path(rel_full_path, source_code))) {
        zig_panic("unable to open '%s': %s", buf_ptr(rel_full_path), err_str(err));
    }

    g->root_import = add_source_file(g, g->root_package, abs_full_path, source_code);

    assert(g->root_out_name);
    assert(g->out_type != OutTypeUnknown);

    if (!g->is_test_build && g->zig_target.os != ZigLLVM_UnknownOS && !g->have_c_main && !g->have_winmain &&
        ((g->have_pub_main && g->out_type == OutTypeObj) || g->out_type == OutTypeExe))
    {
        g->bootstrap_import = add_special_code(g, create_bootstrap_pkg(g, g->root_package), "bootstrap.zig");
    }
    ImportTableEntry *import_with_panic;
    if (g->have_pub_panic) {
        import_with_panic = g->root_import;
    } else {
        g->panic_package = create_panic_pkg(g);
        import_with_panic = add_special_code(g, g->panic_package, "panic.zig");
    }
    // Zig has lazy top level definitions. Here we semantically analyze the panic function.
    {
        scan_import(g, import_with_panic);
        Tld *panic_tld = find_decl(g, &import_with_panic->decls_scope->base, buf_create_from_str("panic"));
        assert(panic_tld != nullptr);
        resolve_top_level_decl(g, panic_tld, false, nullptr);
    }

    if (g->verbose) {
        fprintf(stderr, "\nIR Generation and Semantic Analysis:\n");
        fprintf(stderr, "--------------------------------------\n");
    }
    if (!g->error_during_imports) {
        semantic_analyze(g);
    }
    if (g->is_test_build) {
        create_test_compile_var_and_add_test_runner(g);
        g->bootstrap_import = add_special_code(g, create_bootstrap_pkg(g, g->test_runner_package), "bootstrap.zig");

        if (!g->error_during_imports) {
            semantic_analyze(g);
        }
    }

    report_errors_and_maybe_exit(g);
    if (g->verbose) {
        fprintf(stderr, "OK\n");
    }

}

void codegen_add_assembly(CodeGen *g, Buf *path) {
    g->assembly_files.append(path);
}

static void gen_global_asm(CodeGen *g) {
    Buf contents = BUF_INIT;
    int err;
    for (size_t i = 0; i < g->assembly_files.length; i += 1) {
        Buf *asm_file = g->assembly_files.at(i);
        if ((err = os_fetch_file_path(asm_file, &contents))) {
            zig_panic("Unable to read %s: %s", buf_ptr(asm_file), err_str(err));
        }
        buf_append_buf(&g->global_asm, &contents);
    }
}

void codegen_add_object(CodeGen *g, Buf *object_path) {
    g->link_objects.append(object_path);
}

// Must be coordinated with with CIntType enum
static const char *c_int_type_names[] = {
    "short",
    "unsigned short",
    "int",
    "unsigned int",
    "long",
    "unsigned long",
    "long long",
    "unsigned long long",
};

static void get_c_type(CodeGen *g, TypeTableEntry *type_entry, Buf *out_buf) {
    assert(type_entry);

    for (size_t i = 0; i < array_length(c_int_type_names); i += 1) {
        if (type_entry == g->builtin_types.entry_c_int[i]) {
            buf_init_from_str(out_buf, c_int_type_names[i]);
            return;
        }
    }
    if (type_entry == g->builtin_types.entry_c_longdouble) {
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
                case 80:
                    buf_init_from_str(out_buf, "__float80");
                    break;
                case 128:
                    buf_init_from_str(out_buf, "__float128");
                    break;
                default:
                    zig_unreachable();
            }
            break;
        case TypeTableEntryIdInt:
            g->c_want_stdint = true;
            buf_resize(out_buf, 0);
            buf_appendf(out_buf, "%sint%" PRIu32 "_t",
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
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdOpaque:
            {
                // TODO add to table of structs we need to declare
                buf_init_from_buf(out_buf, &type_entry->name);
                return;
            }
        case TypeTableEntryIdArray:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
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

static const char *preprocessor_alphabet1 = "_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
static const char *preprocessor_alphabet2 = "_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

static bool need_to_preprocessor_mangle(Buf *src) {
    for (size_t i = 0; i < buf_len(src); i += 1) {
        const char *alphabet = (i == 0) ? preprocessor_alphabet1 : preprocessor_alphabet2;
        uint8_t byte = buf_ptr(src)[i];
        if (strchr(alphabet, byte) == nullptr) {
            return true;
        }
    }
    return false;
}

static Buf *preprocessor_mangle(Buf *src) {
    if (!need_to_preprocessor_mangle(src)) {
        return buf_create_from_buf(src);
    }
    Buf *result = buf_alloc();
    for (size_t i = 0; i < buf_len(src); i += 1) {
        const char *alphabet = (i == 0) ? preprocessor_alphabet1 : preprocessor_alphabet2;
        uint8_t byte = buf_ptr(src)[i];
        if (strchr(alphabet, byte) == nullptr) {
            // perform escape
            buf_appendf(result, "_%02x_", byte);
        } else {
            buf_append_char(result, byte);
        }
    }
    return result;
}

static void gen_h_file(CodeGen *g) {
    if (!g->want_h_file)
        return;

    codegen_add_time_event(g, "Generate .h");

    assert(!g->is_test_build);

    if (!g->out_h_path) {
        g->out_h_path = buf_sprintf("%s.h", buf_ptr(g->root_out_name));
    }

    FILE *out_h = fopen(buf_ptr(g->out_h_path), "wb");
    if (!out_h)
        zig_panic("unable to open %s: %s", buf_ptr(g->out_h_path), strerror(errno));

    Buf *export_macro = preprocessor_mangle(buf_sprintf("%s_EXPORT", buf_ptr(g->root_out_name)));
    buf_upcase(export_macro);

    Buf *extern_c_macro = preprocessor_mangle(buf_sprintf("%s_EXTERN_C", buf_ptr(g->root_out_name)));
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

    Buf *ifdef_dance_name = preprocessor_mangle(buf_sprintf("%s_H", buf_ptr(g->root_out_name)));
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

void codegen_print_timing_report(CodeGen *g, FILE *f) {
    double start_time = g->timing_events.at(0).time;
    double end_time = g->timing_events.last().time;
    double total = end_time - start_time;
    fprintf(f, "%20s%12s%12s%12s%12s\n", "Name", "Start", "End", "Duration", "Percent");
    for (size_t i = 0; i < g->timing_events.length - 1; i += 1) {
        TimeEvent *te = &g->timing_events.at(i);
        TimeEvent *next_te = &g->timing_events.at(i + 1);
        fprintf(f, "%20s%12.4f%12.4f%12.4f%12.4f\n", te->name,
                te->time - start_time,
                next_te->time - start_time,
                next_te->time - te->time,
                (next_te->time - te->time) / total);
    }
    fprintf(f, "%20s%12.4f%12.4f%12.4f%12.4f\n", "Total", 0.0, total, total, 1.0);
}

void codegen_add_time_event(CodeGen *g, const char *name) {
    g->timing_events.append({os_get_time(), name});
}

void codegen_build(CodeGen *g) {
    assert(g->out_type != OutTypeUnknown);
    init(g);

    gen_global_asm(g);
    gen_root_source(g);
    do_code_gen(g);
    gen_h_file(g);
}

PackageTableEntry *codegen_create_package(CodeGen *g, const char *root_src_dir, const char *root_src_path) {
    init(g);
    PackageTableEntry *pkg = new_package(root_src_dir, root_src_path);
    if (g->std_package != nullptr) {
        assert(g->compile_var_package != nullptr);
        pkg->package_table.put(buf_create_from_str("std"), g->std_package);
        pkg->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    }
    return pkg;
}
