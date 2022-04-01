
from pypy.objspace.fake.checkmodule import checkmodule

def test_select_translates():
    checkmodule('select')
