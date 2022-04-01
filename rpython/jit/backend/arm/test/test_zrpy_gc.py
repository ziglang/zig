from rpython.jit.backend.arm.test.support import skip_unless_run_slow_tests
skip_unless_run_slow_tests()

from rpython.jit.backend.llsupport.test.zrpy_gc_test import CompileFrameworkTests


class TestShadowStack(CompileFrameworkTests):
    gcrootfinder = "shadowstack"
