import random
from rpython.jit.backend.x86.regloc import *
from rpython.jit.backend.x86.regalloc import X86FrameManager
from rpython.jit.backend.x86.jump import remap_frame_layout
from rpython.jit.backend.x86.jump import remap_frame_layout_mixed
from rpython.jit.metainterp.history import INT

fm = X86FrameManager(0)
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

    def regalloc_immedmem2mem(self, from_loc, to_loc):
        assert isinstance(from_loc, ConstFloatLoc)
        assert isinstance(to_loc,   FrameLoc)
        self.ops.append(('immedmem2mem', from_loc, to_loc))

    class mc:
        @staticmethod
        def forget_scratch_register():
            pass

    def got(self, expected):
        print '------------------------ comparing ---------------------------'
        for op1, op2 in zip(self.ops, expected):
            print '%-38s| %-38s' % (op1, op2)
            if op1 == op2:
                continue
            assert len(op1) == len(op2)
            for x, y in zip(op1, op2):
                if isinstance(x, FrameLoc) and isinstance(y, MODRM):
                    assert x.byte == y.byte
                    assert x.extradata == y.extradata
                else:
                    assert x == y
        assert len(self.ops) == len(expected)
        return True


def test_trivial():
    assembler = MockAssembler()
    remap_frame_layout(assembler, [], [], '?')
    assert assembler.ops == []
    remap_frame_layout(assembler, [eax, ebx, ecx, edx, esi, edi],
                                  [eax, ebx, ecx, edx, esi, edi], '?')
    assert assembler.ops == []
    s8 = frame_pos(1, INT)
    s12 = frame_pos(31, INT)
    s20 = frame_pos(6, INT)
    remap_frame_layout(assembler, [eax, ebx, ecx, s20, s8, edx, s12, esi, edi],
                                  [eax, ebx, ecx, s20, s8, edx, s12, esi, edi],
                                  '?')
    assert assembler.ops == []

def test_simple_registers():
    assembler = MockAssembler()
    remap_frame_layout(assembler, [eax, ebx, ecx], [edx, esi, edi], '?')
    assert assembler.ops == [('mov', eax, edx),
                             ('mov', ebx, esi),
                             ('mov', ecx, edi)]

def test_simple_framelocs():
    assembler = MockAssembler()
    s8 = frame_pos(0, INT)
    s12 = frame_pos(13, INT)
    s20 = frame_pos(20, INT)
    s24 = frame_pos(221, INT)
    remap_frame_layout(assembler, [s8, eax, s12], [s20, s24, edi], edx)
    assert assembler.ops == [('mov', s8, edx),
                             ('mov', edx, s20),
                             ('mov', eax, s24),
                             ('mov', s12, edi)]

def test_no_tmp_reg():
    assembler = MockAssembler()
    s8 = frame_pos(0, INT)
    s12 = frame_pos(13, INT)
    s20 = frame_pos(20, INT)
    s24 = frame_pos(221, INT)
    remap_frame_layout(assembler, [s8, eax, s12], [s20, s24, edi], None)
    assert assembler.ops == [('push', s8),
                             ('pop', s20),
                             ('mov', eax, s24),
                             ('mov', s12, edi)]

def test_reordering():
    assembler = MockAssembler()
    s8 = frame_pos(8, INT)
    s12 = frame_pos(12, INT)
    s20 = frame_pos(19, INT)
    s24 = frame_pos(1, INT)
    remap_frame_layout(assembler, [eax, s8, s20, ebx],
                                  [s8, ebx, eax, edi], '?')
    assert assembler.got([('mov', ebx, edi),
                          ('mov', s8, ebx),
                          ('mov', eax, s8),
                          ('mov', s20, eax)])

def test_cycle():
    assembler = MockAssembler()
    s8 = frame_pos(8, INT)
    s12 = frame_pos(12, INT)
    s20 = frame_pos(19, INT)
    s24 = frame_pos(1, INT)
    remap_frame_layout(assembler, [eax, s8, s20, ebx],
                                  [s8, ebx, eax, s20], '?')
    assert assembler.got([('push', s8),
                          ('mov', eax, s8),
                          ('mov', s20, eax),
                          ('mov', ebx, s20),
                          ('pop', ebx)])

def test_cycle_2():
    assembler = MockAssembler()
    s8 = frame_pos(8, INT)
    s12 = frame_pos(12, INT)
    s20 = frame_pos(19, INT)
    s24 = frame_pos(1, INT)
    s2 = frame_pos(2, INT)
    s3 = frame_pos(3, INT)
    remap_frame_layout(assembler,
                       [eax, s8, edi, s20, eax, s20, s24, esi, s2, s3],
                       [s8, s20, edi, eax, edx, s24, ebx, s12, s3, s2],
                       ecx)
    assert assembler.got([('mov', eax, edx),
                          ('mov', s24, ebx),
                          ('mov', esi, s12),
                          ('mov', s20, ecx),
                          ('mov', ecx, s24),
                          ('push', s8),
                          ('mov', eax, s8),
                          ('mov', s20, eax),
                          ('pop', s20),
                          ('push', s3),
                          ('mov', s2, ecx),
                          ('mov', ecx, s3),
                          ('pop', s2)])

def test_constants():
    assembler = MockAssembler()
    c3 = imm(3)
    remap_frame_layout(assembler, [c3], [eax], '?')
    assert assembler.ops == [('mov', c3, eax)]
    assembler = MockAssembler()
    s12 = frame_pos(12, INT)
    remap_frame_layout(assembler, [c3], [s12], '?')
    assert assembler.ops == [('mov', c3, s12)]

def test_constants_and_cycle():
    assembler = MockAssembler()
    c3 = imm(3)
    s12 = frame_pos(13, INT)
    remap_frame_layout(assembler, [ebx, c3,  s12],
                                  [s12, eax, ebx], edi)
    assert assembler.ops == [('mov', c3, eax),
                             ('push', s12),
                             ('mov', ebx, s12),
                             ('pop', ebx)]

def test_mixed():
    assembler = MockAssembler()
    s23 = frame_pos(2, FLOAT)     # non-conflicting locations
    s4  = frame_pos(4, INT)
    remap_frame_layout_mixed(assembler, [ebx], [s4], 'tmp',
                                        [s23], [xmm5], 'xmmtmp')
    assert assembler.ops == [('mov', ebx, s4),
                             ('mov', s23, xmm5)]
    #
    if IS_X86_32:
        assembler = MockAssembler()
        s23 = frame_pos(2, FLOAT)  # gets stored in pos 2 and 3, with value==3
        s3  = frame_pos(3, INT)
        remap_frame_layout_mixed(assembler, [ebx], [s3], 'tmp',
                                            [s23], [xmm5], 'xmmtmp')
        assert assembler.ops == [('push', s23),
                                 ('mov', ebx, s3),
                                 ('pop', xmm5)]
    #
    assembler = MockAssembler()
    s23 = frame_pos(2, FLOAT)
    s2  = frame_pos(2, INT)
    remap_frame_layout_mixed(assembler, [ebx], [s2], 'tmp',
                                        [s23], [xmm5], 'xmmtmp')
    assert assembler.ops == [('push', s23),
                             ('mov', ebx, s2),
                             ('pop', xmm5)]
    #
    assembler = MockAssembler()
    s4  = frame_pos(4, INT)
    s45 = frame_pos(4, FLOAT)
    s1  = frame_pos(1, INT)
    remap_frame_layout_mixed(assembler, [s4], [s1], edi,
                                        [s23], [s45], xmm3)
    assert assembler.ops == [('mov', s4, edi),
                             ('mov', edi, s1),
                             ('mov', s23, xmm3),
                             ('mov', xmm3, s45)]
    #
    assembler = MockAssembler()
    s4  = frame_pos(4, INT)
    s45 = frame_pos(4, FLOAT)
    remap_frame_layout_mixed(assembler, [s4], [s2], edi,
                                        [s23], [s45], xmm3)
    assert assembler.ops == [('push', s23),
                             ('mov', s4, edi),
                             ('mov', edi, s2),
                             ('pop', s45)]
    #
    if IS_X86_32:
        assembler = MockAssembler()
        remap_frame_layout_mixed(assembler, [s4], [s3], edi,
                                 [s23], [s45], xmm3)
        assert assembler.ops == [('push', s23),
                                 ('mov', s4, edi),
                                 ('mov', edi, s3),
                                 ('pop', s45)]

def test_random_mixed():
    assembler = MockAssembler()
    registers1 = [eax, ebx, ecx]
    registers2 = [xmm0, xmm1, xmm2]
    if IS_X86_32:
        XMMWORDS = 2
    elif IS_X86_64:
        XMMWORDS = 1
    #
    def pick1():
        n = random.randrange(-3, 10)
        if n < 0:
            return registers1[n]
        else:
            return frame_pos(n, INT)
    def pick2():
        n = random.randrange(-3 , 10 // XMMWORDS)
        if n < 0:
            return registers2[n]
        else:
            return frame_pos(n * XMMWORDS, FLOAT)
    #
    def pick1c():
        n = random.randrange(-2000, 500)
        if n >= 0:
            return imm(n)
        else:
            return pick1()
    #
    def pick2c():
        n = random.randrange(-2000, 500)
        if n >= 0:
            return ConstFloatLoc(n)    # n is the address, not really used here
        else:
            return pick2()
    #
    def pick_dst(fn, count, seen):
        result = []
        while len(result) < count:
            x = fn()
            keys = [x._getregkey()]
            if isinstance(x, FrameLoc) and x.get_width() > WORD:
                keys.append(keys[0] + WORD)
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
            if isinstance(loc, RegLoc):
                if loc.is_xmm:
                    if loc.get_width() > WORD:
                        newvalue = ('value-xmm-%d' % i,
                                    'value-xmm-hiword-%d' % i)
                    else:
                        newvalue = 'value-xmm-%d' % i
                    regs2[loc.value] = newvalue
                else:
                    regs1[loc.value] = 'value-int-%d' % i
            elif isinstance(loc, FrameLoc):
                stack[loc.value] = 'value-width%d-%d' % (loc.get_width(), i)
                if loc.get_width() > WORD:
                    stack[loc.value+WORD] = 'value-hiword-%d' % i
            else:
                assert isinstance(loc, (ImmedLoc, ConstFloatLoc))
        return regs1, regs2, stack
    #
    for i in range(500):
        seen = {}
        src_locations2 = [pick2c() for i in range(4)]
        dst_locations2 = pick_dst(pick2, 4, seen)
        src_locations1 = [pick1c() for i in range(5)]
        dst_locations1 = pick_dst(pick1, 5, seen)
        assembler = MockAssembler()
        remap_frame_layout_mixed(assembler,
                                 src_locations1, dst_locations1, edi,
                                 src_locations2, dst_locations2, xmm7)
        #
        regs1, regs2, stack = get_state(src_locations1 +
                                        src_locations2)
        #
        def read(loc, expected_width=None):
            if expected_width is not None:
                assert loc.get_width() == expected_width
            if isinstance(loc, RegLoc):
                if loc.is_xmm:
                    return regs2[loc.value]
                else:
                    return regs1[loc.value]
            if isinstance(loc, FrameLoc):
                got = stack[loc.value]
                if loc.get_width() > WORD:
                    got = (got, stack[loc.value+WORD])
                return got
            if isinstance(loc, ImmedLoc):
                return 'const-%d' % loc.value
            if isinstance(loc, ConstFloatLoc):
                got = 'constfloat-@%d' % loc.value
                if loc.get_width() > WORD:
                    got = (got, 'constfloat-next-@%d' % loc.value)
                return got
            assert 0, loc
        #
        def write(loc, newvalue):
            assert (type(newvalue) is tuple) == (loc.get_width() > WORD)
            if isinstance(loc, RegLoc):
                if loc.is_xmm:
                    regs2[loc.value] = newvalue
                else:
                    regs1[loc.value] = newvalue
            elif isinstance(loc, FrameLoc):
                if loc.get_width() > WORD:
                    newval1, newval2 = newvalue
                    stack[loc.value] = newval1
                    stack[loc.value+WORD] = newval2
                else:
                    stack[loc.value] = newvalue
            else:
                assert 0, loc
        #
        src_values1 = [read(loc, WORD) for loc in src_locations1]
        src_values2 = [read(loc, 8)    for loc in src_locations2]
        #
        extrapushes = []
        for op in assembler.ops:
            if op[0] == 'mov':
                src, dst = op[1:]
                if isinstance(src, ConstFloatLoc):
                    assert isinstance(dst, RegLoc)
                    assert dst.is_xmm
                else:
                    assert isinstance(src, (RegLoc, FrameLoc, ImmedLoc))
                    assert isinstance(dst, (RegLoc, FrameLoc))
                    assert not (isinstance(src, FrameLoc) and
                                isinstance(dst, FrameLoc))
                write(dst, read(src))
            elif op[0] == 'push':
                src, = op[1:]
                assert isinstance(src, (RegLoc, FrameLoc))
                extrapushes.append(read(src))
            elif op[0] == 'pop':
                dst, = op[1:]
                assert isinstance(dst, (RegLoc, FrameLoc))
                write(dst, extrapushes.pop())
            elif op[0] == 'immedmem2mem':
                src, dst = op[1:]
                assert isinstance(src, ConstFloatLoc)
                assert isinstance(dst, FrameLoc)
                write(dst, read(src, 8))
            else:
                assert 0, "unknown op: %r" % (op,)
        assert not extrapushes
        #
        for i, loc in enumerate(dst_locations1):
            assert read(loc, WORD) == src_values1[i]
        for i, loc in enumerate(dst_locations2):
            assert read(loc, 8) == src_values2[i]


def test_overflow_bug():
    CASE = [
        (144, 248),   # \ cycle
        (248, 144),   # /
        (488, 416),   # \ two usages of -488
        (488, 480),   # /
        (488, 488),   # - one self-application of -488
        ]
    class FakeAssembler:
        def regalloc_mov(self, src, dst):
            print "mov", src, dst
        def regalloc_push(self, x):
            print "push", x
        def regalloc_pop(self, x):
            print "pop", x
        def regalloc_immedmem2mem(self, x, y):
            print "?????????????????????????"
        class mc:
            @staticmethod
            def forget_scratch_register():
                pass
    def main():
        srclocs = [FrameLoc(9999, x, 'i') for x,y in CASE]
        dstlocs = [FrameLoc(9999, y, 'i') for x,y in CASE]
        remap_frame_layout(FakeAssembler(), srclocs, dstlocs, eax)
    # it works when run directly
    main()
    # but it used to crash when translated,
    # because of a -sys.maxint-2 overflowing to sys.maxint
    from rpython.rtyper.test.test_llinterp import interpret
    interpret(main, [])
