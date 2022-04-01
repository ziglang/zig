import os
import pytest
from pypy.objspace.fake.checkmodule import checkmodule

if os.name != 'posix':
    pytest.skip('pwd module only available on unix')

def test_checkmodule():
    checkmodule('pwd')
