import py
from rpython.rtyper.controllerentry import Controller, ControllerEntry
from rpython.rtyper.controllerentry import ControllerEntryForPrebuilt

from rpython.annotator.annrpython import RPythonAnnotator
from rpython.rtyper.test.test_llinterp import interpret


class C(object):
    "Imagine some magic here to have a foo attribute on instances"

def fun(a):
    lst = []
    c = C(a)
    c.foo = lst    # side-effect on lst!  well, it's a test
    return c.foo, lst[0]

class C_Controller(Controller):
    knowntype = C

    def new(self, a):
        return a + '_'

    def convert(self, c):
        return str(c._bar)

    def get_foo(self, obj):
        return obj + "2"

    def set_foo(self, obj, value):
        value.append(obj)

    def getitem(self, obj, key):
        return obj + key

    def setitem(self, obj, key, value):
        value.append(obj + key)

    def call(self, obj, arg):
        return obj + arg

class Entry(ControllerEntry):
    _about_ = C
    _controller_ = C_Controller

class Entry(ControllerEntryForPrebuilt):
    _type_ = C
    _controller_ = C_Controller


def test_C_annotate():
    a = RPythonAnnotator()
    s = a.build_types(fun, [a.bookkeeper.immutablevalue("4")])
    assert s.const == ("4_2", "4_")

def test_C_specialize():
    res = interpret(fun, ["4"])
    assert ''.join(res.item0.chars) == "4_2"
    assert ''.join(res.item1.chars) == "4_"


c2 = C()
c2._bar = 51

c3 = C()
c3._bar = 7654

def fun1():
    return c2.foo

def test_C1_annotate():
    a = RPythonAnnotator()
    s = a.build_types(fun1, [])
    assert s.const == "512"

def test_C1_specialize():
    res = interpret(fun1, [])
    assert ''.join(res.chars) == "512"

def fun2(flag):
    if flag:
        c = c2
    else:
        c = c3
    return c.foo

def test_C2_annotate():
    a = RPythonAnnotator()
    s = a.build_types(fun2, [a.bookkeeper.immutablevalue(True)])
    assert s.const == "512"

def test_C2_specialize():
    res = interpret(fun2, [True])
    assert ''.join(res.chars) == "512"
    res = interpret(fun2, [False])
    assert ''.join(res.chars) == "76542"

def fun3(a):
    lst = []
    c = C(a)
    c['foo'] = lst    # side-effect on lst!  well, it's a test
    call_res = c("baz")
    return c['bar'], lst[0], call_res

def test_getsetitem_annotate():
    a = RPythonAnnotator()
    s = a.build_types(fun3, [a.bookkeeper.immutablevalue("4")])
    assert s.const == ("4_bar", "4_foo", "4_baz")

def test_getsetitem_specialize():
    res = interpret(fun3, ["4"])
    assert ''.join(res.item0.chars) == "4_bar"
    assert ''.join(res.item1.chars) == "4_foo"
    assert ''.join(res.item2.chars) == "4_baz"
