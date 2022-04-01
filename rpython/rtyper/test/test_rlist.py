import sys
import re

import py

from rpython.rtyper.debug import ll_assert
from rpython.rtyper.error import TyperError
from rpython.rtyper.llinterp import LLException, LLAssertFailure
from rpython.rtyper.lltypesystem import rlist as ll_rlist
from rpython.rtyper.lltypesystem.rlist import ListRepr, FixedSizeListRepr, ll_newlist, ll_fixed_newlist
from rpython.rtyper.rint import signed_repr
from rpython.rtyper.rlist import *
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.translator.translator import TranslationContext


# undo the specialization parameters
for n1 in 'get set del'.split():
    if n1 == "get":
        extraarg = "ll_getitem_fast, "
    else:
        extraarg = ""
    for n2 in '', '_nonneg':
        name = 'll_%sitem%s' % (n1, n2)
        globals()['_' + name] = globals()[name]
        exec("""if 1:
            def %s(*args):
                return _%s(dum_checkidx, %s*args)
""" % (name, name, extraarg))
del n1, n2, name


class BaseTestListImpl:

    def check_list(self, l1, expected):
        assert ll_len(l1) == len(expected)
        for i, x in zip(range(len(expected)), expected):
            assert ll_getitem_nonneg(l1, i) == x

    def test_rlist_basic(self):
        l = self.sample_list()
        assert ll_getitem(l, -4) == 42
        assert ll_getitem_nonneg(l, 1) == 43
        assert ll_getitem(l, 2) == 44
        assert ll_getitem(l, 3) == 45
        assert ll_len(l) == 4
        self.check_list(l, [42, 43, 44, 45])

    def test_rlist_set(self):
        l = self.sample_list()
        ll_setitem(l, -1, 99)
        self.check_list(l, [42, 43, 44, 99])
        ll_setitem_nonneg(l, 1, 77)
        self.check_list(l, [42, 77, 44, 99])

    def test_rlist_slice(self):
        l = self.sample_list()
        LIST = typeOf(l).TO
        self.check_list(ll_listslice_startonly(LIST, l, 0), [42, 43, 44, 45])
        self.check_list(ll_listslice_startonly(LIST, l, 1), [43, 44, 45])
        self.check_list(ll_listslice_startonly(LIST, l, 2), [44, 45])
        self.check_list(ll_listslice_startonly(LIST, l, 3), [45])
        self.check_list(ll_listslice_startonly(LIST, l, 4), [])
        for start in range(5):
            for stop in range(start, 8):
                self.check_list(ll_listslice_startstop(LIST, l, start, stop),
                                [42, 43, 44, 45][start:stop])

    def test_rlist_setslice(self):
        n = 100
        for start in range(5):
            for stop in range(start, 5):
                l1 = self.sample_list()
                l2 = self.sample_list()
                expected = [42, 43, 44, 45]
                for i in range(start, stop):
                    expected[i] = n
                    ll_setitem(l2, i, n)
                    n += 1
                l2 = ll_listslice_startstop(typeOf(l2).TO, l2, start, stop)
                ll_listsetslice(l1, start, stop, l2)
                self.check_list(l1, expected)


# helper used by some tests below
def list_is_clear(lis, idx):
    items = lis._obj.items._obj.items
    for i in range(idx, len(items)):
        if items[i]._obj is not None:
            return False
    return True


class TestListImpl(BaseTestListImpl):
    def sample_list(self):    # [42, 43, 44, 45]
        rlist = ListRepr(None, signed_repr)
        rlist.setup()
        l = ll_newlist(rlist.lowleveltype.TO, 3)
        ll_setitem(l, 0, 42)
        ll_setitem(l, -2, 43)
        ll_setitem_nonneg(l, 2, 44)
        ll_append(l, 45)
        return l

    def test_rlist_del(self):
        l = self.sample_list()
        ll_delitem_nonneg(l, 0)
        self.check_list(l, [43, 44, 45])
        ll_delitem(l, -2)
        self.check_list(l, [43, 45])
        ll_delitem(l, 1)
        self.check_list(l, [43])
        ll_delitem(l, 0)
        self.check_list(l, [])

    def test_rlist_extend_concat(self):
        l = self.sample_list()
        ll_extend(l, l)
        self.check_list(l, [42, 43, 44, 45] * 2)
        l1 = ll_concat(typeOf(l).TO, l, l)
        assert typeOf(l1) == typeOf(l)
        assert l1 != l
        self.check_list(l1, [42, 43, 44, 45] * 4)

    def test_rlist_delslice(self):
        l = self.sample_list()
        ll_listdelslice_startonly(l, 3)
        self.check_list(l, [42, 43, 44])
        ll_listdelslice_startonly(l, 0)
        self.check_list(l, [])
        for start in range(5):
            for stop in range(start, 8):
                l = self.sample_list()
                ll_listdelslice_startstop(l, start, stop)
                expected = [42, 43, 44, 45]
                del expected[start:stop]
                self.check_list(l, expected)


class TestFixedSizeListImpl(BaseTestListImpl):
    def sample_list(self):    # [42, 43, 44, 45]
        rlist = FixedSizeListRepr(None, signed_repr)
        rlist.setup()
        l = ll_fixed_newlist(rlist.lowleveltype.TO, 4)
        ll_setitem(l, 0, 42)
        ll_setitem(l, -3, 43)
        ll_setitem_nonneg(l, 2, 44)
        ll_setitem(l, 3, 45)
        return l

    def test_rlist_extend_concat(self):
        l = self.sample_list()
        lvar = TestListImpl.sample_list(TestListImpl())
        ll_extend(lvar, l)
        self.check_list(lvar, [42, 43, 44, 45] * 2)

        l1 = ll_concat(typeOf(l).TO, lvar, l)
        assert typeOf(l1) == typeOf(l)
        assert l1 != l
        self.check_list(l1, [42, 43, 44, 45] * 3)

        l1 = ll_concat(typeOf(l).TO, l, lvar)
        assert typeOf(l1) == typeOf(l)
        assert l1 != l
        self.check_list(l1, [42, 43, 44, 45] * 3)

        lvar1 = ll_concat(typeOf(lvar).TO, lvar, l)
        assert typeOf(lvar1) == typeOf(lvar)
        assert lvar1 != lvar
        self.check_list(l1, [42, 43, 44, 45] * 3)

        lvar1 = ll_concat(typeOf(lvar).TO, l, lvar)
        assert typeOf(lvar1) == typeOf(lvar)
        assert lvar1 != lvar
        self.check_list(lvar1, [42, 43, 44, 45] * 3)



# ____________________________________________________________

# these classes are used in the tests below
class Foo:
    pass

class Bar(Foo):
    pass

class Freezing:
    def _freeze_(self):
        return True


class TestRlist(BaseRtypingTest):
    rlist = ll_rlist

    def test_simple(self):
        def dummyfn():
            l = [10, 20, 30]
            return l[2]
        res = self.interpret(dummyfn, [])
        assert res == 30

    def test_append(self):
        def dummyfn():
            l = []
            l.append(50)
            l.append(60)
            l.append(70)
            l.append(80)
            l.append(90)
            return len(l), l[0], l[-1]
        res = self.interpret(dummyfn, [])
        assert res.item0 == 5
        assert res.item1 == 50
        assert res.item2 == 90

    def test_len(self):
        def dummyfn():
            l = [5, 10]
            return len(l)
        res = self.interpret(dummyfn, [])
        assert res == 2

        def dummyfn():
            l = [5]
            l.append(6)
            return len(l)
        res = self.interpret(dummyfn, [])
        assert res == 2

    def test_iterate(self):
        def dummyfn():
            total = 0
            for x in [1, 3, 5, 7, 9]:
                total += x
            return total
        res = self.interpret(dummyfn, [])
        assert res == 25
        def dummyfn():
            total = 0
            l = [1, 3, 5, 7]
            l.append(9)
            for x in l:
                total += x
            return total
        res = self.interpret(dummyfn, [])
        assert res == 25

    def test_iterate_next(self):
        def dummyfn():
            total = 0
            it = iter([1, 3, 5, 7, 9])
            while 1:
                try:
                    x = it.next()
                except StopIteration:
                    break
                total += x
            return total
        res = self.interpret(dummyfn, [])
        assert res == 25
        def dummyfn():
            total = 0
            l = [1, 3, 5, 7]
            l.append(9)
            it = iter(l)
            while 1:
                try:
                    x = it.next()
                except StopIteration:
                    break
                total += x
            return total
        res = self.interpret(dummyfn, [])
        assert res == 25

    def test_recursive(self):
        def dummyfn(N):
            l = []
            while N > 0:
                l = [l]
                N -= 1
            return len(l)
        res = self.interpret(dummyfn, [5])
        assert res == 1

        def dummyfn(N):
            l = []
            while N > 0:
                l.append(l)
                N -= 1
            return len(l)
        res = self.interpret(dummyfn, [5])
        assert res == 5

    def test_add(self):
        def dummyfn():
            l = [5]
            l += [6, 7]
            return l + [8]
        res = self.interpret(dummyfn, [])
        assert self.ll_to_list(res) == [5, 6, 7, 8]

        def dummyfn():
            l = [5]
            l += [6, 7]
            l2 =  l + [8]
            l2.append(9)
            return l2
        res = self.interpret(dummyfn, [])
        assert self.ll_to_list(res) == [5, 6, 7, 8, 9]

    def test_slice(self):
        def dummyfn():
            l = [5, 6, 7, 8, 9]
            return l[:2], l[1:4], l[3:]
        res = self.interpret(dummyfn, [])
        assert self.ll_to_list(res.item0) == [5, 6]
        assert self.ll_to_list(res.item1) == [6, 7, 8]
        assert self.ll_to_list(res.item2) == [8, 9]

        def dummyfn():
            l = [5, 6, 7, 8]
            l.append(9)
            return l[:2], l[1:4], l[3:]
        res = self.interpret(dummyfn, [])
        assert self.ll_to_list(res.item0) == [5, 6]
        assert self.ll_to_list(res.item1) == [6, 7, 8]
        assert self.ll_to_list(res.item2) == [8, 9]

    def test_getslice_not_constant_folded(self):
        l = list('abcdef')

        def dummyfn():
            result = []
            for i in range(3):
                l2 = l[2:]
                result.append(l2.pop())
            return result

        res = self.interpret(dummyfn, [])
        assert self.ll_to_list(res) == ['f', 'f', 'f']

    def test_set_del_item(self):
        def dummyfn():
            l = [5, 6, 7]
            l[1] = 55
            l[-1] = 66
            return l
        res = self.interpret(dummyfn, [])
        assert self.ll_to_list(res) == [5, 55, 66]

        def dummyfn():
            l = []
            l.append(5)
            l.append(6)
            l.append(7)
            l[1] = 55
            l[-1] = 66
            return l
        res = self.interpret(dummyfn, [])
        assert self.ll_to_list(res) == [5, 55, 66]

        def dummyfn():
            l = [5, 6, 7]
            l[1] = 55
            l[-1] = 66
            del l[0]
            del l[-1]
            del l[:]
            return len(l)
        res = self.interpret(dummyfn, [])
        assert res == 0

    def test_setslice(self):
        def dummyfn():
            l = [10, 9, 8, 7]
            l[:2] = [6, 5]
            return l[0], l[1], l[2], l[3]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 6
        assert res.item1 == 5
        assert res.item2 == 8
        assert res.item3 == 7

        def dummyfn():
            l = [10, 9, 8]
            l.append(7)
            l[:2] = [6, 5]
            return l[0], l[1], l[2], l[3]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 6
        assert res.item1 == 5
        assert res.item2 == 8
        assert res.item3 == 7

        def dummyfn():
            l = [10, 9, 8, 7]
            l[1:3] = [42]
            return l[0], l[1], l[2]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 10
        assert res.item1 == 42
        assert res.item2 == 7

        def dummyfn():
            l = [10, 9, 8, 7]
            l[1:3] = [6, 5, 0]
            return l[0], l[1], l[2], l[3], l[4]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 10
        assert res.item1 == 6
        assert res.item2 == 5
        assert res.item3 == 0
        assert res.item4 == 7

        def dummyfn():
            l = [10, 9, 8, 7]
            l[1:1] = [6, 5, 0]
            return l[0], l[1], l[2], l[3], l[4], l[5], l[6]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 10
        assert res.item1 == 6
        assert res.item2 == 5
        assert res.item3 == 0
        assert res.item4 == 9
        assert res.item5 == 8
        assert res.item6 == 7

        def dummyfn():
            l = [10, 9, 8, 7]
            l[1:3] = []
            return l[0], l[1]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 10
        assert res.item1 == 7

    def test_delslice(self):
        def dummyfn():
            l = [10, 9, 8, 7]
            del l[:2]
            return len(l), l[0], l[1]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 2
        assert res.item1 == 8
        assert res.item2 == 7

        def dummyfn():
            l = [10, 9, 8, 7]
            del l[2:]
            return len(l), l[0], l[1]
        res = self.interpret(dummyfn, ())
        assert res.item0 == 2
        assert res.item1 == 10
        assert res.item2 == 9

    def test_bltn_list(self):
        # test for ll_copy()
        for resize1 in [False, True]:
            for resize2 in [False, True]:
                def dummyfn():
                    l1 = [42]
                    if resize1:
                        l1.append(43)
                    l2 = list(l1)
                    if resize2:
                        l2.append(44)
                    l2[0] = 0
                    return l1[0]
                res = self.interpret(dummyfn, ())
                assert res == 42

    def test_bltn_list_from_string(self):
        def dummyfn(n):
            l1 = list(str(n))
            return ord(l1[0])
        res = self.interpret(dummyfn, [71234])
        assert res == ord('7')

    def test_bltn_list_from_unicode(self):
        def dummyfn(n):
            l1 = list(unicode(str(n)))
            return ord(l1[0])
        res = self.interpret(dummyfn, [71234])
        assert res == ord('7')

    def test_bltn_list_from_string_resize(self):
        def dummyfn(n):
            l1 = list(str(n))
            l1.append('X')
            return ord(l1[0])
        res = self.interpret(dummyfn, [71234])
        assert res == ord('7')

    def test_bltn_list_from_unicode_resize(self):
        def dummyfn(n):
            l1 = list(unicode(str(n)))
            l1.append(u'X')
            return ord(l1[0])
        res = self.interpret(dummyfn, [71234])
        assert res == ord('7')

    def test_is_true(self):
        def is_true(lst):
            if lst:
                return True
            else:
                return False
        def dummyfn1():
            return is_true(None)
        def dummyfn2():
            return is_true([])
        def dummyfn3():
            return is_true([0])
        assert self.interpret(dummyfn1, ()) == False
        assert self.interpret(dummyfn2, ()) == False
        assert self.interpret(dummyfn3, ()) == True

    def test_list_index_simple(self):
        def dummyfn(i):
            l = [5, 6, 7, 8]
            return l.index(i)

        res = self.interpret(dummyfn, (6,))
        assert res == 1
        self.interpret_raises(ValueError, dummyfn, [42])

    def test_insert_pop(self):
        def dummyfn():
            l = [6, 7, 8]
            l.insert(0, 5)
            l.insert(1, 42)
            l.pop(2)
            l.pop(0)
            l.pop(-1)
            l.pop()
            return l[-1]
        res = self.interpret(dummyfn, ())
        assert res == 42

    def test_insert_bug(self):
        def dummyfn(n):
            l = [1]
            l = l[:]
            l.pop(0)
            if n < 0:
                l.insert(0, 42)
            else:
                l.insert(n, 42)
            return l
        res = self.interpret(dummyfn, [0])
        assert res.ll_length() == 1
        assert res.ll_getitem_fast(0) == 42
        res = self.interpret(dummyfn, [-1])
        assert res.ll_length() == 1
        assert res.ll_getitem_fast(0) == 42

    def test_inst_pop(self):
        class A:
            pass
        l = [A(), A()]
        def f(idx):
            try:
                return l.pop(idx)
            except IndexError:
                return None
        res = self.interpret(f, [1])
        assert self.class_name(res) == 'A'
        #''.join(res.super.typeptr.name) == 'A\00'

    def test_reverse(self):
        def dummyfn():
            l = [5, 3, 2]
            l.reverse()
            return l[0]*100 + l[1]*10 + l[2]
        res = self.interpret(dummyfn, ())
        assert res == 235

        def dummyfn():
            l = [5]
            l.append(3)
            l.append(2)
            l.reverse()
            return l[0]*100 + l[1]*10 + l[2]
        res = self.interpret(dummyfn, ())
        assert res == 235

    def test_reversed(self):
        klist = [1, 2, 3]

        def fn():
            res = []
            for elem in reversed(klist):
                res.append(elem)
            return res[0] * 100 + res[1] * 10 + res[2]
        res = self.interpret(fn, [])
        assert res == fn()

    def test_prebuilt_list(self):
        klist = [6, 7, 8, 9]
        def dummyfn(n):
            return klist[n]
        res = self.interpret(dummyfn, [0])
        assert res == 6
        res = self.interpret(dummyfn, [3])
        assert res == 9
        res = self.interpret(dummyfn, [-2])
        assert res == 8

        klist = ['a', 'd', 'z']
        def mkdummyfn():
            def dummyfn(n):
                klist.append('k')
                return klist[n]
            return dummyfn
        res = self.interpret(mkdummyfn(), [0])
        assert res == 'a'
        res = self.interpret(mkdummyfn(), [3])
        assert res == 'k'
        res = self.interpret(mkdummyfn(), [-2])
        assert res == 'z'

    def test_bound_list_method(self):
        klist = [1, 2, 3]
        # for testing constant methods without actually mutating the constant
        def dummyfn(n):
            klist.extend([])
        self.interpret(dummyfn, [7])

    def test_list_is(self):
        def dummyfn():
            l1 = []
            return l1 is l1
        res = self.interpret(dummyfn, [])
        assert res is True
        def dummyfn():
            l2 = [1, 2]
            return l2 is l2
        res = self.interpret(dummyfn, [])
        assert res is True
        def dummyfn():
            l1 = [2]
            l2 = [1, 2]
            return l1 is l2
        res = self.interpret(dummyfn, [])
        assert res is False
        def dummyfn():
            l1 = [1, 2]
            l2 = [1]
            l2.append(2)
            return l1 is l2
        res = self.interpret(dummyfn, [])
        assert res is False

        def dummyfn():
            l1 = None
            l2 = [1, 2]
            return l1 is l2
        res = self.interpret(dummyfn, [])
        assert res is False

        def dummyfn():
            l1 = None
            l2 = [1]
            l2.append(2)
            return l1 is l2
        res = self.interpret(dummyfn, [])
        assert res is False

    def test_list_compare(self):
        def fn(i, j, neg=False):
            s1 = [[1, 2, 3], [4, 5, 1], None]
            s2 = [[1, 2, 3], [4, 5, 1], [1], [1, 2], [4, 5, 1, 6],
                  [7, 1, 1, 8, 9, 10], None]
            if neg: return s1[i] != s2[i]
            return s1[i] == s2[j]
        for i in range(3):
            for j in range(7):
                for case in False, True:
                    res = self.interpret(fn, [i,j,case])
                    assert res is fn(i, j, case)

        def fn(i, j, neg=False):
            s1 = [[1, 2, 3], [4, 5, 1], None]
            l = []
            l.extend([1,2,3])
            s2 = [l, [4, 5, 1], [1], [1, 2], [4, 5, 1, 6],
                  [7, 1, 1, 8, 9, 10], None]
            if neg: return s1[i] != s2[i]
            return s1[i] == s2[j]
        for i in range(3):
            for j in range(7):
                for case in False, True:
                    res = self.interpret(fn, [i,j,case])
                    assert res is fn(i, j, case)


    def test_list_comparestr(self):
        def fn(i, j, neg=False):
            s1 = [["hell"], ["hello", "world"]]
            s1[0][0] += "o" # ensure no interning
            s2 = [["hello"], ["world"]]
            if neg: return s1[i] != s2[i]
            return s1[i] == s2[j]
        for i in range(2):
            for j in range(2):
                for case in False, True:
                    res = self.interpret(fn, [i,j,case])
                    assert res is fn(i, j, case)

    def test_list_compare_char_str(self):
        def fn(i, j):
            l1 = [str(i)]
            l2 = [chr(j)]
            return l1 == l2
        res = self.interpret(fn, [65, 65])
        assert res is False
        res = self.interpret(fn, [1, 49])
        assert res is True


    def test_list_compareinst(self):
        def fn(i, j, neg=False):
            foo1 = Foo()
            foo2 = Foo()
            bar1 = Bar()
            s1 = [[foo1], [foo2], [bar1]]
            s2 = s1[:]
            if neg: return s1[i] != s2[i]
            return s1[i] == s2[j]
        for i in range(3):
            for j in range(3):
                for case in False, True:
                    res = self.interpret(fn, [i, j, case])
                    assert res is fn(i, j, case)

        def fn(i, j, neg=False):
            foo1 = Foo()
            foo2 = Foo()
            bar1 = Bar()
            s1 = [[foo1], [foo2], [bar1]]
            s2 = s1[:]

            s2[0].extend([])

            if neg: return s1[i] != s2[i]
            return s1[i] == s2[j]
        for i in range(3):
            for j in range(3):
                for case in False, True:
                    res = self.interpret(fn, [i, j, case])
                    assert res is fn(i, j, case)


    def test_list_contains(self):
        def fn(i, neg=False):
            foo1 = Foo()
            foo2 = Foo()
            bar1 = Bar()
            bar2 = Bar()
            lis = [foo1, foo2, bar1]
            args = lis + [bar2]
            if neg : return args[i] not in lis
            return args[i] in lis
        for i in range(4):
            for case in False, True:
                res = self.interpret(fn, [i, case])
                assert res is fn(i, case)

        def fn(i, neg=False):
            foo1 = Foo()
            foo2 = Foo()
            bar1 = Bar()
            bar2 = Bar()
            lis = [foo1, foo2, bar1]
            lis.append(lis.pop())
            args = lis + [bar2]
            if neg : return args[i] not in lis
            return args[i] in lis
        for i in range(4):
            for case in False, True:
                res = self.interpret(fn, [i, case])
                assert res is fn(i, case)

    def test_constant_list_contains(self):
        # a 'contains' operation on list containing only annotation-time
        # constants should be optimized into the equivalent code of
        # 'in prebuilt-dictionary'.  Hard to test directly...
        def g():
            return 16
        def f(i):
            return i in [1, 2, 4, 8, g()]
        res = self.interpret(f, [2])
        assert res is True
        res = self.interpret(f, [15])
        assert res is False
        res = self.interpret(f, [16])
        assert res is True

    def test_nonconstant_list_contains(self):
        def f(i):
            return i in [1, -i, 2, 4, 8]
        res = self.interpret(f, [2])
        assert res is True
        res = self.interpret(f, [15])
        assert res is False
        res = self.interpret(f, [0])
        assert res is True


    def test_not_a_char_list_after_all_1(self):
        def fn(n):
            l = ['h', 'e', 'l', 'l', '0']
            return str(n) in l     # turns into: str(n) in {'h','e','l','0'}
        res = self.interpret(fn, [5])
        assert res is False
        res = self.interpret(fn, [0])
        assert res is True

        def fn():
            l = ['h', 'e', 'l', 'l', '0']
            return 'hi' in l     # turns into: 'hi' in {'h','e','l','0'}
        res = self.interpret(fn, [])
        assert res is False

    def test_not_a_char_list_after_all_2(self):
        def fn(n):
            l = ['h', 'e', 'l', 'l', 'o', chr(n)]
            return 'world' in l
        res = self.interpret(fn, [0])
        assert res is False

    def test_list_index(self):
        def fn(i):
            foo1 = Foo()
            foo2 = Foo()
            bar1 = Bar()
            bar2 = Bar()
            lis = [foo1, foo2, bar1]
            args = lis + [bar2]
            return lis.index(args[i])
        for i in range(4):
            for varsize in False, True:
                try:
                    res2 = fn(i)
                    res1 = self.interpret(fn, [i])
                    assert res1 == res2
                except Exception as e:
                    self.interpret_raises(e.__class__, fn, [i])

        def fn(i):
            foo1 = Foo()
            foo2 = Foo()
            bar1 = Bar()
            bar2 = Bar()
            lis = [foo1, foo2, bar1]
            args = lis + [bar2]
            lis.append(lis.pop())
            return lis.index(args[i])
        for i in range(4):
            for varsize in False, True:
                try:
                    res2 = fn(i)
                    res1 = self.interpret(fn, [i])
                    assert res1 == res2
                except Exception as e:
                    self.interpret_raises(e.__class__, fn, [i])


    def test_list_str(self):
        def fn():
            return str([1,2,3])

        res = self.interpret(fn, [])
        assert self.ll_to_string(res) == fn()

        def fn():
            return str([[1,2,3]])

        res = self.interpret(fn, [])
        assert self.ll_to_string(res) == fn()

        def fn():
            l = [1,2]
            l.append(3)
            return str(l)

        res = self.interpret(fn, [])
        assert self.ll_to_string(res) == fn()

        def fn():
            l = [1,2]
            l.append(3)
            return str([l])

        res = self.interpret(fn, [])
        assert self.ll_to_string(res) == fn()

        def fn():
            return str([])

        res = self.interpret(fn, [])
        assert self.ll_to_string(res) == fn()

        def fn():
            return str([1.25])

        res = self.interpret(fn, [])
        assert eval(self.ll_to_string(res)) == [1.25]

    def test_list_or_None(self):
        empty_list = []
        nonempty_list = [1, 2]
        def fn(i):
            test = [None, empty_list, nonempty_list][i]
            if test:
                return 1
            else:
                return 0

        res = self.interpret(fn, [0])
        assert res == 0
        res = self.interpret(fn, [1])
        assert res == 0
        res = self.interpret(fn, [2])
        assert res == 1


        nonempty_list = [1, 2]
        def fn(i):
            empty_list = [1]
            empty_list.pop()
            nonempty_list = []
            nonempty_list.extend([1,2])
            test = [None, empty_list, nonempty_list][i]
            if test:
                return 1
            else:
                return 0

        res = self.interpret(fn, [0])
        assert res == 0
        res = self.interpret(fn, [1])
        assert res == 0
        res = self.interpret(fn, [2])
        assert res == 1


    def test_inst_list(self):
        def fn():
            l = [None]
            l[0] = Foo()
            l.append(Bar())
            l2 = [l[1], l[0], l[0]]
            l.extend(l2)
            for x in l2:
                l.append(x)
            x = l.pop()
            x = l.pop()
            x = l.pop()
            x = l2.pop()
            return str(x)+";"+str(l)
        res = self.ll_to_string(self.interpret(fn, []))
        res = res.replace('rpython.rtyper.test.test_rlist.', '')
        res = re.sub(' at 0x[a-z0-9]+', '', res)
        assert res == '<Foo object>;[<Foo object>, <Bar object>, <Bar object>, <Foo object>, <Foo object>]'

        def fn():
            l = [None] * 2
            l[0] = Foo()
            l[1] = Bar()
            l2 = [l[1], l[0], l[0]]
            l = l + [None] * 3
            i = 2
            for x in l2:
                l[i] = x
                i += 1
            return str(l)
        res = self.ll_to_string(self.interpret(fn, []))
        res = res.replace('rpython.rtyper.test.test_rlist.', '')
        res = re.sub(' at 0x[a-z0-9]+', '', res)
        assert res == '[<Foo object>, <Bar object>, <Bar object>, <Foo object>, <Foo object>]'

    def test_list_slice_minusone(self):
        def fn(i):
            lst = [i, i+1, i+2]
            lst2 = lst[:-1]
            return lst[-1] * lst2[-1]
        res = self.interpret(fn, [5])
        assert res == 42

        def fn(i):
            lst = [i, i+1, i+2, 7]
            lst.pop()
            lst2 = lst[:-1]
            return lst[-1] * lst2[-1]
        res = self.interpret(fn, [5])
        assert res == 42

    def test_list_multiply(self):
        def fn(i):
            lst = [i] * i
            ret = len(lst)
            if ret:
                ret *= lst[-1]
            return ret
        for arg in (1, 9, 0, -1, -27):
            res = self.interpret(fn, [arg])
            assert res == fn(arg)
        def fn(i):
            lst = [i, i + 1] * i
            ret = len(lst)
            if ret:
                ret *= lst[-1]
            return ret
        for arg in (1, 9, 0, -1, -27):
            res = self.interpret(fn, [arg])
            assert res == fn(arg)
        def fn(i):
            lst =  i * [i, i + 1]
            ret = len(lst)
            if ret:
                ret *= lst[-1]
            return ret
        for arg in (1, 9, 0, -1, -27):
            res = self.interpret(fn, [arg])
            assert res == fn(arg)

    def test_list_inplace_multiply(self):
        def fn(i):
            lst = [i]
            lst *= i
            ret = len(lst)
            if ret:
                ret *= lst[-1]
            return ret
        for arg in (1, 9, 0, -1, -27):
            res = self.interpret(fn, [arg])
            assert res == fn(arg)
        def fn(i):
            lst = [i, i + 1]
            lst *= i
            ret = len(lst)
            if ret:
                ret *= lst[-1]
            return ret
        for arg in (1, 9, 0, -1, -27):
            res = self.interpret(fn, [arg])
            assert res == fn(arg)

    def test_indexerror(self):
        def fn(i):
            l = [5, 8, 3]
            try:
                l[i] = 99
            except IndexError:
                pass
            try:
                del l[i]
            except IndexError:
                pass
            try:
                return l[2]
            except IndexError:
                return -1
        res = self.interpret(fn, [6])
        assert res == 3
        res = self.interpret(fn, [-2])
        assert res == -1

        def fn(i):
            l = [5, 8]
            l.append(3)
            try:
                l[i] = 99
            except IndexError:
                pass
            try:
                del l[i]
            except IndexError:
                pass
            try:
                return l[2]
            except IndexError:
                return -1
        res = self.interpret(fn, [6])
        assert res == 3
        res = self.interpret(fn, [-2])
        assert res == -1

    def test_list_basic_ops(self):
        def list_basic_ops(i=int, j=int):
            l = [1,2,3]
            l.insert(0, 42)
            del l[1]
            l.append(i)
            listlen = len(l)
            l.extend(l)
            del l[listlen:]
            l += [5,6]
            l[1] = i
            return l[j]
        for i in range(6):
            for j in range(6):
                res = self.interpret(list_basic_ops, [i, j])
                assert res == list_basic_ops(i, j)

    def test_valueerror(self):
        def fn(i):
            l = [4, 7, 3]
            try:
                j = l.index(i)
            except ValueError:
                j = 100
            return j
        res = self.interpret(fn, [4])
        assert res == 0
        res = self.interpret(fn, [7])
        assert res == 1
        res = self.interpret(fn, [3])
        assert res == 2
        res = self.interpret(fn, [6])
        assert res == 100

        def fn(i):
            l = [5, 8]
            l.append(3)
            try:
                l[i] = 99
            except IndexError:
                pass
            try:
                del l[i]
            except IndexError:
                pass
            try:
                return l[2]
            except IndexError:
                return -1
        res = self.interpret(fn, [6])
        assert res == 3
        res = self.interpret(fn, [-2])
        assert res == -1

    def test_voidlist_prebuilt(self):
        frlist = [Freezing()] * 17
        def mylength(l):
            return len(l)
        def f():
            return mylength(frlist)
        res = self.interpret(f, [])
        assert res == 17

    def test_voidlist_fixed(self):
        fr = Freezing()
        def f():
            return len([fr, fr])
        res = self.interpret(f, [])
        assert res == 2

    def test_voidlist_nonfixed(self):
        class Freezing:
            def _freeze_(self):
                return True
        fr = Freezing()
        def f():
            lst = [fr, fr]
            lst.append(fr)
            del lst[1]
            assert lst[0] is fr
            return len(lst)
        res = self.interpret(f, [])
        assert res == 2

    def test_access_in_try(self):
        def f(sq):
            try:
                return sq[2]
            except ZeroDivisionError:
                return 42
            return -1
        def g(n):
            l = [1] * n
            return f(l)
        res = self.interpret(g, [3])
        assert res == 1

    def test_access_in_try_set(self):
        def f(sq):
            try:
                sq[2] = 77
            except ZeroDivisionError:
                return 42
            return -1
        def g(n):
            l = [1] * n
            f(l)
            return l[2]
        res = self.interpret(g, [3])
        assert res == 77

    def test_list_equality(self):
        def dummyfn(n):
            lst = [12] * n
            assert lst == [12, 12, 12]
            lst2 = [[12, 34], [5], [], [12, 12, 12], [5]]
            assert lst in lst2
        self.interpret(dummyfn, [3])

    def test_list_remove(self):
        def dummyfn(n, p):
            l = range(n)
            l.remove(p)
            return len(l)
        res = self.interpret(dummyfn, [1, 0])
        assert res == 0


    def test_getitem_exc_1(self):
        def f(x):
            l = [1]
            return l[x]

        res = self.interpret(f, [0])
        assert res == 1
        with py.test.raises(LLAssertFailure):
            self.interpret(f, [1])

        def f(x):
            l = [1]
            try:
                return l[x]
            except IndexError:
                return -1
            except Exception:
                return 0

        res = self.interpret(f, [0])
        assert res == 1
        res = self.interpret(f, [1])
        assert res == -1

        def f(x):
            l = [1]
            try:
                return l[x]
            except Exception:
                return 0

        res = self.interpret(f, [0])
        assert res == 1
        res = self.interpret(f, [1])
        assert res == 0

        def f(x):
            l = [1]
            try:
                return l[x]
            except ValueError:
                return 0

        res = self.interpret(f, [0])
        assert res == 1

    def test_getitem_exc_2(self):
        def f(x):
            l = [1]
            return l[x]

        res = self.interpret(f, [0])
        assert res == 1
        with py.test.raises(LLAssertFailure):
            self.interpret(f, [1])

        def f(x):
            l = [1]
            try:
                return l[x]
            except IndexError:
                return -1
            except Exception:
                return 0

        res = self.interpret(f, [0])
        assert res == 1
        res = self.interpret(f, [1])
        assert res == -1

        def f(x):
            l = [1]
            try:
                return l[x]
            except Exception:
                return 0

        res = self.interpret(f, [0])
        assert res == 1
        res = self.interpret(f, [1])
        assert res == 0

        def f(x):
            l = [1]
            try:
                return l[x]
            except ValueError:
                return 0

        res = self.interpret(f, [0])
        assert res == 1
        with py.test.raises(LLAssertFailure):
            self.interpret(f, [1])

    def test_charlist_extension_1(self):
        def f(n):
            s = 'hello%d' % n
            l = ['a', 'b']
            l += s
            return ''.join(l)
        res = self.interpret(f, [58])
        assert self.ll_to_string(res) == 'abhello58'

    def test_unicharlist_extension_1(self):
        def f(n):
            s = u'hello%d' % n
            l = [u'a', u'b']
            l += s
            return ''.join([chr(ord(c)) for c in l])
        res = self.interpret(f, [58])
        assert self.ll_to_string(res) == 'abhello58'

    def test_extend_a_non_char_list_1(self):
        def f(n):
            s = 'hello%d' % n
            l = ['foo', 'bar']
            l += s          # NOT SUPPORTED for now if l is not a list of chars
            return ''.join(l)
        py.test.raises(TyperError, self.interpret, f, [58])

    def test_charlist_extension_2(self):
        def f(n, i):
            s = 'hello%d' % n
            assert 0 <= i <= len(s)
            l = ['a', 'b']
            l += s[i:]
            return ''.join(l)
        res = self.interpret(f, [9381701, 3])
        assert self.ll_to_string(res) == 'ablo9381701'

    def test_unicharlist_extension_2(self):
        def f(n, i):
            s = u'hello%d' % n
            assert 0 <= i <= len(s)
            l = [u'a', u'b']
            l += s[i:]
            return ''.join([chr(ord(c)) for c in l])
        res = self.interpret(f, [9381701, 3])
        assert self.ll_to_string(res) == 'ablo9381701'

    def test_extend_a_non_char_list_2(self):
        def f(n, i):
            s = 'hello%d' % n
            assert 0 <= i <= len(s)
            l = ['foo', 'bar']
            l += s[i:]      # NOT SUPPORTED for now if l is not a list of chars
            return ''.join(l)
        py.test.raises(TyperError, self.interpret, f, [9381701, 3])

    def test_charlist_extension_3(self):
        def f(n, i, j):
            s = 'hello%d' % n
            assert 0 <= i <= j <= len(s)
            l = ['a', 'b']
            l += s[i:j]
            return ''.join(l)
        res = self.interpret(f, [9381701, 3, 7])
        assert self.ll_to_string(res) == 'ablo93'

    def test_unicharlist_extension_3(self):
        def f(n, i, j):
            s = u'hello%d' % n
            assert 0 <= i <= j <= len(s)
            l = [u'a', u'b']
            l += s[i:j]
            return ''.join([chr(ord(c)) for c in l])
        res = self.interpret(f, [9381701, 3, 7])
        assert self.ll_to_string(res) == 'ablo93'

    def test_charlist_extension_4(self):
        def f(n):
            s = 'hello%d' % n
            l = ['a', 'b']
            l += s[:-1]
            return ''.join(l)
        res = self.interpret(f, [9381701])
        assert self.ll_to_string(res) == 'abhello938170'

    def test_unicharlist_extension_4(self):
        def f(n):
            s = u'hello%d' % n
            l = [u'a', u'b']
            l += s[:-1]
            return ''.join([chr(ord(c)) for c in l])
        res = self.interpret(f, [9381701])
        assert self.ll_to_string(res) == 'abhello938170'

    def test_charlist_extension_5(self):
        def f(count):
            l = ['a', 'b']
            l += '.' * count     # char * count
            return ''.join(l)
        res = self.interpret(f, [7])
        assert self.ll_to_string(res) == 'ab.......'
        res = self.interpret(f, [0])
        assert self.ll_to_string(res) == 'ab'

    def test_unicharlist_extension_5(self):
        def f(count):
            l = [u'a', u'b']
            l += u'.' * count
            return ''.join([chr(ord(c)) for c in l])
        res = self.interpret(f, [7])
        assert self.ll_to_string(res) == 'ab.......'
        res = self.interpret(f, [0])
        assert self.ll_to_string(res) == 'ab'

    def test_charlist_extension_6(self):
        def f(count):
            l = ['a', 'b']
            l += count * '.'     # count * char
            return ''.join(l)
        res = self.interpret(f, [7])
        assert self.ll_to_string(res) == 'ab.......'
        res = self.interpret(f, [0])
        assert self.ll_to_string(res) == 'ab'

    def test_extend_a_non_char_list_6(self):
        def f(count):
            l = ['foo', 'bar']
            # NOT SUPPORTED for now if l is not a list of chars
            l += count * '.'
            return ''.join(l)
        py.test.raises(TyperError, self.interpret, f, [5])

    def test_r_short_list(self):
        from rpython.rtyper.lltypesystem.rffi import r_short
        from rpython.rlib import rarithmetic
        def f(i):
            l = [r_short(0)] * 10
            l[i+1] = r_short(3)
            return rarithmetic.widen(l[i])
        res = self.interpret(f, [3])
        assert res == 0

    def test_make_new_list(self):
        class A:
            def _freeze_(self):
                return True
        a1 = A()
        a2 = A()
        def f(i):
            lst = [a1, a1]
            lst2 = list(lst)
            lst2.append(a2)
            return lst2[i] is a2
        res = self.interpret(f, [1])
        assert res == False
        res = self.interpret(f, [2])
        assert res == True

    def test_immutable_list_out_of_instance(self):
        for immutable_fields in (["a", "b"], ["a", "b", "y[*]"]):
            class A(object):
                _immutable_fields_ = immutable_fields
            class B(A):
                pass
            def f(i):
                b = B()
                lst = [i]
                lst[0] += 1
                b.y = lst
                ll_assert(b.y is lst, "copying when reading out the attr?")
                return b.y[0]
            res = self.interpret(f, [10])
            assert res == 11
            t, rtyper, graph = self.gengraph(f, [int])
            block = graph.startblock
            op = block.operations[-1]
            assert op.opname == 'direct_call'
            func = op.args[2].value
            assert ('foldable' in func.__name__) == \
                   ("y[*]" in immutable_fields)

    def test_hints(self):
        from rpython.rlib.objectmodel import newlist_hint

        strings = ['abc', 'def']
        def f(i):
            z = strings[i]
            x = newlist_hint(sizehint=13)
            x += z
            return ''.join(x)

        res = self.interpret(f, [0])
        assert self.ll_to_string(res) == 'abc'

    def test_memoryerror(self):
        def fn(i):
            lst = [0] * i
            lst[i-1] = 5
            return lst[0]
        res = self.interpret(fn, [1])
        assert res == 5
        res = self.interpret(fn, [2])
        assert res == 0
        self.interpret_raises(MemoryError, fn, [sys.maxint])

    def test_type_erase_fixed_size(self):
        class A(object):
            pass
        class B(object):
            pass

        def f():
            return [A()], [B()]

        t = TranslationContext()
        s = t.buildannotator().build_types(f, [])
        rtyper = t.buildrtyper()
        rtyper.specialize()

        s_A_list = s.items[0]
        s_B_list = s.items[1]

        r_A_list = rtyper.getrepr(s_A_list)
        assert isinstance(r_A_list, self.rlist.FixedSizeListRepr)
        r_B_list = rtyper.getrepr(s_B_list)
        assert isinstance(r_B_list, self.rlist.FixedSizeListRepr)

        assert r_A_list.lowleveltype == r_B_list.lowleveltype

    def test_type_erase_var_size(self):
        class A(object):
            pass
        class B(object):
            pass

        def f():
            la = [A()]
            lb = [B()]
            la.append(None)
            lb.append(None)
            return la, lb

        t = TranslationContext()
        s = t.buildannotator().build_types(f, [])
        rtyper = t.buildrtyper()
        rtyper.specialize()

        s_A_list = s.items[0]
        s_B_list = s.items[1]

        r_A_list = rtyper.getrepr(s_A_list)
        assert isinstance(r_A_list, self.rlist.ListRepr)
        r_B_list = rtyper.getrepr(s_B_list)
        assert isinstance(r_B_list, self.rlist.ListRepr)

        assert r_A_list.lowleveltype == r_B_list.lowleveltype

    def test_no_unneeded_refs(self):
        def fndel(p, q):
            lis = ["5", "3", "99"]
            assert q >= 0
            assert p >= 0
            del lis[p:q]
            return lis
        def fnpop(n):
            lis = ["5", "3", "99"]
            while n:
                lis.pop()
                n -=1
            return lis
        for i in range(2, 3+1):
            lis = self.interpret(fndel, [0, i])
            assert list_is_clear(lis, 3-i)
        for i in range(3):
            lis = self.interpret(fnpop, [i])
            assert list_is_clear(lis, 3-i)

    def test_oopspec(self):
        lst1 = [123, 456]     # non-mutated list
        def f(i):
            lst2 = [i]
            lst2.append(42)    # mutated list
            return lst1[i] + lst2[i]
        from rpython.annotator import model as annmodel
        _, _, graph = self.gengraph(f, [annmodel.SomeInteger(nonneg=True)])
        block = graph.startblock
        lst1_getitem_op = block.operations[-3]     # XXX graph fishing
        lst2_getitem_op = block.operations[-2]
        func1 = lst1_getitem_op.args[2].value
        func2 = lst2_getitem_op.args[2].value
        assert func1.oopspec == 'list.getitem_foldable(l, index)'
        assert not hasattr(func2, 'oopspec')

    def test_iterate_over_immutable_list(self):
        from rpython.rtyper import rlist
        class MyException(Exception):
            pass
        lst = list('abcdef')
        def dummyfn():
            total = 0
            for c in lst:
                total += ord(c)
            return total
        #
        prev = rlist.ll_getitem_foldable_nonneg
        try:
            def seen_ok(l, index):
                if index == 5:
                    raise KeyError     # expected case
                return prev(l, index)
            rlist.ll_getitem_foldable_nonneg = seen_ok
            e = py.test.raises(LLException, self.interpret, dummyfn, [])
            assert 'KeyError' in str(e.value)
        finally:
            rlist.ll_getitem_foldable_nonneg = prev

    def test_iterate_over_immutable_list_quasiimmut_attr(self):
        from rpython.rtyper import rlist
        class MyException(Exception):
            pass
        class Foo:
            _immutable_fields_ = ['lst?[*]']
            lst = list('abcdef')
        foo = Foo()
        def dummyfn():
            total = 0
            for c in foo.lst:
                total += ord(c)
            return total
        #
        prev = rlist.ll_getitem_foldable_nonneg
        try:
            def seen_ok(l, index):
                if index == 5:
                    raise KeyError     # expected case
                return prev(l, index)
            rlist.ll_getitem_foldable_nonneg = seen_ok
            e = py.test.raises(LLException, self.interpret, dummyfn, [])
            assert 'KeyError' in str(e.value)
        finally:
            rlist.ll_getitem_foldable_nonneg = prev

    def test_iterate_over_mutable_list(self):
        from rpython.rtyper import rlist
        class MyException(Exception):
            pass
        lst = list('abcdef')
        def dummyfn():
            total = 0
            for c in lst:
                total += ord(c)
            lst[0] = 'x'
            return total
        #
        prev = rlist.ll_getitem_foldable_nonneg
        try:
            def seen_ok(l, index):
                if index == 5:
                    raise KeyError     # expected case
                return prev(l, index)
            rlist.ll_getitem_foldable_nonneg = seen_ok
            res = self.interpret(dummyfn, [])
            assert res == sum(map(ord, 'abcdef'))
        finally:
            rlist.ll_getitem_foldable_nonneg = prev

    def test_extend_was_not_overallocating(self):
        from rpython.rlib import rgc
        from rpython.rlib.objectmodel import resizelist_hint
        from rpython.rtyper.lltypesystem import lltype
        old_arraycopy = rgc.ll_arraycopy
        try:
            GLOB = lltype.GcStruct('GLOB', ('seen', lltype.Signed))
            glob = lltype.malloc(GLOB, immortal=True)
            glob.seen = 0
            def my_arraycopy(*args):
                glob.seen += 1
                return old_arraycopy(*args)
            rgc.ll_arraycopy = my_arraycopy
            def dummyfn():
                lst = []
                i = 0
                while i < 30:
                    i += 1
                    resizelist_hint(lst, i)
                    lst.append(i)
                return glob.seen
            res = self.interpret(dummyfn, [])
        finally:
            rgc.ll_arraycopy = old_arraycopy
        #
        assert 2 <= res <= 10

    def test_alloc_and_set(self):
        def fn(i):
            lst = [0] * r_uint(i)
            return lst
        t, rtyper, graph = self.gengraph(fn, [int])
        block = graph.startblock
        seen = 0
        for op in block.operations:
            if op.opname in ['cast_int_to_uint', 'cast_uint_to_int']:
                continue
            assert op.opname == 'direct_call'
            seen += 1
        assert seen == 1
