from rpython.annotator.model import (
    s_ImpossibleValue, SomeInteger, s_Bool, union, AnnotatorError)
from rpython.annotator.listdef import ListItem
from rpython.rlib.objectmodel import compute_hash


class DictKey(ListItem):
    s_rdict_eqfn = s_ImpossibleValue
    s_rdict_hashfn = s_ImpossibleValue

    def __init__(self, bookkeeper, s_value, is_r_dict=False):
        ListItem.__init__(self, bookkeeper, s_value)
        self.custom_eq_hash = is_r_dict

    def patch(self):
        for dictdef in self.itemof:
            dictdef.dictkey = self

    def merge(self, other):
        if self is not other:
            assert self.custom_eq_hash == other.custom_eq_hash, (
                "mixing plain dictionaries with r_dict()")
            ListItem.merge(self, other)
            if self.custom_eq_hash:
                self.update_rdict_annotations(other.s_rdict_eqfn,
                                              other.s_rdict_hashfn,
                                              other=other)

    def generalize(self, s_other_value):
        updated = ListItem.generalize(self, s_other_value)
        if updated and self.custom_eq_hash:
            self.emulate_rdict_calls()
        return updated

    def update_rdict_annotations(self, s_eqfn, s_hashfn, other=None):
        assert self.custom_eq_hash
        s_eqfn = union(s_eqfn, self.s_rdict_eqfn)
        s_hashfn = union(s_hashfn, self.s_rdict_hashfn)
        self.s_rdict_eqfn = s_eqfn
        self.s_rdict_hashfn = s_hashfn
        self.emulate_rdict_calls(other=other)

    def emulate_rdict_calls(self, other=None):
        myeq = (self, 'eq')
        myhash = (self, 'hash')
        if other:
            replace_othereq = [(other, 'eq')]
            replace_otherhash = [(other, 'hash')]
        else:
            replace_othereq = replace_otherhash = ()

        s_key = self.s_value

        s = self.bookkeeper.emulate_pbc_call(
            myeq, self.s_rdict_eqfn, [s_key, s_key], replace=replace_othereq)
        if not s_Bool.contains(s):
            raise AnnotatorError(
                "the custom eq function of an r_dict must return a boolean"
                " (got %r)" % (s,))

        s = self.bookkeeper.emulate_pbc_call(
            myhash, self.s_rdict_hashfn, [s_key], replace=replace_otherhash)
        if not SomeInteger().contains(s):
            raise AnnotatorError(
                "the custom hash function of an r_dict must return an integer"
                " (got %r)" % (s,))


class DictValue(ListItem):
    def patch(self):
        for dictdef in self.itemof:
            dictdef.dictvalue = self


class DictDef(object):
    """A dict definition remembers how general the keys and values in that
    particular dict have to be.  Every dict creation makes a new DictDef,
    and the union of two dicts merges the DictKeys and DictValues that each
    DictDef stores."""

    def __init__(self, bookkeeper, s_key = s_ImpossibleValue,
                                 s_value = s_ImpossibleValue,
                               is_r_dict = False,
                           force_non_null = False,
                           simple_hash_eq = False):
        self.dictkey = DictKey(bookkeeper, s_key, is_r_dict)
        self.dictkey.itemof[self] = True
        self.dictvalue = DictValue(bookkeeper, s_value)
        self.dictvalue.itemof[self] = True
        self.force_non_null = force_non_null
        self.simple_hash_eq = simple_hash_eq

    def read_key(self, position_key):
        self.dictkey.read_locations.add(position_key)
        return self.dictkey.s_value

    def read_value(self, position_key):
        self.dictvalue.read_locations.add(position_key)
        return self.dictvalue.s_value

    def same_as(self, other):
        return (self.dictkey is other.dictkey and
                self.dictvalue is other.dictvalue)

    def union(self, other):
        self.dictkey.merge(other.dictkey)
        self.dictvalue.merge(other.dictvalue)
        return self

    def generalize_key(self, s_key):
        self.dictkey.generalize(s_key)

    def generalize_value(self, s_value):
        self.dictvalue.generalize(s_value)

    def __repr__(self):
        return '<{%r: %r}>' % (self.dictkey.s_value, self.dictvalue.s_value)
