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
#include "target.hpp"
#include "util.hpp"
#include "zig_llvm.h"
#include "stage2.h"
#include "dump_analysis.hpp"
#include "softfloat.hpp"
#include "mem_profile.hpp"

#include <stdio.h>
#include <errno.h>

enum ResumeId {
    ResumeIdManual,
    ResumeIdReturn,
    ResumeIdCall,
};

static ZigPackage *new_package(const char *root_src_dir, const char *root_src_path, const char *pkg_path) {
    ZigPackage *entry = heap::c_allocator.create<ZigPackage>();
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

void codegen_set_rdynamic(CodeGen *g, bool rdynamic) {
    g->linker_rdynamic = rdynamic;
}

void codegen_set_linker_script(CodeGen *g, const char *linker_script) {
    g->linker_script = linker_script;
}


static void render_const_val(CodeGen *g, ZigValue *const_val, const char *name);
static void render_const_val_global(CodeGen *g, ZigValue *const_val, const char *name);
static LLVMValueRef gen_const_val(CodeGen *g, ZigValue *const_val, const char *name);
static void generate_error_name_table(CodeGen *g);
static bool value_is_all_undef(CodeGen *g, ZigValue *const_val);
static void gen_undef_init(CodeGen *g, uint32_t ptr_align_bytes, ZigType *value_type, LLVMValueRef ptr);
static LLVMValueRef build_alloca(CodeGen *g, ZigType *type_entry, const char *name, uint32_t alignment);
static LLVMValueRef gen_await_early_return(CodeGen *g, IrInstGen *source_instr,
        LLVMValueRef target_frame_ptr, ZigType *result_type, ZigType *ptr_result_type,
        LLVMValueRef result_loc, bool non_async);
static Error get_tmp_filename(CodeGen *g, Buf *out, Buf *suffix);

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

static bool is_symbol_available(CodeGen *g, const char *name) {
    Buf *buf_name = buf_create_from_str(name);
    bool result =
        g->exported_symbol_names.maybe_get(buf_name) == nullptr &&
        g->external_symbol_names.maybe_get(buf_name) == nullptr;
    buf_destroy(buf_name);
    return result;
}

static const char *get_mangled_name(CodeGen *g, const char *original_name) {
    if (is_symbol_available(g, original_name))
        return original_name;

    int n = 0;
    for (;; n += 1) {
        const char *new_name = buf_ptr(buf_sprintf("%s.%d", original_name, n));
        if (is_symbol_available(g, new_name)) {
            return new_name;
        }
    }
}

static ZigLLVM_CallingConv get_llvm_cc(CodeGen *g, CallingConvention cc) {
    switch (cc) {
        case CallingConventionUnspecified:
            return ZigLLVM_Fast;
        case CallingConventionC:
            return ZigLLVM_C;
        case CallingConventionCold:
            if ((g->zig_target->arch == ZigLLVM_x86 ||
                 g->zig_target->arch == ZigLLVM_x86_64) &&
                g->zig_target->os != OsWindows)
                return ZigLLVM_Cold;
            return ZigLLVM_C;
        case CallingConventionNaked:
            zig_unreachable();
        case CallingConventionStdcall:
            if (g->zig_target->arch == ZigLLVM_x86)
                return ZigLLVM_X86_StdCall;
            return ZigLLVM_C;
        case CallingConventionFastcall:
            if (g->zig_target->arch == ZigLLVM_x86)
                return ZigLLVM_X86_FastCall;
            return ZigLLVM_C;
        case CallingConventionVectorcall:
            if (g->zig_target->arch == ZigLLVM_x86)
                return ZigLLVM_X86_VectorCall;
            if (target_is_arm(g->zig_target) &&
                target_arch_pointer_bit_width(g->zig_target->arch) == 64)
                return ZigLLVM_AArch64_VectorCall;
            return ZigLLVM_C;
        case CallingConventionThiscall:
            if (g->zig_target->arch == ZigLLVM_x86)
                return ZigLLVM_X86_ThisCall;
            return ZigLLVM_C;
        case CallingConventionAsync:
            return ZigLLVM_Fast;
        case CallingConventionAPCS:
            if (target_is_arm(g->zig_target))
                return ZigLLVM_ARM_APCS;
            return ZigLLVM_C;
        case CallingConventionAAPCS:
            if (target_is_arm(g->zig_target))
                return ZigLLVM_ARM_AAPCS;
            return ZigLLVM_C;
        case CallingConventionAAPCSVFP:
            if (target_is_arm(g->zig_target))
                return ZigLLVM_ARM_AAPCS_VFP;
            return ZigLLVM_C;
        case CallingConventionInterrupt:
            if (g->zig_target->arch == ZigLLVM_x86 ||
                g->zig_target->arch == ZigLLVM_x86_64)
                return ZigLLVM_X86_INTR;
            if (g->zig_target->arch == ZigLLVM_avr)
                return ZigLLVM_AVR_INTR;
            if (g->zig_target->arch == ZigLLVM_msp430)
                return ZigLLVM_MSP430_INTR;
            return ZigLLVM_C;
        case CallingConventionSignal:
            if (g->zig_target->arch == ZigLLVM_avr)
                return ZigLLVM_AVR_SIGNAL;
            return ZigLLVM_C;
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

struct CalcLLVMFieldIndex {
    uint32_t offset;
    uint32_t field_index;
};

static void calc_llvm_field_index_add(CodeGen *g, CalcLLVMFieldIndex *calc, ZigType *ty) {
    if (!type_has_bits(g, ty)) return;
    uint32_t ty_align = get_abi_alignment(g, ty);
    if (calc->offset % ty_align != 0) {
        uint32_t llvm_align = LLVMABIAlignmentOfType(g->target_data_ref, get_llvm_type(g, ty));
        if (llvm_align >= ty_align) {
            ty_align = llvm_align; // llvm's padding is sufficient
        } else if (calc->offset) {
            calc->field_index += 1; // zig will insert an extra padding field here
        }
        calc->offset += ty_align - (calc->offset % ty_align); // padding bytes
    }
    calc->offset += ty->abi_size;
    calc->field_index += 1;
}

// label (grep this): [fn_frame_struct_layout]
static void frame_index_trace_arg_calc(CodeGen *g, CalcLLVMFieldIndex *calc, ZigType *return_type) {
    calc_llvm_field_index_add(g, calc, g->builtin_types.entry_usize); // function pointer
    calc_llvm_field_index_add(g, calc, g->builtin_types.entry_usize); // resume index
    calc_llvm_field_index_add(g, calc, g->builtin_types.entry_usize); // awaiter index

    if (type_has_bits(g, return_type)) {
        calc_llvm_field_index_add(g, calc, g->builtin_types.entry_usize); // *ReturnType (callee's)
        calc_llvm_field_index_add(g, calc, g->builtin_types.entry_usize); // *ReturnType (awaiter's)
        calc_llvm_field_index_add(g, calc, return_type); // ReturnType
    }
}

static uint32_t frame_index_trace_arg(CodeGen *g, ZigType *return_type) {
    CalcLLVMFieldIndex calc = {0};
    frame_index_trace_arg_calc(g, &calc, return_type);
    return calc.field_index;
}

// label (grep this): [fn_frame_struct_layout]
static void frame_index_arg_calc(CodeGen *g, CalcLLVMFieldIndex *calc, ZigType *return_type) {
    frame_index_trace_arg_calc(g, calc, return_type);

    if (codegen_fn_has_err_ret_tracing_arg(g, return_type)) {
        calc_llvm_field_index_add(g, calc, g->builtin_types.entry_usize); // *StackTrace (callee's)
        calc_llvm_field_index_add(g, calc, g->builtin_types.entry_usize); // *StackTrace (awaiter's)
    }
}

// label (grep this): [fn_frame_struct_layout]
static uint32_t frame_index_trace_stack(CodeGen *g, ZigFn *fn) {
    size_t field_index = 6;
    bool have_stack_trace = codegen_fn_has_err_ret_tracing_arg(g, fn->type_entry->data.fn.fn_type_id.return_type);
    if (have_stack_trace) {
        field_index += 2;
    }
    field_index += fn->type_entry->data.fn.fn_type_id.param_count;
    ZigType *locals_struct = fn->frame_type->data.frame.locals_struct;
    TypeStructField *field = locals_struct->data.structure.fields[field_index];
    return field->gen_index;
}


static uint32_t get_err_ret_trace_arg_index(CodeGen *g, ZigFn *fn_table_entry) {
    if (!g->have_err_ret_tracing) {
        return UINT32_MAX;
    }
    if (fn_is_async(fn_table_entry)) {
        return UINT32_MAX;
    }
    ZigType *fn_type = fn_table_entry->type_entry;
    if (!fn_type_can_fail(&fn_type->data.fn.fn_type_id)) {
        return UINT32_MAX;
    }
    ZigType *return_type = fn_type->data.fn.fn_type_id.return_type;
    bool first_arg_ret = type_has_bits(g, return_type) && handle_is_ptr(g, return_type);
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
        case CallingConventionInterrupt:
        case CallingConventionSignal:
        case CallingConventionStdcall:
        case CallingConventionFastcall:
        case CallingConventionVectorcall:
        case CallingConventionThiscall:
        case CallingConventionAPCS:
        case CallingConventionAAPCS:
        case CallingConventionAAPCSVFP:
            return true;
        case CallingConventionAsync:
        case CallingConventionUnspecified:
            return false;
    }
    zig_unreachable();
}

static bool codegen_have_frame_pointer(CodeGen *g) {
    return g->build_mode == BuildModeDebug;
}

static LLVMValueRef make_fn_llvm_value(CodeGen *g, ZigFn *fn) {
    const char *unmangled_name = buf_ptr(&fn->symbol_name);
    const char *symbol_name;
    GlobalLinkageId linkage;
    if (fn->body_node == nullptr) {
        symbol_name = unmangled_name;
        linkage = GlobalLinkageIdStrong;
    } else if (fn->export_list.length == 0) {
        symbol_name = get_mangled_name(g, unmangled_name);
        linkage = GlobalLinkageIdInternal;
    } else {
        GlobalExport *fn_export = &fn->export_list.items[0];
        symbol_name = buf_ptr(&fn_export->name);
        linkage = fn_export->linkage;
    }

    CallingConvention cc = fn->type_entry->data.fn.fn_type_id.cc;
    bool is_async = fn_is_async(fn);

    ZigType *fn_type = fn->type_entry;
    // Make the raw_type_ref populated
    resolve_llvm_types_fn(g, fn);
    LLVMTypeRef fn_llvm_type = fn->raw_type_ref;
    LLVMValueRef llvm_fn = nullptr;
    if (fn->body_node == nullptr) {
        const unsigned fn_addrspace = ZigLLVMDataLayoutGetProgramAddressSpace(g->target_data_ref);
        LLVMValueRef existing_llvm_fn = LLVMGetNamedFunction(g->module, symbol_name);
        if (existing_llvm_fn) {
            return LLVMConstBitCast(existing_llvm_fn, LLVMPointerType(fn_llvm_type, fn_addrspace));
        } else {
            Buf *buf_symbol_name = buf_create_from_str(symbol_name);
            auto entry = g->exported_symbol_names.maybe_get(buf_symbol_name);
            buf_destroy(buf_symbol_name);

            if (entry == nullptr) {
                llvm_fn = LLVMAddFunction(g->module, symbol_name, fn_llvm_type);

                if (target_is_wasm(g->zig_target)) {
                    assert(fn->proto_node->type == NodeTypeFnProto);
                    AstNodeFnProto *fn_proto = &fn->proto_node->data.fn_proto;
                    if (fn_proto-> is_extern && fn_proto->lib_name != nullptr ) {
                        addLLVMFnAttrStr(llvm_fn, "wasm-import-module", buf_ptr(fn_proto->lib_name));
                    }
                }
            } else {
                assert(entry->value->id == TldIdFn);
                TldFn *tld_fn = reinterpret_cast<TldFn *>(entry->value);
                // Make the raw_type_ref populated
                resolve_llvm_types_fn(g, tld_fn->fn_entry);
                tld_fn->fn_entry->llvm_value = LLVMAddFunction(g->module, symbol_name,
                        tld_fn->fn_entry->raw_type_ref);
                llvm_fn = LLVMConstBitCast(tld_fn->fn_entry->llvm_value, LLVMPointerType(fn_llvm_type, fn_addrspace));
                return llvm_fn;
            }
        }
    } else {
        if (llvm_fn == nullptr) {
            llvm_fn = LLVMAddFunction(g->module, symbol_name, fn_llvm_type);
        }

        for (size_t i = 1; i < fn->export_list.length; i += 1) {
            GlobalExport *fn_export = &fn->export_list.items[i];
            LLVMAddAlias(g->module, LLVMTypeOf(llvm_fn), llvm_fn, buf_ptr(&fn_export->name));
        }
    }

    switch (fn->fn_inline) {
        case FnInlineAlways:
            addLLVMFnAttr(llvm_fn, "alwaysinline");
            g->inline_fns.append(fn);
            break;
        case FnInlineNever:
            addLLVMFnAttr(llvm_fn, "noinline");
            break;
        case FnInlineAuto:
            if (fn->alignstack_value != 0) {
                addLLVMFnAttr(llvm_fn, "noinline");
            }
            break;
    }

    if (cc == CallingConventionNaked) {
        addLLVMFnAttr(llvm_fn, "naked");
    } else {
        ZigLLVMFunctionSetCallingConv(llvm_fn, get_llvm_cc(g, cc));
    }

    bool want_cold = fn->is_cold || cc == CallingConventionCold;
    if (want_cold) {
        ZigLLVMAddFunctionAttrCold(llvm_fn);
    }


    LLVMSetLinkage(llvm_fn, to_llvm_linkage(linkage));

    if (linkage == GlobalLinkageIdInternal) {
        LLVMSetUnnamedAddr(llvm_fn, true);
    }

    ZigType *return_type = fn_type->data.fn.fn_type_id.return_type;
    if (return_type->id == ZigTypeIdUnreachable) {
        addLLVMFnAttr(llvm_fn, "noreturn");
    }

    if (fn->body_node != nullptr) {
        maybe_export_dll(g, llvm_fn, linkage);

        bool want_fn_safety = g->build_mode != BuildModeFastRelease &&
                              g->build_mode != BuildModeSmallRelease &&
                              !fn->def_scope->safety_off;
        if (want_fn_safety) {
            if (g->libc_link_lib != nullptr) {
                addLLVMFnAttr(llvm_fn, "sspstrong");
                addLLVMFnAttrStr(llvm_fn, "stack-protector-buffer-size", "4");
            }
        }
        if (g->have_stack_probing && !fn->def_scope->safety_off) {
            addLLVMFnAttrStr(llvm_fn, "probe-stack", "__zig_probe_stack");
        } else if (g->zig_target->os == OsUefi) {
            addLLVMFnAttrStr(llvm_fn, "no-stack-arg-probe", "");
        }
    } else {
        maybe_import_dll(g, llvm_fn, linkage);
    }

    if (fn->alignstack_value != 0) {
        addLLVMFnAttrInt(llvm_fn, "alignstack", fn->alignstack_value);
    }

    addLLVMFnAttr(llvm_fn, "nounwind");
    add_uwtable_attr(g, llvm_fn);
    addLLVMFnAttr(llvm_fn, "nobuiltin");
    if (codegen_have_frame_pointer(g) && fn->fn_inline != FnInlineAlways) {
        ZigLLVMAddFunctionAttr(llvm_fn, "frame-pointer", "all");
    }
    if (fn->section_name) {
        LLVMSetSection(llvm_fn, buf_ptr(fn->section_name));
    }
    if (fn->align_bytes > 0) {
        LLVMSetAlignment(llvm_fn, (unsigned)fn->align_bytes);
    } else {
        // We'd like to set the best alignment for the function here, but on Darwin LLVM gives
        // "Cannot getTypeInfo() on a type that is unsized!" assertion failure when calling
        // any of the functions for getting alignment. Not specifying the alignment should
        // use the ABI alignment, which is fine.
    }

    if (is_async) {
        addLLVMArgAttr(llvm_fn, 0, "nonnull");
    } else {
        unsigned init_gen_i = 0;
        if (!type_has_bits(g, return_type)) {
            // nothing to do
        } else if (type_is_nonnull_ptr(g, return_type)) {
            addLLVMAttr(llvm_fn, 0, "nonnull");
        } else if (want_first_arg_sret(g, &fn_type->data.fn.fn_type_id)) {
            // Sret pointers must not be address 0
            addLLVMArgAttr(llvm_fn, 0, "nonnull");
            addLLVMArgAttr(llvm_fn, 0, "sret");
            if (cc_want_sret_attr(cc)) {
                addLLVMArgAttr(llvm_fn, 0, "noalias");
            }
            init_gen_i = 1;
        }

        // set parameter attributes
        FnWalk fn_walk = {};
        fn_walk.id = FnWalkIdAttrs;
        fn_walk.data.attrs.fn = fn;
        fn_walk.data.attrs.llvm_fn = llvm_fn;
        fn_walk.data.attrs.gen_i = init_gen_i;
        walk_function_params(g, fn_type, &fn_walk);

        uint32_t err_ret_trace_arg_index = get_err_ret_trace_arg_index(g, fn);
        if (err_ret_trace_arg_index != UINT32_MAX) {
            // Error return trace memory is in the stack, which is impossible to be at address 0
            // on any architecture.
            addLLVMArgAttr(llvm_fn, (unsigned)err_ret_trace_arg_index, "nonnull");
        }
    }

    return llvm_fn;
}

static LLVMValueRef fn_llvm_value(CodeGen *g, ZigFn *fn) {
    if (fn->llvm_value)
        return fn->llvm_value;

    fn->llvm_value = make_fn_llvm_value(g, fn);
    fn->llvm_name = strdup(LLVMGetValueName(fn->llvm_value));
    return fn->llvm_value;
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
            assert(fn_table_entry->raw_di_type != nullptr);
            ZigLLVMDISubprogram *subprogram = ZigLLVMCreateFunction(g->dbuilder,
                fn_di_scope, buf_ptr(&fn_table_entry->symbol_name), "",
                import->data.structure.root_struct->di_file, line_number,
                fn_table_entry->raw_di_type, is_internal_linkage,
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
        case ScopeIdNoSuspend:
        case ScopeIdRuntime:
        case ScopeIdTypeOf:
        case ScopeIdExpr:
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
        sprintf(fn_name, "llvm.%s.with.overflow.v%" PRIu64 "i%" PRIu32, signed_str,
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
        name = float_op_to_name(op);
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
    if (type_has_bits(g, type)) {
        if (handle_is_ptr(g, type)) {
            return ptr;
        } else {
            assert(ptr_type->id == ZigTypeIdPointer);
            return gen_load(g, ptr, ptr_type, "");
        }
    } else {
        return nullptr;
    }
}

static void ir_assert_impl(bool ok, IrInstGen *source_instruction, const char *file, unsigned int line) {
    if (ok) return;
    src_assert_impl(ok, source_instruction->base.source_node, file, line);
}

#define ir_assert(OK, SOURCE_INSTRUCTION) ir_assert_impl((OK), (SOURCE_INSTRUCTION), __FILE__, __LINE__)

static bool ir_want_fast_math(CodeGen *g, IrInstGen *instruction) {
    // TODO memoize
    Scope *scope = instruction->base.scope;
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

static bool ir_want_runtime_safety_scope(CodeGen *g, Scope *scope) {
    // TODO memoize
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

static bool ir_want_runtime_safety(CodeGen *g, IrInstGen *instruction) {
    return ir_want_runtime_safety_scope(g, instruction->base.scope);
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
        case PanicMsgIdUnwrapOptionalFail:
            return buf_create_from_str("attempt to use null value");
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
        case PanicMsgIdBadResume:
            return buf_create_from_str("resumed an async function which already returned");
        case PanicMsgIdBadAwait:
            return buf_create_from_str("async function awaited twice");
        case PanicMsgIdBadReturn:
            return buf_create_from_str("async function returned twice");
        case PanicMsgIdResumedAnAwaitingFn:
            return buf_create_from_str("awaiting function resumed");
        case PanicMsgIdFrameTooSmall:
            return buf_create_from_str("frame too small");
        case PanicMsgIdResumedFnPendingAwait:
            return buf_create_from_str("resumed an async function which can only be awaited");
        case PanicMsgIdBadNoSuspendCall:
            return buf_create_from_str("async function called in nosuspend scope suspended");
        case PanicMsgIdResumeNotSuspendedFn:
            return buf_create_from_str("resumed a non-suspended function");
        case PanicMsgIdBadSentinel:
            return buf_create_from_str("sentinel mismatch");
        case PanicMsgIdShxTooBigRhs:
            return buf_create_from_str("shift amount is greater than the type size");
    }
    zig_unreachable();
}

static LLVMValueRef get_panic_msg_ptr_val(CodeGen *g, PanicMsgId msg_id) {
    ZigValue *val = &g->panic_msg_vals[msg_id];
    if (!val->llvm_global) {

        Buf *buf_msg = panic_msg_buf(msg_id);
        ZigValue *array_val = create_const_str_lit(g, buf_msg)->data.x_ptr.data.ref.pointee;
        init_const_slice(g, val, array_val, 0, buf_len(buf_msg), true);

        render_const_val(g, val, "");
        render_const_val_global(g, val, "");

        assert(val->llvm_global);
    }

    ZigType *u8_ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0, false);
    ZigType *str_type = get_slice_type(g, u8_ptr_type);
    return LLVMConstBitCast(val->llvm_global, LLVMPointerType(get_llvm_type(g, str_type), 0));
}

static ZigType *ptr_to_stack_trace_type(CodeGen *g) {
    return get_pointer_to_type(g, get_stack_trace_type(g), false);
}

static void gen_panic(CodeGen *g, LLVMValueRef msg_arg, LLVMValueRef stack_trace_arg,
        bool stack_trace_is_llvm_alloca)
{
    assert(g->panic_fn != nullptr);
    LLVMValueRef fn_val = fn_llvm_value(g, g->panic_fn);
    ZigLLVM_CallingConv llvm_cc = get_llvm_cc(g, g->panic_fn->type_entry->data.fn.fn_type_id.cc);
    if (stack_trace_arg == nullptr) {
        stack_trace_arg = LLVMConstNull(get_llvm_type(g, ptr_to_stack_trace_type(g)));
    }
    LLVMValueRef args[] = {
        msg_arg,
        stack_trace_arg,
    };
    ZigLLVMBuildCall(g->builder, fn_val, args, 2, llvm_cc, ZigLLVM_CallAttrAuto, "");
    if (!stack_trace_is_llvm_alloca) {
        // The stack trace argument is not in the stack of the caller, so
        // we'd like to set tail call here, but because slices (the type of msg_arg) are
        // still passed as pointers (see https://github.com/ziglang/zig/issues/561) we still
        // cannot make this a tail call.
        //LLVMSetTailCall(call_instruction, true);
    }
    LLVMBuildUnreachable(g->builder);
}

// TODO update most callsites to call gen_assertion instead of this
static void gen_safety_crash(CodeGen *g, PanicMsgId msg_id) {
    gen_panic(g, get_panic_msg_ptr_val(g, msg_id), nullptr, false);
}

static void gen_assertion_scope(CodeGen *g, PanicMsgId msg_id, Scope *source_scope) {
    if (ir_want_runtime_safety_scope(g, source_scope)) {
        gen_safety_crash(g, msg_id);
    } else {
        LLVMBuildUnreachable(g->builder);
    }
}

static void gen_assertion(CodeGen *g, PanicMsgId msg_id, IrInstGen *source_instruction) {
    return gen_assertion_scope(g, msg_id, source_instruction->base.scope);
}

static LLVMValueRef gen_wasm_memory_size(CodeGen *g) {
    if (g->wasm_memory_size)
        return g->wasm_memory_size;

    // TODO adjust for wasm64 as well
    // declare i32 @llvm.wasm.memory.size.i32(i32) nounwind readonly
    LLVMTypeRef param_type = LLVMInt32Type();
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMInt32Type(), &param_type, 1, false);
    g->wasm_memory_size = LLVMAddFunction(g->module, "llvm.wasm.memory.size.i32", fn_type);
    assert(LLVMGetIntrinsicID(g->wasm_memory_size));

    return g->wasm_memory_size;
}

static LLVMValueRef gen_wasm_memory_grow(CodeGen *g) {
    if (g->wasm_memory_grow)
        return g->wasm_memory_grow;

    // TODO adjust for wasm64 as well
    // declare i32 @llvm.wasm.memory.grow.i32(i32, i32) nounwind
    LLVMTypeRef param_types[] = {
        LLVMInt32Type(),
        LLVMInt32Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(LLVMInt32Type(), param_types, 2, false);
    g->wasm_memory_grow = LLVMAddFunction(g->module, "llvm.wasm.memory.grow.i32", fn_type);
    assert(LLVMGetIntrinsicID(g->wasm_memory_grow));

    return g->wasm_memory_grow;
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
        get_llvm_type(g, ptr_to_stack_trace_type(g)),
        g->builtin_types.entry_usize->llvm_type,
    };
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 2, false);

    const char *fn_name = get_mangled_name(g, "__zig_add_err_ret_trace_addr");
    LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type_ref);
    addLLVMFnAttr(fn_val, "alwaysinline");
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    ZigLLVMFunctionSetCallingConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    // Error return trace memory is in the stack, which is impossible to be at address 0
    // on any architecture.
    addLLVMArgAttr(fn_val, (unsigned)0, "nonnull");
    if (codegen_have_frame_pointer(g)) {
        ZigLLVMAddFunctionAttr(fn_val, "frame-pointer", "all");
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

    size_t index_field_index = g->stack_trace_type->data.structure.fields[0]->gen_index;
    LLVMValueRef index_field_ptr = LLVMBuildStructGEP(g->builder, err_ret_trace_ptr, (unsigned)index_field_index, "");
    size_t addresses_field_index = g->stack_trace_type->data.structure.fields[1]->gen_index;
    LLVMValueRef addresses_field_ptr = LLVMBuildStructGEP(g->builder, err_ret_trace_ptr, (unsigned)addresses_field_index, "");

    ZigType *slice_type = g->stack_trace_type->data.structure.fields[1]->type_entry;
    size_t ptr_field_index = slice_type->data.structure.fields[slice_ptr_index]->gen_index;
    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, addresses_field_ptr, (unsigned)ptr_field_index, "");
    size_t len_field_index = slice_type->data.structure.fields[slice_len_index]->gen_index;
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

static LLVMValueRef get_return_err_fn(CodeGen *g) {
    if (g->return_err_fn != nullptr)
        return g->return_err_fn;

    assert(g->err_tag_type != nullptr);

    LLVMTypeRef arg_types[] = {
        // error return trace pointer
        get_llvm_type(g, ptr_to_stack_trace_type(g)),
    };
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 1, false);

    const char *fn_name = get_mangled_name(g, "__zig_return_error");
    LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type_ref);
    addLLVMFnAttr(fn_val, "noinline"); // so that we can look at return address
    addLLVMFnAttr(fn_val, "cold");
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    ZigLLVMFunctionSetCallingConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    if (codegen_have_frame_pointer(g)) {
        ZigLLVMAddFunctionAttr(fn_val, "frame-pointer", "all");
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

    LLVMBasicBlockRef return_block = LLVMAppendBasicBlock(fn_val, "Return");
    LLVMBasicBlockRef dest_non_null_block = LLVMAppendBasicBlock(fn_val, "DestNonNull");

    LLVMValueRef null_dest_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, err_ret_trace_ptr,
            LLVMConstNull(LLVMTypeOf(err_ret_trace_ptr)), "");
    LLVMBuildCondBr(g->builder, null_dest_bit, return_block, dest_non_null_block);

    LLVMPositionBuilderAtEnd(g->builder, return_block);
    LLVMBuildRetVoid(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, dest_non_null_block);
    LLVMValueRef args[] = { err_ret_trace_ptr, return_address };
    ZigLLVMBuildCall(g->builder, add_error_return_trace_addr_fn_val, args, 2,
            get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAlwaysInline, "");
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
    LLVMSetLinkage(msg_prefix, LLVMPrivateLinkage);
    LLVMSetGlobalConstant(msg_prefix, true);

    const char *fn_name = get_mangled_name(g, "__zig_fail_unwrap");
    LLVMTypeRef fn_type_ref;
    if (g->have_err_ret_tracing) {
        LLVMTypeRef arg_types[] = {
            get_llvm_type(g, get_pointer_to_type(g, get_stack_trace_type(g), false)),
            get_llvm_type(g, g->err_tag_type),
        };
        fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 2, false);
    } else {
        LLVMTypeRef arg_types[] = {
            get_llvm_type(g, g->err_tag_type),
        };
        fn_type_ref = LLVMFunctionType(LLVMVoidType(), arg_types, 1, false);
    }
    LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type_ref);
    addLLVMFnAttr(fn_val, "noreturn");
    addLLVMFnAttr(fn_val, "cold");
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    ZigLLVMFunctionSetCallingConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    if (codegen_have_frame_pointer(g)) {
        ZigLLVMAddFunctionAttr(fn_val, "frame-pointer", "all");
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
    gen_panic(g, msg_slice, err_ret_trace_arg, false);

    LLVMPositionBuilderAtEnd(g->builder, prev_block);
    if (!g->strip_debug_symbols) {
        LLVMSetCurrentDebugLocation(g->builder, prev_debug_location);
    }

    g->safety_crash_err_fn = fn_val;
    return fn_val;
}

static LLVMValueRef get_cur_err_ret_trace_val(CodeGen *g, Scope *scope, bool *is_llvm_alloca) {
    if (!g->have_err_ret_tracing) {
        *is_llvm_alloca = false;
        return nullptr;
    }
    if (g->cur_err_ret_trace_val_stack != nullptr) {
        *is_llvm_alloca = !fn_is_async(g->cur_fn);
        return g->cur_err_ret_trace_val_stack;
    }
    *is_llvm_alloca = false;
    return g->cur_err_ret_trace_val_arg;
}

static void gen_safety_crash_for_err(CodeGen *g, LLVMValueRef err_val, Scope *scope) {
    LLVMValueRef safety_crash_err_fn = get_safety_crash_err_fn(g);
    LLVMValueRef call_instruction;
    bool is_llvm_alloca = false;
    if (g->have_err_ret_tracing) {
        LLVMValueRef err_ret_trace_val = get_cur_err_ret_trace_val(g, scope, &is_llvm_alloca);
        if (err_ret_trace_val == nullptr) {
            err_ret_trace_val = LLVMConstNull(get_llvm_type(g, ptr_to_stack_trace_type(g)));
        }
        LLVMValueRef args[] = {
            err_ret_trace_val,
            err_val,
        };
        call_instruction = ZigLLVMBuildCall(g->builder, safety_crash_err_fn, args, 2,
                get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAuto, "");
    } else {
        LLVMValueRef args[] = {
            err_val,
        };
        call_instruction = ZigLLVMBuildCall(g->builder, safety_crash_err_fn, args, 1,
                get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAuto, "");
    }
    if (!is_llvm_alloca) {
        LLVMSetTailCall(call_instruction, true);
    }
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

static void add_sentinel_check(CodeGen *g, LLVMValueRef sentinel_elem_ptr, ZigValue *sentinel) {
    LLVMValueRef expected_sentinel = gen_const_val(g, sentinel, "");

    LLVMValueRef actual_sentinel = gen_load_untyped(g, sentinel_elem_ptr, 0, false, "");
    LLVMValueRef ok_bit;
    if (sentinel->type->id == ZigTypeIdFloat) {
        ok_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, actual_sentinel, expected_sentinel, "");
    } else {
        ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, actual_sentinel, expected_sentinel, "");
    }

    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "SentinelFail");
    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "SentinelOk");
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_safety_crash(g, PanicMsgIdBadSentinel);

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

    if (actual_type->id == ZigTypeIdInt && want_runtime_safety && (
        // negative to unsigned
        (!wanted_type->data.integral.is_signed && actual_type->data.integral.is_signed) ||
        // unsigned would become negative
        (wanted_type->data.integral.is_signed && !actual_type->data.integral.is_signed && actual_bits == wanted_bits)))
    {
        LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, actual_type));
        LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntSGE, expr_val, zero, "");

        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "SignCastOk");
        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "SignCastFail");
        LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_safety_crash(g, actual_type->data.integral.is_signed ? PanicMsgIdCastNegativeToUnsigned : PanicMsgIdCastTruncatedData);

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

static void gen_assign_raw(CodeGen *g, LLVMValueRef ptr, ZigType *ptr_type,
        LLVMValueRef value)
{
    assert(ptr_type->id == ZigTypeIdPointer);
    ZigType *child_type = ptr_type->data.pointer.child_type;

    if (!type_has_bits(g, child_type))
        return;

    if (handle_is_ptr(g, child_type)) {
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
        return;
    }

    assert(ptr_type->data.pointer.vector_index != VECTOR_INDEX_RUNTIME);
    if (ptr_type->data.pointer.vector_index != VECTOR_INDEX_NONE) {
        LLVMValueRef index_val = LLVMConstInt(LLVMInt32Type(),
                ptr_type->data.pointer.vector_index, false);
        LLVMValueRef loaded_vector = gen_load(g, ptr, ptr_type, "");
        LLVMValueRef new_vector = LLVMBuildInsertElement(g->builder, loaded_vector, value,
                index_val, "");
        gen_store(g, new_vector, ptr, ptr_type);
        return;
    }

    uint32_t host_int_bytes = ptr_type->data.pointer.host_int_bytes;
    if (host_int_bytes == 0) {
        gen_store(g, value, ptr, ptr_type);
        return;
    }

    bool big_endian = g->is_big_endian;

    LLVMTypeRef int_ptr_ty = LLVMPointerType(LLVMIntType(host_int_bytes * 8), 0);
    LLVMValueRef int_ptr = LLVMBuildBitCast(g->builder, ptr, int_ptr_ty, "");
    LLVMValueRef containing_int = gen_load(g, int_ptr, ptr_type, "");
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

    gen_store(g, ored_value, int_ptr, ptr_type);
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

static LLVMValueRef ir_llvm_value(CodeGen *g, IrInstGen *instruction) {
    Error err;

    bool value_has_bits;
    if ((err = type_has_bits2(g, instruction->value->type, &value_has_bits)))
        codegen_report_errors_and_exit(g);

    if (!value_has_bits)
        return nullptr;

    if (!instruction->llvm_value) {
        if (instruction->id == IrInstGenIdAwait) {
            IrInstGenAwait *await = reinterpret_cast<IrInstGenAwait*>(instruction);
            if (await->result_loc != nullptr) {
                return get_handle_value(g, ir_llvm_value(g, await->result_loc),
                    await->result_loc->value->type->data.pointer.child_type, await->result_loc->value->type);
            }
        }
        if (instruction->spill != nullptr) {
            ZigType *ptr_type = instruction->spill->value->type;
            ir_assert(ptr_type->id == ZigTypeIdPointer, instruction);
            return get_handle_value(g, ir_llvm_value(g, instruction->spill),
                ptr_type->data.pointer.child_type, instruction->spill->value->type);
        }
        ir_assert(instruction->value->special != ConstValSpecialRuntime, instruction);
        assert(instruction->value->type);
        render_const_val(g, instruction->value, "");
        // we might have to do some pointer casting here due to the way union
        // values are rendered with a type other than the one we expect
        if (handle_is_ptr(g, instruction->value->type)) {
            render_const_val_global(g, instruction->value, "");
            ZigType *ptr_type = get_pointer_to_type(g, instruction->value->type, true);
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value->llvm_global, get_llvm_type(g, ptr_type), "");
        } else {
            instruction->llvm_value = LLVMBuildBitCast(g->builder, instruction->value->llvm_value,
                    get_llvm_type(g, instruction->value->type), "");
        }
        assert(instruction->llvm_value);
    }
    return instruction->llvm_value;
}

void codegen_report_errors_and_exit(CodeGen *g) {
    // Clear progress indicator before printing errors
    if (g->sub_progress_node != nullptr) {
        stage2_progress_end(g->sub_progress_node);
        g->sub_progress_node = nullptr;
    }
    if (g->main_progress_node != nullptr) {
        stage2_progress_end(g->main_progress_node);
        g->main_progress_node = nullptr;
    }

    assert(g->errors.length != 0);
    for (size_t i = 0; i < g->errors.length; i += 1) {
        ErrorMsg *err = g->errors.at(i);
        print_err_msg(err, g->err_color);
    }
    exit(1);
}

static void report_errors_and_maybe_exit(CodeGen *g) {
    if (g->errors.length != 0) {
        codegen_report_errors_and_exit(g);
    }
}

ATTRIBUTE_NORETURN
static void give_up_with_c_abi_error(CodeGen *g, AstNode *source_node) {
    ErrorMsg *msg = add_node_error(g, source_node,
            buf_sprintf("TODO: support C ABI for more targets. https://github.com/ziglang/zig/issues/1481"));
    add_error_note(g, msg, source_node,
        buf_sprintf("pointers, integers, floats, bools, and enums work on all targets"));
    codegen_report_errors_and_exit(g);
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
            llvm_fn = fn_walk->data.attrs.llvm_fn;
            break;
        case FnWalkIdCall: {
            if (src_i >= fn_walk->data.call.inst->arg_count)
                return false;
            IrInstGen *arg = fn_walk->data.call.inst->args[src_i];
            ty = arg->value->type;
            source_node = arg->base.source_node;
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

    if (type_is_c_abi_int_bail(g, ty) || ty->id == ZigTypeIdFloat || ty->id == ZigTypeIdVector ||
        ty->id == ZigTypeIdInt // TODO investigate if we need to change this
    ) {
        switch (fn_walk->id) {
            case FnWalkIdAttrs: {
                ZigType *ptr_type = get_codegen_ptr_type_bail(g, ty);
                if (ptr_type != nullptr) {
                    if (type_is_nonnull_ptr(g, ty)) {
                        addLLVMArgAttr(llvm_fn, fn_walk->data.attrs.gen_i, "nonnull");
                    }
                    if (ptr_type->id == ZigTypeIdPointer && ptr_type->data.pointer.is_const) {
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
                var->value_ref = build_alloca(g, ty, var->name, var->align_bytes);
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

    {
        // Arrays are just pointers
        if (ty->id == ZigTypeIdArray) {
            assert(handle_is_ptr(g, ty));
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

        X64CABIClass abi_class = type_c_abi_x86_64_class(g, ty);
        size_t ty_size = type_size(g, ty);
        if (abi_class == X64CABIClass_MEMORY || abi_class == X64CABIClass_MEMORY_nobyval) {
            assert(handle_is_ptr(g, ty));
            switch (fn_walk->id) {
                case FnWalkIdAttrs:
                    if (abi_class != X64CABIClass_MEMORY_nobyval) {
                        ZigLLVMAddByValAttr(llvm_fn, fn_walk->data.attrs.gen_i + 1, get_llvm_type(g, ty));
                        addLLVMArgAttrInt(llvm_fn, fn_walk->data.attrs.gen_i, "align", get_abi_alignment(g, ty));
                    } else if (g->zig_target->arch == ZigLLVM_aarch64 ||
                            g->zig_target->arch == ZigLLVM_aarch64_be)
                    {
                        // no attrs needed
                    } else {
                        if (source_node != nullptr) {
                            give_up_with_c_abi_error(g, source_node);
                        }
                        // otherwise allow codegen code to report a compile error
                        return false;
                    }

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
                    var->value_ref = build_alloca(g, ty, var->name, var->align_bytes);
                    fn_walk->data.vars.gen_i += 1;
                    dest_ty = ty;
                    goto var_ok;
                }
                case FnWalkIdInits: {
                    clear_debug_source_node(g);
                    if (!fn_is_async(fn_walk->data.inits.fn)) {
                        LLVMValueRef arg = LLVMGetParam(llvm_fn, fn_walk->data.inits.gen_i);
                        LLVMTypeRef ptr_to_int_type_ref = LLVMPointerType(LLVMIntType((unsigned)ty_size * 8), 0);
                        LLVMValueRef bitcasted = LLVMBuildBitCast(g->builder, var->value_ref, ptr_to_int_type_ref, "");
                        gen_store_untyped(g, arg, bitcasted, var->align_bytes, false);
                    }
                    if (var->decl_node) {
                        gen_var_debug_decl(g, var);
                    }
                    fn_walk->data.inits.gen_i += 1;
                    break;
                }
            }
            return true;
        } else if (abi_class == X64CABIClass_SSE) {
            // For now only handle structs with only floats/doubles in it.
            if (ty->id != ZigTypeIdStruct) {
                if (source_node != nullptr) {
                    give_up_with_c_abi_error(g, source_node);
                }
                // otherwise allow codegen code to report a compile error
                return false;
            }

            for (uint32_t i = 0; i < ty->data.structure.src_field_count; i += 1) {
                if (ty->data.structure.fields[i]->type_entry->id != ZigTypeIdFloat) {
                    if (source_node != nullptr) {
                        give_up_with_c_abi_error(g, source_node);
                    }
                    // otherwise allow codegen code to report a compile error
                    return false;
                }
            }

            // The SystemV ABI says that we have to setup 1 FP register per f64.
            // So two f32 can be passed in one f64, but 3 f32 have to be passed in 2 FP registers.
            // To achieve this with LLVM API, we pass multiple f64 parameters to the LLVM function if
            // the type is bigger than 8 bytes.

            // Example:
            // extern struct {
            //      x: f32,
            //      y: f32,
            //      z: f32,
            // };
            // const ptr = (*f64)*Struct;
            // Register 1: ptr.*
            // Register 2: (ptr + 1).*

            // One floating point register per f64 or 2 f32's
            size_t number_of_fp_regs = (size_t)ceilf((float)ty_size / (float)8);

            switch (fn_walk->id) {
                case FnWalkIdAttrs: {
                    fn_walk->data.attrs.gen_i += 1;
                    break;
                }
                case FnWalkIdCall: {
                    LLVMValueRef f64_ptr_to_struct = LLVMBuildBitCast(g->builder, val, LLVMPointerType(LLVMDoubleType(), 0), "");
                    for (uint32_t i = 0; i < number_of_fp_regs; i += 1) {
                        LLVMValueRef index = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, i, false);
                        LLVMValueRef indices[] = { index };
                        LLVMValueRef adjusted_ptr_to_struct = LLVMBuildInBoundsGEP(g->builder, f64_ptr_to_struct, indices, 1, "");
                        LLVMValueRef loaded = LLVMBuildLoad(g->builder, adjusted_ptr_to_struct, "");
                        fn_walk->data.call.gen_param_values->append(loaded);
                    }
                    break;
                }
                case FnWalkIdTypes: {
                    for (uint32_t i = 0; i < number_of_fp_regs; i += 1) {
                        fn_walk->data.types.gen_param_types->append(get_llvm_type(g, g->builtin_types.entry_f64));
                        fn_walk->data.types.param_di_types->append(get_llvm_di_type(g, g->builtin_types.entry_f64));
                    }
                    break;
                }
                case FnWalkIdVars:
                case FnWalkIdInits: {
                    // TODO: Handle exporting functions
                    if (source_node != nullptr) {
                        give_up_with_c_abi_error(g, source_node);
                    }
                    // otherwise allow codegen code to report a compile error
                    return false;
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
                var->name, fn_walk->data.vars.import->data.structure.root_struct->di_file,
                (unsigned)(var->decl_node->line + 1),
                get_llvm_di_type(g, dest_ty), !g->strip_debug_symbols, 0, di_arg_index + 1);
    }
    return true;
}

void walk_function_params(CodeGen *g, ZigType *fn_type, FnWalk *fn_walk) {
    CallingConvention cc = fn_type->data.fn.fn_type_id.cc;
    if (!calling_convention_allows_zig_types(cc)) {
        size_t src_i = 0;
        for (;;) {
            if (!iter_function_params_c_abi(g, fn_type, fn_walk, src_i))
                break;
            src_i += 1;
        }
        return;
    }
    if (fn_walk->id == FnWalkIdCall) {
        IrInstGenCall *instruction = fn_walk->data.call.inst;
        bool is_var_args = fn_walk->data.call.is_var_args;
        for (size_t call_i = 0; call_i < instruction->arg_count; call_i += 1) {
            IrInstGen *param_instruction = instruction->args[call_i];
            ZigType *param_type = param_instruction->value->type;
            if (is_var_args || type_has_bits(g, param_type)) {
                LLVMValueRef param_value = ir_llvm_value(g, param_instruction);
                assert(param_value);
                fn_walk->data.call.gen_param_values->append(param_value);
                fn_walk->data.call.gen_param_types->append(param_type);
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
                LLVMValueRef llvm_fn = fn_walk->data.attrs.llvm_fn;
                bool is_byval = gen_info->is_byval;
                FnTypeParamInfo *param_info = &fn_type->data.fn.fn_type_id.param_info[param_i];

                ZigType *param_type = gen_info->type;
                if (param_info->is_noalias) {
                    addLLVMArgAttr(llvm_fn, (unsigned)gen_index, "noalias");
                }
                if ((param_type->id == ZigTypeIdPointer && param_type->data.pointer.is_const) || is_byval) {
                    addLLVMArgAttr(llvm_fn, (unsigned)gen_index, "readonly");
                }
                if (get_codegen_ptr_type_bail(g, param_type) != nullptr) {
                    addLLVMArgAttrInt(llvm_fn, (unsigned)gen_index, "align", get_ptr_align(g, param_type));
                }
                if (type_is_nonnull_ptr(g, param_type)) {
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

                if (!handle_is_ptr(g, variable->var_type) && !fn_is_async(fn_walk->data.inits.fn)) {
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

static LLVMValueRef get_merge_err_ret_traces_fn_val(CodeGen *g) {
    if (g->merge_err_ret_traces_fn_val)
        return g->merge_err_ret_traces_fn_val;

    assert(g->stack_trace_type != nullptr);

    LLVMTypeRef param_types[] = {
        get_llvm_type(g, ptr_to_stack_trace_type(g)),
        get_llvm_type(g, ptr_to_stack_trace_type(g)),
    };
    LLVMTypeRef fn_type_ref = LLVMFunctionType(LLVMVoidType(), param_types, 2, false);

    const char *fn_name = get_mangled_name(g, "__zig_merge_error_return_traces");
    LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type_ref);
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    ZigLLVMFunctionSetCallingConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    addLLVMArgAttr(fn_val, (unsigned)0, "noalias");
    addLLVMArgAttr(fn_val, (unsigned)0, "writeonly");

    addLLVMArgAttr(fn_val, (unsigned)1, "noalias");
    addLLVMArgAttr(fn_val, (unsigned)1, "readonly");
    if (codegen_have_frame_pointer(g)) {
        ZigLLVMAddFunctionAttr(fn_val, "frame-pointer", "all");
    }

    // this is above the ZigLLVMClearCurrentDebugLocation
    LLVMValueRef add_error_return_trace_addr_fn_val = get_add_error_return_trace_addr_fn(g);

    LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn_val, "Entry");
    LLVMBasicBlockRef prev_block = LLVMGetInsertBlock(g->builder);
    LLVMValueRef prev_debug_location = LLVMGetCurrentDebugLocation(g->builder);
    LLVMPositionBuilderAtEnd(g->builder, entry_block);
    ZigLLVMClearCurrentDebugLocation(g->builder);

    // if (dest_stack_trace == null or src_stack_trace == null) return;
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
    LLVMBasicBlockRef non_null_block = LLVMAppendBasicBlock(fn_val, "NonNull");

    LLVMValueRef frame_index_ptr = LLVMBuildAlloca(g->builder, g->builtin_types.entry_usize->llvm_type, "frame_index");
    LLVMValueRef frames_left_ptr = LLVMBuildAlloca(g->builder, g->builtin_types.entry_usize->llvm_type, "frames_left");

    LLVMValueRef dest_stack_trace_ptr = LLVMGetParam(fn_val, 0);
    LLVMValueRef src_stack_trace_ptr = LLVMGetParam(fn_val, 1);

    LLVMValueRef null_dest_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, dest_stack_trace_ptr,
            LLVMConstNull(LLVMTypeOf(dest_stack_trace_ptr)), "");
    LLVMValueRef null_src_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, src_stack_trace_ptr,
            LLVMConstNull(LLVMTypeOf(src_stack_trace_ptr)), "");
    LLVMValueRef null_bit = LLVMBuildOr(g->builder, null_dest_bit, null_src_bit, "");
    LLVMBuildCondBr(g->builder, null_bit, return_block, non_null_block);

    LLVMPositionBuilderAtEnd(g->builder, non_null_block);
    size_t src_index_field_index = g->stack_trace_type->data.structure.fields[0]->gen_index;
    size_t src_addresses_field_index = g->stack_trace_type->data.structure.fields[1]->gen_index;
    LLVMValueRef src_index_field_ptr = LLVMBuildStructGEP(g->builder, src_stack_trace_ptr,
            (unsigned)src_index_field_index, "");
    LLVMValueRef src_addresses_field_ptr = LLVMBuildStructGEP(g->builder, src_stack_trace_ptr,
            (unsigned)src_addresses_field_index, "");
    ZigType *slice_type = g->stack_trace_type->data.structure.fields[1]->type_entry;
    size_t ptr_field_index = slice_type->data.structure.fields[slice_ptr_index]->gen_index;
    LLVMValueRef src_ptr_field_ptr = LLVMBuildStructGEP(g->builder, src_addresses_field_ptr, (unsigned)ptr_field_index, "");
    size_t len_field_index = slice_type->data.structure.fields[slice_len_index]->gen_index;
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
    ZigLLVMBuildCall(g->builder, add_error_return_trace_addr_fn_val, args, 2, get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAlwaysInline, "");
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
static LLVMValueRef ir_render_save_err_ret_addr(CodeGen *g, IrExecutableGen *executable,
        IrInstGenSaveErrRetAddr *save_err_ret_addr_instruction)
{
    assert(g->have_err_ret_tracing);

    LLVMValueRef return_err_fn = get_return_err_fn(g);
    bool is_llvm_alloca;
    LLVMValueRef my_err_trace_val = get_cur_err_ret_trace_val(g, save_err_ret_addr_instruction->base.base.scope,
            &is_llvm_alloca);
    ZigLLVMBuildCall(g->builder, return_err_fn, &my_err_trace_val, 1,
            get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAuto, "");

    ZigType *ret_type = g->cur_fn->type_entry->data.fn.fn_type_id.return_type;
    if (fn_is_async(g->cur_fn) && codegen_fn_has_err_ret_tracing_arg(g, ret_type)) {
        LLVMValueRef trace_ptr_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr,
                frame_index_trace_arg(g, ret_type), "");
        LLVMBuildStore(g->builder, my_err_trace_val, trace_ptr_ptr);
    }

    return nullptr;
}

static void gen_assert_resume_id(CodeGen *g, IrInstGen *source_instr, ResumeId resume_id, PanicMsgId msg_id,
        LLVMBasicBlockRef end_bb)
{
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;

    if (ir_want_runtime_safety(g, source_instr)) {
        // Write a value to the resume index which indicates the function was resumed while not suspended.
        LLVMBuildStore(g->builder, g->cur_bad_not_suspended_index, g->cur_async_resume_index_ptr);
    }

    LLVMBasicBlockRef bad_resume_block = LLVMAppendBasicBlock(g->cur_fn_val, "BadResume");
    if (end_bb == nullptr) end_bb = LLVMAppendBasicBlock(g->cur_fn_val, "OkResume");
    LLVMValueRef expected_value = LLVMConstSub(LLVMConstAllOnes(usize_type_ref),
            LLVMConstInt(usize_type_ref, resume_id, false));
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, LLVMGetParam(g->cur_fn_val, 1), expected_value, "");
    LLVMBuildCondBr(g->builder, ok_bit, end_bb, bad_resume_block);

    LLVMPositionBuilderAtEnd(g->builder, bad_resume_block);
    gen_assertion(g, msg_id, source_instr);

    LLVMPositionBuilderAtEnd(g->builder, end_bb);
}

static LLVMValueRef gen_resume(CodeGen *g, LLVMValueRef fn_val, LLVMValueRef target_frame_ptr, ResumeId resume_id) {
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
    if (fn_val == nullptr) {
        LLVMValueRef fn_ptr_ptr = LLVMBuildStructGEP(g->builder, target_frame_ptr, frame_fn_ptr_index, "");
        fn_val = LLVMBuildLoad(g->builder, fn_ptr_ptr, "");
    }
    LLVMValueRef arg_val = LLVMConstSub(LLVMConstAllOnes(usize_type_ref),
            LLVMConstInt(usize_type_ref, resume_id, false));
    LLVMValueRef args[] = {target_frame_ptr, arg_val};
    return ZigLLVMBuildCall(g->builder, fn_val, args, 2, ZigLLVM_Fast, ZigLLVM_CallAttrAuto, "");
}

static LLVMBasicBlockRef gen_suspend_begin(CodeGen *g, const char *name_hint) {
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
    LLVMBasicBlockRef resume_bb = LLVMAppendBasicBlock(g->cur_fn_val, name_hint);
    size_t new_block_index = g->cur_resume_block_count;
    g->cur_resume_block_count += 1;
    LLVMValueRef new_block_index_val = LLVMConstInt(usize_type_ref, new_block_index, false);
    LLVMAddCase(g->cur_async_switch_instr, new_block_index_val, resume_bb);
    LLVMBuildStore(g->builder, new_block_index_val, g->cur_async_resume_index_ptr);
    return resume_bb;
}

// Be careful setting tail call. According to LLVM lang ref,
// tail and musttail imply that the callee does not access allocas from the caller.
// This works for async functions since the locals are spilled.
// http://llvm.org/docs/LangRef.html#id320
static void set_tail_call_if_appropriate(CodeGen *g, LLVMValueRef call_inst) {
    LLVMSetTailCall(call_inst, true);
}

static LLVMValueRef gen_maybe_atomic_op(CodeGen *g, LLVMAtomicRMWBinOp op, LLVMValueRef ptr, LLVMValueRef val,
        LLVMAtomicOrdering order)
{
    if (g->is_single_threaded) {
        LLVMValueRef loaded = LLVMBuildLoad(g->builder, ptr, "");
        LLVMValueRef modified;
        switch (op) {
            case LLVMAtomicRMWBinOpXchg:
                modified = val;
                break;
            case LLVMAtomicRMWBinOpXor:
                modified = LLVMBuildXor(g->builder, loaded, val, "");
                break;
            default:
                zig_unreachable();
        }
        LLVMBuildStore(g->builder, modified, ptr);
        return loaded;
    } else {
        return LLVMBuildAtomicRMW(g->builder, op, ptr, val, order, false);
    }
}

static void gen_async_return(CodeGen *g, IrInstGenReturn *instruction) {
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;

    ZigType *operand_type = (instruction->operand != nullptr) ? instruction->operand->value->type : nullptr;
    bool operand_has_bits = (operand_type != nullptr) && type_has_bits(g, operand_type);
    ZigType *ret_type = g->cur_fn->type_entry->data.fn.fn_type_id.return_type;
    bool ret_type_has_bits = type_has_bits(g, ret_type);

    if (operand_has_bits && instruction->operand != nullptr) {
        bool need_store = instruction->operand->value->special != ConstValSpecialRuntime || !handle_is_ptr(g, ret_type);
        if (need_store) {
            // It didn't get written to the result ptr. We do that now.
            ZigType *ret_ptr_type = get_pointer_to_type(g, ret_type, true);
            gen_assign_raw(g, g->cur_ret_ptr, ret_ptr_type, ir_llvm_value(g, instruction->operand));
        }
    }

    // Whether we tail resume the awaiter, or do an early return, we are done and will not be resumed.
    if (ir_want_runtime_safety(g, &instruction->base)) {
        LLVMValueRef new_resume_index = LLVMConstAllOnes(usize_type_ref);
        LLVMBuildStore(g->builder, new_resume_index, g->cur_async_resume_index_ptr);
    }

    LLVMValueRef zero = LLVMConstNull(usize_type_ref);
    LLVMValueRef all_ones = LLVMConstAllOnes(usize_type_ref);

    LLVMValueRef prev_val = gen_maybe_atomic_op(g, LLVMAtomicRMWBinOpXor, g->cur_async_awaiter_ptr,
            all_ones, LLVMAtomicOrderingAcquire);

    LLVMBasicBlockRef bad_return_block = LLVMAppendBasicBlock(g->cur_fn_val, "BadReturn");
    LLVMBasicBlockRef early_return_block = LLVMAppendBasicBlock(g->cur_fn_val, "EarlyReturn");
    LLVMBasicBlockRef resume_them_block = LLVMAppendBasicBlock(g->cur_fn_val, "ResumeThem");

    LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, prev_val, resume_them_block, 2);

    LLVMAddCase(switch_instr, zero, early_return_block);
    LLVMAddCase(switch_instr, all_ones, bad_return_block);

    // Something has gone horribly wrong, and this is an invalid second return.
    LLVMPositionBuilderAtEnd(g->builder, bad_return_block);
    gen_assertion(g, PanicMsgIdBadReturn, &instruction->base);

    // There is no awaiter yet, but we're completely done.
    LLVMPositionBuilderAtEnd(g->builder, early_return_block);
    LLVMBuildRetVoid(g->builder);

    // We need to resume the caller by tail calling them,
    // but first write through the result pointer and possibly
    // error return trace pointer.
    LLVMPositionBuilderAtEnd(g->builder, resume_them_block);

    if (ret_type_has_bits) {
        // If the awaiter result pointer is non-null, we need to copy the result to there.
        LLVMBasicBlockRef copy_block = LLVMAppendBasicBlock(g->cur_fn_val, "CopyResult");
        LLVMBasicBlockRef copy_end_block = LLVMAppendBasicBlock(g->cur_fn_val, "CopyResultEnd");
        LLVMValueRef awaiter_ret_ptr_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr, frame_ret_start + 1, "");
        LLVMValueRef awaiter_ret_ptr = LLVMBuildLoad(g->builder, awaiter_ret_ptr_ptr, "");
        LLVMValueRef zero_ptr = LLVMConstNull(LLVMTypeOf(awaiter_ret_ptr));
        LLVMValueRef need_copy_bit = LLVMBuildICmp(g->builder, LLVMIntNE, awaiter_ret_ptr, zero_ptr, "");
        LLVMBuildCondBr(g->builder, need_copy_bit, copy_block, copy_end_block);

        LLVMPositionBuilderAtEnd(g->builder, copy_block);
        LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
        LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, awaiter_ret_ptr, ptr_u8, "");
        LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, g->cur_ret_ptr, ptr_u8, "");
        bool is_volatile = false;
        uint32_t abi_align = get_abi_alignment(g, ret_type);
        LLVMValueRef byte_count_val = LLVMConstInt(usize_type_ref, type_size(g, ret_type), false);
        ZigLLVMBuildMemCpy(g->builder,
                dest_ptr_casted, abi_align,
                src_ptr_casted, abi_align, byte_count_val, is_volatile);
        LLVMBuildBr(g->builder, copy_end_block);

        LLVMPositionBuilderAtEnd(g->builder, copy_end_block);
        if (codegen_fn_has_err_ret_tracing_arg(g, ret_type)) {
            LLVMValueRef awaiter_trace_ptr_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr,
                    frame_index_trace_arg(g, ret_type) + 1, "");
            LLVMValueRef dest_trace_ptr = LLVMBuildLoad(g->builder, awaiter_trace_ptr_ptr, "");
            bool is_llvm_alloca;
            LLVMValueRef my_err_trace_val = get_cur_err_ret_trace_val(g, instruction->base.base.scope, &is_llvm_alloca);
            LLVMValueRef args[] = { dest_trace_ptr, my_err_trace_val };
            ZigLLVMBuildCall(g->builder, get_merge_err_ret_traces_fn_val(g), args, 2,
                    get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAuto, "");
        }
    }

    // Resume the caller by tail calling them.
    ZigType *any_frame_type = get_any_frame_type(g, ret_type);
    LLVMValueRef their_frame_ptr = LLVMBuildIntToPtr(g->builder, prev_val, get_llvm_type(g, any_frame_type), "");
    LLVMValueRef call_inst = gen_resume(g, nullptr, their_frame_ptr, ResumeIdReturn);
    set_tail_call_if_appropriate(g, call_inst);
    LLVMBuildRetVoid(g->builder);
}

static LLVMValueRef ir_render_return(CodeGen *g, IrExecutableGen *executable, IrInstGenReturn *instruction) {
    if (fn_is_async(g->cur_fn)) {
        gen_async_return(g, instruction);
        return nullptr;
    }

    if (want_first_arg_sret(g, &g->cur_fn->type_entry->data.fn.fn_type_id)) {
        if (instruction->operand == nullptr) {
            LLVMBuildRetVoid(g->builder);
            return nullptr;
        }
        assert(g->cur_ret_ptr);
        ir_assert(instruction->operand->value->special != ConstValSpecialRuntime, &instruction->base);
        LLVMValueRef value = ir_llvm_value(g, instruction->operand);
        ZigType *return_type = instruction->operand->value->type;
        gen_assign_raw(g, g->cur_ret_ptr, get_pointer_to_type(g, return_type, false), value);
        LLVMBuildRetVoid(g->builder);
    } else if (g->cur_fn->type_entry->data.fn.fn_type_id.cc != CallingConventionAsync &&
            handle_is_ptr(g, g->cur_fn->type_entry->data.fn.fn_type_id.return_type))
    {
        if (instruction->operand == nullptr) {
            LLVMValueRef by_val_value = gen_load_untyped(g, g->cur_ret_ptr, 0, false, "");
            LLVMBuildRet(g->builder, by_val_value);
        } else {
            LLVMValueRef value = ir_llvm_value(g, instruction->operand);
            LLVMValueRef by_val_value = gen_load_untyped(g, value, 0, false, "");
            LLVMBuildRet(g->builder, by_val_value);
        }
    } else if (instruction->operand == nullptr) {
        if (g->cur_ret_ptr == nullptr) {
            LLVMBuildRetVoid(g->builder);
        } else {
            LLVMValueRef by_val_value = gen_load_untyped(g, g->cur_ret_ptr, 0, false, "");
            LLVMBuildRet(g->builder, by_val_value);
        }
    } else {
        LLVMValueRef value = ir_llvm_value(g, instruction->operand);
        LLVMBuildRet(g->builder, value);
    }
    return nullptr;
}

enum class ScalarizePredicate {
    // Returns true iff all the elements in the vector are 1.
    // Equivalent to folding all the bits with `and`.
    All,
    // Returns true iff there's at least one element in the vector that is 1.
    // Equivalent to folding all the bits with `or`.
    Any,
};

// Collapses a <N x i1> vector into a single i1 according to the given predicate
static LLVMValueRef scalarize_cmp_result(CodeGen *g, LLVMValueRef val, ScalarizePredicate predicate) {
    assert(LLVMGetTypeKind(LLVMTypeOf(val)) == LLVMVectorTypeKind);
    LLVMTypeRef scalar_type = LLVMIntType(LLVMGetVectorSize(LLVMTypeOf(val)));
    LLVMValueRef casted = LLVMBuildBitCast(g->builder, val, scalar_type, "");

    switch (predicate) {
        case ScalarizePredicate::Any: {
            LLVMValueRef all_zeros = LLVMConstNull(scalar_type);
            return LLVMBuildICmp(g->builder, LLVMIntNE, casted, all_zeros, "");
        }
        case ScalarizePredicate::All: {
            LLVMValueRef all_ones = LLVMConstAllOnes(scalar_type);
            return LLVMBuildICmp(g->builder, LLVMIntEQ, casted, all_ones, "");
        }
    }

    zig_unreachable();
}


static LLVMValueRef gen_overflow_shl_op(CodeGen *g, ZigType *operand_type,
    LLVMValueRef val1, LLVMValueRef val2)
{
    // for unsigned left shifting, we do the lossy shift, then logically shift
    // right the same number of bits
    // if the values don't match, we have an overflow
    // for signed left shifting we do the same except arithmetic shift right
    ZigType *scalar_type = (operand_type->id == ZigTypeIdVector) ?
        operand_type->data.vector.elem_type : operand_type;

    assert(scalar_type->id == ZigTypeIdInt);

    LLVMValueRef result = LLVMBuildShl(g->builder, val1, val2, "");
    LLVMValueRef orig_val;
    if (scalar_type->data.integral.is_signed) {
        orig_val = LLVMBuildAShr(g->builder, result, val2, "");
    } else {
        orig_val = LLVMBuildLShr(g->builder, result, val2, "");
    }
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, orig_val, "");

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowFail");
    if (operand_type->id == ZigTypeIdVector) {
        ok_bit = scalarize_cmp_result(g, ok_bit, ScalarizePredicate::All);
    }
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_safety_crash(g, PanicMsgIdShlOverflowedBits);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_overflow_shr_op(CodeGen *g, ZigType *operand_type,
    LLVMValueRef val1, LLVMValueRef val2)
{
    ZigType *scalar_type = (operand_type->id == ZigTypeIdVector) ?
        operand_type->data.vector.elem_type : operand_type;

    assert(scalar_type->id == ZigTypeIdInt);

    LLVMValueRef result;
    if (scalar_type->data.integral.is_signed) {
        result = LLVMBuildAShr(g->builder, val1, val2, "");
    } else {
        result = LLVMBuildLShr(g->builder, val1, val2, "");
    }
    LLVMValueRef orig_val = LLVMBuildShl(g->builder, result, val2, "");
    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, orig_val, "");

    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowOk");
    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "OverflowFail");
    if (operand_type->id == ZigTypeIdVector) {
        ok_bit = scalarize_cmp_result(g, ok_bit, ScalarizePredicate::All);
    }
    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

    LLVMPositionBuilderAtEnd(g->builder, fail_block);
    gen_safety_crash(g, PanicMsgIdShrOverflowedBits);

    LLVMPositionBuilderAtEnd(g->builder, ok_block);
    return result;
}

static LLVMValueRef gen_float_op(CodeGen *g, LLVMValueRef val, ZigType *type_entry, BuiltinFnId op) {
    assert(type_entry->id == ZigTypeIdFloat || type_entry->id == ZigTypeIdVector);
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

    if (LLVMGetTypeKind(type_ref) == LLVMVectorTypeKind) {
        const unsigned vector_len = LLVMGetVectorSize(type_ref);
        LLVMTypeRef elem_type = LLVMGetElementType(type_ref);

        LLVMValueRef *values = heap::c_allocator.allocate_nonzero<LLVMValueRef>(vector_len);
        // Create a vector with all the elements having the same value
        for (unsigned i = 0; i < vector_len; i++) {
            values[i] = bigint_to_llvm_const(elem_type, bigint);
        }
        LLVMValueRef result = LLVMConstVector(values, vector_len);
        heap::c_allocator.deallocate(values, vector_len);
        return result;
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
    LLVMValueRef val1, LLVMValueRef val2, ZigType *operand_type, DivKind div_kind)
{
    ZigType *scalar_type = (operand_type->id == ZigTypeIdVector) ?
        operand_type->data.vector.elem_type : operand_type;

    ZigLLVMSetFastMath(g->builder, want_fast_math);

    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, operand_type));
    if (want_runtime_safety && (want_fast_math || scalar_type->id != ZigTypeIdFloat)) {
        // Safety check: divisor != 0
        LLVMValueRef is_zero_bit;
        if (scalar_type->id == ZigTypeIdInt) {
            is_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");
        } else if (scalar_type->id == ZigTypeIdFloat) {
            is_zero_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, val2, zero, "");
        } else {
            zig_unreachable();
        }

        if (operand_type->id == ZigTypeIdVector) {
            is_zero_bit = scalarize_cmp_result(g, is_zero_bit, ScalarizePredicate::Any);
        }

        LLVMBasicBlockRef div_zero_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivZeroFail");
        LLVMBasicBlockRef div_zero_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivZeroOk");
        LLVMBuildCondBr(g->builder, is_zero_bit, div_zero_fail_block, div_zero_ok_block);

        LLVMPositionBuilderAtEnd(g->builder, div_zero_fail_block);
        gen_safety_crash(g, PanicMsgIdDivisionByZero);

        LLVMPositionBuilderAtEnd(g->builder, div_zero_ok_block);

        // Safety check: check for overflow (dividend = minInt and divisor = -1)
        if (scalar_type->id == ZigTypeIdInt && scalar_type->data.integral.is_signed) {
            LLVMValueRef neg_1_value = LLVMConstAllOnes(get_llvm_type(g, operand_type));
            BigInt int_min_bi = {0};
            eval_min_max_value_int(g, scalar_type, &int_min_bi, false);
            LLVMValueRef int_min_value = bigint_to_llvm_const(get_llvm_type(g, operand_type), &int_min_bi);

            LLVMBasicBlockRef overflow_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivOverflowFail");
            LLVMBasicBlockRef overflow_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivOverflowOk");
            LLVMValueRef num_is_int_min = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, int_min_value, "");
            LLVMValueRef den_is_neg_1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, neg_1_value, "");
            LLVMValueRef overflow_fail_bit = LLVMBuildAnd(g->builder, num_is_int_min, den_is_neg_1, "");
            if (operand_type->id == ZigTypeIdVector) {
                overflow_fail_bit = scalarize_cmp_result(g, overflow_fail_bit, ScalarizePredicate::Any);
            }
            LLVMBuildCondBr(g->builder, overflow_fail_bit, overflow_fail_block, overflow_ok_block);

            LLVMPositionBuilderAtEnd(g->builder, overflow_fail_block);
            gen_safety_crash(g, PanicMsgIdIntegerOverflow);

            LLVMPositionBuilderAtEnd(g->builder, overflow_ok_block);
        }
    }

    if (scalar_type->id == ZigTypeIdFloat) {
        LLVMValueRef result = LLVMBuildFDiv(g->builder, val1, val2, "");
        switch (div_kind) {
            case DivKindFloat:
                return result;
            case DivKindExact:
                if (want_runtime_safety) {
                    // Safety check: a / b == floor(a / b)
                    LLVMValueRef floored = gen_float_op(g, result, operand_type, BuiltinFnIdFloor);

                    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactOk");
                    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactFail");
                    LLVMValueRef ok_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, floored, result, "");
                    if (operand_type->id == ZigTypeIdVector) {
                        ok_bit = scalarize_cmp_result(g, ok_bit, ScalarizePredicate::All);
                    }
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
                    if (operand_type->id == ZigTypeIdVector) {
                        ltz = scalarize_cmp_result(g, ltz, ScalarizePredicate::Any);
                    }
                    LLVMBuildCondBr(g->builder, ltz, ltz_block, gez_block);

                    LLVMPositionBuilderAtEnd(g->builder, ltz_block);
                    LLVMValueRef ceiled = gen_float_op(g, result, operand_type, BuiltinFnIdCeil);
                    LLVMBasicBlockRef ceiled_end_block = LLVMGetInsertBlock(g->builder);
                    LLVMBuildBr(g->builder, end_block);

                    LLVMPositionBuilderAtEnd(g->builder, gez_block);
                    LLVMValueRef floored = gen_float_op(g, result, operand_type, BuiltinFnIdFloor);
                    LLVMBasicBlockRef floored_end_block = LLVMGetInsertBlock(g->builder);
                    LLVMBuildBr(g->builder, end_block);

                    LLVMPositionBuilderAtEnd(g->builder, end_block);
                    LLVMValueRef phi = LLVMBuildPhi(g->builder, get_llvm_type(g, operand_type), "");
                    LLVMValueRef incoming_values[] = { ceiled, floored };
                    LLVMBasicBlockRef incoming_blocks[] = { ceiled_end_block, floored_end_block };
                    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);
                    return phi;
                }
            case DivKindFloor:
                return gen_float_op(g, result, operand_type, BuiltinFnIdFloor);
        }
        zig_unreachable();
    }

    assert(scalar_type->id == ZigTypeIdInt);

    switch (div_kind) {
        case DivKindFloat:
            zig_unreachable();
        case DivKindTrunc:
            if (scalar_type->data.integral.is_signed) {
                return LLVMBuildSDiv(g->builder, val1, val2, "");
            } else {
                return LLVMBuildUDiv(g->builder, val1, val2, "");
            }
        case DivKindExact:
            if (want_runtime_safety) {
                // Safety check: a % b == 0
                LLVMValueRef remainder_val;
                if (scalar_type->data.integral.is_signed) {
                    remainder_val = LLVMBuildSRem(g->builder, val1, val2, "");
                } else {
                    remainder_val = LLVMBuildURem(g->builder, val1, val2, "");
                }

                LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactOk");
                LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "DivExactFail");
                LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, remainder_val, zero, "");
                if (operand_type->id == ZigTypeIdVector) {
                    ok_bit = scalarize_cmp_result(g, ok_bit, ScalarizePredicate::All);
                }
                LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

                LLVMPositionBuilderAtEnd(g->builder, fail_block);
                gen_safety_crash(g, PanicMsgIdExactDivisionRemainder);

                LLVMPositionBuilderAtEnd(g->builder, ok_block);
            }
            if (scalar_type->data.integral.is_signed) {
                return LLVMBuildExactSDiv(g->builder, val1, val2, "");
            } else {
                return LLVMBuildExactUDiv(g->builder, val1, val2, "");
            }
        case DivKindFloor:
            {
                if (!scalar_type->data.integral.is_signed) {
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
    LLVMValueRef val1, LLVMValueRef val2, ZigType *operand_type, RemKind rem_kind)
{
    ZigType *scalar_type = (operand_type->id == ZigTypeIdVector) ?
        operand_type->data.vector.elem_type : operand_type;

    ZigLLVMSetFastMath(g->builder, want_fast_math);

    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, operand_type));
    if (want_runtime_safety) {
        // Safety check: divisor != 0
        LLVMValueRef is_zero_bit;
        if (scalar_type->id == ZigTypeIdInt) {
            LLVMIntPredicate pred = scalar_type->data.integral.is_signed ? LLVMIntSLE : LLVMIntEQ;
            is_zero_bit = LLVMBuildICmp(g->builder, pred, val2, zero, "");
        } else if (scalar_type->id == ZigTypeIdFloat) {
            is_zero_bit = LLVMBuildFCmp(g->builder, LLVMRealOEQ, val2, zero, "");
        } else {
            zig_unreachable();
        }

        if (operand_type->id == ZigTypeIdVector) {
            is_zero_bit = scalarize_cmp_result(g, is_zero_bit, ScalarizePredicate::Any);
        }

        LLVMBasicBlockRef rem_zero_ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemZeroOk");
        LLVMBasicBlockRef rem_zero_fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "RemZeroFail");
        LLVMBuildCondBr(g->builder, is_zero_bit, rem_zero_fail_block, rem_zero_ok_block);

        LLVMPositionBuilderAtEnd(g->builder, rem_zero_fail_block);
        gen_safety_crash(g, PanicMsgIdRemainderDivisionByZero);

        LLVMPositionBuilderAtEnd(g->builder, rem_zero_ok_block);
    }

    if (scalar_type->id == ZigTypeIdFloat) {
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
        assert(scalar_type->id == ZigTypeIdInt);
        if (scalar_type->data.integral.is_signed) {
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

static void gen_shift_rhs_check(CodeGen *g, ZigType *lhs_type, ZigType *rhs_type, LLVMValueRef value) {
    // We only check if the rhs value of the shift expression is greater or
    // equal to the number of bits of the lhs if it's not a power of two,
    // otherwise the check is useful as the allowed values are limited by the
    // operand type itself
    if (!is_power_of_2(lhs_type->data.integral.bit_count)) {
        BigInt bit_count_bi = {0};
        bigint_init_unsigned(&bit_count_bi, lhs_type->data.integral.bit_count);
        LLVMValueRef bit_count_value = bigint_to_llvm_const(get_llvm_type(g, rhs_type),
            &bit_count_bi);

        LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "CheckFail");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "CheckOk");
        LLVMValueRef less_than_bit = LLVMBuildICmp(g->builder, LLVMIntULT, value, bit_count_value, "");
        if (rhs_type->id == ZigTypeIdVector) {
            less_than_bit = scalarize_cmp_result(g, less_than_bit, ScalarizePredicate::Any);
        }
        LLVMBuildCondBr(g->builder, less_than_bit, ok_block, fail_block);

        LLVMPositionBuilderAtEnd(g->builder, fail_block);
        gen_safety_crash(g, PanicMsgIdShxTooBigRhs);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }
}

static LLVMValueRef ir_render_bin_op(CodeGen *g, IrExecutableGen *executable,
        IrInstGenBinOp *bin_op_instruction)
{
    IrBinOp op_id = bin_op_instruction->op_id;
    IrInstGen *op1 = bin_op_instruction->op1;
    IrInstGen *op2 = bin_op_instruction->op2;

    ZigType *operand_type = op1->value->type;
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
                    get_codegen_ptr_type_bail(g, scalar_type) != nullptr)
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
                LLVMValueRef op2_casted = LLVMBuildZExt(g->builder, op2_value,
                    LLVMTypeOf(op1_value), "");

                if (want_runtime_safety) {
                    gen_shift_rhs_check(g, scalar_type, op2->value->type, op2_value);
                }

                bool is_sloppy = (op_id == IrBinOpBitShiftLeftLossy);
                if (is_sloppy) {
                    return LLVMBuildShl(g->builder, op1_value, op2_casted, "");
                } else if (want_runtime_safety) {
                    return gen_overflow_shl_op(g, operand_type, op1_value, op2_casted);
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
                LLVMValueRef op2_casted = LLVMBuildZExt(g->builder, op2_value,
                    LLVMTypeOf(op1_value), "");

                if (want_runtime_safety) {
                    gen_shift_rhs_check(g, scalar_type, op2->value->type, op2_value);
                }

                bool is_sloppy = (op_id == IrBinOpBitShiftRightLossy);
                if (is_sloppy) {
                    if (scalar_type->data.integral.is_signed) {
                        return LLVMBuildAShr(g->builder, op1_value, op2_casted, "");
                    } else {
                        return LLVMBuildLShr(g->builder, op1_value, op2_casted, "");
                    }
                } else if (want_runtime_safety) {
                    return gen_overflow_shr_op(g, operand_type, op1_value, op2_casted);
                } else if (scalar_type->data.integral.is_signed) {
                    return ZigLLVMBuildAShrExact(g->builder, op1_value, op2_casted, "");
                } else {
                    return ZigLLVMBuildLShrExact(g->builder, op1_value, op2_casted, "");
                }
            }
        case IrBinOpDivUnspecified:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, operand_type, DivKindFloat);
        case IrBinOpDivExact:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, operand_type, DivKindExact);
        case IrBinOpDivTrunc:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, operand_type, DivKindTrunc);
        case IrBinOpDivFloor:
            return gen_div(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, operand_type, DivKindFloor);
        case IrBinOpRemRem:
            return gen_rem(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, operand_type, RemKindRem);
        case IrBinOpRemMod:
            return gen_rem(g, want_runtime_safety, ir_want_fast_math(g, &bin_op_instruction->base),
                    op1_value, op2_value, operand_type, RemKindMod);
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
            bigint_as_usize(&biggest_possible_err_val) < g->errors_by_index.length)
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

static LLVMValueRef ir_render_cast(CodeGen *g, IrExecutableGen *executable,
        IrInstGenCast *cast_instruction)
{
    Error err;
    ZigType *actual_type = cast_instruction->value->value->type;
    ZigType *wanted_type = cast_instruction->base.value->type;
    bool wanted_type_has_bits;
    if ((err = type_has_bits2(g, wanted_type, &wanted_type_has_bits)))
        codegen_report_errors_and_exit(g);
    if (!wanted_type_has_bits)
        return nullptr;
    LLVMValueRef expr_val = ir_llvm_value(g, cast_instruction->value);
    ir_assert(expr_val, &cast_instruction->base);

    switch (cast_instruction->cast_op) {
        case CastOpNoCast:
        case CastOpNumLitToConcrete:
            zig_unreachable();
        case CastOpNoop:
            if (actual_type->id == ZigTypeIdPointer && wanted_type->id == ZigTypeIdPointer &&
                actual_type->data.pointer.child_type->id == ZigTypeIdArray &&
                wanted_type->data.pointer.child_type->id == ZigTypeIdArray)
            {
                return LLVMBuildBitCast(g->builder, expr_val, get_llvm_type(g, wanted_type), "");
            } else {
                return expr_val;
            }
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

static LLVMValueRef ir_render_ptr_of_array_to_slice(CodeGen *g, IrExecutableGen *executable,
        IrInstGenPtrOfArrayToSlice *instruction)
{
    ZigType *actual_type = instruction->operand->value->type;
    ZigType *slice_type = instruction->base.value->type;
    ZigType *slice_ptr_type = slice_type->data.structure.fields[slice_ptr_index]->type_entry;
    size_t ptr_index = slice_type->data.structure.fields[slice_ptr_index]->gen_index;
    size_t len_index = slice_type->data.structure.fields[slice_len_index]->gen_index;

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    assert(actual_type->id == ZigTypeIdPointer);
    ZigType *array_type = actual_type->data.pointer.child_type;
    assert(array_type->id == ZigTypeIdArray);

    if (type_has_bits(g, actual_type)) {
        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, result_loc, ptr_index, "");
        LLVMValueRef indices[] = {
            LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
            LLVMConstInt(g->builtin_types.entry_usize->llvm_type, 0, false),
        };
        LLVMValueRef expr_val = ir_llvm_value(g, instruction->operand);
        LLVMValueRef slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, expr_val, indices, 2, "");
        gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);
    } else if (ir_want_runtime_safety(g, &instruction->base)) {
        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, result_loc, ptr_index, "");
        gen_undef_init(g, slice_ptr_type->abi_align, slice_ptr_type, ptr_field_ptr);
    }

    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, result_loc, len_index, "");
    LLVMValueRef len_value = LLVMConstInt(g->builtin_types.entry_usize->llvm_type,
            array_type->data.array.len, false);
    gen_store_untyped(g, len_value, len_field_ptr, 0, false);

    return result_loc;
}

static LLVMValueRef ir_render_ptr_cast(CodeGen *g, IrExecutableGen *executable,
        IrInstGenPtrCast *instruction)
{
    ZigType *wanted_type = instruction->base.value->type;
    if (!type_has_bits(g, wanted_type)) {
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

static LLVMValueRef ir_render_bit_cast(CodeGen *g, IrExecutableGen *executable,
        IrInstGenBitCast *instruction)
{
    ZigType *wanted_type = instruction->base.value->type;
    ZigType *actual_type = instruction->operand->value->type;
    LLVMValueRef value = ir_llvm_value(g, instruction->operand);

    bool wanted_is_ptr = handle_is_ptr(g, wanted_type);
    bool actual_is_ptr = handle_is_ptr(g, actual_type);
    if (wanted_is_ptr == actual_is_ptr) {
        // We either bitcast the value directly or bitcast the pointer which does a pointer cast
        LLVMTypeRef wanted_type_ref = wanted_is_ptr ?
            LLVMPointerType(get_llvm_type(g, wanted_type), 0) : get_llvm_type(g, wanted_type);
        return LLVMBuildBitCast(g->builder, value, wanted_type_ref, "");
    } else if (actual_is_ptr) {
        // A scalar is wanted but we got a pointer
        LLVMTypeRef wanted_ptr_type_ref = LLVMPointerType(get_llvm_type(g, wanted_type), 0);
        LLVMValueRef bitcasted_ptr = LLVMBuildBitCast(g->builder, value, wanted_ptr_type_ref, "");
        uint32_t alignment = get_abi_alignment(g, actual_type);
        return gen_load_untyped(g, bitcasted_ptr, alignment, false, "");
    } else {
        // A pointer is wanted but we got a scalar
        assert(actual_type->id == ZigTypeIdPointer);
        LLVMTypeRef wanted_ptr_type_ref = LLVMPointerType(get_llvm_type(g, wanted_type), 0);
        return LLVMBuildBitCast(g->builder, value, wanted_ptr_type_ref, "");
    }
}

static LLVMValueRef ir_render_widen_or_shorten(CodeGen *g, IrExecutableGen *executable,
        IrInstGenWidenOrShorten *instruction)
{
    ZigType *actual_type = instruction->target->value->type;
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
            instruction->base.value->type, target_val);
}

static LLVMValueRef ir_render_int_to_ptr(CodeGen *g, IrExecutableGen *executable, IrInstGenIntToPtr *instruction) {
    ZigType *wanted_type = instruction->base.value->type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);

    if (ir_want_runtime_safety(g, &instruction->base)) {
        ZigType *usize = g->builtin_types.entry_usize;
        LLVMValueRef zero = LLVMConstNull(usize->llvm_type);

        if (!ptr_allows_addr_zero(wanted_type)) {
            LLVMValueRef is_zero_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, target_val, zero, "");
            LLVMBasicBlockRef bad_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrToIntBad");
            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrToIntOk");
            LLVMBuildCondBr(g->builder, is_zero_bit, bad_block, ok_block);

            LLVMPositionBuilderAtEnd(g->builder, bad_block);
            gen_safety_crash(g, PanicMsgIdPtrCastNull);

            LLVMPositionBuilderAtEnd(g->builder, ok_block);
        }

        {
            const uint32_t align_bytes = get_ptr_align(g, wanted_type);
            LLVMValueRef alignment_minus_1 = LLVMConstInt(usize->llvm_type, align_bytes - 1, false);
            LLVMValueRef anded_val = LLVMBuildAnd(g->builder, target_val, alignment_minus_1, "");
            LLVMValueRef is_ok_bit = LLVMBuildICmp(g->builder, LLVMIntEQ, anded_val, zero, "");
            LLVMBasicBlockRef bad_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrToIntAlignBad");
            LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "PtrToIntAlignOk");
            LLVMBuildCondBr(g->builder, is_ok_bit, ok_block, bad_block);

            LLVMPositionBuilderAtEnd(g->builder, bad_block);
            gen_safety_crash(g, PanicMsgIdIncorrectAlignment);

            LLVMPositionBuilderAtEnd(g->builder, ok_block);
        }
    }
    return LLVMBuildIntToPtr(g->builder, target_val, get_llvm_type(g, wanted_type), "");
}

static LLVMValueRef ir_render_ptr_to_int(CodeGen *g, IrExecutableGen *executable, IrInstGenPtrToInt *instruction) {
    ZigType *wanted_type = instruction->base.value->type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    return LLVMBuildPtrToInt(g->builder, target_val, get_llvm_type(g, wanted_type), "");
}

static LLVMValueRef ir_render_int_to_enum(CodeGen *g, IrExecutableGen *executable, IrInstGenIntToEnum *instruction) {
    ZigType *wanted_type = instruction->base.value->type;
    assert(wanted_type->id == ZigTypeIdEnum);
    ZigType *tag_int_type = wanted_type->data.enumeration.tag_int_type;

    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    LLVMValueRef tag_int_value = gen_widen_or_shorten(g, ir_want_runtime_safety(g, &instruction->base),
            instruction->target->value->type, tag_int_type, target_val);

    if (ir_want_runtime_safety(g, &instruction->base) && !wanted_type->data.enumeration.non_exhaustive) {
        LLVMBasicBlockRef bad_value_block = LLVMAppendBasicBlock(g->cur_fn_val, "BadValue");
        LLVMBasicBlockRef ok_value_block = LLVMAppendBasicBlock(g->cur_fn_val, "OkValue");
        size_t field_count = wanted_type->data.enumeration.src_field_count;
        LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, tag_int_value, bad_value_block, field_count);

        HashMap<BigInt, Buf *, bigint_hash, bigint_eql> occupied_tag_values = {};
        occupied_tag_values.init(field_count);

        for (size_t field_i = 0; field_i < field_count; field_i += 1) {
            TypeEnumField *type_enum_field = &wanted_type->data.enumeration.fields[field_i];

            Buf *name = type_enum_field->name;
            auto entry = occupied_tag_values.put_unique(type_enum_field->value, name);
            if (entry != nullptr) {
                continue;
            }

            LLVMValueRef this_tag_int_value = bigint_to_llvm_const(get_llvm_type(g, tag_int_type),
                    &type_enum_field->value);
            LLVMAddCase(switch_instr, this_tag_int_value, ok_value_block);
        }
        occupied_tag_values.deinit();
        LLVMPositionBuilderAtEnd(g->builder, bad_value_block);
        gen_safety_crash(g, PanicMsgIdBadEnumValue);

        LLVMPositionBuilderAtEnd(g->builder, ok_value_block);
    }
    return tag_int_value;
}

static LLVMValueRef ir_render_int_to_err(CodeGen *g, IrExecutableGen *executable, IrInstGenIntToErr *instruction) {
    ZigType *wanted_type = instruction->base.value->type;
    assert(wanted_type->id == ZigTypeIdErrorSet);

    ZigType *actual_type = instruction->target->value->type;
    assert(actual_type->id == ZigTypeIdInt);
    assert(!actual_type->data.integral.is_signed);

    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);

    if (ir_want_runtime_safety(g, &instruction->base)) {
        add_error_range_check(g, wanted_type, actual_type, target_val);
    }

    return gen_widen_or_shorten(g, false, actual_type, g->err_tag_type, target_val);
}

static LLVMValueRef ir_render_err_to_int(CodeGen *g, IrExecutableGen *executable, IrInstGenErrToInt *instruction) {
    ZigType *wanted_type = instruction->base.value->type;
    assert(wanted_type->id == ZigTypeIdInt);
    assert(!wanted_type->data.integral.is_signed);

    ZigType *actual_type = instruction->target->value->type;
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);

    if (actual_type->id == ZigTypeIdErrorSet) {
        return gen_widen_or_shorten(g, ir_want_runtime_safety(g, &instruction->base),
            g->err_tag_type, wanted_type, target_val);
    } else if (actual_type->id == ZigTypeIdErrorUnion) {
        // this should have been a compile time constant
        assert(type_has_bits(g, actual_type->data.error_union.err_set_type));

        if (!type_has_bits(g, actual_type->data.error_union.payload_type)) {
            return gen_widen_or_shorten(g, ir_want_runtime_safety(g, &instruction->base),
                g->err_tag_type, wanted_type, target_val);
        } else {
            zig_panic("TODO err to int when error union payload type not void");
        }
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef ir_render_unreachable(CodeGen *g, IrExecutableGen *executable,
        IrInstGenUnreachable *unreachable_instruction)
{
    if (ir_want_runtime_safety(g, &unreachable_instruction->base)) {
        gen_safety_crash(g, PanicMsgIdUnreachable);
    } else {
        LLVMBuildUnreachable(g->builder);
    }
    return nullptr;
}

static LLVMValueRef ir_render_cond_br(CodeGen *g, IrExecutableGen *executable,
        IrInstGenCondBr *cond_br_instruction)
{
    LLVMBuildCondBr(g->builder,
            ir_llvm_value(g, cond_br_instruction->condition),
            cond_br_instruction->then_block->llvm_block,
            cond_br_instruction->else_block->llvm_block);
    return nullptr;
}

static LLVMValueRef ir_render_br(CodeGen *g, IrExecutableGen *executable, IrInstGenBr *br_instruction) {
    LLVMBuildBr(g->builder, br_instruction->dest_block->llvm_block);
    return nullptr;
}

static LLVMValueRef ir_render_binary_not(CodeGen *g, IrExecutableGen *executable,
        IrInstGenBinaryNot *inst)
{
    LLVMValueRef operand = ir_llvm_value(g, inst->operand);
    return LLVMBuildNot(g->builder, operand, "");
}

static LLVMValueRef ir_gen_negation(CodeGen *g, IrInstGen *inst, IrInstGen *operand, bool wrapping) {
    LLVMValueRef llvm_operand = ir_llvm_value(g, operand);
    ZigType *operand_type = operand->value->type;
    ZigType *scalar_type = (operand_type->id == ZigTypeIdVector) ?
        operand_type->data.vector.elem_type : operand_type;

    if (scalar_type->id == ZigTypeIdFloat) {
        ZigLLVMSetFastMath(g->builder, ir_want_fast_math(g, inst));
        return LLVMBuildFNeg(g->builder, llvm_operand, "");
    } else if (scalar_type->id == ZigTypeIdInt) {
        if (wrapping) {
            return LLVMBuildNeg(g->builder, llvm_operand, "");
        } else if (ir_want_runtime_safety(g, inst)) {
            LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(llvm_operand));
            return gen_overflow_op(g, operand_type, AddSubMulSub, zero, llvm_operand);
        } else if (scalar_type->data.integral.is_signed) {
            return LLVMBuildNSWNeg(g->builder, llvm_operand, "");
        } else {
            zig_unreachable();
        }
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef ir_render_negation(CodeGen *g, IrExecutableGen *executable,
        IrInstGenNegation *inst)
{
    return ir_gen_negation(g, &inst->base, inst->operand, false);
}

static LLVMValueRef ir_render_negation_wrapping(CodeGen *g, IrExecutableGen *executable,
        IrInstGenNegationWrapping *inst)
{
    return ir_gen_negation(g, &inst->base, inst->operand, true);
}

static LLVMValueRef ir_render_bool_not(CodeGen *g, IrExecutableGen *executable, IrInstGenBoolNot *instruction) {
    LLVMValueRef value = ir_llvm_value(g, instruction->value);
    LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(value));
    return LLVMBuildICmp(g->builder, LLVMIntEQ, value, zero, "");
}

static void render_decl_var(CodeGen *g, ZigVar *var) {
    if (!type_has_bits(g, var->var_type))
        return;

    var->value_ref = ir_llvm_value(g, var->ptr_instruction);
    gen_var_debug_decl(g, var);
}

static LLVMValueRef ir_render_decl_var(CodeGen *g, IrExecutableGen *executable, IrInstGenDeclVar *instruction) {
    instruction->var->ptr_instruction = instruction->var_ptr;
    instruction->var->did_the_decl_codegen = true;
    render_decl_var(g, instruction->var);
    return nullptr;
}

static LLVMValueRef ir_render_load_ptr(CodeGen *g, IrExecutableGen *executable,
        IrInstGenLoadPtr *instruction)
{
    ZigType *child_type = instruction->base.value->type;
    if (!type_has_bits(g, child_type))
        return nullptr;

    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    ZigType *ptr_type = instruction->ptr->value->type;
    assert(ptr_type->id == ZigTypeIdPointer);

    ir_assert(ptr_type->data.pointer.vector_index != VECTOR_INDEX_RUNTIME, &instruction->base);
    if (ptr_type->data.pointer.vector_index != VECTOR_INDEX_NONE) {
        LLVMValueRef index_val = LLVMConstInt(LLVMInt32Type(),
                ptr_type->data.pointer.vector_index, false);
        LLVMValueRef loaded_vector = LLVMBuildLoad(g->builder, ptr, "");
        return LLVMBuildExtractElement(g->builder, loaded_vector, index_val, "");
    }

    uint32_t host_int_bytes = ptr_type->data.pointer.host_int_bytes;
    if (host_int_bytes == 0)
        return get_handle_value(g, ptr, child_type, ptr_type);

    bool big_endian = g->is_big_endian;

    LLVMTypeRef int_ptr_ty = LLVMPointerType(LLVMIntType(host_int_bytes * 8), 0);
    LLVMValueRef int_ptr = LLVMBuildBitCast(g->builder, ptr, int_ptr_ty, "");
    LLVMValueRef containing_int = gen_load(g, int_ptr, ptr_type, "");

    uint32_t host_bit_count = LLVMGetIntTypeWidth(LLVMTypeOf(containing_int));
    assert(host_bit_count == host_int_bytes * 8);
    uint32_t size_in_bits = type_size_bits(g, child_type);

    uint32_t bit_offset = ptr_type->data.pointer.bit_offset_in_host;
    uint32_t shift_amt = big_endian ? host_bit_count - bit_offset - size_in_bits : bit_offset;

    LLVMValueRef shift_amt_val = LLVMConstInt(LLVMTypeOf(containing_int), shift_amt, false);
    LLVMValueRef shifted_value = LLVMBuildLShr(g->builder, containing_int, shift_amt_val, "");

    if (handle_is_ptr(g, child_type)) {
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

static bool value_is_all_undef_array(CodeGen *g, ZigValue *const_val, size_t len) {
    switch (const_val->data.x_array.special) {
        case ConstArraySpecialUndef:
            return true;
        case ConstArraySpecialBuf:
            return false;
        case ConstArraySpecialNone:
            for (size_t i = 0; i < len; i += 1) {
                if (!value_is_all_undef(g, &const_val->data.x_array.data.s_none.elements[i]))
                    return false;
            }
            return true;
    }
    zig_unreachable();
}

static bool value_is_all_undef(CodeGen *g, ZigValue *const_val) {
    Error err;
    if (const_val->special == ConstValSpecialLazy &&
        (err = ir_resolve_lazy(g, nullptr, const_val)))
        codegen_report_errors_and_exit(g);

    switch (const_val->special) {
        case ConstValSpecialLazy:
            zig_unreachable();
        case ConstValSpecialRuntime:
            return false;
        case ConstValSpecialUndef:
            return true;
        case ConstValSpecialStatic:
            if (const_val->type->id == ZigTypeIdStruct) {
                for (size_t i = 0; i < const_val->type->data.structure.src_field_count; i += 1) {
                    if (!value_is_all_undef(g, const_val->data.x_struct.fields[i]))
                        return false;
                }
                return true;
            } else if (const_val->type->id == ZigTypeIdArray) {
                return value_is_all_undef_array(g, const_val, const_val->type->data.array.len);
            } else if (const_val->type->id == ZigTypeIdVector) {
                return value_is_all_undef_array(g, const_val, const_val->type->data.vector.len);
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
    assert(type_has_bits(g, value_type));
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

static LLVMValueRef ir_render_store_ptr(CodeGen *g, IrExecutableGen *executable, IrInstGenStorePtr *instruction) {
    Error err;

    ZigType *ptr_type = instruction->ptr->value->type;
    assert(ptr_type->id == ZigTypeIdPointer);
    bool ptr_type_has_bits;
    if ((err = type_has_bits2(g, ptr_type, &ptr_type_has_bits)))
        codegen_report_errors_and_exit(g);
    if (!ptr_type_has_bits)
        return nullptr;
    if (instruction->ptr->base.ref_count == 0) {
        // In this case, this StorePtr instruction should be elided. Something happened like this:
        //     var t = true;
        //     const x = if (t) Num.Two else unreachable;
        // The if condition is a runtime value, so the StorePtr for `x = Num.Two` got generated
        // (this instruction being rendered) but because of `else unreachable` the result ended
        // up being a comptime const value.
        return nullptr;
    }

    bool have_init_expr = !value_is_all_undef(g, instruction->value->value);
    if (have_init_expr) {
        LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
        LLVMValueRef value = ir_llvm_value(g, instruction->value);
        gen_assign_raw(g, ptr, ptr_type, value);
    } else if (ir_want_runtime_safety(g, &instruction->base)) {
        gen_undef_init(g, get_ptr_align(g, ptr_type), instruction->value->value->type,
            ir_llvm_value(g, instruction->ptr));
    }
    return nullptr;
}

static LLVMValueRef ir_render_vector_store_elem(CodeGen *g, IrExecutableGen *executable,
        IrInstGenVectorStoreElem *instruction)
{
    LLVMValueRef vector_ptr = ir_llvm_value(g, instruction->vector_ptr);
    LLVMValueRef index = ir_llvm_value(g, instruction->index);
    LLVMValueRef value = ir_llvm_value(g, instruction->value);

    LLVMValueRef loaded_vector = gen_load(g, vector_ptr, instruction->vector_ptr->value->type, "");
    LLVMValueRef modified_vector = LLVMBuildInsertElement(g->builder, loaded_vector, value, index, "");
    gen_store(g, modified_vector, vector_ptr, instruction->vector_ptr->value->type);
    return nullptr;
}

static LLVMValueRef ir_render_var_ptr(CodeGen *g, IrExecutableGen *executable, IrInstGenVarPtr *instruction) {
    if (instruction->base.value->special != ConstValSpecialRuntime)
        return ir_llvm_value(g, &instruction->base);
    ZigVar *var = instruction->var;
    if (type_has_bits(g, var->var_type)) {
        assert(var->value_ref);
        return var->value_ref;
    } else {
        return nullptr;
    }
}

static LLVMValueRef ir_render_return_ptr(CodeGen *g, IrExecutableGen *executable,
        IrInstGenReturnPtr *instruction)
{
    if (!type_has_bits(g, instruction->base.value->type))
        return nullptr;
    ir_assert(g->cur_ret_ptr != nullptr, &instruction->base);
    return g->cur_ret_ptr;
}

static LLVMValueRef ir_render_elem_ptr(CodeGen *g, IrExecutableGen *executable, IrInstGenElemPtr *instruction) {
    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->array_ptr);
    ZigType *array_ptr_type = instruction->array_ptr->value->type;
    assert(array_ptr_type->id == ZigTypeIdPointer);
    ZigType *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef subscript_value = ir_llvm_value(g, instruction->elem_index);
    assert(subscript_value);

    if (!type_has_bits(g, array_type))
        return nullptr;

    bool safety_check_on = ir_want_runtime_safety(g, &instruction->base) && instruction->safety_check_on;

    if (array_type->id == ZigTypeIdArray ||
        (array_type->id == ZigTypeIdPointer && array_type->data.pointer.ptr_len == PtrLenSingle))
    {
        LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);
        if (array_type->id == ZigTypeIdPointer) {
            assert(array_type->data.pointer.child_type->id == ZigTypeIdArray);
            array_type = array_type->data.pointer.child_type;
        }

        assert(array_type->data.array.len != 0 || array_type->data.array.sentinel != nullptr);

        if (safety_check_on) {
            uint64_t extra_len_from_sentinel = (array_type->data.array.sentinel != nullptr) ? 1 : 0;
            uint64_t full_len = array_type->data.array.len + extra_len_from_sentinel;
            LLVMValueRef end = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, full_len, false);
            add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, end);
        }
        if (array_ptr_type->data.pointer.host_int_bytes != 0) {
            return array_ptr_ptr;
        }
        ZigType *child_type = array_type->data.array.child_type;
        if (child_type->id == ZigTypeIdStruct &&
            child_type->data.structure.layout == ContainerLayoutPacked)
        {
            ZigType *ptr_type = instruction->base.value->type;
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
        LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        LLVMValueRef indices[] = {
            subscript_value
        };
        return LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 1, "");
    } else if (array_type->id == ZigTypeIdStruct) {
        LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);
        assert(array_type->data.structure.special == StructSpecialSlice);

        ZigType *ptr_type = array_type->data.structure.fields[slice_ptr_index]->type_entry;
        if (!type_has_bits(g, ptr_type)) {
            if (safety_check_on) {
                assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMIntegerTypeKind);
                add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, LLVMIntULT, array_ptr);
            }
            return nullptr;
        }

        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        if (safety_check_on) {
            size_t len_index = array_type->data.structure.fields[slice_len_index]->gen_index;
            assert(len_index != SIZE_MAX);
            LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)len_index, "");
            LLVMValueRef len = gen_load_untyped(g, len_ptr, 0, false, "");
            LLVMIntPredicate upper_op = (ptr_type->data.pointer.sentinel != nullptr) ? LLVMIntULE : LLVMIntULT;
            add_bounds_check(g, subscript_value, LLVMIntEQ, nullptr, upper_op, len);
        }

        size_t ptr_index = array_type->data.structure.fields[slice_ptr_index]->gen_index;
        assert(ptr_index != SIZE_MAX);
        LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, (unsigned)ptr_index, "");
        LLVMValueRef ptr = gen_load_untyped(g, ptr_ptr, 0, false, "");
        return LLVMBuildInBoundsGEP(g->builder, ptr, &subscript_value, 1, "");
    } else if (array_type->id == ZigTypeIdVector) {
        return array_ptr_ptr;
    } else {
        zig_unreachable();
    }
}

static LLVMValueRef get_new_stack_addr(CodeGen *g, LLVMValueRef new_stack) {
    LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, new_stack, (unsigned)slice_ptr_index, "");
    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, new_stack, (unsigned)slice_len_index, "");

    LLVMValueRef ptr_value = gen_load_untyped(g, ptr_field_ptr, 0, false, "");
    LLVMValueRef len_value = gen_load_untyped(g, len_field_ptr, 0, false, "");

    LLVMValueRef ptr_addr = LLVMBuildPtrToInt(g->builder, ptr_value, LLVMTypeOf(len_value), "");
    LLVMValueRef end_addr = LLVMBuildNUWAdd(g->builder, ptr_addr, len_value, "");
    const unsigned alignment_factor = ZigLLVMDataLayoutGetStackAlignment(g->target_data_ref);
    LLVMValueRef align_amt = LLVMConstInt(LLVMTypeOf(end_addr), alignment_factor, false);
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

static void render_async_spills(CodeGen *g) {
    ZigType *fn_type = g->cur_fn->type_entry;
    ZigType *import = get_scope_import(&g->cur_fn->fndef_scope->base);

    CalcLLVMFieldIndex arg_calc = {0};
    frame_index_arg_calc(g, &arg_calc, fn_type->data.fn.fn_type_id.return_type);
    for (size_t var_i = 0; var_i < g->cur_fn->variable_list.length; var_i += 1) {
        ZigVar *var = g->cur_fn->variable_list.at(var_i);

        if (!type_has_bits(g, var->var_type)) {
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
            continue;
        }

        calc_llvm_field_index_add(g, &arg_calc, var->var_type);
        var->value_ref = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr, arg_calc.field_index - 1, var->name);
        if (var->decl_node) {
            var->di_loc_var = ZigLLVMCreateAutoVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                var->name, import->data.structure.root_struct->di_file,
                (unsigned)(var->decl_node->line + 1),
                get_llvm_di_type(g, var->var_type), !g->strip_debug_symbols, 0);
            gen_var_debug_decl(g, var);
        }
    }

    ZigType *frame_type = g->cur_fn->frame_type->data.frame.locals_struct;

    for (size_t alloca_i = 0; alloca_i < g->cur_fn->alloca_gen_list.length; alloca_i += 1) {
        IrInstGenAlloca *instruction = g->cur_fn->alloca_gen_list.at(alloca_i);
        if (instruction->field_index == SIZE_MAX)
            continue;

        size_t gen_index = frame_type->data.structure.fields[instruction->field_index]->gen_index;
        instruction->base.llvm_value = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr, gen_index,
                instruction->name_hint);
    }
}

static void render_async_var_decls(CodeGen *g, Scope *scope) {
    for (;;) {
        switch (scope->id) {
            case ScopeIdCImport:
                zig_unreachable();
            case ScopeIdFnDef:
                return;
            case ScopeIdVarDecl: {
                ZigVar *var = reinterpret_cast<ScopeVarDecl *>(scope)->var;
                if (var->did_the_decl_codegen) {
                    render_decl_var(g, var);
                }
            }
            ZIG_FALLTHROUGH;

            case ScopeIdDecls:
            case ScopeIdBlock:
            case ScopeIdDefer:
            case ScopeIdDeferExpr:
            case ScopeIdLoop:
            case ScopeIdSuspend:
            case ScopeIdCompTime:
            case ScopeIdNoSuspend:
            case ScopeIdRuntime:
            case ScopeIdTypeOf:
            case ScopeIdExpr:
                scope = scope->parent;
                continue;
        }
    }
}

static LLVMValueRef gen_frame_size(CodeGen *g, LLVMValueRef fn_val) {
    assert(g->need_frame_size_prefix_data);
    LLVMTypeRef usize_llvm_type = g->builtin_types.entry_usize->llvm_type;
    LLVMTypeRef ptr_usize_llvm_type = LLVMPointerType(usize_llvm_type, 0);
    LLVMValueRef casted_fn_val = LLVMBuildBitCast(g->builder, fn_val, ptr_usize_llvm_type, "");
    LLVMValueRef negative_one = LLVMConstInt(LLVMInt32Type(), -1, true);
    LLVMValueRef prefix_ptr = LLVMBuildInBoundsGEP(g->builder, casted_fn_val, &negative_one, 1, "");
    return LLVMBuildLoad(g->builder, prefix_ptr, "");
}

static void gen_init_stack_trace(CodeGen *g, LLVMValueRef trace_field_ptr, LLVMValueRef addrs_field_ptr) {
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
    LLVMValueRef zero = LLVMConstNull(usize_type_ref);

    LLVMValueRef index_ptr = LLVMBuildStructGEP(g->builder, trace_field_ptr, 0, "");
    LLVMBuildStore(g->builder, zero, index_ptr);

    LLVMValueRef addrs_slice_ptr = LLVMBuildStructGEP(g->builder, trace_field_ptr, 1, "");
    LLVMValueRef addrs_ptr_ptr = LLVMBuildStructGEP(g->builder, addrs_slice_ptr, slice_ptr_index, "");
    LLVMValueRef indices[] = { LLVMConstNull(usize_type_ref), LLVMConstNull(usize_type_ref) };
    LLVMValueRef trace_field_addrs_as_ptr = LLVMBuildInBoundsGEP(g->builder, addrs_field_ptr, indices, 2, "");
    LLVMBuildStore(g->builder, trace_field_addrs_as_ptr, addrs_ptr_ptr);

    LLVMValueRef addrs_len_ptr = LLVMBuildStructGEP(g->builder, addrs_slice_ptr, slice_len_index, "");
    LLVMBuildStore(g->builder, LLVMConstInt(usize_type_ref, stack_trace_ptr_count, false), addrs_len_ptr);
}

static LLVMValueRef ir_render_call(CodeGen *g, IrExecutableGen *executable, IrInstGenCall *instruction) {
    Error err;

    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;

    LLVMValueRef fn_val;
    ZigType *fn_type;
    bool callee_is_async;
    if (instruction->fn_entry) {
        fn_val = fn_llvm_value(g, instruction->fn_entry);
        fn_type = instruction->fn_entry->type_entry;
        callee_is_async = fn_is_async(instruction->fn_entry);
    } else {
        assert(instruction->fn_ref);
        fn_val = ir_llvm_value(g, instruction->fn_ref);
        fn_type = instruction->fn_ref->value->type;
        callee_is_async = fn_type->data.fn.fn_type_id.cc == CallingConventionAsync;
    }

    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;

    ZigType *src_return_type = fn_type_id->return_type;
    bool ret_has_bits = type_has_bits(g, src_return_type);

    CallingConvention cc = fn_type->data.fn.fn_type_id.cc;

    bool first_arg_ret = ret_has_bits && want_first_arg_sret(g, fn_type_id);
    bool prefix_arg_err_ret_stack = codegen_fn_has_err_ret_tracing_arg(g, fn_type_id->return_type);
    bool is_var_args = fn_type_id->is_var_args;
    ZigList<LLVMValueRef> gen_param_values = {};
    ZigList<ZigType *> gen_param_types = {};
    LLVMValueRef result_loc = instruction->result_loc ? ir_llvm_value(g, instruction->result_loc) : nullptr;
    LLVMValueRef zero = LLVMConstNull(usize_type_ref);
    bool need_frame_ptr_ptr_spill = false;
    ZigType *anyframe_type = nullptr;
    LLVMValueRef frame_result_loc_uncasted = nullptr;
    LLVMValueRef frame_result_loc;
    LLVMValueRef awaiter_init_val;
    LLVMValueRef ret_ptr;
    if (callee_is_async) {
        if (instruction->new_stack == nullptr) {
            if (instruction->modifier == CallModifierAsync) {
                frame_result_loc = result_loc;
            } else {
                ir_assert(instruction->frame_result_loc != nullptr, &instruction->base);
                frame_result_loc_uncasted = ir_llvm_value(g, instruction->frame_result_loc);
                ir_assert(instruction->fn_entry != nullptr, &instruction->base);
                frame_result_loc = LLVMBuildBitCast(g->builder, frame_result_loc_uncasted,
                        LLVMPointerType(get_llvm_type(g, instruction->fn_entry->frame_type), 0), "");
            }
        } else {
            if (instruction->new_stack->value->type->id == ZigTypeIdPointer &&
                instruction->new_stack->value->type->data.pointer.child_type->id == ZigTypeIdFnFrame)
            {
                frame_result_loc = ir_llvm_value(g, instruction->new_stack);
            } else {
                LLVMValueRef frame_slice_ptr = ir_llvm_value(g, instruction->new_stack);
                if (ir_want_runtime_safety(g, &instruction->base)) {
                    LLVMValueRef given_len_ptr = LLVMBuildStructGEP(g->builder, frame_slice_ptr, slice_len_index, "");
                    LLVMValueRef given_frame_len = LLVMBuildLoad(g->builder, given_len_ptr, "");
                    LLVMValueRef actual_frame_len = gen_frame_size(g, fn_val);

                    LLVMBasicBlockRef fail_block = LLVMAppendBasicBlock(g->cur_fn_val, "FrameSizeCheckFail");
                    LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "FrameSizeCheckOk");

                    LLVMValueRef ok_bit = LLVMBuildICmp(g->builder, LLVMIntUGE, given_frame_len, actual_frame_len, "");
                    LLVMBuildCondBr(g->builder, ok_bit, ok_block, fail_block);

                    LLVMPositionBuilderAtEnd(g->builder, fail_block);
                    gen_safety_crash(g, PanicMsgIdFrameTooSmall);

                    LLVMPositionBuilderAtEnd(g->builder, ok_block);
                }
                need_frame_ptr_ptr_spill = true;
                LLVMValueRef frame_ptr_ptr = LLVMBuildStructGEP(g->builder, frame_slice_ptr, slice_ptr_index, "");
                LLVMValueRef frame_ptr = LLVMBuildLoad(g->builder, frame_ptr_ptr, "");
                if (instruction->fn_entry == nullptr) {
                    anyframe_type = get_any_frame_type(g, src_return_type);
                    frame_result_loc = LLVMBuildBitCast(g->builder, frame_ptr, get_llvm_type(g, anyframe_type), "");
                } else {
                    ZigType *frame_type = get_fn_frame_type(g, instruction->fn_entry);
                    if ((err = type_resolve(g, frame_type, ResolveStatusLLVMFull)))
                        codegen_report_errors_and_exit(g);
                    ZigType *ptr_frame_type = get_pointer_to_type(g, frame_type, false);
                    frame_result_loc = LLVMBuildBitCast(g->builder, frame_ptr,
                            get_llvm_type(g, ptr_frame_type), "");
                }
            }
        }
        if (instruction->modifier == CallModifierAsync) {
            if (instruction->new_stack == nullptr) {
                awaiter_init_val = zero;

                if (ret_has_bits) {
                    // Use the result location which is inside the frame if this is an async call.
                    ret_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start + 2, "");
                }
            } else {
                awaiter_init_val = zero;

                if (ret_has_bits) {
                    if (result_loc != nullptr) {
                        // Use the result location provided to the @asyncCall builtin
                        ret_ptr = result_loc;
                    } else {
                        // no result location provided to @asyncCall - use the one inside the frame.
                        ret_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start + 2, "");
                    }
                }
            }

            // even if prefix_arg_err_ret_stack is true, let the async function do its own
            // initialization.
        } else {
            if (instruction->modifier == CallModifierNoSuspend && !fn_is_async(g->cur_fn)) {
                // Async function called as a normal function, and calling function is not async.
                // This is allowed because it was called with `nosuspend` which asserts that it will
                // never suspend.
                awaiter_init_val = zero;
            } else {
                // async function called as a normal function
                awaiter_init_val = LLVMBuildPtrToInt(g->builder, g->cur_frame_ptr, usize_type_ref, ""); // caller's own frame pointer
            }
            if (ret_has_bits) {
                if (result_loc == nullptr) {
                    // return type is a scalar, but we still need a pointer to it. Use the async fn frame.
                    ret_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start + 2, "");
                } else {
                    // Use the call instruction's result location.
                    ret_ptr = result_loc;
                }

                // Store a zero in the awaiter's result ptr to indicate we do not need a copy made.
                LLVMValueRef awaiter_ret_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start + 1, "");
                LLVMValueRef zero_ptr = LLVMConstNull(LLVMGetElementType(LLVMTypeOf(awaiter_ret_ptr)));
                LLVMBuildStore(g->builder, zero_ptr, awaiter_ret_ptr);
            }

            if (prefix_arg_err_ret_stack) {
                LLVMValueRef err_ret_trace_ptr_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc,
                        frame_index_trace_arg(g, src_return_type) + 1, "");
                bool is_llvm_alloca;
                LLVMValueRef my_err_ret_trace_val = get_cur_err_ret_trace_val(g, instruction->base.base.scope,
                        &is_llvm_alloca);
                LLVMBuildStore(g->builder, my_err_ret_trace_val, err_ret_trace_ptr_ptr);
            }
        }

        assert(frame_result_loc != nullptr);

        LLVMValueRef fn_ptr_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_fn_ptr_index, "");
        LLVMValueRef bitcasted_fn_val = LLVMBuildBitCast(g->builder, fn_val,
                LLVMGetElementType(LLVMTypeOf(fn_ptr_ptr)), "");
        LLVMBuildStore(g->builder, bitcasted_fn_val, fn_ptr_ptr);

        LLVMValueRef resume_index_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_resume_index, "");
        LLVMBuildStore(g->builder, zero, resume_index_ptr);

        LLVMValueRef awaiter_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_awaiter_index, "");
        LLVMBuildStore(g->builder, awaiter_init_val, awaiter_ptr);

        if (ret_has_bits) {
            LLVMValueRef ret_ptr_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start, "");
            LLVMBuildStore(g->builder, ret_ptr, ret_ptr_ptr);
        }
    } else if (instruction->modifier == CallModifierAsync) {
        // Async call of blocking function
        if (instruction->new_stack != nullptr) {
            zig_panic("TODO @asyncCall of non-async function");
        }
        frame_result_loc = result_loc;
        awaiter_init_val = LLVMConstAllOnes(usize_type_ref);

        LLVMValueRef awaiter_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_awaiter_index, "");
        LLVMBuildStore(g->builder, awaiter_init_val, awaiter_ptr);

        if (ret_has_bits) {
            ret_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start + 2, "");
            LLVMValueRef ret_ptr_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start, "");
            LLVMBuildStore(g->builder, ret_ptr, ret_ptr_ptr);

            if (first_arg_ret) {
                gen_param_values.append(ret_ptr);
            }
            if (prefix_arg_err_ret_stack) {
                // Set up the callee stack trace pointer pointing into the frame.
                // Then we have to wire up the StackTrace pointers.
                // Await is responsible for merging error return traces.
                uint32_t trace_field_index_start = frame_index_trace_arg(g, src_return_type);
                LLVMValueRef callee_trace_ptr_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc,
                        trace_field_index_start, "");
                LLVMValueRef trace_field_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc,
                        trace_field_index_start + 2, "");
                LLVMValueRef addrs_field_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc,
                        trace_field_index_start + 3, "");

                LLVMBuildStore(g->builder, trace_field_ptr, callee_trace_ptr_ptr);

                gen_init_stack_trace(g, trace_field_ptr, addrs_field_ptr);

                bool is_llvm_alloca;
                gen_param_values.append(get_cur_err_ret_trace_val(g, instruction->base.base.scope, &is_llvm_alloca));
            }
        }
    } else {
        if (first_arg_ret) {
            gen_param_values.append(result_loc);
        }
        if (prefix_arg_err_ret_stack) {
            bool is_llvm_alloca;
            gen_param_values.append(get_cur_err_ret_trace_val(g, instruction->base.base.scope, &is_llvm_alloca));
        }
    }
    FnWalk fn_walk = {};
    fn_walk.id = FnWalkIdCall;
    fn_walk.data.call.inst = instruction;
    fn_walk.data.call.is_var_args = is_var_args;
    fn_walk.data.call.gen_param_values = &gen_param_values;
    fn_walk.data.call.gen_param_types = &gen_param_types;
    walk_function_params(g, fn_type, &fn_walk);

    ZigLLVM_CallAttr call_attr;
    switch (instruction->modifier) {
        case CallModifierBuiltin:
        case CallModifierCompileTime:
            zig_unreachable();
        case CallModifierNone:
        case CallModifierNoSuspend:
        case CallModifierAsync:
            call_attr = ZigLLVM_CallAttrAuto;
            break;
        case CallModifierNeverTail:
            call_attr = ZigLLVM_CallAttrNeverTail;
            break;
        case CallModifierNeverInline:
            call_attr = ZigLLVM_CallAttrNeverInline;
            break;
        case CallModifierAlwaysTail:
            call_attr = ZigLLVM_CallAttrAlwaysTail;
            break;
        case CallModifierAlwaysInline:
            ir_assert(instruction->fn_entry != nullptr, &instruction->base);
            call_attr = ZigLLVM_CallAttrAlwaysInline;
            break;
    }

    ZigLLVM_CallingConv llvm_cc = get_llvm_cc(g, cc);
    LLVMValueRef result;

    if (callee_is_async) {
        CalcLLVMFieldIndex arg_calc_start = {0};
        frame_index_arg_calc(g, &arg_calc_start, fn_type->data.fn.fn_type_id.return_type);

        LLVMValueRef casted_frame;
        if (instruction->new_stack != nullptr && instruction->fn_entry == nullptr) {
            // We need the frame type to be a pointer to a struct that includes the args

            // Count ahead to determine how many llvm struct fields we need.
            CalcLLVMFieldIndex arg_calc = arg_calc_start;
            for (size_t i = 0; i < gen_param_types.length; i += 1) {
                calc_llvm_field_index_add(g, &arg_calc, gen_param_types.at(i));
            }
            size_t field_count = arg_calc.field_index;

            LLVMTypeRef *field_types = heap::c_allocator.allocate_nonzero<LLVMTypeRef>(field_count);
            LLVMGetStructElementTypes(LLVMGetElementType(LLVMTypeOf(frame_result_loc)), field_types);
            assert(LLVMCountStructElementTypes(LLVMGetElementType(LLVMTypeOf(frame_result_loc))) == arg_calc_start.field_index);

            arg_calc = arg_calc_start;
            for (size_t arg_i = 0; arg_i < gen_param_values.length; arg_i += 1) {
                CalcLLVMFieldIndex prev = arg_calc;
                calc_llvm_field_index_add(g, &arg_calc, gen_param_types.at(arg_i));
                field_types[arg_calc.field_index - 1] = LLVMTypeOf(gen_param_values.at(arg_i));
                if (arg_calc.field_index - prev.field_index > 1) {
                    // Padding field
                    uint32_t pad_bytes = arg_calc.offset - prev.offset - gen_param_types.at(arg_i)->abi_size;
                    LLVMTypeRef pad_llvm_type = LLVMArrayType(LLVMInt8Type(), pad_bytes);
                    field_types[arg_calc.field_index - 2] = pad_llvm_type;
                }
            }
            LLVMTypeRef frame_with_args_type = LLVMStructType(field_types, field_count, false);
            LLVMTypeRef ptr_frame_with_args_type = LLVMPointerType(frame_with_args_type, 0);

            casted_frame = LLVMBuildBitCast(g->builder, frame_result_loc, ptr_frame_with_args_type, "");
        } else {
            casted_frame = frame_result_loc;
        }

        CalcLLVMFieldIndex arg_calc = arg_calc_start;
        for (size_t arg_i = 0; arg_i < gen_param_values.length; arg_i += 1) {
            calc_llvm_field_index_add(g, &arg_calc, gen_param_types.at(arg_i));
            LLVMValueRef arg_ptr = LLVMBuildStructGEP(g->builder, casted_frame, arg_calc.field_index - 1, "");
            gen_assign_raw(g, arg_ptr, get_pointer_to_type(g, gen_param_types.at(arg_i), true),
                    gen_param_values.at(arg_i));
        }

        if (instruction->modifier == CallModifierAsync) {
            gen_resume(g, fn_val, frame_result_loc, ResumeIdCall);
            if (instruction->new_stack != nullptr) {
                return LLVMBuildBitCast(g->builder, frame_result_loc,
                        get_llvm_type(g, instruction->base.value->type), "");
            }
            return nullptr;
        } else if (instruction->modifier == CallModifierNoSuspend && !fn_is_async(g->cur_fn)) {
            gen_resume(g, fn_val, frame_result_loc, ResumeIdCall);

            if (ir_want_runtime_safety(g, &instruction->base)) {
                LLVMValueRef awaiter_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc,
                        frame_awaiter_index, "");
                LLVMValueRef all_ones = LLVMConstAllOnes(usize_type_ref);
                LLVMValueRef prev_val = gen_maybe_atomic_op(g, LLVMAtomicRMWBinOpXchg, awaiter_ptr,
                        all_ones, LLVMAtomicOrderingRelease);
                LLVMValueRef ok_val = LLVMBuildICmp(g->builder, LLVMIntEQ, prev_val, all_ones, "");

                LLVMBasicBlockRef bad_block = LLVMAppendBasicBlock(g->cur_fn_val, "NoSuspendPanic");
                LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "NoSuspendOk");
                LLVMBuildCondBr(g->builder, ok_val, ok_block, bad_block);

                // The async function suspended, but this nosuspend call asserted it wouldn't.
                LLVMPositionBuilderAtEnd(g->builder, bad_block);
                gen_safety_crash(g, PanicMsgIdBadNoSuspendCall);

                LLVMPositionBuilderAtEnd(g->builder, ok_block);
            }

            ZigType *result_type = instruction->base.value->type;
            ZigType *ptr_result_type = get_pointer_to_type(g, result_type, true);
            return gen_await_early_return(g, &instruction->base, frame_result_loc,
                    result_type, ptr_result_type, result_loc, true);
        } else {
            ZigType *ptr_result_type = get_pointer_to_type(g, src_return_type, true);

            LLVMBasicBlockRef call_bb = gen_suspend_begin(g, "CallResume");

            LLVMValueRef call_inst = gen_resume(g, fn_val, frame_result_loc, ResumeIdCall);
            set_tail_call_if_appropriate(g, call_inst);
            LLVMBuildRetVoid(g->builder);

            LLVMPositionBuilderAtEnd(g->builder, call_bb);
            gen_assert_resume_id(g, &instruction->base, ResumeIdReturn, PanicMsgIdResumedAnAwaitingFn, nullptr);
            render_async_var_decls(g, instruction->base.base.scope);

            if (!type_has_bits(g, src_return_type))
                return nullptr;

            if (result_loc != nullptr) {
                if (instruction->result_loc->id == IrInstGenIdReturnPtr) {
                    instruction->base.spill = nullptr;
                    return g->cur_ret_ptr;
                } else {
                    return get_handle_value(g, result_loc, src_return_type, ptr_result_type);
                }
            }

            if (need_frame_ptr_ptr_spill) {
                LLVMValueRef frame_slice_ptr = ir_llvm_value(g, instruction->new_stack);
                LLVMValueRef frame_ptr_ptr = LLVMBuildStructGEP(g->builder, frame_slice_ptr, slice_ptr_index, "");
                frame_result_loc_uncasted = LLVMBuildLoad(g->builder, frame_ptr_ptr, "");
            }
            if (frame_result_loc_uncasted != nullptr) {
                if (instruction->fn_entry != nullptr) {
                    frame_result_loc = LLVMBuildBitCast(g->builder, frame_result_loc_uncasted,
                            LLVMPointerType(get_llvm_type(g, instruction->fn_entry->frame_type), 0), "");
                } else {
                    frame_result_loc = LLVMBuildBitCast(g->builder, frame_result_loc_uncasted,
                            get_llvm_type(g, anyframe_type), "");
                }
            }

            LLVMValueRef result_ptr = LLVMBuildStructGEP(g->builder, frame_result_loc, frame_ret_start + 2, "");
            return LLVMBuildLoad(g->builder, result_ptr, "");
        }
    }

    if (instruction->new_stack == nullptr || instruction->is_async_call_builtin) {
        result = ZigLLVMBuildCall(g->builder, fn_val,
                gen_param_values.items, (unsigned)gen_param_values.length, llvm_cc, call_attr, "");
    } else if (instruction->modifier == CallModifierAsync) {
        zig_panic("TODO @asyncCall of non-async function");
    } else {
        LLVMValueRef new_stack_addr = get_new_stack_addr(g, ir_llvm_value(g, instruction->new_stack));
        LLVMValueRef old_stack_ref;
        if (src_return_type->id != ZigTypeIdUnreachable) {
            LLVMValueRef stacksave_fn_val = get_stacksave_fn_val(g);
            old_stack_ref = LLVMBuildCall(g->builder, stacksave_fn_val, nullptr, 0, "");
        }
        gen_set_stack_pointer(g, new_stack_addr);
        result = ZigLLVMBuildCall(g->builder, fn_val,
                gen_param_values.items, (unsigned)gen_param_values.length, llvm_cc, call_attr, "");
        if (src_return_type->id != ZigTypeIdUnreachable) {
            LLVMValueRef stackrestore_fn_val = get_stackrestore_fn_val(g);
            LLVMBuildCall(g->builder, stackrestore_fn_val, &old_stack_ref, 1, "");
        }
    }

    if (src_return_type->id == ZigTypeIdUnreachable) {
        return LLVMBuildUnreachable(g->builder);
    } else if (!ret_has_bits) {
        return nullptr;
    } else if (first_arg_ret) {
        set_call_instr_sret(g, result);
        return result_loc;
    } else if (handle_is_ptr(g, src_return_type)) {
        LLVMValueRef store_instr = LLVMBuildStore(g->builder, result, result_loc);
        LLVMSetAlignment(store_instr, get_ptr_align(g, instruction->result_loc->value->type));
        return result_loc;
    } else if (!callee_is_async && instruction->modifier == CallModifierAsync) {
        LLVMBuildStore(g->builder, result, ret_ptr);
        return result_loc;
    } else {
        return result;
    }
}

static LLVMValueRef ir_render_struct_field_ptr(CodeGen *g, IrExecutableGen *executable,
    IrInstGenStructFieldPtr *instruction)
{
    Error err;

    if (instruction->base.value->special != ConstValSpecialRuntime)
        return nullptr;

    LLVMValueRef struct_ptr = ir_llvm_value(g, instruction->struct_ptr);
    // not necessarily a pointer. could be ZigTypeIdStruct
    ZigType *struct_ptr_type = instruction->struct_ptr->value->type;
    TypeStructField *field = instruction->field;

    if (!type_has_bits(g, field->type_entry))
        return nullptr;

    if (struct_ptr_type->id == ZigTypeIdPointer &&
        struct_ptr_type->data.pointer.host_int_bytes != 0)
    {
        return struct_ptr;
    }

    ZigType *struct_type;
    if (struct_ptr_type->id == ZigTypeIdPointer) {
        if (struct_ptr_type->data.pointer.inferred_struct_field != nullptr) {
            struct_type = struct_ptr_type->data.pointer.inferred_struct_field->inferred_struct_type;
        } else {
            struct_type = struct_ptr_type->data.pointer.child_type;
        }
    } else {
        struct_type = struct_ptr_type;
    }

    if ((err = type_resolve(g, struct_type, ResolveStatusLLVMFull)))
        codegen_report_errors_and_exit(g);

    ir_assert(field->gen_index != SIZE_MAX, &instruction->base);
    LLVMValueRef field_ptr_val = LLVMBuildStructGEP(g->builder, struct_ptr, (unsigned)field->gen_index, "");
    ZigType *res_type = instruction->base.value->type;
    ir_assert(res_type->id == ZigTypeIdPointer, &instruction->base);
    if (res_type->data.pointer.host_int_bytes != 0) {
        // We generate packed structs with get_llvm_type_of_n_bytes, which is
        // u8 for 1 byte or [n]u8 for multiple bytes. But the pointer to the type
        // is supposed to be a pointer to the integer. So we bitcast it here.
        LLVMTypeRef int_elem_type = LLVMIntType(8*res_type->data.pointer.host_int_bytes);
        LLVMTypeRef integer_ptr_type = LLVMPointerType(int_elem_type, 0);
        return LLVMBuildBitCast(g->builder, field_ptr_val, integer_ptr_type, "");
    }
    return field_ptr_val;
}

static LLVMValueRef ir_render_union_field_ptr(CodeGen *g, IrExecutableGen *executable,
    IrInstGenUnionFieldPtr *instruction)
{
    if (instruction->base.value->special != ConstValSpecialRuntime)
        return nullptr;

    ZigType *union_ptr_type = instruction->union_ptr->value->type;
    assert(union_ptr_type->id == ZigTypeIdPointer);
    ZigType *union_type = union_ptr_type->data.pointer.child_type;
    assert(union_type->id == ZigTypeIdUnion);

    TypeUnionField *field = instruction->field;

    if (!type_has_bits(g, field->type_entry)) {
        ZigType *tag_type = union_type->data.unionation.tag_type;
        if (!instruction->initializing || tag_type == nullptr || !type_has_bits(g, tag_type))
            return nullptr;

        // The field has no bits but we still have to change the discriminant
        // value here
        LLVMValueRef union_ptr = ir_llvm_value(g, instruction->union_ptr);

        LLVMTypeRef tag_type_ref = get_llvm_type(g, tag_type);
        LLVMValueRef tag_field_ptr = nullptr;
        if (union_type->data.unionation.gen_field_count == 0) {
            assert(union_type->data.unionation.gen_tag_index == SIZE_MAX);
            // The whole union is collapsed into the discriminant
            tag_field_ptr = LLVMBuildBitCast(g->builder, union_ptr,
                LLVMPointerType(tag_type_ref, 0), "");
        } else {
            assert(union_type->data.unionation.gen_tag_index != SIZE_MAX);
            tag_field_ptr = LLVMBuildStructGEP(g->builder, union_ptr,
                union_type->data.unionation.gen_tag_index, "");
        }

        LLVMValueRef tag_value = bigint_to_llvm_const(tag_type_ref,
            &field->enum_field->value);
        assert(tag_field_ptr != nullptr);
        gen_store_untyped(g, tag_value, tag_field_ptr, 0, false);

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

static LLVMValueRef ir_render_asm_gen(CodeGen *g, IrExecutableGen *executable, IrInstGenAsm *instruction) {
    AstNode *asm_node = instruction->base.base.source_node;
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
    LLVMTypeRef *param_types = heap::c_allocator.allocate<LLVMTypeRef>(input_and_output_count);
    LLVMValueRef *param_values = heap::c_allocator.allocate<LLVMValueRef>(input_and_output_count);
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
        IrInstGen *ir_input = instruction->input_list[i];
        buf_append_buf(&constraint_buf, asm_input->constraint);
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        ZigType *const type = ir_input->value->type;
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
        ret_type = get_llvm_type(g, instruction->base.value->type);
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
    if (!type_has_bits(g, child_type))
        return maybe_handle;

    bool is_scalar = !handle_is_ptr(g, maybe_type);
    if (is_scalar)
        return LLVMBuildICmp(g->builder, LLVMIntNE, maybe_handle, LLVMConstNull(get_llvm_type(g, maybe_type)), "");

    LLVMValueRef maybe_field_ptr = LLVMBuildStructGEP(g->builder, maybe_handle, maybe_null_index, "");
    return gen_load_untyped(g, maybe_field_ptr, 0, false, "");
}

static LLVMValueRef ir_render_test_non_null(CodeGen *g, IrExecutableGen *executable,
    IrInstGenTestNonNull *instruction)
{
    return gen_non_null_bit(g, instruction->value->value->type, ir_llvm_value(g, instruction->value));
}

static LLVMValueRef ir_render_optional_unwrap_ptr(CodeGen *g, IrExecutableGen *executable,
        IrInstGenOptionalUnwrapPtr *instruction)
{
    if (instruction->base.value->special != ConstValSpecialRuntime)
        return nullptr;

    ZigType *ptr_type = instruction->base_ptr->value->type;
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
    if (!type_has_bits(g, child_type)) {
        if (instruction->initializing) {
            LLVMValueRef non_null_bit = LLVMConstInt(LLVMInt1Type(), 1, false);
            gen_store_untyped(g, non_null_bit, base_ptr, 0, false);
        }
        return nullptr;
    } else {
        bool is_scalar = !handle_is_ptr(g, maybe_type);
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

static LLVMValueRef get_int_builtin_fn(CodeGen *g, ZigType *expr_type, BuiltinFnId fn_id) {
    bool is_vector = expr_type->id == ZigTypeIdVector;
    ZigType *int_type = is_vector ? expr_type->data.vector.elem_type : expr_type;
    assert(int_type->id == ZigTypeIdInt);
    uint32_t vector_len = is_vector ? expr_type->data.vector.len : 0;
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
        key.data.bswap.vector_len = vector_len;
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
    if (is_vector)
        sprintf(llvm_name, "llvm.%s.v%" PRIu32 "i%" PRIu32, fn_name, vector_len, int_type->data.integral.bit_count);
    else
        sprintf(llvm_name, "llvm.%s.i%" PRIu32, fn_name, int_type->data.integral.bit_count);
    LLVMTypeRef param_types[] = {
        get_llvm_type(g, expr_type),
        LLVMInt1Type(),
    };
    LLVMTypeRef fn_type = LLVMFunctionType(get_llvm_type(g, expr_type), param_types, n_args, false);
    LLVMValueRef fn_val = LLVMAddFunction(g->module, llvm_name, fn_type);
    assert(LLVMGetIntrinsicID(fn_val));

    g->llvm_fn_table.put(key, fn_val);

    return fn_val;
}

static LLVMValueRef ir_render_clz(CodeGen *g, IrExecutableGen *executable, IrInstGenClz *instruction) {
    ZigType *int_type = instruction->op->value->type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdClz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->op);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    return gen_widen_or_shorten(g, false, int_type, instruction->base.value->type, wrong_size_int);
}

static LLVMValueRef ir_render_ctz(CodeGen *g, IrExecutableGen *executable, IrInstGenCtz *instruction) {
    ZigType *int_type = instruction->op->value->type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdCtz);
    LLVMValueRef operand = ir_llvm_value(g, instruction->op);
    LLVMValueRef params[] {
        operand,
        LLVMConstNull(LLVMInt1Type()),
    };
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, params, 2, "");
    return gen_widen_or_shorten(g, false, int_type, instruction->base.value->type, wrong_size_int);
}

static LLVMValueRef ir_render_shuffle_vector(CodeGen *g, IrExecutableGen *executable, IrInstGenShuffleVector *instruction) {
    uint64_t len_a = instruction->a->value->type->data.vector.len;
    uint64_t len_mask = instruction->mask->value->type->data.vector.len;

    // LLVM uses integers larger than the length of the first array to
    // index into the second array. This was deemed unnecessarily fragile
    // when changing code, so Zig uses negative numbers to index the
    // second vector. These start at -1 and go down, and are easiest to use
    // with the ~ operator. Here we convert between the two formats.
    IrInstGen *mask = instruction->mask;
    LLVMValueRef *values = heap::c_allocator.allocate<LLVMValueRef>(len_mask);
    for (uint64_t i = 0; i < len_mask; i++) {
        if (mask->value->data.x_array.data.s_none.elements[i].special == ConstValSpecialUndef) {
            values[i] = LLVMGetUndef(LLVMInt32Type());
        } else {
            int32_t v = bigint_as_signed(&mask->value->data.x_array.data.s_none.elements[i].data.x_bigint);
            uint32_t index_val = (v >= 0) ? (uint32_t)v : (uint32_t)~v + (uint32_t)len_a;
            values[i] = LLVMConstInt(LLVMInt32Type(), index_val, false);
        }
    }

    LLVMValueRef llvm_mask_value = LLVMConstVector(values, len_mask);
    heap::c_allocator.deallocate(values, len_mask);

    return LLVMBuildShuffleVector(g->builder,
        ir_llvm_value(g, instruction->a),
        ir_llvm_value(g, instruction->b),
        llvm_mask_value, "");
}

static LLVMValueRef ir_render_splat(CodeGen *g, IrExecutableGen *executable, IrInstGenSplat *instruction) {
    ZigType *result_type = instruction->base.value->type;
    ir_assert(result_type->id == ZigTypeIdVector, &instruction->base);
    uint32_t len = result_type->data.vector.len;
    LLVMTypeRef op_llvm_type = LLVMVectorType(get_llvm_type(g, instruction->scalar->value->type), 1);
    LLVMTypeRef mask_llvm_type = LLVMVectorType(LLVMInt32Type(), len);
    LLVMValueRef undef_vector = LLVMGetUndef(op_llvm_type);
    LLVMValueRef op_vector = LLVMBuildInsertElement(g->builder, undef_vector,
            ir_llvm_value(g, instruction->scalar), LLVMConstInt(LLVMInt32Type(), 0, false), "");
    return LLVMBuildShuffleVector(g->builder, op_vector, undef_vector, LLVMConstNull(mask_llvm_type), "");
}

static LLVMValueRef ir_render_pop_count(CodeGen *g, IrExecutableGen *executable, IrInstGenPopCount *instruction) {
    ZigType *int_type = instruction->op->value->type;
    LLVMValueRef fn_val = get_int_builtin_fn(g, int_type, BuiltinFnIdPopCount);
    LLVMValueRef operand = ir_llvm_value(g, instruction->op);
    LLVMValueRef wrong_size_int = LLVMBuildCall(g->builder, fn_val, &operand, 1, "");
    return gen_widen_or_shorten(g, false, int_type, instruction->base.value->type, wrong_size_int);
}

static LLVMValueRef ir_render_switch_br(CodeGen *g, IrExecutableGen *executable, IrInstGenSwitchBr *instruction) {
    ZigType *target_type = instruction->target_value->value->type;
    LLVMBasicBlockRef else_block = instruction->else_block->llvm_block;

    LLVMValueRef target_value = ir_llvm_value(g, instruction->target_value);
    if (target_type->id == ZigTypeIdPointer) {
        const ZigType *usize = g->builtin_types.entry_usize;
        target_value = LLVMBuildPtrToInt(g->builder, target_value, usize->llvm_type, "");
    }

    LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, target_value, else_block,
                                                (unsigned)instruction->case_count);

    for (size_t i = 0; i < instruction->case_count; i += 1) {
        IrInstGenSwitchBrCase *this_case = &instruction->cases[i];

        LLVMValueRef case_value = ir_llvm_value(g, this_case->value);
        if (target_type->id == ZigTypeIdPointer) {
            const ZigType *usize = g->builtin_types.entry_usize;
            case_value = LLVMBuildPtrToInt(g->builder, case_value, usize->llvm_type, "");
        }

        LLVMAddCase(switch_instr, case_value, this_case->block->llvm_block);
    }

    return nullptr;
}

static LLVMValueRef ir_render_phi(CodeGen *g, IrExecutableGen *executable, IrInstGenPhi *instruction) {
    if (!type_has_bits(g, instruction->base.value->type))
        return nullptr;

    LLVMTypeRef phi_type;
    if (handle_is_ptr(g, instruction->base.value->type)) {
        phi_type = LLVMPointerType(get_llvm_type(g,instruction->base.value->type), 0);
    } else {
        phi_type = get_llvm_type(g, instruction->base.value->type);
    }

    LLVMValueRef phi = LLVMBuildPhi(g->builder, phi_type, "");
    LLVMValueRef *incoming_values = heap::c_allocator.allocate<LLVMValueRef>(instruction->incoming_count);
    LLVMBasicBlockRef *incoming_blocks = heap::c_allocator.allocate<LLVMBasicBlockRef>(instruction->incoming_count);
    for (size_t i = 0; i < instruction->incoming_count; i += 1) {
        incoming_values[i] = ir_llvm_value(g, instruction->incoming_values[i]);
        incoming_blocks[i] = instruction->incoming_blocks[i]->llvm_exit_block;
    }
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, (unsigned)instruction->incoming_count);
    return phi;
}

static LLVMValueRef ir_render_ref(CodeGen *g, IrExecutableGen *executable, IrInstGenRef *instruction) {
    if (!type_has_bits(g, instruction->base.value->type)) {
        return nullptr;
    }
    if (instruction->operand->id == IrInstGenIdCall) {
        IrInstGenCall *call = reinterpret_cast<IrInstGenCall *>(instruction->operand);
        if (call->result_loc != nullptr) {
            return ir_llvm_value(g, call->result_loc);
        }
    }
    LLVMValueRef value = ir_llvm_value(g, instruction->operand);
    if (handle_is_ptr(g, instruction->operand->value->type)) {
        return value;
    } else {
        LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
        gen_store_untyped(g, value, result_loc, 0, false);
        return result_loc;
    }
}

static LLVMValueRef ir_render_err_name(CodeGen *g, IrExecutableGen *executable, IrInstGenErrName *instruction) {
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

    const char *fn_name = get_mangled_name(g,
            buf_ptr(buf_sprintf("__zig_tag_name_%s", buf_ptr(&enum_type->name))));
    LLVMValueRef fn_val = LLVMAddFunction(g->module, fn_name, fn_type_ref);
    LLVMSetLinkage(fn_val, LLVMInternalLinkage);
    ZigLLVMFunctionSetCallingConv(fn_val, get_llvm_cc(g, CallingConventionUnspecified));
    addLLVMFnAttr(fn_val, "nounwind");
    add_uwtable_attr(g, fn_val);
    if (codegen_have_frame_pointer(g)) {
        ZigLLVMAddFunctionAttr(fn_val, "frame-pointer", "all");
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

    HashMap<BigInt, Buf *, bigint_hash, bigint_eql> occupied_tag_values = {};
    occupied_tag_values.init(field_count);

    for (size_t field_i = 0; field_i < field_count; field_i += 1) {
        TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[field_i];

        Buf *name = type_enum_field->name;
        auto entry = occupied_tag_values.put_unique(type_enum_field->value, name);
        if (entry != nullptr) {
            continue;
        }

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
    occupied_tag_values.deinit();

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

static LLVMValueRef ir_render_enum_tag_name(CodeGen *g, IrExecutableGen *executable,
        IrInstGenTagName *instruction)
{
    ZigType *enum_type = instruction->target->value->type;
    assert(enum_type->id == ZigTypeIdEnum);

    LLVMValueRef enum_name_function = get_enum_tag_name_function(g, enum_type);

    LLVMValueRef enum_tag_value = ir_llvm_value(g, instruction->target);
    return ZigLLVMBuildCall(g->builder, enum_name_function, &enum_tag_value, 1,
            get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAuto, "");
}

static LLVMValueRef ir_render_field_parent_ptr(CodeGen *g, IrExecutableGen *executable,
        IrInstGenFieldParentPtr *instruction)
{
    ZigType *container_ptr_type = instruction->base.value->type;
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

static LLVMValueRef ir_render_align_cast(CodeGen *g, IrExecutableGen *executable, IrInstGenAlignCast *instruction) {
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    assert(target_val);

    bool want_runtime_safety = ir_want_runtime_safety(g, &instruction->base);
    if (!want_runtime_safety) {
        return target_val;
    }

    ZigType *target_type = instruction->base.value->type;
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
    } else if (target_type->id == ZigTypeIdStruct &&
            target_type->data.structure.special == StructSpecialSlice)
    {
        ZigType *slice_ptr_type = target_type->data.structure.fields[slice_ptr_index]->type_entry;
        align_bytes = get_ptr_align(g, slice_ptr_type);

        size_t ptr_index = target_type->data.structure.fields[slice_ptr_index]->gen_index;
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

static LLVMValueRef ir_render_error_return_trace(CodeGen *g, IrExecutableGen *executable,
        IrInstGenErrorReturnTrace *instruction)
{
    bool is_llvm_alloca;
    LLVMValueRef cur_err_ret_trace_val = get_cur_err_ret_trace_val(g, instruction->base.base.scope, &is_llvm_alloca);
    if (cur_err_ret_trace_val == nullptr) {
        return LLVMConstNull(get_llvm_type(g, ptr_to_stack_trace_type(g)));
    }
    return cur_err_ret_trace_val;
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

static enum ZigLLVM_AtomicRMWBinOp to_ZigLLVMAtomicRMWBinOp(AtomicRmwOp op, bool is_signed, bool is_float) {
    switch (op) {
        case AtomicRmwOp_xchg: return ZigLLVMAtomicRMWBinOpXchg;
        case AtomicRmwOp_add:
            return is_float ? ZigLLVMAtomicRMWBinOpFAdd : ZigLLVMAtomicRMWBinOpAdd;
        case AtomicRmwOp_sub:
            return is_float ? ZigLLVMAtomicRMWBinOpFSub : ZigLLVMAtomicRMWBinOpSub;
        case AtomicRmwOp_and: return ZigLLVMAtomicRMWBinOpAnd;
        case AtomicRmwOp_nand: return ZigLLVMAtomicRMWBinOpNand;
        case AtomicRmwOp_or: return ZigLLVMAtomicRMWBinOpOr;
        case AtomicRmwOp_xor: return ZigLLVMAtomicRMWBinOpXor;
        case AtomicRmwOp_max:
            return is_signed ? ZigLLVMAtomicRMWBinOpMax : ZigLLVMAtomicRMWBinOpUMax;
        case AtomicRmwOp_min:
            return is_signed ? ZigLLVMAtomicRMWBinOpMin : ZigLLVMAtomicRMWBinOpUMin;
    }
    zig_unreachable();
}

static LLVMTypeRef get_atomic_abi_type(CodeGen *g, IrInstGen *instruction) {
    // If the operand type of an atomic operation is not a power of two sized
    // we need to widen it before using it and then truncate the result.

    ir_assert(instruction->value->type->id == ZigTypeIdPointer, instruction);
    ZigType *operand_type = instruction->value->type->data.pointer.child_type;
    if (operand_type->id == ZigTypeIdInt || operand_type->id == ZigTypeIdEnum) {
        if (operand_type->id == ZigTypeIdEnum) {
            operand_type = operand_type->data.enumeration.tag_int_type;
        }
        auto bit_count = operand_type->data.integral.bit_count;
        bool is_signed = operand_type->data.integral.is_signed;

        ir_assert(bit_count != 0, instruction);
        if (bit_count == 1 || !is_power_of_2(bit_count)) {
            return get_llvm_type(g, get_int_type(g, is_signed, operand_type->abi_size * 8));
        } else {
            return nullptr;
        }
    } else if (operand_type->id == ZigTypeIdFloat) {
        return nullptr;
    } else if (operand_type->id == ZigTypeIdBool) {
        return g->builtin_types.entry_u8->llvm_type;
    } else {
        ir_assert(get_codegen_ptr_type_bail(g, operand_type) != nullptr, instruction);
        return nullptr;
    }
}

static LLVMValueRef ir_render_cmpxchg(CodeGen *g, IrExecutableGen *executable, IrInstGenCmpxchg *instruction) {
    LLVMValueRef ptr_val = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef cmp_val = ir_llvm_value(g, instruction->cmp_value);
    LLVMValueRef new_val = ir_llvm_value(g, instruction->new_value);

    ZigType *operand_type = instruction->new_value->value->type;
    LLVMTypeRef actual_abi_type = get_atomic_abi_type(g, instruction->ptr);
    if (actual_abi_type != nullptr) {
        // operand needs widening and truncating
        ptr_val = LLVMBuildBitCast(g->builder, ptr_val,
            LLVMPointerType(actual_abi_type, 0), "");
        if (operand_type->data.integral.is_signed) {
            cmp_val = LLVMBuildSExt(g->builder, cmp_val, actual_abi_type, "");
            new_val = LLVMBuildSExt(g->builder, new_val, actual_abi_type, "");
        } else {
            cmp_val = LLVMBuildZExt(g->builder, cmp_val, actual_abi_type, "");
            new_val = LLVMBuildZExt(g->builder, new_val, actual_abi_type, "");
        }
    }

    LLVMAtomicOrdering success_order = to_LLVMAtomicOrdering(instruction->success_order);
    LLVMAtomicOrdering failure_order = to_LLVMAtomicOrdering(instruction->failure_order);

    LLVMValueRef result_val = ZigLLVMBuildCmpXchg(g->builder, ptr_val, cmp_val, new_val,
            success_order, failure_order, instruction->is_weak);

    ZigType *optional_type = instruction->base.value->type;
    assert(optional_type->id == ZigTypeIdOptional);
    ZigType *child_type = optional_type->data.maybe.child_type;

    if (!handle_is_ptr(g, optional_type)) {
        LLVMValueRef payload_val = LLVMBuildExtractValue(g->builder, result_val, 0, "");
        if (actual_abi_type != nullptr) {
            payload_val = LLVMBuildTrunc(g->builder, payload_val, get_llvm_type(g, operand_type), "");
        }
        LLVMValueRef success_bit = LLVMBuildExtractValue(g->builder, result_val, 1, "");
        return LLVMBuildSelect(g->builder, success_bit, LLVMConstNull(get_llvm_type(g, child_type)), payload_val, "");
    }

    // When the cmpxchg is discarded, the result location will have no bits.
    if (!type_has_bits(g, instruction->result_loc->value->type)) {
        return nullptr;
    }

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
    ir_assert(result_loc != nullptr, &instruction->base);
    ir_assert(type_has_bits(g, child_type), &instruction->base);

    LLVMValueRef payload_val = LLVMBuildExtractValue(g->builder, result_val, 0, "");
    if (actual_abi_type != nullptr) {
        payload_val = LLVMBuildTrunc(g->builder, payload_val, get_llvm_type(g, operand_type), "");
    }
    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_child_index, "");
    gen_assign_raw(g, val_ptr, get_pointer_to_type(g, child_type, false), payload_val);

    LLVMValueRef success_bit = LLVMBuildExtractValue(g->builder, result_val, 1, "");
    LLVMValueRef nonnull_bit = LLVMBuildNot(g->builder, success_bit, "");
    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_null_index, "");
    gen_store_untyped(g, nonnull_bit, maybe_ptr, 0, false);
    return result_loc;
}

static LLVMValueRef ir_render_fence(CodeGen *g, IrExecutableGen *executable, IrInstGenFence *instruction) {
    LLVMAtomicOrdering atomic_order = to_LLVMAtomicOrdering(instruction->order);
    LLVMBuildFence(g->builder, atomic_order, false, "");
    return nullptr;
}

static LLVMValueRef ir_render_truncate(CodeGen *g, IrExecutableGen *executable, IrInstGenTruncate *instruction) {
    LLVMValueRef target_val = ir_llvm_value(g, instruction->target);
    ZigType *dest_type = instruction->base.value->type;
    ZigType *src_type = instruction->target->value->type;
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

static LLVMValueRef ir_render_memset(CodeGen *g, IrExecutableGen *executable, IrInstGenMemset *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");

    ZigType *ptr_type = instruction->dest_ptr->value->type;
    assert(ptr_type->id == ZigTypeIdPointer);

    bool val_is_undef = value_is_all_undef(g, instruction->byte->value);
    LLVMValueRef fill_char;
    if (val_is_undef) {
        if (ir_want_runtime_safety_scope(g, instruction->base.base.scope)) {
            fill_char = LLVMConstInt(LLVMInt8Type(), 0xaa, false);
        } else {
            return nullptr;
        }
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

static LLVMValueRef ir_render_memcpy(CodeGen *g, IrExecutableGen *executable, IrInstGenMemcpy *instruction) {
    LLVMValueRef dest_ptr = ir_llvm_value(g, instruction->dest_ptr);
    LLVMValueRef src_ptr = ir_llvm_value(g, instruction->src_ptr);
    LLVMValueRef len_val = ir_llvm_value(g, instruction->count);

    LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);

    LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, dest_ptr, ptr_u8, "");
    LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, src_ptr, ptr_u8, "");

    ZigType *dest_ptr_type = instruction->dest_ptr->value->type;
    ZigType *src_ptr_type = instruction->src_ptr->value->type;

    assert(dest_ptr_type->id == ZigTypeIdPointer);
    assert(src_ptr_type->id == ZigTypeIdPointer);

    bool is_volatile = (dest_ptr_type->data.pointer.is_volatile || src_ptr_type->data.pointer.is_volatile);
    ZigLLVMBuildMemCpy(g->builder, dest_ptr_casted, get_ptr_align(g, dest_ptr_type),
            src_ptr_casted, get_ptr_align(g, src_ptr_type), len_val, is_volatile);
    return nullptr;
}

static LLVMValueRef ir_render_wasm_memory_size(CodeGen *g, IrExecutableGen *executable, IrInstGenWasmMemorySize *instruction) {
    // TODO adjust for wasm64
    LLVMValueRef param = ir_llvm_value(g, instruction->index);
    LLVMValueRef val = LLVMBuildCall(g->builder, gen_wasm_memory_size(g), &param, 1, "");
    return val;
}

static LLVMValueRef ir_render_wasm_memory_grow(CodeGen *g, IrExecutableGen *executable, IrInstGenWasmMemoryGrow *instruction) {
    // TODO adjust for wasm64
    LLVMValueRef params[] = {
        ir_llvm_value(g, instruction->index),
        ir_llvm_value(g, instruction->delta),
    };
    LLVMValueRef val = LLVMBuildCall(g->builder, gen_wasm_memory_grow(g), params, 2, "");
    return val;
}

static LLVMValueRef ir_render_slice(CodeGen *g, IrExecutableGen *executable, IrInstGenSlice *instruction) {
    Error err;

    LLVMValueRef array_ptr_ptr = ir_llvm_value(g, instruction->ptr);
    ZigType *array_ptr_type = instruction->ptr->value->type;
    assert(array_ptr_type->id == ZigTypeIdPointer);
    ZigType *array_type = array_ptr_type->data.pointer.child_type;
    LLVMValueRef array_ptr = get_handle_value(g, array_ptr_ptr, array_type, array_ptr_type);

    bool want_runtime_safety = instruction->safety_check_on && ir_want_runtime_safety(g, &instruction->base);

    // The result is either a slice or a pointer to an array
    ZigType *result_type = instruction->base.value->type;

    // This is not whether the result type has a sentinel, but whether there should be a sentinel check,
    // e.g. if they used [a..b :s] syntax.
    ZigValue *sentinel = instruction->sentinel;

    LLVMValueRef slice_start_ptr = nullptr;
    LLVMValueRef len_value = nullptr;

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
            // Safety check: start <= end
            if (instruction->start->value->special == ConstValSpecialRuntime || instruction->end) {
                add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
            }

            // Safety check: the last element of the slice (the sentinel if
            // requested) must be inside the array
            // XXX: Overflow is not checked here...
            const size_t full_len = array_type->data.array.len +
                (array_type->data.array.sentinel != nullptr);
            LLVMValueRef array_end = LLVMConstInt(g->builtin_types.entry_usize->llvm_type,
                    full_len, false);

            LLVMValueRef check_end_val = end_val;
            if (sentinel != nullptr) {
                LLVMValueRef usize_one = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, 1, false);
                check_end_val = LLVMBuildNUWAdd(g->builder, end_val, usize_one, "");
            }
            add_bounds_check(g, check_end_val, LLVMIntEQ, nullptr, LLVMIntULE, array_end);
        }

        bool value_has_bits;
        if ((err = type_has_bits2(g, array_type, &value_has_bits)))
            codegen_report_errors_and_exit(g);

        if (value_has_bits) {
            if (want_runtime_safety && sentinel != nullptr) {
                LLVMValueRef indices[] = {
                    LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
                    end_val,
                };
                LLVMValueRef sentinel_elem_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
                add_sentinel_check(g, sentinel_elem_ptr, sentinel);
            }

            LLVMValueRef indices[] = {
                LLVMConstNull(g->builtin_types.entry_usize->llvm_type),
                start_val,
            };
            slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, indices, 2, "");
        }

        len_value = LLVMBuildNUWSub(g->builder, end_val, start_val, "");
    } else if (array_type->id == ZigTypeIdPointer) {
        assert(array_type->data.pointer.ptr_len != PtrLenSingle);
        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val = ir_llvm_value(g, instruction->end);

        if (want_runtime_safety) {
            // Safety check: start <= end
            add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);
        }

        bool value_has_bits;
        if ((err = type_has_bits2(g, array_type, &value_has_bits)))
            codegen_report_errors_and_exit(g);

        if (value_has_bits) {
            if (want_runtime_safety && sentinel != nullptr) {
                LLVMValueRef sentinel_elem_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, &end_val, 1, "");
                add_sentinel_check(g, sentinel_elem_ptr, sentinel);
            }

            slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, &start_val, 1, "");
        }

        len_value = LLVMBuildNUWSub(g->builder, end_val, start_val, "");
    } else if (array_type->id == ZigTypeIdStruct) {
        assert(array_type->data.structure.special == StructSpecialSlice);
        assert(LLVMGetTypeKind(LLVMTypeOf(array_ptr)) == LLVMPointerTypeKind);
        assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(array_ptr))) == LLVMStructTypeKind);

        const size_t gen_len_index = array_type->data.structure.fields[slice_len_index]->gen_index;
        assert(gen_len_index != SIZE_MAX);

        LLVMValueRef prev_end = nullptr;
        if (!instruction->end || want_runtime_safety) {
            LLVMValueRef src_len_ptr = LLVMBuildStructGEP(g->builder, array_ptr, gen_len_index, "");
            prev_end = gen_load_untyped(g, src_len_ptr, 0, false, "");
        }

        LLVMValueRef start_val = ir_llvm_value(g, instruction->start);
        LLVMValueRef end_val;
        if (instruction->end) {
            end_val = ir_llvm_value(g, instruction->end);
        } else {
            end_val = prev_end;
        }

        ZigType *ptr_field_type = array_type->data.structure.fields[slice_ptr_index]->type_entry;

        if (want_runtime_safety) {
            assert(prev_end);
            // Safety check: start <= end
            add_bounds_check(g, start_val, LLVMIntEQ, nullptr, LLVMIntULE, end_val);

            // Safety check: the sentinel counts as one more element
            // XXX: Overflow is not checked here...
            LLVMValueRef check_prev_end = prev_end;
            if (ptr_field_type->data.pointer.sentinel != nullptr) {
                LLVMValueRef usize_one = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, 1, false);
                check_prev_end = LLVMBuildNUWAdd(g->builder, prev_end, usize_one, "");
            }
            LLVMValueRef check_end_val = end_val;
            if (sentinel != nullptr) {
                LLVMValueRef usize_one = LLVMConstInt(g->builtin_types.entry_usize->llvm_type, 1, false);
                check_end_val = LLVMBuildNUWAdd(g->builder, end_val, usize_one, "");
            }

            add_bounds_check(g, check_end_val, LLVMIntEQ, nullptr, LLVMIntULE, check_prev_end);
        }

        bool ptr_has_bits;
        if ((err = type_has_bits2(g, ptr_field_type, &ptr_has_bits)))
            codegen_report_errors_and_exit(g);

        if (ptr_has_bits) {
            const size_t gen_ptr_index = array_type->data.structure.fields[slice_ptr_index]->gen_index;
            assert(gen_ptr_index != SIZE_MAX);

            LLVMValueRef src_ptr_ptr = LLVMBuildStructGEP(g->builder, array_ptr, gen_ptr_index, "");
            LLVMValueRef src_ptr = gen_load_untyped(g, src_ptr_ptr, 0, false, "");

            if (sentinel != nullptr) {
                LLVMValueRef sentinel_elem_ptr = LLVMBuildInBoundsGEP(g->builder, src_ptr, &end_val, 1, "");
                add_sentinel_check(g, sentinel_elem_ptr, sentinel);
            }

            slice_start_ptr = LLVMBuildInBoundsGEP(g->builder, src_ptr, &start_val, 1, "");
        }

        len_value = LLVMBuildNUWSub(g->builder, end_val, start_val, "");
    } else {
        zig_unreachable();
    }

    bool result_has_bits;
    if ((err = type_has_bits2(g, result_type, &result_has_bits)))
        codegen_report_errors_and_exit(g);

    // Nothing to do, we're only interested in the bound checks emitted above
    if (!result_has_bits)
        return nullptr;

    // The starting pointer for the slice may be null in case of zero-sized
    // arrays, the length value is always defined.
    assert(len_value != nullptr);

    // The slice decays into a pointer to an array, the size is tracked in the
    // type itself
    if (result_type->id == ZigTypeIdPointer) {
        ir_assert(instruction->result_loc == nullptr, &instruction->base);
        LLVMTypeRef result_ptr_type = get_llvm_type(g, result_type);

        if (slice_start_ptr != nullptr) {
            return LLVMBuildBitCast(g->builder, slice_start_ptr, result_ptr_type, "");
        }

        return LLVMGetUndef(result_ptr_type);
    }

    ir_assert(instruction->result_loc != nullptr, &instruction->base);
    // Create a new slice
    LLVMValueRef tmp_struct_ptr = ir_llvm_value(g, instruction->result_loc);

    ZigType *slice_ptr_type = result_type->data.structure.fields[slice_ptr_index]->type_entry;

    // The slice may not have a pointer at all if it points to a zero-sized type
    const size_t gen_ptr_index = result_type->data.structure.fields[slice_ptr_index]->gen_index;
    if (gen_ptr_index != SIZE_MAX) {
        LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, gen_ptr_index, "");
        if (slice_start_ptr != nullptr) {
            gen_store_untyped(g, slice_start_ptr, ptr_field_ptr, 0, false);
        } else if (want_runtime_safety) {
            gen_undef_init(g, slice_ptr_type->abi_align, slice_ptr_type, ptr_field_ptr);
        } else {
            gen_store_untyped(g, LLVMGetUndef(get_llvm_type(g, slice_ptr_type)), ptr_field_ptr, 0, false);
        }
    }

    const size_t gen_len_index = result_type->data.structure.fields[slice_len_index]->gen_index;
    assert(gen_len_index != SIZE_MAX);

    LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, tmp_struct_ptr, gen_len_index, "");
    gen_store_untyped(g, len_value, len_field_ptr, 0, false);

    return tmp_struct_ptr;
}

static LLVMValueRef get_trap_fn_val(CodeGen *g) {
    if (g->trap_fn_val)
        return g->trap_fn_val;

    LLVMTypeRef fn_type = LLVMFunctionType(LLVMVoidType(), nullptr, 0, false);
    g->trap_fn_val = LLVMAddFunction(g->module, "llvm.debugtrap", fn_type);
    assert(LLVMGetIntrinsicID(g->trap_fn_val));

    return g->trap_fn_val;
}


static LLVMValueRef ir_render_breakpoint(CodeGen *g, IrExecutableGen *executable, IrInstGenBreakpoint *instruction) {
    LLVMBuildCall(g->builder, get_trap_fn_val(g), nullptr, 0, "");
    return nullptr;
}

static LLVMValueRef ir_render_return_address(CodeGen *g, IrExecutableGen *executable,
        IrInstGenReturnAddress *instruction)
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
    g->frame_address_fn_val = LLVMAddFunction(g->module, "llvm.frameaddress.p0i8", fn_type);
    assert(LLVMGetIntrinsicID(g->frame_address_fn_val));

    return g->frame_address_fn_val;
}

static LLVMValueRef ir_render_frame_address(CodeGen *g, IrExecutableGen *executable,
        IrInstGenFrameAddress *instruction)
{
    LLVMValueRef zero = LLVMConstNull(g->builtin_types.entry_i32->llvm_type);
    LLVMValueRef ptr_val = LLVMBuildCall(g->builder, get_frame_address_fn_val(g), &zero, 1, "");
    return LLVMBuildPtrToInt(g->builder, ptr_val, g->builtin_types.entry_usize->llvm_type, "");
}

static LLVMValueRef ir_render_handle(CodeGen *g, IrExecutableGen *executable, IrInstGenFrameHandle *instruction) {
    return g->cur_frame_ptr;
}

static LLVMValueRef render_shl_with_overflow(CodeGen *g, IrInstGenOverflowOp *instruction) {
    ZigType *int_type = instruction->result_ptr_type;
    assert(int_type->id == ZigTypeIdInt);

    LLVMValueRef op1 = ir_llvm_value(g, instruction->op1);
    LLVMValueRef op2 = ir_llvm_value(g, instruction->op2);
    LLVMValueRef ptr_result = ir_llvm_value(g, instruction->result_ptr);

    LLVMValueRef op2_casted = gen_widen_or_shorten(g, false, instruction->op2->value->type,
            instruction->op1->value->type, op2);

    LLVMValueRef result = LLVMBuildShl(g->builder, op1, op2_casted, "");
    LLVMValueRef orig_val;
    if (int_type->data.integral.is_signed) {
        orig_val = LLVMBuildAShr(g->builder, result, op2_casted, "");
    } else {
        orig_val = LLVMBuildLShr(g->builder, result, op2_casted, "");
    }
    LLVMValueRef overflow_bit = LLVMBuildICmp(g->builder, LLVMIntNE, op1, orig_val, "");

    gen_store(g, result, ptr_result, instruction->result_ptr->value->type);

    return overflow_bit;
}

static LLVMValueRef ir_render_overflow_op(CodeGen *g, IrExecutableGen *executable, IrInstGenOverflowOp *instruction) {
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
    gen_store(g, result, ptr_result, instruction->result_ptr->value->type);

    return overflow_bit;
}

static LLVMValueRef ir_render_test_err(CodeGen *g, IrExecutableGen *executable, IrInstGenTestErr *instruction) {
    ZigType *err_union_type = instruction->err_union->value->type;
    ZigType *payload_type = err_union_type->data.error_union.payload_type;
    LLVMValueRef err_union_handle = ir_llvm_value(g, instruction->err_union);

    LLVMValueRef err_val;
    if (type_has_bits(g, payload_type)) {
        LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
        err_val = gen_load_untyped(g, err_val_ptr, 0, false, "");
    } else {
        err_val = err_union_handle;
    }

    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, g->err_tag_type));
    return LLVMBuildICmp(g->builder, LLVMIntNE, err_val, zero, "");
}

static LLVMValueRef ir_render_unwrap_err_code(CodeGen *g, IrExecutableGen *executable,
        IrInstGenUnwrapErrCode *instruction)
{
    if (instruction->base.value->special != ConstValSpecialRuntime)
        return nullptr;

    ZigType *ptr_type = instruction->err_union_ptr->value->type;
    assert(ptr_type->id == ZigTypeIdPointer);
    ZigType *err_union_type = ptr_type->data.pointer.child_type;
    ZigType *payload_type = err_union_type->data.error_union.payload_type;
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->err_union_ptr);
    if (!type_has_bits(g, payload_type)) {
        return err_union_ptr;
    } else {
        // TODO assign undef to the payload
        LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, ptr_type);
        return LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
    }
}

static LLVMValueRef ir_render_unwrap_err_payload(CodeGen *g, IrExecutableGen *executable,
        IrInstGenUnwrapErrPayload *instruction)
{
    Error err;

    if (instruction->base.value->special != ConstValSpecialRuntime)
        return nullptr;

    bool want_safety = instruction->safety_check_on && ir_want_runtime_safety(g, &instruction->base) &&
        g->errors_by_index.length > 1;

    ZigType *ptr_type = instruction->value->value->type;
    assert(ptr_type->id == ZigTypeIdPointer);
    ZigType *err_union_type = ptr_type->data.pointer.child_type;
    ZigType *payload_type = err_union_type->data.error_union.payload_type;
    LLVMValueRef err_union_ptr = ir_llvm_value(g, instruction->value);

    LLVMValueRef zero = LLVMConstNull(get_llvm_type(g, g->err_tag_type));
    bool value_has_bits;
    if ((err = type_has_bits2(g, instruction->base.value->type, &value_has_bits)))
        codegen_report_errors_and_exit(g);
    if (!want_safety && !value_has_bits) {
        if (instruction->initializing) {
            gen_store_untyped(g, zero, err_union_ptr, 0, false);
        }
        return nullptr;
    }


    LLVMValueRef err_union_handle = get_handle_value(g, err_union_ptr, err_union_type, ptr_type);

    if (!type_has_bits(g, err_union_type->data.error_union.err_set_type)) {
        return err_union_handle;
    }

    if (want_safety) {
        LLVMValueRef err_val;
        if (type_has_bits(g, payload_type)) {
            LLVMValueRef err_val_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
            err_val = gen_load_untyped(g, err_val_ptr, 0, false, "");
        } else {
            err_val = err_union_handle;
        }
        LLVMValueRef cond_val = LLVMBuildICmp(g->builder, LLVMIntEQ, err_val, zero, "");
        LLVMBasicBlockRef err_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrError");
        LLVMBasicBlockRef ok_block = LLVMAppendBasicBlock(g->cur_fn_val, "UnwrapErrOk");
        LLVMBuildCondBr(g->builder, cond_val, ok_block, err_block);

        LLVMPositionBuilderAtEnd(g->builder, err_block);
        gen_safety_crash_for_err(g, err_val, instruction->base.base.scope);

        LLVMPositionBuilderAtEnd(g->builder, ok_block);
    }

    if (type_has_bits(g, payload_type)) {
        if (instruction->initializing) {
            LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, err_union_handle, err_union_err_index, "");
            LLVMValueRef ok_err_val = LLVMConstNull(get_llvm_type(g, g->err_tag_type));
            gen_store_untyped(g, ok_err_val, err_tag_ptr, 0, false);
        }
        return LLVMBuildStructGEP(g->builder, err_union_handle, err_union_payload_index, "");
    } else {
        if (instruction->initializing) {
            gen_store_untyped(g, zero, err_union_ptr, 0, false);
        }
        return nullptr;
    }
}

static LLVMValueRef ir_render_optional_wrap(CodeGen *g, IrExecutableGen *executable, IrInstGenOptionalWrap *instruction) {
    ZigType *wanted_type = instruction->base.value->type;

    assert(wanted_type->id == ZigTypeIdOptional);

    ZigType *child_type = wanted_type->data.maybe.child_type;

    if (!type_has_bits(g, child_type)) {
        LLVMValueRef result = LLVMConstAllOnes(LLVMInt1Type());
        if (instruction->result_loc != nullptr) {
            LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
            gen_store_untyped(g, result, result_loc, 0, false);
        }
        return result;
    }

    LLVMValueRef payload_val = ir_llvm_value(g, instruction->operand);
    if (!handle_is_ptr(g, wanted_type)) {
        if (instruction->result_loc != nullptr) {
            LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
            gen_store_untyped(g, payload_val, result_loc, 0, false);
        }
        return payload_val;
    }

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    LLVMValueRef val_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_child_index, "");
    // child_type and instruction->value->value->type may differ by constness
    gen_assign_raw(g, val_ptr, get_pointer_to_type(g, child_type, false), payload_val);
    LLVMValueRef maybe_ptr = LLVMBuildStructGEP(g->builder, result_loc, maybe_null_index, "");
    gen_store_untyped(g, LLVMConstAllOnes(LLVMInt1Type()), maybe_ptr, 0, false);

    return result_loc;
}

static LLVMValueRef ir_render_err_wrap_code(CodeGen *g, IrExecutableGen *executable, IrInstGenErrWrapCode *instruction) {
    ZigType *wanted_type = instruction->base.value->type;

    assert(wanted_type->id == ZigTypeIdErrorUnion);

    LLVMValueRef err_val = ir_llvm_value(g, instruction->operand);

    if (!handle_is_ptr(g, wanted_type))
        return err_val;

    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_err_index, "");
    gen_store_untyped(g, err_val, err_tag_ptr, 0, false);

    // TODO store undef to the payload

    return result_loc;
}

static LLVMValueRef ir_render_err_wrap_payload(CodeGen *g, IrExecutableGen *executable, IrInstGenErrWrapPayload *instruction) {
    ZigType *wanted_type = instruction->base.value->type;

    assert(wanted_type->id == ZigTypeIdErrorUnion);

    ZigType *payload_type = wanted_type->data.error_union.payload_type;
    ZigType *err_set_type = wanted_type->data.error_union.err_set_type;

    if (!type_has_bits(g, err_set_type)) {
        return ir_llvm_value(g, instruction->operand);
    }

    LLVMValueRef ok_err_val = LLVMConstNull(get_llvm_type(g, g->err_tag_type));

    if (!type_has_bits(g, payload_type))
        return ok_err_val;


    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);

    LLVMValueRef payload_val = ir_llvm_value(g, instruction->operand);

    LLVMValueRef err_tag_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_err_index, "");
    gen_store_untyped(g, ok_err_val, err_tag_ptr, 0, false);

    LLVMValueRef payload_ptr = LLVMBuildStructGEP(g->builder, result_loc, err_union_payload_index, "");
    gen_assign_raw(g, payload_ptr, get_pointer_to_type(g, payload_type, false), payload_val);

    return result_loc;
}

static LLVMValueRef ir_render_union_tag(CodeGen *g, IrExecutableGen *executable, IrInstGenUnionTag *instruction) {
    ZigType *union_type = instruction->value->value->type;

    ZigType *tag_type = union_type->data.unionation.tag_type;
    if (!type_has_bits(g, tag_type))
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

static LLVMValueRef ir_render_panic(CodeGen *g, IrExecutableGen *executable, IrInstGenPanic *instruction) {
    bool is_llvm_alloca;
    LLVMValueRef err_ret_trace_val = get_cur_err_ret_trace_val(g, instruction->base.base.scope, &is_llvm_alloca);
    gen_panic(g, ir_llvm_value(g, instruction->msg), err_ret_trace_val, is_llvm_alloca);
    return nullptr;
}

static LLVMValueRef ir_render_atomic_rmw(CodeGen *g, IrExecutableGen *executable,
        IrInstGenAtomicRmw *instruction)
{
    bool is_signed;
    ZigType *operand_type = instruction->operand->value->type;
    bool is_float = operand_type->id == ZigTypeIdFloat;
    if (operand_type->id == ZigTypeIdInt) {
        is_signed = operand_type->data.integral.is_signed;
    } else {
        is_signed = false;
    }
    enum ZigLLVM_AtomicRMWBinOp op = to_ZigLLVMAtomicRMWBinOp(instruction->op, is_signed, is_float);
    LLVMAtomicOrdering ordering = to_LLVMAtomicOrdering(instruction->ordering);
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef operand = ir_llvm_value(g, instruction->operand);

    LLVMTypeRef actual_abi_type = get_atomic_abi_type(g, instruction->ptr);
    if (actual_abi_type != nullptr) {
        // operand needs widening and truncating
        LLVMValueRef casted_ptr = LLVMBuildBitCast(g->builder, ptr,
            LLVMPointerType(actual_abi_type, 0), "");
        LLVMValueRef casted_operand;
        if (operand_type->data.integral.is_signed) {
            casted_operand = LLVMBuildSExt(g->builder, operand, actual_abi_type, "");
        } else {
            casted_operand = LLVMBuildZExt(g->builder, operand, actual_abi_type, "");
        }
        LLVMValueRef uncasted_result = ZigLLVMBuildAtomicRMW(g->builder, op, casted_ptr, casted_operand, ordering,
                g->is_single_threaded);
        return LLVMBuildTrunc(g->builder, uncasted_result, get_llvm_type(g, operand_type), "");
    }

    if (get_codegen_ptr_type_bail(g, operand_type) == nullptr) {
        return ZigLLVMBuildAtomicRMW(g->builder, op, ptr, operand, ordering, g->is_single_threaded);
    }

    // it's a pointer but we need to treat it as an int
    LLVMValueRef casted_ptr = LLVMBuildBitCast(g->builder, ptr,
        LLVMPointerType(g->builtin_types.entry_usize->llvm_type, 0), "");
    LLVMValueRef casted_operand = LLVMBuildPtrToInt(g->builder, operand, g->builtin_types.entry_usize->llvm_type, "");
    LLVMValueRef uncasted_result = ZigLLVMBuildAtomicRMW(g->builder, op, casted_ptr, casted_operand, ordering,
            g->is_single_threaded);
    return LLVMBuildIntToPtr(g->builder, uncasted_result, get_llvm_type(g, operand_type), "");
}

static LLVMValueRef ir_render_atomic_load(CodeGen *g, IrExecutableGen *executable,
        IrInstGenAtomicLoad *instruction)
{
    LLVMAtomicOrdering ordering = to_LLVMAtomicOrdering(instruction->ordering);
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);

    ZigType *operand_type = instruction->ptr->value->type->data.pointer.child_type;
    LLVMTypeRef actual_abi_type = get_atomic_abi_type(g, instruction->ptr);
    if (actual_abi_type != nullptr) {
        // operand needs widening and truncating
        ptr = LLVMBuildBitCast(g->builder, ptr,
                LLVMPointerType(actual_abi_type, 0), "");
        LLVMValueRef load_inst = gen_load(g, ptr, instruction->ptr->value->type, "");
        LLVMSetOrdering(load_inst, ordering);
        return LLVMBuildTrunc(g->builder, load_inst, get_llvm_type(g, operand_type), "");
    }
    LLVMValueRef load_inst = gen_load(g, ptr, instruction->ptr->value->type, "");
    LLVMSetOrdering(load_inst, ordering);
    return load_inst;
}

static LLVMValueRef ir_render_atomic_store(CodeGen *g, IrExecutableGen *executable,
        IrInstGenAtomicStore *instruction)
{
    LLVMAtomicOrdering ordering = to_LLVMAtomicOrdering(instruction->ordering);
    LLVMValueRef ptr = ir_llvm_value(g, instruction->ptr);
    LLVMValueRef value = ir_llvm_value(g, instruction->value);

    LLVMTypeRef actual_abi_type = get_atomic_abi_type(g, instruction->ptr);
    if (actual_abi_type != nullptr) {
        // operand needs widening
        ptr = LLVMBuildBitCast(g->builder, ptr,
                LLVMPointerType(actual_abi_type, 0), "");
        if (instruction->value->value->type->data.integral.is_signed) {
            value = LLVMBuildSExt(g->builder, value, actual_abi_type, "");
        } else {
            value = LLVMBuildZExt(g->builder, value, actual_abi_type, "");
        }
    }
    LLVMValueRef store_inst = gen_store(g, value, ptr, instruction->ptr->value->type);
    LLVMSetOrdering(store_inst, ordering);
    return nullptr;
}

static LLVMValueRef ir_render_float_op(CodeGen *g, IrExecutableGen *executable, IrInstGenFloatOp *instruction) {
    LLVMValueRef operand = ir_llvm_value(g, instruction->operand);
    LLVMValueRef fn_val = get_float_fn(g, instruction->base.value->type, ZigLLVMFnIdFloatOp, instruction->fn_id);
    return LLVMBuildCall(g->builder, fn_val, &operand, 1, "");
}

static LLVMValueRef ir_render_mul_add(CodeGen *g, IrExecutableGen *executable, IrInstGenMulAdd *instruction) {
    LLVMValueRef op1 = ir_llvm_value(g, instruction->op1);
    LLVMValueRef op2 = ir_llvm_value(g, instruction->op2);
    LLVMValueRef op3 = ir_llvm_value(g, instruction->op3);
    assert(instruction->base.value->type->id == ZigTypeIdFloat ||
           instruction->base.value->type->id == ZigTypeIdVector);
    LLVMValueRef fn_val = get_float_fn(g, instruction->base.value->type, ZigLLVMFnIdFMA, BuiltinFnIdMulAdd);
    LLVMValueRef args[3] = {
        op1,
        op2,
        op3,
    };
    return LLVMBuildCall(g->builder, fn_val, args, 3, "");
}

static LLVMValueRef ir_render_bswap(CodeGen *g, IrExecutableGen *executable, IrInstGenBswap *instruction) {
    LLVMValueRef op = ir_llvm_value(g, instruction->op);
    ZigType *expr_type = instruction->base.value->type;
    bool is_vector = expr_type->id == ZigTypeIdVector;
    ZigType *int_type = is_vector ? expr_type->data.vector.elem_type : expr_type;
    assert(int_type->id == ZigTypeIdInt);
    if (int_type->data.integral.bit_count % 16 == 0) {
        LLVMValueRef fn_val = get_int_builtin_fn(g, expr_type, BuiltinFnIdBswap);
        return LLVMBuildCall(g->builder, fn_val, &op, 1, "");
    }
    // Not an even number of bytes, so we zext 1 byte, then bswap, shift right 1 byte, truncate
    ZigType *extended_type = get_int_type(g, int_type->data.integral.is_signed,
            int_type->data.integral.bit_count + 8);
    LLVMValueRef shift_amt = LLVMConstInt(get_llvm_type(g, extended_type), 8, false);
    if (is_vector) {
        extended_type = get_vector_type(g, expr_type->data.vector.len, extended_type);
        LLVMValueRef *values = heap::c_allocator.allocate_nonzero<LLVMValueRef>(expr_type->data.vector.len);
        for (uint32_t i = 0; i < expr_type->data.vector.len; i += 1) {
            values[i] = shift_amt;
        }
        shift_amt = LLVMConstVector(values, expr_type->data.vector.len);
        heap::c_allocator.deallocate(values, expr_type->data.vector.len);
    }
    // aabbcc
    LLVMValueRef extended = LLVMBuildZExt(g->builder, op, get_llvm_type(g, extended_type), "");
    // 00aabbcc
    LLVMValueRef fn_val = get_int_builtin_fn(g, extended_type, BuiltinFnIdBswap);
    LLVMValueRef swapped = LLVMBuildCall(g->builder, fn_val, &extended, 1, "");
    // ccbbaa00
    LLVMValueRef shifted = ZigLLVMBuildLShrExact(g->builder, swapped, shift_amt, "");
    // 00ccbbaa
    return LLVMBuildTrunc(g->builder, shifted, get_llvm_type(g, expr_type), "");
}

static LLVMValueRef ir_render_bit_reverse(CodeGen *g, IrExecutableGen *executable, IrInstGenBitReverse *instruction) {
    LLVMValueRef op = ir_llvm_value(g, instruction->op);
    ZigType *int_type = instruction->base.value->type;
    assert(int_type->id == ZigTypeIdInt);
    LLVMValueRef fn_val = get_int_builtin_fn(g, instruction->base.value->type, BuiltinFnIdBitReverse);
    return LLVMBuildCall(g->builder, fn_val, &op, 1, "");
}

static LLVMValueRef ir_render_vector_to_array(CodeGen *g, IrExecutableGen *executable,
        IrInstGenVectorToArray *instruction)
{
    ZigType *array_type = instruction->base.value->type;
    assert(array_type->id == ZigTypeIdArray);
    assert(handle_is_ptr(g, array_type));
    LLVMValueRef result_loc = ir_llvm_value(g, instruction->result_loc);
    LLVMValueRef vector = ir_llvm_value(g, instruction->vector);

    ZigType *elem_type = array_type->data.array.child_type;
    bool bitcast_ok = elem_type->size_in_bits == elem_type->abi_size * 8;
    if (bitcast_ok) {
        LLVMValueRef casted_ptr = LLVMBuildBitCast(g->builder, result_loc,
                LLVMPointerType(get_llvm_type(g, instruction->vector->value->type), 0), "");
        uint32_t alignment = get_ptr_align(g, instruction->result_loc->value->type);
        gen_store_untyped(g, vector, casted_ptr, alignment, false);
    } else {
        // If the ABI size of the element type is not evenly divisible by size_in_bits, a simple bitcast
        // will not work, and we fall back to extractelement.
        LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
        LLVMTypeRef u32_type_ref = LLVMInt32Type();
        LLVMValueRef zero = LLVMConstInt(usize_type_ref, 0, false);
        for (uintptr_t i = 0; i < instruction->vector->value->type->data.vector.len; i++) {
            LLVMValueRef index_usize = LLVMConstInt(usize_type_ref, i, false);
            LLVMValueRef index_u32 = LLVMConstInt(u32_type_ref, i, false);
            LLVMValueRef indexes[] = { zero, index_usize };
            LLVMValueRef elem_ptr = LLVMBuildInBoundsGEP(g->builder, result_loc, indexes, 2, "");
            LLVMValueRef elem = LLVMBuildExtractElement(g->builder, vector, index_u32, "");
            LLVMBuildStore(g->builder, elem, elem_ptr);
        }
    }
    return result_loc;
}

static LLVMValueRef ir_render_array_to_vector(CodeGen *g, IrExecutableGen *executable,
        IrInstGenArrayToVector *instruction)
{
    ZigType *vector_type = instruction->base.value->type;
    assert(vector_type->id == ZigTypeIdVector);
    assert(!handle_is_ptr(g, vector_type));
    LLVMValueRef array_ptr = ir_llvm_value(g, instruction->array);
    LLVMTypeRef vector_type_ref = get_llvm_type(g, vector_type);

    ZigType *elem_type = vector_type->data.vector.elem_type;
    bool bitcast_ok = elem_type->size_in_bits == elem_type->abi_size * 8;
    if (bitcast_ok) {
        LLVMValueRef casted_ptr = LLVMBuildBitCast(g->builder, array_ptr,
                LLVMPointerType(vector_type_ref, 0), "");
        ZigType *array_type = instruction->array->value->type;
        assert(array_type->id == ZigTypeIdArray);
        uint32_t alignment = get_abi_alignment(g, array_type->data.array.child_type);
        return gen_load_untyped(g, casted_ptr, alignment, false, "");
    } else {
        // If the ABI size of the element type is not evenly divisible by size_in_bits, a simple bitcast
        // will not work, and we fall back to insertelement.
        LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
        LLVMTypeRef u32_type_ref = LLVMInt32Type();
        LLVMValueRef zero = LLVMConstInt(usize_type_ref, 0, false);
        LLVMValueRef vector = LLVMGetUndef(vector_type_ref);
        for (uintptr_t i = 0; i < instruction->base.value->type->data.vector.len; i++) {
            LLVMValueRef index_usize = LLVMConstInt(usize_type_ref, i, false);
            LLVMValueRef index_u32 = LLVMConstInt(u32_type_ref, i, false);
            LLVMValueRef indexes[] = { zero, index_usize };
            LLVMValueRef elem_ptr = LLVMBuildInBoundsGEP(g->builder, array_ptr, indexes, 2, "");
            LLVMValueRef elem = LLVMBuildLoad(g->builder, elem_ptr, "");
            vector = LLVMBuildInsertElement(g->builder, vector, elem, index_u32, "");
        }
        return vector;
    }
}

static LLVMValueRef ir_render_assert_zero(CodeGen *g, IrExecutableGen *executable,
        IrInstGenAssertZero *instruction)
{
    LLVMValueRef target = ir_llvm_value(g, instruction->target);
    ZigType *int_type = instruction->target->value->type;
    if (ir_want_runtime_safety(g, &instruction->base)) {
        return gen_assert_zero(g, target, int_type);
    }
    return nullptr;
}

static LLVMValueRef ir_render_assert_non_null(CodeGen *g, IrExecutableGen *executable,
        IrInstGenAssertNonNull *instruction)
{
    LLVMValueRef target = ir_llvm_value(g, instruction->target);
    ZigType *target_type = instruction->target->value->type;

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

static LLVMValueRef ir_render_suspend_begin(CodeGen *g, IrExecutableGen *executable,
        IrInstGenSuspendBegin *instruction)
{
    if (fn_is_async(g->cur_fn)) {
        instruction->resume_bb = gen_suspend_begin(g, "SuspendResume");
    }
    return nullptr;
}

static LLVMValueRef ir_render_suspend_finish(CodeGen *g, IrExecutableGen *executable,
        IrInstGenSuspendFinish *instruction)
{
    LLVMBuildRetVoid(g->builder);

    LLVMPositionBuilderAtEnd(g->builder, instruction->begin->resume_bb);
    if (ir_want_runtime_safety(g, &instruction->base)) {
        LLVMBuildStore(g->builder, g->cur_bad_not_suspended_index, g->cur_async_resume_index_ptr);
    }
    render_async_var_decls(g, instruction->base.base.scope);
    return nullptr;
}

static LLVMValueRef gen_await_early_return(CodeGen *g, IrInstGen *source_instr,
        LLVMValueRef target_frame_ptr, ZigType *result_type, ZigType *ptr_result_type,
        LLVMValueRef result_loc, bool non_async)
{
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
    LLVMValueRef their_result_ptr = nullptr;
    if (type_has_bits(g, result_type) && (non_async || result_loc != nullptr)) {
        LLVMValueRef their_result_ptr_ptr = LLVMBuildStructGEP(g->builder, target_frame_ptr, frame_ret_start, "");
        their_result_ptr = LLVMBuildLoad(g->builder, their_result_ptr_ptr, "");
        if (result_loc != nullptr) {
            LLVMTypeRef ptr_u8 = LLVMPointerType(LLVMInt8Type(), 0);
            LLVMValueRef dest_ptr_casted = LLVMBuildBitCast(g->builder, result_loc, ptr_u8, "");
            LLVMValueRef src_ptr_casted = LLVMBuildBitCast(g->builder, their_result_ptr, ptr_u8, "");
            bool is_volatile = false;
            uint32_t abi_align = get_abi_alignment(g, result_type);
            LLVMValueRef byte_count_val = LLVMConstInt(usize_type_ref, type_size(g, result_type), false);
            ZigLLVMBuildMemCpy(g->builder,
                    dest_ptr_casted, abi_align,
                    src_ptr_casted, abi_align, byte_count_val, is_volatile);
        }
    }
    if (codegen_fn_has_err_ret_tracing_arg(g, result_type)) {
        LLVMValueRef their_trace_ptr_ptr = LLVMBuildStructGEP(g->builder, target_frame_ptr,
                frame_index_trace_arg(g, result_type), "");
        LLVMValueRef src_trace_ptr = LLVMBuildLoad(g->builder, their_trace_ptr_ptr, "");
        bool is_llvm_alloca;
        LLVMValueRef dest_trace_ptr = get_cur_err_ret_trace_val(g, source_instr->base.scope, &is_llvm_alloca);
        LLVMValueRef args[] = { dest_trace_ptr, src_trace_ptr };
        ZigLLVMBuildCall(g->builder, get_merge_err_ret_traces_fn_val(g), args, 2,
                get_llvm_cc(g, CallingConventionUnspecified), ZigLLVM_CallAttrAuto, "");
    }
    if (non_async && type_has_bits(g, result_type)) {
        LLVMValueRef result_ptr = (result_loc == nullptr) ? their_result_ptr : result_loc;
        return get_handle_value(g, result_ptr, result_type, ptr_result_type);
    } else {
        return nullptr;
    }
}

static LLVMValueRef ir_render_await(CodeGen *g, IrExecutableGen *executable, IrInstGenAwait *instruction) {
    LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
    LLVMValueRef zero = LLVMConstNull(usize_type_ref);
    LLVMValueRef target_frame_ptr = ir_llvm_value(g, instruction->frame);
    ZigType *result_type = instruction->base.value->type;
    ZigType *ptr_result_type = get_pointer_to_type(g, result_type, true);

    LLVMValueRef result_loc = (instruction->result_loc == nullptr) ?
        nullptr : ir_llvm_value(g, instruction->result_loc);

    if (instruction->is_nosuspend ||
        (instruction->target_fn != nullptr && !fn_is_async(instruction->target_fn)))
    {
        return gen_await_early_return(g, &instruction->base, target_frame_ptr, result_type,
                ptr_result_type, result_loc, true);
    }

    // Prepare to be suspended
    LLVMBasicBlockRef resume_bb = gen_suspend_begin(g, "AwaitResume");
    LLVMBasicBlockRef end_bb = LLVMAppendBasicBlock(g->cur_fn_val, "AwaitEnd");

    // At this point resuming the function will continue from resume_bb.
    // This code is as if it is running inside the suspend block.

    // supply the awaiter return pointer
    if (type_has_bits(g, result_type)) {
        LLVMValueRef awaiter_ret_ptr_ptr = LLVMBuildStructGEP(g->builder, target_frame_ptr, frame_ret_start + 1, "");
        if (result_loc == nullptr) {
            // no copy needed
            LLVMBuildStore(g->builder, LLVMConstNull(LLVMGetElementType(LLVMTypeOf(awaiter_ret_ptr_ptr))),
                    awaiter_ret_ptr_ptr);
        } else {
            LLVMBuildStore(g->builder, result_loc, awaiter_ret_ptr_ptr);
        }
    }

    // supply the error return trace pointer
    if (codegen_fn_has_err_ret_tracing_arg(g, result_type)) {
        bool is_llvm_alloca;
        LLVMValueRef my_err_ret_trace_val = get_cur_err_ret_trace_val(g, instruction->base.base.scope, &is_llvm_alloca);
        assert(my_err_ret_trace_val != nullptr);
        LLVMValueRef err_ret_trace_ptr_ptr = LLVMBuildStructGEP(g->builder, target_frame_ptr,
                frame_index_trace_arg(g, result_type) + 1, "");
        LLVMBuildStore(g->builder, my_err_ret_trace_val, err_ret_trace_ptr_ptr);
    }

    // caller's own frame pointer
    LLVMValueRef awaiter_init_val = LLVMBuildPtrToInt(g->builder, g->cur_frame_ptr, usize_type_ref, "");
    LLVMValueRef awaiter_ptr = LLVMBuildStructGEP(g->builder, target_frame_ptr, frame_awaiter_index, "");
    LLVMValueRef prev_val = gen_maybe_atomic_op(g, LLVMAtomicRMWBinOpXchg, awaiter_ptr, awaiter_init_val,
            LLVMAtomicOrderingRelease);

    LLVMBasicBlockRef bad_await_block = LLVMAppendBasicBlock(g->cur_fn_val, "BadAwait");
    LLVMBasicBlockRef complete_suspend_block = LLVMAppendBasicBlock(g->cur_fn_val, "CompleteSuspend");
    LLVMBasicBlockRef early_return_block = LLVMAppendBasicBlock(g->cur_fn_val, "EarlyReturn");

    LLVMValueRef all_ones = LLVMConstAllOnes(usize_type_ref);
    LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, prev_val, bad_await_block, 2);

    LLVMAddCase(switch_instr, zero, complete_suspend_block);
    LLVMAddCase(switch_instr, all_ones, early_return_block);

    // We discovered that another awaiter was already here.
    LLVMPositionBuilderAtEnd(g->builder, bad_await_block);
    gen_assertion(g, PanicMsgIdBadAwait, &instruction->base);

    // Rely on the target to resume us from suspension.
    LLVMPositionBuilderAtEnd(g->builder, complete_suspend_block);
    LLVMBuildRetVoid(g->builder);

    // Early return: The async function has already completed. We must copy the result and
    // the error return trace if applicable.
    LLVMPositionBuilderAtEnd(g->builder, early_return_block);
    gen_await_early_return(g, &instruction->base, target_frame_ptr, result_type, ptr_result_type,
            result_loc, false);
    LLVMBuildBr(g->builder, end_bb);

    LLVMPositionBuilderAtEnd(g->builder, resume_bb);
    gen_assert_resume_id(g, &instruction->base, ResumeIdReturn, PanicMsgIdResumedAnAwaitingFn, nullptr);
    LLVMBuildBr(g->builder, end_bb);

    LLVMPositionBuilderAtEnd(g->builder, end_bb);
    // Rely on the spill for the llvm_value to be populated.
    // See the implementation of ir_llvm_value.
    return nullptr;
}

static LLVMValueRef ir_render_resume(CodeGen *g, IrExecutableGen *executable, IrInstGenResume *instruction) {
    LLVMValueRef frame = ir_llvm_value(g, instruction->frame);
    ZigType *frame_type = instruction->frame->value->type;
    assert(frame_type->id == ZigTypeIdAnyFrame);

    gen_resume(g, nullptr, frame, ResumeIdManual);
    return nullptr;
}

static LLVMValueRef ir_render_frame_size(CodeGen *g, IrExecutableGen *executable,
        IrInstGenFrameSize *instruction)
{
    LLVMValueRef fn_val = ir_llvm_value(g, instruction->fn);
    return gen_frame_size(g, fn_val);
}

static LLVMValueRef ir_render_spill_begin(CodeGen *g, IrExecutableGen *executable,
        IrInstGenSpillBegin *instruction)
{
    if (!fn_is_async(g->cur_fn))
        return nullptr;

    switch (instruction->spill_id) {
        case SpillIdInvalid:
            zig_unreachable();
        case SpillIdRetErrCode: {
            LLVMValueRef operand = ir_llvm_value(g, instruction->operand);
            LLVMValueRef ptr = ir_llvm_value(g, g->cur_fn->err_code_spill);
            LLVMBuildStore(g->builder, operand, ptr);
            return nullptr;
        }

    }
    zig_unreachable();
}

static LLVMValueRef ir_render_spill_end(CodeGen *g, IrExecutableGen *executable, IrInstGenSpillEnd *instruction) {
    if (!fn_is_async(g->cur_fn))
        return ir_llvm_value(g, instruction->begin->operand);

    switch (instruction->begin->spill_id) {
        case SpillIdInvalid:
            zig_unreachable();
        case SpillIdRetErrCode: {
            LLVMValueRef ptr = ir_llvm_value(g, g->cur_fn->err_code_spill);
            return LLVMBuildLoad(g->builder, ptr, "");
        }

    }
    zig_unreachable();
}

static LLVMValueRef ir_render_vector_extract_elem(CodeGen *g, IrExecutableGen *executable,
        IrInstGenVectorExtractElem *instruction)
{
    LLVMValueRef vector = ir_llvm_value(g, instruction->vector);
    LLVMValueRef index = ir_llvm_value(g, instruction->index);
    return LLVMBuildExtractElement(g->builder, vector, index, "");
}

static void set_debug_location(CodeGen *g, IrInstGen *instruction) {
    AstNode *source_node = instruction->base.source_node;
    Scope *scope = instruction->base.scope;

    assert(source_node);
    assert(scope);

    ZigLLVMSetCurrentDebugLocation(g->builder, (int)source_node->line + 1,
            (int)source_node->column + 1, get_di_scope(g, scope));
}

static LLVMValueRef ir_render_instruction(CodeGen *g, IrExecutableGen *executable, IrInstGen *instruction) {
    switch (instruction->id) {
        case IrInstGenIdInvalid:
        case IrInstGenIdConst:
        case IrInstGenIdAlloca:
            zig_unreachable();

        case IrInstGenIdDeclVar:
            return ir_render_decl_var(g, executable, (IrInstGenDeclVar *)instruction);
        case IrInstGenIdReturn:
            return ir_render_return(g, executable, (IrInstGenReturn *)instruction);
        case IrInstGenIdBinOp:
            return ir_render_bin_op(g, executable, (IrInstGenBinOp *)instruction);
        case IrInstGenIdCast:
            return ir_render_cast(g, executable, (IrInstGenCast *)instruction);
        case IrInstGenIdUnreachable:
            return ir_render_unreachable(g, executable, (IrInstGenUnreachable *)instruction);
        case IrInstGenIdCondBr:
            return ir_render_cond_br(g, executable, (IrInstGenCondBr *)instruction);
        case IrInstGenIdBr:
            return ir_render_br(g, executable, (IrInstGenBr *)instruction);
        case IrInstGenIdBinaryNot:
            return ir_render_binary_not(g, executable, (IrInstGenBinaryNot *)instruction);
        case IrInstGenIdNegation:
            return ir_render_negation(g, executable, (IrInstGenNegation *)instruction);
        case IrInstGenIdNegationWrapping:
            return ir_render_negation_wrapping(g, executable, (IrInstGenNegationWrapping *)instruction);
        case IrInstGenIdLoadPtr:
            return ir_render_load_ptr(g, executable, (IrInstGenLoadPtr *)instruction);
        case IrInstGenIdStorePtr:
            return ir_render_store_ptr(g, executable, (IrInstGenStorePtr *)instruction);
        case IrInstGenIdVectorStoreElem:
            return ir_render_vector_store_elem(g, executable, (IrInstGenVectorStoreElem *)instruction);
        case IrInstGenIdVarPtr:
            return ir_render_var_ptr(g, executable, (IrInstGenVarPtr *)instruction);
        case IrInstGenIdReturnPtr:
            return ir_render_return_ptr(g, executable, (IrInstGenReturnPtr *)instruction);
        case IrInstGenIdElemPtr:
            return ir_render_elem_ptr(g, executable, (IrInstGenElemPtr *)instruction);
        case IrInstGenIdCall:
            return ir_render_call(g, executable, (IrInstGenCall *)instruction);
        case IrInstGenIdStructFieldPtr:
            return ir_render_struct_field_ptr(g, executable, (IrInstGenStructFieldPtr *)instruction);
        case IrInstGenIdUnionFieldPtr:
            return ir_render_union_field_ptr(g, executable, (IrInstGenUnionFieldPtr *)instruction);
        case IrInstGenIdAsm:
            return ir_render_asm_gen(g, executable, (IrInstGenAsm *)instruction);
        case IrInstGenIdTestNonNull:
            return ir_render_test_non_null(g, executable, (IrInstGenTestNonNull *)instruction);
        case IrInstGenIdOptionalUnwrapPtr:
            return ir_render_optional_unwrap_ptr(g, executable, (IrInstGenOptionalUnwrapPtr *)instruction);
        case IrInstGenIdClz:
            return ir_render_clz(g, executable, (IrInstGenClz *)instruction);
        case IrInstGenIdCtz:
            return ir_render_ctz(g, executable, (IrInstGenCtz *)instruction);
        case IrInstGenIdPopCount:
            return ir_render_pop_count(g, executable, (IrInstGenPopCount *)instruction);
        case IrInstGenIdSwitchBr:
            return ir_render_switch_br(g, executable, (IrInstGenSwitchBr *)instruction);
        case IrInstGenIdBswap:
            return ir_render_bswap(g, executable, (IrInstGenBswap *)instruction);
        case IrInstGenIdBitReverse:
            return ir_render_bit_reverse(g, executable, (IrInstGenBitReverse *)instruction);
        case IrInstGenIdPhi:
            return ir_render_phi(g, executable, (IrInstGenPhi *)instruction);
        case IrInstGenIdRef:
            return ir_render_ref(g, executable, (IrInstGenRef *)instruction);
        case IrInstGenIdErrName:
            return ir_render_err_name(g, executable, (IrInstGenErrName *)instruction);
        case IrInstGenIdCmpxchg:
            return ir_render_cmpxchg(g, executable, (IrInstGenCmpxchg *)instruction);
        case IrInstGenIdFence:
            return ir_render_fence(g, executable, (IrInstGenFence *)instruction);
        case IrInstGenIdTruncate:
            return ir_render_truncate(g, executable, (IrInstGenTruncate *)instruction);
        case IrInstGenIdBoolNot:
            return ir_render_bool_not(g, executable, (IrInstGenBoolNot *)instruction);
        case IrInstGenIdMemset:
            return ir_render_memset(g, executable, (IrInstGenMemset *)instruction);
        case IrInstGenIdMemcpy:
            return ir_render_memcpy(g, executable, (IrInstGenMemcpy *)instruction);
        case IrInstGenIdSlice:
            return ir_render_slice(g, executable, (IrInstGenSlice *)instruction);
        case IrInstGenIdBreakpoint:
            return ir_render_breakpoint(g, executable, (IrInstGenBreakpoint *)instruction);
        case IrInstGenIdReturnAddress:
            return ir_render_return_address(g, executable, (IrInstGenReturnAddress *)instruction);
        case IrInstGenIdFrameAddress:
            return ir_render_frame_address(g, executable, (IrInstGenFrameAddress *)instruction);
        case IrInstGenIdFrameHandle:
            return ir_render_handle(g, executable, (IrInstGenFrameHandle *)instruction);
        case IrInstGenIdOverflowOp:
            return ir_render_overflow_op(g, executable, (IrInstGenOverflowOp *)instruction);
        case IrInstGenIdTestErr:
            return ir_render_test_err(g, executable, (IrInstGenTestErr *)instruction);
        case IrInstGenIdUnwrapErrCode:
            return ir_render_unwrap_err_code(g, executable, (IrInstGenUnwrapErrCode *)instruction);
        case IrInstGenIdUnwrapErrPayload:
            return ir_render_unwrap_err_payload(g, executable, (IrInstGenUnwrapErrPayload *)instruction);
        case IrInstGenIdOptionalWrap:
            return ir_render_optional_wrap(g, executable, (IrInstGenOptionalWrap *)instruction);
        case IrInstGenIdErrWrapCode:
            return ir_render_err_wrap_code(g, executable, (IrInstGenErrWrapCode *)instruction);
        case IrInstGenIdErrWrapPayload:
            return ir_render_err_wrap_payload(g, executable, (IrInstGenErrWrapPayload *)instruction);
        case IrInstGenIdUnionTag:
            return ir_render_union_tag(g, executable, (IrInstGenUnionTag *)instruction);
        case IrInstGenIdPtrCast:
            return ir_render_ptr_cast(g, executable, (IrInstGenPtrCast *)instruction);
        case IrInstGenIdBitCast:
            return ir_render_bit_cast(g, executable, (IrInstGenBitCast *)instruction);
        case IrInstGenIdWidenOrShorten:
            return ir_render_widen_or_shorten(g, executable, (IrInstGenWidenOrShorten *)instruction);
        case IrInstGenIdPtrToInt:
            return ir_render_ptr_to_int(g, executable, (IrInstGenPtrToInt *)instruction);
        case IrInstGenIdIntToPtr:
            return ir_render_int_to_ptr(g, executable, (IrInstGenIntToPtr *)instruction);
        case IrInstGenIdIntToEnum:
            return ir_render_int_to_enum(g, executable, (IrInstGenIntToEnum *)instruction);
        case IrInstGenIdIntToErr:
            return ir_render_int_to_err(g, executable, (IrInstGenIntToErr *)instruction);
        case IrInstGenIdErrToInt:
            return ir_render_err_to_int(g, executable, (IrInstGenErrToInt *)instruction);
        case IrInstGenIdPanic:
            return ir_render_panic(g, executable, (IrInstGenPanic *)instruction);
        case IrInstGenIdTagName:
            return ir_render_enum_tag_name(g, executable, (IrInstGenTagName *)instruction);
        case IrInstGenIdFieldParentPtr:
            return ir_render_field_parent_ptr(g, executable, (IrInstGenFieldParentPtr *)instruction);
        case IrInstGenIdAlignCast:
            return ir_render_align_cast(g, executable, (IrInstGenAlignCast *)instruction);
        case IrInstGenIdErrorReturnTrace:
            return ir_render_error_return_trace(g, executable, (IrInstGenErrorReturnTrace *)instruction);
        case IrInstGenIdAtomicRmw:
            return ir_render_atomic_rmw(g, executable, (IrInstGenAtomicRmw *)instruction);
        case IrInstGenIdAtomicLoad:
            return ir_render_atomic_load(g, executable, (IrInstGenAtomicLoad *)instruction);
        case IrInstGenIdAtomicStore:
            return ir_render_atomic_store(g, executable, (IrInstGenAtomicStore *)instruction);
        case IrInstGenIdSaveErrRetAddr:
            return ir_render_save_err_ret_addr(g, executable, (IrInstGenSaveErrRetAddr *)instruction);
        case IrInstGenIdFloatOp:
            return ir_render_float_op(g, executable, (IrInstGenFloatOp *)instruction);
        case IrInstGenIdMulAdd:
            return ir_render_mul_add(g, executable, (IrInstGenMulAdd *)instruction);
        case IrInstGenIdArrayToVector:
            return ir_render_array_to_vector(g, executable, (IrInstGenArrayToVector *)instruction);
        case IrInstGenIdVectorToArray:
            return ir_render_vector_to_array(g, executable, (IrInstGenVectorToArray *)instruction);
        case IrInstGenIdAssertZero:
            return ir_render_assert_zero(g, executable, (IrInstGenAssertZero *)instruction);
        case IrInstGenIdAssertNonNull:
            return ir_render_assert_non_null(g, executable, (IrInstGenAssertNonNull *)instruction);
        case IrInstGenIdPtrOfArrayToSlice:
            return ir_render_ptr_of_array_to_slice(g, executable, (IrInstGenPtrOfArrayToSlice *)instruction);
        case IrInstGenIdSuspendBegin:
            return ir_render_suspend_begin(g, executable, (IrInstGenSuspendBegin *)instruction);
        case IrInstGenIdSuspendFinish:
            return ir_render_suspend_finish(g, executable, (IrInstGenSuspendFinish *)instruction);
        case IrInstGenIdResume:
            return ir_render_resume(g, executable, (IrInstGenResume *)instruction);
        case IrInstGenIdFrameSize:
            return ir_render_frame_size(g, executable, (IrInstGenFrameSize *)instruction);
        case IrInstGenIdAwait:
            return ir_render_await(g, executable, (IrInstGenAwait *)instruction);
        case IrInstGenIdSpillBegin:
            return ir_render_spill_begin(g, executable, (IrInstGenSpillBegin *)instruction);
        case IrInstGenIdSpillEnd:
            return ir_render_spill_end(g, executable, (IrInstGenSpillEnd *)instruction);
        case IrInstGenIdShuffleVector:
            return ir_render_shuffle_vector(g, executable, (IrInstGenShuffleVector *) instruction);
        case IrInstGenIdSplat:
            return ir_render_splat(g, executable, (IrInstGenSplat *) instruction);
        case IrInstGenIdVectorExtractElem:
            return ir_render_vector_extract_elem(g, executable, (IrInstGenVectorExtractElem *) instruction);
        case IrInstGenIdWasmMemorySize:
            return ir_render_wasm_memory_size(g, executable, (IrInstGenWasmMemorySize *) instruction);
        case IrInstGenIdWasmMemoryGrow:
            return ir_render_wasm_memory_grow(g, executable, (IrInstGenWasmMemoryGrow *) instruction);
    }
    zig_unreachable();
}

static void ir_render(CodeGen *g, ZigFn *fn_entry) {
    assert(fn_entry);

    IrExecutableGen *executable = &fn_entry->analyzed_executable;
    assert(executable->basic_block_list.length > 0);

    for (size_t block_i = 0; block_i < executable->basic_block_list.length; block_i += 1) {
        IrBasicBlockGen *current_block = executable->basic_block_list.at(block_i);
        if (get_scope_typeof(current_block->scope) != nullptr) {
            LLVMBuildBr(g->builder, current_block->llvm_block);
        }
        assert(current_block->llvm_block);
        LLVMPositionBuilderAtEnd(g->builder, current_block->llvm_block);
        for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
            IrInstGen *instruction = current_block->instruction_list.at(instr_i);
            if (instruction->base.ref_count == 0 && !ir_inst_gen_has_side_effects(instruction))
                continue;
            if (get_scope_typeof(instruction->base.scope) != nullptr)
                continue;

            if (!g->strip_debug_symbols) {
                set_debug_location(g, instruction);
            }
            instruction->llvm_value = ir_render_instruction(g, executable, instruction);
            if (instruction->spill != nullptr && instruction->llvm_value != nullptr) {
                LLVMValueRef spill_ptr = ir_llvm_value(g, instruction->spill);
                gen_assign_raw(g, spill_ptr, instruction->spill->value->type, instruction->llvm_value);
                instruction->llvm_value = nullptr;
            }
        }
        current_block->llvm_exit_block = LLVMGetInsertBlock(g->builder);
    }
}

static LLVMValueRef gen_const_ptr_struct_recursive(CodeGen *g, ZigValue *struct_const_val, size_t field_index);
static LLVMValueRef gen_const_ptr_array_recursive(CodeGen *g, ZigValue *array_const_val, size_t index);
static LLVMValueRef gen_const_ptr_union_recursive(CodeGen *g, ZigValue *union_const_val);
static LLVMValueRef gen_const_ptr_err_union_code_recursive(CodeGen *g, ZigValue *err_union_const_val);
static LLVMValueRef gen_const_ptr_err_union_payload_recursive(CodeGen *g, ZigValue *err_union_const_val);
static LLVMValueRef gen_const_ptr_optional_payload_recursive(CodeGen *g, ZigValue *optional_const_val);

static LLVMValueRef gen_parent_ptr(CodeGen *g, ZigValue *val, ConstParent *parent) {
    switch (parent->id) {
        case ConstParentIdNone:
            render_const_val(g, val, "");
            render_const_val_global(g, val, "");
            return val->llvm_global;
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
            return parent->data.p_scalar.scalar_val->llvm_global;
    }
    zig_unreachable();
}

static LLVMValueRef gen_const_ptr_array_recursive(CodeGen *g, ZigValue *array_const_val, size_t index) {
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
        return base_ptr;
    }
}

static LLVMValueRef gen_const_ptr_struct_recursive(CodeGen *g, ZigValue *struct_const_val, size_t field_index) {
    ConstParent *parent = &struct_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, struct_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), field_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_err_union_code_recursive(CodeGen *g, ZigValue *err_union_const_val) {
    ConstParent *parent = &err_union_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, err_union_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), err_union_err_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_err_union_payload_recursive(CodeGen *g, ZigValue *err_union_const_val) {
    ConstParent *parent = &err_union_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, err_union_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), err_union_payload_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_optional_payload_recursive(CodeGen *g, ZigValue *optional_const_val) {
    ConstParent *parent = &optional_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, optional_const_val, parent);

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), maybe_child_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, 2);
}

static LLVMValueRef gen_const_ptr_union_recursive(CodeGen *g, ZigValue *union_const_val) {
    ConstParent *parent = &union_const_val->parent;
    LLVMValueRef base_ptr = gen_parent_ptr(g, union_const_val, parent);

    // Slot in the structure where the payload is stored, if equal to SIZE_MAX
    // the union has no tag and a single field and is collapsed into the field
    // itself
    size_t union_payload_index = union_const_val->type->data.unionation.gen_union_index;

    ZigType *u32 = g->builtin_types.entry_u32;
    LLVMValueRef indices[] = {
        LLVMConstNull(get_llvm_type(g, u32)),
        LLVMConstInt(get_llvm_type(g, u32), union_payload_index, false),
    };
    return LLVMConstInBoundsGEP(base_ptr, indices, (union_payload_index != SIZE_MAX) ? 2 : 1);
}

static LLVMValueRef pack_const_int(CodeGen *g, LLVMTypeRef big_int_type_ref, ZigValue *const_val) {
    switch (const_val->special) {
        case ConstValSpecialLazy:
        case ConstValSpecialRuntime:
            zig_unreachable();
        case ConstValSpecialUndef:
            return LLVMConstInt(big_int_type_ref, 0, false);
        case ConstValSpecialStatic:
            break;
    }

    ZigType *type_entry = const_val->type;
    assert(type_has_bits(g, type_entry));
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
                ZigValue *elem_val = &const_val->data.x_array.data.s_none.elements[i];
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

            if (type_entry->data.array.sentinel != nullptr) {
                ZigValue *elem_val = type_entry->data.array.sentinel;
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
                    TypeStructField *field = type_entry->data.structure.fields[i];
                    if (field->gen_index == SIZE_MAX) {
                        continue;
                    }
                    LLVMValueRef child_val = pack_const_int(g, big_int_type_ref, const_val->data.x_struct.fields[i]);
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
        case ZigTypeIdFnFrame:
            zig_panic("TODO bit pack an async function frame");
        case ZigTypeIdAnyFrame:
            zig_panic("TODO bit pack an anyframe");
    }
    zig_unreachable();
}

// We have this because union constants can't be represented by the official union type,
// and this property bubbles up in whatever aggregate type contains a union constant
static bool is_llvm_value_unnamed_type(CodeGen *g, ZigType *type_entry, LLVMValueRef val) {
    return LLVMTypeOf(val) != get_llvm_type(g, type_entry);
}

static LLVMValueRef gen_const_val_ptr(CodeGen *g, ZigValue *const_val, const char *name) {
    switch (const_val->data.x_ptr.special) {
        case ConstPtrSpecialInvalid:
        case ConstPtrSpecialDiscard:
            zig_unreachable();
        case ConstPtrSpecialRef:
            {
                ZigValue *pointee = const_val->data.x_ptr.data.ref.pointee;
                render_const_val(g, pointee, "");
                render_const_val_global(g, pointee, "");
                const_val->llvm_value = LLVMConstBitCast(pointee->llvm_global,
                        get_llvm_type(g, const_val->type));
                return const_val->llvm_value;
            }
        case ConstPtrSpecialBaseArray:
        case ConstPtrSpecialSubArray:
            {
                ZigValue *array_const_val = const_val->data.x_ptr.data.base_array.array_val;
                assert(array_const_val->type->id == ZigTypeIdArray);
                if (!type_has_bits(g, array_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->llvm_value;
                }
                size_t elem_index = const_val->data.x_ptr.data.base_array.elem_index;
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_array_recursive(g, array_const_val, elem_index);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseStruct:
            {
                ZigValue *struct_const_val = const_val->data.x_ptr.data.base_struct.struct_val;
                assert(struct_const_val->type->id == ZigTypeIdStruct);
                if (!type_has_bits(g, struct_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->llvm_value;
                }
                size_t src_field_index = const_val->data.x_ptr.data.base_struct.field_index;
                size_t gen_field_index = struct_const_val->type->data.structure.fields[src_field_index]->gen_index;
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_struct_recursive(g, struct_const_val,
                        gen_field_index);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseErrorUnionCode:
            {
                ZigValue *err_union_const_val = const_val->data.x_ptr.data.base_err_union_code.err_union_val;
                assert(err_union_const_val->type->id == ZigTypeIdErrorUnion);
                if (!type_has_bits(g, err_union_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->llvm_value;
                }
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_err_union_code_recursive(g, err_union_const_val);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseErrorUnionPayload:
            {
                ZigValue *err_union_const_val = const_val->data.x_ptr.data.base_err_union_payload.err_union_val;
                assert(err_union_const_val->type->id == ZigTypeIdErrorUnion);
                if (!type_has_bits(g, err_union_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->llvm_value;
                }
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_err_union_payload_recursive(g, err_union_const_val);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialBaseOptionalPayload:
            {
                ZigValue *optional_const_val = const_val->data.x_ptr.data.base_optional_payload.optional_val;
                assert(optional_const_val->type->id == ZigTypeIdOptional);
                if (!type_has_bits(g, optional_const_val->type)) {
                    // make this a null pointer
                    ZigType *usize = g->builtin_types.entry_usize;
                    const_val->llvm_value = LLVMConstIntToPtr(LLVMConstNull(usize->llvm_type),
                            get_llvm_type(g, const_val->type));
                    return const_val->llvm_value;
                }
                LLVMValueRef uncasted_ptr_val = gen_const_ptr_optional_payload_recursive(g, optional_const_val);
                LLVMValueRef ptr_val = LLVMConstBitCast(uncasted_ptr_val, get_llvm_type(g, const_val->type));
                const_val->llvm_value = ptr_val;
                return ptr_val;
            }
        case ConstPtrSpecialHardCodedAddr:
            {
                uint64_t addr_value = const_val->data.x_ptr.data.hard_coded_addr.addr;
                ZigType *usize = g->builtin_types.entry_usize;
                const_val->llvm_value = LLVMConstIntToPtr(
                        LLVMConstInt(usize->llvm_type, addr_value, false), get_llvm_type(g, const_val->type));
                return const_val->llvm_value;
            }
        case ConstPtrSpecialFunction:
            return LLVMConstBitCast(fn_llvm_value(g, const_val->data.x_ptr.data.fn.fn_entry),
                    get_llvm_type(g, const_val->type));
        case ConstPtrSpecialNull:
            return LLVMConstNull(get_llvm_type(g, const_val->type));
    }
    zig_unreachable();
}

static LLVMValueRef gen_const_val_err_set(CodeGen *g, ZigValue *const_val, const char *name) {
    uint64_t value = (const_val->data.x_err_set == nullptr) ? 0 : const_val->data.x_err_set->value;
    return LLVMConstInt(get_llvm_type(g, g->builtin_types.entry_global_error_set), value, false);
}

static LLVMValueRef gen_const_val(CodeGen *g, ZigValue *const_val, const char *name) {
    Error err;

    ZigType *type_entry = const_val->type;
    assert(type_has_bits(g, type_entry));

    if (const_val->special == ConstValSpecialLazy &&
        (err = ir_resolve_lazy(g, nullptr, const_val)))
        codegen_report_errors_and_exit(g);

    switch (const_val->special) {
        case ConstValSpecialLazy:
        case ConstValSpecialRuntime:
            zig_unreachable();
        case ConstValSpecialUndef:
            return LLVMGetUndef(get_llvm_type(g, type_entry));
        case ConstValSpecialStatic:
            break;
    }

    if ((err = type_resolve(g, type_entry, ResolveStatusLLVMFull)))
        zig_unreachable();

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

                if (get_src_ptr_type(type_entry) != nullptr) {
                    bool has_bits;
                    if ((err = type_has_bits2(g, child_type, &has_bits)))
                        codegen_report_errors_and_exit(g);

                    if (has_bits)
                        return gen_const_val_ptr(g, const_val, name);

                    // No bits, treat this value as a boolean
                    const unsigned bool_val = optional_value_is_null(const_val) ? 0 : 1;
                    return LLVMConstInt(LLVMInt1Type(), bool_val, false);
                } else if (child_type->id == ZigTypeIdErrorSet) {
                    return gen_const_val_err_set(g, const_val, name);
                } else if (!type_has_bits(g, child_type)) {
                    return LLVMConstInt(LLVMInt1Type(), const_val->data.x_optional ? 1 : 0, false);
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
                        nullptr,
                    };
                    if (make_unnamed_struct) {
                        LLVMValueRef result = LLVMConstStruct(fields, 2, false);
                        uint64_t last_field_offset = LLVMOffsetOfElement(g->target_data_ref, LLVMTypeOf(result), 1);
                        uint64_t end_offset = last_field_offset +
                            LLVMStoreSizeOfType(g->target_data_ref, LLVMTypeOf(fields[1]));
                        uint64_t expected_sz = LLVMABISizeOfType(g->target_data_ref, get_llvm_type(g, type_entry));
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
            }
        case ZigTypeIdStruct:
            {
                LLVMValueRef *fields = heap::c_allocator.allocate<LLVMValueRef>(type_entry->data.structure.gen_field_count);
                size_t src_field_count = type_entry->data.structure.src_field_count;
                bool make_unnamed_struct = false;
                assert(type_entry->data.structure.resolve_status == ResolveStatusLLVMFull);
                if (type_entry->data.structure.layout == ContainerLayoutPacked) {
                    size_t src_field_index = 0;
                    while (src_field_index < src_field_count) {
                        TypeStructField *type_struct_field = type_entry->data.structure.fields[src_field_index];
                        if (type_struct_field->gen_index == SIZE_MAX) {
                            src_field_index += 1;
                            continue;
                        }

                        size_t src_field_index_end = src_field_index + 1;
                        for (; src_field_index_end < src_field_count; src_field_index_end += 1) {
                            TypeStructField *it_field = type_entry->data.structure.fields[src_field_index_end];
                            if (it_field->gen_index != type_struct_field->gen_index)
                                break;
                        }

                        if (src_field_index + 1 == src_field_index_end) {
                            ZigValue *field_val = const_val->data.x_struct.fields[src_field_index];
                            LLVMValueRef val = gen_const_val(g, field_val, "");
                            fields[type_struct_field->gen_index] = val;
                            make_unnamed_struct = make_unnamed_struct || is_llvm_value_unnamed_type(g, field_val->type, val);
                        } else {
                            bool is_big_endian = g->is_big_endian; // TODO get endianness from struct type
                            LLVMTypeRef field_ty = LLVMStructGetTypeAtIndex(get_llvm_type(g, type_entry),
                                    (unsigned)type_struct_field->gen_index);
                            const size_t size_in_bytes = LLVMStoreSizeOfType(g->target_data_ref, field_ty);
                            const size_t size_in_bits = size_in_bytes * 8;
                            LLVMTypeRef big_int_type_ref = LLVMIntType(size_in_bits);
                            LLVMValueRef val = LLVMConstInt(big_int_type_ref, 0, false);
                            size_t used_bits = 0;
                            for (size_t i = src_field_index; i < src_field_index_end; i += 1) {
                                TypeStructField *it_field = type_entry->data.structure.fields[i];
                                if (it_field->gen_index == SIZE_MAX) {
                                    continue;
                                }
                                LLVMValueRef child_val = pack_const_int(g, big_int_type_ref,
                                        const_val->data.x_struct.fields[i]);
                                uint32_t packed_bits_size = type_size_bits(g, it_field->type_entry);
                                if (is_big_endian) {
                                    LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref,
                                        size_in_bits - used_bits - packed_bits_size, false);
                                    LLVMValueRef child_val_shifted = LLVMConstShl(child_val, shift_amt);
                                    val = LLVMConstOr(val, child_val_shifted);
                                } else {
                                    LLVMValueRef shift_amt = LLVMConstInt(big_int_type_ref, used_bits, false);
                                    LLVMValueRef child_val_shifted = LLVMConstShl(child_val, shift_amt);
                                    val = LLVMConstOr(val, child_val_shifted);
                                }
                                used_bits += packed_bits_size;
                            }
                            assert(size_in_bits >= used_bits);
                            if (LLVMGetTypeKind(field_ty) != LLVMArrayTypeKind) {
                                assert(LLVMGetTypeKind(field_ty) == LLVMIntegerTypeKind);
                                fields[type_struct_field->gen_index] = val;
                            } else {
                                const LLVMValueRef AMT = LLVMConstInt(LLVMTypeOf(val), 8, false);

                                LLVMValueRef *values = heap::c_allocator.allocate<LLVMValueRef>(size_in_bytes);
                                for (size_t i = 0; i < size_in_bytes; i++) {
                                    const size_t idx = is_big_endian ? size_in_bytes - 1 - i : i;
                                    values[idx] = LLVMConstTruncOrBitCast(val, LLVMInt8Type());
                                    val = LLVMConstLShr(val, AMT);
                                }

                                fields[type_struct_field->gen_index] = LLVMConstArray(LLVMInt8Type(), values, size_in_bytes);
                            }
                        }

                        src_field_index = src_field_index_end;
                    }
                } else {
                    for (uint32_t i = 0; i < src_field_count; i += 1) {
                        TypeStructField *type_struct_field = type_entry->data.structure.fields[i];
                        if (type_struct_field->gen_index == SIZE_MAX) {
                            continue;
                        }
                        ZigValue *field_val = const_val->data.x_struct.fields[i];
                        if (field_val == nullptr) {
                            add_node_error(g, type_struct_field->decl_node,
                                    buf_sprintf("compiler bug: generating const value for struct field '%s'",
                                        buf_ptr(type_struct_field->name)));
                            codegen_report_errors_and_exit(g);
                        }
                        ZigType *field_type = field_val->type;
                        assert(field_type != nullptr);
                        if ((err = ensure_const_val_repr(nullptr, g, nullptr, field_val, field_type))) {
                            zig_unreachable();
                        }

                        LLVMValueRef val = gen_const_val(g, field_val, "");
                        make_unnamed_struct = make_unnamed_struct || is_llvm_value_unnamed_type(g, field_type, val);

                        // Find the next runtime field
                        size_t next_rt_gen_index = type_entry->data.structure.gen_field_count;
                        size_t next_offset = type_entry->abi_size;
                        for (size_t j = i + 1; j < src_field_count; j++) {
                            const size_t index = type_entry->data.structure.fields[j]->gen_index;
                            const size_t offset = type_entry->data.structure.fields[j]->offset;

                            if (index != SIZE_MAX) {
                                next_rt_gen_index = index;
                                next_offset = offset;
                                break;
                            }
                        }

                        // How much padding is needed to reach the next field
                        const size_t pad_bytes = next_offset -
                            (type_struct_field->offset + LLVMABISizeOfType(g->target_data_ref, LLVMTypeOf(val)));
                        // Catch underflow
                        assert((ssize_t)pad_bytes >= 0);

                        if (type_struct_field->gen_index + 1 != next_rt_gen_index) {
                            // If there's a hole between this field and the next
                            // we have an alignment gap to fill
                            fields[type_struct_field->gen_index] = val;
                            fields[type_struct_field->gen_index + 1] = LLVMGetUndef(LLVMArrayType(LLVMInt8Type(), pad_bytes));
                        } else if (pad_bytes != 0) {
                            LLVMValueRef padded_val[] = {
                                val,
                                LLVMGetUndef(LLVMArrayType(LLVMInt8Type(), pad_bytes)),
                            };
                            fields[type_struct_field->gen_index] = LLVMConstStruct(padded_val, 2, true);
                            make_unnamed_struct = true;
                        } else {
                            fields[type_struct_field->gen_index] = val;
                        }
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
                        uint64_t extra_len_from_sentinel = (type_entry->data.array.sentinel != nullptr) ? 1 : 0;
                        uint64_t full_len = len + extra_len_from_sentinel;
                        LLVMValueRef *values = heap::c_allocator.allocate<LLVMValueRef>(full_len);
                        LLVMTypeRef element_type_ref = get_llvm_type(g, type_entry->data.array.child_type);
                        bool make_unnamed_struct = false;
                        for (uint64_t i = 0; i < len; i += 1) {
                            ZigValue *elem_value = &const_val->data.x_array.data.s_none.elements[i];
                            LLVMValueRef val = gen_const_val(g, elem_value, "");
                            values[i] = val;
                            make_unnamed_struct = make_unnamed_struct || is_llvm_value_unnamed_type(g, elem_value->type, val);
                        }
                        if (type_entry->data.array.sentinel != nullptr) {
                            values[len] = gen_const_val(g, type_entry->data.array.sentinel, "");
                        }
                        if (make_unnamed_struct) {
                            return LLVMConstStruct(values, full_len, true);
                        } else {
                            return LLVMConstArray(element_type_ref, values, (unsigned)full_len);
                        }
                    }
                    case ConstArraySpecialBuf: {
                        Buf *buf = const_val->data.x_array.data.s_buf;
                        return LLVMConstString(buf_ptr(buf), (unsigned)buf_len(buf),
                                type_entry->data.array.sentinel == nullptr);
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
                    LLVMValueRef *values = heap::c_allocator.allocate<LLVMValueRef>(len);
                    for (uint64_t i = 0; i < len; i += 1) {
                        ZigValue *elem_value = &const_val->data.x_array.data.s_none.elements[i];
                        values[i] = gen_const_val(g, elem_value, "");
                    }
                    return LLVMConstVector(values, len);
                }
                case ConstArraySpecialBuf: {
                    Buf *buf = const_val->data.x_array.data.s_buf;
                    assert(buf_len(buf) == len);
                    LLVMValueRef *values = heap::c_allocator.allocate<LLVMValueRef>(len);
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
                ZigValue *payload_value = const_val->data.x_union.payload;
                if (payload_value == nullptr || !type_has_bits(g, payload_value->type)) {
                    if (type_entry->data.unionation.gen_tag_index == SIZE_MAX)
                        return LLVMGetUndef(get_llvm_type(g, type_entry));

                    union_value_ref = LLVMGetUndef(union_type_ref);
                    make_unnamed_struct = false;
                } else {
                    uint64_t field_type_bytes = LLVMABISizeOfType(g->target_data_ref,
                            get_llvm_type(g, payload_value->type));
                    uint64_t pad_bytes = type_entry->data.unionation.union_abi_size - field_type_bytes;
                    LLVMValueRef correctly_typed_value = gen_const_val(g, payload_value, "");
                    make_unnamed_struct = is_llvm_value_unnamed_type(g, payload_value->type, correctly_typed_value) ||
                        payload_value->type != type_entry->data.unionation.most_aligned_union_member->type_entry;

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
                    uint64_t expected_sz = LLVMABISizeOfType(g->target_data_ref, get_llvm_type(g, type_entry));
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
            if (const_val->data.x_ptr.special == ConstPtrSpecialFunction &&
                const_val->data.x_ptr.mut != ConstPtrMutComptimeConst) {
                zig_unreachable();
            }
            // Treat it the same as we do for pointers
            return gen_const_val_ptr(g, const_val, name);
        case ZigTypeIdPointer:
            return gen_const_val_ptr(g, const_val, name);
        case ZigTypeIdErrorUnion:
            {
                ZigType *payload_type = type_entry->data.error_union.payload_type;
                ZigType *err_set_type = type_entry->data.error_union.err_set_type;
                if (!type_has_bits(g, payload_type)) {
                    assert(type_has_bits(g, err_set_type));
                    ErrorTableEntry *err_set = const_val->data.x_err_union.error_set->data.x_err_set;
                    uint64_t value = (err_set == nullptr) ? 0 : err_set->value;
                    return LLVMConstInt(get_llvm_type(g, g->err_tag_type), value, false);
                } else if (!type_has_bits(g, err_set_type)) {
                    assert(type_has_bits(g, payload_type));
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
                        ZigValue *payload_val = const_val->data.x_err_union.payload;
                        err_payload_value = gen_const_val(g, payload_val, "");
                        make_unnamed_struct = is_llvm_value_unnamed_type(g, payload_val->type, err_payload_value);
                    }
                    LLVMValueRef fields[3];
                    fields[err_union_err_index] = err_tag_value;
                    fields[err_union_payload_index] = err_payload_value;
                    size_t field_count = 2;
                    if (type_entry->data.error_union.pad_llvm_type != nullptr) {
                        fields[2] = LLVMGetUndef(type_entry->data.error_union.pad_llvm_type);
                        field_count = 3;
                    }
                    if (make_unnamed_struct) {
                        return LLVMConstStruct(fields, field_count, false);
                    } else {
                        return LLVMConstNamedStruct(get_llvm_type(g, type_entry), fields, field_count);
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
        case ZigTypeIdOpaque:
            zig_unreachable();
        case ZigTypeIdFnFrame:
            zig_panic("TODO");
        case ZigTypeIdAnyFrame:
            zig_panic("TODO");
    }
    zig_unreachable();
}

static void render_const_val(CodeGen *g, ZigValue *const_val, const char *name) {
    if (!const_val->llvm_value)
        const_val->llvm_value = gen_const_val(g, const_val, name);

    if (const_val->llvm_global)
        LLVMSetInitializer(const_val->llvm_global, const_val->llvm_value);
}

static void render_const_val_global(CodeGen *g, ZigValue *const_val, const char *name) {
    if (!const_val->llvm_global) {
        LLVMTypeRef type_ref = const_val->llvm_value ?
            LLVMTypeOf(const_val->llvm_value) : get_llvm_type(g, const_val->type);
        LLVMValueRef global_value = LLVMAddGlobal(g->module, type_ref, name);
        LLVMSetLinkage(global_value, (name == nullptr) ? LLVMPrivateLinkage : LLVMInternalLinkage);
        LLVMSetGlobalConstant(global_value, true);
        LLVMSetUnnamedAddr(global_value, true);
        LLVMSetAlignment(global_value, (const_val->llvm_align == 0) ?
                get_abi_alignment(g, const_val->type) : const_val->llvm_align);

        const_val->llvm_global = global_value;
    }

    if (const_val->llvm_value)
        LLVMSetInitializer(const_val->llvm_global, const_val->llvm_value);
}

static void generate_error_name_table(CodeGen *g) {
    if (g->err_name_table != nullptr || !g->generate_error_name_table || g->errors_by_index.length == 1) {
        return;
    }

    assert(g->errors_by_index.length > 0);

    ZigType *u8_ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0, false);
    ZigType *str_type = get_slice_type(g, u8_ptr_type);

    LLVMValueRef *values = heap::c_allocator.allocate<LLVMValueRef>(g->errors_by_index.length);
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
            get_mangled_name(g, buf_ptr(buf_create_from_str("__zig_err_name_table"))));
    LLVMSetInitializer(g->err_name_table, err_name_table_init);
    LLVMSetLinkage(g->err_name_table, LLVMPrivateLinkage);
    LLVMSetGlobalConstant(g->err_name_table, true);
    LLVMSetUnnamedAddr(g->err_name_table, true);
    LLVMSetAlignment(g->err_name_table, LLVMABIAlignmentOfType(g->target_data_ref, LLVMTypeOf(err_name_table_init)));
}

static void build_all_basic_blocks(CodeGen *g, ZigFn *fn) {
    IrExecutableGen *executable = &fn->analyzed_executable;
    assert(executable->basic_block_list.length > 0);
    LLVMValueRef fn_val = fn_llvm_value(g, fn);
    LLVMBasicBlockRef first_bb = nullptr;
    if (fn_is_async(fn)) {
        first_bb = LLVMAppendBasicBlock(fn_val, "AsyncSwitch");
        g->cur_preamble_llvm_block = first_bb;
    }
    for (size_t block_i = 0; block_i < executable->basic_block_list.length; block_i += 1) {
        IrBasicBlockGen *bb = executable->basic_block_list.at(block_i);
        bb->llvm_block = LLVMAppendBasicBlock(fn_val, bb->name_hint);
    }
    if (first_bb == nullptr) {
        first_bb = executable->basic_block_list.at(0)->llvm_block;
    }
    LLVMPositionBuilderAtEnd(g->builder, first_bb);
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
    ZigLLVMCreateGlobalVariable(g->dbuilder, get_di_scope(g, var->parent_scope), var->name,
        var->name, import->data.structure.root_struct->di_file,
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
    Error err;
    assert(!g->errors.length);

    generate_error_name_table(g);

    // Generate module level variables
    for (size_t i = 0; i < g->global_vars.length; i += 1) {
        TldVar *tld_var = g->global_vars.at(i);
        ZigVar *var = tld_var->var;

        if (var->var_type->id == ZigTypeIdComptimeFloat) {
            // Generate debug info for it but that's it.
            ZigValue *const_val = var->const_value;
            assert(const_val->special != ConstValSpecialRuntime);
            if ((err = ir_resolve_lazy(g, var->decl_node, const_val)))
                zig_unreachable();
            if (const_val->type != var->var_type) {
                zig_panic("TODO debug info for var with ptr casted value");
            }
            ZigType *var_type = g->builtin_types.entry_f128;
            ZigValue coerced_value = {};
            coerced_value.special = ConstValSpecialStatic;
            coerced_value.type = var_type;
            coerced_value.data.x_f128 = bigfloat_to_f128(&const_val->data.x_bigfloat);
            LLVMValueRef init_val = gen_const_val(g, &coerced_value, "");
            gen_global_var(g, var, init_val, var_type);
            continue;
        }

        if (var->var_type->id == ZigTypeIdComptimeInt) {
            // Generate debug info for it but that's it.
            ZigValue *const_val = var->const_value;
            assert(const_val->special != ConstValSpecialRuntime);
            if ((err = ir_resolve_lazy(g, var->decl_node, const_val)))
                zig_unreachable();
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

        if (!type_has_bits(g, var->var_type))
            continue;

        assert(var->decl_node);

        GlobalLinkageId linkage;
        const char *unmangled_name = var->name;
        const char *symbol_name;
        if (var->export_list.length == 0) {
            if (var->decl_node->data.variable_declaration.is_extern) {
                symbol_name = unmangled_name;
                linkage = GlobalLinkageIdStrong;
            } else {
                symbol_name = get_mangled_name(g, unmangled_name);
                linkage = GlobalLinkageIdInternal;
            }
        } else {
            GlobalExport *global_export = &var->export_list.items[0];
            symbol_name = buf_ptr(&global_export->name);
            linkage = global_export->linkage;
        }

        LLVMValueRef global_value;
        bool externally_initialized = var->decl_node->data.variable_declaration.expr == nullptr;
        if (externally_initialized) {
            LLVMValueRef existing_llvm_var = LLVMGetNamedGlobal(g->module, symbol_name);
            if (existing_llvm_var) {
                global_value = LLVMConstBitCast(existing_llvm_var,
                        LLVMPointerType(get_llvm_type(g, var->var_type), 0));
            } else {
                global_value = LLVMAddGlobal(g->module, get_llvm_type(g, var->var_type), symbol_name);
                // TODO debug info for the extern variable

                LLVMSetLinkage(global_value, to_llvm_linkage(linkage));
                maybe_import_dll(g, global_value, GlobalLinkageIdStrong);
                LLVMSetAlignment(global_value, var->align_bytes);
                LLVMSetGlobalConstant(global_value, var->gen_is_const);
                set_global_tls(g, var, global_value);
            }
        } else {
            bool exported = (linkage != GlobalLinkageIdInternal);
            render_const_val(g, var->const_value, symbol_name);
            render_const_val_global(g, var->const_value, symbol_name);
            global_value = var->const_value->llvm_global;

            if (exported) {
                LLVMSetLinkage(global_value, to_llvm_linkage(linkage));
                maybe_export_dll(g, global_value, GlobalLinkageIdStrong);
            }
            if (var->section_name) {
                LLVMSetSection(global_value, buf_ptr(var->section_name));
            }
            LLVMSetAlignment(global_value, var->align_bytes);

            // TODO debug info for function pointers
            // Here we use const_value->type because that's the type of the llvm global,
            // which we const ptr cast upon use to whatever it needs to be.
            if (var->gen_is_const && var->const_value->type->id != ZigTypeIdFn) {
                gen_global_var(g, var, var->const_value->llvm_value, var->const_value->type);
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
    stage2_progress_update_node(g->sub_progress_node, 0, g->fn_defs.length);
    for (size_t fn_i = 0; fn_i < g->fn_defs.length; fn_i += 1) {
        ZigFn *fn_table_entry = g->fn_defs.at(fn_i);
        Stage2ProgressNode *fn_prog_node = stage2_progress_start(g->sub_progress_node,
                buf_ptr(&fn_table_entry->symbol_name), buf_len(&fn_table_entry->symbol_name), 0);

        FnTypeId *fn_type_id = &fn_table_entry->type_entry->data.fn.fn_type_id;
        CallingConvention cc = fn_type_id->cc;
        bool is_c_abi = !calling_convention_allows_zig_types(cc);
        bool want_sret = want_first_arg_sret(g, fn_type_id);

        LLVMValueRef fn = fn_llvm_value(g, fn_table_entry);
        g->cur_fn = fn_table_entry;
        g->cur_fn_val = fn;

        build_all_basic_blocks(g, fn_table_entry);
        clear_debug_source_node(g);

        bool is_async = fn_is_async(fn_table_entry);

        if (is_async) {
            g->cur_frame_ptr = LLVMGetParam(fn, 0);
        } else {
            if (want_sret) {
                g->cur_ret_ptr = LLVMGetParam(fn, 0);
            } else if (type_has_bits(g, fn_type_id->return_type)) {
                g->cur_ret_ptr = build_alloca(g, fn_type_id->return_type, "result", 0);
                // TODO add debug info variable for this
            } else {
                g->cur_ret_ptr = nullptr;
            }
        }

        uint32_t err_ret_trace_arg_index = get_err_ret_trace_arg_index(g, fn_table_entry);
        bool have_err_ret_trace_arg = err_ret_trace_arg_index != UINT32_MAX;
        if (have_err_ret_trace_arg) {
            g->cur_err_ret_trace_val_arg = LLVMGetParam(fn, err_ret_trace_arg_index);
        } else {
            g->cur_err_ret_trace_val_arg = nullptr;
        }

        // error return tracing setup
        bool have_err_ret_trace_stack = g->have_err_ret_tracing && fn_table_entry->calls_or_awaits_errorable_fn &&
            !is_async && !have_err_ret_trace_arg;
        LLVMValueRef err_ret_array_val = nullptr;
        if (have_err_ret_trace_stack) {
            ZigType *array_type = get_array_type(g, g->builtin_types.entry_usize, stack_trace_ptr_count, nullptr);
            err_ret_array_val = build_alloca(g, array_type, "error_return_trace_addresses", get_abi_alignment(g, array_type));

            (void)get_llvm_type(g, get_stack_trace_type(g));
            g->cur_err_ret_trace_val_stack = build_alloca(g, get_stack_trace_type(g), "error_return_trace",
                    get_abi_alignment(g, g->stack_trace_type));
        } else {
            g->cur_err_ret_trace_val_stack = nullptr;
        }

        if (!is_async) {
            // allocate async frames for nosuspend calls & awaits to async functions
            ZigType *largest_call_frame_type = nullptr;
            IrInstGen *all_calls_alloca = ir_create_alloca(g, &fn_table_entry->fndef_scope->base,
                    fn_table_entry->body_node, fn_table_entry, g->builtin_types.entry_void, "@async_call_frame");
            for (size_t i = 0; i < fn_table_entry->call_list.length; i += 1) {
                IrInstGenCall *call = fn_table_entry->call_list.at(i);
                if (call->fn_entry == nullptr)
                    continue;
                if (!fn_is_async(call->fn_entry))
                    continue;
                if (call->modifier != CallModifierNoSuspend)
                    continue;
                if (call->frame_result_loc != nullptr)
                    continue;
                ZigType *callee_frame_type = get_fn_frame_type(g, call->fn_entry);
                if (largest_call_frame_type == nullptr ||
                    callee_frame_type->abi_size > largest_call_frame_type->abi_size)
                {
                    largest_call_frame_type = callee_frame_type;
                }
                call->frame_result_loc = all_calls_alloca;
            }
            if (largest_call_frame_type != nullptr) {
                all_calls_alloca->value->type = get_pointer_to_type(g, largest_call_frame_type, false);
            }
            // allocate temporary stack data
            for (size_t alloca_i = 0; alloca_i < fn_table_entry->alloca_gen_list.length; alloca_i += 1) {
                IrInstGenAlloca *instruction = fn_table_entry->alloca_gen_list.at(alloca_i);
                ZigType *ptr_type = instruction->base.value->type;
                assert(ptr_type->id == ZigTypeIdPointer);
                ZigType *child_type = ptr_type->data.pointer.child_type;
                if (type_resolve(g, child_type, ResolveStatusSizeKnown))
                    zig_unreachable();
                if (!type_has_bits(g, child_type))
                    continue;
                if (instruction->base.base.ref_count == 0)
                    continue;
                if (instruction->base.value->special != ConstValSpecialRuntime) {
                    if (const_ptr_pointee(nullptr, g, instruction->base.value, nullptr)->special !=
                            ConstValSpecialRuntime)
                    {
                        continue;
                    }
                }
                if (type_resolve(g, child_type, ResolveStatusLLVMFull))
                    zig_unreachable();
                instruction->base.llvm_value = build_alloca(g, child_type, instruction->name_hint,
                        get_ptr_align(g, ptr_type));
            }
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

            if (!type_has_bits(g, var->var_type)) {
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
                        var->name, import->data.structure.root_struct->di_file, (unsigned)(var->decl_node->line + 1),
                        get_llvm_di_type(g, var->var_type), !g->strip_debug_symbols, 0);

            } else if (is_c_abi) {
                fn_walk_var.data.vars.var = var;
                iter_function_params_c_abi(g, fn_table_entry->type_entry, &fn_walk_var, var->src_arg_index);
            } else if (!is_async) {
                ZigType *gen_type;
                FnGenParamInfo *gen_info = &fn_table_entry->type_entry->data.fn.gen_param_info[var->src_arg_index];
                assert(gen_info->gen_index != SIZE_MAX);

                if (handle_is_ptr(g, var->var_type)) {
                    if (gen_info->is_byval) {
                        gen_type = var->var_type;
                    } else {
                        gen_type = gen_info->type;
                    }
                    var->value_ref = LLVMGetParam(fn, gen_info->gen_index);
                } else {
                    gen_type = var->var_type;
                    var->value_ref = build_alloca(g, var->var_type, var->name, var->align_bytes);
                }
                if (var->decl_node) {
                    var->di_loc_var = ZigLLVMCreateParameterVariable(g->dbuilder, get_di_scope(g, var->parent_scope),
                        var->name, import->data.structure.root_struct->di_file,
                        (unsigned)(var->decl_node->line + 1),
                        get_llvm_di_type(g, gen_type), !g->strip_debug_symbols, 0, (unsigned)(gen_info->gen_index+1));
                }

            }
        }

        // finishing error return trace setup. we have to do this after all the allocas.
        if (have_err_ret_trace_stack) {
            ZigType *usize = g->builtin_types.entry_usize;
            size_t index_field_index = g->stack_trace_type->data.structure.fields[0]->gen_index;
            LLVMValueRef index_field_ptr = LLVMBuildStructGEP(g->builder, g->cur_err_ret_trace_val_stack, (unsigned)index_field_index, "");
            gen_store_untyped(g, LLVMConstNull(usize->llvm_type), index_field_ptr, 0, false);

            size_t addresses_field_index = g->stack_trace_type->data.structure.fields[1]->gen_index;
            LLVMValueRef addresses_field_ptr = LLVMBuildStructGEP(g->builder, g->cur_err_ret_trace_val_stack, (unsigned)addresses_field_index, "");

            ZigType *slice_type = g->stack_trace_type->data.structure.fields[1]->type_entry;
            size_t ptr_field_index = slice_type->data.structure.fields[slice_ptr_index]->gen_index;
            LLVMValueRef ptr_field_ptr = LLVMBuildStructGEP(g->builder, addresses_field_ptr, (unsigned)ptr_field_index, "");
            LLVMValueRef zero = LLVMConstNull(usize->llvm_type);
            LLVMValueRef indices[] = {zero, zero};
            LLVMValueRef err_ret_array_val_elem0_ptr = LLVMBuildInBoundsGEP(g->builder, err_ret_array_val,
                    indices, 2, "");
            ZigType *ptr_ptr_usize_type = get_pointer_to_type(g, get_pointer_to_type(g, usize, false), false);
            gen_store(g, err_ret_array_val_elem0_ptr, ptr_field_ptr, ptr_ptr_usize_type);

            size_t len_field_index = slice_type->data.structure.fields[slice_len_index]->gen_index;
            LLVMValueRef len_field_ptr = LLVMBuildStructGEP(g->builder, addresses_field_ptr, (unsigned)len_field_index, "");
            gen_store(g, LLVMConstInt(usize->llvm_type, stack_trace_ptr_count, false), len_field_ptr, get_pointer_to_type(g, usize, false));
        }

        if (is_async) {
            (void)get_llvm_type(g, fn_table_entry->frame_type);
            g->cur_resume_block_count = 0;

            LLVMTypeRef usize_type_ref = g->builtin_types.entry_usize->llvm_type;
            LLVMValueRef size_val = LLVMConstInt(usize_type_ref, fn_table_entry->frame_type->abi_size, false);
            if (g->need_frame_size_prefix_data) {
                ZigLLVMFunctionSetPrefixData(fn_table_entry->llvm_value, size_val);
            }

            if (!g->strip_debug_symbols) {
                AstNode *source_node = fn_table_entry->proto_node;
                ZigLLVMSetCurrentDebugLocation(g->builder, (int)source_node->line + 1,
                        (int)source_node->column + 1, get_di_scope(g, fn_table_entry->child_scope));
            }
            IrExecutableGen *executable = &fn_table_entry->analyzed_executable;
            LLVMBasicBlockRef bad_resume_block = LLVMAppendBasicBlock(g->cur_fn_val, "BadResume");
            LLVMPositionBuilderAtEnd(g->builder, bad_resume_block);
            gen_assertion_scope(g, PanicMsgIdBadResume, fn_table_entry->child_scope);

            LLVMPositionBuilderAtEnd(g->builder, g->cur_preamble_llvm_block);
            render_async_spills(g);
            g->cur_async_awaiter_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr, frame_awaiter_index, "");
            LLVMValueRef resume_index_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr, frame_resume_index, "");
            g->cur_async_resume_index_ptr = resume_index_ptr;

            if (type_has_bits(g, fn_type_id->return_type)) {
                LLVMValueRef cur_ret_ptr_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr, frame_ret_start, "");
                g->cur_ret_ptr = LLVMBuildLoad(g->builder, cur_ret_ptr_ptr, "");
            }
            uint32_t trace_field_index_stack = UINT32_MAX;
            if (codegen_fn_has_err_ret_tracing_stack(g, fn_table_entry, true)) {
                trace_field_index_stack = frame_index_trace_stack(g, fn_table_entry);
                g->cur_err_ret_trace_val_stack = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr,
                        trace_field_index_stack, "");
            }

            LLVMValueRef resume_index = LLVMBuildLoad(g->builder, resume_index_ptr, "");
            LLVMValueRef switch_instr = LLVMBuildSwitch(g->builder, resume_index, bad_resume_block, 4);
            g->cur_async_switch_instr = switch_instr;

            LLVMValueRef zero = LLVMConstNull(usize_type_ref);
            IrBasicBlockGen *entry_block = executable->basic_block_list.at(0);
            LLVMAddCase(switch_instr, zero, entry_block->llvm_block);
            g->cur_resume_block_count += 1;

            {
                LLVMBasicBlockRef bad_not_suspended_bb = LLVMAppendBasicBlock(g->cur_fn_val, "NotSuspended");
                size_t new_block_index = g->cur_resume_block_count;
                g->cur_resume_block_count += 1;
                g->cur_bad_not_suspended_index = LLVMConstInt(usize_type_ref, new_block_index, false);
                LLVMAddCase(g->cur_async_switch_instr, g->cur_bad_not_suspended_index, bad_not_suspended_bb);

                LLVMPositionBuilderAtEnd(g->builder, bad_not_suspended_bb);
                gen_assertion_scope(g, PanicMsgIdResumeNotSuspendedFn, fn_table_entry->child_scope);
            }

            LLVMPositionBuilderAtEnd(g->builder, entry_block->llvm_block);
            LLVMBuildStore(g->builder, g->cur_bad_not_suspended_index, g->cur_async_resume_index_ptr);
            if (trace_field_index_stack != UINT32_MAX) {
                if (codegen_fn_has_err_ret_tracing_arg(g, fn_type_id->return_type)) {
                    LLVMValueRef trace_ptr_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr,
                            frame_index_trace_arg(g, fn_type_id->return_type), "");
                    LLVMValueRef zero_ptr = LLVMConstNull(LLVMGetElementType(LLVMTypeOf(trace_ptr_ptr)));
                    LLVMBuildStore(g->builder, zero_ptr, trace_ptr_ptr);
                }

                LLVMValueRef trace_field_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr,
                        trace_field_index_stack, "");
                LLVMValueRef addrs_field_ptr = LLVMBuildStructGEP(g->builder, g->cur_frame_ptr,
                        trace_field_index_stack + 1, "");

                gen_init_stack_trace(g, trace_field_ptr, addrs_field_ptr);
            }
            render_async_var_decls(g, entry_block->instruction_list.at(0)->base.scope);
        } else {
            // create debug variable declarations for parameters
            // rely on the first variables in the variable_list being parameters.
            FnWalk fn_walk_init = {};
            fn_walk_init.id = FnWalkIdInits;
            fn_walk_init.data.inits.fn = fn_table_entry;
            fn_walk_init.data.inits.llvm_fn = fn;
            fn_walk_init.data.inits.gen_i = gen_i_init;
            walk_function_params(g, fn_table_entry->type_entry, &fn_walk_init);
        }

        ir_render(g, fn_table_entry);

        stage2_progress_end(fn_prog_node);
    }

    assert(!g->errors.length);

    if (buf_len(&g->global_asm) != 0) {
        LLVMSetModuleInlineAsm(g->module, buf_ptr(&g->global_asm));
    }

    while (g->type_resolve_stack.length != 0) {
        ZigType *ty = g->type_resolve_stack.last();
        if (type_resolve(g, ty, ResolveStatusLLVMFull))
            zig_unreachable();
    }

    ZigLLVMDIBuilderFinalize(g->dbuilder);

    if (g->verbose_llvm_ir) {
        fflush(stderr);
        LLVMDumpModule(g->module);
    }

    char *error = nullptr;
    if (LLVMVerifyModule(g->module, LLVMReturnStatusAction, &error)) {
        zig_panic("broken LLVM module found: %s\nThis is a bug in the Zig compiler.", error);
    }
}

static void zig_llvm_emit_output(CodeGen *g) {
    g->pass1_arena->destruct(&heap::c_allocator);
    g->pass1_arena = nullptr;

    bool is_small = g->build_mode == BuildModeSmallRelease;

    char *err_msg = nullptr;
    const char *asm_filename = nullptr;
    const char *bin_filename = nullptr;
    const char *llvm_ir_filename = nullptr;

    if (g->emit_bin) bin_filename = buf_ptr(&g->o_file_output_path);
    if (g->emit_asm) asm_filename = buf_ptr(&g->asm_file_output_path);
    if (g->emit_llvm_ir) llvm_ir_filename = buf_ptr(&g->llvm_ir_file_output_path);

    // Unfortunately, LLVM shits the bed when we ask for both binary and assembly. So we call the entire
    // pipeline multiple times if this is requested.
    if (asm_filename != nullptr && bin_filename != nullptr) {
        if (ZigLLVMTargetMachineEmitToFile(g->target_machine, g->module, &err_msg, g->build_mode == BuildModeDebug,
            is_small, g->enable_time_report, nullptr, bin_filename, llvm_ir_filename))
        {
            fprintf(stderr, "LLVM failed to emit file: %s\n", err_msg);
            exit(1);
        }
        bin_filename = nullptr;
        llvm_ir_filename = nullptr;
    }

    if (ZigLLVMTargetMachineEmitToFile(g->target_machine, g->module, &err_msg, g->build_mode == BuildModeDebug,
        is_small, g->enable_time_report, asm_filename, bin_filename, llvm_ir_filename))
    {
        fprintf(stderr, "LLVM failed to emit file: %s\n", err_msg);
        exit(1);
    }

    validate_inline_fns(g);

    if (g->emit_bin) {
        g->link_objects.append(&g->o_file_output_path);
        if (g->bundle_compiler_rt && (g->out_type == OutTypeObj || (g->out_type == OutTypeLib && !g->is_dynamic))) {
            zig_link_add_compiler_rt(g, g->sub_progress_node);
        }
    }

    LLVMDisposeModule(g->module);
    g->module = nullptr;
    LLVMDisposeTargetData(g->target_data_ref);
    g->target_data_ref = nullptr;
    LLVMDisposeTargetMachine(g->target_machine);
    g->target_machine = nullptr;
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
        ZigType *entry = new_type_table_entry(ZigTypeIdOpaque);
        buf_init_from_str(&entry->name, "(anytype)");
        g->builtin_types.entry_anytype = entry;
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
                8*LLVMStoreSizeOfType(g->target_data_ref, entry->llvm_type),
                is_signed ? ZigLLVMEncoding_DW_ATE_signed() : ZigLLVMEncoding_DW_ATE_unsigned());
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
                8*LLVMStoreSizeOfType(g->target_data_ref, entry->llvm_type),
                ZigLLVMEncoding_DW_ATE_boolean());
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
                8*LLVMStoreSizeOfType(g->target_data_ref, entry->llvm_type),
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
}

static void define_intern_values(CodeGen *g) {
    {
        auto& value = g->intern.x_undefined;
        value.type = g->builtin_types.entry_undef;
        value.special = ConstValSpecialStatic;
    }
    {
        auto& value = g->intern.x_void;
        value.type = g->builtin_types.entry_void;
        value.special = ConstValSpecialStatic;
    }
    {
        auto& value = g->intern.x_null;
        value.type = g->builtin_types.entry_null;
        value.special = ConstValSpecialStatic;
    }
    {
        auto& value = g->intern.x_unreachable;
        value.type = g->builtin_types.entry_unreachable;
        value.special = ConstValSpecialStatic;
    }
    {
        auto& value = g->intern.zero_byte;
        value.type = g->builtin_types.entry_u8;
        value.special = ConstValSpecialStatic;
        bigint_init_unsigned(&value.data.x_bigint, 0);
    }
}

static BuiltinFnEntry *create_builtin_fn(CodeGen *g, BuiltinFnId id, const char *name, size_t count) {
    BuiltinFnEntry *builtin_fn = heap::c_allocator.create<BuiltinFnEntry>();
    buf_init_from_str(&builtin_fn->name, name);
    builtin_fn->id = id;
    builtin_fn->param_count = count;
    g->builtin_fn_table.put(&builtin_fn->name, builtin_fn);
    return builtin_fn;
}

static void define_builtin_fns(CodeGen *g) {
    create_builtin_fn(g, BuiltinFnIdBreakpoint, "breakpoint", 0);
    create_builtin_fn(g, BuiltinFnIdReturnAddress, "returnAddress", 0);
    create_builtin_fn(g, BuiltinFnIdMemcpy, "memcpy", 3);
    create_builtin_fn(g, BuiltinFnIdMemset, "memset", 3);
    create_builtin_fn(g, BuiltinFnIdSizeof, "sizeOf", 1);
    create_builtin_fn(g, BuiltinFnIdAlignOf, "alignOf", 1);
    create_builtin_fn(g, BuiltinFnIdField, "field", 2);
    create_builtin_fn(g, BuiltinFnIdTypeInfo, "typeInfo", 1);
    create_builtin_fn(g, BuiltinFnIdType, "Type", 1);
    create_builtin_fn(g, BuiltinFnIdHasField, "hasField", 2);
    create_builtin_fn(g, BuiltinFnIdTypeof, "TypeOf", SIZE_MAX);
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
    create_builtin_fn(g, BuiltinFnIdVectorType, "Vector", 2);
    create_builtin_fn(g, BuiltinFnIdShuffle, "shuffle", 4);
    create_builtin_fn(g, BuiltinFnIdSplat, "splat", 2);
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
    create_builtin_fn(g, BuiltinFnIdSqrt, "sqrt", 1);
    create_builtin_fn(g, BuiltinFnIdSin, "sin", 1);
    create_builtin_fn(g, BuiltinFnIdCos, "cos", 1);
    create_builtin_fn(g, BuiltinFnIdExp, "exp", 1);
    create_builtin_fn(g, BuiltinFnIdExp2, "exp2", 1);
    create_builtin_fn(g, BuiltinFnIdLog, "log", 1);
    create_builtin_fn(g, BuiltinFnIdLog2, "log2", 1);
    create_builtin_fn(g, BuiltinFnIdLog10, "log10", 1);
    create_builtin_fn(g, BuiltinFnIdFabs, "fabs", 1);
    create_builtin_fn(g, BuiltinFnIdFloor, "floor", 1);
    create_builtin_fn(g, BuiltinFnIdCeil, "ceil", 1);
    create_builtin_fn(g, BuiltinFnIdTrunc, "trunc", 1);
    create_builtin_fn(g, BuiltinFnIdNearbyInt, "nearbyInt", 1);
    create_builtin_fn(g, BuiltinFnIdRound, "round", 1);
    create_builtin_fn(g, BuiltinFnIdMulAdd, "mulAdd", 4);
    create_builtin_fn(g, BuiltinFnIdAsyncCall, "asyncCall", SIZE_MAX);
    create_builtin_fn(g, BuiltinFnIdShlExact, "shlExact", 2);
    create_builtin_fn(g, BuiltinFnIdShrExact, "shrExact", 2);
    create_builtin_fn(g, BuiltinFnIdSetEvalBranchQuota, "setEvalBranchQuota", 1);
    create_builtin_fn(g, BuiltinFnIdAlignCast, "alignCast", 2);
    create_builtin_fn(g, BuiltinFnIdOpaqueType, "OpaqueType", 0);
    create_builtin_fn(g, BuiltinFnIdSetAlignStack, "setAlignStack", 1);
    create_builtin_fn(g, BuiltinFnIdExport, "export", 2);
    create_builtin_fn(g, BuiltinFnIdErrorReturnTrace, "errorReturnTrace", 0);
    create_builtin_fn(g, BuiltinFnIdAtomicRmw, "atomicRmw", 5);
    create_builtin_fn(g, BuiltinFnIdAtomicLoad, "atomicLoad", 3);
    create_builtin_fn(g, BuiltinFnIdAtomicStore, "atomicStore", 4);
    create_builtin_fn(g, BuiltinFnIdErrSetCast, "errSetCast", 2);
    create_builtin_fn(g, BuiltinFnIdThis, "This", 0);
    create_builtin_fn(g, BuiltinFnIdHasDecl, "hasDecl", 2);
    create_builtin_fn(g, BuiltinFnIdUnionInit, "unionInit", 3);
    create_builtin_fn(g, BuiltinFnIdFrameHandle, "frame", 0);
    create_builtin_fn(g, BuiltinFnIdFrameType, "Frame", 1);
    create_builtin_fn(g, BuiltinFnIdFrameAddress, "frameAddress", 0);
    create_builtin_fn(g, BuiltinFnIdFrameSize, "frameSize", 1);
    create_builtin_fn(g, BuiltinFnIdAs, "as", 2);
    create_builtin_fn(g, BuiltinFnIdCall, "call", 3);
    create_builtin_fn(g, BuiltinFnIdBitSizeof, "bitSizeOf", 1);
    create_builtin_fn(g, BuiltinFnIdWasmMemorySize, "wasmMemorySize", 1);
    create_builtin_fn(g, BuiltinFnIdWasmMemoryGrow, "wasmMemoryGrow", 2);
    create_builtin_fn(g, BuiltinFnIdSrc, "src", 0);
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
    if (target_os_requires_libc(g->zig_target->os))
        return true;
    if (g->libc_link_lib != nullptr && target_is_glibc(g->zig_target))
        return true;
    // If there are no dynamic libraries then we can disable dynamic linking.
    for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(i);
        if (target_is_libc_lib_name(g->zig_target, buf_ptr(link_lib->name)))
            continue;
        if (target_is_libcpp_lib_name(g->zig_target, buf_ptr(link_lib->name)))
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

static bool detect_sanitize_c(CodeGen *g) {
    if (!target_supports_sanitize_c(g->zig_target))
        return false;
    switch (g->want_sanitize_c) {
        case WantCSanitizeDisabled:
            return false;
        case WantCSanitizeEnabled:
            return true;
        case WantCSanitizeAuto:
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
        if (g->have_c_main || g->is_test_build || g->have_winmain_crt_startup || g->have_wwinmain_crt_startup)
            return TargetSubsystemConsole;
        if (g->have_winmain || g->have_wwinmain)
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

static LLVMCodeModel to_llvm_code_model(CodeGen *g) {
        switch (g->code_model) {
            case CodeModelDefault:
                return LLVMCodeModelDefault;
            case CodeModelTiny:
                return LLVMCodeModelTiny;
            case CodeModelSmall:
                return LLVMCodeModelSmall;
            case CodeModelKernel:
                return LLVMCodeModelKernel;
            case CodeModelMedium:
                return LLVMCodeModelMedium;
            case CodeModelLarge:
                return LLVMCodeModelLarge;
        }

        zig_unreachable();
}

Buf *codegen_generate_builtin_source(CodeGen *g) {
    g->have_dynamic_link = detect_dynamic_link(g);
    g->have_pic = detect_pic(g);
    g->have_stack_probing = detect_stack_probing(g);
    g->have_sanitize_c = detect_sanitize_c(g);
    g->is_single_threaded = detect_single_threaded(g);
    g->have_err_ret_tracing = detect_err_ret_tracing(g);

    Buf *contents = buf_alloc();
    buf_appendf(contents, "usingnamespace @import(\"std\").builtin;\n\n");

    const char *cur_os = nullptr;
    {
        uint32_t field_count = (uint32_t)target_os_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            Os os_type = target_os_enum(i);
            const char *name = target_os_name(os_type);

            if (os_type == g->zig_target->os) {
                g->target_os_index = i;
                cur_os = name;
            }
        }
    }
    assert(cur_os != nullptr);

    const char *cur_arch = nullptr;
    {
        uint32_t field_count = (uint32_t)target_arch_count();
        for (uint32_t arch_i = 0; arch_i < field_count; arch_i += 1) {
            ZigLLVM_ArchType arch = target_arch_enum(arch_i);
            const char *arch_name = target_arch_name(arch);
            if (arch == g->zig_target->arch) {
                g->target_arch_index = arch_i;
                cur_arch = arch_name;
            }
        }
    }
    assert(cur_arch != nullptr);

    const char *cur_abi = nullptr;
    {
        uint32_t field_count = (uint32_t)target_abi_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            ZigLLVM_EnvironmentType abi = target_abi_enum(i);
            const char *name = target_abi_name(abi);

            if (abi == g->zig_target->abi) {
                g->target_abi_index = i;
                cur_abi = name;
            }
        }
    }
    assert(cur_abi != nullptr);

    const char *cur_obj_fmt = nullptr;
    {
        uint32_t field_count = (uint32_t)target_oformat_count();
        for (uint32_t i = 0; i < field_count; i += 1) {
            ZigLLVM_ObjectFormatType oformat = target_oformat_enum(i);
            const char *name = target_oformat_name(oformat);

            ZigLLVM_ObjectFormatType target_oformat = target_object_format(g->zig_target);
            if (oformat == target_oformat) {
                g->target_oformat_index = i;
                cur_obj_fmt = name;
            }
        }

    }
    assert(cur_obj_fmt != nullptr);

    // If any of these asserts trip then you need to either fix the internal compiler enum
    // or the corresponding one in std.Target or std.builtin.
    static_assert(ContainerLayoutAuto == 0, "");
    static_assert(ContainerLayoutExtern == 1, "");
    static_assert(ContainerLayoutPacked == 2, "");

    static_assert(CallingConventionUnspecified == 0, "");
    static_assert(CallingConventionC == 1, "");
    static_assert(CallingConventionCold == 2, "");
    static_assert(CallingConventionNaked == 3, "");
    static_assert(CallingConventionAsync == 4, "");
    static_assert(CallingConventionInterrupt == 5, "");
    static_assert(CallingConventionSignal == 6, "");
    static_assert(CallingConventionStdcall == 7, "");
    static_assert(CallingConventionFastcall == 8, "");
    static_assert(CallingConventionVectorcall == 9, "");
    static_assert(CallingConventionThiscall == 10, "");
    static_assert(CallingConventionAPCS == 11, "");
    static_assert(CallingConventionAAPCS == 12, "");
    static_assert(CallingConventionAAPCSVFP == 13, "");

    static_assert(FnInlineAuto == 0, "");
    static_assert(FnInlineAlways == 1, "");
    static_assert(FnInlineNever == 2, "");

    static_assert(BuiltinPtrSizeOne == 0, "");
    static_assert(BuiltinPtrSizeMany == 1, "");
    static_assert(BuiltinPtrSizeSlice == 2, "");
    static_assert(BuiltinPtrSizeC == 3, "");

    static_assert(TargetSubsystemConsole == 0, "");
    static_assert(TargetSubsystemWindows == 1, "");
    static_assert(TargetSubsystemPosix == 2, "");
    static_assert(TargetSubsystemNative == 3, "");
    static_assert(TargetSubsystemEfiApplication == 4, "");
    static_assert(TargetSubsystemEfiBootServiceDriver == 5, "");
    static_assert(TargetSubsystemEfiRom == 6, "");
    static_assert(TargetSubsystemEfiRuntimeDriver == 7, "");
    {
        const char *endian_str = g->is_big_endian ? "Endian.Big" : "Endian.Little";
        buf_appendf(contents, "pub const endian = %s;\n", endian_str);
    }
    const char *out_type = nullptr;
    switch (g->out_type) {
        case OutTypeExe:
            out_type = "Exe";
            break;
        case OutTypeLib:
            out_type = "Lib";
            break;
        case OutTypeObj:
        case OutTypeUnknown: // This happens when running the `zig builtin` command.
            out_type = "Obj";
            break;
    }
    buf_appendf(contents, "pub const output_mode = OutputMode.%s;\n", out_type);
    const char *link_type = g->have_dynamic_link ? "Dynamic" : "Static";
    buf_appendf(contents, "pub const link_mode = LinkMode.%s;\n", link_type);
    buf_appendf(contents, "pub const is_test = %s;\n", bool_to_str(g->is_test_build));
    buf_appendf(contents, "pub const single_threaded = %s;\n", bool_to_str(g->is_single_threaded));
    buf_append_str(contents, "/// Deprecated: use `std.Target.cpu.arch`\n");
    buf_appendf(contents, "pub const arch = Arch.%s;\n", cur_arch);
    buf_appendf(contents, "pub const abi = Abi.%s;\n", cur_abi);
    {
        buf_append_str(contents, "pub const cpu: Cpu = ");
        if (g->zig_target->cpu_builtin_str != nullptr) {
            buf_append_str(contents, g->zig_target->cpu_builtin_str);
        } else {
            buf_appendf(contents, "Target.Cpu.baseline(.%s);\n", cur_arch);
        }
    }
    {
        buf_append_str(contents, "pub const os = ");
        if (g->zig_target->os_builtin_str != nullptr) {
            buf_append_str(contents, g->zig_target->os_builtin_str);
        } else {
            buf_appendf(contents, "Target.Os.defaultVersionRange(.%s);\n", cur_os);
        }
    }
    buf_appendf(contents, "pub const object_format = ObjectFormat.%s;\n", cur_obj_fmt);
    buf_appendf(contents, "pub const mode = %s;\n", build_mode_to_str(g->build_mode));
    buf_appendf(contents, "pub const link_libc = %s;\n", bool_to_str(g->libc_link_lib != nullptr));
    buf_appendf(contents, "pub const link_libcpp = %s;\n", bool_to_str(g->libcpp_link_lib != nullptr));
    buf_appendf(contents, "pub const have_error_return_tracing = %s;\n", bool_to_str(g->have_err_ret_tracing));
    buf_appendf(contents, "pub const valgrind_support = %s;\n", bool_to_str(want_valgrind_support(g)));
    buf_appendf(contents, "pub const position_independent_code = %s;\n", bool_to_str(g->have_pic));
    buf_appendf(contents, "pub const strip_debug_info = %s;\n", bool_to_str(g->strip_debug_symbols));

    {
        const char *code_model;
        switch (g->code_model) {
        case CodeModelDefault:
            code_model = "default";
            break;
        case CodeModelTiny:
            code_model = "tiny";
            break;
        case CodeModelSmall:
            code_model = "small";
            break;
        case CodeModelKernel:
            code_model = "kernel";
            break;
        case CodeModelMedium:
            code_model = "medium";
            break;
        case CodeModelLarge:
            code_model = "large";
            break;
        default:
            zig_unreachable();
        }

        buf_appendf(contents, "pub const code_model = CodeModel.%s;\n", code_model);
    }

    {
        TargetSubsystem detected_subsystem = detect_subsystem(g);
        if (detected_subsystem != TargetSubsystemAuto) {
            buf_appendf(contents, "pub const explicit_subsystem = SubSystem.%s;\n", subsystem_to_str(detected_subsystem));
        }
    }

    if (g->is_test_build) {
        buf_appendf(contents,
            "pub var test_functions: []TestFn = undefined; // overwritten later\n"
        );

        buf_appendf(contents, "pub const test_io_mode = %s;\n",
            g->test_is_evented ? ".evented" : ".blocking");
    }

    return contents;
}

static ZigPackage *create_test_runner_pkg(CodeGen *g) {
    return codegen_create_package(g, buf_ptr(g->zig_std_special_dir), "test_runner.zig", "std.special");
}

static Error define_builtin_compile_vars(CodeGen *g) {
    if (g->std_package == nullptr)
        return ErrorNone;

    Error err;

    Buf *manifest_dir = buf_alloc();
    os_path_join(get_global_cache_dir(), buf_create_from_str("builtin"), manifest_dir);

    CacheHash cache_hash;
    cache_init(&cache_hash, manifest_dir);

    Buf *compiler_id;
    if ((err = get_compiler_id(&compiler_id)))
        return err;

    // Only a few things affect builtin.zig
    cache_buf(&cache_hash, compiler_id);
    cache_int(&cache_hash, g->build_mode);
    cache_bool(&cache_hash, g->strip_debug_symbols);
    cache_int(&cache_hash, g->out_type);
    cache_bool(&cache_hash, detect_dynamic_link(g));
    cache_bool(&cache_hash, g->is_test_build);
    cache_bool(&cache_hash, g->is_single_threaded);
    cache_bool(&cache_hash, g->test_is_evented);
    cache_int(&cache_hash, g->code_model);
    cache_int(&cache_hash, g->zig_target->is_native_os);
    cache_int(&cache_hash, g->zig_target->is_native_cpu);
    cache_int(&cache_hash, g->zig_target->arch);
    cache_int(&cache_hash, g->zig_target->vendor);
    cache_int(&cache_hash, g->zig_target->os);
    cache_int(&cache_hash, g->zig_target->abi);
    if (g->zig_target->cache_hash != nullptr) {
        cache_mem(&cache_hash, g->zig_target->cache_hash, g->zig_target->cache_hash_len);
    }
    if (g->zig_target->glibc_or_darwin_version != nullptr) {
        cache_int(&cache_hash, g->zig_target->glibc_or_darwin_version->major);
        cache_int(&cache_hash, g->zig_target->glibc_or_darwin_version->minor);
        cache_int(&cache_hash, g->zig_target->glibc_or_darwin_version->patch);
    }
    cache_bool(&cache_hash, g->have_err_ret_tracing);
    cache_bool(&cache_hash, g->libc_link_lib != nullptr);
    cache_bool(&cache_hash, g->libcpp_link_lib != nullptr);
    cache_bool(&cache_hash, g->valgrind_support);
    cache_bool(&cache_hash, g->link_eh_frame_hdr);
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

    assert(g->main_pkg);
    assert(g->std_package);
    g->compile_var_package = new_package(buf_ptr(this_dir), builtin_zig_basename, "builtin");
    if (g->is_test_build) {
        if (g->test_runner_package == nullptr) {
            g->test_runner_package = create_test_runner_pkg(g);
        }
        g->root_pkg = g->test_runner_package;
    } else {
        g->root_pkg = g->main_pkg;
    }
    g->compile_var_package->package_table.put(buf_create_from_str("std"), g->std_package);
    g->main_pkg->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    g->main_pkg->package_table.put(buf_create_from_str("root"), g->root_pkg);
    g->std_package->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    g->std_package->package_table.put(buf_create_from_str("std"), g->std_package);
    g->std_package->package_table.put(buf_create_from_str("root"), g->root_pkg);
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
    g->have_sanitize_c = detect_sanitize_c(g);
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

    const char *target_specific_cpu_args = "";
    const char *target_specific_features = "";

    if (g->zig_target->is_native_cpu) {
        target_specific_cpu_args = ZigLLVMGetHostCPUName();
        target_specific_features = ZigLLVMGetNativeFeatures();
    }

    // Override CPU and features if defined by user.
    if (g->zig_target->llvm_cpu_name != nullptr) {
        target_specific_cpu_args = g->zig_target->llvm_cpu_name;
    }
    if (g->zig_target->llvm_cpu_features != nullptr) {
        target_specific_features = g->zig_target->llvm_cpu_features;
    }
    if (g->verbose_llvm_cpu_features) {
        fprintf(stderr, "name=%s triple=%s\n", buf_ptr(g->root_out_name), buf_ptr(&g->llvm_triple_str));
        fprintf(stderr, "name=%s target_specific_cpu_args=%s\n", buf_ptr(g->root_out_name), target_specific_cpu_args);
        fprintf(stderr, "name=%s target_specific_features=%s\n", buf_ptr(g->root_out_name), target_specific_features);
    }

    // TODO handle float ABI better- it should depend on the ABI portion of std.Target
    ZigLLVMABIType float_abi = ZigLLVMABITypeDefault;

    // TODO a way to override this as part of std.Target ABI?
    const char *abi_name = nullptr;
    if (target_is_riscv(g->zig_target)) {
        // RISC-V Linux defaults to ilp32d/lp64d
        if (g->zig_target->os == OsLinux) {
            abi_name = (g->zig_target->arch == ZigLLVM_riscv32) ? "ilp32d" : "lp64d";
        } else {
            abi_name = (g->zig_target->arch == ZigLLVM_riscv32) ? "ilp32" : "lp64";
        }
    }

    g->target_machine = ZigLLVMCreateTargetMachine(target_ref, buf_ptr(&g->llvm_triple_str),
            target_specific_cpu_args, target_specific_features, opt_level, reloc_mode,
            to_llvm_code_model(g), g->function_sections, float_abi, abi_name);

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

    // For macOS stack traces, we want to avoid having to parse the compilation unit debug
    // info. As long as each debug info file has a path independent of the compilation unit
    // directory (DW_AT_comp_dir), then we never have to look at the compilation unit debug
    // info. If we provide an absolute path to LLVM here for the compilation unit debug info,
    // LLVM will emit DWARF info that depends on DW_AT_comp_dir. To avoid this, we pass "."
    // for the compilation unit directory. This forces each debug file to have a directory
    // rather than be relative to DW_AT_comp_dir. According to DWARF 5, debug files will
    // no longer reference DW_AT_comp_dir, for the purpose of being able to support the
    // common practice of stripping all but the line number sections from an executable.
    const char *compile_unit_dir = target_os_is_darwin(g->zig_target->os) ? "." :
        buf_ptr(&g->main_pkg->root_src_dir);

    ZigLLVMDIFile *compile_unit_file = ZigLLVMCreateFile(g->dbuilder, buf_ptr(g->root_out_name),
            compile_unit_dir);
    g->compile_unit = ZigLLVMCreateCompileUnit(g->dbuilder, ZigLLVMLang_DW_LANG_C99(),
            compile_unit_file, buf_ptr(producer), is_optimized, flags, runtime_version,
            "", 0, !g->strip_debug_symbols);

    // This is for debug stuff that doesn't have a real file.
    g->dummy_di_file = nullptr;

    define_builtin_types(g);
    define_intern_values(g);

    IrInstGen *sentinel_instructions = heap::c_allocator.allocate<IrInstGen>(2);
    g->invalid_inst_gen = &sentinel_instructions[0];
    g->invalid_inst_gen->value = g->pass1_arena->create<ZigValue>();
    g->invalid_inst_gen->value->type = g->builtin_types.entry_invalid;

    g->unreach_instruction = &sentinel_instructions[1];
    g->unreach_instruction->value = g->pass1_arena->create<ZigValue>();
    g->unreach_instruction->value->type = g->builtin_types.entry_unreachable;

    g->invalid_inst_src = heap::c_allocator.create<IrInstSrc>();

    define_builtin_fns(g);
    Error err;
    if ((err = define_builtin_compile_vars(g))) {
        fprintf(stderr, "Unable to create builtin.zig: %s\n", err_str(err));
        exit(1);
    }
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
        g->libc_include_dir_list = heap::c_allocator.allocate<const char*>(g->libc_include_dir_len);
        g->libc_include_dir_list[0] = buf_ptr(arch_include_dir);
        g->libc_include_dir_list[1] = buf_ptr(generic_include_dir);
        g->libc_include_dir_list[2] = buf_ptr(arch_os_include_dir);
        g->libc_include_dir_list[3] = buf_ptr(generic_os_include_dir);
        return;
    }

    if (g->zig_target->is_native_os) {
        g->libc = heap::c_allocator.create<Stage2LibCInstallation>();

        if ((err = stage2_libc_find_native(g->libc))) {
            fprintf(stderr,
                "Unable to link against libc: Unable to find libc installation: %s\n"
                "See `zig libc --help` for more details.\n", err_str(err));
            exit(1);
        }

        bool want_sys_dir = !mem_eql_mem(g->libc->include_dir,     g->libc->include_dir_len,
                                         g->libc->sys_include_dir, g->libc->sys_include_dir_len);
        size_t want_um_and_shared_dirs = (g->zig_target->os == OsWindows) ? 2 : 0;
        size_t dir_count = 1 + want_sys_dir + want_um_and_shared_dirs;
        g->libc_include_dir_len = 0;
        g->libc_include_dir_list = heap::c_allocator.allocate<const char *>(dir_count);

        g->libc_include_dir_list[g->libc_include_dir_len] = buf_ptr(buf_create_from_mem(
                    g->libc->include_dir, g->libc->include_dir_len));
        g->libc_include_dir_len += 1;

        if (want_sys_dir) {
            g->libc_include_dir_list[g->libc_include_dir_len] = buf_ptr(buf_create_from_mem(
                        g->libc->sys_include_dir, g->libc->sys_include_dir_len));
            g->libc_include_dir_len += 1;
        }

        if (want_um_and_shared_dirs != 0) {
            Buf *include_dir_parent = buf_alloc();
            os_path_join(buf_create_from_mem(g->libc->include_dir, g->libc->include_dir_len),
                    buf_create_from_str(".."), include_dir_parent);

            Buf *buff1 = buf_alloc();
            os_path_join(include_dir_parent, buf_create_from_str("um"), buff1);
            g->libc_include_dir_list[g->libc_include_dir_len] = buf_ptr(buff1);
            g->libc_include_dir_len += 1;

            Buf *buff2 = buf_alloc();
            os_path_join(include_dir_parent, buf_create_from_str("shared"), buff2);
            g->libc_include_dir_list[g->libc_include_dir_len] = buf_ptr(buff2);
            g->libc_include_dir_len += 1;
        }
        assert(g->libc_include_dir_len == dir_count);
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
void add_cc_args(CodeGen *g, ZigList<const char *> &args, const char *out_dep_path,
        bool translate_c, FileExt source_kind)
{
    if (translate_c) {
        args.append("-x");
        args.append("c");
    }

    args.append("-nostdinc");
    if (source_kind == FileExtCpp) {
        args.append("-nostdinc++");
    }
    args.append("-fno-spell-checking");

    if (g->function_sections) {
        args.append("-ffunction-sections");
    }

    if (!translate_c) {
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

    for (size_t i = 0; i < g->framework_dirs.length; i += 1) {
        args.append("-iframework");
        args.append(g->framework_dirs.at(i));
    }

    if (g->libcpp_link_lib != nullptr) {
        const char *libcxx_include_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxx" OS_SEP "include",
                buf_ptr(g->zig_lib_dir)));

        const char *libcxxabi_include_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxxabi" OS_SEP "include",
                buf_ptr(g->zig_lib_dir)));

        args.append("-isystem");
        args.append(libcxx_include_path);

        args.append("-isystem");
        args.append(libcxxabi_include_path);

        if (target_abi_is_musl(g->zig_target->abi)) {
            args.append("-D_LIBCPP_HAS_MUSL_LIBC");
        }
        args.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");
        args.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");
    }

    args.append("-target");
    args.append(buf_ptr(&g->llvm_triple_str));

    switch (source_kind) {
        case FileExtC:
        case FileExtCpp:
        case FileExtHeader:
            // According to Rich Felker libc headers are supposed to go before C language headers.
            // However as noted by @dimenus, appending libc headers before c_headers breaks intrinsics
            // and other compiler specific items.
            args.append("-isystem");
            args.append(buf_ptr(g->zig_c_headers_dir));

            for (size_t i = 0; i < g->libc_include_dir_len; i += 1) {
                const char *include_dir = g->libc_include_dir_list[i];
                args.append("-isystem");
                args.append(include_dir);
            }

            if (g->zig_target->llvm_cpu_name != nullptr) {
                args.append("-Xclang");
                args.append("-target-cpu");
                args.append("-Xclang");
                args.append(g->zig_target->llvm_cpu_name);
            }
            if (g->zig_target->llvm_cpu_features != nullptr) {
                // https://github.com/ziglang/zig/issues/5017
                SplitIterator it = memSplit(str(g->zig_target->llvm_cpu_features), str(","));
                Optional<Slice<uint8_t>> flag = SplitIterator_next(&it);
                while (flag.is_some) {
                    args.append("-Xclang");
                    args.append("-target-feature");
                    args.append("-Xclang");
                    args.append(buf_ptr(buf_create_from_slice(flag.value)));
                    flag = SplitIterator_next(&it);
                }
            }
            if (translate_c) {
                // this gives us access to preprocessing entities, presumably at
                // the cost of performance
                args.append("-Xclang");
                args.append("-detailed-preprocessing-record");
            }
            if (out_dep_path != nullptr) {
                args.append("-MD");
                args.append("-MV");
                args.append("-MF");
                args.append(out_dep_path);
            }
            break;
        case FileExtAsm:
        case FileExtLLVMIr:
        case FileExtLLVMBitCode:
        case FileExtUnknown:
            break;
    }
    for (size_t i = 0; i < g->zig_target->llvm_cpu_features_asm_len; i += 1) {
        args.append(g->zig_target->llvm_cpu_features_asm_ptr[i]);
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

    if (codegen_have_frame_pointer(g)) {
        args.append("-fno-omit-frame-pointer");
    } else {
        args.append("-fomit-frame-pointer");
    }

    if (g->have_sanitize_c) {
        args.append("-fsanitize=undefined");
        args.append("-fsanitize-trap=undefined");
    }

    switch (g->build_mode) {
        case BuildModeDebug:
            // windows c runtime requires -D_DEBUG if using debug libraries
            args.append("-D_DEBUG");
            args.append("-Og");

            if (g->libc_link_lib != nullptr) {
                args.append("-fstack-protector-strong");
                args.append("--param");
                args.append("ssp-buffer-size=4");
            } else {
                args.append("-fno-stack-protector");
            }
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
            break;
        case BuildModeSmallRelease:
            args.append("-DNDEBUG");
            args.append("-Os");
            args.append("-fno-stack-protector");
            break;
    }

    if (target_supports_fpic(g->zig_target) && g->have_pic) {
        args.append("-fPIC");
    }

    for (size_t arg_i = 0; arg_i < g->clang_argv_len; arg_i += 1) {
        args.append(g->clang_argv[arg_i]);
    }

}

void codegen_translate_c(CodeGen *g, Buf *full_path) {
    Error err;

    Buf *src_basename = buf_alloc();
    Buf *src_dirname = buf_alloc();
    os_path_split(full_path, src_dirname, src_basename);

    Buf noextname = BUF_INIT;
    os_path_extname(src_basename, &noextname, nullptr);

    Buf *zig_basename = buf_sprintf("%s.zig", buf_ptr(&noextname));

    detect_libc(g);

    Buf cache_digest = BUF_INIT;
    buf_resize(&cache_digest, 0);

    CacheHash *cache_hash = nullptr;
    if (g->enable_cache) {
        if ((err = create_c_object_cache(g, &cache_hash, true))) {
            // Already printed error; verbose = true
            exit(1);
        }
        cache_file(cache_hash, full_path);
        // to distinguish from generating a C object
        cache_buf(cache_hash, buf_create_from_str("translate-c"));

        if ((err = cache_hit(cache_hash, &cache_digest))) {
            if (err != ErrorInvalidFormat) {
                fprintf(stderr, "unable to check cache: %s\n", err_str(err));
                exit(1);
            }
        }
        if (cache_hash->manifest_file_path != nullptr) {
            g->caches_to_release.append(cache_hash);
        }
    }

    if (g->enable_cache && buf_len(&cache_digest) != 0) {
        // cache hit
        Buf *cached_path = buf_sprintf("%s" OS_SEP CACHE_OUT_SUBDIR OS_SEP "%s" OS_SEP "%s",
                buf_ptr(g->cache_dir), buf_ptr(&cache_digest), buf_ptr(zig_basename));
        fprintf(stdout, "%s\n", buf_ptr(cached_path));
        return;
    }

    // cache miss or cache disabled
    init(g);

    Buf *out_dep_path = nullptr;
    const char *out_dep_path_cstr = nullptr;

    if (g->enable_cache) {
        buf_alloc();// we can't know the digest until we do the C compiler invocation, so we
        // need a tmp filename.
        out_dep_path = buf_alloc();
        if ((err = get_tmp_filename(g, out_dep_path, buf_sprintf("%s.d", buf_ptr(zig_basename))))) {
            fprintf(stderr, "unable to create tmp dir: %s\n", err_str(err));
            exit(1);
        }
        out_dep_path_cstr = buf_ptr(out_dep_path);
    }

    ZigList<const char *> clang_argv = {0};
    add_cc_args(g, clang_argv, out_dep_path_cstr, true, FileExtC);

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

    err = stage2_translate_c(&ast, &errors_ptr, &errors_len,
                    &clang_argv.at(0), &clang_argv.last(), resources_path);

    if (err == ErrorCCompileErrors && errors_len > 0) {
        for (size_t i = 0; i < errors_len; i += 1) {
            Stage2ErrorMsg *clang_err = &errors_ptr[i];

            ErrorMsg *err_msg = err_msg_create_with_offset(
                clang_err->filename_ptr ?
                buf_create_from_mem(clang_err->filename_ptr, clang_err->filename_len) : nullptr,
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

    if (!g->enable_cache) {
        stage2_render_ast(ast, stdout);
        return;
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

    if ((err = cache_final(cache_hash, &cache_digest))) {
        fprintf(stderr, "Unable to finalize cache hash: %s\n", err_str(err));
        exit(1);
    }

    Buf *artifact_dir = buf_sprintf("%s" OS_SEP CACHE_OUT_SUBDIR OS_SEP "%s",
            buf_ptr(g->cache_dir), buf_ptr(&cache_digest));

    if ((err = os_make_path(artifact_dir))) {
        fprintf(stderr, "Unable to make dir: %s\n", err_str(err));
        exit(1);
    }

    Buf *cached_path = buf_sprintf("%s" OS_SEP "%s", buf_ptr(artifact_dir), buf_ptr(zig_basename));

    FILE *out_file = fopen(buf_ptr(cached_path), "wb");
    if (out_file == nullptr) {
        fprintf(stderr, "Unable to open output file: %s\n", strerror(errno));
        exit(1);
    }
    stage2_render_ast(ast, out_file);
    if (fclose(out_file) != 0) {
        fprintf(stderr, "Unable to write to output file: %s\n", strerror(errno));
        exit(1);
    }
    fprintf(stdout, "%s\n", buf_ptr(cached_path));
}

static void update_test_functions_builtin_decl(CodeGen *g) {
    Error err;

    assert(g->is_test_build);

    if (g->test_fns.length == 0) {
        fprintf(stderr, "No tests to run.\n");
        exit(0);
    }

    ZigType *fn_type = get_test_fn_type(g);

    ZigValue *test_fn_type_val = get_builtin_value(g, "TestFn");
    assert(test_fn_type_val->type->id == ZigTypeIdMetaType);
    ZigType *struct_type = test_fn_type_val->data.x_type;
    if ((err = type_resolve(g, struct_type, ResolveStatusSizeKnown)))
        zig_unreachable();

    ZigValue *test_fn_array = g->pass1_arena->create<ZigValue>();
    test_fn_array->type = get_array_type(g, struct_type, g->test_fns.length, nullptr);
    test_fn_array->special = ConstValSpecialStatic;
    test_fn_array->data.x_array.data.s_none.elements = g->pass1_arena->allocate<ZigValue>(g->test_fns.length);

    for (size_t i = 0; i < g->test_fns.length; i += 1) {
        ZigFn *test_fn_entry = g->test_fns.at(i);

        ZigValue *this_val = &test_fn_array->data.x_array.data.s_none.elements[i];
        this_val->special = ConstValSpecialStatic;
        this_val->type = struct_type;
        this_val->parent.id = ConstParentIdArray;
        this_val->parent.data.p_array.array_val = test_fn_array;
        this_val->parent.data.p_array.elem_index = i;
        this_val->data.x_struct.fields = alloc_const_vals_ptrs(g, 3);

        ZigValue *name_field = this_val->data.x_struct.fields[0];
        ZigValue *name_array_val = create_const_str_lit(g, &test_fn_entry->symbol_name)->data.x_ptr.data.ref.pointee;
        init_const_slice(g, name_field, name_array_val, 0, buf_len(&test_fn_entry->symbol_name), true);

        ZigValue *fn_field = this_val->data.x_struct.fields[1];
        fn_field->type = fn_type;
        fn_field->special = ConstValSpecialStatic;
        fn_field->data.x_ptr.special = ConstPtrSpecialFunction;
        fn_field->data.x_ptr.mut = ConstPtrMutComptimeConst;
        fn_field->data.x_ptr.data.fn.fn_entry = test_fn_entry;

        ZigValue *frame_size_field = this_val->data.x_struct.fields[2];
        frame_size_field->type = get_optional_type(g, g->builtin_types.entry_usize);
        frame_size_field->special = ConstValSpecialStatic;
        frame_size_field->data.x_optional = nullptr;

        if (fn_is_async(test_fn_entry)) {
            frame_size_field->data.x_optional = g->pass1_arena->create<ZigValue>();
            frame_size_field->data.x_optional->special = ConstValSpecialStatic;
            frame_size_field->data.x_optional->type = g->builtin_types.entry_usize;
            bigint_init_unsigned(&frame_size_field->data.x_optional->data.x_bigint,
                    test_fn_entry->frame_type->abi_size);
        }
    }
    report_errors_and_maybe_exit(g);

    ZigValue *test_fn_slice = create_const_slice(g, test_fn_array, 0, g->test_fns.length, true);

    update_compile_var(g, buf_create_from_str("test_functions"), test_fn_slice);
    assert(g->test_runner_package != nullptr);
}

static Buf *get_resolved_root_src_path(CodeGen *g) {
    // TODO memoize
    if (buf_len(&g->main_pkg->root_src_path) == 0)
        return nullptr;

    Buf rel_full_path = BUF_INIT;
    os_path_join(&g->main_pkg->root_src_dir, &g->main_pkg->root_src_path, &rel_full_path);

    Buf *resolved_path = buf_alloc();
    Buf *resolve_paths[] = {&rel_full_path};
    *resolved_path = os_path_resolve(resolve_paths, 1);

    return resolved_path;
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

    ZigType *root_import_alias = add_source_file(g, g->main_pkg, resolved_path, source_code, SourceKindRoot);
    assert(root_import_alias == g->root_import);

    assert(g->root_out_name);
    assert(g->out_type != OutTypeUnknown);

    if (!g->is_dummy_so) {
        // Zig has lazy top level definitions. Here we semantically analyze the panic function.
        Buf *import_target_path;
        Buf full_path = BUF_INIT;
        ZigType *std_import;
        if ((err = analyze_import(g, g->root_import, buf_create_from_str("std"), &std_import,
            &import_target_path, &full_path)))
        {
            if (err == ErrorFileNotFound) {
                fprintf(stderr, "unable to find '%s'", buf_ptr(import_target_path));
            } else {
                fprintf(stderr, "unable to open '%s': %s\n", buf_ptr(&full_path), err_str(err));
            }
            exit(1);
        }

        Tld *builtin_tld = find_decl(g, &get_container_scope(std_import)->base,
                buf_create_from_str("builtin"));
        assert(builtin_tld != nullptr);
        resolve_top_level_decl(g, builtin_tld, nullptr, false);
        report_errors_and_maybe_exit(g);
        assert(builtin_tld->id == TldIdVar);
        TldVar *builtin_tld_var = (TldVar*)builtin_tld;
        ZigValue *builtin_val = builtin_tld_var->var->const_value;
        assert(builtin_val->type->id == ZigTypeIdMetaType);
        ZigType *builtin_type = builtin_val->data.x_type;

        Tld *panic_tld = find_decl(g, &get_container_scope(builtin_type)->base,
                buf_create_from_str("panic"));
        assert(panic_tld != nullptr);
        resolve_top_level_decl(g, panic_tld, nullptr, false);
        report_errors_and_maybe_exit(g);
        assert(panic_tld->id == TldIdVar);
        TldVar *panic_tld_var = (TldVar*)panic_tld;
        ZigValue *panic_fn_val = panic_tld_var->var->const_value;
        assert(panic_fn_val->type->id == ZigTypeIdFn);
        assert(panic_fn_val->data.x_ptr.special == ConstPtrSpecialFunction);
        g->panic_fn = panic_fn_val->data.x_ptr.data.fn.fn_entry;
        assert(g->panic_fn != nullptr);
    }

    if (!g->error_during_imports) {
        semantic_analyze(g);
    }
    report_errors_and_maybe_exit(g);

    if (g->is_test_build) {
        update_test_functions_builtin_decl(g);
        if (!g->error_during_imports) {
            semantic_analyze(g);
        }
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
    CacheHash *cache_hash = heap::c_allocator.create<CacheHash>();
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
    cache_list_of_str(cache_hash, g->framework_dirs.items, g->framework_dirs.length);
    cache_bool(cache_hash, g->libcpp_link_lib != nullptr);
    cache_buf(cache_hash, g->zig_lib_dir);
    cache_buf(cache_hash, g->zig_c_headers_dir);
    cache_list_of_str(cache_hash, g->libc_include_dir_list, g->libc_include_dir_len);
    cache_int(cache_hash, g->zig_target->is_native_os);
    cache_int(cache_hash, g->zig_target->is_native_cpu);
    cache_int(cache_hash, g->zig_target->arch);
    cache_int(cache_hash, g->zig_target->vendor);
    cache_int(cache_hash, g->zig_target->os);
    cache_int(cache_hash, g->zig_target->abi);
    cache_bool(cache_hash, g->strip_debug_symbols);
    cache_int(cache_hash, g->build_mode);
    cache_bool(cache_hash, g->have_pic);
    cache_bool(cache_hash, g->have_sanitize_c);
    cache_bool(cache_hash, want_valgrind_support(g));
    cache_bool(cache_hash, g->function_sections);
    cache_int(cache_hash, g->code_model);
    cache_bool(cache_hash, codegen_have_frame_pointer(g));
    cache_bool(cache_hash, g->libc_link_lib);
    if (g->zig_target->cache_hash != nullptr) {
        cache_mem(cache_hash, g->zig_target->cache_hash, g->zig_target->cache_hash_len);
    }

    for (size_t arg_i = 0; arg_i < g->clang_argv_len; arg_i += 1) {
        cache_str(cache_hash, g->clang_argv[arg_i]);
    }

    *out_cache_hash = cache_hash;
    return ErrorNone;
}

static bool need_llvm_module(CodeGen *g) {
    return buf_len(&g->main_pkg->root_src_path) != 0;
}

// before gen_c_objects
static bool main_output_dir_is_just_one_c_object_pre(CodeGen *g) {
    return g->enable_cache && g->c_source_files.length == 1 && !need_llvm_module(g) &&
        g->out_type == OutTypeObj && g->link_objects.length == 0;
}

// after gen_c_objects
static bool main_output_dir_is_just_one_c_object_post(CodeGen *g) {
    return g->enable_cache && g->link_objects.length == 1 && !need_llvm_module(g) && g->out_type == OutTypeObj;
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

    Stage2ProgressNode *child_prog_node = stage2_progress_start(g->sub_progress_node, buf_ptr(c_source_basename),
            buf_len(c_source_basename), 0);

    Buf *final_o_basename = buf_alloc();
    if (c_file->preprocessor_only_basename == nullptr) {
        // We special case when doing build-obj for just one C file
        if (main_output_dir_is_just_one_c_object_pre(g)) {
            buf_init_from_buf(final_o_basename, g->root_out_name);
        } else {
            os_path_extname(c_source_basename, final_o_basename, nullptr);
        }
        buf_append_str(final_o_basename, target_o_file_ext(g->zig_target));
    } else {
        buf_init_from_str(final_o_basename, c_file->preprocessor_only_basename);
    }

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
    bool is_cache_miss = g->disable_c_depfile || (buf_len(&digest) == 0);
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
        args.append("clang");

        if (c_file->preprocessor_only_basename == nullptr) {
            args.append("-c");
        }

        Buf *out_dep_path = g->disable_c_depfile ? nullptr : buf_sprintf("%s.d", buf_ptr(out_obj_path));
        const char *out_dep_path_cstr = (out_dep_path == nullptr) ? nullptr : buf_ptr(out_dep_path);
        FileExt ext = classify_file_ext(buf_ptr(c_source_basename), buf_len(c_source_basename));
        add_cc_args(g, args, out_dep_path_cstr, false, ext);

        args.append("-o");
        args.append(buf_ptr(out_obj_path));

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

        if (out_dep_path != nullptr) {
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

    g->c_artifact_dir = artifact_dir;
    g->link_objects.append(o_final_path);
    g->caches_to_release.append(cache_hash);

    stage2_progress_end(child_prog_node);
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

    codegen_add_time_event(g, "Compile C Objects");
    const char *c_prog_name = "Compile C Objects";
    codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node, c_prog_name, strlen(c_prog_name),
            g->c_source_files.length));

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
        case ZigTypeIdErrorUnion:
        case ZigTypeIdErrorSet:
        case ZigTypeIdFnFrame:
        case ZigTypeIdAnyFrame:
            zig_unreachable();
        case ZigTypeIdVoid:
        case ZigTypeIdUnreachable:
            return;
        case ZigTypeIdBool:
            g->c_want_stdbool = true;
            return;
        case ZigTypeIdInt:
            g->c_want_stdint = true;
            return;
        case ZigTypeIdFloat:
            return;
        case ZigTypeIdOpaque:
            gen_h->types_to_declare.append(type_entry);
            return;
        case ZigTypeIdStruct:
            for (uint32_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
                TypeStructField *field = type_entry->data.structure.fields[i];
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
                if (!type_has_bits(g, child_type)) {
                    buf_init_from_str(out_buf, "bool");
                    return;
                } else if (type_is_nonnull_ptr(g, child_type)) {
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
        case ZigTypeIdFnFrame:
        case ZigTypeIdAnyFrame:
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

static void gen_h_file_types(CodeGen* g, GenH* gen_h, Buf* out_buf) {
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
            case ZigTypeIdOptional:
            case ZigTypeIdFn:
            case ZigTypeIdVector:
            case ZigTypeIdFnFrame:
            case ZigTypeIdAnyFrame:
                zig_unreachable();

            case ZigTypeIdEnum:
                if (type_entry->data.enumeration.layout == ContainerLayoutExtern) {
                    buf_appendf(out_buf, "enum %s {\n", buf_ptr(type_h_name(type_entry)));
                    for (uint32_t field_i = 0; field_i < type_entry->data.enumeration.src_field_count; field_i += 1) {
                        TypeEnumField *enum_field = &type_entry->data.enumeration.fields[field_i];
                        Buf *value_buf = buf_alloc();
                        bigint_append_buf(value_buf, &enum_field->value, 10);
                        buf_appendf(out_buf, "    %s = %s", buf_ptr(enum_field->name), buf_ptr(value_buf));
                        if (field_i != type_entry->data.enumeration.src_field_count - 1) {
                            buf_appendf(out_buf, ",");
                        }
                        buf_appendf(out_buf, "\n");
                    }
                    buf_appendf(out_buf, "};\n\n");
                } else {
                    buf_appendf(out_buf, "enum %s;\n\n", buf_ptr(type_h_name(type_entry)));
                }
                break;
            case ZigTypeIdStruct:
                if (type_entry->data.structure.layout == ContainerLayoutExtern) {
                    buf_appendf(out_buf, "struct %s {\n", buf_ptr(type_h_name(type_entry)));
                    for (uint32_t field_i = 0; field_i < type_entry->data.structure.src_field_count; field_i += 1) {
                        TypeStructField *struct_field = type_entry->data.structure.fields[field_i];

                        Buf *type_name_buf = buf_alloc();
                        get_c_type(g, gen_h, struct_field->type_entry, type_name_buf);

                        if (struct_field->type_entry->id == ZigTypeIdArray) {
                            buf_appendf(out_buf, "    %s %s[%" ZIG_PRI_u64 "];\n", buf_ptr(type_name_buf),
                                    buf_ptr(struct_field->name),
                                    struct_field->type_entry->data.array.len);
                        } else {
                            buf_appendf(out_buf, "    %s %s;\n", buf_ptr(type_name_buf), buf_ptr(struct_field->name));
                        }

                    }
                    buf_appendf(out_buf, "};\n\n");
                } else {
                    buf_appendf(out_buf, "struct %s;\n\n", buf_ptr(type_h_name(type_entry)));
                }
                break;
            case ZigTypeIdUnion:
                if (type_entry->data.unionation.layout == ContainerLayoutExtern) {
                    buf_appendf(out_buf, "union %s {\n", buf_ptr(type_h_name(type_entry)));
                    for (uint32_t field_i = 0; field_i < type_entry->data.unionation.src_field_count; field_i += 1) {
                        TypeUnionField *union_field = &type_entry->data.unionation.fields[field_i];

                        Buf *type_name_buf = buf_alloc();
                        get_c_type(g, gen_h, union_field->type_entry, type_name_buf);
                        buf_appendf(out_buf, "    %s %s;\n", buf_ptr(type_name_buf), buf_ptr(union_field->name));
                    }
                    buf_appendf(out_buf, "};\n\n");
                } else {
                    buf_appendf(out_buf, "union %s;\n\n", buf_ptr(type_h_name(type_entry)));
                }
                break;
            case ZigTypeIdOpaque:
                buf_appendf(out_buf, "struct %s;\n\n", buf_ptr(type_h_name(type_entry)));
                break;
        }
    }
}

static void gen_h_file_functions(CodeGen* g, GenH* gen_h, Buf* out_buf, Buf* export_macro) {
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

        if (export_macro != nullptr) {
            buf_appendf(out_buf, "%s %s %s(",
                buf_ptr(export_macro),
                buf_ptr(&return_type_c),
                buf_ptr(symbol_name));
        } else {
            buf_appendf(out_buf, "%s %s(",
                buf_ptr(&return_type_c),
                buf_ptr(symbol_name));
        }

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
                    buf_appendf(out_buf, "%s%s%s %s[]", comma_str, buf_ptr(&param_type_c),
                            restrict_str, buf_ptr(param_name));
                } else {
                    buf_appendf(out_buf, "%s%s%s %s", comma_str, buf_ptr(&param_type_c),
                            restrict_str, buf_ptr(param_name));
                }
            }
            buf_appendf(out_buf, ")");
        } else {
            buf_appendf(out_buf, "void)");
        }

        buf_appendf(out_buf, ";\n");
    }
}

static void gen_h_file_variables(CodeGen* g, GenH* gen_h, Buf* h_buf, Buf* export_macro) {
    for (size_t exp_var_i = 0; exp_var_i < g->global_vars.length; exp_var_i += 1) {
        ZigVar* var = g->global_vars.at(exp_var_i)->var;
        if (var->export_list.length == 0)
            continue;

        Buf var_type_c = BUF_INIT;
        get_c_type(g, gen_h, var->var_type, &var_type_c);

        if (export_macro != nullptr) {
            buf_appendf(h_buf, "extern %s %s %s;\n",
                buf_ptr(export_macro),
                buf_ptr(&var_type_c),
                var->name);
        } else {
            buf_appendf(h_buf, "extern %s %s;\n",
                buf_ptr(&var_type_c),
                var->name);
        }
    }
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

    Buf fns_buf = BUF_INIT;
    buf_resize(&fns_buf, 0);
    gen_h_file_functions(g, gen_h, &fns_buf, export_macro);

    Buf vars_buf = BUF_INIT;
    buf_resize(&vars_buf, 0);
    gen_h_file_variables(g, gen_h, &vars_buf, export_macro);

    // Types will be populated by exported functions and variables so it has to run last.
    Buf types_buf = BUF_INIT;
    buf_resize(&types_buf, 0);
    gen_h_file_types(g, gen_h, &types_buf);

    Buf *ifdef_dance_name = preprocessor_mangle(buf_sprintf("%s_H", buf_ptr(g->root_out_name)));
    buf_upcase(ifdef_dance_name);

    fprintf(out_h, "#ifndef %s\n", buf_ptr(ifdef_dance_name));
    fprintf(out_h, "#define %s\n\n", buf_ptr(ifdef_dance_name));

    if (g->c_want_stdbool)
        fprintf(out_h, "#include <stdbool.h>\n");
    if (g->c_want_stdint)
        fprintf(out_h, "#include <stdint.h>\n");

    fprintf(out_h, "\n");

    if (g->is_dynamic) {
        fprintf(out_h, "#if defined(_WIN32)\n");
        fprintf(out_h, "#define %s __declspec(dllimport)\n", buf_ptr(export_macro));
        fprintf(out_h, "#else\n");
        fprintf(out_h, "#define %s __attribute__((visibility (\"default\")))\n",
            buf_ptr(export_macro));
        fprintf(out_h, "#endif\n");
        fprintf(out_h, "\n");
    }

    fprintf(out_h, "%s", buf_ptr(&types_buf));

    fprintf(out_h, "#ifdef __cplusplus\n");
    fprintf(out_h, "extern \"C\" {\n");
    fprintf(out_h, "#endif\n");
    fprintf(out_h, "\n");

    fprintf(out_h, "%s\n", buf_ptr(&fns_buf));

    fprintf(out_h, "#ifdef __cplusplus\n");
    fprintf(out_h, "} // extern \"C\"\n");
    fprintf(out_h, "#endif\n\n");

    fprintf(out_h, "%s\n", buf_ptr(&vars_buf));

    fprintf(out_h, "#endif // %s\n", buf_ptr(ifdef_dance_name));

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

    add_cache_pkg(g, ch, g->main_pkg);
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
    cache_bool(ch, g->zig_target->is_native_os);
    cache_bool(ch, g->zig_target->is_native_cpu);
    cache_int(ch, g->zig_target->arch);
    cache_int(ch, g->zig_target->vendor);
    cache_int(ch, g->zig_target->os);
    cache_int(ch, g->zig_target->abi);
    if (g->zig_target->cache_hash != nullptr) {
        cache_mem(ch, g->zig_target->cache_hash, g->zig_target->cache_hash_len);
    }
    if (g->zig_target->glibc_or_darwin_version != nullptr) {
        cache_int(ch, g->zig_target->glibc_or_darwin_version->major);
        cache_int(ch, g->zig_target->glibc_or_darwin_version->minor);
        cache_int(ch, g->zig_target->glibc_or_darwin_version->patch);
    }
    if (g->zig_target->dynamic_linker != nullptr) {
        cache_str(ch, g->zig_target->dynamic_linker);
    }
    cache_int(ch, detect_subsystem(g));
    cache_bool(ch, g->strip_debug_symbols);
    cache_bool(ch, g->is_test_build);
    if (g->is_test_build) {
        cache_buf_opt(ch, g->test_filter);
        cache_buf_opt(ch, g->test_name_prefix);
        cache_bool(ch, g->test_is_evented);
    }
    cache_bool(ch, g->link_eh_frame_hdr);
    cache_bool(ch, g->is_single_threaded);
    cache_bool(ch, g->linker_rdynamic);
    cache_bool(ch, g->each_lib_rpath);
    cache_bool(ch, g->disable_gen_h);
    cache_bool(ch, g->bundle_compiler_rt);
    cache_bool(ch, want_valgrind_support(g));
    cache_bool(ch, g->have_pic);
    cache_bool(ch, g->have_dynamic_link);
    cache_bool(ch, g->have_stack_probing);
    cache_bool(ch, g->have_sanitize_c);
    cache_bool(ch, g->is_dummy_so);
    cache_bool(ch, g->function_sections);
    cache_bool(ch, g->enable_dump_analysis);
    cache_bool(ch, g->enable_doc_generation);
    cache_bool(ch, g->emit_bin);
    cache_bool(ch, g->emit_llvm_ir);
    cache_bool(ch, g->emit_asm);
    cache_usize(ch, g->version_major);
    cache_usize(ch, g->version_minor);
    cache_usize(ch, g->version_patch);
    cache_list_of_str(ch, g->llvm_argv, g->llvm_argv_len);
    cache_list_of_str(ch, g->clang_argv, g->clang_argv_len);
    cache_list_of_str(ch, g->lib_dirs.items, g->lib_dirs.length);
    cache_list_of_str(ch, g->framework_dirs.items, g->framework_dirs.length);
    if (g->libc) {
        cache_slice(ch, Slice<const char>{g->libc->include_dir, g->libc->include_dir_len});
        cache_slice(ch, Slice<const char>{g->libc->sys_include_dir, g->libc->sys_include_dir_len});
        cache_slice(ch, Slice<const char>{g->libc->crt_dir, g->libc->crt_dir_len});
        cache_slice(ch, Slice<const char>{g->libc->msvc_lib_dir, g->libc->msvc_lib_dir_len});
        cache_slice(ch, Slice<const char>{g->libc->kernel32_lib_dir, g->libc->kernel32_lib_dir_len});
    }
    cache_buf_opt(ch, g->version_script_path);
    cache_buf_opt(ch, g->override_soname);
    cache_buf_opt(ch, g->linker_optimization);
    cache_int(ch, g->linker_gc_sections);
    cache_int(ch, g->linker_allow_shlib_undefined);
    cache_int(ch, g->linker_bind_global_refs_locally);
    cache_bool(ch, g->linker_z_nodelete);
    cache_bool(ch, g->linker_z_defs);
    cache_usize(ch, g->stack_size_override);

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

static void resolve_out_paths(CodeGen *g) {
    assert(g->output_dir != nullptr);
    assert(g->root_out_name != nullptr);

    if (g->emit_bin) {
        Buf *out_basename = buf_create_from_buf(g->root_out_name);
        Buf *o_basename = buf_create_from_buf(g->root_out_name);
        switch (g->out_type) {
            case OutTypeUnknown:
                zig_unreachable();
            case OutTypeObj:
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
        os_path_join(g->output_dir, o_basename, &g->o_file_output_path);
        os_path_join(g->output_dir, out_basename, &g->bin_file_output_path);
    }
    if (g->emit_asm) {
        Buf *asm_basename = buf_create_from_buf(g->root_out_name);
        const char *asm_ext = target_asm_file_ext(g->zig_target);
        buf_append_str(asm_basename, asm_ext);
        os_path_join(g->output_dir, asm_basename, &g->asm_file_output_path);
    }
    if (g->emit_llvm_ir) {
        Buf *llvm_ir_basename = buf_create_from_buf(g->root_out_name);
        const char *llvm_ir_ext = target_llvm_ir_file_ext(g->zig_target);
        buf_append_str(llvm_ir_basename, llvm_ir_ext);
        os_path_join(g->output_dir, llvm_ir_basename, &g->llvm_ir_file_output_path);
    }
}

static void output_type_information(CodeGen *g) {
    if (g->enable_dump_analysis) {
        const char *analysis_json_filename = buf_ptr(buf_sprintf("%s" OS_SEP "%s-analysis.json",
                    buf_ptr(g->output_dir), buf_ptr(g->root_out_name)));
        FILE *f = fopen(analysis_json_filename, "wb");
        if (f == nullptr) {
            fprintf(stderr, "Unable to open '%s': %s\n", analysis_json_filename, strerror(errno));
            exit(1);
        }
        zig_print_analysis_dump(g, f, " ", "\n");
        if (fclose(f) != 0) {
            fprintf(stderr, "Unable to write '%s': %s\n", analysis_json_filename, strerror(errno));
            exit(1);
        }
    }
    if (g->enable_doc_generation) {
        Error err;
        Buf *doc_dir_path = buf_sprintf("%s" OS_SEP "docs", buf_ptr(g->output_dir));
        if ((err = os_make_path(doc_dir_path))) {
            fprintf(stderr, "Unable to create directory %s: %s\n", buf_ptr(doc_dir_path), err_str(err));
            exit(1);
        }
        Buf *index_html_src_path = buf_sprintf("%s" OS_SEP "special" OS_SEP "docs" OS_SEP "index.html",
                buf_ptr(g->zig_std_dir));
        Buf *index_html_dest_path = buf_sprintf("%s" OS_SEP "index.html", buf_ptr(doc_dir_path));
        Buf *main_js_src_path = buf_sprintf("%s" OS_SEP "special" OS_SEP "docs" OS_SEP "main.js",
                buf_ptr(g->zig_std_dir));
        Buf *main_js_dest_path = buf_sprintf("%s" OS_SEP "main.js", buf_ptr(doc_dir_path));

        if ((err = os_copy_file(index_html_src_path, index_html_dest_path))) {
            fprintf(stderr, "Unable to copy %s to %s: %s\n", buf_ptr(index_html_src_path),
                    buf_ptr(index_html_dest_path), err_str(err));
            exit(1);
        }
        if ((err = os_copy_file(main_js_src_path, main_js_dest_path))) {
            fprintf(stderr, "Unable to copy %s to %s: %s\n", buf_ptr(main_js_src_path),
                    buf_ptr(main_js_dest_path), err_str(err));
            exit(1);
        }
        const char *data_js_filename = buf_ptr(buf_sprintf("%s" OS_SEP "data.js", buf_ptr(doc_dir_path)));
        FILE *f = fopen(data_js_filename, "wb");
        if (f == nullptr) {
            fprintf(stderr, "Unable to open '%s': %s\n", data_js_filename, strerror(errno));
            exit(1);
        }
        fprintf(f, "zigAnalysis=");
        zig_print_analysis_dump(g, f, "", "");
        fprintf(f, ";");
        if (fclose(f) != 0) {
            fprintf(stderr, "Unable to write '%s': %s\n", data_js_filename, strerror(errno));
            exit(1);
        }
    }
}

static void init_output_dir(CodeGen *g, Buf *digest) {
    if (main_output_dir_is_just_one_c_object_post(g)) {
        g->output_dir = buf_alloc();
        os_path_dirname(g->link_objects.at(0), g->output_dir);
    } else {
        g->output_dir = buf_sprintf("%s" OS_SEP CACHE_OUT_SUBDIR OS_SEP "%s",
            buf_ptr(g->cache_dir), buf_ptr(digest));
    }
}

void codegen_build_and_link(CodeGen *g) {
    Error err;
    assert(g->out_type != OutTypeUnknown);

    if (!g->enable_cache) {
        if (g->output_dir == nullptr) {
            g->output_dir = buf_create_from_str(".");
        } else if ((err = os_make_path(g->output_dir))) {
            fprintf(stderr, "Unable to create output directory: %s\n", err_str(err));
            exit(1);
        }
    }

    g->have_dynamic_link = detect_dynamic_link(g);
    g->have_pic = detect_pic(g);
    g->is_single_threaded = detect_single_threaded(g);
    g->have_err_ret_tracing = detect_err_ret_tracing(g);
    g->have_sanitize_c = detect_sanitize_c(g);
    detect_libc(g);

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
        init_output_dir(g, &digest);
        resolve_out_paths(g);
    } else {
        if (need_llvm_module(g)) {
            init(g);

            codegen_add_time_event(g, "Semantic Analysis");
            const char *progress_name = "Semantic Analysis";
            codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                    progress_name, strlen(progress_name), 0));

            gen_root_source(g);

        }
        if (g->enable_cache) {
            if (buf_len(&digest) == 0) {
                if ((err = cache_final(&g->cache_hash, &digest))) {
                    fprintf(stderr, "Unable to finalize cache hash: %s\n", err_str(err));
                    exit(1);
                }
            }
            init_output_dir(g, &digest);

            if ((err = os_make_path(g->output_dir))) {
                fprintf(stderr, "Unable to create output directory: %s\n", err_str(err));
                exit(1);
            }
        }
        resolve_out_paths(g);

        if (g->enable_dump_analysis || g->enable_doc_generation) {
            output_type_information(g);
        }

        if (need_llvm_module(g)) {
            codegen_add_time_event(g, "Code Generation");
            {
                const char *progress_name = "Code Generation";
                codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                        progress_name, strlen(progress_name), 0));
            }

            do_code_gen(g);
            codegen_add_time_event(g, "LLVM Emit Output");
            {
                const char *progress_name = "LLVM Emit Output";
                codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                        progress_name, strlen(progress_name), 0));
            }
            zig_llvm_emit_output(g);

            if (!g->disable_gen_h && (g->out_type == OutTypeObj || g->out_type == OutTypeLib)) {
                codegen_add_time_event(g, "Generate .h");
                {
                    const char *progress_name = "Generate .h";
                    codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                            progress_name, strlen(progress_name), 0));
                }
                gen_h_file(g);
            }
        }

        // If we're outputting assembly or llvm IR we skip linking.
        // If we're making a library or executable we must link.
        // If there is more than one object, we have to link them (with -r).
        // Finally, if we didn't make an object from zig source, and we don't have caching enabled,
        // then we have an object from C source that we must copy to the output dir which we do with a -r link.
        if (g->emit_bin  &&
                (g->out_type != OutTypeObj || g->link_objects.length > 1 ||
                    (!need_llvm_module(g) && !g->enable_cache)))
        {
            codegen_link(g);
        }
    }

    codegen_release_caches(g);
    codegen_add_time_event(g, "Done");
    codegen_switch_sub_prog_node(g, nullptr);
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

        pkg->package_table.put(buf_create_from_str("root"), g->root_pkg);

        pkg->package_table.put(buf_create_from_str("builtin"), g->compile_var_package);
    }
    return pkg;
}

CodeGen *create_child_codegen(CodeGen *parent_gen, Buf *root_src_path, OutType out_type,
        Stage2LibCInstallation *libc, const char *name, Stage2ProgressNode *parent_progress_node)
{
    Stage2ProgressNode *child_progress_node = stage2_progress_start(
            parent_progress_node ? parent_progress_node : parent_gen->sub_progress_node,
            name, strlen(name), 0);

    CodeGen *child_gen = codegen_create(nullptr, root_src_path, parent_gen->zig_target, out_type,
        parent_gen->build_mode, parent_gen->zig_lib_dir, libc, get_global_cache_dir(), false, child_progress_node);
    child_gen->root_out_name = buf_create_from_str(name);
    child_gen->disable_gen_h = true;
    child_gen->want_stack_check = WantStackCheckDisabled;
    child_gen->want_sanitize_c = WantCSanitizeDisabled;
    child_gen->verbose_tokenize = parent_gen->verbose_tokenize;
    child_gen->verbose_ast = parent_gen->verbose_ast;
    child_gen->verbose_link = parent_gen->verbose_link;
    child_gen->verbose_ir = parent_gen->verbose_ir;
    child_gen->verbose_llvm_ir = parent_gen->verbose_llvm_ir;
    child_gen->verbose_cimport = parent_gen->verbose_cimport;
    child_gen->verbose_cc = parent_gen->verbose_cc;
    child_gen->verbose_llvm_cpu_features = parent_gen->verbose_llvm_cpu_features;
    child_gen->llvm_argv = parent_gen->llvm_argv;

    codegen_set_strip(child_gen, parent_gen->strip_debug_symbols);
    child_gen->want_pic = parent_gen->have_pic ? WantPICEnabled : WantPICDisabled;
    child_gen->valgrind_support = ValgrindSupportDisabled;

    codegen_set_errmsg_color(child_gen, parent_gen->err_color);

    child_gen->enable_cache = true;

    return child_gen;
}

CodeGen *codegen_create(Buf *main_pkg_path, Buf *root_src_path, const ZigTarget *target,
    OutType out_type, BuildMode build_mode, Buf *override_lib_dir,
    Stage2LibCInstallation *libc, Buf *cache_dir, bool is_test_build, Stage2ProgressNode *progress_node)
{
    CodeGen *g = heap::c_allocator.create<CodeGen>();
    g->emit_bin = true;
    g->pass1_arena = heap::ArenaAllocator::construct(&heap::c_allocator, &heap::c_allocator, "pass1");
    g->main_progress_node = progress_node;

    codegen_add_time_event(g, "Initialize");
    {
        const char *progress_name = "Initialize";
        codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                progress_name, strlen(progress_name), 0));
    }

    g->subsystem = TargetSubsystemAuto;
    g->libc = libc;
    g->zig_target = target;
    g->cache_dir = cache_dir;

    if (override_lib_dir == nullptr) {
        g->zig_lib_dir = get_zig_lib_dir();
    } else {
        g->zig_lib_dir = override_lib_dir;
    }

    g->zig_std_dir = buf_alloc();
    os_path_join(g->zig_lib_dir, buf_create_from_str("std"), g->zig_std_dir);

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
    g->external_symbol_names.init(8);
    g->string_literals_table.init(16);
    g->type_info_cache.init(32);
    g->one_possible_values.init(32);
    g->is_test_build = is_test_build;
    g->is_single_threaded = false;
    g->code_model = CodeModelDefault;
    buf_resize(&g->global_asm, 0);

    for (size_t i = 0; i < array_length(symbols_that_llvm_depends_on); i += 1) {
        g->external_symbol_names.put(buf_create_from_str(symbols_that_llvm_depends_on[i]), nullptr);
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

        g->main_pkg = new_package(buf_ptr(root_pkg_path), buf_ptr(rel_root_src_path), "");
        g->std_package = new_package(buf_ptr(g->zig_std_dir), "std.zig", "std");
        g->main_pkg->package_table.put(buf_create_from_str("std"), g->std_package);
    } else {
        g->main_pkg = new_package(".", "", "");
    }

    g->zig_std_special_dir = buf_alloc();
    os_path_join(g->zig_std_dir, buf_sprintf("special"), g->zig_std_special_dir);

    assert(target != nullptr);
    if (!target->is_native_os) {
        g->each_lib_rpath = false;
    } else {
        g->each_lib_rpath = true;
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

bool codegen_fn_has_err_ret_tracing_arg(CodeGen *g, ZigType *return_type) {
    return g->have_err_ret_tracing &&
        (return_type->id == ZigTypeIdErrorUnion ||
         return_type->id == ZigTypeIdErrorSet);
}

bool codegen_fn_has_err_ret_tracing_stack(CodeGen *g, ZigFn *fn, bool is_async) {
    if (is_async) {
        return g->have_err_ret_tracing && (fn->calls_or_awaits_errorable_fn ||
            codegen_fn_has_err_ret_tracing_arg(g, fn->type_entry->data.fn.fn_type_id.return_type));
    } else {
        return g->have_err_ret_tracing && fn->calls_or_awaits_errorable_fn &&
            !codegen_fn_has_err_ret_tracing_arg(g, fn->type_entry->data.fn.fn_type_id.return_type);
    }
}

void codegen_switch_sub_prog_node(CodeGen *g, Stage2ProgressNode *node) {
    if (g->sub_progress_node != nullptr) {
        stage2_progress_end(g->sub_progress_node);
    }
    g->sub_progress_node = node;
}

ZigValue *CodeGen::Intern::for_undefined() {
#ifdef ZIG_ENABLE_MEM_PROFILE
    mem::intern_counters.x_undefined += 1;
#endif
    return &this->x_undefined;
}

ZigValue *CodeGen::Intern::for_void() {
#ifdef ZIG_ENABLE_MEM_PROFILE
    mem::intern_counters.x_void += 1;
#endif
    return &this->x_void;
}

ZigValue *CodeGen::Intern::for_null() {
#ifdef ZIG_ENABLE_MEM_PROFILE
    mem::intern_counters.x_null += 1;
#endif
    return &this->x_null;
}

ZigValue *CodeGen::Intern::for_unreachable() {
#ifdef ZIG_ENABLE_MEM_PROFILE
    mem::intern_counters.x_unreachable += 1;
#endif
    return &this->x_unreachable;
}

ZigValue *CodeGen::Intern::for_zero_byte() {
#ifdef ZIG_ENABLE_MEM_PROFILE
    mem::intern_counters.zero_byte += 1;
#endif
    return &this->zero_byte;
}
