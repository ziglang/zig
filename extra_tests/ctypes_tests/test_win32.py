# Windows specific tests

from ctypes import *

import pytest

@pytest.mark.skipif("sys.platform != 'win32'")
def test_VARIANT():
    from ctypes import wintypes
    a = wintypes.VARIANT_BOOL()
    assert a.value is False
    b = wintypes.VARIANT_BOOL(3)
    assert b.value is True
