from hypothesis import given, settings, strategies as st, assume
from rpython.jit.backend.aarch64 import registers as r
from rpython.jit.backend.aarch64 import codebuilder
from rpython.jit.backend.aarch64.test.gen import assemble

class CodeBuilder(codebuilder.InstrBuilder):
    def __init__(self, arch_version=7):
        self.arch_version = arch_version
        self.buffer = []

    def writechar(self, char):
        self.buffer.append(char)

    def currpos(self):
        return 0

    def hexdump(self):
        return ''.join(self.buffer)


class TestInstrBuilder(object):

    @settings(max_examples=20)
    @given(r1=st.sampled_from(r.registers))
    def test_RET_r(self, r1):
        cb = CodeBuilder()
        cb.RET_r(r1.value)
        res = cb.hexdump()
        exp = assemble('RET %r' % r1)
        assert res == exp

    @settings(max_examples=20)
    @given(r1=st.sampled_from(r.registers),
           r2=st.sampled_from(r.registers),
           offset=st.integers(min_value=-64, max_value=63))
    def test_STP_rr(self, r1, r2, offset):
        cb = CodeBuilder()
        cb.STP_rr_preindex(r1.value, r2.value, r.sp.value, offset * 8)
        assert cb.hexdump() == assemble("STP %r, %r, [sp, %d]!" % (r1, r2, offset * 8))
        cb = CodeBuilder()
        cb.STP_rri(r1.value, r2.value, r.sp.value, offset * 8)
        assert cb.hexdump() == assemble("STP %r, %r, [sp, %d]" % (r1, r2, offset * 8))

    @settings(max_examples=20)
    @given(r1=st.sampled_from(r.registers),
           r2=st.sampled_from(r.registers))
    def test_MOV_rr(self, r1, r2):
        cb = CodeBuilder()
        cb.MOV_rr(r1.value, r2.value)
        assert cb.hexdump() == assemble("MOV %r, %r" % (r1, r2))

    @settings(max_examples=20)
    @given(r1=st.sampled_from(r.registers),
           immed=st.integers(min_value=0, max_value=(1<<16) - 1),
           shift=st.integers(min_value=0, max_value=3))
    def test_MOVK(self, r1, immed, shift):
        cb = CodeBuilder()
        cb.MOVK_r_u16(r1.value, immed, shift * 16)
        assert cb.hexdump() == assemble("MOVK %r, %d, lsl %d" % (r1, immed, shift * 16))

    @settings(max_examples=20)
    @given(r1=st.sampled_from(r.registers),
           immed=st.integers(min_value=0, max_value=(1<<16) - 1),
           shift=st.integers(min_value=0, max_value=3))
    def test_MOVZ(self, r1, immed, shift):
        cb = CodeBuilder()
        cb.MOVZ_r_u16(r1.value, immed, shift * 16)
        assert cb.hexdump() == assemble("MOVZ %r, %d, lsl %d" % (r1, immed, shift * 16))

    @settings(max_examples=20)
    @given(r1=st.sampled_from(r.registers),
           immed=st.integers(min_value=0, max_value=(1<<16) - 1))
    def test_MOVN(self, r1, immed):
        cb = CodeBuilder()
        cb.MOVN_r_u16(r1.value, immed)
        assert cb.hexdump() == assemble("MOV %r, %d" % (r1, ~immed))

    @settings(max_examples=20)
    @given(rt=st.sampled_from(r.registers),
           rn=st.sampled_from(r.registers),
           offset=st.integers(min_value=0, max_value=(1<<12)-1))
    def test_STR_ri(self, rt, rn, offset):
        cb = CodeBuilder()
        cb.STR_ri(rt.value, rn.value, offset * 8)
        assert cb.hexdump() == assemble("STR %r, [%r, %d]" % (rt, rn, offset * 8))

    @settings(max_examples=20)
    @given(reg1=st.sampled_from(r.registers),
           reg2=st.sampled_from(r.registers),
           rn=st.sampled_from(r.registers),
           offset=st.integers(min_value=-64, max_value=63))
    def test_LDP_rr(self, reg1, reg2, rn, offset):
        assume(reg1.value != reg2.value)
        cb = CodeBuilder()
        cb.LDP_rri(reg1.value, reg2.value, rn.value, offset * 8)
        assert cb.hexdump() == assemble("LDP %r, %r, [%r, %d]" % (reg1, reg2, rn, offset * 8))
        #
        assume(rn.value != reg1.value)
        assume(rn.value != reg2.value)
        cb = CodeBuilder()
        cb.LDP_rr_postindex(reg1.value, reg2.value, rn.value, offset * 8)
        assert cb.hexdump() == assemble("LDP %r, %r, [%r], %d" % (reg1, reg2, rn, offset * 8))

    @settings(max_examples=20)
    @given(rt=st.sampled_from(r.registers),
           rn=st.sampled_from(r.registers),
           offset=st.integers(min_value=0, max_value=(1<<12)-1))
    def test_LDR_ri(self, rt, rn, offset):
        cb = CodeBuilder()
        cb.LDR_ri(rt.value, rn.value, offset * 8)
        assert cb.hexdump() == assemble("LDR %r, [%r, %d]" % (rt, rn, offset * 8))

    @settings(max_examples=20)
    @given(rt=st.sampled_from(r.registers),
           offset=st.integers(min_value=-(1<<18), max_value=(1<<18)-1))
    def test_LDR_r_literal(self, rt, offset):
        cb = CodeBuilder()
        cb.LDR_r_literal(rt.value, offset * 4)
        assert cb.hexdump() == assemble("LDR %r, %d" % (rt, offset * 4))

    @settings(max_examples=20)
    @given(rd=st.sampled_from(r.registers),
           rn=st.sampled_from(r.registers),
           rm=st.sampled_from(r.registers))
    def test_ADD_rr(self, rd, rn, rm):
        cb = CodeBuilder()
        cb.ADD_rr(rd.value, rn.value, rm.value)
        assert cb.hexdump() == assemble("ADD %r, %r, %r" % (rd, rn, rm))

    @settings(max_examples=20)
    @given(rd=st.sampled_from(r.registers),
           rn=st.sampled_from(r.registers),
           imm=st.integers(min_value=0, max_value=(1<<12)-1))
    def test_ADD_ri(self, rd, rn, imm):
        cb = CodeBuilder()
        cb.ADD_ri(rd.value, rn.value, imm)
        assert cb.hexdump() == assemble("ADD %r, %r, %d" % (rd, rn, imm))

    @settings(max_examples=20)
    @given(rd=st.sampled_from(r.registers),
           rn=st.sampled_from(r.registers),
           ofs=st.integers(min_value=0, max_value=4095))
    def test_SUB_ri(self, rd, rn, ofs):
        cb = CodeBuilder()
        cb.SUB_ri(rd.value, rn.value, ofs)
        assert cb.hexdump() == assemble("SUB %r, %r, %d" % (rd, rn, ofs))

    @settings(max_examples=20)
    @given(rn=st.sampled_from(r.registers),
           rm=st.sampled_from(r.registers))
    def test_CMP_rr(self, rn, rm):
        cb = CodeBuilder()
        cb.CMP_rr(rn.value, rm.value)
        assert cb.hexdump() == assemble("CMP %r, %r" % (rn, rm))

    def test_BRK(self):
        cb = CodeBuilder()
        cb.BRK()
        assert cb.hexdump() == assemble("BRK 0")

    def test_STLR(self):
        cb = CodeBuilder()
        cb.STLR(r.x11.value, r.x22.value)
        assert cb.hexdump() == assemble("STLR x11, [x22]")

    def test_LDXR(self):
        cb = CodeBuilder()
        cb.LDXR(r.x11.value, r.x22.value)
        assert cb.hexdump() == assemble("LDXR x11, [x22]")

    def test_STXR(self):
        cb = CodeBuilder()
        cb.STXR(r.x6.value, r.x11.value, r.x22.value)
        assert cb.hexdump() == assemble("STXR w6, x11, [x22]")

    def test_CBNZ(self):
        cb = CodeBuilder()
        cb.CBNZ(r.x6.value, -8)
        assert cb.hexdump() == assemble("CBNZ x6, -8")

    def test_CBNZ_w(self):
        cb = CodeBuilder()
        cb.CBNZ_w(r.x6.value, -8)
        assert cb.hexdump() == assemble("CBNZ w6, -8")

    def test_CBZ(self):
        cb = CodeBuilder()
        cb.CBZ(r.x25.value, -888)
        assert cb.hexdump() == assemble("CBZ x25, -888")
