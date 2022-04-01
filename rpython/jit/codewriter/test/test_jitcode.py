from rpython.jit.codewriter.jitcode import JitCode


def test_num_regs():
    j = JitCode("test")
    j.setup(num_regs_i=12, num_regs_r=34, num_regs_f=56)
    assert j.num_regs_i() == 12
    assert j.num_regs_r() == 34
    assert j.num_regs_f() == 56
    j.setup(num_regs_i=0, num_regs_r=0, num_regs_f=0)
    assert j.num_regs_i() == 0
    assert j.num_regs_r() == 0
    assert j.num_regs_f() == 0
    j.setup(num_regs_i=255, num_regs_r=255, num_regs_f=255)
    assert j.num_regs_i() == 255
    assert j.num_regs_r() == 255
    assert j.num_regs_f() == 255

def test_liveness():
    j = JitCode("test")
    j.setup(liveness={5: (" A", "b", "CD")})
    assert j.has_liveness_info(5)
    assert not j.has_liveness_info(4)
    assert j._live_vars(5) == "%i32 %i65 %r98 %f67 %f68"
