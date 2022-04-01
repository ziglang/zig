try:
    from __pypy__ import identity_dict as idict
except ImportError:
    idict = None

from UserDict import DictMixin


class IdentityDictPurePython(object, DictMixin):
    __slots__ = "_dict _keys".split()

    def __init__(self):
        self._dict = {}
        self._keys = {} # id(obj) -> obj

    def __getitem__(self, arg):
        return self._dict[id(arg)]

    def __setitem__(self, arg, val):
        self._keys[id(arg)] = arg
        self._dict[id(arg)] = val

    def __delitem__(self, arg):
        del self._keys[id(arg)]
        del self._dict[id(arg)]

    def keys(self):
        return self._keys.values()

    def __contains__(self, arg):
        return id(arg) in self._dict

    def copy(self):
        d = type(self)()
        d.update(self.items())
        assert len(d) == len(self)
        return d


class IdentityDictPyPy(object, DictMixin):
    __slots__ = ["_dict"]

    def __init__(self):
        self._dict = idict()

    def __getitem__(self, arg):
        return self._dict[arg]

    def __setitem__(self, arg, val):
        self._dict[arg] = val

    def __delitem__(self, arg):
        del self._dict[arg]

    def keys(self):
        return self._dict.keys()

    def __contains__(self, arg):
        return arg in self._dict

    def copy(self):
        d = type(self)()
        d.update(self.items())
        assert len(d) == len(self)
        return d

if idict is None:
    identity_dict = IdentityDictPurePython
else:
    identity_dict = IdentityDictPyPy

