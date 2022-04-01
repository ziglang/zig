from rpython.jit.backend.llsupport.test.zrpy_releasegil_test import ReleaseGILTests


class TestShadowStack(ReleaseGILTests):
    gcrootfinder = "shadowstack"
