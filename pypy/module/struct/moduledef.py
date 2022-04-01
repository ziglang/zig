
"""
Mixed-module definition for the struct module.
Note that there is also a pure Python implementation in pypy/lib/struct.py;
the present mixed-module version of struct takes precedence if it is enabled.
"""

from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    """\
Functions to convert between Python values and C structs.
Python strings are used to hold the data representing the C struct
and also as format strings to describe the layout of data in the C struct.

The optional first format char indicates byte order, size and alignment:
 @: native order, size & alignment (default)
 =: native order, std. size & alignment
 <: little-endian, std. size & alignment
 >: big-endian, std. size & alignment
 !: same as >

The remaining chars indicate types of args and must match exactly;
these can be preceded by a decimal repeat count:
   x: pad byte (no data);
   c:char;
   b:signed byte;
   B:unsigned byte;
   h:short;
   H:unsigned short;
   i:int;
   I:unsigned int;
   l:long;
   L:unsigned long;
   q:long long;
   Q:unsigned long long
   f:float;
   d:double.
Special cases (preceding decimal count indicates length):
   s:string (array of char); p: pascal string (with count byte).
Special case (only available in native format):
   P:an integer type that is wide enough to hold a pointer.
Whitespace between formats is ignored.

The variable struct.error is an exception raised on errors."""

    applevel_name = "_struct"

    interpleveldefs = {
        'error': 'interp_struct.get_error(space)',

        'calcsize': 'interp_struct.calcsize',
        'pack': 'interp_struct.pack',
        'pack_into': 'interp_struct.pack_into',
        'unpack': 'interp_struct.unpack',
        'unpack_from': 'interp_struct.unpack_from',
        'iter_unpack': 'interp_struct.iter_unpack',

        'Struct': 'interp_struct.W_Struct',
        '_clearcache': 'interp_struct.clearcache',
    }

    appleveldefs = {
    }
