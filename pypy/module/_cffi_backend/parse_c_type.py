import py, os
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator import cdir
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.objectmodel import specialize


src_dir = py.path.local(os.path.dirname(__file__)) / 'src'

eci = ExternalCompilationInfo(
    includes = ['parse_c_type.h'],
    separate_module_files = [src_dir / 'parse_c_type.c'],
    include_dirs = [src_dir, cdir],
    pre_include_bits = ['#define _CFFI_INTERNAL'],
)

def llexternal(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           _nowrapper=True, **kwds)

_CFFI_OPCODE_T = rffi.VOIDP
GLOBAL_S = rffi.CStruct('_cffi_global_s',
                       ('name', rffi.CCHARP),
                       ('address', rffi.VOIDP),
                       ('type_op', _CFFI_OPCODE_T),
                       ('size_or_direct_fn', rffi.CCHARP))
CDL_INTCONST_S = lltype.Struct('cdl_intconst_s',
                       ('value', rffi.ULONGLONG),
                       ('neg', rffi.INT))
STRUCT_UNION_S = rffi.CStruct('_cffi_struct_union_s',
                       ('name', rffi.CCHARP),
                       ('type_index', rffi.INT),
                       ('flags', rffi.INT),
                       ('size', rffi.SIZE_T),
                       ('alignment', rffi.INT),
                       ('first_field_index', rffi.INT),
                       ('num_fields', rffi.INT))
FIELD_S = rffi.CStruct('_cffi_field_s',
                       ('name', rffi.CCHARP),
                       ('field_offset', rffi.SIZE_T),
                       ('field_size', rffi.SIZE_T),
                       ('field_type_op', _CFFI_OPCODE_T))
ENUM_S = rffi.CStruct('_cffi_enum_s',
                       ('name', rffi.CCHARP),
                       ('type_index', rffi.INT),
                       ('type_prim', rffi.INT),
                       ('enumerators', rffi.CCHARP))
TYPENAME_S = rffi.CStruct('_cffi_typename_s',
                       ('name', rffi.CCHARP),
                       ('type_index', rffi.INT))

PCTX = rffi.CStructPtr('_cffi_type_context_s',
                       ('types', rffi.VOIDPP),
                       ('globals', rffi.CArrayPtr(GLOBAL_S)),
                       ('fields', rffi.CArrayPtr(FIELD_S)),
                       ('struct_unions', rffi.CArrayPtr(STRUCT_UNION_S)),
                       ('enums', rffi.CArrayPtr(ENUM_S)),
                       ('typenames', rffi.CArrayPtr(TYPENAME_S)),
                       ('num_globals', rffi.INT),
                       ('num_struct_unions', rffi.INT),
                       ('num_enums', rffi.INT),
                       ('num_typenames', rffi.INT),
                       ('includes', rffi.CCHARPP),
                       ('num_types', rffi.INT),
                       ('flags', rffi.INT))

PINFO = rffi.CStructPtr('_cffi_parse_info_s',
                        ('ctx', PCTX),
                        ('output', rffi.VOIDPP),
                        ('output_size', rffi.UINT),
                        ('error_location', rffi.SIZE_T),
                        ('error_message', rffi.CCHARP))

PEXTERNPY = rffi.CStructPtr('_cffi_externpy_s',
                            ('name', rffi.CCHARP),
                            ('size_of_result', rffi.SIZE_T),
                            ('reserved1', rffi.VOIDP),
                            ('reserved2', rffi.VOIDP))

GETCONST_S = rffi.CStruct('_cffi_getconst_s',
                          ('value', rffi.ULONGLONG),
                          ('ctx', PCTX),
                          ('gindex', rffi.INT))

ll_parse_c_type = llexternal('pypy_parse_c_type', [PINFO, rffi.CCHARP],
                             rffi.INT)
ll_search_in_globals = llexternal('pypy_search_in_globals',
                                  [PCTX, rffi.CCHARP, rffi.SIZE_T],
                                  rffi.INT)
ll_search_in_struct_unions = llexternal('pypy_search_in_struct_unions',
                                        [PCTX, rffi.CCHARP, rffi.SIZE_T],
                                        rffi.INT)
ll_set_cdl_realize_global_int = llexternal('pypy_set_cdl_realize_global_int',
                                           [lltype.Ptr(GLOBAL_S)],
                                           lltype.Void)
ll_enum_common_types = llexternal('pypy_enum_common_types',
                                  [rffi.INT], rffi.CCHARP)

def parse_c_type(info, input):
    with rffi.scoped_view_charp(input) as p_input:
        res = ll_parse_c_type(info, p_input)
    return rffi.cast(lltype.Signed, res)

NULL_CTX = lltype.nullptr(PCTX.TO)
FFI_COMPLEXITY_OUTPUT = 1200     # xxx should grow as needed
internal_output = lltype.malloc(rffi.VOIDPP.TO, FFI_COMPLEXITY_OUTPUT,
                                flavor='raw', zero=True, immortal=True)
PCTXOBJ = lltype.Ptr(lltype.Struct('cffi_ctxobj',
                                   ('ctx', PCTX.TO),
                                   ('info', PINFO.TO)))

def allocate_ctxobj(src_ctx):
    p = lltype.malloc(PCTXOBJ.TO, flavor='raw', zero=True)
    if src_ctx:
        rffi.c_memcpy(rffi.cast(rffi.VOIDP, p.ctx),
                      rffi.cast(rffi.VOIDP, src_ctx),
                      rffi.cast(rffi.SIZE_T, rffi.sizeof(PCTX.TO)))
    p.info.c_ctx = p.ctx
    p.info.c_output = internal_output
    rffi.setintfield(p.info, 'c_output_size', FFI_COMPLEXITY_OUTPUT)
    return p

def free_ctxobj(p):
    lltype.free(p, flavor='raw')

def get_num_types(src_ctx):
    return rffi.getintfield(src_ctx, 'c_num_types')

def search_in_globals(ctx, name):
    with rffi.scoped_view_charp(name) as c_name:
        result = ll_search_in_globals(ctx, c_name,
                                      rffi.cast(rffi.SIZE_T, len(name)))
    return rffi.cast(lltype.Signed, result)

def search_in_struct_unions(ctx, name):
    with rffi.scoped_view_charp(name) as c_name:
        result = ll_search_in_struct_unions(ctx, c_name,
                                            rffi.cast(rffi.SIZE_T, len(name)))
    return rffi.cast(lltype.Signed, result)
