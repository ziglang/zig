""" Supplies the internal functions for functools.py in the standard library """
try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f

try: from reprlib import recursive_repr as _recursive_repr
except ImportError: _recursive_repr = lambda: (lambda f: f)
from _pypy_generic_alias import GenericAlias


sentinel = object()

@builtinify
def reduce(func, sequence, initial=sentinel):
    """reduce(function, sequence[, initial]) -> value

Apply a function of two arguments cumulatively to the items of a sequence,
from left to right, so as to reduce the sequence to a single value.
For example, reduce(lambda x, y: x+y, [1, 2, 3, 4, 5]) calculates
((((1+2)+3)+4)+5).  If initial is present, it is placed before the items
of the sequence in the calculation, and serves as a default when the
sequence is empty."""
    iterator = iter(sequence)
    if initial is sentinel:
        try:
            initial = next(iterator)
        except StopIteration:
            raise TypeError("reduce() of empty sequence with no initial value")
    result = initial
    for item in iterator:
        result = func(result, item)
    return result


class partial(object):
    """
    partial(func, *args, **keywords) - new function with partial application
    of the given arguments and keywords.
    """

    __slots__ = ('_func', '_args', '_keywords', '__dict__')
    __module__ = 'functools'   # instead of '_functools'

    def __init__(*args, **keywords):
        if len(args) < 2:
            raise TypeError('__init__() takes at least 2 arguments (%d given)'
                            % len(args))
        self, func, args = args[0], args[1], args[2:]
        if not callable(func):
            raise TypeError("the first argument must be callable")
        if isinstance(func, partial):
            args = func._args + args
            tmpkw = func._keywords.copy()
            tmpkw.update(keywords)
            keywords = tmpkw
            del tmpkw
            func = func._func
        self._func = func
        self._args = args
        self._keywords = keywords

    def __delattr__(self, key):
        if key == '__dict__':
            raise TypeError("a partial object's dictionary may not be deleted")
        object.__delattr__(self, key)

    @property
    def func(self):
        return self._func

    @property
    def args(self):
        return self._args

    @property
    def keywords(self):
        return self._keywords

    def __call__(self, *fargs, **fkeywords):
        if self._keywords:
            fkeywords = dict(self._keywords, **fkeywords)
        return self._func(*(self._args + fargs), **fkeywords)

    @_recursive_repr()
    def __repr__(self):
        cls = type(self)
        if cls is partial:
            name = 'functools.partial'
        else:
            name = cls.__name__
        tmp = [repr(self.func)]
        for arg in self.args:
            tmp.append(repr(arg))
        if self.keywords:
            for k, v in self.keywords.items():
                tmp.append("{}={!r}".format(k, v))
        return "{}({})".format(name, ', '.join(tmp))

    def __reduce__(self):
        d = dict((k, v) for k, v in self.__dict__.items() if k not in
                ('_func', '_args', '_keywords'))
        if len(d) == 0:
            d = None
        return (type(self), (self._func,),
                (self._func, self._args, self._keywords, d))

    def __setstate__(self, state):
        if not isinstance(state, tuple) or len(state) != 4:
            raise TypeError("invalid partial state")

        func, args, keywords, d = state

        if (not callable(func) or not isinstance(args, tuple) or
            (keywords is not None and not isinstance(keywords, dict))):
            raise TypeError("invalid partial state")

        self._func = func
        self._args = tuple(args)

        if keywords is None:
            keywords = {}
        elif type(keywords) is not dict:
            keywords = dict(keywords)
        self._keywords = keywords

        if d is None:
            self.__dict__.clear()
        else:
            self.__dict__.update(d)

    def __class_getitem__(self, item):
        return GenericAlias(self, item)


@builtinify
def cmp_to_key(mycmp):
    """Convert a cmp= function into a key= function"""
    class K(object):
        __slots__ = ['obj']
        def __init__(self, obj):
            self.obj = obj
        def __lt__(self, other):
            return mycmp(self.obj, other.obj) < 0
        def __gt__(self, other):
            return mycmp(self.obj, other.obj) > 0
        def __eq__(self, other):
            return mycmp(self.obj, other.obj) == 0
        def __le__(self, other):
            return mycmp(self.obj, other.obj) <= 0
        def __ge__(self, other):
            return mycmp(self.obj, other.obj) >= 0
        __hash__ = None
    return K
