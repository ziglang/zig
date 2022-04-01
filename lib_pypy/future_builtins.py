"""This module provides functions that will be builtins in Python 3.0,
but that conflict with builtins that already exist in Python 2.x.

Functions:

hex(arg) -- Returns the hexadecimal representation of an integer
oct(arg) -- Returns the octal representation of an integer
ascii(arg) -- Same as repr(arg)
map, filter, zip -- Same as itertools.imap, ifilter, izip

The typical usage of this module is to replace existing builtins in a
module's namespace:

from future_builtins import hex, oct
"""

__all__ = ['hex', 'oct', 'ascii', 'map', 'filter', 'zip']

from itertools import imap as map, ifilter as filter, izip as zip

ascii = repr
_builtin_hex = hex
_builtin_oct = oct

def hex(arg):
    return _builtin_hex(arg).rstrip('L')

def oct(arg):
    result = _builtin_oct(arg).rstrip('L')
    if result == '0':
        return '0o0'
    i = result.index('0') + 1
    return result[:i] + 'o' + result[i:]
