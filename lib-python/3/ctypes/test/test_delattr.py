import unittest
from ctypes import *

class X(Structure):
    _fields_ = [("foo", c_int)]

class TestCase(unittest.TestCase):
    def test_simple(self):
        self.assertRaises((TypeError, AttributeError),
                          delattr, c_int(42), "value")

    def test_chararray(self):
        self.assertRaises((TypeError, AttributeError),
                          delattr, (c_char * 5)(), "value")

    def test_struct(self):
        self.assertRaises((TypeError, AttributeError),
                          delattr, X(), "foo")

if __name__ == "__main__":
    unittest.main()
