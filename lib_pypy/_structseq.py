"""
Implementation helper: a struct that looks like a tuple.  See timemodule
and posixmodule for example uses.
"""
from __pypy__ import hidden_applevel

class structseqfield(object):
    """Definition of field of a structseq.  The 'index' is for positional
    tuple-like indexing.  Fields whose index is after a gap in the numbers
    cannot be accessed like this, but only by name.
    """
    def __init__(self, index, doc=None, default=lambda self: None):
        self.__name__ = '?'
        self.index    = index    # patched to None if not positional
        self._index   = index
        self.__doc__  = doc
        self._default = default

    def __repr__(self):
        return '<field %s (%s)>' % (self.__name__,
                                    self.__doc__ or 'undocumented')

    @hidden_applevel
    def __get__(self, obj, typ=None):
        if obj is None:
            return self
        if self.index is None:
            return obj.__dict__[self.__name__]
        else:
            return obj[self.index]

    def __set__(self, obj, value):
        raise AttributeError("readonly attribute")


class structseqtype(type):

    def __new__(metacls, classname, bases, dict):
        assert not bases
        fields_by_index = {}
        for name, field in dict.items():
            if isinstance(field, structseqfield):
                assert field._index not in fields_by_index
                fields_by_index[field._index] = field
                field.__name__ = name
        n_fields = len(fields_by_index)
        dict['n_fields'] = n_fields

        extra_fields = sorted(fields_by_index.items())
        n_sequence_fields = 0
        invis_fields = []
        if 'n_sequence_fields' in dict:
            n_sequence_fields = dict['n_sequence_fields']
            extra_fields = extra_fields[n_sequence_fields:]
        else:
            while extra_fields and extra_fields[0][0] == n_sequence_fields:
                extra_fields.pop(0)
                n_sequence_fields += 1

        dict['n_sequence_fields'] = n_sequence_fields
        dict['n_unnamed_fields'] = 0     # no fully anonymous fields in PyPy

        extra_fields = [field for index, field in extra_fields]
        for i,field in enumerate(extra_fields):
            field.index = None     # no longer relevant

        dict['_extra_fields'] = tuple(extra_fields)
        if '__new__' not in dict:
            dict['__new__'] = structseq_new
        dict['__reduce__'] = structseq_reduce
        dict['__setattr__'] = structseq_setattr
        dict['__repr__'] = structseq_repr
        dict['__str__'] = structseq_repr
        dict['_name'] = dict.get('name', '')
        return type.__new__(metacls, classname, (tuple,), dict)


builtin_dict = dict

@hidden_applevel
def structseq_new(cls, sequence, dict={}):
    dict = builtin_dict(dict)
    # visible fields
    visible_count = cls.n_sequence_fields
    # total fields (unnamed are not yet supported, extra fields not included)
    real_count = cls.n_fields
    if visible_count == 1:
        sequence = tuple([sequence])
    else:
        sequence = tuple(sequence)
    length = len(sequence)
    if length < visible_count:
        if visible_count < real_count:
            msg = "at least"
        else:
            msg = "exactly"
        raise TypeError("expected a sequence with %s %d items. has %d" % (
            msg, visible_count, length))
    if length > visible_count:
        if length > real_count:
            if visible_count < real_count:
                msg = "at most"
            else:
                msg = "exactly"
            raise TypeError("expected a sequence with %s %d items. has %d" \
                            % (msg, real_count, length))
        for field, value in zip(cls._extra_fields, sequence[visible_count:]):
            name = field.__name__
            if name in dict:
                raise TypeError("duplicate value for %r" % (name,))
            dict[name] = value
        sequence = sequence[:visible_count]
    result = tuple.__new__(cls, sequence)
    object.__setattr__(result, '__dict__', dict)
    for field in cls._extra_fields:
        name = field.__name__
        if name not in dict:
            dict[name] = field._default(result)

    return result

def structseq_reduce(self):
    return type(self), (tuple(self), self.__dict__)

def structseq_setattr(self, attr, value):
    if attr not in type(self).__dict__:
        raise AttributeError("%r object has no attribute %r" % (
            self.__class__.__name__, attr))
    else:
        raise AttributeError("readonly attribute")

def structseq_repr(self):
    fields = {}
    visible_count = self.n_sequence_fields
    for field in type(self).__dict__.values():
        if isinstance(field, structseqfield) and \
           field._index <= visible_count:
            fields[field._index] = field
    parts = ["%s=%r" % (fields[index].__name__, value)
            for index, value in enumerate(self[:visible_count])]
    return "%s(%s)" % (self._name, ", ".join(parts))


class SimpleNamespace:
    """A simple attribute-based namespace.

SimpleNamespace(**kwargs)"""

    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)

    def __repr__(self):
        ident = id(self)
        if ident in sns_recurse:
            return "namespace(...)"
        sns_recurse.add(ident)
        try:
            pairs = ('%s=%r' % item for item in sorted(self.__dict__.items()))
            return "namespace(%s)" % ', '.join(pairs)
        finally:
            sns_recurse.discard(ident)

    def __eq__(self, other):
        if issubclass(type(other), SimpleNamespace):
            return self.__dict__ == other.__dict__
        return NotImplemented

    def __ne__(self, other):
        if issubclass(type(other), SimpleNamespace):
            return self.__dict__ != other.__dict__
        return NotImplemented

sns_recurse = set()

# This class is not exposed in sys, but by the types module.
SimpleNamespace.__module__ = 'types'
