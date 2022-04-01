"""
Interp-level implementation of the basic space operations.
"""

import math

from pypy.interpreter import gateway
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec, WrappedDefault
from rpython.rlib.rfloat import isfinite, round_double, round_away
from rpython.rlib import rfloat, rutf8
import __builtin__

def abs(space, w_val):
    "abs(number) -> number\n\nReturn the absolute value of the argument."
    return space.abs(w_val)

def ascii(space, w_obj):
    """"ascii(object) -> string

    As repr(), return a string containing a printable representation of an
    object, but escape the non-ASCII characters in the string returned by
    repr() using \\x, \\u or \\U escapes.  This generates a string similar
    to that returned by repr() in Python 2."""
    from pypy.objspace.std.unicodeobject import ascii_from_object
    return ascii_from_object(space, w_obj)

@unwrap_spec(code=int)
def chr(space, code):
    "Return a Unicode string of one character with the given ordinal."
    if code < 0 or code > 0x10FFFF:
        raise oefmt(space.w_ValueError, "chr() arg out of range")
    s = rutf8.unichr_as_utf8(code, allow_surrogates=True)
    return space.newutf8(s, 1)

def len(space, w_obj):
    "len(object) -> integer\n\nReturn the number of items of a sequence or mapping."
    return space.len(w_obj)


def checkattrname(space, w_name, msg):
    # This is a check to ensure that getattr/setattr/delattr only pass a
    # ascii string to the rest of the code.  XXX not entirely sure if these
    # functions are the only way for non-string objects to reach
    # space.{get,set,del}attr()...
    # Note that if w_name is already an exact string it must be ascii encoded
    if not space.isinstance_w(w_name, space.w_text):
        try:
            name = space.text_w(w_name)    # typecheck
        except OperationError as e:
            if e.match(space, space.w_UnicodeError):
                raise e
            raise oefmt(space.w_TypeError,
                 "%s(): attribute name must be string", msg)
        w_name = space.newtext(name)
    return w_name

def delattr(space, w_object, w_name):
    """Delete a named attribute on an object.
delattr(x, 'y') is equivalent to ``del x.y''."""
    w_name = checkattrname(space, w_name, 'delattr')
    space.delattr(w_object, w_name)
    return space.w_None

def getattr(space, w_object, w_name, w_defvalue=None):
    """Get a named attribute from an object.
getattr(x, 'y') is equivalent to ``x.y''."""
    w_name = checkattrname(space, w_name, 'getattr')
    try:
        return space.getattr(w_object, w_name)
    except OperationError as e:
        if w_defvalue is not None:
            if e.match(space, space.w_AttributeError):
                return w_defvalue
        raise

def hasattr(space, w_object, w_name):
    """Return whether the object has an attribute with the given name.
    (This is done by calling getattr(object, name) and catching exceptions.)"""
    w_name = checkattrname(space, w_name, 'hasattr')
    try:
        space.getattr(w_object, w_name)
    except OperationError as e:
        if e.match(space, space.w_AttributeError):
            return space.w_False
        raise
    else:
        return space.w_True

def hash(space, w_object):
    """Return a hash value for the object.  Two objects which compare as
equal have the same hash value.  It is possible, but unlikely, for
two un-equal objects to have the same hash value."""
    return space.hash(w_object)

def id(space, w_object):
    "Return the identity of an object: id(x) == id(y) if and only if x is y."
    w_res = space.id(w_object)
    space.audit("builtins.id", [w_res])
    return w_res

def divmod(space, w_x, w_y):
    """Return the tuple ((x-x%y)/y, x%y).  Invariant: div*y + mod == x."""
    return space.divmod(w_x, w_y)

# ____________________________________________________________

def round(space, w_number, w_ndigits=None):
    """round(number[, ndigits]) -> number

Round a number to a given precision in decimal digits (default 0 digits).
This returns an int when called with one argument or if ndigits=None,
otherwise the same type as the number. ndigits may be negative."""
    round = space.lookup(w_number, '__round__')
    if round is None:
        raise oefmt(space.w_TypeError,
                    "type %T doesn't define __round__ method", w_number)
    if space.is_none(w_ndigits):
        return space.get_and_call_function(round, w_number)
    else:
        return space.get_and_call_function(round, w_number, w_ndigits)

# ____________________________________________________________

iter_sentinel = gateway.applevel('''
    # NOT_RPYTHON  -- uses yield
    # App-level implementation of the iter(callable,sentinel) operation.

    def iter_generator(callable_, sentinel):
        while 1:
            try:
                result = callable_()
            except StopIteration:
                return
            if result == sentinel:
                return
            yield result

    def iter_sentinel(callable_, sentinel):
        if not callable(callable_):
            raise TypeError('iter(v, w): v must be callable')
        return iter_generator(callable_, sentinel)

''', filename=__file__).interphook("iter_sentinel")

def iter(space, w_collection_or_callable, w_sentinel=None):
    """iter(collection) -> iterator over the elements of the collection.

iter(callable, sentinel) -> iterator calling callable() until it returns
                            the sentinel.
"""
    if w_sentinel is None:
        return space.iter(w_collection_or_callable)
    else:
        return iter_sentinel(space, w_collection_or_callable, w_sentinel)

def next(space, w_iterator, w_default=None):
    """next(iterator[, default])
Return the next item from the iterator. If default is given and the iterator
is exhausted, it is returned instead of raising StopIteration."""
    try:
        return space.next(w_iterator)
    except OperationError as e:
        if w_default is not None and e.match(space, space.w_StopIteration):
            return w_default
        raise

def ord(space, w_val):
    """Return the integer ordinal of a character."""
    return space.ord(w_val)

@unwrap_spec(w_mod=WrappedDefault(None))
def pow(space, w_base, w_exp, w_mod):
    """With two arguments, equivalent to ``base**exp''.
With three arguments, equivalent to ``(base**exp) % mod''.

Some types, such as ints, are able to use a more efficient algorithm when
invoked using the three argument form."""
    return space.pow(w_base, w_exp, w_mod)

def repr(space, w_object):
    """Return a canonical string representation of the object.
For simple object types, eval(repr(object)) == object."""
    return space.repr(w_object)

def setattr(space, w_object, w_name, w_val):
    """Store a named attribute into an object.
setattr(x, 'y', z) is equivalent to ``x.y = z''."""
    w_name = checkattrname(space, w_name, 'setattr')
    space.setattr(w_object, w_name, w_val)
    return space.w_None

def callable(space, w_object):
    """Check whether the object appears to be callable (i.e., some kind of
function).  Note that classes are callable."""
    return space.callable(w_object)

@unwrap_spec(w_format_spec = WrappedDefault(u""))
def format(space, w_obj, w_format_spec):
    """Format a obj according to format_spec"""
    return space.format(w_obj, w_format_spec)
