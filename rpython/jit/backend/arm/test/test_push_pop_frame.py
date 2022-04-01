import py
from rpython.jit.backend.arm import conditions as c
from rpython.jit.backend.arm import registers as r
from rpython.jit.backend.arm.arch import WORD
from rpython.jit.backend.arm.test.test_regalloc_mov import BaseMovTest, mi

base_ofs = 23
class MockCPU(object):
    def get_baseofs_of_frame_field(self):
        return base_ofs


class TestRegallocPush(BaseMovTest):
    def setup_method(self, method):
        BaseMovTest.setup_method(self, method)
        self.asm.cpu = MockCPU()

    def test_callee_only(self):
        expected = [
                mi('ADD_ri', r.ip.value, r.fp.value, base_ofs),
                mi('STM', r.ip.value, [r.r0.value, r.r1.value,
                    r.r2.value, r.r3.value]),
        ]
        self.asm._push_all_regs_to_jitframe(self.asm.mc, ignored_regs=[],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_callee_only_with_holes(self):
        expected = [
                mi('STR_ri', r.r0.value, r.fp.value, cond=c.AL, imm=base_ofs),
                mi('STR_ri', r.r2.value, r.fp.value, cond=c.AL, imm=base_ofs + 8),
        ]
        self.asm._push_all_regs_to_jitframe(self.asm.mc, ignored_regs=[r.r1, r.r3],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_callee_only_with_holes_in_front(self):
        expected = [
                mi('STR_ri', r.r2.value, r.fp.value, cond=c.AL, imm=base_ofs + 8),
                mi('STR_ri', r.r3.value, r.fp.value, cond=c.AL, imm=base_ofs + 12),
        ]
        self.asm._push_all_regs_to_jitframe(self.asm.mc, ignored_regs=[r.r0, r.r1],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_callee_only_ignore_more_than_saved(self):
        expected = [
                mi('STR_ri', r.r0.value, r.fp.value, cond=c.AL, imm=base_ofs),
        ]
        self.asm._push_all_regs_to_jitframe(self.asm.mc,
                ignored_regs=[r.r1, r.r2, r.r3, r.r4, r.r5],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_with_floats(self):
        expected = [
            mi('STR_ri', r.r0.value, r.fp.value, cond=c.AL, imm=base_ofs),
            mi('ADD_ri', r.ip.value, r.fp.value, imm=base_ofs + len(r.all_regs) * WORD),
            mi('VSTM', r.ip.value, [v.value for v in r.all_vfp_regs])
        ]
        self.asm._push_all_regs_to_jitframe(self.asm.mc,
                ignored_regs=[r.r1, r.r2, r.r3],
                withfloats=True, callee_only=True)
        self.validate(expected)

    def test_try_ignore_vfp_reg(self):
        py.test.raises(AssertionError, self.asm._push_all_regs_to_jitframe, self.asm.mc,
                ignored_regs=[r.d0, r.r2, r.r3], withfloats=True, callee_only=True)

    def test_all_regs(self):
        expected = [
                mi('ADD_ri', r.ip.value, r.fp.value, base_ofs),
                mi('STM', r.ip.value, [reg.value for reg in r.all_regs]),
        ]
        self.asm._push_all_regs_to_jitframe(self.asm.mc, ignored_regs=[],
                withfloats=False, callee_only=False)
        self.validate(expected)

    def test_all_regs_with_holes(self):
        ignored = [r.r1, r.r6]
        expected = [mi('STR_ri', reg.value, r.fp.value, cond=c.AL, imm=base_ofs + reg.value * WORD)
                                    for reg in r.all_regs if reg not in ignored]
        self.asm._push_all_regs_to_jitframe(self.asm.mc, ignored_regs=ignored,
                withfloats=False, callee_only=False)
        self.validate(expected)

    def test_all_regs_with_holes_in_front(self):
        ignored = [r.r0, r.r1]
        expected = [mi('STR_ri', reg.value, r.fp.value, cond=c.AL, imm=base_ofs + reg.value * WORD)
                                    for reg in r.all_regs if reg not in ignored]
        self.asm._push_all_regs_to_jitframe(self.asm.mc, ignored_regs=ignored,
                withfloats=False, callee_only=False)
        self.validate(expected)



class TestRegallocPop(BaseMovTest):
    def setup_method(self, method):
        BaseMovTest.setup_method(self, method)
        self.asm.cpu = MockCPU()

    def test_callee_only(self):
        expected = [
                mi('ADD_ri', r.ip.value, r.fp.value, base_ofs),
                mi('LDM', r.ip.value, [r.r0.value, r.r1.value,
                    r.r2.value, r.r3.value]),
        ]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc, ignored_regs=[],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_callee_only_with_holes(self):
        expected = [
                mi('LDR_ri', r.r0.value, r.fp.value, cond=c.AL, imm=base_ofs),
                mi('LDR_ri', r.r2.value, r.fp.value, cond=c.AL, imm=base_ofs + 8),
        ]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc, ignored_regs=[r.r1, r.r3],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_callee_only_with_holes_in_front(self):
        expected = [
                mi('LDR_ri', r.r2.value, r.fp.value, cond=c.AL, imm=base_ofs + 8),
                mi('LDR_ri', r.r3.value, r.fp.value, cond=c.AL, imm=base_ofs + 12),
        ]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc, ignored_regs=[r.r0, r.r1],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_callee_only_ignore_more_than_saved(self):
        expected = [
                mi('LDR_ri', r.r0.value, r.fp.value, cond=c.AL, imm=base_ofs),
        ]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc,
                ignored_regs=[r.r1, r.r2, r.r3, r.r4, r.r5],
                withfloats=False, callee_only=True)
        self.validate(expected)

    def test_with_floats(self):
        expected = [
            mi('LDR_ri', r.r0.value, r.fp.value, cond=c.AL, imm=base_ofs),
            mi('ADD_ri', r.ip.value, r.fp.value, imm=base_ofs + len(r.all_regs) * WORD),
            mi('VLDM', r.ip.value, [v.value for v in r.all_vfp_regs])
        ]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc,
                ignored_regs=[r.r1, r.r2, r.r3],
                withfloats=True, callee_only=True)
        self.validate(expected)

    def test_try_ignore_vfp_reg(self):
        py.test.raises(AssertionError, self.asm._pop_all_regs_from_jitframe, self.asm.mc,
                ignored_regs=[r.d0, r.r2, r.r3], withfloats=True, callee_only=True)

    def test_all_regs(self):
        expected = [
                mi('ADD_ri', r.ip.value, r.fp.value, base_ofs),
                mi('LDM', r.ip.value, [reg.value for reg in r.all_regs]),
        ]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc, ignored_regs=[],
                withfloats=False, callee_only=False)
        self.validate(expected)

    def test_all_regs_with_holes(self):
        ignored = [r.r1, r.r6]
        expected = [mi('LDR_ri', reg.value, r.fp.value, cond=c.AL, imm=base_ofs + reg.value * WORD)
                                    for reg in r.all_regs if reg not in ignored]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc, ignored_regs=ignored,
                withfloats=False, callee_only=False)
        self.validate(expected)

    def test_all_regs_with_holes_in_front(self):
        ignored = [r.r0, r.r1]
        expected = [mi('LDR_ri', reg.value, r.fp.value, cond=c.AL, imm=base_ofs + reg.value * WORD)
                                    for reg in r.all_regs if reg not in ignored]
        self.asm._pop_all_regs_from_jitframe(self.asm.mc, ignored_regs=ignored,
                withfloats=False, callee_only=False)
        self.validate(expected)
