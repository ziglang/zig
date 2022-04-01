# unittest for SOME ctypes com function calls.
# Can't resist from implementing some kind of mini-comtypes
# theller ;-)

import pytest
import sys
if sys.platform != "win32":
    # this doesn't work, it still tries to do module-level imports
    # pytestmark = pytest.mark.skip("skip_the_whole_module")
    pytest.importorskip('skip_the_whole_module')  # hack!


import ctypes, types, unittest
from ctypes import HRESULT
from _ctypes import COMError

oleaut32 = ctypes.OleDLL("oleaut32")

class UnboundMethod(object):
    def __init__(self, func, index, name):
        self.func = func
        self.index = index
        self.name = name
        self.__doc__ = func.__doc__

    def __repr__(self):
        return "<Unbound COM method index %d: %s at %x>" % (self.index, self.name, id(self))

    def __get__(self, instance, owner):
        if instance is None:
            return self
        return types.MethodType(self.func, instance, owner)

def commethod(index, restype, *argtypes):
    """A decorator that generates COM methods.  The decorated function
    itself is not used except for it's name."""
    def make_commethod(func):
        comfunc = ctypes.WINFUNCTYPE(restype, *argtypes)(index, func.__name__)
        comfunc.__name__ = func.__name__
        comfunc.__doc__ = func.__doc__
        return UnboundMethod(comfunc, index, func.__name__)
    return make_commethod

class ICreateTypeLib2(ctypes.c_void_p):

    @commethod(1, ctypes.c_long)
    def AddRef(self):
        pass

    @commethod(2, ctypes.c_long)
    def Release(self):
        pass

    @commethod(4, HRESULT, ctypes.c_wchar_p)
    def SetName(self):
        """Set the name of the library."""

    @commethod(12, HRESULT)
    def SaveAllChanges(self):
        pass


CreateTypeLib2 = oleaut32.CreateTypeLib2
CreateTypeLib2.argtypes = (ctypes.c_int, ctypes.c_wchar_p, ctypes.POINTER(ICreateTypeLib2))

################################################################

def test_basic_comtypes():
    punk = ICreateTypeLib2()
    hr = CreateTypeLib2(0, "foobar.tlb", punk)
    assert hr == 0

    assert 2 == punk.AddRef()
    assert 3 == punk.AddRef()
    assert 4 == punk.AddRef()

    punk.SetName("TypeLib_ByPYPY")
    with pytest.raises(COMError):
        punk.SetName(None)

    # This would save the typelib to disk.
    ## punk.SaveAllChanges()

    assert 3 == punk.Release()
    assert 2 == punk.Release()
    assert 1 == punk.Release()
