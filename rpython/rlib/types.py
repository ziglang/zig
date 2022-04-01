from rpython.annotator import model
from rpython.annotator.listdef import ListDef
from rpython.annotator.dictdef import DictDef


def none():
    return model.s_None


def impossible():
    return model.s_ImpossibleValue


def float():
    return model.SomeFloat()


def singlefloat():
    return model.SomeSingleFloat()


def longfloat():
    return model.SomeLongFloat()


def int():
    return model.SomeInteger()

def int_nonneg():
    return model.SomeInteger(nonneg=True)

def bool():
    return model.SomeBool()


def unicode():
    return model.SomeUnicodeString()


def unicode0():
    return model.SomeUnicodeString(no_nul=True)


def str(can_be_None=False):
    return model.SomeString(can_be_None=can_be_None)


def bytearray():
    return model.SomeByteArray()


def str0():
    return model.SomeString(no_nul=True)


def char():
    return model.SomeChar()


def ptr(ll_type):
    from rpython.rtyper.lltypesystem.lltype import Ptr
    from rpython.rtyper.llannotation import SomePtr
    return SomePtr(Ptr(ll_type))


def list(element):
    listdef = ListDef(None, element, mutated=True, resized=True)
    return model.SomeList(listdef)


def array(element):
    listdef = ListDef(None, element, mutated=True, resized=False)
    return model.SomeList(listdef)


def dict(keytype, valuetype):
    dictdef = DictDef(None, keytype, valuetype)
    return model.SomeDict(dictdef)


def instance(cls, can_be_None=False):
    return lambda bookkeeper: model.SomeInstance(bookkeeper.getuniqueclassdef(cls), can_be_None=can_be_None)


class SelfTypeMarker(object):
    pass


def self():
    return SelfTypeMarker()


class AnyTypeMarker(object):
    pass


def any():
    return AnyTypeMarker()
