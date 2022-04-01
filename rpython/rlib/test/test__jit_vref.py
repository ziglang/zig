import py
from rpython.rlib.jit import virtual_ref, virtual_ref_finish
from rpython.rlib.jit import vref_None, non_virtual_ref, InvalidVirtualRef
from rpython.rlib._jit_vref import SomeVRef
from rpython.annotator import model as annmodel
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.rtyper.rclass import OBJECTPTR
from rpython.rtyper.lltypesystem import lltype

from rpython.rtyper.test.tool import BaseRtypingTest


class X(object):
    pass

class Y(X):
    pass

class Z(X):
    pass


def test_direct_forced():
    x1 = X()
    vref = virtual_ref(x1)
    assert vref._state == 'non-forced'
    assert vref.virtual is True
    assert vref() is x1
    assert vref._state == 'forced'
    assert vref.virtual is False
    virtual_ref_finish(vref, x1)
    assert vref._state == 'forced'
    assert vref.virtual is False
    assert vref() is x1

def test_direct_invalid():
    x1 = X()
    vref = virtual_ref(x1)
    assert vref._state == 'non-forced'
    virtual_ref_finish(vref, x1)
    assert vref._state == 'invalid'
    py.test.raises(InvalidVirtualRef, "vref()")

def test_annotate_1():
    def f():
        return virtual_ref(X())
    a = RPythonAnnotator()
    s = a.build_types(f, [])
    assert isinstance(s, SomeVRef)
    assert isinstance(s.s_instance, annmodel.SomeInstance)
    assert s.s_instance.classdef == a.bookkeeper.getuniqueclassdef(X)

def test_annotate_2():
    def f():
        x1 = X()
        vref = virtual_ref(x1)
        x2 = vref()
        virtual_ref_finish(vref, x1)
        return x2
    a = RPythonAnnotator()
    s = a.build_types(f, [])
    assert isinstance(s, annmodel.SomeInstance)
    assert s.classdef == a.bookkeeper.getuniqueclassdef(X)

def test_annotate_3():
    def f(n):
        if n > 0:
            return virtual_ref(Y())
        else:
            return non_virtual_ref(Z())
    a = RPythonAnnotator()
    s = a.build_types(f, [int])
    assert isinstance(s, SomeVRef)
    assert isinstance(s.s_instance, annmodel.SomeInstance)
    assert not s.s_instance.can_be_None
    assert s.s_instance.classdef == a.bookkeeper.getuniqueclassdef(X)

def test_annotate_4():
    def f(n):
        if n > 0:
            return virtual_ref(X())
        else:
            return vref_None
    a = RPythonAnnotator()
    s = a.build_types(f, [int])
    assert isinstance(s, SomeVRef)
    assert isinstance(s.s_instance, annmodel.SomeInstance)
    assert s.s_instance.can_be_None
    assert s.s_instance.classdef == a.bookkeeper.getuniqueclassdef(X)

class TestVRef(BaseRtypingTest):
    OBJECTTYPE = OBJECTPTR
    def castable(self, TO, var):
        return lltype.castable(TO, lltype.typeOf(var)) > 0

    def test_rtype_1(self):
        def f():
            return virtual_ref(X())
        x = self.interpret(f, [])
        assert lltype.typeOf(x) == self.OBJECTTYPE

    def test_rtype_2(self):
        def f():
            x1 = X()
            vref = virtual_ref(x1)
            x2 = vref()
            virtual_ref_finish(vref, x2)
            return x2
        x = self.interpret(f, [])
        assert self.castable(self.OBJECTTYPE, x)

    def test_rtype_3(self):
        def f(n):
            if n > 0:
                return virtual_ref(Y())
            else:
                return non_virtual_ref(Z())
        x = self.interpret(f, [-5])
        assert lltype.typeOf(x) == self.OBJECTTYPE

    def test_rtype_4(self):
        def f(n):
            if n > 0:
                return virtual_ref(X())
            else:
                return vref_None
        x = self.interpret(f, [-5])
        assert lltype.typeOf(x) == self.OBJECTTYPE
        assert not x

    def test_rtype_5(self):
        def f():
            vref = virtual_ref(X())
            try:
                vref()
                return 42
            except InvalidVirtualRef:
                return -1
        x = self.interpret(f, [])
        assert x == 42

    def test_rtype_virtualattr(self):
        def f():
            vref = virtual_ref(X())
            return vref.virtual
        x = self.interpret(f, [])
        assert x is False
