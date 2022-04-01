import random
import py
from rpython.jit.backend.arm.registers import *
from rpython.jit.backend.arm.locations import *
from rpython.jit.backend.arm.regalloc import ARMFrameManager
from rpython.jit.backend.arm.jump import remap_frame_layout, remap_frame_layout_mixed
from rpython.jit.metainterp.history import INT

fm = ARMFrameManager(0)
frame_pos = fm.frame_pos

class MockAssembler:
    def __init__(self):
        self.ops = []

    def regalloc_mov(self, from_loc, to_loc):
        self.ops.append(('mov', from_loc, to_loc))

    def regalloc_push(self, loc):
        self.ops.append(('push', loc))

    def regalloc_pop(self, loc):
        self.ops.append(('pop', loc))

    def got(self, expected):
        print '------------------------ comparing ---------------------------'
        for op1, op2 in zip(self.ops, expected):
            print '%-38s| %-38s' % (op1, op2)
            if op1 == op2:
                continue
            assert len(op1) == len(op2)
            for x, y in zip(op1, op2):
                if isinstance(x, StackLoc) and isinstance(y, MODRM):
                    assert x.byte == y.byte
                    assert x.extradata == y.extradata
                else:
                    assert x == y
        assert len(self.ops) == len(expected)
        return True

class TestJump(object):
    def setup_method(self, m):
        self.assembler = MockAssembler()

    def test_trivial(self):
        remap_frame_layout(self.assembler, [], [], '?')
        assert self.assembler.ops == []
        remap_frame_layout(self.assembler, [r0, r1, r3, r5, r6, r7, r9],
                                      [r0, r1, r3, r5, r6, r7, r9], '?')
        assert self.assembler.ops == []
        s8 = frame_pos(1, INT)
        s12 = frame_pos(31, INT)
        s20 = frame_pos(6, INT)
        remap_frame_layout(self.assembler, [r0, r1, s20, s8, r3, r5, r6, s12, r7, r9],
                                      [r0, r1, s20, s8, r3, r5, r6, s12, r7, r9],
                                      '?')
        assert self.assembler.ops == []

    def test_simple_registers(self):
        remap_frame_layout(self.assembler, [r0, r1, r2], [r3, r4, r5], '?')
        assert self.assembler.ops == [('mov', r0, r3),
                                 ('mov', r1, r4),
                                 ('mov', r2, r5)]

    def test_simple_framelocs(self):
        s8 = frame_pos(0, INT)
        s12 = frame_pos(13, INT)
        s20 = frame_pos(20, INT)
        s24 = frame_pos(221, INT)
        remap_frame_layout(self.assembler, [s8, r7, s12], [s20, s24, r9], ip)
        assert self.assembler.ops == [('mov', s8, ip),
                                 ('mov', ip, s20),
                                 ('mov', r7, s24),
                                 ('mov', s12, r9)]

    def test_reordering(self):
        s8 = frame_pos(8, INT)
        s12 = frame_pos(12, INT)
        s20 = frame_pos(19, INT)
        s24 = frame_pos(1, INT)
        remap_frame_layout(self.assembler, [r7, s8, s20, r4],
                                      [s8, r4, r7, r2], '?')
        assert self.assembler.got([('mov', r4, r2),
                              ('mov', s8, r4),
                              ('mov', r7, s8),
                              ('mov', s20, r7)])

    def test_cycle(self):
        s8 = frame_pos(8, INT)
        s12 = frame_pos(12, INT)
        s20 = frame_pos(19, INT)
        s24 = frame_pos(1, INT)
        remap_frame_layout(self.assembler, [r4, s8, s20, r7],
                                      [s8, r7, r4, s20], '?')
        assert self.assembler.got([('push', s8),
                              ('mov', r4, s8),
                              ('mov', s20, r4),
                              ('mov', r7, s20),
                              ('pop', r7)])

    def test_cycle_2(self):
        s8 = frame_pos(8, INT)
        s12 = frame_pos(12, INT)
        s20 = frame_pos(19, INT)
        s24 = frame_pos(1, INT)
        s2 = frame_pos(2, INT)
        s3 = frame_pos(3, INT)
        remap_frame_layout(self.assembler,
                           [r0, s8, r1, s20, r0, s20, s24, r3, s2, s3],
                           [s8, s20, r1, r0, r4, s24, r5, s12, s3, s2],
                           ip)
        assert self.assembler.got([('mov', r0, r4),
                              ('mov', s24, r5),
                              ('mov', r3, s12),
                              ('mov', s20, ip),
                              ('mov', ip, s24),
                              ('push', s8),
                              ('mov', r0, s8),
                              ('mov', s20, r0),
                              ('pop', s20),
                              ('push', s3),
                              ('mov', s2, ip),
                              ('mov', ip, s3),
                              ('pop', s2)])

    def test_constants(self):
        c3 = ImmLocation(3)
        remap_frame_layout(self.assembler, [c3], [r0], '?')
        assert self.assembler.ops == [('mov', c3, r0)]

    def test_constants2(self):
        c3 = ImmLocation(3)
        s12 = frame_pos(12, INT)
        remap_frame_layout(self.assembler, [c3], [s12], '?')
        assert self.assembler.ops == [('mov', c3, s12)]

    def test_constants_and_cycle(self):
        c3 = ImmLocation(3)
        s12 = frame_pos(13, INT)
        remap_frame_layout(self.assembler, [r5, c3,  s12],
                                      [s12, r0, r5], r1)
        assert self.assembler.ops == [('mov', c3, r0),
                                 ('push', s12),
                                 ('mov', r5, s12),
                                 ('pop', r5)]
    def test_mixed(self):
        s23 = frame_pos(2, FLOAT)     # non-conflicting locations
        s4  = frame_pos(4, INT)
        remap_frame_layout_mixed(self.assembler, [r1], [s4], 'tmp',
                                            [s23], [d5], 'vfptmp')
        assert self.assembler.ops == [('mov', r1, s4),
                                 ('mov', s23, d5)]
    def test_mixed2(self):
        s23 = frame_pos(2, FLOAT)  # gets stored in pos 2 and 3, with value==3
        s3  = frame_pos(3, INT)
        remap_frame_layout_mixed(self.assembler, [r1], [s3], 'tmp',
                                            [s23], [d5], 'vfptmp')
        assert self.assembler.ops == [('push', s23),
                                 ('mov', r1, s3),
                                 ('pop', d5)]
    def test_mixed3(self):
        s23 = frame_pos(2, FLOAT)
        s2  = frame_pos(2, INT)
        remap_frame_layout_mixed(self.assembler, [r1], [s2], 'tmp',
                                            [s23], [d5], 'vfptmp')
        assert self.assembler.ops == [
                                 ('push', s23),
                                 ('mov', r1, s2),
                                 ('pop', d5)]
    def test_mixed4(self):
        s23 = frame_pos(2, FLOAT)
        s4  = frame_pos(4, INT)
        s45 = frame_pos(4, FLOAT)
        s1  = frame_pos(1, INT)
        remap_frame_layout_mixed(self.assembler, [s4], [s1], r3,
                                            [s23], [s45], d3)
        assert self.assembler.ops == [('mov', s4, r3),
                                 ('mov', r3, s1),
                                 ('mov', s23, d3),
                                 ('mov', d3, s45)]
    def test_mixed5(self):
        s2  = frame_pos(2, INT)
        s23 = frame_pos(2, FLOAT)
        s4  = frame_pos(4, INT)
        s45 = frame_pos(4, FLOAT)
        remap_frame_layout_mixed(self.assembler, [s4], [s2], r3,
                                            [s23], [s45], d3)
        assert self.assembler.ops == [('push', s23),
                                 ('mov', s4, r3),
                                 ('mov', r3, s2),
                                 ('pop', s45)]
    def test_mixed6(self):
        s3  = frame_pos(3, INT)
        s23 = frame_pos(2, FLOAT)
        s4  = frame_pos(4, INT)
        s45 = frame_pos(4, FLOAT)
        remap_frame_layout_mixed(self.assembler, [s4], [s3], r3,
                                     [s23], [s45], d3)
        assert self.assembler.ops == [('push', s23),
                                     ('mov', s4, r3),
                                     ('mov', r3, s3),
                                     ('pop', s45)]

def test_random_mixed():
    assembler = MockAssembler()
    registers1 = all_regs
    registers2 = all_vfp_regs
    VFPWORDS = 2
    #
    def pick1():
        n = random.randrange(-3, 10)
        if n < 0:
            return registers1[n]
        else:
            return frame_pos(n, INT)
    def pick2():
        n = random.randrange(-3 , 10 // VFPWORDS)
        if n < 0:
            return registers2[n]
        else:
            return frame_pos(n*VFPWORDS, FLOAT)
    #
    def pick1c():
        n = random.randrange(-2000, 500)
        if n >= 0:
            return imm(n)
        else:
            return pick1()
    #
    def pick_dst(fn, count, seen):
        result = []
        while len(result) < count:
            x = fn()
            keys = [x.as_key()]
            if x.is_stack() and x.width > WORD:
                keys.append(keys[0] + 1)
            for key in keys:
                if key in seen:
                    break
            else:
                for key in keys:
                    seen[key] = True
                result.append(x)
        return result
    #
    def get_state(locations):
        regs1 = {}
        regs2 = {}
        stack = {}
        for i, loc in enumerate(locations):
            if loc.is_vfp_reg():
                if loc.width > WORD:
                    newvalue = ('value-vfp-%d' % i,
                                'value-vfp-hiword-%d' % i)
                else:
                    newvalue = 'value-vfp-%d' % i
                regs2[loc.value] = newvalue
            elif loc.is_core_reg():
                regs1[loc.value] = 'value-int-%d' % i
            elif loc.is_stack():
                stack[loc.position] = 'value-width%d-%d' % (loc.width, i)
                if loc.width > WORD:
                    stack[loc.position+1] = 'value-hiword-%d' % i
            else:
                assert loc.is_imm() or loc.is_imm_float()
        return regs1, regs2, stack
    #
    for i in range(500):
        seen = {}
        src_locations2 = [pick2() for i in range(4)]
        dst_locations2 = pick_dst(pick2, 4, seen)
        src_locations1 = [pick1c() for i in range(5)]
        dst_locations1 = pick_dst(pick1, 5, seen)
        assembler = MockAssembler()
        remap_frame_layout_mixed(assembler,
                                 src_locations1, dst_locations1, ip,
                                 src_locations2, dst_locations2, vfp_ip)
        #
        regs1, regs2, stack = get_state(src_locations1 +
                                        src_locations2)
        #
        def read(loc, expected_width=None):
            if expected_width is not None:
                assert loc.width == expected_width*WORD
            if loc.is_vfp_reg():
                return regs2[loc.value]
            elif loc.is_core_reg():
                return regs1[loc.value]
            elif loc.is_stack():
                got = stack[loc.position]
                if loc.width > WORD:
                    got = (got, stack[loc.position+1])
                return got
            if loc.is_imm() or loc.is_imm_float():
                return 'const-%d' % loc.value
            assert 0, loc
        #
        def write(loc, newvalue):
            if loc.is_vfp_reg():
                regs2[loc.value] = newvalue
            elif loc.is_core_reg():
                regs1[loc.value] = newvalue
            elif loc.is_stack():
                if loc.width > WORD:
                    newval1, newval2 = newvalue
                    stack[loc.position] = newval1
                    stack[loc.position+1] = newval2
                else:
                    stack[loc.position] = newvalue
            else:
                assert 0, loc
        #
        src_values1 = [read(loc, 1) for loc in src_locations1]
        src_values2 = [read(loc, 2)    for loc in src_locations2]
        #
        extrapushes = []
        for op in assembler.ops:
            if op[0] == 'mov':
                src, dst = op[1:]
                assert src.is_core_reg() or src.is_vfp_reg() or src.is_stack() or src.is_imm_float() or src.is_imm()
                assert dst.is_core_reg() or dst.is_vfp_reg() or dst.is_stack()
                assert not (src.is_stack() and dst.is_stack())
                write(dst, read(src))
            elif op[0] == 'push':
                src, = op[1:]
                assert src.is_core_reg() or src.is_vfp_reg() or src.is_stack()
                extrapushes.append(read(src))
            elif op[0] == 'pop':
                dst, = op[1:]
                assert dst.is_core_reg() or dst.is_vfp_reg() or dst.is_stack()
                write(dst, extrapushes.pop())
            else:
                assert 0, "unknown op: %r" % (op,)
        assert not extrapushes
        #
        for i, loc in enumerate(dst_locations1):
            assert read(loc, 1) == src_values1[i]
        for i, loc in enumerate(dst_locations2):
            assert read(loc, 2) == src_values2[i]
