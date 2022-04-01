from __pypy__ import reversed_dict, move_to_end, objects_in_repr
from _operator import eq as _eq


class OrderedDict(dict):
    '''Dictionary that remembers insertion order.

    In PyPy all dicts are ordered anyway.  This is mostly useful as a
    placeholder to mean "this dict must be ordered even on CPython".

    Known difference: iterating over an OrderedDict which is being
    concurrently modified raises RuntimeError in PyPy.  In CPython
    instead we get some behavior that appears reasonable in some
    cases but is nonsensical in other cases.  This is officially
    forbidden by the CPython docs, so we forbid it explicitly for now.
    '''
    __module__ = 'collections'

    def __init__(*args, **kwds):
        '''Initialize an ordered dictionary.  The signature is the same as
        regular dictionaries, but keyword arguments are not recommended because
        their insertion order is arbitrary.

        '''
        if not args:
            raise TypeError("descriptor '__init__' of 'OrderedDict' object "
                            "needs an argument")
        self, *args = args
        if len(args) > 1:
            raise TypeError('expected at most 1 arguments, got %d' % len(args))
        self.__update(*args, **kwds)

    def update(*args, **kwds):
        ''' D.update([E, ]**F) -> None.  Update D from mapping/iterable E and F.
            If E present and has a .keys() method, does:     for k in E: D[k] = E[k]
            If E present and lacks .keys() method, does:     for (k, v) in E: D[k] = v
            In either case, this is followed by: for k, v in F.items(): D[k] = v
        '''
        if not args:
            raise TypeError("descriptor 'update' of 'OrderedDict' object "
                            "needs an argument")
        self, *args = args
        if len(args) > 1:
            raise TypeError('update expected at most 1 arguments, got %d' %
                            len(args))
        if args:
            other = args[0]
            if hasattr(other, "keys"):
                for key in other.keys():
                    self[key] = other[key]
            elif hasattr(other, 'items'):
                for key, value in other.items():
                    self[key] = value
            else:
                for key, value in other:
                    self[key] = value
        for key, value in kwds.items():
            self[key] = value
    __update = update

    def __reversed__(self):
        return reversed_dict(self)

    def popitem(self, last=True):
        '''od.popitem() -> (k, v), return and remove a (key, value) pair.
        Pairs are returned in LIFO order if last is true or FIFO order if false.

        '''
        if last:
            return dict.popitem(self)
        else:
            it = dict.__iter__(self)
            try:
                k = next(it)
            except StopIteration:
                raise KeyError('dictionary is empty')
            return (k, self.pop(k))

    def move_to_end(self, key, last=True):
        '''Move an existing element to the end (or beginning if last==False).

        Raises KeyError if the element does not exist.
        When last=True, acts like a fast version of self[key]=self.pop(key).

        '''
        return move_to_end(self, key, last)

    def __repr__(self):
        'od.__repr__() <==> repr(od)'
        if not self:
            return '%s()' % (self.__class__.__name__,)
        currently_in_repr = objects_in_repr()
        if self in currently_in_repr:
            return '...'
        currently_in_repr[self] = 1
        try:
            return '%s(%r)' % (self.__class__.__name__, list(self.items()))
        finally:
            try:
                del currently_in_repr[self]
            except:
                pass

    def __reduce__(self):
        'Return state information for pickling'
        inst_dict = vars(self).copy()
        return self.__class__, (), inst_dict or None, None, iter(self.items())

    def copy(self):
        'od.copy() -> a shallow copy of od'
        return self.__class__(self)

    def __eq__(self, other):
        '''od.__eq__(y) <==> od==y.  Comparison to another OD is order-sensitive
        while comparison to a regular mapping is order-insensitive.

        '''
        if isinstance(other, OrderedDict):
            return dict.__eq__(self, other) and all(map(_eq, self, other))
        return dict.__eq__(self, other)

    def __or__(self, other):
        if not isinstance(other, dict):
            return NotImplemented
        copyself = self.copy()
        copyself.update(other)
        return copyself

    def __ror__(self, other):
        if not isinstance(other, dict):
            return NotImplemented
        copy = type(self)(other)
        copy.update(self)
        return copy

    # for __ior__ the dict implementation is fine

    __ne__ = object.__ne__

    def keys(self):
        "D.keys() -> a set-like object providing a view on D's keys"
        return _OrderedDictKeysView(self)

    def items(self):
        "D.items() -> a set-like object providing a view on D's items"
        return _OrderedDictItemsView(self)

    def values(self):
        "D.values() -> an object providing a view on D's values"
        return _OrderedDictValuesView(self)

dict_keys = type({}.keys())
dict_values = type({}.values())
dict_items = type({}.items())

class _OrderedDictKeysView(dict_keys):
    def __reversed__(self):
        yield from reversed_dict(self._dict)

class _OrderedDictItemsView(dict_items):
    def __reversed__(self):
        for key in reversed_dict(self._dict):
            yield (key, self._dict[key])

class _OrderedDictValuesView(dict_values):
    def __reversed__(self):
        for key in reversed_dict(self._dict):
            yield self._dict[key]
