from pypy.objspace.fake.checkmodule import checkmodule

def test_faulthandler_translates():
    import pypy.module._vmprof.interp_vmprof   # register_code_object_class()
    checkmodule('faulthandler')
