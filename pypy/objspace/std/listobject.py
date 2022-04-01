"""The builtin list implementation

Lists optimize their storage by holding certain primitive datatypes in
unwrapped form. For more information:

https://www.pypy.org/posts/2011/10/more-compact-lists-with-list-strategies-8229304944653956829.html

"""

import math
import operator
import sys

from rpython.rlib import debug, jit, rerased, rutf8
from rpython.rlib.listsort import make_timsort_class
from rpython.rlib.objectmodel import (
    import_from_mixin, instantiate, newlist_hint, resizelist_hint, specialize)
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rlib import longlong2float
from rpython.tool.sourcetools import func_with_new_name

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import (
    WrappedDefault, applevel, interp2app, unwrap_spec)
from pypy.interpreter.signature import Signature
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.miscutils import StringSort
from pypy.objspace.std.bytesobject import W_BytesObject
from pypy.objspace.std.floatobject import W_FloatObject
from pypy.objspace.std.intobject import W_IntObject
from pypy.objspace.std.longobject import W_LongObject
from pypy.objspace.std.iterobject import (
    W_FastListIterObject, W_ReverseSeqIterObject)
from pypy.objspace.std.sliceobject import W_SliceObject, unwrap_start_stop
from pypy.objspace.std.tupleobject import W_AbstractTupleObject
from pypy.objspace.std.unicodeobject import W_UnicodeObject
from pypy.objspace.std.util import get_positive_index, negate, generic_alias_class_getitem

__all__ = ['W_ListObject', 'make_range_list', 'make_empty_list_with_size']


UNROLL_CUTOFF = 5


def make_range_list(space, start, step, length):
    if length <= 0:
        strategy = space.fromcache(EmptyListStrategy)
        storage = strategy.erase(None)
    elif start == 0 and step == 1:
        strategy = space.fromcache(SimpleRangeListStrategy)
        storage = strategy.erase((length,))
    else:
        strategy = space.fromcache(RangeListStrategy)
        storage = strategy.erase((start, step, length))
    return W_ListObject.from_storage_and_strategy(space, storage, strategy)


def make_empty_list(space):
    strategy = space.fromcache(EmptyListStrategy)
    storage = strategy.erase(None)
    return W_ListObject.from_storage_and_strategy(space, storage, strategy)


def make_empty_list_with_size(space, hint):
    strategy = SizeListStrategy(space, hint)
    storage = strategy.erase(None)
    return W_ListObject.from_storage_and_strategy(space, storage, strategy)


@jit.look_inside_iff(lambda space, list_w, sizehint:
        jit.loop_unrolling_heuristic(list_w, len(list_w), UNROLL_CUTOFF))
def get_strategy_from_list_objects(space, list_w, sizehint):
    if not list_w:
        if sizehint != -1:
            return SizeListStrategy(space, sizehint)
        return space.fromcache(EmptyListStrategy)

    w_firstobj = list_w[0]
    check_int_or_float = False

    if is_plain_int1(w_firstobj):
        # check for all-ints
        for i in range(1, len(list_w)):
            w_obj = list_w[i]
            if not is_plain_int1(w_obj):
                check_int_or_float = (type(w_obj) is W_FloatObject)
                break
        else:
            return space.fromcache(IntegerListStrategy)

    elif type(w_firstobj) is W_BytesObject:
        # check for all-strings
        for i in range(1, len(list_w)):
            if type(list_w[i]) is not W_BytesObject:
                break
        else:
            return space.fromcache(BytesListStrategy)

    elif type(w_firstobj) is W_UnicodeObject and w_firstobj.is_ascii():
        # check for all-unicodes containing only ascii
        for i in range(1, len(list_w)):
            item = list_w[i]
            if type(item) is not W_UnicodeObject or not item.is_ascii():
                break
        else:
            return space.fromcache(AsciiListStrategy)

    elif type(w_firstobj) is W_FloatObject:
        # check for all-floats
        for i in range(1, len(list_w)):
            w_obj = list_w[i]
            if type(w_obj) is not W_FloatObject:
                check_int_or_float = is_plain_int1(w_obj)
                break
        else:
            return space.fromcache(FloatListStrategy)

    if check_int_or_float:
        for w_obj in list_w:
            if is_plain_int1(w_obj):
                if longlong2float.can_encode_int32(plain_int_w(space, w_obj)):
                    continue    # ok
            elif type(w_obj) is W_FloatObject:
                if longlong2float.can_encode_float(w_obj.float_w(space)):
                    continue    # ok
            break
        else:
            return space.fromcache(IntOrFloatListStrategy)

    return space.fromcache(ObjectListStrategy)


def _get_printable_location(strategy_type, greenkey):
    return 'list__do_extend_from_iterable [%s, %s]' % (
        strategy_type,
        greenkey.iterator_greenkey_printable())


_do_extend_jitdriver = jit.JitDriver(
    name='list__do_extend_from_iterable',
    greens=['strategy_type', 'greenkey'],
    reds='auto',
    get_printable_location=_get_printable_location)

def _do_extend_from_iterable(space, w_list, w_iterable):
    w_iterator = space.iter(w_iterable)
    greenkey = space.iterator_greenkey(w_iterator)
    i = 0
    while True:
        _do_extend_jitdriver.jit_merge_point(
                greenkey=greenkey,
                strategy_type=type(w_list.strategy))
        try:
            w_list.append(space.next(w_iterator))
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
            break
        i += 1
    return i


def list_unroll_condition(w_list1, space, w_list2):
    return (jit.loop_unrolling_heuristic(w_list1, w_list1.length(),
                                         UNROLL_CUTOFF) or
            jit.loop_unrolling_heuristic(w_list2, w_list2.length(),
                                         UNROLL_CUTOFF))


class W_ListObject(W_Root):
    strategy = None

    def __init__(self, space, wrappeditems, sizehint=-1):
        assert isinstance(wrappeditems, list)
        self.space = space
        if space.config.objspace.std.withliststrategies:
            self.strategy = get_strategy_from_list_objects(space, wrappeditems,
                                                           sizehint)
        else:
            self.strategy = space.fromcache(ObjectListStrategy)
        self.init_from_list_w(wrappeditems)

    @staticmethod
    def from_storage_and_strategy(space, storage, strategy):
        self = instantiate(W_ListObject)
        self.space = space
        self.strategy = strategy
        self.lstorage = storage
        if not space.config.objspace.std.withliststrategies:
            self.switch_to_object_strategy()
        return self

    @staticmethod
    def newlist_bytes(space, list_b):
        strategy = space.fromcache(BytesListStrategy)
        storage = strategy.erase(list_b)
        return W_ListObject.from_storage_and_strategy(space, storage, strategy)

    @staticmethod
    def newlist_ascii(space, list_u):
        strategy = space.fromcache(AsciiListStrategy)
        storage = strategy.erase(list_u)
        return W_ListObject.from_storage_and_strategy(space, storage, strategy)

    @staticmethod
    def newlist_int(space, list_i):
        strategy = space.fromcache(IntegerListStrategy)
        storage = strategy.erase(list_i)
        return W_ListObject.from_storage_and_strategy(space, storage, strategy)

    @staticmethod
    def newlist_float(space, list_f):
        strategy = space.fromcache(FloatListStrategy)
        storage = strategy.erase(list_f)
        return W_ListObject.from_storage_and_strategy(space, storage, strategy)

    def __repr__(self):
        """ representation for debugging purposes """
        return "%s(%s, %s)" % (self.__class__.__name__, self.strategy,
                               self.lstorage._x)

    def unwrap(w_list, space):
        # for tests only!
        items = [space.unwrap(w_item) for w_item in w_list.getitems()]
        return list(items)

    def switch_to_object_strategy(self):
        object_strategy = self.space.fromcache(ObjectListStrategy)
        if self.strategy is object_strategy:
            return
        list_w = self.getitems()
        self.strategy = object_strategy
        object_strategy.init_from_list_w(self, list_w)

    def _temporarily_as_objects(self):
        if self.strategy is self.space.fromcache(ObjectListStrategy):
            return self
        list_w = self.getitems()
        strategy = self.space.fromcache(ObjectListStrategy)
        storage = strategy.erase(list_w)
        w_objectlist = W_ListObject.from_storage_and_strategy(
                self.space, storage, strategy)
        return w_objectlist

    def convert_to_cpy_strategy(self, space):
        from pypy.module.cpyext.sequence import CPyListStorage, CPyListStrategy

        cpy_strategy = self.space.fromcache(CPyListStrategy)
        if self.strategy is cpy_strategy:
            return
        lst = self.getitems()
        self.strategy = cpy_strategy
        self.lstorage = cpy_strategy.erase(CPyListStorage(space, lst))

    # ___________________________________________________

    def init_from_list_w(self, list_w):
        """Initializes listobject by iterating through the given list of
        wrapped items, unwrapping them if neccessary and creating a
        new erased object as storage"""
        self.strategy.init_from_list_w(self, list_w)

    def clear(self, space):
        """Initializes (or overrides) the listobject as empty."""
        self.space = space
        if space.config.objspace.std.withliststrategies:
            strategy = space.fromcache(EmptyListStrategy)
        else:
            strategy = space.fromcache(ObjectListStrategy)
        self.strategy = strategy
        strategy.clear(self)

    def clone(self):
        """Returns a clone by creating a new listobject
        with the same strategy and a copy of the storage"""
        return self.strategy.clone(self)

    def _resize_hint(self, hint):
        """Ensure the underlying list has room for at least hint
        elements without changing the len() of the list"""
        return self.strategy._resize_hint(self, hint)

    def copy_into(self, other):
        """Used only when extending an EmptyList. Sets the EmptyLists
        strategy and storage according to the other W_List"""
        self.strategy.copy_into(self, other)

    def find(self, w_item, start=0, end=sys.maxint):
        """Find w_item in list[start:end]. If not found, raise ValueError"""
        return self.strategy.find(self, w_item, start, end)

    def append(self, w_item):
        """L.append(object) -> None -- append object to end"""
        self.strategy.append(self, w_item)

    def length(self):
        return self.strategy.length(self)

    def getitem(self, index):
        """Returns the wrapped object that is found in the
        list at the given index. The index must be unwrapped.
        May raise IndexError."""
        return self.strategy.getitem(self, index)

    def getslice(self, start, stop, step, length):
        """Returns a slice of the list defined by the arguments. Arguments must
        be normalized (i.e. using normalize_simple_slice or W_Slice.indices4).
        May raise IndexError."""
        return self.strategy.getslice(self, start, stop, step, length)

    def getitems(self):
        """Returns a list of all items after wrapping them. The result can
        share with the storage, if possible."""
        return self.strategy.getitems(self)

    def getitems_fixedsize(self):
        """Returns a fixed-size list of all items after wrapping them."""
        l = self.strategy.getitems_fixedsize(self)
        debug.make_sure_not_resized(l)
        return l

    def getitems_unroll(self):
        """Returns a fixed-size list of all items after wrapping them. The JIT
        will fully unroll this function."""
        l = self.strategy.getitems_unroll(self)
        debug.make_sure_not_resized(l)
        return l

    def getitems_copy(self):
        """Returns a copy of all items in the list. Same as getitems except for
        ObjectListStrategy."""
        return self.strategy.getitems_copy(self)

    def getitems_bytes(self):
        """Return the items in the list as unwrapped strings. If the list does
        not use the list strategy, return None."""
        return self.strategy.getitems_bytes(self)

    def getitems_ascii(self):
        """Return the items in the list as unwrapped unicodes. If the list does
        not use the list strategy, return None."""
        return self.strategy.getitems_ascii(self)

    def getitems_int(self):
        """Return the items in the list as unwrapped ints. If the list does not
        use the list strategy, return None."""
        return self.strategy.getitems_int(self)

    def getitems_float(self):
        """Return the items in the list as unwrapped floats. If the list does not
        use the list strategy, return None."""
        return self.strategy.getitems_float(self)
    # ___________________________________________________

    def mul(self, times):
        """Returns a copy of the list, multiplied by times.
        Argument must be unwrapped."""
        return self.strategy.mul(self, times)

    def inplace_mul(self, times):
        """Alters the list by multiplying its content by times."""
        self.strategy.inplace_mul(self, times)

    def deleteslice(self, start, step, length):
        """Deletes a slice from the list. Used in delitem and delslice.
        Arguments must be normalized (see getslice)."""
        self.strategy.deleteslice(self, start, step, length)

    def pop(self, index):
        """Pops an item from the list. Index must be normalized.
        May raise IndexError."""
        return self.strategy.pop(self, index)

    def pop_end(self):
        """ Pop the last element from the list."""
        return self.strategy.pop_end(self)

    def setitem(self, index, w_item):
        """Inserts a wrapped item at the given (unwrapped) index.
        May raise IndexError."""
        self.strategy.setitem(self, index, w_item)

    def setslice(self, start, step, slicelength, sequence_w):
        """Sets the slice of the list from start to start+step*slicelength to
        the sequence sequence_w.
        Used by setslice and setitem."""
        self.strategy.setslice(self, start, step, slicelength, sequence_w)

    def insert(self, index, w_item):
        """Inserts an item at the given position. Item must be wrapped,
        index not."""
        self.strategy.insert(self, index, w_item)

    def extend(self, w_iterable):
        '''L.extend(iterable) -- extend list by appending elements from the iterable'''
        self.strategy.extend(self, w_iterable)

    def reverse(self):
        """Reverses the list."""
        self.strategy.reverse(self)

    def sort(self, reverse):
        """Sorts the list ascending or descending depending on
        argument reverse. Argument must be unwrapped."""
        self.strategy.sort(self, reverse)

    def physical_size(self):
        """ return the physical (ie overallocated size) of the underlying list.
        """
        # exposed in __pypy__
        return self.strategy.physical_size(self)

    # exposed to app-level

    @staticmethod
    def descr_new(space, w_listtype, __args__):
        "Create and return a new object.  See help(type) for accurate signature."
        w_obj = space.allocate_instance(W_ListObject, w_listtype)
        w_obj.clear(space)
        return w_obj

    def descr_init(self, space, __args__):
        """Initialize self.  See help(type(self)) for accurate signature."""
        # this is on the silly side
        w_iterable, = __args__.parse_obj(
                None, 'list', init_signature, init_defaults)
        self.clear(space)
        if w_iterable is not None:
            self.extend(w_iterable)

    def descr_repr(self, space):
        if self.length() == 0:
            return space.newtext('[]')
        return listrepr(space, space.get_objects_in_repr(), self)

    def descr_eq(self, space, w_other):
        if not isinstance(w_other, W_ListObject):
            return space.w_NotImplemented
        return self._descr_eq(space, w_other)

    @jit.look_inside_iff(list_unroll_condition)
    def _descr_eq(self, space, w_other):
        # needs to be safe against eq_w() mutating the w_lists behind our back
        if self.length() != w_other.length():
            return space.w_False

        # XXX in theory, this can be implemented more efficiently as well.
        # let's not care for now
        i = 0
        while i < self.length() and i < w_other.length():
            if not space.eq_w(self.getitem(i), w_other.getitem(i)):
                return space.w_False
            i += 1
        return space.w_True

    descr_ne = negate(descr_eq)

    def _make_list_comparison(name):
        op = getattr(operator, name)

        def compare_unwrappeditems(self, space, w_list2):
            if not isinstance(w_list2, W_ListObject):
                return space.w_NotImplemented
            return _compare_unwrappeditems(self, space, w_list2)

        @jit.look_inside_iff(list_unroll_condition)
        def _compare_unwrappeditems(self, space, w_list2):
            # needs to be safe against eq_w() mutating the w_lists behind our
            # back
            # Search for the first index where items are different
            i = 0
            # XXX in theory, this can be implemented more efficiently as well.
            # let's not care for now
            while i < self.length() and i < w_list2.length():
                w_item1 = self.getitem(i)
                w_item2 = w_list2.getitem(i)
                if not space.eq_w(w_item1, w_item2):
                    return getattr(space, name)(w_item1, w_item2)
                i += 1
            # No more items to compare -- compare sizes
            return space.newbool(op(self.length(), w_list2.length()))

        return func_with_new_name(compare_unwrappeditems, 'descr_' + name)

    descr_lt = _make_list_comparison('lt')
    descr_le = _make_list_comparison('le')
    descr_gt = _make_list_comparison('gt')
    descr_ge = _make_list_comparison('ge')

    def descr_len(self, space):
        result = self.length()
        return space.newint(result)

    def descr_iter(self, space):
        return W_FastListIterObject(self)

    def descr_contains(self, space, w_obj):
        try:
            self.find(w_obj)
            return space.w_True
        except ValueError:
            return space.w_False

    def descr_add(self, space, w_list2):
        if not isinstance(w_list2, W_ListObject):
            return space.w_NotImplemented
        w_clone = self.clone()
        w_clone.extend(w_list2)
        return w_clone

    def descr_inplace_add(self, space, w_iterable):
        if isinstance(w_iterable, W_ListObject):
            self.extend(w_iterable)
            return self

        try:
            self.extend(w_iterable)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                return space.w_NotImplemented
            raise
        return self

    def descr_mul(self, space, w_times):
        try:
            times = space.getindex_w(w_times, space.w_OverflowError)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                return space.w_NotImplemented
            raise
        return self.mul(times)

    def descr_inplace_mul(self, space, w_times):
        try:
            times = space.getindex_w(w_times, space.w_OverflowError)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                return space.w_NotImplemented
            raise
        self.inplace_mul(times)
        return self

    def descr_getitem(self, space, w_index):
        if isinstance(w_index, W_SliceObject):
            length = self.length()
            start, stop, step, slicelength = w_index.indices4(space, length)
            assert slicelength >= 0
            if slicelength == 0:
                return make_empty_list(space)
            return self.getslice(start, stop, step, slicelength)

        try:
            index = space.getindex_w(w_index, space.w_IndexError, "list")
            return self.getitem(index)
        except IndexError:
            raise oefmt(space.w_IndexError, "list index out of range")

    def descr_setitem(self, space, w_index, w_any):
        if isinstance(w_index, W_SliceObject):
            # special case for l[:] = l2
            if (space.is_w(w_index.w_start, space.w_None) and
                    space.is_w(w_index.w_stop, space.w_None) and
                    space.is_w(w_index.w_step, space.w_None)):
                # use the extend logic
                if isinstance(w_any, W_ListObject):
                    if space.is_w(self, w_any):
                        return
                    w_other = w_any
                else:
                    sequence_w = space.listview(w_any)
                    w_other = W_ListObject(space, sequence_w)
                self.clear(space)
                w_other.copy_into(self)
                return

            oldsize = self.length()
            start, stop, step, slicelength = w_index.indices4(space, oldsize)
            if isinstance(w_any, W_ListObject):
                w_other = w_any
            else:
                sequence_w = space.listview(w_any)
                w_other = W_ListObject(space, sequence_w)
            self.setslice(start, step, slicelength, w_other)
            return

        idx = space.getindex_w(w_index, space.w_IndexError, "list")
        try:
            self.setitem(idx, w_any)
        except IndexError:
            raise oefmt(space.w_IndexError, "list index out of range")

    def descr_delitem(self, space, w_idx):
        if isinstance(w_idx, W_SliceObject):
            start, stop, step, slicelength = w_idx.indices4(
                    space, self.length())
            self.deleteslice(start, step, slicelength)
            return

        idx = space.getindex_w(w_idx, space.w_IndexError, "list")
        if idx < 0:
            idx += self.length()
        try:
            self.pop(idx)
        except IndexError:
            raise oefmt(space.w_IndexError, "list index out of range")

    def descr_reversed(self, space):
        'L.__reversed__() -- return a reverse iterator over the list'
        return W_ReverseSeqIterObject(space, self, -1)

    def descr_reverse(self, space):
        'L.reverse() -- reverse *IN PLACE*'
        self.reverse()

    def descr_count(self, space, w_value):
        '''L.count(value) -> integer -- return number of occurrences of value'''
        # needs to be safe against eq_w() mutating the w_list behind our back
        count = 0
        i = 0
        while i < self.length():
            if space.eq_w(self.getitem(i), w_value):
                count += 1
            i += 1
        return space.newint(count)

    @unwrap_spec(index=int)
    def descr_insert(self, space, index, w_value):
        'L.insert(index, object) -- insert object before index'
        length = self.length()
        index = get_positive_index(index, length)
        self.insert(index, w_value)

    @unwrap_spec(index=int)
    def descr_pop(self, space, index=-1):
        """L.pop([index]) -> item -- remove and return item at index (default last).
Raises IndexError if list is empty or index is out of range."""
        length = self.length()
        if length == 0:
            raise oefmt(space.w_IndexError, "pop from empty list")
        # clearly differentiate between list.pop() and list.pop(index)
        if index == -1:
            return self.pop_end()  # cannot raise because list is not empty
        if index < 0:
            index += length
        try:
            return self.pop(index)
        except IndexError:
            raise oefmt(space.w_IndexError, "pop index out of range")

    def descr_clear(self, space):
        """L.clear() -> None -- remove all items from L"""
        self.clear(space)

    def descr_copy(self, space):
        '''L.copy() -> list -- a shallow copy of L'''
        return self.clone()

    def descr_remove(self, space, w_value):
        """L.remove(value) -> None -- remove first occurrence of value.
Raises ValueError if the value is not present."""
        # needs to be safe against eq_w() mutating the w_list behind our back
        try:
            i = self.find(w_value, 0, sys.maxint)
        except ValueError:
            raise oefmt(space.w_ValueError,
                        "list.remove(): %R is not in list", w_value)
        if i < self.length():  # otherwise list was mutated
            self.pop(i)

    @unwrap_spec(w_start=WrappedDefault(0), w_stop=WrappedDefault(sys.maxint))
    def descr_index(self, space, w_value, w_start, w_stop):
        """L.index(value, [start, [stop]]) -> integer -- return first index of value.
Raises ValueError if the value is not present."""
        # needs to be safe against eq_w() mutating the w_list behind our back
        size = self.length()
        i, stop = unwrap_start_stop(space, size, w_start, w_stop)
        # note that 'i' and 'stop' can be bigger than the length of the list
        try:
            i = self.find(w_value, i, stop)
        except ValueError:
            raise oefmt(space.w_ValueError, "%R is not in list", w_value)
        return space.newint(i)

    @unwrap_spec(reverse=int)
    def descr_sort(self, space, w_key=None, reverse=False):
        """L.sort(key=None, reverse=False) -> None -- stable sort *IN PLACE*"""
        has_key = not space.is_none(w_key)

        # create and setup a TimSort instance
        if 0:
            # this was the old "if has_cmp" path. We didn't remove the
            # if not to diverge too much from default, to avoid spurious
            # conflicts
            pass
        else:
            if has_key:
                sorterclass = CustomKeySort
            else:
                if self.strategy is space.fromcache(ObjectListStrategy):
                    sorterclass = SimpleSort
                else:
                    self.sort(reverse)
                    return

        sorter = sorterclass(self.getitems(), self.length())
        sorter.space = space

        try:
            # The list is temporarily made empty, so that mutations performed
            # by comparison functions can't affect the slice of memory we're
            # sorting (allowing mutations during sorting is an IndexError or
            # core-dump factory, since the storage may change).
            self.__init__(space, [])

            # wrap each item in a KeyContainer if needed
            if has_key:
                for i in range(sorter.listlength):
                    w_item = sorter.list[i]
                    w_keyitem = space.call_function(w_key, w_item)
                    sorter.list[i] = KeyContainer(w_keyitem, w_item)

            # Reverse sort stability achieved by initially reversing the list,
            # applying a stable forward sort, then reversing the final result.
            if reverse:
                sorter.list.reverse()

            # perform the sort
            sorter.sort()

            # reverse again
            if reverse:
                sorter.list.reverse()

        finally:
            # unwrap each item if needed
            if has_key:
                for i in range(sorter.listlength):
                    w_obj = sorter.list[i]
                    if isinstance(w_obj, KeyContainer):
                        sorter.list[i] = w_obj.w_item

            # check if the user mucked with the list during the sort
            mucked = self.length() > 0

            # put the items back into the list
            self.__init__(space, sorter.list)

        if mucked:
            raise oefmt(space.w_ValueError, "list modified during sort")

def get_printable_location(strategy_type, tp):
    return "list.find [%s, %s]" % (strategy_type, tp.getname(tp.space), )
find_jmp = jit.JitDriver(greens=['strategy_type', 'tp'], reds='auto', name='list.find', get_printable_location=get_printable_location)

class ListStrategy(object):

    def __init__(self, space):
        self.space = space

    def get_sizehint(self):
        return -1

    def init_from_list_w(self, w_list, list_w):
        raise NotImplementedError

    def clone(self, w_list):
        raise NotImplementedError

    def copy_into(self, w_list, w_other):
        raise NotImplementedError

    def _resize_hint(self, w_list, hint):
        raise NotImplementedError

    def find(self, w_list, w_item, start, stop):
        space = self.space
        i = start
        # needs to be safe against eq_w mutating stuff
        tp = space.type(w_item)
        while i < stop and i < w_list.length():
            find_jmp.jit_merge_point(tp=tp, strategy_type=type(self))
            if space.eq_w(w_list.getitem(i), w_item):
                return i
            i += 1
        raise ValueError

    def length(self, w_list):
        raise NotImplementedError

    def getitem(self, w_list, index):
        raise NotImplementedError

    def getslice(self, w_list, start, stop, step, length):
        raise NotImplementedError

    def getitems(self, w_list):
        return self.getitems_copy(w_list)

    def getitems_copy(self, w_list):
        raise NotImplementedError

    def getitems_bytes(self, w_list):
        return None

    def getitems_ascii(self, w_list):
        return None

    def getitems_int(self, w_list):
        return None

    def getitems_float(self, w_list):
        return None

    def getstorage_copy(self, w_list):
        raise NotImplementedError

    def append(self, w_list, w_item):
        raise NotImplementedError

    def mul(self, w_list, times):
        w_newlist = w_list.clone()
        w_newlist.inplace_mul(times)
        return w_newlist

    def inplace_mul(self, w_list, times):
        raise NotImplementedError

    def deleteslice(self, w_list, start, step, slicelength):
        raise NotImplementedError

    def pop(self, w_list, index):
        raise NotImplementedError

    def pop_end(self, w_list):
        return self.pop(w_list, self.length(w_list) - 1)

    def setitem(self, w_list, index, w_item):
        raise NotImplementedError

    def setslice(self, w_list, start, step, slicelength, sequence_w):
        raise NotImplementedError

    def insert(self, w_list, index, w_item):
        raise NotImplementedError

    def extend(self, w_list, w_any):
        from pypy.objspace.std.tupleobject import W_AbstractTupleObject
        space = self.space
        if type(w_any) is W_ListObject or (isinstance(w_any, W_ListObject) and
                                           space._uses_list_iter(w_any)):
            self._extend_from_list(w_list, w_any)
        elif (isinstance(w_any, W_AbstractTupleObject) and
                not w_any.user_overridden_class and
                w_any.length() < UNROLL_CUTOFF
        ):
            self._extend_from_tuple(w_list, w_any.tolist())
        elif space.is_generator(w_any):
            w_any.unpack_into_w(w_list)
        else:
            self._extend_from_iterable(w_list, w_any)

    def _extend_from_list(self, w_list, w_other):
        raise NotImplementedError

    @jit.look_inside_iff(lambda self, w_list, tup_w:
            jit.loop_unrolling_heuristic(tup_w, len(tup_w), UNROLL_CUTOFF))
    def _extend_from_tuple(self, w_list, tup_w):
        try:
            newsize_hint = ovfcheck(w_list.length() + len(tup_w))
        except OverflowError:
            pass
        else:
            w_list._resize_hint(newsize_hint)
        for w_element in tup_w:
            w_list.append(w_element)

    def _extend_from_iterable(self, w_list, w_iterable):
        """Extend w_list from a generic iterable"""
        length_hint = self.space.length_hint(w_iterable, 0)
        if length_hint:
            try:
                newsize_hint = ovfcheck(w_list.length() + length_hint)
            except OverflowError:
                pass
            else:
                w_list._resize_hint(newsize_hint)

        extended = _do_extend_from_iterable(self.space, w_list, w_iterable)

        # cut back if the length hint was too large
        if extended < length_hint:
            w_list._resize_hint(w_list.length())

    def reverse(self, w_list):
        raise NotImplementedError

    def sort(self, w_list, reverse):
        raise NotImplementedError

    def is_empty_strategy(self):
        return False

    def physical_size(self, w_list):
        raise oefmt(self.space.w_ValueError, "can't get physical size of list")


class EmptyListStrategy(ListStrategy):
    """EmptyListStrategy is used when a W_List withouth elements is created.
    The storage is None. When items are added to the W_List a new RPython list
    is created and the strategy and storage of the W_List are changed depending
    to the added item.
    W_Lists do not switch back to EmptyListStrategy when becoming empty again.
    """

    def __init__(self, space):
        ListStrategy.__init__(self, space)

    def init_from_list_w(self, w_list, list_w):
        assert len(list_w) == 0
        w_list.lstorage = self.erase(None)

    def clear(self, w_list):
        w_list.lstorage = self.erase(None)

    erase, unerase = rerased.new_erasing_pair("empty")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def clone(self, w_list):
        return W_ListObject.from_storage_and_strategy(
                self.space, w_list.lstorage, self)

    def copy_into(self, w_list, w_other):
        pass

    def _resize_hint(self, w_list, hint):
        assert hint >= 0
        if hint:
            w_list.strategy = SizeListStrategy(self.space, hint)

    def find(self, w_list, w_item, start, stop):
        raise ValueError

    def length(self, w_list):
        return 0

    def getitem(self, w_list, index):
        raise IndexError

    def getslice(self, w_list, start, stop, step, length):
        # will never be called because the empty list case is already caught in
        # getslice__List_ANY_ANY and getitem__List_Slice
        return W_ListObject(self.space, [])

    def getitems(self, w_list):
        return []

    def getitems_copy(self, w_list):
        return []
    getitems_fixedsize = func_with_new_name(getitems_copy,
                                            "getitems_fixedsize")
    getitems_unroll = getitems_fixedsize

    def getstorage_copy(self, w_list):
        return self.erase(None)

    def switch_to_correct_strategy(self, w_list, w_item):
        if is_plain_int1(w_item):
            strategy = self.space.fromcache(IntegerListStrategy)
        elif type(w_item) is W_BytesObject:
            strategy = self.space.fromcache(BytesListStrategy)
        elif type(w_item) is W_UnicodeObject and w_item.is_ascii():
            strategy = self.space.fromcache(AsciiListStrategy)
        elif type(w_item) is W_FloatObject:
            strategy = self.space.fromcache(FloatListStrategy)
        else:
            strategy = self.space.fromcache(ObjectListStrategy)

        storage = strategy.get_empty_storage(self.get_sizehint())
        w_list.strategy = strategy
        w_list.lstorage = storage

    def append(self, w_list, w_item):
        self.switch_to_correct_strategy(w_list, w_item)
        w_list.append(w_item)

    def inplace_mul(self, w_list, times):
        return

    def deleteslice(self, w_list, start, step, slicelength):
        pass

    def pop(self, w_list, index):
        # will not be called because IndexError was already raised in
        # list_pop__List_ANY
        raise IndexError

    def setitem(self, w_list, index, w_item):
        raise IndexError

    def setslice(self, w_list, start, step, slicelength, w_other):
        strategy = w_other.strategy
        if step != 1:
            len2 = strategy.length(w_other)
            if len2 == 0:
                return
            else:
                raise oefmt(self.space.w_ValueError,
                            "attempt to assign sequence of size %d to extended "
                            "slice of size %d", len2, 0)
        storage = strategy.getstorage_copy(w_other)
        w_list.strategy = strategy
        w_list.lstorage = storage

    def sort(self, w_list, reverse):
        return

    def insert(self, w_list, index, w_item):
        assert index == 0
        self.append(w_list, w_item)

    def _extend_from_list(self, w_list, w_other):
        w_other.copy_into(w_list)

    def _extend_from_iterable(self, w_list, w_iterable):
        space = self.space
        if (isinstance(w_iterable, W_AbstractTupleObject)
                and space._uses_tuple_iter(w_iterable)):
            w_list.__init__(space, w_iterable.getitems_copy())
            return

        intlist = space.unpackiterable_int(w_iterable)
        if intlist is not None:
            w_list.strategy = strategy = space.fromcache(IntegerListStrategy)
            w_list.lstorage = strategy.erase(intlist)
            return

        floatlist = space.unpackiterable_float(w_iterable)
        if floatlist is not None:
            w_list.strategy = strategy = space.fromcache(FloatListStrategy)
            w_list.lstorage = strategy.erase(floatlist)
            return

        byteslist = space.listview_bytes(w_iterable)
        if byteslist is not None:
            w_list.strategy = strategy = space.fromcache(BytesListStrategy)
            # need to copy because intlist can share with w_iterable
            w_list.lstorage = strategy.erase(byteslist[:])
            return

        unilist = space.listview_ascii(w_iterable)
        if unilist is not None:
            w_list.strategy = strategy = space.fromcache(AsciiListStrategy)
            # need to copy because intlist can share with w_iterable
            w_list.lstorage = strategy.erase(unilist[:])
            return

        ListStrategy._extend_from_iterable(self, w_list, w_iterable)

    def reverse(self, w_list):
        pass

    def is_empty_strategy(self):
        return True

    def physical_size(self, w_list):
        return 0


class SizeListStrategy(EmptyListStrategy):
    """Like empty, but when modified it'll preallocate the size to sizehint."""
    def __init__(self, space, sizehint):
        self.sizehint = sizehint
        ListStrategy.__init__(self, space)

    def get_sizehint(self):
        return self.sizehint

    def _resize_hint(self, w_list, hint):
        assert hint >= 0
        self.sizehint = hint


class BaseRangeListStrategy(ListStrategy):
    def switch_to_integer_strategy(self, w_list):
        items = self._getitems_range(w_list, False)
        strategy = w_list.strategy = self.space.fromcache(IntegerListStrategy)
        w_list.lstorage = strategy.erase(items)

    def wrap(self, intval):
        return self.space.newint(intval)

    def unwrap(self, w_int):
        return plain_int_w(self.space, w_int)

    def init_from_list_w(self, w_list, list_w):
        raise NotImplementedError

    def clone(self, w_list):
        storage = w_list.lstorage  # lstorage is tuple, no need to clone
        w_clone = W_ListObject.from_storage_and_strategy(self.space, storage,
                                                         self)
        return w_clone

    def _resize_hint(self, w_list, hint):
        # XXX: this could be supported
        assert hint >= 0

    def copy_into(self, w_list, w_other):
        w_other.strategy = self
        w_other.lstorage = w_list.lstorage

    def getitem(self, w_list, i):
        return self.wrap(self._getitem_unwrapped(w_list, i))

    def getitems_int(self, w_list):
        return self._getitems_range(w_list, False)

    def getitems_copy(self, w_list):
        return self._getitems_range(w_list, True)

    def getstorage_copy(self, w_list):
        # tuple is immutable
        return w_list.lstorage

    @jit.dont_look_inside
    def getitems_fixedsize(self, w_list):
        return self._getitems_range_unroll(w_list, True)

    def getitems_unroll(self, w_list):
        return self._getitems_range_unroll(w_list, True)

    def getslice(self, w_list, start, stop, step, length):
        self.switch_to_integer_strategy(w_list)
        return w_list.getslice(start, stop, step, length)

    def append(self, w_list, w_item):
        if is_plain_int1(w_item):
            self.switch_to_integer_strategy(w_list)
        else:
            w_list.switch_to_object_strategy()
        w_list.append(w_item)

    def inplace_mul(self, w_list, times):
        self.switch_to_integer_strategy(w_list)
        w_list.inplace_mul(times)

    def deleteslice(self, w_list, start, step, slicelength):
        self.switch_to_integer_strategy(w_list)
        w_list.deleteslice(start, step, slicelength)

    def setitem(self, w_list, index, w_item):
        self.switch_to_integer_strategy(w_list)
        w_list.setitem(index, w_item)

    def setslice(self, w_list, start, step, slicelength, sequence_w):
        self.switch_to_integer_strategy(w_list)
        w_list.setslice(start, step, slicelength, sequence_w)

    def insert(self, w_list, index, w_item):
        self.switch_to_integer_strategy(w_list)
        w_list.insert(index, w_item)

    def extend(self, w_list, w_any):
        self.switch_to_integer_strategy(w_list)
        w_list.extend(w_any)

    def reverse(self, w_list):
        self.switch_to_integer_strategy(w_list)
        w_list.reverse()

    def sort(self, w_list, reverse):
        step = self.step(w_list)
        if step > 0 and reverse or step < 0 and not reverse:
            self.switch_to_integer_strategy(w_list)
            w_list.sort(reverse)


class SimpleRangeListStrategy(BaseRangeListStrategy):
    """SimpleRangeListStrategy is used when a list is created using the range
       method providing only positive length. The storage is a one element tuple
       with positive integer storing length."""

    erase, unerase = rerased.new_erasing_pair("simple_range")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def find(self, w_list, w_obj, startindex, stopindex):
        if is_plain_int1(w_obj):
            obj = self.unwrap(w_obj)
            length = self.unerase(w_list.lstorage)[0]
            if 0 <= obj < length and startindex <= obj < stopindex:
                return obj
            else:
                raise ValueError
        return ListStrategy.find(self, w_list, w_obj, startindex, stopindex)

    def length(self, w_list):
        return self.unerase(w_list.lstorage)[0]

    def step(self, w_list):
        return 1

    def _getitem_unwrapped(self, w_list, i):
        length = self.unerase(w_list.lstorage)[0]
        if i < 0:
            i += length
            if i < 0:
                raise IndexError
        elif i >= length:
            raise IndexError
        return i

    @specialize.arg(2)
    def _getitems_range(self, w_list, wrap_items):
        length = self.unerase(w_list.lstorage)[0]
        if wrap_items:
            r = [None] * length
        else:
            r = [0] * length
        i = 0
        while i < length:
            if wrap_items:
                r[i] = self.wrap(i)
            else:
                r[i] = i
            i += 1

        return r

    _getitems_range_unroll = jit.unroll_safe(
            func_with_new_name(_getitems_range, "_getitems_range_unroll"))

    def pop_end(self, w_list):
        new_length = self.unerase(w_list.lstorage)[0] - 1
        w_result = self.wrap(new_length)
        if new_length > 0:
            w_list.lstorage = self.erase((new_length,))
        else:
            strategy = w_list.strategy = self.space.fromcache(EmptyListStrategy)
            w_list.lstorage = strategy.erase(None)
        return w_result

    def pop(self, w_list, index):
        self.switch_to_integer_strategy(w_list)
        return w_list.pop(index)


class RangeListStrategy(BaseRangeListStrategy):
    """RangeListStrategy is used when a list is created using the range method.
    The storage is a tuple containing only three integers start, step and
    length and elements are calculated based on these values.  On any operation
    destroying the range (inserting, appending non-ints) the strategy is
    switched to IntegerListStrategy."""

    erase, unerase = rerased.new_erasing_pair("range")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def find(self, w_list, w_obj, startindex, stopindex):
        if is_plain_int1(w_obj):
            obj = self.unwrap(w_obj)
            start, step, length = self.unerase(w_list.lstorage)
            if ((step > 0 and start <= obj <= start + (length - 1) * step and
                 (start - obj) % step == 0) or
                (step < 0 and start + (length - 1) * step <= obj <= start and
                 (start - obj) % step == 0)):
                index = (obj - start) // step
            else:
                raise ValueError
            if startindex <= index < stopindex:
                return index
            raise ValueError
        return ListStrategy.find(self, w_list, w_obj, startindex, stopindex)

    def length(self, w_list):
        return self.unerase(w_list.lstorage)[2]

    def step(self, w_list):
        return self.unerase(w_list.lstorage)[1]

    def _getitem_unwrapped(self, w_list, i):
        v = self.unerase(w_list.lstorage)
        start = v[0]
        step = v[1]
        length = v[2]
        if i < 0:
            i += length
            if i < 0:
                raise IndexError
        elif i >= length:
            raise IndexError
        return start + i * step

    @specialize.arg(2)
    def _getitems_range(self, w_list, wrap_items):
        l = self.unerase(w_list.lstorage)
        start = l[0]
        step = l[1]
        length = l[2]
        if wrap_items:
            r = [None] * length
        else:
            r = [0] * length
        i = start
        n = 0
        while n < length:
            if wrap_items:
                r[n] = self.wrap(i)
            else:
                r[n] = i
            i += step
            n += 1

        return r

    _getitems_range_unroll = jit.unroll_safe(
            func_with_new_name(_getitems_range, "_getitems_range_unroll"))

    def pop_end(self, w_list):
        start, step, length = self.unerase(w_list.lstorage)
        w_result = self.wrap(start + (length - 1) * step)
        new = self.erase((start, step, length - 1))
        w_list.lstorage = new
        return w_result

    def pop(self, w_list, index):
        l = self.unerase(w_list.lstorage)
        start = l[0]
        step = l[1]
        length = l[2]
        if index == 0:
            w_result = self.wrap(start)
            new = self.erase((start + step, step, length - 1))
            w_list.lstorage = new
            return w_result
        elif index == length - 1:
            return self.pop_end(w_list)
        else:
            self.switch_to_integer_strategy(w_list)
            return w_list.pop(index)


class AbstractUnwrappedStrategy(object):

    def wrap(self, unwrapped):
        raise NotImplementedError

    def unwrap(self, wrapped):
        raise NotImplementedError

    def _quick_cmp(self, a, b):
        """ do a quick comparison between two unwrapped elements. """
        raise NotImplementedError("abstract base class")

    @staticmethod
    def unerase(storage):
        raise NotImplementedError("abstract base class")

    @staticmethod
    def erase(obj):
        raise NotImplementedError("abstract base class")

    def is_correct_type(self, w_obj):
        raise NotImplementedError("abstract base class")

    def list_is_correct_type(self, w_list):
        raise NotImplementedError("abstract base class")

    @jit.look_inside_iff(lambda space, w_list, list_w:
            jit.loop_unrolling_heuristic(list_w, len(list_w), UNROLL_CUTOFF))
    def init_from_list_w(self, w_list, list_w):
        l = [self.unwrap(w_item) for w_item in list_w]
        w_list.lstorage = self.erase(l)

    def get_empty_storage(self, sizehint):
        if sizehint == -1:
            return self.erase([])
        return self.erase(newlist_hint(sizehint))

    def clone(self, w_list):
        l = self.unerase(w_list.lstorage)
        storage = self.erase(l[:])
        w_clone = W_ListObject.from_storage_and_strategy(
                self.space, storage, self)
        return w_clone

    def _resize_hint(self, w_list, hint):
        resizelist_hint(self.unerase(w_list.lstorage), hint)

    def copy_into(self, w_list, w_other):
        w_other.strategy = self
        items = self.unerase(w_list.lstorage)[:]
        w_other.lstorage = self.erase(items)

    def find(self, w_list, w_obj, start, stop):
        if self.is_correct_type(w_obj):
            return self._safe_find(w_list, self.unwrap(w_obj), start, stop)
        return ListStrategy.find(self, w_list, w_obj, start, stop)

    def _safe_find(self, w_list, obj, start, stop):
        l = self.unerase(w_list.lstorage)
        for i in range(start, min(stop, len(l))):
            val = l[i]
            if val == obj:
                return i
        raise ValueError

    def length(self, w_list):
        return len(self.unerase(w_list.lstorage))

    def getitem(self, w_list, index):
        l = self.unerase(w_list.lstorage)
        try:
            r = l[index]
        except IndexError:  # make RPython raise the exception
            raise
        return self.wrap(r)

    def getitems_copy(self, w_list):
        storage = self.unerase(w_list.lstorage)
        if len(storage) == 0:
            return []
        res = [None] * len(storage)
        prevvalue = storage[0]
        w_item = self.wrap(prevvalue)
        res[0] = w_item
        for index in range(1, len(storage)):
            item = storage[index]
            if jit.we_are_jitted() or not self._quick_cmp(item, prevvalue):
                prevvalue = item
                w_item = self.wrap(item)
            res[index] = w_item
        return res

    getitems_unroll = jit.unroll_safe(
            func_with_new_name(getitems_copy, "getitems_unroll"))

    getitems_copy = jit.look_inside_iff(lambda self, w_list:
            jit.loop_unrolling_heuristic(w_list, w_list.length(),
                                         UNROLL_CUTOFF))(getitems_copy)


    @jit.look_inside_iff(lambda self, w_list:
            jit.loop_unrolling_heuristic(w_list, w_list.length(),
                                         UNROLL_CUTOFF))
    def getitems_fixedsize(self, w_list):
        return self.getitems_unroll(w_list)

    def getstorage_copy(self, w_list):
        items = self.unerase(w_list.lstorage)[:]
        return self.erase(items)

    def getslice(self, w_list, start, stop, step, length):
        if step == 1 and 0 <= start <= stop:
            l = self.unerase(w_list.lstorage)
            assert start >= 0
            assert stop >= 0
            sublist = l[start:stop]
            storage = self.erase(sublist)
            return W_ListObject.from_storage_and_strategy(
                    self.space, storage, self)
        else:
            subitems_w = [self._none_value] * length
            l = self.unerase(w_list.lstorage)
            self._fill_in_with_sliced_items(subitems_w, l, start, step, length)
            storage = self.erase(subitems_w)
            return W_ListObject.from_storage_and_strategy(
                    self.space, storage, self)

    def _fill_in_with_sliced_items(self, subitems_w, l, start, step, length):
        for i in range(length):
            try:
                subitems_w[i] = l[start]
                start += step
            except IndexError:
                raise

    def switch_to_next_strategy(self, w_list, w_sample_item):
        w_list.switch_to_object_strategy()

    def append(self, w_list, w_item):
        if self.is_correct_type(w_item):
            self.unerase(w_list.lstorage).append(self.unwrap(w_item))
            return

        self.switch_to_next_strategy(w_list, w_item)
        w_list.append(w_item)

    def insert(self, w_list, index, w_item):
        l = self.unerase(w_list.lstorage)

        if self.is_correct_type(w_item):
            l.insert(index, self.unwrap(w_item))
            return

        self.switch_to_next_strategy(w_list, w_item)
        w_list.insert(index, w_item)

    def _extend_from_list(self, w_list, w_other):
        l = self.unerase(w_list.lstorage)
        if self.list_is_correct_type(w_other):
            l += self.unerase(w_other.lstorage)
            return
        elif w_other.strategy.is_empty_strategy():
            return

        w_other = w_other._temporarily_as_objects()
        w_list.switch_to_object_strategy()
        w_list.extend(w_other)

    def setitem(self, w_list, index, w_item):
        l = self.unerase(w_list.lstorage)

        if self.is_correct_type(w_item):
            try:
                l[index] = self.unwrap(w_item)
            except IndexError:
                raise
        else:
            self.switch_to_next_strategy(w_list, w_item)
            w_list.setitem(index, w_item)

    def setslice(self, w_list, start, step, slicelength, w_other):
        assert slicelength >= 0
        space = self.space

        if self is space.fromcache(ObjectListStrategy):
            w_other = w_other._temporarily_as_objects()
        elif not self.list_is_correct_type(w_other) and w_other.length() != 0:
            w_list.switch_to_object_strategy()
            w_other_as_object = w_other._temporarily_as_objects()
            assert (w_other_as_object.strategy is
                    space.fromcache(ObjectListStrategy))
            w_list.setslice(start, step, slicelength, w_other_as_object)
            return

        items = self.unerase(w_list.lstorage)
        oldsize = len(items)
        len2 = w_other.length()
        if step == 1:  # Support list resizing for non-extended slices
            delta = slicelength - len2
            if delta < 0:
                delta = -delta
                newsize = oldsize + delta
                # XXX support this in rlist!
                items += [self._none_value] * delta
                lim = start + len2
                i = newsize - 1
                while i >= lim:
                    items[i] = items[i - delta]
                    i -= 1
            elif delta == 0:
                pass
            else:
                # start < 0 is only possible with slicelength == 0
                assert start >= 0
                del items[start:start + delta]
        elif len2 != slicelength:  # No resize for extended slices
            raise oefmt(space.w_ValueError,
                        "attempt to assign sequence of size %d to extended "
                        "slice of size %d", len2, slicelength)

        if len2 == 0:
            other_items = []
        else:
            # at this point both w_list and w_other have the same type, so
            # self.unerase is valid for both of them
            other_items = self.unerase(w_other.lstorage)
        if other_items is items:
            if step > 0:
                # Always copy starting from the right to avoid
                # having to make a shallow copy in the case where
                # the source and destination lists are the same list.
                i = len2 - 1
                start += i * step
                while i >= 0:
                    items[start] = other_items[i]
                    start -= step
                    i -= 1
                return
            else:
                # other_items is items and step is < 0, therefore:
                assert step == -1
                items.reverse()
                return
                #other_items = list(other_items)
        for i in range(len2):
            items[start] = other_items[i]
            start += step

    def deleteslice(self, w_list, start, step, slicelength):
        items = self.unerase(w_list.lstorage)
        if slicelength == 0:
            return

        if step < 0:
            start = start + step * (slicelength - 1)
            step = -step

        if step == 1:
            assert start >= 0
            if slicelength > 0:
                del items[start:start + slicelength]
        else:
            n = len(items)
            i = start

            for discard in range(1, slicelength):
                j = i + 1
                i += step
                while j < i:
                    items[j - discard] = items[j]
                    j += 1

            j = i + 1
            while j < n:
                items[j - slicelength] = items[j]
                j += 1
            start = n - slicelength
            assert start >= 0  # annotator hint
            del items[start:]

    def pop_end(self, w_list):
        l = self.unerase(w_list.lstorage)
        return self.wrap(l.pop())

    def pop(self, w_list, index):
        l = self.unerase(w_list.lstorage)
        # not sure if RPython raises IndexError on pop
        # so check again here
        if index < 0:
            raise IndexError
        try:
            item = l.pop(index)
        except IndexError:
            raise

        w_item = self.wrap(item)
        return w_item

    def mul(self, w_list, times):
        l = self.unerase(w_list.lstorage)
        return W_ListObject.from_storage_and_strategy(
            self.space, self.erase(l * times), self)

    def inplace_mul(self, w_list, times):
        l = self.unerase(w_list.lstorage)
        l *= times

    def reverse(self, w_list):
        self.unerase(w_list.lstorage).reverse()

    def physical_size(self, w_list):
        from rpython.rlib.objectmodel import list_get_physical_size
        l = self.unerase(w_list.lstorage)
        return list_get_physical_size(l)


class ObjectListStrategy(ListStrategy):
    import_from_mixin(AbstractUnwrappedStrategy)

    _none_value = None

    def unwrap(self, w_obj):
        return w_obj

    def wrap(self, item):
        return item

    def _quick_cmp(self, a, b):
        return a is b

    erase, unerase = rerased.new_erasing_pair("object")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    @jit.look_inside_iff(lambda self, w_list:
            jit.loop_unrolling_heuristic(w_list, w_list.length(),
                                         UNROLL_CUTOFF))
    def getitems_copy(self, w_list):
        storage = self.unerase(w_list.lstorage)
        return storage[:]

    @jit.unroll_safe
    def getitems_unroll(self, w_list):
        storage = self.unerase(w_list.lstorage)
        return storage[:]

    def is_correct_type(self, w_obj):
        return True

    def list_is_correct_type(self, w_list):
        return w_list.strategy is self.space.fromcache(ObjectListStrategy)

    def init_from_list_w(self, w_list, list_w):
        w_list.lstorage = self.erase(list_w)

    def clear(self, w_list):
        w_list.lstorage = self.erase([])

    def find(self, w_list, w_obj, start, stop):
        return ListStrategy.find(self, w_list, w_obj, start, stop)

    def getitems(self, w_list):
        return self.unerase(w_list.lstorage)

    # no sort() method here: W_ListObject.descr_sort() handles this
    # case explicitly


class IntegerListStrategy(ListStrategy):
    import_from_mixin(AbstractUnwrappedStrategy)

    _none_value = 0

    def wrap(self, intval):
        return self.space.newint(intval)

    def unwrap(self, w_int):
        return plain_int_w(self.space, w_int)

    def _quick_cmp(self, a, b):
        return a == b

    erase, unerase = rerased.new_erasing_pair("integer")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def is_correct_type(self, w_obj):
        return is_plain_int1(w_obj)

    def list_is_correct_type(self, w_list):
        return w_list.strategy is self.space.fromcache(IntegerListStrategy)

    def sort(self, w_list, reverse):
        l = self.unerase(w_list.lstorage)
        sorter = IntSort(l, len(l))
        sorter.sort()
        if reverse:
            l.reverse()

    def getitems_int(self, w_list):
        return self.unerase(w_list.lstorage)


    _base_extend_from_list = _extend_from_list

    def _extend_from_list(self, w_list, w_other):
        if isinstance(w_other.strategy, BaseRangeListStrategy):
            l = self.unerase(w_list.lstorage)
            other = w_other.getitems_int()
            assert other is not None
            l += other
            return
        if (w_other.strategy is self.space.fromcache(FloatListStrategy) or
            w_other.strategy is self.space.fromcache(IntOrFloatListStrategy)):
            if self.switch_to_int_or_float_strategy(w_list):
                w_list.extend(w_other)
                return
        return self._base_extend_from_list(w_list, w_other)


    _base_setslice = setslice

    def setslice(self, w_list, start, step, slicelength, w_other):
        if w_other.strategy is self.space.fromcache(RangeListStrategy):
            storage = self.erase(w_other.getitems_int())
            w_other = W_ListObject.from_storage_and_strategy(
                    self.space, storage, self)
        if (w_other.strategy is self.space.fromcache(FloatListStrategy) or
            w_other.strategy is self.space.fromcache(IntOrFloatListStrategy)):
            if self.switch_to_int_or_float_strategy(w_list):
                w_list.setslice(start, step, slicelength, w_other)
                return
        return self._base_setslice(w_list, start, step, slicelength, w_other)


    @staticmethod
    def int_2_float_or_int(w_list):
        l = IntegerListStrategy.unerase(w_list.lstorage)
        if not longlong2float.CAN_ALWAYS_ENCODE_INT32:
            for intval in l:
                if not longlong2float.can_encode_int32(intval):
                    raise ValueError
        return [longlong2float.encode_int32_into_longlong_nan(intval)
                for intval in l]

    def switch_to_int_or_float_strategy(self, w_list):
        try:
            generalized_list = self.int_2_float_or_int(w_list)
        except ValueError:
            return False
        strategy = self.space.fromcache(IntOrFloatListStrategy)
        w_list.strategy = strategy
        w_list.lstorage = strategy.erase(generalized_list)
        return True

    def switch_to_next_strategy(self, w_list, w_sample_item):
        if type(w_sample_item) is W_FloatObject:
            if self.switch_to_int_or_float_strategy(w_list):
                # yes, we can switch to IntOrFloatListStrategy
                # (ignore here the extremely unlikely case where
                # w_sample_item is just the wrong nonstandard NaN float;
                # it will caught later and yet another switch will occur)
                return
        # no, fall back to ObjectListStrategy
        w_list.switch_to_object_strategy()


class FloatListStrategy(ListStrategy):
    import_from_mixin(AbstractUnwrappedStrategy)

    _none_value = 0.0

    def wrap(self, floatval):
        return self.space.newfloat(floatval)

    def unwrap(self, w_float):
        return self.space.float_w(w_float)

    erase, unerase = rerased.new_erasing_pair("float")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def _quick_cmp(self, a, b):
        return longlong2float.float2longlong(a) == longlong2float.float2longlong(b)

    def is_correct_type(self, w_obj):
        return type(w_obj) is W_FloatObject

    def list_is_correct_type(self, w_list):
        return w_list.strategy is self.space.fromcache(FloatListStrategy)

    def sort(self, w_list, reverse):
        l = self.unerase(w_list.lstorage)
        sorter = FloatSort(l, len(l))
        sorter.sort()
        if reverse:
            l.reverse()

    def getitems_float(self, w_list):
        return self.unerase(w_list.lstorage)


    _base_extend_from_list = _extend_from_list

    def _extend_from_list(self, w_list, w_other):
        if (w_other.strategy is self.space.fromcache(IntegerListStrategy) or
            w_other.strategy is self.space.fromcache(IntOrFloatListStrategy)):
            # xxx a case that we don't optimize: [3.4].extend([9999999999999])
            # will cause a switch to int-or-float, followed by another
            # switch to object
            if self.switch_to_int_or_float_strategy(w_list):
                w_list.extend(w_other)
                return
        return self._base_extend_from_list(w_list, w_other)


    _base_setslice = setslice

    def setslice(self, w_list, start, step, slicelength, w_other):
        if (w_other.strategy is self.space.fromcache(IntegerListStrategy) or
            w_other.strategy is self.space.fromcache(IntOrFloatListStrategy)):
            if self.switch_to_int_or_float_strategy(w_list):
                w_list.setslice(start, step, slicelength, w_other)
                return
        return self._base_setslice(w_list, start, step, slicelength, w_other)


    def _safe_find(self, w_list, obj, start, stop):
        l = self.unerase(w_list.lstorage)
        stop = min(stop, len(l))
        if not math.isnan(obj):
            for i in range(start, stop):
                val = l[i]
                if val == obj:
                    return i
        else:
            search = longlong2float.float2longlong(obj)
            for i in range(start, stop):
                val = l[i]
                if longlong2float.float2longlong(val) == search:
                    return i
        raise ValueError

    @staticmethod
    def float_2_float_or_int(w_list):
        l = FloatListStrategy.unerase(w_list.lstorage)
        generalized_list = []
        for floatval in l:
            if not longlong2float.can_encode_float(floatval):
                raise ValueError
            generalized_list.append(
                longlong2float.float2longlong(floatval))
        return generalized_list

    def switch_to_int_or_float_strategy(self, w_list):
        # xxx we should be able to use the same lstorage, but
        # there is a typing issue (float vs longlong)...
        try:
            generalized_list = self.float_2_float_or_int(w_list)
        except ValueError:
            return False
        strategy = self.space.fromcache(IntOrFloatListStrategy)
        w_list.strategy = strategy
        w_list.lstorage = strategy.erase(generalized_list)
        return True

    def switch_to_next_strategy(self, w_list, w_sample_item):
        if is_plain_int1(w_sample_item):
            sample_intval = plain_int_w(self.space, w_sample_item)
            if longlong2float.can_encode_int32(sample_intval):
                if self.switch_to_int_or_float_strategy(w_list):
                    # yes, we can switch to IntOrFloatListStrategy
                    return
        # no, fall back to ObjectListStrategy
        w_list.switch_to_object_strategy()


class IntOrFloatListStrategy(ListStrategy):
    import_from_mixin(AbstractUnwrappedStrategy)

    _none_value = longlong2float.float2longlong(0.0)

    def wrap(self, llval):
        if longlong2float.is_int32_from_longlong_nan(llval):
            intval = longlong2float.decode_int32_from_longlong_nan(llval)
            return self.space.newint(intval)
        else:
            floatval = longlong2float.longlong2float(llval)
            return self.space.newfloat(floatval)

    def unwrap(self, w_int_or_float):
        if is_plain_int1(w_int_or_float):
            intval = plain_int_w(self.space, w_int_or_float)
            return longlong2float.encode_int32_into_longlong_nan(intval)
        else:
            floatval = self.space.float_w(w_int_or_float)
            return longlong2float.float2longlong(floatval)

    def _quick_cmp(self, a, b):
        return a == b

    erase, unerase = rerased.new_erasing_pair("longlong")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def is_correct_type(self, w_obj):
        if is_plain_int1(w_obj):
            intval = plain_int_w(self.space, w_obj)
            return longlong2float.can_encode_int32(intval)
        elif type(w_obj) is W_FloatObject:
            floatval = self.space.float_w(w_obj)
            return longlong2float.can_encode_float(floatval)
        else:
            return False

    def list_is_correct_type(self, w_list):
        return w_list.strategy is self.space.fromcache(IntOrFloatListStrategy)

    def sort(self, w_list, reverse):
        l = self.unerase(w_list.lstorage)
        sorter = IntOrFloatSort(l, len(l))
        # Reverse sort stability achieved by initially reversing the list,
        # applying a stable forward sort, then reversing the final result.
        if reverse:
            l.reverse()
        sorter.sort()
        if reverse:
            l.reverse()

    _base_extend_from_list = _extend_from_list

    def _extend_longlong(self, w_list, longlong_list):
        l = self.unerase(w_list.lstorage)
        l += longlong_list

    def _extend_from_list(self, w_list, w_other):
        if w_other.strategy is self.space.fromcache(IntegerListStrategy):
            try:
                longlong_list = IntegerListStrategy.int_2_float_or_int(w_other)
            except ValueError:
                pass
            else:
                return self._extend_longlong(w_list, longlong_list)
        if w_other.strategy is self.space.fromcache(FloatListStrategy):
            try:
                longlong_list = FloatListStrategy.float_2_float_or_int(w_other)
            except ValueError:
                pass
            else:
                return self._extend_longlong(w_list, longlong_list)
        return self._base_extend_from_list(w_list, w_other)

    _base_setslice = setslice

    def _temporary_longlong_list(self, longlong_list):
        storage = self.erase(longlong_list)
        return W_ListObject.from_storage_and_strategy(self.space, storage, self)

    def setslice(self, w_list, start, step, slicelength, w_other):
        if w_other.strategy is self.space.fromcache(IntegerListStrategy):
            try:
                longlong_list = IntegerListStrategy.int_2_float_or_int(w_other)
            except ValueError:
                pass
            else:
                w_other = self._temporary_longlong_list(longlong_list)
        elif w_other.strategy is self.space.fromcache(FloatListStrategy):
            try:
                longlong_list = FloatListStrategy.float_2_float_or_int(w_other)
            except ValueError:
                pass
            else:
                w_other = self._temporary_longlong_list(longlong_list)
        return self._base_setslice(w_list, start, step, slicelength, w_other)

    def _safe_find(self, w_list, obj, start, stop):
        l = self.unerase(w_list.lstorage)
        # careful: we must consider that 0.0 == -0.0 == 0, but also
        # NaN == NaN if they have the same bit pattern.
        fobj = longlong2float.maybe_decode_longlong_as_float(obj)
        for i in range(start, min(stop, len(l))):
            llval = l[i]
            if llval == obj:     # equal as longlongs: includes NaN == NaN
                return i
            fval = longlong2float.maybe_decode_longlong_as_float(llval)
            if fval == fobj:     # cases like 0.0 == -0.0 or 42 == 42.0
                return i
        raise ValueError


class BytesListStrategy(ListStrategy):
    import_from_mixin(AbstractUnwrappedStrategy)

    _none_value = ""

    def wrap(self, stringval):
        return self.space.newbytes(stringval)

    def unwrap(self, w_string):
        return self.space.bytes_w(w_string)

    def _quick_cmp(self, a, b):
        return a is b

    erase, unerase = rerased.new_erasing_pair("bytes")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def is_correct_type(self, w_obj):
        return type(w_obj) is W_BytesObject

    def list_is_correct_type(self, w_list):
        return w_list.strategy is self.space.fromcache(BytesListStrategy)

    def sort(self, w_list, reverse):
        l = self.unerase(w_list.lstorage)
        sorter = StringSort(l, len(l))
        sorter.sort()
        if reverse:
            l.reverse()

    def getitems_bytes(self, w_list):
        return self.unerase(w_list.lstorage)


class AsciiListStrategy(ListStrategy):
    import_from_mixin(AbstractUnwrappedStrategy)

    _none_value = ""

    def wrap(self, stringval):
        assert stringval is not None
        return self.space.newutf8(stringval, len(stringval))

    def unwrap(self, w_string):
        return self.space.utf8_w(w_string)

    def _quick_cmp(self, a, b):
        return a is b

    erase, unerase = rerased.new_erasing_pair("unicode")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def is_correct_type(self, w_obj):
        return type(w_obj) is W_UnicodeObject and w_obj.is_ascii()

    def list_is_correct_type(self, w_list):
        return w_list.strategy is self.space.fromcache(AsciiListStrategy)

    def sort(self, w_list, reverse):
        l = self.unerase(w_list.lstorage)
        sorter = StringSort(l, len(l))
        sorter.sort()
        if reverse:
            l.reverse()

    def getitems_ascii(self, w_list):
        return self.unerase(w_list.lstorage)


def is_plain_int1(w_obj):
    return (type(w_obj) is W_IntObject or
            (type(w_obj) is W_LongObject and w_obj._fits_int()))

def plain_int_w(space, w_obj):
    # like space.int_w(w_obj, allow_conversion=False).  Meant to be
    # used only for objects for which is_plain_int1() returned True;
    # for that use case it should never raise.
    return w_obj._int_w(space)

# _______________________________________________________

init_signature = Signature(['sequence'], posonlyargcount=1)
init_defaults = [None]

app = applevel("""
    def listrepr(currently_in_repr, l):
        'The app-level part of repr().'
        if l in currently_in_repr:
            return '[...]'
        currently_in_repr[l] = 1
        try:
            return "[" + ", ".join([repr(x) for x in l]) + ']'
        finally:
            try:
                del currently_in_repr[l]
            except:
                pass
""", filename=__file__)

listrepr = app.interphook("listrepr")

# ____________________________________________________________
# Sorting

# Reverse a slice of a list in place, from lo up to (exclusive) hi.
# (used in sort)

TimSort = make_timsort_class()
IntBaseTimSort = make_timsort_class()
FloatBaseTimSort = make_timsort_class()
IntOrFloatBaseTimSort = make_timsort_class()


class KeyContainer(W_Root):
    def __init__(self, w_key, w_item):
        self.w_key = w_key
        self.w_item = w_item


# NOTE: all the subclasses of TimSort should inherit from a common subclass,
#       so make sure that only SimpleSort inherits directly from TimSort.
#       This is necessary to hide the parent method TimSort.lt() from the
#       annotator.
class SimpleSort(TimSort):
    def lt(self, a, b):
        space = self.space
        return space.is_true(space.lt(a, b))


class IntSort(IntBaseTimSort):
    def lt(self, a, b):
        return a < b


class FloatSort(FloatBaseTimSort):
    def lt(self, a, b):
        return a < b


class IntOrFloatSort(IntOrFloatBaseTimSort):
    def lt(self, a, b):
        fa = longlong2float.maybe_decode_longlong_as_float(a)
        fb = longlong2float.maybe_decode_longlong_as_float(b)
        return fa < fb


class CustomCompareSort(SimpleSort):
    def lt(self, a, b):
        space = self.space
        w_cmp = self.w_cmp
        w_result = space.call_function(w_cmp, a, b)
        try:
            result = space.int_w(w_result)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                raise oefmt(space.w_TypeError,
                            "comparison function must return int")
            raise
        return result < 0


class CustomKeySort(SimpleSort):
    def lt(self, a, b):
        assert isinstance(a, KeyContainer)
        assert isinstance(b, KeyContainer)
        space = self.space
        return space.is_true(space.lt(a.w_key, b.w_key))


W_ListObject.typedef = TypeDef("list",
    __doc__ = """list() -> new empty list
list(iterable) -> new list initialized from iterable's items""",
    __new__ = interp2app(W_ListObject.descr_new),
    __init__ = interp2app(W_ListObject.descr_init),
    __repr__ = interp2app(W_ListObject.descr_repr),
    __hash__ = None,

    __eq__ = interp2app(W_ListObject.descr_eq),
    __ne__ = interp2app(W_ListObject.descr_ne),
    __lt__ = interp2app(W_ListObject.descr_lt),
    __le__ = interp2app(W_ListObject.descr_le),
    __gt__ = interp2app(W_ListObject.descr_gt),
    __ge__ = interp2app(W_ListObject.descr_ge),

    __len__ = interp2app(W_ListObject.descr_len),
    __iter__ = interp2app(W_ListObject.descr_iter),
    __contains__ = interp2app(W_ListObject.descr_contains),

    __add__ = interp2app(W_ListObject.descr_add),
    __iadd__ = interp2app(W_ListObject.descr_inplace_add),
    __mul__ = interp2app(W_ListObject.descr_mul),
    __rmul__ = interp2app(W_ListObject.descr_mul),
    __imul__ = interp2app(W_ListObject.descr_inplace_mul),

    __getitem__ = interp2app(W_ListObject.descr_getitem),
    __setitem__ = interp2app(W_ListObject.descr_setitem),
    __delitem__ = interp2app(W_ListObject.descr_delitem),

    __class_getitem__ = interp2app(
        generic_alias_class_getitem, as_classmethod=True),

    sort = interp2app(W_ListObject.descr_sort),
    index = interp2app(W_ListObject.descr_index),
    copy = interp2app(W_ListObject.descr_copy),
    append = interp2app(W_ListObject.append),
    reverse = interp2app(W_ListObject.descr_reverse),
    __reversed__ = interp2app(W_ListObject.descr_reversed),
    count = interp2app(W_ListObject.descr_count),
    pop = interp2app(W_ListObject.descr_pop),
    clear = interp2app(W_ListObject.descr_clear),
    extend = interp2app(W_ListObject.extend),
    insert = interp2app(W_ListObject.descr_insert),
    remove = interp2app(W_ListObject.descr_remove),
)
W_ListObject.typedef.flag_sequence_bug_compat = True
