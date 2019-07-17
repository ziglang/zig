/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ast_render.hpp"
#include "codegen.hpp"
#include "compiler.hpp"
#include "config.h"
#include "errmsg.hpp"
#include "error.hpp"
#include "hash_map.hpp"
#include "ir.hpp"
#include "os.hpp"
#include "translate_c.hpp"
#include "target.hpp"
#include "util.hpp"
#include "zig_llvm.h"
#include "userland.h"

#include <stdio.h>
#include <errno.h>

static void init_darwin_native(CodeGen *g) {
    char *osx_target = getenv("MACOSX_DEPLOYMENT_TARGET");
    char *ios_target = getenv("IPHONEOS_DEPLOYMENT_TARGET");

    // Allow conflicts among OSX and iOS, but choose the default platform.
    if (osx_target && ios_target) {
        if (g->zig_target->arch == ZigLLVM_arm ||
            g->zig_target->arch == ZigLLVM_aarch64 ||
            g->zig_target->arch == ZigLLVM_thumb)
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
    } else if (g->zig_target->os != OsIOS) {
        g->mmacosx_version_min = buf_create_from_str("10.14");
    }
}

static ZigPackage *new_package(const char *root_src_dir, const char *root_src_path, const char *pkg_path) {
    ZigPackage *entry = allocate<ZigPackage>(1);
    entry->package_table.init(4);
    buf_init_from_str(&entry->root_src_dir, root_src_dir);
    buf_init_from_str(&entry->root_src_path, root_src_path);
    buf_init_from_str(&entry->pkg_path, pkg_path);
    return entry;
}

ZigPackage *new_anonymous_package() {
    return new_package("", "", "");
}

static const char *symbols_that_llvm_depends_on[] = {
    "memcpy",
    "memset",
    "sqrt",
    "powi",
    "sin",
    "cos",
    "pow",
    "exp",
    "exp2",
    "log",
    "log10",
    "log2",
    "fma",
    "fabs",
    "minnum",
    "maxnum",
    "copysign",
    "floor",
    "ceil",
    "trunc",
    "rint",
    "nearbyint",
    "round",
    // TODO probably all of compiler-rt needs to go here
};

CodeGen *codegen_create(Buf *main_pkg_path, Buf *root_src_path, const ZigTarget *target,
    OutType out_type, BuildMode build_mode, Buf *override_lib_dir, Buf *override_std_dir,
    ZigLibCInstallation *libc, Buf *cache_dir)
{
    CodeGen *g = allocate<CodeGen>(1);

    codegen_add_time_event(g, "Initialize");

    g->subsystem = TargetSubsystemAuto;
    g->libc = libc;
    g->zig_target = target;
    g->cache_dir = cache_dir;

    if (override_lib_dir == nullptr) {
        g->zig_lib_dir = get_zig_lib_dir();
    } else {
        g->zig_lib_dir = override_lib_dir;
    }

    if (override_std_dir == nullptr) {
        g->zig_std_dir = buf_alloc();
        os_path_join(g->zig_lib_dir, buf_create_from_str("std"), g->zig_std_dir);
    } else {
        g->zig_std_dir = override_std_dir;
    }

    g->zig_c_headers_dir = buf_alloc();
    os_path_join(g->zig_lib_dir, buf_create_from_str("include"), g->zig_c_headers_dir);

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
    g->string_literals_table.init(16);
    g->type_info_cache.init(32);
    g->is_test_build = false;
    g->is_single_threaded = false;
    buf_resize(&g->global_asm, 0);

    for (size_t i = 0; i < array_length(symbols_that_llvm_depends_on); i += 1) {
        g->external_prototypes.put(buf_create_from_str(symbols_that_llvm_depends_on[i]), nullptr);
    }

    if (root_src_path) {
        Buf *root_pkg_path;
        Buf *rel_root_src_path;
        if (main_pkg_path == nullptr) {
            Buf *src_basename = buf_alloc();
            Buf *src_dir = buf_alloc();
            os_path_split(root_src_path, src_dir, src_basename);

            if (buf_len(src_basename) == 0) {
                fprintf(stderr, "Invalid root source path: %s\n", buf_ptr(root_src_path));
                exit(1);
            }
            root_pkg_path = src_dir;
            rel_root_src_path = src_basename;
        } else {
            Buf resolved_root_src_path = os_path_resolve(&root_src_path, 1);
            Buf resolved_main_pkg_path = os_path_resolve(&main_pkg_path, 1);

            if (!buf_starts_with_buf(&resolved_root_src_path, &resolved_main_pkg_path)) {
                fprintf(stderr, "Root source path '%s' outside main package path '%s'",
                        buf_ptr(root_src_path), buf_ptr(main_pkg_path));
                exit(1);
            }
            root_pkg_path = main_pkg_path;
            rel_root_src_path = buf_create_from_mem(
                    buf_ptr(&resolved_root_src_path) + buf_len(&resolved_main_pkg_path) + 1,
                    buf_len(&resolved_root_src_path) - buf_len(&resolved_main_pkg_path) - 1);
        }

        g->root_package = new_package(buf_ptr(root_pkg_path), buf_ptr(rel_root_src_path), "");
        g->std_package = new_package(buf_ptr(g->zig_std_dir), "std.zig", "std");
        g->root_package->package_table.put(buf_create_from_str("std"), g->std_package);
    } else {
        g->root_package = new_package(".", "", "");
    }

    g->root_package->package_table.put(buf_create_from_str("root"), g->root_package);

    g->zig_std_special_dir = buf_alloc();
    os_path_join(g->zig_std_dir, buf_sprintf("special"), g->zig_std_special_dir);

    assert(target != nullptr);
    if (!target->is_native) {
        g->each_lib_rpath = false;
    } else {
        g->each_lib_rpath = true;

        if (target_os_is_darwin(g->zig_target->os)) {
            init_darwin_native(g);
        }

    }

    if (target_os_requires_libc(g->zig_target->os)) {
        g->libc_link_lib = create_link_lib(buf_create_from_str("c"));
        g->link_libs_list.append(g->libc_link_lib);
    }

    target_triple_llvm(&g->llvm_triple_str, g->zig_target);
    g->pointer_size_bytes = target_arch_pointer_bit_width(g->zig_target->arch) / 8;

    if (!target_has_debug_info(g->zig_target)) {
        g->strip_debug_symbols = true;
    }

    return g;
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

void codegen_set_emit_file_type(CodeGen *g, EmitFileType emit_file_type) {
    g->emit_file_type = emit_file_type;
}

void codegen_set_each_lib_rpath(CodeGen *g, bool each_lib_rpath) {
    g->each_lib_rpath = each_lib_rpath;
}

void codegen_set_errmsg_color(CodeGen *g, ErrColor err_color) {
    g->err_color = err_color;
}

void codegen_set_strip(CodeGen *g, bool strip) {
    g->strip_debug_symbols = strip;
    if (!target_has_debug_info(g->zig_target)) {
        g->strip_debug_symbols = true;
    }
}

void codegen_set_out_name(CodeGen *g, Buf *out_name) {
    g->root_out_name = out_name;
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

void codegen_add_forbidden_lib(CodeGen *codegen, Buf *lib) {
    codegen->forbidden_libs.append(lib);
}

void codegen_add_framework(CodeGen *g, const char *framework) {
    g->darwin_frameworks.append(buf_create_from_str(framework));
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


static void render_const_val(CodeGen *g, ConstExprValue *const_val, const char *name);
static void render_const_val_global(CodeGen *g, ConstExprValue *const_val, const char *name);
static LLVMValueRef gen_const_val(CodeGen *g, ConstExprValue *const_val, const char *name);
static void generate_error_name_table(CodeGen *g);
static bool value_is_all_undef(ConstExprValue *const_val);
static void gen_undef_init(CodeGen *g, uint32_t ptr_align_bytes, ZigType *value_type, LLVMValueRef ptr);
static LLVMValueRef build_alloca(CodeGen *g, ZigType *type_entry, const char *name, uint32_t alignment);

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

static void addLLVMArgAttr(LLVMValueRef fn_val, unsigned param_index, const char *attr_name) {
    return addLLVMAttr(fn_val, param_index + 1, attr_name);
}

static void addLLVMArgAttrInt(LLVMValueRef fn_val, unsigned param_index, const char *attr_name, uint64_t attr_val) {
    return addLLVMAttrInt(fn_val, param_index + 1, attr_name, attr_val);
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
            if (g->zig_target->arch == ZigLLVM_x86 ||
                g->zig_target->arch == ZigLLVM_x86_64)
            {
                // cold calling convention is not supported on windows
                if (g->zig_target->os == OsWindows) {
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
            if (g->zig_target->arch == ZigLLVM_x86) {
                return LLVMX86StdcallCallConv;
            } else {
                return LLVMCCallConv;
            }
        case CallingConventionAsync:
            return LLVMFastCallConv;
    }
    zig_unreachable();
}

static void add_uwtable_attr(CodeGen *g, LLVMValueRef fn_val) {
    if (g->zig_target->os == OsWindows) {
        addLLVMFnAttr(fn_val, "uwtable");
    }
}

static LLVMLinkage to_llvm_linkage(GlobalLinkageId id) {
    switch (id) {
        case GlobalLinkageIdInternal:
            return LLVMInternalLinkage;
        case GlobalLinkageIdStrong:
            return LLVMExternalLinkage;
        case GlobalLinkageIdWeak:
            return LLVMWeakODRLinkage;
        case GlobalLinkageIdLinkOnce:
            return LLVMLinkOnceODRLinkage;
    }
    zig_unreachable();
}

static uint32_t get_err_ret_trace_arg_index(CodeGen *g, ZigFn *fn_table_entry) {
    if (!g->have_err_ret_tracing) {
        return UINT32_MAX;
    }
    if (fn_table_entry->type_entry->data.fn.fn_type_id.cc == CallingConventionAsync) {
        return 0;
    }
    ZigType *fn_type = fn_table_entry->type_entry;
    if (!fn_type_can_fail(&fn_type->data.fn.fn_type_id)) {
        return UINT32_MAX;
    }
    ZigType *return_type = fn_type->data.fn.fn_type_id.return_type;
    bool first_arg_ret = type_has_bits(return_type) && handle_is_ptr(return_type);
    return first_arg_ret ? 1 : 0;
}

static void maybe_export_dll(CodeGen *g, LLVMValueRef global_value, GlobalLinkageId linkage) {
    if (linkage != GlobalLinkageIdInternal && g->zig_target->os == OsWindows && g->is_dynamic) {
        LLVMSetDLLStorageClass(global_value, LLVMDLLExportStorageClass);
    }
}

static void maybe_import_dll(CodeGen *g, LLVMValueRef global_value, GlobalLinkageId linkage) {
    if (linkage != GlobalLinkageIdInternal && g->zig_target->os == OsWindows) {
        // TODO come up with a good explanation/understanding for why we never do
        // DLLImportStorageClass. Empirically it only causes problems. But let's have
        // this documented and then clean up the code accordingly.
        //LLVMSetDLLStorageClass(global_value, LLVMDLLImportStorageClass);
    }
}

static bool cc_want_sret_attr(CallingConvention cc) {
    switch (cc) {
        case CallingConventionNaked:
            zig_unreachable();
        case CallingConventionC:
        case CallingConventionCold:
        case CallingConventionStdcall:
            return true;
        case CallingConventionAsync:
        case CallingConventionUnspecified:
            return false;
    }
    zig_unreachable();
}

static LLVMValueRef fn_llvm_value(CodeGen *g, ZigFn *fn_table_entry) {
    if (fn_table_entry->llvm_value)
        return fn_table_entry->llvm_value;

    Buf *unmangled_name = &fn_table_entry->symbol_name;
    Buf *symbol_name;
    GlobalLinkageId linkage;
    if (fn_table_entry->body_node == nullptr) {
        symbol_name = unmangled_name;
        linkage = GlobalLinkageIdStrong;
    } else if (fn_table_entry->export_list.length == 0) {
        symbol_name = get_mangled_name(g, unmangled_name, false);
        linkage = GlobalLinkageIdInternal;
    } else {
        GlobalExport *fn_export = &fn_table_entry->export_list.items[0];
        symbol_name = &fn_export->name;
        linkage = fn_export->linkage;
    }

    bool external_linkage = linkage != GlobalLinkageIdInternal;
    CallingConvention cc = fn_table_entry->type_entry->data.fn.fn_type_id.cc;
    if (cc == CallingConventionStdcall && external_linkage &&
        g->zig_target->arch == ZigLLVM_x86)
    {
        // prevent llvm name mangling
        symbol_name = buf_sprintf("\x01_%s", buf_ptr(symbol_name));
    }


    ZigType *fn_type = fn_table_entry->type_entry;
    // Make the raw_type_ref populated
    (void)get_llvm_type(g, fn_type);
    LLVMTypeRef fn_llvm_type = fn_type->data.fn.raw_type_ref;
    if (fn_table_entry->body_node == nullptr) {
        LLVMValueRef existing_llvm_fn = LLVMGetNamedFunction(g->module, buf_ptr(symbol_name));
        if (existing_llvm_fn) {
            fn_table_entry->llvm_value = LLVMConstBitCast(existing_llvm_fn, LLVMPointerType(fn_llvm_type, 0));
            return fn_table_entry->llvm_value;
        } else {
            auto entry = g->exported_symbol_names.maybe_get(symbol_name);
            if (entry == nullptr) {
                fn_table_entry->llvm_value = LLVMAddFunction(g->module, buf_ptr(symbol_name), fn_llvm_type);

                if (target_is_wasm(g->zig_target)) {
                    assert(fn_table_entry->proto_node->type == NodeTypeFnProto);
                    AstNodeFnProto *fn_proto = &fn_table_entry->proto_node->data.fn_proto;
                    if (fn_proto-> is_extern && fn_proto->lib_name != nullptr ) {
                        addLLVMFnAttrStr(fn_table_entry->llvm_value, "wasm-import-module", buf_ptr(fn_proto->lib_name));
                    }
                }
            } else {
                assert(entry->value->id == TldIdFn);
                TldFn *tld_fn = reinterpret_cast<TldFn *>(entry->value);
                // Make the raw_type_ref populated
                (void)get_llvm_type(g, tld_fn->fn_entry->type_entry);
                tld_fn->fn_entry->llvm_value = LLVMAddFunction(g->module, buf_ptr(symbol_name),
                        tld_fn->fn_entry->type_entry->data.fn.raw_type_ref);
                fn_table_entry->llvm_value = LLVMConstBitCast(tld_fn->fn_entry->llvm_value,
                        LLVMPointerType(fn_llvm_type, 0));
                return fn_table_entry->llvm_value;
            }
        }
    } else {
        if (fn_table_entry->llvm_value == nullptr) {
            fn_table_entry->llvm_value = LLVMAddFunction(g->module, buf_ptr(symbol_name), fn_llvm_type);
        }

        for (size_t i = 1; i < fn_table_entry->export_list.length; i += 1) {
            GlobalExport *fn_export = &fn_table_entry->export_list.items[i];
            LLVMAddAlias(g->module, LLVMTypeOf(fn_table_entry->llvm_value),
                    fn_table_entry->llvm_value, buf_ptr(&fn_export->name));
        }
    }
    fn_table_entry->llvm_name = strdup(LLVMGetValueName(fn_table_entry->llvm_value));

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

    if (cc == CallingConventionNaked) {
        addLLVMFnAttr(fn_table_entry->llvm_value, "naked");
    } else {
        LLVMSetFunctionCallConv(fn_table_entry->llvm_value, get_llvm_cc(g, fn_type->data.fn.fn_type_id.cc));
    }
    if (cc == CallingConventionAsync) {
        addLLVMFnAttr(fn_table_entry->llvm_value, "optnone");
        addLLVMFnAttr(fn_table_entry->llvm_value, "noinline");
    }

    bool want_cold = fn_table_entry->is_cold || cc == CallingConventionCold;
    if (want_cold) {
        ZigLLVMAddFunctionAttrCold(fn_table_entry->llvm_value);
    }


    LLVMSetLinkage(fn_table_entry->llvm_value, to_llvm_linkage(linkage));

    if (linkage == GlobalLinkageIdInternal) {
        LLVMSetUnnamedAddr(fn_table_entry->llvm_value, true);
    }

    ZigType *return_type = fn_type->data.fn.fn_type_id.return_type;
    if (return_type->id == ZigTypeIdUnreachable) {
        addLLVMFnAttr(fn_table_entry->llvm_value, "noreturn");
    }

    if (fn_table_entry->body_node != nullptr) {
        maybe_export_dll(g, fn_table_entry->llvm_value, linkage);

        bool want_fn_safety = g->build_mode != BuildModeFastRelease &&
                              g->build_mode != BuildModeSmallRelease &&
                              !fn_table_entry->def_scope->safety_off;
        if (want_fn_safety) {
            if (g->libc_link_lib != nullptr) {
                addLLVMFnAttr(fn_table_entry->llvm_value, "sspstrong");
                addLLVMFnAttrStr(fn_table_entry->llvm_value, "stack-protector-buffer-size", "4");
            }
        }
        if (g->have_stack_probing && !fn_table_entry->def_scope->safety_off) {
            addLLVMFnAttrStr(fn_table_entry->llvm_value, "probe-stack", "__zig_probe_stack");
        }
    } else {
        maybe_import_dll(g, fn_table_entry->llvm_value, linkage);
    }

    if (fn_table_entry->alignstack_value != 0) {
        addLLVMFnAttrInt(fn_table_entry->llvm_value, "alignstack", fn_table_entry->alignstack_value);
    }

    addLLVMFnAttr(fn_table_entry->llvm_value, "nounwind");
    add_uwtable_attr(g, fn_table_entry->llvm_value);
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

    unsigned init_gen_i = 0;
    if (!type_has_bits(return_type)) {
        // nothing to do
    } else if (type_is_nonnull_ptr(return_type)) {
        addLLVMAttr(fn_table_entry->llvm_value, 0, "nonnull");
    } else if (want_first_arg_sret(g, &fn_type->data.fn.fn_type_id)) {
        // Sret pointers must not be address 0
        addLLVMArgAttr(fn_table_entry->llvm_value, 0, "nonnull");
        addLLVMArgAttr(fn_table_entry->llvm_value, 0, "sret");
        if (cc_want_sret_attr(cc)) {
            addLLVMArgAttr(fn_table_entry->llvm_value, 0, "noalias");
        }
        init_gen_i = 1;
    }

    // set parameter attributes
    FnWalk fn_walk = {};
    fn_walk.id = FnWalkIdAttrs;
    fn_walk.data.attrs.fn = fn_table_entry;
    fn_walk.data.attrs.gen_i = init_gen_i;
    walk_function_params(g, fn_type, &fn_walk);

    uint32_t err_ret_trace_arg_index = get_err_ret_trace_arg_index(g, fn_table_entry);
    if (err_ret_trace_arg_index != UINT32_MAX) {
        // Error return trace memory is in the stack, which is impossible to be at address 0
        // on any architecture.
        addLLVMArgAttr(fn_table_entry->llvm_value, (unsigned)err_ret_trace_arg_index, "nonnull");
    }

    return fn_table_entry->llvm_value;
}

static ZigLLVMDIScope *get_di_scope(CodeGen *g, Scope *scope) {
    if (scope->di_scope)
        return scope->di_scope;

    ZigType *import = get_scope_import(scope);
    switch (scope->id) {
        case ScopeIdCImport:
            zig_unreachable();
        case ScopeIdFnDef:
        {
            assert(scope->parent);
            ScopeFnDef *fn_scope = (ScopeFnDef *)scope;
            ZigFn *fn_table_entry = fn_scope->fn_entry;
            if (!fn_table_entry->proto_node)
                return get_di_scope(g, scope->parent);
            unsigned line_number = (unsigned)(fn_table_entry->proto_node->line == 0) ?
                0 : (fn_table_entry->proto_node->line + 1);
            unsigned scope_line = line_number;
            bool is_definition = fn_table_entry->body_node != nullptr;
            bool is_optimized = g->build_mode != BuildModeDebug;
            bool is_internal_linkage = (fn_table_entry->body_node != nullptr &&
                    fn_table_entry->export_list.length == 0);
            unsigned flags = ZigLLVM_DIFlags_StaticMember;
            ZigLLVMDIScope *fn_di_scope = get_di_scope(g, scope->parent);
            assert(fn_di_scope != nullptr);
            ZigLLVMDISubprogram *subprogram = ZigLLVMCreateFunction(g->dbuilder,
                fn_di_scope, buf_ptr(&fn_table_entry->symbol_name), "",
                import->data.structure.root_struct->di_file, line_number,
                fn_table_entry->type_entry->data.fn.raw_di_type, is_internal_linkage,
                is_definition, scope_line, flags, is_optimized, nullptr);

            scope->di_scope = ZigLLVMSubprogramToScope(subprogram);
            if (!g->strip_debug_symbols) {
                ZigLLVMFnSetSubprogram(fn_llvm_value(g, fn_table_entry), subprogram);
            }
            return scope->di_scope;
        }
        case ScopeIdDecls:
            if (scope->parent) {
                ScopeDecls *decls_scope = (ScopeDecls *)scope;
                assert(decls_scope->container_type);
                scope->di_scope = ZigLLVMTypeToScope(get_llvm_di_type(g, decls_scope->container_type));
            } else {
                scope->di_scope = ZigLLVMFileToScope(import->data.structure.root_struct->di_file);
            }
            return scope->di_scope;
        case ScopeIdBlock:
        case ScopeIdDefer:
        {
            assert(scope->parent);
            ZigLLVMDILexicalBlock *di_block = ZigLLVMCreateLexicalBlock(g->dbuilder,
                get_di_scope(g, scope->parent),
                import->data.structure.root_struct->di_file,
                (unsigned)scope->source_node->line + 1,
                (unsigned)scope->source_node->column + 1);
            scope->di_scope = ZigLLVMLexicalBlockToScope(di_block);
            return scope->di_scope;
        }
        case ScopeIdVarDecl:
        case ScopeIdDeferExpr:
        case ScopeIdLoop:
        case ScopeIdSuspend:
        case ScopeIdCompTime:
        case ScopeIdCoroPrelude:
        case ScopeIdRuntime:
            return get_di_scope(g, scope->parent);
    }
    zig_unreachable();
}

static void clear_debug_source_node(CodeGen *g) {
    ZigLLVMClearCurrentDebugLocation(g->builder);
}

static LLVMValueRef get_arithmetic_overflow_fn(CodeGen *g, ZigType *operand_type,
        const char *signed_name, const char *unsigned_name)
{
    ZigType *int_type = (operand_type->id == ZigTypeIdVector) ? operand_type->data.vector.elem_type : operand_type;
    char fn_name[64];

    assert(int_type->id == ZigTypeIdInt);
    const char *signed_str = int_type->data.integral.is_signed ? signed_name : unsigned_name;

    LLVMTypeRef param_types[] = {
        get_llvm_type(g, operand_type),
        get_llvm_type(g, operand_type),
    };

    if (operand_type->id == ZigTypeIdVector) {
        sprintf(fn_name, "llvm.%s.with.overflow.v%" PRIu32 "i%" PRIu32, signed_str,
                operand_type->data.vector.len, int_type->data.integral.bit_count);

        LLVMTypeRef return_elem_types[] = {
            get_llvm_type(g, operand_type),
            LLVMVectorType(LLVMInt1Type(), operand_type->data.vector.len),
        };
        LLVMTypeRef return_struct_type = LLVMStructType(return_elem_types, 2, false);
        LLVMTypeRef fn_type = LLVMFunctionType(return_struct_type, param_types, 2, false);
        LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type);
        assert(LLVMGetIntrinsicID(fn_val));
        return fn_val;
    } else {
        sprintf(fn_name, "llvm.%s.with.overflow.i%" PRIu32, signed_str, int_type->data.integral.bit_count);

        LLVMTypeRef return_elem_types[] = {
            get_llvm_type(g, operand_type),
            LLVMInt1Type(),
        };
        LLVMTypeRef return_struct_type = LLVMStructType(return_elem_types, 2, false);
        LLVMTypeRef fn_type = LLVMFunctionType(return_struct_type, param_types, 2, false);
        LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type);
        assert(LLVMGetIntrinsicID(fn_val));
        return fn_val;
    }
}

static LLVMValueRef get_int_overflow_fn(CodeGen *g, ZigType *operand_type, AddSubMul add_sub_mul) {
    ZigType *int_type = (operand_type->id == ZigTypeIdVector) ? operand_type->data.vector.elem_type : operand_type;
    assert(int_type->id == ZigTypeIdInt);

    ZigLLVMFnKey key = {};
    key.id = ZigLLVMFnIdOverflowArithmetic;
    key.data.overflow_arithmetic.is_signed = int_type->data.integral.is_signed;
    key.data.overflow_arithmetic.add_sub_mul = add_sub_mul;
    key.data.overflow_arithmetic.bit_count = (uint32_t)int_type->data.integral.bit_count;
    key.data.overflow_arithmetic.vector_len = (operand_type->id == ZigTypeIdVector) ?
        operand_type->data.vector.len : 0;

    auto existing_entry = g->llvm_fn_table.maybe_get(key);
    if (existing_entry)
        return existing_entry->value;

    LLVMValueRef fn_val;
    switch (add_sub_mul) {
        case AddSubMulAdd:
            fn_val = get_arithmetic_overflow_fn(g, operand_type, "sadd", "uadd");
            break;
        case AddSubMulSub:
            fn_val = get_arithmetic_overflow_fn(g, operand_type, "ssub", "usub");
            break;
        case AddSubMulMul:
            fn_val = get_arithmetic_overflow_fn(g, operand_type, "smul", "umul");
            break;
    }

    g->llvm_fn_table.put(key, fn_val);
    return fn_val;
}

static LLVMValueRef get_float_fn(CodeGen *g, ZigType *type_entry, ZigLLVMFnId fn_id, BuiltinFnId op) {
    assert(type_entry->id == ZigTypeIdFloat ||
           type_entry->id == ZigTypeIdVector);

    bool is_vector = (type_entry->id == ZigTypeIdVector);
    ZigType *float_type = is_vector ? type_entry->data.vector.elem_type : type_entry;

    ZigLLVMFnKey key = {};
    key.id = fn_id;
    key.data.floating.bit_count = (uint32_t)float_type->data.floating.bit_count;
    key.data.floating.vector_len = is_vector ? (uint32_t)type_entry->data.vector.len : 0;
    key.data.floating.op = op;

    auto existing_entry = g->llvm_fn_table.maybe_get(key);
    if (existing_entry)
        return existing_entry->value;

    const char *name;
    uint32_t num_args;
    if (fn_id == ZigLLVMFnIdFMA) {
        name = "fma";
        num_args = 3;
    } else if (fn_id == ZigLLVMFnIdFloatOp) {
        name = float_op_to_name(op, true);
        num_args = 1;
    } else {
        zig_unreachable();
    }

    char fn_name[64];
    if (is_vector)
        sprintf(fn_name, "llvm.%s.v%" PRIu32 "f%" PRIu32, name, key.data.floating.vector_len, key.data.floating.bit_count);
    else
        sprintf(fn_name, "llvm.%s.f%" PRIu32, name, key.data.floating.bit_count);
    LLVMTypeRef float_type_ref = get_llvm_type(g, type_entry);
    LLVMTypeRef return_elem_types[3] = {
        float_type_ref,
        float_type_ref,
        float_type_ref,
    };
    LLVMTypeRef fn_type = LLVMFunctionType(float_type_ref, return_elem_types, num_args, false);
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
    if (alignment != 0) {
        LLVMSetAlignment(instruction, alignment);
    }
    return instruction;
}

static LLVMValueRef gen_store(CodeGen *g, LLVMValueRef value, LLVMValueRef ptr, ZigType *ptr_type) {
    assert(ptr_type->id == ZigTypeIdPointer);
    uint32_t alignment = get_ptr_align(g, ptr_type);
    return gen_store_untyped(g, value, ptr, alignment, ptr_type->data.pointer.is_volatile);
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

static LLVMValueRef gen_load(CodeGen *g, LLVMValueRef ptr, ZigType *ptr_type, const char *name) {
    assert(ptr_type->id == ZigTypeIdPointer);
    uint32_t alignment = get_ptr_align(g, ptr_type);
    return gen_load_untyped(g, ptr, alignment, ptr_type->data.pointer.is_volatile, name);
}

static LLVMValueRef get_handle_value(CodeGen *g, LLVMValueRef ptr, ZigType *type, ZigType *ptr_type) {
    if (type_has_bits(type)) {
        if (handle_is_ptr(type)) {
            return ptr;
        } else {
            assert(ptr_type->id == ZigTypeIdPointer);
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
                return block_scope->fast_math_on;
        } else if (scope->id == ScopeIdDecls) {
            ScopeDecls *decls_scope = (ScopeDecls *)scope;
            if (decls_scope->fast_math_set_node)
                return decls_scope->fast_math_on;
        }
        scope = scope->parent;
    }
    return false;
}

static bool ir_want_runtime_safety(CodeGen *g, IrInstruction *instruction) {
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

    return (g->build_mode != BuildModeFastRelease &&
            g->build_mode != BuildModeSmallRelease);
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
        case PanicMsgIdUnwrapOptionalFail:
            return buf_create_from_str("attempt to unwrap null");
        case PanicMsgIdUnreachable:
            return buf_create_from_str("reached unreachable code");
        case PanicMsgIdInvalidErrorCode:
            return buf_create_from_str("invalid error code");
        case PanicMsgIdIncorrectAlignment:
            return buf_create_from_str("incorrect alignment");
        case PanicMsgIdBadUnionField:
            return buf_create_from_str("access of inactive union field");
        case PanicMsgIdBadEnumValue:
            return buf_create_from_str("invalid enum value");
        case PanicMsgIdFloatToInt:
            return buf_create_from_str("integer part of floating point value out of bounds");
        case PanicMsgIdPtrCastNull:
            return buf_create_from_str("cast causes pointer to be null");
    }
    zig_unreachable();
}

static LLVMValueRef get_panic_msg_ptr_val(CodeGen *g, PanicMsgId msg_id) {
    ConstExprValue *val = &g->panic_msg_vals[msg_id];
    if (!val->global_refs->llvm_global) {

        Buf *buf_msg = panic_msg_buf(msg_id);
        ConstExprValue *array_val = create_const_str_lit(g, buf_msg);
        init_const_slice(g, val, array_val, 0, buf_len(buf_msg), true);

        render_const_val(g, val, "");
        render_const_val_global(g, val, "");

        assert(val->global_refs->llvm_global);
    }

    ZigType *u8_ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0, false);
    ZigType *str_type = get_slice_type(g, u8_ptr_type);
    return LLVMConstBitCast(val->global_refs->llvm_global, LLVMPointerType(get_llvm_type(g, str_type), 0));
}

static void gen_panic(CodeGen *g, LLVMValueRef msg_arg, LLVMValueRef stack_trace_arg) {
    assert(g->panic_fn != nullptr);
    LLVMValueRef fn_val = fn_llvm_value(g, g->panic_fn);
    LLVMCallConv llvm_cc = get_llvm_cc(g, g->panic_fn->type_entry->data.fn.fn_type_id.cc);
    if (stack_trace_arg == nullptr) {
        ZigType *ptr_to_stack_trace_type = get_ptr_to_stack_trace_type(g);
        stack_trace_arg = LLVMConstNull(get_llvm_type(g, ptr_to_stack_trace_type));
    }
    LLVMValueRef args[] = {
        msg_arg,
        stack_trace_arg,
    };
    LLVMValueRef call_instruction = ZigLLVMBuildCall(g->builder, fn_val, args, 2, llvm_cc, ZigLLVM_FnInlineAuto, "");
    LLVMSetTailCall(call_instruction, true);
    LLVMBuildUnreachable(g->builder);
}

// TODO update most callsites to call gen_assertion instead of this
static void gen_safety_crash(CodeGen *g, PanicMsgId msg_id) {
    gen_panic(g, get_panic_msg_ptr_val(g, msg_id), nullptr);
}

static void gen_assertion(CodeGen *g, PanicMsgId msg_id, IrInstruction *source_instruction) {
    if (ir_want_runtime_safety(g, source_instruction)) {
        gen_safety_crash(g, msg_id);
    } else {
        LLVMBuildUnreachable(g->builder);
    }
}

static LLVMValueRef get_stacksave_fn_val(CodeGen *g) {
    if (g->stacksave_fn_val)
        return g->stacksave_fn_val;

    // declare i8* @llvm.stacksave()

    LLVMTypeRef fn_type = LLVMFunctionType(LLVMPointerType(LLVMInt8Type(), 0), nullptr, 0, false);
    g->stacksave_fn_val = LLVMAddFunction(g->module, "llvm.stacksave", fn_type);
    assert(LLVMGetIntrinsicID(g->stacksave_fn_val));

    return g->stacksave_fn_val;
}

static LLVMValueRef get_stackrestore_fn_val(CodeGen *g) {
    if (g->stackrestore_fn_val)
        return g->stackrestore_fn_val;

    // declare void @llvm.stackrestore(i8* %ptr)

    LLVMTypeRef param_type = LLVMPointerType(LLVMInt8Type(), 0);
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), &param_type, 1, false);
    g->stackrestore_fn_val = LLVMAddFunction(g->module, "llvm.stackrestore", fn_type);
    assert(LLVMGetIntrinsicID(g->stackrestore_fn_val));

    return g->stackrestore_fn_val;
}

static LLVMValueRef get_write_register_fn_val(CodeGen *g) {
    if (g->write_register_fn_val)
        return g->write_register_fn_val;

    // declare void @llvm.write_register.i64(metadata, i64 @value)
    // !0 = !{!"sp\00"}

    LLVMTypeRef param_types[] = {
        LLVMMetadataTypeInContext(LLVMGetGlobalContext()),
        LLVMIntType(g->pointer_size_bytes * 8),
    };

    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), param_types, 2, false);
    Buf *name = buf_sprintf("llvm.write_register.i%d", g->pointer_size_bytes * 8);
    g->write_register_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->write_register_fn_val));

    return g->write_register_fn_val;
}

static LLVMValueRef get_coro_destroy_fn_val(CodeGen *g) {
    if (g->coro_destroy_fn_val)
        return g->coro_destroy_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMPointerType(LLVMInt8Type(), 0),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), param_types, 1, false);
    Buf *name = buf_sprintf("llvm.coro.destroy");
    g->coro_destroy_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_destroy_fn_val));

    return g->coro_destroy_fn_val;
}

static LLVMValueRef get_coro_id_fn_val(CodeGen *g) {
    if (g->coro_id_fn_val)
        return g->coro_id_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMInt32Type(),
        LLVMPointerType(LLVMInt8Type(), 0),
        LLVMPointerType(LLVMInt8Type(), 0),
        LLVMPointerType(LLVMInt8Type(), 0),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(ZigLLVMTokenTypeInContext(LLVMGetGlobalContext()), param_types, 4, false);
    Buf *name = buf_sprintf("llvm.coro.id");
    g->coro_id_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_id_fn_val));

    return g->coro_id_fn_val;
}

static LLVMValueRef get_coro_alloc_fn_val(CodeGen *g) {
    if (g->coro_alloc_fn_val)
        return g->coro_alloc_fn_val;

    LLVMTypeRef param_types[] = {
        ZigLLVMTokenTypeInContext(LLVMGetGlobalContext()),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMInt1Type(), param_types, 1, false);
    Buf *name = buf_sprintf("llvm.coro.alloc");
    g->coro_alloc_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_alloc_fn_val));

    return g->coro_alloc_fn_val;
}

static LLVMValueRef get_coro_size_fn_val(CodeGen *g) {
    if (g->coro_size_fn_val)
        return g->coro_size_fn_val;

    LLVMTypeRef fn_type = LLVMFunctionType(g->builtin_types.entry_usize->llvm_type, nullptr, 0, false);
    Buf *name = buf_sprintf("llvm.coro.size.i%d", g->pointer_size_bytes * 8);
    g->coro_size_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_size_fn_val));

    return g->coro_size_fn_val;
}

static LLVMValueRef get_coro_begin_fn_val(CodeGen *g) {
    if (g->coro_begin_fn_val)
        return g->coro_begin_fn_val;

    LLVMTypeRef param_types[] = {
        ZigLLVMTokenTypeInContext(LLVMGetGlobalContext()),
        LLVMPointerType(LLVMInt8Type(), 0),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMPointerType(LLVMInt8Type(), 0), param_types, 2, false);
    Buf *name = buf_sprintf("llvm.coro.begin");
    g->coro_begin_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_begin_fn_val));

    return g->coro_begin_fn_val;
}

static LLVMValueRef get_coro_suspend_fn_val(CodeGen *g) {
    if (g->coro_suspend_fn_val)
        return g->coro_suspend_fn_val;

    LLVMTypeRef param_types[] = {
        ZigLLVMTokenTypeInContext(LLVMGetGlobalContext()),
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMInt8Type(), param_types, 2, false);
    Buf *name = buf_sprintf("llvm.coro.suspend");
    g->coro_suspend_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_suspend_fn_val));

    return g->coro_suspend_fn_val;
}

static LLVMValueRef get_coro_end_fn_val(CodeGen *g) {
    if (g->coro_end_fn_val)
        return g->coro_end_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMPointerType(LLVMInt8Type(), 0),
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMInt1Type(), param_types, 2, false);
    Buf *name = buf_sprintf("llvm.coro.end");
    g->coro_end_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_end_fn_val));

    return g->coro_end_fn_val;
}

static LLVMValueRef get_coro_free_fn_val(CodeGen *g) {
    if (g->coro_free_fn_val)
        return g->coro_free_fn_val;

    LLVMTypeRef param_types[] = {
        ZigLLVMTokenTypeInContext(LLVMGetGlobalContext()),
        LLVMPointerType(LLVMInt8Type(), 0),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMPointerType(LLVMInt8Type(), 0), param_types, 2, false);
    Buf *name = buf_sprintf("llvm.coro.free");
    g->coro_free_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_free_fn_val));

    return g->coro_free_fn_val;
}

static LLVMValueRef get_coro_resume_fn_val(CodeGen *g) {
    if (g->coro_resume_fn_val)
        return g->coro_resume_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMPointerType(LLVMInt8Type(), 0),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), param_types, 1, false);
    Buf *name = buf_sprintf("llvm.coro.resume");
    g->coro_resume_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_resume_fn_val));

    return g->coro_resume_fn_val;
}

static LLVMValueRef get_coro_save_fn_val(CodeGen *g) {
    if (g->coro_save_fn_val)
        return g->coro_save_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMPointerType(LLVMInt8Type(), 0),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(ZigLLVMTokenTypeInContext(LLVMGetGlobalContext()), param_types, 1, false);
    Buf *name = buf_sprintf("llvm.coro.save");
    g->coro_save_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_save_fn_val));

    return g->coro_save_fn_val;
}

static LLVMValueRef get_coro_promise_fn_val(CodeGen *g) {
    if (g->coro_promise_fn_val)
        return g->coro_promise_fn_val;

    LLVMTypeRef param_types[] = {
        LLVMPointerType(LLVMInt8Type(), 0),
        LLVMInt32Type(),
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMPointerType(LLVMInt8Type(), 0), param_types, 3, false);
    Buf *name = buf_sprintf("llvm.coro.promise");
    g->coro_promise_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_promise_fn_val));

    return g->coro_promise_fn_val;
}

static LLVMValueRef get_return_address_fn_val(CodeGen *g) {
    if (g->return_address_fn_val)
        return g->return_address_fn_val;

    ZigType *return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

    LLVMTypeRef fn_type = LLVMFunctionType(get_llvm_type(g, return_type),
            &g->builtin_types.entry_i32->llvm_type, 1, false);
    g->return_address_fn_val = LLVMAddFunction(g->module, "llvm.returnaddress", fn_type);
    assert(LLVMGetIntrinsicID(g->return_address_fn_val));

    return g->return_address_fn_val;
}

static LLVMValueRef get_add_error_return_trace_addr_fn(CodeGen *g) {
    if (g->add_error_return_trace_addr_fn_val != nullptr)
        return g->add_error_return_trace_addr_fn_val;

    LLVMTypeRef arg_types[] = {
        get_llvm_type(g, get_ptr_to_stack_trace_type(g)),
        g->builtin_types.entry_usize->llvm_type,
    };
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 2, false);

    Buf *fn_name = get_mangled_name(g, buf_create_from_str("__zig_add_err_ret_trace_addr"), false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(fn_name), fn_type_ref);
    addLLVMFnAttr(fn_val, "alwaysinline");
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    LLVMSetFunctionCallConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    // Error return trace memory is in the stack, which is impossible to be at address 0
    // on any architecture.
    addLLVMArgAttr(fn_val, (unsigned)0, "nonnull");
    if (g->build_mode == BuildModeDebug) {
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim", "true");
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim-non-leaf", nullptr);
    }

    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn_val, "Entry");
    LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
    LLVMValueRef prev_debug_location = LLVMGetCurrentDebugLocation(g->builder);
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
    ZigLLVMClearCurrentDebugLocation(g->builder);

    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;

    // stack_trace.instruction_addresses[stack_trace.index & (stack_trace.instruction_addresses.len - 1)] = return_address;

    LLVMValueRef err_ret_trace_ptr = LLVMGetParam(fn_val, 0);
    LLVMValueRef address_value = LLVMGetParam(fn_val, 1);

    size_t index_field_index = g->stack_trace_type->data.structure.fields[0].gen_index;
    LLVMValueRef index_field_ptr = LLVMBuildStructGEP(g->builder, err_ret_trace_ptr, (unsigned)index_field_index, "");
    size_t addresses_field_index = g->stack_trace_type->data.structure.fields[1].gen_index;
    LLVMValueRef addresses_field_ptr = LLVMBuildStructGEP(g->builder, err_ret_trace_ptr, (unsigned)addresses_field_index, "");

    ZigType *slice_type = g->stack_trace_type->data.structure.fields[1].type_entry;
    size_t ptr_field_index = slice_type->data.structure.fields[slice_ptr_index].gen_index;
    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, addresses_field_ptr, (unsigned)ptr_field_index, "");
    size_t len_field_index = slice_type->data.structure.fields[slice_len_index].gen_index;
    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, addresses_field_ptr, (unsigned)len_field_index, "");

    LLVMValueRef len_value = gen_load_untyped(g, len_field_ptr, 0, false, "");
    LLVMValueRef index_val = gen_load_untyped(g, index_field_ptr, 0, false, "");
    LLVMValueRef len_val_minus_one = LLVMBuildSub(g->builder, len_value, LLVMConstInt(usize_type_ref, 1, false), "");
    LLVMValueRef masked_val = LLVMBuildAnd(g->builder, index_val, len_val_minus_one, "");
    LLVMValueRef address_indices[] = {
        masked_val,
    };

    LLVMValueRef ptr_value = gen_load_untyped(g, ptr_field_ptr, 0, false, "");
    LLVMValueRef address_slot = LLVMBuildInBoundsGEP(g->builder, ptr_value, address_indices, 1, "");

    gen_store_untyped(g, address_value, address_slot, 0, false);

    // stack_trace.index += 1;
    LLVMValueRef index_plus_one_val = LLVMBuildNUWAdd(g->builder, index_val, LLVMConstInt(usize_type_ref, 1, false), "");
    gen_store_untyped(g, index_plus_one_val, index_field_ptr, 0, false);

    // return;
    LLVMBuildRetVoid(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    if (!g->strip_debug_symbols) {
        LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);
    }

    g->add_error_return_trace_addr_fn_val = fn_val;
    return fn_val;
}

static LLVMValueRef get_merge_err_ret_traces_fn_val(CodeGen *g) {
    if (g->merge_err_ret_traces_fn_val)
        return g->merge_err_ret_traces_fn_val;

    assert(g->stack_trace_type != nullptr);

    LLVMTypeRef param_types[] = {
        get_llvm_type(g, get_ptr_to_stack_trace_type(g)),
        get_llvm_type(g, get_ptr_to_stack_trace_type(g)),
    };
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMVoidType(), param_types, 2, false);

    Buf *fn_name = get_mangled_name(g, buf_create_from_str("__zig_merge_error_return_traces"), false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(fn_name), fn_type_ref);
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    LLVMSetFunctionCallConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    // Error return trace memory is in the stack, which is impossible to be at address 0
    // on any architecture.
    addLLVMArgAttr(fn_val, (unsigned)0, "nonnull");
    addLLVMArgAttr(fn_val, (unsigned)0, "noalias");
    addLLVMArgAttr(fn_val, (unsigned)0, "writeonly");
    // Error return trace memory is in the stack, which is impossible to be at address 0
    // on any architecture.
    addLLVMArgAttr(fn_val, (unsigned)1, "nonnull");
    addLLVMArgAttr(fn_val, (unsigned)1, "noalias");
    addLLVMArgAttr(fn_val, (unsigned)1, "readonly");
    if (g->build_mode == BuildModeDebug) {
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim", "true");
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim-non-leaf", nullptr);
    }

    // this is above the ZigLLVMClearCurrentDebugLocation
    LLVMValueRef add_error_return_trace_addr_fn_val = get_add_error_return_trace_addr_fn(g);

    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn_val, "Entry");
    LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
    LLVMValueRef prev_debug_location = LLVMGetCurrentDebugLocation(g->builder);
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
    ZigLLVMClearCurrentDebugLocation(g->builder);

    // var frame_index: usize = undefined;
    // var frames_left: usize = undefined;
    // if (src_stack_trace.index < src_stack_trace.instruction_addresses.len) {
    //     frame_index = 0;
    //     frames_left = src_stack_trace.index;
    //     if (frames_left == 0) return;
    // } else {
    //     frame_index = (src_stack_trace.index + 1) % src_stack_trace.instruction_addresses.len;
    //     frames_left = src_stack_trace.instruction_addresses.len;
    // }
    // while (true) {
    //     __zig_add_err_ret_trace_addr(dest_stack_trace, src_stack_trace.instruction_addresses[frame_index]);
    //     frames_left -= 1;
    //     if (frames_left == 0) return;
    //     frame_index = (frame_index + 1) % src_stack_trace.instruction_addresses.len;
    // }
    LLVMBasicBlockRef return_block = LLVMAppendBasicBlock(fn_val, "Return");

    LLVMValueRef frame_index_ptr = LLVMBuildAlloca(g->builder, g->builtin_types.entry_usize->llvm_type, "frame_index");
    LLVMValueRef frames_left_ptr = LLVMBuildAlloca(g->builder, g->builtin_types.entry_usize->llvm_type, "frames_left");

    LLVMValueRef dest_stack_trace_ptr = LLVMGetParam(fn_val, 0);
    LLVMValueRef src_stack_trace_ptr = LLVMGetParam(fn_val, 1);

    size_t src_index_field_index = g->stack_trace_type->data.structure.fields[0].gen_index;
    size_t src_addresses_field_index = g->stack_trace_type->data.structure.fields[1].gen_index;
    LLVMValueRef src_index_field_ptr = LLVMBuildStructGEP(g->builder, src_stack_trace_ptr,
            (unsigned)src_index_field_index, "");
    LLVMValueRef src_addresses_field_ptr = LLVMBuildStructGEP(g->builder, src_stack_trace_ptr,
            (unsigned)src_addresses_field_index, "");
    ZigType *slice_type = g->stack_trace_type->data.structure.fields[1].type_entry;
    size_t ptr_field_index = slice_type->data.structure.fields[slice_ptr_index].gen_index;
    LLVMValueRef src_ptr_field_ptr = LLVMBuildStructGEP(g->builder, src_addresses_field_ptr, (unsigned)ptr_field_index, "");
    size_t len_field_index = slice_type->data.structure.fields[slice_len_index].gen_index;
    LLVMValueRef src_len_field_ptr = LLVMBuildStructGEP(g->builder, src_addresses_field_ptr, (unsigned)len_field_index, "");
    LLVMValueRef src_index_val = LLVMBuildLoad(g->builder, src_index_field_ptr, "");
    LLVMValueRef src_ptr_val = LLVMBuildLoad(g->builder, src_ptr_field_ptr, "");
    LLVMValueRef src_len_val = LLVMBuildLoad(g->builder, src_len_field_ptr, "");
    LLVMValueRef no_wrap_bit = LLVMBuildICmp(g->builder, LLVMIntULT, src_index_val, src_len_val, "");
    LLVMBasicBlockRef no_wrap_block = LLVMAppendBasicBlock(fn_val, "NoWrap");
    LLVMBasicBlockRef yes_wrap_block = LLVMAppendBasicBlock(fn_val, "YesWrap");
    LLVMBasicBlockRef loop_block = LLVMAppendBasicBlock(fn_val, "Loop");
    LLVMBuildCondBr(g->builder, no_wrap_bit, no_wrap_block, yes_wrap_block);

    LLVMPositionBuilderAtEnd(g->builder, no_wrap_block);
    LLVMValueRef usize_zero = LLVMConstNull(g->builtin_types.entry_usize->llvm_type);
    LLVMBuildStore(g->builder, usize_zero, frame_index_ptr);
    LLVMBuildStore(g->builder, src_index_val, frames_left_ptr);
    LLVMValueRef frames_left_eq_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, src_index_val, usize_zero, "");
    LLVMBuildCondBr(g->builder, frames_left_eq_zero_bit, return_block, loop_block);

    LLVMPositionBuilderAtEnd(g->builder, yes_wrap_block);
    LLVMValueRef usize_one = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, 1, false);
    LLVMValueRef plus_one = LLVMBuildNUWAdd(g->builder, src_index_val, usize_one, "");
    LLVMValueRef mod_len = LLVMBuildURem(g->builder, plus_one, src_len_val, "");
    LLVMBuildStore(g->builder, mod_len, frame_index_ptr);
    LLVMBuildStore(g->builder, src_len_val, frames_left_ptr);
    LLVMBuildBr(g->builder, loop_block);

    LLVMPositionBuilderAtEnd(g->builder, loop_block);
    LLVMValueRef ptr_index = LLVMBuildLoad(g->builder, frame_index_ptr, "");
    LLVMValueRef addr_ptr = LLVMBuildInBoundsGEP(g->builder, src_ptr_val, &ptr_index, 1, "");
    LLVMValueRef this_addr_val = LLVMBuildLoad(g->builder, addr_ptr, "");
    LLVMValueRef args[] = {dest_stack_trace_ptr, this_addr_val};
    ZigLLVMBuildCall(g->builder, add_error_return_trace_addr_fn_val, args, 2, get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAlways, "");
    LLVMValueRef prev_frames_left = LLVMBuildLoad(g->builder, frames_left_ptr, "");
    LLVMValueRef new_frames_left = LLVMBuildNUWSub(g->builder, prev_frames_left, usize_one, "");
    LLVMValueRef done_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, new_frames_left, usize_zero, "");
    LLVMBasicBlockRef continue_block = LLVMAppendBasicBlock(fn_val, "Continue");
    LLVMBuildCondBr(g->builder, done_bit, return_block, continue_block);

    LLVMPositionBuilderAtEnd(g->builder, return_block);
    LLVMBuildRetVoid(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, continue_block);
    LLVMBuildStore(g->builder, new_frames_left, frames_left_ptr);
    LLVMValueRef prev_index = LLVMBuildLoad(g->builder, frame_index_ptr, "");
    LLVMValueRef index_plus_one = LLVMBuildNUWAdd(g->builder, prev_index, usize_one, "");
    LLVMValueRef index_mod_len = LLVMBuildURem(g->builder, index_plus_one, src_len_val, "");
    LLVMBuildStore(g->builder, index_mod_len, frame_index_ptr);
    LLVMBuildBr(g->builder, loop_block);

    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    if (!g->strip_debug_symbols) {
        LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);
    }

    g->merge_err_ret_traces_fn_val = fn_val;
    return fn_val;

}

static LLVMValueRef get_return_err_fn(CodeGen *g) {
    if (g->return_err_fn != nullptr)
        return g->return_err_fn;

    assert(g->err_tag_type != nullptr);

    LLVMTypeRef arg_types[] = {
        // error return trace pointer
        get_llvm_type(g, get_ptr_to_stack_trace_type(g)),
    };
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 1, false);

    Buf *fn_name = get_mangled_name(g, buf_create_from_str("__zig_return_error"), false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(fn_name), fn_type_ref);
    addLLVMFnAttr(fn_val, "noinline"); // so that we can look at return address
    addLLVMFnAttr(fn_val, "cold");
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    LLVMSetFunctionCallConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    // Error return trace memory is in the stack, which is impossible to be at address 0
    // on any architecture.
    addLLVMArgAttr(fn_val, (unsigned)0, "nonnull");
    if (g->build_mode == BuildModeDebug) {
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim", "true");
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim-non-leaf", nullptr);
    }

    // this is above the ZigLLVMClearCurrentDebugLocation
    LLVMValueRef add_error_return_trace_addr_fn_val = get_add_error_return_trace_addr_fn(g);

    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn_val, "Entry");
    LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
    LLVMValueRef prev_debug_location = LLVMGetCurrentDebugLocation(g->builder);
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
    ZigLLVMClearCurrentDebugLocation(g->builder);

    LLVMValueRef err_ret_trace_ptr = LLVMGetParam(fn_val, 0);

    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, g->builtin_types.entry_i32));
    LLVMValueRef return_address_ptr = LLVMBuildCall(g->builder, get_return_address_fn_val(g), &zero, 1, "");
    LLVMValueRef return_address = LLVMBuildPtrToInt(g->builder, return_address_ptr, usize_type_ref, "");

    LLVMValueRef args[] = { err_ret_trace_ptr, return_address };
    ZigLLVMBuildCall(g->builder, add_error_return_trace_addr_fn_val, args, 2, get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAlways, "");
    LLVMBuildRetVoid(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    if (!g->strip_debug_symbols) {
        LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);
    }

    g->return_err_fn = fn_val;
    return fn_val;
}

static LLVMValueRef get_safety_crash_err_fn(CodeGen *g) {
    if (g->safety_crash_err_fn != nullptr)
        return g->safety_crash_err_fn;

    static const char *unwrap_err_msg_text = "attempt to unwrap error: ";

    g->generate_error_name_table = true;
    generate_error_name_table(g);
    assert(g->err_name_table != nullptr);

    // Generate the constant part of the error message
    LLVMValueRef msg_prefix_init = LLVMConstString(unwrap_err_msg_text, strlen(unwrap_err_msg_text), 1);
    LLVMValueRef msg_prefix = LLVMAddGlobal(g->module, LLVMTypeOf(msg_prefix_init), "");
    LLVMSetInitializer(msg_prefix, msg_prefix_init);
    LLVMSetLinkage(msg_prefix, LLVMInternalLinkage);
    LLVMSetGlobalConstant(msg_prefix, true);

    Buf *fn_name = get_mangled_name(g, buf_create_from_str("__zig_fail_unwrap"), false);
    LLVMTypeRef fn_type_ref;
    if (g->have_err_ret_tracing) {
        LLVMTypeRef arg_types[] = {
            get_llvm_type(g, g->ptr_to_stack_trace_type),
            get_llvm_type(g, g->err_tag_type),
        };
        fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 2, false);
    } else {
        LLVMTypeRef arg_types[] = {
            get_llvm_type(g, g->err_tag_type),
        };
        fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 1, false);
    }
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(fn_name), fn_type_ref);
    addLLVMFnAttr(fn_val, "noreturn");
    addLLVMFnAttr(fn_val, "cold");
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    LLVMSetFunctionCallConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
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

    ZigType *usize_ty = g->builtin_types.entry_usize;
    ZigType *u8_ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0, false);
    ZigType *str_type = get_slice_type(g, u8_ptr_type);

    // Allocate a buffer to hold the fully-formatted error message
    const size_t err_buf_len = strlen(unwrap_err_msg_text) + g->largest_err_name_len;
    LLVMValueRef max_msg_len = LLVMConstInt(usize_ty->llvm_type, err_buf_len, 0);
    LLVMValueRef msg_buffer = LLVMBuildArrayAlloca(g->builder, LLVMInt8Type(), max_msg_len, "msg_buffer");

    // Allocate a []u8 slice for the message
    LLVMValueRef msg_slice = build_alloca(g, str_type, "msg_slice", 0);

    LLVMValueRef err_ret_trace_arg;
    LLVMValueRef err_val;
    if (g->have_err_ret_tracing) {
        err_ret_trace_arg = LLVMGetParam(fn_val, 0);
        err_val = LLVMGetParam(fn_val, 1);
    } else {
        err_ret_trace_arg = nullptr;
        err_val = LLVMGetParam(fn_val, 0);
    }

    // Fetch the error name from the global table
    LLVMValueRef err_table_indices[] = {
        LLVMConstNull(usize_ty->llvm_type),
        err_val,
    };
    LLVMValueRef err_name_val = LLVMBuildInBoundsGEP(g->builder, g->err_name_table, err_table_indices, 2, "");

    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, err_name_val, slice_ptr_index, "");
    LLVMValueRef err_name_ptr = gen_load_untyped(g, ptr_field_ptr, 0, false, "");

    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, err_name_val, slice_len_index, "");
    LLVMValueRef err_name_len = gen_load_untyped(g, len_field_ptr, 0, false, "");

    LLVMValueRef msg_prefix_len = LLVMConstInt(usize_ty->llvm_type, strlen(unwrap_err_msg_text), false);
    // Points to the beginning of msg_buffer
    LLVMValueRef msg_buffer_ptr_indices[] = {
        LLVMConstNull(usize_ty->llvm_type),
    };
    LLVMValueRef msg_buffer_ptr = LLVMBuildInBoundsGEP(g->builder, msg_buffer, msg_buffer_ptr_indices, 1, "");
    // Points to the beginning of the constant prefix message
    LLVMValueRef msg_prefix_ptr_indices[] = {
        LLVMConstNull(usize_ty->llvm_type),
    };
    LLVMValueRef msg_prefix_ptr = LLVMConstInBoundsGEP(msg_prefix, msg_prefix_ptr_indices, 1);

    // Build the message using the prefix...
    ZigLLVMBuildMemCpy(g->builder, msg_buffer_ptr, 1, msg_prefix_ptr, 1, msg_prefix_len, false);
    // ..and append the error name
    LLVMValueRef msg_buffer_ptr_after_indices[] = {
        msg_prefix_len,
    };
    LLVMValueRef msg_buffer_ptr_after = LLVMBuildInBoundsGEP(g->builder, msg_buffer, msg_buffer_ptr_after_indices, 1, "");
    ZigLLVMBuildMemCpy(g->builder, msg_buffer_ptr_after, 1, err_name_ptr, 1, err_name_len, false);

    // Set the slice pointer
    LLVMValueRef msg_slice_ptr_field_ptr = LLVMBuildStructGEP(g->builder, msg_slice, slice_ptr_index, "");
    gen_store_untyped(g, msg_buffer_ptr, msg_slice_ptr_field_ptr, 0, false);

    // Set the slice length
    LLVMValueRef slice_len = LLVMBuildNUWAdd(g->builder, msg_prefix_len, err_name_len, "");
    LLVMValueRef msg_slice_len_field_ptr = LLVMBuildStructGEP(g->builder, msg_slice, slice_len_index, "");
    gen_store_untyped(g, slice_len, msg_slice_len_field_ptr, 0, false);

    // Call panic()
    gen_panic(g, msg_slice, err_ret_trace_arg);

    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    if (!g->strip_debug_symbols) {
        LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);
    }

    g->safety_crash_err_fn = fn_val;
    return fn_val;
}

static bool is_coro_prelude_scope(Scope *scope) {
    while (scope != nullptr) {
        if (scope->id == ScopeIdCoroPrelude) {
            return true;
        } else if (scope->id == ScopeIdFnDef) {
            break;
        }
        scope = scope->parent;
    }
    return false;
}

static LLVMValueRef get_cur_err_ret_trace_val(CodeGen *g, Scope *scope) {
    if (!g->have_err_ret_tracing) {
        return nullptr;
    }
    if (g->cur_fn->type_entry->data.fn.fn_type_id.cc == CallingConventionAsync) {
        return is_coro_prelude_scope(scope) ? g->cur_err_ret_trace_val_arg : g->cur_err_ret_trace_val_stack;
    }
    if (g->cur_err_ret_trace_val_stack != nullptr) {
        return g->cur_err_ret_trace_val_stack;
    }
    return g->cur_err_ret_trace_val_arg;
}

static void gen_safety_crash_for_err(CodeGen *g, LLVMValueRef err_val, Scope *scope) {
    LLVMValueRef safety_crash_err_fn = get_safety_crash_err_fn(g);
    LLVMValueRef call_instruction;
    if (g->have_err_ret_tracing) {
        LLVMValueRef err_ret_trace_val = get_cur_err_ret_trace_val(g, scope);
        if (err_ret_trace_val == nullptr) {
            ZigType *ptr_to_stack_trace_type = get_ptr_to_stack_trace_type(g);
            err_ret_trace_val = LLVMConstNull(get_llvm_type(g, ptr_to_stack_trace_type));
        }
        LLVMValueRef args[] = {
            err_ret_trace_val,
            err_val,
        };
        call_instruction = ZigLLVMBuildCall(g->builder, safety_crash_err_fn, args, 2,
                get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAuto, "");
    } else {
        LLVMValueRef args[] = {
            err_val,
        };
        call_instruction = ZigLLVMBuildCall(g->builder, safety_crash_err_fn, args, 1,
                get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAuto, "");
    }
    LLVMSetTailCall(call_instruction, true);
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
    gen_safety_crash(g, PanicMsgIdBoundsCheckFailure);

    if (upper_value) {
        LLVMPositionBuilderAtEnd(g->builder, lower_ok_block);
        LLVMValueRef upper_ok_val = LLVMBuildICmp(g->builder, upper_pred, target_val, upper_value, "");
        LLVMBuildCondBr(g->builder, upper_ok_val, ok_block, bounds_check_fail_block);
    }

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
}

static LLVMValueRef gen_assert_zero(CodeGen *g, LLVMValueRef expr_val, ZigType *int_type) {
    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, int_type));
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, expr_val, zero, "");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "CastShortenOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "CastShortenFail");
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_safety_crash(g, PanicMsgIdCastTruncatedData);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return nullptr;
}

static LLVMValueRef gen_widen_or_shorten(CodeGen *g, bool want_runtime_safety, ZigType *actual_type,
        ZigType *wanted_type, LLVMValueRef expr_val)
{
    assert(actual_type->id == wanted_type->id);
    assert(expr_val != nullptr);

    uint64_t actual_bits;
    uint64_t wanted_bits;
    if (actual_type->id == ZigTypeIdFloat) {
        actual_bits = actual_type->data.floating.bit_count;
        wanted_bits = wanted_type->data.floating.bit_count;
    } else if (actual_type->id == ZigTypeIdInt) {
        actual_bits = actual_type->data.integral.bit_count;
        wanted_bits = wanted_type->data.integral.bit_count;
    } else {
        zig_unreachable();
    }

    if (actual_type->id == ZigTypeIdInt &&
        !wanted_type->data.integral.is_signed && actual_type->data.integral.is_signed &&
        want_runtime_safety)
    {
        LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, actual_type));
        LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntSGE, expr_val, zero, "");

        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "SignCastOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "SignCastFail");
        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_safety_crash(g, PanicMsgIdCastNegativeToUnsigned);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    if (actual_bits == wanted_bits) {
        return expr_val;
    } else if (actual_bits < wanted_bits) {
        if (actual_type->id == ZigTypeIdFloat) {
            return LLVMBuildFPExt(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
        } else if (actual_type->id == ZigTypeIdInt) {
            if (actual_type->data.integral.is_signed) {
                return LLVMBuildSExt(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            } else {
                return LLVMBuildZExt(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            }
        } else {
            zig_unreachable();
        }
    } else if (actual_bits > wanted_bits) {
        if (actual_type->id == ZigTypeIdFloat) {
            return LLVMBuildFPTrunc(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
        } else if (actual_type->id == ZigTypeIdInt) {
            if (wanted_bits == 0) {
                if (!want_runtime_safety)
                    return nullptr;

                return gen_assert_zero(g, expr_val, actual_type);
            }
            LLVMValueRef trunc_val = LLVMBuildTrunc(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            if (!want_runtime_safety) {
                return trunc_val;
            }
            LLVMValueRef orig_val;
            if (wanted_type->data.integral.is_signed) {
                orig_val = LLVMBuildSExt(g->builder, trunc_val, get_llvm_type(g, actual_type), "");
            } else {
                orig_val = LLVMBuildZExt(g->builder, trunc_val, get_llvm_type(g, actual_type), "");
            }
            LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, expr_val, orig_val, "");
            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "CastShortenOk");
            LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "CastShortenFail");
            LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

            LLVMPositionBuilderAtEnd(g->builder, fail_block);
            gen_safety_crash(g, PanicMsgIdCastTruncatedData);

            LLVMPositionBuilderAtEnd(g->builder, ok_block);
            return trunc_val;
        } else {
            zig_unreachable();
        }
    } else {
        zig_unreachable();
    }
}

typedef LLVMValueRef (*BuildBinOpFunc)(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *);
// These are lookup table using the AddSubMul enum as the lookup.
// If AddSubMul ever changes, then these tables will be out of
// date.
static const BuildBinOpFunc float_op[3] = { LLVMBuildFAdd, LLVMBuildFSub, LLVMBuildFMul };
static const BuildBinOpFunc wrap_op[3] = { LLVMBuildAdd, LLVMBuildSub, LLVMBuildMul };
static const BuildBinOpFunc signed_op[3] = { LLVMBuildNSWAdd, LLVMBuildNSWSub, LLVMBuildNSWMul };
static const BuildBinOpFunc unsigned_op[3] = { LLVMBuildNUWAdd, LLVMBuildNUWSub, LLVMBuildNUWMul };

static LLVMValueRef gen_overflow_op(CodeGen *g, ZigType *operand_type, AddSubMul op,
        LLVMValueRef val1, LLVMValueRef val2)
{
    LLVMValueRef overflow_bit;
    LLVMValueRef result;

    if (operand_type->id == ZigTypeIdVector) {
        ZigType *int_type = operand_type->data.vector.elem_type;
        assert(int_type->id == ZigTypeIdInt);
        LLVMTypeRef one_more_bit_int = LLVMIntType(int_type->data.integral.bit_count + 1);
        LLVMTypeRef one_more_bit_int_vector = LLVMVectorType(one_more_bit_int, operand_type->data.vector.len);
        const auto buildExtFn = int_type->data.integral.is_signed ? LLVMBuildSExt : LLVMBuildZExt;
        LLVMValueRef extended1 = buildExtFn(g->builder, val1, one_more_bit_int_vector, "");
        LLVMValueRef extended2 = buildExtFn(g->builder, val2, one_more_bit_int_vector, "");
        LLVMValueRef extended_result = wrap_op[op](g->builder, extended1, extended2, "");
        result = LLVMBuildTrunc(g->builder, extended_result, get_llvm_type(g, operand_type), "");

        LLVMValueRef re_extended_result = buildExtFn(g->builder, result, one_more_bit_int_vector, "");
        LLVMValueRef overflow_vector = LLVMBuildICmp(g->builder, LLVMIntNE, extended_result, re_extended_result, "");
        LLVMTypeRef bitcast_int_type = LLVMIntType(operand_type->data.vector.len);
        LLVMValueRef bitcasted_overflow = LLVMBuildBitCast(g->builder, overflow_vector, bitcast_int_type, "");
        LLVMValueRef zero = LLVMConstNull(bitcast_int_type);
        overflow_bit = LLVMBuildICmp(g->builder, LLVMIntNE, bitcasted_overflow, zero, "");
    } else {
        LLVMValueRef fn_val = get_int_overflow_fn(g, operand_type, op);
        LLVMValueRef params[] = {
            val1,
            val2,
        };
        LLVMValueRef result_struct = LLVMBuildCall(g->builder, fn_val, params, 2, "");
        result = LLVMBuildExtractValue(g->builder, result_struct, 0, "");
        overflow_bit = LLVMBuildExtractValue(g->builder, result_struct, 1, "");
    }

    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowFail");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowOk");
    LLVMBuildCondBr(g->builder, overflow_bit, fail_block, ok_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_safety_crash(g, PanicMsgIdIntegerOverflow);

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
            return LLVMRealUNE;
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

static LLVMValueRef gen_assign_raw(CodeGen *g, LLVMValueRef ptr, ZigType *ptr_type,
        LLVMValueRef value)
{
    assert(ptr_type->id == ZigTypeIdPointer);
    ZigType *child_type = ptr_type->data.pointer.child_type;

    if (!type_has_bits(child_type))
        return nullptr;

    if (handle_is_ptr(child_type)) {
        assert(LLVMGetTypeKind(LLVMTypeOf(value)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMTypeOf(ptr)) == LLVMPointerTypeKind);

        LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

        LLVMValueRef src_ptr = LLVMBuildBitCast(g->builder, value, ptr_u8, "");
        LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, ptr, ptr_u8, "");

        ZigType *usize = g->builtin_types.entry_usize;
        uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, get_llvm_type(g, child_type));
        uint64_t align_bytes = get_ptr_align(g, ptr_type);
        assert(size_bytes > 0);
        assert(align_bytes > 0);

        ZigLLVMBuildMemCpy(g->builder, dest_ptr, align_bytes, src_ptr, align_bytes,
                LLVMConstInt(usize->llvm_type, size_bytes, false),
                ptr_type->data.pointer.is_volatile);
        return nullptr;
    }

    uint32_t host_int_bytes = ptr_type->data.pointer.host_int_bytes;
    if (host_int_bytes == 0) {
        gen_store(g, value, ptr, ptr_type);
        return nullptr;
    }

    bool big_endian = g->is_big_endian;

    LLVMValueRef containing_int = gen_load(g, ptr, ptr_type, "");
    uint32_t host_bit_count = LLVMGetIntTypeWidth(LLVMTypeOf(containing_int));
    assert(host_bit_count == host_int_bytes * 8);
    uint32_t size_in_bits = type_size_bits(g, child_type);

    uint32_t bit_offset = ptr_type->data.pointer.bit_offset_in_host;
    uint32_t shift_amt = big_endian ? host_bit_count - bit_offset - size_in_bits : bit_offset;
    LLVMValueRef shift_amt_val = LLVMConstInt(LLVMTypeOf(containing_int), shift_amt, false);

    // Convert to equally-sized integer type in order to perform the bit
    // operations on the value to store
    LLVMTypeRef value_bits_type = LLVMIntType(size_in_bits);
    LLVMValueRef value_bits = LLVMBuildBitCast(g->builder, value, value_bits_type, "");

    LLVMValueRef mask_val = LLVMConstAllOnes(value_bits_type);
    mask_val = LLVMConstZExt(mask_val, LLVMTypeOf(containing_int));
    mask_val = LLVMConstShl(mask_val, shift_amt_val);
    mask_val = LLVMConstNot(mask_val);

    LLVMValueRef anded_containing_int = LLVMBuildAnd(g->builder, containing_int, mask_val, "");
    LLVMValueRef extended_value = LLVMBuildZExt(g->builder, value_bits, LLVMTypeOf(containing_int), "");
    LLVMValueRef shifted_value = LLVMBuildShl(g->builder, extended_value, shift_amt_val, "");
    LLVMValueRef ored_value = LLVMBuildOr(g->builder, shifted_value, anded_containing_int, "");

    gen_store(g, ored_value, ptr, ptr_type);
    return nullptr;
}

static void gen_var_debug_decl(CodeGen *g, ZigVar *var) {
    if (g->strip_debug_symbols) return;
    assert(var->di_loc_var != nullptr);
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
        src_assert(instruction->value.special != ConstValSpecialRuntime, instruction->source_node);
        assert(instruction->value.type);
        render_const_val(g, &instruction->value, "");
        // we might have to do some pointer casting here due to the way union
        // values are rendered with a type other than the one we expect
        if (handle_is_ptr(instruction->value.type)) {
            render_const_val_global(g, &instruction->value, "");
            ZigType *ptr_type = get_pointer_to_type(g, instruction->value.type, true);
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value.global_refs->llvm_global, get_llvm_type(g, ptr_type), "");
        } else {
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value.global_refs->llvm_value,
                    get_llvm_type(g, instruction->value.type), "");
        }
        assert(instruction->llvm_value);
    }
    return instruction->llvm_value;
}

ATTRIBUTE_NORETURN
static void report_errors_and_exit(CodeGen *g) {
    assert(g->errors.length != 0);
    for (size_t i = 0; i < g->errors.length; i += 1) {
        ErrorMsg *err = g->errors.at(i);
        print_err_msg(err, g->err_color);
    }
    exit(1);
}

static void report_errors_and_maybe_exit(CodeGen *g) {
    if (g->errors.length != 0) {
        report_errors_and_exit(g);
    }
}

ATTRIBUTE_NORETURN
static void give_up_with_c_abi_error(CodeGen *g, AstNode *source_node) {
    ErrorMsg *msg = add_node_error(g, source_node,
            buf_sprintf("TODO: support C ABI for more targets. https://github.com/ziglang/zig/issues/1481"));
    add_error_note(g, msg, source_node,
        buf_sprintf("pointers, integers, floats, bools, and enums work on all targets"));
    report_errors_and_exit(g);
}

static LLVMValueRef build_alloca(CodeGen *g, ZigType *type_entry, const char *name, uint32_t alignment) {
    LLVMValueRef result = LLVMBuildAlloca(g->builder, get_llvm_type(g, type_entry), name);
    LLVMSetAlignment(result, (alignment == 0) ? get_abi_alignment(g, type_entry) : alignment);
    return result;
}

static bool iter_function_params_c_abi(CodeGen *g, ZigType *fn_type, FnWalk *fn_walk, size_t src_i) {
    // Initialized from the type for some walks, but because of C var args,
    // initialized based on callsite instructions for that one.
    FnTypeParamInfo *param_info = nullptr;
    ZigType *ty;
    ZigType *dest_ty = nullptr;
    AstNode *source_node = nullptr;
    LLVMValueRef val;
    LLVMValueRef llvm_fn;
    unsigned di_arg_index;
    ZigVar *var;
    switch (fn_walk->id) {
        case FnWalkIdAttrs:
            if (src_i >= fn_type->data.fn.fn_type_id.param_count)
                return false;
            param_info = &fn_type->data.fn.fn_type_id.param_info[src_i];
            ty = param_info->type;
            source_node = fn_walk->data.attrs.fn->proto_node;
            llvm_fn = fn_walk->data.attrs.fn->llvm_value;
            break;
        case FnWalkIdCall: {
            if (src_i >= fn_walk->data.call.inst->arg_count)
                return false;
            IrInstruction *arg = fn_walk->data.call.inst->args[src_i];
            ty = arg->value.type;
            source_node = arg->source_node;
            val = ir_llvm_value(g, arg);
            break;
        }
        case FnWalkIdTypes:
            if (src_i >= fn_type->data.fn.fn_type_id.param_count)
                return false;
            param_info = &fn_type->data.fn.fn_type_id.param_info[src_i];
            ty = param_info->type;
            break;
        case FnWalkIdVars:
            assert(src_i < fn_type->data.fn.fn_type_id.param_count);
            param_info = &fn_type->data.fn.fn_type_id.param_info[src_i];
            ty = param_info->type;
            var = fn_walk->data.vars.var;
            source_node = var->decl_node;
            llvm_fn = fn_walk->data.vars.llvm_fn;
            break;
        case FnWalkIdInits:
            if (src_i >= fn_type->data.fn.fn_type_id.param_count)
                return false;
            param_info = &fn_type->data.fn.fn_type_id.param_info[src_i];
            ty = param_info->type;
            var = fn_walk->data.inits.fn->variable_list.at(src_i);
            source_node = fn_walk->data.inits.fn->proto_node;
            llvm_fn = fn_walk->data.inits.llvm_fn;
            break;
    }

    if (type_is_c_abi_int(g, ty) || ty->id == ZigTypeIdFloat || ty->id == ZigTypeIdVector ||
        ty->id == ZigTypeIdInt // TODO investigate if we need to change this
    ) {
        switch (fn_walk->id) {
            case FnWalkIdAttrs: {
                ZigType *ptr_type = get_codegen_ptr_type(ty);
                if (ptr_type != nullptr) {
                    if (type_is_nonnull_ptr(ty)) {
                        addLLVMArgAttr(llvm_fn, fn_walk->data.attrs.gen_i, "nonnull");
                    }
                    if (ptr_type->data.pointer.is_const) {
                        addLLVMArgAttr(llvm_fn, fn_walk->data.attrs.gen_i, "readonly");
                    }
                    if (param_info->is_noalias) {
                        addLLVMArgAttr(llvm_fn, fn_walk->data.attrs.gen_i, "noalias");
                    }
                }
                fn_walk->data.attrs.gen_i += 1;
                break;
            }
            case FnWalkIdCall:
                fn_walk->data.call.gen_param_values->append(val);
                break;
            case FnWalkIdTypes:
                fn_walk->data.types.gen_param_types->append(get_llvm_type(g, ty));
                fn_walk->data.types.param_di_types->append(get_llvm_di_type(g, ty));
                break;
            case FnWalkIdVars: {
                var->value_ref = build_alloca(g, ty, buf_ptr(&var->name), var->align_bytes);
                di_arg_index = fn_walk->data.vars.gen_i;
                fn_walk->data.vars.gen_i += 1;
                dest_ty = ty;
                goto var_ok;
            }
            case FnWalkIdInits:
                clear_debug_source_node(g);
                gen_store_untyped(g, LLVMGetParam(llvm_fn, fn_walk->data.inits.gen_i), var->value_ref, var->align_bytes, false);
                if (var->decl_node) {
                    gen_var_debug_decl(g, var);
                }
                fn_walk->data.inits.gen_i += 1;
                break;
        }
        return true;
    }

    // Arrays are just pointers
    if (ty->id == ZigTypeIdArray) {
        assert(handle_is_ptr(ty));
        switch (fn_walk->id) {
            case FnWalkIdAttrs:
                // arrays passed to C ABI functions may not be at address 0
                addLLVMArgAttr(llvm_fn, fn_walk->data.attrs.gen_i, "nonnull");
                addLLVMArgAttrInt(llvm_fn, fn_walk->data.attrs.gen_i, "align", get_abi_alignment(g, ty));
                fn_walk->data.attrs.gen_i += 1;
                break;
            case FnWalkIdCall:
                fn_walk->data.call.gen_param_values->append(val);
                break;
            case FnWalkIdTypes: {
                ZigType *gen_type = get_pointer_to_type(g, ty, true);
                fn_walk->data.types.gen_param_types->append(get_llvm_type(g, gen_type));
                fn_walk->data.types.param_di_types->append(get_llvm_di_type(g, gen_type));
                break;
            }
            case FnWalkIdVars: {
                var->value_ref = LLVMGetParam(llvm_fn,  fn_walk->data.vars.gen_i);
                di_arg_index = fn_walk->data.vars.gen_i;
                dest_ty = get_pointer_to_type(g, ty, false);
                fn_walk->data.vars.gen_i += 1;
                goto var_ok;
            }
            case FnWalkIdInits:
                if (var->decl_node) {
                    gen_var_debug_decl(g, var);
                }
                fn_walk->data.inits.gen_i += 1;
                break;
        }
        return true;
    }

    if (g->zig_target->arch == ZigLLVM_x86_64) {
        X64CABIClass abi_class = type_c_abi_x86_64_class(g, ty);
        size_t ty_size = type_size(g, ty);
        if (abi_class == X64CABIClass_MEMORY) {
            assert(handle_is_ptr(ty));
            switch (fn_walk->id) {
                case FnWalkIdAttrs:
                    addLLVMArgAttr(llvm_fn, fn_walk->data.attrs.gen_i, "byval");
                    addLLVMArgAttrInt(llvm_fn, fn_walk->data.attrs.gen_i, "align", get_abi_alignment(g, ty));
                    // Byvalue parameters must not have address 0
                    addLLVMArgAttr(llvm_fn, fn_walk->data.attrs.gen_i, "nonnull");
                    fn_walk->data.attrs.gen_i += 1;
                    break;
                case FnWalkIdCall:
                    fn_walk->data.call.gen_param_values->append(val);
                    break;
                case FnWalkIdTypes: {
                    ZigType *gen_type = get_pointer_to_type(g, ty, true);
                    fn_walk->data.types.gen_param_types->append(get_llvm_type(g, gen_type));
                    fn_walk->data.types.param_di_types->append(get_llvm_di_type(g, gen_type));
                    break;
                }
                case FnWalkIdVars: {
                    di_arg_index = fn_walk->data.vars.gen_i;
                    var->value_ref = LLVMGetParam(llvm_fn,  fn_walk->data.vars.gen_i);
                    dest_ty = get_pointer_to_type(g, ty, false);
                    fn_walk->data.vars.gen_i += 1;
                    goto var_ok;
                }
                case FnWalkIdInits:
                    if (var->decl_node) {
                        gen_var_debug_decl(g, var);
                    }
                    fn_walk->data.inits.gen_i += 1;
                    break;
            }
            return true;
        } else if (abi_class == X64CABIClass_INTEGER) {
            switch (fn_walk->id) {
                case FnWalkIdAttrs:
                    fn_walk->data.attrs.gen_i += 1;
                    break;
                case FnWalkIdCall: {
                    LLVMTypeRef ptr_to_int_type_ref = LLVMPointerType(LLVMIntType((unsigned)ty_size * 8), 0);
                    LLVMValueRef bitcasted = LLVMBuildBitCast(g->builder, val, ptr_to_int_type_ref, "");
                    LLVMValueRef loaded = LLVMBuildLoad(g->builder, bitcasted, "");
                    fn_walk->data.call.gen_param_values->append(loaded);
                    break;
                }
                case FnWalkIdTypes: {
                    ZigType *gen_type = get_int_type(g, false, ty_size * 8);
                    fn_walk->data.types.gen_param_types->append(get_llvm_type(g, gen_type));
                    fn_walk->data.types.param_di_types->append(get_llvm_di_type(g, gen_type));
                    break;
                }
                case FnWalkIdVars: {
                    di_arg_index = fn_walk->data.vars.gen_i;
                    var->value_ref = build_alloca(g, ty, buf_ptr(&var->name), var->align_bytes);
                    fn_walk->data.vars.gen_i += 1;
                    dest_ty = ty;
                    goto var_ok;
                }
                case FnWalkIdInits: {
                    clear_debug_source_node(g);
                    LLVMValueRef arg = LLVMGetParam(llvm_fn, fn_walk->data.inits.gen_i);
                    LLVMTypeRef ptr_to_int_type_ref = LLVMPointerType(LLVMIntType((unsigned)ty_size * 8), 0);
                    LLVMValueRef bitcasted = LLVMBuildBitCast(g->builder, var->value_ref, ptr_to_int_type_ref, "");
                    gen_store_untyped(g, arg, bitcasted, var->align_bytes, false);
                    if (var->decl_node) {
                        gen_var_debug_decl(g, var);
                    }
                    fn_walk->data.inits.gen_i += 1;
                    break;
                }
            }
            return true;
        }
    }
    if (source_node != nullptr) {
        give_up_with_c_abi_error(g, source_node);
    }
    // otherwise allow codegen code to report a compile error
    return false;

var_ok:
    if (dest_ty != nullptr && var->decl_node) {
        // arg index + 1 because the 0 index is return value
        var->di_loc_var = ZigLLVMCreateParameterVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                buf_ptr(&var->name), fn_walk->data.vars.import->data.structure.root_struct->di_file,
                (unsigned)(var->decl_node->line + 1),
                get_llvm_di_type(g, dest_ty), !g->strip_debug_symbols, 0, di_arg_index + 1);
    }
    return true;
}

void walk_function_params(CodeGen *g, ZigType *fn_type, FnWalk *fn_walk) {
    CallingConvention cc = fn_type->data.fn.fn_type_id.cc;
    if (cc == CallingConventionC) {
        size_t src_i = 0;
        for (;;) {
            if (!iter_function_params_c_abi(g, fn_type, fn_walk, src_i))
                break;
            src_i += 1;
        }
        return;
    }
    if (fn_walk->id == FnWalkIdCall) {
        IrInstructionCallGen *instruction = fn_walk->data.call.inst;
        bool is_var_args = fn_walk->data.call.is_var_args;
        for (size_t call_i = 0; call_i < instruction->arg_count; call_i += 1) {
            IrInstruction *param_instruction = instruction->args[call_i];
            ZigType *param_type = param_instruction->value.type;
            if (is_var_args || type_has_bits(param_type)) {
                LLVMValueRef param_value = ir_llvm_value(g, param_instruction);
                assert(param_value);
                fn_walk->data.call.gen_param_values->append(param_value);
            }
        }
        return;
    }
    size_t next_var_i = 0;
    for (size_t param_i = 0; param_i < fn_type->data.fn.fn_type_id.param_count; param_i += 1) {
        FnGenParamInfo *gen_info = &fn_type->data.fn.gen_param_info[param_i];
        size_t gen_index = gen_info->gen_index;

        if (gen_index == SIZE_MAX) {
            continue;
        }

        switch (fn_walk->id) {
            case FnWalkIdAttrs: {
                LLVMValueRef llvm_fn = fn_walk->data.attrs.fn->llvm_value;
                bool is_byval = gen_info->is_byval;
                FnTypeParamInfo *param_info = &fn_type->data.fn.fn_type_id.param_info[param_i];

                ZigType *param_type = gen_info->type;
                if (param_info->is_noalias) {
                    addLLVMArgAttr(llvm_fn, (unsigned)gen_index, "noalias");
                }
                if ((param_type->id == ZigTypeIdPointer && param_type->data.pointer.is_const) || is_byval) {
                    addLLVMArgAttr(llvm_fn, (unsigned)gen_index, "readonly");
                }
                if (get_codegen_ptr_type(param_type) != nullptr) {
                    addLLVMArgAttrInt(llvm_fn, (unsigned)gen_index, "align", get_ptr_align(g, param_type));
                }
                if (type_is_nonnull_ptr(param_type)) {
                    addLLVMArgAttr(llvm_fn, (unsigned)gen_index, "nonnull");
                }
                break;
            }
            case FnWalkIdInits: {
                ZigFn *fn_table_entry = fn_walk->data.inits.fn;
                LLVMValueRef llvm_fn = fn_table_entry->llvm_value;
                ZigVar *variable = fn_table_entry->variable_list.at(next_var_i);
                assert(variable->src_arg_index != SIZE_MAX);
                next_var_i += 1;

                assert(variable);
                assert(variable->value_ref);

                if (!handle_is_ptr(variable->var_type)) {
                    clear_debug_source_node(g);
                    ZigType *fn_type = fn_table_entry->type_entry;
                    unsigned gen_arg_index = fn_type->data.fn.gen_param_info[variable->src_arg_index].gen_index;
                    gen_store_untyped(g, LLVMGetParam(llvm_fn, gen_arg_index),
                            variable->value_ref, variable->align_bytes, false);
                }

                if (variable->decl_node) {
                    gen_var_debug_decl(g, variable);
                }
                break;
            }
            case FnWalkIdCall:
                // handled before for loop
                zig_unreachable();
            case FnWalkIdTypes:
                // Not called for non-c-abi
                zig_unreachable();
            case FnWalkIdVars:
                // iter_function_params_c_abi is called directly for this one
                zig_unreachable();
        }
    }
}

static LLVMValueRef ir_render_save_err_ret_addr(CodeGen *g, IrExecutable *executable,
        IrInstructionSaveErrRetAddr *save_err_ret_addr_instruction)
{
    assert(g->have_err_ret_tracing);

    LLVMValueRef return_err_fn = get_return_err_fn(g);
    LLVMValueRef args[] = {
        get_cur_err_ret_trace_val(g, save_err_ret_addr_instruction->base.scope),
    };
    LLVMValueRef call_instruction = ZigLLVMBuildCall(g->builder, return_err_fn, args, 1,
            get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAuto, "");
    return call_instruction;
}

static LLVMValueRef ir_render_return(CodeGen *g, IrExecutable *executable, IrInstructionReturn *return_instruction) {
    if (want_first_arg_sret(g, &g->cur_fn->type_entry->data.fn.fn_type_id)) {
        if (return_instruction->value == nullptr) {
            LLVMBuildRetVoid(g->builder);
            return nullptr;
        }
        assert(g->cur_ret_ptr);
        src_assert(return_instruction->value->value.special != ConstValSpecialRuntime,
                return_instruction->base.source_node);
        LLVMValueRef value = ir_llvm_value(g, return_instruction->value);
        ZigType *return_type = return_instruction->value->value.type;
        gen_assign_raw(g, g->cur_ret_ptr, get_pointer_to_type(g, return_type, false), value);
        LLVMBuildRetVoid(g->builder);
    } else if (g->cur_fn->type_entry->data.fn.fn_type_id.cc != CallingConventionAsync &&
            handle_is_ptr(g->cur_fn->type_entry->data.fn.fn_type_id.return_type))
    {
        if (return_instruction->value == nullptr) {
            LLVMValueRef by_val_value = gen_load_untyped(g, g->cur_ret_ptr, 0, false, "");
            LLVMBuildRet(g->builder, by_val_value);
        } else {
            LLVMValueRef value = ir_llvm_value(g, return_instruction->value);
            LLVMValueRef by_val_value = gen_load_untyped(g, value, 0, false, "");
            LLVMBuildRet(g->builder, by_val_value);
        }
    } else if (return_instruction->value == nullptr) {
        LLVMBuildRetVoid(g->builder);
    } else {
        LLVMValueRef value = ir_llvm_value(g, return_instruction->value);
        LLVMBuildRet(g->builder, value);
    }
    return nullptr;
}

static LLVMValueRef gen_overflow_shl_op(CodeGen *g, ZigType *type_entry,
        LLVMValueRef val1, LLVMValueRef val2)
{
    // for unsigned left shifting, we do the lossy shift, then logically shift
    // right the same number of bits
    // if the values don't match, we have an overflow
    // for signed left shifting we do the same except arithmetic shift right

    assert(type_entry->id == ZigTypeIdInt);

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
    gen_safety_crash(g, PanicMsgIdShlOverflowedBits);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_overflow_shr_op(CodeGen *g, ZigType *type_entry,
        LLVMValueRef val1, LLVMValueRef val2)
{
    assert(type_entry->id == ZigTypeIdInt);

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
    gen_safety_crash(g, PanicMsgIdShrOverflowedBits);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_float_op(CodeGen *g, LLVMValueRef val, ZigType *type_entry, BuiltinFnId op) {
    if ((op == BuiltinFnIdCeil ||
         op == BuiltinFnIdFloor) &&
        type_entry->id == ZigTypeIdInt)
        return val;
    assert(type_entry->id == ZigTypeIdFloat);

    LLVMValueRef floor_fn = get_float_fn(g, type_entry, ZigLLVMFnIdFloatOp, op);
    return LLVMBuildCall(g->builder, floor_fn, &val, 1, "");
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
    LLVMValueRef unsigned_val;
    if (bigint->digit_count == 1) {
        unsigned_val = LLVMConstInt(type_ref, bigint_ptr(bigint)[0], false);
    } else {
        unsigned_val = LLVMConstIntOfArbitraryPrecision(type_ref, bigint->digit_count, bigint_ptr(bigint));
    }
    if (bigint->is_negative) {
        return LLVMConstNeg(unsigned_val);
    } else {
        return unsigned_val;
    }
}

static LLVMValueRef gen_div(CodeGen *g, bool want_runtime_safety, bool want_fast_math,
        LLVMValueRef val1, LLVMValueRef val2,
        ZigType *type_entry, DivKind div_kind)
{
    ZigLLVMSetFastMath(g->builder, want_fast_math);

    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, type_entry));
    if (want_runtime_safety && (want_fast_math || type_entry->id != ZigTypeIdFloat)) {
        LLVMValueRef is_zero_bit;
        if (type_entry->id == ZigTypeIdInt) {
            is_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");
        } else if (type_entry->id == ZigTypeIdFloat) {
            is_zero_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, val2, zero, "");
        } else {
            zig_unreachable();
        }
        LLVMBasicBlockRef div_zero_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivZeroFail");
        LLVMBasicBlockRef div_zero_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivZeroOk");
        LLVMBuildCondBr(g->builder, is_zero_bit, div_zero_fail_block, div_zero_ok_block);

        LLVMPositionBuilderAtEnd(g->builder, div_zero_fail_block);
        gen_safety_crash(g, PanicMsgIdDivisionByZero);

        LLVMPositionBuilderAtEnd(g->builder, div_zero_ok_block);

        if (type_entry->id == ZigTypeIdInt && type_entry->data.integral.is_signed) {
            LLVMValueRef neg_1_value = LLVMConstInt(get_llvm_type(g, type_entry), -1, true);
            BigInt int_min_bi = {0};
            eval_min_max_value_int(g, type_entry, &int_min_bi, false);
            LLVMValueRef int_min_value = bigint_to_llvm_const(get_llvm_type(g, type_entry), &int_min_bi);
            LLVMBasicBlockRef overflow_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivOverflowFail");
            LLVMBasicBlockRef overflow_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivOverflowOk");
            LLVMValueRef num_is_int_min = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, int_min_value, "");
            LLVMValueRef den_is_neg_1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, neg_1_value, "");
            LLVMValueRef overflow_fail_bit = LLVMBuildAnd(g->builder, num_is_int_min, den_is_neg_1, "");
            LLVMBuildCondBr(g->builder, overflow_fail_bit, overflow_fail_block, overflow_ok_block);

            LLVMPositionBuilderAtEnd(g->builder, overflow_fail_block);
            gen_safety_crash(g, PanicMsgIdIntegerOverflow);

            LLVMPositionBuilderAtEnd(g->builder, overflow_ok_block);
        }
    }

    if (type_entry->id == ZigTypeIdFloat) {
        LLVMValueRef result = LLVMBuildFDiv(g->builder, val1, val2, "");
        switch (div_kind) {
            case DivKindFloat:
                return result;
            case DivKindExact:
                if (want_runtime_safety) {
                    LLVMValueRef floored = gen_float_op(g, result, type_entry, BuiltinFnIdFloor);
                    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactOk");
                    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactFail");
                    LLVMValueRef ok_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, floored, result, "");

                    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

                    LLVMPositionBuilderAtEnd(g->builder, fail_block);
                    gen_safety_crash(g, PanicMsgIdExactDivisionRemainder);

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
                    LLVMValueRef ceiled = gen_float_op(g, result, type_entry, BuiltinFnIdCeil);
                    LLVMBasicBlockRef ceiled_end_block = LLVMGetInsertBlock(g->builder);
                    LLVMBuildBr(g->builder, end_block);

                    LLVMPositionBuilderAtEnd(g->builder, gez_block);
                    LLVMValueRef floored = gen_float_op(g, result, type_entry, BuiltinFnIdFloor);
                    LLVMBasicBlockRef floored_end_block = LLVMGetInsertBlock(g->builder);
                    LLVMBuildBr(g->builder, end_block);

                    LLVMPositionBuilderAtEnd(g->builder, end_block);
                    LLVMValueRef phi = LLVMBuildPhi(g->builder, get_llvm_type(g, type_entry), "");
                    LLVMValueRef incoming_values[] = { ceiled, floored };
                    LLVMBasicBlockRef incoming_blocks[] = { ceiled_end_block, floored_end_block };
                    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);
                    return phi;
                }
            case DivKindFloor:
                return gen_float_op(g, result, type_entry, BuiltinFnIdFloor);
        }
        zig_unreachable();
    }

    assert(type_entry->id == ZigTypeIdInt);

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
            if (want_runtime_safety) {
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
                gen_safety_crash(g, PanicMsgIdExactDivisionRemainder);

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
                // const d = @divTrunc(a, b);
                // const r = @rem(a, b);
                // return if (r == 0) d else d - ((a < 0) ^ (b < 0));

                LLVMValueRef div_trunc = LLVMBuildSDiv(g->builder, val1, val2, "");
                LLVMValueRef rem = LLVMBuildSRem(g->builder, val1, val2, "");
                LLVMValueRef rem_eq_0 = LLVMBuildICmp(g->builder, LLVMIntEQ, rem, zero, "");
                LLVMValueRef a_lt_0 = LLVMBuildICmp(g->builder, LLVMIntSLT, val1, zero, "");
                LLVMValueRef b_lt_0 = LLVMBuildICmp(g->builder, LLVMIntSLT, val2, zero, "");
                LLVMValueRef a_b_xor = LLVMBuildXor(g->builder, a_lt_0, b_lt_0, "");
                LLVMValueRef a_b_xor_ext = LLVMBuildZExt(g->builder, a_b_xor, LLVMTypeOf(div_trunc), "");
                LLVMValueRef d_sub_xor = LLVMBuildSub(g->builder, div_trunc, a_b_xor_ext, "");
                return LLVMBuildSelect(g->builder, rem_eq_0, div_trunc, d_sub_xor, "");
            }
    }
    zig_unreachable();
}

enum RemKind {
    RemKindRem,
    RemKindMod,
};

static LLVMValueRef gen_rem(CodeGen *g, bool want_runtime_safety, bool want_fast_math,
        LLVMValueRef val1, LLVMValueRef val2,
        ZigType *type_entry, RemKind rem_kind)
{
    ZigLLVMSetFastMath(g->builder, want_fast_math);

    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, type_entry));
    if (want_runtime_safety) {
        LLVMValueRef is_zero_bit;
        if (type_entry->id == ZigTypeIdInt) {
            LLVMIntPredicate pred = type_entry->data.integral.is_signed ? LLVMIntSLE : LLVMIntEQ;
            is_zero_bit = LLVMBuildICmp(g->builder, pred, val2, zero, "");
        } else if (type_entry->id == ZigTypeIdFloat) {
            is_zero_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, val2, zero, "");
        } else {
            zig_unreachable();
        }
        LLVMBasicBlockRef rem_zero_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemZeroOk");
        LLVMBasicBlockRef rem_zero_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemZeroFail");
        LLVMBuildCondBr(g->builder, is_zero_bit, rem_zero_fail_block, rem_zero_ok_block);

        LLVMPositionBuilderAtEnd(g->builder, rem_zero_fail_block);
        gen_safety_crash(g, PanicMsgIdRemainderDivisionByZero);

        LLVMPositionBuilderAtEnd(g->builder, rem_zero_ok_block);
    }

    if (type_entry->id == ZigTypeIdFloat) {
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
        assert(type_entry->id == ZigTypeIdInt);
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
        op_id == IrBinOpBitShiftRightExact ||
        (op1->value.type->id == ZigTypeIdErrorSet && op2->value.type->id == ZigTypeIdErrorSet) ||
        (op1->value.type->id == ZigTypeIdPointer &&
            (op_id == IrBinOpAdd || op_id == IrBinOpSub) &&
            op1->value.type->data.pointer.ptr_len != PtrLenSingle)
    );
    ZigType *operand_type = op1->value.type;
    ZigType *scalar_type = (operand_type->id == ZigTypeIdVector) ? operand_type->data.vector.elem_type : operand_type;

    bool want_runtime_safety = bin_op_instruction->safety_check_on &&
        ir_want_runtime_safety(g, &bin_op_instruction->base);

    LLVMValueRef op1_value = ir_llvm_value(g, op1);
    LLVMValueRef op2_value = ir_llvm_value(g, op2);


    switch (op_id) {
        case IrBinOpInvalid:
        case IrBinOpArrayCat:
        case IrBinOpArrayMult:
        case IrBinOpRemUnspecified:
        case IrBinOpMergeErrorSets:
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
            if (scalar_type->id == ZigTypeIdFloat) {
                ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &bin_op_instruction->base));
                LLVMRealPredicate pred = cmp_op_to_real_predicate(op_id);
                return LLVMBuildFCmp(g->builder, pred, op1_value, op2_value, "");
            } else if (scalar_type->id == ZigTypeIdInt) {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, scalar_type->data.integral.is_signed);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else if (scalar_type->id == ZigTypeIdEnum ||
                    scalar_type->id == ZigTypeIdErrorSet ||
                    scalar_type->id == ZigTypeIdBool ||
                    get_codegen_ptr_type(scalar_type) != nullptr)
            {
                LLVMIntPredicate pred = cmp_op_to_int_predicate(op_id, false);
                return LLVMBuildICmp(g->builder, pred, op1_value, op2_value, "");
            } else {
                zig_unreachable();
            }
        case IrBinOpMult:
        case IrBinOpMultWrap:
        case IrBinOpAdd:
        case IrBinOpAddWrap:
        case IrBinOpSub:
        case IrBinOpSubWrap: {
            bool is_wrapping = (op_id == IrBinOpSubWrap || op_id == IrBinOpAddWrap || op_id == IrBinOpMultWrap);
            AddSubMul add_sub_mul =
                op_id == IrBinOpAdd || op_id == IrBinOpAddWrap ? AddSubMulAdd :
                op_id == IrBinOpSub || op_id == IrBinOpSubWrap ? AddSubMulSub :
                AddSubMulMul;

            if (scalar_type->id == ZigTypeIdPointer) {
                assert(scalar_type->data.pointer.ptr_len != PtrLenSingle);
                LLVMValueRef subscript_value;
                if (operand_type->id == ZigTypeIdVector)
                    zig_panic("TODO: Implement vector operations on pointers.");

                switch (add_sub_mul) {
                    case AddSubMulAdd:
                        subscript_value = op2_value;
                        break;
                    case AddSubMulSub:
                        subscript_value = LLVMBuildNeg(g->builder, op2_value, "");
                        break;
                    case AddSubMulMul:
                        zig_unreachable();
                }

                // TODO runtime safety
                return LLVMBuildInBoundsGEP(g->builder, op1_value, &subscript_value, 1, "");
            } else if (scalar_type->id == ZigTypeIdFloat) {
                ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &bin_op_instruction->base));
                return float_op[add_sub_mul](g->builder, op1_value, op2_value, "");
            } else if (scalar_type->id == ZigTypeIdInt) {
                if (is_wrapping) {
                    return wrap_op[add_sub_mul](g->builder, op1_value, op2_value, "");
                } else if (want_runtime_safety) {
                    return gen_overflow_op(g, operand_type, add_sub_mul, op1_value, op2_value);
                } else if (scalar_type->data.integral.is_signed) {
                    return signed_op[add_sub_mul](g->builder, op1_value, op2_value, "");
                } else {
                    return unsigned_op[add_sub_mul](g->builder, op1_value, op2_value, "");
                }
            } else {
                zig_unreachable();
            }
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
                assert(scalar_type->id == ZigTypeIdInt);
                LLVMValueRef op2_casted = gen_widen_or_shorten(g, false, op2->value.type, scalar_type, op2_value);
                bool is_sloppy = (op_id == IrBinOpBitShiftLeftLossy);
                if (is_sloppy) {
                    return LLVMBuildShl(g->builder, op1_value, op2_casted, "");
                } else if (want_runtime_safety) {
                    return gen_overflow_shl_op(g, scalar_type, op1_value, op2_casted);
                } else if (scalar_type->data.integral.is_signed) {
                    return ZigLLVMBuildNSWShl(g->builder, op1_value, op2_casted, "");
                } else {
                    return ZigLLVMBuildNUWShl(g->builder, op1_value, op2_casted, "");
                }
            }
        case IrBinOpBitShiftRightLossy:
        case IrBinOpBitShiftRightExact:
            {
                assert(scalar_type->id == ZigTypeIdInt);
                LLVMValueRef op2_casted = gen_widen_or_shorten(g, false, op2->value.type, scalar_type, op2_value);
                bool is_sloppy = (op_id == IrBinOpBitShiftRightLossy);
                if (is_sloppy) {
                    if (scalar_type->data.integral.is_signed) {
                        return LLVMBuildAShr(g->builder, op1_value, op2_casted, "");
                    } else {
                        return LLVMBuildLShr(g->builder, op1_value, op2_casted, "");
                    }
                } else if (want_runtime_safety) {
                    return gen_overflow_shr_op(g, scalar_type, op1_value, op2_casted);
                } else if (scalar_type->data.integral.is_signed) {
                    return ZigLLVMBuildAShrExact(g->builder, op1_value, op2_casted, "");
                } else {
                    return ZigLLVMBuildLShrExact(g->builder, op1_value, op2_casted, "");
                }
            }
        case IrBinOpDivUnspecified:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, scalar_type, DivKindFloat);
        case IrBinOpDivExact:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, scalar_type, DivKindExact);
        case IrBinOpDivTrunc:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, scalar_type, DivKindTrunc);
        case IrBinOpDivFloor:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, scalar_type, DivKindFloor);
        case IrBinOpRemRem:
            return gen_rem(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, scalar_type, RemKindRem);
        case IrBinOpRemMod:
            return gen_rem(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, scalar_type, RemKindMod);
    }
    zig_unreachable();
}

static void add_error_range_check(CodeGen *g, ZigType *err_set_type, ZigType *int_type, LLVMValueRef target_val) {
    assert(err_set_type->id == ZigTypeIdErrorSet);

    if (type_is_global_error_set(err_set_type)) {
        LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, int_type));
        LLVMValueRef neq_zero_bit = LLVMBuildICmp(g->builder, LLVMIntNE, target_val, zero, "");
        LLVMValueRef ok_bit;

        BigInt biggest_possible_err_val = {0};
        eval_min_max_value_int(g, int_type, &biggest_possible_err_val, true);

        if (bigint_fits_in_bits(&biggest_possible_err_val, 64, false) &&
            bigint_as_unsigned(&biggest_possible_err_val) < g->errors_by_index.length)
        {
            ok_bit = neq_zero_bit;
        } else {
            LLVMValueRef error_value_count = LLVMConstInt(get_llvm_type(g, int_type), g->errors_by_index.length, false);
            LLVMValueRef in_bounds_bit = LLVMBuildICmp(g->builder, LLVMIntULT, target_val, error_value_count, "");
            ok_bit = LLVMBuildAnd(g->builder, neq_zero_bit, in_bounds_bit, "");
        }

        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "IntToErrOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "IntToErrFail");

        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_safety_crash(g, PanicMsgIdInvalidErrorCode);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    } else {
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "IntToErrOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "IntToErrFail");

        uint32_t err_count = err_set_type->data.error_set.err_count;
        LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, target_val, fail_block, err_count);
        for (uint32_t i = 0; i < err_count; i += 1) {
            LLVMValueRef case_value = LLVMConstInt(get_llvm_type(g, g->err_tag_type),
                    err_set_type->data.error_set.errors[i]->value, false);
            LLVMAddCase(switch_instr, case_value, ok_block);
        }

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_safety_crash(g, PanicMsgIdInvalidErrorCode);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }
}

static LLVMValueRef ir_render_resize_slice(CodeGen *g, IrExecutable *executable,
        IrInstructionResizeSlice *instruction)
{
    ZigType *actual_type = instruction->operand->value.type;
    ZigType *wanted_type = instruction->base.value.type;
    LLVMValueRef expr_val = ir_llvm_value(g, instruction->operand);
    assert(expr_val);

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
    assert(wanted_type->id == ZigTypeIdStruct);
    assert(wanted_type->data.structure.is_slice);
    assert(actual_type->id == ZigTypeIdStruct);
    assert(actual_type->data.structure.is_slice);

    ZigType *actual_pointer_type = actual_type->data.structure.fields[0].type_entry;
    ZigType *actual_child_type = actual_pointer_type->data.pointer.child_type;
    ZigType *wanted_pointer_type = wanted_type->data.structure.fields[0].type_entry;
    ZigType *wanted_child_type = wanted_pointer_type->data.pointer.child_type;


    size_t actual_ptr_index = actual_type->data.structure.fields[slice_ptr_index].gen_index;
    size_t actual_len_index = actual_type->data.structure.fields[slice_len_index].gen_index;
    size_t wanted_ptr_index = wanted_type->data.structure.fields[slice_ptr_index].gen_index;
    size_t wanted_len_index = wanted_type->data.structure.fields[slice_len_index].gen_index;

    LLVMValueRef src_ptr_ptr = LLVMBuildStructGEP(g->builder, expr_val, (unsigned)actual_ptr_index, "");
    LLVMValueRef src_ptr = gen_load_untyped(g, src_ptr_ptr, 0, false, "");
    LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr,
            get_llvm_type(g, wanted_type->data.structure.fields[0].type_entry), "");
    LLVMValueRef dest_ptr_ptr = LLVMBuildStructGEP(g->builder, result_loc,
            (unsigned)wanted_ptr_index, "");
    gen_store_untyped(g, src_ptr_casted, dest_ptr_ptr, 0, false);

    LLVMValueRef src_len_ptr = LLVMBuildStructGEP(g->builder, expr_val, (unsigned)actual_len_index, "");
    LLVMValueRef src_len = gen_load_untyped(g, src_len_ptr, 0, false, "");
    uint64_t src_size = type_size(g, actual_child_type);
    uint64_t dest_size = type_size(g, wanted_child_type);

    LLVMValueRef new_len;
    if (dest_size == 1) {
        LLVMValueRef src_size_val = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, src_size, false);
        new_len = LLVMBuildMul(g->builder, src_len, src_size_val, "");
    } else if (src_size == 1) {
        LLVMValueRef dest_size_val = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, dest_size, false);
        if (ir_want_runtime_safety(g, &instruction->base)) {
            LLVMValueRef remainder_val = LLVMBuildURem(g->builder, src_len, dest_size_val, "");
            LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_usize->llvm_type);
            LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, remainder_val, zero, "");
            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "SliceWidenOk");
            LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "SliceWidenFail");
            LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

            LLVMPositionBuilderAtEnd(g->builder, fail_block);
            gen_safety_crash(g, PanicMsgIdSliceWidenRemainder);

            LLVMPositionBuilderAtEnd(g->builder, ok_block);
        }
        new_len = LLVMBuildExactUDiv(g->builder, src_len, dest_size_val, "");
    } else {
        zig_unreachable();
    }

    LLVMValueRef dest_len_ptr = LLVMBuildStructGEP(g->builder, result_loc, (unsigned)wanted_len_index, "");
    gen_store_untyped(g, new_len, dest_len_ptr, 0, false);

    return result_loc;
}

static LLVMValueRef ir_render_cast(CodeGen *g, IrExecutable *executable,
        IrInstructionCast *cast_instruction)
{
    ZigType *actual_type = cast_instruction->value->value.type;
    ZigType *wanted_type = cast_instruction->base.value.type;
    LLVMValueRef expr_val = ir_llvm_value(g, cast_instruction->value);
    assert(expr_val);

    switch (cast_instruction->cast_op) {
        case CastOpNoCast:
        case CastOpNumLitToConcrete:
            zig_unreachable();
        case CastOpNoop:
            return expr_val;
        case CastOpIntToFloat:
            assert(actual_type->id == ZigTypeIdInt);
            if (actual_type->data.integral.is_signed) {
                return LLVMBuildSIToFP(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            } else {
                return LLVMBuildUIToFP(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            }
        case CastOpFloatToInt: {
            assert(wanted_type->id == ZigTypeIdInt);
            ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &cast_instruction->base));

            bool want_safety = ir_want_runtime_safety(g, &cast_instruction->base);

            LLVMValueRef result;
            if (wanted_type->data.integral.is_signed) {
                result = LLVMBuildFPToSI(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            } else {
                result = LLVMBuildFPToUI(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            }

            if (want_safety) {
                LLVMValueRef back_to_float;
                if (wanted_type->data.integral.is_signed) {
                    back_to_float = LLVMBuildSIToFP(g->builder, result, LLVMTypeOf(expr_val), "");
                } else {
                    back_to_float = LLVMBuildUIToFP(g->builder, result, LLVMTypeOf(expr_val), "");
                }
                LLVMValueRef difference = LLVMBuildFSub(g->builder, expr_val, back_to_float, "");
                LLVMValueRef one_pos = LLVMConstReal(LLVMTypeOf(expr_val), 1.0f);
                LLVMValueRef one_neg = LLVMConstReal(LLVMTypeOf(expr_val), -1.0f);
                LLVMValueRef ok_bit_pos = LLVMBuildFCmp(g->builder, LLVMRealOLT, difference, one_pos, "");
                LLVMValueRef ok_bit_neg = LLVMBuildFCmp(g->builder, LLVMRealOGT, difference, one_neg, "");
                LLVMValueRef ok_bit = LLVMBuildAnd(g->builder, ok_bit_pos, ok_bit_neg, "");
                LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "FloatCheckOk");
                LLVMBasicBlockRef bad_block = LLVMAppendBasicBlock(g->cur_fn_val, "FloatCheckFail");
                LLVMBuildCondBr(g->builder, ok_bit, ok_block, bad_block);
                LLVMPositionBuilderAtEnd(g->builder, bad_block);
                gen_safety_crash(g, PanicMsgIdFloatToInt);
                LLVMPositionBuilderAtEnd(g->builder, ok_block);
            }
            return result;
        }
        case CastOpBoolToInt:
            assert(wanted_type->id == ZigTypeIdInt);
            assert(actual_type->id == ZigTypeIdBool);
            return LLVMBuildZExt(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
        case CastOpErrSet:
            if (ir_want_runtime_safety(g, &cast_instruction->base)) {
                add_error_range_check(g, wanted_type, g->err_tag_type, expr_val);
            }
            return expr_val;
        case CastOpBitCast:
            return LLVMBuildBitCast(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
    }
    zig_unreachable();
}

static LLVMValueRef ir_render_ptr_of_array_to_slice(CodeGen *g, IrExecutable *executable,
        IrInstructionPtrOfArrayToSlice *instruction)
{
    ZigType *actual_type = instruction->operand->value.type;
    LLVMValueRef expr_val = ir_llvm_value(g, instruction->operand);
    assert(expr_val);

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    assert(actual_type->id == ZigTypeIdPointer);
    ZigType *array_type = actual_type->data.pointer.child_type;
    assert(array_type->id == ZigTypeIdArray);

    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, result_loc, slice_ptr_index, "");
    LLVMValueRef indices[] = {
        LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
        LLVMConstInt(g->builtin_types.entry_usize->llvm_type, 0, false),
    };
    LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, expr_val, indices, 2, "");
    gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);

    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, result_loc, slice_len_index, "");
    LLVMValueRef len_value = LLVMConstInt(g->builtin_types.entry_usize->llvm_type,
            array_type->data.array.len, false);
    gen_store_untyped(g, len_value, len_field_ptr, 0, false);

    return result_loc;
}

static LLVMValueRef ir_render_ptr_cast(CodeGen *g, IrExecutable *executable,
        IrInstructionPtrCastGen *instruction)
{
    ZigType *wanted_type = instruction->base.value.type;
    if (!type_has_bits(wanted_type)) {
        return nullptr;
    }
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef result_ptr = LLVMBuildBitCast(g->builder, ptr, get_llvm_type(g, wanted_type), "");
    bool want_safety_check = instruction->safety_check_on && ir_want_runtime_safety(g, &instruction->base);
    if (!want_safety_check || ptr_allows_addr_zero(wanted_type))
        return result_ptr;

    LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(result_ptr));
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntNE, result_ptr, zero, "");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrCastFail");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrCastOk");
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_safety_crash(g, PanicMsgIdPtrCastNull);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result_ptr;
}

static LLVMValueRef ir_render_bit_cast(CodeGen *g, IrExecutable *executable,
        IrInstructionBitCastGen *instruction)
{
    ZigType *wanted_type = instruction->base.value.type;
    ZigType *actual_type = instruction->operand->value.type;
    LLVMValueRef value = ir_llvm_value(g, instruction->operand);

    bool wanted_is_ptr = handle_is_ptr(wanted_type);
    bool actual_is_ptr = handle_is_ptr(actual_type);
    if (wanted_is_ptr == actual_is_ptr) {
        // We either bitcast the value directly or bitcast the pointer which does a pointer cast
        LLVMTypeRef wanted_type_ref = wanted_is_ptr ?
            LLVMPointerType(get_llvm_type(g, wanted_type), 0) : get_llvm_type(g, wanted_type);
        return LLVMBuildBitCast(g->builder, value, wanted_type_ref, "");
    } else if (actual_is_ptr) {
        LLVMTypeRef wanted_ptr_type_ref = LLVMPointerType(get_llvm_type(g, wanted_type), 0);
        LLVMValueRef bitcasted_ptr = LLVMBuildBitCast(g->builder, value, wanted_ptr_type_ref, "");
        uint32_t alignment = get_abi_alignment(g, actual_type);
        return gen_load_untyped(g, bitcasted_ptr, alignment, false, "");
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef ir_render_widen_or_shorten(CodeGen *g, IrExecutable *executable,
        IrInstructionWidenOrShorten *instruction)
{
    ZigType *actual_type = instruction->target->value.type;
    // TODO instead of this logic, use the Noop instruction to change the type from
    // enum_tag to the underlying int type
    ZigType *int_type;
    if (actual_type->id == ZigTypeIdEnum) {
        int_type = actual_type->data.enumeration.tag_int_type;
    } else {
        int_type = actual_type;
    }
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    return gen_widen_or_shorten(g, ir_want_runtime_safety(g, &instruction->base), int_type,
            instruction->base.value.type, target_val);
}

static LLVMValueRef ir_render_int_to_ptr(CodeGen *g, IrExecutable *executable, IrInstructionIntToPtr *instruction) {
    ZigType *wanted_type = instruction->base.value.type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    if (!ptr_allows_addr_zero(wanted_type) && ir_want_runtime_safety(g, &instruction->base)) {
        LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(target_val));
        LLVMValueRef is_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, target_val, zero, "");
        LLVMBasicBlockRef bad_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrToIntBad");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrToIntOk");
        LLVMBuildCondBr(g->builder, is_zero_bit, bad_block, ok_block);

        LLVMPositionBuilderAtEnd(g->builder, bad_block);
        gen_safety_crash(g, PanicMsgIdPtrCastNull);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }
    return LLVMBuildIntToPtr(g->builder, target_val, get_llvm_type(g, wanted_type), "");
}

static LLVMValueRef ir_render_ptr_to_int(CodeGen *g, IrExecutable *executable, IrInstructionPtrToInt *instruction) {
    ZigType *wanted_type = instruction->base.value.type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    return LLVMBuildPtrToInt(g->builder, target_val, get_llvm_type(g, wanted_type), "");
}

static LLVMValueRef ir_render_int_to_enum(CodeGen *g, IrExecutable *executable, IrInstructionIntToEnum *instruction) {
    ZigType *wanted_type = instruction->base.value.type;
    assert(wanted_type->id == ZigTypeIdEnum);
    ZigType *tag_int_type = wanted_type->data.enumeration.tag_int_type;

    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    LLVMValueRef tag_int_value = gen_widen_or_shorten(g, ir_want_runtime_safety(g, &instruction->base),
            instruction->target->value.type, tag_int_type, target_val);

    if (ir_want_runtime_safety(g, &instruction->base)) {
        LLVMBasicBlockRef bad_value_block = LLVMAppendBasicBlock(g->cur_fn_val, "BadValue");
        LLVMBasicBlockRef ok_value_block = LLVMAppendBasicBlock(g->cur_fn_val, "OkValue");
        size_t field_count = wanted_type->data.enumeration.src_field_count;
        LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, tag_int_value, bad_value_block, field_count);
        for (size_t field_i = 0; field_i < field_count; field_i += 1) {
            LLVMValueRef this_tag_int_value = bigint_to_llvm_const(get_llvm_type(g, tag_int_type),
                    &wanted_type->data.enumeration.fields[field_i].value);
            LLVMAddCase(switch_instr, this_tag_int_value, ok_value_block);
        }
        LLVMPositionBuilderAtEnd(g->builder, bad_value_block);
        gen_safety_crash(g, PanicMsgIdBadEnumValue);

        LLVMPositionBuilderAtEnd(g->builder, ok_value_block);
    }
    return tag_int_value;
}

static LLVMValueRef ir_render_int_to_err(CodeGen *g, IrExecutable *executable, IrInstructionIntToErr *instruction) {
    ZigType *wanted_type = instruction->base.value.type;
    assert(wanted_type->id == ZigTypeIdErrorSet);

    ZigType *actual_type = instruction->target->value.type;
    assert(actual_type->id == ZigTypeIdInt);
    assert(!actual_type->data.integral.is_signed);

    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);

    if (ir_want_runtime_safety(g, &instruction->base)) {
        add_error_range_check(g, wanted_type, actual_type, target_val);
    }

    return gen_widen_or_shorten(g, false, actual_type, g->err_tag_type, target_val);
}

static LLVMValueRef ir_render_err_to_int(CodeGen *g, IrExecutable *executable, IrInstructionErrToInt *instruction) {
    ZigType *wanted_type = instruction->base.value.type;
    assert(wanted_type->id == ZigTypeIdInt);
    assert(!wanted_type->data.integral.is_signed);

    ZigType *actual_type = instruction->target->value.type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);

    if (actual_type->id == ZigTypeIdErrorSet) {
        return gen_widen_or_shorten(g, ir_want_runtime_safety(g, &instruction->base),
            g->err_tag_type, wanted_type, target_val);
    } else if (actual_type->id == ZigTypeIdErrorUnion) {
        // this should have been a compile time constant
        assert(type_has_bits(actual_type->data.error_union.err_set_type));

        if (!type_has_bits(actual_type->data.error_union.payload_type)) {
            return gen_widen_or_shorten(g, ir_want_runtime_safety(g, &instruction->base),
                g->err_tag_type, wanted_type, target_val);
        } else {
            zig_panic("TODO err to int when error union payload type not void");
        }
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef ir_render_unreachable(CodeGen *g, IrExecutable *executable,
        IrInstructionUnreachable *unreachable_instruction)
{
    if (ir_want_runtime_safety(g, &unreachable_instruction->base)) {
        gen_safety_crash(g, PanicMsgIdUnreachable);
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
    ZigType *operand_type = un_op_instruction->value->value.type;
    ZigType *scalar_type = (operand_type->id == ZigTypeIdVector) ? operand_type->data.vector.elem_type : operand_type;

    switch (op_id) {
        case IrUnOpInvalid:
        case IrUnOpOptional:
        case IrUnOpDereference:
            zig_unreachable();
        case IrUnOpNegation:
        case IrUnOpNegationWrap:
            {
                if (scalar_type->id == ZigTypeIdFloat) {
                    ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, &un_op_instruction->base));
                    return LLVMBuildFNeg(g->builder, expr, "");
                } else if (scalar_type->id == ZigTypeIdInt) {
                    if (op_id == IrUnOpNegationWrap) {
                        return LLVMBuildNeg(g->builder, expr, "");
                    } else if (ir_want_runtime_safety(g, &un_op_instruction->base)) {
                        LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(expr));
                        return gen_overflow_op(g, operand_type, AddSubMulSub, zero, expr);
                    } else if (scalar_type->data.integral.is_signed) {
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

static LLVMValueRef ir_render_decl_var(CodeGen *g, IrExecutable *executable, IrInstructionDeclVarGen *instruction) {
    ZigVar *var = instruction->var;

    if (!type_has_bits(var->var_type))
        return nullptr;

    var->value_ref = ir_llvm_value(g, instruction->var_ptr);
    gen_var_debug_decl(g, var);
    return nullptr;
}

static LLVMValueRef ir_render_load_ptr(CodeGen *g, IrExecutable *executable, IrInstructionLoadPtrGen *instruction) {
    ZigType *child_type = instruction->base.value.type;
    if (!type_has_bits(child_type))
        return nullptr;

    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    ZigType *ptr_type = instruction->ptr->value.type;
    assert(ptr_type->id == ZigTypeIdPointer);

    uint32_t host_int_bytes = ptr_type->data.pointer.host_int_bytes;
    if (host_int_bytes == 0)
        return get_handle_value(g, ptr, child_type, ptr_type);

    bool big_endian = g->is_big_endian;

    LLVMValueRef containing_int = gen_load(g, ptr, ptr_type, "");
    uint32_t host_bit_count = LLVMGetIntTypeWidth(LLVMTypeOf(containing_int));
    assert(host_bit_count == host_int_bytes * 8);
    uint32_t size_in_bits = type_size_bits(g, child_type);

    uint32_t bit_offset = ptr_type->data.pointer.bit_offset_in_host;
    uint32_t shift_amt = big_endian ? host_bit_count - bit_offset - size_in_bits : bit_offset;

    LLVMValueRef shift_amt_val = LLVMConstInt(LLVMTypeOf(containing_int), shift_amt, false);
    LLVMValueRef shifted_value = LLVMBuildLShr(g->builder, containing_int, shift_amt_val, "");

    if (handle_is_ptr(child_type)) {
        LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
        LLVMTypeRef same_size_int = LLVMIntType(size_in_bits);
        LLVMValueRef truncated_int = LLVMBuildTrunc(g->builder, shifted_value, same_size_int, "");
        LLVMValueRef bitcasted_ptr = LLVMBuildBitCast(g->builder, result_loc,
                                                      LLVMPointerType(same_size_int, 0), "");
        LLVMBuildStore(g->builder, truncated_int, bitcasted_ptr);
        return result_loc;
    }

    if (child_type->id == ZigTypeIdFloat) {
        LLVMTypeRef same_size_int = LLVMIntType(size_in_bits);
        LLVMValueRef truncated_int = LLVMBuildTrunc(g->builder, shifted_value, same_size_int, "");
        return LLVMBuildBitCast(g->builder, truncated_int, get_llvm_type(g, child_type), "");
    }

    return LLVMBuildTrunc(g->builder, shifted_value, get_llvm_type(g, child_type), "");
}

static bool value_is_all_undef_array(ConstExprValue *const_val, size_t len) {
    switch (const_val->data.x_array.special) {
        case ConstArraySpecialUndef:
            return true;
        case ConstArraySpecialBuf:
            return false;
        case ConstArraySpecialNone:
            for (size_t i = 0; i < len; i += 1) {
                if (!value_is_all_undef(&const_val->data.x_array.data.s_none.elements[i]))
                    return false;
            }
            return true;
    }
    zig_unreachable();
}

static bool value_is_all_undef(ConstExprValue *const_val) {
    switch (const_val->special) {
        case ConstValSpecialRuntime:
            return false;
        case ConstValSpecialUndef:
            return true;
        case ConstValSpecialStatic:
            if (const_val->type->id == ZigTypeIdStruct) {
                for (size_t i = 0; i < const_val->type->data.structure.src_field_count; i += 1) {
                    if (!value_is_all_undef(&const_val->data.x_struct.fields[i]))
                        return false;
                }
                return true;
            } else if (const_val->type->id == ZigTypeIdArray) {
                return value_is_all_undef_array(const_val, const_val->type->data.array.len);
            } else if (const_val->type->id == ZigTypeIdVector) {
                return value_is_all_undef_array(const_val, const_val->type->data.vector.len);
            } else {
                return false;
            }
    }
    zig_unreachable();
}

static LLVMValueRef gen_valgrind_client_request(CodeGen *g, LLVMValueRef default_value, LLVMValueRef request,
        LLVMValueRef a1, LLVMValueRef a2, LLVMValueRef a3, LLVMValueRef a4, LLVMValueRef a5)
{
    if (!target_has_valgrind_support(g->zig_target)) {
        return default_value;
    }
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
    bool asm_has_side_effects = true;
    bool asm_is_alignstack = false;
    if (g->zig_target->arch == ZigLLVM_x86_64) {
        if (g->zig_target->os == OsLinux || target_os_is_darwin(g->zig_target->os) || g->zig_target->os == OsSolaris ||
            (g->zig_target->os == OsWindows && g->zig_target->abi != ZigLLVM_MSVC))
        {
            if (g->cur_fn->valgrind_client_request_array == nullptr) {
                LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
                LLVMBasicBlockRef entry_block = LLVMGetEntryBasicBlock(g->cur_fn->llvm_value);
                LLVMValueRef first_inst = LLVMGetFirstInstruction(entry_block);
                LLVMPositionBuilderBefore(g->builder, first_inst);
                LLVMTypeRef array_type_ref = LLVMArrayType(usize_type_ref, 6);
                g->cur_fn->valgrind_client_request_array = LLVMBuildAlloca(g->builder, array_type_ref, "");
                LLVMPositionBuilderAtEnd(g->builder, prev_block);
            }
            LLVMValueRef array_ptr = g->cur_fn->valgrind_client_request_array;
            LLVMValueRef array_elements[] = {request, a1, a2, a3, a4, a5};
            LLVMValueRef zero = LLVMConstInt(usize_type_ref, 0, false);
            for (unsigned i = 0; i < 6; i += 1) {
                LLVMValueRef indexes[] = {
                    zero,
                    LLVMConstInt(usize_type_ref, i, false),
                };
                LLVMValueRef elem_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, indexes, 2, "");
                LLVMBuildStore(g->builder, array_elements[i], elem_ptr);
            }

            Buf *asm_template = buf_create_from_str(
                "rolq $$3,  %rdi ; rolq $$13, %rdi\n"
                "rolq $$61, %rdi ; rolq $$51, %rdi\n"
                "xchgq %rbx,%rbx\n"
            );
            Buf *asm_constraints = buf_create_from_str(
                "={rdx},{rax},0,~{cc},~{memory}"
            );
            unsigned input_and_output_count = 2;
            LLVMValueRef array_ptr_as_usize = LLVMBuildPtrToInt(g->builder, array_ptr, usize_type_ref, "");
            LLVMValueRef param_values[] = { array_ptr_as_usize, default_value };
            LLVMTypeRef param_types[] = {usize_type_ref, usize_type_ref};
            LLVMTypeRef function_type = LLVMFunctionType(usize_type_ref, param_types,
                    input_and_output_count, false);
            LLVMValueRef asm_fn = LLVMGetInlineAsm(function_type, buf_ptr(asm_template), buf_len(asm_template),
                    buf_ptr(asm_constraints), buf_len(asm_constraints), asm_has_side_effects, asm_is_alignstack,
                    LLVMInlineAsmDialectATT);
            return LLVMBuildCall(g->builder, asm_fn, param_values, input_and_output_count, "");
        }
    }
    zig_unreachable();
}

static bool want_valgrind_support(CodeGen *g) {
    if (!target_has_valgrind_support(g->zig_target))
        return false;
    switch (g->valgrind_support) {
        case ValgrindSupportDisabled:
            return false;
        case ValgrindSupportEnabled:
            return true;
        case ValgrindSupportAuto:
            return g->build_mode == BuildModeDebug;
    }
    zig_unreachable();
}

static void gen_valgrind_undef(CodeGen *g, LLVMValueRef dest_ptr, LLVMValueRef byte_count) {
    static const uint32_t VG_USERREQ__MAKE_MEM_UNDEFINED = 1296236545;
    ZigType *usize = g->builtin_types.entry_usize;
    LLVMValueRef zero = LLVMConstInt(usize->llvm_type, 0, false);
    LLVMValueRef req = LLVMConstInt(usize->llvm_type, VG_USERREQ__MAKE_MEM_UNDEFINED, false);
    LLVMValueRef ptr_as_usize = LLVMBuildPtrToInt(g->builder, dest_ptr, usize->llvm_type, "");
    gen_valgrind_client_request(g, zero, req, ptr_as_usize, byte_count, zero, zero, zero);
}

static void gen_undef_init(CodeGen *g, uint32_t ptr_align_bytes, ZigType *value_type, LLVMValueRef ptr) {
    assert(type_has_bits(value_type));
    uint64_t size_bytes = LLVMStoreSizeOfType(g->target_data_ref, get_llvm_type(g, value_type));
    assert(size_bytes > 0);
    assert(ptr_align_bytes > 0);
    // memset uninitialized memory to 0xaa
    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
    LLVMValueRef fill_char = LLVMConstInt(LLVMInt8Type(), 0xaa, false);
    LLVMValueRef dest_ptr = LLVMBuildBitCast(g->builder, ptr, ptr_u8, "");
    ZigType *usize = g->builtin_types.entry_usize;
    LLVMValueRef byte_count = LLVMConstInt(usize->llvm_type, size_bytes, false);
    ZigLLVMBuildMemSet(g->builder, dest_ptr, fill_char, byte_count, ptr_align_bytes, false);
    // then tell valgrind that the memory is undefined even though we just memset it
    if (want_valgrind_support(g)) {
        gen_valgrind_undef(g, dest_ptr, byte_count);
    }
}

static LLVMValueRef ir_render_store_ptr(CodeGen *g, IrExecutable *executable, IrInstructionStorePtr *instruction) {
    ZigType *ptr_type = instruction->ptr->value.type;
    assert(ptr_type->id == ZigTypeIdPointer);
    if (!type_has_bits(ptr_type))
        return nullptr;

    bool have_init_expr = !value_is_all_undef(&instruction->value->value);
    if (have_init_expr) {
        LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
        LLVMValueRef value = ir_llvm_value(g, instruction->value);
        gen_assign_raw(g, ptr, ptr_type, value);
    } else if (ir_want_runtime_safety(g, &instruction->base)) {
        gen_undef_init(g, get_ptr_align(g, ptr_type), instruction->value->value.type,
            ir_llvm_value(g, instruction->ptr));
    }
    return nullptr;
}

static LLVMValueRef ir_render_var_ptr(CodeGen *g, IrExecutable *executable, IrInstructionVarPtr *instruction) {
    ZigVar *var = instruction->var;
    if (type_has_bits(var->var_type)) {
        assert(var->value_ref);
        return var->value_ref;
    } else {
        return nullptr;
    }
}

static LLVMValueRef ir_render_return_ptr(CodeGen *g, IrExecutable *executable,
        IrInstructionReturnPtr *instruction)
{
    src_assert(g->cur_ret_ptr != nullptr || !type_has_bits(instruction->base.value.type),
            instruction->base.source_node);
    return g->cur_ret_ptr;
}

static LLVMValueRef ir_render_elem_ptr(CodeGen *g, IrExecutable *executable, IrInstructionElemPtr *instruction) {
    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->array_ptr);
    ZigType *array_ptr_type = instruction->array_ptr->value.type;
    assert(array_ptr_type->id == ZigTypeIdPointer);
    ZigType *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);
    LLVMValueRef subscript_value = ir_llvm_value(g, instruction->elem_index);
    assert(subscript_value);

    if (!type_has_bits(array_type))
        return nullptr;

    bool safety_check_on = ir_want_runtime_safety(g, &instruction->base) && instruction->safety_check_on;

    if (array_type->id == ZigTypeIdArray ||
        (array_type->id == ZigTypeIdPointer && array_type->data.pointer.ptr_len == PtrLenSingle))
    {
        if (array_type->id == ZigTypeIdPointer) {
            assert(array_type->data.pointer.child_type->id == ZigTypeIdArray);
            array_type = array_type->data.pointer.child_type;
        }
        if (safety_check_on) {
            LLVMValueRef end = LLVMConstInt(g->builtin_types.entry_usize->llvm_type,
                    array_type->data.array.len, false);
            add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, end);
        }
        if (array_ptr_type->data.pointer.host_int_bytes != 0) {
            return array_ptr_ptr;
        }
        ZigType *child_type = array_type->data.array.child_type;
        if (child_type->id == ZigTypeIdStruct &&
            child_type->data.structure.layout == ContainerLayoutPacked)
        {
            ZigType *ptr_type = instruction->base.value.type;
            size_t host_int_bytes = ptr_type->data.pointer.host_int_bytes;
            if (host_int_bytes != 0) {
                uint32_t size_in_bits = type_size_bits(g, ptr_type->data.pointer.child_type);
                LLVMTypeRef ptr_u8_type_ref = LLVMPointerType(LLVMInt8Type(), 0);
                LLVMValueRef u8_array_ptr = LLVMBuildBitCast(g->builder, array_ptr, ptr_u8_type_ref, "");
                assert(size_in_bits % 8 == 0);
                LLVMValueRef elem_size_bytes = LLVMConstInt(g->builtin_types.entry_usize->llvm_type,
                        size_in_bits / 8, false);
                LLVMValueRef byte_offset = LLVMBuildNUWMul(g->builder, subscript_value, elem_size_bytes, "");
                LLVMValueRef indices[] = {
                    byte_offset
                };
                LLVMValueRef elem_byte_ptr = LLVMBuildInBoundsGEP(g->builder, u8_array_ptr, indices, 1, "");
                return LLVMBuildBitCast(g->builder, elem_byte_ptr, LLVMPointerType(get_llvm_type(g, child_type), 0), "");
            }
        }
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
            subscript_value
        };
        return LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
    } else if (array_type->id == ZigTypeIdPointer) {
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        LLVMValueRef indices[] = {
            subscript_value
        };
        return LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 1, "");
    } else if (array_type->id == ZigTypeIdStruct) {
        assert(array_type->data.structure.is_slice);

        ZigType *ptr_type = instruction->base.value.type;
        if (!type_has_bits(ptr_type)) {
            if (safety_check_on) {
                assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMIntegerTypeKind);
                add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, array_ptr);
            }
            return nullptr;
        }

        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        if (safety_check_on) {
            size_t len_index = array_type->data.structure.fields[slice_len_index].gen_index;
            assert(len_index != SIZE_MAX);
            LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)len_index, "");
            LLVMValueRef len = gen_load_untyped(g, len_ptr, 0, false, "");
            add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, len);
        }

        size_t ptr_index = array_type->data.structure.fields[slice_ptr_index].gen_index;
        assert(ptr_index != SIZE_MAX);
        LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)ptr_index, "");
        LLVMValueRef ptr = gen_load_untyped(g, ptr_ptr, 0, false, "");
        return LLVMBuildInBoundsGEP(g->builder, ptr, &subscript_value, 1, "");
    } else {
        zig_unreachable();
    }
}

static bool get_prefix_arg_err_ret_stack(CodeGen *g, FnTypeId *fn_type_id) {
    return g->have_err_ret_tracing &&
        (fn_type_id->return_type->id == ZigTypeIdErrorUnion ||
         fn_type_id->return_type->id == ZigTypeIdErrorSet ||
         fn_type_id->cc == CallingConventionAsync);
}

static size_t get_async_allocator_arg_index(CodeGen *g, FnTypeId *fn_type_id) {
    // 0             1             2        3
    // err_ret_stack allocator_ptr err_code other_args...
    return get_prefix_arg_err_ret_stack(g, fn_type_id) ? 1 : 0;
}

static size_t get_async_err_code_arg_index(CodeGen *g, FnTypeId *fn_type_id) {
    // 0             1             2        3
    // err_ret_stack allocator_ptr err_code other_args...
    return 1 + get_async_allocator_arg_index(g, fn_type_id);
}


static LLVMValueRef get_new_stack_addr(CodeGen *g, LLVMValueRef new_stack) {
    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, new_stack, (unsigned)slice_ptr_index, "");
    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, new_stack, (unsigned)slice_len_index, "");

    LLVMValueRef ptr_value = gen_load_untyped(g, ptr_field_ptr, 0, false, "");
    LLVMValueRef len_value = gen_load_untyped(g, len_field_ptr, 0, false, "");

    LLVMValueRef ptr_addr = LLVMBuildPtrToInt(g->builder, ptr_value, LLVMTypeOf(len_value), "");
    LLVMValueRef end_addr = LLVMBuildNUWAdd(g->builder, ptr_addr, len_value, "");
    LLVMValueRef align_amt = LLVMConstInt(LLVMTypeOf(end_addr), get_abi_alignment(g, g->builtin_types.entry_usize), false);
    LLVMValueRef align_adj = LLVMBuildURem(g->builder, end_addr, align_amt, "");
    return LLVMBuildNUWSub(g->builder, end_addr, align_adj, "");
}

static void gen_set_stack_pointer(CodeGen *g, LLVMValueRef aligned_end_addr) {
    LLVMValueRef write_register_fn_val = get_write_register_fn_val(g);

    if (g->sp_md_node == nullptr) {
        Buf *sp_reg_name = buf_create_from_str(arch_stack_pointer_register_name(g->zig_target->arch));
        LLVMValueRef str_node = LLVMMDString(buf_ptr(sp_reg_name), buf_len(sp_reg_name) + 1);
        g->sp_md_node = LLVMMDNode(&str_node, 1);
    }

    LLVMValueRef params[] = {
        g->sp_md_node,
        aligned_end_addr,
    };

    LLVMBuildCall(g->builder, write_register_fn_val, params, 2, "");
}

static void set_call_instr_sret(CodeGen *g, LLVMValueRef call_instr) {
    unsigned attr_kind_id = LLVMGetEnumAttributeKindForName("sret", 4);
    LLVMAttributeRef sret_attr = LLVMCreateEnumAttribute(LLVMGetGlobalContext(), attr_kind_id, 0);
    LLVMAddCallSiteAttribute(call_instr, 1, sret_attr);
}

static LLVMValueRef ir_render_call(CodeGen *g, IrExecutable *executable, IrInstructionCallGen *instruction) {
    LLVMValueRef fn_val;
    ZigType *fn_type;
    if (instruction->fn_entry) {
        fn_val = fn_llvm_value(g, instruction->fn_entry);
        fn_type = instruction->fn_entry->type_entry;
    } else {
        assert(instruction->fn_ref);
        fn_val = ir_llvm_value(g, instruction->fn_ref);
        fn_type = instruction->fn_ref->value.type;
    }

    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;

    ZigType *src_return_type = fn_type_id->return_type;
    bool ret_has_bits = type_has_bits(src_return_type);

    CallingConvention cc = fn_type->data.fn.fn_type_id.cc;

    bool first_arg_ret = ret_has_bits && want_first_arg_sret(g, fn_type_id);
    bool prefix_arg_err_ret_stack = get_prefix_arg_err_ret_stack(g, fn_type_id);
    bool is_var_args = fn_type_id->is_var_args;
    ZigList<LLVMValueRef> gen_param_values = {};
    LLVMValueRef result_loc = instruction->result_loc ? ir_llvm_value(g, instruction->result_loc) : nullptr;
    if (first_arg_ret) {
        gen_param_values.append(result_loc);
    }
    if (prefix_arg_err_ret_stack) {
        gen_param_values.append(get_cur_err_ret_trace_val(g, instruction->base.scope));
    }
    if (instruction->is_async) {
        gen_param_values.append(ir_llvm_value(g, instruction->async_allocator));

        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_err_index, "");
        gen_param_values.append(err_val_ptr);
    }
    FnWalk fn_walk = {};
    fn_walk.id = FnWalkIdCall;
    fn_walk.data.call.inst = instruction;
    fn_walk.data.call.is_var_args = is_var_args;
    fn_walk.data.call.gen_param_values = &gen_param_values;
    walk_function_params(g, fn_type, &fn_walk);

    ZigLLVM_FnInline fn_inline;
    switch (instruction->fn_inline) {
        case FnInlineAuto:
            fn_inline = ZigLLVM_FnInlineAuto;
            break;
        case FnInlineAlways:
            fn_inline = (instruction->fn_entry == nullptr) ? ZigLLVM_FnInlineAuto : ZigLLVM_FnInlineAlways;
            break;
        case FnInlineNever:
            fn_inline = ZigLLVM_FnInlineNever;
            break;
    }

    LLVMCallConv llvm_cc = get_llvm_cc(g, cc);
    LLVMValueRef result;

    if (instruction->new_stack == nullptr) {
        result = ZigLLVMBuildCall(g->builder, fn_val,
                gen_param_values.items, (unsigned)gen_param_values.length, llvm_cc, fn_inline, "");
    } else {
        LLVMValueRef stacksave_fn_val = get_stacksave_fn_val(g);
        LLVMValueRef stackrestore_fn_val = get_stackrestore_fn_val(g);

        LLVMValueRef new_stack_addr = get_new_stack_addr(g, ir_llvm_value(g, instruction->new_stack));
        LLVMValueRef old_stack_ref = LLVMBuildCall(g->builder, stacksave_fn_val, nullptr, 0, "");
        gen_set_stack_pointer(g, new_stack_addr);
        result = ZigLLVMBuildCall(g->builder, fn_val,
                gen_param_values.items, (unsigned)gen_param_values.length, llvm_cc, fn_inline, "");
        LLVMBuildCall(g->builder, stackrestore_fn_val, &old_stack_ref, 1, "");
    }


    if (instruction->is_async) {
        LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_payload_index, "");
        LLVMBuildStore(g->builder, result, payload_ptr);
        return result_loc;
    }

    if (src_return_type->id == ZigTypeIdUnreachable) {
        return LLVMBuildUnreachable(g->builder);
    } else if (!ret_has_bits) {
        return nullptr;
    } else if (first_arg_ret) {
        set_call_instr_sret(g, result);
        return result_loc;
    } else if (handle_is_ptr(src_return_type)) {
        LLVMValueRef store_instr = LLVMBuildStore(g->builder, result, result_loc);
        LLVMSetAlignment(store_instr, get_ptr_align(g, instruction->result_loc->value.type));
        return result_loc;
    } else {
        return result;
    }
}

static LLVMValueRef ir_render_struct_field_ptr(CodeGen *g, IrExecutable *executable,
    IrInstructionStructFieldPtr *instruction)
{
    if (instruction->base.value.special != ConstValSpecialRuntime)
        return nullptr;

    LLVMValueRef struct_ptr = ir_llvm_value(g, instruction->struct_ptr);
    // not necessarily a pointer. could be ZigTypeIdStruct
    ZigType *struct_ptr_type = instruction->struct_ptr->value.type;
    TypeStructField *field = instruction->field;

    if (!type_has_bits(field->type_entry))
        return nullptr;

    if (struct_ptr_type->id == ZigTypeIdPointer &&
        struct_ptr_type->data.pointer.host_int_bytes != 0)
    {
        return struct_ptr;
    }

    assert(field->gen_index != SIZE_MAX);
    return LLVMBuildStructGEP(g->builder, struct_ptr, (unsigned)field->gen_index, "");
}

static LLVMValueRef ir_render_union_field_ptr(CodeGen *g, IrExecutable *executable,
    IrInstructionUnionFieldPtr *instruction)
{
    if (instruction->base.value.special != ConstValSpecialRuntime)
        return nullptr;

    ZigType *union_ptr_type = instruction->union_ptr->value.type;
    assert(union_ptr_type->id == ZigTypeIdPointer);
    ZigType *union_type = union_ptr_type->data.pointer.child_type;
    assert(union_type->id == ZigTypeIdUnion);

    TypeUnionField *field = instruction->field;

    if (!type_has_bits(field->type_entry)) {
        if (union_type->data.unionation.gen_tag_index == SIZE_MAX) {
            return nullptr;
        }
        if (instruction->initializing) {
            LLVMValueRef union_ptr = ir_llvm_value(g, instruction->union_ptr);
            LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, union_ptr,
                    union_type->data.unionation.gen_tag_index, "");
            LLVMValueRef tag_value = bigint_to_llvm_const(get_llvm_type(g, union_type->data.unionation.tag_type),
                    &field->enum_field->value);
            gen_store_untyped(g, tag_value, tag_field_ptr, 0, false);
        }
        return nullptr;
    }

    LLVMValueRef union_ptr = ir_llvm_value(g, instruction->union_ptr);
    LLVMTypeRef field_type_ref = LLVMPointerType(get_llvm_type(g, field->type_entry), 0);

    if (union_type->data.unionation.gen_tag_index == SIZE_MAX) {
        LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, union_ptr, 0, "");
        LLVMValueRef bitcasted_union_field_ptr = LLVMBuildBitCast(g->builder, union_field_ptr, field_type_ref, "");
        return bitcasted_union_field_ptr;
    }

    if (instruction->initializing) {
        LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, union_ptr, union_type->data.unionation.gen_tag_index, "");
        LLVMValueRef tag_value = bigint_to_llvm_const(get_llvm_type(g, union_type->data.unionation.tag_type),
                &field->enum_field->value);
        gen_store_untyped(g, tag_value, tag_field_ptr, 0, false);
    } else if (instruction->safety_check_on && ir_want_runtime_safety(g, &instruction->base)) {
        LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, union_ptr, union_type->data.unionation.gen_tag_index, "");
        LLVMValueRef tag_value = gen_load_untyped(g, tag_field_ptr, 0, false, "");


        LLVMValueRef expected_tag_value = bigint_to_llvm_const(get_llvm_type(g, union_type->data.unionation.tag_type),
                &field->enum_field->value);
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnionCheckOk");
        LLVMBasicBlockRef bad_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnionCheckFail");
        LLVMValueRef ok_val = LLVMBuildICmp(g->builder, LLVMIntEQ, tag_value, expected_tag_value, "");
        LLVMBuildCondBr(g->builder, ok_val, ok_block, bad_block);

        LLVMPositionBuilderAtEnd(g->builder, bad_block);
        gen_safety_crash(g, PanicMsgIdBadUnionField);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    LLVMValueRef union_field_ptr = LLVMBuildStructGEP(g->builder, union_ptr,
            union_type->data.unionation.gen_union_index, "");
    LLVMValueRef bitcasted_union_field_ptr = LLVMBuildBitCast(g->builder, union_field_ptr, field_type_ref, "");
    return bitcasted_union_field_ptr;
}

static size_t find_asm_index(CodeGen *g, AstNode *node, AsmToken *tok, Buf *src_template) {
    const char *ptr = buf_ptr(src_template) + tok->start + 2;
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

    Buf *src_template = instruction->asm_template;

    Buf llvm_template = BUF_INIT;
    buf_resize(&llvm_template, 0);

    for (size_t token_i = 0; token_i < instruction->token_list_len; token_i += 1) {
        AsmToken *asm_token = &instruction->token_list[token_i];
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
                    size_t index = find_asm_index(g, asm_node, asm_token, src_template);
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
        // LLVM uses commas internally to separate different constraints,
        // alternative constraints are achieved with pipes.
        // We still allow the user to use commas in a way that is similar
        // to GCC's inline assembly.
        // http://llvm.org/docs/LangRef.html#constraint-codes
        buf_replace(asm_output->constraint, ',', '|');

        if (is_return) {
            buf_appendf(&constraint_buf, "=%s", buf_ptr(asm_output->constraint) + 1);
        } else {
            buf_appendf(&constraint_buf, "=*%s", buf_ptr(asm_output->constraint) + 1);
        }
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        if (!is_return) {
            ZigVar *variable = instruction->output_vars[i];
            assert(variable);
            param_types[param_index] = LLVMTypeOf(variable->value_ref);
            param_values[param_index] = variable->value_ref;
            param_index += 1;
        }
    }
    for (size_t i = 0; i < asm_expr->input_list.length; i += 1, total_index += 1, param_index += 1) {
        AsmInput *asm_input = asm_expr->input_list.at(i);
        buf_replace(asm_input->constraint, ',', '|');
        IrInstruction *ir_input = instruction->input_list[i];
        buf_append_buf(&constraint_buf, asm_input->constraint);
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        ZigType *const type = ir_input->value.type;
        LLVMTypeRef type_ref = get_llvm_type(g, type);
        LLVMValueRef value_ref = ir_llvm_value(g, ir_input);
        // Handle integers of non pot bitsize by widening them.
        if (type->id == ZigTypeIdInt) {
            const size_t bitsize = type->data.integral.bit_count;
            if (bitsize < 8 || !is_power_of_2(bitsize)) {
                const bool is_signed = type->data.integral.is_signed;
                const size_t wider_bitsize = bitsize < 8 ? 8 : round_to_next_power_of_2(bitsize);
                ZigType *const wider_type = get_int_type(g, is_signed, wider_bitsize);
                type_ref = get_llvm_type(g, wider_type);
                value_ref = gen_widen_or_shorten(g, false, type, wider_type, value_ref);
            }
        }

        param_types[param_index] = type_ref;
        param_values[param_index] = value_ref;
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
        ret_type = get_llvm_type(g, instruction->base.value.type);
    }
    LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, (unsigned)input_and_output_count, false);

    bool is_volatile = instruction->has_side_effects || (asm_expr->output_list.length == 0);
    LLVMValueRef asm_fn = LLVMGetInlineAsm(function_type, buf_ptr(&llvm_template), buf_len(&llvm_template),
            buf_ptr(&constraint_buf), buf_len(&constraint_buf), is_volatile, false, LLVMInlineAsmDialectATT);

    return LLVMBuildCall(g->builder, asm_fn, param_values, (unsigned)input_and_output_count, "");
}

static LLVMValueRef gen_non_null_bit(CodeGen *g, ZigType *maybe_type, LLVMValueRef maybe_handle) {
    assert(maybe_type->id == ZigTypeIdOptional ||
            (maybe_type->id == ZigTypeIdPointer && maybe_type->data.pointer.allow_zero));

    ZigType *child_type = maybe_type->data.maybe.child_type;
    if (!type_has_bits(child_type))
        return maybe_handle;

    bool is_scalar = !handle_is_ptr(maybe_type);
    if (is_scalar)
        return LLVMBuildICmp(g->builder, LLVMIntNE, maybe_handle, LLVMConstNull(get_llvm_type(g, maybe_type)), "");

    LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, maybe_handle, maybe_null_index, "");
    return gen_load_untyped(g, maybe_field_ptr, 0, false, "");
}

static LLVMValueRef ir_render_test_non_null(CodeGen *g, IrExecutable *executable,
    IrInstructionTestNonNull *instruction)
{
    return gen_non_null_bit(g, instruction->value->value.type, ir_llvm_value(g, instruction->value));
}

static LLVMValueRef ir_render_optional_unwrap_ptr(CodeGen *g, IrExecutable *executable,
        IrInstructionOptionalUnwrapPtr *instruction)
{
    if (instruction->base.value.special != ConstValSpecialRuntime)
        return nullptr;

    ZigType *ptr_type = instruction->base_ptr->value.type;
    assert(ptr_type->id == ZigTypeIdPointer);
    ZigType *maybe_type = ptr_type->data.pointer.child_type;
    assert(maybe_type->id == ZigTypeIdOptional);
    ZigType *child_type = maybe_type->data.maybe.child_type;
    LLVMValueRef base_ptr = ir_llvm_value(g, instruction->base_ptr);
    if (instruction->safety_check_on && ir_want_runtime_safety(g, &instruction->base)) {
        LLVMValueRef maybe_handle = get_handle_value(g, base_ptr, maybe_type, ptr_type);
        LLVMValueRef non_null_bit = gen_non_null_bit(g, maybe_type, maybe_handle);
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapOptionalFail");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapOptionalOk");
        LLVMBuildCondBr(g->builder, non_null_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_safety_crash(g, PanicMsgIdUnwrapOptionalFail);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }
    if (!type_has_bits(child_type)) {
        return nullptr;
    } else {
        bool is_scalar = !handle_is_ptr(maybe_type);
        if (is_scalar) {
            return base_ptr;
        } else {
            LLVMValueRef optional_struct_ref = get_handle_value(g, base_ptr, maybe_type, ptr_type);
            if (instruction->initializing) {
                LLVMValueRef non_null_bit_ptr = LLVMBuildStructGEP(g->builder, optional_struct_ref,
                        maybe_null_index, "");
                LLVMValueRef non_null_bit = LLVMConstInt(LLVMInt1Type(), 1, false);
                gen_store_untyped(g, non_null_bit, non_null_bit_ptr, 0, false);
            }
            return LLVMBuildStructGEP(g->builder, optional_struct_ref, maybe_child_index, "");
        }
    }
}

static LLVMValueRef get_int_builtin_fn(CodeGen *g, ZigType *int_type, BuiltinFnId fn_id) {
    ZigLLVMFnKey key = {};
    const char *fn_name;
    uint32_t n_args;
    if (fn_id == BuiltinFnIdCtz) {
        fn_name = "cttz";
        n_args = 2;
        key.id = ZigLLVMFnIdCtz;
        key.data.ctz.bit_count = (uint32_t)int_type->data.integral.bit_count;
    } else if (fn_id == BuiltinFnIdClz) {
        fn_name = "ctlz";
        n_args = 2;
        key.id = ZigLLVMFnIdClz;
        key.data.clz.bit_count = (uint32_t)int_type->data.integral.bit_count;
    } else if (fn_id == BuiltinFnIdPopCount) {
        fn_name = "ctpop";
        n_args = 1;
        key.id = ZigLLVMFnIdPopCount;
        key.data.pop_count.bit_count = (uint32_t)int_type->data.integral.bit_count;
    } else if (fn_id == BuiltinFnIdBswap) {
        fn_name = "bswap";
        n_args = 1;
        key.id = ZigLLVMFnIdBswap;
        key.data.bswap.bit_count = (uint32_t)int_type->data.integral.bit_count;
    } else if (fn_id == BuiltinFnIdBitReverse) {
        fn_name = "bitreverse";
        n_args = 1;
        key.id = ZigLLVMFnIdBitReverse;
        key.data.bit_reverse.bit_count = (uint32_t)int_type->data.integral.bit_count;
    } else {
        zig_unreachable();
    }

    auto existing_entry = g->llvm_fn_table.maybe_get(key);
    if (existing_entry)
        return existing_entry->value;

    char llvm_name[64];
    sprintf(llvm_name, "llvm.%s.i%" PRIu32, fn_name, int_type->data.integral.bit_count);
    LLVMTypeRef param_types[] = {
        get_llvm_type(g, int_type),
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(get_llvm_type(g, int_type), param_types, n_args, false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, llvm_name, fn_type);
    assert(LLVMGetIntrinsicID(fn_val));

    g->llvm_fn_table.put(key, fn_val);

    return fn_val;
}

static LLVMValueRef ir_render_clz(CodeGen *g, IrExecutable *executable, IrInstructionClz *instruction) {
    ZigType *int_type = instruction->op->value.type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdClz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->op);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    return gen_widen_or_shorten(g, false, int_type, instruction->base.value.type, wrong_size_int);
}

static LLVMValueRef ir_render_ctz(CodeGen *g, IrExecutable *executable, IrInstructionCtz *instruction) {
    ZigType *int_type = instruction->op->value.type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdCtz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->op);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    return gen_widen_or_shorten(g, false, int_type, instruction->base.value.type, wrong_size_int);
}

static LLVMValueRef ir_render_pop_count(CodeGen *g, IrExecutable *executable, IrInstructionPopCount *instruction) {
    ZigType *int_type = instruction->op->value.type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdPopCount);
    LLVMValueRef operand = ir_llvm_value(g, instruction->op);
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, &operand, 1, "");
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
        phi_type = LLVMPointerType(get_llvm_type(g,instruction->base.value.type), 0);
    } else {
        phi_type = get_llvm_type(g, instruction->base.value.type);
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

static LLVMValueRef ir_render_ref(CodeGen *g, IrExecutable *executable, IrInstructionRefGen *instruction) {
    if (!type_has_bits(instruction->base.value.type)) {
        return nullptr;
    }
    LLVMValueRef value = ir_llvm_value(g, instruction->operand);
    if (handle_is_ptr(instruction->operand->value.type)) {
        return value;
    } else {
        LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
        gen_store_untyped(g, value, result_loc, 0, false);
        return result_loc;
    }
}

static LLVMValueRef ir_render_err_name(CodeGen *g, IrExecutable *executable, IrInstructionErrName *instruction) {
    assert(g->generate_error_name_table);

    if (g->errors_by_index.length == 1) {
        LLVMBuildUnreachable(g->builder);
        return nullptr;
    }

    LLVMValueRef err_val = ir_llvm_value(g, instruction->value);
    if (ir_want_runtime_safety(g, &instruction->base)) {
        LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(err_val));
        LLVMValueRef end_val = LLVMConstInt(LLVMTypeOf(err_val), g->errors_by_index.length, false);
        add_bounds_check(g, err_val, LLVMIntNE, zero, LLVMIntULT, end_val);
    }

    LLVMValueRef indices[] = {
        LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
        err_val,
    };
    return LLVMBuildInBoundsGEP(g->builder, g->err_name_table, indices, 2, "");
}

static LLVMValueRef get_enum_tag_name_function(CodeGen *g, ZigType *enum_type) {
    assert(enum_type->id == ZigTypeIdEnum);
    if (enum_type->data.enumeration.name_function)
        return enum_type->data.enumeration.name_function;

    ZigType *u8_ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, false, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0, false);
    ZigType *u8_slice_type = get_slice_type(g, u8_ptr_type);
    ZigType *tag_int_type = enum_type->data.enumeration.tag_int_type;

    LLVMTypeRef tag_int_llvm_type = get_llvm_type(g, tag_int_type);
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMPointerType(get_llvm_type(g, u8_slice_type), 0),
            &tag_int_llvm_type, 1, false);

    Buf *fn_name = get_mangled_name(g, buf_sprintf("__zig_tag_name_%s", buf_ptr(&enum_type->name)), false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(fn_name), fn_type_ref);
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    LLVMSetFunctionCallConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    if (g->build_mode == BuildModeDebug) {
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim", "true");
        ZigLLVMAddFunctionAttr(fn_val, "no-frame-pointer-elim-non-leaf", nullptr);
    }

    LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
    LLVMValueRef prev_debug_location = LLVMGetCurrentDebugLocation(g->builder);
    ZigFn *prev_cur_fn = g->cur_fn;
    LLVMValueRef prev_cur_fn_val = g->cur_fn_val;

    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn_val, "Entry");
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
    ZigLLVMClearCurrentDebugLocation(g->builder);
    g->cur_fn = nullptr;
    g->cur_fn_val = fn_val;

    size_t field_count = enum_type->data.enumeration.src_field_count;
    LLVMBasicBlockRef bad_value_block = LLVMAppendBasicBlock(g->cur_fn_val, "BadValue");
    LLVMValueRef tag_int_value = LLVMGetParam(fn_val, 0);
    LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, tag_int_value, bad_value_block, field_count);


    ZigType *usize = g->builtin_types.entry_usize;
    LLVMValueRef array_ptr_indices[] = {
        LLVMConstNull(usize->llvm_type),
        LLVMConstNull(usize->llvm_type),
    };

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
            LLVMConstGEP(str_global, array_ptr_indices, 2),
            LLVMConstInt(g->builtin_types.entry_usize->llvm_type, buf_len(name), false),
        };
        LLVMValueRef slice_init_value = LLVMConstNamedStruct(get_llvm_type(g, u8_slice_type), fields, 2);

        LLVMValueRef slice_global = LLVMAddGlobal(g->module, LLVMTypeOf(slice_init_value), "");
        LLVMSetInitializer(slice_global, slice_init_value);
        LLVMSetLinkage(slice_global, LLVMPrivateLinkage);
        LLVMSetGlobalConstant(slice_global, true);
        LLVMSetUnnamedAddr(slice_global, true);
        LLVMSetAlignment(slice_global, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(slice_init_value)));

        LLVMBasicBlockRef return_block = LLVMAppendBasicBlock(g->cur_fn_val, "Name");
        LLVMValueRef this_tag_int_value = bigint_to_llvm_const(get_llvm_type(g, tag_int_type),
                &enum_type->data.enumeration.fields[field_i].value);
        LLVMAddCase(switch_instr, this_tag_int_value, return_block);

        LLVMPositionBuilderAtEnd(g->builder, return_block);
        LLVMBuildRet(g->builder, slice_global);
    }

    LLVMPositionBuilderAtEnd(g->builder, bad_value_block);
    if (g->build_mode == BuildModeDebug || g->build_mode == BuildModeSafeRelease) {
        gen_safety_crash(g, PanicMsgIdBadEnumValue);
    } else {
        LLVMBuildUnreachable(g->builder);
    }

    g->cur_fn = prev_cur_fn;
    g->cur_fn_val = prev_cur_fn_val;
    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    if (!g->strip_debug_symbols) {
        LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);
    }

    enum_type->data.enumeration.name_function = fn_val;
    return fn_val;
}

static LLVMValueRef ir_render_enum_tag_name(CodeGen *g, IrExecutable *executable,
        IrInstructionTagName *instruction)
{
    ZigType *enum_type = instruction->target->value.type;
    assert(enum_type->id == ZigTypeIdEnum);

    LLVMValueRef enum_name_function = get_enum_tag_name_function(g, enum_type);

    LLVMValueRef enum_tag_value = ir_llvm_value(g, instruction->target);
    return ZigLLVMBuildCall(g->builder, enum_name_function, &enum_tag_value, 1,
            get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAuto, "");
}

static LLVMValueRef ir_render_field_parent_ptr(CodeGen *g, IrExecutable *executable,
        IrInstructionFieldParentPtr *instruction)
{
    ZigType *container_ptr_type = instruction->base.value.type;
    assert(container_ptr_type->id == ZigTypeIdPointer);

    ZigType *container_type = container_ptr_type->data.pointer.child_type;

    size_t byte_offset = LLVMOffsetOfElement(g->target_data_ref,
            get_llvm_type(g, container_type), instruction->field->gen_index);

    LLVMValueRef field_ptr_val = ir_llvm_value(g, instruction->field_ptr);

    if (byte_offset == 0) {
        return LLVMBuildBitCast(g->builder, field_ptr_val, get_llvm_type(g, container_ptr_type), "");
    } else {
        ZigType *usize = g->builtin_types.entry_usize;

        LLVMValueRef field_ptr_int = LLVMBuildPtrToInt(g->builder, field_ptr_val, usize->llvm_type, "");

        LLVMValueRef base_ptr_int = LLVMBuildNUWSub(g->builder, field_ptr_int,
                LLVMConstInt(usize->llvm_type, byte_offset, false), "");

        return LLVMBuildIntToPtr(g->builder, base_ptr_int, get_llvm_type(g, container_ptr_type), "");
    }
}

static LLVMValueRef ir_render_align_cast(CodeGen *g, IrExecutable *executable, IrInstructionAlignCast *instruction) {
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    assert(target_val);

    bool want_runtime_safety = ir_want_runtime_safety(g, &instruction->base);
    if (!want_runtime_safety) {
        return target_val;
    }

    ZigType *target_type = instruction->base.value.type;
    uint32_t align_bytes;
    LLVMValueRef ptr_val;

    if (target_type->id == ZigTypeIdPointer) {
        align_bytes = get_ptr_align(g, target_type);
        ptr_val = target_val;
    } else if (target_type->id == ZigTypeIdFn) {
        align_bytes = target_type->data.fn.fn_type_id.alignment;
        ptr_val = target_val;
    } else if (target_type->id == ZigTypeIdOptional &&
            target_type->data.maybe.child_type->id == ZigTypeIdPointer)
    {
        align_bytes = get_ptr_align(g, target_type->data.maybe.child_type);
        ptr_val = target_val;
    } else if (target_type->id == ZigTypeIdOptional &&
            target_type->data.maybe.child_type->id == ZigTypeIdFn)
    {
        align_bytes = target_type->data.maybe.child_type->data.fn.fn_type_id.alignment;
        ptr_val = target_val;
    } else if (target_type->id == ZigTypeIdOptional &&
            target_type->data.maybe.child_type->id == ZigTypeIdPromise)
    {
        zig_panic("TODO audit this function");
    } else if (target_type->id == ZigTypeIdStruct && target_type->data.structure.is_slice) {
        ZigType *slice_ptr_type = target_type->data.structure.fields[slice_ptr_index].type_entry;
        align_bytes = get_ptr_align(g, slice_ptr_type);

        size_t ptr_index = target_type->data.structure.fields[slice_ptr_index].gen_index;
        LLVMValueRef ptr_val_ptr = LLVMBuildStructGEP(g->builder, target_val, (unsigned)ptr_index, "");
        ptr_val = gen_load_untyped(g, ptr_val_ptr, 0, false, "");
    } else {
        zig_unreachable();
    }

    assert(align_bytes != 1);

    ZigType *usize = g->builtin_types.entry_usize;
    LLVMValueRef ptr_as_int_val = LLVMBuildPtrToInt(g->builder, ptr_val, usize->llvm_type, "");
    LLVMValueRef alignment_minus_1 = LLVMConstInt(usize->llvm_type, align_bytes - 1, false);
    LLVMValueRef anded_val = LLVMBuildAnd(g->builder, ptr_as_int_val, alignment_minus_1, "");
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, anded_val, LLVMConstNull(usize->llvm_type), "");

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "AlignCastOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "AlignCastFail");

    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_safety_crash(g, PanicMsgIdIncorrectAlignment);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);

    return target_val;
}

static LLVMValueRef ir_render_error_return_trace(CodeGen *g, IrExecutable *executable,
        IrInstructionErrorReturnTrace *instruction)
{
    LLVMValueRef cur_err_ret_trace_val = get_cur_err_ret_trace_val(g, instruction->base.scope);
    if (cur_err_ret_trace_val == nullptr) {
        ZigType *ptr_to_stack_trace_type = get_ptr_to_stack_trace_type(g);
        return LLVMConstNull(get_llvm_type(g, ptr_to_stack_trace_type));
    }
    return cur_err_ret_trace_val;
}

static LLVMValueRef ir_render_cancel(CodeGen *g, IrExecutable *executable, IrInstructionCancel *instruction) {
    LLVMValueRef target_handle = ir_llvm_value(g, instruction->target);
    LLVMBuildCall(g->builder, get_coro_destroy_fn_val(g), &target_handle, 1, "");
    return nullptr;
}

static LLVMValueRef ir_render_get_implicit_allocator(CodeGen *g, IrExecutable *executable,
        IrInstructionGetImplicitAllocator *instruction)
{
    assert(instruction->id == ImplicitAllocatorIdArg);
    size_t allocator_arg_index = get_async_allocator_arg_index(g, &g->cur_fn->type_entry->data.fn.fn_type_id);
    return LLVMGetParam(g->cur_fn_val, allocator_arg_index);
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

static LLVMAtomicRMWBinOp to_LLVMAtomicRMWBinOp(AtomicRmwOp op, bool is_signed) {
    switch (op) {
        case AtomicRmwOp_xchg: return LLVMAtomicRMWBinOpXchg;
        case AtomicRmwOp_add: return LLVMAtomicRMWBinOpAdd;
        case AtomicRmwOp_sub: return LLVMAtomicRMWBinOpSub;
        case AtomicRmwOp_and: return LLVMAtomicRMWBinOpAnd;
        case AtomicRmwOp_nand: return LLVMAtomicRMWBinOpNand;
        case AtomicRmwOp_or: return LLVMAtomicRMWBinOpOr;
        case AtomicRmwOp_xor: return LLVMAtomicRMWBinOpXor;
        case AtomicRmwOp_max:
            return is_signed ? LLVMAtomicRMWBinOpMax : LLVMAtomicRMWBinOpUMax;
        case AtomicRmwOp_min:
            return is_signed ? LLVMAtomicRMWBinOpMin : LLVMAtomicRMWBinOpUMin;
    }
    zig_unreachable();
}

static LLVMValueRef ir_render_cmpxchg(CodeGen *g, IrExecutable *executable, IrInstructionCmpxchgGen *instruction) {
    LLVMValueRef ptr_val = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef cmp_val = ir_llvm_value(g, instruction->cmp_value);
    LLVMValueRef new_val = ir_llvm_value(g, instruction->new_value);

    LLVMAtomicOrdering success_order = to_LLVMAtomicOrdering(instruction->success_order);
    LLVMAtomicOrdering failure_order = to_LLVMAtomicOrdering(instruction->failure_order);

    LLVMValueRef result_val = ZigLLVMBuildCmpXchg(g->builder, ptr_val, cmp_val, new_val,
            success_order, failure_order, instruction->is_weak);

    ZigType *optional_type = instruction->base.value.type;
    assert(optional_type->id == ZigTypeIdOptional);
    ZigType *child_type = optional_type->data.maybe.child_type;

    if (!handle_is_ptr(optional_type)) {
        LLVMValueRef payload_val = LLVMBuildExtractValue(g->builder, result_val, 0, "");
        LLVMValueRef success_bit = LLVMBuildExtractValue(g->builder, result_val, 1, "");
        return LLVMBuildSelect(g->builder, success_bit, LLVMConstNull(get_llvm_type(g, child_type)), payload_val, "");
    }

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
    assert(type_has_bits(child_type));

    LLVMValueRef payload_val = LLVMBuildExtractValue(g->builder, result_val, 0, "");
    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_child_index, "");
    gen_assign_raw(g, val_ptr, get_pointer_to_type(g, child_type, false), payload_val);

    LLVMValueRef success_bit = LLVMBuildExtractValue(g->builder, result_val, 1, "");
    LLVMValueRef nonnull_bit = LLVMBuildNot(g->builder, success_bit, "");
    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_null_index, "");
    gen_store_untyped(g, nonnull_bit, maybe_ptr, 0, false);
    return result_loc;
}

static LLVMValueRef ir_render_fence(CodeGen *g, IrExecutable *executable, IrInstructionFence *instruction) {
    LLVMAtomicOrdering atomic_order = to_LLVMAtomicOrdering(instruction->order);
    LLVMBuildFence(g->builder, atomic_order, false, "");
    return nullptr;
}

static LLVMValueRef ir_render_truncate(CodeGen *g, IrExecutable *executable, IrInstructionTruncate *instruction) {
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    ZigType *dest_type = instruction->base.value.type;
    ZigType *src_type = instruction->target->value.type;
    if (dest_type == src_type) {
        // no-op
        return target_val;
    } if (src_type->data.integral.bit_count == dest_type->data.integral.bit_count) {
        return LLVMBuildBitCast(g->builder, target_val, get_llvm_type(g, dest_type), "");
    } else {
        LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
        return LLVMBuildTrunc(g->builder, target_val, get_llvm_type(g, dest_type), "");
    }
}

static LLVMValueRef ir_render_memset(CodeGen *g, IrExecutable *executable, IrInstructionMemset *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");

    ZigType *ptr_type = instruction->dest_ptr->value.type;
    assert(ptr_type->id == ZigTypeIdPointer);

    bool val_is_undef = value_is_all_undef(&instruction->byte->value);
    LLVMValueRef fill_char;
    if (val_is_undef) {
        fill_char = LLVMConstInt(LLVMInt8Type(), 0xaa, false);
    } else {
        fill_char = ir_llvm_value(g, instruction->byte);
    }
    ZigLLVMBuildMemSet(g->builder, dest_ptr_casted, fill_char, len_val, get_ptr_align(g, ptr_type),
            ptr_type->data.pointer.is_volatile);

    if (val_is_undef && want_valgrind_support(g)) {
        gen_valgrind_undef(g, dest_ptr_casted, len_val);
    }
    return nullptr;
}

static LLVMValueRef ir_render_memcpy(CodeGen *g, IrExecutable *executable, IrInstructionMemcpy *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef src_ptr = ir_llvm_value(g, instruction->src_ptr);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");
    LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr, ptr_u8, "");

    ZigType *dest_ptr_type = instruction->dest_ptr->value.type;
    ZigType *src_ptr_type = instruction->src_ptr->value.type;

    assert(dest_ptr_type->id == ZigTypeIdPointer);
    assert(src_ptr_type->id == ZigTypeIdPointer);

    bool is_volatile = (dest_ptr_type->data.pointer.is_volatile || src_ptr_type->data.pointer.is_volatile);
    ZigLLVMBuildMemCpy(g->builder, dest_ptr_casted, get_ptr_align(g, dest_ptr_type),
            src_ptr_casted, get_ptr_align(g, src_ptr_type), len_val, is_volatile);
    return nullptr;
}

static LLVMValueRef ir_render_slice(CodeGen *g, IrExecutable *executable, IrInstructionSliceGen *instruction) {
    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->ptr);
    ZigType *array_ptr_type = instruction->ptr->value.type;
    assert(array_ptr_type->id == ZigTypeIdPointer);
    ZigType *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);

    LLVMValueRef tmp_struct_ptr = ir_llvm_value(g, instruction->result_loc);

    bool want_runtime_safety = instruction->safety_check_on && ir_want_runtime_safety(g, &instruction->base);

    if (array_type->id == ZigTypeIdArray ||
        (array_type->id == ZigTypeIdPointer && array_type->data.pointer.ptr_len == PtrLenSingle))
    {
        if (array_type->id == ZigTypeIdPointer) {
            array_type = array_type->data.pointer.child_type;
        }
        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val;
        if (instruction->end) {
            end_val = ir_llvm_value(g, instruction->end);
        } else {
            end_val = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, array_type->data.array.len, false);
        }
        if (want_runtime_safety) {
            if (instruction->start->value.special == ConstValSpecialRuntime || instruction->end) {
                add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
            }
            if (instruction->end) {
                LLVMValueRef array_end = LLVMConstInt(g->builtin_types.entry_usize->llvm_type,
                        array_type->data.array.len, false);
                add_bounds_check(g, end_val, LLVMIntEQ, nullptr, LLVMIntULE, array_end);
            }
        }
        if (!type_has_bits(array_type)) {
            LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_len_index, "");

            // TODO if runtime safety is on, store 0xaaaaaaa in ptr field
            LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
            gen_store_untyped(g, len_value, len_field_ptr, 0, false);
            return tmp_struct_ptr;
        }


        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_ptr_index, "");
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
            start_val,
        };
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
        gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);

        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, slice_len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        gen_store_untyped(g, len_value, len_field_ptr, 0, false);

        return tmp_struct_ptr;
    } else if (array_type->id == ZigTypeIdPointer) {
        assert(array_type->data.pointer.ptr_len != PtrLenSingle);
        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val = ir_llvm_value(g, instruction->end);

        if (want_runtime_safety) {
            add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
        }

        if (type_has_bits(array_type)) {
            size_t gen_ptr_index = instruction->base.value.type->data.structure.fields[slice_ptr_index].gen_index;
            LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, gen_ptr_index, "");
            LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, &start_val, 1, "");
            gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);
        }

        size_t gen_len_index = instruction->base.value.type->data.structure.fields[slice_len_index].gen_index;
        LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, gen_len_index, "");
        LLVMValueRef len_value = LLVMBuildNSWSub(g->builder, end_val, start_val, "");
        gen_store_untyped(g, len_value, len_field_ptr, 0, false);

        return tmp_struct_ptr;
    } else if (array_type->id == ZigTypeIdStruct) {
        assert(array_type->data.structure.is_slice);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(tmp_struct_ptr))) == LLVMStructTypeKind);

        size_t ptr_index = array_type->data.structure.fields[slice_ptr_index].gen_index;
        assert(ptr_index != SIZE_MAX);
        size_t len_index = array_type->data.structure.fields[slice_len_index].gen_index;
        assert(len_index != SIZE_MAX);

        LLVMValueRef prev_end = nullptr;
        if (!instruction->end || want_runtime_safety) {
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

        if (want_runtime_safety) {
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

static LLVMValueRef ir_render_return_address(CodeGen *g, IrExecutable *executable,
        IrInstructionReturnAddress *instruction)
{
    LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->llvm_type);
    LLVMValueRef ptr_val = LLVMBuildCall(g->builder, get_return_address_fn_val(g), &zero, 1, "");
    return LLVMBuildPtrToInt(g->builder, ptr_val, g->builtin_types.entry_usize->llvm_type, "");
}

static LLVMValueRef get_frame_address_fn_val(CodeGen *g) {
    if (g->frame_address_fn_val)
        return g->frame_address_fn_val;

    ZigType *return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

    LLVMTypeRef fn_type = LLVMFunctionType(get_llvm_type(g, return_type),
            &g->builtin_types.entry_i32->llvm_type, 1, false);
    g->frame_address_fn_val = LLVMAddFunction(g->module, "llvm.frameaddress", fn_type);
    assert(LLVMGetIntrinsicID(g->frame_address_fn_val));

    return g->frame_address_fn_val;
}

static LLVMValueRef ir_render_frame_address(CodeGen *g, IrExecutable *executable,
        IrInstructionFrameAddress *instruction)
{
    LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->llvm_type);
    LLVMValueRef ptr_val = LLVMBuildCall(g->builder, get_frame_address_fn_val(g), &zero, 1, "");
    return LLVMBuildPtrToInt(g->builder, ptr_val, g->builtin_types.entry_usize->llvm_type, "");
}

static LLVMValueRef get_handle_fn_val(CodeGen *g) {
    if (g->coro_frame_fn_val)
        return g->coro_frame_fn_val;

    LLVMTypeRef fn_type = LLVMFunctionType( LLVMPointerType(LLVMInt8Type(), 0)
                                          , nullptr, 0, false);
    Buf *name = buf_sprintf("llvm.coro.frame");
    g->coro_frame_fn_val = LLVMAddFunction(g->module, buf_ptr(name), fn_type);
    assert(LLVMGetIntrinsicID(g->coro_frame_fn_val));

    return g->coro_frame_fn_val;
}

static LLVMValueRef ir_render_handle(CodeGen *g, IrExecutable *executable,
        IrInstructionHandle *instruction)
{
    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, g->builtin_types.entry_promise));
    return LLVMBuildCall(g->builder, get_handle_fn_val(g), &zero, 0, "");
}

static LLVMValueRef render_shl_with_overflow(CodeGen *g, IrInstructionOverflowOp *instruction) {
    ZigType *int_type = instruction->result_ptr_type;
    assert(int_type->id == ZigTypeIdInt);

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

    ZigType *int_type = instruction->result_ptr_type;
    assert(int_type->id == ZigTypeIdInt);

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

static LLVMValueRef ir_render_test_err(CodeGen *g, IrExecutable *executable, IrInstructionTestErrGen *instruction) {
    ZigType *err_union_type = instruction->err_union->value.type;
    ZigType *payload_type = err_union_type->data.error_union.payload_type;
    LLVMValueRef err_union_handle = ir_llvm_value(g, instruction->err_union);

    LLVMValueRef err_val;
    if (type_has_bits(payload_type)) {
        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
        err_val = gen_load_untyped(g, err_val_ptr, 0, false, "");
    } else {
        err_val = err_union_handle;
    }

    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, g->err_tag_type));
    return LLVMBuildICmp(g->builder, LLVMIntNE, err_val, zero, "");
}

static LLVMValueRef ir_render_unwrap_err_code(CodeGen *g, IrExecutable *executable,
        IrInstructionUnwrapErrCode *instruction)
{
    if (instruction->base.value.special != ConstValSpecialRuntime)
        return nullptr;

    ZigType *ptr_type = instruction->err_union_ptr->value.type;
    assert(ptr_type->id == ZigTypeIdPointer);
    ZigType *err_union_type = ptr_type->data.pointer.child_type;
    ZigType *payload_type = err_union_type->data.error_union.payload_type;
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->err_union_ptr);
    if (!type_has_bits(payload_type)) {
        return err_union_ptr;
    } else {
        // TODO assign undef to the payload
        LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, ptr_type);
        return LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
    }
}

static LLVMValueRef ir_render_unwrap_err_payload(CodeGen *g, IrExecutable *executable,
        IrInstructionUnwrapErrPayload *instruction)
{
    if (instruction->base.value.special != ConstValSpecialRuntime)
        return nullptr;

    bool want_safety = instruction->safety_check_on && ir_want_runtime_safety(g, &instruction->base) &&
        g->errors_by_index.length > 1;
    if (!want_safety && !type_has_bits(instruction->base.value.type))
        return nullptr;
    ZigType *ptr_type = instruction->value->value.type;
    assert(ptr_type->id == ZigTypeIdPointer);
    ZigType *err_union_type = ptr_type->data.pointer.child_type;
    ZigType *payload_type = err_union_type->data.error_union.payload_type;
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->value);
    LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, ptr_type);

    if (!type_has_bits(err_union_type->data.error_union.err_set_type)) {
        return err_union_handle;
    }

    if (want_safety) {
        LLVMValueRef err_val;
        if (type_has_bits(payload_type)) {
            LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
            err_val = gen_load_untyped(g, err_val_ptr, 0, false, "");
        } else {
            err_val = err_union_handle;
        }
        LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, g->err_tag_type));
        LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, zero, "");
        LLVMBasicBlockRef err_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrError");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrOk");
        LLVMBuildCondBr(g->builder, cond_val, ok_block, err_block);

        LLVMPositionBuilderAtEnd(g->builder, err_block);
        gen_safety_crash_for_err(g, err_val, instruction->base.scope);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    if (type_has_bits(payload_type)) {
        if (instruction->initializing) {
            LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
            LLVMValueRef ok_err_val = LLVMConstNull(get_llvm_type(g, g->err_tag_type));
            gen_store_untyped(g, ok_err_val, err_tag_ptr, 0, false);
        }
        return LLVMBuildStructGEP(g->builder, err_union_handle, err_union_payload_index, "");
    } else {
        return nullptr;
    }
}

static LLVMValueRef ir_render_optional_wrap(CodeGen *g, IrExecutable *executable, IrInstructionOptionalWrap *instruction) {
    ZigType *wanted_type = instruction->base.value.type;

    assert(wanted_type->id == ZigTypeIdOptional);

    ZigType *child_type = wanted_type->data.maybe.child_type;

    if (!type_has_bits(child_type)) {
        LLVMValueRef result = LLVMConstAllOnes(LLVMInt1Type());
        if (instruction->result_loc != nullptr) {
            LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
            gen_store_untyped(g, result, result_loc, 0, false);
        }
        return result;
    }

    LLVMValueRef payload_val = ir_llvm_value(g, instruction->operand);
    if (!handle_is_ptr(wanted_type)) {
        if (instruction->result_loc != nullptr) {
            LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
            gen_store_untyped(g, payload_val, result_loc, 0, false);
        }
        return payload_val;
    }

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_child_index, "");
    // child_type and instruction->value->value.type may differ by constness
    gen_assign_raw(g, val_ptr, get_pointer_to_type(g, child_type, false), payload_val);
    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_null_index, "");
    gen_store_untyped(g, LLVMConstAllOnes(LLVMInt1Type()), maybe_ptr, 0, false);

    return result_loc;
}

static LLVMValueRef ir_render_err_wrap_code(CodeGen *g, IrExecutable *executable, IrInstructionErrWrapCode *instruction) {
    ZigType *wanted_type = instruction->base.value.type;

    assert(wanted_type->id == ZigTypeIdErrorUnion);

    LLVMValueRef err_val = ir_llvm_value(g, instruction->operand);

    if (!handle_is_ptr(wanted_type))
        return err_val;

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_err_index, "");
    gen_store_untyped(g, err_val, err_tag_ptr, 0, false);

    // TODO store undef to the payload

    return result_loc;
}

static LLVMValueRef ir_render_err_wrap_payload(CodeGen *g, IrExecutable *executable, IrInstructionErrWrapPayload *instruction) {
    ZigType *wanted_type = instruction->base.value.type;

    assert(wanted_type->id == ZigTypeIdErrorUnion);

    ZigType *payload_type = wanted_type->data.error_union.payload_type;
    ZigType *err_set_type = wanted_type->data.error_union.err_set_type;

    if (!type_has_bits(err_set_type)) {
        return ir_llvm_value(g, instruction->operand);
    }

    LLVMValueRef ok_err_val = LLVMConstNull(get_llvm_type(g, g->err_tag_type));

    if (!type_has_bits(payload_type))
        return ok_err_val;


    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    LLVMValueRef payload_val = ir_llvm_value(g, instruction->operand);

    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_err_index, "");
    gen_store_untyped(g, ok_err_val, err_tag_ptr, 0, false);

    LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_payload_index, "");
    gen_assign_raw(g, payload_ptr, get_pointer_to_type(g, payload_type, false), payload_val);

    return result_loc;
}

static LLVMValueRef ir_render_union_tag(CodeGen *g, IrExecutable *executable, IrInstructionUnionTag *instruction) {
    ZigType *union_type = instruction->value->value.type;

    ZigType *tag_type = union_type->data.unionation.tag_type;
    if (!type_has_bits(tag_type))
        return nullptr;

    LLVMValueRef union_val = ir_llvm_value(g, instruction->value);
    if (union_type->data.unionation.gen_field_count == 0)
        return union_val;

    assert(union_type->data.unionation.gen_tag_index != SIZE_MAX);
    LLVMValueRef tag_field_ptr = LLVMBuildStructGEP(g->builder, union_val,
            union_type->data.unionation.gen_tag_index, "");
    ZigType *ptr_type = get_pointer_to_type(g, tag_type, false);
    return get_handle_value(g, tag_field_ptr, tag_type, ptr_type);
}

static LLVMValueRef ir_render_panic(CodeGen *g, IrExecutable *executable, IrInstructionPanic *instruction) {
    gen_panic(g, ir_llvm_value(g, instruction->msg), get_cur_err_ret_trace_val(g, instruction->base.scope));
    return nullptr;
}

static LLVMValueRef ir_render_coro_id(CodeGen *g, IrExecutable *executable, IrInstructionCoroId *instruction) {
    LLVMValueRef promise_ptr = ir_llvm_value(g, instruction->promise_ptr);
    LLVMValueRef align_val = LLVMConstInt(LLVMInt32Type(), get_coro_frame_align_bytes(g), false);
    LLVMValueRef null = LLVMConstIntToPtr(LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
            LLVMPointerType(LLVMInt8Type(), 0));
    LLVMValueRef params[] = {
        align_val,
        promise_ptr,
        null,
        null,
    };
    return LLVMBuildCall(g->builder, get_coro_id_fn_val(g), params, 4, "");
}

static LLVMValueRef ir_render_coro_alloc(CodeGen *g, IrExecutable *executable, IrInstructionCoroAlloc *instruction) {
    LLVMValueRef token = ir_llvm_value(g, instruction->coro_id);
    return LLVMBuildCall(g->builder, get_coro_alloc_fn_val(g), &token, 1, "");
}

static LLVMValueRef ir_render_coro_size(CodeGen *g, IrExecutable *executable, IrInstructionCoroSize *instruction) {
    return LLVMBuildCall(g->builder, get_coro_size_fn_val(g), nullptr, 0, "");
}

static LLVMValueRef ir_render_coro_begin(CodeGen *g, IrExecutable *executable, IrInstructionCoroBegin *instruction) {
    LLVMValueRef coro_id = ir_llvm_value(g, instruction->coro_id);
    LLVMValueRef coro_mem_ptr = ir_llvm_value(g, instruction->coro_mem_ptr);
    LLVMValueRef params[] = {
        coro_id,
        coro_mem_ptr,
    };
    return LLVMBuildCall(g->builder, get_coro_begin_fn_val(g), params, 2, "");
}

static LLVMValueRef ir_render_coro_alloc_fail(CodeGen *g, IrExecutable *executable,
        IrInstructionCoroAllocFail *instruction)
{
    size_t err_code_ptr_arg_index = get_async_err_code_arg_index(g, &g->cur_fn->type_entry->data.fn.fn_type_id);
    LLVMValueRef err_code_ptr_val = LLVMGetParam(g->cur_fn_val, err_code_ptr_arg_index);
    LLVMValueRef err_code = ir_llvm_value(g, instruction->err_val);
    LLVMBuildStore(g->builder, err_code, err_code_ptr_val);

    LLVMValueRef return_value;
    if (ir_want_runtime_safety(g, &instruction->base)) {
        return_value = LLVMConstNull(LLVMPointerType(LLVMInt8Type(), 0));
    } else {
        return_value = LLVMGetUndef(LLVMPointerType(LLVMInt8Type(), 0));
    }
    LLVMBuildRet(g->builder, return_value);
    return nullptr;
}

static LLVMValueRef ir_render_coro_suspend(CodeGen *g, IrExecutable *executable, IrInstructionCoroSuspend *instruction) {
    LLVMValueRef save_point;
    if (instruction->save_point == nullptr) {
        save_point = LLVMConstNull(ZigLLVMTokenTypeInContext(LLVMGetGlobalContext()));
    } else {
        save_point = ir_llvm_value(g, instruction->save_point);
    }
    LLVMValueRef is_final = ir_llvm_value(g, instruction->is_final);
    LLVMValueRef params[] = {
        save_point,
        is_final,
    };
    return LLVMBuildCall(g->builder, get_coro_suspend_fn_val(g), params, 2, "");
}

static LLVMValueRef ir_render_coro_end(CodeGen *g, IrExecutable *executable, IrInstructionCoroEnd *instruction) {
    LLVMValueRef params[] = {
        LLVMConstNull(LLVMPointerType(LLVMInt8Type(), 0)),
        LLVMConstNull(LLVMInt1Type()),
    };
    return LLVMBuildCall(g->builder, get_coro_end_fn_val(g), params, 2, "");
}

static LLVMValueRef ir_render_coro_free(CodeGen *g, IrExecutable *executable, IrInstructionCoroFree *instruction) {
    LLVMValueRef coro_id = ir_llvm_value(g, instruction->coro_id);
    LLVMValueRef coro_handle = ir_llvm_value(g, instruction->coro_handle);
    LLVMValueRef params[] = {
        coro_id,
        coro_handle,
    };
    return LLVMBuildCall(g->builder, get_coro_free_fn_val(g), params, 2, "");
}

static LLVMValueRef ir_render_coro_resume(CodeGen *g, IrExecutable *executable, IrInstructionCoroResume *instruction) {
    LLVMValueRef awaiter_handle = ir_llvm_value(g, instruction->awaiter_handle);
    return LLVMBuildCall(g->builder, get_coro_resume_fn_val(g), &awaiter_handle, 1, "");
}

static LLVMValueRef ir_render_coro_save(CodeGen *g, IrExecutable *executable, IrInstructionCoroSave *instruction) {
    LLVMValueRef coro_handle = ir_llvm_value(g, instruction->coro_handle);
    return LLVMBuildCall(g->builder, get_coro_save_fn_val(g), &coro_handle, 1, "");
}

static LLVMValueRef ir_render_coro_promise(CodeGen *g, IrExecutable *executable, IrInstructionCoroPromise *instruction) {
    LLVMValueRef coro_handle = ir_llvm_value(g, instruction->coro_handle);
    LLVMValueRef params[] = {
        coro_handle,
        LLVMConstInt(LLVMInt32Type(), get_coro_frame_align_bytes(g), false),
        LLVMConstNull(LLVMInt1Type()),
    };
    LLVMValueRef uncasted_result = LLVMBuildCall(g->builder, get_coro_promise_fn_val(g), params, 3, "");
    return LLVMBuildBitCast(g->builder, uncasted_result, get_llvm_type(g, instruction->base.value.type), "");
}

static LLVMValueRef get_coro_alloc_helper_fn_val(CodeGen *g, LLVMTypeRef alloc_fn_type_ref, ZigType *fn_type) {
    if (g->coro_alloc_helper_fn_val != nullptr)
        return g->coro_alloc_helper_fn_val;

    assert(fn_type->id == ZigTypeIdFn);

    ZigType *ptr_to_err_code_type = get_pointer_to_type(g, g->builtin_types.entry_global_error_set, false);

    LLVMTypeRef alloc_raw_fn_type_ref = LLVMGetElementType(alloc_fn_type_ref);
    LLVMTypeRef *alloc_fn_arg_types = allocate<LLVMTypeRef>(LLVMCountParamTypes(alloc_raw_fn_type_ref));
    LLVMGetParamTypes(alloc_raw_fn_type_ref, alloc_fn_arg_types);

    ZigList<LLVMTypeRef> arg_types = {};
    arg_types.append(alloc_fn_type_ref);
    if (g->have_err_ret_tracing) {
        arg_types.append(alloc_fn_arg_types[1]);
    }
    arg_types.append(alloc_fn_arg_types[g->have_err_ret_tracing ? 2 : 1]);
    arg_types.append(get_llvm_type(g, ptr_to_err_code_type));
    arg_types.append(g->builtin_types.entry_usize->llvm_type);

    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMPointerType(LLVMInt8Type(), 0),
            arg_types.items, arg_types.length, false);

    Buf *fn_name = get_mangled_name(g, buf_create_from_str("__zig_coro_alloc_helper"), false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, buf_ptr(fn_name), fn_type_ref);
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    LLVMSetFunctionCallConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    addLLVMArgAttr(fn_val, (unsigned)0, "nonnull");
    addLLVMArgAttr(fn_val, (unsigned)1, "nonnull");

    LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
    LLVMValueRef prev_debug_location = LLVMGetCurrentDebugLocation(g->builder);
    ZigFn *prev_cur_fn = g->cur_fn;
    LLVMValueRef prev_cur_fn_val = g->cur_fn_val;

    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn_val, "Entry");
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
    ZigLLVMClearCurrentDebugLocation(g->builder);
    g->cur_fn = nullptr;
    g->cur_fn_val = fn_val;

    LLVMValueRef sret_ptr = LLVMBuildAlloca(g->builder, LLVMGetElementType(alloc_fn_arg_types[0]), "");

    size_t next_arg = 0;
    LLVMValueRef realloc_fn_val = LLVMGetParam(fn_val, next_arg);
    next_arg += 1;

    LLVMValueRef stack_trace_val;
    if (g->have_err_ret_tracing) {
        stack_trace_val = LLVMGetParam(fn_val, next_arg);
        next_arg += 1;
    }

    LLVMValueRef allocator_val = LLVMGetParam(fn_val, next_arg);
    next_arg += 1;
    LLVMValueRef err_code_ptr = LLVMGetParam(fn_val, next_arg);
    next_arg += 1;
    LLVMValueRef coro_size = LLVMGetParam(fn_val, next_arg);
    next_arg += 1;
    LLVMValueRef alignment_val = LLVMConstInt(g->builtin_types.entry_u29->llvm_type,
            get_coro_frame_align_bytes(g), false);

    ConstExprValue *zero_array = create_const_str_lit(g, buf_create_from_str(""));
    ConstExprValue *undef_slice_zero = create_const_slice(g, zero_array, 0, 0, false);
    render_const_val(g, undef_slice_zero, "");
    render_const_val_global(g, undef_slice_zero, "");

    ZigList<LLVMValueRef> args = {};
    args.append(sret_ptr);
    if (g->have_err_ret_tracing) {
        args.append(stack_trace_val);
    }
    args.append(allocator_val);
    args.append(undef_slice_zero->global_refs->llvm_global);
    args.append(LLVMGetUndef(g->builtin_types.entry_u29->llvm_type));
    args.append(coro_size);
    args.append(alignment_val);
    LLVMValueRef call_instruction = ZigLLVMBuildCall(g->builder, realloc_fn_val, args.items, args.length,
            get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAuto, "");
    set_call_instr_sret(g, call_instruction);
    LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, sret_ptr, err_union_err_index, "");
    LLVMValueRef err_val = LLVMBuildLoad(g->builder, err_val_ptr, "");
    LLVMBuildStore(g->builder, err_val, err_code_ptr);
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, LLVMConstNull(LLVMTypeOf(err_val)), "");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(fn_val, "AllocOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(fn_val, "AllocFail");
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, sret_ptr, err_union_payload_index, "");
    ZigType *u8_ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, false, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0, false);
    ZigType *slice_type = get_slice_type(g, u8_ptr_type);
    size_t ptr_field_index = slice_type->data.structure.fields[slice_ptr_index].gen_index;
    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, payload_ptr, ptr_field_index, "");
    LLVMValueRef ptr_val = LLVMBuildLoad(g->builder, ptr_field_ptr, "");
    LLVMBuildRet(g->builder, ptr_val);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    LLVMBuildRet(g->builder, LLVMConstNull(LLVMPointerType(LLVMInt8Type(), 0)));

    g->cur_fn = prev_cur_fn;
    g->cur_fn_val = prev_cur_fn_val;
    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    if (!g->strip_debug_symbols) {
        LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);
    }

    g->coro_alloc_helper_fn_val = fn_val;
    return fn_val;
}

static LLVMValueRef ir_render_coro_alloc_helper(CodeGen *g, IrExecutable *executable,
        IrInstructionCoroAllocHelper *instruction)
{
    LLVMValueRef realloc_fn = ir_llvm_value(g, instruction->realloc_fn);
    LLVMValueRef coro_size = ir_llvm_value(g, instruction->coro_size);
    LLVMValueRef fn_val = get_coro_alloc_helper_fn_val(g, LLVMTypeOf(realloc_fn), instruction->realloc_fn->value.type);
    size_t err_code_ptr_arg_index = get_async_err_code_arg_index(g, &g->cur_fn->type_entry->data.fn.fn_type_id);
    size_t allocator_arg_index = get_async_allocator_arg_index(g, &g->cur_fn->type_entry->data.fn.fn_type_id);

    ZigList<LLVMValueRef> params = {};
    params.append(realloc_fn);
    uint32_t err_ret_trace_arg_index = get_err_ret_trace_arg_index(g, g->cur_fn);
    if (err_ret_trace_arg_index != UINT32_MAX) {
        params.append(LLVMGetParam(g->cur_fn_val, err_ret_trace_arg_index));
    }
    params.append(LLVMGetParam(g->cur_fn_val, allocator_arg_index));
    params.append(LLVMGetParam(g->cur_fn_val, err_code_ptr_arg_index));
    params.append(coro_size);

    return ZigLLVMBuildCall(g->builder, fn_val, params.items, params.length,
            get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAuto, "");
}

static LLVMValueRef ir_render_atomic_rmw(CodeGen *g, IrExecutable *executable,
        IrInstructionAtomicRmw *instruction)
{
    bool is_signed;
    ZigType *operand_type = instruction->operand->value.type;
    if (operand_type->id == ZigTypeIdInt) {
        is_signed = operand_type->data.integral.is_signed;
    } else {
        is_signed = false;
    }
    LLVMAtomicRMWBinOp op = to_LLVMAtomicRMWBinOp(instruction->resolved_op, is_signed);
    LLVMAtomicOrdering ordering = to_LLVMAtomicOrdering(instruction->resolved_ordering);
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef operand = ir_llvm_value(g, instruction->operand);

    if (get_codegen_ptr_type(operand_type) == nullptr) {
        return LLVMBuildAtomicRMW(g->builder, op, ptr, operand, ordering, false);
    }

    // it's a pointer but we need to treat it as an int
    LLVMValueRef casted_ptr = LLVMBuildBitCast(g->builder, ptr,
        LLVMPointerType(g->builtin_types.entry_usize->llvm_type, 0), "");
    LLVMValueRef casted_operand = LLVMBuildPtrToInt(g->builder, operand, g->builtin_types.entry_usize->llvm_type, "");
    LLVMValueRef uncasted_result = LLVMBuildAtomicRMW(g->builder, op, casted_ptr, casted_operand, ordering, false);
    return LLVMBuildIntToPtr(g->builder, uncasted_result, get_llvm_type(g, operand_type), "");
}

static LLVMValueRef ir_render_atomic_load(CodeGen *g, IrExecutable *executable,
        IrInstructionAtomicLoad *instruction)
{
    LLVMAtomicOrdering ordering = to_LLVMAtomicOrdering(instruction->resolved_ordering);
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef load_inst = gen_load(g, ptr, instruction->ptr->value.type, "");
    LLVMSetOrdering(load_inst, ordering);
    return load_inst;
}

static LLVMValueRef ir_render_merge_err_ret_traces(CodeGen *g, IrExecutable *executable,
        IrInstructionMergeErrRetTraces *instruction)
{
    assert(g->have_err_ret_tracing);

    LLVMValueRef src_trace_ptr = ir_llvm_value(g, instruction->src_err_ret_trace_ptr);
    LLVMValueRef dest_trace_ptr = ir_llvm_value(g, instruction->dest_err_ret_trace_ptr);

    LLVMValueRef args[] = { dest_trace_ptr, src_trace_ptr };
    ZigLLVMBuildCall(g->builder, get_merge_err_ret_traces_fn_val(g), args, 2, get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_FnInlineAuto, "");
    return nullptr;
}

static LLVMValueRef ir_render_mark_err_ret_trace_ptr(CodeGen *g, IrExecutable *executable,
        IrInstructionMarkErrRetTracePtr *instruction)
{
    assert(g->have_err_ret_tracing);
    g->cur_err_ret_trace_val_stack = ir_llvm_value(g, instruction->err_ret_trace_ptr);
    return nullptr;
}

static LLVMValueRef ir_render_float_op(CodeGen *g, IrExecutable *executable, IrInstructionFloatOp *instruction) {
    LLVMValueRef op = ir_llvm_value(g, instruction->op1);
    assert(instruction->base.value.type->id == ZigTypeIdFloat);
    LLVMValueRef fn_val = get_float_fn(g, instruction->base.value.type, ZigLLVMFnIdFloatOp, instruction->op);
    return LLVMBuildCall(g->builder, fn_val, &op, 1, "");
}

static LLVMValueRef ir_render_mul_add(CodeGen *g, IrExecutable *executable, IrInstructionMulAdd *instruction) {
    LLVMValueRef op1 = ir_llvm_value(g, instruction->op1);
    LLVMValueRef op2 = ir_llvm_value(g, instruction->op2);
    LLVMValueRef op3 = ir_llvm_value(g, instruction->op3);
    assert(instruction->base.value.type->id == ZigTypeIdFloat ||
           instruction->base.value.type->id == ZigTypeIdVector);
    LLVMValueRef fn_val = get_float_fn(g, instruction->base.value.type, ZigLLVMFnIdFMA, BuiltinFnIdMulAdd);
    LLVMValueRef args[3] = {
        op1,
        op2,
        op3,
    };
    return LLVMBuildCall(g->builder, fn_val, args, 3, "");
}

static LLVMValueRef ir_render_bswap(CodeGen *g, IrExecutable *executable, IrInstructionBswap *instruction) {
    LLVMValueRef op = ir_llvm_value(g, instruction->op);
    ZigType *int_type = instruction->base.value.type;
    assert(int_type->id == ZigTypeIdInt);
    if (int_type->data.integral.bit_count % 16 == 0) {
        LLVMValueRef fn_val = get_int_builtin_fn(g, instruction->base.value.type, BuiltinFnIdBswap);
        return LLVMBuildCall(g->builder, fn_val, &op, 1, "");
    }
    // Not an even number of bytes, so we zext 1 byte, then bswap, shift right 1 byte, truncate
    ZigType *extended_type = get_int_type(g, int_type->data.integral.is_signed,
            int_type->data.integral.bit_count + 8);
    // aabbcc
    LLVMValueRef extended = LLVMBuildZExt(g->builder, op, get_llvm_type(g, extended_type), "");
    // 00aabbcc
    LLVMValueRef fn_val = get_int_builtin_fn(g, extended_type, BuiltinFnIdBswap);
    LLVMValueRef swapped = LLVMBuildCall(g->builder, fn_val, &extended, 1, "");
    // ccbbaa00
    LLVMValueRef shifted = ZigLLVMBuildLShrExact(g->builder, swapped,
            LLVMConstInt(get_llvm_type(g, extended_type), 8, false), "");
    // 00ccbbaa
    return LLVMBuildTrunc(g->builder, shifted, get_llvm_type(g, int_type), "");
}

static LLVMValueRef ir_render_bit_reverse(CodeGen *g, IrExecutable *executable, IrInstructionBitReverse *instruction) {
    LLVMValueRef op = ir_llvm_value(g, instruction->op);
    ZigType *int_type = instruction->base.value.type;
    assert(int_type->id == ZigTypeIdInt);
    LLVMValueRef fn_val = get_int_builtin_fn(g, instruction->base.value.type, BuiltinFnIdBitReverse);
    return LLVMBuildCall(g->builder, fn_val, &op, 1, "");
}

static LLVMValueRef ir_render_vector_to_array(CodeGen *g, IrExecutable *executable,
        IrInstructionVectorToArray *instruction)
{
    ZigType *array_type = instruction->base.value.type;
    assert(array_type->id == ZigTypeIdArray);
    assert(handle_is_ptr(array_type));
    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
    LLVMValueRef vector = ir_llvm_value(g, instruction->vector);
    LLVMValueRef casted_ptr = LLVMBuildBitCast(g->builder, result_loc,
            LLVMPointerType(get_llvm_type(g, instruction->vector->value.type), 0), "");
    gen_store_untyped(g, vector, casted_ptr, get_ptr_align(g, instruction->result_loc->value.type), false);
    return result_loc;
}

static LLVMValueRef ir_render_array_to_vector(CodeGen *g, IrExecutable *executable,
        IrInstructionArrayToVector *instruction)
{
    ZigType *vector_type = instruction->base.value.type;
    assert(vector_type->id == ZigTypeIdVector);
    assert(!handle_is_ptr(vector_type));
    LLVMValueRef array_ptr = ir_llvm_value(g, instruction->array);
    LLVMValueRef casted_ptr = LLVMBuildBitCast(g->builder, array_ptr,
            LLVMPointerType(get_llvm_type(g, vector_type), 0), "");
    return gen_load_untyped(g, casted_ptr, 0, false, "");
}

static LLVMValueRef ir_render_assert_zero(CodeGen *g, IrExecutable *executable,
        IrInstructionAssertZero *instruction)
{
    LLVMValueRef target = ir_llvm_value(g, instruction->target);
    ZigType *int_type = instruction->target->value.type;
    if (ir_want_runtime_safety(g, &instruction->base)) {
        return gen_assert_zero(g, target, int_type);
    }
    return nullptr;
}

static LLVMValueRef ir_render_assert_non_null(CodeGen *g, IrExecutable *executable,
        IrInstructionAssertNonNull *instruction)
{
    LLVMValueRef target = ir_llvm_value(g, instruction->target);
    ZigType *target_type = instruction->target->value.type;

    if (target_type->id == ZigTypeIdPointer) {
        assert(target_type->data.pointer.ptr_len == PtrLenC);
        LLVMValueRef non_null_bit = LLVMBuildICmp(g->builder, LLVMIntNE, target,
                LLVMConstNull(get_llvm_type(g, target_type)), "");

        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "AssertNonNullFail");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "AssertNonNullOk");
        LLVMBuildCondBr(g->builder, non_null_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_assertion(g, PanicMsgIdUnwrapOptionalFail, &instruction->base);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    } else {
        zig_unreachable();
    }
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
    switch (instruction->id) {
        case IrInstructionIdInvalid:
        case IrInstructionIdConst:
        case IrInstructionIdTypeOf:
        case IrInstructionIdFieldPtr:
        case IrInstructionIdSetCold:
        case IrInstructionIdSetRuntimeSafety:
        case IrInstructionIdSetFloatMode:
        case IrInstructionIdArrayType:
        case IrInstructionIdPromiseType:
        case IrInstructionIdSliceType:
        case IrInstructionIdSizeOf:
        case IrInstructionIdSwitchTarget:
        case IrInstructionIdContainerInitFields:
        case IrInstructionIdCompileErr:
        case IrInstructionIdCompileLog:
        case IrInstructionIdImport:
        case IrInstructionIdCImport:
        case IrInstructionIdCInclude:
        case IrInstructionIdCDefine:
        case IrInstructionIdCUndef:
        case IrInstructionIdEmbedFile:
        case IrInstructionIdIntType:
        case IrInstructionIdVectorType:
        case IrInstructionIdMemberCount:
        case IrInstructionIdMemberType:
        case IrInstructionIdMemberName:
        case IrInstructionIdAlignOf:
        case IrInstructionIdFnProto:
        case IrInstructionIdTestComptime:
        case IrInstructionIdCheckSwitchProngs:
        case IrInstructionIdCheckStatementIsVoid:
        case IrInstructionIdTypeName:
        case IrInstructionIdDeclRef:
        case IrInstructionIdSwitchVar:
        case IrInstructionIdSwitchElseVar:
        case IrInstructionIdByteOffsetOf:
        case IrInstructionIdBitOffsetOf:
        case IrInstructionIdTypeInfo:
        case IrInstructionIdHasField:
        case IrInstructionIdTypeId:
        case IrInstructionIdSetEvalBranchQuota:
        case IrInstructionIdPtrType:
        case IrInstructionIdOpaqueType:
        case IrInstructionIdSetAlignStack:
        case IrInstructionIdArgType:
        case IrInstructionIdTagType:
        case IrInstructionIdExport:
        case IrInstructionIdErrorUnion:
        case IrInstructionIdPromiseResultType:
        case IrInstructionIdAwaitBookkeeping:
        case IrInstructionIdAddImplicitReturnType:
        case IrInstructionIdIntCast:
        case IrInstructionIdFloatCast:
        case IrInstructionIdIntToFloat:
        case IrInstructionIdFloatToInt:
        case IrInstructionIdBoolToInt:
        case IrInstructionIdErrSetCast:
        case IrInstructionIdFromBytes:
        case IrInstructionIdToBytes:
        case IrInstructionIdEnumToInt:
        case IrInstructionIdCheckRuntimeScope:
        case IrInstructionIdDeclVarSrc:
        case IrInstructionIdPtrCastSrc:
        case IrInstructionIdCmpxchgSrc:
        case IrInstructionIdLoadPtr:
        case IrInstructionIdGlobalAsm:
        case IrInstructionIdHasDecl:
        case IrInstructionIdUndeclaredIdent:
        case IrInstructionIdCallSrc:
        case IrInstructionIdAllocaSrc:
        case IrInstructionIdEndExpr:
        case IrInstructionIdAllocaGen:
        case IrInstructionIdImplicitCast:
        case IrInstructionIdResolveResult:
        case IrInstructionIdResetResult:
        case IrInstructionIdResultPtr:
        case IrInstructionIdContainerInitList:
        case IrInstructionIdSliceSrc:
        case IrInstructionIdRef:
        case IrInstructionIdBitCastSrc:
        case IrInstructionIdTestErrSrc:
        case IrInstructionIdUnionInitNamedField:
            zig_unreachable();

        case IrInstructionIdDeclVarGen:
            return ir_render_decl_var(g, executable, (IrInstructionDeclVarGen *)instruction);
        case IrInstructionIdReturn:
            return ir_render_return(g, executable, (IrInstructionReturn *)instruction);
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
        case IrInstructionIdLoadPtrGen:
            return ir_render_load_ptr(g, executable, (IrInstructionLoadPtrGen *)instruction);
        case IrInstructionIdStorePtr:
            return ir_render_store_ptr(g, executable, (IrInstructionStorePtr *)instruction);
        case IrInstructionIdVarPtr:
            return ir_render_var_ptr(g, executable, (IrInstructionVarPtr *)instruction);
        case IrInstructionIdReturnPtr:
            return ir_render_return_ptr(g, executable, (IrInstructionReturnPtr *)instruction);
        case IrInstructionIdElemPtr:
            return ir_render_elem_ptr(g, executable, (IrInstructionElemPtr *)instruction);
        case IrInstructionIdCallGen:
            return ir_render_call(g, executable, (IrInstructionCallGen *)instruction);
        case IrInstructionIdStructFieldPtr:
            return ir_render_struct_field_ptr(g, executable, (IrInstructionStructFieldPtr *)instruction);
        case IrInstructionIdUnionFieldPtr:
            return ir_render_union_field_ptr(g, executable, (IrInstructionUnionFieldPtr *)instruction);
        case IrInstructionIdAsm:
            return ir_render_asm(g, executable, (IrInstructionAsm *)instruction);
        case IrInstructionIdTestNonNull:
            return ir_render_test_non_null(g, executable, (IrInstructionTestNonNull *)instruction);
        case IrInstructionIdOptionalUnwrapPtr:
            return ir_render_optional_unwrap_ptr(g, executable, (IrInstructionOptionalUnwrapPtr *)instruction);
        case IrInstructionIdClz:
            return ir_render_clz(g, executable, (IrInstructionClz *)instruction);
        case IrInstructionIdCtz:
            return ir_render_ctz(g, executable, (IrInstructionCtz *)instruction);
        case IrInstructionIdPopCount:
            return ir_render_pop_count(g, executable, (IrInstructionPopCount *)instruction);
        case IrInstructionIdSwitchBr:
            return ir_render_switch_br(g, executable, (IrInstructionSwitchBr *)instruction);
        case IrInstructionIdBswap:
            return ir_render_bswap(g, executable, (IrInstructionBswap *)instruction);
        case IrInstructionIdBitReverse:
            return ir_render_bit_reverse(g, executable, (IrInstructionBitReverse *)instruction);
        case IrInstructionIdPhi:
            return ir_render_phi(g, executable, (IrInstructionPhi *)instruction);
        case IrInstructionIdRefGen:
            return ir_render_ref(g, executable, (IrInstructionRefGen *)instruction);
        case IrInstructionIdErrName:
            return ir_render_err_name(g, executable, (IrInstructionErrName *)instruction);
        case IrInstructionIdCmpxchgGen:
            return ir_render_cmpxchg(g, executable, (IrInstructionCmpxchgGen *)instruction);
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
        case IrInstructionIdSliceGen:
            return ir_render_slice(g, executable, (IrInstructionSliceGen *)instruction);
        case IrInstructionIdBreakpoint:
            return ir_render_breakpoint(g, executable, (IrInstructionBreakpoint *)instruction);
        case IrInstructionIdReturnAddress:
            return ir_render_return_address(g, executable, (IrInstructionReturnAddress *)instruction);
        case IrInstructionIdFrameAddress:
            return ir_render_frame_address(g, executable, (IrInstructionFrameAddress *)instruction);
        case IrInstructionIdHandle:
            return ir_render_handle(g, executable, (IrInstructionHandle *)instruction);
        case IrInstructionIdOverflowOp:
            return ir_render_overflow_op(g, executable, (IrInstructionOverflowOp *)instruction);
        case IrInstructionIdTestErrGen:
            return ir_render_test_err(g, executable, (IrInstructionTestErrGen *)instruction);
        case IrInstructionIdUnwrapErrCode:
            return ir_render_unwrap_err_code(g, executable, (IrInstructionUnwrapErrCode *)instruction);
        case IrInstructionIdUnwrapErrPayload:
            return ir_render_unwrap_err_payload(g, executable, (IrInstructionUnwrapErrPayload *)instruction);
        case IrInstructionIdOptionalWrap:
            return ir_render_optional_wrap(g, executable, (IrInstructionOptionalWrap *)instruction);
        case IrInstructionIdErrWrapCode:
            return ir_render_err_wrap_code(g, executable, (IrInstructionErrWrapCode *)instruction);
        case IrInstructionIdErrWrapPayload:
            return ir_render_err_wrap_payload(g, executable, (IrInstructionErrWrapPayload *)instruction);
        case IrInstructionIdUnionTag:
            return ir_render_union_tag(g, executable, (IrInstructionUnionTag *)instruction);
        case IrInstructionIdPtrCastGen:
            return ir_render_ptr_cast(g, executable, (IrInstructionPtrCastGen *)instruction);
        case IrInstructionIdBitCastGen:
            return ir_render_bit_cast(g, executable, (IrInstructionBitCastGen *)instruction);
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
        case IrInstructionIdPanic:
            return ir_render_panic(g, executable, (IrInstructionPanic *)instruction);
        case IrInstructionIdTagName:
            return ir_render_enum_tag_name(g, executable, (IrInstructionTagName *)instruction);
        case IrInstructionIdFieldParentPtr:
            return ir_render_field_parent_ptr(g, executable, (IrInstructionFieldParentPtr *)instruction);
        case IrInstructionIdAlignCast:
            return ir_render_align_cast(g, executable, (IrInstructionAlignCast *)instruction);
        case IrInstructionIdErrorReturnTrace:
            return ir_render_error_return_trace(g, executable, (IrInstructionErrorReturnTrace *)instruction);
        case IrInstructionIdCancel:
            return ir_render_cancel(g, executable, (IrInstructionCancel *)instruction);
        case IrInstructionIdGetImplicitAllocator:
            return ir_render_get_implicit_allocator(g, executable, (IrInstructionGetImplicitAllocator *)instruction);
        case IrInstructionIdCoroId:
            return ir_render_coro_id(g, executable, (IrInstructionCoroId *)instruction);
        case IrInstructionIdCoroAlloc:
            return ir_render_coro_alloc(g, executable, (IrInstructionCoroAlloc *)instruction);
        case IrInstructionIdCoroSize:
            return ir_render_coro_size(g, executable, (IrInstructionCoroSize *)instruction);
        case IrInstructionIdCoroBegin:
            return ir_render_coro_begin(g, executable, (IrInstructionCoroBegin *)instruction);
        case IrInstructionIdCoroAllocFail:
            return ir_render_coro_alloc_fail(g, executable, (IrInstructionCoroAllocFail *)instruction);
        case IrInstructionIdCoroSuspend:
            return ir_render_coro_suspend(g, executable, (IrInstructionCoroSuspend *)instruction);
        case IrInstructionIdCoroEnd:
            return ir_render_coro_end(g, executable, (IrInstructionCoroEnd *)instruction);
        case IrInstructionIdCoroFree:
            return ir_render_coro_free(g, executable, (IrInstructionCoroFree *)instruction);
        case IrInstructionIdCoroResume:
            return ir_render_coro_resume(g, executable, (IrInstructionCoroResume *)instruction);
        case IrInstructionIdCoroSave:
            return ir_render_coro_save(g, executable, (IrInstructionCoroSave *)instruction);
        case IrInstructionIdCoroPromise:
            return ir_render_coro_promise(g, executable, (IrInstructionCoroPromise *)instruction);
        case IrInstructionIdCoroAllocHelper:
            return ir_render_coro_alloc_helper(g, executable, (IrInstructionCoroAllocHelper *)instruction);
        case IrInstructionIdAtomicRmw:
            return ir_render_atomic_rmw(g, executable, (IrInstructionAtomicRmw *)instruction);
        case IrInstructionIdAtomicLoad:
            return ir_render_atomic_load(g, executable, (IrInstructionAtomicLoad *)instruction);
        case IrInstructionIdSaveErrRetAddr:
            return ir_render_save_err_ret_addr(g, executable, (IrInstructionSaveErrRetAddr *)instruction);
        case IrInstructionIdMergeErrRetTraces:
            return ir_render_merge_err_ret_traces(g, executable, (IrInstructionMergeErrRetTraces *)instruction);
        case IrInstructionIdMarkErrRetTracePtr:
            return ir_render_mark_err_ret_trace_ptr(g, executable, (IrInstructionMarkErrRetTracePtr *)instruction);
        case IrInstructionIdFloatOp:
            return ir_render_float_op(g, executable, (IrInstructionFloatOp *)instruction);
        case IrInstructionIdMulAdd:
            return ir_render_mul_add(g, executable, (IrInstructionMulAdd *)instruction);
        case IrInstructionIdArrayToVector:
            return ir_render_array_to_vector(g, executable, (IrInstructionArrayToVector *)instruction);
        case IrInstructionIdVectorToArray:
            return ir_render_vector_to_array(g, executable, (IrInstructionVectorToArray *)instruction);
        case IrInstructionIdAssertZero:
            return ir_render_assert_zero(g, executable, (IrInstructionAssertZero *)instruction);
        case IrInstructionIdAssertNonNull:
            return ir_render_assert_non_null(g, executable, (IrInstructionAssertNonNull *)instruction);
        case IrInstructionIdResizeSlice:
            return ir_render_resize_slice(g, executable, (IrInstructionResizeSlice *)instruction);
        case IrInstructionIdPtrOfArrayToSlice:
            return ir_render_ptr_of_array_to_slice(g, executable, (IrInstructionPtrOfArrayToSlice *)instruction);
    }
    zig_unreachable();
}

static void ir_render(CodeGen *g, ZigFn *fn_entry) {
    assert(fn_entry);

    IrExecutable *executable = &fn_entry->analyzed_executable;
    assert(executable->basic_block_list.length > 0);
    for (size_t block_i = 0; block_i < executable->basic_block_list.length; block_i += 1) {
        IrBasicBlock *current_block = executable->basic_block_list.at(block_i);
        assert(current_block->llvm_block);
        LLVMPositionBuilderAtEnd(g->builder, current_block->llvm_block);
        for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
            IrInstruction *instruction = current_block->instruction_list.at(instr_i);
            if (instruction->ref_count == 0 && !ir_has_side_effects(instruction))
                continue;

            if (!g->strip_debug_symbols) {
                set_debug_location(g, instruction);
            }
            instruction->llvm_value = ir_render_instruction(g, executable, instruction);
        }
        current_block->llvm_exit_block = LLVMGetInsertBlock(g->builder);
    }
}

static LLVMValueRef gen_const_ptr_struct_recursive(CodeGen *g, ConstExprValue *struct_const_val, size_t field_index);
static LLVMValueRef gen_const_ptr_array_recursive(CodeGen *g, ConstExprValue *array_const_val, size_t index);
static LLVMValueRef gen_const_ptr_union_recursive(CodeGen *g, ConstExprValue *union_const_val);
static LLVMValueRef gen_const_ptr_err_union_code_recursive(CodeGen *g, ConstExprValue *err_union_const_val);
static LLVMValueRef gen_const_ptr_err_union_payload_recursive(CodeGen *g, ConstExprValue *err_union_const_val);
static LLVMValueRef gen_const_ptr_optional_payload_recursive(CodeGen *g, ConstExprValue *optional_const_val);

static LLVMValueRef gen_parent_ptr(CodeGen *g, ConstExprValue *val, ConstParent *parent) {
    switch (parent->id) {
        case ConstParentIdNone:
            render_const_val(g, val, "");
            render_const_val_global(g, val, "");
            return val->global_refs->llvm_global;
        case ConstParentIdStruct:
            return gen_const_ptr_struct_recursive(g, parent->data.p_struct.struct_val,
                    parent->data.p_struct.field_index);
        case ConstParentIdErrUnionCode:
            return gen_const_ptr_err_union_code_recursive(g, parent->data.p_err_union_code.err_union_val);
        case ConstParentIdErrUnionPayload:
            return gen_const_ptr_err_union_payload_recursive(g, parent->data.p_err_union_payload.err_union_val);
        case ConstParentIdOptionalPayload:
            return gen_const_ptr_optional_payload_recursive(g, parent->data.p_optional_payload.optional_val);
        case ConstParentIdArray:
            return gen_const_ptr_array_recursive(g, parent->data.p_array.array_val,
                    parent->data.p_array.elem_index);
        case ConstParentIdUnion:
            return gen_const_ptr_union_recursive(g, parent->data.p_union.union_val);
        case ConstParentIdScalar:
            render_const_val(g, parent->data.p_scalar.scalar_val, "");
            render_const_val_global(g, parent->data.p_scalar.scalar_val, "");
            return parent->data.p_scalar.scalar_val->global_refs->llvm_global;
    }
    zig_unreachable();
}

static LLVMValueRef gen_const_ptr_array_recursive(CodeGen *g, ConstExprValue *array_const_val, size_t index) {
    expand_undef_array(g, array_const_val);
    ConstParent *parent = &array_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, array_const_val, parent);

    LLVMTypeKind el_type = LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(base_ptr)));
    if (el_type == LLVMArrayTypeKind) {
        ZigType *usize = g->builtin_types.entry_usize;
        LLVMValueRef indices[] = {
            LLVMConstNull(usize->llvm_type),
            LLVMConstInt(usize->llvm_type, index, false),
        };
        return LLVMConstInBoundsGEP(base_ptr, indices, 2);
    } else if (el_type == LLVMStructTypeKind) {
        ZigType *u32 = g->builtin_types.entry_u32;
        LLVMValueRef indices[] = {
            LLVMConstNull(get_llvm_type(g, u32)),
            LLVMConstInt(get_llvm_type(g, u32), index, false),
        };
        return LLVMConstInBoundsGEP(base_ptr, indices, 2);
    } else {
        assert(parent->id == ConstParentIdScalar);
        return base_ptr;
    }
}

static LLVMValueRef gen_const_ptr_struct_recursive(CodeGen *g, ConstExprValue *struct_const_val, size_t field_index) {
    ConstParent *parent = &struct_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, struct_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), field_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_err_union_code_recursive(CodeGen *g, ConstExprValue *err_union_const_val) {
    ConstParent *parent = &err_union_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, err_union_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), err_union_err_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_err_union_payload_recursive(CodeGen *g, ConstExprValue *err_union_const_val) {
    ConstParent *parent = &err_union_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, err_union_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), err_union_payload_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_optional_payload_recursive(CodeGen *g, ConstExprValue *optional_const_val) {
    ConstParent *parent = &optional_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, optional_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), maybe_child_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_union_recursive(CodeGen *g, ConstExprValue *union_const_val) {
    ConstParent *parent = &union_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, union_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), 0, false), // TODO test const union with more aligned tag type than payload
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

    ZigType *type_entry = const_val->type;
    assert(type_has_bits(type_entry));
    switch (type_entry->id) {
        case ZigTypeIdInvalid:
        case ZigTypeIdMetaType:
        case ZigTypeIdUnreachable:
        case ZigTypeIdComptimeFloat:
        case ZigTypeIdComptimeInt:
        case ZigTypeIdEnumLiteral:
        case ZigTypeIdUndefined:
        case ZigTypeIdNull:
        case ZigTypeIdErrorUnion:
        case ZigTypeIdErrorSet:
        case ZigTypeIdBoundFn:
        case ZigTypeIdArgTuple:
        case ZigTypeIdVoid:
        case ZigTypeIdOpaque:
            zig_unreachable();
        case ZigTypeIdBool:
            return LLVMConstInt(big_int_type_ref, const_val->data.x_bool ? 1 : 0, false);
        case ZigTypeIdEnum:
            {
                assert(type_entry->data.enumeration.decl_node->data.container_decl.init_arg_expr != nullptr);
                LLVMValueRef int_val = gen_const_val(g, const_val, "");
                return LLVMConstZExt(int_val, big_int_type_ref);
            }
        case ZigTypeIdInt:
            {
                LLVMValueRef int_val = gen_const_val(g, const_val, "");
                return LLVMConstZExt(int_val, big_int_type_ref);
            }
        case ZigTypeIdFloat:
            {
                LLVMValueRef float_val = gen_const_val(g, const_val, "");
                LLVMValueRef int_val = LLVMConstFPToUI(float_val,
                        LLVMIntType((unsigned)type_entry->data.floating.bit_count));
                return LLVMConstZExt(int_val, big_int_type_ref);
            }
        case ZigTypeIdPointer:
        case ZigTypeIdFn:
        case ZigTypeIdOptional:
        case ZigTypeIdPromise:
            {
                LLVMValueRef ptr_val = gen_const_val(g, const_val, "");
                LLVMValueRef ptr_size_int_val = LLVMConstPtrToInt(ptr_val, g->builtin_types.entry_usize->llvm_type);
                return LLVMConstZExt(ptr_size_int_val, big_int_type_ref);
            }
        case ZigTypeIdArray: {
            LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
            if (const_val->data.x_array.special == ConstArraySpecialUndef) {
                return val;
            }
            expand_undef_array(g, const_val);
            bool is_big_endian = g->is_big_endian; // TODO get endianness from struct type
            uint32_t packed_bits_size = type_size_bits(g, type_entry->data.array.child_type);
            size_t used_bits = 0;
            for (size_t i = 0; i < type_entry->data.array.len; i += 1) {
                ConstExprValue *elem_val = &const_val->data.x_array.data.s_none.elements[i];
                LLVMValueRef child_val = pack_const_int(g, big_int_type_ref, elem_val);

                if (is_big_endian) {
                    LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref, packed_bits_size, false);
                    val = LLVMConstShl(val, shift_amt);
                    val = LLVMConstOr(val, child_val);
                } else {
                    LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref, used_bits, false);
                    LLVMValueRef child_val_shifted = LLVMConstShl(child_val, shift_amt);
                    val = LLVMConstOr(val, child_val_shifted);
                    used_bits += packed_bits_size;
                }
            }
            return val;
        }
        case ZigTypeIdVector:
            zig_panic("TODO bit pack a vector");
        case ZigTypeIdUnion:
            zig_panic("TODO bit pack a union");
        case ZigTypeIdStruct:
            {
                assert(type_entry->data.structure.layout == ContainerLayoutPacked);
                bool is_big_endian = g->is_big_endian; // TODO get endianness from struct type

                LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
                size_t used_bits = 0;
                for (size_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
                    TypeStructField *field = &type_entry->data.structure.fields[i];
                    if (field->gen_index == SIZE_MAX) {
                        continue;
                    }
                    LLVMValueRef child_val = pack_const_int(g, big_int_type_ref, &const_val->data.x_struct.fields[i]);
                    uint32_t packed_bits_size = type_size_bits(g, field->type_entry);
                    if (is_big_endian) {
                        LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref, packed_bits_size, false);
                        val = LLVMConstShl(val, shift_amt);
                        val = LLVMConstOr(val, child_val);
                    } else {
                        LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref, used_bits, false);
                        LLVMValueRef child_val_shifted = LLVMConstShl(child_val, shift_amt);
                        val = LLVMConstOr(val, child_val_shifted);
                        used_bits += packed_bits_size;
                    }
                }
                return val;
            }

    }
    zig_unreachable();
}

// We have this because union constants can't be represented by the official union type,
// and this property bubbles up in whatever aggregate type contains a union constant
static bool is_llvm_value_unnamed_type(CodeGen *g, ZigType *type_entry, LLVMValueRef val) {
    return LLVMTypeOf(val) != get_llvm_type(g, type_entry);
}

static LLVMValueRef gen_const_val_ptr(CodeGen *g, ConstExprValue *const_val, const char *name) {
    switch (const_val->data.x_ptr.special) {
        case ConstPtrSpecialInvalid:
        case ConstPtrSpecialDiscard:
            zig_unreachable();
        case ConstPtrSpecialRef:
            {
                assert(const_val->global_refs != nullptr);
                ConstExprValue *pointee = const_val->data.x_ptr.data.ref.pointee;
                render_const_val(g, pointee, "");
                render_const_val_global(g, pointee, "");
                const_val->global_refs->llvm_value = LLVMConstBitCast(pointee->global_refs->llvm_global,
                        get_llvm_type(g, const_val->type));
                return const_val->global_refs->llvm_value;
            }
        case ConstPtrSpecialBaseArray:
            {
                assert(const_val->global_refs != nullptr);
                ConstExprValue *array_const_val = const_val->data.x_ptr.data.base_array.array_val;
                assert(array_const_val->type->id == ZigTypeIdArray);
                if (!type_has_bits(array_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->global_refs->llvm_value;
                }
                size_t elem_index = const_val->data.x_ptr.data.base_array.elem_index;
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_array_recursive(g, array_const_val, elem_index);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->global_refs->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseStruct:
            {
                assert(const_val->global_refs != nullptr);
                ConstExprValue *struct_const_val = const_val->data.x_ptr.data.base_struct.struct_val;
                assert(struct_const_val->type->id == ZigTypeIdStruct);
                if (!type_has_bits(struct_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->global_refs->llvm_value;
                }
                size_t src_field_index = const_val->data.x_ptr.data.base_struct.field_index;
                size_t gen_field_index = struct_const_val->type->data.structure.fields[src_field_index].gen_index;
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_struct_recursive(g, struct_const_val,
                        gen_field_index);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->global_refs->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseErrorUnionCode:
            {
                assert(const_val->global_refs != nullptr);
                ConstExprValue *err_union_const_val = const_val->data.x_ptr.data.base_err_union_code.err_union_val;
                assert(err_union_const_val->type->id == ZigTypeIdErrorUnion);
                if (!type_has_bits(err_union_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->global_refs->llvm_value;
                }
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_err_union_code_recursive(g, err_union_const_val);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->global_refs->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseErrorUnionPayload:
            {
                assert(const_val->global_refs != nullptr);
                ConstExprValue *err_union_const_val = const_val->data.x_ptr.data.base_err_union_payload.err_union_val;
                assert(err_union_const_val->type->id == ZigTypeIdErrorUnion);
                if (!type_has_bits(err_union_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->global_refs->llvm_value;
                }
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_err_union_payload_recursive(g, err_union_const_val);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->global_refs->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseOptionalPayload:
            {
                assert(const_val->global_refs != nullptr);
                ConstExprValue *optional_const_val = const_val->data.x_ptr.data.base_optional_payload.optional_val;
                assert(optional_const_val->type->id == ZigTypeIdOptional);
                if (!type_has_bits(optional_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->global_refs->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->global_refs->llvm_value;
                }
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_optional_payload_recursive(g, optional_const_val);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->global_refs->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialHardCodedAddr:
            {
                assert(const_val->global_refs != nullptr);
                uint64_t addr_value = const_val->data.x_ptr.data.hard_coded_addr.addr;
                ZigType *usize = g->builtin_types.entry_usize;
                const_val->global_refs->llvm_value = LLVMConstIntToPtr(
                        LLVMConstInt(usize->llvm_type, addr_value, false), get_llvm_type(g, const_val->type));
                return const_val->global_refs->llvm_value;
            }
        case ConstPtrSpecialFunction:
            return LLVMConstBitCast(fn_llvm_value(g, const_val->data.x_ptr.data.fn.fn_entry),
                    get_llvm_type(g, const_val->type));
        case ConstPtrSpecialNull:
            return LLVMConstNull(get_llvm_type(g, const_val->type));
    }
    zig_unreachable();
}

static LLVMValueRef gen_const_val_err_set(CodeGen *g, ConstExprValue *const_val, const char *name) {
    uint64_t value = (const_val->data.x_err_set == nullptr) ? 0 : const_val->data.x_err_set->value;
    return LLVMConstInt(get_llvm_type(g, g->builtin_types.entry_global_error_set), value, false);
}

static LLVMValueRef gen_const_val(CodeGen *g, ConstExprValue *const_val, const char *name) {
    Error err;

    ZigType *type_entry = const_val->type;
    assert(type_has_bits(type_entry));

    switch (const_val->special) {
        case ConstValSpecialRuntime:
            zig_unreachable();
        case ConstValSpecialUndef:
            return LLVMGetUndef(get_llvm_type(g, type_entry));
        case ConstValSpecialStatic:
            break;
    }

    switch (type_entry->id) {
        case ZigTypeIdInt:
            return bigint_to_llvm_const(get_llvm_type(g, type_entry), &const_val->data.x_bigint);
        case ZigTypeIdErrorSet:
            return gen_const_val_err_set(g, const_val, name);
        case ZigTypeIdFloat:
            switch (type_entry->data.floating.bit_count) {
                case 16:
                    return LLVMConstReal(get_llvm_type(g, type_entry), zig_f16_to_double(const_val->data.x_f16));
                case 32:
                    return LLVMConstReal(get_llvm_type(g, type_entry), const_val->data.x_f32);
                case 64:
                    return LLVMConstReal(get_llvm_type(g, type_entry), const_val->data.x_f64);
                case 128:
                    {
                        // TODO make sure this is correct on big endian targets too
                        uint8_t buf[16];
                        memcpy(buf, &const_val->data.x_f128, 16);
                        LLVMValueRef as_int = LLVMConstIntOfArbitraryPrecision(LLVMInt128Type(), 2,
                                (uint64_t*)buf);
                        return LLVMConstBitCast(as_int, get_llvm_type(g, type_entry));
                    }
                default:
                    zig_unreachable();
            }
        case ZigTypeIdBool:
            if (const_val->data.x_bool) {
                return LLVMConstAllOnes(LLVMInt1Type());
            } else {
                return LLVMConstNull(LLVMInt1Type());
            }
        case ZigTypeIdOptional:
            {
                ZigType *child_type = type_entry->data.maybe.child_type;
                if (!type_has_bits(child_type)) {
                    return LLVMConstInt(LLVMInt1Type(), const_val->data.x_optional ? 1 : 0, false);
                } else if (get_codegen_ptr_type(type_entry) != nullptr) {
                    return gen_const_val_ptr(g, const_val, name);
                } else if (child_type->id == ZigTypeIdErrorSet) {
                    return gen_const_val_err_set(g, const_val, name);
                } else {
                    LLVMValueRef child_val;
                    LLVMValueRef maybe_val;
                    bool make_unnamed_struct;
                    if (const_val->data.x_optional) {
                        child_val = gen_const_val(g, const_val->data.x_optional, "");
                        maybe_val = LLVMConstAllOnes(LLVMInt1Type());

                        make_unnamed_struct = is_llvm_value_unnamed_type(g, const_val->type, child_val);
                    } else {
                        child_val = LLVMGetUndef(get_llvm_type(g, child_type));
                        maybe_val = LLVMConstNull(LLVMInt1Type());

                        make_unnamed_struct = false;
                    }
                    LLVMValueRef fields[] = {
                        child_val,
                        maybe_val,
                    };
                    if (make_unnamed_struct) {
                        return LLVMConstStruct(fields, 2, false);
                    } else {
                        return LLVMConstNamedStruct(get_llvm_type(g, type_entry), fields, 2);
                    }
                }
            }
        case ZigTypeIdStruct:
            {
                LLVMValueRef *fields = allocate<LLVMValueRef>(type_entry->data.structure.gen_field_count);
                size_t src_field_count = type_entry->data.structure.src_field_count;
                bool make_unnamed_struct = false;
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
                            ConstExprValue *field_val = &const_val->data.x_struct.fields[src_field_index];
                            LLVMValueRef val = gen_const_val(g, field_val, "");
                            fields[type_struct_field->gen_index] = val;
                            make_unnamed_struct = make_unnamed_struct || is_llvm_value_unnamed_type(g, field_val->type, val);
                        } else {
                            bool is_big_endian = g->is_big_endian; // TODO get endianness from struct type
                            LLVMTypeRef big_int_type_ref = LLVMStructGetTypeAtIndex(get_llvm_type(g, type_entry),
                                    (unsigned)type_struct_field->gen_index);
                            LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
                            size_t used_bits = 0;
                            for (size_t i = src_field_index; i < src_field_index_end; i += 1) {
                                TypeStructField *it_field = &type_entry->data.structure.fields[i];
                                if (it_field->gen_index == SIZE_MAX) {
                                    continue;
                                }
                                LLVMValueRef child_val = pack_const_int(g, big_int_type_ref,
                                        &const_val->data.x_struct.fields[i]);
                                uint32_t packed_bits_size = type_size_bits(g, it_field->type_entry);
                                if (is_big_endian) {
                                    LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref,
                                            packed_bits_size, false);
                                    val = LLVMConstShl(val, shift_amt);
                                    val = LLVMConstOr(val, child_val);
                                } else {
                                    LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref, used_bits, false);
                                    LLVMValueRef child_val_shifted = LLVMConstShl(child_val, shift_amt);
                                    val = LLVMConstOr(val, child_val_shifted);
                                    used_bits += packed_bits_size;
                                }
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
                        ConstExprValue *field_val = &const_val->data.x_struct.fields[i];
                        assert(field_val->type != nullptr);
                        if ((err = ensure_const_val_repr(nullptr, g, nullptr, field_val,
                                        type_struct_field->type_entry)))
                        {
                            zig_unreachable();
                        }

                        LLVMValueRef val = gen_const_val(g, field_val, "");
                        fields[type_struct_field->gen_index] = val;
                        make_unnamed_struct = make_unnamed_struct || is_llvm_value_unnamed_type(g, field_val->type, val);
                    }
                }
                if (make_unnamed_struct) {
                    return LLVMConstStruct(fields, type_entry->data.structure.gen_field_count,
                        type_entry->data.structure.layout == ContainerLayoutPacked);
                } else {
                    return LLVMConstNamedStruct(get_llvm_type(g, type_entry), fields, type_entry->data.structure.gen_field_count);
                }
            }
        case ZigTypeIdArray:
            {
                uint64_t len = type_entry->data.array.len;
                switch (const_val->data.x_array.special) {
                    case ConstArraySpecialUndef:
                        return LLVMGetUndef(get_llvm_type(g, type_entry));
                    case ConstArraySpecialNone: {
                        LLVMValueRef *values = allocate<LLVMValueRef>(len);
                        LLVMTypeRef element_type_ref = get_llvm_type(g, type_entry->data.array.child_type);
                        bool make_unnamed_struct = false;
                        for (uint64_t i = 0; i < len; i += 1) {
                            ConstExprValue *elem_value = &const_val->data.x_array.data.s_none.elements[i];
                            LLVMValueRef val = gen_const_val(g, elem_value, "");
                            values[i] = val;
                            make_unnamed_struct = make_unnamed_struct || is_llvm_value_unnamed_type(g, elem_value->type, val);
                        }
                        if (make_unnamed_struct) {
                            return LLVMConstStruct(values, len, true);
                        } else {
                            return LLVMConstArray(element_type_ref, values, (unsigned)len);
                        }
                    }
                    case ConstArraySpecialBuf: {
                        Buf *buf = const_val->data.x_array.data.s_buf;
                        return LLVMConstString(buf_ptr(buf), (unsigned)buf_len(buf), true);
                    }
                }
                zig_unreachable();
            }
        case ZigTypeIdVector: {
            uint32_t len = type_entry->data.vector.len;
            switch (const_val->data.x_array.special) {
                case ConstArraySpecialUndef:
                    return LLVMGetUndef(get_llvm_type(g, type_entry));
                case ConstArraySpecialNone: {
                    LLVMValueRef *values = allocate<LLVMValueRef>(len);
                    for (uint64_t i = 0; i < len; i += 1) {
                        ConstExprValue *elem_value = &const_val->data.x_array.data.s_none.elements[i];
                        values[i] = gen_const_val(g, elem_value, "");
                    }
                    return LLVMConstVector(values, len);
                }
                case ConstArraySpecialBuf: {
                    Buf *buf = const_val->data.x_array.data.s_buf;
                    assert(buf_len(buf) == len);
                    LLVMValueRef *values = allocate<LLVMValueRef>(len);
                    for (uint64_t i = 0; i < len; i += 1) {
                        values[i] = LLVMConstInt(g->builtin_types.entry_u8->llvm_type, buf_ptr(buf)[i], false);
                    }
                    return LLVMConstVector(values, len);
                }
            }
            zig_unreachable();
        }
        case ZigTypeIdUnion:
            {
                // Force type_entry->data.unionation.union_llvm_type to get resolved
                (void)get_llvm_type(g, type_entry);

                if (type_entry->data.unionation.gen_field_count == 0) {
                    if (type_entry->data.unionation.tag_type == nullptr) {
                        return nullptr;
                    } else {
                        return bigint_to_llvm_const(get_llvm_type(g, type_entry->data.unionation.tag_type),
                            &const_val->data.x_union.tag);
                    }
                }

                LLVMTypeRef union_type_ref = type_entry->data.unionation.union_llvm_type;
                assert(union_type_ref != nullptr);

                LLVMValueRef union_value_ref;
                bool make_unnamed_struct;
                ConstExprValue *payload_value = const_val->data.x_union.payload;
                if (payload_value == nullptr || !type_has_bits(payload_value->type)) {
                    if (type_entry->data.unionation.gen_tag_index == SIZE_MAX)
                        return LLVMGetUndef(get_llvm_type(g, type_entry));

                    union_value_ref = LLVMGetUndef(union_type_ref);
                    make_unnamed_struct = false;
                } else {
                    uint64_t field_type_bytes = LLVMStoreSizeOfType(g->target_data_ref,
                            get_llvm_type(g, payload_value->type));
                    uint64_t pad_bytes = type_entry->data.unionation.union_abi_size - field_type_bytes;
                    LLVMValueRef correctly_typed_value = gen_const_val(g, payload_value, "");
                    make_unnamed_struct = is_llvm_value_unnamed_type(g, payload_value->type, correctly_typed_value) ||
                        payload_value->type != type_entry->data.unionation.most_aligned_union_member;

                    {
                        if (pad_bytes == 0) {
                            union_value_ref = correctly_typed_value;
                        } else {
                            LLVMValueRef fields[2];
                            fields[0] = correctly_typed_value;
                            fields[1] = LLVMGetUndef(LLVMArrayType(LLVMInt8Type(), (unsigned)pad_bytes));
                            if (make_unnamed_struct || type_entry->data.unionation.gen_tag_index != SIZE_MAX) {
                                union_value_ref = LLVMConstStruct(fields, 2, false);
                            } else {
                                union_value_ref = LLVMConstNamedStruct(union_type_ref, fields, 2);
                            }
                        }
                    }

                    if (type_entry->data.unionation.gen_tag_index == SIZE_MAX) {
                        return union_value_ref;
                    }
                }

                LLVMValueRef tag_value = bigint_to_llvm_const(
                        get_llvm_type(g, type_entry->data.unionation.tag_type),
                        &const_val->data.x_union.tag);

                LLVMValueRef fields[3];
                fields[type_entry->data.unionation.gen_union_index] = union_value_ref;
                fields[type_entry->data.unionation.gen_tag_index] = tag_value;

                if (make_unnamed_struct) {
                    LLVMValueRef result = LLVMConstStruct(fields, 2, false);
                    uint64_t last_field_offset = LLVMOffsetOfElement(g->target_data_ref, LLVMTypeOf(result), 1);
                    uint64_t end_offset = last_field_offset +
                        LLVMStoreSizeOfType(g->target_data_ref, LLVMTypeOf(fields[1]));
                    uint64_t expected_sz = LLVMStoreSizeOfType(g->target_data_ref, get_llvm_type(g, type_entry));
                    unsigned pad_sz = expected_sz - end_offset;
                    if (pad_sz != 0) {
                        fields[2] = LLVMGetUndef(LLVMArrayType(LLVMInt8Type(), pad_sz));
                        result = LLVMConstStruct(fields, 3, false);
                    }
                    uint64_t actual_sz = LLVMStoreSizeOfType(g->target_data_ref, LLVMTypeOf(result));
                    assert(actual_sz == expected_sz);
                    return result;
                } else {
                    return LLVMConstNamedStruct(get_llvm_type(g, type_entry), fields, 2);
                }

            }

        case ZigTypeIdEnum:
            return bigint_to_llvm_const(get_llvm_type(g, type_entry), &const_val->data.x_enum_tag);
        case ZigTypeIdFn:
            if (const_val->data.x_ptr.special == ConstPtrSpecialFunction) {
                assert(const_val->data.x_ptr.mut == ConstPtrMutComptimeConst);
                return fn_llvm_value(g, const_val->data.x_ptr.data.fn.fn_entry);
            } else if (const_val->data.x_ptr.special == ConstPtrSpecialHardCodedAddr) {
                LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
                uint64_t addr = const_val->data.x_ptr.data.hard_coded_addr.addr;
                return LLVMConstIntToPtr(LLVMConstInt(usize_type_ref, addr, false), get_llvm_type(g, type_entry));
            } else {
                zig_unreachable();
            }
        case ZigTypeIdPointer:
            return gen_const_val_ptr(g, const_val, name);
        case ZigTypeIdErrorUnion:
            {
                ZigType *payload_type = type_entry->data.error_union.payload_type;
                ZigType *err_set_type = type_entry->data.error_union.err_set_type;
                if (!type_has_bits(payload_type)) {
                    assert(type_has_bits(err_set_type));
                    ErrorTableEntry *err_set = const_val->data.x_err_union.error_set->data.x_err_set;
                    uint64_t value = (err_set == nullptr) ? 0 : err_set->value;
                    return LLVMConstInt(get_llvm_type(g, g->err_tag_type), value, false);
                } else if (!type_has_bits(err_set_type)) {
                    assert(type_has_bits(payload_type));
                    return gen_const_val(g, const_val->data.x_err_union.payload, "");
                } else {
                    LLVMValueRef err_tag_value;
                    LLVMValueRef err_payload_value;
                    bool make_unnamed_struct;
                    ErrorTableEntry *err_set = const_val->data.x_err_union.error_set->data.x_err_set;
                    if (err_set != nullptr) {
                        err_tag_value = LLVMConstInt(get_llvm_type(g, g->err_tag_type), err_set->value, false);
                        err_payload_value = LLVMConstNull(get_llvm_type(g, payload_type));
                        make_unnamed_struct = false;
                    } else {
                        err_tag_value = LLVMConstNull(get_llvm_type(g, g->err_tag_type));
                        ConstExprValue *payload_val = const_val->data.x_err_union.payload;
                        err_payload_value = gen_const_val(g, payload_val, "");
                        make_unnamed_struct = is_llvm_value_unnamed_type(g, payload_val->type, err_payload_value);
                    }
                    if (make_unnamed_struct) {
                        uint64_t payload_off = LLVMOffsetOfElement(g->target_data_ref, get_llvm_type(g, type_entry), 1);
                        uint64_t err_sz = LLVMStoreSizeOfType(g->target_data_ref, LLVMTypeOf(err_tag_value));
                        unsigned pad_sz = payload_off - err_sz;
                        if (pad_sz == 0) {
                            LLVMValueRef fields[] = {
                                err_tag_value,
                                err_payload_value,
                            };
                            return LLVMConstStruct(fields, 2, false);
                        } else {
                            LLVMValueRef fields[] = {
                                err_tag_value,
                                LLVMGetUndef(LLVMArrayType(LLVMInt8Type(), pad_sz)),
                                err_payload_value,
                            };
                            return LLVMConstStruct(fields, 3, false);
                        }
                    } else {
                        LLVMValueRef fields[] = {
                            err_tag_value,
                            err_payload_value,
                        };
                        return LLVMConstNamedStruct(get_llvm_type(g, type_entry), fields, 2);
                    }
                }
            }
        case ZigTypeIdVoid:
            return nullptr;
        case ZigTypeIdInvalid:
        case ZigTypeIdMetaType:
        case ZigTypeIdUnreachable:
        case ZigTypeIdComptimeFloat:
        case ZigTypeIdComptimeInt:
        case ZigTypeIdEnumLiteral:
        case ZigTypeIdUndefined:
        case ZigTypeIdNull:
        case ZigTypeIdBoundFn:
        case ZigTypeIdArgTuple:
        case ZigTypeIdOpaque:
        case ZigTypeIdPromise:
            zig_unreachable();

    }
    zig_unreachable();
}

static void render_const_val(CodeGen *g, ConstExprValue *const_val, const char *name) {
    if (!const_val->global_refs)
        const_val->global_refs = allocate<ConstGlobalRefs>(1);
    if (!const_val->global_refs->llvm_value)
        const_val->global_refs->llvm_value = gen_const_val(g, const_val, name);

    if (const_val->global_refs->llvm_global)
        LLVMSetInitializer(const_val->global_refs->llvm_global, const_val->global_refs->llvm_value);
}

static void render_const_val_global(CodeGen *g, ConstExprValue *const_val, const char *name) {
    if (!const_val->global_refs)
        const_val->global_refs = allocate<ConstGlobalRefs>(1);

    if (!const_val->global_refs->llvm_global) {
        LLVMTypeRef type_ref = const_val->global_refs->llvm_value ?
            LLVMTypeOf(const_val->global_refs->llvm_value) : get_llvm_type(g, const_val->type);
        LLVMValueRef global_value = LLVMAddGlobal(g->module, type_ref, name);
        LLVMSetLinkage(global_value, LLVMInternalLinkage);
        LLVMSetGlobalConstant(global_value, true);
        LLVMSetUnnamedAddr(global_value, true);
        LLVMSetAlignment(global_value, (const_val->global_refs->align == 0) ?
                get_abi_alignment(g, const_val->type) : const_val->global_refs->align);

        const_val->global_refs->llvm_global = global_value;
    }

    if (const_val->global_refs->llvm_value)
        LLVMSetInitializer(const_val->global_refs->llvm_global, const_val->global_refs->llvm_value);
}

static void generate_error_name_table(CodeGen *g) {
    if (g->err_name_table != nullptr || !g->generate_error_name_table || g->errors_by_index.length == 1) {
        return;
    }

    assert(g->errors_by_index.length > 0);

    ZigType *u8_ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0, false);
    ZigType *str_type = get_slice_type(g, u8_ptr_type);

    LLVMValueRef *values = allocate<LLVMValueRef>(g->errors_by_index.length);
    values[0] = LLVMGetUndef(get_llvm_type(g, str_type));
    for (size_t i = 1; i < g->errors_by_index.length; i += 1) {
        ErrorTableEntry *err_entry = g->errors_by_index.at(i);
        Buf *name = &err_entry->name;

        g->largest_err_name_len = max(g->largest_err_name_len, buf_len(name));

        LLVMValueRef str_init = LLVMConstString(buf_ptr(name), (unsigned)buf_len(name), true);
        LLVMValueRef str_global = LLVMAddGlobal(g->module, LLVMTypeOf(str_init), "");
        LLVMSetInitializer(str_global, str_init);
        LLVMSetLinkage(str_global, LLVMPrivateLinkage);
        LLVMSetGlobalConstant(str_global, true);
        LLVMSetUnnamedAddr(str_global, true);
        LLVMSetAlignment(str_global, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(str_init)));

        LLVMValueRef fields[] = {
            LLVMConstBitCast(str_global, get_llvm_type(g, u8_ptr_type)),
            LLVMConstInt(g->builtin_types.entry_usize->llvm_type, buf_len(name), false),
        };
        values[i] = LLVMConstNamedStruct(get_llvm_type(g, str_type), fields, 2);
    }

    LLVMValueRef err_name_table_init = LLVMConstArray(get_llvm_type(g, str_type), values, (unsigned)g->errors_by_index.length);

    g->err_name_table = LLVMAddGlobal(g->module, LLVMTypeOf(err_name_table_init),
            buf_ptr(get_mangled_name(g, buf_create_from_str("__zig_err_name_table"), false)));
    LLVMSetInitializer(g->err_name_table, err_name_table_init);
    LLVMSetLinkage(g->err_name_table, LLVMPrivateLinkage);
    LLVMSetGlobalConstant(g->err_name_table, true);
    LLVMSetUnnamedAddr(g->err_name_table, true);
    LLVMSetAlignment(g->err_name_table, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(err_name_table_init)));
}

static void build_all_basic_blocks(CodeGen *g, ZigFn *fn) {
    IrExecutable *executable = &fn->analyzed_executable;
    assert(executable->basic_block_list.length > 0);
    for (size_t block_i = 0; block_i < executable->basic_block_list.length; block_i += 1) {
        IrBasicBlock *bb = executable->basic_block_list.at(block_i);
        bb->llvm_block = LLVMAppendBasicBlock(fn_llvm_value(g, fn), bb->name_hint);
    }
    IrBasicBlock *entry_bb = executable->basic_block_list.at(0);
    LLVMPositionBuilderAtEnd(g->builder, entry_bb->llvm_block);
}

static void gen_global_var(CodeGen *g, ZigVar *var, LLVMValueRef init_val,
    ZigType *type_entry)
{
    if (g->strip_debug_symbols) {
        return;
    }

    assert(var->gen_is_const);
    assert(type_entry);

    ZigType *import = get_scope_import(var->parent_scope);
    assert(import);

    bool is_local_to_unit = true;
    ZigLLVMCreateGlobalVariable(g->dbuilder, get_di_scope(g, var->parent_scope), buf_ptr(&var->name),
        buf_ptr(&var->name), import->data.structure.root_struct->di_file,
        (unsigned)(var->decl_node->line + 1),
        get_llvm_di_type(g, type_entry), is_local_to_unit);

    // TODO ^^ make an actual global variable
}

static void validate_inline_fns(CodeGen *g) {
    for (size_t i = 0; i < g->inline_fns.length; i += 1) {
        ZigFn *fn_entry = g->inline_fns.at(i);
        LLVMValueRef fn_val = LLVMGetNamedFunction(g->module, fn_entry->llvm_name);
        if (fn_val != nullptr) {
            add_node_error(g, fn_entry->proto_node, buf_sprintf("unable to inline function"));
        }
    }
    report_errors_and_maybe_exit(g);
}

static void set_global_tls(CodeGen *g, ZigVar *var, LLVMValueRef global_value) {
    bool is_extern = var->decl_node->data.variable_declaration.is_extern;
    bool is_export = var->decl_node->data.variable_declaration.is_export;
    bool is_internal_linkage = !is_extern && !is_export;
    if (var->is_thread_local && (!g->is_single_threaded || !is_internal_linkage)) {
        LLVMSetThreadLocalMode(global_value, LLVMGeneralDynamicTLSModel);
    }
}

static void do_code_gen(CodeGen *g) {
    assert(!g->errors.length);

    generate_error_name_table(g);

    // Generate module level variables
    for (size_t i = 0; i < g->global_vars.length; i += 1) {
        TldVar *tld_var = g->global_vars.at(i);
        ZigVar *var = tld_var->var;

        if (var->var_type->id == ZigTypeIdComptimeFloat) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = var->const_value;
            assert(const_val->special != ConstValSpecialRuntime);
            if (const_val->type != var->var_type) {
                zig_panic("TODO debug info for var with ptr casted value");
            }
            ZigType *var_type = g->builtin_types.entry_f128;
            ConstExprValue coerced_value = {};
            coerced_value.special = ConstValSpecialStatic;
            coerced_value.type = var_type;
            coerced_value.data.x_f128 = bigfloat_to_f128(&const_val->data.x_bigfloat);
            LLVMValueRef init_val = gen_const_val(g, &coerced_value, "");
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (var->var_type->id == ZigTypeIdComptimeInt) {
            // Generate debug info for it but that's it.
            ConstExprValue *const_val = var->const_value;
            assert(const_val->special != ConstValSpecialRuntime);
            if (const_val->type != var->var_type) {
                zig_panic("TODO debug info for var with ptr casted value");
            }
            size_t bits_needed = bigint_bits_needed(&const_val->data.x_bigint);
            if (bits_needed < 8) {
                bits_needed = 8;
            }
            ZigType *var_type = get_int_type(g, const_val->data.x_bigint.is_negative, bits_needed);
            LLVMValueRef init_val = bigint_to_llvm_const(get_llvm_type(g, var_type), &const_val->data.x_bigint);
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (!type_has_bits(var->var_type))
            continue;

        assert(var->decl_node);

        GlobalLinkageId linkage;
        Buf *unmangled_name = &var->name;
        Buf *symbol_name;
        if (var->export_list.length == 0) {
            if (var->decl_node->data.variable_declaration.is_extern) {
                symbol_name = unmangled_name;
                linkage = GlobalLinkageIdStrong;
            } else {
                symbol_name = get_mangled_name(g, unmangled_name, false);
                linkage = GlobalLinkageIdInternal;
            }
        } else {
            GlobalExport *global_export = &var->export_list.items[0];
            symbol_name = &global_export->name;
            linkage = global_export->linkage;
        }

        LLVMValueRef global_value;
        bool externally_initialized = var->decl_node->data.variable_declaration.expr == nullptr;
        if (externally_initialized) {
            LLVMValueRef existing_llvm_var = LLVMGetNamedGlobal(g->module, buf_ptr(symbol_name));
            if (existing_llvm_var) {
                global_value = LLVMConstBitCast(existing_llvm_var,
                        LLVMPointerType(get_llvm_type(g, var->var_type), 0));
            } else {
                global_value = LLVMAddGlobal(g->module, get_llvm_type(g, var->var_type), buf_ptr(symbol_name));
                // TODO debug info for the extern variable

                LLVMSetLinkage(global_value, to_llvm_linkage(linkage));
                maybe_import_dll(g, global_value, GlobalLinkageIdStrong);
                LLVMSetAlignment(global_value, var->align_bytes);
                LLVMSetGlobalConstant(global_value, var->gen_is_const);
                set_global_tls(g, var, global_value);
            }
        } else {
            bool exported = (linkage != GlobalLinkageIdInternal);
            render_const_val(g, var->const_value, buf_ptr(symbol_name));
            render_const_val_global(g, var->const_value, buf_ptr(symbol_name));
            global_value = var->const_value->global_refs->llvm_global;

            if (exported) {
                LLVMSetLinkage(global_value, to_llvm_linkage(linkage));
                maybe_export_dll(g, global_value, GlobalLinkageIdStrong);
            }
            if (tld_var->section_name) {
                LLVMSetSection(global_value, buf_ptr(tld_var->section_name));
            }
            LLVMSetAlignment(global_value, var->align_bytes);

            // TODO debug info for function pointers
            // Here we use const_value->type because that's the type of the llvm global,
            // which we const ptr cast upon use to whatever it needs to be.
            if (var->gen_is_const && var->const_value->type->id != ZigTypeIdFn) {
                gen_global_var(g, var, var->const_value->global_refs->llvm_value, var->const_value->type);
            }

            LLVMSetGlobalConstant(global_value, var->gen_is_const);
            set_global_tls(g, var, global_value);
        }

        var->value_ref = global_value;

        for (size_t export_i = 1; export_i < var->export_list.length; export_i += 1) {
            GlobalExport *global_export = &var->export_list.items[export_i];
            LLVMAddAlias(g->module, LLVMTypeOf(var->value_ref), var->value_ref, buf_ptr(&global_export->name));
        }
    }

    // Generate function definitions.
    for (size_t fn_i = 0; fn_i < g->fn_defs.length; fn_i += 1) {
        ZigFn *fn_table_entry = g->fn_defs.at(fn_i);
        FnTypeId *fn_type_id = &fn_table_entry->type_entry->data.fn.fn_type_id;
        CallingConvention cc = fn_type_id->cc;
        bool is_c_abi = cc == CallingConventionC;
        bool want_sret = want_first_arg_sret(g, fn_type_id);

        LLVMValueRef fn = fn_llvm_value(g, fn_table_entry);
        g->cur_fn = fn_table_entry;
        g->cur_fn_val = fn;

        build_all_basic_blocks(g, fn_table_entry);
        clear_debug_source_node(g);

        if (want_sret) {
            g->cur_ret_ptr = LLVMGetParam(fn, 0);
        } else if (handle_is_ptr(fn_type_id->return_type)) {
            g->cur_ret_ptr = build_alloca(g, fn_type_id->return_type, "result", 0);
            // TODO add debug info variable for this
        } else {
            g->cur_ret_ptr = nullptr;
        }

        uint32_t err_ret_trace_arg_index = get_err_ret_trace_arg_index(g, fn_table_entry);
        bool have_err_ret_trace_arg = err_ret_trace_arg_index != UINT32_MAX;
        if (have_err_ret_trace_arg) {
            g->cur_err_ret_trace_val_arg = LLVMGetParam(fn, err_ret_trace_arg_index);
        } else {
            g->cur_err_ret_trace_val_arg = nullptr;
        }

        // error return tracing setup
        bool is_async = cc == CallingConventionAsync;
        bool have_err_ret_trace_stack = g->have_err_ret_tracing && fn_table_entry->calls_or_awaits_errorable_fn && !is_async && !have_err_ret_trace_arg;
        LLVMValueRef err_ret_array_val = nullptr;
        if (have_err_ret_trace_stack) {
            ZigType *array_type = get_array_type(g, g->builtin_types.entry_usize, stack_trace_ptr_count);
            err_ret_array_val = build_alloca(g, array_type, "error_return_trace_addresses", get_abi_alignment(g, array_type));

            // populate g->stack_trace_type
            (void)get_ptr_to_stack_trace_type(g);
            g->cur_err_ret_trace_val_stack = build_alloca(g, g->stack_trace_type, "error_return_trace", get_abi_alignment(g, g->stack_trace_type));
        } else {
            g->cur_err_ret_trace_val_stack = nullptr;
        }

        // allocate temporary stack data
        for (size_t alloca_i = 0; alloca_i < fn_table_entry->alloca_gen_list.length; alloca_i += 1) {
            IrInstructionAllocaGen *instruction = fn_table_entry->alloca_gen_list.at(alloca_i);
            ZigType *ptr_type = instruction->base.value.type;
            assert(ptr_type->id == ZigTypeIdPointer);
            ZigType *child_type = ptr_type->data.pointer.child_type;
            if (!type_has_bits(child_type))
                continue;
            if (instruction->base.ref_count == 0)
                continue;
            if (instruction->base.value.special != ConstValSpecialRuntime) {
                if (const_ptr_pointee(nullptr, g, &instruction->base.value, nullptr)->special !=
                        ConstValSpecialRuntime)
                {
                    continue;
                }
            }
            instruction->base.llvm_value = build_alloca(g, child_type, instruction->name_hint,
                    get_ptr_align(g, ptr_type));
        }

        ZigType *import = get_scope_import(&fn_table_entry->fndef_scope->base);
        unsigned gen_i_init = want_sret ? 1 : 0;

        // create debug variable declarations for variables and allocate all local variables
        FnWalk fn_walk_var = {};
        fn_walk_var.id = FnWalkIdVars;
        fn_walk_var.data.vars.import = import;
        fn_walk_var.data.vars.fn = fn_table_entry;
        fn_walk_var.data.vars.llvm_fn = fn;
        fn_walk_var.data.vars.gen_i = gen_i_init;
        for (size_t var_i = 0; var_i < fn_table_entry->variable_list.length; var_i += 1) {
            ZigVar *var = fn_table_entry->variable_list.at(var_i);

            if (!type_has_bits(var->var_type)) {
                continue;
            }
            if (ir_get_var_is_comptime(var))
                continue;
            switch (type_requires_comptime(g, var->var_type)) {
                case ReqCompTimeInvalid:
                    zig_unreachable();
                case ReqCompTimeYes:
                    continue;
                case ReqCompTimeNo:
                    break;
            }

            if (var->src_arg_index == SIZE_MAX) {
                var->di_loc_var = ZigLLVMCreateAutoVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                        buf_ptr(&var->name), import->data.structure.root_struct->di_file, (unsigned)(var->decl_node->line + 1),
                        get_llvm_di_type(g, var->var_type), !g->strip_debug_symbols, 0);

            } else if (is_c_abi) {
                fn_walk_var.data.vars.var = var;
                iter_function_params_c_abi(g, fn_table_entry->type_entry, &fn_walk_var, var->src_arg_index);
            } else {
                ZigType *gen_type;
                FnGenParamInfo *gen_info = &fn_table_entry->type_entry->data.fn.gen_param_info[var->src_arg_index];
                assert(gen_info->gen_index != SIZE_MAX);

                if (handle_is_ptr(var->var_type)) {
                    if (gen_info->is_byval) {
                        gen_type = var->var_type;
                    } else {
                        gen_type = gen_info->type;
                    }
                    var->value_ref = LLVMGetParam(fn, gen_info->gen_index);
                } else {
                    gen_type = var->var_type;
                    var->value_ref = build_alloca(g, var->var_type, buf_ptr(&var->name), var->align_bytes);
                }
                if (var->decl_node) {
                    var->di_loc_var = ZigLLVMCreateParameterVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                        buf_ptr(&var->name), import->data.structure.root_struct->di_file,
                        (unsigned)(var->decl_node->line + 1),
                        get_llvm_di_type(g, gen_type), !g->strip_debug_symbols, 0, (unsigned)(gen_info->gen_index+1));
                }

            }
        }

        // finishing error return trace setup. we have to do this after all the allocas.
        if (have_err_ret_trace_stack) {
            ZigType *usize = g->builtin_types.entry_usize;
            size_t index_field_index = g->stack_trace_type->data.structure.fields[0].gen_index;
            LLVMValueRef index_field_ptr = LLVMBuildStructGEP(g->builder, g->cur_err_ret_trace_val_stack, (unsigned)index_field_index, "");
            gen_store_untyped(g, LLVMConstNull(usize->llvm_type), index_field_ptr, 0, false);

            size_t addresses_field_index = g->stack_trace_type->data.structure.fields[1].gen_index;
            LLVMValueRef addresses_field_ptr = LLVMBuildStructGEP(g->builder, g->cur_err_ret_trace_val_stack, (unsigned)addresses_field_index, "");

            ZigType *slice_type = g->stack_trace_type->data.structure.fields[1].type_entry;
            size_t ptr_field_index = slice_type->data.structure.fields[slice_ptr_index].gen_index;
            LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, addresses_field_ptr, (unsigned)ptr_field_index, "");
            LLVMValueRef zero = LLVMConstNull(usize->llvm_type);
            LLVMValueRef indices[] = {zero, zero};
            LLVMValueRef err_ret_array_val_elem0_ptr = LLVMBuildInBoundsGEP(g->builder, err_ret_array_val,
                    indices, 2, "");
            ZigType *ptr_ptr_usize_type = get_pointer_to_type(g, get_pointer_to_type(g, usize, false), false);
            gen_store(g, err_ret_array_val_elem0_ptr, ptr_field_ptr, ptr_ptr_usize_type);

            size_t len_field_index = slice_type->data.structure.fields[slice_len_index].gen_index;
            LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, addresses_field_ptr, (unsigned)len_field_index, "");
            gen_store(g, LLVMConstInt(usize->llvm_type, stack_trace_ptr_count, false), len_field_ptr, get_pointer_to_type(g, usize, false));
        }

        // create debug variable declarations for parameters
        // rely on the first variables in the variable_list being parameters.
        FnWalk fn_walk_init = {};
        fn_walk_init.id = FnWalkIdInits;
        fn_walk_init.data.inits.fn = fn_table_entry;
        fn_walk_init.data.inits.llvm_fn = fn;
        fn_walk_init.data.inits.gen_i = gen_i_init;
        walk_function_params(g, fn_table_entry->type_entry, &fn_walk_init);

        ir_render(g, fn_table_entry);

    }

    assert(!g->errors.length);

    if (buf_len(&g->global_asm) != 0) {
        LLVMSetModuleInlineAsm(g->module, buf_ptr(&g->global_asm));
    }

    ZigLLVMDIBuilderFinalize(g->dbuilder);

    if (g->verbose_llvm_ir) {
        fflush(stderr);
        LLVMDumpModule(g->module);
    }

    // in release mode, we're sooooo confident that we've generated correct ir,
    // that we skip the verify module step in order to get better performance.
#ifndef NDEBUG
    char *error = nullptr;
    LLVMVerifyModule(g->module, LLVMAbortProcessAction, &error);
#endif
}

static void zig_llvm_emit_output(CodeGen *g) {
    bool is_small = g->build_mode == BuildModeSmallRelease;

    Buf *output_path = &g->o_file_output_path;
    char *err_msg = nullptr;
    switch (g->emit_file_type) {
        case EmitFileTypeBinary:
            if (ZigLLVMTargetMachineEmitToFile(g->target_machine, g->module, buf_ptr(output_path),
                        ZigLLVM_EmitBinary, &err_msg, g->build_mode == BuildModeDebug, is_small,
                        g->enable_time_report))
            {
                zig_panic("unable to write object file %s: %s", buf_ptr(output_path), err_msg);
            }
            validate_inline_fns(g);
            g->link_objects.append(output_path);
            if (g->bundle_compiler_rt && (g->out_type == OutTypeObj ||
                (g->out_type == OutTypeLib && !g->is_dynamic)))
            {
                zig_link_add_compiler_rt(g);
            }
            break;

        case EmitFileTypeAssembly:
            if (ZigLLVMTargetMachineEmitToFile(g->target_machine, g->module, buf_ptr(output_path),
                        ZigLLVM_EmitAssembly, &err_msg, g->build_mode == BuildModeDebug, is_small,
                        g->enable_time_report))
            {
                zig_panic("unable to write assembly file %s: %s", buf_ptr(output_path), err_msg);
            }
            validate_inline_fns(g);
            break;

        case EmitFileTypeLLVMIr:
            if (ZigLLVMTargetMachineEmitToFile(g->target_machine, g->module, buf_ptr(output_path),
                        ZigLLVM_EmitLLVMIr, &err_msg, g->build_mode == BuildModeDebug, is_small,
                        g->enable_time_report))
            {
                zig_panic("unable to write llvm-ir file %s: %s", buf_ptr(output_path), err_msg);
            }
            validate_inline_fns(g);
            break;

        default:
            zig_unreachable();
    }
}

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

static void add_fp_entry(CodeGen *g, const char *name, uint32_t bit_count, LLVMTypeRef type_ref,
        ZigType **field)
{
    ZigType *entry = new_type_table_entry(ZigTypeIdFloat);
    entry->llvm_type = type_ref;
    entry->size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->llvm_type);
    entry->abi_size = LLVMABISizeOfType(g->target_data_ref, entry->llvm_type);
    entry->abi_align = LLVMABIAlignmentOfType(g->target_data_ref, entry->llvm_type);
    buf_init_from_str(&entry->name, name);
    entry->data.floating.bit_count = bit_count;

    entry->llvm_di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
            entry->size_in_bits, ZigLLVMEncoding_DW_ATE_float());
    *field = entry;
    g->primitive_type_table.put(&entry->name, entry);
}

static void define_builtin_types(CodeGen *g) {
    {
        // if this type is anywhere in the AST, we should never hit codegen.
        ZigType *entry = new_type_table_entry(ZigTypeIdInvalid);
        buf_init_from_str(&entry->name, "(invalid)");
        g->builtin_types.entry_invalid = entry;
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdComptimeFloat);
        buf_init_from_str(&entry->name, "comptime_float");
        g->builtin_types.entry_num_lit_float = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdComptimeInt);
        buf_init_from_str(&entry->name, "comptime_int");
        g->builtin_types.entry_num_lit_int = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdEnumLiteral);
        buf_init_from_str(&entry->name, "(enum literal)");
        g->builtin_types.entry_enum_literal = entry;
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdUndefined);
        buf_init_from_str(&entry->name, "(undefined)");
        g->builtin_types.entry_undef = entry;
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdNull);
        buf_init_from_str(&entry->name, "(null)");
        g->builtin_types.entry_null = entry;
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdArgTuple);
        buf_init_from_str(&entry->name, "(args)");
        g->builtin_types.entry_arg_tuple = entry;
    }

    for (size_t i = 0; i < array_length(c_int_type_infos); i += 1) {
        const CIntTypeInfo *info = &c_int_type_infos[i];
        uint32_t size_in_bits = target_c_type_size_in_bits(g->zig_target, info->id);
        bool is_signed = info->is_signed;

        ZigType *entry = new_type_table_entry(ZigTypeIdInt);
        entry->llvm_type = LLVMIntType(size_in_bits);
        entry->size_in_bits = size_in_bits;
        entry->abi_size = LLVMABISizeOfType(g->target_data_ref, entry->llvm_type);
        entry->abi_align = LLVMABIAlignmentOfType(g->target_data_ref, entry->llvm_type);

        buf_init_from_str(&entry->name, info->name);

        entry->llvm_di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                size_in_bits, is_signed ? ZigLLVMEncoding_DW_ATE_signed() : ZigLLVMEncoding_DW_ATE_unsigned());
        entry->data.integral.is_signed = is_signed;
        entry->data.integral.bit_count = size_in_bits;
        g->primitive_type_table.put(&entry->name, entry);

        get_c_int_type_ptr(g, info->id)[0] = entry;
    }

    {
        ZigType *entry = new_type_table_entry(ZigTypeIdBool);
        entry->llvm_type = LLVMInt1Type();
        entry->size_in_bits = 1;
        entry->abi_size = LLVMABISizeOfType(g->target_data_ref, entry->llvm_type);
        entry->abi_align = LLVMABIAlignmentOfType(g->target_data_ref, entry->llvm_type);
        buf_init_from_str(&entry->name, "bool");
        entry->llvm_di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, ZigLLVMEncoding_DW_ATE_boolean());
        g->builtin_types.entry_bool = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    for (size_t sign_i = 0; sign_i < array_length(is_signed_list); sign_i += 1) {
        bool is_signed = is_signed_list[sign_i];

        ZigType *entry = new_type_table_entry(ZigTypeIdInt);
        entry->llvm_type = LLVMIntType(g->pointer_size_bytes * 8);
        entry->size_in_bits = g->pointer_size_bytes * 8;
        entry->abi_size = LLVMABISizeOfType(g->target_data_ref, entry->llvm_type);
        entry->abi_align = LLVMABIAlignmentOfType(g->target_data_ref, entry->llvm_type);

        const char u_or_i = is_signed ? 'i' : 'u';
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "%csize", u_or_i);

        entry->data.integral.is_signed = is_signed;
        entry->data.integral.bit_count = g->pointer_size_bytes * 8;

        entry->llvm_di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits,
                is_signed ? ZigLLVMEncoding_DW_ATE_signed() : ZigLLVMEncoding_DW_ATE_unsigned());
        g->primitive_type_table.put(&entry->name, entry);

        if (is_signed) {
            g->builtin_types.entry_isize = entry;
        } else {
            g->builtin_types.entry_usize = entry;
        }
    }

    add_fp_entry(g, "f16", 16, LLVMHalfType(), &g->builtin_types.entry_f16);
    add_fp_entry(g, "f32", 32, LLVMFloatType(), &g->builtin_types.entry_f32);
    add_fp_entry(g, "f64", 64, LLVMDoubleType(), &g->builtin_types.entry_f64);
    add_fp_entry(g, "f128", 128, LLVMFP128Type(), &g->builtin_types.entry_f128);
    add_fp_entry(g, "c_longdouble", 80, LLVMX86FP80Type(), &g->builtin_types.entry_c_longdouble);

    {
        ZigType *entry = new_type_table_entry(ZigTypeIdVoid);
        entry->llvm_type = LLVMVoidType();
        buf_init_from_str(&entry->name, "void");
        entry->llvm_di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                0,
                ZigLLVMEncoding_DW_ATE_signed());
        g->builtin_types.entry_void = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdUnreachable);
        entry->llvm_type = LLVMVoidType();
        buf_init_from_str(&entry->name, "noreturn");
        entry->llvm_di_type = g->builtin_types.entry_void->llvm_di_type;
        g->builtin_types.entry_unreachable = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        ZigType *entry = new_type_table_entry(ZigTypeIdMetaType);
        buf_init_from_str(&entry->name, "type");
        g->builtin_types.entry_type = entry;
        g->primitive_type_table.put(&entry->name, entry);
    }

    g->builtin_types.entry_u8 = get_int_type(g, false, 8);
    g->builtin_types.entry_u16 = get_int_type(g, false, 16);
    g->builtin_types.entry_u29 = get_int_type(g, false, 29);
    g->builtin_types.entry_u32 = get_int_type(g, false, 32);
    g->builtin_types.entry_u64 = get_int_type(g, false, 64);
    g->builtin_types.entry_i8 = get_int_type(g, true, 8);
    g->builtin_types.entry_i32 = get_int_type(g, true, 32);
    g->builtin_types.entry_i64 = get_int_type(g, true, 64);

    {
        g->builtin_types.entry_c_void = get_opaque_type(g, nullptr, nullptr, "c_void",
                buf_create_from_str("c_void"));
        g->primitive_type_table.put(&g->builtin_types.entry_c_void->name, g->builtin_types.entry_c_void);
    }

    {
        ZigType *entry = new_type_table_entry(ZigTypeIdErrorSet);
        buf_init_from_str(&entry->name, "anyerror");
        entry->data.error_set.err_count = UINT32_MAX;

        // TODO https://github.com/ziglang/zig/issues/786
        g->err_tag_type = g->builtin_types.entry_u16;

        entry->size_in_bits = g->err_tag_type->size_in_bits;
        entry->abi_align = g->err_tag_type->abi_align;
        entry->abi_size = g->err_tag_type->abi_size;

        g->builtin_types.entry_global_error_set = entry;

        g->errors_by_index.append(nullptr);

        g->primitive_type_table.put(&entry->name, entry);
    }
    {
        ZigType *entry = get_promise_type(g, nullptr);
        g->primitive_type_table.put(&entry->name, entry);
        entry->size_in_bits = g->builtin_types.entry_usize->size_in_bits;
        entry->abi_align = g->builtin_types.entry_usize->abi_align;
        entry->abi_size = g->builtin_types.entry_usize->abi_size;
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
    create_builtin_fn(g, BuiltinFnIdHandle, "handle", 0);
    create_builtin_fn(g, BuiltinFnIdMemcpy, "memcpy", 3);
    create_builtin_fn(g, BuiltinFnIdMemset, "memset", 3);
    create_builtin_fn(g, BuiltinFnIdSizeof, "sizeOf", 1);
    create_builtin_fn(g, BuiltinFnIdAlignOf, "alignOf", 1);
    create_builtin_fn(g, BuiltinFnIdMemberCount, "memberCount", 1);
    create_builtin_fn(g, BuiltinFnIdMemberType, "memberType", 2);
    create_builtin_fn(g, BuiltinFnIdMemberName, "memberName", 2);
    create_builtin_fn(g, BuiltinFnIdField, "field", 2);
    create_builtin_fn(g, BuiltinFnIdTypeInfo, "typeInfo", 1);
    create_builtin_fn(g, BuiltinFnIdHasField, "hasField", 2);
    create_builtin_fn(g, BuiltinFnIdTypeof, "typeOf", 1); // TODO rename to TypeOf
    create_builtin_fn(g, BuiltinFnIdAddWithOverflow, "addWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdSubWithOverflow, "subWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdMulWithOverflow, "mulWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdShlWithOverflow, "shlWithOverflow", 4);
    create_builtin_fn(g, BuiltinFnIdCInclude, "cInclude", 1);
    create_builtin_fn(g, BuiltinFnIdCDefine, "cDefine", 2);
    create_builtin_fn(g, BuiltinFnIdCUndef, "cUndef", 1);
    create_builtin_fn(g, BuiltinFnIdCtz, "ctz", 2);
    create_builtin_fn(g, BuiltinFnIdClz, "clz", 2);
    create_builtin_fn(g, BuiltinFnIdPopCount, "popCount", 2);
    create_builtin_fn(g, BuiltinFnIdBswap, "byteSwap", 2);
    create_builtin_fn(g, BuiltinFnIdBitReverse, "bitReverse", 2);
    create_builtin_fn(g, BuiltinFnIdImport, "import", 1);
    create_builtin_fn(g, BuiltinFnIdCImport, "cImport", 1);
    create_builtin_fn(g, BuiltinFnIdErrName, "errorName", 1);
    create_builtin_fn(g, BuiltinFnIdTypeName, "typeName", 1);
    create_builtin_fn(g, BuiltinFnIdEmbedFile, "embedFile", 1);
    create_builtin_fn(g, BuiltinFnIdCmpxchgWeak, "cmpxchgWeak", 6);
    create_builtin_fn(g, BuiltinFnIdCmpxchgStrong, "cmpxchgStrong", 6);
    create_builtin_fn(g, BuiltinFnIdFence, "fence", 1);
    create_builtin_fn(g, BuiltinFnIdTruncate, "truncate", 2);
    create_builtin_fn(g, BuiltinFnIdIntCast, "intCast", 2);
    create_builtin_fn(g, BuiltinFnIdFloatCast, "floatCast", 2);
    create_builtin_fn(g, BuiltinFnIdIntToFloat, "intToFloat", 2);
    create_builtin_fn(g, BuiltinFnIdFloatToInt, "floatToInt", 2);
    create_builtin_fn(g, BuiltinFnIdBoolToInt, "boolToInt", 1);
    create_builtin_fn(g, BuiltinFnIdErrToInt, "errorToInt", 1);
    create_builtin_fn(g, BuiltinFnIdIntToErr, "intToError", 1);
    create_builtin_fn(g, BuiltinFnIdEnumToInt, "enumToInt", 1);
    create_builtin_fn(g, BuiltinFnIdIntToEnum, "intToEnum", 2);
    create_builtin_fn(g, BuiltinFnIdCompileErr, "compileError", 1);
    create_builtin_fn(g, BuiltinFnIdCompileLog, "compileLog", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdIntType, "IntType", 2); // TODO rename to Int
    create_builtin_fn(g, BuiltinFnIdVectorType, "Vector", 2);
    create_builtin_fn(g, BuiltinFnIdSetCold, "setCold", 1);
    create_builtin_fn(g, BuiltinFnIdSetRuntimeSafety, "setRuntimeSafety", 1);
    create_builtin_fn(g, BuiltinFnIdSetFloatMode, "setFloatMode", 1);
    create_builtin_fn(g, BuiltinFnIdPanic, "panic", 1);
    create_builtin_fn(g, BuiltinFnIdPtrCast, "ptrCast", 2);
    create_builtin_fn(g, BuiltinFnIdBitCast, "bitCast", 2);
    create_builtin_fn(g, BuiltinFnIdIntToPtr, "intToPtr", 2);
    create_builtin_fn(g, BuiltinFnIdPtrToInt, "ptrToInt", 1);
    create_builtin_fn(g, BuiltinFnIdTagName, "tagName", 1);
    create_builtin_fn(g, BuiltinFnIdTagType, "TagType", 1);
    create_builtin_fn(g, BuiltinFnIdFieldParentPtr, "fieldParentPtr", 3);
    create_builtin_fn(g, BuiltinFnIdByteOffsetOf, "byteOffsetOf", 2);
    create_builtin_fn(g, BuiltinFnIdBitOffsetOf, "bitOffsetOf", 2);
    create_builtin_fn(g, BuiltinFnIdDivExact, "divExact", 2);
    create_builtin_fn(g, BuiltinFnIdDivTrunc, "divTrunc", 2);
    create_builtin_fn(g, BuiltinFnIdDivFloor, "divFloor", 2);
    create_builtin_fn(g, BuiltinFnIdRem, "rem", 2);
    create_builtin_fn(g, BuiltinFnIdMod, "mod", 2);
    create_builtin_fn(g, BuiltinFnIdSqrt, "sqrt", 2);
    create_builtin_fn(g, BuiltinFnIdSin, "sin", 2);
    create_builtin_fn(g, BuiltinFnIdCos, "cos", 2);
    create_builtin_fn(g, BuiltinFnIdExp, "exp", 2);
    create_builtin_fn(g, BuiltinFnIdExp2, "exp2", 2);
    create_builtin_fn(g, BuiltinFnIdLn, "ln", 2);
    create_builtin_fn(g, BuiltinFnIdLog2, "log2", 2);
    create_builtin_fn(g, BuiltinFnIdLog10, "log10", 2);
    create_builtin_fn(g, BuiltinFnIdFabs, "fabs", 2);
    create_builtin_fn(g, BuiltinFnIdFloor, "floor", 2);
    create_builtin_fn(g, BuiltinFnIdCeil, "ceil", 2);
    create_builtin_fn(g, BuiltinFnIdTrunc, "trunc", 2);
    //Needs library support on Windows
    //create_builtin_fn(g, BuiltinFnIdNearbyInt, "nearbyInt", 2);
    create_builtin_fn(g, BuiltinFnIdRound, "round", 2);
    create_builtin_fn(g, BuiltinFnIdMulAdd, "mulAdd", 4);
    create_builtin_fn(g, BuiltinFnIdInlineCall, "inlineCall", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdNoInlineCall, "noInlineCall", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdNewStackCall, "newStackCall", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdTypeId, "typeId", 1);
    create_builtin_fn(g, BuiltinFnIdShlExact, "shlExact", 2);
    create_builtin_fn(g, BuiltinFnIdShrExact, "shrExact", 2);
    create_builtin_fn(g, BuiltinFnIdSetEvalBranchQuota, "setEvalBranchQuota", 1);
    create_builtin_fn(g, BuiltinFnIdAlignCast, "alignCast", 2);
    create_builtin_fn(g, BuiltinFnIdOpaqueType, "OpaqueType", 0);
    create_builtin_fn(g, BuiltinFnIdSetAlignStack, "setAlignStack", 1);
    create_builtin_fn(g, BuiltinFnIdArgType, "ArgType", 2);
    create_builtin_fn(g, BuiltinFnIdExport, "export", 3);
    create_builtin_fn(g, BuiltinFnIdErrorReturnTrace, "errorReturnTrace", 0);
    create_builtin_fn(g, BuiltinFnIdAtomicRmw, "atomicRmw", 5);
    create_builtin_fn(g, BuiltinFnIdAtomicLoad, "atomicLoad", 3);
    create_builtin_fn(g, BuiltinFnIdErrSetCast, "errSetCast", 2);
    create_builtin_fn(g, BuiltinFnIdToBytes, "sliceToBytes", 1);
    create_builtin_fn(g, BuiltinFnIdFromBytes, "bytesToSlice", 2);
    create_builtin_fn(g, BuiltinFnIdThis, "This", 0);
    create_builtin_fn(g, BuiltinFnIdHasDecl, "hasDecl", 2);
    create_builtin_fn(g, BuiltinFnIdUnionInit, "unionInit", 3);
}

static const char *bool_to_str(bool b) {
    return b ? "true" : "false";
}

static const char *build_mode_to_str(BuildMode build_mode) {
    switch (build_mode) {
        case BuildModeDebug: return "Mode.Debug";
        case BuildModeSafeRelease: return "Mode.ReleaseSafe";
        case BuildModeFastRelease: return "Mode.ReleaseFast";
        case BuildModeSmallRelease: return "Mode.ReleaseSmall";
    }
    zig_unreachable();
}

static const char *subsystem_to_str(TargetSubsystem subsystem) {
    switch (subsystem) {
        case TargetSubsystemConsole: return "Console";
        case TargetSubsystemWindows: return "Windows";
        case TargetSubsystemPosix: return "Posix";
        case TargetSubsystemNative: return "Native";
        case TargetSubsystemEfiApplication: return "EfiApplication";
        case TargetSubsystemEfiBootServiceDriver: return "EfiBootServiceDriver";
        case TargetSubsystemEfiRom: return "EfiRom";
        case TargetSubsystemEfiRuntimeDriver: return "EfiRuntimeDriver";
        case TargetSubsystemAuto: zig_unreachable();
    }
    zig_unreachable();
}

static bool detect_dynamic_link(CodeGen *g) {
    if (g->is_dynamic)
        return true;
    if (g->zig_target->os == OsFreestanding)
        return false;
    if (target_requires_pic(g->zig_target, g->libc_link_lib != nullptr))
        return true;
    // If there are no dynamic libraries then we can disable PIC
    for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(i);
        if (target_is_libc_lib_name(g->zig_target, buf_ptr(link_lib->name)))
            continue;
        return true;
    }
    return false;
}

static bool detect_pic(CodeGen *g) {
    if (target_requires_pic(g->zig_target, g->libc_link_lib != nullptr))
        return true;
    switch (g->want_pic) {
        case WantPICDisabled:
            return false;
        case WantPICEnabled:
            return true;
        case WantPICAuto:
            return g->have_dynamic_link;
    }
    zig_unreachable();
}

static bool detect_stack_probing(CodeGen *g) {
    if (!target_supports_stack_probing(g->zig_target))
        return false;
    switch (g->want_stack_check) {
        case WantStackCheckDisabled:
            return false;
        case WantStackCheckEnabled:
            return true;
        case WantStackCheckAuto:
            return g->build_mode == BuildModeSafeRelease || g->build_mode == BuildModeDebug;
    }
    zig_unreachable();
}

// Returns TargetSubsystemAuto to mean "no subsystem"
TargetSubsystem detect_subsystem(CodeGen *g) {
    if (g->subsystem != TargetSubsystemAuto)
        return g->subsystem;
    if (g->zig_target->os == OsWindows) {
        if (g->have_dllmain_crt_startup || (g->out_type == OutTypeLib && g->is_dynamic))
            return TargetSubsystemAuto;
        if (g->have_c_main || g->have_pub_main || g->is_test_build)
            return TargetSubsystemConsole;
        if (g->have_winmain || g->have_winmain_crt_startup)
            return TargetSubsystemWindows;
    } else if (g->zig_target->os == OsUefi) {
        return TargetSubsystemEfiApplication;
    }
    return TargetSubsystemAuto;
}

static bool detect_single_threaded(CodeGen *g) {
    if (g->want_single_threaded)
        return true;
    if (target_is_single_threaded(g->zig_target)) {
        return true;
    }
    return false;
}

static bool detect_err_ret_tracing(CodeGen *g) {
    return !g->strip_debug_symbols &&
        g->build_mode != BuildModeFastRelease &&
        g->build_mode != BuildModeSmallRelease;
}

Buf *codegen_generate_builtin_source(CodeGen *g) {
    g->have_dynamic_link = detect_dynamic_link(g);
    g->have_pic = detect_pic(g);
    g->have_stack_probing = detect_stack_probing(g);
    g->is_single_threaded = detect_single_threaded(g);
    g->have_err_ret_tracing = detect_err_ret_tracing(g);

    Buf *contents = buf_alloc();

    // NOTE: when editing this file, you may need to make modifications to the
    // cache input parameters in define_builtin_compile_vars

    // Modifications to this struct must be coordinated with code that does anything with
    // g->stack_trace_type. There are hard-coded references to the field indexes.
    buf_append_str(contents,
        "pub const StackTrace = struct {\n"
        "    index: usize,\n"
        "    instruction_addresses: []usize,\n"
        "};\n\n");

    buf_append_str(contents, "pub const PanicFn = fn([]const u8, ?*StackTrace) noreturn;\n\n");

    const char *cur_os = nullptr;
    {
        buf_appendf(contents, "pub const Os = enum {\n");
        uint32_t field_count = (uint32_t)target_os_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            Os os_type = target_os_enum(i);
            const char *name = target_os_name(os_type);
            buf_appendf(contents, "    %s,\n", name);

            if (os_type == g->zig_target->os) {
                g->target_os_index = i;
                cur_os = name;
            }
        }
        buf_appendf(contents, "};\n\n");
    }
    assert(cur_os != nullptr);

    const char *cur_arch = nullptr;
    {
        buf_appendf(contents, "pub const Arch = union(enum) {\n");
        uint32_t field_count = (uint32_t)target_arch_count();
        for (uint32_t arch_i = 0; arch_i < field_count; arch_i += 1) {
            ZigLLVM_ArchType arch = target_arch_enum(arch_i);
            const char *arch_name = target_arch_name(arch);
            SubArchList sub_arch_list = target_subarch_list(arch);
            if (sub_arch_list == SubArchListNone) {
                buf_appendf(contents, "    %s,\n", arch_name);
                if (arch == g->zig_target->arch) {
                    g->target_arch_index = arch_i;
                    cur_arch = buf_ptr(buf_sprintf("Arch.%s", arch_name));
                }
            } else {
                const char *sub_arch_list_name = target_subarch_list_name(sub_arch_list);
                buf_appendf(contents, "    %s: %s,\n", arch_name, sub_arch_list_name);
                if (arch == g->zig_target->arch) {
                    size_t sub_count = target_subarch_count(sub_arch_list);
                    for (size_t sub_i = 0; sub_i < sub_count; sub_i += 1) {
                        ZigLLVM_SubArchType sub = target_subarch_enum(sub_arch_list, sub_i);
                        if (sub == g->zig_target->sub_arch) {
                            g->target_sub_arch_index = sub_i;
                            cur_arch = buf_ptr(buf_sprintf("Arch{ .%s = Arch.%s.%s }",
                                        arch_name, sub_arch_list_name, target_subarch_name(sub)));
                        }
                    }
                }
            }
        }

        uint32_t list_count = target_subarch_list_count();
        // start at index 1 to skip None
        for (uint32_t list_i = 1; list_i < list_count; list_i += 1) {
            SubArchList sub_arch_list = target_subarch_list_enum(list_i);
            const char *subarch_list_name = target_subarch_list_name(sub_arch_list);
            buf_appendf(contents, "    pub const %s = enum {\n", subarch_list_name);
            size_t sub_count = target_subarch_count(sub_arch_list);
            for (size_t sub_i = 0; sub_i < sub_count; sub_i += 1) {
                ZigLLVM_SubArchType sub = target_subarch_enum(sub_arch_list, sub_i);
                buf_appendf(contents, "        %s,\n", target_subarch_name(sub));
            }
            buf_appendf(contents, "    };\n");
        }
        buf_appendf(contents, "};\n\n");
    }
    assert(cur_arch != nullptr);

    const char *cur_abi = nullptr;
    {
        buf_appendf(contents, "pub const Abi = enum {\n");
        uint32_t field_count = (uint32_t)target_abi_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            ZigLLVM_EnvironmentType abi = target_abi_enum(i);
            const char *name = target_abi_name(abi);
            buf_appendf(contents, "    %s,\n", name);

            if (abi == g->zig_target->abi) {
                g->target_abi_index = i;
                cur_abi = name;
            }
        }
        buf_appendf(contents, "};\n\n");
    }
    assert(cur_abi != nullptr);

    const char *cur_obj_fmt = nullptr;
    {
        buf_appendf(contents, "pub const ObjectFormat = enum {\n");
        uint32_t field_count = (uint32_t)target_oformat_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            ZigLLVM_ObjectFormatType oformat = target_oformat_enum(i);
            const char *name = target_oformat_name(oformat);
            buf_appendf(contents, "    %s,\n", name);

            ZigLLVM_ObjectFormatType target_oformat = target_object_format(g->zig_target);
            if (oformat == target_oformat) {
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
            "pub const AtomicRmwOp = enum {\n"
            "    Xchg,\n"
            "    Add,\n"
            "    Sub,\n"
            "    And,\n"
            "    Nand,\n"
            "    Or,\n"
            "    Xor,\n"
            "    Max,\n"
            "    Min,\n"
            "};\n\n");
    }
    {
        buf_appendf(contents,
            "pub const Mode = enum {\n"
            "    Debug,\n"
            "    ReleaseSafe,\n"
            "    ReleaseFast,\n"
            "    ReleaseSmall,\n"
            "};\n\n");
    }
    {
        buf_appendf(contents, "pub const TypeId = enum {\n");
        size_t field_count = type_id_len();
        for (size_t i = 0; i < field_count; i += 1) {
            const ZigTypeId id = type_id_at_index(i);
            buf_appendf(contents, "    %s,\n", type_id_name(id));
        }
        buf_appendf(contents, "};\n\n");
    }
    {
        buf_appendf(contents,
            "pub const TypeInfo = union(TypeId) {\n"
            "    Type: void,\n"
            "    Void: void,\n"
            "    Bool: void,\n"
            "    NoReturn: void,\n"
            "    Int: Int,\n"
            "    Float: Float,\n"
            "    Pointer: Pointer,\n"
            "    Array: Array,\n"
            "    Struct: Struct,\n"
            "    ComptimeFloat: void,\n"
            "    ComptimeInt: void,\n"
            "    Undefined: void,\n"
            "    Null: void,\n"
            "    Optional: Optional,\n"
            "    ErrorUnion: ErrorUnion,\n"
            "    ErrorSet: ErrorSet,\n"
            "    Enum: Enum,\n"
            "    Union: Union,\n"
            "    Fn: Fn,\n"
            "    BoundFn: Fn,\n"
            "    ArgTuple: void,\n"
            "    Opaque: void,\n"
            "    Promise: Promise,\n"
            "    Vector: Vector,\n"
            "    EnumLiteral: void,\n"
            "\n\n"
            "    pub const Int = struct {\n"
            "        is_signed: bool,\n"
            "        bits: comptime_int,\n"
            "    };\n"
            "\n"
            "    pub const Float = struct {\n"
            "        bits: comptime_int,\n"
            "    };\n"
            "\n"
            "    pub const Pointer = struct {\n"
            "        size: Size,\n"
            "        is_const: bool,\n"
            "        is_volatile: bool,\n"
            "        alignment: comptime_int,\n"
            "        child: type,\n"
            "        is_allowzero: bool,\n"
            "\n"
            "        pub const Size = enum {\n"
            "            One,\n"
            "            Many,\n"
            "            Slice,\n"
            "            C,\n"
            "        };\n"
            "    };\n"
            "\n"
            "    pub const Array = struct {\n"
            "        len: comptime_int,\n"
            "        child: type,\n"
            "    };\n"
            "\n"
            "    pub const ContainerLayout = enum {\n"
            "        Auto,\n"
            "        Extern,\n"
            "        Packed,\n"
            "    };\n"
            "\n"
            "    pub const StructField = struct {\n"
            "        name: []const u8,\n"
            "        offset: ?comptime_int,\n"
            "        field_type: type,\n"
            "    };\n"
            "\n"
            "    pub const Struct = struct {\n"
            "        layout: ContainerLayout,\n"
            "        fields: []StructField,\n"
            "        decls: []Declaration,\n"
            "    };\n"
            "\n"
            "    pub const Optional = struct {\n"
            "        child: type,\n"
            "    };\n"
            "\n"
            "    pub const ErrorUnion = struct {\n"
            "        error_set: type,\n"
            "        payload: type,\n"
            "    };\n"
            "\n"
            "    pub const Error = struct {\n"
            "        name: []const u8,\n"
            "        value: comptime_int,\n"
            "    };\n"
            "\n"
            "    pub const ErrorSet = ?[]Error;\n"
            "\n"
            "    pub const EnumField = struct {\n"
            "        name: []const u8,\n"
            "        value: comptime_int,\n"
            "    };\n"
            "\n"
            "    pub const Enum = struct {\n"
            "        layout: ContainerLayout,\n"
            "        tag_type: type,\n"
            "        fields: []EnumField,\n"
            "        decls: []Declaration,\n"
            "    };\n"
            "\n"
            "    pub const UnionField = struct {\n"
            "        name: []const u8,\n"
            "        enum_field: ?EnumField,\n"
            "        field_type: type,\n"
            "    };\n"
            "\n"
            "    pub const Union = struct {\n"
            "        layout: ContainerLayout,\n"
            "        tag_type: ?type,\n"
            "        fields: []UnionField,\n"
            "        decls: []Declaration,\n"
            "    };\n"
            "\n"
            "    pub const CallingConvention = enum {\n"
            "        Unspecified,\n"
            "        C,\n"
            "        Cold,\n"
            "        Naked,\n"
            "        Stdcall,\n"
            "        Async,\n"
            "    };\n"
            "\n"
            "    pub const FnArg = struct {\n"
            "        is_generic: bool,\n"
            "        is_noalias: bool,\n"
            "        arg_type: ?type,\n"
            "    };\n"
            "\n"
            "    pub const Fn = struct {\n"
            "        calling_convention: CallingConvention,\n"
            "        is_generic: bool,\n"
            "        is_var_args: bool,\n"
            "        return_type: ?type,\n"
            "        async_allocator_type: ?type,\n"
            "        args: []FnArg,\n"
            "    };\n"
            "\n"
            "    pub const Promise = struct {\n"
            "        child: ?type,\n"
            "    };\n"
            "\n"
            "    pub const Vector = struct {\n"
            "        len: comptime_int,\n"
            "        child: type,\n"
            "    };\n"
            "\n"
            "    pub const Declaration = struct {\n"
            "        name: []const u8,\n"
            "        is_pub: bool,\n"
            "        data: Data,\n"
            "\n"
            "        pub const Data = union(enum) {\n"
            "            Type: type,\n"
            "            Var: type,\n"
            "            Fn: FnDecl,\n"
            "\n"
            "            pub const FnDecl = struct {\n"
            "                fn_type: type,\n"
            "                inline_type: Inline,\n"
            "                calling_convention: CallingConvention,\n"
            "                is_var_args: bool,\n"
            "                is_extern: bool,\n"
            "                is_export: bool,\n"
            "                lib_name: ?[]const u8,\n"
            "                return_type: type,\n"
            "                arg_names: [][] const u8,\n"
            "\n"
            "                pub const Inline = enum {\n"
            "                    Auto,\n"
            "                    Always,\n"
            "                    Never,\n"
            "                };\n"
            "            };\n"
            "        };\n"
            "    };\n"
            "};\n\n");
        assert(ContainerLayoutAuto == 0);
        assert(ContainerLayoutExtern == 1);
        assert(ContainerLayoutPacked == 2);

        assert(CallingConventionUnspecified == 0);
        assert(CallingConventionC == 1);
        assert(CallingConventionCold == 2);
        assert(CallingConventionNaked == 3);
        assert(CallingConventionStdcall == 4);
        assert(CallingConventionAsync == 5);

        assert(FnInlineAuto == 0);
        assert(FnInlineAlways == 1);
        assert(FnInlineNever == 2);
    }
    {
        buf_appendf(contents,
            "pub const FloatMode = enum {\n"
            "    Strict,\n"
            "    Optimized,\n"
            "};\n\n");
        assert(FloatModeStrict == 0);
        assert(FloatModeOptimized == 1);
    }
    {
        buf_appendf(contents,
            "pub const Endian = enum {\n"
            "    Big,\n"
            "    Little,\n"
            "};\n\n");
        //assert(EndianBig == 0);
        //assert(EndianLittle == 1);
    }
    {
        buf_appendf(contents,
            "pub const Version = struct {\n"
            "    major: u32,\n"
            "    minor: u32,\n"
            "    patch: u32,\n"
            "};\n\n");
    }
    {
        buf_appendf(contents,
        "pub const SubSystem = enum {\n"
        "    Console,\n"
        "    Windows,\n"
        "    Posix,\n"
        "    Native,\n"
        "    EfiApplication,\n"
        "    EfiBootServiceDriver,\n"
        "    EfiRom,\n"
        "    EfiRuntimeDriver,\n"
        "};\n\n");

        assert(TargetSubsystemConsole == 0);
        assert(TargetSubsystemWindows == 1);
        assert(TargetSubsystemPosix == 2);
        assert(TargetSubsystemNative == 3);
        assert(TargetSubsystemEfiApplication == 4);
        assert(TargetSubsystemEfiBootServiceDriver == 5);
        assert(TargetSubsystemEfiRom == 6);
        assert(TargetSubsystemEfiRuntimeDriver == 7);
    }
    {
        const char *endian_str = g->is_big_endian ? "Endian.Big" : "Endian.Little";
        buf_appendf(contents, "pub const endian = %s;\n", endian_str);
    }
    buf_appendf(contents, "pub const is_test = %s;\n", bool_to_str(g->is_test_build));
    buf_appendf(contents, "pub const single_threaded = %s;\n", bool_to_str(g->is_single_threaded));
    buf_appendf(contents, "pub const os = Os.%s;\n", cur_os);
    buf_appendf(contents, "pub const arch = %s;\n", cur_arch);
    buf_appendf(contents, "pub const abi = Abi.%s;\n", cur_abi);
    if (g->libc_link_lib != nullptr && g->zig_target->glibc_version != nullptr) {
        buf_appendf(contents,
            "pub const glibc_version: ?Version = Version{.major = %d, .minor = %d, .patch = %d};\n",
                g->zig_target->glibc_version->major,
                g->zig_target->glibc_version->minor,
                g->zig_target->glibc_version->patch);
    } else {
        buf_appendf(contents, "pub const glibc_version: ?Version = null;\n");
    }
    buf_appendf(contents, "pub const object_format = ObjectFormat.%s;\n", cur_obj_fmt);
    buf_appendf(contents, "pub const mode = %s;\n", build_mode_to_str(g->build_mode));
    buf_appendf(contents, "pub const link_libc = %s;\n", bool_to_str(g->libc_link_lib != nullptr));
    buf_appendf(contents, "pub const have_error_return_tracing = %s;\n", bool_to_str(g->have_err_ret_tracing));
    buf_appendf(contents, "pub const valgrind_support = %s;\n", bool_to_str(want_valgrind_support(g)));
    buf_appendf(contents, "pub const position_independent_code = %s;\n", bool_to_str(g->have_pic));
    buf_appendf(contents, "pub const strip_debug_info = %s;\n", bool_to_str(g->strip_debug_symbols));

    {
        TargetSubsystem detected_subsystem = detect_subsystem(g);
        if (detected_subsystem != TargetSubsystemAuto) {
            buf_appendf(contents, "pub const subsystem = SubSystem.%s;\n", subsystem_to_str(detected_subsystem));
        }
    }

    if (g->is_test_build) {
        buf_appendf(contents,
            "const TestFn = struct {\n"
                "name: []const u8,\n"
                "func: fn()anyerror!void,\n"
            "};\n"
            "pub const test_functions = {}; // overwritten later\n"
        );
    }

    return contents;
}

static Error define_builtin_compile_vars(CodeGen *g) {
    if (g->std_package == nullptr)
        return ErrorNone;

    Error err;

    Buf *manifest_dir = buf_alloc();
    os_path_join(get_stage1_cache_path(), buf_create_from_str("builtin"), manifest_dir);

    CacheHash cache_hash;
    cache_init(&cache_hash, manifest_dir);

    Buf *compiler_id;
    if ((err = get_compiler_id(&compiler_id)))
        return err;

    // Only a few things affect builtin.zig
    cache_buf(&cache_hash, compiler_id);
    cache_int(&cache_hash, g->build_mode);
    cache_bool(&cache_hash, g->strip_debug_symbols);
    cache_bool(&cache_hash, g->is_test_build);
    cache_bool(&cache_hash, g->is_single_threaded);
    cache_int(&cache_hash, g->zig_target->is_native);
    cache_int(&cache_hash, g->zig_target->arch);
    cache_int(&cache_hash, g->zig_target->sub_arch);
    cache_int(&cache_hash, g->zig_target->vendor);
    cache_int(&cache_hash, g->zig_target->os);
    cache_int(&cache_hash, g->zig_target->abi);
    if (g->zig_target->glibc_version != nullptr) {
        cache_int(&cache_hash, g->zig_target->glibc_version->major);
        cache_int(&cache_hash, g->zig_target->glibc_version->minor);
        cache_int(&cache_hash, g->zig_target->glibc_version->patch);
    }
    cache_bool(&cache_hash, g->have_err_ret_tracing);
    cache_bool(&cache_hash, g->libc_link_lib != nullptr);
    cache_bool(&cache_hash, g->valgrind_support);
    cache_int(&cache_hash, detect_subsystem(g));

    Buf digest = BUF_INIT;
    buf_resize(&digest, 0);
    if ((err = cache_hit(&cache_hash, &digest))) {
        // Treat an invalid format error as a cache miss.
        if (err != ErrorInvalidFormat)
            return err;
    }

    // We should always get a cache hit because there are no
    // files in the input hash.
    assert(buf_len(&digest) != 0);

    Buf *this_dir = buf_alloc();
    os_path_join(manifest_dir, &digest, this_dir);

    if ((err = os_make_path(this_dir)))
        return err;

    const char *builtin_zig_basename = "builtin.zig";
    Buf *builtin_zig_path = buf_alloc();
    os_path_join(this_dir, buf_create_from_str(builtin_zig_basename), builtin_zig_path);

    bool hit;
    if ((err = os_file_exists(builtin_zig_path, &hit)))
        return err;
    Buf *contents;
    if (hit) {
        contents = buf_alloc();
        if ((err = os_fetch_file_path(builtin_zig_path, contents))) {
            fprintf(stderr, "Unable to open '%s': %s\n", buf_ptr(builtin_zig_path), err_str(err));
            exit(1);
        }
    } else {
        contents = codegen_generate_builtin_source(g);
        if ((err = os_write_file(builtin_zig_path, contents))) {
            fprintf(stderr, "Unable to write file '%s': %s\n", buf_ptr(builtin_zig_path), err_str(err));
            exit(1);
        }
    }

    assert(g->root_package);
    assert(g->std_package);
    g->compile_var_package = new_package(buf_ptr(this_dir), builtin_zig_basename, "builtin");
    g->root_package->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    g->std_package->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    g->std_package->package_table.put(buf_create_from_str("std"), g->std_package);
    g->std_package->package_table.put(buf_create_from_str("root"),
            g->is_test_build ? g->test_runner_package : g->root_package);
    g->compile_var_import = add_source_file(g, g->compile_var_package, builtin_zig_path, contents,
            SourceKindPkgMain);

    return ErrorNone;
}

static void init(CodeGen *g) {
    if (g->module)
        return;

    g->have_dynamic_link = detect_dynamic_link(g);
    g->have_pic = detect_pic(g);
    g->have_stack_probing = detect_stack_probing(g);
    g->is_single_threaded = detect_single_threaded(g);
    g->have_err_ret_tracing = detect_err_ret_tracing(g);

    if (target_is_single_threaded(g->zig_target)) {
        g->is_single_threaded = true;
    }

    assert(g->root_out_name);
    g->module = LLVMModuleCreateWithName(buf_ptr(g->root_out_name));

    LLVMSetTarget(g->module, buf_ptr(&g->llvm_triple_str));

    if (target_object_format(g->zig_target) == ZigLLVM_COFF) {
        ZigLLVMAddModuleCodeViewFlag(g->module);
    } else {
        ZigLLVMAddModuleDebugInfoFlag(g->module);
    }

    LLVMTargetRef target_ref;
    char *err_msg = nullptr;
    if (LLVMGetTargetFromTriple(buf_ptr(&g->llvm_triple_str), &target_ref, &err_msg)) {
        fprintf(stderr,
            "Zig is expecting LLVM to understand this target: '%s'\n"
            "However LLVM responded with: \"%s\"\n"
            "Zig is unable to continue. This is a bug in Zig:\n"
            "https://github.com/ziglang/zig/issues/438\n"
        , buf_ptr(&g->llvm_triple_str), err_msg);
        exit(1);
    }

    bool is_optimized = g->build_mode != BuildModeDebug;
    LLVMCodeGenOptLevel opt_level = is_optimized ? LLVMCodeGenLevelAggressive : LLVMCodeGenLevelNone;

    LLVMRelocMode reloc_mode;
    if (g->have_pic) {
        reloc_mode = LLVMRelocPIC;
    } else if (g->have_dynamic_link) {
        reloc_mode = LLVMRelocDynamicNoPic;
    } else {
        reloc_mode = LLVMRelocStatic;
    }

    const char *target_specific_cpu_args;
    const char *target_specific_features;
    if (g->zig_target->is_native) {
        // LLVM creates invalid binaries on Windows sometimes.
        // See https://github.com/ziglang/zig/issues/508
        // As a workaround we do not use target native features on Windows.
        if (g->zig_target->os == OsWindows || g->zig_target->os == OsUefi) {
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

    g->target_machine = ZigLLVMCreateTargetMachine(target_ref, buf_ptr(&g->llvm_triple_str),
            target_specific_cpu_args, target_specific_features, opt_level, reloc_mode,
            LLVMCodeModelDefault, g->function_sections);

    g->target_data_ref = LLVMCreateTargetDataLayout(g->target_machine);

    char *layout_str = LLVMCopyStringRepOfTargetData(g->target_data_ref);
    LLVMSetDataLayout(g->module, layout_str);


    assert(g->pointer_size_bytes == LLVMPointerSize(g->target_data_ref));
    g->is_big_endian = (LLVMByteOrder(g->target_data_ref) == LLVMBigEndian);

    g->builder = LLVMCreateBuilder();
    g->dbuilder = ZigLLVMCreateDIBuilder(g->module, true);

    // Don't use ZIG_VERSION_STRING here, llvm misparses it when it includes
    // the git revision.
    Buf *producer = buf_sprintf("zig %d.%d.%d", ZIG_VERSION_MAJOR, ZIG_VERSION_MINOR, ZIG_VERSION_PATCH);
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

    IrInstruction *sentinel_instructions = allocate<IrInstruction>(2);
    g->invalid_instruction = &sentinel_instructions[0];
    g->invalid_instruction->value.type = g->builtin_types.entry_invalid;
    g->invalid_instruction->value.global_refs = allocate<ConstGlobalRefs>(1);

    g->unreach_instruction = &sentinel_instructions[1];
    g->unreach_instruction->value.type = g->builtin_types.entry_unreachable;
    g->unreach_instruction->value.global_refs = allocate<ConstGlobalRefs>(1);

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
    Error err;
    if ((err = define_builtin_compile_vars(g))) {
        fprintf(stderr, "Unable to create builtin.zig: %s\n", err_str(err));
        exit(1);
    }
}

static void detect_dynamic_linker(CodeGen *g) {
    if (g->dynamic_linker_path != nullptr)
        return;
    if (!g->have_dynamic_link)
        return;
    if (g->out_type == OutTypeObj || (g->out_type == OutTypeLib && !g->is_dynamic))
        return;

    const char *standard_ld_path = target_dynamic_linker(g->zig_target);
    if (standard_ld_path == nullptr)
        return;

    if (g->zig_target->is_native) {
        // target_dynamic_linker is usually correct. However on some systems, such as NixOS
        // it will be incorrect. See if we can do better by looking at what zig's own
        // dynamic linker path is.
        g->dynamic_linker_path = get_self_dynamic_linker_path();
        if (g->dynamic_linker_path != nullptr)
            return;

        // If Zig is statically linked, such as via distributed binary static builds, the above
        // trick won't work. What are we left with? Try to run the system C compiler and get
        // it to tell us the dynamic linker path
#if defined(ZIG_OS_LINUX)
        {
            Error err;
            Buf *result = buf_alloc();
            for (size_t i = 0; possible_ld_names[i] != NULL; i += 1) {
                const char *lib_name = possible_ld_names[i];
                if ((err = zig_libc_cc_print_file_name(lib_name, result, false, true))) {
                    if (err != ErrorCCompilerCannotFindFile && err != ErrorNoCCompilerInstalled) {
                        fprintf(stderr, "Unable to detect native dynamic linker: %s\n", err_str(err));
                        exit(1);
                    }
                    continue;
                }
                g->dynamic_linker_path = result;
                return;
            }
        }
#endif
    }

    g->dynamic_linker_path = buf_create_from_str(standard_ld_path);
}

static void detect_libc(CodeGen *g) {
    Error err;

    if (g->libc != nullptr || g->libc_link_lib == nullptr)
        return;

    if (target_can_build_libc(g->zig_target)) {
        const char *generic_name = target_libc_generic_name(g->zig_target);
        const char *arch_name = target_arch_name(g->zig_target->arch);
        const char *abi_name = target_abi_name(g->zig_target->abi);
        if (target_is_musl(g->zig_target)) {
            // musl has some overrides. its headers are ABI-agnostic and so they all have the "musl" ABI name.
            abi_name = "musl";
            // some architectures are handled by the same set of headers
            arch_name = target_arch_musl_name(g->zig_target->arch);
        }
        Buf *arch_include_dir = buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-%s-%s",
                buf_ptr(g->zig_lib_dir), arch_name, target_os_name(g->zig_target->os), abi_name);
        Buf *generic_include_dir = buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "generic-%s",
                buf_ptr(g->zig_lib_dir), generic_name);
        Buf *arch_os_include_dir = buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-%s-any",
                buf_ptr(g->zig_lib_dir), target_arch_name(g->zig_target->arch), target_os_name(g->zig_target->os));
        Buf *generic_os_include_dir = buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "any-%s-any",
                buf_ptr(g->zig_lib_dir), target_os_name(g->zig_target->os));

        g->libc_include_dir_len = 4;
        g->libc_include_dir_list = allocate<Buf*>(g->libc_include_dir_len);
        g->libc_include_dir_list[0] = arch_include_dir;
        g->libc_include_dir_list[1] = generic_include_dir;
        g->libc_include_dir_list[2] = arch_os_include_dir;
        g->libc_include_dir_list[3] = generic_os_include_dir;
        return;
    }

    if (g->zig_target->is_native) {
        g->libc = allocate<ZigLibCInstallation>(1);

        // Look for zig-cache/native_libc.txt
        Buf *native_libc_txt = buf_alloc();
        os_path_join(g->cache_dir, buf_create_from_str("native_libc.txt"), native_libc_txt);
        if ((err = zig_libc_parse(g->libc, native_libc_txt, g->zig_target, false))) {
            if ((err = zig_libc_find_native(g->libc, true))) {
                fprintf(stderr,
                    "Unable to link against libc: Unable to find libc installation: %s\n"
                    "See `zig libc --help` for more details.\n", err_str(err));
                exit(1);
            }
            if ((err = os_make_path(g->cache_dir))) {
                fprintf(stderr, "Unable to create %s directory: %s\n",
                    buf_ptr(g->cache_dir), err_str(err));
                exit(1);
            }
            Buf *native_libc_tmp = buf_sprintf("%s.tmp", buf_ptr(native_libc_txt));
            FILE *file = fopen(buf_ptr(native_libc_tmp), "wb");
            if (file == nullptr) {
                fprintf(stderr, "Unable to open %s: %s\n", buf_ptr(native_libc_tmp), strerror(errno));
                exit(1);
            }
            zig_libc_render(g->libc, file);
            if (fclose(file) != 0) {
                fprintf(stderr, "Unable to save %s: %s\n", buf_ptr(native_libc_tmp), strerror(errno));
                exit(1);
            }
            if ((err = os_rename(native_libc_tmp, native_libc_txt))) {
                fprintf(stderr, "Unable to create %s: %s\n", buf_ptr(native_libc_txt), err_str(err));
                exit(1);
            }
        }
        bool want_sys_dir = !buf_eql_buf(&g->libc->include_dir, &g->libc->sys_include_dir);
        size_t dir_count = 1 + want_sys_dir;
        g->libc_include_dir_len = dir_count;
        g->libc_include_dir_list = allocate<Buf*>(dir_count);
        g->libc_include_dir_list[0] = &g->libc->include_dir;
        if (want_sys_dir) {
            g->libc_include_dir_list[1] = &g->libc->sys_include_dir;
        }
    } else if ((g->out_type == OutTypeExe || (g->out_type == OutTypeLib && g->is_dynamic)) &&
        !target_os_is_darwin(g->zig_target->os))
    {
        Buf triple_buf = BUF_INIT;
        target_triple_zig(&triple_buf, g->zig_target);
        fprintf(stderr,
            "Zig is unable to provide a libc for the chosen target '%s'.\n"
            "The target is non-native, so Zig also cannot use the native libc installation.\n"
            "Choose a target which has a libc available (see `zig targets`), or\n"
            "provide a libc installation text file (see `zig libc --help`).\n", buf_ptr(&triple_buf));
        exit(1);
    }
}

// does not add the "cc" arg
void add_cc_args(CodeGen *g, ZigList<const char *> &args, const char *out_dep_path, bool translate_c) {
    if (translate_c) {
        args.append("-x");
        args.append("c");
    }

    if (out_dep_path != nullptr) {
        args.append("-MD");
        args.append("-MV");
        args.append("-MF");
        args.append(out_dep_path);
    }

    args.append("-nostdinc");
    args.append("-fno-spell-checking");

    if (g->function_sections) {
        args.append("-ffunction-sections");
    }

    if (translate_c) {
        // this gives us access to preprocessing entities, presumably at
        // the cost of performance
        args.append("-Xclang");
        args.append("-detailed-preprocessing-record");
    } else {
        switch (g->err_color) {
            case ErrColorAuto:
                break;
            case ErrColorOff:
                args.append("-fno-color-diagnostics");
                args.append("-fno-caret-diagnostics");
                break;
            case ErrColorOn:
                args.append("-fcolor-diagnostics");
                args.append("-fcaret-diagnostics");
                break;
        }
    }

    for (size_t i = 0; i < g->libc_include_dir_len; i += 1) {
        Buf *include_dir = g->libc_include_dir_list[i];
        args.append("-isystem");
        args.append(buf_ptr(include_dir));
    }

    // According to Rich Felker libc headers are supposed to go before C language headers.
    args.append("-isystem");
    args.append(buf_ptr(g->zig_c_headers_dir));

    if (g->zig_target->is_native) {
        args.append("-march=native");
    } else {
        args.append("-target");
        args.append(buf_ptr(&g->llvm_triple_str));
    }
    if (g->zig_target->os == OsFreestanding) {
        args.append("-ffreestanding");
    }

    // windows.h has files such as pshpack1.h which do #pragma packing, triggering a clang warning.
    // So for this target, we disable this warning.
    if (g->zig_target->os == OsWindows && target_abi_is_gnu(g->zig_target->abi)) {
        args.append("-Wno-pragma-pack");
    }

    if (!g->strip_debug_symbols) {
        args.append("-g");
    }

    switch (g->build_mode) {
        case BuildModeDebug:
            // windows c runtime requires -D_DEBUG if using debug libraries
            args.append("-D_DEBUG");

            if (g->libc_link_lib != nullptr) {
                args.append("-fstack-protector-strong");
                args.append("--param");
                args.append("ssp-buffer-size=4");
            } else {
                args.append("-fno-stack-protector");
            }
            args.append("-fno-omit-frame-pointer");
            break;
        case BuildModeSafeRelease:
            // See the comment in the BuildModeFastRelease case for why we pass -O2 rather
            // than -O3 here.
            args.append("-O2");
            if (g->libc_link_lib != nullptr) {
                args.append("-D_FORTIFY_SOURCE=2");
                args.append("-fstack-protector-strong");
                args.append("--param");
                args.append("ssp-buffer-size=4");
            } else {
                args.append("-fno-stack-protector");
            }
            args.append("-fomit-frame-pointer");
            break;
        case BuildModeFastRelease:
            args.append("-DNDEBUG");
            // Here we pass -O2 rather than -O3 because, although we do the equivalent of
            // -O3 in Zig code, the justification for the difference here is that Zig
            // has better detection and prevention of undefined behavior, so -O3 is safer for
            // Zig code than it is for C code. Also, C programmers are used to their code
            // running in -O2 and thus the -O3 path has been tested less.
            args.append("-O2");
            args.append("-fno-stack-protector");
            args.append("-fomit-frame-pointer");
            break;
        case BuildModeSmallRelease:
            args.append("-DNDEBUG");
            args.append("-Os");
            args.append("-fno-stack-protector");
            args.append("-fomit-frame-pointer");
            break;
    }

    if (target_supports_fpic(g->zig_target) && g->have_pic) {
        args.append("-fPIC");
    }

    for (size_t arg_i = 0; arg_i < g->clang_argv_len; arg_i += 1) {
        args.append(g->clang_argv[arg_i]);
    }
}

void codegen_translate_c(CodeGen *g, Buf *full_path, FILE *out_file, bool use_userland_implementation) {
    Error err;
    Buf *src_basename = buf_alloc();
    Buf *src_dirname = buf_alloc();
    os_path_split(full_path, src_dirname, src_basename);

    Buf noextname = BUF_INIT;
    os_path_extname(src_basename, &noextname, nullptr);

    detect_libc(g);

    init(g);

    Stage2TranslateMode trans_mode = buf_ends_with_str(full_path, ".h") ?
        Stage2TranslateModeImport : Stage2TranslateModeTranslate;


    ZigList<const char *> clang_argv = {0};
    add_cc_args(g, clang_argv, nullptr, true);

    clang_argv.append(buf_ptr(full_path));

    if (g->verbose_cc) {
        fprintf(stderr, "clang");
        for (size_t i = 0; i < clang_argv.length; i += 1) {
            fprintf(stderr, " %s", clang_argv.at(i));
        }
        fprintf(stderr, "\n");
    }

    clang_argv.append(nullptr); // to make the [start...end] argument work

    const char *resources_path = buf_ptr(g->zig_c_headers_dir);
    Stage2ErrorMsg *errors_ptr;
    size_t errors_len;
    Stage2Ast *ast;
    AstNode *root_node;

    if (use_userland_implementation) {
        err = stage2_translate_c(&ast, &errors_ptr, &errors_len,
                        &clang_argv.at(0), &clang_argv.last(), trans_mode, resources_path);
    } else {
        err = parse_h_file(g, &root_node, &errors_ptr, &errors_len, &clang_argv.at(0), &clang_argv.last(),
                trans_mode, resources_path);
    }

    if (err == ErrorCCompileErrors && errors_len > 0) {
        for (size_t i = 0; i < errors_len; i += 1) {
            Stage2ErrorMsg *clang_err = &errors_ptr[i];
            ErrorMsg *err_msg = err_msg_create_with_offset(
                    clang_err->filename_ptr ?
                        buf_create_from_mem(clang_err->filename_ptr, clang_err->filename_len) : buf_alloc(),
                    clang_err->line, clang_err->column, clang_err->offset, clang_err->source,
                    buf_create_from_mem(clang_err->msg_ptr, clang_err->msg_len));
            print_err_msg(err_msg, g->err_color);
        }
        exit(1);
    }

    if (err) {
        fprintf(stderr, "unable to parse C file: %s\n", err_str(err));
        exit(1);
    }


    if (use_userland_implementation) {
        stage2_render_ast(ast, out_file);
    } else {
        ast_render(out_file, root_node, 4);
    }
}

static ZigType *add_special_code(CodeGen *g, ZigPackage *package, const char *basename) {
    Buf *code_basename = buf_create_from_str(basename);
    Buf path_to_code_src = BUF_INIT;
    os_path_join(g->zig_std_special_dir, code_basename, &path_to_code_src);

    Buf *resolve_paths[] = {&path_to_code_src};
    Buf *resolved_path = buf_alloc();
    *resolved_path = os_path_resolve(resolve_paths, 1);
    Buf *import_code = buf_alloc();
    Error err;
    if ((err = file_fetch(g, resolved_path, import_code))) {
        zig_panic("unable to open '%s': %s\n", buf_ptr(&path_to_code_src), err_str(err));
    }

    return add_source_file(g, package, resolved_path, import_code, SourceKindPkgMain);
}

static ZigPackage *create_start_pkg(CodeGen *g, ZigPackage *pkg_with_main) {
    ZigPackage *package = codegen_create_package(g, buf_ptr(g->zig_std_special_dir), "start.zig", "std.special");
    package->package_table.put(buf_create_from_str("root"), pkg_with_main);
    return package;
}

static ZigPackage *create_test_runner_pkg(CodeGen *g) {
    return codegen_create_package(g, buf_ptr(g->zig_std_special_dir), "test_runner.zig", "std.special");
}

static ZigPackage *create_panic_pkg(CodeGen *g) {
    return codegen_create_package(g, buf_ptr(g->zig_std_special_dir), "panic.zig", "std.special");
}

static void create_test_compile_var_and_add_test_runner(CodeGen *g) {
    Error err;

    assert(g->is_test_build);

    if (g->test_fns.length == 0) {
        fprintf(stderr, "No tests to run.\n");
        exit(0);
    }

    ZigType *fn_type = get_test_fn_type(g);

    ConstExprValue *test_fn_type_val = get_builtin_value(g, "TestFn");
    assert(test_fn_type_val->type->id == ZigTypeIdMetaType);
    ZigType *struct_type = test_fn_type_val->data.x_type;
    if ((err = type_resolve(g, struct_type, ResolveStatusSizeKnown)))
        zig_unreachable();

    ConstExprValue *test_fn_array = create_const_vals(1);
    test_fn_array->type = get_array_type(g, struct_type, g->test_fns.length);
    test_fn_array->special = ConstValSpecialStatic;
    test_fn_array->data.x_array.data.s_none.elements = create_const_vals(g->test_fns.length);

    for (size_t i = 0; i < g->test_fns.length; i += 1) {
        ZigFn *test_fn_entry = g->test_fns.at(i);

        ConstExprValue *this_val = &test_fn_array->data.x_array.data.s_none.elements[i];
        this_val->special = ConstValSpecialStatic;
        this_val->type = struct_type;
        this_val->parent.id = ConstParentIdArray;
        this_val->parent.data.p_array.array_val = test_fn_array;
        this_val->parent.data.p_array.elem_index = i;
        this_val->data.x_struct.fields = create_const_vals(2);

        ConstExprValue *name_field = &this_val->data.x_struct.fields[0];
        ConstExprValue *name_array_val = create_const_str_lit(g, &test_fn_entry->symbol_name);
        init_const_slice(g, name_field, name_array_val, 0, buf_len(&test_fn_entry->symbol_name), true);

        ConstExprValue *fn_field = &this_val->data.x_struct.fields[1];
        fn_field->type = fn_type;
        fn_field->special = ConstValSpecialStatic;
        fn_field->data.x_ptr.special = ConstPtrSpecialFunction;
        fn_field->data.x_ptr.mut = ConstPtrMutComptimeConst;
        fn_field->data.x_ptr.data.fn.fn_entry = test_fn_entry;
    }

    ConstExprValue *test_fn_slice = create_const_slice(g, test_fn_array, 0, g->test_fns.length, true);

    update_compile_var(g, buf_create_from_str("test_functions"), test_fn_slice);
    g->test_runner_package = create_test_runner_pkg(g);
    g->test_runner_import = add_special_code(g, g->test_runner_package, "test_runner.zig");
}

static Buf *get_resolved_root_src_path(CodeGen *g) {
    // TODO memoize
    if (buf_len(&g->root_package->root_src_path) == 0)
        return nullptr;

    Buf rel_full_path = BUF_INIT;
    os_path_join(&g->root_package->root_src_dir, &g->root_package->root_src_path, &rel_full_path);

    Buf *resolved_path = buf_alloc();
    Buf *resolve_paths[] = {&rel_full_path};
    *resolved_path = os_path_resolve(resolve_paths, 1);

    return resolved_path;
}

static bool want_startup_code(CodeGen *g) {
    // Test builds get handled separately.
    if (g->is_test_build)
        return false;

    // start code does not handle UEFI target
    if (g->zig_target->os == OsUefi)
        return false;

    // WASM freestanding can still have an entry point but other freestanding targets do not.
    if (g->zig_target->os == OsFreestanding && !target_is_wasm(g->zig_target))
        return false;

    // Declaring certain export functions means skipping the start code
    if (g->have_c_main || g->have_winmain || g->have_winmain_crt_startup)
        return false;

    // If there is a pub main in the root source file, that means we need start code.
    if (g->have_pub_main)
        return true;

    if (g->out_type == OutTypeExe) {
        // For build-exe, we might add start code even though there is no pub main, so that the
        // programmer gets the "no pub main" compile error. However if linking libc and there is
        // a C source file, that might have main().
        return g->c_source_files.length == 0 || g->libc_link_lib == nullptr;
    }

    // For objects and libraries, and we don't have pub main, no start code.
    return false;
}

static void gen_root_source(CodeGen *g) {
    Buf *resolved_path = get_resolved_root_src_path(g);
    if (resolved_path == nullptr)
        return;

    Buf *source_code = buf_alloc();
    Error err;
    // No need for using the caching system for this file fetch because it is handled
    // separately.
    if ((err = os_fetch_file_path(resolved_path, source_code))) {
        fprintf(stderr, "unable to open '%s': %s\n", buf_ptr(resolved_path), err_str(err));
        exit(1);
    }

    ZigType *root_import_alias = add_source_file(g, g->root_package, resolved_path, source_code, SourceKindRoot);
    assert(root_import_alias == g->root_import);

    assert(g->root_out_name);
    assert(g->out_type != OutTypeUnknown);

    if (!g->is_dummy_so) {
        // Zig has lazy top level definitions. Here we semantically analyze the panic function.
        ZigType *import_with_panic;
        if (g->have_pub_panic) {
            import_with_panic = g->root_import;
        } else {
            g->panic_package = create_panic_pkg(g);
            import_with_panic = add_special_code(g, g->panic_package, "panic.zig");
        }
        Tld *panic_tld = find_decl(g, &get_container_scope(import_with_panic)->base, buf_create_from_str("panic"));
        assert(panic_tld != nullptr);
        resolve_top_level_decl(g, panic_tld, nullptr);
    }


    if (!g->error_during_imports) {
        semantic_analyze(g);
    }
    report_errors_and_maybe_exit(g);

    if (want_startup_code(g)) {
        g->start_import = add_special_code(g, create_start_pkg(g, g->root_package), "start.zig");
    }
    if (g->zig_target->os == OsWindows && !g->have_dllmain_crt_startup &&
            g->out_type == OutTypeLib && g->is_dynamic)
    {
        g->start_import = add_special_code(g, create_start_pkg(g, g->root_package), "start_lib.zig");
    }

    if (!g->error_during_imports) {
        semantic_analyze(g);
    }
    if (g->is_test_build) {
        create_test_compile_var_and_add_test_runner(g);
        g->start_import = add_special_code(g, create_start_pkg(g, g->test_runner_package), "start.zig");

        if (!g->error_during_imports) {
            semantic_analyze(g);
        }
    }

    if (!g->is_dummy_so) {
        typecheck_panic_fn(g, g->panic_tld_fn, g->panic_fn);
    }

    report_errors_and_maybe_exit(g);

}

static void print_zig_cc_cmd(ZigList<const char *> *args) {
    for (size_t arg_i = 0; arg_i < args->length; arg_i += 1) {
        const char *space_str = (arg_i == 0) ? "" : " ";
        fprintf(stderr, "%s%s", space_str, args->at(arg_i));
    }
    fprintf(stderr, "\n");
}

// Caller should delete the file when done or rename it into a better location.
static Error get_tmp_filename(CodeGen *g, Buf *out, Buf *suffix) {
    Error err;
    buf_resize(out, 0);
    os_path_join(g->cache_dir, buf_create_from_str("tmp" OS_SEP), out);
    if ((err = os_make_path(out))) {
        return err;
    }
    const char base64[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    assert(array_length(base64) == 64 + 1);
    for (size_t i = 0; i < 12; i += 1) {
        buf_append_char(out, base64[rand() % 64]);
    }
    buf_append_char(out, '-');
    buf_append_buf(out, suffix);
    return ErrorNone;
}

Error create_c_object_cache(CodeGen *g, CacheHash **out_cache_hash, bool verbose) {
    Error err;
    CacheHash *cache_hash = allocate<CacheHash>(1);
    Buf *manifest_dir = buf_sprintf("%s" OS_SEP CACHE_HASH_SUBDIR, buf_ptr(g->cache_dir));
    cache_init(cache_hash, manifest_dir);

    Buf *compiler_id;
    if ((err = get_compiler_id(&compiler_id))) {
        if (verbose) {
            fprintf(stderr, "unable to get compiler id: %s\n", err_str(err));
        }
        return err;
    }
    cache_buf(cache_hash, compiler_id);
    cache_int(cache_hash, g->err_color);
    cache_buf(cache_hash, g->zig_c_headers_dir);
    cache_list_of_buf(cache_hash, g->libc_include_dir_list, g->libc_include_dir_len);
    cache_int(cache_hash, g->zig_target->is_native);
    cache_int(cache_hash, g->zig_target->arch);
    cache_int(cache_hash, g->zig_target->sub_arch);
    cache_int(cache_hash, g->zig_target->vendor);
    cache_int(cache_hash, g->zig_target->os);
    cache_int(cache_hash, g->zig_target->abi);
    cache_bool(cache_hash, g->strip_debug_symbols);
    cache_int(cache_hash, g->build_mode);
    cache_bool(cache_hash, g->have_pic);
    cache_bool(cache_hash, want_valgrind_support(g));
    cache_bool(cache_hash, g->function_sections);
    for (size_t arg_i = 0; arg_i < g->clang_argv_len; arg_i += 1) {
        cache_str(cache_hash, g->clang_argv[arg_i]);
    }

    *out_cache_hash = cache_hash;
    return ErrorNone;
}

// returns true if it was a cache miss
static void gen_c_object(CodeGen *g, Buf *self_exe_path, CFile *c_file) {
    Error err;

    Buf *artifact_dir;
    Buf *o_final_path;

    Buf *o_dir = buf_sprintf("%s" OS_SEP CACHE_OUT_SUBDIR, buf_ptr(g->cache_dir));

    Buf *c_source_file = buf_create_from_str(c_file->source_path);
    Buf *c_source_basename = buf_alloc();
    os_path_split(c_source_file, nullptr, c_source_basename);
    Buf *final_o_basename = buf_alloc();
    os_path_extname(c_source_basename, final_o_basename, nullptr);
    buf_append_str(final_o_basename, target_o_file_ext(g->zig_target));

    CacheHash *cache_hash;
    if ((err = create_c_object_cache(g, &cache_hash, true))) {
        // Already printed error; verbose = true
        exit(1);
    }
    cache_file(cache_hash, c_source_file);

    // Note: not directory args, just args that always have a file next
    static const char *file_args[] = {
        "-include",
    };
    for (size_t arg_i = 0; arg_i < c_file->args.length; arg_i += 1) {
        const char *arg = c_file->args.at(arg_i);
        cache_str(cache_hash, arg);
        for (size_t file_arg_i = 0; file_arg_i < array_length(file_args); file_arg_i += 1) {
            if (strcmp(arg, file_args[file_arg_i]) == 0 && arg_i + 1 < c_file->args.length) {
                arg_i += 1;
                cache_file(cache_hash, buf_create_from_str(c_file->args.at(arg_i)));
            }
        }
    }

    Buf digest = BUF_INIT;
    buf_resize(&digest, 0);
    if ((err = cache_hit(cache_hash, &digest))) {
        if (err != ErrorInvalidFormat) {
            if (err == ErrorCacheUnavailable) {
                // already printed error
            } else {
                fprintf(stderr, "unable to check cache when compiling C object: %s\n", err_str(err));
            }
            exit(1);
        }
    }
    bool is_cache_miss = (buf_len(&digest) == 0);
    if (is_cache_miss) {
        // we can't know the digest until we do the C compiler invocation, so we
        // need a tmp filename.
        Buf *out_obj_path = buf_alloc();
        if ((err = get_tmp_filename(g, out_obj_path, final_o_basename))) {
            fprintf(stderr, "unable to create tmp dir: %s\n", err_str(err));
            exit(1);
        }

        Termination term;
        ZigList<const char *> args = {};
        args.append(buf_ptr(self_exe_path));
        args.append("cc");

        Buf *out_dep_path = buf_sprintf("%s.d", buf_ptr(out_obj_path));
        add_cc_args(g, args, buf_ptr(out_dep_path), false);

        args.append("-o");
        args.append(buf_ptr(out_obj_path));

        args.append("-c");
        args.append(buf_ptr(c_source_file));

        for (size_t arg_i = 0; arg_i < c_file->args.length; arg_i += 1) {
            args.append(c_file->args.at(arg_i));
        }

        if (g->verbose_cc) {
            print_zig_cc_cmd(&args);
        }
        os_spawn_process(args, &term);
        if (term.how != TerminationIdClean || term.code != 0) {
            fprintf(stderr, "\nThe following command failed:\n");
            print_zig_cc_cmd(&args);
            exit(1);
        }

        // add the files depended on to the cache system
        if ((err = cache_add_dep_file(cache_hash, out_dep_path, true))) {
            // Don't treat the absence of the .d file as a fatal error, the
            // compiler may not produce one eg. when compiling .s files
            if (err != ErrorFileNotFound) {
                fprintf(stderr, "Failed to add C source dependencies to cache: %s\n", err_str(err));
                exit(1);
            }
        }
        if (err != ErrorFileNotFound) {
            os_delete_file(out_dep_path);
        }

        if ((err = cache_final(cache_hash, &digest))) {
            fprintf(stderr, "Unable to finalize cache hash: %s\n", err_str(err));
            exit(1);
        }
        artifact_dir = buf_alloc();
        os_path_join(o_dir, &digest, artifact_dir);
        if ((err = os_make_path(artifact_dir))) {
            fprintf(stderr, "Unable to create output directory '%s': %s",
                    buf_ptr(artifact_dir), err_str(err));
            exit(1);
        }
        o_final_path = buf_alloc();
        os_path_join(artifact_dir, final_o_basename, o_final_path);
        if ((err = os_rename(out_obj_path, o_final_path))) {
            fprintf(stderr, "Unable to rename object: %s\n", err_str(err));
            exit(1);
        }
    } else {
        // cache hit
        artifact_dir = buf_alloc();
        os_path_join(o_dir, &digest, artifact_dir);
        o_final_path = buf_alloc();
        os_path_join(artifact_dir, final_o_basename, o_final_path);
    }

    g->link_objects.append(o_final_path);
    g->caches_to_release.append(cache_hash);
}

// returns true if we had any cache misses
static void gen_c_objects(CodeGen *g) {
    Error err;

    if (g->c_source_files.length == 0)
        return;

    Buf *self_exe_path = buf_alloc();
    if ((err = os_self_exe_path(self_exe_path))) {
        fprintf(stderr, "Unable to get self exe path: %s\n", err_str(err));
        exit(1);
    }

    codegen_add_time_event(g, "Compile C Code");

    for (size_t c_file_i = 0; c_file_i < g->c_source_files.length; c_file_i += 1) {
        CFile *c_file = g->c_source_files.at(c_file_i);
        gen_c_object(g, self_exe_path, c_file);
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

struct GenH {
    ZigList<ZigType *> types_to_declare;
};

static void prepend_c_type_to_decl_list(CodeGen *g, GenH *gen_h, ZigType *type_entry) {
    if (type_entry->gen_h_loop_flag)
        return;
    type_entry->gen_h_loop_flag = true;

    switch (type_entry->id) {
        case ZigTypeIdInvalid:
        case ZigTypeIdMetaType:
        case ZigTypeIdComptimeFloat:
        case ZigTypeIdComptimeInt:
        case ZigTypeIdEnumLiteral:
        case ZigTypeIdUndefined:
        case ZigTypeIdNull:
        case ZigTypeIdBoundFn:
        case ZigTypeIdArgTuple:
        case ZigTypeIdErrorUnion:
        case ZigTypeIdErrorSet:
        case ZigTypeIdPromise:
            zig_unreachable();
        case ZigTypeIdVoid:
        case ZigTypeIdUnreachable:
        case ZigTypeIdBool:
        case ZigTypeIdInt:
        case ZigTypeIdFloat:
            return;
        case ZigTypeIdOpaque:
            gen_h->types_to_declare.append(type_entry);
            return;
        case ZigTypeIdStruct:
            for (uint32_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
                TypeStructField *field = &type_entry->data.structure.fields[i];
                prepend_c_type_to_decl_list(g, gen_h, field->type_entry);
            }
            gen_h->types_to_declare.append(type_entry);
            return;
        case ZigTypeIdUnion:
            for (uint32_t i = 0; i < type_entry->data.unionation.src_field_count; i += 1) {
                TypeUnionField *field = &type_entry->data.unionation.fields[i];
                prepend_c_type_to_decl_list(g, gen_h, field->type_entry);
            }
            gen_h->types_to_declare.append(type_entry);
            return;
        case ZigTypeIdEnum:
            prepend_c_type_to_decl_list(g, gen_h, type_entry->data.enumeration.tag_int_type);
            gen_h->types_to_declare.append(type_entry);
            return;
        case ZigTypeIdPointer:
            prepend_c_type_to_decl_list(g, gen_h, type_entry->data.pointer.child_type);
            return;
        case ZigTypeIdArray:
            prepend_c_type_to_decl_list(g, gen_h, type_entry->data.array.child_type);
            return;
        case ZigTypeIdVector:
            prepend_c_type_to_decl_list(g, gen_h, type_entry->data.vector.elem_type);
            return;
        case ZigTypeIdOptional:
            prepend_c_type_to_decl_list(g, gen_h, type_entry->data.maybe.child_type);
            return;
        case ZigTypeIdFn:
            for (size_t i = 0; i < type_entry->data.fn.fn_type_id.param_count; i += 1) {
                prepend_c_type_to_decl_list(g, gen_h, type_entry->data.fn.fn_type_id.param_info[i].type);
            }
            prepend_c_type_to_decl_list(g, gen_h, type_entry->data.fn.fn_type_id.return_type);
            return;
    }
}

static void get_c_type(CodeGen *g, GenH *gen_h, ZigType *type_entry, Buf *out_buf) {
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

    prepend_c_type_to_decl_list(g, gen_h, type_entry);

    switch (type_entry->id) {
        case ZigTypeIdVoid:
            buf_init_from_str(out_buf, "void");
            break;
        case ZigTypeIdBool:
            buf_init_from_str(out_buf, "bool");
            g->c_want_stdbool = true;
            break;
        case ZigTypeIdUnreachable:
            buf_init_from_str(out_buf, "__attribute__((__noreturn__)) void");
            break;
        case ZigTypeIdFloat:
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
        case ZigTypeIdInt:
            g->c_want_stdint = true;
            buf_resize(out_buf, 0);
            buf_appendf(out_buf, "%sint%" PRIu32 "_t",
                    type_entry->data.integral.is_signed ? "" : "u",
                    type_entry->data.integral.bit_count);
            break;
        case ZigTypeIdPointer:
            {
                Buf child_buf = BUF_INIT;
                ZigType *child_type = type_entry->data.pointer.child_type;
                get_c_type(g, gen_h, child_type, &child_buf);

                const char *const_str = type_entry->data.pointer.is_const ? "const " : "";
                buf_resize(out_buf, 0);
                buf_appendf(out_buf, "%s%s *", const_str, buf_ptr(&child_buf));
                break;
            }
        case ZigTypeIdOptional:
            {
                ZigType *child_type = type_entry->data.maybe.child_type;
                if (!type_has_bits(child_type)) {
                    buf_init_from_str(out_buf, "bool");
                    return;
                } else if (type_is_nonnull_ptr(child_type)) {
                    return get_c_type(g, gen_h, child_type, out_buf);
                } else {
                    zig_unreachable();
                }
            }
        case ZigTypeIdStruct:
        case ZigTypeIdOpaque:
            {
                buf_init_from_str(out_buf, "struct ");
                buf_append_buf(out_buf, type_h_name(type_entry));
                return;
            }
        case ZigTypeIdUnion:
            {
                buf_init_from_str(out_buf, "union ");
                buf_append_buf(out_buf, type_h_name(type_entry));
                return;
            }
        case ZigTypeIdEnum:
            {
                buf_init_from_str(out_buf, "enum ");
                buf_append_buf(out_buf, type_h_name(type_entry));
                return;
            }
        case ZigTypeIdArray:
            {
                ZigTypeArray *array_data = &type_entry->data.array;

                Buf *child_buf = buf_alloc();
                get_c_type(g, gen_h, array_data->child_type, child_buf);

                buf_resize(out_buf, 0);
                buf_appendf(out_buf, "%s", buf_ptr(child_buf));
                return;
            }
        case ZigTypeIdVector:
            zig_panic("TODO implement get_c_type for vector types");
        case ZigTypeIdErrorUnion:
        case ZigTypeIdErrorSet:
        case ZigTypeIdFn:
            zig_panic("TODO implement get_c_type for more types");
        case ZigTypeIdInvalid:
        case ZigTypeIdMetaType:
        case ZigTypeIdBoundFn:
        case ZigTypeIdComptimeFloat:
        case ZigTypeIdComptimeInt:
        case ZigTypeIdEnumLiteral:
        case ZigTypeIdUndefined:
        case ZigTypeIdNull:
        case ZigTypeIdArgTuple:
        case ZigTypeIdPromise:
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
    GenH gen_h_data = {0};
    GenH *gen_h = &gen_h_data;

    assert(!g->is_test_build);
    assert(!g->disable_gen_h);

    Buf *out_h_path = buf_sprintf("%s" OS_SEP "%s.h", buf_ptr(g->output_dir), buf_ptr(g->root_out_name));

    FILE *out_h = fopen(buf_ptr(out_h_path), "wb");
    if (!out_h)
        zig_panic("unable to open %s: %s\n", buf_ptr(out_h_path), strerror(errno));

    Buf *export_macro = nullptr;
    if (g->is_dynamic) {
        export_macro = preprocessor_mangle(buf_sprintf("%s_EXPORT", buf_ptr(g->root_out_name)));
        buf_upcase(export_macro);
    }

    Buf *extern_c_macro = preprocessor_mangle(buf_sprintf("%s_EXTERN_C", buf_ptr(g->root_out_name)));
    buf_upcase(extern_c_macro);

    Buf h_buf = BUF_INIT;
    buf_resize(&h_buf, 0);
    for (size_t fn_def_i = 0; fn_def_i < g->fn_defs.length; fn_def_i += 1) {
        ZigFn *fn_table_entry = g->fn_defs.at(fn_def_i);

        if (fn_table_entry->export_list.length == 0)
            continue;

        FnTypeId *fn_type_id = &fn_table_entry->type_entry->data.fn.fn_type_id;

        Buf return_type_c = BUF_INIT;
        get_c_type(g, gen_h, fn_type_id->return_type, &return_type_c);

        Buf *symbol_name;
        if (fn_table_entry->export_list.length == 0) {
            symbol_name = &fn_table_entry->symbol_name;
        } else {
            GlobalExport *fn_export = &fn_table_entry->export_list.items[0];
            symbol_name = &fn_export->name;
        }

        buf_appendf(&h_buf, "%s %s %s(",
            buf_ptr(g->is_dynamic ? export_macro : extern_c_macro),
            buf_ptr(&return_type_c),
            buf_ptr(symbol_name));

        Buf param_type_c = BUF_INIT;
        if (fn_type_id->param_count > 0) {
            for (size_t param_i = 0; param_i < fn_type_id->param_count; param_i += 1) {
                FnTypeParamInfo *param_info = &fn_type_id->param_info[param_i];
                AstNode *param_decl_node = get_param_decl_node(fn_table_entry, param_i);
                Buf *param_name = param_decl_node->data.param_decl.name;

                const char *comma_str = (param_i == 0) ? "" : ", ";
                const char *restrict_str = param_info->is_noalias ? "restrict" : "";
                get_c_type(g, gen_h, param_info->type, &param_type_c);

                if (param_info->type->id == ZigTypeIdArray) {
                    // Arrays decay to pointers
                    buf_appendf(&h_buf, "%s%s%s %s[]", comma_str, buf_ptr(&param_type_c),
                            restrict_str, buf_ptr(param_name));
                } else {
                    buf_appendf(&h_buf, "%s%s%s %s", comma_str, buf_ptr(&param_type_c),
                            restrict_str, buf_ptr(param_name));
                }
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

    if (g->is_dynamic) {
        fprintf(out_h, "#if defined(_WIN32)\n");
        fprintf(out_h, "#define %s %s __declspec(dllimport)\n", buf_ptr(export_macro), buf_ptr(extern_c_macro));
        fprintf(out_h, "#else\n");
        fprintf(out_h, "#define %s %s __attribute__((visibility (\"default\")))\n",
            buf_ptr(export_macro), buf_ptr(extern_c_macro));
        fprintf(out_h, "#endif\n");
        fprintf(out_h, "\n");
    }

    for (size_t type_i = 0; type_i < gen_h->types_to_declare.length; type_i += 1) {
        ZigType *type_entry = gen_h->types_to_declare.at(type_i);
        switch (type_entry->id) {
            case ZigTypeIdInvalid:
            case ZigTypeIdMetaType:
            case ZigTypeIdVoid:
            case ZigTypeIdBool:
            case ZigTypeIdUnreachable:
            case ZigTypeIdInt:
            case ZigTypeIdFloat:
            case ZigTypeIdPointer:
            case ZigTypeIdComptimeFloat:
            case ZigTypeIdComptimeInt:
            case ZigTypeIdEnumLiteral:
            case ZigTypeIdArray:
            case ZigTypeIdUndefined:
            case ZigTypeIdNull:
            case ZigTypeIdErrorUnion:
            case ZigTypeIdErrorSet:
            case ZigTypeIdBoundFn:
            case ZigTypeIdArgTuple:
            case ZigTypeIdOptional:
            case ZigTypeIdFn:
            case ZigTypeIdPromise:
            case ZigTypeIdVector:
                zig_unreachable();
            case ZigTypeIdEnum:
                if (type_entry->data.enumeration.layout == ContainerLayoutExtern) {
                    fprintf(out_h, "enum %s {\n", buf_ptr(type_h_name(type_entry)));
                    for (uint32_t field_i = 0; field_i < type_entry->data.enumeration.src_field_count; field_i += 1) {
                        TypeEnumField *enum_field = &type_entry->data.enumeration.fields[field_i];
                        Buf *value_buf = buf_alloc();
                        bigint_append_buf(value_buf, &enum_field->value, 10);
                        fprintf(out_h, "    %s = %s", buf_ptr(enum_field->name), buf_ptr(value_buf));
                        if (field_i != type_entry->data.enumeration.src_field_count - 1) {
                            fprintf(out_h, ",");
                        }
                        fprintf(out_h, "\n");
                    }
                    fprintf(out_h, "};\n\n");
                } else {
                    fprintf(out_h, "enum %s;\n", buf_ptr(type_h_name(type_entry)));
                }
                break;
            case ZigTypeIdStruct:
                if (type_entry->data.structure.layout == ContainerLayoutExtern) {
                    fprintf(out_h, "struct %s {\n", buf_ptr(type_h_name(type_entry)));
                    for (uint32_t field_i = 0; field_i < type_entry->data.structure.src_field_count; field_i += 1) {
                        TypeStructField *struct_field = &type_entry->data.structure.fields[field_i];

                        Buf *type_name_buf = buf_alloc();
                        get_c_type(g, gen_h, struct_field->type_entry, type_name_buf);

                        if (struct_field->type_entry->id == ZigTypeIdArray) {
                            fprintf(out_h, "    %s %s[%" ZIG_PRI_u64 "];\n", buf_ptr(type_name_buf),
                                    buf_ptr(struct_field->name),
                                    struct_field->type_entry->data.array.len);
                        } else {
                            fprintf(out_h, "    %s %s;\n", buf_ptr(type_name_buf), buf_ptr(struct_field->name));
                        }

                    }
                    fprintf(out_h, "};\n\n");
                } else {
                    fprintf(out_h, "struct %s;\n", buf_ptr(type_h_name(type_entry)));
                }
                break;
            case ZigTypeIdUnion:
                if (type_entry->data.unionation.layout == ContainerLayoutExtern) {
                    fprintf(out_h, "union %s {\n", buf_ptr(type_h_name(type_entry)));
                    for (uint32_t field_i = 0; field_i < type_entry->data.unionation.src_field_count; field_i += 1) {
                        TypeUnionField *union_field = &type_entry->data.unionation.fields[field_i];

                        Buf *type_name_buf = buf_alloc();
                        get_c_type(g, gen_h, union_field->type_entry, type_name_buf);
                        fprintf(out_h, "    %s %s;\n", buf_ptr(type_name_buf), buf_ptr(union_field->name));
                    }
                    fprintf(out_h, "};\n\n");
                } else {
                    fprintf(out_h, "union %s;\n", buf_ptr(type_h_name(type_entry)));
                }
                break;
            case ZigTypeIdOpaque:
                fprintf(out_h, "struct %s;\n\n", buf_ptr(type_h_name(type_entry)));
                break;
        }
    }

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
    OsTimeStamp timestamp = os_timestamp_monotonic();
    double seconds = (double)timestamp.sec;
    seconds += ((double)timestamp.nsec) / 1000000000.0;
    g->timing_events.append({seconds, name});
}

static void add_cache_pkg(CodeGen *g, CacheHash *ch, ZigPackage *pkg) {
    if (buf_len(&pkg->root_src_path) == 0)
        return;
    pkg->added_to_cache = true;

    Buf *rel_full_path = buf_alloc();
    os_path_join(&pkg->root_src_dir, &pkg->root_src_path, rel_full_path);
    cache_file(ch, rel_full_path);

    auto it = pkg->package_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        if (!pkg->added_to_cache) {
            cache_buf(ch, entry->key);
            add_cache_pkg(g, ch, entry->value);
        }
    }
}

// Called before init()
// is_cache_hit takes into account gen_c_objects
static Error check_cache(CodeGen *g, Buf *manifest_dir, Buf *digest) {
    Error err;

    Buf *compiler_id;
    if ((err = get_compiler_id(&compiler_id)))
        return err;

    CacheHash *ch = &g->cache_hash;
    cache_init(ch, manifest_dir);

    add_cache_pkg(g, ch, g->root_package);
    if (g->linker_script != nullptr) {
        cache_file(ch, buf_create_from_str(g->linker_script));
    }
    cache_buf(ch, compiler_id);
    cache_buf(ch, g->root_out_name);
    cache_buf(ch, g->zig_lib_dir);
    cache_buf(ch, g->zig_std_dir);
    cache_list_of_link_lib(ch, g->link_libs_list.items, g->link_libs_list.length);
    cache_list_of_buf(ch, g->darwin_frameworks.items, g->darwin_frameworks.length);
    cache_list_of_buf(ch, g->rpath_list.items, g->rpath_list.length);
    cache_list_of_buf(ch, g->forbidden_libs.items, g->forbidden_libs.length);
    cache_int(ch, g->build_mode);
    cache_int(ch, g->out_type);
    cache_bool(ch, g->zig_target->is_native);
    cache_int(ch, g->zig_target->arch);
    cache_int(ch, g->zig_target->sub_arch);
    cache_int(ch, g->zig_target->vendor);
    cache_int(ch, g->zig_target->os);
    cache_int(ch, g->zig_target->abi);
    if (g->zig_target->glibc_version != nullptr) {
        cache_int(ch, g->zig_target->glibc_version->major);
        cache_int(ch, g->zig_target->glibc_version->minor);
        cache_int(ch, g->zig_target->glibc_version->patch);
    }
    cache_int(ch, detect_subsystem(g));
    cache_bool(ch, g->strip_debug_symbols);
    cache_bool(ch, g->is_test_build);
    if (g->is_test_build) {
        cache_buf_opt(ch, g->test_filter);
        cache_buf_opt(ch, g->test_name_prefix);
    }
    cache_bool(ch, g->is_single_threaded);
    cache_bool(ch, g->linker_rdynamic);
    cache_bool(ch, g->each_lib_rpath);
    cache_bool(ch, g->disable_gen_h);
    cache_bool(ch, g->bundle_compiler_rt);
    cache_bool(ch, want_valgrind_support(g));
    cache_bool(ch, g->have_pic);
    cache_bool(ch, g->have_dynamic_link);
    cache_bool(ch, g->have_stack_probing);
    cache_bool(ch, g->is_dummy_so);
    cache_bool(ch, g->function_sections);
    cache_buf_opt(ch, g->mmacosx_version_min);
    cache_buf_opt(ch, g->mios_version_min);
    cache_usize(ch, g->version_major);
    cache_usize(ch, g->version_minor);
    cache_usize(ch, g->version_patch);
    cache_list_of_str(ch, g->llvm_argv, g->llvm_argv_len);
    cache_list_of_str(ch, g->clang_argv, g->clang_argv_len);
    cache_list_of_str(ch, g->lib_dirs.items, g->lib_dirs.length);
    if (g->libc) {
        cache_buf(ch, &g->libc->include_dir);
        cache_buf(ch, &g->libc->sys_include_dir);
        cache_buf(ch, &g->libc->crt_dir);
        cache_buf(ch, &g->libc->msvc_lib_dir);
        cache_buf(ch, &g->libc->kernel32_lib_dir);
    }
    cache_buf_opt(ch, g->dynamic_linker_path);
    cache_buf_opt(ch, g->version_script_path);

    // gen_c_objects appends objects to g->link_objects which we want to include in the hash
    gen_c_objects(g);
    cache_list_of_file(ch, g->link_objects.items, g->link_objects.length);

    buf_resize(digest, 0);
    if ((err = cache_hit(ch, digest))) {
        if (err != ErrorInvalidFormat)
            return err;
    }

    if (ch->manifest_file_path != nullptr) {
        g->caches_to_release.append(ch);
    }

    return ErrorNone;
}

static bool need_llvm_module(CodeGen *g) {
    return buf_len(&g->root_package->root_src_path) != 0;
}

static void resolve_out_paths(CodeGen *g) {
    assert(g->output_dir != nullptr);
    assert(g->root_out_name != nullptr);

    Buf *out_basename = buf_create_from_buf(g->root_out_name);
    Buf *o_basename = buf_create_from_buf(g->root_out_name);
    switch (g->emit_file_type) {
        case EmitFileTypeBinary: {
            switch (g->out_type) {
                case OutTypeUnknown:
                    zig_unreachable();
                case OutTypeObj:
                    if (g->enable_cache && g->link_objects.length == 1 && !need_llvm_module(g)) {
                        buf_init_from_buf(&g->output_file_path, g->link_objects.at(0));
                        return;
                    }
                    if (need_llvm_module(g) && g->link_objects.length != 0 && !g->enable_cache &&
                        buf_eql_buf(o_basename, out_basename))
                    {
                        // make it not collide with main output object
                        buf_append_str(o_basename, ".root");
                    }
                    buf_append_str(o_basename, target_o_file_ext(g->zig_target));
                    buf_append_str(out_basename, target_o_file_ext(g->zig_target));
                    break;
                case OutTypeExe:
                    buf_append_str(o_basename, target_o_file_ext(g->zig_target));
                    buf_append_str(out_basename, target_exe_file_ext(g->zig_target));
                    break;
                case OutTypeLib:
                    buf_append_str(o_basename, target_o_file_ext(g->zig_target));
                    buf_resize(out_basename, 0);
                    buf_append_str(out_basename, target_lib_file_prefix(g->zig_target));
                    buf_append_buf(out_basename, g->root_out_name);
                    buf_append_str(out_basename, target_lib_file_ext(g->zig_target, !g->is_dynamic,
                                g->version_major, g->version_minor, g->version_patch));
                    break;
            }
            break;
        }
        case EmitFileTypeAssembly: {
            const char *asm_ext = target_asm_file_ext(g->zig_target);
            buf_append_str(o_basename, asm_ext);
            buf_append_str(out_basename, asm_ext);
            break;
        }
        case EmitFileTypeLLVMIr: {
            const char *llvm_ir_ext = target_llvm_ir_file_ext(g->zig_target);
            buf_append_str(o_basename, llvm_ir_ext);
            buf_append_str(out_basename, llvm_ir_ext);
            break;
        }
    }

    os_path_join(g->output_dir, o_basename, &g->o_file_output_path);
    os_path_join(g->output_dir, out_basename, &g->output_file_path);
}

void codegen_build_and_link(CodeGen *g) {
    Error err;
    assert(g->out_type != OutTypeUnknown);

    if (!g->enable_cache && g->output_dir == nullptr) {
        g->output_dir = buf_create_from_str(".");
    }

    g->have_dynamic_link = detect_dynamic_link(g);
    g->have_pic = detect_pic(g);
    g->is_single_threaded = detect_single_threaded(g);
    g->have_err_ret_tracing = detect_err_ret_tracing(g);
    detect_libc(g);
    detect_dynamic_linker(g);

    Buf digest = BUF_INIT;
    if (g->enable_cache) {
        Buf *manifest_dir = buf_alloc();
        os_path_join(g->cache_dir, buf_create_from_str(CACHE_HASH_SUBDIR), manifest_dir);

        if ((err = check_cache(g, manifest_dir, &digest))) {
            if (err == ErrorCacheUnavailable) {
                // message already printed
            } else if (err == ErrorNotDir) {
                fprintf(stderr, "Unable to check cache: %s is not a directory\n",
                    buf_ptr(manifest_dir));
            } else {
                fprintf(stderr, "Unable to check cache: %s: %s\n", buf_ptr(manifest_dir), err_str(err));
            }
            exit(1);
        }
    } else {
        // There is a call to this in check_cache
        gen_c_objects(g);
    }

    if (g->enable_cache && buf_len(&digest) != 0) {
        g->output_dir = buf_sprintf("%s" OS_SEP CACHE_OUT_SUBDIR OS_SEP "%s",
                buf_ptr(g->cache_dir), buf_ptr(&digest));
        resolve_out_paths(g);
    } else {
        if (need_llvm_module(g)) {
            init(g);

            codegen_add_time_event(g, "Semantic Analysis");

            gen_root_source(g);

        }
        if (g->enable_cache) {
            if (buf_len(&digest) == 0) {
                if ((err = cache_final(&g->cache_hash, &digest))) {
                    fprintf(stderr, "Unable to finalize cache hash: %s\n", err_str(err));
                    exit(1);
                }
            }
            g->output_dir = buf_sprintf("%s" OS_SEP CACHE_OUT_SUBDIR OS_SEP "%s",
                    buf_ptr(g->cache_dir), buf_ptr(&digest));

            if ((err = os_make_path(g->output_dir))) {
                fprintf(stderr, "Unable to create output directory: %s\n", err_str(err));
                exit(1);
            }
        }
        resolve_out_paths(g);

        if (need_llvm_module(g)) {
            codegen_add_time_event(g, "Code Generation");

            do_code_gen(g);
            codegen_add_time_event(g, "LLVM Emit Output");
            zig_llvm_emit_output(g);

            if (!g->disable_gen_h && (g->out_type == OutTypeObj || g->out_type == OutTypeLib)) {
                codegen_add_time_event(g, "Generate .h");
                gen_h_file(g);
            }
        }

        // If we're outputting assembly or llvm IR we skip linking.
        // If we're making a library or executable we must link.
        // If there is more than one object, we have to link them (with -r).
        // Finally, if we didn't make an object from zig source, and we don't have caching enabled,
        // then we have an object from C source that we must copy to the output dir which we do with a -r link.
        if (g->emit_file_type == EmitFileTypeBinary && (g->out_type != OutTypeObj || g->link_objects.length > 1 ||
                    (!need_llvm_module(g) && !g->enable_cache)))
        {
            codegen_link(g);
        }
    }

    codegen_release_caches(g);
    codegen_add_time_event(g, "Done");
}

void codegen_release_caches(CodeGen *g) {
    while (g->caches_to_release.length != 0) {
        cache_release(g->caches_to_release.pop());
    }
}

ZigPackage *codegen_create_package(CodeGen *g, const char *root_src_dir, const char *root_src_path,
        const char *pkg_path)
{
    init(g);
    ZigPackage *pkg = new_package(root_src_dir, root_src_path, pkg_path);
    if (g->std_package != nullptr) {
        assert(g->compile_var_package != nullptr);
        pkg->package_table.put(buf_create_from_str("std"), g->std_package);

        ZigPackage *main_pkg = g->is_test_build ? g->test_runner_package : g->root_package;
        pkg->package_table.put(buf_create_from_str("root"), main_pkg);

        pkg->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    }
    return pkg;
}

CodeGen *create_child_codegen(CodeGen *parent_gen, Buf *root_src_path, OutType out_type,
        ZigLibCInstallation *libc)
{
    CodeGen *child_gen = codegen_create(nullptr, root_src_path, parent_gen->zig_target, out_type,
        parent_gen->build_mode, parent_gen->zig_lib_dir, parent_gen->zig_std_dir, libc, get_stage1_cache_path());
    child_gen->disable_gen_h = true;
    child_gen->want_stack_check = WantStackCheckDisabled;
    child_gen->verbose_tokenize = parent_gen->verbose_tokenize;
    child_gen->verbose_ast = parent_gen->verbose_ast;
    child_gen->verbose_link = parent_gen->verbose_link;
    child_gen->verbose_ir = parent_gen->verbose_ir;
    child_gen->verbose_llvm_ir = parent_gen->verbose_llvm_ir;
    child_gen->verbose_cimport = parent_gen->verbose_cimport;
    child_gen->verbose_cc = parent_gen->verbose_cc;
    child_gen->llvm_argv = parent_gen->llvm_argv;
    child_gen->dynamic_linker_path = parent_gen->dynamic_linker_path;

    codegen_set_strip(child_gen, parent_gen->strip_debug_symbols);
    child_gen->want_pic = parent_gen->have_pic ? WantPICEnabled : WantPICDisabled;
    child_gen->valgrind_support = ValgrindSupportDisabled;

    codegen_set_errmsg_color(child_gen, parent_gen->err_color);

    codegen_set_mmacosx_version_min(child_gen, parent_gen->mmacosx_version_min);
    codegen_set_mios_version_min(child_gen, parent_gen->mios_version_min);

    child_gen->enable_cache = true;

    return child_gen;
}

