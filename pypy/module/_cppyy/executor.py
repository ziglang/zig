import sys

from pypy.interpreter.error import oefmt
from pypy.interpreter.argument import Arguments
from pypy.objspace.std.unicodeobject import W_UnicodeObject

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib import jit_libffi

from pypy.module._rawffi.interp_rawffi import letter2tp
from pypy.module._cppyy import helper, capi, ffitypes, lowlevelviews

# Executor objects are used to dispatch C++ methods. They are defined by their
# return type only: arguments are converted by Converter objects, and Executors
# only deal with arrays of memory that are either passed to a stub or libffi.
# No argument checking or conversions are done.
#
# If a libffi function is not implemented, FastCallNotPossible is raised. If a
# stub function is missing (e.g. if no reflection info is available for the
# return type), an app-level TypeError is raised.
#
# Executor instances are created by get_executor(<return type name>), see
# below. The name given should be qualified in case there is a specialised,
# exact match for the qualified type.


NULL = lltype.nullptr(jit_libffi.FFI_TYPE_P.TO)

class Executor(object):
    def __init__(self, space, extra):
        pass

    def cffi_type(self, space):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

    def execute(self, space, cppmethod, cppthis, num_args, args):
        raise oefmt(space.w_TypeError,
                    "return type not available or supported")

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible


class PtrTypeExecutor(Executor):
    _immutable_fields_ = ['typecode']
    typecode = 'P'

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def execute(self, space, cppmethod, cppthis, num_args, args):
        if hasattr(space, "fake"):
            raise NotImplementedError
        address = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        ipv = rffi.cast(rffi.UINTPTR_T, address)
        if ipv == rffi.cast(rffi.UINTPTR_T, 0):
            from pypy.module._cppyy import interp_cppyy
            return interp_cppyy.get_nullptr(space)
        shape = letter2tp(space, self.typecode)
        return lowlevelviews.W_LowLevelView(space, shape, sys.maxint/shape.size, ipv)


class VoidExecutor(Executor):
    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_void

    def execute(self, space, cppmethod, cppthis, num_args, args):
        capi.c_call_v(space, cppmethod, cppthis, num_args, args)
        return space.w_None

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        return space.w_None


class NumericExecutorMixin(object):
    _mixin_ = True

    def execute(self, space, cppmethod, cppthis, num_args, args):
        result = self.c_stubcall(space, cppmethod, cppthis, num_args, args)
        return self._wrap_object(space, rffi.cast(self.c_type, result))

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        result = rffi.ptradd(buf, cif_descr.exchange_result)
        return self._wrap_object(space, rffi.cast(self.c_ptrtype, result)[0])

class NumericRefExecutorMixin(object):
    _mixin_ = True

    def __init__(self, space, extra):
        Executor.__init__(self, space, extra)
        self.do_assign = False
        self.w_item = space.w_None

    def set_item(self, space, w_item):
        self.w_item = w_item
        self.do_assign = True

    def _wrap_reference(self, space, rffiptr):
        if self.do_assign:
            rffiptr[0] = rffi.cast(self.c_type, self._unwrap_object(space, self.w_item))
            self.do_assign = False
        return self._wrap_object(space, rffiptr[0])    # all paths, for rtyper

    def execute(self, space, cppmethod, cppthis, num_args, args):
        result = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        return self._wrap_reference(space, rffi.cast(self.c_ptrtype, result))

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        result = rffi.ptradd(buf, cif_descr.exchange_result)
        return self._wrap_reference(space,
            rffi.cast(self.c_ptrtype, rffi.cast(rffi.VOIDPP, result)[0]))

class LongDoubleExecutorMixin(object):
    # Note: not really supported, but returns normal double
    _mixin_ = True

    def execute(self, space, cppmethod, cppthis, num_args, args):
        result = self.c_stubcall(space, cppmethod, cppthis, num_args, args)
        return space.newfloat(result)

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

class LongDoubleExecutor(ffitypes.typeid(rffi.LONGDOUBLE), LongDoubleExecutorMixin, Executor):
    _immutable_ = True
    c_stubcall  = staticmethod(capi.c_call_ld)

class LongDoubleRefExecutorMixin(NumericRefExecutorMixin):
    # Note: not really supported, but returns normal double
    _mixin_ = True

    def _wrap_reference(self, space, rffiptr):
        if self.do_assign:
            capi.c_double2longdouble(space, space.float_w(self.w_item), rffiptr)
            self.do_assign = False
            return self.w_item
        return space.newfloat(capi.c_longdouble2double(space, rffiptr))

    def execute(self, space, cppmethod, cppthis, num_args, args):
        result = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        return self._wrap_reference(space, rffi.cast(self.c_ptrtype, result))

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        result = rffi.ptradd(buf, cif_descr.exchange_result)
        return self._wrap_reference(space,
            rffi.cast(self.c_ptrtype, rffi.cast(rffi.VOIDPP, result)[0]))

class LongDoubleRefExecutor(ffitypes.typeid(rffi.LONGDOUBLE), LongDoubleRefExecutorMixin, Executor):
    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp


class CStringExecutor(Executor):
    def execute(self, space, cppmethod, cppthis, num_args, args):
        vptr = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        ccp = rffi.cast(rffi.CCHARP, vptr)
        if ccp == rffi.cast(rffi.CCHARP, 0):
            return space.newbytes("")
        result = rffi.charp2str(ccp)   # TODO: make it a choice to free
        # debatable whether this should be newtext or newbytes; they are bytes
        # but will be more likely used as text after binding ... probably need
        # to make this configurable on a per-function bases (same as the old
        # char* v.s. byte* problem)
        return space.newtext(result)
        return space.newtext(result)


class CharNExecutor(object):
    _mixin_ = True
    def execute(self, space, cppmethod, cppthis, num_args, args):
        lres = capi.c_call_l(space, cppmethod, cppthis, num_args, args)
        return self._wrap_object(space, lres)

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        vptr = rffi.ptradd(buf, cif_descr.exchange_result)
        lres = rffi.cast(rffi.LONG, rffi.cast(rffi.LONGP, vptr)[0])
        return self._wrap_object(space, lres)

class WCharExecutor(ffitypes.typeid(lltype.UniChar), CharNExecutor, Executor):
    pass

class Char16Executor(ffitypes.typeid(ffitypes.CHAR16_T), CharNExecutor, Executor):
    pass

class Char32Executor(ffitypes.typeid(ffitypes.CHAR32_T), CharNExecutor, Executor):
    pass


class ConstructorExecutor(Executor):
    def execute(self, space, cppmethod, cpptype, num_args, args):
        from pypy.module._cppyy import interp_cppyy
        newthis = capi.c_constructor(space, cppmethod, cpptype, num_args, args)
        assert lltype.typeOf(newthis) == capi.C_OBJECT
        return space.newlong(rffi.cast(rffi.LONG, newthis))   # really want ptrdiff_t here


class InstanceExecutor(Executor):
    # For return of a C++ instance by value: MyClass func()
    _immutable_fields_ = ['clsdecl']

    def __init__(self, space, clsdecl):
        Executor.__init__(self, space, clsdecl)
        self.clsdecl = clsdecl

    def _wrap_result(self, space, obj):
        from pypy.module._cppyy import interp_cppyy
        return interp_cppyy.wrap_cppinstance(space,
            obj, self.clsdecl, do_cast=False, python_owns=True, fresh=True)

    def execute(self, space, cppmethod, cppthis, num_args, args):
        oresult = capi.c_call_o(space, cppmethod, cppthis, num_args, args, self.clsdecl)
        return self._wrap_result(space, rffi.cast(capi.C_OBJECT, oresult))


class InstancePtrExecutor(InstanceExecutor):
    # For return of a C++ instance by pointer: MyClass* func()

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def _wrap_result(self, space, obj):
        from pypy.module._cppyy import interp_cppyy
        return interp_cppyy.wrap_cppinstance(space, obj, self.clsdecl)

    def execute(self, space, cppmethod, cppthis, num_args, args):
        vptr = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        return self._wrap_result(space, rffi.cast(capi.C_OBJECT, vptr))

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        presult = rffi.ptradd(buf, cif_descr.exchange_result)
        obj = rffi.cast(capi.C_OBJECT, rffi.cast(rffi.VOIDPP, presult)[0])
        return self._wrap_result(space, obj)

class InstancePtrPtrExecutor(InstancePtrExecutor):
    # For return of a C++ instance by ptr-to-ptr or ptr-to-ref: MyClass*& func()

    def execute(self, space, cppmethod, cppthis, num_args, args):
        presult = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        vref = rffi.cast(rffi.VOIDPP, presult)
        return self._wrap_result(space, rffi.cast(capi.C_OBJECT, vref[0]))

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible


class ComplexExecutor(Executor):
    _immutable_fields_ = ['clsdecl', 'realf', 'imagf']

    def __init__(self, space, clsdecl):
        Executor.__init__(self, space, clsdecl)
        self.clsdecl = clsdecl
        self.realf = self.clsdecl.scope__dispatch__('real', '')
        self.imagf = self.clsdecl.scope__dispatch__('imag', '')

    def _convert2complex(self, space, cmplx):
        w_real = self.realf.call_impl(cmplx, [])
        w_imag = self.imagf.call_impl(cmplx, [])
        return space.newcomplex(space.float_w(w_real), space.float_w(w_imag))

    def execute(self, space, cppmethod, cppthis, num_args, args):
        cmplx = capi.c_call_o(space, cppmethod, cppthis, num_args, args, self.clsdecl)
        pycmplx = self._convert2complex(space, rffi.cast(capi.C_OBJECT, cmplx))
        capi.c_destruct(space, self.clsdecl, cmplx)
        return pycmplx

class ComplexRefExecutor(ComplexExecutor):
    def execute(self, space, cppmethod, cppthis, num_args, args):
        cmplx = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        return self._convert2complex(space, rffi.cast(capi.C_OBJECT, cmplx))

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        result = rffi.ptradd(buf, cif_descr.exchange_result)
        return self._convert2complex(space,
            rffi.cast(capi.C_OBJECT, rffi.cast(rffi.VOIDPP, result)[0]))


class StdStringExecutor(InstancePtrExecutor):
    def execute(self, space, cppmethod, cppthis, num_args, args):
        cstr, cstr_len = capi.c_call_s(space, cppmethod, cppthis, num_args, args)
        pystr = rffi.charpsize2str(cstr, cstr_len)
        capi.c_free(space, rffi.cast(rffi.VOIDP, cstr))
        return space.newbytes(pystr) 

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

class StdStringRefExecutor(InstancePtrExecutor):
    def __init__(self, space, clsdecl):
        from pypy.module._cppyy import interp_cppyy
        clsdecl = interp_cppyy.scope_byname(space, capi.std_string_name)
        InstancePtrExecutor.__init__(self, space, clsdecl)


class PyObjectExecutor(PtrTypeExecutor):
    def wrap_result(self, space, lresult):
        space.getbuiltinmodule("cpyext")
        from pypy.module.cpyext.pyobject import PyObject, from_ref, make_ref, decref
        result = rffi.cast(PyObject, lresult)
        w_obj = from_ref(space, result)
        if result:
            decref(space, result)
        return w_obj

    def execute(self, space, cppmethod, cppthis, num_args, args):
        if hasattr(space, "fake"):
            raise NotImplementedError
        vptr = capi.c_call_r(space, cppmethod, cppthis, num_args, args)
        return self.wrap_result(space, vptr)

    def execute_libffi(self, space, cif_descr, funcaddr, buf):
        if hasattr(space, "fake"):
            raise NotImplementedError
        jit_libffi.jit_ffi_call(cif_descr, funcaddr, buf)
        result = rffi.ptradd(buf, cif_descr.exchange_result)
        return self.wrap_result(space, rffi.cast(rffi.VOIDPP, result)[0])


class SmartPointerExecutor(InstanceExecutor):
    _immutable_fields_ = ['smartdecl', 'deref']

    def __init__(self, space, smartdecl, raw, deref):
        from pypy.module._cppyy.interp_cppyy import W_CPPClassDecl, get_pythonized_cppclass
        w_raw   = get_pythonized_cppclass(space, raw)
        rawdecl = space.interp_w(W_CPPClassDecl, space.findattr(w_raw, space.newtext("__cppdecl__")))
        InstanceExecutor.__init__(self, space, rawdecl)
        self.smartdecl = smartdecl
        self.deref     = deref

    def _wrap_result(self, space, obj):
        from pypy.module._cppyy import interp_cppyy
        return interp_cppyy.wrap_cppinstance(space, obj, self.clsdecl,
            self.smartdecl, self.deref, do_cast=False, python_owns=True, fresh=True)

class SmartPointerPtrExecutor(InstancePtrExecutor):
    _immutable_fields_ = ['smartdecl', 'deref']

    def __init__(self, space, smartdecl, raw, deref):
        # TODO: share this with SmartPointerExecutor through in mixin
        from pypy.module._cppyy.interp_cppyy import W_CPPClassDecl, get_pythonized_cppclass
        w_raw   = get_pythonized_cppclass(space, raw)
        rawdecl = space.interp_w(W_CPPClassDecl, space.findattr(w_raw, space.newtext("__cppdecl__")))
        InstancePtrExecutor.__init__(self, space, rawdecl)
        self.smartdecl = smartdecl
        self.deref     = deref

    def _wrap_result(self, space, obj):
        from pypy.module._cppyy import interp_cppyy
        # TODO: this is a pointer to a smart pointer, take ownership on the smart one?
        return interp_cppyy.wrap_cppinstance(space, obj, self.clsdecl,
            self.smartdecl, self.deref, do_cast=False)


_executors = {}
def get_executor(space, name):
    # Matching of 'name' to an executor factory goes through up to four levels:
    #   1) full, qualified match
    #   2) drop '&': by-ref is pretty much the same as by-value, python-wise
    #   3) types/classes, either by ref/ptr or by value
    #   4) additional special cases
    #
    # If all fails, a default is used, which can be ignored at least until use.

    # original, exact match
    try:
        return _executors[name](space, None)
    except KeyError:
        pass

    # resolved, exact match
    name = capi.c_resolve_name(space, name)
    try:
        return _executors[name](space, None)
    except KeyError:
        pass

    compound = helper.compound(name)
    clean_name = capi.c_resolve_name(space, helper.clean_type(name))

    # clean lookup
    try:
        return _executors[clean_name+compound](space, None)
    except KeyError:
        pass

    # drop '&': by-ref is pretty much the same as by-value, python-wise
    if compound and compound[len(compound)-1] == '&':
        # TODO: this does not actually work with Reflex (?)
        try:
            return _executors[clean_name](space, None)
        except KeyError:
            pass

    # types/classes, either by ref/ptr or by value
    from pypy.module._cppyy import interp_cppyy
    cppclass = interp_cppyy.scope_byname(space, clean_name)
    if cppclass:
        # type check for the benefit of the annotator
        from pypy.module._cppyy.interp_cppyy import W_CPPClassDecl
        clsdecl = space.interp_w(W_CPPClassDecl, cppclass, can_be_None=False)

        # check smart pointer type
        check_smart = capi.c_smartptr_info(space, clean_name)
        if check_smart[0]:
            if compound == '':
                return SmartPointerExecutor(space, clsdecl, check_smart[1], check_smart[2])
            elif compound == '*' or compound == '&':
                return SmartPointerPtrExecutor(space, clsdecl, check_smart[1], check_smart[2])
            # fall through: can still return smart pointer in non-smart way

        if clean_name.find('std::complex', 0, 12) == 0 and\
               (0 < clean_name.find('double') or 0 < clean_name.find('float')):
            if compound == '':
                return ComplexExecutor(space, clsdecl)
            elif compound == '&':
                return ComplexRefExecutor(space, clsdecl)

        if compound == '':
            return InstanceExecutor(space, clsdecl)
        elif compound == '*' or compound == '&':
            return InstancePtrExecutor(space, clsdecl)
        elif compound == '**' or compound == '*&':
            return InstancePtrPtrExecutor(space, clsdecl)
    elif "(anonymous)" in name:
        # special case: enum w/o a type name
        return _executors["internal_enum_type_t"](space, None)

    # 4) additional special cases
    if compound == '*':
        return _executors['void*'](space, None)  # allow at least passing of the pointer

    # currently used until proper lazy instantiation available in interp_cppyy
    return Executor(space, None)
 

_executors["void"]                = VoidExecutor
_executors["void*"]               = PtrTypeExecutor
_executors["const char*"]         = CStringExecutor
_executors["wchar_t"]             = WCharExecutor
_executors["char16_t"]            = Char16Executor
_executors["char32_t"]            = Char32Executor

# long double not really supported: narrows to double
_executors["long double"]          = LongDoubleExecutor
_executors["long double&"]         = LongDoubleRefExecutor

# special cases (note: 'string' aliases added below)
_executors["constructor"]         = ConstructorExecutor

_executors["std::basic_string<char>"]         = StdStringExecutor
_executors["const std::basic_string<char>&"]  = StdStringRefExecutor
_executors["std::basic_string<char>&"]        = StdStringRefExecutor

_executors["PyObject*"]           = PyObjectExecutor

# add basic (builtin) executors
def _build_basic_executors():
    "NOT_RPYTHON"
    type_info = (
        (bool,               capi.c_call_b,      ("bool",)),
        # TODO: either signed or unsigned is correct for a given platform ...
        (rffi.CHAR,          capi.c_call_c,      ("char", "unsigned char", "signed char")),
        (ffitypes.INT8_T,    capi.c_call_c,      ("int8_t",)),
        (ffitypes.UINT8_T,   capi.c_call_c,      ("uint8_t", "std::byte", "byte",)),
        (rffi.SHORT,         capi.c_call_h,      ("short", "short int", "unsigned short", "unsigned short int")),
        (rffi.INT,           capi.c_call_i,      ("int", "internal_enum_type_t")),
        (rffi.UINT,          capi.c_call_l,      ("unsigned", "unsigned int")),
        (rffi.LONG,          capi.c_call_l,      ("long", "long int")),
        (rffi.ULONG,         capi.c_call_l,      ("unsigned long", "unsigned long int")),
        (rffi.LONGLONG,      capi.c_call_ll,     ("long long", "long long int", "Long64_t")),
        (rffi.ULONGLONG,     capi.c_call_ll,     ("unsigned long long", "unsigned long long int", "ULong64_t")),
        (rffi.FLOAT,         capi.c_call_f,      ("float",)),
        (rffi.DOUBLE,        capi.c_call_d,      ("double",)),
#        (rffi.LONGDOUBLE, capi.c_call_ld,  ("long double",)),
    )

    for c_type, stub, names in type_info:
        class BasicExecutor(ffitypes.typeid(c_type), NumericExecutorMixin, Executor):
            _immutable_ = True
            c_stubcall  = staticmethod(stub)
        class BasicRefExecutor(ffitypes.typeid(c_type), NumericRefExecutorMixin, Executor):
            def cffi_type(self, space):
                state = space.fromcache(ffitypes.State)
                return state.c_voidp
        for name in names:
            _executors[name]              = BasicExecutor
            _executors[name+'&']          = BasicRefExecutor
            _executors['const '+name+'&'] = BasicRefExecutor     # no copy needed for builtins
_build_basic_executors()

# create the pointer executors; all real work is in the PtrTypeExecutor, since
# all pointer types are of the same size
def _build_ptr_executors():
    "NOT_RPYTHON"
    ptr_info = (
        ('b', ("bool",)),     # really unsigned char, but this works ...
        ('h', ("short int", "short")),
        ('H', ("unsigned short int", "unsigned short")),
        ('i', ("int",)),
        ('I', ("unsigned int", "unsigned")),
        ('l', ("long int", "long")),
        ('L', ("unsigned long int", "unsigned long")),
        ('f', ("float",)),
        ('d', ("double",)),
    )

    for tcode, names in ptr_info:
        class PtrExecutor(PtrTypeExecutor):
            _immutable_fields_ = ['typecode']
            typecode = tcode
        for name in names:
            _executors[name+'*'] = PtrExecutor
_build_ptr_executors()

# add another set of aliased names
def _add_aliased_executors():
    "NOT_RPYTHON"
    aliases = (
        ("const char*",                     "char*"),

        ("std::basic_string<char>",         "std::string"),
        ("const std::basic_string<char>&",  "const std::string&"),
        ("std::basic_string<char>&",        "std::string&"),

        ("PyObject*",                       "_object*"),
    )

    for c_type, alias in aliases:
        _executors[alias] = _executors[c_type]
_add_aliased_executors()
