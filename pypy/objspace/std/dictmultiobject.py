"""The builtin dict implementation"""

from rpython.rlib import jit, rerased, objectmodel, rutf8
from rpython.rlib.debug import mark_dict_non_null
from rpython.rlib.objectmodel import newlist_hint, r_dict, specialize
from rpython.tool.sourcetools import func_renamer, func_with_new_name

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import (
    WrappedDefault, applevel, interp2app, unwrap_spec)
from pypy.interpreter.mixedmodule import MixedModule
from pypy.interpreter.signature import Signature
from pypy.interpreter.typedef import TypeDef, interp_attrproperty_w
from pypy.interpreter.unicodehelper import decode_utf8sp
from pypy.objspace.std.util import negate, generic_alias_class_getitem


UNROLL_CUTOFF = 5


def _never_equal_to_string(space, w_lookup_type):
    """Handles the case of a non string key lookup.
    Types that have a sane hash/eq function should allow us to return True
    directly to signal that the key is not in the dict in any case.
    XXX The types should provide such a flag. """

    # XXX there are many more types
    return (space.is_w(w_lookup_type, space.w_NoneType) or
            space.is_w(w_lookup_type, space.w_int) or
            space.is_w(w_lookup_type, space.w_bool) or
            space.is_w(w_lookup_type, space.w_float))


@specialize.call_location()
def w_dict_unrolling_heuristic(w_dct):
    """In which cases iterating over dict items can be unrolled.
    Note that w_dct is an instance of W_DictMultiObject, not necesarilly
    an actual dict
    """
    return jit.isvirtual(w_dct) or (jit.isconstant(w_dct) and
                                    w_dct.length() <= UNROLL_CUTOFF)


# for json decoder
def create_empty_unicode_key_dict(space):
    return r_dict(unicode_eq, unicode_hash,
                  force_non_null=True,
                  simple_hash_eq=True)

def from_unicode_key_dict(space, d):
    strategy = space.fromcache(UnicodeDictStrategy)
    return W_DictObject(space, strategy, strategy.erase(d))


class W_DictMultiObject(W_Root):
    """ Abstract base class that does not store a strategy. """
    __slots__ = ['space', 'dstorage']

    def get_strategy(self):
        raise NotImplementedError("abstract method")

    def set_strategy(self, strategy):
        raise NotImplementedError("abstract method")


    @staticmethod
    def allocate_and_init_instance(space, w_type=None, module=False,
                                   instance=False, strdict=False,
                                   kwargs=False):
        if module:
            from pypy.objspace.std.celldict import ModuleDictStrategy
            assert w_type is None
            # every module needs its own strategy, because the strategy stores
            # the version tag
            strategy = ModuleDictStrategy(space)
            storage = strategy.get_empty_storage()
            w_obj = space.allocate_instance(W_ModuleDictObject, space.w_dict)
            W_ModuleDictObject.__init__(w_obj, space, strategy, storage)
            return w_obj
        elif instance:
            from pypy.objspace.std.mapdict import make_instance_dict
            assert w_type is None
            return make_instance_dict(space)
        elif strdict or module:
            assert w_type is None
            strategy = space.fromcache(UnicodeDictStrategy)
        elif kwargs:
            assert w_type is None
            from pypy.objspace.std.kwargsdict import EmptyKwargsDictStrategy
            strategy = space.fromcache(EmptyKwargsDictStrategy)
        else:
            strategy = space.fromcache(EmptyDictStrategy)
        if w_type is None:
            w_type = space.w_dict

        storage = strategy.get_empty_storage()
        w_obj = space.allocate_instance(W_DictObject, w_type)
        W_DictObject.__init__(w_obj, space, strategy, storage)
        return w_obj

    def __init__(self, space, storage):
        self.space = space
        self.dstorage = storage

    def __repr__(self):
        """representation for debugging purposes"""
        return "%s(%s)" % (self.__class__.__name__, self.get_strategy())

    def unwrap(w_dict, space):
        result = {}
        items = w_dict.items()
        for w_pair in items:
            key, val = space.unwrap(w_pair)
            result[key] = val
        return result

    def initialize_content(self, list_pairs_w):
        for w_k, w_v in list_pairs_w:
            self.setitem(w_k, w_v)

    def setitem_str(self, key, w_value):
        self.get_strategy().setitem_str(self, key, w_value)

    @staticmethod
    def descr_new(space, w_dicttype, __args__):
        w_obj = W_DictMultiObject.allocate_and_init_instance(space, w_dicttype)
        return w_obj

    @staticmethod
    def descr_fromkeys(space, w_type, w_iterable, w_value=None):
        w_keys = w_iterable  # \
        w_fill = w_value     # / rename the arguments for app-level
        if w_fill is None:
            w_fill = space.w_None
        if space.is_w(w_type, space.w_dict):
            # XXX consider re-enabling a fast-path here
            w_dict = W_DictMultiObject.allocate_and_init_instance(space,
                                                                  w_type)
            for w_key in space.listview(w_keys):
                w_dict.setitem(w_key, w_fill)
        else:
            w_dict = space.call_function(w_type)
            for w_key in space.listview(w_keys):
                space.setitem(w_dict, w_key, w_fill)
        return w_dict

    def descr_init(self, space, __args__):
        init_or_update(space, self, __args__, 'dict')

    def descr_repr(self, space):
        return dictrepr(space, space.get_objects_in_repr(), self)

    def descr_eq(self, space, w_other):
        if space.is_w(self, w_other):
            return space.w_True
        if not isinstance(w_other, W_DictMultiObject):
            return space.w_NotImplemented

        if self.length() != w_other.length():
            return space.w_False
        iteratorimplementation = self.iteritems()
        while True:
            w_key, w_val = iteratorimplementation.next_item()
            if w_key is None:
                break
            w_rightval = w_other.getitem(w_key)
            if w_rightval is None:
                return space.w_False
            if not space.eq_w(w_val, w_rightval):
                return space.w_False
        return space.w_True

    descr_ne = negate(descr_eq)

    def descr_len(self, space):
        return space.newint(self.length())

    def descr_iter(self, space):
        return W_DictMultiIterKeysObject(space, self.iterkeys())

    def descr_contains(self, space, w_key):
        return space.newbool(self.getitem(w_key) is not None)

    def descr_getitem(self, space, w_key):
        w_value = self.getitem(w_key)
        if w_value is not None:
            return w_value

        # if there is a __missing__ method, call it
        if not space.is_w(space.type(self), space.w_dict):
            w_missing = space.lookup(self, '__missing__')
            if w_missing is not None:
                return space.get_and_call_function(w_missing, self, w_key)

        space.raise_key_error(w_key)

    def descr_setitem(self, space, w_newkey, w_newvalue):
        self.setitem(w_newkey, w_newvalue)

    def descr_delitem(self, space, w_key):
        try:
            self.delitem(w_key)
        except KeyError:
            space.raise_key_error(w_key)

    def internal_delitem(self, w_key):
        try:
            self.delitem(w_key)
        except KeyError:
            raise oefmt(self.space.w_RuntimeError,
                        "an internal 'del' on the dictionary failed to find "
                        "the key")

    def descr_copy(self, space):
        """D.copy() -> a shallow copy of D"""
        return self.copy()

    def descr_items(self, space):
        """D.items() -> a set-like object providing a view on D's items"""
        return W_DictViewItemsObject(space, self)

    def descr_keys(self, space):
        """D.keys() -> a set-like object providing a view on D's keys"""
        return W_DictViewKeysObject(space, self)

    def descr_values(self, space):
        """D.values() -> an object providing a view on D's values"""
        return W_DictViewValuesObject(space, self)

    def descr_reversed(self, space):
        """Return a reverse iterator over the dict keys.
        """
        strategy = self.get_strategy()
        return strategy.w_iterreversed(self)

    def nondescr_delitem_if_value_is(self, space, w_key, w_value):
        """Not exposed directly to app-level, but used by
        _weakref._remove_dead_weakref and via __pypy__.delitem_if_value_is().
        """
        strategy = self.ensure_object_strategy()
        d = strategy.unerase(self.dstorage)
        objectmodel.delitem_if_value_is(d, w_key, w_value)

    def nondescr_move_to_end(self, space, w_key, last_flag):
        """Not exposed directly to app-level, but via __pypy__.move_to_end().
        """
        strategy = self.get_strategy()
        strategy.move_to_end(self, w_key, last_flag)

    def nondescr_popitem_first(self, space):
        """Not exposed directly to app-level, but via __pypy__.popitem_first().
        """
        w_key, w_value = self.iteritems().next_item()
        if w_key is None:
            raise oefmt(space.w_KeyError, "popitem(): dictionary is empty")
        self.internal_delitem(w_key)
        return space.newtuple([w_key, w_value])

    def descr_clear(self, space):
        """D.clear() -> None.  Remove all items from D."""
        self.clear()

    @unwrap_spec(w_default=WrappedDefault(None))
    def descr_get(self, space, w_key, w_default):
        """D.get(k[,d]) -> D[k] if k in D, else d.  d defaults to None."""
        w_value = self.getitem(w_key)
        return w_value if w_value is not None else w_default

    def descr_pop(self, space, w_key, w_default=None):
        """D.pop(k[,d]) -> v, remove specified key and return the
        corresponding value\nIf key is not found, d is returned if given,
        otherwise KeyError is raised
        """
        strategy = self.get_strategy()
        try:
            return strategy.pop(self, w_key, w_default)
        except KeyError:
            raise space.raise_key_error(w_key)

    def descr_popitem(self, space):
        """D.popitem() -> (k, v), remove and return some (key, value) pair as
        a\n2-tuple; but raise KeyError if D is empty"""
        try:
            w_key, w_value = self.popitem()
        except KeyError:
            raise oefmt(space.w_KeyError, "popitem(): dictionary is empty")
        return space.newtuple([w_key, w_value])

    @unwrap_spec(w_default=WrappedDefault(None))
    def descr_setdefault(self, space, w_key, w_default):
        """D.setdefault(k[,d]) -> D.get(k,d), also set D[k]=d if k not in D"""
        return self.setdefault(w_key, w_default)

    def descr_update(self, space, __args__):
        """D.update(E, **F) -> None.  Update D from E and F: for k in E: D[k]
        = E[k]\n(if E has keys else: for (k, v) in E: D[k] = v) then: for k in
        F: D[k] = F[k]"""
        init_or_update(space, self, __args__, 'dict.update')

    def ensure_object_strategy(self):    # also called by cpyext
        object_strategy = self.space.fromcache(ObjectDictStrategy)
        strategy = self.get_strategy()
        if strategy is not object_strategy:
            strategy.switch_to_object_strategy(self)
        return object_strategy

    def descr_or(self, space, w_other):
        if not space.isinstance_w(w_other, space.w_dict):
            return space.w_NotImplemented
        copyself = self.copy()
        update1(space, copyself, w_other)
        return copyself

    def descr_ior(self, space, w_other):
        update1(space, self, w_other)
        return self


class W_DictObject(W_DictMultiObject):
    """ a regular dict object """
    __slots__ = ['dstrategy']

    def __init__(self, space, strategy, storage):
        W_DictMultiObject.__init__(self, space, storage)
        self.dstrategy = strategy

    def get_strategy(self):
        return self.dstrategy

    def set_strategy(self, strategy):
        self.dstrategy = strategy


class W_ModuleDictObject(W_DictMultiObject):
    """ a dict object for a module, that is not expected to change. It stores
    the strategy as a quasi-immutable field. """
    __slots__ = ['mstrategy']
    _immutable_fields_ = ['mstrategy?']

    def __init__(self, space, strategy, storage):
        W_DictMultiObject.__init__(self, space, storage)
        self.mstrategy = strategy

    def get_strategy(self):
        return self.mstrategy

    def set_strategy(self, strategy):
        self.mstrategy = strategy



# called below DictStrategy

def _add_indirections():
    dict_methods = "getitem getitem_str setitem setdefault \
                    popitem delitem clear copy \
                    length w_keys values items \
                    iterkeys itervalues iteritems iterreversed \
                    listview_bytes listview_ascii listview_int \
                    view_as_kwargs".split()

    def make_method(method):
        def f(self, *args):
            return getattr(self.get_strategy(), method)(self, *args)
        f.func_name = method
        return f

    for method in dict_methods:
        assert hasattr(DictStrategy, method)
        setattr(W_DictMultiObject, method, make_method(method))


app = applevel('''
    def dictrepr(currently_in_repr, d):
        if len(d) == 0:
            return "{}"
        if d in currently_in_repr:
            return '{...}'
        currently_in_repr[d] = 1
        try:
            items = []
            # XXX for now, we cannot use items() without list at
            #     app-level because we want a reasonable result instead
            #     of a RuntimeError even if the dict is mutated by the
            #     repr() in the loop.
            for k, v in list(dict.items(d)):
                items.append(repr(k) + ": " + repr(v))
            return "{" +  ', '.join(items) + "}"
        finally:
            try:
                del currently_in_repr[d]
            except:
                pass

    def viewrepr(currently_in_repr, view):
        if view in currently_in_repr:
            return '...'
        currently_in_repr[view] = 1
        try:
            return (type(view).__name__ + "([" +
               ", ".join([repr(x) for x in view]) + '])')
        finally:
            try:
                del currently_in_repr[view]
            except:
                pass
''', filename=__file__)

dictrepr = app.interphook("dictrepr")
viewrepr = app.interphook("viewrepr")


W_DictMultiObject.typedef = TypeDef("dict",
    __doc__ = '''dict() -> new empty dictionary.
dict(mapping) -> new dictionary initialized from a mapping object\'s
    (key, value) pairs.
dict(seq) -> new dictionary initialized as if via:
    d = {}
    for k, v in seq:
        d[k] = v
dict(**kwargs) -> new dictionary initialized with the name=value pairs
    in the keyword argument list.  For example:  dict(one=1, two=2)''',
    __new__ = interp2app(W_DictMultiObject.descr_new),
    fromkeys = interp2app(W_DictMultiObject.descr_fromkeys,
                          as_classmethod=True),
    __hash__ = None,
    __repr__ = interp2app(W_DictMultiObject.descr_repr),
    __init__ = interp2app(W_DictMultiObject.descr_init),

    __eq__ = interp2app(W_DictMultiObject.descr_eq),
    __ne__ = interp2app(W_DictMultiObject.descr_ne),

    __len__ = interp2app(W_DictMultiObject.descr_len),
    __iter__ = interp2app(W_DictMultiObject.descr_iter),
    __reversed__ = interp2app(W_DictMultiObject.descr_reversed),
    __contains__ = interp2app(W_DictMultiObject.descr_contains),

    __getitem__ = interp2app(W_DictMultiObject.descr_getitem),
    __setitem__ = interp2app(W_DictMultiObject.descr_setitem),
    __delitem__ = interp2app(W_DictMultiObject.descr_delitem),

    __or__ = interp2app(W_DictMultiObject.descr_or),
    __ior__ = interp2app(W_DictMultiObject.descr_ior),

    __class_getitem__ = interp2app(
        generic_alias_class_getitem, as_classmethod=True),

    copy = interp2app(W_DictMultiObject.descr_copy),
    items = interp2app(W_DictMultiObject.descr_items),
    keys = interp2app(W_DictMultiObject.descr_keys),
    values = interp2app(W_DictMultiObject.descr_values),
    clear = interp2app(W_DictMultiObject.descr_clear),
    get = interp2app(W_DictMultiObject.descr_get),
    pop = interp2app(W_DictMultiObject.descr_pop),
    popitem = interp2app(W_DictMultiObject.descr_popitem),
    setdefault = interp2app(W_DictMultiObject.descr_setdefault),
    update = interp2app(W_DictMultiObject.descr_update),
    )


class DictStrategy(object):
    def __init__(self, space):
        self.space = space

    def get_empty_storage(self):
        raise NotImplementedError

    def getitem(self, w_dict, w_key):
        raise NotImplementedError

    def getitem_str(self, w_dict, key):
        return w_dict.getitem(self.space.newtext(key))

    def setitem(self, w_dict, w_key, w_value):
        raise NotImplementedError

    def setitem_str(self, w_dict, key, w_value):
        w_dict.setitem(self.space.newtext(key), w_value)

    def delitem(self, w_dict, w_key):
        raise NotImplementedError

    def length(self, w_dict):
        raise NotImplementedError

    def setdefault(self, w_dict, w_key, w_value):
        # slow default implementation
        w_result = self.getitem(w_dict, w_key)
        if w_result is not None:
            return w_result
        self.setitem(w_dict, w_key, w_value)
        return w_value

    def iterkeys(self, w_dict):
        raise NotImplementedError

    def itervalues(self, w_dict):
        raise NotImplementedError

    def iteritems(self, w_dict):
        raise NotImplementedError

    @jit.look_inside_iff(lambda self, w_dict:
                         w_dict_unrolling_heuristic(w_dict))
    def w_keys(self, w_dict):
        iterator = self.iterkeys(w_dict)
        result = newlist_hint(self.length(w_dict))
        while True:
            w_key = iterator.next_key()
            if w_key is not None:
                result.append(w_key)
            else:
                return self.space.newlist(result)

    def values(self, w_dict):
        iterator = self.itervalues(w_dict)
        result = newlist_hint(self.length(w_dict))
        while True:
            w_value = iterator.next_value()
            if w_value is not None:
                result.append(w_value)
            else:
                return result

    def items(self, w_dict):
        iterator = self.iteritems(w_dict)
        result = newlist_hint(self.length(w_dict))
        while True:
            w_key, w_value = iterator.next_item()
            if w_key is not None:
                result.append(self.space.newtuple([w_key, w_value]))
            else:
                return result

    def popitem(self, w_dict):
        # this is a bad implementation: if we call popitem() repeatedly,
        # it ends up taking n**2 time, because the next() calls below
        # will take longer and longer.  But all interesting strategies
        # provide a better one.
        iterator = self.iteritems(w_dict)
        w_key, w_value = iterator.next_item()
        if w_key is None:
            raise KeyError
        self.delitem(w_dict, w_key)
        return (w_key, w_value)

    def clear(self, w_dict):
        strategy = self.space.fromcache(EmptyDictStrategy)
        storage = strategy.get_empty_storage()
        w_dict.set_strategy(strategy)
        w_dict.dstorage = storage

    def copy(self, w_dict):
        w_new = W_DictMultiObject.allocate_and_init_instance(self.space)
        update1_dict_dict(self.space, w_new, w_dict)
        return w_new

    def listview_bytes(self, w_dict):
        return None

    def listview_ascii(self, w_dict):
        return None

    def listview_int(self, w_dict):
        return None

    def view_as_kwargs(self, w_dict):
        return (None, None)

    def getiterkeys(self, w_dict):
        raise NotImplementedError

    def getitervalues(self, w_dict):
        raise NotImplementedError

    def getiteritems_with_hash(self, w_dict):
        raise NotImplementedError

    def rev_update1_dict_dict(self, w_dict, w_updatedict):
        iteritems = self.iteritems(w_dict)
        while True:
            w_key, w_value = iteritems.next_item()
            if w_key is None:
                break
            w_updatedict.setitem(w_key, w_value)

    def prepare_update(self, w_dict, num_extra):
        pass

    def move_to_end(self, w_dict, w_key, last_flag):
        # fall-back
        w_value = w_dict.getitem(w_key)
        if w_value is None:
            self.space.raise_key_error(w_key)
        else:
            w_dict.internal_delitem(w_key)
            if last_flag:
                w_dict.setitem(w_key, w_value)
            else:
                # *very slow* fall-back
                keys_w = []
                values_w = []
                iteratorimplementation = w_dict.iteritems()
                while True:
                    w_k, w_v = iteratorimplementation.next_item()
                    if w_k is None:
                        break
                    keys_w.append(w_k)
                    values_w.append(w_v)
                w_dict.clear()
                w_dict.setitem(w_key, w_value)
                for i in range(len(keys_w)):
                    w_dict.setitem(keys_w[i], values_w[i])


    def pop(self, w_dict, w_key, w_default):
        # fall-back
        w_item = w_dict.getitem(w_key)
        if w_item is None:
            if w_default is not None:
                return w_default
            else:
                raise KeyError
        else:
            w_dict.internal_delitem(w_key)
            return w_item

    def w_iterreversed(self, w_dict):
        # fall-back if getiterreversed is not present
        w_keys = self.w_keys(w_dict)
        return self.space.call_method(w_keys, '__reversed__')

    def iterreversed(self, w_dict):
        raise NotImplementedError

_add_indirections()


class EmptyDictStrategy(DictStrategy):
    erase, unerase = rerased.new_erasing_pair("empty")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def get_empty_storage(self):
        return self.erase(None)

    def switch_to_correct_strategy(self, w_dict, w_key):
        if type(w_key) is self.space.StringObjectCls:
            self.switch_to_bytes_strategy(w_dict)
            return
        if type(w_key) is self.space.UnicodeObjectCls:
            self.switch_to_unicode_strategy(w_dict)
            return
        w_type = self.space.type(w_key)
        if self.space.is_w(w_type, self.space.w_int):
            self.switch_to_int_strategy(w_dict)
        elif w_type.compares_by_identity():
            self.switch_to_identity_strategy(w_dict)
        else:
            self.switch_to_object_strategy(w_dict)

    def switch_to_bytes_strategy(self, w_dict):
        strategy = self.space.fromcache(BytesDictStrategy)
        storage = strategy.get_empty_storage()
        w_dict.set_strategy(strategy)
        w_dict.dstorage = storage

    def switch_to_unicode_strategy(self, w_dict):
        strategy = self.space.fromcache(UnicodeDictStrategy)
        storage = strategy.get_empty_storage()
        w_dict.set_strategy(strategy)
        w_dict.dstorage = storage

    def switch_to_int_strategy(self, w_dict):
        strategy = self.space.fromcache(IntDictStrategy)
        storage = strategy.get_empty_storage()
        w_dict.set_strategy(strategy)
        w_dict.dstorage = storage

    def switch_to_identity_strategy(self, w_dict):
        from pypy.objspace.std.identitydict import IdentityDictStrategy
        strategy = self.space.fromcache(IdentityDictStrategy)
        storage = strategy.get_empty_storage()
        w_dict.set_strategy(strategy)
        w_dict.dstorage = storage

    def switch_to_object_strategy(self, w_dict):
        strategy = self.space.fromcache(ObjectDictStrategy)
        storage = strategy.get_empty_storage()
        w_dict.set_strategy(strategy)
        w_dict.dstorage = storage

    def getitem(self, w_dict, w_key):
        #return w_value or None
        # in case the key is unhashable, try to hash it
        self.space.hash(w_key)
        # return None anyway
        return None

    def getitem_str(self, w_dict, key):
        #return w_value or None
        return None

    def setdefault(self, w_dict, w_key, w_default):
        # here the dict is always empty
        self.switch_to_correct_strategy(w_dict, w_key)
        w_dict.setitem(w_key, w_default)
        return w_default

    def setitem(self, w_dict, w_key, w_value):
        self.switch_to_correct_strategy(w_dict, w_key)
        w_dict.setitem(w_key, w_value)

    def setitem_str(self, w_dict, key, w_value):
        self.switch_to_unicode_strategy(w_dict)
        w_dict.setitem_str(key, w_value)

    def delitem(self, w_dict, w_key):
        # in case the key is unhashable, try to hash it
        self.space.hash(w_key)
        raise KeyError

    def length(self, w_dict):
        return 0

    def clear(self, w_dict):
        return

    def popitem(self, w_dict):
        raise KeyError

    def view_as_kwargs(self, w_dict):
        return ([], [])

    def move_to_end(self, w_dict, w_key, last_flag):
        self.space.raise_key_error(w_key)

    def pop(self, w_dict, w_key, w_default):
        if w_default is not None:
            return w_default
        else:
            raise KeyError

    # ---------- iterator interface ----------------

    def getiterkeys(self, w_dict):
        return iter([])

    def getitervalues(self, w_dict):
        return iter([])

    def getiteritems_with_hash(self, w_dict):
        return iter([])

    def getiterreversed(self, w_dict):
        return iter([])


# Iterator Implementation base classes

def _new_next(TP):
    if TP in ('key', 'value'):
        EMPTY = None
    else:
        EMPTY = None, None

    def next(self):
        if self.w_dict is None:
            return EMPTY
        space = self.space
        if self.len != self.w_dict.length():
            self.len = -1   # Make this error state sticky
            raise oefmt(space.w_RuntimeError,
                        "dictionary changed size during iteration")

        # look for the next entry
        if self.pos < self.len:
            result = getattr(self, 'next_' + TP + '_entry')()
            self.pos += 1
            if self.strategy is self.w_dict.get_strategy():
                return result      # common case
            else:
                # waaa, obscure case: the strategy changed, but not the
                # length of the dict.  The (key, value) pair in 'result'
                # might be out-of-date.  We try to explicitly look up
                # the key in the dict.
                if TP == 'key' or TP == 'value':
                    return result
                w_key = result[0]
                w_value = self.w_dict.getitem(w_key)
                if w_value is None:
                    self.len = -1   # Make this error state sticky
                    raise oefmt(space.w_RuntimeError,
                                "dictionary changed during iteration")
                return (w_key, w_value)
        # no more entries
        self.w_dict = None
        return EMPTY
    return func_with_new_name(next, 'next_' + TP)


class BaseIteratorImplementation(object):
    def __init__(self, space, strategy, w_dict):
        self.space = space
        self.strategy = strategy
        self.w_dict = w_dict
        self.len = w_dict.length()
        self.pos = 0

    def length(self):
        if self.w_dict is not None and self.len != -1:
            return self.len - self.pos
        return 0

    def _cleanup_(self):
        raise Exception("seeing a prebuilt %r object" % (
            self.__class__,))

class BaseKeyIterator(BaseIteratorImplementation):
    next_key = _new_next('key')

class BaseValueIterator(BaseIteratorImplementation):
    next_value = _new_next('value')

class BaseItemIterator(BaseIteratorImplementation):
    next_item = _new_next('item')


def create_iterator_classes(dictimpl,
                            override_next_key=None,
                            override_next_value=None,
                            override_next_item=None):
    if not hasattr(dictimpl, 'wrapkey'):
        wrapkey = lambda space, key: key
    else:
        wrapkey = dictimpl.wrapkey.im_func
    if not hasattr(dictimpl, 'wrapvalue'):
        wrapvalue = lambda space, value: value
    else:
        wrapvalue = dictimpl.wrapvalue.im_func
    if not hasattr(dictimpl, 'setitem_untyped'):
        setitem_untyped = None
    else:
        setitem_untyped = dictimpl.setitem_untyped.im_func
        setitem_untyped = func_with_new_name(setitem_untyped,
            'setitem_untyped_%s' % dictimpl.__name__)

    class IterClassKeys(BaseKeyIterator):
        def __init__(self, space, strategy, w_dict):
            self.iterator = strategy.getiterkeys(w_dict)
            BaseIteratorImplementation.__init__(self, space, strategy, w_dict)

        if override_next_key is not None:
            next_key_entry = override_next_key
        else:
            def next_key_entry(self):
                for key in self.iterator:
                    return wrapkey(self.space, key)
                else:
                    return None

    class IterClassValues(BaseValueIterator):
        def __init__(self, space, strategy, w_dict):
            self.iterator = strategy.getitervalues(w_dict)
            BaseIteratorImplementation.__init__(self, space, strategy, w_dict)

        if override_next_value is not None:
            next_value_entry = override_next_value
        else:
            def next_value_entry(self):
                for value in self.iterator:
                    return wrapvalue(self.space, value)
                else:
                    return None

    class IterClassItems(BaseItemIterator):
        def __init__(self, space, strategy, w_dict):
            self.iterator = strategy.getiteritems_with_hash(w_dict)
            BaseIteratorImplementation.__init__(self, space, strategy, w_dict)

        if override_next_item is not None:
            next_item_entry = override_next_item
        else:
            def next_item_entry(self):
                for key, value, keyhash in self.iterator:
                    return (wrapkey(self.space, key),
                            wrapvalue(self.space, value))
                else:
                    return None, None

    class IterClassReversed(BaseKeyIterator):
        def __init__(self, space, strategy, w_dict):
            self.iterator = strategy.getiterreversed(w_dict)
            BaseIteratorImplementation.__init__(self, space, strategy, w_dict)

        def next_key_entry(self):
            for key in self.iterator:
                return wrapkey(self.space, key)
            else:
                return None

    def iterkeys(self, w_dict):
        return IterClassKeys(self.space, self, w_dict)

    def itervalues(self, w_dict):
        return IterClassValues(self.space, self, w_dict)

    def iteritems(self, w_dict):
        return IterClassItems(self.space, self, w_dict)

    if hasattr(dictimpl, 'getiterreversed'):
        def iterreversed(self, w_dict):
            return IterClassReversed(self.space, self, w_dict)

        def w_iterreversed(self, w_dict):
            return W_DictMultiIterKeysReversedObject(
                    self.space,
                    iterreversed(self, w_dict))
        dictimpl.w_iterreversed = w_iterreversed
        dictimpl.iterreversed = iterreversed

    @jit.look_inside_iff(lambda self, w_dict, w_updatedict:
                         w_dict_unrolling_heuristic(w_dict))
    def rev_update1_dict_dict(self, w_dict, w_updatedict):
        # the logic is to call prepare_dict_update() after the first setitem():
        # it gives the w_updatedict a chance to switch its strategy.
        if override_next_item is not None:
            # this is very similar to the general version, but the difference
            # is that it is specialized to call a specific next_item()
            iteritems = IterClassItems(self.space, self, w_dict)
            w_key, w_value = iteritems.next_item()
            if w_key is None:
                return
            w_updatedict.setitem(w_key, w_value)
            w_updatedict.get_strategy().prepare_update(w_updatedict,
                                                       w_dict.length() - 1)
            while True:
                w_key, w_value = iteritems.next_item()
                if w_key is None:
                    return
                w_updatedict.setitem(w_key, w_value)
        else:
            iteritemsh = self.getiteritems_with_hash(w_dict)
            if not same_strategy(self, w_updatedict):
                # Different strategy.  Try to copy one item of w_dict
                for key, value, keyhash in iteritemsh:
                    w_key = wrapkey(self.space, key)
                    w_value = wrapvalue(self.space, value)
                    w_updatedict.setitem(w_key, w_value)
                    break
                else:
                    return     # w_dict is completely empty, nothing to do
                count = w_dict.length() - 1
                w_updatedict.get_strategy().prepare_update(w_updatedict, count)
                # If the strategy is still different, continue the slow way
                if not same_strategy(self, w_updatedict):
                    for key, value, keyhash in iteritemsh:
                        w_key = wrapkey(self.space, key)
                        w_value = wrapvalue(self.space, value)
                        w_updatedict.setitem(w_key, w_value)
                    return     # done
            else:
                # Same strategy.
                self.prepare_update(w_updatedict, w_dict.length())
            #
            # Use setitem_untyped() to speed up copying without
            # wrapping/unwrapping the key.
            assert setitem_untyped is not None
            dstorage = w_updatedict.dstorage
            for key, value, keyhash in iteritemsh:
                setitem_untyped(self, dstorage, key, value, keyhash)

    def same_strategy(self, w_otherdict):
        return (setitem_untyped is not None and
                w_otherdict.get_strategy() is self)

    dictimpl.iterkeys = iterkeys
    dictimpl.itervalues = itervalues
    dictimpl.iteritems = iteritems
    dictimpl.rev_update1_dict_dict = rev_update1_dict_dict

create_iterator_classes(EmptyDictStrategy)


# concrete subclasses of the above

class AbstractTypedStrategy(object):
    _mixin_ = True

    @staticmethod
    def erase(storage):
        raise NotImplementedError("abstract base class")

    @staticmethod
    def unerase(obj):
        raise NotImplementedError("abstract base class")

    def wrap(self, unwrapped):
        raise NotImplementedError

    def unwrap(self, wrapped):
        raise NotImplementedError

    def is_correct_type(self, w_obj):
        raise NotImplementedError("abstract base class")

    def get_empty_storage(self):
        raise NotImplementedError("abstract base class")

    def _never_equal_to(self, w_lookup_type):
        raise NotImplementedError("abstract base class")

    def setitem(self, w_dict, w_key, w_value):
        if self.is_correct_type(w_key):
            self.unerase(w_dict.dstorage)[self.unwrap(w_key)] = w_value
            return
        else:
            self.switch_to_object_strategy(w_dict)
            w_dict.setitem(w_key, w_value)

    def setitem_str(self, w_dict, key, w_value):
        self.switch_to_object_strategy(w_dict)
        w_dict.setitem(self.space.newtext(key), w_value)

    def setdefault(self, w_dict, w_key, w_default):
        if self.is_correct_type(w_key):
            return self.unerase(w_dict.dstorage).setdefault(self.unwrap(w_key),
                                                            w_default)
        else:
            self.switch_to_object_strategy(w_dict)
            return w_dict.setdefault(w_key, w_default)

    def delitem(self, w_dict, w_key):
        if self.is_correct_type(w_key):
            del self.unerase(w_dict.dstorage)[self.unwrap(w_key)]
            return
        else:
            self.switch_to_object_strategy(w_dict)
            return w_dict.delitem(w_key)

    def length(self, w_dict):
        return len(self.unerase(w_dict.dstorage))

    def getitem_str(self, w_dict, key):
        return self.getitem(w_dict, self.space.newtext(key))

    def getitem(self, w_dict, w_key):
        space = self.space
        if self.is_correct_type(w_key):
            return self.unerase(w_dict.dstorage).get(self.unwrap(w_key), None)
        elif self._never_equal_to(space.type(w_key)):
            return None
        else:
            self.switch_to_object_strategy(w_dict)
            return w_dict.getitem(w_key)

    def w_keys(self, w_dict):
        l = [self.wrap(key)
             for key in self.unerase(w_dict.dstorage).iterkeys()]
        return self.space.newlist(l)

    def values(self, w_dict):
        return self.unerase(w_dict.dstorage).values()

    def items(self, w_dict):
        space = self.space
        dict_w = self.unerase(w_dict.dstorage)
        return [space.newtuple([self.wrap(key), w_value])
                for (key, w_value) in dict_w.iteritems()]

    def popitem(self, w_dict):
        key, value = self.unerase(w_dict.dstorage).popitem()
        return (self.wrap(key), value)

    def pop(self, w_dict, w_key, w_default):
        space = self.space
        if self.is_correct_type(w_key):
            key = self.unwrap(w_key)
            d = self.unerase(w_dict.dstorage)
            if w_default is None:
                return d.pop(key)
            else:
                return d.pop(key, w_default)
        elif self._never_equal_to(space.type(w_key)):
            if w_default is not None:
                return w_default
            raise KeyError
        else:
            self.switch_to_object_strategy(w_dict)
            return w_dict.get_strategy().pop(w_dict, w_key, w_default)

    def clear(self, w_dict):
        self.unerase(w_dict.dstorage).clear()

    def switch_to_object_strategy(self, w_dict):
        d = self.unerase(w_dict.dstorage)
        strategy = self.space.fromcache(ObjectDictStrategy)
        d_new = strategy.unerase(strategy.get_empty_storage())
        for key, value in d.iteritems():
            d_new[self.wrap(key)] = value
        w_dict.set_strategy(strategy)
        w_dict.dstorage = strategy.erase(d_new)

    # --------------- iterator interface -----------------

    def getiterkeys(self, w_dict):
        return self.unerase(w_dict.dstorage).iterkeys()

    def getitervalues(self, w_dict):
        return self.unerase(w_dict.dstorage).itervalues()

    def getiteritems_with_hash(self, w_dict):
        return objectmodel.iteritems_with_hash(self.unerase(w_dict.dstorage))

    def getiterreversed(self, w_dict):
        return objectmodel.reversed_dict(self.unerase(w_dict.dstorage))

    def move_to_end(self, w_dict, w_key, last_flag):
        if self.is_correct_type(w_key):
            d = self.unerase(w_dict.dstorage)
            key = self.unwrap(w_key)
            try:
                objectmodel.move_to_end(d, key, last_flag)
            except KeyError:
                w_dict.space.raise_key_error(w_key)
        else:
            self.switch_to_object_strategy(w_dict)
            w_dict.nondescr_move_to_end(w_dict.space, w_key, last_flag)

    def prepare_update(self, w_dict, num_extra):
        objectmodel.prepare_dict_update(self.unerase(w_dict.dstorage),
                                        num_extra)

    def setitem_untyped(self, dstorage, key, w_value, keyhash):
        d = self.unerase(dstorage)
        objectmodel.setitem_with_hash(d, key, keyhash, w_value)


class ObjectDictStrategy(AbstractTypedStrategy, DictStrategy):
    erase, unerase = rerased.new_erasing_pair("object")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def wrap(self, unwrapped):
        return unwrapped

    def unwrap(self, wrapped):
        return wrapped

    def is_correct_type(self, w_obj):
        return True

    def get_empty_storage(self):
        new_dict = r_dict(self.space.eq_w, self.space.hash_w,
                          force_non_null=True)
        return self.erase(new_dict)

    def _never_equal_to(self, w_lookup_type):
        return False

    def w_keys(self, w_dict):
        return self.space.newlist(self.unerase(w_dict.dstorage).keys())

    def setitem_str(self, w_dict, s, w_value):
        self.setitem(w_dict, self.space.newtext(s), w_value)

    def switch_to_object_strategy(self, w_dict):
        assert 0, "should be unreachable"

create_iterator_classes(ObjectDictStrategy)


class BytesDictStrategy(AbstractTypedStrategy, DictStrategy):
    erase, unerase = rerased.new_erasing_pair("bytes")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def wrap(self, unwrapped):
        return self.space.newbytes(unwrapped)

    def unwrap(self, wrapped):
        return self.space.bytes_w(wrapped)

    def is_correct_type(self, w_obj):
        space = self.space
        return space.is_w(space.type(w_obj), space.w_bytes)

    def get_empty_storage(self):
        res = {}
        mark_dict_non_null(res)
        return self.erase(res)

    def _never_equal_to(self, w_lookup_type):
        return _never_equal_to_string(self.space, w_lookup_type)

    ##def setitem_str(self, w_dict, key, w_value):
    ##    assert key is not None
    ##    self.unerase(w_dict.dstorage)[key] = w_value

    ##def getitem(self, w_dict, w_key):
    ##    space = self.space
    ##    # -- This is called extremely often.  Hack for performance --
    ##    if type(w_key) is space.StringObjectCls:
    ##        return self.unerase(w_dict.dstorage).get(self.unwrap(w_key), None)
    ##    # -- End of performance hack --
    ##    return AbstractTypedStrategy.getitem(self, w_dict, w_key)

    ##def getitem_str(self, w_dict, key):
    ##    assert key is not None
    ##    return self.unerase(w_dict.dstorage).get(key, None)

    def listview_bytes(self, w_dict):
        return self.unerase(w_dict.dstorage).keys()

    def w_keys(self, w_dict):
        return self.space.newlist_bytes(self.listview_bytes(w_dict))

    def wrapkey(space, key):
        return space.newbytes(key)


create_iterator_classes(BytesDictStrategy)

def unicode_eq(w_uni1, w_uni2):
    return w_uni1.eq_w(w_uni2)

def unicode_hash(w_uni):
    return w_uni.hash_w()

class UnicodeDictStrategy(AbstractTypedStrategy, DictStrategy):
    erase, unerase = rerased.new_erasing_pair("unicode")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def wrap(self, unwrapped):
        return unwrapped

    def unwrap(self, wrapped):
        assert type(wrapped) is self.space.UnicodeObjectCls
        return wrapped

    def is_correct_type(self, w_obj):
        space = self.space
        return type(w_obj) is space.UnicodeObjectCls

    def get_empty_storage(self):
        res = create_empty_unicode_key_dict(self.space)
        return self.erase(res)

    def _never_equal_to(self, w_lookup_type):
        return _never_equal_to_string(self.space, w_lookup_type)

    # we should implement the same shortcuts as we do for BytesDictStrategy

    def setitem_str(self, w_dict, key, w_value):
        # XXX think about how to do better again
        self.setitem(w_dict, self.space.newtext(key), w_value)

    def getitem_str(self, w_dict, key):
        # XXX think about how to do better again
        assert key is not None
        return self.getitem(w_dict, self.space.newtext(key))

    def wrapkey(space, key):
        return key

    @jit.look_inside_iff(lambda self, w_dict:
                         w_dict_unrolling_heuristic(w_dict))
    def view_as_kwargs(self, w_dict):
        d = self.unerase(w_dict.dstorage)
        l = len(d)
        keys, values = [None] * l, [None] * l
        i = 0
        for w_key, val in d.iteritems():
            keys[i] = w_key
            values[i] = val
            i += 1
        return keys, values

create_iterator_classes(UnicodeDictStrategy)


class IntDictStrategy(AbstractTypedStrategy, DictStrategy):
    erase, unerase = rerased.new_erasing_pair("int")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def wrap(self, unwrapped):
        return self.space.newint(unwrapped)

    def unwrap(self, wrapped):
        from pypy.objspace.std.listobject import plain_int_w
        return plain_int_w(self.space, wrapped)

    def get_empty_storage(self):
        return self.erase({})

    def is_correct_type(self, w_obj):
        from pypy.objspace.std.listobject import is_plain_int1
        return is_plain_int1(w_obj)

    def _never_equal_to(self, w_lookup_type):
        space = self.space
        # XXX there are many more types
        return (space.is_w(w_lookup_type, space.w_NoneType) or
                space.is_w(w_lookup_type, space.w_bytes) or
                space.is_w(w_lookup_type, space.w_unicode)
                )

    def listview_int(self, w_dict):
        return self.unerase(w_dict.dstorage).keys()

    def wrapkey(space, key):
        return space.newint(key)

    def w_keys(self, w_dict):
        return self.space.newlist_int(self.listview_int(w_dict))

create_iterator_classes(IntDictStrategy)


def update1(space, w_dict, w_data):
    # CPython 'logic' for copying from a dict subclass: use the fast path iff
    # __iter__ hasn't been overridden, otherwise fall back to using keys().
    w_st_iter = space.newtext("__iter__")
    if (isinstance(w_data, W_DictMultiObject) and
            space.is_w(
                space.findattr(space.type(w_data), w_st_iter),
                space.findattr(space.w_dict, w_st_iter))):
        update1_dict_dict(space, w_dict, w_data)
        return
    w_method = space.findattr(w_data, space.newtext("keys"))
    if w_method is None:
        # no 'keys' method, so we assume it is a sequence of pairs
        data_w = space.listview(w_data)
        update1_pairs(space, w_dict, data_w)
    else:
        # general case -- "for k in o.keys(): dict.__setitem__(d, k, o[k])"
        data_w = space.listview(space.call_function(w_method))
        update1_keys(space, w_dict, w_data, data_w)


def update1_dict_dict(space, w_dict, w_data):
    w_data.get_strategy().rev_update1_dict_dict(w_data, w_dict)


def update1_pairs(space, w_dict, data_w):
    for w_pair in data_w:
        pair = space.fixedview(w_pair)
        if len(pair) != 2:
            raise oefmt(space.w_ValueError, "sequence of pairs expected")
        w_key, w_value = pair
        w_dict.setitem(w_key, w_value)


def update1_keys(space, w_dict, w_data, data_w):
    for w_key in data_w:
        w_value = space.getitem(w_data, w_key)
        w_dict.setitem(w_key, w_value)


init_signature = Signature(['seq_or_map'], None, 'kwargs')
init_defaults = [None]

def init_or_update(space, w_dict, __args__, funcname):
    w_src, w_kwds = __args__.parse_obj(
            None, funcname,
            init_signature, # signature
            init_defaults)  # default argument
    if w_src is not None:
        update1(space, w_dict, w_src)
    if space.is_true(w_kwds):
        update1(space, w_dict, w_kwds)


# ____________________________________________________________
# Iteration

class W_BaseDictMultiIterObject(W_Root):
    _immutable_fields_ = ["iteratorimplementation"]

    def __init__(self, space, iteratorimplementation):
        self.space = space
        self.iteratorimplementation = iteratorimplementation

    def descr_iter(self, space):
        return self

    def descr_length_hint(self, space):
        return space.newint(self.iteratorimplementation.length())

    def descr_reduce(self, space):
        """
        This is a slightly special case of pickling.
        Since iteration over a dict is a bit hairy,
        we do the following:
        - create a clone of the dict iterator
        - run it to the original position
        - collect all remaining elements into a list
        At unpickling time, we just use that list
        and create an iterator on it.
        This is of course not the standard way.
        """
        w_mod    = space.getbuiltinmodule('_pickle_support')
        mod      = space.interp_w(MixedModule, w_mod)
        new_inst = mod.get('dictiter_surrogate_new')

        w_dict = self.iteratorimplementation.w_dict
        w_clone = self.clone_for_pickling(space, w_dict)
        assert isinstance(w_clone, W_BaseDictMultiIterObject)

        # spool until we have the same pos
        for x in xrange(self.iteratorimplementation.pos):
            w_clone.descr_next(space)

        w_res = space.call_function(space.w_list, w_clone)
        w_ret = space.newtuple([new_inst, space.newtuple([w_res])])
        return w_ret

    def clone_for_pickling(self, space, w_dict):
        raise oefmt(space.w_TypeError,
                    "unsupported dictiter type '%R' during pickling", self)

    def _cleanup_(self):
        raise Exception("seeing a prebuilt %r object" % (
            self.__class__,))


class W_DictMultiIterKeysObject(W_BaseDictMultiIterObject):
    def descr_next(self, space):
        iteratorimplementation = self.iteratorimplementation
        w_key = iteratorimplementation.next_key()
        if w_key is not None:
            return w_key
        raise OperationError(space.w_StopIteration, space.w_None)

    def clone_for_pickling(self, space, w_dict):
        return W_DictMultiIterKeysObject(space, w_dict.iterkeys())


class W_DictMultiIterKeysReversedObject(W_DictMultiIterKeysObject):
    def clone_for_pickling(self, space, w_dict):
        return w_dict.descr_reversed(space)

class W_DictMultiIterValuesObject(W_BaseDictMultiIterObject):
    def descr_next(self, space):
        iteratorimplementation = self.iteratorimplementation
        w_value = iteratorimplementation.next_value()
        if w_value is not None:
            return w_value
        raise OperationError(space.w_StopIteration, space.w_None)

    def clone_for_pickling(self, space, w_dict):
        return W_DictMultiIterValuesObject(space, w_dict.itervalues())

class W_DictMultiIterItemsObject(W_BaseDictMultiIterObject):
    def descr_next(self, space):
        iteratorimplementation = self.iteratorimplementation
        w_key, w_value = iteratorimplementation.next_item()
        if w_key is not None:
            return space.newtuple([w_key, w_value])
        raise OperationError(space.w_StopIteration, space.w_None)

    def clone_for_pickling(self, space, w_dict):
        return W_DictMultiIterItemsObject(space, w_dict.iteritems())

class W_DictMultiIterValuesReversedObject(W_BaseDictMultiIterObject):
    def descr_next(self, space):
        iteratorimplementation = self.iteratorimplementation
        w_key = iteratorimplementation.next_key()
        if w_key is not None:
            return iteratorimplementation.w_dict.getitem(w_key)
        raise OperationError(space.w_StopIteration, space.w_None)

    def clone_for_pickling(self, space, w_dict):
        return W_DictMultiIterValuesReversedObject(space, w_dict.iterreversed())

class W_DictMultiIterItemsReversedObject(W_BaseDictMultiIterObject):
    def descr_next(self, space):
        iteratorimplementation = self.iteratorimplementation
        w_key = iteratorimplementation.next_key()
        if w_key is not None:
            w_value = iteratorimplementation.w_dict.getitem(w_key)
            return space.newtuple([w_key, w_value])
        raise OperationError(space.w_StopIteration, space.w_None)

    def clone_for_pickling(self, space, w_dict):
        return W_DictMultiIterItemsReversedObject(space, w_dict.iterreversed())


W_DictMultiIterItemsObject.typedef = TypeDef(
    "dict_itemiterator",
    __iter__ = interp2app(W_DictMultiIterItemsObject.descr_iter),
    __next__ = interp2app(W_DictMultiIterItemsObject.descr_next),
    __length_hint__ = interp2app(W_BaseDictMultiIterObject.descr_length_hint),
    __reduce__ = interp2app(W_BaseDictMultiIterObject.descr_reduce),
    )

W_DictMultiIterKeysObject.typedef = TypeDef(
    "dict_keyiterator",
    __iter__ = interp2app(W_DictMultiIterKeysObject.descr_iter),
    __next__ = interp2app(W_DictMultiIterKeysObject.descr_next),
    __length_hint__ = interp2app(W_BaseDictMultiIterObject.descr_length_hint),
    __reduce__ = interp2app(W_BaseDictMultiIterObject.descr_reduce),
    )

W_DictMultiIterValuesObject.typedef = TypeDef(
    "dict_valueiterator",
    __iter__ = interp2app(W_DictMultiIterValuesObject.descr_iter),
    __next__ = interp2app(W_DictMultiIterValuesObject.descr_next),
    __length_hint__ = interp2app(W_BaseDictMultiIterObject.descr_length_hint),
    __reduce__ = interp2app(W_BaseDictMultiIterObject.descr_reduce),
    )

W_DictMultiIterValuesReversedObject.typedef = TypeDef(
    "dict_reversevalueiterator",
    __iter__ = interp2app(W_DictMultiIterValuesReversedObject.descr_iter),
    __next__ = interp2app(W_DictMultiIterValuesReversedObject.descr_next),
    __length_hint__ = interp2app(W_BaseDictMultiIterObject.descr_length_hint),
    __reduce__ = interp2app(W_BaseDictMultiIterObject.descr_reduce),
    )

W_DictMultiIterItemsReversedObject.typedef = TypeDef(
    "dict_reverseitemiterator",
    __iter__ = interp2app(W_DictMultiIterItemsReversedObject.descr_iter),
    __next__ = interp2app(W_DictMultiIterItemsReversedObject.descr_next),
    __length_hint__ = interp2app(W_BaseDictMultiIterObject.descr_length_hint),
    __reduce__ = interp2app(W_BaseDictMultiIterObject.descr_reduce),
    )
# ____________________________________________________________
# Views

class W_DictViewObject(W_Root):
    def __init__(self, space, w_dict):
        self.w_dict = w_dict

    def descr_repr(self, space):
        return viewrepr(space, space.get_objects_in_repr(), self)

    def descr_len(self, space):
        return space.len(self.w_dict)

def _all_contained_in(space, w_dictview, w_other):
    w_iter = space.iter(w_dictview)
    while 1:
        try:
            w_item = space.next(w_iter)
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
            break
        if not space.contains_w(w_other, w_item):
            return space.w_False
    return space.w_True

def _is_set_like(w_other):
    from pypy.objspace.std.setobject import W_BaseSetObject
    return (isinstance(w_other, W_BaseSetObject) or
            isinstance(w_other, W_DictViewKeysObject) or
            isinstance(w_other, W_DictViewItemsObject))

class SetLikeDictView(object):
    _mixin_ = True

    def descr_eq(self, space, w_other):
        if not _is_set_like(w_other):
            return space.w_NotImplemented
        if space.len_w(self) == space.len_w(w_other):
            return _all_contained_in(space, self, w_other)
        return space.w_False

    descr_ne = negate(descr_eq)

    def descr_lt(self, space, w_other):
        if not _is_set_like(w_other):
            return space.w_NotImplemented
        if space.len_w(self) < space.len_w(w_other):
            return _all_contained_in(space, self, w_other)
        return space.w_False

    def descr_le(self, space, w_other):
        if not _is_set_like(w_other):
            return space.w_NotImplemented
        if space.len_w(self) <= space.len_w(w_other):
            return _all_contained_in(space, self, w_other)
        return space.w_False

    def descr_gt(self, space, w_other):
        if not _is_set_like(w_other):
            return space.w_NotImplemented
        if space.len_w(self) > space.len_w(w_other):
            return _all_contained_in(space, w_other, self)
        return space.w_False

    def descr_ge(self, space, w_other):
        if not _is_set_like(w_other):
            return space.w_NotImplemented
        if space.len_w(self) >= space.len_w(w_other):
            return _all_contained_in(space, w_other, self)
        return space.w_False

    def descr_isdisjoint(self, space, w_other):
        """"Return True if the view and the given iterable have a null
        intersection.
        """
        if self is w_other:
            return space.newbool(space.len_w(self) == 0)

        if _is_set_like(w_other):
            # if w_other is set-like and it's longer, we iterate over
            # self instead
            len_self = space.len_w(self)
            len_other = space.len_w(w_other)
            if len_other > len_self:
                self, w_other = w_other, self

        w_iter = space.iter(w_other)
        while 1:
            try:
                w_item = space.next(w_iter)
            except OperationError as e:
                if not e.match(space, space.w_StopIteration):
                    raise
                break
            if space.contains_w(self, w_item):
                return space.w_False
        return space.w_True

    def _as_set_op(name, methname):
        @func_renamer('descr_' + name)
        def op(self, space, w_other):
            w_set = space.call_function(space.w_set, self)
            space.call_method(w_set, methname, w_other)
            return w_set
        @func_renamer('descr_r' + name)
        def rop(self, space, w_other):
            w_set = space.call_function(space.w_set, w_other)
            space.call_method(w_set, methname, self)
            return w_set
        return op, rop

    descr_sub, descr_rsub = _as_set_op('sub', 'difference_update')
    descr_and, descr_rand = _as_set_op('and', 'intersection_update')
    descr_or, descr_ror = _as_set_op('or', 'update')
    descr_xor, descr_rxor = _as_set_op('xor', 'symmetric_difference_update')

def new_dict_items(space, w_type, w_dict):
    w_dict = space.interp_w(W_DictMultiObject, w_dict)
    w_obj = space.allocate_instance(W_DictViewItemsObject, w_type)
    W_DictViewObject.__init__(w_obj, space, w_dict)
    return w_obj

class W_DictViewItemsObject(W_DictViewObject, SetLikeDictView):
    def descr_iter(self, space):
        return W_DictMultiIterItemsObject(space, self.w_dict.iteritems())

    def descr_reversed(self, space):
        return W_DictMultiIterItemsReversedObject(space, self.w_dict.iterreversed())

    def descr_contains(self, space, w_item):
        if not space.isinstance_w(w_item, space.w_tuple):
            return space.w_False
        try:
            w_key, w_value = space.fixedview_unroll(w_item, 2)
        except OperationError as e:
            if e.async(space):
                raise
            w_found = None
        else:
            w_found = self.w_dict.getitem(w_key)
        if w_found is None:
            return space.w_False
        return space.newbool(space.eq_w(w_found, w_value))


def new_dict_keys(space, w_type, w_dict):
    w_dict = space.interp_w(W_DictMultiObject, w_dict)
    w_obj = space.allocate_instance(W_DictViewKeysObject, w_type)
    W_DictViewObject.__init__(w_obj, space, w_dict)
    return w_obj

class W_DictViewKeysObject(W_DictViewObject, SetLikeDictView):
    def descr_iter(self, space):
        return W_DictMultiIterKeysObject(space, self.w_dict.iterkeys())

    def descr_reversed(self, space):
        return self.w_dict.descr_reversed(space)

    def descr_contains(self, space, w_key):
        return self.w_dict.descr_contains(space, w_key)

def new_dict_values(space, w_type, w_dict):
    w_dict = space.interp_w(W_DictMultiObject, w_dict)
    w_obj = space.allocate_instance(W_DictViewValuesObject, w_type)
    W_DictViewObject.__init__(w_obj, space, w_dict)
    return w_obj

class W_DictViewValuesObject(W_DictViewObject):
    def descr_iter(self, space):
        return W_DictMultiIterValuesObject(space, self.w_dict.itervalues())

    def descr_reversed(self, space):
        return W_DictMultiIterValuesReversedObject(space, self.w_dict.iterreversed())


W_DictViewItemsObject.typedef = TypeDef(
    "dict_items",
    __new__ = interp2app(new_dict_items),
    __repr__ = interp2app(W_DictViewItemsObject.descr_repr),
    __len__ = interp2app(W_DictViewItemsObject.descr_len),
    __iter__ = interp2app(W_DictViewItemsObject.descr_iter),
    __reversed__ = interp2app(W_DictViewItemsObject.descr_reversed),
    __contains__ = interp2app(W_DictViewItemsObject.descr_contains),

    __eq__ = interp2app(W_DictViewItemsObject.descr_eq),
    __ne__ = interp2app(W_DictViewItemsObject.descr_ne),
    __lt__ = interp2app(W_DictViewItemsObject.descr_lt),
    __le__ = interp2app(W_DictViewItemsObject.descr_le),
    __gt__ = interp2app(W_DictViewItemsObject.descr_gt),
    __ge__ = interp2app(W_DictViewItemsObject.descr_ge),

    __sub__ = interp2app(W_DictViewItemsObject.descr_sub),
    __rsub__ = interp2app(W_DictViewItemsObject.descr_rsub),
    __and__ = interp2app(W_DictViewItemsObject.descr_and),
    __rand__ = interp2app(W_DictViewItemsObject.descr_rand),
    __or__ = interp2app(W_DictViewItemsObject.descr_or),
    __ror__ = interp2app(W_DictViewItemsObject.descr_ror),
    __xor__ = interp2app(W_DictViewItemsObject.descr_xor),
    __rxor__ = interp2app(W_DictViewItemsObject.descr_rxor),
    isdisjoint = interp2app(W_DictViewItemsObject.descr_isdisjoint),
    _dict = interp_attrproperty_w('w_dict', cls=W_DictViewItemsObject),
    )

W_DictViewKeysObject.typedef = TypeDef(
    "dict_keys",
    __new__ = interp2app(new_dict_keys),
    __repr__ = interp2app(W_DictViewKeysObject.descr_repr),
    __len__ = interp2app(W_DictViewKeysObject.descr_len),
    __iter__ = interp2app(W_DictViewKeysObject.descr_iter),
    __reversed__ = interp2app(W_DictViewKeysObject.descr_reversed),
    __contains__ = interp2app(W_DictViewKeysObject.descr_contains),

    __eq__ = interp2app(W_DictViewKeysObject.descr_eq),
    __ne__ = interp2app(W_DictViewKeysObject.descr_ne),
    __lt__ = interp2app(W_DictViewKeysObject.descr_lt),
    __le__ = interp2app(W_DictViewKeysObject.descr_le),
    __gt__ = interp2app(W_DictViewKeysObject.descr_gt),
    __ge__ = interp2app(W_DictViewKeysObject.descr_ge),

    __sub__ = interp2app(W_DictViewKeysObject.descr_sub),
    __rsub__ = interp2app(W_DictViewKeysObject.descr_rsub),
    __and__ = interp2app(W_DictViewKeysObject.descr_and),
    __rand__ = interp2app(W_DictViewKeysObject.descr_rand),
    __or__ = interp2app(W_DictViewKeysObject.descr_or),
    __ror__ = interp2app(W_DictViewKeysObject.descr_ror),
    __xor__ = interp2app(W_DictViewKeysObject.descr_xor),
    __rxor__ = interp2app(W_DictViewKeysObject.descr_rxor),
    isdisjoint = interp2app(W_DictViewKeysObject.descr_isdisjoint),
    _dict = interp_attrproperty_w('w_dict', cls=W_DictViewKeysObject),
    )

W_DictViewValuesObject.typedef = TypeDef(
    "dict_values",
    __new__ = interp2app(new_dict_values),
    __repr__ = interp2app(W_DictViewValuesObject.descr_repr),
    __len__ = interp2app(W_DictViewValuesObject.descr_len),
    __iter__ = interp2app(W_DictViewValuesObject.descr_iter),
    __reversed__ = interp2app(W_DictViewValuesObject.descr_reversed),
    _dict = interp_attrproperty_w('w_dict', cls=W_DictViewValuesObject),
    )
