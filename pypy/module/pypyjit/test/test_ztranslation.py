from pypy.objspace.fake.checkmodule import checkmodule


def test_pypyjit_translates():
    checkmodule('pypyjit')
