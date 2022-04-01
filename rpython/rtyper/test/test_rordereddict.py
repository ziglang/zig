import py
import random
from collections import OrderedDict

from hypothesis import settings, given, strategies
from hypothesis.stateful import run_state_machine_as_test

from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem import rordereddict, rstr
from rpython.rlib.rarithmetic import intmask
from rpython.rtyper.annlowlevel import llstr, hlstr
from rpython.rtyper.test.test_rdict import (
    BaseTestRDict, MappingSpace, MappingSM)
from rpython.rlib import objectmodel

rodct = rordereddict

def get_indexes(ll_d):
    return ll_d.indexes._obj.container._as_ptr()

def foreach_index(ll_d):
    indexes = get_indexes(ll_d)
    for i in range(len(indexes)):
        yield rffi.cast(lltype.Signed, indexes[i])

def count_items(ll_d, ITEM):
    c = 0
    for item in foreach_index(ll_d):
        if item == ITEM:
            c += 1
    return c


class TestRDictDirect(object):
    dummykeyobj = None
    dummyvalueobj = None

    def _get_str_dict(self):
        # STR -> lltype.Signed
        DICT = rordereddict.get_ll_dict(lltype.Ptr(rstr.STR), lltype.Signed,
                                 ll_fasthash_function=rstr.LLHelpers.ll_strhash,
                                 ll_hash_function=rstr.LLHelpers.ll_strhash,
                                 ll_eq_function=rstr.LLHelpers.ll_streq,
                                 dummykeyobj=self.dummykeyobj,
                                 dummyvalueobj=self.dummyvalueobj)
        return DICT

    def test_dict_creation(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        lls = llstr("abc")
        rordereddict.ll_dict_setitem(ll_d, lls, 13)
        assert count_items(ll_d, rordereddict.FREE) == rordereddict.DICT_INITSIZE - 1
        assert rordereddict.ll_dict_getitem(ll_d, llstr("abc")) == 13
        assert rordereddict.ll_dict_getitem(ll_d, lls) == 13
        rordereddict.ll_dict_setitem(ll_d, lls, 42)
        assert rordereddict.ll_dict_getitem(ll_d, lls) == 42
        rordereddict.ll_dict_setitem(ll_d, llstr("abc"), 43)
        assert rordereddict.ll_dict_getitem(ll_d, lls) == 43

    def test_dict_creation_2(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        llab = llstr("ab")
        llb = llstr("b")
        rordereddict.ll_dict_setitem(ll_d, llab, 1)
        rordereddict.ll_dict_setitem(ll_d, llb, 2)
        assert rordereddict.ll_dict_getitem(ll_d, llb) == 2

    def test_dict_store_get(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        for i in range(20):
            for j in range(i):
                assert rordereddict.ll_dict_getitem(ll_d, llstr(str(j))) == j
            rordereddict.ll_dict_setitem(ll_d, llstr(str(i)), i)
        assert ll_d.num_live_items == 20
        for i in range(20):
            assert rordereddict.ll_dict_getitem(ll_d, llstr(str(i))) == i

    def test_dict_store_get_del(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        for i in range(20):
            for j in range(0, i, 2):
                assert rordereddict.ll_dict_getitem(ll_d, llstr(str(j))) == j
            rordereddict.ll_dict_setitem(ll_d, llstr(str(i)), i)
            if i % 2 != 0:
                rordereddict.ll_dict_delitem(ll_d, llstr(str(i)))
        assert ll_d.num_live_items == 10
        for i in range(0, 20, 2):
            assert rordereddict.ll_dict_getitem(ll_d, llstr(str(i))) == i

    def test_dict_del_lastitem(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        py.test.raises(KeyError, rordereddict.ll_dict_delitem, ll_d, llstr("abc"))
        rordereddict.ll_dict_setitem(ll_d, llstr("abc"), 13)
        py.test.raises(KeyError, rordereddict.ll_dict_delitem, ll_d, llstr("def"))
        rordereddict.ll_dict_delitem(ll_d, llstr("abc"))
        assert count_items(ll_d, rordereddict.FREE) == rordereddict.DICT_INITSIZE - 1
        assert count_items(ll_d, rordereddict.DELETED) == 1
        py.test.raises(KeyError, rordereddict.ll_dict_getitem, ll_d, llstr("abc"))

    def test_dict_del_not_lastitem(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("abc"), 13)
        rordereddict.ll_dict_setitem(ll_d, llstr("def"), 15)
        rordereddict.ll_dict_delitem(ll_d, llstr("abc"))
        assert count_items(ll_d, rordereddict.FREE) == rordereddict.DICT_INITSIZE - 2
        assert count_items(ll_d, rordereddict.DELETED) == 1

    def test_dict_resize(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("a"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("b"), 2)
        rordereddict.ll_dict_setitem(ll_d, llstr("c"), 3)
        rordereddict.ll_dict_setitem(ll_d, llstr("d"), 4)
        rordereddict.ll_dict_setitem(ll_d, llstr("e"), 5)
        rordereddict.ll_dict_setitem(ll_d, llstr("f"), 6)
        rordereddict.ll_dict_setitem(ll_d, llstr("g"), 7)
        rordereddict.ll_dict_setitem(ll_d, llstr("h"), 8)
        rordereddict.ll_dict_setitem(ll_d, llstr("i"), 9)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 10)
        assert len(get_indexes(ll_d)) == 16
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 11)
        rordereddict.ll_dict_setitem(ll_d, llstr("l"), 12)
        rordereddict.ll_dict_setitem(ll_d, llstr("m"), 13)
        assert len(get_indexes(ll_d)) == 64
        for item in 'abcdefghijklm':
            assert rordereddict.ll_dict_getitem(ll_d, llstr(item)) == ord(item) - ord('a') + 1

    def test_dict_grow_cleanup(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        lls = llstr("a")
        for i in range(40):
            rordereddict.ll_dict_setitem(ll_d, lls, i)
            rordereddict.ll_dict_delitem(ll_d, lls)
        assert ll_d.num_ever_used_items <= 10

    def test_dict_iteration(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 2)
        assert [hlstr(entry.key) for entry in self._ll_iter(ll_d)] == ["k", "j"]

    def _ll_iter(self, ll_d):
        ITER = rordereddict.get_ll_dictiter(lltype.typeOf(ll_d))
        ll_iter = rordereddict.ll_dictiter(ITER, ll_d)
        ll_dictnext = rordereddict._ll_dictnext
        while True:
            try:
                num = ll_dictnext(ll_iter)
            except StopIteration:
                break
            yield ll_d.entries[num]

    def test_popitem(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 2)
        TUP = lltype.Ptr(lltype.GcStruct('x', ('item0', lltype.Ptr(rstr.STR)),
                                              ('item1', lltype.Signed)))
        ll_elem = rordereddict.ll_dict_popitem(TUP, ll_d)
        assert hlstr(ll_elem.item0) == "j"
        assert ll_elem.item1 == 2
        ll_elem = rordereddict.ll_dict_popitem(TUP, ll_d)
        assert hlstr(ll_elem.item0) == "k"
        assert ll_elem.item1 == 1
        py.test.raises(KeyError, rordereddict.ll_dict_popitem, TUP, ll_d)

    def test_popitem_first(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 2)
        rordereddict.ll_dict_setitem(ll_d, llstr("m"), 3)
        ITER = rordereddict.get_ll_dictiter(lltype.Ptr(DICT))
        for expected in ["k", "j", "m"]:
            ll_iter = rordereddict.ll_dictiter(ITER, ll_d)
            num = rordereddict._ll_dictnext(ll_iter)
            ll_key = ll_d.entries[num].key
            assert hlstr(ll_key) == expected
            rordereddict.ll_dict_delitem(ll_d, ll_key)
        ll_iter = rordereddict.ll_dictiter(ITER, ll_d)
        py.test.raises(StopIteration, rordereddict._ll_dictnext, ll_iter)

    def test_popitem_first_bug(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 1)
        rordereddict.ll_dict_delitem(ll_d, llstr("k"))
        ITER = rordereddict.get_ll_dictiter(lltype.Ptr(DICT))
        ll_iter = rordereddict.ll_dictiter(ITER, ll_d)
        num = rordereddict._ll_dictnext(ll_iter)
        ll_key = ll_d.entries[num].key
        assert hlstr(ll_key) == "j"
        assert ll_d.lookup_function_no == (   # 1 free item found at the start
            (1 << rordereddict.FUNC_SHIFT) | rordereddict.FUNC_BYTE)
        rordereddict.ll_dict_delitem(ll_d, llstr("j"))
        assert ll_d.num_ever_used_items == 0
        assert ll_d.lookup_function_no == rordereddict.FUNC_BYTE   # reset

    def _get_int_dict(self):
        def eq(a, b):
            return a == b

        return rordereddict.get_ll_dict(lltype.Signed, lltype.Signed,
                                 ll_fasthash_function=intmask,
                                 ll_hash_function=intmask,
                                 ll_eq_function=eq)

    def test_direct_enter_and_del(self):
        DICT = self._get_int_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        numbers = [i * rordereddict.DICT_INITSIZE + 1 for i in range(8)]
        for num in numbers:
            rordereddict.ll_dict_setitem(ll_d, num, 1)
            rordereddict.ll_dict_delitem(ll_d, num)
            for k in foreach_index(ll_d):
                assert k < rordereddict.VALID_OFFSET

    def test_contains(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        assert rordereddict.ll_dict_contains(ll_d, llstr("k"))
        assert not rordereddict.ll_dict_contains(ll_d, llstr("j"))

    def test_clear(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("l"), 1)
        rordereddict.ll_dict_clear(ll_d)
        assert ll_d.num_live_items == 0

    def test_get(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        assert rordereddict.ll_dict_get(ll_d, llstr("k"), 32) == 1
        assert rordereddict.ll_dict_get(ll_d, llstr("j"), 32) == 32

    def test_setdefault(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        assert rordereddict.ll_dict_setdefault(ll_d, llstr("j"), 42) == 42
        assert rordereddict.ll_dict_getitem(ll_d, llstr("j")) == 42
        assert rordereddict.ll_dict_setdefault(ll_d, llstr("k"), 42) == 1
        assert rordereddict.ll_dict_getitem(ll_d, llstr("k")) == 1

    def test_copy(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 1)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 2)
        ll_d2 = rordereddict.ll_dict_copy(ll_d)
        for ll_d3 in [ll_d, ll_d2]:
            assert rordereddict.ll_dict_getitem(ll_d3, llstr("k")) == 1
            assert rordereddict.ll_dict_get(ll_d3, llstr("j"), 42) == 2
            assert rordereddict.ll_dict_get(ll_d3, llstr("i"), 42) == 42

    def test_update(self):
        DICT = self._get_str_dict()
        ll_d1 = rordereddict.ll_newdict(DICT)
        ll_d2 = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d1, llstr("k"), 5)
        rordereddict.ll_dict_setitem(ll_d1, llstr("j"), 6)
        rordereddict.ll_dict_setitem(ll_d2, llstr("i"), 7)
        rordereddict.ll_dict_setitem(ll_d2, llstr("k"), 8)
        rordereddict.ll_dict_update(ll_d1, ll_d2)
        for key, value in [("k", 8), ("i", 7), ("j", 6)]:
            assert rordereddict.ll_dict_getitem(ll_d1, llstr(key)) == value

    def test_pop(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 5)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 6)
        assert rordereddict.ll_dict_pop(ll_d, llstr("k")) == 5
        assert rordereddict.ll_dict_pop(ll_d, llstr("j")) == 6
        py.test.raises(KeyError, rordereddict.ll_dict_pop, ll_d, llstr("k"))
        py.test.raises(KeyError, rordereddict.ll_dict_pop, ll_d, llstr("j"))

    def test_pop_default(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, llstr("k"), 5)
        rordereddict.ll_dict_setitem(ll_d, llstr("j"), 6)
        assert rordereddict.ll_dict_pop_default(ll_d, llstr("k"), 42) == 5
        assert rordereddict.ll_dict_pop_default(ll_d, llstr("j"), 41) == 6
        assert rordereddict.ll_dict_pop_default(ll_d, llstr("k"), 40) == 40
        assert rordereddict.ll_dict_pop_default(ll_d, llstr("j"), 39) == 39

    def test_bug_remove_deleted_items(self):
        DICT = self._get_str_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        for i in range(15):
            rordereddict.ll_dict_setitem(ll_d, llstr(chr(i)), 5)
        for i in range(15):
            rordereddict.ll_dict_delitem(ll_d, llstr(chr(i)))
        rordereddict.ll_prepare_dict_update(ll_d, 7)
        # used to get UninitializedMemoryAccess

    def test_bug_resize_counter(self):
        DICT = self._get_int_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_delitem(ll_d, 0)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_delitem(ll_d, 0)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_delitem(ll_d, 0)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_delitem(ll_d, 0)
        rordereddict.ll_dict_setitem(ll_d, 1, 0)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_setitem(ll_d, 2, 0)
        rordereddict.ll_dict_delitem(ll_d, 1)
        rordereddict.ll_dict_delitem(ll_d, 0)
        rordereddict.ll_dict_delitem(ll_d, 2)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_delitem(ll_d, 0)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_delitem(ll_d, 0)
        rordereddict.ll_dict_setitem(ll_d, 0, 0)
        rordereddict.ll_dict_setitem(ll_d, 1, 0)
        d = ll_d
        idx = d.indexes._obj.container
        num_nonfrees = 0
        for i in range(idx.getlength()):
            got = idx.getitem(i)   # 0: unused; 1: deleted
            num_nonfrees += (got > 0)
        assert d.resize_counter <= idx.getlength() * 2 - num_nonfrees * 3

    @given(strategies.lists(strategies.integers(min_value=1, max_value=5)))
    def test_direct_move_to_end(self, lst):
        DICT = self._get_int_dict()
        ll_d = rordereddict.ll_newdict(DICT)
        rordereddict.ll_dict_setitem(ll_d, 1, 11)
        rordereddict.ll_dict_setitem(ll_d, 2, 22)
        def content():
            return [(entry.key, entry.value) for entry in self._ll_iter(ll_d)]
        for case in lst:
            if case == 1:
                rordereddict.ll_dict_move_to_end(ll_d, 1, True)
                assert content() == [(2, 22), (1, 11)]
            elif case == 2:
                rordereddict.ll_dict_move_to_end(ll_d, 2, True)
                assert content() == [(1, 11), (2, 22)]
            elif case == 3:
                py.test.raises(KeyError, rordereddict.ll_dict_move_to_end,
                                                 ll_d, 3, True)
            elif case == 4:
                rordereddict.ll_dict_move_to_end(ll_d, 2, False)
                assert content() == [(2, 22), (1, 11)]
            elif case == 5:
                rordereddict.ll_dict_move_to_end(ll_d, 1, False)
                assert content() == [(1, 11), (2, 22)]


class TestRDictDirectDummyKey(TestRDictDirect):
    class dummykeyobj:
        ll_dummy_value = llstr("dupa")

class TestRDictDirectDummyValue(TestRDictDirect):
    class dummyvalueobj:
        ll_dummy_value = -42

class TestOrderedRDict(BaseTestRDict):
    @staticmethod
    def newdict():
        return OrderedDict()

    @staticmethod
    def newdict2():
        return OrderedDict()

    @staticmethod
    def new_r_dict(myeq, myhash, force_non_null=False, simple_hash_eq=False):
        return objectmodel.r_ordereddict(
            myeq, myhash, force_non_null=force_non_null,
            simple_hash_eq=simple_hash_eq)

    def test_two_dicts_with_different_value_types(self):
        def func(i):
            d1 = OrderedDict()
            d1['hello'] = i + 1
            d2 = OrderedDict()
            d2['world'] = d1
            return d2['world']['hello']
        res = self.interpret(func, [5])
        assert res == 6

    def test_move_to_end(self):
        def func():
            d1 = OrderedDict()
            d1['key1'] = 'value1'
            d1['key2'] = 'value2'
            for i in range(20):
                objectmodel.move_to_end(d1, 'key1')
                assert d1.keys() == ['key2', 'key1']
                objectmodel.move_to_end(d1, 'key2')
                assert d1.keys() == ['key1', 'key2']
            for i in range(20):
                objectmodel.move_to_end(d1, 'key2', last=False)
                assert d1.keys() == ['key2', 'key1']
                objectmodel.move_to_end(d1, 'key1', last=False)
                assert d1.keys() == ['key1', 'key2']
        func()
        self.interpret(func, [])


class ODictSpace(MappingSpace):
    MappingRepr = rodct.OrderedDictRepr
    moved_around = False
    ll_getitem = staticmethod(rodct.ll_dict_getitem)
    ll_setitem = staticmethod(rodct.ll_dict_setitem)
    ll_delitem = staticmethod(rodct.ll_dict_delitem)
    ll_len = staticmethod(rodct.ll_dict_len)
    ll_contains = staticmethod(rodct.ll_dict_contains)
    ll_copy = staticmethod(rodct.ll_dict_copy)
    ll_clear = staticmethod(rodct.ll_dict_clear)
    ll_popitem = staticmethod(rodct.ll_dict_popitem)

    def newdict(self, repr):
        return rodct.ll_newdict(repr.DICT)

    def get_keys(self):
        DICT = lltype.typeOf(self.l_dict).TO
        ITER = rordereddict.get_ll_dictiter(lltype.Ptr(DICT))
        ll_iter = rordereddict.ll_dictiter(ITER, self.l_dict)
        ll_dictnext = rordereddict._ll_dictnext
        keys_ll = []
        while True:
            try:
                num = ll_dictnext(ll_iter)
                keys_ll.append(self.l_dict.entries[num].key)
            except StopIteration:
                break
        return keys_ll

    def popitem(self):
        # overridden to check that we're getting the most recent key,
        # not a random one
        try:
            ll_tuple = self.ll_popitem(self.TUPLE, self.l_dict)
        except KeyError:
            assert len(self.reference) == 0
        else:
            ll_key = ll_tuple.item0
            ll_value = ll_tuple.item1
            key, value = self.reference.popitem()
            assert self.ll_key(key) == ll_key
            assert self.ll_value(value) == ll_value
            self.removed_keys.append(key)

    def removeindex(self):
        # remove the index, as done during translation for prebuilt dicts
        # (but cannot be done if we already removed a key)
        if not self.removed_keys and not self.moved_around:
            rodct.ll_no_initial_index(self.l_dict)

    def move_to_end(self, key, last=True):
        ll_key = self.ll_key(key)
        rodct.ll_dict_move_to_end(self.l_dict, ll_key, last)
        value = self.reference.pop(key)
        if last:
            self.reference[key] = value
        else:
            items = self.reference.items()
            self.reference.clear()
            self.reference[key] = value
            self.reference.update(items)
        # prevent ll_no_initial_index()
        self.moved_around = True

    def fullcheck(self):
        # overridden to also check key order
        assert self.ll_len(self.l_dict) == len(self.reference)
        keys_ll = self.get_keys()
        assert len(keys_ll) == len(self.reference)
        for key, ll_key in zip(self.reference, keys_ll):
            assert self.ll_key(key) == ll_key
            assert (self.ll_getitem(self.l_dict, self.ll_key(key)) ==
                self.ll_value(self.reference[key]))
        for key in self.removed_keys:
            if key not in self.reference:
                try:
                    self.ll_getitem(self.l_dict, self.ll_key(key))
                except KeyError:
                    pass
                else:
                    raise AssertionError("removed key still shows up")
        # check some internal invariants
        d = self.l_dict
        num_lives = 0
        for i in range(d.num_ever_used_items):
            if d.entries.valid(i):
                num_lives += 1
        assert num_lives == d.num_live_items
        fun = d.lookup_function_no & rordereddict.FUNC_MASK
        if fun == rordereddict.FUNC_MUST_REINDEX:
            assert not d.indexes
        else:
            assert d.indexes
            idx = d.indexes._obj.container
            num_lives = 0
            num_nonfrees = 0
            for i in range(idx.getlength()):
                got = idx.getitem(i)   # 0: unused; 1: deleted
                num_nonfrees += (got > 0)
                num_lives += (got > 1)
            assert num_lives == d.num_live_items
            assert 0 < d.resize_counter <= idx.getlength()*2 - num_nonfrees*3


class ODictSM(MappingSM):
    Space = ODictSpace

def test_hypothesis():
    run_state_machine_as_test(
        ODictSM, settings(max_examples=500, stateful_step_count=100))
