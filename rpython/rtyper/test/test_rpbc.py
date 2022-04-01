import py

from rpython.annotator import model as annmodel
from rpython.annotator import specialize
from rpython.rtyper.lltypesystem.lltype import typeOf
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.llannotation import SomePtr, lltype_to_annotation


class MyBase:
    def m(self, x):
        return self.z + x

class MySubclass(MyBase):
    def m(self, x):
        return self.z - x

class MyStrangerSubclass(MyBase):
    def m(self, x, y):
        return x*y

class MyBaseWithInit:
    def __init__(self, a):
        self.a1 = a

class MySubclassWithInit(MyBaseWithInit):
    def __init__(self, a, b):
        MyBaseWithInit.__init__(self, a)
        self.b1 = b

class MySubclassWithoutInit(MyBaseWithInit):
    pass

class MySubclassWithoutMethods(MyBase):
    pass


class Freezing:
    def _freeze_(self):
        return True
    def mymethod(self, y):
        return self.x + y


class TestRPBC(BaseRtypingTest):

    def test_easy_call(self):
        def f(x):
            return x+1
        def g(y):
            return f(y+2)
        res = self.interpret(g, [5])
        assert res == 8

    def test_multiple_call(self):
        def f1(x):
            return x+1
        def f2(x):
            return x+2
        def g(y):
            if y < 0:
                f = f1
            else:
                f = f2
            return f(y+3)
        res = self.interpret(g, [-1])
        assert res == 3
        res = self.interpret(g, [1])
        assert res == 6

    def test_function_is_null(self):
        def f1(x):
            return x+1
        def f2(x):
            return x+2
        def g(x):
            if x < 0:
                return None
            elif x == 0:
                return f2
            else:
                return f1
        def fn(x):
            func = g(x)
            if func:
                return 42
            else:
                return 43
        assert self.interpret(fn, [1]) == 42
        assert self.interpret(fn, [-1]) == 43

    def test_method_call(self):
        def f(a, b):
            obj = MyBase()
            obj.z = a
            return obj.m(b)
        res = self.interpret(f, [4, 5])
        assert res == 9

    def test_virtual_method_call(self):
        def f(a, b):
            if a > 0:
                obj = MyBase()
            else:
                obj = MySubclass()
            obj.z = a
            return obj.m(b)
        res = self.interpret(f, [1, 2.3])
        assert res == 3.3
        res = self.interpret(f, [-1, 2.3])
        assert res == -3.3

    def test_stranger_subclass_1(self):
        def f1():
            obj = MyStrangerSubclass()
            obj.z = 100
            return obj.m(6, 7)
        res = self.interpret(f1, [])
        assert res == 42

    def test_stranger_subclass_2(self):
        def f2():
            obj = MyStrangerSubclass()
            obj.z = 100
            return obj.m(6, 7) + MyBase.m(obj, 58)
        res = self.interpret(f2, [])
        assert res == 200


    def test_class_init(self):
        def f(a):
            instance = MyBaseWithInit(a)
            return instance.a1
        assert self.interpret(f, [5]) == 5

    def test_class_init_2(self):
        def f(a, b):
            instance = MySubclassWithInit(a, b)
            return instance.a1 * instance.b1
        assert self.interpret(f, [6, 7]) == 42

    def test_class_calling_init(self):
        def f():
            instance = MySubclassWithInit(1, 2)
            instance.__init__(3, 4)
            return instance.a1 * instance.b1
        assert self.interpret(f, []) == 12

    def test_class_init_w_kwds(self):
        def f(a):
            instance = MyBaseWithInit(a=a)
            return instance.a1
        assert self.interpret(f, [5]) == 5

    def test_class_init_2_w_kwds(self):
        def f(a, b):
            instance = MySubclassWithInit(a, b=b)
            return instance.a1 * instance.b1
        assert self.interpret(f, [6, 7]) == 42

    def test_class_init_inherited(self):
        def f(a):
            instance = MySubclassWithoutInit(a)
            return instance.a1
        assert self.interpret(f, [42]) == 42

    def test_class_method_inherited(self):
        # The strange names for this test are taken from richards,
        # where the problem originally arose.
        class Task:
            def waitTask(self, a):
                return a+1

            def fn(self, a):
                raise NotImplementedError

            def runTask(self, a):
                return self.fn(a)

        class HandlerTask(Task):
            def fn(self, a):
                return self.waitTask(a)+2

        class DeviceTask(Task):
            def fn(self, a):
                return self.waitTask(a)+3

        def f(a, b):
            if b:
                inst = HandlerTask()
            else:
                inst = DeviceTask()

            return inst.runTask(a)

        assert self.interpret(f, [42, True]) == 45
        assert self.interpret(f, [42, False]) == 46

    def test_freezing(self):
        fr1 = Freezing()
        fr2 = Freezing()
        fr1.x = 5
        fr2.x = 6
        def g(fr):
            return fr.x
        def f(n):
            if n > 0:
                fr = fr1
            elif n < 0:
                fr = fr2
            else:
                fr = None
            return g(fr)
        res = self.interpret(f, [1])
        assert res == 5
        res = self.interpret(f, [-1])
        assert res == 6

    def test_call_frozen_pbc_simple(self):
        fr1 = Freezing()
        fr1.x = 5
        def f(n):
            return fr1.mymethod(n)
        res = self.interpret(f, [6])
        assert res == 11

    def test_call_frozen_pbc_simple_w_kwds(self):
        fr1 = Freezing()
        fr1.x = 5
        def f(n):
            return fr1.mymethod(y=n)
        res = self.interpret(f, [6])
        assert res == 11

    def test_call_frozen_pbc_multiple(self):
        fr1 = Freezing()
        fr2 = Freezing()
        fr1.x = 5
        fr2.x = 6
        def f(n):
            if n > 0:
                fr = fr1
            else:
                fr = fr2
            return fr.mymethod(n)
        res = self.interpret(f, [1])
        assert res == 6
        res = self.interpret(f, [-1])
        assert res == 5

    def test_call_frozen_pbc_multiple_w_kwds(self):
        fr1 = Freezing()
        fr2 = Freezing()
        fr1.x = 5
        fr2.x = 6
        def f(n):
            if n > 0:
                fr = fr1
            else:
                fr = fr2
            return fr.mymethod(y=n)
        res = self.interpret(f, [1])
        assert res == 6
        res = self.interpret(f, [-1])
        assert res == 5

    def test_is_among_frozen(self):
        fr1 = Freezing()
        fr2 = Freezing()
        def givefr1():
            return fr1
        def givefr2():
            return fr2
        def f(i):
            if i == 1:
                fr = givefr1()
            else:
                fr = givefr2()
            return fr is fr1
        res = self.interpret(f, [0])
        assert res is False
        res = self.interpret(f, [1])
        assert res is True

    def test_unbound_method(self):
        def f():
            inst = MySubclass()
            inst.z = 40
            return MyBase.m(inst, 2)
        res = self.interpret(f, [])
        assert res == 42

    def test_call_defaults(self):
        def g(a, b=2, c=3):
            return a+b+c
        def f1():
            return g(1)
        def f2():
            return g(1, 10)
        def f3():
            return g(1, 10, 100)
        res = self.interpret(f1, [])
        assert res == 1+2+3
        res = self.interpret(f2, [])
        assert res == 1+10+3
        res = self.interpret(f3, [])
        assert res == 1+10+100

    def test_call_memoized_function(self):
        fr1 = Freezing()
        fr2 = Freezing()
        def getorbuild(key):
            a = 1
            if key is fr1:
                result = eval("a+2")
            else:
                result = eval("a+6")
            return result
        getorbuild._annspecialcase_ = "specialize:memo"

        def f1(i):
            if i > 0:
                fr = fr1
            else:
                fr = fr2
            return getorbuild(fr)

        res = self.interpret(f1, [0])
        assert res == 7
        res = self.interpret(f1, [1])
        assert res == 3

    def test_call_memoized_function_with_bools(self):
        fr1 = Freezing()
        fr2 = Freezing()
        def getorbuild(key, flag1, flag2):
            a = 1
            if key is fr1:
                result = eval("a+2")
            else:
                result = eval("a+6")
            if flag1:
                result += 100
            if flag2:
                result += 1000
            return result
        getorbuild._annspecialcase_ = "specialize:memo"

        def f1(i):
            if i > 0:
                fr = fr1
            else:
                fr = fr2
            return getorbuild(fr, i % 2 == 0, i % 3 == 0)

        for n in [0, 1, 2, -3, 6]:
            res = self.interpret(f1, [n])
            assert res == f1(n)

    def test_call_memoized_cache(self):

        # this test checks that we add a separate field
        # per specialization and also it uses a subclass of
        # the standard rpython.rlib.cache.Cache

        from rpython.rlib.cache import Cache
        fr1 = Freezing()
        fr2 = Freezing()

        class Cache1(Cache):
            def _build(self, key):
                "NOT_RPYTHON"
                if key is fr1:
                    return fr2
                else:
                    return fr1

        class Cache2(Cache):
            def _build(self, key):
                "NOT_RPYTHON"
                a = 1
                if key is fr1:
                    result = eval("a+2")
                else:
                    result = eval("a+6")
                return result

        cache1 = Cache1()
        cache2 = Cache2()

        def f1(i):
            if i > 0:
                fr = fr1
            else:
                fr = fr2
            newfr = cache1.getorbuild(fr)
            return cache2.getorbuild(newfr)

        res = self.interpret(f1, [0])
        assert res == 3
        res = self.interpret(f1, [1])
        assert res == 7

    def test_call_memo_with_single_value(self):
        class A: pass
        def memofn(cls):
            return len(cls.__name__)
        memofn._annspecialcase_ = "specialize:memo"

        def f1():
            A()    # make sure we have a ClassDef
            return memofn(A)
        res = self.interpret(f1, [])
        assert res == 1

    def test_call_memo_with_class(self):
        class A: pass
        class FooBar(A): pass
        def memofn(cls):
            return len(cls.__name__)
        memofn._annspecialcase_ = "specialize:memo"

        def f1(i):
            if i == 1:
                cls = A
            else:
                cls = FooBar
            FooBar()    # make sure we have ClassDefs
            return memofn(cls)
        res = self.interpret(f1, [1])
        assert res == 1
        res = self.interpret(f1, [2])
        assert res == 6

    def test_call_memo_with_string(self):
        def memofn(s):
            return eval(s)
        memofn._annspecialcase_ = "specialize:memo"

        def f1(i):
            if i == 1:
                return memofn("6*7")
            else:
                return memofn("1+2+3+4")
        res = self.interpret(f1, [1])
        assert res == 42
        res = self.interpret(f1, [2])
        assert res == 10

    def test_rpbc_bound_method_static_call(self):
        class R:
            def meth(self):
                return 0
        r = R()
        m = r.meth
        def fn():
            return m()
        res = self.interpret(fn, [])
        assert res == 0

    def test_rpbc_bound_method_static_call_w_kwds(self):
        class R:
            def meth(self, x):
                return x
        r = R()
        m = r.meth
        def fn():
            return m(x=3)
        res = self.interpret(fn, [])
        assert res == 3


    def test_constant_return_disagreement(self):
        class R:
            def meth(self):
                return 0
        r = R()
        def fn():
            return r.meth()
        res = self.interpret(fn, [])
        assert res == 0

    def test_None_is_false(self):
        def fn(i):
            if i == 0:
                v = None
            else:
                v = fn
            return bool(v)
        res = self.interpret(fn, [1])
        assert res is True
        res = self.interpret(fn, [0])
        assert res is False

    def test_classpbc_getattr(self):
        class A:
            myvalue = 123
        class B(A):
            myvalue = 456
        def f(i):
            if i == 0:
                v = A
            else:
                v = B
            return v.myvalue
        res = self.interpret(f, [0])
        assert res == 123
        res = self.interpret(f, [1])
        assert res == 456

    def test_function_or_None(self):
        def g1():
            return 42
        def f(i):
            g = None
            if i > 5:
                g = g1
            if i > 6:
                return g()
            else:
                return 12

        res = self.interpret(f, [0])
        assert res == 12
        res = self.interpret(f, [6])
        assert res == 12
        res = self.interpret(f, [7])
        assert res == 42

    def test_simple_function_pointer(self):
        def f1(x):
            return x + 1
        def f2(x):
            return x + 2

        l = [f1, f2]

        def pointersimple(i):
            return l[i](i)

        res = self.interpret(pointersimple, [1])
        assert res == 3

    def test_classdef_getattr(self):
        class A:
            myvalue = 123
        class B(A):
            myvalue = 456
        def f(i):
            B()    # for A and B to have classdefs
            if i == 0:
                v = A
            else:
                v = B
            return v.myvalue
        res = self.interpret(f, [0])
        assert res == 123
        res = self.interpret(f, [1])
        assert res == 456

    def test_call_classes(self):
        class A: pass
        class B(A): pass
        def f(i):
            if i == 1:
                cls = B
            else:
                cls = A
            return cls()
        res = self.interpret(f, [0])
        assert self.class_name(res) == 'A'
        res = self.interpret(f, [1])
        assert self.class_name(res) == 'B'

    def test_call_classes_or_None(self):
        class A: pass
        class B(A): pass
        def f(i):
            if i == -1:
                cls = None
            elif i == 1:
                cls = B
            else:
                cls = A
            return cls()
        res = self.interpret(f, [0])
        assert self.class_name(res) == 'A'
        res = self.interpret(f, [1])
        assert self.class_name(res) == 'B'

        #def f(i):
        #    if i == -1:
        #        cls = None
        #    else:
        #        cls = A
        #    return cls()
        #res = self.interpret(f, [0])
        #assert self.class_name(res) == 'A'

    def test_call_classes_with_init2(self):
        class A:
            def __init__(self, z):
                self.z = z
        class B(A):
            def __init__(self, z, x=42):
                A.__init__(self, z)
                self.extra = x
        def f(i, z):
            if i == 1:
                cls = B
            else:
                cls = A
            return cls(z)
        res = self.interpret(f, [0, 5])
        assert self.class_name(res) == 'A'
        assert self.read_attr(res, "z") == 5
        res = self.interpret(f, [1, -7645])
        assert self.class_name(res) == 'B'
        assert self.read_attr(res, "z") == -7645
        assert self.read_attr(res, "extra") == 42

    def test_conv_from_None(self):
        class A(object): pass
        def none():
            return None

        def f(i):
            if i == 1:
                return none()
            else:
                return "ab"
        res = self.interpret(f, [1])
        assert not res
        res = self.interpret(f, [0])
        assert self.ll_to_string(res) == "ab"

        def g(i):
            if i == 1:
                return none()
            else:
                return A()
        res = self.interpret(g, [1])
        assert not res
        res = self.interpret(g, [0])
        assert self.class_name(res) == 'A'


    def test_conv_from_classpbcset_to_larger(self):
        class A(object): pass
        class B(A): pass
        class C(A): pass

        def a():
            return A
        def b():
            return B


        def g(i):
            if i == 1:
                cls = a()
            else:
                cls = b()
            return cls()

        res = self.interpret(g, [0])
        assert self.class_name(res) == 'B'
        res = self.interpret(g, [1])
        assert self.class_name(res) == 'A'

        def bc(j):
            if j == 1:
                return B
            else:
                return C

        def g(i, j):
            if i == 1:
                cls = a()
            else:
                cls = bc(j)
            return cls()

        res = self.interpret(g, [0, 0])
        assert self.class_name(res) == 'C'
        res = self.interpret(g, [0, 1])
        assert self.class_name(res) == 'B'
        res = self.interpret(g, [1, 0])
        assert self.class_name(res) == 'A'

    def test_call_starargs(self):
        def g(x=-100, *arg):
            return x + len(arg)
        def f(i):
            if i == -1:
                return g()
            elif i == 0:
                return g(4)
            elif i == 1:
                return g(5, 15)
            elif i == 2:
                return g(7, 17, 27)
            else:
                return g(10, 198, 1129, 13984)
        res = self.interpret(f, [-1])
        assert res == -100
        res = self.interpret(f, [0])
        assert res == 4
        res = self.interpret(f, [1])
        assert res == 6
        res = self.interpret(f, [2])
        assert res == 9
        res = self.interpret(f, [3])
        assert res == 13

    def test_call_keywords(self):
        def g(a=1, b=2, c=3):
            return 100*a+10*b+c

        def f(i):
            if i == 0:
                return g(a=7)
            elif i == 1:
                return g(b=11)
            elif i == 2:
                return g(c=13)
            elif i == 3:
                return g(a=7, b=11)
            elif i == 4:
                return g(b=7, a=11)
            elif i == 5:
                return g(a=7, c=13)
            elif i == 6:
                return g(c=7, a=13)
            elif i == 7:
                return g(a=7,b=11,c=13)
            elif i == 8:
                return g(a=7,c=11,b=13)
            elif i == 9:
                return g(b=7,a=11,c=13)
            else:
                return g(b=7,c=11,a=13)

        for i in range(11):
            res = self.interpret(f, [i])
            assert res == f(i)

    def test_call_star_and_keywords(self):
        def g(a=1, b=2, c=3):
            return 100*a+10*b+c

        def f(i, x):
            if x == 1:
                j = 11
            else:
                j = 22
            if i == 0:
                return g(7)
            elif i == 1:
                return g(7,*(j,))
            elif i == 2:
                return g(7,*(11,j))
            elif i == 3:
                return g(a=7)
            elif i == 4:
                return g(b=7, *(j,))
            elif i == 5:
                return g(b=7, c=13, *(j,))
            elif i == 6:
                return g(c=7, b=13, *(j,))
            elif i == 7:
                return g(c=7,*(j,))
            elif i == 8:
                return g(c=7,*(11,j))
            else:
                return 0

        for i in range(9):
            for x in range(1):
                res = self.interpret(f, [i, x])
                assert res == f(i, x)

    def test_call_star_and_keywords_starargs(self):
        def g(a=1, b=2, c=3, *rest):
            return 1000*len(rest)+100*a+10*b+c

        def f(i, x):
            if x == 1:
                j = 13
            else:
                j = 31
            if i == 0:
                return g()
            elif i == 1:
                return g(*(j,))
            elif i == 2:
                return g(*(13, j))
            elif i == 3:
                return g(*(13, j, 19))
            elif i == 4:
                return g(*(13, j, 19, 21))
            elif i == 5:
                return g(7)
            elif i == 6:
                return g(7, *(j,))
            elif i == 7:
                return g(7, *(13, j))
            elif i == 8:
                return g(7, *(13, 17, j))
            elif i == 9:
                return g(7, *(13, 17, j, 21))
            elif i == 10:
                return g(7, 9)
            elif i == 11:
                return g(7, 9, *(j,))
            elif i == 12:
                return g(7, 9, *(j, 17))
            elif i == 13:
                return g(7, 9, *(13, j, 19))
            elif i == 14:
                return g(7, 9, 11)
            elif i == 15:
                return g(7, 9, 11, *(j,))
            elif i == 16:
                return g(7, 9, 11, *(13, j))
            elif i == 17:
                return g(7, 9, 11, *(13, 17, j))
            elif i == 18:
                return g(7, 9, 11, 2)
            elif i == 19:
                return g(7, 9, 11, 2, *(j,))
            elif i == 20:
                return g(7, 9, 11, 2, *(13, j))
            else:
                return 0

        for i in range(21):
            for x in range(1):
                res = self.interpret(f, [i, x])
                assert res == f(i, x)

    def test_conv_from_funcpbcset_to_larger(self):
        def f1():
            return 7
        def f2():
            return 11
        def f3():
            return 13

        def a():
            return f1
        def b():
            return f2


        def g(i):
            if i == 1:
                f = a()
            else:
                f = b()
            return f()

        res = self.interpret(g, [0])
        assert res == 11
        res = self.interpret(g, [1])
        assert res == 7

        def bc(j):
            if j == 1:
                return f2
            else:
                return f3

        def g(i, j):
            if i == 1:
                cls = a()
            else:
                cls = bc(j)
            return cls()

        res = self.interpret(g, [0, 0])
        assert res == 13
        res = self.interpret(g, [0, 1])
        assert res == 11
        res = self.interpret(g, [1, 0])
        assert res == 7

    def test_call_special_starargs_method(self):
        class Star:
            def __init__(self, d):
                self.d = d
            def meth(self, *args):
                return self.d + len(args)

        def f(i, j):
            s = Star(i)
            return s.meth(i, j)

        res = self.interpret(f, [3, 0])
        assert res == 5

    def test_call_star_method(self):
        class N:
            def __init__(self, d):
                self.d = d
            def meth(self, a, b):
                return self.d + a + b

        def f(i, j):
            n = N(i)
            return n.meth(*(i, j))

        res = self.interpret(f, [3, 7])
        assert res == 13

    def test_call_star_special_starargs_method(self):
        class N:
            def __init__(self, d):
                self.d = d
            def meth(self, *args):
                return self.d + len(args)

        def f(i, j):
            n = N(i)
            return n.meth(*(i, j))

        res = self.interpret(f, [3, 0])
        assert res == 5

    def test_various_patterns_but_one_signature_method(self):
        class A:
            def meth(self, a, b=0):
                raise NotImplementedError
        class B(A):
            def meth(self, a, b=0):
                return a+b

        class C(A):
            def meth(self, a, b=0):
                return a*b
        def f(i):
            if i == 0:
                x = B()
            else:
                x = C()
            r1 = x.meth(1)
            r2 = x.meth(3, 2)
            r3 = x.meth(7, b=11)
            return r1+r2+r3
        res = self.interpret(f, [0])
        assert res == 1+3+2+7+11
        res = self.interpret(f, [1])
        assert res == 3*2+11*7


    def test_multiple_ll_one_hl_op(self):
        class E(Exception):
            pass
        class A(object):
            pass
        class B(A):
            pass
        class C(object):
            def method(self, x):
                if x:
                    raise E()
                else:
                    return A()
        class D(C):
            def method(self, x):
                if x:
                    raise E()
                else:
                    return B()
        def call(x):
            c = D()
            c.method(x)
            try:
                c.method(x + 1)
            except E:
                pass
            c = C()
            c.method(x)
            try:
                return c.method(x + 1)
            except E:
                return None
        res = self.interpret(call, [0])

    def test_multiple_pbc_with_void_attr(self):
        class A:
            def _freeze_(self):
                return True
        a1 = A()
        a2 = A()
        unique = A()
        unique.result = 42
        a1.value = unique
        a2.value = unique
        def g(a):
            return a.value.result
        def f(i):
            if i == 1:
                a = a1
            else:
                a = a2
            return g(a)
        res = self.interpret(f, [0])
        assert res == 42
        res = self.interpret(f, [1])
        assert res == 42

    def test_function_or_none(self):
        def h(y):
            return y+84
        def g(y):
            return y+42
        def f(x, y):
            if x == 1:
                func = g
            elif x == 2:
                func = h
            else:
                func = None
            if func:
                return func(y)
            return -1
        res = self.interpret(f, [1, 100])
        assert res == 142
        res = self.interpret(f, [2, 100])
        assert res == 184
        res = self.interpret(f, [3, 100])
        assert res == -1

    def test_pbc_getattr_conversion(self):
        fr1 = Freezing()
        fr2 = Freezing()
        fr3 = Freezing()
        fr1.value = 10
        fr2.value = 5
        fr3.value = 2.5
        def pick12(i):
            if i > 0:
                return fr1
            else:
                return fr2
        def pick23(i):
            if i > 5:
                return fr2
            else:
                return fr3
        def f(i):
            x = pick12(i)
            y = pick23(i)
            return x.value, y.value
        for i in [0, 5, 10]:
            res = self.interpret(f, [i])
            item0, item1 = self.ll_unpack_tuple(res, 2)
            assert type(item0) is int   # precise
            assert type(item1) in (float, int)  # we get int on JS
            assert item0 == f(i)[0]
            assert item1 == f(i)[1]

    def test_pbc_getattr_conversion_with_classes(self):
        class base: pass
        class fr1(base): pass
        class fr2(base): pass
        class fr3(base): pass
        fr1.value = 10
        fr2.value = 5
        fr3.value = 2.5
        def pick12(i):
            if i > 0:
                return fr1
            else:
                return fr2
        def pick23(i):
            if i > 5:
                return fr2
            else:
                return fr3
        def f(i):
            x = pick12(i)
            y = pick23(i)
            return x.value, y.value
        for i in [0, 5, 10]:
            res = self.interpret(f, [i])
            item0, item1 = self.ll_unpack_tuple(res, 2)
            assert type(item0) is int   # precise
            assert type(item1) in (float, int)  # we get int on JS
            assert item0 == f(i)[0]
            assert item1 == f(i)[1]

    def test_pbc_imprecise_attrfamily(self):
        fr1 = Freezing(); fr1.x = 5; fr1.y = [8]
        fr2 = Freezing(); fr2.x = 6; fr2.y = ["string"]
        def head(fr):
            return fr.y[0]
        def f(n):
            if n == 1:
                fr = fr1
            else:
                fr = fr2
            return head(fr1) + fr.x
        res = self.interpret(f, [2])
        assert res == 8 + 6

    def test_multiple_specialized_functions(self):
        def myadder(x, y):   # int,int->int or str,str->str
            return x+y
        def myfirst(x, y):   # int,int->int or str,str->str
            return x
        def mysecond(x, y):  # int,int->int or str,str->str
            return y
        myadder._annspecialcase_ = 'specialize:argtype(0)'
        myfirst._annspecialcase_ = 'specialize:argtype(0)'
        mysecond._annspecialcase_ = 'specialize:argtype(0)'
        def f(i):
            if i == 0:
                g = myfirst
            elif i == 1:
                g = mysecond
            else:
                g = myadder
            s = g("hel", "lo")
            n = g(40, 2)
            return len(s) * n
        for i in range(3):
            res = self.interpret(f, [i])
            assert res == f(i)

    def test_specialized_method_of_frozen(self):
        class space:
            def _freeze_(self):
                return True
            def __init__(self, tag):
                self.tag = tag
            def wrap(self, x):
                if isinstance(x, int):
                    return self.tag + '< %d >' % x
                else:
                    return self.tag + x
            wrap._annspecialcase_ = 'specialize:argtype(1)'
        space1 = space("tag1:")
        space2 = space("tag2:")
        def f(i):
            if i == 1:
                sp = space1
            else:
                sp = space2
            w1 = sp.wrap('hello')
            w2 = sp.wrap(42)
            return w1 + w2
        res = self.interpret(f, [1])
        assert self.ll_to_string(res) == 'tag1:hellotag1:< 42 >'
        res = self.interpret(f, [0])
        assert self.ll_to_string(res) == 'tag2:hellotag2:< 42 >'

    def test_specialized_method(self):
        class A:
            def __init__(self, tag):
                self.tag = tag
            def wrap(self, x):
                if isinstance(x, int):
                    return self.tag + '< %d >' % x
                else:
                    return self.tag + x
            wrap._annspecialcase_ = 'specialize:argtype(1)'
        a1 = A("tag1:")
        a2 = A("tag2:")
        def f(i):
            if i == 1:
                sp = a1
            else:
                sp = a2
            w1 = sp.wrap('hello')
            w2 = sp.wrap(42)
            return w1 + w2
        res = self.interpret(f, [1])
        assert self.ll_to_string(res) == 'tag1:hellotag1:< 42 >'
        res = self.interpret(f, [0])
        assert self.ll_to_string(res) == 'tag2:hellotag2:< 42 >'

    def test_precise_method_call_1(self):
        class A(object):
            def meth(self, x=5):
                return x+1
        class B(A):
            def meth(self, x=5):
                return x+2
        class C(A):
            pass
        def f(i, n):
            # call both A.meth and B.meth with an explicit argument
            if i > 0:
                x = A()
            else:
                x = B()
            result1 = x.meth(n)
            # now call A.meth only, using the default argument
            result2 = C().meth()
            return result1 * result2
        for i in [0, 1]:
            res = self.interpret(f, [i, 1234])
            assert res == f(i, 1234)

    def test_precise_method_call_2(self):
        class A(object):
            def meth(self, x=5):
                return x+1
        class B(A):
            def meth(self, x=5):
                return x+2
        class C(A):
            def meth(self, x=5):
                return x+3
        def f(i, n):
            # call both A.meth and B.meth with an explicit argument
            if i > 0:
                x = A()
            else:
                x = B()
            result1 = x.meth(n)
            # now call A.meth and C.meth, using the default argument
            if i > 0:
                x = C()
            else:
                x = A()
            result2 = x.meth()
            return result1 * result2
        for i in [0, 1]:
            res = self.interpret(f, [i, 1234])
            assert res == f(i, 1234)

    def test_disjoint_pbcs(self):
        class Frozen(object):
            def __init__(self, v):
                self.v = v
            def _freeze_(self):
                return True

        fr1 = Frozen(2)
        fr2 = Frozen(3)

        def g1(x):
            return x.v
        def g2(y):
            return y.v
        def h(x):
            return x is not None
        def h2(x):
            return x is fr1

        def f():
            a = g1(fr1)
            b = g2(fr2)
            h(None)
            return (h(fr1) + 10*h(fr2) + 100*a + 1000*b +
                    10000*h2(fr1) + 100000*h2(fr2))

        res = self.interpret(f, [])
        assert res == 13211

    def test_disjoint_pbcs_2(self):
        class Frozen(object):
            def __init__(self, v):
                self.v = v
            def _freeze_(self):
                return True
        fr1 = Frozen(1)
        fr2 = Frozen(2)
        fr3 = Frozen(3)
        def getv(x):
            return x.v
        def h(x):
            return (x is not None) + 2*(x is fr2) + 3*(x is fr3)
        def f(n):
            if n == 1:
                fr = fr1
            else:
                fr = fr2
            total = getv(fr)
            if n == 3:
                fr = fr3
            h(None)
            return total + 10*h(fr)

        res = self.interpret(f, [3])
        assert res == 42

    def test_convert_multiple_to_single(self):
        class A:
            def meth(self, fr):
                return 65
        class B(A):
            def meth(self, fr):
                return 66
        fr1 = Freezing()
        fr2 = Freezing()
        def f():
            return A().meth(fr1) * B().meth(fr2)

        res = self.interpret(f, [])
        assert res == 65*66

    def test_convert_multiple_to_single_method_of_frozen_pbc(self):
        class A:
            def meth(self, frmeth):
                return frmeth(100)
        class B(A):
            def meth(self, frmeth):
                return frmeth(1000)
        fr1 = Freezing(); fr1.x = 65
        fr2 = Freezing(); fr2.x = 66
        def f():
            return A().meth(fr1.mymethod) * B().meth(fr2.mymethod)

        res = self.interpret(f, [])
        assert res == 165 * 1066

    def test_convert_none_to_frozen_pbc(self):
        fr1 = Freezing(); fr1.x = 65
        fr2 = Freezing(); fr2.y = 65
        def g(fr):
            return fr.x
        def identity(z):
            return z
        def f(n):  # NB. this crashes with n == 0
            if n == 0:
                fr = identity(None)
            else:
                fr = fr1
            return g(fr)
        res = self.interpret(f, [1])
        assert res == 65

    def test_multiple_attribute_access_patterns(self):
        class Base(object):
            pass
        class A(Base):
            value = 1000
            def meth(self): return self.n + 1
        class B(A):
            def meth(self): return self.n + 2
        class C(Base):
            value = 2000
            def meth(self): ShouldNotBeSeen
        def AorB(n):
            if n == 5: return A
            else:      return B
        def BorC(n):
            if n == 3: return B
            else:      return C
        def f(n):
            value = BorC(n).value
            x = B()
            x.n = 100
            return value + AorB(n).meth(x)

        for i in [1, 3, 5]:
            res = self.interpret(f, [i])
            assert res == f(i)

    def test_function_as_frozen_pbc(self):
        def f1(): pass
        def f2(): pass
        def choose(n):
            if n == 1:
                return f1
            else:
                return f2
        def f(n):
            return choose(n) is f1
        res = self.interpret(f, [1])
        assert res == True
        res = self.interpret(f, [2])
        assert res == False

    def test_call_from_list(self):
        def f0(n): return n+200
        def f1(n): return n+192
        def f2(n): return n+46
        def f3(n): return n+2987
        def f4(n): return n+217
        lst = [f0, f1, f2, f3, f4]
        def f(i, n):
            return lst[i](n)
        for i in range(5):
            res = self.interpret(f, [i, 1000])
            assert res == f(i, 1000)

    def test_None_is_None(self):
        def g():
            return None
        def f():
            return g() is None
        res = self.interpret(f, [])
        assert res == True

    def test_except_class_call(self):
        class A:
            pass   # no constructor
        def f():
            try:
                A()
                IndexError()
                return 12
            except ValueError:
                return 23
        res = self.interpret(f, [])
        assert res == 12

    def test_exception_with_non_empty_baseclass(self):
        class BE(Exception):
            pass
        class E1(BE):
            pass
        class E2(BE):
            pass
        def f(x):
            if x:
                e = E1()
            else:
                e = E2()
            witness = E1()
            witness.x = 42
            e.x = 3
            return witness.x

        res = self.interpret(f, [0])
        assert res == 42
        res = self.interpret(f, [1])
        assert res == 42

    def test_funcornone_to_func(self):
        def g(y):
            return y*2
        def f(x):
            if x > 0:
                g1 = g
            else:
                g1 = None
            x += 1
            if g1:
                return g1(x)
            else:
                return -1

        res = self.interpret(f, [20])
        assert res == 42

    def test_specialize_functionarg(self):
        def f(x, y):
            return x + y
        def g(x, y, z):
            return x + y + z
        def functionarg(func, *extraargs):
            return func(42, *extraargs)
        functionarg._annspecialcase_ = "specialize:arg(0)"
        def call_functionarg():
            return functionarg(f, 1) + functionarg(g, 1, 2)
        assert call_functionarg() == 2 * 42 + 4
        res = self.interpret(call_functionarg, [])
        assert res == 2 * 42 + 4

    def test_convert_multiple_classes_to_single(self):
        class A:
            result = 321
            def meth(self, n):
                if n:
                    return A
                else:
                    return B
        class B(A):
            result = 123
            def meth(self, n):
                return B
        def f(n):
            A().meth(n)
            cls = B().meth(n)
            return cls().result
        res = self.interpret(f, [5])
        assert res == 123

    def test_is_among_functions(self):
        def g1(): pass
        def g2(): pass
        def g3(): pass
        def f(n):
            if n > 5:
                g = g2
            else:
                g = g1
            g()
            g3()
            return g is g3
        res = self.interpret(f, [2])
        assert res == False

    def test_is_among_functions_2(self):
        def g1(): pass
        def g2(): pass
        def f(n):
            if n > 5:
                g = g2
            else:
                g = g1
            g()
            return g is g2
        res = self.interpret(f, [2])
        assert res == False
        res = self.interpret(f, [8])
        assert res == True

    def test_is_among_functions_3(self):
        def g0(): pass
        def g1(): pass
        def g2(): pass
        def g3(): pass
        def g4(): pass
        def g5(): pass
        def g6(): pass
        def g7(): pass
        glist = [g0, g1, g2, g3, g4, g5, g6, g7]
        def f(n):
            if n > 5:
                g = g2
            else:
                g = g1
            h = glist[n]
            g()
            h()
            return g is h
        res = self.interpret(f, [2])
        assert res == False
        res = self.interpret(f, [1])
        assert res == True
        res = self.interpret(f, [6])
        assert res == False

    def test_shrink_pbc_set(self):
        def g1():
            return 10
        def g2():
            return 20
        def g3():
            return 30
        def h1(g):          # g in {g1, g2}
            return 1 + g()
        def h2(g):          # g in {g1, g2, g3}
            return 2 + g()
        def f(n):
            if n > 5: g = g1
            else:     g = g2
            if n % 2: h = h1
            else:     h = h2
            res = h(g)
            if n > 7: g = g3
            h2(g)
            return res
        res = self.interpret(f, [7])
        assert res == 11

    def test_single_pbc_getattr(self):
        class C:
            def __init__(self, v1, v2):
                self.v1 = v1
                self.v2 = v2
            def _freeze_(self):
                return True
        c1 = C(11, lambda: "hello")
        c2 = C(22, lambda: 623)
        def f1(l, c):
            l.append(c.v1)
        def f2(c):
            return c.v2
        def f3(c):
            return c.v2
        def g():
            l = []
            f1(l, c1)
            f1(l, c2)
            return f2(c1)(), f3(c2)()

        res = self.interpret(g, [])
        item0, item1 = self.ll_unpack_tuple(res, 2)
        assert self.ll_to_string(item0) == "hello"
        assert item1 == 623

    def test_always_raising_methods(self):
        class Base:
            def m(self):
                raise KeyError
        class A(Base):
            def m(self):
                return 42
        class B(Base):
            pass
        def f(n):
            if n > 3:
                o = A()
            else:
                o = B()
            try:
                o.m()
            except KeyError:
                assert 0
            return B().m()

        self.interpret_raises(KeyError, f, [7])

    def test_possible_missing_attribute_access(self):
        py.test.skip("Should explode or give some warning")
        class Base(object):
            pass

        class A(Base):
            a = 1
            b = 2

        class B(Base):
            a = 2
            b = 2

        class C(Base):
            b = 8

        def f(n):
            if n > 3:
                x = A
            elif n > 1:
                x = B
            else:
                x = C
            if n > 0:
                return x.a
            return 9

        self.interpret(f, [int])


    def test_funcpointer_default_value(self):
        def foo(x): return x+1
        class Foo:
            func = None
            def __init__(self, n):
                if n == 1:
                    self.func = foo

        def fn(n):
            a = Foo(n)
            if a.func:
                return a.func(n)
            return -1

        res = self.interpret(fn, [0])
        assert res == -1

    def test_is_none(self):
        from rpython.rlib.nonconst import NonConstant
        def g(x):
            return NonConstant(g) is None
        res = self.interpret(g, [1])
        assert not res

    def test_pbc_of_classes_not_all_used(self):
        class Base(object): pass
        class A(Base): pass
        class B(Base): pass
        def poke(lst):
            pass
        def g():
            A()
            poke([A, B])
        self.interpret(g, [])

    def test_pbc_of_classes_isinstance_only(self):
        class Base(object): pass
        class ASub(Base): pass
        def g():
            x = Base()
            return isinstance(x, ASub)
        res = self.interpret(g, [])
        assert res == False

    def test_class___name__(self):
        class Base(object): pass
        class ASub(Base): pass
        def g(n):
            if n == 1:
                x = Base()
            else:
                x = ASub()
            return x.__class__.__name__
        res = self.interpret(g, [1])
        assert self.ll_to_string(res) == "Base"
        res = self.interpret(g, [2])
        assert self.ll_to_string(res) == "ASub"

    def test_str_class(self):
        class Base(object): pass
        class ASub(Base): pass
        def g(n):
            if n == 1:
                x = Base()
            else:
                x = ASub()
            return str(x.__class__)
        res = self.interpret(g, [1])
        assert self.ll_to_string(res) == "Base"
        res = self.interpret(g, [2])
        assert self.ll_to_string(res) == "ASub"

    def test_bug_callfamily(self):
        def cb1():
            xxx    # never actually called
        def cb2():
            pass
        def g(cb, result):
            assert (cb is None) == (result == 0)
        def h(cb):
            cb()
        def f():
            g(None, 0)
            g(cb1, 1)
            g(cb2, 2)
            h(cb2)
            return 42
        res = self.interpret(f, [])
        assert res == 42

    def test_equality_of_frozen_pbcs_inside_data_structures(self):
        class A:
            def _freeze_(self):
                return True
        a1 = A()
        a2 = A()
        def f():
            return [a1] == [a1]
        def g(i):
            x1 = [a1, a2][i]
            x2 = [a1, a2][i]
            return (x1,) == (x2,)
        res = self.interpret(f, [])
        assert res == True
        res = self.interpret(g, [1])
        assert res == True

    def test_convert_from_anything_to_impossible(self):
        def f1():
            return 42
        def f2():
            raise ValueError
        def f3():
            raise ValueError
        def f(i):
            if i > 5:
                f = f2
            else:
                f = f3
            try:
                f()
            except ValueError:
                pass
            if i > 1:
                f = f2
            else:
                f = f1
            return f()
        self.interpret(f, [-5])

    def test_single_function_to_noncallable_pbcs(self):
        from rpython.annotator import annrpython
        a = annrpython.RPythonAnnotator()

        def h1(i):
            return i + 5
        def h3(i):
            "NOT_RPYTHON"   # should not be annotated
            return i + 7

        def other_func(i):
            h1(i)
            return h1

        def g(i):
            fn = other_func(i)
            if i > 5:
                return fn
            return h3
        self.interpret(g, [-5])

    def test_multiple_functions_to_noncallable_pbcs(self):
        py.test.skip("unsupported")

        from rpython.annotator import annrpython
        a = annrpython.RPythonAnnotator()

        def h1(i):
            return i + 5
        def h2(i):
            return i + 5
        def h3(i):
            "NOT_RPYTHON"   # should not be annotated
            return i + 7

        def g(i):
            if i & 1:
                fn = h1
            else:
                fn = h2
            fn(i)
            if i > 5:
                return fn
            return h3
        self.interpret(g, [-5])

    def test_single_function_from_noncallable_pbcs(self):
        from rpython.annotator import annrpython
        a = annrpython.RPythonAnnotator()

        def h1(i):
            return i + 5
        def h3(i):
            "NOT_RPYTHON"   # should not be annotated
            return i + 7

        def other_func(i):
            h1(i)
            return h1

        def g(i):
            if i & 1:
                fn = h1
            else:
                fn = h3
            h1(i)
            if fn is h1:
                fn(i)
        self.interpret(g, [-5])

# ____________________________________________________________

def test_hlinvoke_simple():
    def f(a,b):
        return a + b
    from rpython.translator import translator
    from rpython.annotator import annrpython
    a = annrpython.RPythonAnnotator()

    s_f = a.bookkeeper.immutablevalue(f)
    a.bookkeeper.emulate_pbc_call('f', s_f, [annmodel.SomeInteger(), annmodel.SomeInteger()])
    a.complete()

    from rpython.rtyper import rtyper
    rt = rtyper.RPythonTyper(a)
    rt.specialize()

    def ll_h(R, f, x):
        from rpython.rlib.objectmodel import hlinvoke
        return hlinvoke(R, f, x, 2)

    from rpython.rtyper import annlowlevel

    r_f = rt.getrepr(s_f)

    s_R = a.bookkeeper.immutablevalue(r_f)
    s_ll_f = lltype_to_annotation(r_f.lowleveltype)
    ll_h_graph = annlowlevel.annotate_lowlevel_helper(a, ll_h, [s_R, s_ll_f, annmodel.SomeInteger()])
    assert a.binding(ll_h_graph.getreturnvar()).knowntype == int
    rt.specialize_more_blocks()

    from rpython.rtyper.llinterp import LLInterpreter
    interp = LLInterpreter(rt)

    #a.translator.view()
    res = interp.eval_graph(ll_h_graph, [None, None, 3])
    assert res == 5

def test_hlinvoke_simple2():
    def f1(a,b):
        return a + b
    def f2(a,b):
        return a - b
    from rpython.annotator import annrpython
    a = annrpython.RPythonAnnotator()

    def g(i):
        if i:
            f = f1
        else:
            f = f2
        f(5,4)
        f(3,2)

    a.build_types(g, [int])

    from rpython.rtyper import rtyper
    rt = rtyper.RPythonTyper(a)
    rt.specialize()

    def ll_h(R, f, x):
        from rpython.rlib.objectmodel import hlinvoke
        return hlinvoke(R, f, x, 2)

    from rpython.rtyper import annlowlevel

    f1desc = a.bookkeeper.getdesc(f1)
    f2desc = a.bookkeeper.getdesc(f2)

    s_f = annmodel.SomePBC([f1desc, f2desc])
    r_f = rt.getrepr(s_f)

    s_R = a.bookkeeper.immutablevalue(r_f)
    s_ll_f = lltype_to_annotation(r_f.lowleveltype)
    ll_h_graph= annlowlevel.annotate_lowlevel_helper(a, ll_h, [s_R, s_ll_f, annmodel.SomeInteger()])
    assert a.binding(ll_h_graph.getreturnvar()).knowntype == int
    rt.specialize_more_blocks()

    from rpython.rtyper.llinterp import LLInterpreter
    interp = LLInterpreter(rt)

    #a.translator.view()
    res = interp.eval_graph(ll_h_graph, [None, r_f.convert_desc(f1desc), 3])
    assert res == 5
    res = interp.eval_graph(ll_h_graph, [None, r_f.convert_desc(f2desc), 3])
    assert res == 1

def test_hlinvoke_hltype():
    class A(object):
        def __init__(self, v):
            self.v = v
    def f(a):
        return A(a)

    from rpython.annotator import annrpython
    a = annrpython.RPythonAnnotator()

    def g():
        a = A(None)
        f(a)

    a.build_types(g, [])

    from rpython.rtyper import rtyper
    from rpython.rtyper import rclass
    rt = rtyper.RPythonTyper(a)
    rt.specialize()

    def ll_h(R, f, a):
        from rpython.rlib.objectmodel import hlinvoke
        return hlinvoke(R, f, a)

    from rpython.rtyper import annlowlevel

    s_f = a.bookkeeper.immutablevalue(f)
    r_f = rt.getrepr(s_f)

    s_R = a.bookkeeper.immutablevalue(r_f)
    s_ll_f = lltype_to_annotation(r_f.lowleveltype)
    A_repr = rclass.getinstancerepr(rt, a.bookkeeper.getdesc(A).
                                    getuniqueclassdef())
    ll_h_graph = annlowlevel.annotate_lowlevel_helper(
        a, ll_h, [s_R, s_ll_f, SomePtr(A_repr.lowleveltype)])
    s = a.binding(ll_h_graph.getreturnvar())
    assert s.ll_ptrtype == A_repr.lowleveltype
    rt.specialize_more_blocks()

    from rpython.rtyper.llinterp import LLInterpreter
    interp = LLInterpreter(rt)

    #a.translator.view()
    c_a = A_repr.convert_const(A(None))
    res = interp.eval_graph(ll_h_graph, [None, None, c_a])
    assert typeOf(res) == A_repr.lowleveltype

def test_hlinvoke_method_hltype():
    class A(object):
        def __init__(self, v):
            self.v = v
    class Impl(object):
        def f(self, a):
            return A(a)

    from rpython.annotator import annrpython
    a = annrpython.RPythonAnnotator()

    def g():
        a = A(None)
        i = Impl()
        i.f(a)

    a.build_types(g, [])

    from rpython.rtyper import rtyper
    from rpython.rtyper import rclass
    rt = rtyper.RPythonTyper(a)
    rt.specialize()

    def ll_h(R, f, a):
        from rpython.rlib.objectmodel import hlinvoke
        return hlinvoke(R, f, a)

    from rpython.rtyper import annlowlevel

    Impl_def = a.bookkeeper.getdesc(Impl).getuniqueclassdef()
    Impl_f_desc = a.bookkeeper.getmethoddesc(
        a.bookkeeper.getdesc(Impl.f.im_func),
        Impl_def,
        Impl_def,
        'f')
    s_f = annmodel.SomePBC([Impl_f_desc])
    r_f = rt.getrepr(s_f)

    s_R = a.bookkeeper.immutablevalue(r_f)
    s_ll_f = lltype_to_annotation(r_f.lowleveltype)
    A_repr = rclass.getinstancerepr(rt, a.bookkeeper.getdesc(A).
                                    getuniqueclassdef())
    ll_h_graph = annlowlevel.annotate_lowlevel_helper(
        a, ll_h, [s_R, s_ll_f, SomePtr(A_repr.lowleveltype)])
    s = a.binding(ll_h_graph.getreturnvar())
    assert s.ll_ptrtype == A_repr.lowleveltype
    rt.specialize_more_blocks()

    from rpython.rtyper.llinterp import LLInterpreter
    interp = LLInterpreter(rt)

    # low-level value is just the instance
    c_f = rclass.getinstancerepr(rt, Impl_def).convert_const(Impl())
    c_a = A_repr.convert_const(A(None))
    res = interp.eval_graph(ll_h_graph, [None, c_f, c_a])
    assert typeOf(res) == A_repr.lowleveltype

def test_hlinvoke_pbc_method_hltype():
    class A(object):
        def __init__(self, v):
            self.v = v
    class Impl(object):
        def _freeze_(self):
            return True

        def f(self, a):
            return A(a)

    from rpython.annotator import annrpython
    a = annrpython.RPythonAnnotator()

    i = Impl()

    def g():
        a = A(None)
        i.f(a)

    a.build_types(g, [])

    from rpython.rtyper import rtyper
    from rpython.rtyper import rclass
    rt = rtyper.RPythonTyper(a)
    rt.specialize()

    def ll_h(R, f, a):
        from rpython.rlib.objectmodel import hlinvoke
        return hlinvoke(R, f, a)

    from rpython.rtyper import annlowlevel

    s_f = a.bookkeeper.immutablevalue(i.f)
    r_f = rt.getrepr(s_f)

    s_R = a.bookkeeper.immutablevalue(r_f)
    s_ll_f = lltype_to_annotation(r_f.lowleveltype)

    A_repr = rclass.getinstancerepr(rt, a.bookkeeper.getdesc(A).
                                    getuniqueclassdef())
    ll_h_graph = annlowlevel.annotate_lowlevel_helper(
        a, ll_h, [s_R, s_ll_f, SomePtr(A_repr.lowleveltype)])
    s = a.binding(ll_h_graph.getreturnvar())
    assert s.ll_ptrtype == A_repr.lowleveltype
    rt.specialize_more_blocks()

    from rpython.rtyper.llinterp import LLInterpreter
    interp = LLInterpreter(rt)

    c_f = r_f.convert_const(i.f)
    c_a = A_repr.convert_const(A(None))
    res = interp.eval_graph(ll_h_graph, [None, c_f, c_a])
    assert typeOf(res) == A_repr.lowleveltype

# ____________________________________________________________

class TestSmallFuncSets(TestRPBC):
    def setup_class(cls):
        from rpython.config.translationoption import get_combined_translation_config
        cls.config = get_combined_translation_config(translating=True)
        cls.config.translation.withsmallfuncsets = 3

    def interpret(self, fn, args, **kwds):
        kwds['config'] = self.config
        return TestRPBC.interpret(fn, args, **kwds)

    def test_class_missing_base_method_should_crash(self):
        class Base(object):
            pass   # no method 'm' here
        class A(Base):
            def m(self):
                return 42
        class B(Base):
            def m(self):
                return 63
        def g(n):
            if n == 1:
                return A()
            elif n == 2:
                return B()
            else:
                return Base()
        def f(n):
            return g(n).m()

        assert self.interpret(f, [1]) == 42
        assert self.interpret(f, [2]) == 63
        e = py.test.raises(ValueError, self.interpret, f, [3])
        assert str(e.value).startswith(r"exit case '\xff' not found")

    @py.test.mark.parametrize('limit', [3, 5])
    def test_conversion_table(self, limit):
        # with limit==3, check conversion from Char to Ptr(Func).
        # with limit>3, check conversion from Char to Char.
        def f1():
            return 111
        def f2():
            return 222
        def f3():
            return 333
        def g(n):
            if n & 1:
                return f1
            else:
                return f2
        def f(n):
            x = g(n)    # can be f1 or f2
            if n > 10:
                x = f3  # now can be f1 or f2 or f3
            return x()

        from rpython.config.translationoption import get_combined_translation_config
        self.config = get_combined_translation_config(translating=True)
        self.config.translation.withsmallfuncsets = limit
        assert self.interpret(f, [3]) == 111
        assert self.interpret(f, [4]) == 222
        assert self.interpret(f, [13]) == 333
        assert self.interpret(f, [14]) == 333


def test_smallfuncsets_basic():
    from rpython.translator.translator import TranslationContext, graphof
    from rpython.config.translationoption import get_combined_translation_config
    from rpython.rtyper.llinterp import LLInterpreter
    config = get_combined_translation_config(translating=True)
    config.translation.withsmallfuncsets = 10

    def g(x):
        return x + 1
    def h(x):
        return x - 1
    def f(x, y):
        if y > 0:
            func = g
        else:
            func = h
        return func(x)
    t = TranslationContext(config=config)
    a = t.buildannotator()
    a.build_types(f, [int, int])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    graph = graphof(t, f)
    interp = LLInterpreter(rtyper)
    res = interp.eval_graph(graph, [0, 0])
    assert res == -1
    res = interp.eval_graph(graph, [0, 1])
    assert res == 1
