from rpython.jit.backend.arm import conditions as cond
from rpython.jit.backend.arm import instructions


# move table lookup out of generated functions
def define_load_store_func(name, table):
    n = (0x1 << 26
        | (table['A'] & 0x1) << 25
        | (table['op1'] & 0x1F) << 20)
    if 'B' in table:
        b_zero = True
    else:
        b_zero = False
    op1cond = table['op1not']
    rncond = ('rn' in table and table['rn'] == '!0xF')
    if table['imm']:
        assert not b_zero

        def f(self, rt, rn, imm=0, cond=cond.AL):
            assert not (rncond and rn == 0xF)
            p = 1
            w = 0
            u, imm = self._encode_imm(imm)
            instr = (n
                    | cond << 28
                    | (p & 0x1) << 24
                    | (u & 0x1) << 23
                    | (w & 0x1) << 21
                    | imm_operation(rt, rn, imm))
            assert instr & 0x1F00000 != op1cond
            self.write32(instr)
    else:
        def f(self, rt, rn, rm, imm=0, cond=cond.AL, s=0, shifttype=0):
            assert not (rncond and rn == 0xF)
            p = 1
            w = 0
            u, imm = self._encode_imm(imm)
            instr = (n
                    | cond << 28
                    | (p & 0x1) << 24
                    | (u & 0x1) << 23
                    | (w & 0x1) << 21
                    | reg_operation(rt, rn, rm, imm, s, shifttype))
            if b_zero:
                assert instr & 0x10 == 0, 'bit 4 should be zero'
            assert instr & 0x1F00000 != op1cond
            self.write32(instr)
    return f


def define_extra_load_store_func(name, table):
    def check_registers(r1, r2):
        assert r1 % 2 == 0
        assert r1 + 1 == r2
        assert r1 != 14

    n = ((table['op1'] & 0x1F) << 20
        | 0x1 << 7
        | (table['op2'] & 0x3) << 5
        | 0x1 << 4)
    p = 1
    w = 0
    rncond = ('rn' in table and table['rn'] == '!0xF')
    dual = (name[-4] == 'D')

    if dual:
        if name[-2:] == 'rr':
            def f(self, rt, rt2, rn, rm, cond=cond.AL):
                check_registers(rt, rt2)
                assert not (rncond and rn == 0xF)
                self.write32(n
                        | cond << 28
                        | (p & 0x1) << 24
                        | (1 & 0x1) << 23
                        | (w & 0x1) << 21
                        | (rn & 0xF) << 16
                        | (rt & 0xF) << 12
                        | (rm & 0xF))
        else:
            def f(self, rt, rt2, rn, imm=0, cond=cond.AL):
                check_registers(rt, rt2)
                assert not (rncond and rn == 0xF)
                u, imm = self._encode_imm(imm)
                self.write32(n
                        | cond << 28
                        | (p & 0x1) << 24
                        | (u & 0x1) << 23
                        | (w & 0x1) << 21
                        | (rn & 0xF) << 16
                        | (rt & 0xF) << 12
                        | ((imm >> 0x4) & 0xF) << 8
                        | (imm & 0xF))

    else:
        if name[-2:] == 'rr':
            def f(self, rt, rn, rm, cond=cond.AL):
                assert not (rncond and rn == 0xF)
                self.write32(n
                        | cond << 28
                        | (p & 0x1) << 24
                        | (1 & 0x1) << 23
                        | (w & 0x1) << 21
                        | (rn & 0xF) << 16
                        | (rt & 0xF) << 12
                        | (rm & 0xF))
        else:
            def f(self, rt, rn, imm=0, cond=cond.AL):
                assert not (rncond and rn == 0xF)
                u, imm = self._encode_imm(imm)
                self.write32(n
                        | cond << 28
                        | (p & 0x1) << 24
                        | (u & 0x1) << 23
                        | (w & 0x1) << 21
                        | (rn & 0xF) << 16
                        | (rt & 0xF) << 12
                        | ((imm >> 0x4) & 0xF) << 8
                        | (imm & 0xF))
    return f


def define_data_proc_imm_func(name, table):
    n = (0x1 << 25
        | (table['op'] & 0x1F) << 20)
    if table['result'] and table['base']:
        def imm_func(self, rd, rn, imm=0, cond=cond.AL, s=0):
            if imm < 0:
                raise ValueError
            self.write32(n
                | cond << 28
                | s << 20
                | imm_operation(rd, rn, imm))
    elif not table['base']:
        def imm_func(self, rd, imm=0, cond=cond.AL, s=0):
            self.write32(n
                | cond << 28
                | s << 20
                | imm_operation(rd, 0, imm))
    else:
        def imm_func(self, rn, imm=0, cond=cond.AL, s=0):
            self.write32(n
                | cond << 28
                | s << 20
                | imm_operation(0, rn, imm))
    return imm_func


def define_data_proc_func(name, table):
    n = ((table['op1'] & 0x1F) << 20
        | (table['op2'] & 0x1F) << 7
        | (table['op3'] & 0x3) << 5)
    if name[-2:] == 'ri':
        def f(self, rd, rm, imm=0, cond=cond.AL, s=0):
            if table['op2cond'] == '!0':
                assert imm != 0
            elif table['op2cond'] == '0':
                assert imm == 0
            self.write32(n
                        | cond << 28
                        | (s & 0x1) << 20
                        | (rd & 0xFF) << 12
                        | (imm & 0x1F) << 7
                        | (rm & 0xFF))

    elif not table['result']:
        # ops without result
        def f(self, rn, rm, imm=0, cond=cond.AL, s=0, shifttype=0):
            self.write32(n
                        | cond << 28
                        | reg_operation(0, rn, rm, imm, s, shifttype))
    elif not table['base']:
        # ops without base register
        def f(self, rd, rm, imm=0, cond=cond.AL, s=0, shifttype=0):
            self.write32(n
                        | cond << 28
                        | reg_operation(rd, 0, rm, imm, s, shifttype))
    else:
        def f(self, rd, rn, rm, imm=0, cond=cond.AL, s=0, shifttype=0):
            self.write32(n
                        | cond << 28
                        | reg_operation(rd, rn, rm, imm, s, shifttype))
    return f


def define_data_proc_reg_shift_reg_func(name, table):
    n = ((0x1 << 4) | (table['op1'] & 0x1F) << 20 | (table['op2'] & 0x3) << 5)
    if 'result' in table and not table['result']:
        result = False
    else:
        result = True
    if name[-2:] == 'sr':
        if result:
            def f(self, rd, rn, rm, rs, cond=cond.AL, s=0, shifttype=0):
                self.write32(n
                            | cond << 28
                            | (s & 0x1) << 20
                            | (rn & 0xF) << 16
                            | (rd & 0xF) << 12
                            | (rs & 0xF) << 8
                            | (shifttype & 0x3) << 5
                            | (rm & 0xF))
        else:
            def f(self, rn, rm, rs, cond=cond.AL, s=0, shifttype=0):
                self.write32(n
                            | cond << 28
                            | (s & 0x1) << 20
                            | (rn & 0xF) << 16
                            | (rs & 0xF) << 8
                            | (shifttype & 0x3) << 5
                            | (rm & 0xF))
    else:
        def f(self, rd, rn, rm, cond=cond.AL, s=0):
            self.write32(n
                        | cond << 28
                        | (s & 0x1) << 20
                        | (rd & 0xF) << 12
                        | (rm & 0xF) << 8
                        | (rn & 0xF))
    return f


def define_supervisor_and_coproc_func(name, table):
    n = (0x3 << 26 | (table['op1'] & 0x3F) << 20 | (table['op'] & 0x1) << 4)

    def f(self, coproc, opc1, rt, crn, crm, opc2=0, cond=cond.AL):
        assert coproc & 0xE != 0xA
        self.write32(n
                    | cond << 28
                    | (opc1 & 0x7) << 21
                    | (crn & 0xF) << 16
                    | (rt & 0xF) << 12
                    | (coproc & 0xF) << 8
                    | (opc2 & 0x7) << 5
                    | (crm & 0xF))
    return f


def define_multiply_func(name, table):
    n = (table['op'] & 0xF) << 20 | 0x9 << 4
    if 'acc' in table and table['acc']:
        if 'update_flags' in table and table['update_flags']:
            def f(self, rd, rn, rm, ra, cond=cond.AL, s=0):
                self.write32(n
                            | cond << 28
                            | (s & 0x1) << 20
                            | (rd & 0xF) << 16
                            | (ra & 0xF) << 12
                            | (rm & 0xF) << 8
                            | (rn & 0xF))
        else:
            def f(self, rd, rn, rm, ra, cond=cond.AL):
                self.write32(n
                            | cond << 28
                            | (rd & 0xF) << 16
                            | (ra & 0xF) << 12
                            | (rm & 0xF) << 8
                            | (rn & 0xF))

    elif 'long' in table and table['long']:
        def f(self, rdlo, rdhi, rn, rm, cond=cond.AL):
            assert rdhi != rdlo
            self.write32(n
                    | cond << 28
                    | (rdhi & 0xF) << 16
                    | (rdlo & 0xF) << 12
                    | (rm & 0xF) << 8
                    | (rn & 0xF))
    else:
        def f(self, rd, rn, rm, cond=cond.AL, s=0):
            self.write32(n
                        | cond << 28
                        | (s & 0x1) << 20
                        | (rd & 0xF) << 16
                        | (rm & 0xF) << 8
                        | (rn & 0xF))

    return f


def define_block_data_func(name, table):
    n = (table['op'] & 0x3F) << 20

    def f(self, rn, regs, w=0, cond=cond.AL):
        # no R bit for now at bit 15
        instr = (n
                | cond << 28
                | 0x1 << 27
                | (w & 0x1) << 21
                | (rn & 0xF) << 16)
        instr = self._encode_reg_list(instr, regs)
        self.write32(instr)

    return f


def define_float_load_store_func(name, table):
    n = (0x3 << 26
        | (table['opcode'] & 0x1F) << 20
        | 0x5 << 0x9
        | 0x1 << 0x8)

    # The imm value for thins function has to be a multiple of 4,
    # the value actually encoded is imm / 4
    def f(self, dd, rn, imm=0, cond=cond.AL):
        assert imm % 4 == 0
        imm = imm / 4
        u, imm = self._encode_imm(imm)
        instr = (n
                | (cond & 0xF) << 28
                | (u & 0x1) << 23
                | (rn & 0xF) << 16
                | (dd & 0xF) << 12
                | (imm & 0xFF))
        self.write32(instr)
    return f


def define_float64_data_proc_instructions_func(name, table):
    n = (0xE << 24
        | 0x5 << 9
        | 0x1 << 8  # 64 bit flag
        | (table['opc3'] & 0x3) << 6)

    if 'opc1' in table:
        n |= (table['opc1'] & 0xF) << 20
    if 'opc2' in table:
        n |= (table['opc2'] & 0xF) << 16

    if 'result' in table and not table['result']:
        def f(self, dd, dm, cond=cond.AL):
            instr = (n
                    | (cond & 0xF) << 28
                    | 0x4 << 16
                    | (dd & 0xF) << 12
                    | (dm & 0xF))
            self.write32(instr)
    elif 'base' in table and not table['base']:
        def f(self, dd, dm, cond=cond.AL):
            instr = (n
                    | (cond & 0xF) << 28
                    | (dd & 0xF) << 12
                    | (dm & 0xF))
            self.write32(instr)
    else:
        def f(self, dd, dn, dm, cond=cond.AL):
            instr = (n
                    | (cond & 0xF) << 28
                    | (dn & 0xF) << 16
                    | (dd & 0xF) << 12
                    | (dm & 0xF))
            self.write32(instr)
    return f

def define_simd_instructions_3regs_func(name, table):
    n = 0
    if 'A' in table:
        n |= (table['A'] & 0xF) << 8
    if 'B' in table:
        n |= (table['B'] & 0x1) << 4
    if 'U' in table:
        n |= (table['U'] & 0x1) << 24
    if 'C' in table:
        n |= (table['C'] & 0x3) << 20
    if name == 'VADD_i64' or name == 'VSUB_i64':
        size = 0x3 << 20
        n |= size
    def f(self, dd, dn, dm):
        base = 0x79
        N = (dn >> 4) & 0x1
        M = (dm >> 4) & 0x1
        D = (dd >> 4) & 0x1
        Q = 0 # we want doubleword regs
        instr = (n
                | base << 25
                | D << 22
                | (dn & 0xf) << 16
                | (dd & 0xf) << 12
                | N << 7
                | Q << 6
                | M << 5
                | (dm & 0xf))
        self.write32(instr)
    return f


def imm_operation(rt, rn, imm):
    return ((rn & 0xFF) << 16
    | (rt & 0xFF) << 12
    | (imm & 0xFFF))


def reg_operation(rt, rn, rm, imm, s, shifttype):
    return ((s & 0x1) << 20
            | (rn & 0xF) << 16
            | (rt & 0xF) << 12
            | (imm & 0x1F) << 7
            | (shifttype & 0x3) << 5
            | (rm & 0xF))


def define_instruction(builder, key, val, target):
    f = builder(key, val)
    f.__name__ = key
    setattr(target, key, f)


def define_instructions(target):
    inss = [k for k in instructions.__dict__.keys() if not k.startswith('__')]
    for name in inss:
        if name == 'branch':
            continue
        try:
            func = globals()['define_%s_func' % name]
        except KeyError:
            print 'No instr generator for %s instructions' % name
            continue
        for key, value in getattr(instructions, name).iteritems():
            define_instruction(func, key, value, target)
