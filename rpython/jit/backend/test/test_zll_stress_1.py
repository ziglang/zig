from rpython.jit.backend.test import zll_stress

def test_stress_1():
    zll_stress.do_test_stress(1)
