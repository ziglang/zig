import py
from rpython.rtyper.rtuple import TUPLE_TYPE, TupleRepr
from rpython.rtyper.lltypesystem.lltype import Signed, Bool
from rpython.rtyper.rbool import bool_repr
from rpython.rtyper.rint import signed_repr
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.error import TyperError
from rpython.rlib.objectmodel import compute_hash
from rpython.translator.translator import TranslationContext


def test_rtuple():
    rtuple = TupleRepr(None, [signed_repr, bool_repr])
    assert rtuple.lowleveltype == TUPLE_TYPE([Signed, Bool])

# ____________________________________________________________

class TestRtuple(BaseRtypingTest):

    def test_simple(self):
        def dummyfn(x):
            l = (10, x, 30)
            return l[2]
        res = self.interpret(dummyfn, [4])
        assert res == 30

    def test_len(self):
        def dummyfn(x):
            l = (5,x)
            return len(l)
        res = self.interpret(dummyfn, [4])
        assert res == 2

    def test_return_tuple(self):
        def dummyfn(x, y):
            return (x<y, x>y)
        res = self.interpret(dummyfn, [4,5])
        assert res.item0 == True
        assert res.item1 == False

    def test_tuple_concatenation(self):
        def f(n):
            tup = (1,n)
            tup1 = (3,)
            res = tup + tup1 + ()
            return res[0]*100 + res[1]*10 + res[2]
        res = self.interpret(f, [2])
        assert res == 123

    def test_tuple_concatenation_mix(self):
        def f(n):
            tup = (1,n)
            tup1 = ('3',)
            res = tup + tup1
            return res[0]*100 + res[1]*10 + ord(res[2]) - ord('0')
        res = self.interpret(f, [2])
        assert res == 123

    def test_constant_tuple_contains(self):
        def f(i):
            t1 = (1, 2, 3, 4)
            return i in t1
        res = self.interpret(f, [3])
        assert res is True
        res = self.interpret(f, [0])
        assert res is False

    def test_constant_tuple_contains2(self):
        def t1():
            return (1,2,3,4)
        def f(i):
            return i in t1()
        res = self.interpret(f, [3])
        assert res is True
        res = self.interpret(f, [0])
        assert res is False

    def test_constant_tuple_contains3(self):
        def f(i):
            return i in ()
        res = self.interpret(f, [3])
        assert res is False

    def test_constant_tuple_contains4(self):
        def f(i):
            return i in (3,)
        res = self.interpret(f, [3])
        assert res is True
        res = self.interpret(f, [4])
        assert res is False

    def test_constant_unichar_tuple_contains(self):
        def f(i):
            return unichr(i) in (u'1', u'9')
        res = self.interpret(f, [49])
        assert res is True
        res = self.interpret(f, [50])
        assert res is False

    def test_constant_tuple_contains_bug(self):
        def f(i):
            return chr(i) in ('1', '2', '34')    # the '34' can never match
        res = self.interpret(f, [ord('1')])
        assert res is True
        res = self.interpret(f, [ord('3')])
        assert res is False

    def test_conv(self):
        def t0():
            return (3, 2, None)
        def t1():
            return (7, 2, "xy")
        def f(i):
            if i == 1:
                return t1()
            else:
                return t0()

        res = self.interpret(f, [1])
        assert res.item0 == 7
        assert self.ll_to_string(res.item2) == "xy"

        res = self.interpret(f, [0])
        assert res.item0 == 3
        assert not res.item2

    def test_constant_tuples_shared(self):
        def g(n):
            x = (n, 42)    # constant (5, 42) detected by the annotator
            y = (5, 42)    # another one, built by the flow space
            z = x + ()     # yet another
            return x, y, z
        def f():
            return g(5)
        res = self.interpret(f, [])
        assert res.item0 == res.item1 == res.item2

    def test_inst_tuple_getitem(self):
        class A:
            pass
        class B(A):
            pass

        def f(i):
            if i:
                x = (1, A())
            else:
                x = (1, B())
            return x[1]

        res = self.interpret(f, [0])
        assert self.class_name(res) == "B"

    def test_inst_tuple_add_getitem(self):
        class A:
            pass
        class B(A):
            pass

        def f(i):
            x = (1, A())
            y = (2, B())
            if i:
                z = x + y
            else:
                z = y + x
            return z[1]

        res = self.interpret(f, [1])
        assert self.class_name(res) == "A"

        res = self.interpret(f, [0])
        assert self.class_name(res) == "B"

    def test_type_erase(self):
        class A(object):
            pass
        class B(object):
            pass

        def f():
            return (A(), B()), (B(), A())

        t = TranslationContext()
        s = t.buildannotator().build_types(f, [])
        rtyper = t.buildrtyper()
        rtyper.specialize()

        s_AB_tup = s.items[0]
        s_BA_tup = s.items[1]

        r_AB_tup = rtyper.getrepr(s_AB_tup)
        r_BA_tup = rtyper.getrepr(s_AB_tup)

        assert r_AB_tup.lowleveltype == r_BA_tup.lowleveltype

    def test_tuple_hash(self):
        def f(i, j):
            return compute_hash((i, j))

        res1 = self.interpret(f, [12, 27])
        res2 = self.interpret(f, [27, 12])
        assert res1 != res2

    def test_constant_tuple_hash_str(self):
        def f(i):
            if i:
                t = (None, "abc")
            else:
                t = ("abc", None)
            return compute_hash(t)

        res1 = self.interpret(f, [0])
        res2 = self.interpret(f, [1])
        assert res1 != res2

    def test_tuple_to_list(self):
        def f(i, j):
            return list((i, j))

        res = self.interpret(f, [2, 3])
        assert self.ll_to_list(res) == [2, 3]

    def test_tuple_iterator_length1(self):
        def f(i):
            total = 0
            for x in (i,):
                total += x
            return total
        res = self.interpret(f, [93813])
        assert res == 93813

    def test_tuple_iterator_reversed_unsupported(self):
        def f(i):
            total = 0
            t = (i,)
            for x in reversed(t):
                total += x
            return total
        py.test.raises(TyperError, self.interpret, f, [93813])

    def test_inst_tuple_iter(self):
        class A:
            pass
        class B(A):
            pass

        def f(i):
            if i:
                x = (A(),)
            else:
                x = (B(),)
            l = None
            for y in x:
                l = y
            return l

        res = self.interpret(f, [0])
        assert self.class_name(res) == "B"

    def test_access_in_try(self):
        def f(sq):
            try:
                return sq[2]
            except ZeroDivisionError:
                return 42
            return -1
        def g(n):
            t = (1,2,n)
            return f(t)
        res = self.interpret(g, [3])
        assert res == 3

    def test_void_items(self):
        def f():
            return 6
        def getf():
            return f
        def g():
            f1 = getf()
            return (f1, 12)
        def example():
            return g()[0]()
        res = self.interpret(example, [])
        assert res == 6

    def test_empty_tuple(self):
        def f():
            lst = [(), (), ()]
            res = []
            for x in lst:
                res.append(list(x))
            assert res[0] == res[1] == res[2] == []
        self.interpret(f, [])

    def test_slice(self):
        def g(n):
            t = (1.5, "hello", n)
            return t[1:] + t[:-1] + t[12:] + t[0:2]
        def f(n):
            res = g(n)
            assert len(res) == 6
            assert res[0] == "hello"
            assert res[1] == n
            assert res[2] == 1.5
            assert res[3] == "hello"
            assert res[4] == 1.5
            assert res[5] == "hello"
        self.interpret(f, [9])

    def test_tuple_eq(self):
        def f(n):
            return (n, 6) == (3, n*2)
        res = self.interpret(f, [3])
        assert res is True
        res = self.interpret(f, [2])
        assert res is False

    def test_tuple_ne(self):
        def f(n):
            return (n, 6) != (3, n*2)
        res = self.interpret(f, [3])
        assert res is False
        res = self.interpret(f, [2])
        assert res is True

    def test_tuple_eq_list(self):
        def f(n):
            lst1 = [1, n]
            lst1.append(3)
            return (lst1, 52) == ([1, 53, 3], n-1)
        res = self.interpret(f, [53])
        assert res is True

    def test_compare_list_char_str(self):
        def fn(i, j):
            t1 = ([str(i)],)
            t2 = ([chr(j)],)
            return t1 == t2
        res = self.interpret(fn, [65, 65])
        assert res is False
        res = self.interpret(fn, [1, 49])
        assert res is True

    def test_tuple_hash_2(self):
        def f(n):
            return compute_hash((n, 6)) == compute_hash((3, n*2))
        res = self.interpret(f, [3])
        assert res is True

    def test_tuple_str(self):
        def f(n):
            assert str(()) == "()"
            assert str((n,)) == "(%d,)" % n
            assert str((n, 6)) == "(%d, 6)" % n
            assert str(((n,),)) == "((%d,),)" % n
        self.interpret(f, [3])
