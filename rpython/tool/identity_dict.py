try:
    from __pypy__ import identity_dict as idict
except ImportError:
    idict = None

from collections import MutableMapping


class IdentityDictPurePython(MutableMapping):
    __slots__ = "_dict _keys".split()

    def __init__(self):
        self._dict = {}
        self._keys = {}  # id(obj) -> obj

    def __getitem__(self, arg):
        return self._dict[id(arg)]

    def __setitem__(self, arg, val):
        self._keys[id(arg)] = arg
        self._dict[id(arg)] = val

    def __delitem__(self, arg):
        del self._keys[id(arg)]
        del self._dict[id(arg)]

    def __iter__(self):
        return self._keys.itervalues()

    def __len__(self):
        return len(self._keys)

    def __contains__(self, arg):
        return id(arg) in self._dict

    def copy(self):
        d = type(self)()
        d.update(self.iteritems())
        assert len(d) == len(self)
        return d


class IdentityDictPyPy(MutableMapping):

    def __init__(self):
        self._dict = idict()

    def __getitem__(self, arg):
        return self._dict[arg]

    def __setitem__(self, arg, val):
        self._dict[arg] = val

    def __delitem__(self, arg):
        del self._dict[arg]

    def __iter__(self):
        return iter(self._dict.keys())

    def __len__(self):
        return len(self._dict)

    def __contains__(self, arg):
        return arg in self._dict

    def copy(self):
        d = type(self)()
        d.update(self.iteritems())
        assert len(d) == len(self)
        return d

    def __nonzero__(self):
        return bool(self._dict)

if idict is None:
    identity_dict = IdentityDictPurePython
else:
    identity_dict = IdentityDictPyPy
