import gc
from pypy.interpreter import typedef
from rpython.tool.udir import udir
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import ObjSpace, interp2app

# this test isn't so much to test that the objspace interface *works*
# -- it's more to test that it's *there*

class AppTestTraceBackAttributes:

    def test_newstring(self):
        # XXX why is this called newstring?
        import sys
        def f():
            raise TypeError("hello")

        def g():
            f()

        try:
            g()
        except:
            typ,val,tb = sys.exc_info()
        else:
            raise AssertionError("should have raised")
        assert hasattr(tb, 'tb_frame')
        assert hasattr(tb, 'tb_lasti')
        assert hasattr(tb, 'tb_lineno')
        assert hasattr(tb, 'tb_next')

    def test_descr_dict(self):
        def f():
            pass
        dictdescr = type(f).__dict__['__dict__']   # only for functions
        assert dictdescr.__get__(f) is f.__dict__
        raises(TypeError, dictdescr.__get__, 5)
        d = {}
        dictdescr.__set__(f, d)
        assert f.__dict__ is d
        raises(TypeError, dictdescr.__set__, f, "not a dict")
        raises(TypeError, dictdescr.__set__, 5, d)
        # in PyPy, the following descr applies to any object that has a dict,
        # but not to objects without a dict, obviously
        dictdescr = type.__dict__['__dict__']
        raises(TypeError, dictdescr.__get__, 5)
        # TypeError on CPython because descr applies only to its
        # __objclass__
        raises((AttributeError, TypeError), dictdescr.__set__, 5, d)

    def test_descr_member_descriptor(self):
        class X(object):
            __slots__ = ['x']
        member = X.x
        assert member.__name__ == 'x'
        assert member.__objclass__ is X
        raises(AttributeError, "member.__name__ = 'x'")
        raises(AttributeError, "member.__objclass__ = X")

    def test_descr_getsetproperty(self):
        from types import FrameType
        assert FrameType.f_lineno.__name__ == 'f_lineno'
        assert FrameType.f_lineno.__qualname__ == 'frame.f_lineno'
        assert FrameType.f_lineno.__objclass__ is FrameType
        class A(object):
            pass
        assert A.__dict__['__dict__'].__name__ == '__dict__'


class TestTypeDef:

    def test_subclass_cache(self):
        # check that we don't create more than 6 subclasses of a
        # given W_XxxObject (instead of the 16 that follow from
        # all combinations)
        space = self.space
        sources = []
        for hasdict in [False, True]:
            for wants_slots in [False, True]:
                for needsdel in [False, True]:
                    for weakrefable in [False, True]:
                        print 'Testing case', hasdict, wants_slots,
                        print needsdel, weakrefable
                        slots = []
                        checks = []

                        if hasdict:
                            slots.append('__dict__')
                            checks.append('x.foo=5; x.__dict__')
                        else:
                            checks.append('raises(AttributeError, "x.foo=5");'
                                        'raises(AttributeError, "x.__dict__")')

                        if wants_slots:
                            slots.append('a')
                            checks.append('x.a=5; assert X.a.__get__(x)==5')
                        else:
                            checks.append('')

                        if weakrefable:
                            slots.append('__weakref__')
                            checks.append('import _weakref;_weakref.ref(x)')
                        else:
                            checks.append('')

                        if needsdel:
                            methodname = '__del__'
                            checks.append('X();X();X();'
                                          'import gc;gc.collect();'
                                          'assert seen')
                        else:
                            methodname = 'spam'
                            checks.append('assert "Del" not in irepr')

                        assert len(checks) == 4
                        space.appexec([], """():
                            seen = []
                            class X(list):
                                __slots__ = %r
                                def %s(self):
                                    seen.append(1)
                            x = X()
                            import __pypy__
                            irepr = __pypy__.internal_repr(x)
                            print(irepr)
                            %s
                            %s
                            %s
                            %s
                        """ % (slots, methodname, checks[0], checks[1],
                               checks[2], checks[3]))
        subclasses = {}
        for cls, subcls in typedef._unique_subclass_cache.items():
            subclasses.setdefault(cls, {})
            prevsubcls = subclasses[cls].setdefault(subcls.__name__, subcls)
            assert subcls is prevsubcls
        for cls, set in subclasses.items():
            assert len(set) <= 6, "%s has %d subclasses:\n%r" % (
                cls, len(set), list(set))

    def test_getsetproperty(self):
        class W_SomeType(W_Root):
            pass
        def fget(self, space, w_self):
            assert self is prop
        # NB. this GetSetProperty is not copied when creating the
        # W_TypeObject because of 'cls'.  Without it, a duplicate of the
        # GetSetProperty is taken and it is given the w_objclass that is
        # the W_TypeObject
        prop = typedef.GetSetProperty(fget, use_closure=True, cls=W_SomeType)
        W_SomeType.typedef = typedef.TypeDef(
            'some_type',
            x=prop)
        w_obj = self.space.wrap(W_SomeType())
        assert self.space.getattr(w_obj, self.space.wrap('x')) is self.space.w_None

    def test_getsetproperty_arguments(self):
        class W_SomeType(W_Root):
            def fget1(space, w_self):
                assert isinstance(space, ObjSpace)
                assert isinstance(w_self, W_SomeType)
            def fget2(self, space):
                assert isinstance(space, ObjSpace)
                assert isinstance(self, W_SomeType)
        W_SomeType.typedef = typedef.TypeDef(
            'some_type',
            x1=typedef.GetSetProperty(W_SomeType.fget1),
            x2=typedef.GetSetProperty(W_SomeType.fget2),
            )
        space = self.space
        w_obj = space.wrap(W_SomeType())
        assert space.getattr(w_obj, space.wrap('x1')) == space.w_None
        assert space.getattr(w_obj, space.wrap('x2')) == space.w_None

    def test_unhashable(self):
        class W_SomeType(W_Root):
            pass
        W_SomeType.typedef = typedef.TypeDef(
            'some_type',
            __hash__ = None)
        w_obj = self.space.wrap(W_SomeType())
        self.space.appexec([w_obj], """(obj):
            assert type(obj).__hash__ is None
            err = raises(TypeError, hash, obj)
            assert str(err.value) == "unhashable type: 'some_type'"
            """)

    def test_destructor(self):
        space = self.space
        class W_Level1(W_Root):
            def __init__(self, space1):
                assert space1 is space
                self.register_finalizer(space)
            def _finalize_(self):
                space.call_method(w_seen, 'append', space.wrap(1))
        W_Level1.typedef = typedef.TypeDef(
            'level1',
            __new__ = typedef.generic_new_descr(W_Level1))
        #
        w_seen = space.newlist([])
        W_Level1(space)
        gc.collect(); gc.collect()
        assert space.text_w(space.repr(w_seen)) == "[]"  # not called yet
        ec = space.getexecutioncontext()
        self.space.user_del_action.perform(ec, None)
        assert space.unwrap(w_seen) == [1]   # called by user_del_action
        #
        w_seen = space.newlist([])
        self.space.appexec([self.space.gettypeobject(W_Level1.typedef)],
        """(level1):
            class A3(level1):
                pass
            A3()
        """)
        gc.collect(); gc.collect()
        self.space.user_del_action.perform(ec, None)
        assert space.unwrap(w_seen) == [1]
        #
        w_seen = space.newlist([])
        self.space.appexec([self.space.gettypeobject(W_Level1.typedef),
                            w_seen],
        """(level1, seen):
            class A4(level1):
                def __del__(self):
                    seen.append(4)
            A4()
        """)
        gc.collect(); gc.collect()
        self.space.user_del_action.perform(ec, None)
        assert space.unwrap(w_seen) == [4, 1]    # user __del__, and _finalize_
        #
        w_seen = space.newlist([])
        self.space.appexec([self.space.gettypeobject(W_Level1.typedef)],
        """(level2):
            class A5(level2):
                pass
            A5()
        """)
        gc.collect(); gc.collect()
        self.space.user_del_action.perform(ec, None)
        assert space.unwrap(w_seen) == [1]     # _finalize_ only

    def test_multiple_inheritance(self):
        class W_A(W_Root):
            a = 1
            b = 2
        class W_C(W_A):
            b = 3
        W_A.typedef = typedef.TypeDef("A",
            a = typedef.interp_attrproperty("a", cls=W_A,
                wrapfn="newint"),
            b = typedef.interp_attrproperty("b", cls=W_A,
                wrapfn="newint"),
        )
        class W_B(W_Root):
            pass
        def standalone_method(space, w_obj):
            if isinstance(w_obj, W_A):
                return space.w_True
            else:
                return space.w_False
        W_B.typedef = typedef.TypeDef("B",
            c = interp2app(standalone_method)
        )
        W_C.typedef = typedef.TypeDef("C", (W_A.typedef, W_B.typedef,))

        w_o1 = self.space.wrap(W_C())
        w_o2 = self.space.wrap(W_B())
        w_c = self.space.gettypefor(W_C)
        w_b = self.space.gettypefor(W_B)
        w_a = self.space.gettypefor(W_A)
        assert w_c.mro_w == [
            w_c,
            w_a,
            w_b,
            self.space.w_object,
        ]
        for w_tp in w_c.mro_w:
            assert self.space.isinstance_w(w_o1, w_tp)
        def assert_attr(w_obj, name, value):
            assert self.space.unwrap(self.space.getattr(w_obj, self.space.wrap(name))) == value
        def assert_method(w_obj, name, value):
            assert self.space.unwrap(self.space.call_method(w_obj, name)) == value
        assert_attr(w_o1, "a", 1)
        assert_attr(w_o1, "b", 3)
        assert_method(w_o1, "c", True)
        assert_method(w_o2, "c", False)

    def test_total_ordering(self):
        class W_SomeType(W_Root):
            def __init__(self, space, x):
                self.space = space
                self.x = x

            def descr__lt(self, w_other):
                assert isinstance(w_other, W_SomeType)
                return self.space.wrap(self.x < w_other.x)

            def descr__eq(self, w_other):
                assert isinstance(w_other, W_SomeType)
                return self.space.wrap(self.x == w_other.x)

        W_SomeType.typedef = typedef.TypeDef(
            'some_type',
            __total_ordering__ = 'auto',
            __lt__ = interp2app(W_SomeType.descr__lt),
            __eq__ = interp2app(W_SomeType.descr__eq),
            )
        space = self.space
        w_b = space.wrap(W_SomeType(space, 2))
        w_c = space.wrap(W_SomeType(space, 2))
        w_a = space.wrap(W_SomeType(space, 1))
        # explicitly defined
        assert space.is_true(space.lt(w_a, w_b))
        assert not space.is_true(space.eq(w_a, w_b))
        assert space.is_true(space.eq(w_b, w_c))
        # automatically defined
        assert space.is_true(space.le(w_a, w_b))
        assert space.is_true(space.le(w_b, w_c))
        assert space.is_true(space.gt(w_b, w_a))
        assert space.is_true(space.ge(w_b, w_a))
        assert space.is_true(space.ge(w_b, w_c))
        assert space.is_true(space.ne(w_a, w_b))
        assert not space.is_true(space.ne(w_b, w_c))

    def test_class_attr(self):
        class W_SomeType(W_Root):
            pass

        seen = []
        def make_me(space):
            seen.append(1)
            return space.wrap("foobar")

        W_SomeType.typedef = typedef.TypeDef(
            'some_type',
            abc = typedef.ClassAttr(make_me)
            )
        assert seen == []
        self.space.appexec([W_SomeType()], """(x):
            assert type(x).abc == "foobar"
            assert x.abc == "foobar"
            assert type(x).abc == "foobar"
        """)
        assert seen == [1]

    def test_mapdict_number_of_slots(self):
        space = self.space
        a, b, c = space.unpackiterable(space.appexec([], """():
            class A(object):
                pass
            a = A()
            a.x = 1
            class B:
                pass
            b = B()
            b.x = 1
            class C(int):
                pass
            c = C(1)
            c.x = 1
            return a, b, c
        """), 3)
        assert not hasattr(a, "storage")
        assert not hasattr(b, "storage")
        assert hasattr(c, "storage")

class AppTestTypeDef:

    spaceconfig = dict(usemodules=['array'])

    def setup_class(cls):
        path = udir.join('AppTestTypeDef.txt')
        path.write('hello world\n')
        cls.w_path = cls.space.wrap(str(path))

    def test_destructor(self):
        import gc, array
        seen = []
        class MyArray(array.array):
            def __del__(self):
                # here we check that we can still access the array, i.e. that
                # the interp-level __del__ has not been called yet
                seen.append(10)
                seen.append(self[0])
        a = MyArray('i')
        a.append(42)
        seen.append(a[0])
        del a
        gc.collect(); gc.collect(); gc.collect()
        lst = seen[:]
        print(lst)
        assert lst == [42, 10, 42]

    def test_method_attrs(self):
        import sys
        class A(object):
            def m(self):
                "aaa"
            m.x = 3
        class B(A):
            pass

        obj = B()
        bm = obj.m
        assert bm.__func__ is A.m
        assert bm.__self__ is obj
        assert bm.__doc__ == "aaa"
        assert bm.x == 3
        assert type(bm).__doc__ == "instancemethod(function, instance, class)\n\nCreate an instance method object."
        raises(AttributeError, setattr, bm, 'x', 15)
        l = []
        assert l.append.__self__ is l
        assert l.__add__.__self__ is l
        # note: 'l.__add__.__objclass__' is not defined in pypy
        # because it's a regular method, and .__objclass__
        # differs from .im_class in case the method is
        # defined in some parent class of l's actual class

    def test_func_closure(self):
        x = 2
        def f():
            return x
        assert f.__closure__[0].cell_contents is x

    def test_get_with_none_arg(self):
        raises(TypeError, type.__dict__['__mro__'].__get__, None)
        raises(TypeError, type.__dict__['__mro__'].__get__, None, None)

    def test_builtin_readonly_property(self):
        import sys
        x = lambda: 5
        e = raises(AttributeError, 'x.__globals__ = {}')
        if '__pypy__' in sys.builtin_module_names:
            assert str(e.value) == "readonly attribute '__globals__'"

    def test_del_doc(self):
        class X:
            "hi there"
        assert X.__doc__ == 'hi there'
        exc = raises(AttributeError, 'del X.__doc__')
        assert "can't delete X.__doc__" in str(exc.value)
