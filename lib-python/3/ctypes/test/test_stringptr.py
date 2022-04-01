import unittest
from test import support
from ctypes import *

import _ctypes_test

lib = CDLL(_ctypes_test.__file__)

class StringPtrTestCase(unittest.TestCase):

    @support.refcount_test
    def test__POINTER_c_char(self):
        class X(Structure):
            _fields_ = [("str", POINTER(c_char))]
        x = X()

        # NULL pointer access
        self.assertRaises(ValueError, getattr, x.str, "contents")
        b = c_buffer(b"Hello, World")
        from sys import getrefcount as grc
        self.assertEqual(grc(b), 2)
        x.str = b
        self.assertEqual(grc(b), 3)

        # POINTER(c_char) and Python string is NOT compatible
        # POINTER(c_char) and c_buffer() is compatible
        for i in range(len(b)):
            self.assertEqual(b[i], x.str[i])

        self.assertRaises(TypeError, setattr, x, "str", "Hello, World")

    def test__c_char_p(self):
        class X(Structure):
            _fields_ = [("str", c_char_p)]
        x = X()

        # c_char_p and Python string is compatible
        # c_char_p and c_buffer is NOT compatible
        self.assertEqual(x.str, None)
        x.str = b"Hello, World"
        self.assertEqual(x.str, b"Hello, World")
        b = c_buffer(b"Hello, World")
        self.assertRaises(TypeError, setattr, x, b"str", b)


    def test_functions(self):
        strchr = lib.my_strchr
        strchr.restype = c_char_p

        # c_char_p and Python string is compatible
        # c_char_p and c_buffer are now compatible
        strchr.argtypes = c_char_p, c_char
        self.assertEqual(strchr(b"abcdef", b"c"), b"cdef")
        self.assertEqual(strchr(c_buffer(b"abcdef"), b"c"), b"cdef")

        # POINTER(c_char) and Python string is NOT compatible
        # POINTER(c_char) and c_buffer() is compatible
        strchr.argtypes = POINTER(c_char), c_char
        buf = c_buffer(b"abcdef")
        self.assertEqual(strchr(buf, b"c"), b"cdef")
        self.assertEqual(strchr(b"abcdef", b"c"), b"cdef")

        # XXX These calls are dangerous, because the first argument
        # to strchr is no longer valid after the function returns!
        # So we must keep a reference to buf separately

        strchr.restype = POINTER(c_char)
        buf = c_buffer(b"abcdef")
        r = strchr(buf, b"c")
        x = r[0], r[1], r[2], r[3], r[4]
        self.assertEqual(x, (b"c", b"d", b"e", b"f", b"\000"))
        del buf
        # Because r is a pointer to memory that is freed after deleting buf,
        # the pointer is hanging and using it would reference freed memory.

if __name__ == '__main__':
    unittest.main()
