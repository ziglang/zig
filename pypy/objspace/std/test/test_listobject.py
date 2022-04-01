# coding: iso-8859-15
import py
import random
from pypy.objspace.std.listobject import W_ListObject, SizeListStrategy,\
     IntegerListStrategy, BytesListStrategy, FloatListStrategy, \
     ObjectListStrategy, IntOrFloatListStrategy, AsciiListStrategy
from pypy.interpreter.error import OperationError
from rpython.rlib.rarithmetic import is_valid_int


class TestW_ListObject(object):
    def test_is_true(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [])
        assert self.space.is_true(w_list) == False
        w_list = W_ListObject(self.space, [w(5)])
        assert self.space.is_true(w_list) == True
        w_list = W_ListObject(self.space, [w(5), w(3)])
        assert self.space.is_true(w_list) == True

    def test_len(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [])
        assert self.space.eq_w(self.space.len(w_list), w(0))
        w_list = W_ListObject(self.space, [w(5)])
        assert self.space.eq_w(self.space.len(w_list), w(1))
        w_list = W_ListObject(self.space, [w(5), w(3), w(99)]*111)
        assert self.space.eq_w(self.space.len(w_list), w(333))
        w_list = W_ListObject(self.space, [w(u'\u2039')])
        assert self.space.eq_w(self.space.len(w_list), w(1))

    def test_getitem(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [w(5), w(3)])
        assert self.space.eq_w(self.space.getitem(w_list, w(0)), w(5))
        assert self.space.eq_w(self.space.getitem(w_list, w(1)), w(3))
        assert self.space.eq_w(self.space.getitem(w_list, w(-2)), w(5))
        assert self.space.eq_w(self.space.getitem(w_list, w(-1)), w(3))
        self.space.raises_w(self.space.w_IndexError,
                            self.space.getitem, w_list, w(2))
        self.space.raises_w(self.space.w_IndexError,
                            self.space.getitem, w_list, w(42))
        self.space.raises_w(self.space.w_IndexError,
                            self.space.getitem, w_list, w(-3))

    def test_getitems(self):
        w = self.space.wrap
        from pypy.objspace.std.listobject import make_range_list
        r = make_range_list(self.space, 1,1,7)
        l = [w(1),w(2),w(3),w(4),w(5),w(6),w(7)]
        l2 = r.getitems()
        for i in range(7):
            assert self.space.eq_w(l[i], l2[i])

    def test_getitems_fixedsize(self):
        w = self.space.wrap
        from pypy.objspace.std.listobject import make_range_list
        rangelist = make_range_list(self.space, 1,1,7)
        emptylist = W_ListObject(self.space, [])
        intlist = W_ListObject(self.space, [w(1),w(2),w(3),w(4),w(5),w(6),w(7)])
        strlist = W_ListObject(self.space, [w('1'),w('2'),w('3'),w('4'),w('5'),w('6'),w('7')])
        floatlist = W_ListObject(self.space, [w(1.0),w(2.0),w(3.0),w(4.0),w(5.0),w(6.0),w(7.0)])
        objlist = W_ListObject(self.space, [w(1),w('2'),w(3.0),w(4),w(5),w(6),w(7)])

        emptylist_copy = emptylist.getitems_fixedsize()
        assert emptylist_copy == []

        rangelist_copy = rangelist.getitems_fixedsize()
        intlist_copy = intlist.getitems_fixedsize()
        strlist_copy = strlist.getitems_fixedsize()
        floatlist_copy = floatlist.getitems_fixedsize()
        objlist_copy = objlist.getitems_fixedsize()
        for i in range(7):
            assert self.space.eq_w(rangelist_copy[i], rangelist.getitem(i))
            assert self.space.eq_w(intlist_copy[i], intlist.getitem(i))
            assert self.space.eq_w(strlist_copy[i], strlist.getitem(i))
            assert self.space.eq_w(floatlist_copy[i], floatlist.getitem(i))
            assert self.space.eq_w(objlist_copy[i], objlist.getitem(i))

        emptylist_copy = emptylist.getitems_unroll()
        assert emptylist_copy == []

        rangelist_copy = rangelist.getitems_unroll()
        intlist_copy = intlist.getitems_unroll()
        strlist_copy = strlist.getitems_unroll()
        floatlist_copy = floatlist.getitems_unroll()
        objlist_copy = objlist.getitems_unroll()
        for i in range(7):
            assert self.space.eq_w(rangelist_copy[i], rangelist.getitem(i))
            assert self.space.eq_w(intlist_copy[i], intlist.getitem(i))
            assert self.space.eq_w(strlist_copy[i], strlist.getitem(i))
            assert self.space.eq_w(floatlist_copy[i], floatlist.getitem(i))
            assert self.space.eq_w(objlist_copy[i], objlist.getitem(i))

    def test_random_getitem(self):
        w = self.space.wrap
        s = list('qedx387tn3uixhvt 7fh387fymh3dh238 dwd-wq.dwq9')
        w_list = W_ListObject(self.space, map(w, s))
        keys = range(-len(s)-5, len(s)+5)
        choices = keys + [None]*12
        stepchoices = [None, None, None, 1, 1, -1, -1, 2, -2,
                       len(s)-1, len(s), len(s)+1,
                       -len(s)-1, -len(s), -len(s)+1]
        for i in range(40):
            keys.append(slice(random.choice(choices),
                              random.choice(choices),
                              random.choice(stepchoices)))
        random.shuffle(keys)
        for key in keys:
            try:
                expected = s[key]
            except IndexError:
                self.space.raises_w(self.space.w_IndexError,
                                    self.space.getitem, w_list, w(key))
            else:
                w_result = self.space.getitem(w_list, w(key))
                assert self.space.unwrap(w_result) == expected

    def test_iter(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_iter = self.space.iter(w_list)
        assert self.space.eq_w(self.space.next(w_iter), w(5))
        assert self.space.eq_w(self.space.next(w_iter), w(3))
        assert self.space.eq_w(self.space.next(w_iter), w(99))
        py.test.raises(OperationError, self.space.next, w_iter)
        py.test.raises(OperationError, self.space.next, w_iter)

    def test_contains(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [w(5), w(3), w(99)])
        assert self.space.eq_w(self.space.contains(w_list, w(5)),
                           self.space.w_True)
        assert self.space.eq_w(self.space.contains(w_list, w(99)),
                           self.space.w_True)
        assert self.space.eq_w(self.space.contains(w_list, w(11)),
                           self.space.w_False)
        assert self.space.eq_w(self.space.contains(w_list, w_list),
                           self.space.w_False)

    def test_getslice(self):
        w = self.space.wrap

        def test1(testlist, start, stop, step, expected):
            w_slice  = self.space.newslice(w(start), w(stop), w(step))
            w_list = W_ListObject(self.space, [w(i) for i in testlist])
            w_result = self.space.getitem(w_list, w_slice)
            assert self.space.unwrap(w_result) == expected

        for testlist in [[], [5,3,99]]:
            for start in [-2, 0, 1, 10]:
                for end in [-1, 2, 999]:
                    test1(testlist, start, end, 1, testlist[start:end])

        test1([5,7,1,4], 3, 1, -2,  [4,])
        test1([5,7,1,4], 3, 0, -2,  [4, 7])
        test1([5,7,1,4], 3, -1, -2, [])
        test1([5,7,1,4], -2, 11, 2, [1,])
        test1([5,7,1,4], -3, 11, 2, [7, 4])
        test1([5,7,1,4], -5, 11, 2, [5, 1])

    def test_setslice(self):
        w = self.space.wrap

        def test1(lhslist, start, stop, rhslist, expected):
            w_slice  = self.space.newslice(w(start), w(stop), w(1))
            w_lhslist = W_ListObject(self.space, [w(i) for i in lhslist])
            w_rhslist = W_ListObject(self.space, [w(i) for i in rhslist])
            self.space.setitem(w_lhslist, w_slice, w_rhslist)
            assert self.space.unwrap(w_lhslist) == expected

        test1([5,7,1,4], 1, 3, [9,8],  [5,9,8,4])
        test1([5,7,1,4], 1, 3, [9],    [5,9,4])
        test1([5,7,1,4], 1, 3, [9,8,6],[5,9,8,6,4])
        test1([5,7,1,4], 1, 3, [],     [5,4])
        test1([5,7,1,4], 2, 2, [9],    [5,7,9,1,4])
        test1([5,7,1,4], 0, 99,[9,8],  [9,8])

    def test_add(self):
        w = self.space.wrap
        w_list0 = W_ListObject(self.space, [])
        w_list1 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list2 = W_ListObject(self.space, [w(-7)] * 111)
        assert self.space.eq_w(self.space.add(w_list1, w_list1),
                           W_ListObject(self.space, [w(5), w(3), w(99),
                                               w(5), w(3), w(99)]))
        assert self.space.eq_w(self.space.add(w_list1, w_list2),
                           W_ListObject(self.space, [w(5), w(3), w(99)] +
                                              [w(-7)] * 111))
        assert self.space.eq_w(self.space.add(w_list1, w_list0), w_list1)
        assert self.space.eq_w(self.space.add(w_list0, w_list2), w_list2)

    def test_mul(self):
        # only testing right mul at the moment
        w = self.space.wrap
        arg = w(2)
        n = 3
        w_lis = W_ListObject(self.space, [arg])
        w_lis3 = W_ListObject(self.space, [arg]*n)
        w_res = self.space.mul(w_lis, w(n))
        assert self.space.eq_w(w_lis3, w_res)
        # commute
        w_res = self.space.mul(w(n), w_lis)
        assert self.space.eq_w(w_lis3, w_res)

    def test_mul_does_not_clone(self):
        # only testing right mul at the moment
        w = self.space.wrap
        arg = w(2)
        w_lis = W_ListObject(self.space, [arg])
        w_lis.clone = None
        # does not crash
        self.space.mul(w_lis, w(5))

    def test_setitem(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [w(5), w(3)])
        w_exp1 = W_ListObject(self.space, [w(5), w(7)])
        w_exp2 = W_ListObject(self.space, [w(8), w(7)])
        self.space.setitem(w_list, w(1), w(7))
        assert self.space.eq_w(w_exp1, w_list)
        self.space.setitem(w_list, w(-2), w(8))
        assert self.space.eq_w(w_exp2, w_list)
        self.space.raises_w(self.space.w_IndexError,
                            self.space.setitem, w_list, w(2), w(5))
        self.space.raises_w(self.space.w_IndexError,
                            self.space.setitem, w_list, w(-3), w(5))

    def test_random_setitem_delitem(self):
        w = self.space.wrap
        s = range(39)
        w_list = W_ListObject(self.space, map(w, s))
        expected = list(s)
        keys = range(-len(s)-5, len(s)+5)
        choices = keys + [None]*12
        stepchoices = [None, None, None, 1, 1, -1, -1, 2, -2,
                       len(s)-1, len(s), len(s)+1,
                       -len(s)-1, -len(s), -len(s)+1]
        for i in range(50):
            keys.append(slice(random.choice(choices),
                              random.choice(choices),
                              random.choice(stepchoices)))
        random.shuffle(keys)
        n = len(s)
        for key in keys:
            if random.random() < 0.15:
                random.shuffle(s)
                w_list = W_ListObject(self.space, map(w, s))
                expected = list(s)
            try:
                value = expected[key]
            except IndexError:
                self.space.raises_w(self.space.w_IndexError,
                                    self.space.setitem, w_list, w(key), w(42))
            else:
                if is_valid_int(value):   # non-slicing
                    if random.random() < 0.25:   # deleting
                        self.space.delitem(w_list, w(key))
                        del expected[key]
                    else:
                        self.space.setitem(w_list, w(key), w(n))
                        expected[key] = n
                        n += 1
                else:        # slice assignment
                    mode = random.choice(['samesize', 'resize', 'delete'])
                    if mode == 'delete':
                        self.space.delitem(w_list, w(key))
                        del expected[key]
                    elif mode == 'samesize':
                        newvalue = range(n, n+len(value))
                        self.space.setitem(w_list, w(key), w(newvalue))
                        expected[key] = newvalue
                        n += len(newvalue)
                    elif mode == 'resize' and key.step is None:
                        newvalue = range(n, n+random.randrange(0, 20))
                        self.space.setitem(w_list, w(key), w(newvalue))
                        expected[key] = newvalue
                        n += len(newvalue)
            assert self.space.unwrap(w_list) == expected

    def test_eq(self):
        w = self.space.wrap

        w_list0 = W_ListObject(self.space, [])
        w_list1 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list2 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list3 = W_ListObject(self.space, [w(5), w(3), w(99), w(-1)])

        assert self.space.eq_w(self.space.eq(w_list0, w_list1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.eq(w_list1, w_list0),
                           self.space.w_False)
        assert self.space.eq_w(self.space.eq(w_list1, w_list1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.eq(w_list1, w_list2),
                           self.space.w_True)
        assert self.space.eq_w(self.space.eq(w_list2, w_list3),
                           self.space.w_False)

    def test_ne(self):
        w = self.space.wrap

        w_list0 = W_ListObject(self.space, [])
        w_list1 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list2 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list3 = W_ListObject(self.space, [w(5), w(3), w(99), w(-1)])

        assert self.space.eq_w(self.space.ne(w_list0, w_list1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ne(w_list1, w_list0),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ne(w_list1, w_list1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ne(w_list1, w_list2),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ne(w_list2, w_list3),
                           self.space.w_True)

    def test_lt(self):
        w = self.space.wrap

        w_list0 = W_ListObject(self.space, [])
        w_list1 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list2 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list3 = W_ListObject(self.space, [w(5), w(3), w(99), w(-1)])
        w_list4 = W_ListObject(self.space, [w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.lt(w_list0, w_list1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.lt(w_list1, w_list0),
                           self.space.w_False)
        assert self.space.eq_w(self.space.lt(w_list1, w_list1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.lt(w_list1, w_list2),
                           self.space.w_False)
        assert self.space.eq_w(self.space.lt(w_list2, w_list3),
                           self.space.w_True)
        assert self.space.eq_w(self.space.lt(w_list4, w_list3),
                           self.space.w_True)

    def test_ge(self):
        w = self.space.wrap

        w_list0 = W_ListObject(self.space, [])
        w_list1 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list2 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list3 = W_ListObject(self.space, [w(5), w(3), w(99), w(-1)])
        w_list4 = W_ListObject(self.space, [w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.ge(w_list0, w_list1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ge(w_list1, w_list0),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ge(w_list1, w_list1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ge(w_list1, w_list2),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ge(w_list2, w_list3),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ge(w_list4, w_list3),
                           self.space.w_False)

    def test_gt(self):
        w = self.space.wrap

        w_list0 = W_ListObject(self.space, [])
        w_list1 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list2 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list3 = W_ListObject(self.space, [w(5), w(3), w(99), w(-1)])
        w_list4 = W_ListObject(self.space, [w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.gt(w_list0, w_list1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_list1, w_list0),
                           self.space.w_True)
        assert self.space.eq_w(self.space.gt(w_list1, w_list1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_list1, w_list2),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_list2, w_list3),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_list4, w_list3),
                           self.space.w_False)

    def test_le(self):
        w = self.space.wrap

        w_list0 = W_ListObject(self.space, [])
        w_list1 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list2 = W_ListObject(self.space, [w(5), w(3), w(99)])
        w_list3 = W_ListObject(self.space, [w(5), w(3), w(99), w(-1)])
        w_list4 = W_ListObject(self.space, [w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.le(w_list0, w_list1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_list1, w_list0),
                           self.space.w_False)
        assert self.space.eq_w(self.space.le(w_list1, w_list1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_list1, w_list2),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_list2, w_list3),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_list4, w_list3),
                           self.space.w_True)

    def test_sizehint(self):
        space = self.space
        w_l = space.newlist([], sizehint=10)
        assert isinstance(w_l.strategy, SizeListStrategy)
        space.call_method(w_l, 'append', space.wrap(3))
        assert isinstance(w_l.strategy, IntegerListStrategy)
        w_l = space.newlist([], sizehint=10)
        space.call_method(w_l, 'append', space.w_None)
        assert isinstance(w_l.strategy, ObjectListStrategy)

    def test_newlist_hint(self):
        space = self.space
        w_lst = space.newlist_hint(13)
        assert isinstance(w_lst.strategy, SizeListStrategy)
        assert w_lst.strategy.sizehint == 13

    def test_find_fast_on_intlist(self, monkeypatch):
        monkeypatch.setattr(self.space, "eq_w", None)
        w = self.space.wrap
        intlist = W_ListObject(self.space, [w(1),w(2),w(3),w(4),w(5),w(6),w(7)])
        res = intlist.find(w(4), 0, 7)
        assert res == 3
        res = intlist.find(w(4), 0, 100)
        assert res == 3
        with py.test.raises(ValueError):
            intlist.find(w(4), 4, 7)
        with py.test.raises(ValueError):
            intlist.find(w(4), 0, 2)

    def test_intlist_to_object_too_much_wrapping(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [w(1000000)] * 100)
        assert isinstance(w_list.strategy, IntegerListStrategy)
        w_list.setitem(0, w(1))
        w_list.setitem(0, self.space.w_None)
        assert isinstance(w_list.strategy, ObjectListStrategy)
        l = w_list.getitems()
        assert len(set(l)) == 2

    def test_floatlist_to_object_too_much_wrapping(self):
        w = self.space.wrap
        for value in [11233.12, float('NaN')]:
            w_list = W_ListObject(self.space, [w(value)] * 100)
            assert isinstance(w_list.strategy, FloatListStrategy)
            w_list.setitem(0, self.space.w_None)
            assert isinstance(w_list.strategy, ObjectListStrategy)
            l = w_list.getitems()
            for element in l[2:]:
                assert element is l[1]

    def test_intorfloatlist_to_object_too_much_wrapping(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [w(0)] * 100)
        w_list.setitem(0, w(1.1))
        assert isinstance(w_list.strategy, IntOrFloatListStrategy)
        w_list.setitem(0, self.space.w_None)
        assert isinstance(w_list.strategy, ObjectListStrategy)
        l = w_list.getitems()
        assert len(set(l)) == 2

    def test_byteslist_to_object_too_much_wrapping(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [self.space.newbytes(b"abc")] * 100)
        assert isinstance(w_list.strategy, BytesListStrategy)
        w_list.setitem(0, self.space.w_None)
        assert isinstance(w_list.strategy, ObjectListStrategy)
        l = w_list.getitems()
        for element in l[2:]:
            assert element is l[1]

    def test_asciilist_to_object_too_much_wrapping(self):
        w = self.space.wrap
        w_list = W_ListObject(self.space, [self.space.newutf8(b"abc", 3)] * 100)
        assert isinstance(w_list.strategy, AsciiListStrategy)
        w_list.setitem(0, self.space.w_None)
        assert isinstance(w_list.strategy, ObjectListStrategy)
        l = w_list.getitems()
        for element in l[2:]:
            assert element is l[1]

    def test_tuple_extend_shortcut(self, space, monkeypatch):
        from pypy.objspace.std import listobject
        w = self.space.wrap
        w_list = W_ListObject(space, [w(5)])
        w_tup = space.newtuple([w(6), w(7)])
        monkeypatch.setattr(listobject, "_do_extend_from_iterable", None)
        space.call_method(w_list, "extend", w_tup) # does not crash because of the shortcut
        assert space.unwrap(w_list) == [5, 6, 7]


class AppTestListObject(object):
    #spaceconfig = {"objspace.std.withliststrategies": True}  # it's the default

    def setup_class(cls):
        import platform
        import sys
        on_cpython = (cls.runappdirect and
                      not hasattr(sys, 'pypy_translation_info'))
        cls.w_on_cpython = cls.space.wrap(on_cpython)
        cls.w_on_arm = cls.space.wrap(platform.machine().startswith('arm'))
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)

    def test_doc(self):
        assert list.__doc__ == "list() -> new empty list\nlist(iterable) -> new list initialized from iterable's items"
        assert list.__new__.__doc__ == "Create and return a new object.  See help(type) for accurate signature."
        assert list.__init__.__doc__ == "Initialize self.  See help(type(self)) for accurate signature."

    def test_getstrategyfromlist_w(self):
        l0 = ["a", "2", "a", True]
        # this raised TypeError on ListStrategies
        l1 = ["a", "2", True, "a"]
        l2 = [1, "2", "a", "a"]
        assert set(l1) == set(l2)

    def test_notequals(self):
        assert [1,2,3,4] != [1,2,5,4]

    def test_contains(self):
        l = []
        assert not l.__contains__(2)

        l = [1,2,3]
        assert l.__contains__(2)
        assert not l.__contains__("2")
        assert l.__contains__(1.0)

        l = ["1","2","3"]
        assert l.__contains__("2")
        assert not l.__contains__(2)

        l = range(4)
        assert l.__contains__(2)
        assert not l.__contains__("2")

        l = [1,2,"3"]
        assert l.__contains__(2)
        assert not l.__contains__("2")

        l = range(2, 20, 3) # = [2, 5, 8, 11, 14, 17]
        assert l.__contains__(2)
        assert l.__contains__(5)
        assert l.__contains__(8)
        assert l.__contains__(11)
        assert l.__contains__(14)
        assert l.__contains__(17)
        assert not l.__contains__(3)
        assert not l.__contains__(4)
        assert not l.__contains__(7)
        assert not l.__contains__(13)
        assert not l.__contains__(20)

        l = range(2, -20, -3) # [2, -1, -4, -7, -10, -13, -16, -19]
        assert l.__contains__(2)
        assert l.__contains__(-4)
        assert l.__contains__(-13)
        assert l.__contains__(-16)
        assert l.__contains__(-19)
        assert not l.__contains__(-17)
        assert not l.__contains__(-3)
        assert not l.__contains__(-20)
        assert not l.__contains__(-21)

        logger = []

        class Foo(object):

            def __init__(self, value, name=None):
                self.value = value
                self.name = name or value

            def __repr__(self):
                return '<Foo %s>' % self.name

            def __eq__(self, other):
                logger.append((self, other))
                return self.value == other.value

        foo1, foo2, foo3 = Foo(1), Foo(2), Foo(3)
        foo42 = Foo(42)
        foo_list = [foo1, foo2, foo3]
        foo42 in foo_list
        logger_copy = logger[:]  # prevent re-evaluation during pytest error print
        assert logger_copy == [(foo1, foo42), (foo2, foo42), (foo3, foo42)]

        del logger[:]
        foo2_bis = Foo(2, '2 bis')
        foo2_bis in foo_list
        logger_copy = logger[:]  # prevent re-evaluation during pytest error print
        assert logger_copy == [(foo1, foo2_bis), (foo2, foo2_bis)]

    def test_call_list(self):
        assert list('') == []
        assert list('abc') == ['a', 'b', 'c']
        assert list((1, 2)) == [1, 2]
        l = [1]
        assert list(l) is not l
        assert list(l) == l

    def test_explicit_new_init(self):
        l = l0 = list.__new__(list)
        l.__init__([1,2])
        assert l is l0
        assert l == [1,2]
        list.__init__(l, [1,2,3])
        assert l is l0
        assert l == [1,2,3]
        list.__init__(l, ['a', 'b', 'c'])
        assert l is l0
        assert l == ['a', 'b', 'c']
        list.__init__(l)
        assert l == []

    def test_explicit_new_init_more_cases(self):
        for assignment in [[], (), [3], ["foo"]]:
            l = [1, 2]
            l.__init__(assignment)
            assert l == list(assignment)

    def test_range_init(self):
        x = list(range(5,1))
        assert x == []

        x = list(range(1,10))
        x[22:0:-1] == range(1,10)

        r = list(range(10, 10))
        assert len(r) == 0
        assert list(reversed(r)) == []
        assert r[:] == []

    def test_extend_list(self):
        l = l0 = [1]
        l.extend([2])
        assert l is l0
        assert l == [1,2]
        l = ['a']
        l.extend('b')
        assert l == ['a', 'b']
        l = ['a']
        l.extend([0])
        assert l == ['a', 0]
        l = list(range(10))
        l.extend([10])
        assert l == list(range(11))

        l = []
        m = [1,2,3]
        l.extend(m)
        m[0] = 5
        assert m == [5,2,3]
        assert l == [1,2,3]

    def test_extend_tuple(self):
        l = l0 = [1]
        l.extend((2,))
        assert l is l0
        assert l == [1,2]
        l = ['a']
        l.extend(('b',))
        assert l == ['a', 'b']

    def test_extend_iterable(self):
        l = l0 = [1]
        l.extend(iter([1, 2, 3, 4]))
        assert l is l0
        assert l == [1, 1, 2, 3, 4]

        l = l0 = ['a']
        l.extend(iter(['b', 'c', 'd']))
        assert l == ['a', 'b', 'c', 'd']
        assert l is l0

        l = l0 = [1.2]
        l.extend(iter([2.3, 3.4, 4.5]))
        assert l == [1.2, 2.3, 3.4, 4.5]
        assert l is l0

    def test_extend_iterable_length_hint_overflow(self):
        import sys
        class CustomIterable(object):
            def __iter__(self):
                if False:
                    yield
            def __length_hint__(self):
                return sys.maxsize
        a = [1, 2, 3, 4]
        a.extend(CustomIterable())
        assert a == [1, 2, 3, 4]

    def test_sort(self):
        l = l0 = [1, 5, 3, 0]
        l.sort()
        assert l is l0
        assert l == [0, 1, 3, 5]
        l = l0 = []
        l.sort()
        assert l is l0
        assert l == []
        l = l0 = [1]
        l.sort()
        assert l is l0
        assert l == [1]

        l = ["c", "a", "d", "b"]
        l.sort(reverse=True)
        assert l == ["d", "c", "b", "a"]

        l = [3.3, 2.2, 4.4, 1.1, 3.1, 5.5]
        l.sort()
        assert l == [1.1, 2.2, 3.1, 3.3, 4.4, 5.5]

    def test_sort_key(self):
        def lower(x): return x.lower()
        l = ['a', 'C', 'b']
        l.sort(key=lower)
        assert l == ['a', 'b', 'C']
        l = []
        l.sort(key=lower)
        assert l == []
        l = ['a']
        l.sort(key=lower)
        assert l == ['a']

        r = list(range(10))
        r.sort(key=lambda x: -x)
        assert r == list(range(9, -1, -1))

    def test_sort_reversed(self):
        l = list(range(10))
        l.sort(reverse=True)
        assert l == list(range(9, -1, -1))
        l = []
        l.sort(reverse=True)
        assert l == []
        l = [1]
        l.sort(reverse=True)
        assert l == [1]
        raises(TypeError, sorted, [], None, lambda x, y: 0)

    def test_sort_cmp_key_reverse(self):
        def lower(x): return x.lower()
        l = ['a', 'C', 'b']
        l.sort(reverse = True, key = lower)
        assert l == ['C', 'b', 'a']

    def test_sort_simple_string(self):
        l = ["a", "d", "c", "b"]
        l.sort()
        assert l == ["a", "b", "c", "d"]

    def test_sort_range(self):
        l = list(range(3, 10, 3))
        l.sort()
        assert l == [3, 6, 9]
        l.sort(reverse=True)
        assert l == [9, 6, 3]
        l.sort(reverse=True)
        assert l == [9, 6, 3]
        l.sort()
        assert l == [3, 6, 9]

    def test_getitem(self):
        l = [1, 2, 3, 4, 5, 6, 9]
        assert l[0] == 1
        assert l[-1] == 9
        assert l[-2] == 6
        raises(IndexError, "l[len(l)]")
        raises(IndexError, "l[-len(l)-1]")

        l = ['a', 'b', 'c']
        assert l[0] == 'a'
        assert l[-1] == 'c'
        assert l[-2] == 'b'
        raises(IndexError, "l[len(l)]")

        l = [1.1, 2.2, 3.3]
        assert l[0] == 1.1
        assert l[-1] == 3.3
        assert l[-2] == 2.2
        raises(IndexError, "l[len(l)]")

        l = []
        raises(IndexError, "l[1]")

    def test_getitem_range(self):
        l = range(5)
        raises(IndexError, "l[-6]")
        raises(IndexError, "l[5]")
        assert l[0] == 0
        assert l[-1] == 4
        assert l[-2] == 3
        assert l[-5] == 0

        l = range(1, 5)
        raises(IndexError, "l[-5]")
        raises(IndexError, "l[4]")
        assert l[0] == 1
        assert l[-1] == 4
        assert l[-2] == 3
        assert l[-4] == 1

    def test_setitem(self):
        l = []
        raises(IndexError, "l[1] = 2")

        l = [5,3]
        l[0] = 2
        assert l == [2,3]

        l = [5,3]
        l[0] = "2"
        assert l == ["2",3]

        l = list(range(3))
        l[0] = 1
        assert l == [1,1,2]

    def test_delitem(self):
        l = [1, 2, 3, 4, 5, 6, 9]
        del l[0]
        assert l == [2, 3, 4, 5, 6, 9]
        del l[-1]
        assert l == [2, 3, 4, 5, 6]
        del l[-2]
        assert l == [2, 3, 4, 6]
        raises(IndexError, "del l[len(l)]")
        raises(IndexError, "del l[-len(l)-1]")

        l = l0 = ['a', 'b', 'c']
        del l[0]
        assert l == ['b', 'c']
        del l[-1]
        assert l == ['b']
        del l[-1]
        assert l == []
        assert l is l0
        raises(IndexError, "del l[0]")

        l = l0 = [1.1, 2.2, 3.3]
        del l[0]
        assert l == [2.2, 3.3]
        del l[-1]
        assert l == [2.2]
        del l[-1]
        assert l == []
        assert l is l0
        raises(IndexError, "del l[0]")

        l = list(range(10))
        del l[5]
        assert l == [0, 1, 2, 3, 4, 6, 7, 8, 9]

    def test_getitem_slice(self):
        l = list(range(10))
        assert l[::] == l
        del l[::2]
        assert l == [1,3,5,7,9]
        l[-2::-1] = l[:-1]
        assert l == [7,5,3,1,9]
        del l[-1:2:-1]
        assert l == [7,5,3]
        del l[:2]
        assert l == [3]
        assert l[1:] == []
        assert l[1::2] == []
        assert l[::] == l
        assert l[0::-2] == l
        assert l[-1::-5] == l

        l = ['']
        assert l[1:] == []
        assert l[1::2] == []
        assert l[::] == l
        assert l[0::-5] == l
        assert l[-1::-5] == l
        l.extend(['a', 'b'])
        assert l[::-1] == ['b', 'a', '']

        l = [1,2,3,4,5]
        assert l[1:0:None] == []
        assert l[1:0] == []

    def test_getslice_invalid(self):
        x = [1,2,3,4]
        assert x[10:0] == []
        assert x[10:0:None] == []

        x = list(range(1,5))
        assert x[10:0] == []
        assert x[10:0:None] == []

        assert x[0:22] == [1,2,3,4]
        assert x[-1:10] == [4]

        assert x[0:22:None] == [1,2,3,4]
        assert x[-1:10:None] == [4]

    def test_getslice_range_backwards(self):
        x = list(range(1,10))
        assert x[22:-10] == []
        assert x[22:-10:-1] == [9,8,7,6,5,4,3,2,1]
        assert x[10:3:-1] == [9,8,7,6,5]
        assert x[10:3:-2] == [9,7,5]
        assert x[1:5:-1] == []

    def test_delall(self):
        l = l0 = [1,2,3]
        del l[:]
        assert l is l0
        assert l == []

        l = ['a', 'b']
        del l[:]
        assert l == []

        l = [1.1, 2.2]
        del l[:]
        assert l == []

    def test_clear(self):
        l = l0 = [1,2,3]
        l.clear()
        assert l is l0
        assert l == []

        l = ['a', 'b']
        l.clear()
        assert l == []

        l = [1.1, 2.2]
        l.clear()
        assert l == []

        l = []
        l.clear()
        assert l == []

    def test_iadd(self):
        l = l0 = [1,2,3]
        l += [4,5]
        assert l is l0
        assert l == [1,2,3,4,5]

        l = l0 = [1.1,2.2,3.3]
        l += [4.4,5.5]
        assert l is l0
        assert l == [1.1,2.2,3.3,4.4,5.5]

        l = l0 = ['a', 'b', 'c']
        l1 = l[:]
        l += ['d']
        assert l is l0
        assert l == ['a', 'b', 'c', 'd']
        l1 += [0]
        assert l1 == ['a', 'b', 'c', 0]

        r1 = r2 = list(range(5))
        assert r1 is r2
        r1 += [15]
        assert r1 is r2
        assert r1 == [0, 1, 2, 3, 4, 15]
        assert r2 == [0, 1, 2, 3, 4, 15]

    def test_iadd_iterable(self):
        l = l0 = [1,2,3]
        l += iter([4,5])
        assert l is l0
        assert l == [1,2,3,4,5]

    def test_iadd_subclass(self):
        class Bar(object):
            def __radd__(self, other):
                return ('radd', self, other)
        bar = Bar()
        l1 = [1,2,3]
        l1 += bar
        assert l1 == ('radd', bar, [1,2,3])

    def test_add_lists(self):
        l1 = [1,2,3]
        l2 = [4,5,6]
        l3 = l1 + l2
        assert l3 == [1,2,3,4,5,6]

    def test_imul(self):
        l = l0 = [4,3]
        l *= 2
        assert l is l0
        assert l == [4,3,4,3]
        l *= 0
        assert l is l0
        assert l == []
        l = l0 = [4,3]
        l *= (-1)
        assert l is l0
        assert l == []

        l = l0 = ['a', 'b']
        l *= 2
        assert l is l0
        assert l == ['a', 'b', 'a', 'b']
        l *= 0
        assert l is l0
        assert l == []
        l = ['a']
        l *= -5
        assert l == []

        l = l0 = [1.1, 2.2]
        l *= 2
        assert l is l0
        assert l == [1.1, 2.2, 1.1, 2.2]

        l = list(range(2))
        l *= 2
        assert l == [0, 1, 0, 1]

        r1 = r2 = list(range(3))
        assert r1 is r2
        r1 *= 2
        assert r1 is r2
        assert r1 == [0, 1, 2, 0, 1, 2]
        assert r2 == [0, 1, 2, 0, 1, 2]

    def test_mul_errors(self):
        try:
            [1, 2, 3] * (3,)
        except TypeError:
            pass

    def test_mul___index__(self):
        class MyInt(object):
          def __init__(self, x):
            self.x = x

          def __int__(self):
            return self.x

        class MyIndex(object):
          def __init__(self, x):
            self.x = x

          def __index__(self):
            return self.x

        assert [0] * MyIndex(3) == [0, 0, 0]
        raises(TypeError, "[0]*MyInt(3)")
        raises(TypeError, "[0]*MyIndex(MyInt(3))")

    def test_index(self):
        c = list(range(10))
        assert c.index(0) == 0
        raises(ValueError, c.index, 10)

        c = list('hello world')
        assert c.index('l') == 2
        raises(ValueError, c.index, '!')
        assert c.index('l', 3) == 3
        assert c.index('l', 4) == 9
        raises(ValueError, c.index, 'l', 10)
        assert c.index('l', -5) == 9
        assert c.index('l', -25) == 2
        assert c.index('o', 1, 5) == 4
        raises(ValueError, c.index, 'o', 1, 4)
        assert c.index('o', 1, 5-11) == 4
        raises(ValueError, c.index, 'o', 1, 4-11)
        raises(TypeError, c.index, 'c', 0, 4.3)
        raises(TypeError, c.index, 'c', 1.0, 5.6)

        c = [0, 2, 4]
        assert c.index(0) == 0
        raises(ValueError, c.index, 3)

        c = [0.0, 2.2, 4.4]
        assert c.index(0) == 0.0
        e = raises(ValueError, c.index, 3)
        import sys
        if sys.version_info[:2] == (2, 7):     # CPython 2.7, PyPy
            assert str(e.value) == '3 is not in list'

    def test_index_cpython_bug(self):
        if self.on_cpython:
            skip("cpython has a bug here")
        c = list('hello world')
        assert c.index('l', None, None) == 2
        assert c.index('l', 3, None) == 3
        assert c.index('l', None, 4) == 2

    def test_ass_slice(self):
        l = list(range(6))
        l[1:3] = 'abc'
        assert l == [0, 'a', 'b', 'c', 3, 4, 5]
        l = []
        l[:-3] = []
        assert l == []
        l = list(range(6))
        l[:] = []
        assert l == []

        l = l0 = ['a', 'b']
        l[1:1] = ['ae']
        assert l == ['a', 'ae', 'b']
        l[1:100] = ['B']
        assert l == ['a', 'B']
        l[:] = []
        assert l == []
        assert l is l0

        l = []
        l2 = range(3)
        l.__setitem__(slice(0,3),l2)
        assert l == [0,1,2]

    def test_assign_extended_slice(self):
        l = l0 = ['a', 'b', 'c']
        l[::-1] = ['a', 'b', 'c']
        assert l == ['c', 'b', 'a']
        l[::-2] = [0, 1]
        assert l == [1, 'b', 0]
        l[-1:5:2] = [2]
        assert l == [1, 'b', 2]
        l[:-1:2] = [0]
        assert l == [0, 'b', 2]
        assert l is l0

        l = [1,2,3]
        raises(ValueError, "l[0:2:2] = [1,2,3,4]")
        raises(ValueError, "l[::2] = []")

        l = list(range(6))
        l[::3] = ('a', 'b')
        assert l == ['a', 1, 2, 'b', 4, 5]

        l = [0.0, 1.1, 2.2, 3.3, 4.4, 5.5]
        l[::3] = ('a', 'b')
        assert l == ['a', 1.1, 2.2, 'b', 4.4, 5.5]

        l_int = [5]; l_int.pop()   # IntListStrategy
        l_empty = []               # EmptyListStrategy
        raises(ValueError, "l_int[::-1] = [42]")
        raises(ValueError, "l_int[::7] = [42]")
        raises(ValueError, "l_empty[::-1] = [42]")
        raises(ValueError, "l_empty[::7] = [42]")
        l_int[::1] = [42]; assert l_int == [42]
        l_empty[::1] = [42]; assert l_empty == [42]

    def test_setslice_with_self(self):
        l = [1,2,3,4]
        l[:] = l
        assert l == [1,2,3,4]

        l = [1,2,3,4]
        l[0:2] = l
        assert l == [1,2,3,4,3,4]

        l = [1,2,3,4]
        l[0:2] = l
        assert l == [1,2,3,4,3,4]

        l = [1,2,3,4,5,6,7,8,9,10]
        raises(ValueError, "l[5::-1] = l")

        l = [1,2,3,4,5,6,7,8,9,10]
        raises(ValueError, "l[::2] = l")

        l = [1,2,3,4,5,6,7,8,9,10]
        l[5:] = l
        assert l == [1,2,3,4,5,1,2,3,4,5,6,7,8,9,10]

        l = [1,2,3,4,5,6]
        l[::-1] = l
        assert l == [6,5,4,3,2,1]

    def test_setitem_slice_performance(self):
        # because of a complexity bug, this used to take forever on a
        # translated pypy.  On CPython2.6 -A, it takes around 5 seconds.
        if self.on_arm:
            skip("consumes too much memory for most ARM machines")
        if self.runappdirect:
            count = 16*1024*1024
        else:
            count = 1024
        b = [None] * count
        for i in range(count):
            b[i:i+1] = ['y']
        assert b == ['y'] * count

    def test_setslice_full(self):
        l = [1, 2, 3]
        l[::] = "abc"
        assert l == ['a', 'b', 'c']

        l = [1, 2, 3]
        l[::] = []
        assert l == []

        l = [1, 2, 3]
        l[::] = l
        assert l == [1, 2, 3]

    def test_setslice_full_bug(self):
        l = [1, 2, 3]
        l[::] = (x + 1 for x in l)
        assert l == [2, 3, 4]

    def test_recursive_repr(self):
        l = []
        assert repr(l) == '[]'
        l.append(l)
        assert repr(l) == '[[...]]'

    def test_copy(self):
        # test that empty list copies the empty list
        l = []
        c = l.copy()
        assert c == []

        # test that the items of a list are the same
        l = list(range(3))
        c = l.copy()
        assert l == c

        # test that it's indeed a copy and not a reference
        l = ['a', 'b']
        c = l.copy()
        c.append('i')
        assert l == ['a', 'b']
        assert c == l + ['i']

        # test that it's a shallow, not a deep copy
        l = [1, 2, [3, 4], 5]
        c = l.copy()
        assert l == c
        assert c[3] == l[3]

        raises(TypeError, l.copy, None)

    def test_append(self):
        l = []
        l.append('X')
        assert l == ['X']
        l.append('Y')
        l.append('Z')
        assert l == ['X', 'Y', 'Z']

        l = []
        l.append(0)
        assert l == [0]
        for x in range(1, 5):
            l.append(x)
        assert l == list(range(5))

        l = [1,2,3]
        l.append("a")
        assert l == [1,2,3,"a"]

        l = [1.1, 2.2, 3.3]
        l.append(4.4)
        assert l == [1.1, 2.2, 3.3, 4.4]

        l = list(range(4))
        l.append(4)
        assert l == list(range(5))

        l = list(range(5))
        l.append(26)
        assert l == [0,1,2,3,4,26]

        l = list(range(5))
        l.append("a")
        assert l == [0,1,2,3,4,"a"]

        l = list(range(5))
        l.append(5)
        assert l == [0,1,2,3,4,5]

    def test_count(self):
        c = list('hello')
        assert c.count('l') == 2
        assert c.count('h') == 1
        assert c.count('w') == 0

    def test_insert(self):
        c = list('hello world')
        c.insert(0, 'X')
        assert c[:4] == ['X', 'h', 'e', 'l']
        c.insert(2, 'Y')
        c.insert(-2, 'Z')
        assert ''.join(c) == 'XhYello worZld'

        ls = [1, 2, 3, 4, 5, 6, 7]
        for i in range(5):
            ls.insert(0, i)
        assert len(ls) == 12

        l = []
        l.insert(4,2)
        assert l == [2]

        l = [1,2,3]
        l.insert(0,"a")
        assert l == ["a", 1, 2, 3]

        l = list(range(3))
        l.insert(1,5)
        assert l == [0,5,1,2]

    def test_pop(self):
        c = list('hello world')
        s = ''
        for i in range(11):
            s += c.pop()
        assert s == 'dlrow olleh'
        raises(IndexError, c.pop)
        assert len(c) == 0

        l = list(range(10))
        l.pop()
        assert l == list(range(9))
        assert l.pop(0) == 0

        l = [1.1, 2.2, 3.3]
        l.pop()
        assert l == [1.1, 2.2]

        l = []
        raises(IndexError, l.pop, 0)

    def test_pop_custom_int(self):
        class A(object):
            def __init__(self, x):
                self.x = x

            def __int__(self):
                return self.x

        l = list(range(10))
        x = l.pop(A(-1))
        assert x == 9
        assert l == list(range(9))
        raises(TypeError, list(range(10)).pop, 1.0)

    def test_pop_negative(self):
        l1 = [1,2,3,4]
        l2 = ["1", "2", "3", "4"]
        l3 = list(range(5))
        l4 = [1, 2, 3, "4"]
        l5 = [1.1, 2.2, 3.3, 4.4]

        raises(IndexError, l1.pop, -5)
        raises(IndexError, l2.pop, -5)
        raises(IndexError, l3.pop, -6)
        raises(IndexError, l4.pop, -5)
        raises(IndexError, l5.pop, -5)

        assert l1.pop(-2) == 3
        assert l2.pop(-2) == "3"
        assert l3.pop(-2) == 3
        assert l4.pop(-2) == 3
        assert l5.pop(-2) == 3.3

    def test_remove(self):
        c = list('hello world')
        c.remove('l')
        assert ''.join(c) == 'helo world'
        c.remove('l')
        assert ''.join(c) == 'heo world'
        c.remove('l')
        assert ''.join(c) == 'heo word'
        raises(ValueError, c.remove, 'l')
        assert ''.join(c) == 'heo word'

        l = list(range(5))
        l.remove(2)
        assert l == [0, 1, 3, 4]
        l = [0, 3, 5]
        raises(ValueError, c.remove, 2)

        l = [0.0, 1.1, 2.2, 3.3, 4.4]
        l.remove(2.2)
        assert l == [0.0, 1.1, 3.3, 4.4]
        l = [0.0, 3.3, 5.5]
        raises(ValueError, c.remove, 2)
        e = raises(ValueError, c.remove, 2.2)
        if not self.on_cpython:
            assert str(e.value) == 'list.remove(): 2.2 is not in list'

    def test_reverse(self):
        c = list('hello world')
        c.reverse()
        assert ''.join(c) == 'dlrow olleh'

        l = list(range(3))
        l.reverse()
        assert l == [2,1,0]

        r = list(range(3))
        r[0] = 1
        assert r == [1, 1, 2]
        r.reverse()
        assert r == [2, 1, 1]

    def test_reversed(self):
        assert list(list('hello').__reversed__()) == ['o', 'l', 'l', 'e', 'h']
        assert list(reversed(list('hello'))) == ['o', 'l', 'l', 'e', 'h']

    def test_mutate_while_remove(self):
        class Mean(object):
            def __init__(self, i):
                self.i = i
            def __eq__(self, other):
                if self.i == 9:
                    del l[self.i - 1]
                    return True
                else:
                    return False
        l = [Mean(i) for i in range(10)]
        # does not crash
        l.remove(None)
        class Mean2(object):
            def __init__(self, i):
                self.i = i
            def __eq__(self, other):
                l.append(self.i)
                return False
        l = [Mean2(i) for i in range(10)]
        # does not crash
        l.remove(5)
        assert l[10:] == [0, 1, 2, 3, 4, 6, 7, 8, 9]

    def test_mutate_while_contains(self):
        class Mean(object):
            def __init__(self, i):
                self.i = i
            def __eq__(self, other):
                if self.i == 9 == other:
                    del l[0]
                    return True
                else:
                    return False
        l = [Mean(i) for i in range(10)]
        assert l.__contains__(9)
        assert not l.__contains__(2)

    def test_mutate_while_extend(self):
        # this used to segfault pypy-c (with py.test -A)
        import sys
        if hasattr(sys, 'pypy_translation_info'):
            if sys.pypy_translation_info['translation.gc'] == 'boehm':
                skip("not reliable on top of Boehm")
        class A(object):
            def __del__(self):
                print('del')
                del lst[:]
        for i in range(10):
            keepalive = []
            lst = list(str(i)) * 100
            A()
            while lst:
                keepalive.append(lst[:])

    def test_unicode(self):
        s = "\ufffd\ufffd\ufffd"
        assert s.encode("ascii", "replace") == b"???"
        assert s.encode("ascii", "ignore") == b""
        l1 = [s.encode("ascii", "replace")]
        assert l1[0] == b"???"

        l2 = [s.encode("ascii", "ignore")]
        assert l2[0] == b""

        l3 = [s]
        assert l3[0].encode("ascii", "replace") == b"???"

        s = u"\u2039"
        l1 = list(s)
        assert len(l1) == 1

    def test_unicode_bug_in_listview_utf8(self):
        l1 = list(u'\u1234\u2345')
        assert l1 == [u'\u1234', u'\u2345']

    def test_list_from_set(self):
        l = ['a']
        l.__init__(set('b'))
        assert l == ['b']

    def test_list_from_generator(self):
        l = ['a']
        g = (i*i for i in range(5))
        l.__init__(g)
        assert l == [0, 1, 4, 9, 16]
        l.__init__(g)
        assert l == []
        assert list(g) == []

    def test_list_from_bytes(self):
        b = list(b'abc')
        assert b == [97, 98, 99]

    def test_uses_custom_iterator(self):
        # obscure corner case: space.listview*() must not shortcut subclasses
        # of dicts, because the OrderedDict in the stdlib relies on this.
        # we extend the use case to lists and sets, i.e. all types that have
        # strategies, to avoid surprizes depending on the strategy.
        class X: pass
        for base, arg in [
                (list, []), (list, [5]), (list, ['x']), (list, [X]), (list, ['x']),
                (set, []),  (set,  [5]), (set,  ['x']), (set, [X]), (set, ['x']),
                (dict, []), (dict, [(5,6)]), (dict, [('x',7)]), (dict, [(X,8)]),
                (dict, [('x', 7)]),
                ]:
            print(base, arg)
            class SubClass(base):
                def __iter__(self):
                    return iter("foobar")
            sub = SubClass(arg)
            assert list(sub) == ['f', 'o', 'o', 'b', 'a', 'r']
            l = []
            l.extend(sub)
            assert l == ['f', 'o', 'o', 'b', 'a', 'r']
            # test another list strategy
            l = ['Z']
            l.extend(sub)
            assert l == ['Z', 'f', 'o', 'o', 'b', 'a', 'r']

            class Sub2(base):
                pass
            assert list(Sub2(arg)) == list(base(arg))
            s = set()
            s.update(Sub2(arg))
            assert s == set(base(arg))

    def test_comparison(self):
        assert ([] <  []) is False
        assert ([] <= []) is True
        assert ([] == []) is True
        assert ([] != []) is False
        assert ([] >  []) is False
        assert ([] >= []) is True
        assert ([5] <  []) is False
        assert ([5] <= []) is False
        assert ([5] == []) is False
        assert ([5] != []) is True
        assert ([5] >  []) is True
        assert ([5] >= []) is True
        assert ([] <  [5]) is True
        assert ([] <= [5]) is True
        assert ([] == [5]) is False
        assert ([] != [5]) is True
        assert ([] >  [5]) is False
        assert ([] >= [5]) is False
        assert ([4] <  [5]) is True
        assert ([4] <= [5]) is True
        assert ([4] == [5]) is False
        assert ([4] != [5]) is True
        assert ([4] >  [5]) is False
        assert ([4] >= [5]) is False
        assert ([5] <  [5]) is False
        assert ([5] <= [5]) is True
        assert ([5] == [5]) is True
        assert ([5] != [5]) is False
        assert ([5] >  [5]) is False
        assert ([5] >= [5]) is True
        assert ([6] <  [5]) is False
        assert ([6] <= [5]) is False
        assert ([6] == [5]) is False
        assert ([6] != [5]) is True
        assert ([6] >  [5]) is True
        assert ([6] >= [5]) is True
        N = float('nan')
        assert ([N] <  [5]) is False
        assert ([N] <= [5]) is False
        assert ([N] == [5]) is False
        assert ([N] != [5]) is True
        assert ([N] >  [5]) is False
        assert ([N] >= [5]) is False
        assert ([5] <  [N]) is False
        assert ([5] <= [N]) is False
        assert ([5] == [N]) is False
        assert ([5] != [N]) is True
        assert ([5] >  [N]) is False
        assert ([5] >= [N]) is False

    def test_resizelist_hint(self):
        if self.on_cpython:
            skip('pypy-only test')
        import __pypy__
        l2 = []
        __pypy__.resizelist_hint(l2, 100)
        l1 = [1, 2, 3]
        l1[:] = l2
        assert len(l1) == 0

    def test_use_method_for_wrong_object(self):
        if self.on_cpython:
            skip('pypy-only test')
        raises(TypeError, list.append, 1, 2)

    def test_ne_NotImplemented(self):
        class NonList(object):
            pass
        non_list = NonList()
        assert [] != non_list

    def test_extend_from_empty_list_with_subclasses(self):
        # some of these tests used to fail by ignoring the
        # custom __iter__() --- but only if the list has so
        # far the empty strategy, as opposed to .extend()ing
        # a non-empty list.
        class T(tuple):
            def __iter__(self):
                yield "ok"
        assert list(T([5, 6])) == ["ok"]
        #
        class L(list):
            def __iter__(self):
                yield "ok"
        assert list(L([5, 6])) == ["ok"]
        assert list(L([5.2, 6.3])) == ["ok"]
        #
        class S(bytes):
            def __iter__(self):
                yield "ok"
        assert list(S(b"don't see me")) == ["ok"]
        #
        class U(str):
            def __iter__(self):
                yield "ok"
        assert list(U("don't see me")) == ["ok"]
        #
        class S(bytes):
            def __getitem__(self, index):
                never_called
        assert list(S(b"abc")) == list(b"abc")   # __getitem__ ignored
        #
        class U(str):
            def __getitem__(self, index):
                never_called
        assert list(U("abc")) == list("abc")     # __getitem__ ignored

    def test_extend_from_nonempty_list_with_subclasses(self):
        l = ["hi!"]
        class T(tuple):
            def __iter__(self):
                yield "okT"
        l.extend(T([5, 6]))
        #
        class L(list):
            def __iter__(self):
                yield "okL"
        l.extend(L([5, 6]))
        l.extend(L([5.2, 6.3]))
        #
        class S(bytes):
            def __iter__(self):
                yield "okS"
        l.extend(S(b"don't see me"))
        #
        class U(str):
            def __iter__(self):
                yield "okU"
        l.extend(U("don't see me"))
        #
        assert l == ["hi!", "okT", "okL", "okL", "okS", "okU"]
        #
        class S(bytes):
            def __getitem__(self, index):
                never_called
        l = []
        l.extend(S(b"abc"))
        assert l == list(b"abc")    # __getitem__ ignored
        #
        class U(str):
            def __getitem__(self, index):
                never_called
        l = []
        l.extend(U("abc"))
        assert l == list("abc")     # __getitem__ ignored

    def test_issue1266(self):
        l = list(range(1))
        l.pop()
        # would previously crash
        l.append(1)
        assert l == [1]

        l = list(range(1))
        l.pop()
        # would previously crash
        l.reverse()
        assert l == []

    def test_issue1266_ovf(self):
        import sys

        l = list(range(0, sys.maxsize, sys.maxsize))
        l.append(sys.maxsize)
        # -2 would be next in the range sequence if overflow were
        # allowed
        l.append(-2)
        assert l == [0, sys.maxsize, -2]
        assert -2 in l

        l = list(range(-sys.maxsize, sys.maxsize, sys.maxsize // 10))
        item11 = l[11]
        assert l[::11] == [-sys.maxsize, item11]
        assert item11 in l[::11]

    def test_bug_list_of_nans(self):
        N = float('nan')
        L1 = [N, 'foo']       # general object strategy
        assert N in L1
        assert L1.index(N) == 0
        assert L1 == [N, 'foo']
        # our float list strategy needs to consider NaNs are equal!
        L2 = [N, 0.0]         # float strategy
        assert N in L2
        assert L2.index(N) == 0
        assert L2.index(-0.0) == 1
        assert L2 == [N, -0.0]
        # same with the int-or-float list strategy
        L3 = [N, 0.0, -0.0, 0]
        assert N in L3
        assert L3.index(N) == 0
        for i in [1, 2, 3]:
            assert L3[i] == 0
            assert L3[i] == 0.0
            assert L3[i] == -0.0
            assert L3.index(0, i) == i
            assert L3.index(0.0, i) == i
            assert L3.index(-0.0, i) == i

    def test_list_new_pos_only(self):
        with raises(TypeError):
            list(sequence=[])

    def test_generic_alias(self):
        ga = list[int]
        assert ga.__origin__ is list
        assert ga.__args__ == (int, )


class AppTestWithoutStrategies:
    spaceconfig = {"objspace.std.withliststrategies": False}

    def test_no_shared_empty_list(self):
        l = []
        copy = l[:]
        copy.append({})
        assert copy == [{}]

        notshared = l[:]
        assert notshared == []


class AppTestListFastSubscr:
    spaceconfig = {"objspace.std.optimized_list_getitem": True}

    def test_getitem(self):
        import operator
        l = [0, 1, 2, 3, 4]
        for i in range(5):
            assert l[i] == i
        assert l[3:] == [3, 4]
        raises(TypeError, operator.getitem, l, "str")
