import os, sys

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import intmask
from rpython.rlib import jit, jit_libffi, libffi, rdynload, objectmodel
from rpython.rlib.rarithmetic import r_singlefloat
from rpython.tool import leakfinder

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.argument import Arguments
from pypy.interpreter.gateway import interp2app, interpindirect2app
from pypy.interpreter.typedef import TypeDef
from pypy.objspace.std.iterobject import W_AbstractSeqIterObject

from pypy.module._rawffi.interp_array import W_ArrayInstance
from pypy.module._cffi_backend import ctypefunc, cdataobj, misc
from pypy.module._cffi_backend import newtype
from pypy.module._cppyy import ffitypes
from pypy.module.sys.version import PYPY_VERSION

from pypy.module._cppyy.capi.capi_types import C_SCOPE, C_TYPE, C_OBJECT,\
   C_METHOD, C_INDEX, C_INDEX_ARRAY, C_FUNC_PTR

backend_ext = '.so'
if sys.platform == 'win32':
    backend_ext = '.dll'
    dldflags = 0
else:
    dldflags = rdynload.RTLD_LOCAL | rdynload.RTLD_LAZY

backend_library = 'libcppyy_backend'

# this is not technically correct, but will do for now
std_string_name = 'std::string'

class _Arg:         # poor man's union
    _immutable_ = True
    def __init__(self, tc, h = rffi.cast(C_SCOPE, 0),
                           m = rffi.cast(C_METHOD, 0),
                           o = rffi.cast(C_OBJECT, 0),
                           u = rffi.cast(C_INDEX, -1),
                           i = rffi.cast(rffi.INT, -1),
                           d = rffi.cast(rffi.DOUBLE, -1.),
                           s = '',
                           p = rffi.cast(rffi.VOIDP, 0)):
        self.tc      = tc
        self._scope  = h
        self._method = m
        self._object = o
        self._index  = u
        self._int    = i
        self._double = d
        self._string = s
        self._voidp  = p

# use separate classes for the benefit of the rtyper
class _ArgH(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 'h', h = val)

def _ArgC(val):
    return _ArgH(val.handle)

class _ArgM(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 'm', m = val)

class _ArgO(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 'o', o = val)

class _ArgU(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 'u', u = val)

class _ArgI(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 'i', i = val)

class _ArgD(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 'd', d = val)

class _ArgS(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 's', s = val)

class _ArgP(_Arg):
    _immutable_ = True
    def __init__(self, val):
        _Arg.__init__(self, 'p', p = val)

# For the loadable CAPI, the calls start and end in RPython. Therefore, the standard
# _call of W_CTypeFunc, which expects wrapped objects, does not quite work: some
# vars (e.g. void* equivalent) can not be wrapped, and others (such as rfloat) risk
# rounding problems. This W_RCTypeFun then, takes args, instead of args_w. Note that
# rcall() is a new method, so as to not interfere with the base class call and _call
# when rtyping. It is also called directly (see call_capi below).
class W_RCTypeFunc(ctypefunc.W_CTypeFunc):
    @jit.unroll_safe
    def rcall(self, funcaddr, args):
        assert self.cif_descr
        self = jit.promote(self)
        # no checking of len(args) needed, as calls in this context are not dynamic

        # The following code is functionally similar to W_CTypeFunc._call, but its
        # implementation is tailored to the restricted use (include memory handling)
        # of the CAPI calls.
        space = self.space
        cif_descr = self.cif_descr
        size = cif_descr.exchange_size
        raw_string1 = rffi.cast(rffi.CCHARP, 0)
        raw_string2 = rffi.cast(rffi.CCHARP, 0)   # have max two in any CAPI
        buffer = lltype.malloc(rffi.CCHARP.TO, size, flavor='raw')
        try:
            for i in range(len(args)):
                data = rffi.ptradd(buffer, cif_descr.exchange_args[i])
                obj = args[i]
                argtype = self.fargs[i]
                # the following is clumsy, but the data types used as arguments are
                # very limited, so it'll do for now
                if obj.tc == 'h':
                    misc.write_raw_unsigned_data(data, rffi.cast(rffi.SIZE_T, obj._scope), argtype.size)
                elif obj.tc == 'm':
                    misc.write_raw_signed_data(data, rffi.cast(rffi.INTPTR_T, obj._method), argtype.size)
                elif obj.tc == 'o':
                    # additional cast of void* to intptr_t required for 32b (or intmask fails)
                    misc.write_raw_signed_data(data, rffi.cast(rffi.INTPTR_T, rffi.cast(rffi.VOIDP, obj._object)), argtype.size)
                elif obj.tc == 'u':
                    misc.write_raw_unsigned_data(data, rffi.cast(rffi.SIZE_T, obj._index), argtype.size)
                elif obj.tc == 'i':
                    misc.write_raw_signed_data(data, rffi.cast(rffi.INT, obj._int), argtype.size)
                elif obj.tc == 'd':
                    misc.write_raw_float_data(data, rffi.cast(rffi.DOUBLE, obj._double), argtype.size)
                elif obj.tc == 'p':
                    assert obj._voidp != rffi.cast(rffi.VOIDP, 0)
                    data = rffi.cast(rffi.VOIDPP, data)
                    data[0] = obj._voidp
                elif obj.tc == 's':
                    n = len(obj._string)
                    data = rffi.cast(rffi.CCHARPP, data)
                    if raw_string1 == rffi.cast(rffi.CCHARP, 0):
                        # XXX could use rffi.get_nonmovingbuffer_final_null()
                        raw_string1 = rffi.str2charp(obj._string)
                        data[0] = raw_string1
                    else:
                        assert raw_string2 == rffi.cast(rffi.CCHARP, 0)
                        raw_string2 = rffi.str2charp(obj._string)
                        data[0] = raw_string2
                else:   # only other use is voidp
                    assert obj.tc == 'p'
                    assert obj._voidp != rffi.cast(rffi.VOIDP, 0)
                    data = rffi.cast(rffi.VOIDPP, data)
                    data[0] = obj._voidp

            jit_libffi.jit_ffi_call(cif_descr,
                                    rffi.cast(rffi.VOIDP, funcaddr),
                                    buffer)

            resultdata = rffi.ptradd(buffer, cif_descr.exchange_result)
            # this wrapping is unnecessary, but the assumption is that given the
            # immediate unwrapping, the round-trip is removed
            w_res = self.ctitem.copy_and_convert_to_object(resultdata)
        finally:
            if raw_string1 != rffi.cast(rffi.CCHARP, 0):
                rffi.free_charp(raw_string1)
            if raw_string2 != rffi.cast(rffi.CCHARP, 0):
                rffi.free_charp(raw_string2)
            lltype.free(buffer, flavor='raw')
        return w_res

class State(object):
    def __init__(self, space):
        self.backend = None
        self.capi_calls = {}

        nt = newtype     # module from _cffi_backend
        state = space.fromcache(ffitypes.State)   # factored out common types

        # TODO: the following need to match up with the globally defined C_XYZ low-level
        # types (see capi/__init__.py), but by using strings here, that isn't guaranteed
        c_voidp      = state.c_voidp
        c_size_t     = state.c_size_t
        c_ptrdiff_t  = state.c_ptrdiff_t
        c_intptr_t   = state.c_intptr_t

        c_scope       = c_size_t
        c_type        = c_scope
        c_enum        = c_voidp
        c_object      = c_voidp
        c_method      = c_intptr_t
        c_index       = c_size_t
        c_index_array = c_voidp

        c_void    = state.c_void
        c_char    = state.c_char
        c_uchar   = state.c_uchar
        c_short   = state.c_short
        c_int     = state.c_int
        c_long    = state.c_long
        c_llong   = state.c_llong
        c_ullong  = state.c_ullong
        c_float   = state.c_float
        c_double  = state.c_double
        c_ldouble = state.c_ldouble

        c_ccharp  = state.c_ccharp

        self.capi_call_ifaces = {
            # direct interpreter access
            'compile'                  : ([c_ccharp],                 c_int),
            'cppyy_to_string'          : ([c_type, c_object],         c_ccharp),

            # name to opaque C++ scope representation
            'resolve_name'             : ([c_ccharp],                 c_ccharp),
            'resolve_enum'             : ([c_ccharp],                 c_ccharp),
            'get_scope'                : ([c_ccharp],                 c_scope),
            'actual_class'             : ([c_type, c_object],         c_type),
            'size_of_klass'            : ([c_type],                   c_size_t),
            'size_of_type'             : ([c_ccharp],                 c_size_t),

            'is_builtin'               : ([c_ccharp],                 c_int),
            'is_complete'              : ([c_ccharp],                 c_int),

            # memory management
            'allocate'                 : ([c_type],                   c_object),
            'deallocate'               : ([c_type, c_object],         c_void),
            'construct'                : ([c_type],                   c_object),
            'destruct'                 : ([c_type, c_object],         c_void),

            # method/function dispatching
            'call_v'       : ([c_method, c_object, c_int, c_voidp],   c_void),
            'call_b'       : ([c_method, c_object, c_int, c_voidp],   c_uchar),
            'call_c'       : ([c_method, c_object, c_int, c_voidp],   c_char),

            'call_h'       : ([c_method, c_object, c_int, c_voidp],   c_short),
            'call_i'       : ([c_method, c_object, c_int, c_voidp],   c_int),
            'call_l'       : ([c_method, c_object, c_int, c_voidp],   c_long),
            'call_ll'      : ([c_method, c_object, c_int, c_voidp],   c_llong),
            'call_f'       : ([c_method, c_object, c_int, c_voidp],   c_float),
            'call_d'       : ([c_method, c_object, c_int, c_voidp],   c_double),
            'call_ld'      : ([c_method, c_object, c_int, c_voidp],   c_ldouble),
            'call_nld'     : ([c_method, c_object, c_int, c_voidp],   c_double),

            'call_r'       : ([c_method, c_object, c_int, c_voidp],   c_voidp),
            # call_s actually takes an size_t* as last parameter, but this will do
            'call_s'       : ([c_method, c_object, c_int, c_voidp, c_voidp],    c_ccharp),
            'constructor'  : ([c_method, c_object, c_int, c_voidp],   c_object),
            'destructor'   : ([c_type, c_object],                     c_void),
            'call_o'       : ([c_method, c_object, c_int, c_voidp, c_type],     c_object),

            'function_address' : ([c_method],                         c_voidp), # TODO: verify

            # handling of function argument buffer
            'allocate_function_args'   : ([c_int],                    c_voidp),
            'deallocate_function_args' : ([c_voidp],                  c_void),
            'function_arg_sizeof'      : ([],                         c_size_t),
            'function_arg_typeoffset'  : ([],                         c_size_t),

            # scope reflection information
            'is_namespace'             : ([c_scope],                  c_int),
            'is_template'              : ([c_ccharp],                 c_int),
            'is_abstract'              : ([c_type],                   c_int),
            'is_enum'                  : ([c_ccharp],                 c_int),
            'is_aggregate'             : ([c_ccharp],                 c_int),
            'is_default_constructable' : ([c_ccharp],                 c_int),

            'get_all_cpp_names'        : ([c_scope, c_voidp],         c_voidp), # const char**

            # namespace reflection information
            'get_using_namespaces'     : ([c_scope],                  c_index),

            # type/class reflection information
            'final_name'               : ([c_type],                   c_ccharp),
            'scoped_final_name'        : ([c_type],                   c_ccharp),
            'has_virtual_destructor'   : ([c_type],                   c_int),
            'has_complex_hierarchy'    : ([c_type],                   c_int),
            'num_bases'                : ([c_type],                   c_int),
            'base_name'                : ([c_type, c_int],            c_ccharp),
            'is_subtype'               : ([c_type, c_type],           c_int),
            'is_smartptr'              : ([c_type],                   c_int),
            'smartptr_info'            : ([c_ccharp, c_voidp, c_voidp],         c_int),
            'add_smartptr_type'        : ([c_ccharp],                 c_void),

            'add_type_reducer'         : ([c_ccharp, c_ccharp],       c_void),

            'base_offset'              : ([c_type, c_type, c_object, c_int],    c_ptrdiff_t),

            # method/function reflection information
            'num_methods'              : ([c_scope],                  c_int),
            'method_indices_from_name' : ([c_scope, c_ccharp],        c_index_array),

            'get_method'               : ([c_scope, c_index],         c_method),

            'method_name'              : ([c_method],                 c_ccharp),
            'method_full_name'         : ([c_method],                 c_ccharp),
            'method_mangled_name'      : ([c_method],                 c_ccharp),
            'method_result_type'       : ([c_method],                 c_ccharp),
            'method_num_args'          : ([c_method],                 c_int),
            'method_req_args'          : ([c_method],                 c_int),
            'method_arg_name'          : ([c_method, c_int],          c_ccharp),
            'method_arg_type'          : ([c_method, c_int],          c_ccharp),
            'method_arg_default'       : ([c_method, c_int],          c_ccharp),
            'method_signature'         : ([c_method, c_int],          c_ccharp),
            'method_signature_max'     : ([c_method, c_int, c_int],   c_ccharp),
            'method_prototype'         : ([c_scope, c_method, c_int], c_ccharp),
            'is_const_method'          : ([c_method],                 c_int),

            'get_num_templated_methods': ([c_scope],                  c_int),
            'get_templated_method_name': ([c_scope, c_index],         c_ccharp),
            'is_templated_constructor' : ([c_scope, c_index],         c_int),
            'exists_method_template'   : ([c_scope, c_ccharp],        c_int),
            'method_is_template'       : ([c_scope, c_index],         c_int),
            'get_method_template'      : ([c_scope, c_ccharp, c_ccharp],           c_method),

            'get_global_operator'      : ([c_scope, c_scope, c_scope, c_ccharp],   c_index),

            # method properties
            'is_public_method'         : ([c_method],                 c_int),
            'is_protected_method'      : ([c_method],                 c_int),
            'is_constructor'           : ([c_method],                 c_int),
            'is_destructor'            : ([c_method],                 c_int),
            'is_staticmethod'          : ([c_method],                 c_int),

            # data member reflection information
            'num_datamembers'          : ([c_scope],                  c_int),
            'datamember_name'          : ([c_scope, c_int],           c_ccharp),
            'datamember_type'          : ([c_scope, c_int],           c_ccharp),
            'datamember_offset'        : ([c_scope, c_int],           c_intptr_t),
            'datamember_index'         : ([c_scope, c_ccharp],        c_int),

            # data member properties
            'is_publicdata'            : ([c_scope, c_int],           c_int),
            'is_protecteddata'         : ([c_scope, c_int],           c_int),
            'is_staticdata'            : ([c_scope, c_int],           c_int),
            'is_const_data'            : ([c_scope, c_int],           c_int),
            'is_enum_data'             : ([c_scope, c_int],           c_int),
            'get_dimension_size'       : ([c_scope, c_int, c_int],    c_int),

            # enum properties
            'get_enum'                 : ([c_scope, c_ccharp],        c_enum),
            'get_num_enum_data'        : ([c_enum],                   c_index),
            'get_enum_data_name'       : ([c_enum, c_index],          c_ccharp),
            'get_enum_data_value'      : ([c_enum, c_index],          c_llong),

            # misc helpers
            'strtoll'                  : ([c_ccharp],                 c_llong),
            'strtoull'                 : ([c_ccharp],                 c_ullong),
            'free'                     : ([c_voidp],                  c_void),

            'charp2stdstring'          : ([c_ccharp, c_size_t],       c_object),
            #stdstring2charp  actually takes an size_t* as last parameter, but this will do
            'stdstring2charp'          : ([c_object, c_voidp],        c_ccharp),
            'stdstring2stdstring'      : ([c_object],                 c_object),

            'longdouble2double'        : ([c_voidp],                  c_double),
            'double2longdouble'        : ([c_double, c_voidp],        c_void),

            'vectorbool_getitem'       : ([c_object, c_int],          c_int),
            'vectorbool_setitem'       : ([c_object, c_int, c_int],   c_void),
        }

        # size/offset are backend-specific but fixed after load
        self.c_sizeof_farg = 0
        self.c_offset_farg = 0


def load_backend(space):
    state = space.fromcache(State)
    if state.backend is None:
        from pypy.module._cffi_backend.libraryobj import W_Library
        if os.environ.get('CPPYY_BACKEND_LIBRARY'):
            libname = os.environ['CPPYY_BACKEND_LIBRARY']
            state.backend = W_Library(space, space.newtext(libname), dldflags)
        else:
            # try usual lookups
            try:
                if backend_library[-len(backend_ext):] == backend_ext:
                    fullname = backend_library
                else:
                    fullname = backend_library+backend_ext
                state.backend = W_Library(space, space.newtext(fullname), dldflags)
            except Exception as e:
                soabi = space.config.objspace.soabi
                if soabi is None:
                    soabi = '.pypy-%d%d' % PYPY_VERSION[:2]
                state.backend = W_Library(space, space.newtext(backend_library+soabi+backend_ext), dldflags)

        if state.backend:
            # fix constants
            state.c_sizeof_farg = _cdata_to_size_t(
                space, call_capi(space, 'function_arg_sizeof', []))
            state.c_offset_farg = _cdata_to_size_t(
                space, call_capi(space, 'function_arg_typeoffset', []))

def verify_backend(space):
    try:
        load_backend(space)
    except Exception:
        if objectmodel.we_are_translated():
            raise oefmt(space.w_ImportError,
                        "missing backend library %s", backend_library)
        return False
    return True

def call_capi(space, name, args):
    state = space.fromcache(State)
    try:
        c_call = state.capi_calls[name]
    except KeyError:
        if state.backend is None:
            verify_backend(space)
        iface = state.capi_call_ifaces[name]
        cfunc = W_RCTypeFunc(space, iface[0], iface[1], False)
        c_call = state.backend.load_function(cfunc, 'cppyy_'+name)
        # TODO: there must be a better way to trick the leakfinder ...
        if not objectmodel.we_are_translated():
            leakfinder.remember_free(c_call.ctype.cif_descr._obj0)
        state.capi_calls[name] = c_call
    with c_call as ptr:
        return c_call.ctype.rcall(ptr, args)

def _cdata_to_ptr(space, w_cdata):
    w_cdata = space.interp_w(cdataobj.W_CData, w_cdata, can_be_None=False)
    with w_cdata as ptr:
        return rffi.cast(rffi.VOIDP, ptr)   # escapes (is okay)
    return rffi.cast(rffi.VOIDP, 0)

def _cdata_to_cobject(space, w_cdata):
    ptr = _cdata_to_ptr(space, w_cdata)
    return rffi.cast(C_OBJECT, ptr)

_cdata_to_cenum = _cdata_to_cobject

def _cdata_to_size_t(space, w_cdata):
    return rffi.cast(rffi.SIZE_T, space.uint_w(w_cdata))

def _cdata_to_ptrdiff_t(space, w_cdata):
    return rffi.cast(rffi.PTRDIFF_T, space.int_w(w_cdata))

def _cdata_to_intptr_t(space, w_cdata):
    return rffi.cast(rffi.INTPTR_T, space.int_w(w_cdata))

def _cdata_to_ccharp(space, w_cdata):
    ptr = _cdata_to_ptr(space, w_cdata)
    return rffi.cast(rffi.CCHARP, ptr)

# direct interpreter access
def c_compile(space, code):
    return space.int_w(call_capi(space, 'compile', [_ArgS(code)]))
def c_cppyy_to_string(space, cppclass, cppobj):
    args = [_ArgC(cppclass), _ArgO(cppobj)]
    return charp2str_free(space, call_capi(space, 'cppyy_to_string', args))

# name to opaque C++ scope representation ------------------------------------
def c_resolve_name(space, name):
    return charp2str_free(space, call_capi(space, 'resolve_name', [_ArgS(name)]))
def c_resolve_enum(space, name):
    return charp2str_free(space, call_capi(space, 'resolve_enum', [_ArgS(name)]))
def c_get_scope_opaque(space, name):
    return rffi.cast(C_SCOPE, space.uint_w(call_capi(space, 'get_scope', [_ArgS(name)])))
def c_actual_class(space, cppclass, cppobj):
    args = [_ArgC(cppclass), _ArgO(cppobj)]
    return rffi.cast(C_TYPE, space.uint_w(call_capi(space, 'actual_class', args)))
def c_size_of_klass(space, cppclass):
    return _cdata_to_size_t(space, call_capi(space, 'size_of_klass', [_ArgC(cppclass)]))
def c_size_of_type(space, name):
    return _cdata_to_size_t(space, call_capi(space, 'size_of_type', [_ArgS(name)]))

def c_is_builtin(space, name):
    return space.bool_w(call_capi(space, 'is_builtin', [_ArgS(name)]))
def c_is_complete(space, name):
    return space.bool_w(call_capi(space, 'is_complete', [_ArgS(name)]))

# memory management ----------------------------------------------------------
def c_allocate(space, cppclass):
    return _cdata_to_cobject(space, call_capi(space, 'allocate', [_ArgC(cppclass)]))
def c_deallocate(space, cppclass, cppobj):
    call_capi(space, 'deallocate', [_ArgC(cppclass), _ArgO(cppobj)])
def c_construct(space, cppclass):
    return _cdata_to_cobject(space, call_capi(space, 'construct', [_ArgC(cppclass)]))
def c_destruct(space, cppclass, cppobj):
    call_capi(space, 'destruct', [_ArgC(cppclass), _ArgO(cppobj)])

# method/function dispatching ------------------------------------------------
def c_call_v(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    call_capi(space, 'call_v', args)
def c_call_b(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.UCHAR, space.c_uint_w(call_capi(space, 'call_b', args)))
def c_call_c(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.CHAR, space.bytes_w(call_capi(space, 'call_c', args))[0])
def c_call_h(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.SHORT, space.int_w(call_capi(space, 'call_h', args)))
def c_call_i(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.INT, space.c_int_w(call_capi(space, 'call_i', args)))
def c_call_l(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.LONG, space.int_w(call_capi(space, 'call_l', args)))
def c_call_ll(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.LONGLONG, space.r_longlong_w(call_capi(space, 'call_ll', args)))
def c_call_f(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.FLOAT, r_singlefloat(space.float_w(call_capi(space, 'call_f', args))))
def c_call_d(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return rffi.cast(rffi.DOUBLE, space.float_w(call_capi(space, 'call_d', args)))
def c_call_ld(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    #return rffi.cast(rffi.LONGDOUBLE, space.float_w(call_capi(space, 'call_ld', args)))
    # call_nld narrows long double to double
    return rffi.cast(rffi.DOUBLE, space.float_w(call_capi(space, 'call_nld', args)))

def c_call_r(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return _cdata_to_ptr(space, call_capi(space, 'call_r', args))
def c_call_s(space, cppmeth, cppobj, nargs, cargs):
    length = lltype.malloc(rffi.SIZE_TP.TO, 1, flavor='raw')
    try:
        w_cstr = call_capi(space, 'call_s',
            [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs),
             _ArgP(rffi.cast(rffi.VOIDP, length))])
        cstr_len = int(intmask(length[0]))
    finally:
        lltype.free(length, flavor='raw')
    return _cdata_to_ccharp(space, w_cstr), cstr_len
def c_constructor(space, cppmeth, cppobj, nargs, cargs):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs)]
    return _cdata_to_cobject(space, call_capi(space, 'constructor', args))
def c_destructor(space, cppclass, cppobj):
    call_capi(space, 'constructor', [_ArgC(cppclass), _ArgO(cppobj)])
def c_call_o(space, cppmeth, cppobj, nargs, cargs, cppclass):
    args = [_ArgM(cppmeth), _ArgO(cppobj), _ArgI(nargs), _ArgP(cargs), _ArgC(cppclass)]
    return _cdata_to_cobject(space, call_capi(space, 'call_o', args))

def c_function_address(space, cppmeth):
    return rffi.cast(C_FUNC_PTR,
        _cdata_to_ptr(space, call_capi(space, 'function_address', [_ArgM(cppmeth)])))

# handling of function argument buffer ---------------------------------------
def c_allocate_function_args(space, size):
    return _cdata_to_ptr(space, call_capi(space, 'allocate_function_args', [_ArgI(size)]))
def c_deallocate_function_args(space, cargs):
    call_capi(space, 'deallocate_function_args', [_ArgP(cargs)])
def c_function_arg_sizeof(space):
    state = space.fromcache(State)
    return state.c_sizeof_farg
def c_function_arg_typeoffset(space):
    state = space.fromcache(State)
    return state.c_offset_farg

# scope reflection information -----------------------------------------------
def c_is_namespace(space, scope):
    return space.bool_w(call_capi(space, 'is_namespace', [_ArgH(scope)]))
def c_is_template(space, name):
    return space.bool_w(call_capi(space, 'is_template', [_ArgS(name)]))
def c_is_abstract(space, cpptype):
    return space.bool_w(call_capi(space, 'is_abstract', [_ArgC(cpptype)]))
def c_is_enum(space, name):
    return space.bool_w(call_capi(space, 'is_enum', [_ArgS(name)]))
def c_is_aggregate(space, name):
    return space.bool_w(call_capi(space, 'is_aggregate', [_ArgS(name)]))
def c_is_default_constructable(space, name):
    return space.bool_w(call_capi(space, 'is_default_constructable', [_ArgS(name)]))

def c_get_all_cpp_names(space, cppscope):
    sz = lltype.malloc(rffi.SIZE_TP.TO, 1, flavor='raw', zero=True)
    try:
        args = [_ArgC(cppscope), _ArgP(rffi.cast(rffi.VOIDP, sz))]
        rawnames = rffi.cast(rffi.CCHARPP,
            _cdata_to_ptr(space, call_capi(space, 'get_all_cpp_names', args)))
        count = int(intmask(sz[0]))
    finally:
        lltype.free(sz, flavor='raw')
    allnames = []
    for i in range(count):
        pystr = rffi.charp2str(rawnames[i])
        c_free(space, rffi.cast(rffi.VOIDP, rawnames[i])) # c_free defined below
        allnames.append(pystr)
    c_free(space, rffi.cast(rffi.VOIDP, rawnames))        # id.
    return allnames

# namespace reflection information
def c_get_using_namespaces(space, cppscope):
    return space.uint_w(call_capi(space, 'get_using_namespaces', [_ArgC(cppscope)]))

# type/class reflection information ------------------------------------------
def c_final_name(space, handle):
    return charp2str_free(space, call_capi(space, 'final_name', [_ArgH(handle)]))
def c_scoped_final_name(space, handle):
    return charp2str_free(space, call_capi(space, 'scoped_final_name', [_ArgH(handle)]))
def c_has_virtual_destructor(space, handle):
    return space.bool_w(call_capi(space, 'has_virtual_destructor', [_ArgH(handle)]))
def c_has_complex_hierarchy(space, handle):
    return space.bool_w(call_capi(space, 'has_complex_hierarchy', [_ArgH(handle)]))
def c_num_bases(space, cppclass):
    return space.int_w(call_capi(space, 'num_bases', [_ArgC(cppclass)]))
def c_base_name(space, cppclass, base_index):
    args = [_ArgC(cppclass), _ArgI(base_index)]
    return charp2str_free(space, call_capi(space, 'base_name', args))
def c_is_subtype(space, derived, base):
    jit.promote(base)
    if derived == base:
        return bool(1)
    return space.bool_w(call_capi(space, 'is_subtype', [_ArgC(derived), _ArgC(base)]))
def c_is_smartptr(space, handle):
    return space.bool_w(call_capi(space, 'is_smartptr', [_ArgH(handle)]))
def c_smartptr_info(space, name):
    out_raw   = lltype.malloc(rffi.ULONGP.TO, 1, flavor='raw', zero=True)
    out_deref = lltype.malloc(rffi.ULONGP.TO, 1, flavor='raw', zero=True)
    try:
        args = [_ArgS(name),
           _ArgP(rffi.cast(rffi.VOIDP, out_raw)), _ArgP(rffi.cast(rffi.VOIDP, out_deref))]
        result = space.bool_w(call_capi(space, 'smartptr_info', args))
        raw   = rffi.cast(C_TYPE, out_raw[0])
        deref = rffi.cast(C_METHOD, out_deref[0])
    finally:
        lltype.free(out_deref, flavor='raw')
        lltype.free(out_raw, flavor='raw')
    return (result, raw, deref)
def c_add_smartptr_type(space, name):
    return space.bool_w(call_capi(space, 'add_smartptr_type', [_ArgS(name)]))

def c_add_type_reducer(space, reducable, reduced):
    return space.bool_w(call_capi(space, 'add_type_reducer', [_ArgS(reducable), _ArgS(reduced)]))

def _c_base_offset(space, derived_h, base_h, address, direction):
    args = [_ArgH(derived_h), _ArgH(base_h), _ArgO(address), _ArgI(direction)]
    return _cdata_to_ptrdiff_t(space, call_capi(space, 'base_offset', args))
def c_base_offset(space, derived, base, address, direction):
    if derived == base:
        return rffi.cast(rffi.LONG, 0)
    return _c_base_offset(space, derived.handle, base.handle, address, direction)
def c_base_offset1(space, derived_h, base, address, direction):
    return _c_base_offset(space, derived_h, base.handle, address, direction)

# method/function reflection information -------------------------------------
def c_num_methods(space, cppscope):
    return space.int_w(call_capi(space, 'num_methods', [_ArgC(cppscope)]))
def c_method_indices_from_name(space, cppscope, name):
    args = [_ArgC(cppscope), _ArgS(name)]
    indices = rffi.cast(C_INDEX_ARRAY,
        _cdata_to_ptr(space, call_capi(space, 'method_indices_from_name', args)))
    if not indices:
        return []
    py_indices = []
    i = 0
    index = indices[i]
    while index != rffi.cast(C_INDEX, -1):
        i += 1
        py_indices.append(index)
        index = indices[i]
    c_free(space, rffi.cast(rffi.VOIDP, indices))   # c_free defined below
    return py_indices

def c_get_method(space, cppscope, index):
    args = [_ArgC(cppscope), _ArgU(index)]
    return _cdata_to_intptr_t(space, call_capi(space, 'get_method', args))

def c_method_name(space, cppmeth):
    return charp2str_free(space, call_capi(space, 'method_name', [_ArgM(cppmeth)]))
def c_method_full_name(space, cppmeth):
    return charp2str_free(space, call_capi(space, 'method_full_name', [_ArgM(cppmeth)]))
def c_method_mangled_name(space, cppmeth):
    return charp2str_free(space, call_capi(space, 'method_mangled_name', [_ArgM(cppmeth)]))
def c_method_result_type(space, cppmeth):
    return charp2str_free(space, call_capi(space, 'method_result_type', [_ArgM(cppmeth)]))
def c_method_num_args(space, cppmeth):
    return space.int_w(call_capi(space, 'method_num_args', [_ArgM(cppmeth)]))
def c_method_req_args(space, cppmeth):
    return space.int_w(call_capi(space, 'method_req_args', [_ArgM(cppmeth)]))
def c_method_arg_name(space, cppmeth, arg_index):
    args = [_ArgM(cppmeth), _ArgI(arg_index)]
    return charp2str_free(space, call_capi(space, 'method_arg_name', args))
def c_method_arg_type(space, cppmeth, arg_index):
    args = [_ArgM(cppmeth), _ArgI(arg_index)]
    return charp2str_free(space, call_capi(space, 'method_arg_type', args))
def c_method_arg_default(space, cppmeth, arg_index):
    args = [_ArgM(cppmeth), _ArgI(arg_index)]
    return charp2str_free(space, call_capi(space, 'method_arg_default', args))
def c_method_signature(space, cppmeth, show_formalargs=True):
    args = [_ArgM(cppmeth), _ArgI(show_formalargs)]
    return charp2str_free(space, call_capi(space, 'method_signature', args))
def c_method_signature_max(space, cppmeth, show_formalargs, maxargs):
    args = [_ArgM(cppmeth), _ArgI(show_formalargs), _ArgI(maxargs)]
    return charp2str_free(space, call_capi(space, 'method_signature_max', args))
def c_method_prototype(space, cppscope, cppmeth, show_formalargs=True):
    args = [_ArgC(cppscope), _ArgM(cppmeth), _ArgI(show_formalargs)]
    return charp2str_free(space, call_capi(space, 'method_prototype', args))
def c_is_const_method(space, cppmeth):
    return space.bool_w(call_capi(space, 'is_const_method', [_ArgM(cppmeth)]))

def c_get_num_templated_methods(space, cppscope):
    return space.int_w(call_capi(space, 'get_num_templated_methods', [_ArgC(cppscope)]))
def c_get_templated_method_name(space, cppscope, index):
    args = [_ArgC(cppscope), _ArgU(index)]
    return charp2str_free(space, call_capi(space, 'get_templated_method_name', args))
def c_is_templated_constructor(space, cppscope, index):
    args = [_ArgC(cppscope), _ArgU(index)]
    return space.bool_w(space, call_capi(space, 'is_templated_constructor', args))
def c_exists_method_template(space, cppscope, name):
    args = [_ArgC(cppscope), _ArgS(name)]
    return space.bool_w(call_capi(space, 'exists_method_template', args))
def c_method_is_template(space, cppscope, index):
    args = [_ArgC(cppscope), _ArgU(index)]
    return space.bool_w(call_capi(space, 'method_is_template', args))
def c_get_method_template(space, cppscope, name, proto):
    args = [_ArgC(cppscope), _ArgS(name), _ArgS(proto)]
    return rffi.cast(C_METHOD, space.int_w(call_capi(space, 'get_method_template', args)))

def c_get_global_operator(space, nss, lc, rc, op):
    if nss is not None:
        args = [_ArgC(nss), _ArgC(lc), _ArgC(rc), _ArgS(op)]
        return rffi.cast(C_INDEX, space.uint_w(call_capi(space, 'get_global_operator', args)))
    return rffi.cast(C_INDEX, -1)

# method properties ----------------------------------------------------------
def c_is_public_method(space, cppmeth):
    return space.bool_w(call_capi(space, 'is_public_method', [_ArgM(cppmeth)]))
def c_is_protected_method(space, cppmeth):
    return space.bool_w(call_capi(space, 'is_protected_method', [_ArgM(cppmeth)]))
def c_is_constructor(space, cppmeth):
    return space.bool_w(call_capi(space, 'is_constructor', [_ArgM(cppmeth)]))
def c_is_destructor(space, cppmeth):
    return space.bool_w(call_capi(space, 'is_destructor', [_ArgM(cppmeth)]))
def c_is_staticmethod(space, cppmeth):
    return space.bool_w(call_capi(space, 'is_staticmethod', [_ArgM(cppmeth)]))

# data member reflection information -----------------------------------------
def c_num_datamembers(space, cppscope):
    return space.int_w(call_capi(space, 'num_datamembers', [_ArgC(cppscope)]))
def c_datamember_name(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgI(datamember_index)]
    return charp2str_free(space, call_capi(space, 'datamember_name', args))
def c_datamember_type(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgI(datamember_index)]
    return charp2str_free(space, call_capi(space, 'datamember_type', args))
def c_datamember_offset(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgI(datamember_index)]
    return _cdata_to_intptr_t(space, call_capi(space, 'datamember_offset', args))

def c_datamember_index(space, cppscope, name):
    args = [_ArgC(cppscope), _ArgS(name)]
    return space.int_w(call_capi(space, 'datamember_index', args))

# data member properties -----------------------------------------------------
def c_is_publicdata(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgU(datamember_index)]
    return space.bool_w(call_capi(space, 'is_publicdata', args))
def c_is_protecteddata(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgU(datamember_index)]
    return space.bool_w(call_capi(space, 'is_protecteddata', args))
def c_is_staticdata(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgU(datamember_index)]
    return space.bool_w(call_capi(space, 'is_staticdata', args))
def c_is_const_data(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgU(datamember_index)]
    return space.bool_w(call_capi(space, 'is_const_data', args))
def c_is_enum_data(space, cppscope, datamember_index):
    args = [_ArgC(cppscope), _ArgU(datamember_index)]
    return space.bool_w(call_capi(space, 'is_enum_data', args))
def c_get_dimension_size(space, cppscope, datamember_index, dim_idx):
    args = [_ArgC(cppscope), _ArgU(datamember_index), _ArgI(dim_idx)]
    return space.int_w(call_capi(space, 'get_dimension_size', args))

# enum properties ------------------------------------------------------------
def c_get_enum(space, cppscope, name):
    args = [_ArgC(cppscope), _ArgS(name)]
    return _cdata_to_cenum(call_capi(space, 'get_enum', args))
def c_num_enum_data(space, cppenum):
    return space.int_w(call_capi(space, 'num_enum_data', [_ArgE(cppenum)]))
def c_get_enum_data_name(space, cppenum, idata):
    args = [_ArgE(cppenum), _ArgU(idata)]
    return charp2str_free(space, call_capi(space, 'get_enum_data_name', args))
def c_get_enum_data_value(space, cppenum, idata):
    args = [_ArgE(cppenum), _ArgU(idata)]
    return rffi.cast(C_ENUM, call_capi(space, 'get_enum_data_value', args))

# misc helpers ---------------------------------------------------------------
def c_strtoll(space, svalue):
    return space.r_longlong_w(call_capi(space, 'strtoll', [_ArgS(svalue)]))
def c_strtoull(space, svalue):
    return space.r_ulonglong_w(call_capi(space, 'strtoull', [_ArgS(svalue)]))
def c_free(space, voidp):
    call_capi(space, 'free', [_ArgP(voidp)])

def charp2str_free(space, cdata):
    charp = rffi.cast(rffi.CCHARP, _cdata_to_ptr(space, cdata))
    pystr = rffi.charp2str(charp)
    c_free(space, rffi.cast(rffi.VOIDP, charp))
    return pystr

def c_charp2stdstring(space, svalue, sz):
    return _cdata_to_cobject(space, call_capi(space, 'charp2stdstring',
        [_ArgS(svalue), _ArgU(rffi.cast(C_INDEX, sz))]))
def c_stdstring2charp(space, cppstr):
    szp = lltype.malloc(rffi.SIZE_TP.TO, 1, flavor='raw')
    try:
        w_cstr = call_capi(space, 'stdstring2charp',
            [_ArgO(cppstr), _ArgP(rffi.cast(rffi.VOIDP, szp))])
        cstr_len = int(intmask(szp[0]))
    finally:
        lltype.free(szp, flavor='raw')
    return rffi.charpsize2str(_cdata_to_ccharp(space, w_cstr), cstr_len)
def c_stdstring2stdstring(space, cppobj):
    return _cdata_to_cobject(space, call_capi(space, 'stdstring2stdstring', [_ArgO(cppobj)]))

def c_longdouble2double(space, addr):
    return space.float_w(call_capi(space, 'longdouble2double', [_ArgP(addr)]))
def c_double2longdouble(space, dval, addr):
    call_capi(space, 'double2longdouble', [_ArgD(dval), _ArgP(addr)])

def c_vectorbool_getitem(space, vbool, idx):
    return call_capi(space, 'vectorbool_getitem', [_ArgO(vbool), _ArgI(idx)])
def c_vectorbool_setitem(space, vbool, idx, value):
    call_capi(space, 'vectorbool_setitem', [_ArgO(vbool), _ArgI(idx), _ArgI(value)])


# TODO: factor these out ...
# pythonizations
def stdstring_c_str(space, w_self):
    """Return a python string taking into account \0"""
    from pypy.module._cppyy import interp_cppyy
    cppstr = space.interp_w(interp_cppyy.W_CPPInstance, w_self, can_be_None=False)
    return space.newtext(c_stdstring2charp(space, cppstr._rawobject))

def vbool_getindex(space, w_vbool, w_idx):
    idx = space.getindex_w(w_idx, space.w_IndexError, "std::vector<bool> index")
    sz = space.len_w(w_vbool)
    if idx < 0: idx += sz
    if idx < 0 or idx >= sz:
        raise IndexError
    return idx

def vectorbool_getitem(space, w_self, w_idx):
    """Index a std::vector<bool>, return the value"""
    from pypy.module._cppyy import interp_cppyy
    vbool = space.interp_w(interp_cppyy.W_CPPInstance, w_self, can_be_None=False)
    idx = vbool_getindex(space, w_self, w_idx)
    item = c_vectorbool_getitem(space, vbool._rawobject, idx)
    return space.newbool(space.is_true(item))

def vectorbool_setitem(space, w_self, w_idx, w_value):
    """Index a std::vector<bool>, set the value"""
    from pypy.module._cppyy import interp_cppyy
    vbool = space.interp_w(interp_cppyy.W_CPPInstance, w_self, can_be_None=False)
    idx = vbool_getindex(space, w_self, w_idx)
    c_vectorbool_setitem(space, vbool._rawobject, idx, int(space.is_true(w_value)))

class W_STLVectorIter(W_AbstractSeqIterObject):
    # w_seq and index are in base class
    _immutable_fields_ = ['converter', 'data', 'len', 'stride']

    def __init__(self, space, w_vector):
        W_AbstractSeqIterObject.__init__(self, w_vector)
        # TODO: this should live in rpythonize.py or something so that the
        # imports can move to the top w/o getting circles
        from pypy.module._cppyy import interp_cppyy
        assert isinstance(w_vector, interp_cppyy.W_CPPInstance)
        vector = space.interp_w(interp_cppyy.W_CPPInstance, w_vector)

        v_type = c_resolve_name(space, vector.clsdecl.name+'::value_type')
        v_size = c_size_of_type(space, v_type)

        if not v_type or not v_size:
            raise NotImplementedError   # fallback on getitem

        from pypy.module._cppyy import converter
        self.converter = converter.get_converter(space, v_type, '')

        # this 'data' is from the decl, so not the pythonized data from pythonify.py
        w_arr = space.call_obj_args(vector.clsdecl.get_overload('data'), w_vector, Arguments(space, []))
        arr = space.interp_w(W_ArrayInstance, w_arr, can_be_None=True)
        if not arr:
            raise OperationError(space.w_StopIteration, space.w_None)

        self.data    = rffi.cast(rffi.CCHARP, space.uint_w(arr.getbuffer(space)))
        self.len     = space.uint_w(space.call_obj_args(vector.clsdecl.get_overload('size'), w_vector, Arguments(space, [])))
        self.stride  = v_size

    def descr_next(self, space):
        if self.w_seq is None:
            raise OperationError(space.w_StopIteration, space.w_None)
        if self.len <= self.index:
            self.w_seq = None
            raise OperationError(space.w_StopIteration, space.w_None)
        offset = lltype.direct_ptradd(self.data, rffi.cast(rffi.SIZE_T, self.index*self.stride))
        w_item = self.converter.from_memory(space, space.w_None, rffi.cast(rffi.LONG, offset))
        self.index += 1
        return w_item

def stdvector_iter(space, w_self):
    return W_STLVectorIter(space, w_self)


# setup pythonizations for later use at run-time
_pythonizations = {}
def register_pythonizations(space):
    "NOT_RPYTHON"

    allfuncs = [

        ### std::string
        stdstring_c_str,

        ### std::vector
        stdvector_iter,

        ### std::vector<bool>
        vectorbool_getitem,
        vectorbool_setitem,
    ]

    for f in allfuncs:
        _pythonizations[f.__name__] = interp2app(f).spacebind(space)

def _method_alias(space, w_pycppclass, m1, m2):
    space.setattr(w_pycppclass, space.newtext(m1),
                  space.getattr(w_pycppclass, space.newtext(m2)))

def pythonize(space, w_pycppclass, name):
    if name == "string":
        space.setattr(w_pycppclass, space.newtext("c_str"), _pythonizations["stdstring_c_str"])
        _method_alias(space, w_pycppclass, "_cppyy_as_builtin", "c_str")
        _method_alias(space, w_pycppclass, "__str__",           "c_str")

    if  name.find("std::vector<bool", 0, 16) == 0:
        space.setattr(w_pycppclass, space.newtext("__getitem__"), _pythonizations["vectorbool_getitem"])
        space.setattr(w_pycppclass, space.newtext("__setitem__"), _pythonizations["vectorbool_setitem"])

    elif name.find("std::vector", 0, 11) == 0:
        space.setattr(w_pycppclass, space.newtext("__iter__"), _pythonizations["stdvector_iter"])
