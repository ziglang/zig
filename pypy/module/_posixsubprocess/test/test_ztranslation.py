from pypy.objspace.fake.checkmodule import checkmodule
from pypy.module._posixsubprocess import interp_subprocess
import py, sys

if sys.platform == 'win32':
    py.test.skip("not used on win32") 

def test_posixsubprocess_translates():
    # make sure the spaces don't mix
    interp_subprocess.preexec.space = None
    checkmodule('_posixsubprocess')
