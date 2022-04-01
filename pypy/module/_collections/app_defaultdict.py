# NOT_RPYTHON

# For now this is here, living at app-level.
#
# The issue is that for now we don't support writing interp-level
# subclasses of W_Root that inherit at app-level from a type like
# 'dict'.  But what we can do is write individual methods at
# interp-level.

import _collections


class defaultdict(dict):
    __slots__ = ['default_factory']
    __module__ = 'collections'

    def __init__(self, *args, **kwds):
        if len(args) > 0:
            default_factory = args[0]
            args = args[1:]
            if not callable(default_factory) and default_factory is not None:
                raise TypeError("first argument must be callable")
        else:
            default_factory = None
        defaultdict.default_factory.__set__(self, default_factory)
        super(defaultdict, self).__init__(*args, **kwds)

    def __missing__(self, key):
        pass    # this method is written at interp-level
    __missing__.__code__ = _collections.__missing__.__code__

    def __repr__(self, recurse=set()):
        # XXX not thread-safe, but good enough
        dictrepr = super(defaultdict, self).__repr__()
        if id(self) in recurse:
            factoryrepr = "..."
        else:
            try:
                recurse.add(id(self))
                factoryrepr = repr(self.default_factory)
            finally:
                recurse.remove(id(self))
        return "%s(%s, %s)" % (self.__class__.__name__, factoryrepr, dictrepr)

    def copy(self):
        return type(self)(self.default_factory, self)

    __copy__ = copy

    def __reduce__(self):
        """
        __reduce__ must return a 5-tuple as follows:

           - factory function
           - tuple of args for the factory function
           - additional state (here None)
           - sequence iterator (here None)
           - dictionary iterator (yielding successive (key, value) pairs

           This API is used by pickle.py and copy.py.
        """
        return (type(self), (self.default_factory,), None, None,
                iter(self.items()))

    def __or__(self, other):
        if not isinstance(other, dict):
            return NotImplemented
        copyself = self.copy()
        copyself.update(other)
        return copyself

    def __ror__(self, other):
        if not isinstance(other, dict):
            return NotImplemented
        res = type(self)(self.default_factory, other)
        res.update(self)
        return res

    # for __ior__ the dict implementation is fine
