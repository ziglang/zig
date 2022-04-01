import unittest
from ctypes import *
import re, sys

if sys.byteorder == "little":
    THIS_ENDIAN = "<"
    OTHER_ENDIAN = ">"
else:
    THIS_ENDIAN = ">"
    OTHER_ENDIAN = "<"

def normalize(format):
    # Remove current endian specifier and white space from a format
    # string
    if format is None:
        return ""
    format = format.replace(OTHER_ENDIAN, THIS_ENDIAN)
    return re.sub(r"\s", "", format)

class Test(unittest.TestCase):

    def test_native_types(self):
        for tp, fmt, shape, itemtp in native_types:
            ob = tp()
            v = memoryview(ob)
            try:
                self.assertEqual(normalize(v.format), normalize(fmt))
                if shape:
                    self.assertEqual(len(v), shape[0])
                else:
                    self.assertEqual(len(v) * sizeof(itemtp), sizeof(ob))
                self.assertEqual(v.itemsize, sizeof(itemtp))
                self.assertEqual(v.shape, shape)
                # XXX Issue #12851: PyCData_NewGetBuffer() must provide strides
                #     if requested. memoryview currently reconstructs missing
                #     stride information, so this assert will fail.
                # self.assertEqual(v.strides, ())

                # they are always read/write
                self.assertFalse(v.readonly)

                if v.shape:
                    n = 1
                    for dim in v.shape:
                        n = n * dim
                    self.assertEqual(n * v.itemsize, len(v.tobytes()))
            except:
                # so that we can see the failing type
                print(tp)
                raise

    def test_endian_types(self):
        for tp, fmt, shape, itemtp in endian_types:
            ob = tp()
            v = memoryview(ob)
            try:
                self.assertEqual(v.format, fmt)
                if shape:
                    self.assertEqual(len(v), shape[0])
                else:
                    self.assertEqual(len(v) * sizeof(itemtp), sizeof(ob))
                self.assertEqual(v.itemsize, sizeof(itemtp))
                self.assertEqual(v.shape, shape)
                # XXX Issue #12851
                # self.assertEqual(v.strides, ())

                # they are always read/write
                self.assertFalse(v.readonly)

                if v.shape:
                    n = 1
                    for dim in v.shape:
                        n = n * dim
                    self.assertEqual(n, len(v))
            except:
                # so that we can see the failing type
                print(tp)
                raise

# define some structure classes

class Point(Structure):
    _fields_ = [("x", c_long), ("y", c_long)]

class PackedPoint(Structure):
    _pack_ = 2
    _fields_ = [("x", c_long), ("y", c_long)]

class Point2(Structure):
    pass
Point2._fields_ = [("x", c_long), ("y", c_long)]

class EmptyStruct(Structure):
    _fields_ = []

class aUnion(Union):
    _fields_ = [("a", c_int)]

class StructWithArrays(Structure):
    _fields_ = [("x", c_long * 3 * 2), ("y", Point * 4)]

class Incomplete(Structure):
    pass

class Complete(Structure):
    pass
PComplete = POINTER(Complete)
Complete._fields_ = [("a", c_long)]

################################################################
#
# This table contains format strings as they look on little endian
# machines.  The test replaces '<' with '>' on big endian machines.
#

# Platform-specific type codes
s_bool = {1: '?', 2: 'H', 4: 'L', 8: 'Q'}[sizeof(c_bool)]
s_short = {2: 'h', 4: 'l', 8: 'q'}[sizeof(c_short)]
s_ushort = {2: 'H', 4: 'L', 8: 'Q'}[sizeof(c_ushort)]
s_int = {2: 'h', 4: 'i', 8: 'q'}[sizeof(c_int)]
s_uint = {2: 'H', 4: 'I', 8: 'Q'}[sizeof(c_uint)]
s_long = {4: 'l', 8: 'q'}[sizeof(c_long)]
s_ulong = {4: 'L', 8: 'Q'}[sizeof(c_ulong)]
s_longlong = "q"
s_ulonglong = "Q"
s_float = "f"
s_double = "d"
s_longdouble = "g"

# Alias definitions in ctypes/__init__.py
if c_int is c_long:
    s_int = s_long
if c_uint is c_ulong:
    s_uint = s_ulong
if c_longlong is c_long:
    s_longlong = s_long
if c_ulonglong is c_ulong:
    s_ulonglong = s_ulong
if c_longdouble is c_double:
    s_longdouble = s_double


native_types = [
    # type                      format                  shape           calc itemsize

    ## simple types

    (c_char,                    "<c",                   (),           c_char),
    (c_byte,                    "<b",                   (),           c_byte),
    (c_ubyte,                   "<B",                   (),           c_ubyte),
    (c_short,                   "<" + s_short,          (),           c_short),
    (c_ushort,                  "<" + s_ushort,         (),           c_ushort),

    (c_int,                     "<" + s_int,            (),           c_int),
    (c_uint,                    "<" + s_uint,           (),           c_uint),

    (c_long,                    "<" + s_long,           (),           c_long),
    (c_ulong,                   "<" + s_ulong,          (),           c_ulong),

    (c_longlong,                "<" + s_longlong,       (),           c_longlong),
    (c_ulonglong,               "<" + s_ulonglong,      (),           c_ulonglong),

    (c_float,                   "<f",                   (),           c_float),
    (c_double,                  "<d",                   (),           c_double),

    (c_longdouble,              "<" + s_longdouble,     (),           c_longdouble),

    (c_bool,                    "<" + s_bool,           (),           c_bool),
    (py_object,                 "<O",                   (),           py_object),

    ## pointers

    (POINTER(c_byte),           "&<b",                  (),           POINTER(c_byte)),
    (POINTER(POINTER(c_long)),  "&&<" + s_long,         (),           POINTER(POINTER(c_long))),

    ## arrays and pointers

    (c_double * 4,              "<d",                   (4,),           c_double),
    (c_float * 4 * 3 * 2,       "<f",                   (2,3,4),        c_float),
    (POINTER(c_short) * 2,      "&<" + s_short,         (2,),           POINTER(c_short)),
    (POINTER(c_short) * 2 * 3,  "&<" + s_short,         (3,2,),         POINTER(c_short)),
    (POINTER(c_short * 2),      "&(2)<" + s_short,      (),             POINTER(c_short)),

    ## structures and unions

    (Point,                     "T{<l:x:<l:y:}".replace('l', s_long),  (),  Point),
    # packed structures do not implement the pep
    (PackedPoint,               "B",                                   (),  PackedPoint),
    (Point2,                    "T{<l:x:<l:y:}".replace('l', s_long),  (),  Point2),
    (EmptyStruct,               "T{}",                                 (),  EmptyStruct),
    # the pep doesn't support unions
    (aUnion,                    "B",                                   (),  aUnion),
    # structure with sub-arrays
    (StructWithArrays, "T{(2,3)<l:x:(4)T{<l:x:<l:y:}:y:}".replace('l', s_long), (), StructWithArrays),
    (StructWithArrays * 3, "T{(2,3)<l:x:(4)T{<l:x:<l:y:}:y:}".replace('l', s_long), (3,), StructWithArrays),

    ## pointer to incomplete structure
    # XXX: fix on PyPy
    #(Incomplete,                "B",                    (),           Incomplete),
    #(POINTER(Incomplete),       "&B",                   (),           POINTER(Incomplete)),

    # 'Complete' is a structure that starts incomplete, but is completed after the
    # pointer type to it has been created.
    (Complete,                  "T{<l:a:}".replace('l', s_long), (), Complete),
    # Broken on CPython, works on PyPy
    (POINTER(Complete),         "&T{<l:a:}".replace('l', s_long), (), Complete),

    ## other

    # function signatures are not implemented
    (CFUNCTYPE(None),           "X{}",                  (),           CFUNCTYPE(None)),

    ]

class BEPoint(BigEndianStructure):
    _fields_ = [("x", c_long), ("y", c_long)]

class LEPoint(LittleEndianStructure):
    _fields_ = [("x", c_long), ("y", c_long)]

################################################################
#
# This table contains format strings as they really look, on both big
# and little endian machines.
#
endian_types = [
    (BEPoint, "T{>l:x:>l:y:}".replace('l', s_long), (), BEPoint),
    (LEPoint, "T{<l:x:<l:y:}".replace('l', s_long), (), LEPoint),
    (POINTER(BEPoint), "&T{>l:x:>l:y:}".replace('l', s_long), (), POINTER(BEPoint)),
    (POINTER(LEPoint), "&T{<l:x:<l:y:}".replace('l', s_long), (), POINTER(LEPoint)),
    ]

if __name__ == "__main__":
    unittest.main()
