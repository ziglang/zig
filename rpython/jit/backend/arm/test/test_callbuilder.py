from rpython.jit.backend.arm.callbuilder import HardFloatCallBuilder
from rpython.jit.backend.arm import registers as r



def test_hf_vfp_registers_all_singlefloat():
    hf = HardFloatCallBuilder.__new__(HardFloatCallBuilder)
    got = [hf.get_next_vfp('S') for i in range(18)]
    assert got == [r.s0, r.s1, r.s2, r.s3, r.s4, r.s5, r.s6, r.s7,
                   r.s8, r.s9, r.s10, r.s11, r.s12, r.s13, r.s14, r.s15,
                   None, None]

def test_hf_vfp_registers_all_doublefloat():
    hf = HardFloatCallBuilder.__new__(HardFloatCallBuilder)
    got = [hf.get_next_vfp('f') for i in range(10)]
    assert got == [r.d0, r.d1, r.d2, r.d3, r.d4, r.d5, r.d6, r.d7,
                   None, None]

def test_hf_vfp_registers_mixture():
    hf = HardFloatCallBuilder.__new__(HardFloatCallBuilder)
    got = [hf.get_next_vfp('S'), hf.get_next_vfp('f'),
           hf.get_next_vfp('S'), hf.get_next_vfp('f'),
           hf.get_next_vfp('S'), hf.get_next_vfp('f'),
           hf.get_next_vfp('S'), hf.get_next_vfp('f'),
           hf.get_next_vfp('S'), hf.get_next_vfp('f'),
           hf.get_next_vfp('S'), hf.get_next_vfp('f'),
           hf.get_next_vfp('S'), hf.get_next_vfp('f')]
    assert got == [r.s0,  r.d1,
                   r.s1,  r.d2,
                   r.s6,  r.d4,
                   r.s7,  r.d5,
                   r.s12, r.d7,
                   r.s13, None,
                   None,  None]

def test_hf_vfp_registers_mixture_2():
    hf = HardFloatCallBuilder.__new__(HardFloatCallBuilder)
    got = [hf.get_next_vfp('f'), hf.get_next_vfp('f'),
           hf.get_next_vfp('f'), hf.get_next_vfp('f'),
           hf.get_next_vfp('f'), hf.get_next_vfp('f'),
           hf.get_next_vfp('f'), hf.get_next_vfp('S'),
           hf.get_next_vfp('f'), hf.get_next_vfp('S')]
    assert got == [r.d0, r.d1,
                   r.d2, r.d3,
                   r.d4, r.d5,
                   r.d6, r.s14,
                   None, None]    # <- and not r.s15 for the last item
