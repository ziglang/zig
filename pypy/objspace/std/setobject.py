from pypy.interpreter import gateway
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.signature import Signature
from pypy.interpreter.typedef import TypeDef
from pypy.objspace.std.bytesobject import W_BytesObject
from pypy.objspace.std.listobject import is_plain_int1, plain_int_w
from pypy.objspace.std.unicodeobject import W_UnicodeObject
from pypy.objspace.std.util import IDTAG_SPECIAL, IDTAG_SHIFT, \
    generic_alias_class_getitem

from rpython.rlib.objectmodel import r_dict
from rpython.rlib.objectmodel import iterkeys_with_hash, contains_with_hash
from rpython.rlib.objectmodel import setitem_with_hash, delitem_with_hash
from rpython.rlib.rarithmetic import intmask, r_uint
from rpython.rlib import rerased, jit, rutf8


UNROLL_CUTOFF = 5


class W_BaseSetObject(W_Root):
    typedef = None

    def __init__(self, space, w_iterable=None):
        """Initialize the set by taking ownership of 'setdata'."""
        self.space = space
        set_strategy_and_setdata(space, self, w_iterable)

    def __repr__(self):
        """representation for debugging purposes"""
        reprlist = [repr(w_item) for w_item in self.getkeys()]
        return "<%s(%s)(%s)>" % (self.__class__.__name__, self.strategy, ', '.join(reprlist))

    def from_storage_and_strategy(self, storage, strategy):
        obj = self._newobj(self.space, None)
        assert isinstance(obj, W_BaseSetObject)
        obj.strategy = strategy
        obj.sstorage = storage
        return obj

    _lifeline_ = None
    def getweakref(self):
        return self._lifeline_

    def setweakref(self, space, weakreflifeline):
        self._lifeline_ = weakreflifeline
    def delweakref(self):
        self._lifeline_ = None

    def switch_to_object_strategy(self, space):
        d = self.strategy.getdict_w(self)
        self.strategy = strategy = space.fromcache(ObjectSetStrategy)
        self.sstorage = strategy.erase(d)

    def switch_to_empty_strategy(self):
        self.strategy = strategy = self.space.fromcache(EmptySetStrategy)
        self.sstorage = strategy.get_empty_storage()

    # _____________ strategy methods ________________

    def clear(self):
        """ Removes all elements from the set. """
        self.strategy.clear(self)

    def copy_real(self):
        """ Returns a clone of the set. Frozensets storages are also copied."""
        return self.strategy.copy_real(self)

    def length(self):
        """ Returns the number of items inside the set. """
        return self.strategy.length(self)

    def add(self, w_key):
        """ Adds an element to the set. The element must be wrapped. """
        self.strategy.add(self, w_key)

    def remove(self, w_item):
        """ Removes the given element from the set. Element must be wrapped. """
        return self.strategy.remove(self, w_item)

    def getdict_w(self):
        """ Returns a dict with all elements of the set. Needed only for switching to ObjectSetStrategy. """
        return self.strategy.getdict_w(self)

    def listview_bytes(self):
        """ If this is a string set return its contents as a list of uwnrapped strings. Otherwise return None. """
        return self.strategy.listview_bytes(self)

    def listview_ascii(self):
        """ If this is a unicode set return its contents as a list of uwnrapped unicodes. Otherwise return None. """
        return self.strategy.listview_ascii(self)

    def listview_int(self):
        """ If this is an int set return its contents as a list of uwnrapped ints. Otherwise return None. """
        return self.strategy.listview_int(self)

    def get_storage_copy(self):
        """ Returns a copy of the storage. Needed when we want to clone all elements from one set and
        put them into another. """
        return self.strategy.get_storage_copy(self)

    def getkeys(self):
        """ Returns a list of all elements inside the set. Only used in __repr__. Use as less as possible."""
        return self.strategy.getkeys(self)

    def difference(self, w_other):
        """ Returns a set with all items that are in this set, but not in w_other. W_other must be a set."""
        return self.strategy.difference(self, w_other)

    def difference_update(self, w_other):
        """ As difference but overwrites the sets content with the result. W_other must be a set."""
        self.strategy.difference_update(self, w_other)

    def symmetric_difference(self, w_other):
        """ Returns a set with all items that are either in this set or in w_other, but not in both. W_other must be a set. """
        return self.strategy.symmetric_difference(self, w_other)

    def symmetric_difference_update(self, w_other):
        """ As symmetric_difference but overwrites the content of the set with the result. W_other must be a set."""
        self.strategy.symmetric_difference_update(self, w_other)

    def intersect(self, w_other):
        """ Returns a set with all items that exists in both sets, this set and in w_other. W_other must be a set. """
        return self.strategy.intersect(self, w_other)

    def intersect_update(self, w_other):
        """ Keeps only those elements found in both sets, removing all other elements. W_other must be a set."""
        self.strategy.intersect_update(self, w_other)

    def issubset(self, w_other):
        """ Checks wether this set is a subset of w_other. W_other must be a set. """
        return self.strategy.issubset(self, w_other)

    def isdisjoint(self, w_other):
        """ Checks wether this set and the w_other are completly different, i.e. have no equal elements. W_other must be a set."""
        return self.strategy.isdisjoint(self, w_other)

    def update(self, w_other):
        """ Appends all elements from the given set to this set. W_other must be a set."""
        self.strategy.update(self, w_other)

    def has_key(self, w_key):
        """ Checks wether this set contains the given wrapped key."""
        return self.strategy.has_key(self, w_key)

    def equals(self, w_other):
        """ Checks wether this set and the given set are equal, i.e. contain the same elements. W_other must be a set."""
        return self.strategy.equals(self, w_other)

    def iter(self):
        """ Returns an iterator of the elements from this set. """
        return self.strategy.iter(self)

    def popitem(self):
        """ Removes an arbitrary element from the set. May raise KeyError if set is empty."""
        return self.strategy.popitem(self)

    # app-level operations

    def descr_init(self, space, __args__):
        w_iterable, = __args__.parse_obj(
                None, 'set',
                init_signature,
                init_defaults)
        _initialize_set(space, self, w_iterable)

    def descr_repr(self, space):
        return setrepr(space, space.get_objects_in_repr(), self)

    def descr_eq(self, space, w_other):
        if isinstance(w_other, W_BaseSetObject):
            return space.newbool(self.equals(w_other))

        if not space.isinstance_w(w_other, space.w_set):
            return space.w_NotImplemented

        # XXX do not make new setobject here
        w_other_as_set = self._newobj(space, w_other)
        return space.newbool(self.equals(w_other_as_set))

    def descr_ne(self, space, w_other):
        if isinstance(w_other, W_BaseSetObject):
            return space.newbool(not self.equals(w_other))

        if not space.isinstance_w(w_other, space.w_set):
            return space.w_NotImplemented

        # XXX this is not tested
        w_other_as_set = self._newobj(space, w_other)
        return space.newbool(not self.equals(w_other_as_set))

    # automatic registration of "lt(x, y)" as "not ge(y, x)" would not give the
    # correct answer here!
    def descr_lt(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented

        if self.length() >= w_other.length():
            return space.w_False
        else:
            return self.descr_issubset(space, w_other)

    def descr_le(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented

        if self.length() > w_other.length():
            return space.w_False
        return space.newbool(self.issubset(w_other))

    def descr_gt(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented

        if self.length() <= w_other.length():
            return space.w_False
        else:
            return self.descr_issuperset(space, w_other)

    def descr_ge(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented

        if self.length() < w_other.length():
            return space.w_False
        return space.newbool(w_other.issubset(self))

    def descr_len(self, space):
        return space.newint(self.length())

    def descr_iter(self, space):
        return W_SetIterObject(space, self.iter())

    def descr_contains(self, space, w_other):
        try:
            return space.newbool(self.has_key(w_other))
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                w_f = _convert_set_to_frozenset(space, w_other)
                if w_f is not None:
                    return space.newbool(self.has_key(w_f))
            raise

    def descr_sub(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        return self.difference(w_other)

    def descr_rsub(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        return w_other.difference(self)

    def descr_and(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        return self.intersect(w_other)
    descr_rand = descr_and # symmetric

    def descr_or(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        w_copy = self.copy_real()
        w_copy.update(w_other)
        return w_copy
    descr_ror = descr_or # symmetric

    def descr_xor(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        return self.symmetric_difference(w_other)
    descr_rxor = descr_xor # symmetric

    def descr_copy(self, space):
        """Return a shallow copy of a set."""
        if type(self) is W_FrozensetObject:
            return self
        return self.copy_real()

    @gateway.unwrap_spec(others_w='args_w')
    def descr_difference(self, space, others_w):
        """Return a new set with elements in the set that are not in the
        others."""
        result = self.copy_real()
        result.descr_difference_update(space, others_w)
        return result

    @gateway.unwrap_spec(others_w='args_w')
    def descr_intersection(self, space, others_w):
        """Return a new set with elements common to the set and all others."""
        #XXX find smarter implementations
        others_w = [self] + others_w

        # find smallest set in others_w to reduce comparisons
        startindex, startlength = 0, -1
        for i in range(len(others_w)):
            w_other = others_w[i]
            try:
                length = space.int_w(space.len(w_other))
            except OperationError as e:
                if (e.match(space, space.w_TypeError) or
                    e.match(space, space.w_AttributeError)):
                    continue
                raise

            if startlength == -1 or length < startlength:
                startindex = i
                startlength = length

        others_w[startindex], others_w[0] = others_w[0], others_w[startindex]

        result = self._newobj(space, others_w[0])
        for i in range(1,len(others_w)):
            w_other = others_w[i]
            if isinstance(w_other, W_BaseSetObject):
                result.intersect_update(w_other)
            else:
                w_other_as_set = self._newobj(space, w_other)
                result.intersect_update(w_other_as_set)
        return result

    def descr_issubset(self, space, w_other):
        """Report whether another set contains this set."""
        if space.is_w(self, w_other):
            return space.w_True

        if isinstance(w_other, W_BaseSetObject):
            if self.length() > w_other.length():
                return space.w_False
            return space.newbool(self.issubset(w_other))

        w_other_as_set = self._newobj(space, w_other)
        if self.length() > w_other_as_set.length():
            return space.w_False
        return space.newbool(self.issubset(w_other_as_set))

    def descr_issuperset(self, space, w_other):
        """Report whether this set contains another set."""
        if space.is_w(self, w_other):
            return space.w_True

        if isinstance(w_other, W_BaseSetObject):
            if self.length() < w_other.length():
                return space.w_False
            return space.newbool(w_other.issubset(self))

        w_other_as_set = self._newobj(space, w_other)
        if self.length() < w_other_as_set.length():
            return space.w_False
        return space.newbool(w_other_as_set.issubset(self))

    def descr_symmetric_difference(self, space, w_other):
        """Return the symmetric difference of two sets as a new set.

        (i.e. all elements that are in exactly one of the sets.)"""

        if isinstance(w_other, W_BaseSetObject):
            return self.symmetric_difference(w_other)

        w_other_as_set = self._newobj(space, w_other)
        return self.symmetric_difference(w_other_as_set)

    @gateway.unwrap_spec(others_w='args_w')
    def descr_union(self, space, others_w):
        """Return a new set with elements from the set and all others."""
        result = self.copy_real()
        for w_other in others_w:
            if isinstance(w_other, W_BaseSetObject):
                result.update(w_other)
            else:
                for w_key in space.listview(w_other):
                    result.add(w_key)
        return result

    def descr_reduce(self, space):
        """Return state information for pickling."""
        return setreduce(space, self)

    def descr_isdisjoint(self, space, w_other):
        """Return True if two sets have a null intersection."""

        if isinstance(w_other, W_BaseSetObject):
            return space.newbool(self.isdisjoint(w_other))

        #XXX may be optimized when other strategies are added
        for w_key in space.listview(w_other):
            if self.has_key(w_key):
                return space.w_False
        return space.w_True

    @gateway.unwrap_spec(others_w='args_w')
    def descr_difference_update(self, space, others_w):
        """Update the set, removing elements found in others."""
        for w_other in others_w:
            if isinstance(w_other, W_BaseSetObject):
                self.difference_update(w_other)
            else:
                w_other_as_set = self._newobj(space, w_other)
                self.difference_update(w_other_as_set)



class W_SetObject(W_BaseSetObject):

    #overridden here so the error is reported correctly
    def __init__(self, space, w_iterable=None):
        """Initialize the set by taking ownership of 'setdata'."""
        W_BaseSetObject.__init__(self, space, w_iterable)

    def _newobj(self, space, w_iterable):
        """Make a new set by taking ownership of 'w_iterable'."""
        return W_SetObject(space, w_iterable)

    @staticmethod
    def descr_new(space, w_settype, __args__):
        w_obj = space.allocate_instance(W_SetObject, w_settype)
        W_SetObject.__init__(w_obj, space)
        return w_obj

    def descr_inplace_sub(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        self.difference_update(w_other)
        return self

    def descr_inplace_and(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        self.intersect_update(w_other)
        return self

    def descr_inplace_or(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        self.update(w_other)
        return self

    def descr_inplace_xor(self, space, w_other):
        if not isinstance(w_other, W_BaseSetObject):
            return space.w_NotImplemented
        self.descr_symmetric_difference_update(space, w_other)
        return self


    def descr_add(self, space, w_other):
        """Add an element to a set.

        This has no effect if the element is already present."""
        self.add(w_other)

    def descr_clear(self, space):
        """Remove all elements from this set."""
        self.clear()

    def _discard_from_set(self, space, w_item):
        """
        Discard an element from a set, with automatic conversion to
        frozenset if the argument is a set.
        Returns True if successfully removed.
        """
        try:
            deleted = self.remove(w_item)
        except OperationError as e:
            if not e.match(space, space.w_TypeError):
                raise
            else:
                w_f = _convert_set_to_frozenset(space, w_item)
                if w_f is None:
                    raise
                deleted = self.remove(w_f)

        if self.length() == 0:
            self.switch_to_empty_strategy()
        return deleted

    def descr_discard(self, space, w_item):
        """Remove an element from a set if it is a member.

        If the element is not a member, do nothing."""
        self._discard_from_set(space, w_item)

    @gateway.unwrap_spec(others_w='args_w')
    def descr_intersection_update(self, space, others_w):
        """Update the set, keeping only elements found in it and all others."""
        result = self.descr_intersection(space, others_w)
        self.strategy = result.strategy
        self.sstorage = result.sstorage

    def descr_pop(self, space):
        """Remove and return an arbitrary set element."""
        return self.popitem()

    def descr_remove(self, space, w_item):
        """Remove an element from a set; it must be a member.

        If the element is not a member, raise a KeyError."""
        if not self._discard_from_set(space, w_item):
            space.raise_key_error(w_item)

    def descr_symmetric_difference_update(self, space, w_other):
        """Update a set with the symmetric difference of itself and another."""
        if isinstance(w_other, W_BaseSetObject):
            self.symmetric_difference_update(w_other)
            return
        w_other_as_set = self._newobj(space, w_other)
        self.symmetric_difference_update(w_other_as_set)

    @gateway.unwrap_spec(others_w='args_w')
    def descr_update(self, space, others_w):
        """Update a set with the union of itself and another."""
        self._descr_update(space, others_w)

    @jit.look_inside_iff(lambda self, space, others_w:
            jit.loop_unrolling_heuristic(others_w, len(others_w), UNROLL_CUTOFF))
    def _descr_update(self, space, others_w):
        for w_other in others_w:
            if isinstance(w_other, W_BaseSetObject):
                self.update(w_other)
            else:
                _update_from_iterable(space, self, w_other)

W_SetObject.typedef = TypeDef("set",
    __doc__ = """set(iterable) --> set object

Build an unordered collection.""",
    __new__ = gateway.interp2app(W_SetObject.descr_new),
    __init__ = gateway.interp2app(W_SetObject.descr_init),
    __repr__ = gateway.interp2app(W_SetObject.descr_repr),
    __hash__ = None,

    __class_getitem__ = gateway.interp2app(
        generic_alias_class_getitem, as_classmethod=True),

    # comparison operators
    __eq__ = gateway.interp2app(W_SetObject.descr_eq),
    __ne__ = gateway.interp2app(W_SetObject.descr_ne),
    __lt__ = gateway.interp2app(W_SetObject.descr_lt),
    __le__ = gateway.interp2app(W_SetObject.descr_le),
    __gt__ = gateway.interp2app(W_SetObject.descr_gt),
    __ge__ = gateway.interp2app(W_SetObject.descr_ge),

    # non-mutating operators
    __len__ = gateway.interp2app(W_SetObject.descr_len),
    __iter__ = gateway.interp2app(W_SetObject.descr_iter),
    __contains__ = gateway.interp2app(W_SetObject.descr_contains),
    __sub__ = gateway.interp2app(W_SetObject.descr_sub),
    __rsub__ = gateway.interp2app(W_SetObject.descr_rsub),
    __and__ = gateway.interp2app(W_SetObject.descr_and),
    __rand__ = gateway.interp2app(W_SetObject.descr_rand),
    __or__ = gateway.interp2app(W_SetObject.descr_or),
    __ror__ = gateway.interp2app(W_SetObject.descr_ror),
    __xor__ = gateway.interp2app(W_SetObject.descr_xor),
    __rxor__ = gateway.interp2app(W_SetObject.descr_rxor),

    # mutating operators
    __isub__ = gateway.interp2app(W_SetObject.descr_inplace_sub),
    __iand__ = gateway.interp2app(W_SetObject.descr_inplace_and),
    __ior__ = gateway.interp2app(W_SetObject.descr_inplace_or),
    __ixor__ = gateway.interp2app(W_SetObject.descr_inplace_xor),

    # non-mutating methods
    __reduce__ = gateway.interp2app(W_SetObject.descr_reduce),
    copy = gateway.interp2app(W_SetObject.descr_copy),
    difference = gateway.interp2app(W_SetObject.descr_difference),
    intersection = gateway.interp2app(W_SetObject.descr_intersection),
    issubset = gateway.interp2app(W_SetObject.descr_issubset),
    issuperset = gateway.interp2app(W_SetObject.descr_issuperset),
    symmetric_difference = gateway.interp2app(W_SetObject.descr_symmetric_difference),
    union = gateway.interp2app(W_SetObject.descr_union),
    isdisjoint = gateway.interp2app(W_SetObject.descr_isdisjoint),

    # mutating methods
    add = gateway.interp2app(W_SetObject.descr_add),
    clear = gateway.interp2app(W_SetObject.descr_clear),
    difference_update = gateway.interp2app(W_SetObject.descr_difference_update),
    discard = gateway.interp2app(W_SetObject.descr_discard),
    intersection_update = gateway.interp2app(W_SetObject.descr_intersection_update),
    pop = gateway.interp2app(W_SetObject.descr_pop),
    remove = gateway.interp2app(W_SetObject.descr_remove),
    symmetric_difference_update = gateway.interp2app(W_SetObject.descr_symmetric_difference_update),
    update = gateway.interp2app(W_SetObject.descr_update)
    )
set_typedef = W_SetObject.typedef


class W_FrozensetObject(W_BaseSetObject):
    DEFAULT_HASH = -1
    hash = DEFAULT_HASH

    def _cleanup_(self):
        # in case there are frozenset objects existing during
        # translation, make sure we don't translate a cached hash
        self.hash = self.DEFAULT_HASH

    def is_w(self, space, w_other):
        if not isinstance(w_other, W_FrozensetObject):
            return False
        if self is w_other:
            return True
        if self.user_overridden_class or w_other.user_overridden_class:
            return False
        # empty frozensets are unique-ified
        return 0 == w_other.length() == self.length()

    def immutable_unique_id(self, space):
        if self.user_overridden_class or self.length() > 0:
            return None
        # empty frozenset: base value 259
        uid = (259 << IDTAG_SHIFT) | IDTAG_SPECIAL
        return space.newint(uid)

    def _newobj(self, space, w_iterable):
        """Make a new frozenset by taking ownership of 'w_iterable'."""
        return W_FrozensetObject(space, w_iterable)

    @staticmethod
    def descr_new2(space, w_frozensettype, w_iterable=None):
        if (space.is_w(w_frozensettype, space.w_frozenset) and
            w_iterable is not None and type(w_iterable) is W_FrozensetObject):
            return w_iterable
        w_obj = space.allocate_instance(W_FrozensetObject, w_frozensettype)
        W_FrozensetObject.__init__(w_obj, space, w_iterable)
        return w_obj

    def descr_hash(self, space):
        if self.hash != -1:
            return space.newint(self.hash)
        multi = r_uint(1822399083) + r_uint(1822399083) + 1
        hash = r_uint(1927868237)
        hash *= r_uint(self.length() + 1)
        # jit driver, maybe?
        w_iterator = self.iter()
        while True:
            w_item = w_iterator.next_entry()
            if w_item is None:
                break
            h = space.hash_w(w_item)
            value = (r_uint(h ^ (h << 16) ^ 89869747)  * multi)
            hash = hash ^ value
        hash ^= (hash >> 11) ^ (hash >> 25)
        hash = hash * 69069 + 907133923
        hash = intmask(hash)
        if hash == -1:
            hash = 590923713
        self.hash = hash

        return space.newint(hash)

    def cpyext_add_frozen(self, w_key):
        if self.hash != self.DEFAULT_HASH:
            return False
        self.add(w_key)
        return True

W_FrozensetObject.typedef = TypeDef("frozenset",
    __doc__ = """frozenset(iterable) --> frozenset object

Build an immutable unordered collection.""",
    __new__ = gateway.interp2app(W_FrozensetObject.descr_new2),
    __repr__ = gateway.interp2app(W_FrozensetObject.descr_repr),
    __hash__ = gateway.interp2app(W_FrozensetObject.descr_hash),

    __class_getitem__ = gateway.interp2app(
        generic_alias_class_getitem, as_classmethod=True),

    # comparison operators
    __eq__ = gateway.interp2app(W_FrozensetObject.descr_eq),
    __ne__ = gateway.interp2app(W_FrozensetObject.descr_ne),
    __lt__ = gateway.interp2app(W_FrozensetObject.descr_lt),
    __le__ = gateway.interp2app(W_FrozensetObject.descr_le),
    __gt__ = gateway.interp2app(W_FrozensetObject.descr_gt),
    __ge__ = gateway.interp2app(W_FrozensetObject.descr_ge),

    # non-mutating operators
    __len__ = gateway.interp2app(W_FrozensetObject.descr_len),
    __iter__ = gateway.interp2app(W_FrozensetObject.descr_iter),
    __contains__ = gateway.interp2app(W_FrozensetObject.descr_contains),
    __sub__ = gateway.interp2app(W_FrozensetObject.descr_sub),
    __rsub__ = gateway.interp2app(W_FrozensetObject.descr_rsub),
    __and__ = gateway.interp2app(W_FrozensetObject.descr_and),
    __rand__ = gateway.interp2app(W_FrozensetObject.descr_rand),
    __or__ = gateway.interp2app(W_FrozensetObject.descr_or),
    __ror__ = gateway.interp2app(W_FrozensetObject.descr_ror),
    __xor__ = gateway.interp2app(W_FrozensetObject.descr_xor),
    __rxor__ = gateway.interp2app(W_FrozensetObject.descr_rxor),

    # non-mutating methods
    __reduce__ = gateway.interp2app(W_FrozensetObject.descr_reduce),
    copy = gateway.interp2app(W_FrozensetObject.descr_copy),
    difference = gateway.interp2app(W_FrozensetObject.descr_difference),
    intersection = gateway.interp2app(W_FrozensetObject.descr_intersection),
    issubset = gateway.interp2app(W_FrozensetObject.descr_issubset),
    issuperset = gateway.interp2app(W_FrozensetObject.descr_issuperset),
    symmetric_difference = gateway.interp2app(W_FrozensetObject.descr_symmetric_difference),
    union = gateway.interp2app(W_FrozensetObject.descr_union),
    isdisjoint = gateway.interp2app(W_FrozensetObject.descr_isdisjoint)
    )
frozenset_typedef = W_FrozensetObject.typedef



class SetStrategy(object):
    def __init__(self, space):
        self.space = space

    def get_empty_dict(self):
        """ Returns an empty dictionary depending on the strategy. Used to initalize a new storage. """
        raise NotImplementedError

    def get_empty_storage(self):
        """ Returns an empty storage (erased) object. Used to initialize an empty set."""
        raise NotImplementedError

    def listview_bytes(self, w_set):
        return None

    def listview_ascii(self, w_set):
        return None

    def listview_int(self, w_set):
        return None

    #def erase(self, storage):
    #    raise NotImplementedError

    #def unerase(self, storage):
    #    raise NotImplementedError

    # __________________ methods called on W_SetObject _________________

    def clear(self, w_set):
        raise NotImplementedError

    def copy_real(self, w_set):
        raise NotImplementedError

    def length(self, w_set):
        raise NotImplementedError

    def add(self, w_set, w_key):
        raise NotImplementedError

    def remove(self, w_set, w_item):
        raise NotImplementedError

    def getdict_w(self, w_set):
        raise NotImplementedError

    def get_storage_copy(self, w_set):
        raise NotImplementedError

    def getkeys(self, w_set):
        raise NotImplementedError

    def difference(self, w_set, w_other):
        raise NotImplementedError

    def difference_update(self, w_set, w_other):
        raise NotImplementedError

    def symmetric_difference(self, w_set, w_other):
        raise NotImplementedError

    def symmetric_difference_update(self, w_set, w_other):
        raise NotImplementedError

    def intersect(self, w_set, w_other):
        raise NotImplementedError

    def intersect_update(self, w_set, w_other):
        raise NotImplementedError

    def issubset(self, w_set, w_other):
        raise NotImplementedError

    def isdisjoint(self, w_set, w_other):
        raise NotImplementedError

    def update(self, w_set, w_other):
        raise NotImplementedError

    def has_key(self, w_set, w_key):
        raise NotImplementedError

    def equals(self, w_set, w_other):
        raise NotImplementedError

    def iter(self, w_set):
        raise NotImplementedError

    def popitem(self, w_set):
        raise NotImplementedError


class EmptySetStrategy(SetStrategy):
    erase, unerase = rerased.new_erasing_pair("empty")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def get_empty_storage(self):
        return self.erase(None)

    def is_correct_type(self, w_key):
        return False

    def length(self, w_set):
        return 0

    def clear(self, w_set):
        pass

    def copy_real(self, w_set):
        storage = self.erase(None)
        clone = w_set.from_storage_and_strategy(storage, self)
        return clone

    def add(self, w_set, w_key):
        if is_plain_int1(w_key):
            strategy = self.space.fromcache(IntegerSetStrategy)
        elif type(w_key) is W_BytesObject:
            strategy = self.space.fromcache(BytesSetStrategy)
        elif type(w_key) is W_UnicodeObject and w_key.is_ascii():
            strategy = self.space.fromcache(AsciiSetStrategy)
        elif self.space.type(w_key).compares_by_identity():
            strategy = self.space.fromcache(IdentitySetStrategy)
        else:
            strategy = self.space.fromcache(ObjectSetStrategy)
        w_set.strategy = strategy
        w_set.sstorage = strategy.get_empty_storage()
        w_set.add(w_key)

    def remove(self, w_set, w_item):
        return False

    def getdict_w(self, w_set):
        return newset(self.space)

    def get_storage_copy(self, w_set):
        return w_set.sstorage

    def getkeys(self, w_set):
        return []

    def has_key(self, w_set, w_key):
        return False

    def equals(self, w_set, w_other):
        if w_other.strategy is self or w_other.length() == 0:
            return True
        return False

    def difference(self, w_set, w_other):
        return w_set.copy_real()

    def difference_update(self, w_set, w_other):
        pass

    def intersect(self, w_set, w_other):
        return w_set.copy_real()

    def intersect_update(self, w_set, w_other):
        pass

    def isdisjoint(self, w_set, w_other):
        return True

    def issubset(self, w_set, w_other):
        return True

    def symmetric_difference(self, w_set, w_other):
        return w_other.copy_real()

    def symmetric_difference_update(self, w_set, w_other):
        w_set.strategy = w_other.strategy
        w_set.sstorage = w_other.get_storage_copy()

    def update(self, w_set, w_other):
        w_set.strategy = w_other.strategy
        w_set.sstorage = w_other.get_storage_copy()

    def iter(self, w_set):
        return EmptyIteratorImplementation(self.space, self, w_set)

    def popitem(self, w_set):
        raise oefmt(self.space.w_KeyError, "pop from an empty set")


class AbstractUnwrappedSetStrategy(object):
    _mixin_ = True

    def is_correct_type(self, w_key):
        """ Checks wether the given wrapped key fits this strategy."""
        raise NotImplementedError

    def unwrap(self, w_item):
        """ Returns the unwrapped value of the given wrapped item."""
        raise NotImplementedError

    def wrap(self, item):
        """ Returns a wrapped version of the given unwrapped item. """
        raise NotImplementedError

    @jit.look_inside_iff(lambda self, list_w:
            jit.loop_unrolling_heuristic(list_w, len(list_w), UNROLL_CUTOFF))
    def get_storage_from_list(self, list_w):
        setdata = self.get_empty_dict()
        for w_item in list_w:
            setdata[self.unwrap(w_item)] = None
        return self.erase(setdata)

    @jit.look_inside_iff(lambda self, items:
            jit.loop_unrolling_heuristic(items, len(items), UNROLL_CUTOFF))
    def get_storage_from_unwrapped_list(self, items):
        setdata = self.get_empty_dict()
        for item in items:
            setdata[item] = None
        return self.erase(setdata)

    def length(self, w_set):
        return len(self.unerase(w_set.sstorage))

    def clear(self, w_set):
        w_set.switch_to_empty_strategy()

    def copy_real(self, w_set):
        # may be used internally on frozen sets, although frozenset().copy()
        # returns self in frozenset_copy__Frozenset.
        strategy = w_set.strategy
        d = self.unerase(w_set.sstorage)
        storage = self.erase(d.copy())
        clone = w_set.from_storage_and_strategy(storage, strategy)
        return clone

    def add(self, w_set, w_key):
        if self.is_correct_type(w_key):
            d = self.unerase(w_set.sstorage)
            d[self.unwrap(w_key)] = None
        else:
            w_set.switch_to_object_strategy(self.space)
            w_set.add(w_key)

    def remove(self, w_set, w_item):
        d = self.unerase(w_set.sstorage)
        if not self.is_correct_type(w_item):
            #XXX check type of w_item and immediately return False in some cases
            w_set.switch_to_object_strategy(self.space)
            return w_set.remove(w_item)

        key = self.unwrap(w_item)
        try:
            del d[key]
            return True
        except KeyError:
            return False

    def getdict_w(self, w_set):
        result = newset(self.space)
        keys = self.unerase(w_set.sstorage).keys()
        for key in keys:
            result[self.wrap(key)] = None
        return result

    def get_storage_copy(self, w_set):
        d = self.unerase(w_set.sstorage)
        copy = self.erase(d.copy())
        return copy

    def getkeys(self, w_set):
        keys = self.unerase(w_set.sstorage).keys()
        keys_w = [self.wrap(key) for key in keys]
        return keys_w

    def has_key(self, w_set, w_key):
        if not self.is_correct_type(w_key):
            #XXX check type of w_item and immediately return False in some cases
            w_set.switch_to_object_strategy(self.space)
            return w_set.has_key(w_key)
        d = self.unerase(w_set.sstorage)
        return self.unwrap(w_key) in d

    def equals(self, w_set, w_other):
        if w_set.length() != w_other.length():
            return False
        if w_set.length() == 0:
            return True
        # it's possible to have 0-length strategy that's not empty
        if w_set.strategy is w_other.strategy:
            return self._issubset_unwrapped(w_set, w_other)
        if not self.may_contain_equal_elements(w_other.strategy):
            return False
        items = self.unerase(w_set.sstorage).keys()
        for key in items:
            if not w_other.has_key(self.wrap(key)):
                return False
        return True

    def _difference_wrapped(self, w_set, w_other):
        iterator = self.unerase(w_set.sstorage).iterkeys()
        result_dict = self.get_empty_dict()
        for key in iterator:
            w_item = self.wrap(key)
            if not w_other.has_key(w_item):
                result_dict[key] = None
        return self.erase(result_dict)

    def _difference_unwrapped(self, w_set, w_other):
        self_dict = self.unerase(w_set.sstorage)
        other_dict = self.unerase(w_other.sstorage)
        result_dict = self.get_empty_dict()
        for key, keyhash in iterkeys_with_hash(self_dict):
            if not contains_with_hash(other_dict, key, keyhash):
                setitem_with_hash(result_dict, key, keyhash, None)
        return self.erase(result_dict)

    def _difference_base(self, w_set, w_other):
        if self is w_other.strategy:
            storage = self._difference_unwrapped(w_set, w_other)
        elif not w_set.strategy.may_contain_equal_elements(w_other.strategy):
            d = self.unerase(w_set.sstorage)
            storage = self.erase(d.copy())
        else:
            storage = self._difference_wrapped(w_set, w_other)
        return storage

    def difference(self, w_set, w_other):
        storage = self._difference_base(w_set, w_other)
        w_newset = w_set.from_storage_and_strategy(storage, w_set.strategy)
        return w_newset

    def _difference_update_unwrapped(self, w_set, w_other):
        my_dict = self.unerase(w_set.sstorage)
        if w_set.sstorage is w_other.sstorage:
            my_dict.clear()
            return
        other_dict = self.unerase(w_other.sstorage)
        for key, keyhash in iterkeys_with_hash(other_dict):
            try:
                delitem_with_hash(my_dict, key, keyhash)
            except KeyError:
                pass

    def _difference_update_wrapped(self, w_set, w_other):
        w_iterator = w_other.iter()
        while True:
            w_item = w_iterator.next_entry()
            if w_item is None:
                break
            w_set.remove(w_item)

    def difference_update(self, w_set, w_other):
        if self.length(w_set) < w_other.strategy.length(w_other):
            # small_set -= big_set: compute the difference as a new set
            storage = self._difference_base(w_set, w_other)
            w_set.sstorage = storage
        else:
            # big_set -= small_set: be more subtle
            if self is w_other.strategy:
                self._difference_update_unwrapped(w_set, w_other)
            elif w_set.strategy.may_contain_equal_elements(w_other.strategy):
                self._difference_update_wrapped(w_set, w_other)

    def _symmetric_difference_unwrapped(self, w_set, w_other):
        d_new = self.get_empty_dict()
        d_this = self.unerase(w_set.sstorage)
        d_other = self.unerase(w_other.sstorage)
        for key, keyhash in iterkeys_with_hash(d_other):
            if not contains_with_hash(d_this, key, keyhash):
                setitem_with_hash(d_new, key, keyhash, None)
        for key, keyhash in iterkeys_with_hash(d_this):
            if not contains_with_hash(d_other, key, keyhash):
                setitem_with_hash(d_new, key, keyhash, None)

        storage = self.erase(d_new)
        return storage

    def _symmetric_difference_wrapped(self, w_set, w_other):
        newsetdata = newset(self.space)
        for obj in self.unerase(w_set.sstorage):
            w_item = self.wrap(obj)
            if not w_other.has_key(w_item):
                newsetdata[w_item] = None

        w_iterator = w_other.iter()
        while True:
            w_item = w_iterator.next_entry()
            if w_item is None:
                break
            if not w_set.has_key(w_item):
                newsetdata[w_item] = None

        strategy = self.space.fromcache(ObjectSetStrategy)
        return strategy.erase(newsetdata)

    def _symmetric_difference_base(self, w_set, w_other):
        if self is w_other.strategy:
            strategy = w_set.strategy
            storage = self._symmetric_difference_unwrapped(w_set, w_other)
        else:
            strategy = self.space.fromcache(ObjectSetStrategy)
            storage = self._symmetric_difference_wrapped(w_set, w_other)
        return storage, strategy

    def symmetric_difference(self, w_set, w_other):
        if w_other.length() == 0:
            return w_set.copy_real()
        storage, strategy = self._symmetric_difference_base(w_set, w_other)
        return w_set.from_storage_and_strategy(storage, strategy)

    def symmetric_difference_update(self, w_set, w_other):
        if w_other.length() == 0:
            return
        storage, strategy = self._symmetric_difference_base(w_set, w_other)
        w_set.strategy = strategy
        w_set.sstorage = storage

    def _intersect_base(self, w_set, w_other):
        if self is w_other.strategy:
            strategy = self
            if w_set.length() > w_other.length():
                # swap operands
                storage = self._intersect_unwrapped(w_other, w_set)
            else:
                storage = self._intersect_unwrapped(w_set, w_other)
        elif not w_set.strategy.may_contain_equal_elements(w_other.strategy):
            strategy = self.space.fromcache(EmptySetStrategy)
            storage = strategy.get_empty_storage()
        else:
            strategy = self.space.fromcache(ObjectSetStrategy)
            if w_set.length() > w_other.length():
                # swap operands
                storage = w_other.strategy._intersect_wrapped(w_other, w_set)
            else:
                storage = self._intersect_wrapped(w_set, w_other)
        return storage, strategy

    def _intersect_wrapped(self, w_set, w_other):
        result = newset(self.space)
        for key in self.unerase(w_set.sstorage):
            self.intersect_jmp.jit_merge_point()
            w_key = self.wrap(key)
            if w_other.has_key(w_key):
                result[w_key] = None

        strategy = self.space.fromcache(ObjectSetStrategy)
        return strategy.erase(result)

    def _intersect_unwrapped(self, w_set, w_other):
        result = self.get_empty_dict()
        d_this = self.unerase(w_set.sstorage)
        d_other = self.unerase(w_other.sstorage)
        for key, keyhash in iterkeys_with_hash(d_this):
            if contains_with_hash(d_other, key, keyhash):
                setitem_with_hash(result, key, keyhash, None)
        return self.erase(result)

    def intersect(self, w_set, w_other):
        storage, strategy = self._intersect_base(w_set, w_other)
        return w_set.from_storage_and_strategy(storage, strategy)

    def intersect_update(self, w_set, w_other):
        if w_set.length() > w_other.length():
            w_intersection = w_other.intersect(w_set)
            strategy = w_intersection.strategy
            storage = w_intersection.sstorage
        else:
            storage, strategy = self._intersect_base(w_set, w_other)
        w_set.strategy = strategy
        w_set.sstorage = storage

    def _issubset_unwrapped(self, w_set, w_other):
        d_set = self.unerase(w_set.sstorage)
        d_other = self.unerase(w_other.sstorage)
        for key, keyhash in iterkeys_with_hash(d_set):
            if not contains_with_hash(d_other, key, keyhash):
                return False
        return True

    def _issubset_wrapped(self, w_set, w_other):
        for obj in self.unerase(w_set.sstorage):
            w_item = self.wrap(obj)
            if not w_other.has_key(w_item):
                return False
        return True

    def issubset(self, w_set, w_other):
        if w_set.length() == 0:
            return True

        if w_set.strategy is w_other.strategy:
            return self._issubset_unwrapped(w_set, w_other)
        elif not w_set.strategy.may_contain_equal_elements(w_other.strategy):
            return False
        else:
            return self._issubset_wrapped(w_set, w_other)

    def _isdisjoint_unwrapped(self, w_set, w_other):
        d_set = self.unerase(w_set.sstorage)
        d_other = self.unerase(w_other.sstorage)
        for key, keyhash in iterkeys_with_hash(d_set):
            if contains_with_hash(d_other, key, keyhash):
                return False
        return True

    def _isdisjoint_wrapped(self, w_set, w_other):
        d = self.unerase(w_set.sstorage)
        for key in d:
            if w_other.has_key(self.wrap(key)):
                return False
        return True

    def isdisjoint(self, w_set, w_other):
        if w_other.length() == 0:
            return True
        if w_set.length() > w_other.length():
            return w_other.isdisjoint(w_set)

        if w_set.strategy is w_other.strategy:
            return self._isdisjoint_unwrapped(w_set, w_other)
        elif not w_set.strategy.may_contain_equal_elements(w_other.strategy):
            return True
        else:
            return self._isdisjoint_wrapped(w_set, w_other)

    def update(self, w_set, w_other):
        if self is w_other.strategy:
            d_set = self.unerase(w_set.sstorage)
            d_other = self.unerase(w_other.sstorage)
            d_set.update(d_other)
            return
        if w_other.length() == 0:
            return
        w_set.switch_to_object_strategy(self.space)
        w_set.update(w_other)

    def popitem(self, w_set):
        storage = self.unerase(w_set.sstorage)
        try:
            # this returns a tuple because internally sets are dicts
            result = storage.popitem()
        except KeyError:
            # strategy may still be the same even if dict is empty
            raise oefmt(self.space.w_KeyError, "pop from an empty set")
        return self.wrap(result[0])


class BytesSetStrategy(AbstractUnwrappedSetStrategy, SetStrategy):
    erase, unerase = rerased.new_erasing_pair("bytes")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    intersect_jmp = jit.JitDriver(greens = [], reds = 'auto',
                                  name='set(bytes).intersect')

    def get_empty_storage(self):
        return self.erase({})

    def get_empty_dict(self):
        return {}

    def listview_bytes(self, w_set):
        return self.unerase(w_set.sstorage).keys()

    def is_correct_type(self, w_key):
        return type(w_key) is W_BytesObject

    def may_contain_equal_elements(self, strategy):
        if strategy is self.space.fromcache(IntegerSetStrategy):
            return False
        elif strategy is self.space.fromcache(EmptySetStrategy):
            return False
        elif strategy is self.space.fromcache(IdentitySetStrategy):
            return False
        return True

    def unwrap(self, w_item):
        return self.space.bytes_w(w_item)

    def wrap(self, item):
        return self.space.newbytes(item)

    def iter(self, w_set):
        return BytesIteratorImplementation(self.space, self, w_set)


class AsciiSetStrategy(AbstractUnwrappedSetStrategy, SetStrategy):
    erase, unerase = rerased.new_erasing_pair("unicode")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    intersect_jmp = jit.JitDriver(greens = [], reds = 'auto',
                                  name='set(unicode).intersect')

    def get_empty_storage(self):
        return self.erase({})

    def get_empty_dict(self):
        return {}

    def listview_ascii(self, w_set):
        return self.unerase(w_set.sstorage).keys()

    def is_correct_type(self, w_key):
        return type(w_key) is W_UnicodeObject and w_key.is_ascii()

    def may_contain_equal_elements(self, strategy):
        if strategy is self.space.fromcache(IntegerSetStrategy):
            return False
        elif strategy is self.space.fromcache(EmptySetStrategy):
            return False
        elif strategy is self.space.fromcache(IdentitySetStrategy):
            return False
        return True

    def unwrap(self, w_item):
        return self.space.utf8_w(w_item)

    def wrap(self, item):
        return self.space.newutf8(item, len(item))

    def iter(self, w_set):
        return UnicodeIteratorImplementation(self.space, self, w_set)


class IntegerSetStrategy(AbstractUnwrappedSetStrategy, SetStrategy):
    erase, unerase = rerased.new_erasing_pair("integer")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    intersect_jmp = jit.JitDriver(greens = [], reds = 'auto',
                                  name='set(int).intersect')

    def get_empty_storage(self):
        return self.erase({})

    def get_empty_dict(self):
        return {}

    def listview_int(self, w_set):
        return self.unerase(w_set.sstorage).keys()

    def is_correct_type(self, w_key):
        return is_plain_int1(w_key)

    def may_contain_equal_elements(self, strategy):
        if strategy is self.space.fromcache(BytesSetStrategy):
            return False
        elif strategy is self.space.fromcache(AsciiSetStrategy):
            return False
        elif strategy is self.space.fromcache(EmptySetStrategy):
            return False
        elif strategy is self.space.fromcache(IdentitySetStrategy):
            return False
        return True

    def unwrap(self, w_item):
        return plain_int_w(self.space, w_item)

    def wrap(self, item):
        return self.space.newint(item)

    def iter(self, w_set):
        return IntegerIteratorImplementation(self.space, self, w_set)


class ObjectSetStrategy(AbstractUnwrappedSetStrategy, SetStrategy):
    erase, unerase = rerased.new_erasing_pair("object")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    intersect_jmp = jit.JitDriver(greens = [], reds = 'auto',
                                  name='set(object).intersect')

    def get_empty_storage(self):
        return self.erase(self.get_empty_dict())

    def get_empty_dict(self):
        return newset(self.space)

    def is_correct_type(self, w_key):
        return True

    def may_contain_equal_elements(self, strategy):
        if strategy is self.space.fromcache(EmptySetStrategy):
            return False
        return True

    def unwrap(self, w_item):
        return w_item

    def wrap(self, item):
        return item

    def iter(self, w_set):
        return RDictIteratorImplementation(self.space, self, w_set)

    def update(self, w_set, w_other):
        d_obj = self.unerase(w_set.sstorage)

        # optimization only
        if w_other.strategy is self:
            d_other = self.unerase(w_other.sstorage)
            d_obj.update(d_other)
            return

        w_iterator = w_other.iter()
        while True:
            w_item = w_iterator.next_entry()
            if w_item is None:
                break
            d_obj[w_item] = None

class IdentitySetStrategy(AbstractUnwrappedSetStrategy, SetStrategy):
    erase, unerase = rerased.new_erasing_pair("identityset")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    intersect_jmp = jit.JitDriver(greens = [], reds = 'auto',
                                  name='set(identity).intersect')

    def get_empty_storage(self):
        return self.erase({})

    def get_empty_dict(self):
        return {}

    def is_correct_type(self, w_key):
        w_type = self.space.type(w_key)
        return w_type.compares_by_identity()

    def may_contain_equal_elements(self, strategy):
        #empty first, probably more likely
        if strategy is self.space.fromcache(EmptySetStrategy):
            return False
        if strategy is self.space.fromcache(IntegerSetStrategy):
            return False
        if strategy is self.space.fromcache(BytesSetStrategy):
            return False
        if strategy is self.space.fromcache(AsciiSetStrategy):
            return False
        return True

    def unwrap(self, w_item):
        return w_item

    def wrap(self, item):
        return item

    def iter(self, w_set):
        return IdentityIteratorImplementation(self.space, self, w_set)

class IteratorImplementation(object):
    def __init__(self, space, strategy, implementation):
        self.space = space
        self.strategy = strategy
        self.setimplementation = implementation
        self.len = implementation.length()
        self.pos = 0

    def next(self):
        if self.setimplementation is None:
            return None
        if self.len != self.setimplementation.length():
            self.len = -1   # Make this error state sticky
            raise oefmt(self.space.w_RuntimeError,
                        "set changed size during iteration")
        # look for the next entry
        if self.pos < self.len:
            result = self.next_entry()
            self.pos += 1
            if self.strategy is self.setimplementation.strategy:
                return result      # common case
            else:
                # waaa, obscure case: the strategy changed, but not the
                # length of the set.  The 'result' might be out-of-date.
                # We try to explicitly look it up in the set.
                if not self.setimplementation.has_key(result):
                    self.len = -1   # Make this error state sticky
                    raise oefmt(self.space.w_RuntimeError,
                                "dictionary changed during iteration")
                return result
        # no more entries
        self.setimplementation = None
        return None

    def next_entry(self):
        """ Purely abstract method
        """
        raise NotImplementedError

    def length(self):
        if self.setimplementation is not None and self.len != -1:
            return self.len - self.pos
        return 0


class EmptyIteratorImplementation(IteratorImplementation):
    def next_entry(self):
        return None


class BytesIteratorImplementation(IteratorImplementation):
    def __init__(self, space, strategy, w_set):
        IteratorImplementation.__init__(self, space, strategy, w_set)
        d = strategy.unerase(w_set.sstorage)
        self.iterator = d.iterkeys()

    def next_entry(self):
        for key in self.iterator:
            return self.space.newbytes(key)
        else:
            return None


class UnicodeIteratorImplementation(IteratorImplementation):
    def __init__(self, space, strategy, w_set):
        IteratorImplementation.__init__(self, space, strategy, w_set)
        d = strategy.unerase(w_set.sstorage)
        self.iterator = d.iterkeys()

    def next_entry(self):
        for key in self.iterator:
            return self.space.newutf8(key, len(key))
        else:
            return None


class IntegerIteratorImplementation(IteratorImplementation):
    #XXX same implementation in dictmultiobject on dictstrategy-branch
    def __init__(self, space, strategy, w_set):
        IteratorImplementation.__init__(self, space, strategy, w_set)
        d = strategy.unerase(w_set.sstorage)
        self.iterator = d.iterkeys()

    def next_entry(self):
        # note that this 'for' loop only runs once, at most
        for key in self.iterator:
            return self.space.newint(key)
        else:
            return None

class IdentityIteratorImplementation(IteratorImplementation):
    def __init__(self, space, strategy, w_set):
        IteratorImplementation.__init__(self, space, strategy, w_set)
        d = strategy.unerase(w_set.sstorage)
        self.iterator = d.iterkeys()

    def next_entry(self):
        for w_key in self.iterator:
            return w_key
        else:
            return None

class RDictIteratorImplementation(IteratorImplementation):
    def __init__(self, space, strategy, w_set):
        IteratorImplementation.__init__(self, space, strategy, w_set)
        d = strategy.unerase(w_set.sstorage)
        self.iterator = d.iterkeys()

    def next_entry(self):
        # note that this 'for' loop only runs once, at most
        for w_key in self.iterator:
            return w_key
        else:
            return None


class W_SetIterObject(W_Root):

    def __init__(self, space, iterimplementation):
        self.space = space
        self.iterimplementation = iterimplementation

    def descr_length_hint(self, space):
        return space.newint(self.iterimplementation.length())

    def descr_iter(self, space):
        return self

    def descr_next(self, space):
        iterimplementation = self.iterimplementation
        w_key = iterimplementation.next()
        if w_key is not None:
            return w_key
        raise OperationError(space.w_StopIteration, space.w_None)

    def descr_reduce(self, space):
        # copy the iterator state
        w_set = self.iterimplementation.setimplementation
        w_clone = W_SetIterObject(space, w_set.iter())
        # spool until we have the same pos
        for x in xrange(self.iterimplementation.pos):
            w_clone.descr_next(space)
        w_res = space.call_function(space.w_list, w_clone)
        w_iter = space.builtin.get('iter')
        return space.newtuple([w_iter, space.newtuple([w_res])])


W_SetIterObject.typedef = TypeDef("setiterator",
    __length_hint__ = gateway.interp2app(W_SetIterObject.descr_length_hint),
    __iter__ = gateway.interp2app(W_SetIterObject.descr_iter),
    __next__ = gateway.interp2app(W_SetIterObject.descr_next),
    __reduce__ = gateway.interp2app(W_SetIterObject.descr_reduce),
    )
setiter_typedef = W_SetIterObject.typedef



# some helper functions

def newset(space):
    return r_dict(space.eq_w, space.hash_w, force_non_null=True)

def set_strategy_and_setdata(space, w_set, w_iterable):
    if w_iterable is None :
        w_set.strategy = strategy = space.fromcache(EmptySetStrategy)
        w_set.sstorage = strategy.get_empty_storage()
        return

    if isinstance(w_iterable, W_BaseSetObject):
        w_set.strategy = w_iterable.strategy
        w_set.sstorage = w_iterable.get_storage_copy()
        return

    byteslist = space.listview_bytes(w_iterable)
    if byteslist is not None:
        strategy = space.fromcache(BytesSetStrategy)
        w_set.strategy = strategy
        w_set.sstorage = strategy.get_storage_from_unwrapped_list(byteslist)
        return

    unicodelist = space.listview_ascii(w_iterable)
    if unicodelist is not None:
        strategy = space.fromcache(AsciiSetStrategy)
        w_set.strategy = strategy
        w_set.sstorage = strategy.get_storage_from_unwrapped_list(unicodelist)
        return

    intlist = space.listview_int(w_iterable)
    if intlist is not None:
        strategy = space.fromcache(IntegerSetStrategy)
        w_set.strategy = strategy
        w_set.sstorage = strategy.get_storage_from_unwrapped_list(intlist)
        return

    length_hint = space.length_hint(w_iterable, 0)

    if jit.isconstant(length_hint) and length_hint:
        return _pick_correct_strategy_unroll(space, w_set, w_iterable)

    w_set.strategy = strategy = space.fromcache(EmptySetStrategy)
    w_set.sstorage = strategy.get_empty_storage()
    _update_from_iterable(space, w_set, w_iterable)


@jit.unroll_safe
def _pick_correct_strategy_unroll(space, w_set, w_iterable):

    iterable_w = space.listview(w_iterable)
    # check for integers
    for w_item in iterable_w:
        if not is_plain_int1(w_item):
            break
    else:
        w_set.strategy = space.fromcache(IntegerSetStrategy)
        w_set.sstorage = w_set.strategy.get_storage_from_list(iterable_w)
        return

    # check for strings
    for w_item in iterable_w:
        if type(w_item) is not W_BytesObject:
            break
    else:
        w_set.strategy = space.fromcache(BytesSetStrategy)
        w_set.sstorage = w_set.strategy.get_storage_from_list(iterable_w)
        return

    # check for unicode
    for w_item in iterable_w:
        if type(w_item) is not W_UnicodeObject or not w_item.is_ascii():
            break
    else:
        w_set.strategy = space.fromcache(AsciiSetStrategy)
        w_set.sstorage = w_set.strategy.get_storage_from_list(iterable_w)
        return

    # check for compares by identity
    for w_item in iterable_w:
        if not space.type(w_item).compares_by_identity():
            break
    else:
        w_set.strategy = space.fromcache(IdentitySetStrategy)
        w_set.sstorage = w_set.strategy.get_storage_from_list(iterable_w)
        return

    w_set.strategy = space.fromcache(ObjectSetStrategy)
    w_set.sstorage = w_set.strategy.get_storage_from_list(iterable_w)


def get_printable_location(tp, strategy):
    return "update_set: %s %s" % (tp.iterator_greenkey_printable(), strategy)

update_set_driver = jit.JitDriver(name='update_set',
                                  greens=['tp', 'strategy'],
                                  reds='auto',
                                  get_printable_location=get_printable_location)

def _update_from_iterable(space, w_set, w_iterable):
    tp = space.iterator_greenkey(w_iterable)

    w_iter = space.iter(w_iterable)
    while True:
        try:
            w_item = space.next(w_iter)
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
            return
        update_set_driver.jit_merge_point(tp=tp, strategy=w_set.strategy)
        w_set.add(w_item)


init_signature = Signature(['some_iterable'], None, None)
init_defaults = [None]
def _initialize_set(space, w_obj, w_iterable=None):
    w_obj.clear()
    set_strategy_and_setdata(space, w_obj, w_iterable)

def _convert_set_to_frozenset(space, w_obj):
    if isinstance(w_obj, W_SetObject):
        w_frozen = W_FrozensetObject(space, None)
        w_frozen.strategy = w_obj.strategy
        w_frozen.sstorage = w_obj.sstorage
        return w_frozen
    elif space.isinstance_w(w_obj, space.w_set):
        w_frz = space.allocate_instance(W_FrozensetObject, space.w_frozenset)
        W_FrozensetObject.__init__(w_frz, space, w_obj)
        return w_frz
    else:
        return None


app = gateway.applevel("""
    def setrepr(currently_in_repr, s):
        'The app-level part of repr().'
        if s in currently_in_repr:
            return '%s(...)' % (s.__class__.__name__,)
        currently_in_repr[s] = 1
        try:
            if not s:
                return '%s()' % (s.__class__.__name__,)
            listrepr = repr([x for x in s])
            if type(s) is set:
                return '{%s}' % (listrepr[1:-1],)
            else:
                return '%s({%s})' % (s.__class__.__name__, listrepr[1:-1])
        finally:
            try:
                del currently_in_repr[s]
            except:
                pass
""", filename=__file__)

setrepr = app.interphook("setrepr")

app = gateway.applevel("""
    def setreduce(s):
        dict = getattr(s,'__dict__', None)
        return (s.__class__, (tuple(s),), dict)

""", filename=__file__)

setreduce = app.interphook('setreduce')
