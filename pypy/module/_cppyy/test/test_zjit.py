import py, os, sys
from .support import setup_make, soext

from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.objectmodel import specialize, instantiate
from rpython.rlib import rarithmetic, rbigint, jit
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper import llinterp
from pypy.interpreter.baseobjspace import InternalSpaceCache, W_Root

from pypy.module._cppyy import interp_cppyy, capi, executor

if os.getenv("CPPYY_DISABLE_FASTPATH"):
    py.test.skip("fast path is disabled by CPPYY_DISABLE_FASTPATH envar")

# load cpyext early, or its global vars are counted as leaks in the test
# (note that the module is not otherwise used in the test itself)
import pypy.module.cpyext

# add missing alt_errno (??)
def get_tlobj(self):
    try:
        return self._tlobj
    except AttributeError:
        from rpython.rtyper.lltypesystem import rffi
        PERRNO = rffi.CArrayPtr(rffi.INT)
        fake_p_errno = lltype.malloc(PERRNO.TO, 1, flavor='raw', zero=True,
                                     track_allocation=False)
        self._tlobj = {'RPY_TLOFS_p_errno': fake_p_errno,
                       'RPY_TLOFS_alt_errno': rffi.cast(rffi.INT, 0),
                       #'thread_ident': ...,
                       }
        return self._tlobj
llinterp.LLInterpreter.get_tlobj = get_tlobj

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("example01Dict"))+soext

def setup_module(mod):
    setup_make("example01")


class FakeBase(W_Root):
    typename = None

class FakeInt(FakeBase):
    typename = "int"
    def __init__(self, val):
        self.val = val
FakeBool = FakeInt
class FakeLong(FakeBase):
    typename = "long"
    def __init__(self, val):
        self.val = val
class FakeFloat(FakeBase):
    typename = "float"
    def __init__(self, val):
        self.val = val
class FakeComplex(FakeBase):
    typename = "complex"
    def __init__(self, rval, ival):
        self.obj = (rval, ival)
class FakeString(FakeBase):
    typename = "str"
    def __init__(self, val):
        self.val = val
class FakeUnicode(FakeBase):
    typename = "unicode"
    def __init__(self, val):
        self.val = val
class FakeTuple(FakeBase):
    typename = "tuple"
    def __init__(self, val):
        self.val = val
class FakeType(FakeBase):
    typename = "type"
    def __init__(self, name):
        self.name = name
        self.__name__ = name
    def getname(self, space, name):
        return self.name
class FakeBuffer(FakeBase):
    typedname = "buffer"
    def __init__(self, val):
        self.val = val
    def get_raw_address(self):
        raise ValueError("no raw buffer")
class FakeException(FakeType):
    def __init__(self, space, name):
        FakeType.__init__(self, name)
        self.msg = name
        self.space = space

class FakeUserDelAction(object):
    def __init__(self, space):
        pass

    def register_callback(self, w_obj, callback, descrname):
        pass

    def perform(self, executioncontext, frame):
        pass

class FakeState(object):
    def __init__(self, space):
        self.slowcalls = 0

class FakeFinalizerQueue(object):
    def register_finalizer(self, obj):
        pass

class FakeConfig(object):
    pass

class FakeSpace(object):
    fake = True

    w_None  = None
    w_str   = FakeType("str")
    w_text  = FakeType("str")
    w_bytes = FakeType("str")
    w_int   = FakeType("int")
    w_float = FakeType("float")

    def __init__(self):
        self.finalizer_queue = FakeFinalizerQueue()

        self.fromcache = InternalSpaceCache(self).getorbuild
        self.user_del_action = FakeUserDelAction(self)
        self.config = FakeConfig()
        self.config.translating = False

        # kill calls to c_call_i (i.e. slow path)
        def c_call_i(space, cppmethod, cppobject, nargs, args):
            assert not "slow path called"
            return capi.c_call_i(space, cppmethod, cppobject, nargs, args)
        executor.get_executor(self, 'int').__class__.c_stubcall = staticmethod(c_call_i)

        self.w_AttributeError      = FakeException(self, "AttributeError")
        self.w_Exception           = FakeException(self, "Exception")
        self.w_ImportError         = FakeException(self, "ImportError")
        self.w_KeyError            = FakeException(self, "KeyError")
        self.w_LookupError         = FakeException(self, "LookupError")
        self.w_NotImplementedError = FakeException(self, "NotImplementedError")
        self.w_OSError             = FakeException(self, "OSError")
        self.w_ReferenceError      = FakeException(self, "ReferenceError")
        self.w_RuntimeError        = FakeException(self, "RuntimeError")
        self.w_SystemError         = FakeException(self, "SystemError")
        self.w_TypeError           = FakeException(self, "TypeError")
        self.w_ValueError          = FakeException(self, "ValueError")

        self.w_True                = FakeBool(True)
        self.w_False               = FakeBool(False)

    def issequence_w(self, w_obj):
        return True

    def wrap(self, obj):
        assert 0

    @specialize.argtype(1)
    def newbool(self, obj):
        return FakeBool(obj)

    @specialize.argtype(1)
    def newint(self, obj):
        if not isinstance(obj, int):
            return FakeLong(rbigint.rbigint.fromrarith_int(obj))
        return FakeInt(obj)

    @specialize.argtype(1)
    def newlong(self, obj):
        return FakeLong(rbigint.rbigint.fromint(obj))

    @specialize.argtype(1)
    def newlong_from_rarith_int(self, obj):
        return FakeLong(rbigint.rbigint.fromrarith_int(obj))

    def newlong_from_rbigint(self, val):
        return FakeLong(obj)

    @specialize.argtype(1)
    def newfloat(self, obj):
        return FakeFloat(obj)

    @specialize.argtype(1)
    def newcomplex(self, rval, ival):
        return FakeComplex(rval, ival)

    @specialize.argtype(1)
    def newbytes(self, obj):
        return FakeString(obj)

    @specialize.argtype(1)
    def newtext(self, obj):
        return FakeString(obj)

    @specialize.argtype(1)
    def newtuple(self, obj):
        return FakeTuple(obj)

    def getitem(self, coll, i):
        return coll.val[i.val]

    def float_w(self, w_obj, allow_conversion=True):
        assert isinstance(w_obj, FakeFloat)
        return w_obj.val

    def newutf8(self, obj, sz):
        return FakeUnicode(obj)

    def unicode_from_object(self, w_obj):
        if isinstance (w_obj, FakeUnicode):
            return w_obj
        return FakeUnicode(w_obj.utf8_w(self))

    def utf8_len_w(self, w_obj):
        assert isinstance(w_obj, FakeUnicode)
        return w_obj.val, len(w_obj.val)

    @specialize.arg(1)
    def interp_w(self, RequiredClass, w_obj, can_be_None=False):
        if can_be_None and w_obj is None:
            return None
        if not isinstance(w_obj, RequiredClass):
            raise TypeError
        return w_obj

    def getarg_w(self, code, w_obj):    # for retrieving buffers
        return FakeBuffer(w_obj)

    def exception_match(self, typ, sub):
        return typ is sub

    @specialize.argtype(1)
    def is_none(self, w_obj):
        return w_obj is None

    def is_w(self, w_one, w_two):
        return w_one is w_two

    def bool_w(self, w_obj, allow_conversion=True):
        assert isinstance(w_obj, FakeBool)
        return w_obj.val

    def int_w(self, w_obj, allow_conversion=True):
        assert isinstance(w_obj, FakeInt)
        return w_obj.val

    def uint_w(self, w_obj):
        assert isinstance(w_obj, FakeLong)
        return rarithmetic.r_uint(w_obj.val.touint())

    def bytes_w(self, w_obj):
        assert isinstance(w_obj, FakeString)
        return w_obj.val

    def fsencode_w(self, w_obj):
        return self.bytes_w(w_obj)

    def text_w(self, w_obj):
        assert isinstance(w_obj, FakeString)
        return w_obj.val

    def str(self, obj):
        assert isinstance(obj, str)
        return obj

    def len_w(self, obj):
        assert isinstance(obj, str)
        return (obj)

    c_int_w = int_w
    c_uint_w = uint_w
    r_longlong_w = int_w
    r_ulonglong_w = uint_w

    def is_(self, w_obj1, w_obj2):
        return w_obj1 is w_obj2

    def isinstance_w(self, w_obj, w_type):
        assert isinstance(w_obj, FakeBase)
        return w_obj.typename == w_type.name

    def is_true(self, w_obj):
        return not not w_obj

    def type(self, w_obj):
        return FakeType("fake")

    def getattr(self, w_obj, w_name):
        assert isinstance(w_obj, FakeException)
        assert self.text_w(w_name) == "__name__"
        return FakeString(w_obj.name)

    def findattr(self, w_obj, w_name):
        return None

    def allocate_instance(self, cls, w_type):
        return instantiate(cls)

    def call_function(self, w_func, *args_w):
        return None

    def call_obj_args(self, w_callable, w_obj, args):
        return w_callable.call_args([w_obj]+args)

    def _freeze_(self):
        return True


class TestFastPathJIT(LLJitMixin):
    def setup_class(cls):
        import ctypes
        return ctypes.CDLL(test_dct, ctypes.RTLD_GLOBAL)

    def _run_zjit(self, method_name):
        space = FakeSpace()
        drv = jit.JitDriver(greens=[], reds=["i", "inst", "cppmethod"])
        def f():
            cls  = interp_cppyy.scope_byname(space, "example01")
            inst = interp_cppyy._bind_object(space, FakeInt(0), cls, True)
            cls.get_overload("__init__").descr_get(inst, []).call_args([FakeInt(0)])
            cppmethod = cls.get_overload(method_name)
            assert isinstance(inst, interp_cppyy.W_CPPInstance)
            i = 10
            while i > 0:
                drv.jit_merge_point(inst=inst, cppmethod=cppmethod, i=i)
                cppmethod.descr_get(inst, []).call_args([FakeInt(i)])
                i -= 1
            return 7
        f()
        space = FakeSpace()
        result = self.meta_interp(f, [], listops=True, backendopt=True, listcomp=True)
        self.check_jitcell_token_count(1)
        # rely on replacement of capi calls to raise exception instead (see FakeSpace.__init__)

    @py.test.mark.dont_track_allocations("cppmethod.cif_descr kept 'leaks'")
    def test01_simple(self):
        """Test fast path being taken for methods"""

        self._run_zjit("addDataToInt")

    @py.test.mark.dont_track_allocations("cppmethod.cif_descr kept 'leaks'")
    def test02_overload(self):
        """Test fast path being taken for overloaded methods"""

        self._run_zjit("overloadedAddDataToInt")

    @py.test.mark.dont_track_allocations("cppmethod.cif_descr kept 'leaks'")
    def test03_const_ref(self):
        """Test fast path being taken for methods with const ref arguments"""

        self._run_zjit("addDataToIntConstRef")
