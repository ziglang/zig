"""
Two magic tricks for classes:

    class X:
        __metaclass__ = extendabletype
        ...

    # in some other file...
    class __extend__(X):
        ...      # and here you can add new methods and class attributes to X

Mostly useful together with the second trick, which lets you build
methods whose 'self' is a pair of objects instead of just one:

    class __extend__(pairtype(X, Y)):
        attribute = 42
        def method((x, y), other, arguments):
            ...

    pair(x, y).attribute
    pair(x, y).method(other, arguments)

This finds methods and class attributes based on the actual
class of both objects that go into the pair(), with the usual
rules of method/attribute overriding in (pairs of) subclasses.

For more information, see test_pairtype.
"""

class extendabletype(type):
    """A type with a syntax trick: 'class __extend__(t)' actually extends
    the definition of 't' instead of creating a new subclass."""
    def __new__(cls, name, bases, dict):
        if name == '__extend__':
            for cls in bases:
                for key, value in dict.items():
                    if key == '__module__':
                        continue
                    # XXX do we need to provide something more for pickling?
                    setattr(cls, key, value)
            return None
        else:
            return super(extendabletype, cls).__new__(cls, name, bases, dict)


def pair(a, b):
    """Return a pair object."""
    tp = pairtype(a.__class__, b.__class__)
    return tp((a, b))   # tp is a subclass of tuple

pairtypecache = {}

def pairtype(cls1, cls2):
    """type(pair(a,b)) is pairtype(a.__class__, b.__class__)."""
    try:
        pair = pairtypecache[cls1, cls2]
    except KeyError:
        name = 'pairtype(%s, %s)' % (cls1.__name__, cls2.__name__)
        bases1 = [pairtype(base1, cls2) for base1 in cls1.__bases__]
        bases2 = [pairtype(cls1, base2) for base2 in cls2.__bases__]
        bases = tuple(bases1 + bases2) or (tuple,)  # 'tuple': ultimate base
        pair = pairtypecache[cls1, cls2] = extendabletype(name, bases, {})
    return pair

def pairmro(cls1, cls2):
    """
    Return the resolution order on pairs of types for double dispatch.

    This order is compatible with the mro of pairtype(cls1, cls2).
    """
    for base2 in cls2.__mro__:
        for base1 in cls1.__mro__:
            yield (base1, base2)

class DoubleDispatchRegistry(object):
    """
    A mapping of pairs of types to arbitrary objects respecting inheritance
    """
    def __init__(self):
        self._registry = {}
        self._cache = {}

    def __getitem__(self, clspair):
        try:
            return self._cache[clspair]
        except KeyError:
            cls1, cls2 = clspair
            for c1, c2 in pairmro(cls1, cls2):
                if (c1, c2) in self._cache:
                    return self._cache[(c1, c2)]
            else:
                raise

    def __setitem__(self, clspair, value):
        self._registry[clspair] = value
        self._cache = self._registry.copy()

def doubledispatch(func):
    """
    Decorator returning a double-dispatch function

    Usage
    -----
        >>> @doubledispatch
        ... def func(x, y):
        ...     return 0
        >>> @func.register(basestring, basestring)
        ... def func_string_string(x, y):
        ...     return 42
        >>> func(1, 2)
        0
        >>> func('x', u'y')
        42
    """
    return DoubleDispatchFunction(func)

class DoubleDispatchFunction(object):
    def __init__(self, func):
        self._registry = DoubleDispatchRegistry()
        self._default = func

    def __call__(self, arg1, arg2, *args, **kwargs):
        try:
            func = self._registry[type(arg1), type(arg2)]
        except KeyError:
            func = self._default
        return func(arg1, arg2, *args, **kwargs)

    def register(self, cls1, cls2):
        def decorator(func):
            self._registry[cls1, cls2] = func
            return func
        return decorator
