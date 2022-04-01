import sys
import py
from pypy.objspace.std.listobject import (
    W_ListObject, EmptyListStrategy, ObjectListStrategy, IntegerListStrategy,
    FloatListStrategy, BytesListStrategy, RangeListStrategy,
    SimpleRangeListStrategy, make_range_list, AsciiListStrategy,
    IntOrFloatListStrategy)
from pypy.objspace.std import listobject
from pypy.objspace.std.test.test_listobject import TestW_ListObject
from pypy.objspace.std.intobject import W_IntObject
from pypy.objspace.std.longobject import W_LongObject
from pypy.objspace.std.floatobject import W_FloatObject
from rpython.rlib.rbigint import rbigint


class TestW_ListStrategies(TestW_ListObject):
    def test_check_strategy(self):
        space = self.space
        w = space.wrap
        wb = space.newbytes
        assert isinstance(W_ListObject(space, []).strategy, EmptyListStrategy)
        assert isinstance(W_ListObject(space, [w(1),wb('a')]).strategy, ObjectListStrategy)
        assert isinstance(W_ListObject(space, [w(1),w(2),w(3)]).strategy,
                          IntegerListStrategy)
        assert isinstance(W_ListObject(space, [wb('a'), wb('b')]).strategy,
                          BytesListStrategy)
        assert isinstance(W_ListObject(space, [w(u'a'), w(u'b')]).strategy,
                          AsciiListStrategy)
        assert isinstance(W_ListObject(space, [w(u'a'), wb('b')]).strategy,
                          ObjectListStrategy) # mixed unicode and bytes

    def test_empty_to_any(self):
        space = self.space
        w = space.wrap
        wb = space.newbytes
        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.append(w((1,3)))
        assert isinstance(l.strategy, ObjectListStrategy)

        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.append(w(1))
        assert isinstance(l.strategy, IntegerListStrategy)

        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.append(wb('a'))
        assert isinstance(l.strategy, BytesListStrategy)

        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.append(w(u'a'))
        assert isinstance(l.strategy, AsciiListStrategy)

        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.append(w(1.2))
        assert isinstance(l.strategy, FloatListStrategy)

    def test_int_to_any(self):
        l = W_ListObject(self.space,
                         [self.space.wrap(1),self.space.wrap(2),self.space.wrap(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.append(self.space.wrap(4))
        assert isinstance(l.strategy, IntegerListStrategy)
        l.append(self.space.wrap('a'))
        assert isinstance(l.strategy, ObjectListStrategy)

    def test_string_to_any(self):
        l = W_ListObject(self.space,
            [self.space.newbytes('a'), self.space.newbytes('b'),
             self.space.newbytes('c')])
        assert isinstance(l.strategy, BytesListStrategy)
        l.append(self.space.newbytes('d'))
        assert isinstance(l.strategy, BytesListStrategy)
        l.append(self.space.wrap(3))
        assert isinstance(l.strategy, ObjectListStrategy)

    def test_unicode_to_any(self):
        space = self.space
        l = W_ListObject(space, [space.wrap(u'a'), space.wrap(u'b'), space.wrap(u'c')])
        assert isinstance(l.strategy, AsciiListStrategy)
        l.append(space.wrap(u'd'))
        assert isinstance(l.strategy, AsciiListStrategy)
        l.append(space.wrap(3))
        assert isinstance(l.strategy, ObjectListStrategy)

    def test_float_to_any(self):
        l = W_ListObject(self.space,
                         [self.space.wrap(1.1),self.space.wrap(2.2),self.space.wrap(3.3)])
        assert isinstance(l.strategy, FloatListStrategy)
        l.append(self.space.wrap(4.4))
        assert isinstance(l.strategy, FloatListStrategy)
        l.append(self.space.wrap("a"))
        assert isinstance(l.strategy, ObjectListStrategy)

    def test_setitem(self):
        space = self.space
        w = space.wrap
        wb = space.newbytes
        # This should work if test_listobject.py passes
        l = W_ListObject(space, [w('a'),w('b'),w('c')])
        assert space.eq_w(l.getitem(0), w('a'))
        l.setitem(0, w('d'))
        assert space.eq_w(l.getitem(0), w('d'))

        assert isinstance(l.strategy, AsciiListStrategy)

        # IntStrategy to ObjectStrategy
        l = W_ListObject(space, [w(1),w(2),w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.setitem(0, w('d'))
        assert isinstance(l.strategy, ObjectListStrategy)

        # BytesStrategy to ObjectStrategy
        l = W_ListObject(space, [wb('a'),wb('b'),wb('c')])
        assert isinstance(l.strategy, BytesListStrategy)
        l.setitem(0, w(2))
        assert isinstance(l.strategy, ObjectListStrategy)

        # FloatStrategy to ObjectStrategy
        l = W_ListObject(space, [w(1.2),w(2.3),w(3.4)])
        assert isinstance(l.strategy, FloatListStrategy)
        l.setitem(0, w("a"))
        assert isinstance(l.strategy, ObjectListStrategy)

    def test_insert(self):
        space = self.space
        w = space.wrap
        wb = space.newbytes
        # no change
        l = W_ListObject(space, [w(1),w(2),w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.insert(3, w(4))
        assert isinstance(l.strategy, IntegerListStrategy)

        # BytesStrategy
        l = W_ListObject(space, [wb('a'),wb('b'),wb('c')])
        assert isinstance(l.strategy, BytesListStrategy)
        l.insert(3, w(2))
        assert isinstance(l.strategy, ObjectListStrategy)

        # UnicodeStrategy
        l = W_ListObject(space, [w(u'a'),w(u'b'),w(u'c')])
        assert isinstance(l.strategy, AsciiListStrategy)
        l.insert(3, w(2))
        assert isinstance(l.strategy, ObjectListStrategy)

        # IntegerStrategy
        l = W_ListObject(space, [w(1),w(2),w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.insert(3, w('d'))
        assert isinstance(l.strategy, ObjectListStrategy)

        # FloatStrategy
        l = W_ListObject(space, [w(1.1),w(2.2),w(3.3)])
        assert isinstance(l.strategy, FloatListStrategy)
        l.insert(3, w('d'))
        assert isinstance(l.strategy, ObjectListStrategy)

        # EmptyStrategy
        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.insert(0, wb('a'))
        assert isinstance(l.strategy, BytesListStrategy)

        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.insert(0, w(2))
        assert isinstance(l.strategy, IntegerListStrategy)

    def test_list_empty_after_delete(self):
        py.test.skip("return to emptyliststrategy is not supported anymore")
        l = W_ListObject(self.space, [self.space.wrap(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.deleteitem(0)
        assert isinstance(l.strategy, EmptyListStrategy)

        l = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.deleteslice(0, 1, 2)
        assert isinstance(l.strategy, EmptyListStrategy)

        l = W_ListObject(self.space, [self.space.wrap(1)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.pop(-1)
        assert isinstance(l.strategy, EmptyListStrategy)

    def test_setslice(self):
        space = self.space
        w = space.wrap
        wb = space.newbytes

        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.setslice(0, 1, 2, W_ListObject(space, [w(1), w(2), w(3)]))
        assert isinstance(l.strategy, IntegerListStrategy)

        # IntegerStrategy to IntegerStrategy
        l = W_ListObject(space, [w(1), w(2), w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.setslice(0, 1, 2, W_ListObject(space, [w(4), w(5), w(6)]))
        assert isinstance(l.strategy, IntegerListStrategy)

        # ObjectStrategy to ObjectStrategy
        l = W_ListObject(space, [w(1), w('b'), w(3)])
        assert isinstance(l.strategy, ObjectListStrategy)
        l.setslice(0, 1, 2, W_ListObject(space, [w(1), w(2), w(3)]))
        assert isinstance(l.strategy, ObjectListStrategy)

        # IntegerStrategy to ObjectStrategy
        l = W_ListObject(space, [w(1), w(2), w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.setslice(0, 1, 2, W_ListObject(space, [w('a'), w('b'), w('c')]))
        assert isinstance(l.strategy, ObjectListStrategy)

        # BytesStrategy to ObjectStrategy
        l = W_ListObject(space, [wb('a'), wb('b'), wb('c')])
        assert isinstance(l.strategy, BytesListStrategy)
        l.setslice(0, 1, 2, W_ListObject(space, [w(1), w(2), w(3)]))
        assert isinstance(l.strategy, ObjectListStrategy)

        # UnicodeStrategy to ObjectStrategy
        l = W_ListObject(space, [w(u'a'), w(u'b'), w(u'c')])
        assert isinstance(l.strategy, AsciiListStrategy)
        l.setslice(0, 1, 2, W_ListObject(space, [w(1), w(2), w(3)]))
        assert isinstance(l.strategy, ObjectListStrategy)

        # FloatStrategy to ObjectStrategy
        l = W_ListObject(space, [w(1.1), w(2.2), w(3.3)])
        assert isinstance(l.strategy, FloatListStrategy)
        l.setslice(0, 1, 2, W_ListObject(space, [w('a'), w(2), w(3)]))
        assert isinstance(l.strategy, ObjectListStrategy)

    def test_setslice_int_range(self):
        space = self.space
        w = space.wrap
        l = W_ListObject(space, [w(1), w(2), w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.setslice(0, 1, 2, make_range_list(space, 5, 1, 4))
        assert isinstance(l.strategy, IntegerListStrategy)

    def test_setslice_List(self):
        space = self.space

        def wrapitems(items, bytes=False):
            items_w = []
            for i in items:
                w_item = space.newbytes(i) if bytes else space.wrap(i)
                items_w.append(w_item)
            return items_w

        def keep_other_strategy(w_list, start, step, length, w_other):
            other_strategy = w_other.strategy
            w_list.setslice(start, step, length, w_other)
            assert w_other.strategy is other_strategy

        l = W_ListObject(space, wrapitems([1,2,3,4,5]))
        other = W_ListObject(space, wrapitems(["a", "b", "c"]))
        keep_other_strategy(l, 0, 2, other.length(), other)
        assert l.strategy is space.fromcache(ObjectListStrategy)

        l = W_ListObject(space, wrapitems([1,2,3,4,5]))
        other = W_ListObject(space, wrapitems([6, 6, 6]))
        keep_other_strategy(l, 0, 2, other.length(), other)
        assert l.strategy is space.fromcache(IntegerListStrategy)

        l = W_ListObject(space, wrapitems(["a","b","c","d","e"], bytes=True))
        other = W_ListObject(space, wrapitems(["a", "b", "c"], bytes=True))
        keep_other_strategy(l, 0, 2, other.length(), other)
        assert l.strategy is space.fromcache(BytesListStrategy)

        l = W_ListObject(space, wrapitems([u"a",u"b",u"c",u"d",u"e"]))
        other = W_ListObject(space, wrapitems([u"a", u"b", u"c"]))
        keep_other_strategy(l, 0, 2, other.length(), other)
        assert l.strategy is space.fromcache(AsciiListStrategy)

        l = W_ListObject(space, wrapitems([1.1, 2.2, 3.3, 4.4, 5.5]))
        other = W_ListObject(space, [])
        keep_other_strategy(l, 0, 1, l.length(), other)
        assert l.strategy is space.fromcache(FloatListStrategy)

        l = W_ListObject(space, wrapitems(["a",3,"c",4,"e"]))
        other = W_ListObject(space, wrapitems(["a", "b", "c"]))
        keep_other_strategy(l, 0, 2, other.length(), other)
        assert l.strategy is space.fromcache(ObjectListStrategy)

        l = W_ListObject(space, wrapitems(["a",3,"c",4,"e"]))
        other = W_ListObject(space, [])
        keep_other_strategy(l, 0, 1, l.length(), other)
        assert l.strategy is space.fromcache(ObjectListStrategy)

    def test_empty_setslice_with_objectlist(self):
        space = self.space
        w = space.wrap

        l = W_ListObject(space, [])
        o = W_ListObject(space, [space.wrap(1), space.wrap("2"), space.wrap(3)])
        l.setslice(0, 1, o.length(), o)
        assert l.getitems() == o.getitems()
        l.append(space.wrap(17))
        assert l.getitems() != o.getitems()

    def test_extend(self):
        space = self.space
        w = space.wrap

        l = W_ListObject(space, [])
        assert isinstance(l.strategy, EmptyListStrategy)
        l.extend(W_ListObject(space, [w(1), w(2), w(3)]))
        assert isinstance(l.strategy, IntegerListStrategy)

        l = W_ListObject(space, [w(1), w(2), w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.extend(W_ListObject(space, [w('a'), w('b'), w('c')]))
        assert isinstance(l.strategy, ObjectListStrategy)

        l = W_ListObject(space, [w(1), w(2), w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.extend(W_ListObject(space, [w(4), w(5), w(6)]))
        assert isinstance(l.strategy, IntegerListStrategy)

        l = W_ListObject(space, [w(1.1), w(2.2), w(3.3)])
        assert isinstance(l.strategy, FloatListStrategy)
        l.extend(W_ListObject(space, [w("abc"), w("def"), w("ghi")]))
        assert isinstance(l.strategy, ObjectListStrategy)

    def test_empty_extend_with_any(self):
        space = self.space
        w = space.wrap
        wb = space.newbytes

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        empty.extend(W_ListObject(space, [w(1), w(2), w(3)]))
        assert isinstance(empty.strategy, IntegerListStrategy)

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        empty.extend(W_ListObject(space, [wb("a"), wb("b"), wb("c")]))
        assert isinstance(empty.strategy, BytesListStrategy)

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        empty.extend(W_ListObject(space, [w(u"a"), w(u"b"), w(u"c")]))
        assert isinstance(empty.strategy, AsciiListStrategy)

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        r = make_range_list(space, 1,3,7)
        empty.extend(r)
        assert isinstance(empty.strategy, RangeListStrategy)
        print empty.getitem(6)
        assert space.is_true(space.eq(empty.getitem(1), w(4)))

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        r = make_range_list(space, 0, 1, 10)
        empty.extend(r)
        assert isinstance(empty.strategy, SimpleRangeListStrategy)
        assert space.is_true(space.eq(empty.getitem(1), w(1)))

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        empty.extend(W_ListObject(space, [w(1), w(2), w(3)]))
        assert isinstance(empty.strategy, IntegerListStrategy)

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        empty.extend(W_ListObject(space, [w(1.1), w(2.2), w(3.3)]))
        assert isinstance(empty.strategy, FloatListStrategy)

        empty = W_ListObject(space, [])
        assert isinstance(empty.strategy, EmptyListStrategy)
        empty.extend(W_ListObject(space, []))
        assert isinstance(empty.strategy, EmptyListStrategy)

    def test_extend_other_with_empty(self):
        space = self.space
        w = space.wrap
        l = W_ListObject(space, [w(1), w(2), w(3)])
        assert isinstance(l.strategy, IntegerListStrategy)
        l.extend(W_ListObject(space, []))
        assert isinstance(l.strategy, IntegerListStrategy)

    def test_rangelist(self):
        l = make_range_list(self.space, 1,3,7)
        assert isinstance(l.strategy, RangeListStrategy)
        v = l.pop(5)
        assert self.space.eq_w(v, self.space.wrap(16))
        assert isinstance(l.strategy, IntegerListStrategy)

        l = make_range_list(self.space, 1,3,7)
        assert isinstance(l.strategy, RangeListStrategy)
        v = l.pop(0)
        assert self.space.eq_w(v, self.space.wrap(1))
        assert isinstance(l.strategy, RangeListStrategy)
        v = l.pop(l.length() - 1)
        assert self.space.eq_w(v, self.space.wrap(19))
        assert isinstance(l.strategy, RangeListStrategy)
        v = l.pop_end()
        assert self.space.eq_w(v, self.space.wrap(16))
        assert isinstance(l.strategy, RangeListStrategy)

        l = make_range_list(self.space, 1,3,7)
        assert isinstance(l.strategy, RangeListStrategy)
        l.append(self.space.wrap("string"))
        assert isinstance(l.strategy, ObjectListStrategy)

        l = make_range_list(self.space, 1,1,5)
        assert isinstance(l.strategy, RangeListStrategy)
        l.append(self.space.wrap(19))
        assert isinstance(l.strategy, IntegerListStrategy)

    def test_simplerangelist(self):
        l = make_range_list(self.space, 0, 1, 10)
        assert isinstance(l.strategy, SimpleRangeListStrategy)
        v = l.pop(5)
        assert self.space.eq_w(v, self.space.wrap(5))
        assert isinstance(l.strategy, IntegerListStrategy)

        l = make_range_list(self.space, 0, 1, 10)
        assert isinstance(l.strategy, SimpleRangeListStrategy)
        v = l.pop(0)
        assert self.space.eq_w(v, self.space.wrap(0))
        assert isinstance(l.strategy, IntegerListStrategy)

        l = make_range_list(self.space, 0, 1, 10)
        assert isinstance(l.strategy, SimpleRangeListStrategy)
        v = l.pop_end()
        assert self.space.eq_w(v, self.space.wrap(9))
        assert isinstance(l.strategy, SimpleRangeListStrategy)
        v = l.pop_end()
        assert self.space.eq_w(v, self.space.wrap(8))
        assert isinstance(l.strategy, SimpleRangeListStrategy)

        l = make_range_list(self.space, 0, 1, 5)
        assert isinstance(l.strategy, SimpleRangeListStrategy)
        l.append(self.space.wrap("string"))
        assert isinstance(l.strategy, ObjectListStrategy)

        l = make_range_list(self.space, 0,1,5)
        assert isinstance(l.strategy, SimpleRangeListStrategy)
        l.append(self.space.wrap(19))
        assert isinstance(l.strategy, IntegerListStrategy)

        l = make_range_list(self.space, 0,1,5)
        assert isinstance(l.strategy, SimpleRangeListStrategy)
        assert l.find(self.space.wrap(0)) == 0
        assert l.find(self.space.wrap(4)) == 4

        try:
            l.find(self.space.wrap(5))
        except ValueError:
            pass
        else:
            assert False, "Did not raise ValueError"

        try:
            l.find(self.space.wrap(0), 5, 6)
        except ValueError:
            pass
        else:
            assert False, "Did not raise ValueError"

        assert l.length() == 5

        l = make_range_list(self.space, 0, 1, 1)
        assert self.space.eq_w(l.pop(0), self.space.wrap(0))

        l = make_range_list(self.space, 0, 1, 10)
        l.sort(False)
        assert isinstance(l.strategy, SimpleRangeListStrategy)

        assert self.space.eq_w(l.getitem(5), self.space.wrap(5))

        l = make_range_list(self.space, 0, 1, 1)
        assert self.space.eq_w(l.pop_end(), self.space.wrap(0))
        assert isinstance(l.strategy, EmptyListStrategy)

    def test_keep_range(self):
        # simple list
        l = make_range_list(self.space, 1,1,5)
        assert isinstance(l.strategy, RangeListStrategy)
        x = l.pop(0)
        assert self.space.eq_w(x, self.space.wrap(1))
        assert isinstance(l.strategy, RangeListStrategy)
        l.pop(l.length()-1)
        assert isinstance(l.strategy, RangeListStrategy)
        l.append(self.space.wrap(5))
        assert isinstance(l.strategy, IntegerListStrategy)

        # complex list
        l = make_range_list(self.space, 1,3,5)
        assert isinstance(l.strategy, RangeListStrategy)
        l.append(self.space.wrap(16))
        assert isinstance(l.strategy, IntegerListStrategy)

    def test_empty_range(self):
        l = make_range_list(self.space, 0, 0, 0)
        assert isinstance(l.strategy, EmptyListStrategy)

        l = make_range_list(self.space, 1, 1, 10)
        for i in l.getitems():
            assert isinstance(l.strategy, RangeListStrategy)
            l.pop(l.length()-1)

        assert isinstance(l.strategy, RangeListStrategy)

    def test_range_getslice_ovf(self):
        l = make_range_list(self.space, -sys.maxint, sys.maxint // 10, 21)
        assert isinstance(l.strategy, RangeListStrategy)
        l2 = l.getslice(0, 21, 11, 2)
        assert isinstance(l2.strategy, IntegerListStrategy)

    def test_range_setslice(self):
        l = make_range_list(self.space, 1, 3, 5)
        assert isinstance(l.strategy, RangeListStrategy)
        l.setslice(0, 1, 3, W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)]))
        assert isinstance(l.strategy, IntegerListStrategy)

    def test_range_reverse_ovf(self):
        l = make_range_list(self.space, 0, -sys.maxint - 1, 1)
        assert isinstance(l.strategy, RangeListStrategy)
        l.reverse()
        assert isinstance(l.strategy, IntegerListStrategy)

        l = make_range_list(self.space, 0, -sys.maxint - 1, 1)
        l.sort(False)
        assert isinstance(l.strategy, IntegerListStrategy)

    def test_copy_list(self):
        l1 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        l2 = l1.clone()
        l2.append(self.space.wrap(4))
        assert not l2 == l1.getitems()

    def test_getitems_does_not_copy_object_list(self):
        l1 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap("two"), self.space.wrap(3)])
        l2 = l1.getitems()
        l2.append(self.space.wrap("four"))
        assert l2 == l1.getitems()

    def test_clone(self):
        l1 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        clone = l1.clone()
        assert isinstance(clone.strategy, IntegerListStrategy)
        clone.append(self.space.wrap(7))
        assert not self.space.eq_w(l1, clone)

    def test_add_does_not_use_getitems(self):
        l1 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        l1.getitems = None
        l2 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        l2.getitems = None
        l3 = self.space.add(l1, l2)
        l4 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3), self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        assert self.space.eq_w(l3, l4)

    def test_add_of_range_and_int(self):
        l1 = make_range_list(self.space, 0, 1, 100)
        l2 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        l3 = self.space.add(l2, l1)
        assert l3.strategy is l2.strategy

    def test_mul(self):
        l1 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        l2 = l1.mul(2)
        l3 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3), self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        assert self.space.eq_w(l2, l3)

        l4 = make_range_list(self.space, 1, 1, 3)
        assert self.space.eq_w(l4, l1)

        l5 = l4.mul(2)
        assert self.space.eq_w(l5, l3)

    def test_mul_same_strategy_but_different_object(self):
        l1 = W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3)])
        l2 = l1.mul(1)
        assert self.space.eq_w(l1, l2)
        l1.setitem(0, self.space.wrap(5))
        assert not self.space.eq_w(l1, l2)

    def test_weird_rangelist_bug(self):
        space = self.space
        l = make_range_list(space, 1, 1, 3)
        # should not raise
        w_slice = space.newslice(space.wrap(15), space.wrap(2222), space.wrap(1))
        assert l.descr_getitem(space, w_slice).strategy == space.fromcache(EmptyListStrategy)

    def test_add_to_rangelist(self):
        l1 = make_range_list(self.space, 1, 1, 3)
        l2 = W_ListObject(self.space, [self.space.wrap(4), self.space.wrap(5)])
        l3 = l1.descr_add(self.space, l2)
        assert self.space.eq_w(l3, W_ListObject(self.space, [self.space.wrap(1), self.space.wrap(2), self.space.wrap(3), self.space.wrap(4), self.space.wrap(5)]))

    def test_unicode(self):
        l1 = W_ListObject(self.space, [self.space.newbytes("eins"), self.space.newbytes("zwei")])
        assert isinstance(l1.strategy, BytesListStrategy)
        l2 = W_ListObject(self.space, [self.space.newutf8("eins", 4), self.space.newutf8("zwei", 4)])
        assert isinstance(l2.strategy, AsciiListStrategy)
        l3 = W_ListObject(self.space, [self.space.newbytes("eins"), self.space.newutf8("zwei", 4)])
        assert isinstance(l3.strategy, ObjectListStrategy)

    def test_listview_bytes(self):
        space = self.space
        assert space.listview_bytes(space.wrap(1)) == None
        w_l = self.space.newlist([self.space.newbytes('a'), self.space.newbytes('b')])
        assert space.listview_bytes(w_l) == ["a", "b"]

    def test_listview_unicode(self):
        space = self.space
        assert space.listview_ascii(space.wrap(1)) == None
        w_l = self.space.newlist([self.space.wrap(u'a'), self.space.wrap(u'b')])
        assert space.listview_ascii(w_l) == ["a", "b"]

    def test_string_join_uses_listview_bytes(self):
        space = self.space
        w_l = self.space.newlist([self.space.wrap('a'), self.space.wrap('b')])
        w_l.getitems = None
        assert space.text_w(space.call_method(space.wrap("c"), "join", w_l)) == "acb"
        #
        # the same for unicode
        w_l = self.space.newlist([self.space.wrap(u'a'), self.space.wrap(u'b')])
        w_l.getitems = None
        assert space.utf8_w(space.call_method(space.wrap(u"c"), "join", w_l)) == "acb"

    def test_string_join_returns_same_instance(self):
        space = self.space
        w_text = space.wrap("text")
        w_l = self.space.newlist([w_text])
        w_l.getitems = None
        assert space.is_w(space.call_method(space.wrap(" -- "), "join", w_l), w_text)
        #
        # the same for unicode
        w_text = space.wrap(u"text")
        w_l = self.space.newlist([w_text])
        w_l.getitems = None
        assert space.is_w(space.call_method(space.wrap(u" -- "), "join", w_l), w_text)

    def test_newlist_bytes(self):
        space = self.space
        l = ['a', 'b']
        w_l = self.space.newlist_bytes(l)
        assert isinstance(w_l.strategy, BytesListStrategy)
        assert space.listview_bytes(w_l) is l

    def test_string_uses_newlist_bytes(self):
        space = self.space
        w_s = space.newbytes("a b c")
        space.newlist = None
        try:
            w_l = space.call_method(w_s, "split")
            w_l2 = space.call_method(w_s, "split", space.newbytes(" "))
            w_l3 = space.call_method(w_s, "rsplit")
            w_l4 = space.call_method(w_s, "rsplit", space.newbytes(" "))
        finally:
            del space.newlist
        assert space.listview_bytes(w_l) == ["a", "b", "c"]
        assert space.listview_bytes(w_l2) == ["a", "b", "c"]
        assert space.listview_bytes(w_l3) == ["a", "b", "c"]
        assert space.listview_bytes(w_l4) == ["a", "b", "c"]

    def test_unicode_uses_newlist_unicode(self):
        space = self.space
        w_u = space.wrap(u"a b c")
        space.newlist = None
        try:
            w_l = space.call_method(w_u, "split")
            w_l2 = space.call_method(w_u, "split", space.wrap(" "))
            w_l3 = space.call_method(w_u, "rsplit")
            w_l4 = space.call_method(w_u, "rsplit", space.wrap(" "))
        finally:
            del space.newlist
        assert space.listview_ascii(w_l) == [u"a", u"b", u"c"]
        assert space.listview_ascii(w_l2) == [u"a", u"b", u"c"]
        assert space.listview_ascii(w_l3) == [u"a", u"b", u"c"]
        assert space.listview_ascii(w_l4) == [u"a", u"b", u"c"]

    def test_pop_without_argument_is_fast(self):
        space = self.space
        w_l = W_ListObject(space, [space.wrap(1), space.wrap(2), space.wrap(3)])
        w_l.pop = None
        w_res = w_l.descr_pop(space)
        assert space.unwrap(w_res) == 3

    def test_create_list_from_set(self):
        from pypy.objspace.std.setobject import W_SetObject
        from pypy.objspace.std.setobject import _initialize_set

        space = self.space
        w = space.wrap

        w_l = W_ListObject(space, [space.wrap(1), space.wrap(2), space.wrap(3)])

        w_set = W_SetObject(self.space)
        _initialize_set(self.space, w_set, w_l)
        w_set.iter = None # make sure fast path is used

        w_l2 = W_ListObject(space, [])
        space.call_method(w_l2, "__init__", w_set)

        w_l2.sort(False)
        assert space.eq_w(w_l, w_l2)

        w_l = W_ListObject(space, [space.wrap("a"), space.wrap("b"), space.wrap("c")])
        _initialize_set(self.space, w_set, w_l)

        space.call_method(w_l2, "__init__", w_set)

        w_l2.sort(False)
        assert space.eq_w(w_l, w_l2)

    def test_listview_bytes_list(self):
        space = self.space
        w_l = W_ListObject(space, [space.newbytes("a"), space.newbytes("b")])
        assert self.space.listview_bytes(w_l) == ["a", "b"]

    def test_listview_unicode_list(self):
        space = self.space
        w_l = W_ListObject(space, [space.wrap(u"a"), space.wrap(u"b")])
        assert self.space.listview_ascii(w_l) == [u"a", u"b"]

    def test_listview_int_list(self):
        space = self.space
        w_l = W_ListObject(space, [space.wrap(1), space.wrap(2), space.wrap(3)])
        assert self.space.listview_int(w_l) == [1, 2, 3]

    def test_listview_float_list(self):
        space = self.space
        w_l = W_ListObject(space, [space.wrap(1.1), space.wrap(2.2), space.wrap(3.3)])
        assert self.space.listview_float(w_l) == [1.1, 2.2, 3.3]

    def test_unpackiterable_int_list(self):
        space = self.space
        w_l = W_ListObject(space, [space.wrap(1), space.wrap(2), space.wrap(3)])
        list_orig = self.space.listview_int(w_l)
        list_copy = self.space.unpackiterable_int(w_l)
        assert list_orig == list_copy == [1, 2, 3]
        list_copy[0] = 42
        assert list_orig == [1, 2, 3]

    def test_int_or_float_special_nan(self):
        from rpython.rlib import longlong2float, rarithmetic
        space = self.space
        ll = rarithmetic.r_longlong(0xfffffffe12345678 - 2**64)
        specialnan = longlong2float.longlong2float(ll)
        w_l = W_ListObject(space, [space.wrap(1), space.wrap(specialnan)])
        assert isinstance(w_l.strategy, ObjectListStrategy)

    def test_int_or_float_int_overflow(self):
        if sys.maxint == 2147483647:
            py.test.skip("only on 64-bit")
        space = self.space
        ok1 = 2**31 - 1
        ok2 = -2**31
        ovf1 = ok1 + 1
        ovf2 = ok2 - 1
        w_l = W_ListObject(space, [space.wrap(1.2), space.wrap(ovf1)])
        assert isinstance(w_l.strategy, ObjectListStrategy)
        w_l = W_ListObject(space, [space.wrap(1.2), space.wrap(ovf2)])
        assert isinstance(w_l.strategy, ObjectListStrategy)
        w_l = W_ListObject(space, [space.wrap(1.2), space.wrap(ok1)])
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        w_l = W_ListObject(space, [space.wrap(1.2), space.wrap(ok2)])
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)

    def test_int_or_float_base(self):
        from rpython.rlib.rfloat import INFINITY, NAN
        space = self.space
        w = space.wrap
        w_l = W_ListObject(space, [space.wrap(1), space.wrap(2.3)])
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        w_l.append(w(int(2**31-1)))
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        w_l.append(w(-5.1))
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        assert space.int_w(w_l.getitem(2)) == 2**31-1
        assert space.float_w(w_l.getitem(3)) == -5.1
        w_l.append(w(INFINITY))
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        w_l.append(w(NAN))
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        w_l.append(w(-NAN))
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        w_l.append(space.newlist([]))
        assert isinstance(w_l.strategy, ObjectListStrategy)

    def test_int_or_float_from_integer(self):
        space = self.space
        w = space.wrap
        w_l = W_ListObject(space, [space.wrap(int(-2**31))])
        assert isinstance(w_l.strategy, IntegerListStrategy)
        w_l.append(w(-5.1))
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        assert space.int_w(w_l.getitem(0)) == -2**31
        assert space.float_w(w_l.getitem(1)) == -5.1
        assert space.len_w(w_l) == 2

    def test_int_or_float_from_integer_overflow(self):
        if sys.maxint == 2147483647:
            py.test.skip("only on 64-bit")
        space = self.space
        w = space.wrap
        ovf1 = -2**31 - 1
        w_l = W_ListObject(space, [space.wrap(ovf1)])
        assert isinstance(w_l.strategy, IntegerListStrategy)
        w_l.append(w(-5.1))
        assert isinstance(w_l.strategy, ObjectListStrategy)
        assert space.int_w(w_l.getitem(0)) == ovf1
        assert space.float_w(w_l.getitem(1)) == -5.1
        assert space.len_w(w_l) == 2

    def test_int_or_float_from_integer_special_nan(self):
        from rpython.rlib import longlong2float, rarithmetic
        space = self.space
        w = space.wrap
        w_l = W_ListObject(space, [space.wrap(int(-2**31))])
        assert isinstance(w_l.strategy, IntegerListStrategy)
        ll = rarithmetic.r_longlong(0xfffffffe12345678 - 2**64)
        specialnan = longlong2float.longlong2float(ll)
        w_l.append(w(specialnan))
        assert isinstance(w_l.strategy, ObjectListStrategy)
        assert space.int_w(w_l.getitem(0)) == -2**31
        assert space.len_w(w_l) == 2

    def test_int_or_float_from_float(self):
        space = self.space
        w = space.wrap
        w_l = W_ListObject(space, [space.wrap(-42.5)])
        assert isinstance(w_l.strategy, FloatListStrategy)
        w_l.append(w(-15))
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        assert space.float_w(w_l.getitem(0)) == -42.5
        assert space.int_w(w_l.getitem(1)) == -15
        assert space.len_w(w_l) == 2

    def test_int_or_float_from_float_int_overflow(self):
        if sys.maxint == 2147483647:
            py.test.skip("only on 64-bit")
        space = self.space
        w = space.wrap
        ovf1 = 2 ** 31
        w_l = W_ListObject(space, [space.wrap(1.2)])
        assert isinstance(w_l.strategy, FloatListStrategy)
        w_l.append(w(ovf1))
        assert isinstance(w_l.strategy, ObjectListStrategy)
        assert space.float_w(w_l.getitem(0)) == 1.2
        assert space.int_w(w_l.getitem(1)) == ovf1
        assert space.len_w(w_l) == 2

    def test_int_or_float_from_float_special_nan(self):
        from rpython.rlib import longlong2float, rarithmetic
        space = self.space
        w = space.wrap
        ll = rarithmetic.r_longlong(0xfffffffe12345678 - 2**64)
        specialnan = longlong2float.longlong2float(ll)
        w_l = W_ListObject(space, [space.wrap(specialnan)])
        assert isinstance(w_l.strategy, FloatListStrategy)
        w_l.append(w(42))
        assert isinstance(w_l.strategy, ObjectListStrategy)
        assert space.int_w(w_l.getitem(1)) == 42
        assert space.len_w(w_l) == 2

    def test_int_or_float_extend(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(3), space.wrap(4.5)])
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert isinstance(w_l2.strategy, IntOrFloatListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [0, 1.2, 3, 4.5]

    def test_int_or_float_extend_mixed_1(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(3)])
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert isinstance(w_l2.strategy, IntegerListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert [(type(x), x) for x in space.unwrap(w_l1)] == [
            (int, 0), (float, 1.2), (int, 3)]

    def test_int_or_float_extend_mixed_2(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(3.4)])
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert isinstance(w_l2.strategy, FloatListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [0, 1.2, 3.4]

    def test_int_or_float_extend_mixed_3(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0)])
        w_l2 = W_ListObject(space, [space.wrap(3.4)])
        assert isinstance(w_l1.strategy, IntegerListStrategy)
        assert isinstance(w_l2.strategy, FloatListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [0, 3.4]

    def test_int_or_float_extend_mixed_4(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0)])
        w_l2 = W_ListObject(space, [space.wrap(3.4), space.wrap(-2)])
        assert isinstance(w_l1.strategy, IntegerListStrategy)
        assert isinstance(w_l2.strategy, IntOrFloatListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [0, 3.4, -2]

    def test_int_or_float_extend_mixed_5(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(-2.5)])
        w_l2 = W_ListObject(space, [space.wrap(42)])
        assert isinstance(w_l1.strategy, FloatListStrategy)
        assert isinstance(w_l2.strategy, IntegerListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [-2.5, 42]

    def test_int_or_float_extend_mixed_5_overflow(self):
        if sys.maxint == 2147483647:
            py.test.skip("only on 64-bit")
        space = self.space
        ovf1 = 2 ** 35
        w_l1 = W_ListObject(space, [space.wrap(-2.5)])
        w_l2 = W_ListObject(space, [space.wrap(ovf1)])
        assert isinstance(w_l1.strategy, FloatListStrategy)
        assert isinstance(w_l2.strategy, IntegerListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, ObjectListStrategy)
        assert space.unwrap(w_l1) == [-2.5, ovf1]

    def test_int_or_float_extend_mixed_6(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(-2.5)])
        w_l2 = W_ListObject(space, [space.wrap(3.4), space.wrap(-2)])
        assert isinstance(w_l1.strategy, FloatListStrategy)
        assert isinstance(w_l2.strategy, IntOrFloatListStrategy)
        w_l1.extend(w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [-2.5, 3.4, -2]

    def test_int_or_float_setslice(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(3), space.wrap(4.5)])
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert isinstance(w_l2.strategy, IntOrFloatListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [3, 4.5, 1.2]

    def test_int_or_float_setslice_mixed_1(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(12)])
        w_l2 = W_ListObject(space, [space.wrap(3.2), space.wrap(4.5)])
        assert isinstance(w_l1.strategy, IntegerListStrategy)
        assert isinstance(w_l2.strategy, FloatListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [3.2, 4.5, 12]

    def test_int_or_float_setslice_mixed_2(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(12)])
        w_l2 = W_ListObject(space, [space.wrap(3.2), space.wrap(45)])
        assert isinstance(w_l1.strategy, IntegerListStrategy)
        assert isinstance(w_l2.strategy, IntOrFloatListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [3.2, 45, 12]

    def test_int_or_float_setslice_mixed_3(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0.1), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(32), space.wrap(45)])
        assert isinstance(w_l1.strategy, FloatListStrategy)
        assert isinstance(w_l2.strategy, IntegerListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [32, 45, 1.2]

    def test_int_or_float_setslice_mixed_4(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0.1), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(3.2), space.wrap(45)])
        assert isinstance(w_l1.strategy, FloatListStrategy)
        assert isinstance(w_l2.strategy, IntOrFloatListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [3.2, 45, 1.2]

    def test_int_or_float_setslice_mixed_5(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(32), space.wrap(45)])
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert isinstance(w_l2.strategy, IntegerListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [32, 45, 1.2]

    def test_int_or_float_setslice_mixed_5_overflow(self):
        if sys.maxint == 2147483647:
            py.test.skip("only on 64-bit")
        space = self.space
        ovf1 = 2 ** 35
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(32), space.wrap(ovf1)])
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert isinstance(w_l2.strategy, IntegerListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, ObjectListStrategy)
        assert space.unwrap(w_l1) == [32, ovf1, 1.2]

    def test_int_or_float_setslice_mixed_6(self):
        space = self.space
        w_l1 = W_ListObject(space, [space.wrap(0), space.wrap(1.2)])
        w_l2 = W_ListObject(space, [space.wrap(3.2), space.wrap(4.5)])
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert isinstance(w_l2.strategy, FloatListStrategy)
        w_l1.setslice(0, 1, 1, w_l2)
        assert isinstance(w_l1.strategy, IntOrFloatListStrategy)
        assert space.unwrap(w_l1) == [3.2, 4.5, 1.2]

    def test_int_or_float_sort(self):
        space = self.space
        w_l = W_ListObject(space, [space.wrap(1.2), space.wrap(1),
                                   space.wrap(1.0), space.wrap(5)])
        w_l.sort(False)
        assert [(type(x), x) for x in space.unwrap(w_l)] == [
            (int, 1), (float, 1.0), (float, 1.2), (int, 5)]
        w_l.sort(True)
        assert [(type(x), x) for x in space.unwrap(w_l)] == [
            (int, 5), (float, 1.2), (int, 1), (float, 1.0)]

    def test_stringstrategy_wraps_bytes(self):
        space = self.space
        wb = space.newbytes
        l = W_ListObject(space, [wb('a'), wb('b')])
        w_item = l.getitem(0)
        assert isinstance(w_item, space.StringObjectCls)

    def test_integer_strategy_with_w_long(self):
        # tests all calls to is_plain_int1() so far
        space = self.space
        w = W_LongObject(rbigint.fromlong(42))
        w_l = space.newlist([])
        space.call_method(w_l, 'append', w)
        assert isinstance(w_l.strategy, IntegerListStrategy)
        assert isinstance(space.getitem(w_l, space.wrap(0)), W_IntObject)
        #
        w_l = space.newlist([w, w])
        assert isinstance(w_l.strategy, IntegerListStrategy)
        assert isinstance(space.getitem(w_l, space.wrap(0)), W_IntObject)
        assert isinstance(space.getitem(w_l, space.wrap(1)), W_IntObject)
        #
        w_f = space.newfloat(42.0)
        w_l = space.newlist([w_f, w])
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        assert isinstance(space.getitem(w_l, space.wrap(0)), W_FloatObject)
        assert isinstance(space.getitem(w_l, space.wrap(1)), W_IntObject)
        space.call_method(w_l, 'append', w)
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        assert isinstance(space.getitem(w_l, space.wrap(2)), W_IntObject)
        #
        w_l = make_range_list(space, 0, 1, 10)
        space.call_method(w_l, 'append', w)
        assert isinstance(w_l.strategy, IntegerListStrategy)
        assert isinstance(space.getitem(w_l, space.wrap(-1)), W_IntObject)
        #
        w_l = make_range_list(space, 30, 2, 45)
        assert space.eq_w(space.call_method(w_l, 'index', w), space.wrap(6))
        #
        w_l = make_range_list(space, 0, 1, 45)
        assert space.eq_w(space.call_method(w_l, 'index', w), space.wrap(42))
        #
        w_f = space.newfloat(42.0)
        w_l = space.newlist([w_f])
        space.call_method(w_l, 'append', w)
        assert isinstance(w_l.strategy, IntOrFloatListStrategy)
        assert isinstance(space.getitem(w_l, space.wrap(0)), W_FloatObject)
        assert isinstance(space.getitem(w_l, space.wrap(1)), W_IntObject)


class TestW_ListStrategiesDisabled:
    spaceconfig = {"objspace.std.withliststrategies": False}

    def test_check_strategy(self):
        assert isinstance(W_ListObject(self.space, []).strategy, ObjectListStrategy)
        assert isinstance(W_ListObject(self.space, [self.space.wrap(1),self.space.wrap('a')]).strategy, ObjectListStrategy)
        assert isinstance(W_ListObject(self.space, [self.space.wrap(1),self.space.wrap(2),self.space.wrap(3)]).strategy, ObjectListStrategy)
        assert isinstance(W_ListObject(self.space, [self.space.wrap('a'), self.space.wrap('b')]).strategy, ObjectListStrategy)
