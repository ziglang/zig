from rpython.jit.backend.llsupport.test.zrpy_gc_test import CompileFrameworkTests


class TestShadowStack(CompileFrameworkTests):
    gcrootfinder = "shadowstack"
    gc = "incminimark"
