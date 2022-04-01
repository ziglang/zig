from pypy.objspace.fake.checkmodule import checkmodule

def test_posix_translates():
    checkmodule('posix')