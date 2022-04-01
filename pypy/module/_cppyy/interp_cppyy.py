import pypy.module._cppyy.capi as capi

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.function import Method
from pypy.interpreter.argument import Arguments
from pypy.interpreter.typedef import interp_attrproperty_w, descr_generic_ne, make_weakref_descr
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, GetSetProperty, interp_attrproperty
from pypy.interpreter.baseobjspace import W_Root

from rpython.rtyper.lltypesystem import rffi, lltype, llmemory

from rpython.rlib import jit, rdynload, rweakref, rgc
from rpython.rlib import jit_libffi, clibffi
from rpython.rlib.objectmodel import we_are_translated, keepalive_until_here

from pypy.module._cffi_backend import ctypefunc
from pypy.module._cppyy import converter, executor, ffitypes, helper

CLASS_FLAGS_IS_PINNED      = 0x0001

INSTANCE_FLAGS_PYTHON_OWNS = 0x0001
INSTANCE_FLAGS_IS_REF      = 0x0002
INSTANCE_FLAGS_IS_RVALUE   = 0x0004

OVERLOAD_FLAGS_USE_FFI     = 0x0001
OVERLOAD_FLAGS_CREATES     = 0x0002

FUNCTION_IS_GLOBAL         = 0x0001
FUNCTION_IS_STATIC         = 0x0001
FUNCTION_IS_METHOD         = 0x0002
FUNCTION_IS_CONSTRUCTOR    = 0x0004
FUNCTION_IS_TEMPLATE       = 0x0008
FUNCTION_IS_SETITEM        = 0x0010


class FastCallNotPossible(Exception):
    pass

# overload priorities: lower is preferred
priority = { 'void*'         : 100,
             'void**'        : 100,
             'float'         :  30,
             'double'        :  10,
             'bool'          :   1,
             'const string&' :   1, } # solves a specific string ctor overload

from rpython.rlib.listsort import make_timsort_class
CPPMethodBaseTimSort = make_timsort_class()
class CPPMethodSort(CPPMethodBaseTimSort):
    def lt(self, a, b):
        return a.priority() < b.priority()

class State(object):
    def __init__(self, space):
        # final scoped name -> opaque handle
        self.cppscope_cache = {
            'void' : W_CPPClassDecl(space, capi.C_NULL_TYPE, 'void') }
        # opaque handle -> app-level python class
        self.cppclass_registry = {}
        # app-level class generator callback
        self.w_clgen_callback = None
        # app-level function generator callback (currently not used)
        self.w_fngen_callback = None
        # C++11's nullptr
        self.w_nullptr = None

def get_nullptr(space):
    # construct a unique address that compares to NULL, serves as nullptr
    if hasattr(space, 'fake'):
        raise NotImplementedError
    state = space.fromcache(State)
    if state.w_nullptr is None:
        from pypy.module._rawffi.interp_rawffi import unpack_simple_shape
        from pypy.module._rawffi.interp_array import W_Array, W_ArrayInstance
        arr = space.interp_w(W_Array, unpack_simple_shape(space, space.newtext('P')))
        # TODO: fix this hack; fromaddress() will allocate memory if address
        # is null and there seems to be no way around it (ll_buffer can not
        # be touched directly)
        nullarr = arr.fromaddress(space, rffi.cast(rffi.ULONG, 0), 0)
        assert isinstance(nullarr, W_ArrayInstance)
        nullarr.free(space)
        state.w_nullptr = nullarr
    return state.w_nullptr

@unwrap_spec(scoped_name='text')
def resolve_name(space, scoped_name):
    return space.newtext(capi.c_resolve_name(space, scoped_name))


# memoized lookup of handles by final, scoped, name of classes/namespaces
@unwrap_spec(final_scoped_name='text')
def scope_byname(space, final_scoped_name):
    state = space.fromcache(State)
    try:
        return state.cppscope_cache[final_scoped_name]
    except KeyError:
        pass

    opaque_handle = capi.c_get_scope_opaque(space, final_scoped_name)
    assert lltype.typeOf(opaque_handle) == capi.C_SCOPE
    if opaque_handle:
        isns = capi.c_is_namespace(space, opaque_handle)
        if isns:
            cppscope = W_CPPNamespaceDecl(space, opaque_handle, final_scoped_name)
        else:
            if capi.c_has_complex_hierarchy(space, opaque_handle):
                cppscope = W_CPPComplexClassDecl(space, opaque_handle, final_scoped_name)
            else:
                cppscope = W_CPPClassDecl(space, opaque_handle, final_scoped_name)

        # store in the cache to prevent recursion
        state.cppscope_cache[final_scoped_name] = cppscope

        if not isns:
            # build overloads/data; TODO: also defer this for classes (a functional __dir__
            # and instrospection for help() is enough and allows more lazy loading)
            cppscope._build_overloads()
            cppscope._find_datamembers()

        return cppscope

    return None

@unwrap_spec(final_scoped_name='text')
def is_template(space, final_scoped_name):
    return space.newbool(capi.c_is_template(space, final_scoped_name))

def std_string_name(space):
    return space.newtext(capi.std_string_name)

@unwrap_spec(w_callback=W_Root)
def set_class_generator(space, w_callback):
    state = space.fromcache(State)
    state.w_clgen_callback = w_callback

@unwrap_spec(w_callback=W_Root)
def set_function_generator(space, w_callback):
    state = space.fromcache(State)
    state.w_fngen_callback = w_callback

def register_class(space, w_pycppclass):
    w_cppclass = space.findattr(w_pycppclass, space.newtext("__cppdecl__"))
    cppclass = space.interp_w(W_CPPClassDecl, w_cppclass)
    # add back-end specific method pythonizations (doing this on the wrapped
    # class allows simple aliasing of methods)
    capi.pythonize(space, w_pycppclass, cppclass.name)
    state = space.fromcache(State)
    state.cppclass_registry[cppclass.handle] = w_pycppclass


class W_CPPLibrary(W_Root):
    _immutable_ = True

    def __init__(self, space, cdll):
        self.cdll = cdll
        self.space = space

W_CPPLibrary.typedef = TypeDef(
    'CPPLibrary',
)
W_CPPLibrary.typedef.acceptable_as_base_class = True


#-----
# Classes involved with methods and functions come at two levels:
#   - overloads: user-facing collections of overloaded functions
#   - wrappers: internal holders of the individual C++ methods
#
#  W_CPPOverload:                 instance methods (base class)
#  W_CPPConstructorOverload:      constructors
#  W_CPPAbstractCtorOverload:     to prevent instantiation of abstract classes
#  W_CPPStaticOverload:           free and static functions
#  W_CPPTemplateOverload:         templated methods
#  W_CPPTemplateStaticOverload:   templated free and static functions
#
#  CPPMethod:         a single function or method (base class)
#  CPPSetItem:        specialization for Python's __setitem__
#
#  MethodWithProps:   python instancemethod that forwards properties
#
# All methods/functions derive from CPPMethod and are collected as overload
# candidates in user-facing overload classes. Templated methods are a two-step
# process, where first the template is instantiated (or selected if already
# available), which returns a callable object that is the actual bound method.

class CPPMethod(object):
    """Dispatcher of methods. Checks the arguments, find the corresponding FFI
    function if available, makes the call, and returns the wrapped result. It
    also takes care of offset casting and recycling of known objects through
    the memory_regulator."""

    _attrs_ = ['space', 'scope', 'cppmethod', 'arg_defs', 'args_required',
               'converters', 'executor', '_funcaddr', 'cif_descr']
    _immutable_fields_ = ['scope', 'cppmethod', 'arg_defs', 'args_required',
               'converters', 'executor', '_funcaddr', 'cif_descr']

    def __init__(self, space, decl_scope, cppmethod, arg_defs, args_required):
        self.space = space
        self.scope = decl_scope
        self.cppmethod = cppmethod
        self.arg_defs = arg_defs
        self.args_required = args_required

        # Setup of the method dispatch's innards is done lazily, i.e. only when
        # the method is actually used.
        self.converters = None
        self.executor = None
        self.cif_descr = lltype.nullptr(jit_libffi.CIF_DESCRIPTION)
        self._funcaddr = lltype.nullptr(capi.C_FUNC_PTR.TO)

    @jit.unroll_safe
    def call(self, cppthis, args_w, useffi):
        jit.promote(self)

        assert lltype.typeOf(cppthis) == capi.C_OBJECT

        # check number of given arguments against required (== total - defaults)
        args_expected = len(self.arg_defs)
        args_given = len(args_w)

        if args_given < self.args_required:
            raise oefmt(self.space.w_TypeError,
                "takes at least %d arguments (%d given)", self.args_required, args_given)
        elif args_expected < args_given:
            raise oefmt(self.space.w_TypeError,
                "takes at most %d arguments (%d given)", args_expected, args_given)

        # initial setup of converters, executors, and libffi (if available)
        if self.converters is None:
            try:
                self._setup(cppthis)
            except Exception as e:
                if self.converters is None:
                    raise oefmt(self.space.w_SystemError,
                        "unable to initialize converters (%s)", str(e))

        # attempt to call directly through ffi chain
        if useffi and self._funcaddr:
            try:
                return self.do_fast_call(cppthis, args_w)
            except FastCallNotPossible:
                pass      # can happen if converters or executor does not implement ffi

        # ffi chain must have failed; using stub functions instead
        args, stat = self.prepare_arguments(args_w)
        try:
            result = self.executor.execute(
                self.space, self.cppmethod, cppthis, len(args_w), args)
            if stat[0] != rffi.cast(rffi.ULONG, 0):
                what = rffi.cast(rffi.CCHARP, stat[1])
                pywhat = rffi.charp2str(what)
                capi.c_free(self.space, rffi.cast(rffi.VOIDP, what))
                raise OperationError(self.space.w_Exception, self.space.newtext(pywhat))
            return result
        finally:
            self.finalize_call(args, args_w)

    @jit.unroll_safe
    def do_fast_call(self, cppthis, args_w):
        if self.cif_descr == lltype.nullptr(jit_libffi.CIF_DESCRIPTION):
            raise FastCallNotPossible
        jit.promote(self)
        cif_descr = self.cif_descr
        # add extra space for const-ref support (see converter.py)
        buffer = lltype.malloc(rffi.CCHARP.TO,
            cif_descr.exchange_size+len(self.arg_defs)*rffi.sizeof(rffi.DOUBLE), flavor='raw')
        thisoff = 0
        try:
            if cppthis:
                # this pointer
                data = rffi.ptradd(buffer, cif_descr.exchange_args[0])
                x = rffi.cast(rffi.VOIDPP, data)
                x[0] = rffi.cast(rffi.VOIDP, cppthis)
                thisoff = 1

            # actual provided arguments
            i = -1      # needed if all arguments are defaults
            for i in range(len(args_w)):
                conv = self.converters[i]
                data = rffi.ptradd(buffer, cif_descr.exchange_args[i+thisoff])
                scratch = rffi.ptradd(buffer, cif_descr.exchange_size+i*rffi.sizeof(rffi.DOUBLE))
                conv.convert_argument_libffi(self.space, args_w[i], data, scratch)
            # drop in defaults for the rest
            for j in range(i+1, len(self.arg_defs)):
                conv = self.converters[j]
                data = rffi.ptradd(buffer, cif_descr.exchange_args[j+thisoff])
                conv.default_argument_libffi(self.space, data)

            assert self._funcaddr
            w_res = self.executor.execute_libffi(
                self.space, cif_descr, self._funcaddr, buffer)
        finally:
            lltype.free(buffer, flavor='raw')
            keepalive_until_here(args_w)
        return w_res

    # from ctypefunc; have my own version for annotater purposes and to disable
    # memory tracking (method life time is longer than the tests)
    @jit.dont_look_inside
    def _rawallocate(self, builder):
        builder.space = self.space

        # compute the total size needed in the CIF_DESCRIPTION buffer
        builder.nb_bytes = 0
        builder.bufferp = lltype.nullptr(rffi.CCHARP.TO)
        builder.fb_build()

        # allocate the buffer
        if we_are_translated():
            rawmem = lltype.malloc(rffi.CCHARP.TO, builder.nb_bytes,
                                   flavor='raw')
            rawmem = rffi.cast(jit_libffi.CIF_DESCRIPTION_P, rawmem)
        else:
            # gross overestimation of the length below, but too bad
            rawmem = lltype.malloc(jit_libffi.CIF_DESCRIPTION_P.TO, builder.nb_bytes,
                                   flavor='raw', track_allocation=False)

        # the buffer is automatically managed from the W_CTypeFunc instance
        self.cif_descr = rawmem

        # call again fb_build() to really build the libffi data structures
        builder.bufferp = rffi.cast(rffi.CCHARP, rawmem)
        builder.fb_build()
        assert builder.bufferp == rffi.ptradd(rffi.cast(rffi.CCHARP, rawmem),
                                              builder.nb_bytes)

        # fill in the 'exchange_*' fields
        builder.fb_build_exchange(rawmem)

        # fill in the extra fields
        builder.fb_extra_fields(rawmem)

        # call libffi's ffi_prep_cif() function
        res = jit_libffi.jit_ffi_prep_cif(rawmem)
        if res != clibffi.FFI_OK:
            raise oefmt(self.space.w_SystemError,
                        "libffi failed to build this function type")

    def _setup(self, cppthis):
        self.converters = [converter.get_converter(self.space, arg_type, arg_dflt)
                               for arg_type, arg_dflt in self.arg_defs]
        self.executor = executor.get_executor(
            self.space, capi.c_method_result_type(self.space, self.cppmethod))

        # Each CPPMethod corresponds one-to-one to a C++ equivalent and cppthis
        # has been offset to the matching class. Hence, the libffi pointer is
        # uniquely defined and needs to be setup only once.
        funcaddr = capi.c_function_address(self.space, self.cppmethod)
        if funcaddr:
            state = self.space.fromcache(ffitypes.State)

            # argument type specification (incl. cppthis if applicable)
            fargs = []
            try:
                if cppthis: fargs.append(state.c_voidp)
                for i, conv in enumerate(self.converters):
                    fargs.append(conv.cffi_type(self.space))
                fresult = self.executor.cffi_type(self.space)
            except:
                raise FastCallNotPossible

            # the following is derived from _cffi_backend.ctypefunc
            builder = ctypefunc.CifDescrBuilder(fargs[:], fresult, clibffi.FFI_DEFAULT_ABI)
            try:
                self._rawallocate(builder)
            except OperationError as e:
                if not e.match(self.space, self.space.w_NotImplementedError):
                    raise
                # else, eat the NotImplementedError.  We will get the
                # exception if we see an actual call
                if self.cif_descr:   # should not be True, but you never know
                    lltype.free(self.cif_descr, flavor='raw')
                    self.cif_descr = lltype.nullptr(jit_libffi.CIF_DESCRIPTION)
                raise FastCallNotPossible

            # success ...
            self._funcaddr = funcaddr

    @jit.unroll_safe
    def prepare_arguments(self, args_w):
        args = capi.c_allocate_function_args(self.space, len(args_w))
        stride = capi.c_function_arg_sizeof(self.space)
        for i in range(len(args_w)):
            conv = self.converters[i]
            w_arg = args_w[i]
            try:
                arg_i = lltype.direct_ptradd(rffi.cast(rffi.CCHARP, args), i*stride)
                conv.convert_argument(self.space, w_arg, rffi.cast(capi.C_OBJECT, arg_i))
            except:
                # fun :-(
                for j in range(i):
                    conv = self.converters[j]
                    arg_j = lltype.direct_ptradd(rffi.cast(rffi.CCHARP, args), j*stride)
                    conv.free_argument(self.space, rffi.cast(capi.C_OBJECT, arg_j))
                capi.c_deallocate_function_args(self.space, args)
                raise
        stat = rffi.cast(rffi.ULONGP,
            lltype.direct_ptradd(rffi.cast(rffi.CCHARP, args), int(len(args_w))*stride))
        stat[0] = rffi.cast(rffi.ULONG, 0)
        return args, stat

    @jit.unroll_safe
    def finalize_call(self, args, args_w):
        stride = capi.c_function_arg_sizeof(self.space)
        for i in range(len(args_w)):
            conv = self.converters[i]
            arg_i = lltype.direct_ptradd(rffi.cast(rffi.CCHARP, args), i*stride)
            conv.finalize_call(self.space, args_w[i])
            conv.free_argument(self.space, rffi.cast(capi.C_OBJECT, arg_i))
        capi.c_deallocate_function_args(self.space, args)

    def signature(self, show_formalargs=True):
        return capi.c_method_signature(self.space, self.cppmethod, show_formalargs)

    def prototype(self, show_formalargs=True):
        return capi.c_method_prototype(self.space, self.scope, self.cppmethod, show_formalargs)

    def priority(self):
        total_arg_priority = 0
        for arg_type, arg_dflt in self.arg_defs:
            total_arg_priority += priority.get(arg_type, 0)
            if '&&' in arg_type:
                total_arg_priority += 100
        return total_arg_priority

    @rgc.must_be_light_finalizer
    def __del__(self):
        try:
            if self.cif_descr:
                lltype.free(self.cif_descr, flavor='raw')
        except Exception:     # TODO: happens for templates, why?
            pass

    def __repr__(self):
        return "CPPMethod: %s" % self.prototype()

    def _freeze_(self):
        assert 0, "you should never have a pre-built instance of this!"


class CPPSetItem(CPPMethod):
    """Method dispatcher specific to Python's __setitem__ mapped onto C++'s
    operator[](T). The former function takes an extra argument to assign to
    the return type of the latter."""

    _attrs_ = []

    def call(self, cppthis, args_w, useffi):
        end = len(args_w)-1
        if 0 <= end:
            w_item = args_w[end]
            args_w = args_w[:end]
            if self.converters is None:
                self._setup(cppthis)
            self.executor.set_item(self.space, w_item) # TODO: what about threads?
        CPPMethod.call(self, cppthis, args_w, useffi)


# CPPOverloads have settable flags that control memory and ffi behavior. These flags
# need forwarding, which the normal instancemethod does not provide, hence this
# derived class.
class MethodWithProps(Method):
    # set life management of result from the call
    def fget_creates(self, space):
        f = space.interp_w(W_CPPOverload, self.w_function)
        return f.fget_creates(space)

    @unwrap_spec(value=bool)
    def fset_creates(self, space, value):
        f = space.interp_w(W_CPPOverload, self.w_function)
        f.fset_creates(space, value)

    # set ownership policy of arguments (not yet implemented)
    def fget_mempolicy(self, space):
        f = space.interp_w(W_CPPOverload, self.w_function)
        return f.fget_mempolicy(space)

    @unwrap_spec(value=int)
    def fset_mempolicy(self, space, value):
        f = space.interp_w(W_CPPOverload, self.w_function)
        f.fset_mempolicy(space, value)

    # set to release the gil during call (not yet implemented)
    def fget_release_gil(self, space):
        f = space.interp_w(W_CPPOverload, self.w_function)
        return f.fget_release_gil(space)

    @unwrap_spec(value=bool)
    def fset_release_gil(self, space, value):
        f = space.interp_w(W_CPPOverload, self.w_function)
        f.fset_release_gil(space, value)

    # allow user to determine ffi use rules per overload
    def fget_useffi(self, space):
        f = space.interp_w(W_CPPOverload, self.w_function)
        return f.fget_useffi(space)

    @unwrap_spec(value=bool)
    def fset_useffi(self, space, value):
        f = space.interp_w(W_CPPOverload, self.w_function)
        f.fset_useffi(space, value)

MethodWithProps.typedef = TypeDef(
    "cpp_instancemethod",
    __doc__ = """cpp_instancemethod(function, instance, class)

Create an instance method object.""",
    __new__          = interp2app(MethodWithProps.descr_method__new__.im_func),
    __call__         = interp2app(MethodWithProps.descr_method_call),
    __get__          = interp2app(MethodWithProps.descr_method_get),
    __func__         = interp_attrproperty_w('w_function', cls=MethodWithProps),
    __self__         = interp_attrproperty_w('w_instance', cls=MethodWithProps),
    __getattribute__ = interp2app(MethodWithProps.descr_method_getattribute),
    __eq__           = interp2app(MethodWithProps.descr_method_eq),
    __ne__           = descr_generic_ne,
    __hash__         = interp2app(MethodWithProps.descr_method_hash),
    __repr__         = interp2app(MethodWithProps.descr_method_repr),
    __reduce__       = interp2app(MethodWithProps.descr_method__reduce__),
    __weakref__      = make_weakref_descr(MethodWithProps),
    __creates__      = GetSetProperty(MethodWithProps.fget_creates,     MethodWithProps.fset_creates),
    __mempolicy__    = GetSetProperty(MethodWithProps.fget_mempolicy,   MethodWithProps.fset_mempolicy),
    __release_gil__  = GetSetProperty(MethodWithProps.fget_release_gil, MethodWithProps.fset_release_gil),
    __useffi__       = GetSetProperty(MethodWithProps.fget_useffi,      MethodWithProps.fset_useffi),
    )
MethodWithProps.typedef.acceptable_as_base_class = False


class W_CPPOverload(W_Root):
    """App-level dispatcher: controls a collection of (potentially) overloaded methods
    or functions. Calls these in order and deals with error handling and reporting."""

    _attrs_ = ['space', 'scope', 'functions', 'flags']
    _immutable_fields_ = ['scope', 'functions[*]']

    def __init__(self, space, decl_scope, funcs, flags = OVERLOAD_FLAGS_USE_FFI):
        self.space  = space
        self.scope  = decl_scope
        from rpython.rlib import debug
        self.functions = debug.make_sure_not_resized(funcs)
        self.flags  = flags

    def descr_get(self, w_obj, w_cls=None):
        """functionobject.__get__(obj[, type]) -> method"""
        # TODO: check validity of w_cls if given
        # TODO: this does not work for Python 3, which does not have
        #  unbound methods (probably no common code possible, see also
        #  pypy/interpreter/function.py)
        space = self.space
        asking_for_bound = (space.is_none(w_cls) or
                            not space.is_w(w_obj, space.w_None) or
                            space.is_w(w_cls, space.type(space.w_None)))
        if asking_for_bound:
            return MethodWithProps(space, self, w_obj)
        else:
            return self   # unbound methods don't exist in Python 3

    @unwrap_spec(args_w='args_w')
    def call_args(self, args_w):
        jit.promote(self)
        w_this = args_w[0]
        cppinstance = self.space.interp_w(W_CPPInstance, w_this)
        cppinstance._nullcheck()
        if not capi.c_is_subtype(self.space, cppinstance.clsdecl, self.scope):
            raise oefmt(self.space.w_TypeError,
                "cannot pass %T instance as %s", w_this, self.scope.name)
        return self.call_impl(cppinstance.get_cppthis(self.scope), args_w[1:])

    @jit.unroll_safe
    def call_impl(self, cppthis, args_w):
        assert lltype.typeOf(cppthis) == capi.C_OBJECT

        # The following code tries out each of the functions in order. If
        # argument conversion fails (or simply if the number of arguments do
        # not match), that will lead to an exception, The JIT will snip out
        # those (always) failing paths, but only if they have no side-effects.
        # A second loop gathers all exceptions in the case all methods fail
        # (the exception gathering would otherwise be a side-effect as far as
        # the JIT is concerned).
        #
        # TODO: figure out what happens if a callback into from the C++ call
        # raises a Python exception.
        jit.promote(self)
        for i in range(len(self.functions)):
            cppyyfunc = self.functions[i]
            try:
                w_result = cppyyfunc.call(cppthis, args_w, self.flags & OVERLOAD_FLAGS_USE_FFI)
                if self.flags & OVERLOAD_FLAGS_CREATES:
                    if isinstance(w_result, W_CPPInstance):
                        cppinstance = self.space.interp_w(W_CPPInstance, w_result)
                        cppinstance.fset_python_owns(self.space, self.space.w_True)
                return w_result
            except Exception:
                pass

        # only get here if all overloads failed ...
        errmsg = 'none of the %d overloaded methods succeeded. Full details:' % len(self.functions)
        if hasattr(self.space, "fake"):     # FakeSpace fails errorstr (see below)
            raise OperationError(self.space.w_TypeError, self.space.newtext(errmsg))
        w_exc_type = None
        all_same_type = True
        for i in range(len(self.functions)):
            cppyyfunc = self.functions[i]
            try:
                # no need to set ownership on the return value, as none of the methods execute
                return cppyyfunc.call(cppthis, args_w, self.flags & OVERLOAD_FLAGS_USE_FFI)
            except OperationError as e:
                # special case if there's just one function, to prevent clogging the error message
                if len(self.functions) == 1:
                    raise
                if w_exc_type is None:
                    w_exc_type = e.w_type
                elif all_same_type and not e.match(self.space, w_exc_type):
                    all_same_type = False
                errmsg += '\n  '+cppyyfunc.prototype()+' =>\n'
                errmsg += '    '+e.errorstr(self.space)
            except Exception as e:
                # can not special case this for non-overloaded functions as we anyway need an
                # OperationError error down from here
                errmsg += '\n  '+cppyyfunc.prototype()+' =>\n'
                errmsg += '    Exception: '+str(e)

        if all_same_type and w_exc_type is not None:
            raise OperationError(w_exc_type, self.space.newtext(errmsg))
        else:
            raise OperationError(self.space.w_TypeError, self.space.newtext(errmsg))

    def prototype(self):
        sig = self.functions[0].prototype()
        for i in range(1, len(self.functions)):
            sig += '\n'+self.functions[i].prototype()
        return self.space.newtext(sig)

    @unwrap_spec(signature='text')
    def mp_overload(self, signature):
        sig = '(%s)' % signature
        for f in self.functions:
            if f.signature(False) == sig:
                if isinstance(self, W_CPPStaticOverload):
                    return W_CPPStaticOverload(self.space, self.scope, [f])
                return W_CPPOverload(self.space, self.scope, [f])
        raise oefmt(self.space.w_LookupError, "signature '%s' not found", signature)

    # set life management of result from the call
    def fget_creates(self, space):
        return space.newbool(bool(self.flags & OVERLOAD_FLAGS_CREATES))

    @unwrap_spec(value=bool)
    def fset_creates(self, space, value):
        if space.is_true(value):
            self.flags |= OVERLOAD_FLAGS_CREATES
        else:
            self.flags &= ~OVERLOAD_FLAGS_CREATES

    # set ownership policy of arguments (not yet implemented)
    def fget_mempolicy(self, space):
        return space.newint(0)

    @unwrap_spec(value=int)
    def fset_mempolicy(self, space, value):
        pass

    # set to release the gil during call (not yet implemented)
    def fget_release_gil(self, space):
        return space.newbool(True)

    @unwrap_spec(value=bool)
    def fset_release_gil(self, space, value):
        pass

    # allow user to determine ffi use rules per overload
    def fget_useffi(self, space):
        return space.newbool(bool(self.flags & OVERLOAD_FLAGS_USE_FFI))

    @unwrap_spec(value=bool)
    def fset_useffi(self, space, value):
        if space.is_true(value):
            self.flags |= OVERLOAD_FLAGS_USE_FFI
        else:
            self.flags &= ~OVERLOAD_FLAGS_USE_FFI

    def fget_doc(self, space):
        return self.prototype()

    def getname(self, space):
        # for the benefit of Method/instancemethod
        return capi.c_method_name(space, self.functions[0].cppmethod)

    def __repr__(self):
        return "W_CPPOverload(%s)" % [f.prototype() for f in self.functions]

W_CPPOverload.typedef = TypeDef(
    'CPPOverload',
    __get__         = interp2app(W_CPPOverload.descr_get),
    __call__        = interp2app(W_CPPOverload.call_args),
    __creates__     = GetSetProperty(W_CPPOverload.fget_creates,     W_CPPOverload.fset_creates),
    __mempolicy__   = GetSetProperty(W_CPPOverload.fget_mempolicy,   W_CPPOverload.fset_mempolicy),
    __release_gil__ = GetSetProperty(W_CPPOverload.fget_release_gil, W_CPPOverload.fset_release_gil),
    __useffi__      = GetSetProperty(W_CPPOverload.fget_useffi,      W_CPPOverload.fset_useffi),
    __overload__    = interp2app(W_CPPOverload.mp_overload),
    __doc__         = GetSetProperty(W_CPPOverload.fget_doc)
)


# overload collection of static (class and free) functions; these differ
# from methods only in the handling of 'cppthis'
class W_CPPStaticOverload(W_CPPOverload):
    _attrs_ = []

    def descr_get(self, w_obj, w_cls=None):
        if isinstance(w_obj, W_CPPInstance):
            # two possibilities: this is a static function called on an
            # instance and w_this must not be set, or a free function rebound
            # onto a class and w_this should be set
            cppinstance = self.space.interp_w(W_CPPInstance, w_obj)
            if cppinstance.clsdecl.handle != self.scope.handle:
                return MethodWithProps(self.space, self, w_obj)    # bound
        return self      # unbound

    @unwrap_spec(args_w='args_w')
    def call_args(self, args_w):
        jit.promote(self)
        return self.call_impl(capi.C_NULL_OBJECT, args_w)

    def __repr__(self):
        return "W_CPPStaticOverload(%s)" % [f.prototype() for f in self.functions]

W_CPPStaticOverload.typedef = TypeDef(
    'CPPStaticOverload',
    __get__         = interp2app(W_CPPStaticOverload.descr_get),
    __call__        = interp2app(W_CPPStaticOverload.call_args),
    __creates__     = GetSetProperty(W_CPPStaticOverload.fget_creates,     W_CPPStaticOverload.fset_creates),
    __mempolicy__   = GetSetProperty(W_CPPStaticOverload.fget_mempolicy,   W_CPPStaticOverload.fset_mempolicy),
    __release_gil__ = GetSetProperty(W_CPPStaticOverload.fget_release_gil, W_CPPStaticOverload.fset_release_gil),
    __useffi__      = GetSetProperty(W_CPPStaticOverload.fget_useffi,      W_CPPStaticOverload.fset_useffi),
    __overload__    = interp2app(W_CPPStaticOverload.mp_overload),
    __doc__         = GetSetProperty(W_CPPStaticOverload.fget_doc)
)


class W_CPPConstructorOverload(W_CPPOverload):
    _attrs_ = []

    def __init__(self, space, decl_scope, funcs, flags = OVERLOAD_FLAGS_USE_FFI):
        W_CPPOverload.__init__(self, space, decl_scope, funcs, flags)
        self.flags &= ~OVERLOAD_FLAGS_USE_FFI

    @unwrap_spec(args_w='args_w')
    def call_args(self, args_w):
        jit.promote(self)
        cppinstance = self.space.interp_w(W_CPPInstance, args_w[0])
        w_result = self.call_impl(rffi.cast(capi.C_OBJECT, self.scope.handle), args_w[1:])
        newthis = rffi.cast(capi.C_OBJECT, self.space.uint_w(w_result))
        if cppinstance is not None:
            cppinstance._rawobject = newthis
            memory_regulator.register(cppinstance)

    def __repr__(self):
        return "W_CPPConstructorOverload(%s)" % [f.prototype() for f in self.functions]

W_CPPConstructorOverload.typedef = TypeDef(
    'CPPConstructorOverload',
    __get__      = interp2app(W_CPPConstructorOverload.descr_get),
    __call__     = interp2app(W_CPPConstructorOverload.call_args),
    __overload__ = interp2app(W_CPPConstructorOverload.mp_overload),
    __doc__      = GetSetProperty(W_CPPConstructorOverload.fget_doc)
)

class W_CPPAbstractCtorOverload(W_CPPOverload):
    _attrs_ = []

    @unwrap_spec(args_w='args_w')
    def call_args(self, args_w):
        raise oefmt(self.space.w_TypeError,
            "cannot instantiate abstract class '%s'", self.scope.name)

    def __repr__(self):
        return "W_CPPAbstractCtorOverload"

W_CPPAbstractCtorOverload.typedef = TypeDef(
    'CPPAbstractCtorOverload',
    __get__    = interp2app(W_CPPAbstractCtorOverload.descr_get),
    __call__   = interp2app(W_CPPAbstractCtorOverload.call_args),
)


class TemplateOverloadMixin(object):
    """Mixin to instantiate templated methods/functions."""

    _attrs_ = ['tmpl_args_w']
    _mixin_ = True

    def construct_template_args(self, w_tpArgs, args_w = None):
        space = self.space
        tmpl_args = ''
        for i in range(space.len_w(w_tpArgs)):
            w_tp = space.getitem(w_tpArgs, space.newint(i))
            if space.isinstance_w(w_tp, space.w_text):
                s = space.text_w(w_tp)      # string describing type
            elif space.isinstance_w(w_tp, space.w_type):
                try:
                    # cppyy bound types
                    s = space.text_w(space.getattr(w_tp, space.newtext('__cpp_name__')))
                    if args_w:
                        # try to specialize the type match for the given object
                        cppinstance = self.space.interp_w(W_CPPInstance, args_w[i])
                        if cppinstance.rt_flags & INSTANCE_FLAGS_IS_RVALUE:
                            sugar = "&&"
                        elif cppinstance.flags & INSTANCE_FLAGS_IS_REF:
                            sugar = "*"
                        else:
                            sugar = "&"
                        s += sugar
                except OperationError:
                    # generic python types
                    s = space.text_w(space.getattr(w_tp, space.newtext('__name__')))
            else:
                # builtin types etc.
                s = space.text_w(space.str(w_tp))
            # map python types -> C++ types
            if s == 'str': s = 'std::string'
            if i != 0: tmpl_args += ', '
            tmpl_args += s
        return tmpl_args

    def instantiate_method_template(self, name, proto = ''):
        # instantiate/find new callable function
        space = self.space
        cppmeth = capi.c_get_method_template(space, self.scope, name, proto)
        if not cppmeth:
            raise oefmt(self.space.w_AttributeError,
                "failed to instantiate %s::%s for arguments '%s'",
                self.scope.name, name, proto)

        funcs = []
        ftype = self.scope._make_cppfunction(name, cppmeth, funcs)
        if ftype & FUNCTION_IS_STATIC:
            cppol = W_CPPStaticOverload(space, self.scope, funcs[:], self.flags)
        else:
            cppol = W_CPPOverload(space, self.scope, funcs[:], self.flags)
        return cppol

    def _call_method(self, method, args_w):
        if not self.space.is_w(self.w_this, self.space.w_None):
             return self.space.call_obj_args(method, self.w_this, Arguments(self.space, args_w))
        return self.space.call_args(method, Arguments(self.space, args_w))

    def template_call(self, name, tmpl_args, args_w):
        method = None

        fullname = name
        if tmpl_args is not None:
            fullname = fullname+'<'+tmpl_args+'>'

        try:
            # existing cached instantiations
            method = self.master.overloads[fullname]
            return self._call_method(method, args_w)
        except Exception:
            pass

        # if not known, or failed, try instantiation
        w_types = self.space.newtuple([self.space.type(obj_w) for obj_w in args_w])
        proto = self.construct_template_args(w_types, args_w)
        method = self.instantiate_method_template(fullname, proto)     # may raise

        # cache result as the full templated name only
        if fullname[-1] != '>':
            fullname = capi.c_method_full_name(self.space, method.functions[0].cppmethod)
        try:
            existing = self.master.overloads[fullname]
            allf = existing.functions + method.functions
            if isinstance(existing, W_CPPStaticOverload):
                cppol = W_CPPStaticOverload(self.space, self.scope, allf, self.flags)
            else:
                cppol = W_CPPOverload(self.space, self.scope, allf, self.flags)
            self.master.overloads[fullname] = cppol
        except KeyError:
            self.master.overloads[fullname] = method

        # perform actual call (which may still fail)
        return self._call_method(method, args_w)

    def getitem_impl(self, name, args_w):
        space = self.space

        if space.isinstance_w(args_w[0], space.w_tuple):
            w_args = args_w[0]
        else:
            w_args = space.newtuple(args_w)

        tmpl_args = self.construct_template_args(w_args)
        return self.clone(tmpl_args)   # defer instantiation until arguments are known


class W_CPPTemplateOverload(W_CPPOverload, TemplateOverloadMixin):
    """App-level dispatcher to allow both lookup/instantiation of templated methods and
    dispatch among overloads between templated and non-templated method."""

    _attrs_ = ['name', 'tmpl_args', 'overloads', 'master', 'w_this']
    _immutable_fields_ = ['name', 'tmpl_args']

    def __init__(self, space, name, tmpl_args, decl_scope, functions, flags = OVERLOAD_FLAGS_USE_FFI):
         W_CPPOverload.__init__(self, space, decl_scope, functions, flags)
         self.name = name
         self.tmpl_args = tmpl_args
         self.overloads = {}
         self.master = self
         self.w_this = space.w_None

    def clone(self, tmpl_args):
        other = W_CPPTemplateOverload(self.space, self.name, tmpl_args, self.scope, self.functions, self.flags)
        other.overloads = self.overloads
        other.master = self.master
        other.w_this = self.w_this
        return other

    def descr_get(self, w_cppinstance, w_cls=None):
        # TODO: don't return copy, but bind in an external object (like W_CPPOverload)
        if self.space.is_w(w_cppinstance, self.space.w_None):
            return self  # unbound, so no new instance needed
        cppol = W_CPPTemplateOverload(self.space, self.name, self.tmpl_args, self.scope, self.functions, self.flags)
        cppol.w_this = w_cppinstance
        cppol.master = self.master
        return cppol     # bound

    @unwrap_spec(args_w='args_w')
    def call_args(self, args_w):
        # direct call: either pick non-templated overload or attempt to deduce
        # the template instantiation from the argument types
        try:
            return W_CPPOverload.call_args(self, [self.w_this]+args_w)
        except Exception:
            pass
        return self.template_call(self.name, self.tmpl_args, args_w)

    @unwrap_spec(args_w='args_w')
    def getitem(self, args_w):
        return self.getitem_impl(self.name, args_w)

    def getname(self, space):
        return self.name

    def __repr__(self):
        return "W_CPPTemplateOverload(%s)" % [f.prototype() for f in self.functions]

W_CPPTemplateOverload.typedef = TypeDef(
    'CPPTemplateOverload',
    __get__         = interp2app(W_CPPTemplateOverload.descr_get),
    __getitem__     = interp2app(W_CPPTemplateOverload.getitem),
    __call__        = interp2app(W_CPPTemplateOverload.call_args),
    __creates__     = GetSetProperty(W_CPPTemplateOverload.fget_creates,     W_CPPTemplateOverload.fset_creates),
    __mempolicy__   = GetSetProperty(W_CPPTemplateOverload.fget_mempolicy,   W_CPPTemplateOverload.fset_mempolicy),
    __release_gil__ = GetSetProperty(W_CPPTemplateOverload.fget_release_gil, W_CPPTemplateOverload.fset_release_gil),
    __useffi__      = GetSetProperty(W_CPPTemplateOverload.fget_useffi,      W_CPPTemplateOverload.fset_useffi),
    __doc__         = GetSetProperty(W_CPPTemplateOverload.fget_doc)
)

class W_CPPTemplateStaticOverload(W_CPPStaticOverload, TemplateOverloadMixin):
    """Dispatcher to allow both lookup/instantiation of templated methods and
    select among templated and non-templated method overloads."""

    _attrs_ = ['name', 'tmpl_args', 'overloads', 'master', 'w_this']
    _immutable_fields_ = ['name', 'tmpl_args']

    def __init__(self, space, name, tmpl_args, decl_scope, funcs, flags = OVERLOAD_FLAGS_USE_FFI):
         W_CPPStaticOverload.__init__(self, space, decl_scope, funcs, flags)
         self.name = name
         self.tmpl_args = tmpl_args
         self.overloads = {}
         self.master = self
         self.w_this = space.w_None

    def clone(self, tmpl_args):
        other = W_CPPTemplateStaticOverload(self.space, self.name,
            tmpl_args, self.scope, self.functions, self.flags)
        other.overloads = self.overloads
        other.master = self.master
        other.w_this = self.w_this
        return other

    def descr_get(self, w_cppinstance, w_cls=None):
        # TODO: don't return copy, but bind in an external object (like W_CPPOverload)
        if isinstance(w_cppinstance, W_CPPInstance):
            cppinstance = self.space.interp_w(W_CPPInstance, w_cppinstance)
            if cppinstance.clsdecl.handle != self.scope.handle:
                cppol = W_CPPTemplateStaticOverload(self.space, self.name,
                    self.tmpl_args, self.scope, self.functions, self.flags)
                cppol.w_this = w_cppinstance
                cppol.master = self.master
                return cppol       # bound
        return self      # unbound

    @unwrap_spec(args_w='args_w')
    def call_args(self, args_w):
        # direct call: either pick non-templated overload or attempt to deduce
        # the template instantiation from the argument types
        try:
            return W_CPPStaticOverload.call_args(self, [self.w_this]+args_w)
        except Exception:
            pass
        return self.template_call(self.name, self.tmpl_args, args_w)

    @unwrap_spec(args_w='args_w')
    def getitem(self, args_w):
        return self.getitem_impl(self.name, args_w)

    def getname(self, space):
        return self.name

    def __repr__(self):
        return "W_CPPTemplateStaticOverload(%s)" % [f.prototype() for f in self.functions]

W_CPPTemplateStaticOverload.typedef = TypeDef(
    'CPPTemplateStaticOverload',
    __get__         = interp2app(W_CPPTemplateStaticOverload.descr_get),
    __getitem__     = interp2app(W_CPPTemplateStaticOverload.getitem),
    __call__        = interp2app(W_CPPTemplateStaticOverload.call_args),
    __creates__     = GetSetProperty(W_CPPTemplateStaticOverload.fget_creates,
                                     W_CPPTemplateStaticOverload.fset_creates),
    __mempolicy__   = GetSetProperty(W_CPPTemplateStaticOverload.fget_mempolicy,
                                     W_CPPTemplateStaticOverload.fset_mempolicy),
    __release_gil__ = GetSetProperty(W_CPPTemplateStaticOverload.fget_release_gil,
                                     W_CPPTemplateStaticOverload.fset_release_gil),
    __useffi__      = GetSetProperty(W_CPPTemplateStaticOverload.fget_useffi,
                                     W_CPPTemplateStaticOverload.fset_useffi),
    __doc__         = GetSetProperty(W_CPPTemplateStaticOverload.fget_doc)
)


#-----
# Classes for data members:
#
#  W_CPPDataMember:        instance data members
#  W_CPPConstDataMember:   specialization for const data members
#  W_CPPStaticData:        class-level and global/static data
#  W_CPPConstStaticData:   specialization for const global/static data
#
# Data is represented by an offset which is either a global pointer (static data)
# or an offset from the start of an instance (data members). The "const"
# specializations raise when attempting to set their value.

class W_CPPDataMember(W_Root):
    _attrs_ = ['space', 'scope', 'converter', 'offset']
    _immutable_fields = ['scope', 'converter', 'offset']

    def __init__(self, space, decl_scope, type_name, dimensions, offset):
        self.space = space
        self.scope = decl_scope
        self.converter = converter.get_converter(self.space, type_name, dimensions)
        self.offset = rffi.cast(rffi.INTPTR_T, offset)

    def _get_offset(self, cppinstance):
        if cppinstance:
            assert isinstance(cppinstance.clsdecl, W_CPPClassDecl)
            assert lltype.typeOf(cppinstance.clsdecl.handle) == lltype.typeOf(self.scope.handle)
            offset = self.offset + cppinstance.clsdecl.get_base_offset(cppinstance, self.scope)
        else:
            offset = self.offset
        return offset

    def get(self, w_cppinstance, w_pycppclass):
        cppinstance = self.space.interp_w(W_CPPInstance, w_cppinstance, can_be_None=True)
        if not cppinstance:
            raise oefmt(self.space.w_AttributeError,
                        "attribute access requires an instance")
        offset = self._get_offset(cppinstance)
        return self.converter.from_memory(self.space, w_cppinstance, offset)

    def set(self, w_cppinstance, w_value):
        cppinstance = self.space.interp_w(W_CPPInstance, w_cppinstance, can_be_None=True)
        if not cppinstance:
            raise oefmt(self.space.w_AttributeError,
                        "attribute access requires an instance")
        offset = self._get_offset(cppinstance)
        self.converter.to_memory(self.space, w_cppinstance, w_value, offset)
        return self.space.w_None

W_CPPDataMember.typedef = TypeDef(
    'CPPDataMember',
    __get__ = interp2app(W_CPPDataMember.get),
    __set__ = interp2app(W_CPPDataMember.set),
)
W_CPPDataMember.typedef.acceptable_as_base_class = False


class W_CPPConstDataMember(W_CPPDataMember):
    def set(self, w_cppinstance, w_value):
        raise oefmt(self.space.w_TypeError, "assignment to const data not allowed")

W_CPPConstDataMember.typedef = TypeDef(
    'CPPConstDataMember',
    __get__ = interp2app(W_CPPDataMember.get),
    __set__ = interp2app(W_CPPConstDataMember.set),
)
W_CPPConstDataMember.typedef.acceptable_as_base_class = False


class W_CPPStaticData(W_CPPDataMember):
    @jit.elidable_promote()
    def _get_offset(self, cppinstance):
        return self.offset

    def get(self, w_cppinstance, w_pycppclass):
        return self.converter.from_memory(self.space, self.space.w_None, self.offset)

    def set(self, w_cppinstance, w_value):
        self.converter.to_memory(self.space, self.space.w_None, w_value, self.offset)
        return self.space.w_None

W_CPPStaticData.typedef = TypeDef(
    'CPPStaticData',
    __get__ = interp2app(W_CPPStaticData.get),
    __set__ = interp2app(W_CPPStaticData.set),
)
W_CPPStaticData.typedef.acceptable_as_base_class = False


class W_CPPConstStaticData(W_CPPStaticData):
    def set(self, w_cppinstance, w_value):
        raise oefmt(self.space.w_TypeError, "assignment to const data not allowed")

W_CPPConstStaticData.typedef = TypeDef(
    'CPPConstStaticData',
    __get__ = interp2app(W_CPPConstStaticData.get),
    __set__ = interp2app(W_CPPConstStaticData.set),
)
W_CPPConstStaticData.typedef.acceptable_as_base_class = False


def is_static_data(space, w_obj):
    try:
        space.interp_w(W_CPPStaticData, w_obj)
        return space.w_True
    except Exception:
        return space.w_False

#-----
# Classes for data members:
#
# W_CPPScopeDecl         : scope base class
# W_CPPNamespaceDecl     : namespace scope
# W_CPPClassDecl         : class scope
#
# Namespaces and classes mainly differ in lookups of methods. Whereas classes
# can grown templated methods, namespaces are wide open to any additions. Such
# lookups are triggered from get_scoped_pycppitem (in pythonify.py). Further
# specialization is done on the type of data/methods that each can have.

class W_CPPScopeDecl(W_Root):
    _attrs_ = ['space', 'handle', 'flags', 'name', 'overloads', 'datamembers']
    _immutable_fields_ = ['handle', 'name']

    def __init__(self, space, opaque_handle, final_scoped_name):
        self.space = space
        assert lltype.typeOf(opaque_handle) == capi.C_SCOPE
        self.handle = opaque_handle
        self.flags = 0
        self.name = final_scoped_name
        self.overloads = {}
        # Do not call "self._build_overloadss()" here, so that a distinction can
        #  be made between testing for existence (i.e. existence in the cache
        #  of classes) and actual use. Point being that a class can use itself,
        #  e.g. as a return type or an argument to one of its methods.

        self.datamembers = {}
        # Idem as for self.overloads: a type could hold itself by pointer.

    def get_method_names(self):
        return self.space.newlist([self.space.newtext(name) for name in self.overloads])

    @unwrap_spec(name='text')
    def get_overload(self, name):
        try:
            return self.overloads[name]
        except KeyError:
            pass
        new_ol = self.find_overload(name)
        self.overloads[name] = new_ol
        return new_ol

    def get_datamember_names(self):
        return self.space.newlist([self.space.newtext(name) for name in self.datamembers])

    @unwrap_spec(name='text')
    def get_datamember(self, name):
        try:
            return self.datamembers[name]
        except KeyError:
            pass
        new_dm = self.find_datamember(name)
        self.datamembers[name] = new_dm
        return new_dm

    @unwrap_spec(name='text')
    def has_enum(self, name):
        if capi.c_is_enum(self.space, self.name+'::'+name):
            return self.space.w_True
        return self.space.w_False

    def _encode_dm_dimensions(self, idata):
        # encode dimensions (TODO: this is ugly, but here's where the info is)
        dims = []
        sz = capi.c_get_dimension_size(self.space, self, idata, len(dims))
        while 0 < sz:
            dims.append(str(sz))
            sz = capi.c_get_dimension_size(self.space, self, idata, len(dims))
        return ':'.join(dims)

    @unwrap_spec(name='text', signature='text')
    def scope__dispatch__(self, name, signature):
        overload = self.get_overload(name)
        sig = '(%s)' % signature
        for f in overload.functions:
            if f.signature(False) == sig:
                if isinstance(overload, W_CPPStaticOverload):
                    return W_CPPStaticOverload(self.space, self, [f])
                return W_CPPOverload(self.space, self, [f])
        raise oefmt(self.space.w_LookupError, "no overload matches signature")

    def __eq__(self, other):
        return self.handle == other.handle

    def __ne__(self, other):
        return self.handle != other.handle


# Namespaces and classes are separate as namespaces are (more) extensible
# with info from multiple dictionaries and do not need to bother with meta
# classes for inheritance. Both are python classes, though, and further
# refactoring may be in order at some point.
class W_CPPNamespaceDecl(W_CPPScopeDecl):
    _attrs_ = ['space', 'handle', 'name', 'overloads', 'datamembers']
    _immutable_fields_ = ['handle', 'name']

    def _make_cppfunction(self, pyname, cppmeth, funcs):
        num_args = capi.c_method_num_args(self.space, cppmeth)
        args_required = capi.c_method_req_args(self.space, cppmeth)
        arg_defs = []
        for i in range(num_args):
            arg_type = capi.c_method_arg_type(self.space, cppmeth, i)
            arg_dflt = capi.c_method_arg_default(self.space, cppmeth, i)
            arg_defs.append((arg_type, arg_dflt))
        funcs.append(CPPMethod(self.space, self, cppmeth, arg_defs, args_required))
        return FUNCTION_IS_GLOBAL

    def _make_datamember(self, dm_name, dm_idx):
        type_name = capi.c_datamember_type(self.space, self, dm_idx)
        if capi.c_is_enum_data(self.space, self, dm_idx):
            type_name = capi.c_resolve_enum(self.space, type_name)
        offset = capi.c_datamember_offset(self.space, self, dm_idx)
        if offset == rffi.cast(rffi.INTPTR_T, -1):
            raise self.missing_attribute_error(dm_name)
        dims = self._encode_dm_dimensions(dm_idx)
        if capi.c_is_const_data(self.space, self, dm_idx):
            datamember = W_CPPConstStaticData(self.space, self, type_name, dims, offset)
        else:
            datamember = W_CPPStaticData(self.space, self, type_name, dims, offset)
        self.datamembers[dm_name] = datamember
        return datamember

    def find_overload(self, meth_name):
        indices = capi.c_method_indices_from_name(self.space, self, meth_name)
        if indices:
            cppfunctions, ftype = [], 0
            templated = False
            for idx in indices:
                cppmeth = capi.c_get_method(self.space, self, idx)
                ftype |= self._make_cppfunction(meth_name, cppmeth, cppfunctions)
                if capi.c_method_is_template(self.space, self, idx):
                    templated = True
            if templated:
                return W_CPPTemplateStaticOverload(self.space, meth_name, None, self, cppfunctions[:])
            return W_CPPStaticOverload(self.space, self, cppfunctions[:])
        elif capi.c_exists_method_template(self.space, self, meth_name):
            return W_CPPTemplateStaticOverload(self.space, meth_name, None, self, [])
        raise self.missing_attribute_error(meth_name)

    def find_datamember(self, dm_name):
        dm_idx = capi.c_datamember_index(self.space, self, dm_name)
        if dm_idx < 0:
            raise self.missing_attribute_error(dm_name)
        datamember = self._make_datamember(dm_name, dm_idx)
        return datamember

    def is_namespace(self):
        return self.space.w_True

    def ns__dir__(self):
        alldir = capi.c_get_all_cpp_names(self.space, self)
        w_alldir = self.space.newlist([])
        for name in alldir:
            w_alldir.append(self.space.newtext(name))
        return w_alldir

    def missing_attribute_error(self, name):
        return oefmt(self.space.w_AttributeError,
            "namespace '%s' has no attribute %s", self.name, name)


W_CPPNamespaceDecl.typedef = TypeDef(
    'CPPNamespaceDecl',
    get_method_names = interp2app(W_CPPNamespaceDecl.get_method_names),
    get_overload = interp2app(W_CPPNamespaceDecl.get_overload),
    get_datamember_names = interp2app(W_CPPNamespaceDecl.get_datamember_names),
    get_datamember = interp2app(W_CPPNamespaceDecl.get_datamember),
    is_namespace = interp2app(W_CPPNamespaceDecl.is_namespace),
    has_enum = interp2app(W_CPPNamespaceDecl.has_enum),
    __cpp_name__ = interp_attrproperty('name', W_CPPNamespaceDecl, wrapfn="newtext"),
    __dispatch__ = interp2app(W_CPPNamespaceDecl.scope__dispatch__),
    __dir__ = interp2app(W_CPPNamespaceDecl.ns__dir__),
)
W_CPPNamespaceDecl.typedef.acceptable_as_base_class = False


class W_CPPClassDecl(W_CPPScopeDecl):
    _attrs_ = ['space', 'handle', 'name', 'overloads', 'datamembers', 'cppobjects']
    _immutable_fields_ = ['handle', 'name', 'overloads[*]', 'datamembers[*]']

    def __init__(self, space, opaque_handle, final_scoped_name):
        W_CPPScopeDecl.__init__(self, space, opaque_handle, final_scoped_name)
        self.cppobjects = rweakref.RWeakValueDictionary(int, W_CPPInstance)

    def _build_overloads(self):
        assert len(self.overloads) == 0
        methods_tmp = {}; ftype_tmp = {}

        # add all ordinary methods (incl. pre-instantiated templates)
        for idx in range(capi.c_num_methods(self.space, self)):
            cppmeth = capi.c_get_method(self.space, self, idx)
            if capi.c_is_constructor(self.space, cppmeth):
                pyname = '__init__'
            else:
                pyname = helper.map_operator_name(self.space,
                    capi.c_method_name(self.space, cppmeth),
                    capi.c_method_num_args(self.space, cppmeth),
                    capi.c_method_result_type(self.space, cppmeth))
            try:
                methods = methods_tmp[pyname]
            except KeyError:
                methods_tmp[pyname] = []; ftype_tmp[pyname] = 0
                methods = methods_tmp[pyname]
            ftype_tmp[pyname] |= self._make_cppfunction(pyname, cppmeth, methods)
            if capi.c_method_is_template(self.space, self, idx):
                ftype_tmp[pyname] |= FUNCTION_IS_TEMPLATE

        # the following covers the case where the only kind of operator[](idx)
        # returns are the ones that produce non-const references; these can be
        # used for __getitem__ just as much as for __setitem__, though
        if not "__getitem__" in methods_tmp:
            try:
                si_methods = methods_tmp["__setitem__"]
                gi_methods = []; ftype = 0
                for m in si_methods:
                    ftype |= self._make_cppfunction("__getitem__", m.cppmethod, gi_methods)
                methods_tmp["__getitem__"] = gi_methods; ftype_tmp["__getitem__"] = ftype
            except KeyError:
                pass          # just means there's no __setitem__ either

        # create the overloads from the method sets
        for pyname, methods in methods_tmp.iteritems():
            ftype = ftype_tmp[pyname]
            CPPMethodSort(methods).sort()
            if ftype & FUNCTION_IS_CONSTRUCTOR:
                if capi.c_is_abstract(self.space, self):
                    overload = W_CPPAbstractCtorOverload(self.space, self, methods[:])
                else:
                    overload = W_CPPConstructorOverload(self.space, self, methods[:])
            elif ftype & FUNCTION_IS_STATIC:
                if ftype & FUNCTION_IS_TEMPLATE:
                    cppname = capi.c_method_name(self.space, methods[0].cppmethod)
                    overload = W_CPPTemplateStaticOverload(self.space, cppname, None, self, methods[:])
                else:
                    overload = W_CPPStaticOverload(self.space, self, methods[:])
            elif ftype & FUNCTION_IS_TEMPLATE:
                cppname = capi.c_method_name(self.space, methods[0].cppmethod)
                overload = W_CPPTemplateOverload(self.space, cppname, None, self, methods[:])
            else:
                overload = W_CPPOverload(self.space, self, methods[:])
            self.overloads[pyname] = overload

        # add placeholders for all non-instantiated templated methods
        for idx in range(capi.c_get_num_templated_methods(self.space, self)):
            cppname = capi.c_get_templated_method_name(self.space, self, idx)
            self.overloads[cppname] = W_CPPTemplateOverload(self.space, cppname, None, self, [])

    def _make_cppfunction(self, pyname, cppmeth, funcs):
        num_args = capi.c_method_num_args(self.space, cppmeth)
        args_required = capi.c_method_req_args(self.space, cppmeth)
        arg_defs = []
        for i in range(num_args):
            arg_type = capi.c_method_arg_type(self.space, cppmeth, i)
            arg_dflt = capi.c_method_arg_default(self.space, cppmeth, i)
            arg_defs.append((arg_type, arg_dflt))
        ftype = 0
        if pyname == "__setitem__":
            cppfunction = CPPSetItem(self.space, self, cppmeth, arg_defs, args_required)
            ftype = FUNCTION_IS_SETITEM
        else:
            cppfunction = CPPMethod(self.space, self, cppmeth, arg_defs, args_required)
            if capi.c_is_constructor(self.space, cppmeth):
                ftype = FUNCTION_IS_CONSTRUCTOR
            elif capi.c_is_staticmethod(self.space, cppmeth):
                ftype = FUNCTION_IS_STATIC
            else:
                ftype = FUNCTION_IS_METHOD
        funcs.append(cppfunction)
        return ftype

    def _find_datamembers(self):
        num_datamembers = capi.c_num_datamembers(self.space, self)
        for i in range(num_datamembers):
            if not capi.c_is_publicdata(self.space, self, i):
                continue
            datamember_name = capi.c_datamember_name(self.space, self, i)
            type_name = capi.c_datamember_type(self.space, self, i)
            offset = capi.c_datamember_offset(self.space, self, i)
            if offset == rffi.cast(rffi.INTPTR_T, -1):
                continue      # dictionary problem; raises AttributeError on use
            is_static = bool(capi.c_is_staticdata(self.space, self, i))
            is_const  = bool(capi.c_is_const_data(self.space, self, i))
            dims = self._encode_dm_dimensions(i)
            if is_static and is_const:
                datamember = W_CPPConstStaticData(self.space, self, type_name, dims, offset)
            elif is_static:
                datamember = W_CPPStaticData(self.space, self, type_name, dims, offset)
            elif is_const:
                datamember = W_CPPConstDataMember(self.space, self, type_name, dims, offset)
            else:
                datamember = W_CPPDataMember(self.space, self, type_name, dims, offset)
            self.datamembers[datamember_name] = datamember

    def find_overload(self, meth_name):
        raise self.missing_attribute_error(meth_name)

    def find_datamember(self, name):
        raise self.missing_attribute_error(name)

    def get_base_offset(self, cppinstance, calling_scope):
        assert isinstance(cppinstance.clsdecl, W_CPPClassDecl)
        assert self == cppinstance.clsdecl
        return 0

    def get_cppthis(self, cppinstance, calling_scope):
        assert isinstance(cppinstance.clsdecl, W_CPPClassDecl)
        assert self == cppinstance.clsdecl
        return cppinstance.get_rawobject()

    def is_namespace(self):
        return self.space.w_False

    def get_base_names(self):
        bases = []
        num_bases = capi.c_num_bases(self.space, self)
        for i in range(num_bases):
            base_name = capi.c_base_name(self.space, self, i)
            bases.append(self.space.newtext(base_name))
        return self.space.newlist(bases)

    def missing_attribute_error(self, name):
        return oefmt(self.space.w_AttributeError,
            "class '%s' has no attribute %s", self.name, name)


W_CPPClassDecl.typedef = TypeDef(
    'CPPClassDecl',
    get_base_names = interp2app(W_CPPClassDecl.get_base_names),
    get_method_names = interp2app(W_CPPClassDecl.get_method_names),
    get_overload = interp2app(W_CPPClassDecl.get_overload),
    get_datamember_names = interp2app(W_CPPClassDecl.get_datamember_names),
    get_datamember = interp2app(W_CPPClassDecl.get_datamember),
    is_namespace = interp2app(W_CPPClassDecl.is_namespace),
    has_enum = interp2app(W_CPPClassDecl.has_enum),
    __cpp_name__ = interp_attrproperty('name', W_CPPClassDecl, wrapfn="newtext"),
    __dispatch__ = interp2app(W_CPPClassDecl.scope__dispatch__)
)
W_CPPClassDecl.typedef.acceptable_as_base_class = False


class W_CPPComplexClassDecl(W_CPPClassDecl):
    def get_base_offset(self, cppinstance, calling_scope):
        assert isinstance(cppinstance.clsdecl, W_CPPComplexClassDecl)
        assert self == cppinstance.clsdecl
        offset = capi.c_base_offset(self.space,
            self, calling_scope, cppinstance.get_rawobject(), 1)
        return offset

    def get_cppthis(self, cppinstance, calling_scope):
        assert isinstance(cppinstance.clsdecl, W_CPPComplexClassDecl)
        assert self == cppinstance.clsdecl
        offset = self.get_base_offset(cppinstance, calling_scope)
        return capi.direct_ptradd(cppinstance.get_rawobject(), offset)

W_CPPComplexClassDecl.typedef = TypeDef(
    'CPPComplexClassDecl',
    get_base_names = interp2app(W_CPPComplexClassDecl.get_base_names),
    get_method_names = interp2app(W_CPPComplexClassDecl.get_method_names),
    get_overload = interp2app(W_CPPComplexClassDecl.get_overload),
    get_datamember_names = interp2app(W_CPPComplexClassDecl.get_datamember_names),
    get_datamember = interp2app(W_CPPComplexClassDecl.get_datamember),
    is_namespace = interp2app(W_CPPComplexClassDecl.is_namespace),
    __cpp_name__ = interp_attrproperty('name', W_CPPComplexClassDecl, wrapfn="newtext"),
    __dispatch__ = interp2app(W_CPPComplexClassDecl.scope__dispatch__)
)
W_CPPComplexClassDecl.typedef.acceptable_as_base_class = False


class W_CPPInstance(W_Root):
    _attrs_ = ['space', 'clsdecl', '_rawobject', 'smartdecl', 'deref', 'flags', 'rt_flags',
               'finalizer_registered']
    _immutable_fields_ = ['clsdecl', 'smartdecl', 'deref', 'flags']

    finalizer_registered = False

    def __init__(self, space, decl, rawobject, isref, python_owns,
                 smartdecl=None, deref=rffi.cast(capi.C_METHOD, 0)):
        self.space = space
        self.clsdecl = decl
        assert isinstance(self.clsdecl, W_CPPClassDecl)
        assert lltype.typeOf(rawobject) == capi.C_OBJECT
        assert not isref or rawobject
        self._rawobject = rawobject
        assert not isref or not python_owns
        self.flags = 0
        if isref or (smartdecl and deref):
            self.flags |= INSTANCE_FLAGS_IS_REF
        self.rt_flags = 0
        if python_owns:
            self.rt_flags |= INSTANCE_FLAGS_PYTHON_OWNS
            self._opt_register_finalizer()
        self.smartdecl = smartdecl
        self.deref     = deref

    def _opt_register_finalizer(self):
        if not self.finalizer_registered and not hasattr(self.space, "fake"):
            assert self.rt_flags & INSTANCE_FLAGS_PYTHON_OWNS
            self.register_finalizer(self.space)
            self.finalizer_registered = True

    def _nullcheck(self):
        if not self._rawobject or \
               ((self.flags & INSTANCE_FLAGS_IS_REF) and not self.get_rawobject()):
            raise oefmt(self.space.w_ReferenceError,
                        "trying to access a NULL pointer")

    # allow user to determine ownership rules on a per object level
    def fget_python_owns(self, space):
        return space.newbool(bool(self.rt_flags & INSTANCE_FLAGS_PYTHON_OWNS))

    @unwrap_spec(value=bool)
    def fset_python_owns(self, space, value):
        if space.is_true(value):
            self.rt_flags |= INSTANCE_FLAGS_PYTHON_OWNS
            self._opt_register_finalizer()
        else:
            self.rt_flags &= ~INSTANCE_FLAGS_PYTHON_OWNS

    def get_cppthis(self, calling_scope):
        assert isinstance(self.clsdecl, W_CPPClassDecl)
        return self.clsdecl.get_cppthis(self, calling_scope)

    def get_rawobject(self):
        if not (self.flags & INSTANCE_FLAGS_IS_REF):
            return self._rawobject
        elif self.smartdecl and self.deref:
            args = capi.c_allocate_function_args(self.space, 0)
            rawptr = capi.c_call_r(self.space, self.deref, self._rawobject, 0, args)
            capi.c_deallocate_function_args(self.space, args)
            return rffi.cast(capi.C_OBJECT, rawptr)
        else:
            ptrptr = rffi.cast(rffi.VOIDPP, self._rawobject)
            return rffi.cast(capi.C_OBJECT, ptrptr[0])

    def _get_as_builtin(self):
        try:
            return self.space.call_method(self, "_cppyy_as_builtin")
        except OperationError as e:
            if not (e.match(self.space, self.space.w_TypeError) or
                    e.match(self.space, self.space.w_AttributeError)):
                # TODO: TypeError is raised by call_method if the method is not found;
                # it'd be a lot nicer if only AttributeError were raise
                raise
        return None

    def instance__init__(self, args_w):
        raise oefmt(self.space.w_TypeError,
                    "cannot instantiate abstract class '%s'",
                    self.clsdecl.name)

    def instance__eq__(self, w_other):
        # special case: if other is None, compare pointer-style
        if self.space.is_w(w_other, self.space.w_None):
            return self.space.newbool(not self._rawobject)

        # get here if no class-specific overloaded operator is available, try to
        # find a global overload in gbl, in __gnu_cxx (for iterators), or in the
        # scopes of the argument classes (TODO: implement that last option)
        try:
            # TODO: expecting w_other to be an W_CPPInstance is too limiting
            other = self.space.interp_w(W_CPPInstance, w_other)
            for name in ["", "__gnu_cxx", "__1"]:
                nss = scope_byname(self.space, name)
                meth_idx = capi.c_get_global_operator(
                    self.space, nss, self.clsdecl, other.clsdecl, "operator==")
                if meth_idx != rffi.cast(capi.C_INDEX, -1):
                    funcs = []
                    cppmeth = capi.c_get_method(self.space, nss, meth_idx)
                    nss._make_cppfunction("operator==", cppmeth, funcs)
                    ol = W_CPPStaticOverload(self.space, nss, funcs[:])
                    # TODO: cache this operator (not done yet, as the above does not
                    # select all overloads)
                    return ol.call_args([self, w_other])
        except OperationError as e:
            if not e.match(self.space, self.space.w_TypeError):
                raise

        # fallback 1: convert the object to a builtin equivalent
        w_as_builtin = self._get_as_builtin()
        if w_as_builtin is not None:
            return self.space.eq(w_as_builtin, w_other)

        # fallback 2: direct pointer comparison (the class comparison is needed since
        # the first data member in a struct and the struct have the same address)
        other = self.space.interp_w(W_CPPInstance, w_other)  # TODO: factor out
        iseq = (self._rawobject == other._rawobject) and (self.clsdecl == other.clsdecl)
        return self.space.newbool(iseq)

    def instance__ne__(self, w_other):
        return self.space.not_(self.instance__eq__(w_other))

    def instance__nonzero__(self):
        if not self._rawobject or \
               ((self.flags & INSTANCE_FLAGS_IS_REF) and not self.get_rawobject()):
            return self.space.w_False
        return self.space.w_True

    def instance__len__(self):
        w_as_builtin = self._get_as_builtin()
        if w_as_builtin is not None:
            return self.space.len(w_as_builtin)
        raise oefmt(self.space.w_TypeError,
                    "'%s' has no length", self.clsdecl.name)

    def instance__cmp__(self, w_other):
        from pypy.module.sys.version import CPYTHON_VERSION
        if CPYTHON_VERSION[0] != 3:
            w_as_builtin = self._get_as_builtin()
            if w_as_builtin is not None:
                return self.space.cmp(w_as_builtin, w_other)
        raise oefmt(self.space.w_AttributeError,
                    "'%s' has no attribute __cmp__", self.clsdecl.name)

    def instance__repr__(self):
        w_as_builtin = self._get_as_builtin()
        if w_as_builtin is not None:
            return self.space.repr(w_as_builtin)
        return self.space.newtext("<%s object at 0x%x>" %
                               (self.clsdecl.name, rffi.cast(rffi.UINTPTR_T, self.get_rawobject())))

    def smartptr(self):
        if self._rawobject and self.smartdecl:
            return wrap_cppinstance(self.space, self._rawobject, self.smartdecl, do_cast=False)

    def destruct(self):
        if self._rawobject:
            assert isinstance(self.clsdecl, W_CPPClassDecl)
            if self.smartdecl and self.deref:
                klass = self.smartdecl
            elif not (self.flags & INSTANCE_FLAGS_IS_REF):
                klass = self.clsdecl
            else:
                return
            memory_regulator.unregister(self)
            capi.c_destruct(self.space, klass, self._rawobject)
            self._rawobject = capi.C_NULL_OBJECT

    def _finalize_(self):
        if self.rt_flags & INSTANCE_FLAGS_PYTHON_OWNS:
            self.destruct()

W_CPPInstance.typedef = TypeDef(
    'CPPInstance',
    __python_owns__ = GetSetProperty(W_CPPInstance.fget_python_owns, W_CPPInstance.fset_python_owns),
    __init__ = interp2app(W_CPPInstance.instance__init__),
    __eq__ = interp2app(W_CPPInstance.instance__eq__),
    __ne__ = interp2app(W_CPPInstance.instance__ne__),
    # should be based on python version, but syntax is simpler this way
    __nonzero__ = interp2app(W_CPPInstance.instance__nonzero__),
    __bool__ = interp2app(W_CPPInstance.instance__nonzero__),
    __len__ = interp2app(W_CPPInstance.instance__len__),
    __cmp__ = interp2app(W_CPPInstance.instance__cmp__),
    __repr__ = interp2app(W_CPPInstance.instance__repr__),
    __smartptr__ = interp2app(W_CPPInstance.smartptr),
    __destruct__ = interp2app(W_CPPInstance.destruct),
)
W_CPPInstance.typedef.acceptable_as_base_class = True


class MemoryRegulator:
    _immutable_ = True

    @staticmethod
    def register(obj):
        if not obj._rawobject:
            return
        addr_as_int = int(rffi.cast(rffi.INTPTR_T, obj.get_rawobject()))
        clsdecl = obj.clsdecl
        assert isinstance(clsdecl, W_CPPClassDecl)
        clsdecl.cppobjects.set(addr_as_int, obj)

    @staticmethod
    def unregister(obj):
        if not obj._rawobject:
            return
        addr_as_int = int(rffi.cast(rffi.INTPTR_T, obj.get_rawobject()))
        clsdecl = obj.clsdecl
        assert isinstance(clsdecl, W_CPPClassDecl)
        clsdecl.cppobjects.set(addr_as_int, None) # actually deletes (pops)

    @staticmethod
    def retrieve(clsdecl, address):
        if not address:
            return None
        addr_as_int = int(rffi.cast(rffi.INTPTR_T, address))
        assert isinstance(clsdecl, W_CPPClassDecl)
        return clsdecl.cppobjects.get(addr_as_int)

memory_regulator = MemoryRegulator()


def get_pythonized_cppclass(space, handle):
    state = space.fromcache(State)
    try:
        w_pycppclass = state.cppclass_registry[handle]
    except KeyError:
        final_name = capi.c_scoped_final_name(space, handle)
        # the callback will cache the class by calling register_class
        w_pycppclass = space.call_function(state.w_clgen_callback, space.newtext(final_name))
    return w_pycppclass

def get_interface_func(space, w_callable, npar):
    state = space.fromcache(State)
    return space.call_function(state.w_fngen_callback, w_callable, space.newint(npar))

def wrap_cppinstance(space, rawobject, clsdecl,
                     smartdecl=None, deref=rffi.cast(capi.C_METHOD, 0),
                     do_cast=True, python_owns=False, is_ref=False, fresh=False):
    rawobject = rffi.cast(capi.C_OBJECT, rawobject)

    # cast to actual if requested and possible
    w_pycppclass = None
    if do_cast and rawobject and not (clsdecl.flags & CLASS_FLAGS_IS_PINNED):
        actual = capi.c_actual_class(space, clsdecl, rawobject)
        if actual != clsdecl.handle:
            try:
                w_pycppclass = get_pythonized_cppclass(space, actual)
                offset = capi.c_base_offset1(space, actual, clsdecl, rawobject, -1)
                rawobject = capi.direct_ptradd(rawobject, offset)
                w_cppdecl = space.findattr(w_pycppclass, space.newtext("__cppdecl__"))
                clsdecl = space.interp_w(W_CPPClassDecl, w_cppdecl)
            except Exception:
                # failed to locate/build the derived class, so stick to the base (note
                # that only get_pythonized_cppclass is expected to raise, so none of
                # the variables are re-assigned yet)
                pass

    if w_pycppclass is None:
        w_pycppclass = get_pythonized_cppclass(space, clsdecl.handle)

    # try to recycle existing object if this one is not newly created
    if not fresh and rawobject:
        address = rawobject
        if is_ref:
            address = rffi.cast(capi.C_OBJECT, rffi.cast(rffi.VOIDPP, address)[0])
        obj = memory_regulator.retrieve(clsdecl, address)
        if obj is not None:
            return obj

    # fresh creation
    w_cppinstance = space.allocate_instance(W_CPPInstance, w_pycppclass)
    cppinstance = space.interp_w(W_CPPInstance, w_cppinstance)
    cppinstance.__init__(space, clsdecl, rawobject, is_ref, python_owns, smartdecl, deref)
    memory_regulator.register(cppinstance)
    return w_cppinstance

def _addressof(space, w_obj):
    try:
        # attempt to extract address from array
        return rffi.cast(rffi.INTPTR_T, converter.get_rawbuffer(space, w_obj))
    except TypeError:
        pass
    # attempt to get address of C++ instance
    return rffi.cast(rffi.INTPTR_T, converter.get_rawobject(space, w_obj, False))

@unwrap_spec(w_obj=W_Root)
def addressof(space, w_obj):
    """Takes a bound C++ instance or array, returns the raw address."""
    address = _addressof(space, w_obj)
    return space.newlong(address)

@unwrap_spec(owns=bool, cast=bool)
def _bind_object(space, w_obj, w_clsdecl, owns=False, cast=False):
    try:
        # attempt address from array or C++ instance
        rawobject = rffi.cast(capi.C_OBJECT, _addressof(space, w_obj))
    except Exception:
        # accept integer value as address
        rawobject = rffi.cast(capi.C_OBJECT, space.uint_w(w_obj))
    decl = space.interp_w(W_CPPClassDecl, w_clsdecl)
    return wrap_cppinstance(space, rawobject, decl, python_owns=owns, do_cast=cast)

@unwrap_spec(owns=bool, cast=bool)
def bind_object(space, w_obj, w_pycppclass, owns=False, cast=False):
    """Takes an address and a bound C++ class proxy, returns a bound instance."""
    w_clsdecl = space.findattr(w_pycppclass, space.newtext("__cppdecl__"))
    if not w_clsdecl:
        w_clsdecl = scope_byname(space, space.text_w(w_pycppclass))
        if not w_clsdecl:
            raise oefmt(space.w_TypeError,
                        "no such class: %s", space.text_w(w_pycppclass))
    return _bind_object(space, w_obj, w_clsdecl, owns, cast)

def move(space, w_obj):
    """Casts the given instance into an C++-style rvalue."""
    obj = space.interp_w(W_CPPInstance, w_obj)
    if obj:
        obj.rt_flags |= INSTANCE_FLAGS_IS_RVALUE
    return w_obj


# pythonization interface ---------------------------------------------------

# do not auto-cast to given type
@unwrap_spec(w_pycppclass=W_Root)
def _pin_type(space, w_pycppclass):
    w_clsdecl = space.findattr(w_pycppclass, space.newtext("__cppdecl__"))
    decl = space.interp_w(W_CPPClassDecl, w_clsdecl)
    decl.flags |= CLASS_FLAGS_IS_PINNED
