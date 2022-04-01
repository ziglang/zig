from rpython.translator.c.test.test_genc import compile
import pypy.module.cpyext.api
from pypy.module.cpyext.api import slot_function
from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import lltype
from rpython.rlib.objectmodel import specialize
from rpython.rlib.nonconst import NonConstant

def test_llhelper(monkeypatch):
    """Show how to get function pointers used in type slots"""
    FT = lltype.FuncType([], lltype.Signed)
    FTPTR = lltype.Ptr(FT)

    def make_wrapper(self, space):
        def wrapper():
            return self.callable(space)
        return wrapper
    monkeypatch.setattr(pypy.module.cpyext.api.ApiFunction, '_make_wrapper', make_wrapper)

    @specialize.memo()
    def get_tp_function(space, typedef):
        @slot_function([], lltype.Signed, error=-1)
        def slot_tp_function(space):
            return typedef.value

        api_func = slot_tp_function.api_func
        return lambda: llhelper(api_func.functype, api_func.get_wrapper(space))

    class Space:
        _cache = {}
        @specialize.memo()
        def fromcache(self, key):
            try:
                return self._cache[key]
            except KeyError:
                result = self._cache[key] = self.build(key)
                return result
        def _freeze_(self):
            return True
    class TypeDef:
        def __init__(self, value):
            self.value = value
        def _freeze_(self):
            return True
    class W_Type:
        def __init__(self, typedef):
            self.instancetypedef = typedef
        def _freeze(self):
            try:
                del self.funcptr
            except AttributeError:
                pass
            return False

    w_type1 = W_Type(TypeDef(123))
    w_type2 = W_Type(TypeDef(456))
    space = Space()

    def run(x):
        if x:
            w_type = w_type1
        else:
            w_type = w_type2
        typedef = w_type.instancetypedef
        w_type.funcptr = get_tp_function(space, typedef)()
        return w_type.funcptr()

    fn = compile(run, [bool])
    assert fn(True) == 123
    assert fn(False) == 456

