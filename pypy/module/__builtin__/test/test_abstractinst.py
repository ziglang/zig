from pypy.module.__builtin__.abstractinst import *


class TestAbstractInst:

    def test_abstract_isclass(self):
        space = self.space
        w_B1, w_B2, w_B3, w_X, w_Y = space.fixedview(space.appexec([], """():
            class X(object): pass
            class Y: pass
            B1, B2, B3 = X(), X(), X()
            B2.__bases__ = (42,)
            B3.__bases__ = 'spam'
            return B1, B2, B3, X, Y
        """))
        assert abstract_isclass_w(space, space.w_int) is True
        assert abstract_isclass_w(space, w_B1) is False
        assert abstract_isclass_w(space, w_B2) is True
        assert abstract_isclass_w(space, w_B3) is False
        assert abstract_isclass_w(space, w_X) is True
        assert abstract_isclass_w(space, w_Y) is True

    def test_abstract_getclass(self):
        space = self.space
        w_x, w_y, w_A, w_MyInst = space.fixedview(space.appexec([], """():
            class MyInst(object):
                def __init__(self, myclass):
                    self.myclass = myclass
                def __class__(self):
                    if self.myclass is None:
                        raise AttributeError
                    return self.myclass
                __class__ = property(__class__)
            A = object()
            x = MyInst(A)
            y = MyInst(None)
            return x, y, A, MyInst
        """))
        w_42 = space.wrap(42)
        assert space.is_w(abstract_getclass(space, w_42), space.w_int)
        assert space.is_w(abstract_getclass(space, w_x), w_A)
        assert space.is_w(abstract_getclass(space, w_y), w_MyInst)
        assert space.is_w(abstract_getclass(space, w_MyInst), space.w_type)


class AppTestAbstractInst:

    def test_abstract_isinstance(self):
        class MyBaseInst(object):
            pass
        class MyInst(MyBaseInst):
            def __init__(self, myclass):
                self.myclass = myclass
            def __class__(self):
                if self.myclass is None:
                    raise AttributeError
                return self.myclass
            __class__ = property(__class__)
        class MyInst2(MyBaseInst):
            pass
        class MyClass(object):
            pass

        A = MyClass()
        x = MyInst(A)
        assert x.__class__ is A
        assert isinstance(x, MyInst)
        assert isinstance(x, MyBaseInst)
        assert not isinstance(x, MyInst2)
        raises(TypeError, isinstance, x, A)      # A has no __bases__
        A.__bases__ = "hello world"
        raises(TypeError, isinstance, x, A)      # A.__bases__ is not tuple

        class Foo(object):
            pass
        class SubFoo1(Foo):
            pass
        class SubFoo2(Foo):
            pass
        y = MyInst(SubFoo1)
        assert isinstance(y, MyInst)
        assert isinstance(y, MyBaseInst)
        assert not isinstance(y, MyInst2)
        assert isinstance(y, SubFoo1)
        assert isinstance(y, Foo)
        assert not isinstance(y, SubFoo2)

        z = MyInst(None)
        assert isinstance(z, MyInst)
        assert isinstance(z, MyBaseInst)
        assert not isinstance(z, MyInst2)
        assert not isinstance(z, SubFoo1)

        assert isinstance(y, ((), MyInst2, SubFoo1))
        assert isinstance(y, (MyBaseInst, (SubFoo2,)))
        assert not isinstance(y, (MyInst2, SubFoo2))
        assert not isinstance(z, ())

        class Foo(object):
            pass
        class Bar:
            pass
        u = MyInst(Foo)
        assert isinstance(u, MyInst)
        assert isinstance(u, MyBaseInst)
        assert not isinstance(u, MyInst2)
        assert isinstance(u, Foo)
        assert not isinstance(u, Bar)
        v = MyInst(Bar)
        assert isinstance(v, MyInst)
        assert isinstance(v, MyBaseInst)
        assert not isinstance(v, MyInst2)
        assert not isinstance(v, Foo)
        assert isinstance(v, Bar)

        BBase = MyClass()
        BSub1 = MyClass()
        BSub2 = MyClass()
        BBase.__bases__ = ()
        BSub1.__bases__ = (BBase,)
        BSub2.__bases__ = (BBase,)
        x = MyInst(BSub1)
        assert isinstance(x, BSub1)
        assert isinstance(x, BBase)
        assert not isinstance(x, BSub2)
        assert isinstance(x, (BSub2, (), (BSub1,)))

        del BBase.__bases__
        assert isinstance(x, BSub1)
        raises(TypeError, isinstance, x, BBase)
        assert not isinstance(x, BSub2)

        BBase.__bases__ = "foobar"
        assert isinstance(x, BSub1)
        raises(TypeError, isinstance, x, BBase)
        assert not isinstance(x, BSub2)

        class BadClass:
            @property
            def __class__(self):
                raise RuntimeError
        raises(RuntimeError, isinstance, BadClass(), bool)
        # test another code path
        raises(RuntimeError, isinstance, BadClass(), Foo)

    def test_abstract_issubclass(self):
        class MyBaseInst(object):
            pass
        class MyInst(MyBaseInst):
            pass
        class MyInst2(MyBaseInst):
            pass
        class MyClass(object):
            pass

        assert issubclass(MyInst, MyBaseInst)
        assert issubclass(MyInst2, MyBaseInst)
        assert issubclass(MyBaseInst, MyBaseInst)
        assert not issubclass(MyBaseInst, MyInst)
        assert not issubclass(MyInst, MyInst2)
        assert issubclass(MyInst, (MyBaseInst, MyClass))
        assert issubclass(MyInst, (MyClass, (), (MyBaseInst,)))
        assert not issubclass(MyInst, (MyClass, (), (MyInst2,)))

        BBase = MyClass()
        BSub1 = MyClass()
        BSub2 = MyClass()
        BBase.__bases__ = ()
        BSub1.__bases__ = (BBase,)
        BSub2.__bases__ = (BBase,)
        assert issubclass(BSub1, BBase)
        assert issubclass(BBase, BBase)
        assert not issubclass(BBase, BSub1)
        assert not issubclass(BSub1, BSub2)
        assert not issubclass(MyInst, BSub1)
        assert not issubclass(BSub1, MyInst)

        del BBase.__bases__
        raises(TypeError, issubclass, BSub1, BBase)
        raises(TypeError, issubclass, BBase, BBase)
        raises(TypeError, issubclass, BBase, BSub1)
        assert not issubclass(BSub1, BSub2)
        assert not issubclass(MyInst, BSub1)
        assert not issubclass(BSub1, MyInst)

        BBase.__bases__ = 42
        raises(TypeError, issubclass, BSub1, BBase)
        raises(TypeError, issubclass, BBase, BBase)
        raises(TypeError, issubclass, BBase, BSub1)
        assert not issubclass(BSub1, BSub2)
        assert not issubclass(MyInst, BSub1)
        assert not issubclass(BSub1, MyInst)

    def test_overriding(self):
        class ABC(type):

            def __instancecheck__(cls, inst):
                """Implement isinstance(inst, cls)."""
                return any(cls.__subclasscheck__(c)
                           for c in set([type(inst), inst.__class__]))

            def __subclasscheck__(cls, sub):
                """Implement issubclass(sub, cls)."""
                candidates = cls.__dict__.get("__subclass__", set()) | set([cls])
                return any(c in candidates for c in sub.mro())

        # Equivalent to::
        #     class Integer(metaclass=ABC):
        #         __subclass__ = set([int])
        # But with a syntax compatible with 2.x
        Integer = ABC('Integer', (), dict(__subclass__=set([int])))

        assert issubclass(int, Integer)
        assert issubclass(int, (Integer,))

    def test_dont_call_instancecheck_fast_path(self):
        called = []

        class M(type):
            def __instancecheck__(self, obj):
                called.append("called")

        class C:
            __metaclass__ = M

        c = C()
        assert isinstance(c, C)
        assert not called

    def test_instancecheck_exception_not_eaten(self):
        class M(object):
            def __instancecheck__(self, obj):
                raise TypeError("foobar")

        e = raises(TypeError, isinstance, 42, M())
        assert str(e.value) == "foobar"

    def test_issubclass_exception_not_eaten(self):
        class M(object):
            def __subclasscheck__(self, subcls):
                raise TypeError("foobar")

        e = raises(TypeError, issubclass, 42, M())
        assert str(e.value) == "foobar"

    def test_issubclass_no_fallback(self):
        class M(object):
            def __subclasscheck__(self, subcls):
                return False

        assert issubclass(42, M()) is False

    def test_exception_match_does_not_call_subclasscheck(self):
        class Special(Exception):
            class __metaclass__(type):
                def __subclasscheck__(cls1, cls2):
                    return True
        try:
            raise ValueError
        except ValueError:       # Python 3.x behaviour
            pass

    def test_exception_raising_does_not_call_subclasscheck(self):
        # test skipped: unsure how to get a non-normalized exception
        # from pure Python.
        class Special(Exception):
            class __metaclass__(type):
                def __subclasscheck__(cls1, cls2):
                    return True
        try:
            skip("non-normalized exception") #raise Special, ValueError()
        except Special:
            pass

    def test_exception_bad_subclasscheck(self):
        """
        import sys
        class Meta(type):
            def __subclasscheck__(cls, subclass):
                raise ValueError()

        class MyException(Exception, metaclass=Meta):
            pass

        try:
            raise KeyError()
        except MyException as e:
            assert False, "exception should not be a MyException"
        except KeyError:
            pass
        except:
            assert False, "Should have raised KeyError"
        else:
            assert False, "Should have raised KeyError"
        """

    def test_exception_contains_type_name(self):
        with raises(TypeError) as e:
            issubclass(type, None)
        print(e.value)
        assert "NoneType" in str(e.value)
