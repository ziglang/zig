from rpython.jit.backend.arm import registers as r
from rpython.jit.backend.arm import codebuilder
from rpython.jit.backend.arm import conditions
from rpython.jit.backend.arm import instructions
from rpython.jit.backend.arm.test.support import requires_arm_as
from rpython.jit.backend.arm.test.support import get_as_version
from rpython.jit.backend.arm.test.support import define_test
from rpython.jit.backend.arm.test.support import gen_test_function
from gen import assemble
import py

requires_arm_as()

class CodeBuilder(codebuilder.InstrBuilder):
    def __init__(self, arch_version=7):
        self.arch_version = arch_version
        self.buffer = []

    def writechar(self, char):
        self.buffer.append(char)

    def hexdump(self):
        return ''.join(self.buffer)

class ASMTest(object):
    def assert_equal(self, asm):
        assert self.cb.hexdump() == assemble(asm)


class TestInstrCodeBuilder(ASMTest):
    def setup_method(self, ffuu_method):
        self.cb = CodeBuilder()

    def test_ldr(self):
        self.cb.LDR_ri(r.r0.value, r.r1.value)
        self.assert_equal('LDR r0, [r1]')

    def test_ldr_neg(self):
        self.cb.LDR_ri(r.r3.value, r.fp.value, -16)
        self.assert_equal('LDR r3, [fp, #-16]')

    def test_add_ri(self):
        self.cb.ADD_ri(r.r0.value, r.r1.value, 1)
        self.assert_equal('ADD r0, r1, #1')

    def test_mov_rr(self):
        self.cb.MOV_rr(r.r7.value, r.r12.value)
        self.assert_equal('MOV r7, r12')

    def test_mov_ri(self):
        self.cb.MOV_ri(r.r9.value, 123)
        self.assert_equal('MOV r9, #123')

    def test_mov_ri2(self):
        self.cb.MOV_ri(r.r9.value, 255)
        self.assert_equal('MOV r9, #255')

    def test_mov_ri_max(self):
        self.cb.MOV_ri(r.r9.value, 0xFF)
        self.assert_equal('MOV r9, #255')

    def test_str_ri(self):
        self.cb.STR_ri(r.r9.value, r.r14.value)
        self.assert_equal('STR r9, [r14]')

    def test_str_ri_offset(self):
        self.cb.STR_ri(r.r9.value, r.r14.value, 23)
        self.assert_equal('STR r9, [r14, #23]')

    def test_str_ri_offset(self):
        self.cb.STR_ri(r.r9.value, r.r14.value, -20)
        self.assert_equal('STR r9, [r14, #-20]')

    def test_asr_ri(self):
        self.cb.ASR_ri(r.r7.value, r.r5.value, 24)
        self.assert_equal('ASR r7, r5, #24')

    def test_orr_rr_no_shift(self):
        self.cb.ORR_rr(r.r0.value, r.r7.value, r.r12.value)
        self.assert_equal('ORR r0, r7, r12')

    def test_orr_rr_lsl_8(self):
        self.cb.ORR_rr(r.r0.value, r.r7.value, r.r12.value, 8)
        self.assert_equal('ORR r0, r7, r12, lsl #8')

    def test_push_one_reg(self):
        if get_as_version() < (2, 23):
            py.test.xfail("GNU as before version 2.23 generates encoding A1 for "
                        "pushing only one register")
        self.cb.PUSH([r.r1.value])
        self.assert_equal('PUSH {r1}')

    def test_push_multiple(self):
        self.cb.PUSH([reg.value for reg in [r.r1, r.r3, r.r6, r.r8, r.pc]])
        self.assert_equal('PUSH {r1, r3, r6, r8, pc}')

    def test_push_multiple2(self):
        self.cb.PUSH([reg.value for reg in [r.fp, r.ip, r.lr, r.pc]])
        self.assert_equal('PUSH {fp, ip, lr, pc}')

    def test_vpush_one_reg(self):
        self.cb.VPUSH([r.d3.value])
        self.assert_equal('VPUSH {d3}')

    def test_vpush_one_reg2(self):
        self.cb.VPUSH([r.d12.value])
        self.assert_equal('VPUSH {d12}')

    def test_vpush_multiple(self):
        self.cb.VPUSH([reg.value for reg in [r.d11, r.d12, r.d13, r.d14, r.d15]])
        self.assert_equal('VPUSH {D11, D12, D13, D14, D15}')

    def test_sub_ri(self):
        self.cb.SUB_ri(r.r2.value, r.r4.value, 123)
        self.assert_equal('SUB r2, r4, #123')

    def test_sub_ri2(self):
        self.cb.SUB_ri(r.r3.value, r.r7.value, 0xFF)
        self.assert_equal('SUB r3, r7, #255')

    def test_cmp_ri(self):
        self.cb.CMP_ri(r.r3.value, 123)
        self.assert_equal('CMP r3, #123')

    def test_mcr(self):
        self.cb.MCR(15, 0, r.r1.value, 7, 10,0)

        self.assert_equal('MCR P15, 0, r1, c7, c10, 0')

    def test_push_eq_stmdb(self):
        # XXX check other conditions in STMDB
        self.cb.PUSH([reg.value for reg in r.caller_resp], cond=conditions.AL)
        self.assert_equal('STMDB SP!, {r0, r1, r2, r3}')

    def test_push(self):
        self.cb.PUSH([reg.value for reg in r.caller_resp], cond=conditions.AL)
        self.assert_equal('PUSH {r0, r1, r2, r3}')

    def test_push_raises_sp(self):
        assert py.test.raises(AssertionError, 'self.cb.PUSH([r.sp.value])')

    def test_stm(self):
        self.cb.STM(r.fp.value, [reg.value for reg in r.caller_resp], cond=conditions.AL)
        self.assert_equal('STM fp, {r0, r1, r2, r3}')

    def test_ldm(self):
        self.cb.LDM(r.fp.value, [reg.value for reg in r.caller_resp], cond=conditions.AL)
        self.assert_equal('LDM fp, {r0, r1, r2, r3}')

    def test_vstm(self):
        self.cb.VSTM(r.fp.value, [reg.value for reg in r.caller_vfp_resp], cond=conditions.AL)
        self.assert_equal('VSTM fp, {d0, d1, d2, d3, d4, d5, d6, d7}')

    def test_vldm(self):
        self.cb.VLDM(r.fp.value, [reg.value for reg in r.caller_vfp_resp], cond=conditions.AL)
        self.assert_equal('VLDM fp, {d0, d1, d2, d3, d4, d5, d6, d7}')

    def test_pop(self):
        self.cb.POP([reg.value for reg in r.caller_resp], cond=conditions.AL)
        self.assert_equal('POP {r0, r1, r2, r3}')

    def test_pop_eq_ldm(self):
        # XXX check other conditions in LDM
        self.cb.POP([reg.value for reg in r.caller_resp], cond=conditions.AL)
        self.assert_equal('LDM SP!, {r0, r1, r2, r3}')

    def test_double_add(self):
        self.cb.VADD(r.d1.value, r.d2.value, r.d3.value, conditions.LE)
        self.assert_equal("VADDLE.F64 D1, D2, D3")

    def test_double_sub(self):
        self.cb.VSUB(r.d1.value, r.d2.value, r.d3.value, conditions.GT)
        self.assert_equal("VSUBGT.F64 D1, D2, D3")

    def test_vstr_offset(self):
        assert py.test.raises(AssertionError, 'self.cb.VSTR(r.d1, r.r4, 3)')

    def test_vmrs(self):
        self.cb.VMRS(conditions.AL)
        self.assert_equal("vmrs APSR_nzcv, fpscr")

    def test_movw(self):
        self.cb.MOVW_ri(r.r3.value, 0xFFFF, conditions.NE)
        self.assert_equal("MOVWNE r3, #65535")

    def test_movt(self):
        self.cb.MOVT_ri(r.r3.value, 0xFFFF, conditions.NE)
        self.assert_equal("MOVTNE r3, #65535")

    def test_ldrex(self):
        self.cb.LDREX(r.r10.value, r.r11.value)
        self.assert_equal('LDREX r10, [r11]')

    def test_strex(self):
        self.cb.STREX(r.r9.value, r.r1.value, r.r14.value, conditions.NE)
        self.assert_equal('STREXNE r9, r1, [r14]')

    def test_dmb(self):
        self.cb.DMB()
        self.assert_equal('DMB')

    def test_fmdrr(self):
        self.cb.FMDRR(r.d11.value, r.r9.value, r.r14.value)
        self.assert_equal('FMDRR d11, r9, r14')

    def test_fmrrd(self):
        self.cb.FMRRD(r.r9.value, r.r14.value, r.d11.value)
        self.assert_equal('FMRRD r9, r14, d11')


def test_size_of_gen_load_int():
    for v, n in [(5, 4), (6, 4), (7, 2)]:
        c = CodeBuilder(v)
        assert c.get_max_size_of_gen_load_int() == n


class TestInstrCodeBuilderForGeneratedInstr(ASMTest):
    def setup_method(self, ffuu_method):
        self.cb = CodeBuilder()

def gen_test_float_load_store_func(name, table):
    tests = []
    for c,v in [('EQ', conditions.EQ), ('LE', conditions.LE), ('AL', conditions.AL)]:
        for reg in range(15):
            for creg in range(2):
                asm = 'd%d, [r%d]' % (creg, reg)
                tests.append((asm, (creg, reg)))
                asm = 'd%d, [r%d, #16]' % (creg, reg)
                tests.append((asm, (creg, reg, 16)))
    return tests

def gen_test_float64_data_proc_instructions_func(name, table):
    tests = []
    for c,v in [('EQ', conditions.EQ), ('LE', conditions.LE), ('AL', conditions.AL)]:
        for reg in range(15):
            if 'result' in table and not table['result']:
                asm = 'd%d, d2' % reg
                tests.append((asm, (reg, r.d2.value), {}, '.F64'))
            elif 'base' in table and not table['base']:
                asm = 'd%d, d2' % reg
                tests.append((asm, (reg, r.d2.value), {}, '.F64'))
            else:
                asm = 'd%d, d1, d2' % reg
                tests.append((asm, (reg, r.d1.value, r.d2.value), {}, '.F64'))
    return tests

def gen_test_data_proc_imm_func(name, table):
    if table['result'] and table['base']:
        def f(self):
            func = getattr(self.cb, name)
            func(r.r3.value, r.r7.value, 23)
            self.assert_equal('%s r3, r7, #23' % name[:name.index('_')])
            py.test.raises(ValueError, 'func(r.r3.value, r.r7.value, -12)')
        return [f]
    else:
        return [('r3, #23', [r.r3.value, 23])]

def gen_test_load_store_func(name, table):
    if table['imm']:
        return [('r3, [r7, #23]', [r.r3.value, r.r7.value, 23]),
            ('r3, [r7, #-23]', [r.r3.value, r.r7.value, -23])
            ]
    else:
        return [('r3, [r7, r12]', [r.r3.value, r.r7.value, r.r12.value])]

def gen_test_extra_load_store_func(name, table):
    if name[-4] == 'D':
        if name[-2:] == 'rr':
            return [('r4, [r8, r12]', [r.r4.value, r.r5.value, r.r8.value, r.r12.value])]
        else:
            return [('r4, [r8, #223]', [r.r4.value, r.r5.value, r.r8.value, 223])]
    else:
        if name[-2:] == 'rr':
            return [('r4, [r5, r12]', [r.r4.value, r.r5.value, r.r12.value])]
        else:
            return [('r4, [r5, #223]', [r.r4.value, r.r5.value, 223])]
    return f

def gen_test_multiply_func(name, table):
    if 'acc' in table and table['acc']:
        if 'update_flags' in table and table['update_flags']:
            return [
            ('r3, r7, r12, r13', (r.r3.value, r.r7.value, r.r12.value, r.r13.value)),
            ('r3, r7, r12, r13', (r.r3.value, r.r7.value, r.r12.value, r.r13.value), {'s':1}, 'S')
            ]
        else:
            return [('r3, r7, r12, r13', (r.r3.value, r.r7.value, r.r12.value,
            r.r13.value))]
    elif 'long' in table and table['long']:
        return [('r3, r13, r7, r12', (r.r3.value, r.r13.value, r.r7.value, r.r12.value))]
    else:
        return [('r3, r7, r12', (r.r3.value, r.r7.value, r.r12.value))]

def gen_test_data_proc_reg_shift_reg_func(name, table):
    if name[-2:] == 'rr':
        return [('r3, r7, r12', [r.r3.value, r.r7.value, r.r12.value])]
    else:
        result = 'result' not in table or table['result']
        if result:
            return [('r3, r7, r8, ASR r11', [r.r3.value, r.r7.value,
                            r.r8.value, r.r11.value], {'shifttype':0x2})]
        else:
            return [('r3, r7, ASR r11', [r.r3.value, r.r7.value,
                            r.r11.value], {'shifttype':0x2})]

def gen_test_data_proc_func(name, table):
    op_name = name[:name.index('_')]
    if name[-2:] == 'ri':
        return [('r3, r7, #12', (r.r3.value, r.r7.value, 12)),
                ('r3, r7, #12', (r.r3.value, r.r7.value, 12), {'s':1}, 'S')]
    elif table['base'] and table['result']:
        return [('r3, r7, r12', (r.r3.value, r.r7.value, r.r12.value)),
                ('r3, r7, r12', (r.r3.value, r.r7.value, r.r12.value), {'s':1}, 'S')]
    else:
        return [('r3, r7', [r.r3.value, r.r7.value])]

def gen_test_supervisor_and_coproc_func(name, table):
    def f(self):
        py.test.skip('not used at the moment')
    return [f]

def gen_test_branch_func(name, table):
    def f(self):
        py.test.skip('not used at the moment')
    return [f]

def gen_test_block_data_func(name, table):
    tests = []
    for c,v in [('EQ', conditions.EQ), ('LE', conditions.LE), ('AL', conditions.AL)]:
        for regs in range(16):
            asm = 'r3, {%s}' % ','.join(['r%d' % i for i in range(regs+1)])
            tests.append((asm, (r.r3.value, range(regs+1))))
    return tests

def gen_test_simd_instructions_3regs_func(name, table):
    op_name = name[:name.index('_')]
    return  [('d1, d2, d3', (r.d1.value, r.d2.value, r.d3.value), {}, '.i64')]

def build_tests():
    cls = TestInstrCodeBuilderForGeneratedInstr
    test_name = 'test_generated_%s'
    ins = [k for k in instructions.__dict__.keys() if not k.startswith('__')]
    for name in ins:
        try:
            func = globals()['gen_test_%s_func' % name]
        except KeyError:
            print 'No test generator for %s instructions' % name
            continue
        for key, value in getattr(instructions, name).iteritems():
            for test_case in func(key, value):
                define_test(cls, key, test_case, name)
build_tests()
