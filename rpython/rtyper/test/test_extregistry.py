import py, sys

from rpython.rtyper import extregistry
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.annotator import model as annmodel
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.translator.translator import TranslationContext
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.test.test_llinterp import interpret
from rpython.rtyper.rmodel import Repr

def dummy():
    raiseNameError

class Entry(ExtRegistryEntry):
    _about_ = dummy
    s_result_annotation = annmodel.SomeInteger()

def test_call_dummy():
    def func():
        x = dummy()
        return x

    a = RPythonAnnotator()
    s = a.build_types(func, [])
    assert isinstance(s, annmodel.SomeInteger)

def test_callable_annotation():
    def dummy2():
        raiseNameError

    class Entry(ExtRegistryEntry):
        _about_ = dummy2

        def compute_result_annotation(self):
            return annmodel.SomeInteger()

    def func():
        x = dummy2()
        return x

    a = RPythonAnnotator()
    s = a.build_types(func, [])
    assert isinstance(s, annmodel.SomeInteger)

def test_register_type_with_callable():
    class DummyType(object):
        pass

    dummy_type = DummyType()

    def func():
        return dummy_type

    class Entry(ExtRegistryEntry):
        _type_ = DummyType
        def compute_annotation(self):
            assert self.instance is dummy_type
            return annmodel.SomeInteger()

    a = RPythonAnnotator()
    s = a.build_types(func, [])
    assert isinstance(s, annmodel.SomeInteger)

def test_register_value_with_specialization():
    def dummy_func():
        raiseNameError

    class Entry(ExtRegistryEntry):
        _about_ = dummy_func
        s_result_annotation = annmodel.SomeInteger()
        def specialize_call(self, hop):
            hop.exception_cannot_occur()
            return hop.inputconst(lltype.Signed, 42)

    def func():
        return dummy_func()

    res = interpret(func, [])

    assert res == 42

def test_register_type_with_get_repr():
    class DummyClass(object):
        pass

    class SomeDummyObject(annmodel.SomeObject):
        def rtyper_makerepr(self, rtyper):
            entry = extregistry.lookup_type(self.knowntype)
            return entry.get_repr(rtyper, self)

        def rtyper_makekey( self ):
            return self.__class__, self.knowntype

    class DummyRepr(Repr):
        lowleveltype = lltype.Signed

        def convert_const(self, value):
            return 42

    class Entry(ExtRegistryEntry):
        _type_ = DummyClass

        def compute_annotation(self):
            assert self.type is DummyClass
            dummy_object = SomeDummyObject()
            dummy_object.knowntype = DummyClass
            return dummy_object

        def get_repr(self, rtyper, s_instance):
            return DummyRepr()

    dummy_class = DummyClass()

    def func():
        return dummy_class

    res = interpret(func, [])

    assert res == 42

def test_register_unhashable():
    lst1 = [5, 6]
    lst2 = [5, 6]
    class Entry(ExtRegistryEntry):
        _about_ = lst1
    assert isinstance(extregistry.lookup(lst1), Entry)
    py.test.raises(KeyError, "extregistry.lookup(lst2)")

def test_register_non_weakly_refable():
    n1 = sys.maxint // 2
    n2 = sys.maxint // 2
    class Entry(ExtRegistryEntry):
        _about_ = n1
    assert isinstance(extregistry.lookup(n1), Entry)
    assert isinstance(extregistry.lookup(n2), Entry)
