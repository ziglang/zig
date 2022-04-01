import py
import struct
import math
from rpython.jit.backend.zarch import conditions as con
from rpython.jit.backend.zarch import masks as msk
from rpython.jit.backend.zarch import registers as r
from rpython.jit.backend.zarch.assembler import AssemblerZARCH
from rpython.jit.backend.zarch import locations as loc
from rpython.jit.backend.zarch.test.support import run_asm
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.codewriter import longlong

from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import lltype, rffi, ll2ctypes
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.backend.model import CompiledLoopToken
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.annlowlevel import llhelper
from rpython.rlib.objectmodel import specialize
from rpython.rlib.debug import ll_assert
from rpython.rlib.longlong2float import (float2longlong,
        DOUBLE_ARRAY_PTR, singlefloat2uint_emulator)
from rpython.rlib.rarithmetic import r_uint, intmask
import ctypes

CPU = getcpuclass()

def BFL(value, short=False):
    if short:
        return struct.pack('f', value)
    return struct.pack('>q', float2longlong(value))

def ADDR(value):
    ptr = ll2ctypes.lltype2ctypes(value)
    addr = ctypes.addressof(ptr.contents.items)
    return struct.pack('>Q', addr)

def gen_func_prolog(mc):
    STACK_FRAME_SIZE = 40
    mc.STMG(r.r11, r.r15, loc.addr(-STACK_FRAME_SIZE, r.SP))
    mc.AHI(r.SP, loc.imm(-STACK_FRAME_SIZE))

def gen_func_epilog(mc):
    mc.LMG(r.r11, r.r15, loc.addr(0, r.SP))
    mc.BCR_rr(0xf, r.r14.value) # jmp to

def isclose(a,b, rel_tol=1e-9, abs_tol=0.0):
    if math.isnan(a) and math.isnan(b):
        return True
    if a == b:
        return True
    # from PEP 485, added in python 3.5
    return abs(a-b) <= max( rel_tol * max(abs(a), abs(b)), abs_tol )

class LiteralPoolCtx(object):
    def __init__(self, asm):
        self.asm = asm
        self.lit_label = LabelCtx(asm, 'lit')

    def __enter__(self):
        self.lit_label.__enter__()
        self.asm.mc.BRAS(r.r13, loc.imm(0))
        return self

    def __exit__(self, a, b, c):
        self.lit_label.__exit__(None, None, None)
        self.asm.jump_here(self.asm.mc.BRAS, 'lit')

    def addr(self, mem):
        self.asm.mc.write(ADDR(mem))

    def float(self, val):
        self.asm.mc.write(BFL(val))

    def single_float(self, val):
        self.asm.mc.write(BFL(val, short=True))

    def int64(self, val):
        self.asm.mc.write(struct.pack('>q', val))

class LabelCtx(object):
    def __init__(self, asm, name):
        self.asm = asm
        self.name = name
    def __enter__(self):
        self.asm.mc.mark_op(self.name)
        return self
    def __exit__(self, a, b, c):
        self.asm.mc.mark_op(self.name + '.end')

class ActivationRecordCtx(object):
    def __init__(self, asm, name='func'):
        self.asm = asm
        self.name = name
        self.asm.mc.mark_op(self.name)
    def __enter__(self):
        gen_func_prolog(self.asm.mc)
        return self
    def __exit__(self, a, b, c):
        gen_func_epilog(self.asm.a.mc)
        self.asm.mc.mark_op(self.name + '.end')


class TestRunningAssembler(object):
    def setup_method(self, method):
        cpu = CPU(None, None)
        self.a = AssemblerZARCH(cpu)
        self.a.setup_once()
        token = JitCellToken()
        clt = CompiledLoopToken(cpu, 0)
        clt.allgcrefs = []
        token.compiled_loop_token = clt
        self.a.setup(token)
        self.mc = self.a.mc

    def test_make_operation_list(self):
        i = rop.INT_ADD
        from rpython.jit.backend.zarch import assembler
        assert assembler.asm_operations[i] \
            is AssemblerZARCH.emit_int_add.im_func

    def test_sync(self):
        self.a.mc.XGR(r.r2, r.r2)
        self.a.mc.sync()
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 0

    def test_load_64bit(self):
        self.a.mc.load_imm(r.r2, 0x0fffFFFF)
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 0x0fffFFFF

    def test_load_64bit_2(self):
        self.a.mc.load_imm(r.r2, 0xffffFFFF)
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 0xffffFFFF

    def test_load_64bit_3(self):
        self.a.mc.load_imm(r.r2, 2177165728)
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 2177165728

    def test_byte_count_instr(self):
        assert self.mc.BRC_byte_count == 4
        assert self.mc.LG_byte_count == 6

    def test_facility(self):
        adr = self.a.datablockwrapper.malloc_aligned(16, 16)
        self.a.mc.load_imm(r.r2, adr)
        self.a.mc.STFLE(loc.addr(0,r.r2))
        self.a.mc.BCR(con.ANY, r.r14)
        run_asm(self.a)
        fac_data = rffi.cast(rffi.CArrayPtr(rffi.ULONG), adr)
        f64 = bin(fac_data[0])[2:]
        s64 = bin(fac_data[1])[2:]
        print(f64)
        print(s64)
        for i,c in enumerate(f64):
            print('index: %d is set? %s' % (i,c))

        assert f64[1] == '1' # The z/Architecture architectural mode is installed.
        assert f64[2] == '1' # The z/Architecture architectural mode is active.
        assert f64[18] == '1' # long displacement facility
        assert f64[21] == '1' # extended immediate facility
        assert f64[34] == '1' # general instruction facility
        assert f64[41] == '1' # floating-point-support-enhancement

    def test_load_byte_zero_extend(self):
        adr = self.a.datablockwrapper.malloc_aligned(16, 16)
        data = rffi.cast(rffi.CArrayPtr(rffi.ULONG), adr)
        data[0] = rffi.cast(rffi.ULONG, intmask(0xffffFFFFffffFF02))
        self.a.mc.load_imm(r.r3, adr+7)
        self.a.mc.LLGC(r.r2, loc.addr(0,r.r3))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 2

    def test_load_byte_and_imm(self):
        adr = self.a.datablockwrapper.malloc_aligned(16, 16)
        data = rffi.cast(rffi.CArrayPtr(rffi.ULONG), adr)
        data[0] = rffi.cast(rffi.ULONG, intmask(0xffffFFFFffff0001))
        self.a.mc.load_imm(r.r3, adr)
        self.a.mc.LG(r.r2, loc.addr(0,r.r3))
        self.a.mc.LLGC(r.r2, loc.addr(7,r.r3))
        self.a.mc.NILL(r.r2, loc.imm(0x0))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 0

    @py.test.mark.parametrize('p,v', [(0,0),(8,8),(7,0),(4,0),(1,0),(9,8)])
    def test_align(self, p, v):
        WORD = 8
        self.a.mc.load_imm(r.r2, p)
        self.a.mc.LGHI(r.r0, loc.imm(~(WORD-1)))
        self.a.mc.NGR(r.r2, r.r0)
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == v

    @py.test.mark.parametrize('p', [2**32,2**32+1,2**63-1,2**63-2,0,1,2,3,4,5,6,7,8,10001])
    def test_align_withroll(self, p):
        self.a.mc.load_imm(r.r2, p & 0xffffFFFFffffFFFF)
        self.a.mc.RISBG(r.r2, r.r2, loc.imm(0), loc.imm(0x80 | 60), loc.imm(0))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == rffi.cast(rffi.ULONG,p) & ~(7)

    def test_nill(self):
        self.a.mc.load_imm(r.r2, 1)
        self.a.mc.load_imm(r.r3, 0x010001)
        self.a.mc.NILL(r.r3, loc.imm(0xFFFF))
        self.a.mc.BCR(con.EQ, r.r14) # should not branch
        self.a.mc.load_imm(r.r2, 0) # should return here
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 0

    def test_complement(self):
        self.a.mc.load_imm(r.r2, 0)
        #self.a.mc.LCGR(r.r2, r.r2)
        self.a.mc.XIHF(r.r2, loc.imm(0xffffFFFF))
        self.a.mc.XILF(r.r2, loc.imm(0xffffFFFF))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == -1

    def test_and_7_with_risbgn(self):
        n = 13
        l = loc
        self.a.mc.load_imm(r.r2, 7<<n)
        self.a.mc.RISBG(r.r2, r.r2, l.imm(61), l.imm(0x80 | 63), l.imm(64-n))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 7

    def test_risbgn(self):
        n = 16
        l = loc
        self.a.mc.load_imm(r.r2, 0xffFFffFF)
        self.a.mc.RISBG(r.r2, r.r2, l.imm(60), l.imm(0x80 | 63), l.imm(64-n))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 15

    def test_shift_same_register(self):
        self.a.mc.load_imm(r.r3, 0x1)
        self.a.mc.SLLG(r.r2, r.r3, loc.addr(1))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 2

    def test_shift_arith(self):
        self.a.mc.load_imm(r.r2, -14)
        self.a.mc.SLAG(r.r2, r.r2, loc.addr(1))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == -28

    def test_shift_negative_logical(self):
        self.a.mc.load_imm(r.r2, -14)
        self.a.mc.SLLG(r.r2, r.r2, loc.addr(1))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == -28

    def test_shift_negative_logical_2(self):
        self.a.mc.load_imm(r.r2, -2)
        self.a.mc.SLLG(r.r2, r.r2, loc.addr(63))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == 0

    def test_shift_negative_logical_3(self):
        self.a.mc.load_imm(r.r2, -2)
        self.a.mc.SLLG(r.r3, r.r2, loc.addr(1))
        self.a.mc.BCR(con.ANY, r.r14)
        assert run_asm(self.a) == -2

    def test_load_small_int_to_reg(self):
        self.a.mc.LGHI(r.r2, loc.imm(123))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 123

    def test_prolog_epilog(self):
        gen_func_prolog(self.a.mc)
        self.a.mc.LGHI(r.r2, loc.imm(123))
        gen_func_epilog(self.a.mc)
        assert run_asm(self.a) == 123

    def test_simple_func(self):
        # enter
        self.a.mc.STMG(r.r11, r.r15, loc.addr(-96, r.SP))
        self.a.mc.AHI(r.SP, loc.imm(-96))
        # from the start of BRASL to end of jmpto there are 8+6 bytes
        self.a.mc.BRASL(r.r14, loc.imm(8+6))
        self.a.mc.LMG(r.r11, r.r15, loc.addr(0, r.SP))
        self.a.jmpto(r.r14)

        addr = self.a.mc.get_relative_pos()
        assert addr & 0x1 == 0
        gen_func_prolog(self.a.mc)
        self.a.mc.LGHI(r.r2, loc.imm(321))
        gen_func_epilog(self.a.mc)
        assert run_asm(self.a) == 321

    def test_simple_loop(self):
        self.a.mc.LGHI(r.r3, loc.imm(2**15-1))
        self.a.mc.LGHI(r.r4, loc.imm(1))
        L1 = self.a.mc.get_relative_pos()
        self.a.mc.SGR(r.r3, r.r4)
        LJ = self.a.mc.get_relative_pos()
        self.a.mc.BRCL(con.GT, loc.imm(L1-LJ))
        self.a.mc.LGR(r.r2, r.r3)
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 0

    def test_and_imm(self):
        self.a.mc.NIHH(r.r2, loc.imm(0))
        self.a.mc.NIHL(r.r2, loc.imm(0))
        self.a.mc.NILL(r.r2, loc.imm(0))
        self.a.mc.NILH(r.r2, loc.imm(0))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 0

    def test_or_imm(self):
        self.a.mc.OIHH(r.r2, loc.imm(0xffff))
        self.a.mc.OIHL(r.r2, loc.imm(0xffff))
        self.a.mc.OILL(r.r2, loc.imm(0xffff))
        self.a.mc.OILH(r.r2, loc.imm(0xffff))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == -1

    def test_or_bitpos_0to15(self):
        self.a.mc.XGR(r.r2, r.r2)
        self.a.mc.OIHH(r.r2, loc.imm(0x0000))
        self.a.mc.OIHL(r.r2, loc.imm(0x0000))
        self.a.mc.OILL(r.r2, loc.imm(0x0000))
        self.a.mc.OILH(r.r2, loc.imm(0x300c))
        self.a.jmpto(r.r14)
        res = run_asm(self.a)
        assert res == 0x00000000300c0000

    def test_uint_rshift(self):
        self.a.mc.XGR(r.r4, r.r4)
        self.a.mc.LGFI(r.r5, loc.imm(63))
        self.a.mc.NGR(r.r4, r.r5)
        self.a.mc.LGFI(r.r3, loc.imm(18))
        self.a.mc.LGFI(r.r2, loc.imm(-1))
        self.a.mc.SRLG(r.r2, r.r3, loc.addr(18))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 0

    def test_generate_max_integral_64bit(self):
        self.a.mc.LGHI(r.r2, loc.imm(-1))
        self.a.mc.RISBG(r.r2, r.r2, loc.imm(1), loc.imm(0x80 | 63), loc.imm(0))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 2**63-1

    def test_generate_sign_bit(self):
        self.a.mc.LGHI(r.r2, loc.imm(-1))
        self.a.mc.RISBG(r.r2, r.r2, loc.imm(0), loc.imm(0x80 | 0), loc.imm(0))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == -2**63

    def test_ag_overflow(self):
        self.a.mc.BRC(con.ANY, loc.imm(4+8+8))
        self.a.mc.write('\x7f' + '\xff' * 7)
        self.a.mc.write('\x7f' + '\xff' * 7)
        self.a.mc.LARL(r.r5, loc.imm(-8))
        self.a.mc.LG(r.r4, loc.addr(8,r.r5))
        self.a.mc.AG(r.r4, loc.addr(0,r.r5))
        self.a.mc.LGR(r.r2, r.r4)
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == -2

    def test_xor(self):
        self.a.mc.XGR(r.r2, r.r2)
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 0

    def test_literal_pool(self):
        gen_func_prolog(self.a.mc)
        self.a.mc.BRAS(r.r13, loc.imm(8 + self.mc.BRAS_byte_count))
        self.a.mc.write('\x08\x07\x06\x05\x04\x03\x02\x01')
        self.a.mc.LG(r.r2, loc.addr(0, r.r13))
        gen_func_epilog(self.a.mc)
        assert run_asm(self.a) == 0x0807060504030201

    def label(self, name, func=False):
        if not func:
            return LabelCtx(self, name)
        return ActivationRecordCtx(self, name)

    def patch_branch_imm16(self, base, imm):
        imm = (imm & 0xffff) >> 1
        self.mc.overwrite(base, chr((imm >> 8) & 0xFF))
        self.mc.overwrite(base+1, chr(imm & 0xFF))

    def pos(self, name):
        return self.mc.ops_offset[name]
    def cur(self):
        return self.mc.get_relative_pos()

    def jump_here(self, func, name):
        if func.__name__ == 'BRAS':
            self.patch_branch_imm16(self.pos(name)+2, self.cur() - self.pos(name))
        else:
            raise NotImplementedError

    def jump_to(self, reg, label):
        val = (self.pos(label) - self.cur())
        self.mc.BRAS(reg, loc.imm(val))

    def test_stmg(self):
        self.mc.LGR(r.r2, r.r15)
        self.a.jmpto(r.r14)
        print hex(run_asm(self.a))

    def test_recursion(self):
        with ActivationRecordCtx(self):
            with self.label('lit'):
                self.mc.BRAS(r.r13, loc.imm(0))
            self.mc.write('\x00\x00\x00\x00\x00\x00\x00\x00')
            self.jump_here(self.mc.BRAS, 'lit')
            # recurse X times
            self.mc.XGR(r.r2, r.r2)
            self.mc.LGHI(r.r9, loc.imm(15))
            with self.label('L1'):
                self.mc.BRAS(r.r14, loc.imm(0))
            with ActivationRecordCtx(self, 'rec'):
                self.mc.AGR(r.r2, r.r9)
                self.mc.AHI(r.r9, loc.imm(-1))
                # if not entered recursion, return from activation record
                # implicitly generated here by with statement
                self.mc.BRC(con.GT, loc.imm(self.pos('rec') - self.cur()))
            self.jump_here(self.mc.BRAS, 'L1')
            # call rec... recursivly
            self.jump_to(r.r14, 'rec')
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 120

    def test_printf(self):
        with ActivationRecordCtx(self):
            with self.label('lit'):
                self.mc.BRAS(r.r13, loc.imm(0))
            for c in "hello syscall\n":
                self.mc.writechar(c)
            self.jump_here(self.mc.BRAS, 'lit')
            self.mc.LGHI(r.r2, loc.imm(1)) # stderr
            self.mc.LA(r.r3, loc.addr(0, r.r13)) # char*
            self.mc.LGHI(r.r4, loc.imm(14)) # length
            # write sys call
            self.mc.SVC(loc.imm(4))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 14

    def test_float(self):
        with ActivationRecordCtx(self):
            with self.label('lit'):
                self.mc.BRAS(r.r13, loc.imm(0))
            self.mc.write(BFL(-15.0))
            self.jump_here(self.mc.BRAS, 'lit')
            self.mc.LD(r.f0, loc.addr(0, r.r13))
            self.mc.CGDBR(r.r2, msk.RND_CURMODE, r.f0)
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == -15

    @py.test.mark.parametrize("v1,v2,res", [
        (    0.0,       0.0,       0.0),
        (   -15.0,    -15.0,     -30.0),
        (    1.5,     -3.22,      -1.72),
        (    0.5,       0.0,       0.5),
        (    0.0001,   -0.0002,   -0.0001),
        (float('nan'), 1.0, float('nan')),
    ])
    def test_float_to_memory(self, v1, v2, res):
        with lltype.scoped_alloc(DOUBLE_ARRAY_PTR.TO, 16) as mem:
            with ActivationRecordCtx(self):
                with self.label('lit'):
                    self.mc.BRAS(r.r13, loc.imm(0))
                self.mc.write(BFL(v1))
                self.mc.write(BFL(v2))
                self.mc.write(ADDR(mem))
                self.jump_here(self.mc.BRAS, 'lit')
                self.mc.LD(r.f0, loc.addr(0, r.r13))
                self.mc.LD(r.f1, loc.addr(8, r.r13))
                self.mc.ADBR(r.f0, r.f1)
                self.mc.LG(r.r11, loc.addr(16, r.r13))
                self.mc.STD(r.f0, loc.addr(0, r.r11))
            self.a.jmpto(r.r14)
            run_asm(self.a)
            assert isclose(mem[0],res)

    @py.test.mark.parametrize("v1,v2,res", [
        (    0.0,       0.0,       0.0),
        (   -15.0,    -15.0,     225.0),
        (    0.0, 9876543.21,      0.0),
        (   -0.5,      14.5,      -7.25),
        (    0.0001,    2.0,       0.0002),
        (float('nan'), 1.0, float('nan')),
    ])
    def test_float_mul_to_memory(self, v1, v2, res):
        with lltype.scoped_alloc(DOUBLE_ARRAY_PTR.TO, 16) as mem:
            with ActivationRecordCtx(self):
                with LiteralPoolCtx(self) as pool:
                    pool.float(v1)
                    pool.float(v2)
                    pool.addr(mem)
                self.mc.LD(r.f0, loc.addr(0, r.r13))
                self.mc.MDB(r.f0, loc.addr(8, r.r13))
                self.mc.LG(r.r11, loc.addr(16, r.r13))
                self.mc.STD(r.f0, loc.addr(0, r.r11))
            self.a.jmpto(r.r14)
            run_asm(self.a)
            assert isclose(mem[0],res)

    def test_float_load_zero(self):
        with lltype.scoped_alloc(DOUBLE_ARRAY_PTR.TO, 16) as mem:
            with ActivationRecordCtx(self):
                with LiteralPoolCtx(self) as pool:
                    pool.addr(mem)
                self.mc.LZDR(r.f0)
                self.mc.LG(r.r11, loc.addr(0, r.r13))
                self.mc.STD(r.f0, loc.addr(0, r.r11))
            run_asm(self.a)
            assert isclose(mem[0], 0.0)

    def test_cast_single_float_to_float(self):
        with lltype.scoped_alloc(DOUBLE_ARRAY_PTR.TO, 16) as mem:
            with ActivationRecordCtx(self):
                with LiteralPoolCtx(self) as pool:
                    pool.single_float(6.66)
                    pool.addr(mem)
                self.mc.LEY(r.f1, loc.addr(0, r.r13))
                ## cast short to long!
                self.mc.LDEBR(r.f0, r.f1) 
                self.mc.LG(r.r11, loc.addr(4, r.r13))
                self.mc.STD(r.f0, loc.addr(0, r.r11))
            run_asm(self.a)
            assert isclose(mem[0], 6.66, abs_tol=0.05)

    def test_cast_int64_to_float(self):
        with lltype.scoped_alloc(DOUBLE_ARRAY_PTR.TO, 16) as mem:
            with ActivationRecordCtx(self):
                with LiteralPoolCtx(self) as pool:
                    pool.int64(12345)
                    pool.addr(mem)
                self.mc.LG(r.r12, loc.addr(0, r.r13))
                # cast int to float!
                self.mc.CDGBR(r.f0, r.r12) 
                self.mc.LG(r.r11, loc.addr(8, r.r13))
                self.mc.STD(r.f0, loc.addr(0, r.r11))
            run_asm(self.a)
            assert isclose(mem[0], 12345.0)

    def test_float_cmp(self):
        with ActivationRecordCtx(self):
            with LiteralPoolCtx(self) as pool:
                pool.float(1.0)
                pool.float(2.0)
            self.mc.LD(r.f0, loc.addr(0, r.r13))
            self.mc.LD(r.f1, loc.addr(8, r.r13))
            self.mc.CDBR(r.f0, r.f1)
            self.mc.LGHI(r.r2, loc.imm(0))
            self.mc.BCR(con.EQ, r.r14) # must not branch
            self.mc.LGHI(r.r2, loc.imm(1))
        self.a.jmpto(r.r14)
        assert run_asm(self.a) == 1

    def pushpop_jitframe(self, registers):
        self.a._push_core_regs_to_jitframe(self.mc, registers)
        self.a._pop_core_regs_from_jitframe(self.mc, registers)

    def test_pushpop_jitframe_multiple_optimization(self):
        stored = []
        loaded = []
        def STMG(start, end, addr):
            stored.append((start, end))
        def STG(reg, addr):
            stored.append((reg,))
        def LMG(start, end, addr):
            loaded.append((start, end)) 
        def LG(reg, addr):
            loaded.append((reg,))
        self.mc.STMG = STMG
        self.mc.STG = STG
        self.mc.LMG = LMG
        self.mc.LG = LG

        # 2-6
        self.pushpop_jitframe([r.r2, r.r3, r.r4, r.r5, r.r6, r.r8, r.r10])
        assert stored == [(r.r2, r.r6), (r.r8,), (r.r10,)]
        assert stored == loaded
        stored = []
        loaded = []

        # two sequences 10-11, 13-14
        self.pushpop_jitframe([r.r2, r.r3, r.r10, r.r11])
        assert stored == [(r.r2, r.r3), (r.r10, r.r11)]
        assert stored == loaded
        stored = []
        loaded = []

        # one sequence and on single
        self.pushpop_jitframe([r.r2, r.r3, r.r5])
        assert stored == [(r.r2, r.r3), (r.r5,)]
        assert stored == loaded
        stored = []
        loaded = []

        # single items
        self.pushpop_jitframe(r.MANAGED_REGS[::2])
        assert stored == [(x,) for x in r.MANAGED_REGS[::2]]
        assert stored == loaded
        stored = []
        loaded = []

        # large sequence 0-5 and one hole between
        self.pushpop_jitframe([r.r2, r.r3,
            r.r4, r.r5, r.r10, r.r11])
        assert stored == [(r.r2, r.r5), (r.r10, r.r11)]
        assert stored == loaded
        stored = []
        loaded = []

        # ensure there is just on instruction for the 'best case'
        self.pushpop_jitframe(r.MANAGED_REGS)
        assert stored == [(r.r2, r.r11)]
        assert stored == loaded
        stored = []
        loaded = []

        # just one single
        for x in [r.r10, r.r3, r.r2, r.r11]:
            self.pushpop_jitframe([x])
            assert stored == [(x,)]
            assert stored == loaded
            stored = []
            loaded = []

        # unordered
        self.pushpop_jitframe([r.r11, r.r8, r.r4, r.r2])
        assert stored == [(r.r11,), (r.r8,), (r.r4,), (r.r2,)]
        assert stored == loaded
        stored = []
        loaded = []



