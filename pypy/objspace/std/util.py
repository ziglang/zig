from rpython.rlib.rstring import InvalidBaseError

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter import gateway

IDTAG_SHIFT   = 4
IDTAG_ALT_UID = 2     # gives an alternate id() from the same real uid

IDTAG_INT     = 1
IDTAG_LONG    = 3
IDTAG_FLOAT   = 5
IDTAG_COMPLEX = 7
IDTAG_SPECIAL = 11    # -1 - (-maxunicode-1): unichar
                      # 0 - 255: char
                      # 256: empty string
                      # 257: empty unicode
                      # 258: empty tuple
                      # 259: empty frozenset

CMP_OPS = dict(lt='<', le='<=', eq='==', ne='!=', gt='>', ge='>=')
BINARY_BITWISE_OPS = {'and': '&', 'lshift': '<<', 'or': '|', 'rshift': '>>',
                      'xor': '^'}
BINARY_OPS = dict(add='+', div='/', floordiv='//', mod='%', mul='*', sub='-',
                  truediv='/', matmul='@', **BINARY_BITWISE_OPS)
COMMUTATIVE_OPS = ('add', 'mul', 'and', 'or', 'xor')


def negate(f):
    """Create a function which calls `f` and negates its result.  When the
    result is ``space.w_NotImplemented``, ``space.w_NotImplemented`` is
    returned. This is useful for complementing e.g. the __ne__ descriptor if
    your type already defines a __eq__ descriptor.
    """
    def _negator(self, space, w_other):
        # no need to use space.is_ / space.not_
        tmp = f(self, space, w_other)
        if tmp is space.w_NotImplemented:
            return space.w_NotImplemented
        return space.newbool(tmp is space.w_False)
    _negator.func_name = 'negate-%s' % f.func_name
    return _negator

def get_positive_index(where, length):
    if where < 0:
        where += length
        if where < 0:
            where = 0
    elif where > length:
        where = length
    assert where >= 0
    return where


def wrap_parsestringerror(space, e, w_source):
    if isinstance(e, InvalidBaseError):
        raise OperationError(space.w_ValueError, space.newtext(e.msg))
    else:
        raise oefmt(space.w_ValueError, '%s: %R',
                            e.msg, w_source)

app = gateway.applevel(r'''
    def _classdir(klass):
        """__dir__ for type objects

        This includes all attributes of klass and all of the base
        classes recursively.
        """
        names = set()
        ns = getattr(klass, '__dict__', None)
        if ns is not None:
            names.update(ns)
        bases = getattr(klass, '__bases__', None)
        if bases is not None:
            # Note that since we are only interested in the keys, the order
            # we merge classes is unimportant
            for base in bases:
                names.update(_classdir(base))
        return names

    def _objectdir(obj):
        """__dir__ for generic objects

         Returns __dict__, __class__ and recursively up the
         __class__.__bases__ chain.
        """
        names = set()
        ns = getattr(obj, '__dict__', None)
        if isinstance(ns, dict):
            names.update(ns)
        klass = getattr(obj, '__class__', None)
        if klass is not None:
            names.update(_classdir(klass))
        return names
''', filename=__file__)

_classdir = app.interphook('_classdir')
_objectdir = app.interphook('_objectdir')

def generic_alias_class_getitem(space, w_cls, w_item):
    "See PEP 585"
    w_builtins = space.getbuiltinmodule('builtins')
    w_mod = space.call_method(w_builtins, '__import__',
            space.newtext("_pypy_generic_alias"))
    w_GenericAlias = space.getattr(w_mod, space.newtext("GenericAlias"))
    return space.call_function(w_GenericAlias, w_cls, w_item)
