from ctypes import CDLL
from ctypes.util import find_library

def test__handle():
    lib = find_library("c")
    if lib:
        cdll = CDLL(lib)
        assert type(cdll._handle) is int
