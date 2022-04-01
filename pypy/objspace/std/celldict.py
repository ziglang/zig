""" A very simple cell dict implementation using a version tag. The dictionary
maps keys to objects. If a specific key is changed a lot, a level of
indirection is introduced to make the version tag change less often.
"""

from rpython.rlib import jit, rerased, objectmodel

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError
from pypy.objspace.std.dictmultiobject import (
    DictStrategy, ObjectDictStrategy, _never_equal_to_string,
    create_iterator_classes)
from pypy.objspace.std.typeobject import (
    MutableCell, IntMutableCell, ObjectMutableCell, write_cell, unwrap_cell)


class VersionTag(object):
    pass


def _wrapkey(space, key):
    return space.newtext(key)


class ModuleDictStrategy(DictStrategy):

    erase, unerase = rerased.new_erasing_pair("modulecell")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    _immutable_fields_ = ["version?"]

    def __init__(self, space):
        self.space = space
        self.version = VersionTag()

    def get_empty_storage(self):
        return self.erase({})

    def mutated(self):
        self.version = VersionTag()

    def getdictvalue_no_unwrapping(self, w_dict, key):
        # NB: it's important to promote self here, so that self.version is a
        # no-op due to the quasi-immutable field
        self = jit.promote(self)
        return self._getdictvalue_no_unwrapping_pure(self.version, w_dict, key)

    @jit.elidable_promote('0,1,2')
    def _getdictvalue_no_unwrapping_pure(self, version, w_dict, key):
        return self.unerase(w_dict.dstorage).get(key, None)

    def try_unwrap_key(self, space, w_key):
        if space.is_w(space.type(w_key), space.w_text):
            try:
                return space.text_w(w_key)
            except OperationError as e:
                if e.match(space, space.w_UnicodeEncodeError):
                    return None
                raise
        return None

    def setitem(self, w_dict, w_key, w_value):
        space = self.space
        key = self.try_unwrap_key(space, w_key)
        if key is not None:
            self.setitem_str(w_dict, key, w_value)
        else:
            self.switch_to_object_strategy(w_dict)
            w_dict.setitem(w_key, w_value)

    def setitem_str(self, w_dict, key, w_value):
        cell = self.getdictvalue_no_unwrapping(w_dict, key)
        return self._setitem_str_cell_known(cell, w_dict, key, w_value)

    def _setitem_str_cell_known(self, cell, w_dict, key, w_value):
        w_value = write_cell(self.space, cell, w_value)
        if w_value is None:
            return
        self.mutated()
        self.unerase(w_dict.dstorage)[key] = w_value

    def setdefault(self, w_dict, w_key, w_default):
        space = self.space
        key = self.try_unwrap_key(space, w_key)
        if key is not None:
            cell = self.getdictvalue_no_unwrapping(w_dict, key)
            w_result = unwrap_cell(self.space, cell)
            if w_result is not None:
                return w_result
            self._setitem_str_cell_known(cell, w_dict, key, w_default)
            return w_default
        else:
            self.switch_to_object_strategy(w_dict)
            return w_dict.setdefault(w_key, w_default)

    def delitem(self, w_dict, w_key):
        space = self.space
        w_key_type = space.type(w_key)
        key = self.try_unwrap_key(space, w_key)
        if key is not None:
            dict_w = self.unerase(w_dict.dstorage)
            try:
                del dict_w[key]
            except KeyError:
                raise
            else:
                self.mutated()
        elif _never_equal_to_string(space, w_key_type):
            raise KeyError
        else:
            self.switch_to_object_strategy(w_dict)
            w_dict.delitem(w_key)

    def length(self, w_dict):
        return len(self.unerase(w_dict.dstorage))

    def getitem(self, w_dict, w_key):
        space = self.space
        w_lookup_type = space.type(w_key)
        key = self.try_unwrap_key(space, w_key)
        if key is not None:
            return self.getitem_str(w_dict, key)
        elif _never_equal_to_string(space, w_lookup_type):
            return None
        else:
            self.switch_to_object_strategy(w_dict)
            return w_dict.getitem(w_key)

    def getitem_str(self, w_dict, key):
        cell = self.getdictvalue_no_unwrapping(w_dict, key)
        return unwrap_cell(self.space, cell)

    def w_keys(self, w_dict):
        space = self.space
        l = self.unerase(w_dict.dstorage).keys()
        return space.newlist_text(l)

    def values(self, w_dict):
        iterator = self.unerase(w_dict.dstorage).itervalues
        return [unwrap_cell(self.space, cell) for cell in iterator()]

    def items(self, w_dict):
        space = self.space
        iterator = self.unerase(w_dict.dstorage).iteritems
        return [space.newtuple([_wrapkey(space, key), unwrap_cell(self.space, cell)])
                for key, cell in iterator()]

    def clear(self, w_dict):
        self.unerase(w_dict.dstorage).clear()
        self.mutated()

    def popitem(self, w_dict):
        space = self.space
        d = self.unerase(w_dict.dstorage)
        key, cell = d.popitem()
        self.mutated()
        return _wrapkey(space, key), unwrap_cell(self.space, cell)

    def switch_to_object_strategy(self, w_dict):
        space = self.space
        d = self.unerase(w_dict.dstorage)
        strategy = space.fromcache(ObjectDictStrategy)
        d_new = strategy.unerase(strategy.get_empty_storage())
        for key, cell in d.iteritems():
            d_new[_wrapkey(space, key)] = unwrap_cell(self.space, cell)
        w_dict.set_strategy(strategy)
        w_dict.dstorage = strategy.erase(d_new)

    def getiterkeys(self, w_dict):
        return self.unerase(w_dict.dstorage).iterkeys()

    def getitervalues(self, w_dict):
        return self.unerase(w_dict.dstorage).itervalues()

    def getiteritems_with_hash(self, w_dict):
        return objectmodel.iteritems_with_hash(self.unerase(w_dict.dstorage))

    def getiterreversed(self, w_dict):
        return objectmodel.reversed_dict(self.unerase(w_dict.dstorage))

    wrapkey = _wrapkey

    def wrapvalue(space, value):
        return unwrap_cell(space, value)

def remove_cell(w_dict, space, name):
    from pypy.objspace.std.dictmultiobject import W_DictMultiObject
    if isinstance(w_dict, W_DictMultiObject):
        strategy = w_dict.get_strategy()
        if isinstance(strategy, ModuleDictStrategy):
            w_value = strategy.getitem_str(w_dict, name)
            dict_w = strategy.unerase(w_dict.dstorage)
            strategy.mutated()
            dict_w[name] = w_value # store without cell
    # nothing to do, not a W_DictMultiObject or wrong strategy


create_iterator_classes(ModuleDictStrategy)
