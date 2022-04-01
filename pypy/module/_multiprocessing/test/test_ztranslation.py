from pypy.objspace.fake.checkmodule import checkmodule


def test_checkmodule():
    checkmodule('_multiprocessing')
