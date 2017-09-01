/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "all_types.hpp"
#include "analyze.hpp"
#include "c_tokenizer.hpp"
#include "config.h"
#include "error.hpp"
#include "ir.hpp"
#include "os.hpp"
#include "parseh.hpp"
#include "parser.hpp"

#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/AST/Expr.h>

#include <string.h>

using namespace clang;

struct MacroSymbol {
    Buf *name;
    Buf *value;
};

struct GlobalValue {
    TypeTableEntry *type;
    bool is_const;
};

struct Alias {
    Buf *name;
    Tld *tld;
};

struct Context {
    ImportTableEntry *import;
    ZigList<ErrorMsg *> *errors;
    bool warnings_on;
    VisibMod visib_mod;

    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> global_type_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> global_type_table2;

    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> struct_type_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> enum_type_table;
    HashMap<const void *, TypeTableEntry *, ptr_hash, ptr_eq> decl_table;
    HashMap<Buf *, Tld *, buf_hash, buf_eql_buf> macro_table;
    SourceManager *source_manager;
    ZigList<Alias> aliases;
    ZigList<MacroSymbol> macro_symbols;
    AstNode *source_node;
    uint32_t next_anon_index;

    CodeGen *codegen;
    ASTContext *ctx;
};

static TypeTableEntry *resolve_qual_type_with_table(Context *c, QualType qt, const Decl *decl,
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> *type_table);

static TypeTableEntry *resolve_qual_type(Context *c, QualType qt, const Decl *decl);
static TypeTableEntry *resolve_record_decl(Context *c, const RecordDecl *record_decl);
static TypeTableEntry *resolve_enum_decl(Context *c, const EnumDecl *enum_decl);


__attribute__ ((format (printf, 3, 4)))
static void emit_warning(Context *c, const SourceLocation &sl, const char *format, ...) {
    if (!c->warnings_on) {
        return;
    }

    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);

    StringRef filename = c->source_manager->getFilename(sl);
    const char *filename_bytes = (const char *)filename.bytes_begin();
    Buf *path;
    if (filename_bytes) {
        path = buf_create_from_str(filename_bytes);
    } else {
        path = buf_sprintf("(no file)");
    }
    unsigned line = c->source_manager->getSpellingLineNumber(sl);
    unsigned column = c->source_manager->getSpellingColumnNumber(sl);
    fprintf(stderr, "%s:%u:%u: warning: %s\n", buf_ptr(path), line, column, buf_ptr(msg));
}

static uint32_t get_next_anon_index(Context *c) {
    uint32_t result = c->next_anon_index;
    c->next_anon_index += 1;
    return result;
}

static void add_global_alias(Context *c, Buf *name, Tld *tld) {
    c->import->decls_scope->decl_table.put(name, tld);
}

static void add_global_weak_alias(Context *c, Buf *name, Tld *tld) {
    Alias *alias = c->aliases.add_one();
    alias->name = name;
    alias->tld = tld;
}

static void add_global(Context *c, Tld *tld) {
    return add_global_alias(c, tld->name, tld);
}

static Tld *get_global(Context *c, Buf *name) {
    {
        auto entry = c->import->decls_scope->decl_table.maybe_get(name);
        if (entry)
            return entry->value;
    }
    {
        auto entry = c->macro_table.maybe_get(name);
        if (entry)
            return entry->value;
    }
    return nullptr;
}

static const char *decl_name(const Decl *decl) {
    const NamedDecl *named_decl = static_cast<const NamedDecl *>(decl);
    return (const char *)named_decl->getName().bytes_begin();
}

static void parseh_init_tld(Context *c, Tld *tld, TldId id, Buf *name) {
    init_tld(tld, id, name, c->visib_mod, c->source_node, &c->import->decls_scope->base);
    tld->resolution = TldResolutionOk;
    tld->import = c->import;
}

static Tld *create_inline_fn_tld(Context *c, Buf *fn_name, TldVar *tld_var) {
    TldFn *tld_fn = allocate<TldFn>(1);
    parseh_init_tld(c, &tld_fn->base, TldIdFn, fn_name);
    tld_fn->fn_entry = ir_create_inline_fn(c->codegen, fn_name, tld_var->var, &c->import->decls_scope->base);
    return &tld_fn->base;
}

static TldVar *create_global_var(Context *c, Buf *name, ConstExprValue *var_value, bool is_const) {
    auto entry = c->import->decls_scope->decl_table.maybe_get(name);
    if (entry) {
        Tld *existing_tld = entry->value;
        assert(existing_tld->id == TldIdVar);
        return (TldVar *)existing_tld;
    }
    TldVar *tld_var = allocate<TldVar>(1);
    parseh_init_tld(c, &tld_var->base, TldIdVar, name);
    tld_var->var = add_variable(c->codegen, c->source_node, &c->import->decls_scope->base,
            name, is_const, var_value, &tld_var->base);
    c->codegen->global_vars.append(tld_var);
    return tld_var;
}

static Tld *create_global_str_lit_var(Context *c, Buf *name, Buf *value) {
    TldVar *tld_var = create_global_var(c, name, create_const_c_str_lit(c->codegen, value), true);
    return &tld_var->base;
}

static Tld *create_global_num_lit_unsigned_negative_type(Context *c, Buf *name, uint64_t x, bool negative, TypeTableEntry *type_entry) {
    ConstExprValue *var_val = create_const_unsigned_negative(type_entry, x, negative);
    TldVar *tld_var = create_global_var(c, name, var_val, true);
    return &tld_var->base;
}

static Tld *create_global_num_lit_unsigned_negative(Context *c, Buf *name, uint64_t x, bool negative) {
    return create_global_num_lit_unsigned_negative_type(c, name, x, negative, c->codegen->builtin_types.entry_num_lit_int);
}

static Tld *create_global_num_lit_float(Context *c, Buf *name, double value) {
    ConstExprValue *var_val = create_const_float(c->codegen->builtin_types.entry_num_lit_float, value);
    TldVar *tld_var = create_global_var(c, name, var_val, true);
    return &tld_var->base;
}

static ConstExprValue *create_const_int_ap(Context *c, TypeTableEntry *type, const Decl *source_decl,
        const llvm::APSInt &aps_int)
{
    if (aps_int.isSigned()) {
        if (aps_int > INT64_MAX || aps_int < INT64_MIN) {
            emit_warning(c, source_decl->getLocation(), "integer overflow\n");
            return nullptr;
        } else {
            return create_const_signed(type, aps_int.getExtValue());
        }
    } else {
        if (aps_int > INT64_MAX) {
            emit_warning(c, source_decl->getLocation(), "integer overflow\n");
            return nullptr;
        } else {
            return create_const_unsigned_negative(type, aps_int.getExtValue(), false);
        }
    }
}

static Tld *create_global_num_lit_ap(Context *c, const Decl *source_decl, Buf *name,
        const llvm::APSInt &aps_int)
{
    ConstExprValue *const_value = create_const_int_ap(c, c->codegen->builtin_types.entry_num_lit_int,
            source_decl, aps_int);
    if (!const_value)
        return nullptr;
    TldVar *tld_var = create_global_var(c, name, const_value, true);
    return &tld_var->base;
}


static Tld *add_const_type(Context *c, Buf *name, TypeTableEntry *type_entry) {
    ConstExprValue *var_value = create_const_type(c->codegen, type_entry);
    TldVar *tld_var = create_global_var(c, name, var_value, true);
    add_global(c, &tld_var->base);

    c->global_type_table.put(name, type_entry);
    return &tld_var->base;
}

static Tld *add_container_tld(Context *c, TypeTableEntry *type_entry) {
    return add_const_type(c, &type_entry->name, type_entry);
}

static bool is_c_void_type(Context *c, TypeTableEntry *type_entry) {
    return (type_entry == c->codegen->builtin_types.entry_c_void);
}

static bool qual_type_child_is_fn_proto(const QualType &qt) {
    if (qt.getTypePtr()->getTypeClass() == Type::Paren) {
        const ParenType *paren_type = static_cast<const ParenType *>(qt.getTypePtr());
        if (paren_type->getInnerType()->getTypeClass() == Type::FunctionProto) {
            return true;
        }
    } else if (qt.getTypePtr()->getTypeClass() == Type::Attributed) {
        const AttributedType *attr_type = static_cast<const AttributedType *>(qt.getTypePtr());
        return qual_type_child_is_fn_proto(attr_type->getEquivalentType());
    }
    return false;
}

static TypeTableEntry *resolve_type_with_table(Context *c, const Type *ty, const Decl *decl,
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> *type_table)
{
    switch (ty->getTypeClass()) {
        case Type::Builtin:
            {
                const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
                switch (builtin_ty->getKind()) {
                    case BuiltinType::Void:
                        return c->codegen->builtin_types.entry_c_void;
                    case BuiltinType::Bool:
                        return c->codegen->builtin_types.entry_bool;
                    case BuiltinType::Char_U:
                    case BuiltinType::UChar:
                    case BuiltinType::Char_S:
                        return c->codegen->builtin_types.entry_u8;
                    case BuiltinType::SChar:
                        return c->codegen->builtin_types.entry_i8;
                    case BuiltinType::UShort:
                        return get_c_int_type(c->codegen, CIntTypeUShort);
                    case BuiltinType::UInt:
                        return get_c_int_type(c->codegen, CIntTypeUInt);
                    case BuiltinType::ULong:
                        return get_c_int_type(c->codegen, CIntTypeULong);
                    case BuiltinType::ULongLong:
                        return get_c_int_type(c->codegen, CIntTypeULongLong);
                    case BuiltinType::Short:
                        return get_c_int_type(c->codegen, CIntTypeShort);
                    case BuiltinType::Int:
                        return get_c_int_type(c->codegen, CIntTypeInt);
                    case BuiltinType::Long:
                        return get_c_int_type(c->codegen, CIntTypeLong);
                    case BuiltinType::LongLong:
                        return get_c_int_type(c->codegen, CIntTypeLongLong);
                    case BuiltinType::UInt128:
                        return c->codegen->builtin_types.entry_u128;
                    case BuiltinType::Int128:
                        return c->codegen->builtin_types.entry_i128;
                    case BuiltinType::Float:
                        return c->codegen->builtin_types.entry_f32;
                    case BuiltinType::Double:
                        return c->codegen->builtin_types.entry_f64;
                    case BuiltinType::Float128:
                        return c->codegen->builtin_types.entry_f128;
                    case BuiltinType::LongDouble:
                        return c->codegen->builtin_types.entry_c_longdouble;
                    case BuiltinType::WChar_U:
                    case BuiltinType::Char16:
                    case BuiltinType::Char32:
                    case BuiltinType::WChar_S:
                    case BuiltinType::Half:
                    case BuiltinType::NullPtr:
                    case BuiltinType::ObjCId:
                    case BuiltinType::ObjCClass:
                    case BuiltinType::ObjCSel:
                    case BuiltinType::OMPArraySection:
                    case BuiltinType::Dependent:
                    case BuiltinType::Overload:
                    case BuiltinType::BoundMember:
                    case BuiltinType::PseudoObject:
                    case BuiltinType::UnknownAny:
                    case BuiltinType::BuiltinFn:
                    case BuiltinType::ARCUnbridgedCast:

                    case BuiltinType::OCLImage1dRO:
                    case BuiltinType::OCLImage1dArrayRO:
                    case BuiltinType::OCLImage1dBufferRO:
                    case BuiltinType::OCLImage2dRO:
                    case BuiltinType::OCLImage2dArrayRO:
                    case BuiltinType::OCLImage2dDepthRO:
                    case BuiltinType::OCLImage2dArrayDepthRO:
                    case BuiltinType::OCLImage2dMSAARO:
                    case BuiltinType::OCLImage2dArrayMSAARO:
                    case BuiltinType::OCLImage2dMSAADepthRO:
                    case BuiltinType::OCLImage2dArrayMSAADepthRO:
                    case BuiltinType::OCLImage3dRO:
                    case BuiltinType::OCLImage1dWO:
                    case BuiltinType::OCLImage1dArrayWO:
                    case BuiltinType::OCLImage1dBufferWO:
                    case BuiltinType::OCLImage2dWO:
                    case BuiltinType::OCLImage2dArrayWO:
                    case BuiltinType::OCLImage2dDepthWO:
                    case BuiltinType::OCLImage2dArrayDepthWO:
                    case BuiltinType::OCLImage2dMSAAWO:
                    case BuiltinType::OCLImage2dArrayMSAAWO:
                    case BuiltinType::OCLImage2dMSAADepthWO:
                    case BuiltinType::OCLImage2dArrayMSAADepthWO:
                    case BuiltinType::OCLImage3dWO:
                    case BuiltinType::OCLImage1dRW:
                    case BuiltinType::OCLImage1dArrayRW:
                    case BuiltinType::OCLImage1dBufferRW:
                    case BuiltinType::OCLImage2dRW:
                    case BuiltinType::OCLImage2dArrayRW:
                    case BuiltinType::OCLImage2dDepthRW:
                    case BuiltinType::OCLImage2dArrayDepthRW:
                    case BuiltinType::OCLImage2dMSAARW:
                    case BuiltinType::OCLImage2dArrayMSAARW:
                    case BuiltinType::OCLImage2dMSAADepthRW:
                    case BuiltinType::OCLImage2dArrayMSAADepthRW:
                    case BuiltinType::OCLImage3dRW:
                    case BuiltinType::OCLSampler:
                    case BuiltinType::OCLEvent:
                    case BuiltinType::OCLClkEvent:
                    case BuiltinType::OCLQueue:
                    case BuiltinType::OCLReserveID:
                        emit_warning(c, decl->getLocation(), "missed a builtin type");
                        return c->codegen->builtin_types.entry_invalid;
                }
                break;
            }
        case Type::Pointer:
            {
                const PointerType *pointer_ty = static_cast<const PointerType*>(ty);
                QualType child_qt = pointer_ty->getPointeeType();
                TypeTableEntry *child_type = resolve_qual_type(c, child_qt, decl);
                if (type_is_invalid(child_type)) {
                    emit_warning(c, decl->getLocation(), "pointer to unresolved type");
                    return c->codegen->builtin_types.entry_invalid;
                }

                if (qual_type_child_is_fn_proto(child_qt)) {
                    return get_maybe_type(c->codegen, child_type);
                }
                bool is_const = child_qt.isConstQualified();

                TypeTableEntry *non_null_pointer_type = get_pointer_to_type(c->codegen, child_type, is_const);
                return get_maybe_type(c->codegen, non_null_pointer_type);
            }
        case Type::Typedef:
            {
                const TypedefType *typedef_ty = static_cast<const TypedefType*>(ty);
                const TypedefNameDecl *typedef_decl = typedef_ty->getDecl();
                Buf *type_name = buf_create_from_str(decl_name(typedef_decl));
                if (buf_eql_str(type_name, "uint8_t")) {
                    return c->codegen->builtin_types.entry_u8;
                } else if (buf_eql_str(type_name, "int8_t")) {
                    return c->codegen->builtin_types.entry_i8;
                } else if (buf_eql_str(type_name, "uint16_t")) {
                    return c->codegen->builtin_types.entry_u16;
                } else if (buf_eql_str(type_name, "int16_t")) {
                    return c->codegen->builtin_types.entry_i16;
                } else if (buf_eql_str(type_name, "uint32_t")) {
                    return c->codegen->builtin_types.entry_u32;
                } else if (buf_eql_str(type_name, "int32_t")) {
                    return c->codegen->builtin_types.entry_i32;
                } else if (buf_eql_str(type_name, "uint64_t")) {
                    return c->codegen->builtin_types.entry_u64;
                } else if (buf_eql_str(type_name, "int64_t")) {
                    return c->codegen->builtin_types.entry_i64;
                } else if (buf_eql_str(type_name, "intptr_t")) {
                    return c->codegen->builtin_types.entry_isize;
                } else if (buf_eql_str(type_name, "uintptr_t")) {
                    return c->codegen->builtin_types.entry_usize;
                } else {
                    auto entry = type_table->maybe_get(type_name);
                    if (entry) {
                        if (type_is_invalid(entry->value)) {
                            return c->codegen->builtin_types.entry_invalid;
                        } else {
                            return entry->value;
                        }
                    } else {
                        return c->codegen->builtin_types.entry_invalid;
                    }
                }
            }
        case Type::Elaborated:
            {
                const ElaboratedType *elaborated_ty = static_cast<const ElaboratedType*>(ty);
                switch (elaborated_ty->getKeyword()) {
                    case ETK_Struct:
                        return resolve_qual_type_with_table(c, elaborated_ty->getNamedType(),
                                decl, &c->struct_type_table);
                    case ETK_Enum:
                        return resolve_qual_type_with_table(c, elaborated_ty->getNamedType(),
                                decl, &c->enum_type_table);
                    case ETK_Interface:
                    case ETK_Union:
                    case ETK_Class:
                    case ETK_Typename:
                    case ETK_None:
                        emit_warning(c, decl->getLocation(), "unsupported elaborated type");
                        return c->codegen->builtin_types.entry_invalid;
                }
            }
        case Type::FunctionProto:
            {
                const FunctionProtoType *fn_proto_ty = static_cast<const FunctionProtoType*>(ty);

                switch (fn_proto_ty->getCallConv()) {
                    case CC_C:           // __attribute__((cdecl))
                        break;
                    case CC_X86StdCall:  // __attribute__((stdcall))
                        emit_warning(c, decl->getLocation(), "function type has x86 stdcall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86FastCall: // __attribute__((fastcall))
                        emit_warning(c, decl->getLocation(), "function type has x86 fastcall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86ThisCall: // __attribute__((thiscall))
                        emit_warning(c, decl->getLocation(), "function type has x86 thiscall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86VectorCall: // __attribute__((vectorcall))
                        emit_warning(c, decl->getLocation(), "function type has x86 vectorcall calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86Pascal:   // __attribute__((pascal))
                        emit_warning(c, decl->getLocation(), "function type has x86 pascal calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_Win64: // __attribute__((ms_abi))
                        emit_warning(c, decl->getLocation(), "function type has win64 calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86_64SysV:  // __attribute__((sysv_abi))
                        emit_warning(c, decl->getLocation(), "function type has x86 64sysv calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_X86RegCall:
                        emit_warning(c, decl->getLocation(), "function type has x86 reg calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_AAPCS:       // __attribute__((pcs("aapcs")))
                        emit_warning(c, decl->getLocation(), "function type has aapcs calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_AAPCS_VFP:   // __attribute__((pcs("aapcs-vfp")))
                        emit_warning(c, decl->getLocation(), "function type has aapcs-vfp calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_IntelOclBicc: // __attribute__((intel_ocl_bicc))
                        emit_warning(c, decl->getLocation(), "function type has intel_ocl_bicc calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_SpirFunction: // default for OpenCL functions on SPIR target
                        emit_warning(c, decl->getLocation(), "function type has SPIR function calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_OpenCLKernel:
                        emit_warning(c, decl->getLocation(), "function type has OpenCLKernel calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_Swift:
                        emit_warning(c, decl->getLocation(), "function type has Swift calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_PreserveMost:
                        emit_warning(c, decl->getLocation(), "function type has PreserveMost calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                    case CC_PreserveAll:
                        emit_warning(c, decl->getLocation(), "function type has PreserveAll calling convention");
                        return c->codegen->builtin_types.entry_invalid;
                }

                FnTypeId fn_type_id = {0};
                fn_type_id.cc = CallingConventionC;
                fn_type_id.is_var_args = fn_proto_ty->isVariadic();
                fn_type_id.param_count = fn_proto_ty->getNumParams();


                if (fn_proto_ty->getNoReturnAttr()) {
                    fn_type_id.return_type = c->codegen->builtin_types.entry_unreachable;
                } else {
                    fn_type_id.return_type = resolve_qual_type(c, fn_proto_ty->getReturnType(), decl);
                    if (type_is_invalid(fn_type_id.return_type)) {
                        emit_warning(c, decl->getLocation(), "unresolved function proto return type");
                        return c->codegen->builtin_types.entry_invalid;
                    }
                    // convert c_void to actual void (only for return type)
                    if (is_c_void_type(c, fn_type_id.return_type)) {
                        fn_type_id.return_type = c->codegen->builtin_types.entry_void;
                    }
                }

                fn_type_id.param_info = allocate_nonzero<FnTypeParamInfo>(fn_type_id.param_count);
                for (size_t i = 0; i < fn_type_id.param_count; i += 1) {
                    QualType qt = fn_proto_ty->getParamType(i);
                    TypeTableEntry *param_type = resolve_qual_type(c, qt, decl);

                    if (type_is_invalid(param_type)) {
                        emit_warning(c, decl->getLocation(), "unresolved function proto parameter type");
                        return c->codegen->builtin_types.entry_invalid;
                    }

                    FnTypeParamInfo *param_info = &fn_type_id.param_info[i];
                    param_info->type = param_type;
                    param_info->is_noalias = qt.isRestrictQualified();
                }

                return get_fn_type(c->codegen, &fn_type_id);
            }
        case Type::Record:
            {
                const RecordType *record_ty = static_cast<const RecordType*>(ty);
                return resolve_record_decl(c, record_ty->getDecl());
            }
        case Type::Enum:
            {
                const EnumType *enum_ty = static_cast<const EnumType*>(ty);
                return resolve_enum_decl(c, enum_ty->getDecl());
            }
        case Type::ConstantArray:
            {
                const ConstantArrayType *const_arr_ty = static_cast<const ConstantArrayType *>(ty);
                TypeTableEntry *child_type = resolve_qual_type(c, const_arr_ty->getElementType(), decl);
                if (child_type->id == TypeTableEntryIdInvalid) {
                    emit_warning(c, decl->getLocation(), "unresolved array element type");
                    return child_type;
                }
                uint64_t size = const_arr_ty->getSize().getLimitedValue();
                return get_array_type(c->codegen, child_type, size);
            }
        case Type::Paren:
            {
                const ParenType *paren_ty = static_cast<const ParenType *>(ty);
                return resolve_qual_type(c, paren_ty->getInnerType(), decl);
            }
        case Type::Decayed:
            {
                const DecayedType *decayed_ty = static_cast<const DecayedType *>(ty);
                return resolve_qual_type(c, decayed_ty->getDecayedType(), decl);
            }
        case Type::Attributed:
            {
                const AttributedType *attributed_ty = static_cast<const AttributedType *>(ty);
                return resolve_qual_type(c, attributed_ty->getEquivalentType(), decl);
            }
        case Type::BlockPointer:
        case Type::LValueReference:
        case Type::RValueReference:
        case Type::MemberPointer:
        case Type::IncompleteArray:
        case Type::VariableArray:
        case Type::DependentSizedArray:
        case Type::DependentSizedExtVector:
        case Type::Vector:
        case Type::ExtVector:
        case Type::FunctionNoProto:
        case Type::UnresolvedUsing:
        case Type::Adjusted:
        case Type::TypeOfExpr:
        case Type::TypeOf:
        case Type::Decltype:
        case Type::UnaryTransform:
        case Type::TemplateTypeParm:
        case Type::SubstTemplateTypeParm:
        case Type::SubstTemplateTypeParmPack:
        case Type::TemplateSpecialization:
        case Type::Auto:
        case Type::InjectedClassName:
        case Type::DependentName:
        case Type::DependentTemplateSpecialization:
        case Type::PackExpansion:
        case Type::ObjCObject:
        case Type::ObjCInterface:
        case Type::Complex:
        case Type::ObjCObjectPointer:
        case Type::Atomic:
        case Type::Pipe:
        case Type::ObjCTypeParam:
        case Type::DeducedTemplateSpecialization:
            emit_warning(c, decl->getLocation(), "missed a '%s' type", ty->getTypeClassName());
            return c->codegen->builtin_types.entry_invalid;
    }
    zig_unreachable();
}

static TypeTableEntry *resolve_qual_type_with_table(Context *c, QualType qt, const Decl *decl,
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> *type_table)
{
    return resolve_type_with_table(c, qt.getTypePtr(), decl, type_table);
}

static TypeTableEntry *resolve_qual_type(Context *c, QualType qt, const Decl *decl) {
    return resolve_qual_type_with_table(c, qt, decl, &c->global_type_table);
}

#include "ast_render.hpp"

static bool c_is_signed_integer(Context *c, QualType qt) {
    const Type *c_type = qt.getTypePtr();
    if (c_type->getTypeClass() != Type::Builtin)
        return false;
    const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(c_type);
    switch (builtin_ty->getKind()) {
        case BuiltinType::SChar:
        case BuiltinType::Short:
        case BuiltinType::Int:
        case BuiltinType::Long:
        case BuiltinType::LongLong:
        case BuiltinType::Int128:
        case BuiltinType::WChar_S:
            return true;
        default: 
            return false;
    }
}

static bool c_is_unsigned_integer(Context *c, QualType qt) {
    const Type *c_type = qt.getTypePtr();
    if (c_type->getTypeClass() != Type::Builtin)
        return false;
    const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(c_type);
    switch (builtin_ty->getKind()) {
        case BuiltinType::Char_U:
        case BuiltinType::UChar:
        case BuiltinType::Char_S:
        case BuiltinType::UShort:
        case BuiltinType::UInt:
        case BuiltinType::ULong:
        case BuiltinType::ULongLong:
        case BuiltinType::UInt128:
        case BuiltinType::WChar_U:
            return true;
        default: 
            return false;
    }
}

static bool c_is_float(Context *c, QualType qt) {
    const Type *c_type = qt.getTypePtr();
    if (c_type->getTypeClass() != Type::Builtin)
        return false;
    const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(c_type);
    switch (builtin_ty->getKind()) {
        case BuiltinType::Half:
        case BuiltinType::Float:
        case BuiltinType::Double:
        case BuiltinType::Float128:
        case BuiltinType::LongDouble:
            return true;
        default: 
            return false;
    }
}

static AstNode * trans_stmt(Context *c, AstNode *block, Stmt *stmt);
static AstNode * trans_create_node(Context *c, NodeType id);
static AstNode * trans_qual_type(Context *c, QualType qt, const SourceLocation &source_loc);

static AstNode * trans_expr(Context *c, AstNode *block, Expr *expr) {
    return trans_stmt(c, block, expr);
}

static AstNode *trans_create_symbol_node(Context *c, const char * name) {
    AstNode *node = trans_create_node(c, NodeTypeSymbol);
    node->data.symbol_expr.symbol = buf_create_from_str(name);
    return node;
}

static AstNode *trans_type_with_table(Context *c, const Type *ty, const SourceLocation &source_loc,
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> *type_table)
{
    switch (ty->getTypeClass()) {
        case Type::Builtin:
            {
                const BuiltinType *builtin_ty = static_cast<const BuiltinType*>(ty);
                switch (builtin_ty->getKind()) {
                    case BuiltinType::Void:
                        return trans_create_symbol_node(c, "c_void");
                    case BuiltinType::Bool:
                        return trans_create_symbol_node(c, "bool");
                    case BuiltinType::Char_U:
                    case BuiltinType::UChar:
                    case BuiltinType::Char_S:
                        return trans_create_symbol_node(c, "u8");
                    case BuiltinType::SChar:
                        return trans_create_symbol_node(c, "i8");
                    case BuiltinType::UShort:
                        return trans_create_symbol_node(c, "c_ushort");
                    case BuiltinType::UInt:
                        return trans_create_symbol_node(c, "c_uint");
                    case BuiltinType::ULong:
                        return trans_create_symbol_node(c, "c_ulong");
                    case BuiltinType::ULongLong:
                        return trans_create_symbol_node(c, "c_ulonglong");
                    case BuiltinType::Short:
                        return trans_create_symbol_node(c, "c_short");
                    case BuiltinType::Int:
                        return trans_create_symbol_node(c, "c_int");
                    case BuiltinType::Long:
                        return trans_create_symbol_node(c, "c_long");
                    case BuiltinType::LongLong:
                        return trans_create_symbol_node(c, "c_longlong");
                    case BuiltinType::UInt128:
                        return trans_create_symbol_node(c, "u128");
                    case BuiltinType::Int128:
                        return trans_create_symbol_node(c, "i128");
                    case BuiltinType::Float:
                        return trans_create_symbol_node(c, "f32");
                    case BuiltinType::Double:
                        return trans_create_symbol_node(c, "f64");
                    case BuiltinType::Float128:
                        return trans_create_symbol_node(c, "f128");
                    case BuiltinType::LongDouble:
                        return trans_create_symbol_node(c, "c_longdouble");
                    case BuiltinType::WChar_U:
                    case BuiltinType::Char16:
                    case BuiltinType::Char32:
                    case BuiltinType::WChar_S:
                    case BuiltinType::Half:
                    case BuiltinType::NullPtr:
                    case BuiltinType::ObjCId:
                    case BuiltinType::ObjCClass:
                    case BuiltinType::ObjCSel:
                    case BuiltinType::OMPArraySection:
                    case BuiltinType::Dependent:
                    case BuiltinType::Overload:
                    case BuiltinType::BoundMember:
                    case BuiltinType::PseudoObject:
                    case BuiltinType::UnknownAny:
                    case BuiltinType::BuiltinFn:
                    case BuiltinType::ARCUnbridgedCast:

                    case BuiltinType::OCLImage1dRO:
                    case BuiltinType::OCLImage1dArrayRO:
                    case BuiltinType::OCLImage1dBufferRO:
                    case BuiltinType::OCLImage2dRO:
                    case BuiltinType::OCLImage2dArrayRO:
                    case BuiltinType::OCLImage2dDepthRO:
                    case BuiltinType::OCLImage2dArrayDepthRO:
                    case BuiltinType::OCLImage2dMSAARO:
                    case BuiltinType::OCLImage2dArrayMSAARO:
                    case BuiltinType::OCLImage2dMSAADepthRO:
                    case BuiltinType::OCLImage2dArrayMSAADepthRO:
                    case BuiltinType::OCLImage3dRO:
                    case BuiltinType::OCLImage1dWO:
                    case BuiltinType::OCLImage1dArrayWO:
                    case BuiltinType::OCLImage1dBufferWO:
                    case BuiltinType::OCLImage2dWO:
                    case BuiltinType::OCLImage2dArrayWO:
                    case BuiltinType::OCLImage2dDepthWO:
                    case BuiltinType::OCLImage2dArrayDepthWO:
                    case BuiltinType::OCLImage2dMSAAWO:
                    case BuiltinType::OCLImage2dArrayMSAAWO:
                    case BuiltinType::OCLImage2dMSAADepthWO:
                    case BuiltinType::OCLImage2dArrayMSAADepthWO:
                    case BuiltinType::OCLImage3dWO:
                    case BuiltinType::OCLImage1dRW:
                    case BuiltinType::OCLImage1dArrayRW:
                    case BuiltinType::OCLImage1dBufferRW:
                    case BuiltinType::OCLImage2dRW:
                    case BuiltinType::OCLImage2dArrayRW:
                    case BuiltinType::OCLImage2dDepthRW:
                    case BuiltinType::OCLImage2dArrayDepthRW:
                    case BuiltinType::OCLImage2dMSAARW:
                    case BuiltinType::OCLImage2dArrayMSAARW:
                    case BuiltinType::OCLImage2dMSAADepthRW:
                    case BuiltinType::OCLImage2dArrayMSAADepthRW:
                    case BuiltinType::OCLImage3dRW:
                    case BuiltinType::OCLSampler:
                    case BuiltinType::OCLEvent:
                    case BuiltinType::OCLClkEvent:
                    case BuiltinType::OCLQueue:
                    case BuiltinType::OCLReserveID:
                        zig_panic("TODO more c type");
                }
                break;
            }
        case Type::Pointer:
            {
                const PointerType *pointer_ty = static_cast<const PointerType*>(ty);
                QualType child_qt = pointer_ty->getPointeeType();
                AstNode *child_node = trans_qual_type(c, child_qt, source_loc);
                if (child_node == nullptr) return nullptr;

                if (qual_type_child_is_fn_proto(child_qt)) {
                    zig_panic("TODO pointer to function proto");
                }

                AstNode *pointer_node = trans_create_node(c, NodeTypeAddrOfExpr);
                pointer_node->data.addr_of_expr.is_const = child_qt.isConstQualified();
                pointer_node->data.addr_of_expr.is_volatile = child_qt.isVolatileQualified();
                pointer_node->data.addr_of_expr.op_expr = child_node;

                AstNode *maybe_node = trans_create_node(c, NodeTypePrefixOpExpr);
                maybe_node->data.prefix_op_expr.prefix_op = PrefixOpMaybe;
                maybe_node->data.prefix_op_expr.primary_expr = pointer_node;
                return maybe_node;
            }
        case Type::Typedef:
            zig_panic("TODO typedef");
        case Type::Elaborated:
            zig_panic("TODO elaborated");
        case Type::FunctionProto:
            zig_panic("TODO FunctionProto");
        case Type::Record:
            zig_panic("TODO Record");
        case Type::Enum:
            zig_panic("TODO Enum");
        case Type::ConstantArray:
            zig_panic("TODO ConstantArray");
        case Type::Paren:
            zig_panic("TODO Paren");
        case Type::Decayed:
            zig_panic("TODO Decayed");
        case Type::Attributed:
            zig_panic("TODO Attributed");
        case Type::BlockPointer:
        case Type::LValueReference:
        case Type::RValueReference:
        case Type::MemberPointer:
        case Type::IncompleteArray:
        case Type::VariableArray:
        case Type::DependentSizedArray:
        case Type::DependentSizedExtVector:
        case Type::Vector:
        case Type::ExtVector:
        case Type::FunctionNoProto:
        case Type::UnresolvedUsing:
        case Type::Adjusted:
        case Type::TypeOfExpr:
        case Type::TypeOf:
        case Type::Decltype:
        case Type::UnaryTransform:
        case Type::TemplateTypeParm:
        case Type::SubstTemplateTypeParm:
        case Type::SubstTemplateTypeParmPack:
        case Type::TemplateSpecialization:
        case Type::Auto:
        case Type::InjectedClassName:
        case Type::DependentName:
        case Type::DependentTemplateSpecialization:
        case Type::PackExpansion:
        case Type::ObjCObject:
        case Type::ObjCInterface:
        case Type::Complex:
        case Type::ObjCObjectPointer:
        case Type::Atomic:
        case Type::Pipe:
        case Type::ObjCTypeParam:
        case Type::DeducedTemplateSpecialization:
            zig_panic("TODO more c type aoeu");
    }
    zig_unreachable();
}

static AstNode * trans_qual_type_with_table(Context *c, QualType qt, const SourceLocation &source_loc,
        HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> *type_table)
{
    return trans_type_with_table(c, qt.getTypePtr(), source_loc, type_table);
}

static AstNode * trans_qual_type(Context *c, QualType qt, const SourceLocation &source_loc) {
    return trans_qual_type_with_table(c, qt, source_loc, &c->global_type_table2);
}

static AstNode * trans_create_node(Context *c, NodeType id) {
    AstNode *node = allocate<AstNode>(1);
    node->type = id;
    node->owner = c->import;
    // TODO line/column. mapping to C file??
    return node;
}

static AstNode * trans_compound_stmt(Context *c, AstNode *parent, CompoundStmt *stmt) {
    AstNode *child_block = trans_create_node(c, NodeTypeBlock);
    for (CompoundStmt::body_iterator it = stmt->body_begin(), end_it = stmt->body_end(); it != end_it; ++it) {
        AstNode *child_node = trans_stmt(c, child_block, *it);
        if (child_node != nullptr)
            child_block->data.block.statements.append(child_node);
    }
    return child_block;
}

static AstNode *trans_return_stmt(Context *c, AstNode *block, ReturnStmt *stmt) {
    Expr *value_expr = stmt->getRetValue();
    if (value_expr == nullptr) {
        zig_panic("TODO handle C return void");
    } else {
        AstNode *return_node = trans_create_node(c, NodeTypeReturnExpr);
        return_node->data.return_expr.expr = trans_expr(c, block, value_expr);
        return return_node;
    }
}

static void aps_int_to_bigint(Context *c, const llvm::APSInt &aps_int, BigInt *bigint) {
    // TODO respect actually big integers
    if (aps_int.isSigned()) {
        if (aps_int > INT64_MAX || aps_int < INT64_MIN) {
            zig_panic("TODO actually bigint in C");
        } else {
            bigint_init_signed(bigint, aps_int.getExtValue());
        }
    } else {
        if (aps_int > INT64_MAX) {
            zig_panic("TODO actually bigint in C");
        } else {
            bigint_init_unsigned(bigint, aps_int.getExtValue());
        }
    }
}

static AstNode * trans_integer_literal(Context *c, IntegerLiteral *stmt) {
    AstNode *node = trans_create_node(c, NodeTypeIntLiteral);
    llvm::APSInt result;
    if (!stmt->EvaluateAsInt(result, *c->ctx)) {
        fprintf(stderr, "TODO unable to convert integer literal to zig\n");
    }
    node->data.int_literal.bigint = allocate<BigInt>(1);
    aps_int_to_bigint(c, result, node->data.int_literal.bigint);
    return node;
}

static AstNode * trans_conditional_operator(Context *c, AstNode *block, ConditionalOperator *stmt) {
    AstNode *node = trans_create_node(c, NodeTypeIfBoolExpr);

    Expr *cond_expr = stmt->getCond();
    Expr *true_expr = stmt->getTrueExpr();
    Expr *false_expr = stmt->getFalseExpr();

    node->data.if_bool_expr.condition = trans_expr(c, block, cond_expr);
    node->data.if_bool_expr.then_block = trans_expr(c, block, true_expr);
    node->data.if_bool_expr.else_node = trans_expr(c, block, false_expr);

    return node;
}

static AstNode * trans_create_bin_op(Context *c, AstNode *block, Expr *lhs, BinOpType bin_op, Expr *rhs) {
    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
    node->data.bin_op_expr.bin_op = bin_op;
    node->data.bin_op_expr.op1 = trans_expr(c, block, lhs);
    node->data.bin_op_expr.op2 = trans_expr(c, block, rhs);
    return node;
}

static AstNode * trans_binary_operator(Context *c, AstNode *block, BinaryOperator *stmt) {
    switch (stmt->getOpcode()) {
        case BO_PtrMemD:
            zig_panic("TODO handle more C binary operators: BO_PtrMemD");
        case BO_PtrMemI:
            zig_panic("TODO handle more C binary operators: BO_PtrMemI");
        case BO_Mul:
            zig_panic("TODO handle more C binary operators: BO_Mul");
        case BO_Div:
            zig_panic("TODO handle more C binary operators: BO_Div");
        case BO_Rem:
            zig_panic("TODO handle more C binary operators: BO_Rem");
        case BO_Add:
            zig_panic("TODO handle more C binary operators: BO_Add");
        case BO_Sub:
            zig_panic("TODO handle more C binary operators: BO_Sub");
        case BO_Shl:
            zig_panic("TODO handle more C binary operators: BO_Shl");
        case BO_Shr:
            zig_panic("TODO handle more C binary operators: BO_Shr");
        case BO_LT:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpLessThan, stmt->getRHS());
        case BO_GT:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpGreaterThan, stmt->getRHS());
        case BO_LE:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpLessOrEq, stmt->getRHS());
        case BO_GE:
            return trans_create_bin_op(c, block, stmt->getLHS(), BinOpTypeCmpGreaterOrEq, stmt->getRHS());
        case BO_EQ:
            zig_panic("TODO handle more C binary operators: BO_EQ");
        case BO_NE:
            zig_panic("TODO handle more C binary operators: BO_NE");
        case BO_And:
            zig_panic("TODO handle more C binary operators: BO_And");
        case BO_Xor:
            zig_panic("TODO handle more C binary operators: BO_Xor");
        case BO_Or:
            zig_panic("TODO handle more C binary operators: BO_Or");
        case BO_LAnd:
            zig_panic("TODO handle more C binary operators: BO_LAnd");
        case BO_LOr:
            zig_panic("TODO handle more C binary operators: BO_LOr");
        case BO_Assign:
            zig_panic("TODO handle more C binary operators: BO_Assign");
        case BO_MulAssign:
            zig_panic("TODO handle more C binary operators: BO_MulAssign");
        case BO_DivAssign:
            zig_panic("TODO handle more C binary operators: BO_DivAssign");
        case BO_RemAssign:
            zig_panic("TODO handle more C binary operators: BO_RemAssign");
        case BO_AddAssign:
            zig_panic("TODO handle more C binary operators: BO_AddAssign");
        case BO_SubAssign:
            zig_panic("TODO handle more C binary operators: BO_SubAssign");
        case BO_ShlAssign:
            zig_panic("TODO handle more C binary operators: BO_ShlAssign");
        case BO_ShrAssign:
            zig_panic("TODO handle more C binary operators: BO_ShrAssign");
        case BO_AndAssign:
            zig_panic("TODO handle more C binary operators: BO_AndAssign");
        case BO_XorAssign:
            zig_panic("TODO handle more C binary operators: BO_XorAssign");
        case BO_OrAssign:
            zig_panic("TODO handle more C binary operators: BO_OrAssign");
        case BO_Comma:
            zig_panic("TODO handle more C binary operators: BO_Comma");
    }

    zig_unreachable();
}

static AstNode * trans_implicit_cast_expr(Context *c, AstNode *block, ImplicitCastExpr *stmt) {
    switch (stmt->getCastKind()) {
        case CK_LValueToRValue:
            return trans_expr(c, block, stmt->getSubExpr());
        case CK_IntegralCast:
            {
                AstNode *node = trans_create_node(c, NodeTypeFnCallExpr);
                node->data.fn_call_expr.fn_ref_expr = trans_create_symbol_node(c, "bitCast");
                node->data.fn_call_expr.is_builtin = true;
                node->data.fn_call_expr.params.append(trans_qual_type(c, stmt->getType(), stmt->getExprLoc()));
                node->data.fn_call_expr.params.append(trans_expr(c, block, stmt->getSubExpr()));
                return node;
            }
        case CK_Dependent:
            zig_panic("TODO handle C translation cast CK_Dependent");
        case CK_BitCast:
            zig_panic("TODO handle C translation cast CK_BitCast");
        case CK_LValueBitCast:
            zig_panic("TODO handle C translation cast CK_LValueBitCast");
        case CK_NoOp:
            zig_panic("TODO handle C translation cast CK_NoOp");
        case CK_BaseToDerived:
            zig_panic("TODO handle C translation cast CK_BaseToDerived");
        case CK_DerivedToBase:
            zig_panic("TODO handle C translation cast CK_DerivedToBase");
        case CK_UncheckedDerivedToBase:
            zig_panic("TODO handle C translation cast CK_UncheckedDerivedToBase");
        case CK_Dynamic:
            zig_panic("TODO handle C translation cast CK_Dynamic");
        case CK_ToUnion:
            zig_panic("TODO handle C translation cast CK_ToUnion");
        case CK_ArrayToPointerDecay:
            zig_panic("TODO handle C translation cast CK_ArrayToPointerDecay");
        case CK_FunctionToPointerDecay:
            zig_panic("TODO handle C translation cast CK_FunctionToPointerDecay");
        case CK_NullToPointer:
            zig_panic("TODO handle C translation cast CK_NullToPointer");
        case CK_NullToMemberPointer:
            zig_panic("TODO handle C translation cast CK_NullToMemberPointer");
        case CK_BaseToDerivedMemberPointer:
            zig_panic("TODO handle C translation cast CK_BaseToDerivedMemberPointer");
        case CK_DerivedToBaseMemberPointer:
            zig_panic("TODO handle C translation cast CK_DerivedToBaseMemberPointer");
        case CK_MemberPointerToBoolean:
            zig_panic("TODO handle C translation cast CK_MemberPointerToBoolean");
        case CK_ReinterpretMemberPointer:
            zig_panic("TODO handle C translation cast CK_ReinterpretMemberPointer");
        case CK_UserDefinedConversion:
            zig_panic("TODO handle C translation cast CK_UserDefinedConversion");
        case CK_ConstructorConversion:
            zig_panic("TODO handle C translation cast CK_ConstructorConversion");
        case CK_IntegralToPointer:
            zig_panic("TODO handle C translation cast CK_IntegralToPointer");
        case CK_PointerToIntegral:
            zig_panic("TODO handle C translation cast CK_PointerToIntegral");
        case CK_PointerToBoolean:
            zig_panic("TODO handle C translation cast CK_PointerToBoolean");
        case CK_ToVoid:
            zig_panic("TODO handle C translation cast CK_ToVoid");
        case CK_VectorSplat:
            zig_panic("TODO handle C translation cast CK_VectorSplat");
        case CK_IntegralToBoolean:
            zig_panic("TODO handle C translation cast CK_IntegralToBoolean");
        case CK_IntegralToFloating:
            zig_panic("TODO handle C translation cast CK_IntegralToFloating");
        case CK_FloatingToIntegral:
            zig_panic("TODO handle C translation cast CK_FloatingToIntegral");
        case CK_FloatingToBoolean:
            zig_panic("TODO handle C translation cast CK_FloatingToBoolean");
        case CK_BooleanToSignedIntegral:
            zig_panic("TODO handle C translation cast CK_BooleanToSignedIntegral");
        case CK_FloatingCast:
            zig_panic("TODO handle C translation cast CK_FloatingCast");
        case CK_CPointerToObjCPointerCast:
            zig_panic("TODO handle C translation cast CK_CPointerToObjCPointerCast");
        case CK_BlockPointerToObjCPointerCast:
            zig_panic("TODO handle C translation cast CK_BlockPointerToObjCPointerCast");
        case CK_AnyPointerToBlockPointerCast:
            zig_panic("TODO handle C translation cast CK_AnyPointerToBlockPointerCast");
        case CK_ObjCObjectLValueCast:
            zig_panic("TODO handle C translation cast CK_ObjCObjectLValueCast");
        case CK_FloatingRealToComplex:
            zig_panic("TODO handle C translation cast CK_FloatingRealToComplex");
        case CK_FloatingComplexToReal:
            zig_panic("TODO handle C translation cast CK_FloatingComplexToReal");
        case CK_FloatingComplexToBoolean:
            zig_panic("TODO handle C translation cast CK_FloatingComplexToBoolean");
        case CK_FloatingComplexCast:
            zig_panic("TODO handle C translation cast CK_FloatingComplexCast");
        case CK_FloatingComplexToIntegralComplex:
            zig_panic("TODO handle C translation cast CK_FloatingComplexToIntegralComplex");
        case CK_IntegralRealToComplex:
            zig_panic("TODO handle C translation cast CK_IntegralRealToComplex");
        case CK_IntegralComplexToReal:
            zig_panic("TODO handle C translation cast CK_IntegralComplexToReal");
        case CK_IntegralComplexToBoolean:
            zig_panic("TODO handle C translation cast CK_IntegralComplexToBoolean");
        case CK_IntegralComplexCast:
            zig_panic("TODO handle C translation cast CK_IntegralComplexCast");
        case CK_IntegralComplexToFloatingComplex:
            zig_panic("TODO handle C translation cast CK_IntegralComplexToFloatingComplex");
        case CK_ARCProduceObject:
            zig_panic("TODO handle C translation cast CK_ARCProduceObject");
        case CK_ARCConsumeObject:
            zig_panic("TODO handle C translation cast CK_ARCConsumeObject");
        case CK_ARCReclaimReturnedObject:
            zig_panic("TODO handle C translation cast CK_ARCReclaimReturnedObject");
        case CK_ARCExtendBlockObject:
            zig_panic("TODO handle C translation cast CK_ARCExtendBlockObject");
        case CK_AtomicToNonAtomic:
            zig_panic("TODO handle C translation cast CK_AtomicToNonAtomic");
        case CK_NonAtomicToAtomic:
            zig_panic("TODO handle C translation cast CK_NonAtomicToAtomic");
        case CK_CopyAndAutoreleaseBlockObject:
            zig_panic("TODO handle C translation cast CK_CopyAndAutoreleaseBlockObject");
        case CK_BuiltinFnToFnPtr:
            zig_panic("TODO handle C translation cast CK_BuiltinFnToFnPtr");
        case CK_ZeroToOCLEvent:
            zig_panic("TODO handle C translation cast CK_ZeroToOCLEvent");
        case CK_ZeroToOCLQueue:
            zig_panic("TODO handle C translation cast CK_ZeroToOCLQueue");
        case CK_AddressSpaceConversion:
            zig_panic("TODO handle C translation cast CK_AddressSpaceConversion");
        case CK_IntToOCLSampler:
            zig_panic("TODO handle C translation cast CK_IntToOCLSampler");
    }
    zig_unreachable();
}

static AstNode * trans_decl_ref_expr(Context *c, DeclRefExpr *stmt) {
    ValueDecl *value_decl = stmt->getDecl();
    const char *name = decl_name(value_decl);

    AstNode *node = trans_create_node(c, NodeTypeSymbol);
    node->data.symbol_expr.symbol = buf_create_from_str(name);
    return node;
}

static AstNode * trans_create_num_lit_node_unsigned(Context *c, Stmt *stmt, uint64_t x) {
    AstNode *node = trans_create_node(c, NodeTypeIntLiteral);
    node->data.int_literal.bigint = allocate<BigInt>(1);
    bigint_init_unsigned(node->data.int_literal.bigint, x);
    return node;
}

static AstNode * trans_unary_operator(Context *c, AstNode *block, UnaryOperator *stmt) {
    switch (stmt->getOpcode()) {
        case UO_PostInc:
            zig_panic("TODO handle C translation UO_PostInc");
        case UO_PostDec:
            zig_panic("TODO handle C translation UO_PostDec");
        case UO_PreInc:
            zig_panic("TODO handle C translation UO_PreInc");
        case UO_PreDec:
            zig_panic("TODO handle C translation UO_PreDec");
        case UO_AddrOf:
            zig_panic("TODO handle C translation UO_AddrOf");
        case UO_Deref:
            zig_panic("TODO handle C translation UO_Deref");
        case UO_Plus:
            zig_panic("TODO handle C translation UO_Plus");
        case UO_Minus:
            {
                Expr *op_expr = stmt->getSubExpr();
                if (c_is_signed_integer(c, op_expr->getType()) || c_is_float(c, op_expr->getType())) {
                    AstNode *node = trans_create_node(c, NodeTypePrefixOpExpr);
                    node->data.prefix_op_expr.prefix_op = PrefixOpNegation;
                    node->data.prefix_op_expr.primary_expr = trans_expr(c, block, op_expr);
                    return node;
                } else if (c_is_unsigned_integer(c, op_expr->getType())) {
                    // we gotta emit 0 -% x
                    AstNode *node = trans_create_node(c, NodeTypeBinOpExpr);
                    node->data.bin_op_expr.op1 = trans_create_num_lit_node_unsigned(c, stmt, 0);
                    node->data.bin_op_expr.op2 = trans_expr(c, block, op_expr);
                    node->data.bin_op_expr.bin_op = BinOpTypeSubWrap;
                    return node;
                } else {
                    zig_panic("TODO translate C negation with non float non integer");
                }
            }
        case UO_Not:
            zig_panic("TODO handle C translation UO_Not");
        case UO_LNot:
            zig_panic("TODO handle C translation UO_LNot");
        case UO_Real:
            zig_panic("TODO handle C translation UO_Real");
        case UO_Imag:
            zig_panic("TODO handle C translation UO_Imag");
        case UO_Extension:
            zig_panic("TODO handle C translation UO_Extension");
        case UO_Coawait:
            zig_panic("TODO handle C translation UO_Coawait");
    }
    zig_unreachable();
}

static AstNode * trans_local_declaration(Context *c, AstNode *block, DeclStmt *stmt) {
    for (auto iter = stmt->decl_begin(); iter != stmt->decl_end(); iter++) {
        Decl *decl = *iter;
        switch (decl->getKind()) {
            case Decl::Var: {
                VarDecl *var_decl = (VarDecl *)decl;
                AstNode *node = trans_create_node(c, NodeTypeVariableDeclaration);
                node->data.variable_declaration.symbol = buf_create_from_str(decl_name(var_decl));
                QualType qual_type = var_decl->getTypeSourceInfo()->getType();
                node->data.variable_declaration.is_const = qual_type.isConstQualified();
                node->data.variable_declaration.type = trans_qual_type(c, qual_type, stmt->getStartLoc());
                if (var_decl->hasInit()) {
                    node->data.variable_declaration.expr = trans_expr(c, block, var_decl->getInit());
                }

                block->data.block.statements.append(node);
                continue;
            }

            case Decl::AccessSpec:
                zig_panic("TODO handle decl kind AccessSpec");
            case Decl::Block:
                zig_panic("TODO handle decl kind Block");
            case Decl::Captured:
                zig_panic("TODO handle decl kind Captured");
            case Decl::ClassScopeFunctionSpecialization:
                zig_panic("TODO handle decl kind ClassScopeFunctionSpecialization");
            case Decl::Empty:
                zig_panic("TODO handle decl kind Empty");
            case Decl::Export:
                zig_panic("TODO handle decl kind Export");
            case Decl::ExternCContext:
                zig_panic("TODO handle decl kind ExternCContext");
            case Decl::FileScopeAsm:
                zig_panic("TODO handle decl kind FileScopeAsm");
            case Decl::Friend:
                zig_panic("TODO handle decl kind Friend");
            case Decl::FriendTemplate:
                zig_panic("TODO handle decl kind FriendTemplate");
            case Decl::Import:
                zig_panic("TODO handle decl kind Import");
            case Decl::LinkageSpec:
                zig_panic("TODO handle decl kind LinkageSpec");
            case Decl::Label:
                zig_panic("TODO handle decl kind Label");
            case Decl::Namespace:
                zig_panic("TODO handle decl kind Namespace");
            case Decl::NamespaceAlias:
                zig_panic("TODO handle decl kind NamespaceAlias");
            case Decl::ObjCCompatibleAlias:
                zig_panic("TODO handle decl kind ObjCCompatibleAlias");
            case Decl::ObjCCategory:
                zig_panic("TODO handle decl kind ObjCCategory");
            case Decl::ObjCCategoryImpl:
                zig_panic("TODO handle decl kind ObjCCategoryImpl");
            case Decl::ObjCImplementation:
                zig_panic("TODO handle decl kind ObjCImplementation");
            case Decl::ObjCInterface:
                zig_panic("TODO handle decl kind ObjCInterface");
            case Decl::ObjCProtocol:
                zig_panic("TODO handle decl kind ObjCProtocol");
            case Decl::ObjCMethod:
                zig_panic("TODO handle decl kind ObjCMethod");
            case Decl::ObjCProperty:
                zig_panic("TODO handle decl kind ObjCProperty");
            case Decl::BuiltinTemplate:
                zig_panic("TODO handle decl kind BuiltinTemplate");
            case Decl::ClassTemplate:
                zig_panic("TODO handle decl kind ClassTemplate");
            case Decl::FunctionTemplate:
                zig_panic("TODO handle decl kind FunctionTemplate");
            case Decl::TypeAliasTemplate:
                zig_panic("TODO handle decl kind TypeAliasTemplate");
            case Decl::VarTemplate:
                zig_panic("TODO handle decl kind VarTemplate");
            case Decl::TemplateTemplateParm:
                zig_panic("TODO handle decl kind TemplateTemplateParm");
            case Decl::Enum:
                zig_panic("TODO handle decl kind Enum");
            case Decl::Record:
                zig_panic("TODO handle decl kind Record");
            case Decl::CXXRecord:
                zig_panic("TODO handle decl kind CXXRecord");
            case Decl::ClassTemplateSpecialization:
                zig_panic("TODO handle decl kind ClassTemplateSpecialization");
            case Decl::ClassTemplatePartialSpecialization:
                zig_panic("TODO handle decl kind ClassTemplatePartialSpecialization");
            case Decl::TemplateTypeParm:
                zig_panic("TODO handle decl kind TemplateTypeParm");
            case Decl::ObjCTypeParam:
                zig_panic("TODO handle decl kind ObjCTypeParam");
            case Decl::TypeAlias:
                zig_panic("TODO handle decl kind TypeAlias");
            case Decl::Typedef:
                zig_panic("TODO handle decl kind Typedef");
            case Decl::UnresolvedUsingTypename:
                zig_panic("TODO handle decl kind UnresolvedUsingTypename");
            case Decl::Using:
                zig_panic("TODO handle decl kind Using");
            case Decl::UsingDirective:
                zig_panic("TODO handle decl kind UsingDirective");
            case Decl::UsingPack:
                zig_panic("TODO handle decl kind UsingPack");
            case Decl::UsingShadow:
                zig_panic("TODO handle decl kind UsingShadow");
            case Decl::ConstructorUsingShadow:
                zig_panic("TODO handle decl kind ConstructorUsingShadow");
            case Decl::Binding:
                zig_panic("TODO handle decl kind Binding");
            case Decl::Field:
                zig_panic("TODO handle decl kind Field");
            case Decl::ObjCAtDefsField:
                zig_panic("TODO handle decl kind ObjCAtDefsField");
            case Decl::ObjCIvar:
                zig_panic("TODO handle decl kind ObjCIvar");
            case Decl::Function:
                zig_panic("TODO handle decl kind Function");
            case Decl::CXXDeductionGuide:
                zig_panic("TODO handle decl kind CXXDeductionGuide");
            case Decl::CXXMethod:
                zig_panic("TODO handle decl kind CXXMethod");
            case Decl::CXXConstructor:
                zig_panic("TODO handle decl kind CXXConstructor");
            case Decl::CXXConversion:
                zig_panic("TODO handle decl kind CXXConversion");
            case Decl::CXXDestructor:
                zig_panic("TODO handle decl kind CXXDestructor");
            case Decl::MSProperty:
                zig_panic("TODO handle decl kind MSProperty");
            case Decl::NonTypeTemplateParm:
                zig_panic("TODO handle decl kind NonTypeTemplateParm");
            case Decl::Decomposition:
                zig_panic("TODO handle decl kind Decomposition");
            case Decl::ImplicitParam:
                zig_panic("TODO handle decl kind ImplicitParam");
            case Decl::OMPCapturedExpr:
                zig_panic("TODO handle decl kind OMPCapturedExpr");
            case Decl::ParmVar:
                zig_panic("TODO handle decl kind ParmVar");
            case Decl::VarTemplateSpecialization:
                zig_panic("TODO handle decl kind VarTemplateSpecialization");
            case Decl::VarTemplatePartialSpecialization:
                zig_panic("TODO handle decl kind VarTemplatePartialSpecialization");
            case Decl::EnumConstant:
                zig_panic("TODO handle decl kind EnumConstant");
            case Decl::IndirectField:
                zig_panic("TODO handle decl kind IndirectField");
            case Decl::OMPDeclareReduction:
                zig_panic("TODO handle decl kind OMPDeclareReduction");
            case Decl::UnresolvedUsingValue:
                zig_panic("TODO handle decl kind UnresolvedUsingValue");
            case Decl::OMPThreadPrivate:
                zig_panic("TODO handle decl kind OMPThreadPrivate");
            case Decl::ObjCPropertyImpl:
                zig_panic("TODO handle decl kind ObjCPropertyImpl");
            case Decl::PragmaComment:
                zig_panic("TODO handle decl kind PragmaComment");
            case Decl::PragmaDetectMismatch:
                zig_panic("TODO handle decl kind PragmaDetectMismatch");
            case Decl::StaticAssert:
                zig_panic("TODO handle decl kind StaticAssert");
            case Decl::TranslationUnit:
                zig_panic("TODO handle decl kind TranslationUnit");
        }
        zig_unreachable();
    }

    // declarations were already added
    return nullptr;
}

static AstNode *trans_while_loop(Context *c, AstNode *block, WhileStmt *stmt) {
    AstNode *while_node = trans_create_node(c, NodeTypeWhileExpr);
    while_node->data.while_expr.condition = trans_expr(c, block, stmt->getCond());
    while_node->data.while_expr.body = trans_stmt(c, block, stmt->getBody());
    return while_node;
}

static AstNode *trans_stmt(Context *c, AstNode *block, Stmt *stmt) {
    Stmt::StmtClass sc = stmt->getStmtClass();
    switch (sc) {
        case Stmt::ReturnStmtClass:
            return trans_return_stmt(c, block, (ReturnStmt *)stmt);
        case Stmt::CompoundStmtClass:
            return trans_compound_stmt(c, block, (CompoundStmt *)stmt);
        case Stmt::IntegerLiteralClass:
            return trans_integer_literal(c, (IntegerLiteral *)stmt);
        case Stmt::ConditionalOperatorClass:
            return trans_conditional_operator(c, block, (ConditionalOperator *)stmt);
        case Stmt::BinaryOperatorClass:
            return trans_binary_operator(c, block, (BinaryOperator *)stmt);
        case Stmt::ImplicitCastExprClass:
            return trans_implicit_cast_expr(c, block, (ImplicitCastExpr *)stmt);
        case Stmt::DeclRefExprClass:
            return trans_decl_ref_expr(c, (DeclRefExpr *)stmt);
        case Stmt::UnaryOperatorClass:
            return trans_unary_operator(c, block, (UnaryOperator *)stmt);
        case Stmt::DeclStmtClass:
            return trans_local_declaration(c, block, (DeclStmt *)stmt);
        case Stmt::WhileStmtClass:
            return trans_while_loop(c, block, (WhileStmt *)stmt);
        case Stmt::CaseStmtClass:
            zig_panic("TODO handle C CaseStmtClass");
        case Stmt::DefaultStmtClass:
            zig_panic("TODO handle C DefaultStmtClass");
        case Stmt::SwitchStmtClass:
            zig_panic("TODO handle C SwitchStmtClass");
        case Stmt::NoStmtClass:
            zig_panic("TODO handle C NoStmtClass");
        case Stmt::GCCAsmStmtClass:
            zig_panic("TODO handle C GCCAsmStmtClass");
        case Stmt::MSAsmStmtClass:
            zig_panic("TODO handle C MSAsmStmtClass");
        case Stmt::AttributedStmtClass:
            zig_panic("TODO handle C AttributedStmtClass");
        case Stmt::BreakStmtClass:
            zig_panic("TODO handle C BreakStmtClass");
        case Stmt::CXXCatchStmtClass:
            zig_panic("TODO handle C CXXCatchStmtClass");
        case Stmt::CXXForRangeStmtClass:
            zig_panic("TODO handle C CXXForRangeStmtClass");
        case Stmt::CXXTryStmtClass:
            zig_panic("TODO handle C CXXTryStmtClass");
        case Stmt::CapturedStmtClass:
            zig_panic("TODO handle C CapturedStmtClass");
        case Stmt::ContinueStmtClass:
            zig_panic("TODO handle C ContinueStmtClass");
        case Stmt::CoreturnStmtClass:
            zig_panic("TODO handle C CoreturnStmtClass");
        case Stmt::CoroutineBodyStmtClass:
            zig_panic("TODO handle C CoroutineBodyStmtClass");
        case Stmt::DoStmtClass:
            zig_panic("TODO handle C DoStmtClass");
        case Stmt::BinaryConditionalOperatorClass:
            zig_panic("TODO handle C BinaryConditionalOperatorClass");
        case Stmt::AddrLabelExprClass:
            zig_panic("TODO handle C AddrLabelExprClass");
        case Stmt::ArrayInitIndexExprClass:
            zig_panic("TODO handle C ArrayInitIndexExprClass");
        case Stmt::ArrayInitLoopExprClass:
            zig_panic("TODO handle C ArrayInitLoopExprClass");
        case Stmt::ArraySubscriptExprClass:
            zig_panic("TODO handle C ArraySubscriptExprClass");
        case Stmt::ArrayTypeTraitExprClass:
            zig_panic("TODO handle C ArrayTypeTraitExprClass");
        case Stmt::AsTypeExprClass:
            zig_panic("TODO handle C AsTypeExprClass");
        case Stmt::AtomicExprClass:
            zig_panic("TODO handle C AtomicExprClass");
        case Stmt::CompoundAssignOperatorClass:
            zig_panic("TODO handle C CompoundAssignOperatorClass");
        case Stmt::BlockExprClass:
            zig_panic("TODO handle C BlockExprClass");
        case Stmt::CXXBindTemporaryExprClass:
            zig_panic("TODO handle C CXXBindTemporaryExprClass");
        case Stmt::CXXBoolLiteralExprClass:
            zig_panic("TODO handle C CXXBoolLiteralExprClass");
        case Stmt::CXXConstructExprClass:
            zig_panic("TODO handle C CXXConstructExprClass");
        case Stmt::CXXTemporaryObjectExprClass:
            zig_panic("TODO handle C CXXTemporaryObjectExprClass");
        case Stmt::CXXDefaultArgExprClass:
            zig_panic("TODO handle C CXXDefaultArgExprClass");
        case Stmt::CXXDefaultInitExprClass:
            zig_panic("TODO handle C CXXDefaultInitExprClass");
        case Stmt::CXXDeleteExprClass:
            zig_panic("TODO handle C CXXDeleteExprClass");
        case Stmt::CXXDependentScopeMemberExprClass:
            zig_panic("TODO handle C CXXDependentScopeMemberExprClass");
        case Stmt::CXXFoldExprClass:
            zig_panic("TODO handle C CXXFoldExprClass");
        case Stmt::CXXInheritedCtorInitExprClass:
            zig_panic("TODO handle C CXXInheritedCtorInitExprClass");
        case Stmt::CXXNewExprClass:
            zig_panic("TODO handle C CXXNewExprClass");
        case Stmt::CXXNoexceptExprClass:
            zig_panic("TODO handle C CXXNoexceptExprClass");
        case Stmt::CXXNullPtrLiteralExprClass:
            zig_panic("TODO handle C CXXNullPtrLiteralExprClass");
        case Stmt::CXXPseudoDestructorExprClass:
            zig_panic("TODO handle C CXXPseudoDestructorExprClass");
        case Stmt::CXXScalarValueInitExprClass:
            zig_panic("TODO handle C CXXScalarValueInitExprClass");
        case Stmt::CXXStdInitializerListExprClass:
            zig_panic("TODO handle C CXXStdInitializerListExprClass");
        case Stmt::CXXThisExprClass:
            zig_panic("TODO handle C CXXThisExprClass");
        case Stmt::CXXThrowExprClass:
            zig_panic("TODO handle C CXXThrowExprClass");
        case Stmt::CXXTypeidExprClass:
            zig_panic("TODO handle C CXXTypeidExprClass");
        case Stmt::CXXUnresolvedConstructExprClass:
            zig_panic("TODO handle C CXXUnresolvedConstructExprClass");
        case Stmt::CXXUuidofExprClass:
            zig_panic("TODO handle C CXXUuidofExprClass");
        case Stmt::CallExprClass:
            zig_panic("TODO handle C CallExprClass");
        case Stmt::CUDAKernelCallExprClass:
            zig_panic("TODO handle C CUDAKernelCallExprClass");
        case Stmt::CXXMemberCallExprClass:
            zig_panic("TODO handle C CXXMemberCallExprClass");
        case Stmt::CXXOperatorCallExprClass:
            zig_panic("TODO handle C CXXOperatorCallExprClass");
        case Stmt::UserDefinedLiteralClass:
            zig_panic("TODO handle C UserDefinedLiteralClass");
        case Stmt::CStyleCastExprClass:
            zig_panic("TODO handle C CStyleCastExprClass");
        case Stmt::CXXFunctionalCastExprClass:
            zig_panic("TODO handle C CXXFunctionalCastExprClass");
        case Stmt::CXXConstCastExprClass:
            zig_panic("TODO handle C CXXConstCastExprClass");
        case Stmt::CXXDynamicCastExprClass:
            zig_panic("TODO handle C CXXDynamicCastExprClass");
        case Stmt::CXXReinterpretCastExprClass:
            zig_panic("TODO handle C CXXReinterpretCastExprClass");
        case Stmt::CXXStaticCastExprClass:
            zig_panic("TODO handle C CXXStaticCastExprClass");
        case Stmt::ObjCBridgedCastExprClass:
            zig_panic("TODO handle C ObjCBridgedCastExprClass");
        case Stmt::CharacterLiteralClass:
            zig_panic("TODO handle C CharacterLiteralClass");
        case Stmt::ChooseExprClass:
            zig_panic("TODO handle C ChooseExprClass");
        case Stmt::CompoundLiteralExprClass:
            zig_panic("TODO handle C CompoundLiteralExprClass");
        case Stmt::ConvertVectorExprClass:
            zig_panic("TODO handle C ConvertVectorExprClass");
        case Stmt::CoawaitExprClass:
            zig_panic("TODO handle C CoawaitExprClass");
        case Stmt::CoyieldExprClass:
            zig_panic("TODO handle C CoyieldExprClass");
        case Stmt::DependentCoawaitExprClass:
            zig_panic("TODO handle C DependentCoawaitExprClass");
        case Stmt::DependentScopeDeclRefExprClass:
            zig_panic("TODO handle C DependentScopeDeclRefExprClass");
        case Stmt::DesignatedInitExprClass:
            zig_panic("TODO handle C DesignatedInitExprClass");
        case Stmt::DesignatedInitUpdateExprClass:
            zig_panic("TODO handle C DesignatedInitUpdateExprClass");
        case Stmt::ExprWithCleanupsClass:
            zig_panic("TODO handle C ExprWithCleanupsClass");
        case Stmt::ExpressionTraitExprClass:
            zig_panic("TODO handle C ExpressionTraitExprClass");
        case Stmt::ExtVectorElementExprClass:
            zig_panic("TODO handle C ExtVectorElementExprClass");
        case Stmt::FloatingLiteralClass:
            zig_panic("TODO handle C FloatingLiteralClass");
        case Stmt::FunctionParmPackExprClass:
            zig_panic("TODO handle C FunctionParmPackExprClass");
        case Stmt::GNUNullExprClass:
            zig_panic("TODO handle C GNUNullExprClass");
        case Stmt::GenericSelectionExprClass:
            zig_panic("TODO handle C GenericSelectionExprClass");
        case Stmt::ImaginaryLiteralClass:
            zig_panic("TODO handle C ImaginaryLiteralClass");
        case Stmt::ImplicitValueInitExprClass:
            zig_panic("TODO handle C ImplicitValueInitExprClass");
        case Stmt::InitListExprClass:
            zig_panic("TODO handle C InitListExprClass");
        case Stmt::LambdaExprClass:
            zig_panic("TODO handle C LambdaExprClass");
        case Stmt::MSPropertyRefExprClass:
            zig_panic("TODO handle C MSPropertyRefExprClass");
        case Stmt::MSPropertySubscriptExprClass:
            zig_panic("TODO handle C MSPropertySubscriptExprClass");
        case Stmt::MaterializeTemporaryExprClass:
            zig_panic("TODO handle C MaterializeTemporaryExprClass");
        case Stmt::MemberExprClass:
            zig_panic("TODO handle C MemberExprClass");
        case Stmt::NoInitExprClass:
            zig_panic("TODO handle C NoInitExprClass");
        case Stmt::OMPArraySectionExprClass:
            zig_panic("TODO handle C OMPArraySectionExprClass");
        case Stmt::ObjCArrayLiteralClass:
            zig_panic("TODO handle C ObjCArrayLiteralClass");
        case Stmt::ObjCAvailabilityCheckExprClass:
            zig_panic("TODO handle C ObjCAvailabilityCheckExprClass");
        case Stmt::ObjCBoolLiteralExprClass:
            zig_panic("TODO handle C ObjCBoolLiteralExprClass");
        case Stmt::ObjCBoxedExprClass:
            zig_panic("TODO handle C ObjCBoxedExprClass");
        case Stmt::ObjCDictionaryLiteralClass:
            zig_panic("TODO handle C ObjCDictionaryLiteralClass");
        case Stmt::ObjCEncodeExprClass:
            zig_panic("TODO handle C ObjCEncodeExprClass");
        case Stmt::ObjCIndirectCopyRestoreExprClass:
            zig_panic("TODO handle C ObjCIndirectCopyRestoreExprClass");
        case Stmt::ObjCIsaExprClass:
            zig_panic("TODO handle C ObjCIsaExprClass");
        case Stmt::ObjCIvarRefExprClass:
            zig_panic("TODO handle C ObjCIvarRefExprClass");
        case Stmt::ObjCMessageExprClass:
            zig_panic("TODO handle C ObjCMessageExprClass");
        case Stmt::ObjCPropertyRefExprClass:
            zig_panic("TODO handle C ObjCPropertyRefExprClass");
        case Stmt::ObjCProtocolExprClass:
            zig_panic("TODO handle C ObjCProtocolExprClass");
        case Stmt::ObjCSelectorExprClass:
            zig_panic("TODO handle C ObjCSelectorExprClass");
        case Stmt::ObjCStringLiteralClass:
            zig_panic("TODO handle C ObjCStringLiteralClass");
        case Stmt::ObjCSubscriptRefExprClass:
            zig_panic("TODO handle C ObjCSubscriptRefExprClass");
        case Stmt::OffsetOfExprClass:
            zig_panic("TODO handle C OffsetOfExprClass");
        case Stmt::OpaqueValueExprClass:
            zig_panic("TODO handle C OpaqueValueExprClass");
        case Stmt::UnresolvedLookupExprClass:
            zig_panic("TODO handle C UnresolvedLookupExprClass");
        case Stmt::UnresolvedMemberExprClass:
            zig_panic("TODO handle C UnresolvedMemberExprClass");
        case Stmt::PackExpansionExprClass:
            zig_panic("TODO handle C PackExpansionExprClass");
        case Stmt::ParenExprClass:
            zig_panic("TODO handle C ParenExprClass");
        case Stmt::ParenListExprClass:
            zig_panic("TODO handle C ParenListExprClass");
        case Stmt::PredefinedExprClass:
            zig_panic("TODO handle C PredefinedExprClass");
        case Stmt::PseudoObjectExprClass:
            zig_panic("TODO handle C PseudoObjectExprClass");
        case Stmt::ShuffleVectorExprClass:
            zig_panic("TODO handle C ShuffleVectorExprClass");
        case Stmt::SizeOfPackExprClass:
            zig_panic("TODO handle C SizeOfPackExprClass");
        case Stmt::StmtExprClass:
            zig_panic("TODO handle C StmtExprClass");
        case Stmt::StringLiteralClass:
            zig_panic("TODO handle C StringLiteralClass");
        case Stmt::SubstNonTypeTemplateParmExprClass:
            zig_panic("TODO handle C SubstNonTypeTemplateParmExprClass");
        case Stmt::SubstNonTypeTemplateParmPackExprClass:
            zig_panic("TODO handle C SubstNonTypeTemplateParmPackExprClass");
        case Stmt::TypeTraitExprClass:
            zig_panic("TODO handle C TypeTraitExprClass");
        case Stmt::TypoExprClass:
            zig_panic("TODO handle C TypoExprClass");
        case Stmt::UnaryExprOrTypeTraitExprClass:
            zig_panic("TODO handle C UnaryExprOrTypeTraitExprClass");
        case Stmt::VAArgExprClass:
            zig_panic("TODO handle C VAArgExprClass");
        case Stmt::ForStmtClass:
            zig_panic("TODO handle C ForStmtClass");
        case Stmt::GotoStmtClass:
            zig_panic("TODO handle C GotoStmtClass");
        case Stmt::IfStmtClass:
            zig_panic("TODO handle C IfStmtClass");
        case Stmt::IndirectGotoStmtClass:
            zig_panic("TODO handle C IndirectGotoStmtClass");
        case Stmt::LabelStmtClass:
            zig_panic("TODO handle C LabelStmtClass");
        case Stmt::MSDependentExistsStmtClass:
            zig_panic("TODO handle C MSDependentExistsStmtClass");
        case Stmt::NullStmtClass:
            zig_panic("TODO handle C NullStmtClass");
        case Stmt::OMPAtomicDirectiveClass:
            zig_panic("TODO handle C OMPAtomicDirectiveClass");
        case Stmt::OMPBarrierDirectiveClass:
            zig_panic("TODO handle C OMPBarrierDirectiveClass");
        case Stmt::OMPCancelDirectiveClass:
            zig_panic("TODO handle C OMPCancelDirectiveClass");
        case Stmt::OMPCancellationPointDirectiveClass:
            zig_panic("TODO handle C OMPCancellationPointDirectiveClass");
        case Stmt::OMPCriticalDirectiveClass:
            zig_panic("TODO handle C OMPCriticalDirectiveClass");
        case Stmt::OMPFlushDirectiveClass:
            zig_panic("TODO handle C OMPFlushDirectiveClass");
        case Stmt::OMPDistributeDirectiveClass:
            zig_panic("TODO handle C OMPDistributeDirectiveClass");
        case Stmt::OMPDistributeParallelForDirectiveClass:
            zig_panic("TODO handle C OMPDistributeParallelForDirectiveClass");
        case Stmt::OMPDistributeParallelForSimdDirectiveClass:
            zig_panic("TODO handle C OMPDistributeParallelForSimdDirectiveClass");
        case Stmt::OMPDistributeSimdDirectiveClass:
            zig_panic("TODO handle C OMPDistributeSimdDirectiveClass");
        case Stmt::OMPForDirectiveClass:
            zig_panic("TODO handle C OMPForDirectiveClass");
        case Stmt::OMPForSimdDirectiveClass:
            zig_panic("TODO handle C OMPForSimdDirectiveClass");
        case Stmt::OMPParallelForDirectiveClass:
            zig_panic("TODO handle C OMPParallelForDirectiveClass");
        case Stmt::OMPParallelForSimdDirectiveClass:
            zig_panic("TODO handle C OMPParallelForSimdDirectiveClass");
        case Stmt::OMPSimdDirectiveClass:
            zig_panic("TODO handle C OMPSimdDirectiveClass");
        case Stmt::OMPTargetParallelForSimdDirectiveClass:
            zig_panic("TODO handle C OMPTargetParallelForSimdDirectiveClass");
        case Stmt::OMPTargetSimdDirectiveClass:
            zig_panic("TODO handle C OMPTargetSimdDirectiveClass");
        case Stmt::OMPTargetTeamsDistributeDirectiveClass:
            zig_panic("TODO handle C OMPTargetTeamsDistributeDirectiveClass");
        case Stmt::OMPTargetTeamsDistributeParallelForDirectiveClass:
            zig_panic("TODO handle C OMPTargetTeamsDistributeParallelForDirectiveClass");
        case Stmt::OMPTargetTeamsDistributeParallelForSimdDirectiveClass:
            zig_panic("TODO handle C OMPTargetTeamsDistributeParallelForSimdDirectiveClass");
        case Stmt::OMPTargetTeamsDistributeSimdDirectiveClass:
            zig_panic("TODO handle C OMPTargetTeamsDistributeSimdDirectiveClass");
        case Stmt::OMPTaskLoopDirectiveClass:
            zig_panic("TODO handle C OMPTaskLoopDirectiveClass");
        case Stmt::OMPTaskLoopSimdDirectiveClass:
            zig_panic("TODO handle C OMPTaskLoopSimdDirectiveClass");
        case Stmt::OMPTeamsDistributeDirectiveClass:
            zig_panic("TODO handle C OMPTeamsDistributeDirectiveClass");
        case Stmt::OMPTeamsDistributeParallelForDirectiveClass:
            zig_panic("TODO handle C OMPTeamsDistributeParallelForDirectiveClass");
        case Stmt::OMPTeamsDistributeParallelForSimdDirectiveClass:
            zig_panic("TODO handle C OMPTeamsDistributeParallelForSimdDirectiveClass");
        case Stmt::OMPTeamsDistributeSimdDirectiveClass:
            zig_panic("TODO handle C OMPTeamsDistributeSimdDirectiveClass");
        case Stmt::OMPMasterDirectiveClass:
            zig_panic("TODO handle C OMPMasterDirectiveClass");
        case Stmt::OMPOrderedDirectiveClass:
            zig_panic("TODO handle C OMPOrderedDirectiveClass");
        case Stmt::OMPParallelDirectiveClass:
            zig_panic("TODO handle C OMPParallelDirectiveClass");
        case Stmt::OMPParallelSectionsDirectiveClass:
            zig_panic("TODO handle C OMPParallelSectionsDirectiveClass");
        case Stmt::OMPSectionDirectiveClass:
            zig_panic("TODO handle C OMPSectionDirectiveClass");
        case Stmt::OMPSectionsDirectiveClass:
            zig_panic("TODO handle C OMPSectionsDirectiveClass");
        case Stmt::OMPSingleDirectiveClass:
            zig_panic("TODO handle C OMPSingleDirectiveClass");
        case Stmt::OMPTargetDataDirectiveClass:
            zig_panic("TODO handle C OMPTargetDataDirectiveClass");
        case Stmt::OMPTargetDirectiveClass:
            zig_panic("TODO handle C OMPTargetDirectiveClass");
        case Stmt::OMPTargetEnterDataDirectiveClass:
            zig_panic("TODO handle C OMPTargetEnterDataDirectiveClass");
        case Stmt::OMPTargetExitDataDirectiveClass:
            zig_panic("TODO handle C OMPTargetExitDataDirectiveClass");
        case Stmt::OMPTargetParallelDirectiveClass:
            zig_panic("TODO handle C OMPTargetParallelDirectiveClass");
        case Stmt::OMPTargetParallelForDirectiveClass:
            zig_panic("TODO handle C OMPTargetParallelForDirectiveClass");
        case Stmt::OMPTargetTeamsDirectiveClass:
            zig_panic("TODO handle C OMPTargetTeamsDirectiveClass");
        case Stmt::OMPTargetUpdateDirectiveClass:
            zig_panic("TODO handle C OMPTargetUpdateDirectiveClass");
        case Stmt::OMPTaskDirectiveClass:
            zig_panic("TODO handle C OMPTaskDirectiveClass");
        case Stmt::OMPTaskgroupDirectiveClass:
            zig_panic("TODO handle C OMPTaskgroupDirectiveClass");
        case Stmt::OMPTaskwaitDirectiveClass:
            zig_panic("TODO handle C OMPTaskwaitDirectiveClass");
        case Stmt::OMPTaskyieldDirectiveClass:
            zig_panic("TODO handle C OMPTaskyieldDirectiveClass");
        case Stmt::OMPTeamsDirectiveClass:
            zig_panic("TODO handle C OMPTeamsDirectiveClass");
        case Stmt::ObjCAtCatchStmtClass:
            zig_panic("TODO handle C ObjCAtCatchStmtClass");
        case Stmt::ObjCAtFinallyStmtClass:
            zig_panic("TODO handle C ObjCAtFinallyStmtClass");
        case Stmt::ObjCAtSynchronizedStmtClass:
            zig_panic("TODO handle C ObjCAtSynchronizedStmtClass");
        case Stmt::ObjCAtThrowStmtClass:
            zig_panic("TODO handle C ObjCAtThrowStmtClass");
        case Stmt::ObjCAtTryStmtClass:
            zig_panic("TODO handle C ObjCAtTryStmtClass");
        case Stmt::ObjCAutoreleasePoolStmtClass:
            zig_panic("TODO handle C ObjCAutoreleasePoolStmtClass");
        case Stmt::ObjCForCollectionStmtClass:
            zig_panic("TODO handle C ObjCForCollectionStmtClass");
        case Stmt::SEHExceptStmtClass:
            zig_panic("TODO handle C SEHExceptStmtClass");
        case Stmt::SEHFinallyStmtClass:
            zig_panic("TODO handle C SEHFinallyStmtClass");
        case Stmt::SEHLeaveStmtClass:
            zig_panic("TODO handle C SEHLeaveStmtClass");
        case Stmt::SEHTryStmtClass:
            zig_panic("TODO handle C SEHTryStmtClass");
    }
    zig_unreachable();
}

static void visit_fn_decl(Context *c, const FunctionDecl *fn_decl) {
    Buf *fn_name = buf_create_from_str(decl_name(fn_decl));

    if (fn_decl->hasBody()) {
        fprintf(stderr, "fn %s\n", buf_ptr(fn_name));
        Stmt *body = fn_decl->getBody();
        AstNode *body_node = trans_stmt(c, nullptr, body);
        ast_render(c->codegen, stderr, body_node, 4);
        fprintf(stderr, "\n");
    }

    if (get_global(c, fn_name)) {
        // we already saw this function
        return;
    }

    TypeTableEntry *fn_type = resolve_qual_type(c, fn_decl->getType(), fn_decl);

    if (fn_type->id == TypeTableEntryIdInvalid) {
        emit_warning(c, fn_decl->getLocation(), "ignoring function '%s' - unable to resolve type", buf_ptr(fn_name));
        return;
    }
    assert(fn_type->id == TypeTableEntryIdFn);

    FnTableEntry *fn_entry = create_fn_raw(FnInlineAuto, GlobalLinkageIdStrong);
    buf_init_from_buf(&fn_entry->symbol_name, fn_name);
    fn_entry->type_entry = fn_type;

    assert(fn_type->data.fn.fn_type_id.cc != CallingConventionNaked);

    size_t arg_count = fn_type->data.fn.fn_type_id.param_count;
    fn_entry->param_names = allocate<Buf *>(arg_count);
    Buf *name_buf;
    for (size_t i = 0; i < arg_count; i += 1) {
        const ParmVarDecl *param = fn_decl->getParamDecl(i);
        const char *name = decl_name(param);
        if (strlen(name) == 0) {
            name_buf = buf_sprintf("arg%" ZIG_PRI_usize "", i);
        } else {
            name_buf = buf_create_from_str(name);
        }
        fn_entry->param_names[i] = name_buf;
    }

    TldFn *tld_fn = allocate<TldFn>(1);
    parseh_init_tld(c, &tld_fn->base, TldIdFn, fn_name);
    tld_fn->fn_entry = fn_entry;
    add_global(c, &tld_fn->base);

    c->codegen->fn_protos.append(fn_entry);
}

static void visit_typedef_decl(Context *c, const TypedefNameDecl *typedef_decl) {
    QualType child_qt = typedef_decl->getUnderlyingType();
    Buf *type_name = buf_create_from_str(decl_name(typedef_decl));

    if (buf_eql_str(type_name, "uint8_t") ||
        buf_eql_str(type_name, "int8_t") ||
        buf_eql_str(type_name, "uint16_t") ||
        buf_eql_str(type_name, "int16_t") ||
        buf_eql_str(type_name, "uint32_t") ||
        buf_eql_str(type_name, "int32_t") ||
        buf_eql_str(type_name, "uint64_t") ||
        buf_eql_str(type_name, "int64_t") ||
        buf_eql_str(type_name, "intptr_t") ||
        buf_eql_str(type_name, "uintptr_t"))
    {
        // special case we can just use the builtin types
        return;
    }

    // if the underlying type is anonymous, we can special case it to just
    // use the name of this typedef
    // TODO

    TypeTableEntry *child_type = resolve_qual_type(c, child_qt, typedef_decl);
    if (child_type->id == TypeTableEntryIdInvalid) {
        emit_warning(c, typedef_decl->getLocation(), "typedef %s - unresolved child type", buf_ptr(type_name));
        return;
    }
    add_const_type(c, type_name, child_type);
}

static void replace_with_fwd_decl(Context *c, TypeTableEntry *struct_type, Buf *full_type_name) {
    unsigned line = c->source_node ? c->source_node->line : 0;
    ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugForwardDeclType(c->codegen->dbuilder,
        ZigLLVMTag_DW_structure_type(), buf_ptr(full_type_name),
        ZigLLVMFileToScope(c->import->di_file), c->import->di_file, line);

    ZigLLVMReplaceTemporary(c->codegen->dbuilder, struct_type->di_type, replacement_di_type);
    struct_type->di_type = replacement_di_type;
    struct_type->id = TypeTableEntryIdOpaque;
}

static TypeTableEntry *resolve_enum_decl(Context *c, const EnumDecl *enum_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)enum_decl);
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = decl_name(enum_decl);

    Buf *bare_name;
    if (raw_name[0] == 0) {
        bare_name = buf_sprintf("anon_$%" PRIu32, get_next_anon_index(c));
    } else {
        bare_name = buf_create_from_str(raw_name);
    }

    Buf *full_type_name = buf_sprintf("enum_%s", buf_ptr(bare_name));

    const EnumDecl *enum_def = enum_decl->getDefinition();
    if (!enum_def) {
        TypeTableEntry *enum_type = get_partial_container_type(c->codegen, &c->import->decls_scope->base,
                ContainerKindEnum, c->source_node, buf_ptr(full_type_name), ContainerLayoutExtern);
        enum_type->data.enumeration.zero_bits_known = true;
        enum_type->data.enumeration.abi_alignment = 1;
        c->enum_type_table.put(bare_name, enum_type);
        c->decl_table.put(enum_decl, enum_type);
        replace_with_fwd_decl(c, enum_type, full_type_name);

        return enum_type;
    }

    bool pure_enum = true;
    uint32_t field_count = 0;
    for (auto it = enum_def->enumerator_begin(),
              it_end = enum_def->enumerator_end();
              it != it_end; ++it, field_count += 1)
    {
        const EnumConstantDecl *enum_const = *it;
        if (enum_const->getInitExpr()) {
            pure_enum = false;
        }
    }

    TypeTableEntry *tag_int_type = resolve_qual_type(c, enum_decl->getIntegerType(), enum_decl);

    if (pure_enum) {
        TypeTableEntry *enum_type = get_partial_container_type(c->codegen, &c->import->decls_scope->base,
                ContainerKindEnum, c->source_node, buf_ptr(full_type_name), ContainerLayoutExtern);
        TypeTableEntry *tag_type_entry = create_enum_tag_type(c->codegen, enum_type, tag_int_type);
        c->enum_type_table.put(bare_name, enum_type);
        c->decl_table.put(enum_decl, enum_type);

        enum_type->data.enumeration.gen_field_count = 0;
        enum_type->data.enumeration.complete = true;
        enum_type->data.enumeration.zero_bits_known = true;
        enum_type->data.enumeration.abi_alignment = 1;
        enum_type->data.enumeration.tag_type = tag_type_entry;

        enum_type->data.enumeration.src_field_count = field_count;
        enum_type->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        ZigLLVMDIEnumerator **di_enumerators = allocate<ZigLLVMDIEnumerator*>(field_count);

        uint32_t i = 0;
        for (auto it = enum_def->enumerator_begin(),
                it_end = enum_def->enumerator_end();
                it != it_end; ++it, i += 1)
        {
            const EnumConstantDecl *enum_const = *it;

            Buf *enum_val_name = buf_create_from_str(decl_name(enum_const));
            Buf *field_name;
            if (buf_starts_with_buf(enum_val_name, bare_name)) {
                field_name = buf_slice(enum_val_name, buf_len(bare_name), buf_len(enum_val_name));
            } else {
                field_name = enum_val_name;
            }

            TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[i];
            type_enum_field->name = field_name;
            type_enum_field->type_entry = c->codegen->builtin_types.entry_void;
            type_enum_field->value = i;

            di_enumerators[i] = ZigLLVMCreateDebugEnumerator(c->codegen->dbuilder, buf_ptr(type_enum_field->name), i);


            // in C each enum value is in the global namespace. so we put them there too.
            // at this point we can rely on the enum emitting successfully
            add_global(c, create_global_num_lit_unsigned_negative(c, enum_val_name, i, false));
        }

        // create llvm type for root struct
        enum_type->type_ref = tag_type_entry->type_ref;

        enum_type->data.enumeration.abi_alignment = LLVMABIAlignmentOfType(c->codegen->target_data_ref,
                enum_type->type_ref);

        // create debug type for tag
        unsigned line = c->source_node ? (c->source_node->line + 1) : 0;
        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(c->codegen->target_data_ref, enum_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(c->codegen->target_data_ref, enum_type->type_ref);
        ZigLLVMDIType *tag_di_type = ZigLLVMCreateDebugEnumerationType(c->codegen->dbuilder,
                ZigLLVMFileToScope(c->import->di_file), buf_ptr(bare_name),
                c->import->di_file, line,
                debug_size_in_bits,
                debug_align_in_bits,
                di_enumerators, field_count, tag_type_entry->di_type, "");

        ZigLLVMReplaceTemporary(c->codegen->dbuilder, enum_type->di_type, tag_di_type);
        enum_type->di_type = tag_di_type;

        return enum_type;
    } else {
        // TODO after issue #305 is solved, make this be an enum with tag_int_type
        // as the integer type and set the custom enum values
        TypeTableEntry *enum_type = tag_int_type;
        c->enum_type_table.put(bare_name, enum_type);
        c->decl_table.put(enum_decl, enum_type);

        // add variables for all the values with enum_type
        for (auto it = enum_def->enumerator_begin(),
                it_end = enum_def->enumerator_end();
                it != it_end; ++it)
        {
            const EnumConstantDecl *enum_const = *it;

            Buf *enum_val_name = buf_create_from_str(decl_name(enum_const));

            Tld *tld = create_global_num_lit_ap(c, enum_decl, enum_val_name, enum_const->getInitVal());
            if (!tld)
                return c->codegen->builtin_types.entry_invalid;

            add_global(c, tld);
        }

        return enum_type;
    }
}

static void visit_enum_decl(Context *c, const EnumDecl *enum_decl) {
    TypeTableEntry *enum_type = resolve_enum_decl(c, enum_decl);

    if (enum_type->id == TypeTableEntryIdInvalid)
        return;

    // make an alias without the "enum_" prefix. this will get emitted at the
    // end if it doesn't conflict with anything else
    bool is_anonymous = (decl_name(enum_decl)[0] == 0);
    if (is_anonymous)
        return;

    Buf *bare_name = buf_create_from_str(decl_name(enum_decl));

    Tld *tld = add_container_tld(c, enum_type);
    add_global_weak_alias(c, bare_name, tld);
}

static TypeTableEntry *resolve_record_decl(Context *c, const RecordDecl *record_decl) {
    auto existing_entry = c->decl_table.maybe_get((void*)record_decl);
    if (existing_entry) {
        return existing_entry->value;
    }

    const char *raw_name = decl_name(record_decl);

    if (!record_decl->isStruct()) {
        emit_warning(c, record_decl->getLocation(), "skipping record %s, not a struct", raw_name);
        return c->codegen->builtin_types.entry_invalid;
    }

    Buf *bare_name;
    if (record_decl->isAnonymousStructOrUnion() || raw_name[0] == 0) {
        bare_name = buf_sprintf("anon_$%" PRIu32, get_next_anon_index(c));
    } else {
        bare_name = buf_create_from_str(raw_name);
    }

    Buf *full_type_name = buf_sprintf("struct_%s", buf_ptr(bare_name));


    TypeTableEntry *struct_type = get_partial_container_type(c->codegen, &c->import->decls_scope->base,
        ContainerKindStruct, c->source_node, buf_ptr(full_type_name), ContainerLayoutExtern);
    struct_type->data.structure.zero_bits_known = true;
    struct_type->data.structure.abi_alignment = 1;

    c->struct_type_table.put(bare_name, struct_type);
    c->decl_table.put(record_decl, struct_type);

    RecordDecl *record_def = record_decl->getDefinition();
    unsigned line = c->source_node ? c->source_node->line : 0;
    if (!record_def) {
        replace_with_fwd_decl(c, struct_type, full_type_name);
        return struct_type;
    }


    // count fields and validate
    uint32_t field_count = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, field_count += 1)
    {
        const FieldDecl *field_decl = *it;

        if (field_decl->isBitField()) {
            emit_warning(c, field_decl->getLocation(), "struct %s demoted to opaque type - has bitfield\n", buf_ptr(bare_name));
            replace_with_fwd_decl(c, struct_type, full_type_name);
            return struct_type;
        }
    }

    struct_type->data.structure.src_field_count = field_count;
    struct_type->data.structure.fields = allocate<TypeStructField>(field_count);
    LLVMTypeRef *element_types = allocate<LLVMTypeRef>(field_count);
    ZigLLVMDIType **di_element_types = allocate<ZigLLVMDIType*>(field_count);

    // next, populate element_types as its needed for LLVMStructSetBody which is needed for LLVMOffsetOfElement
    uint32_t i = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, i += 1)
    {
        const FieldDecl *field_decl = *it;

        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        type_struct_field->name = buf_create_from_str(decl_name(field_decl));
        type_struct_field->src_index = i;
        type_struct_field->gen_index = i;
        TypeTableEntry *field_type = resolve_qual_type(c, field_decl->getType(), field_decl);
        type_struct_field->type_entry = field_type;

        if (type_is_invalid(field_type) || !type_is_complete(field_type)) {
            emit_warning(c, field_decl->getLocation(), "struct %s demoted to opaque type - unresolved type\n", buf_ptr(bare_name));
            replace_with_fwd_decl(c, struct_type, full_type_name);
            return struct_type;
        }

        element_types[i] = field_type->type_ref;
        assert(element_types[i]);
    }

    LLVMStructSetBody(struct_type->type_ref, element_types, field_count, false);

    // finally populate debug info
    i = 0;
    for (auto it = record_def->field_begin(),
              it_end = record_def->field_end();
              it != it_end; ++it, i += 1)
    {
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        TypeTableEntry *field_type = type_struct_field->type_entry;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(c->codegen->target_data_ref, field_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(c->codegen->target_data_ref, field_type->type_ref);
        uint64_t debug_offset_in_bits = 8*LLVMOffsetOfElement(c->codegen->target_data_ref, struct_type->type_ref, i);
        di_element_types[i] = ZigLLVMCreateDebugMemberType(c->codegen->dbuilder,
                ZigLLVMTypeToScope(struct_type->di_type), buf_ptr(type_struct_field->name),
                c->import->di_file, line + 1,
                debug_size_in_bits,
                debug_align_in_bits,
                debug_offset_in_bits,
                0, field_type->di_type);

        assert(di_element_types[i]);

    }
    struct_type->data.structure.embedded_in_current = false;

    struct_type->data.structure.gen_field_count = field_count;
    struct_type->data.structure.complete = true;
    struct_type->data.structure.abi_alignment = LLVMABIAlignmentOfType(c->codegen->target_data_ref,
            struct_type->type_ref);

    uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(c->codegen->target_data_ref, struct_type->type_ref);
    uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(c->codegen->target_data_ref, struct_type->type_ref);
    ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(c->codegen->dbuilder,
            ZigLLVMFileToScope(c->import->di_file),
            buf_ptr(full_type_name), c->import->di_file, line + 1,
            debug_size_in_bits,
            debug_align_in_bits,
            0,
            nullptr, di_element_types, field_count, 0, nullptr, "");

    ZigLLVMReplaceTemporary(c->codegen->dbuilder, struct_type->di_type, replacement_di_type);
    struct_type->di_type = replacement_di_type;

    return struct_type;
}

static void visit_record_decl(Context *c, const RecordDecl *record_decl) {
    TypeTableEntry *struct_type = resolve_record_decl(c, record_decl);

    if (struct_type->id == TypeTableEntryIdInvalid) {
        return;
    }

    bool is_anonymous = (record_decl->isAnonymousStructOrUnion() || decl_name(record_decl)[0] == 0);
    if (is_anonymous)
        return;

    Buf *bare_name = buf_create_from_str(decl_name(record_decl));

    Tld *tld = add_container_tld(c, struct_type);
    add_global_weak_alias(c, bare_name, tld);
}

static void visit_var_decl(Context *c, const VarDecl *var_decl) {
    Buf *name = buf_create_from_str(decl_name(var_decl));

    switch (var_decl->getTLSKind()) {
        case VarDecl::TLS_None:
            break;
        case VarDecl::TLS_Static:
            emit_warning(c, var_decl->getLocation(), "ignoring variable '%s' - static thread local storage\n", buf_ptr(name));
            return;
        case VarDecl::TLS_Dynamic:
            emit_warning(c, var_decl->getLocation(), "ignoring variable '%s' - dynamic thread local storage\n", buf_ptr(name));
            return;
    }

    QualType qt = var_decl->getType();
    TypeTableEntry *var_type = resolve_qual_type(c, qt, var_decl);
    if (var_type->id == TypeTableEntryIdInvalid) {
        emit_warning(c, var_decl->getLocation(), "ignoring variable '%s' - unresolved type\n", buf_ptr(name));
        return;
    }

    bool is_extern = var_decl->hasExternalStorage();
    bool is_static = var_decl->isFileVarDecl();
    bool is_const = qt.isConstQualified();

    if (is_static && !is_extern) {
        if (!var_decl->hasInit()) {
            emit_warning(c, var_decl->getLocation(), "ignoring variable '%s' - no initializer\n", buf_ptr(name));
            return;
        }
        APValue *ap_value = var_decl->evaluateValue();
        if (!ap_value) {
            emit_warning(c, var_decl->getLocation(), "ignoring variable '%s' - unable to evaluate initializer\n", buf_ptr(name));
            return;
        }
        ConstExprValue *init_value = nullptr;
        switch (ap_value->getKind()) {
            case APValue::Int:
                {
                    if (var_type->id != TypeTableEntryIdInt) {
                        emit_warning(c, var_decl->getLocation(),
                            "ignoring variable '%s' - int initializer for non int type\n", buf_ptr(name));
                        return;
                    }
                    init_value = create_const_int_ap(c, var_type, var_decl, ap_value->getInt());
                    if (!init_value)
                        return;

                    break;
                }
            case APValue::Uninitialized:
            case APValue::Float:
            case APValue::ComplexInt:
            case APValue::ComplexFloat:
            case APValue::LValue:
            case APValue::Vector:
            case APValue::Array:
            case APValue::Struct:
            case APValue::Union:
            case APValue::MemberPointer:
            case APValue::AddrLabelDiff:
                emit_warning(c, var_decl->getLocation(),
                        "ignoring variable '%s' - unrecognized initializer value kind\n", buf_ptr(name));
                return;
        }

        TldVar *tld_var = create_global_var(c, name, init_value, true);
        add_global(c, &tld_var->base);
        return;
    }

    if (is_extern) {
        TldVar *tld_var = create_global_var(c, name, create_const_runtime(var_type), is_const);
        tld_var->var->linkage = VarLinkageExternal;
        add_global(c, &tld_var->base);
        return;
    }

    emit_warning(c, var_decl->getLocation(), "ignoring variable '%s' - non-extern, non-static variable\n", buf_ptr(name));
    return;
}

static bool decl_visitor(void *context, const Decl *decl) {
    Context *c = (Context*)context;

    switch (decl->getKind()) {
        case Decl::Function:
            visit_fn_decl(c, static_cast<const FunctionDecl*>(decl));
            break;
        case Decl::Typedef:
            visit_typedef_decl(c, static_cast<const TypedefNameDecl *>(decl));
            break;
        case Decl::Enum:
            visit_enum_decl(c, static_cast<const EnumDecl *>(decl));
            break;
        case Decl::Record:
            visit_record_decl(c, static_cast<const RecordDecl *>(decl));
            break;
        case Decl::Var:
            visit_var_decl(c, static_cast<const VarDecl *>(decl));
            break;
        default:
            emit_warning(c, decl->getLocation(), "ignoring %s decl\n", decl->getDeclKindName());
    }

    return true;
}

static bool name_exists(Context *c, Buf *name) {
    if (c->global_type_table.maybe_get(name)) {
        return true;
    }
    if (get_global(c, name)) {
        return true;
    }
    if (c->macro_table.maybe_get(name)) {
        return true;
    }
    return false;
}

static void render_aliases(Context *c) {
    for (size_t i = 0; i < c->aliases.length; i += 1) {
        Alias *alias = &c->aliases.at(i);
        if (name_exists(c, alias->name))
            continue;

        add_global_alias(c, alias->name, alias->tld);
    }
}

static void render_macros(Context *c) {
    auto it = c->macro_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        Tld *var_tld = entry->value;
        add_global(c, var_tld);
    }
}

static void process_macro(Context *c, CTokenize *ctok, Buf *name, const char *char_ptr) {
    tokenize_c_macro(ctok, (const uint8_t *)char_ptr);

    if (ctok->error) {
        return;
    }

    bool negate = false;
    for (size_t i = 0; i < ctok->tokens.length; i += 1) {
        bool is_first = (i == 0);
        bool is_last = (i == ctok->tokens.length - 1);
        CTok *tok = &ctok->tokens.at(i);
        switch (tok->id) {
            case CTokIdCharLit:
                if (is_last && is_first) {
                    Tld *tld = create_global_num_lit_unsigned_negative(c, name, tok->data.char_lit, false);
                    c->macro_table.put(name, tld);
                }
                return;
            case CTokIdStrLit:
                if (is_last && is_first) {
                    Tld *tld = create_global_str_lit_var(c, name, buf_create_from_buf(&tok->data.str_lit));
                    c->macro_table.put(name, tld);
                }
                return;
            case CTokIdNumLitInt:
                if (is_last) {
                    Tld *tld;
                    switch (tok->data.num_lit_int.suffix) {
                        case CNumLitSuffixNone:
                            tld = create_global_num_lit_unsigned_negative(c, name, tok->data.num_lit_int.x, negate);
                            break;
                        case CNumLitSuffixL:
                            tld = create_global_num_lit_unsigned_negative_type(c, name, tok->data.num_lit_int.x, negate,
                                    c->codegen->builtin_types.entry_c_int[CIntTypeLong]);
                            break;
                        case CNumLitSuffixU:
                            tld = create_global_num_lit_unsigned_negative_type(c, name, tok->data.num_lit_int.x, negate,
                                    c->codegen->builtin_types.entry_c_int[CIntTypeUInt]);
                            break;
                        case CNumLitSuffixLU:
                            tld = create_global_num_lit_unsigned_negative_type(c, name, tok->data.num_lit_int.x, negate,
                                    c->codegen->builtin_types.entry_c_int[CIntTypeULong]);
                            break;
                        case CNumLitSuffixLL:
                            tld = create_global_num_lit_unsigned_negative_type(c, name, tok->data.num_lit_int.x, negate,
                                    c->codegen->builtin_types.entry_c_int[CIntTypeLongLong]);
                            break;
                        case CNumLitSuffixLLU:
                            tld = create_global_num_lit_unsigned_negative_type(c, name, tok->data.num_lit_int.x, negate,
                                    c->codegen->builtin_types.entry_c_int[CIntTypeULongLong]);
                            break;
                    }
                    c->macro_table.put(name, tld);
                }
                return;
            case CTokIdNumLitFloat:
                if (is_last) {
                    double value = negate ? -tok->data.num_lit_float : tok->data.num_lit_float;
                    Tld *tld = create_global_num_lit_float(c, name, value);
                    c->macro_table.put(name, tld);
                }
                return;
            case CTokIdSymbol:
                if (is_last && is_first) {
                    // if it equals itself, ignore. for example, from stdio.h:
                    // #define stdin stdin
                    Buf *symbol_name = buf_create_from_buf(&tok->data.symbol);
                    if (buf_eql_buf(name, symbol_name)) {
                        return;
                    }
                    c->macro_symbols.append({name, symbol_name});
                    return;
                }
            case CTokIdMinus:
                if (is_first) {
                    negate = true;
                    break;
                } else {
                    return;
                }
        }
    }
}

static void process_symbol_macros(Context *c) {
    for (size_t i = 0; i < c->macro_symbols.length; i += 1) {
        MacroSymbol ms = c->macro_symbols.at(i);

        // If this macro aliases another top level declaration, we can make that happen by
        // putting another entry in the decl table pointing to the same top level decl.
        Tld *existing_tld = get_global(c, ms.value);
        if (!existing_tld)
            continue;

        // If a macro aliases a global variable which is a function pointer, we conclude that
        // the macro is intended to represent a function that assumes the function pointer
        // variable is non-null and calls it.
        if (existing_tld->id == TldIdVar) {
            TldVar *tld_var = (TldVar *)existing_tld;
            TypeTableEntry *var_type = tld_var->var->value->type;
            if (var_type->id == TypeTableEntryIdMaybe && !tld_var->var->src_is_const) {
                TypeTableEntry *child_type = var_type->data.maybe.child_type;
                if (child_type->id == TypeTableEntryIdFn) {
                    Tld *tld = create_inline_fn_tld(c, ms.name, tld_var);
                    c->macro_table.put(ms.name, tld);
                    continue;
                }
            }
        }

        add_global_alias(c, ms.name, existing_tld);
    }
}

static void process_preprocessor_entities(Context *c, ASTUnit &unit) {
    CTokenize ctok = {{0}};

    for (PreprocessedEntity *entity : unit.getLocalPreprocessingEntities()) {
        switch (entity->getKind()) {
            case PreprocessedEntity::InvalidKind:
            case PreprocessedEntity::InclusionDirectiveKind:
            case PreprocessedEntity::MacroExpansionKind:
                continue;
            case PreprocessedEntity::MacroDefinitionKind:
                {
                    MacroDefinitionRecord *macro = static_cast<MacroDefinitionRecord *>(entity);
                    const char *raw_name = macro->getName()->getNameStart();
                    SourceRange range = macro->getSourceRange();
                    SourceLocation begin_loc = range.getBegin();
                    SourceLocation end_loc = range.getEnd();

                    if (begin_loc == end_loc) {
                        // this means it is a macro without a value
                        // we don't care about such things
                        continue;
                    }
                    Buf *name = buf_create_from_str(raw_name);
                    if (name_exists(c, name)) {
                        continue;
                    }

                    const char *end_c = c->source_manager->getCharacterData(end_loc);
                    process_macro(c, &ctok, name, end_c);
                }
        }
    }
}

int parse_h_buf(ImportTableEntry *import, ZigList<ErrorMsg *> *errors, Buf *source,
        CodeGen *codegen, AstNode *source_node)
{
    int err;
    Buf tmp_file_path = BUF_INIT;
    if ((err = os_buf_to_tmp_file(source, buf_create_from_str(".h"), &tmp_file_path))) {
        return err;
    }

    err = parse_h_file(import, errors, buf_ptr(&tmp_file_path), codegen, source_node);

    os_delete_file(&tmp_file_path);

    return err;
}

int parse_h_file(ImportTableEntry *import, ZigList<ErrorMsg *> *errors, const char *target_file,
        CodeGen *codegen, AstNode *source_node)
{
    Context context = {0};
    Context *c = &context;
    c->warnings_on = codegen->verbose;
    c->import = import;
    c->errors = errors;
    c->visib_mod = VisibModPub;
    c->global_type_table.init(8);
    c->enum_type_table.init(8);
    c->struct_type_table.init(8);
    c->decl_table.init(8);
    c->macro_table.init(8);
    c->codegen = codegen;
    c->source_node = source_node;

    ZigList<const char *> clang_argv = {0};

    clang_argv.append("-x");
    clang_argv.append("c");

    if (c->codegen->is_native_target) {
        char *ZIG_PARSEH_CFLAGS = getenv("ZIG_NATIVE_PARSEH_CFLAGS");
        if (ZIG_PARSEH_CFLAGS) {
            Buf tmp_buf = BUF_INIT;
            char *start = ZIG_PARSEH_CFLAGS;
            char *space = strstr(start, " ");
            while (space) {
                if (space - start > 0) {
                    buf_init_from_mem(&tmp_buf, start, space - start);
                    clang_argv.append(buf_ptr(buf_create_from_buf(&tmp_buf)));
                }
                start = space + 1;
                space = strstr(start, " ");
            }
            buf_init_from_str(&tmp_buf, start);
            clang_argv.append(buf_ptr(buf_create_from_buf(&tmp_buf)));
        }
    }

    clang_argv.append("-isystem");
    clang_argv.append(ZIG_HEADERS_DIR);

    clang_argv.append("-isystem");
    clang_argv.append(buf_ptr(codegen->libc_include_dir));

    for (size_t i = 0; i < codegen->clang_argv_len; i += 1) {
        clang_argv.append(codegen->clang_argv[i]);
    }

    // we don't need spell checking and it slows things down
    clang_argv.append("-fno-spell-checking");

    // this gives us access to preprocessing entities, presumably at
    // the cost of performance
    clang_argv.append("-Xclang");
    clang_argv.append("-detailed-preprocessing-record");

    if (!c->codegen->is_native_target) {
        clang_argv.append("-target");
        clang_argv.append(buf_ptr(&c->codegen->triple_str));
    }

    clang_argv.append(target_file);

    // to make the [start...end] argument work
    clang_argv.append(nullptr);

    IntrusiveRefCntPtr<DiagnosticsEngine> diags(CompilerInstance::createDiagnostics(new DiagnosticOptions));

    std::shared_ptr<PCHContainerOperations> pch_container_ops = std::make_shared<PCHContainerOperations>();

    bool skip_function_bodies = false;
    bool only_local_decls = true;
    bool capture_diagnostics = true;
    bool user_files_are_volatile = true;
    bool allow_pch_with_compiler_errors = false;
    bool single_file_parse = false;
    bool for_serialization = false;
    const char *resources_path = ZIG_HEADERS_DIR;
    std::unique_ptr<ASTUnit> err_unit;
    std::unique_ptr<ASTUnit> ast_unit(ASTUnit::LoadFromCommandLine(
            &clang_argv.at(0), &clang_argv.last(),
            pch_container_ops, diags, resources_path,
            only_local_decls, capture_diagnostics, None, true, 0, TU_Complete,
            false, false, allow_pch_with_compiler_errors, skip_function_bodies,
            single_file_parse, user_files_are_volatile, for_serialization, None, &err_unit,
            nullptr));

    // Early failures in LoadFromCommandLine may return with ErrUnit unset.
    if (!ast_unit && !err_unit) {
        return ErrorFileSystem;
    }

    if (diags->getClient()->getNumErrors() > 0) {
        if (ast_unit) {
            err_unit = std::move(ast_unit);
        }

        for (ASTUnit::stored_diag_iterator it = err_unit->stored_diag_begin(),
                it_end = err_unit->stored_diag_end();
                it != it_end; ++it)
        {
            switch (it->getLevel()) {
                case DiagnosticsEngine::Ignored:
                case DiagnosticsEngine::Note:
                case DiagnosticsEngine::Remark:
                case DiagnosticsEngine::Warning:
                    continue;
                case DiagnosticsEngine::Error:
                case DiagnosticsEngine::Fatal:
                    break;
            }
            StringRef msg_str_ref = it->getMessage();
            Buf *msg = buf_create_from_str((const char *)msg_str_ref.bytes_begin());
            FullSourceLoc fsl = it->getLocation();
            if (fsl.hasManager()) {
                FileID file_id = fsl.getFileID();
                StringRef filename = fsl.getManager().getFilename(fsl);
                unsigned line = fsl.getSpellingLineNumber() - 1;
                unsigned column = fsl.getSpellingColumnNumber() - 1;
                unsigned offset = fsl.getManager().getFileOffset(fsl);
                const char *source = (const char *)fsl.getManager().getBufferData(file_id).bytes_begin();
                Buf *path;
                if (filename.empty()) {
                    path = buf_alloc();
                } else {
                    path = buf_create_from_mem((const char *)filename.bytes_begin(), filename.size());
                }

                ErrorMsg *err_msg = err_msg_create_with_offset(path, line, column, offset, source, msg);

                c->errors->append(err_msg);
            } else {
                // NOTE the only known way this gets triggered right now is if you have a lot of errors
                // clang emits "too many errors emitted, stopping now"
                fprintf(stderr, "unexpected error from clang: %s\n", buf_ptr(msg));
            }
        }

        return 0;
    }

    c->ctx = &ast_unit->getASTContext();
    c->source_manager = &ast_unit->getSourceManager();

    ast_unit->visitLocalTopLevelDecls(c, decl_visitor);

    process_preprocessor_entities(c, *ast_unit);

    process_symbol_macros(c);

    render_macros(c);
    render_aliases(c);

    return 0;
}
