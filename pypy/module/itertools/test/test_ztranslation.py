from pypy.objspace.fake.checkmodule import checkmodule

def test_checkmodule():
    # itertools.compress.__next__() crashes in backendopt
    checkmodule('itertools', ignore=['compress'])
