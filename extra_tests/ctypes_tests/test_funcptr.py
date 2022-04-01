from ctypes import *

def test_restype(dll):
    foo = dll.my_unused_function
    assert foo.restype is c_int     # by default
