from rpython.jit.backend.arm import conditions as c
from rpython.jit.backend.arm import registers as r
from rpython.jit.backend.arm.assembler import AssemblerARM
from rpython.jit.backend.arm.locations import imm
from rpython.jit.backend.arm.test.support import run_asm
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.codewriter import longlong

from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.backend.model import CompiledLoopToken
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.annlowlevel import llhelper
from rpython.rlib.objectmodel import specialize
from rpython.rlib.debug import ll_assert

CPU = getcpuclass()


class TestRunningAssembler(object):
    def setup_method(self, method):
        cpu = CPU(None, None)
        self.a = AssemblerARM(cpu)
        self.a.setup_once()
        token = JitCellToken()
        clt = CompiledLoopToken(cpu, 0)
        clt.allgcrefs = []
        token.compiled_loop_token = clt
        self.a.setup(token)

    def test_make_operation_list(self):
        i = rop.INT_ADD
        from rpython.jit.backend.arm import assembler
        assert assembler.asm_operations[i] \
            is AssemblerARM.emit_op_int_add.im_func

    def test_load_small_int_to_reg(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r0.value, 123)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 123

    def test_load_medium_int_to_reg(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r0.value, 0xBBD7)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 48087

    def test_load_int_to_reg(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r0.value, 0xFFFFFF85)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == -123

    def test_load_neg_int_to_reg(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r0.value, -110)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == -110

    def test_load_neg_int_to_reg2(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r0.value, -3)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == -3

    def test_load_int1(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r0.value, 440)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 440

    def test_load_int2(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r0.value, 464)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 464

    def test_or(self):
        self.a.gen_func_prolog()
        self.a.mc.MOV_ri(r.r1.value, 8)
        self.a.mc.MOV_ri(r.r2.value, 8)
        self.a.mc.ORR_rr(r.r0.value, r.r1.value, r.r2.value, 4)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 0x88

    def test_sub(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r1.value, 123456)
        self.a.mc.SUB_ri(r.r0.value, r.r1.value, 123)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 123333

    def test_cmp(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r1.value, 22)
        self.a.mc.CMP_ri(r.r1.value, 123)
        self.a.mc.MOV_ri(r.r0.value, 1, c.LE)
        self.a.mc.MOV_ri(r.r0.value, 0, c.GT)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 1

    def test_int_le_false(self):
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r1.value, 2222)
        self.a.mc.CMP_ri(r.r1.value, 123)
        self.a.mc.MOV_ri(r.r0.value, 1, c.LE)
        self.a.mc.MOV_ri(r.r0.value, 0, c.GT)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 0

    def test_simple_jump(self):
        self.a.gen_func_prolog()
        self.a.mc.MOV_ri(r.r1.value, 1)
        loop_head = self.a.mc.currpos()
        self.a.mc.CMP_ri(r.r1.value, 0)  # z=0, z=1
        self.a.mc.MOV_ri(r.r1.value, 0, cond=c.NE)
        self.a.mc.MOV_ri(r.r1.value, 7, cond=c.EQ)
        self.a.mc.B_offs(loop_head, c.NE)
        self.a.mc.MOV_rr(r.r0.value, r.r1.value)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 7

    def test_jump(self):
        self.a.gen_func_prolog()
        self.a.mc.MOV_ri(r.r1.value, 1)
        loop_head = self.a.mc.currpos()
        self.a.mc.ADD_ri(r.r1.value, r.r1.value, 1)
        self.a.mc.CMP_ri(r.r1.value, 9)
        self.a.mc.B_offs(loop_head, c.NE)
        self.a.mc.MOV_rr(r.r0.value, r.r1.value)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 9

    def test_B_offs_imm(self):
        self.a.mc.PUSH([reg.value for reg in r.callee_saved_registers])
        self.a.mc.MOV_ri(r.r0.value, 0)
        self.a.mc.MOV_ri(r.r1.value, 0)
        self.a.mc.CMP_rr(r.r0.value, r.r1.value)
        pos = self.a.mc.currpos()
        self.a.mc.MOV_ri(r.r0.value, 123, cond=c.NE)

        for x in range(15):
            self.a.mc.POP(
                [reg.value for reg in r.callee_restored_registers], cond=c.NE)

        self.a.mc.MOV_ri(r.r1.value, 33)
        self.a.mc.MOV_ri(r.r0.value, 23)
        self.a.mc.CMP_rr(r.r0.value, r.r1.value)
        self.a.mc.B_offs(pos)
        assert run_asm(self.a) == 123

    def test_B_offs_reg(self):
        self.a.mc.PUSH([reg.value for reg in r.callee_saved_registers])
        self.a.mc.MOV_ri(r.r0.value, 0)
        self.a.mc.MOV_ri(r.r1.value, 0)
        self.a.mc.CMP_rr(r.r0.value, r.r1.value)
        pos = self.a.mc.currpos()
        self.a.mc.MOV_ri(r.r0.value, 123, cond=c.NE)

        for x in range(100):
            self.a.mc.POP(
                [reg.value for reg in r.callee_restored_registers], cond=c.NE)

        self.a.mc.MOV_ri(r.r1.value, 33)
        self.a.mc.MOV_ri(r.r0.value, 23)
        self.a.mc.CMP_rr(r.r0.value, r.r1.value)
        self.a.mc.B_offs(pos)
        assert run_asm(self.a) == 123

    def test_call_python_func(self):
        functype = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed))
        call_addr = rffi.cast(lltype.Signed, llhelper(functype, callme))
        self.a.gen_func_prolog()
        self.a.mc.MOV_ri(r.r0.value, 123)
        self.a.mc.BL(call_addr)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 133

    def test_bl_with_conditional_exec(self):
        functype = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed))
        call_addr = rffi.cast(lltype.Signed, llhelper(functype, callme))
        self.a.gen_func_prolog()
        self.a.mc.MOV_ri(r.r0.value, 123)
        self.a.mc.CMP_ri(r.r0.value, 1)
        self.a.mc.BL(call_addr, c.NE)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 133

    def test_mov_small_imm_loc_to_loc(self):
        self.a.gen_func_prolog()
        self.a.mov_loc_loc(imm(12), r.r0)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 12

    def test_mov_large_imm_loc_to_loc(self):
        self.a.gen_func_prolog()
        self.a.mov_loc_loc(imm(2478), r.r0)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == 2478

    def test_load_store(self):
        x = 0x60002224
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.r1.value, x)
        self.a.mc.SUB_ri(r.sp.value, r.sp.value, 8)
        self.a.mc.MOV_ri(r.r3.value, 8)
        self.a.mc.STR_rr(r.r1.value, r.sp.value, r.r3.value)
        self.a.mc.LDR_ri(r.r0.value, r.sp.value, 8)
        self.a.mc.ADD_ri(r.sp.value, r.sp.value, 8)
        self.a.gen_func_epilog()
        assert run_asm(self.a) == x
    
    def test_stm(self):
        container = lltype.malloc(lltype.Array(lltype.Signed, hints={'nolength': True}), 10, flavor='raw')
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.ip.value, rffi.cast(lltype.Signed, container))
        for x in range(10):
            self.a.mc.gen_load_int(x, x)
        self.a.mc.STM(r.ip.value, [x for x in range(10)])
        self.a.gen_func_epilog()
        run_asm(self.a)
        for x in range(10):
            assert container[x] == x
        lltype.free(container, flavor='raw')

    def test_ldm(self):
        container = lltype.malloc(lltype.Array(lltype.Signed, hints={'nolength': True}), 10, flavor='raw')
        for x in range(10):
            container[x] = x
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.ip.value, rffi.cast(lltype.Signed, container))
        self.a.mc.LDM(r.ip.value, [x for x in range(10)])
        for x in range(1, 10):
            self.a.mc.ADD_rr(0, 0, x)
        self.a.gen_func_epilog()
        res = run_asm(self.a)
        assert res == sum(range(10))
        lltype.free(container, flavor='raw')

    def test_vstm(self):
        n = 14
        source_container = lltype.malloc(lltype.Array(longlong.FLOATSTORAGE,
            hints={'nolength': True}), n, flavor='raw')
        target_container = lltype.malloc(lltype.Array(longlong.FLOATSTORAGE,
            hints={'nolength': True}), n, flavor='raw')
        for x in range(n):
            source_container[x] = longlong.getfloatstorage(float("%d.%d" % (x,x)))
        self.a.gen_func_prolog()
        for x in range(n):
            self.a.mc.ADD_ri(r.ip.value, r.ip.value, 8)
            self.a.mc.VLDR(n, r.ip.value)
        self.a.mc.gen_load_int(r.ip.value, rffi.cast(lltype.Signed, target_container))
        self.a.mc.VSTM(r.ip.value, [x for x in range(n)])
        self.a.gen_func_epilog()
        run_asm(self.a)
        for d in range(n):
            res = longlong.getrealfloat(target_container[0]) == float("%d.%d" % (d,d))
        lltype.free(source_container, flavor='raw')
        lltype.free(target_container, flavor='raw')

    def test_vldm(self):
        n = 14
        container = lltype.malloc(lltype.Array(longlong.FLOATSTORAGE,
                                hints={'nolength': True}), n, flavor='raw')
        for x in range(n):
            container[x] = longlong.getfloatstorage(float("%d.%d" % (x,x)))
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.ip.value, rffi.cast(lltype.Signed, container))
        self.a.mc.VLDM(r.ip.value, [x for x in range(n)])
        for x in range(1, n):
            self.a.mc.VADD(0, 0, x)
        self.a.mc.VSTR(r.d0.value, r.ip.value)
        self.a.gen_func_epilog()
        res = run_asm(self.a)
        assert longlong.getrealfloat(container[0]) == sum([float("%d.%d" % (d,d)) for d in range(n)])
        lltype.free(container, flavor='raw')

    def test_vstm_vldm_combined(self):
        n = 14
        source_container = lltype.malloc(lltype.Array(longlong.FLOATSTORAGE,
            hints={'nolength': True}), n, flavor='raw')
        target_container = lltype.malloc(lltype.Array(longlong.FLOATSTORAGE,
            hints={'nolength': True}), n, flavor='raw')
        for x in range(n):
            source_container[x] = longlong.getfloatstorage(float("%d.%d" % (x,x)))
        self.a.gen_func_prolog()
        self.a.mc.gen_load_int(r.ip.value, rffi.cast(lltype.Signed, source_container))
        self.a.mc.VLDM(r.ip.value, [x for x in range(n)])
        self.a.mc.gen_load_int(r.ip.value, rffi.cast(lltype.Signed, target_container))
        self.a.mc.VSTM(r.ip.value, [x for x in range(n)])
        self.a.gen_func_epilog()
        run_asm(self.a)
        for d in range(n):
            res = longlong.getrealfloat(target_container[0]) == float("%d.%d" % (d,d))
        lltype.free(source_container, flavor='raw')
        lltype.free(target_container, flavor='raw')

def callme(inp):
    i = inp + 10
    return i
