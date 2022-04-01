from rpython.rlib.objectmodel import specialize
from rpython.rtyper.test.test_llinterp import interpret

from pypy.objspace.fake.objspace import FakeObjSpace, is_root
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.interpreter.gateway import interp2app, ObjSpace


def make_checker():
    check = []
    @specialize.memo()
    def see():
        check.append(True)
    return see, check

def test_wrap_interp2app():
    see, check = make_checker()
    space = FakeObjSpace()
    assert len(space._seen_extras) == 2
    assert len(check) == 0
    interp2app(lambda space: see()).spacebind(space)
    assert len(space._seen_extras) == 3
    assert len(check) == 0
    space.translates()
    assert len(check) == 1

def test_wrap_interp2app_int():
    see, check = make_checker()
    def foobar(space, x, w_y, z):
        is_root(w_y)
        see()
        return space.newint(x - z)
    space = FakeObjSpace()
    space.wrap(interp2app(foobar, unwrap_spec=[ObjSpace, int, W_Root, int]))
    space.translates()
    assert check

def test_wrap_interp2app_later():
    see, check = make_checker()
    #
    @specialize.memo()
    def hithere(space):
        space.wrap(interp2app(foobar2))
    #
    def foobar(space):
        hithere(space)
    def foobar2(space):
        see()
    space = FakeObjSpace()
    space.wrap(interp2app(foobar))
    space.translates()
    assert check

def test_wrap_GetSetProperty():
    see, check = make_checker()
    def foobar(w_obj, space):
        is_root(w_obj)
        see()
        return space.w_None
    space = FakeObjSpace()
    space.wrap(GetSetProperty(foobar))
    space.translates()
    assert check


def test_gettypefor_untranslated():
    see, check = make_checker()
    class W_Foo(W_Root):
        def do_it(self, space, w_x):
            is_root(w_x)
            see()
            return W_Root()
    W_Foo.typedef = TypeDef('foo',
                            __module__ = 'barmod',
                            do_it = interp2app(W_Foo.do_it))
    space = FakeObjSpace()
    space.gettypefor(W_Foo)
    assert not check
    space.translates()
    assert check

def test_gettype_mro_untranslated():
    space = FakeObjSpace()
    w_type = space.type(space.wrap(1))
    assert len(w_type.mro_w) == 2

def test_gettype_mro():
    space = FakeObjSpace()

    def f(i):
        w_x = space.newint(i)
        w_type = space.type(w_x)
        return len(w_type.mro_w)

    assert interpret(f, [1]) == 2

def test_see_objects():
    see, check = make_checker()
    class W_Foo(W_Root):
        def __init__(self, x):
            self.x = x
        def do_it(self):
            if self.x == 42:
                return
            see()
    def f():
        W_Foo(42).do_it()
    #
    space = FakeObjSpace()
    space.translates(f)
    assert not check
    #
    space = FakeObjSpace()
    space.translates(f, seeobj_w=[W_Foo(15)])
    assert check
