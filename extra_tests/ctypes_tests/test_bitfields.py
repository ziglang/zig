import pytest
from ctypes import *


def test_set_fields_attr():
    class A(Structure):
        pass
    A._fields_ = [("a", c_byte), ("b", c_ubyte)]

def test_set_fields_attr_bitfields():
    class A(Structure):
        pass
    A._fields_ = [("a", POINTER(A)), ("b", c_ubyte, 4)]

def test_set_fields_cycle_fails():
    class A(Structure):
        pass
    with pytest.raises(AttributeError):
        A._fields_ = [("a", A)]
