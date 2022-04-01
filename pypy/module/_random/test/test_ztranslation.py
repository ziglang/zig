from pypy.objspace.fake.checkmodule import checkmodule
from pypy.module.posix.interp_posix import _sigcheck

def test_checkmodule():
    _sigcheck.space = None
    checkmodule('_random')
