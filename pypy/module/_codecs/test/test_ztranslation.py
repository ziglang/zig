from pypy.objspace.fake.checkmodule import checkmodule


def test__codecs_translates():
    checkmodule('_codecs')
