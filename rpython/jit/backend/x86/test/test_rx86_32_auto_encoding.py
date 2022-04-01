import sys, os, random, struct
import py
from rpython.jit.backend.x86 import rx86
from rpython.rlib.rarithmetic import intmask
from rpython.tool.udir import udir

INPUTNAME = 'checkfile_%s.s'
FILENAME = 'checkfile_%s.o'
BEGIN_TAG = '<<<rx86-test-begin>>>'
END_TAG =   '<<<rx86-test-end>>>'

class CodeCheckerMixin(object):
    def __init__(self, expected, accept_unnecessary_prefix):
        self.expected = expected
        self.accept_unnecessary_prefix = accept_unnecessary_prefix
        self.index = 0

    def begin(self, op):
        self.op = op
        self.instrindex = self.index

    def writechar(self, char):
        if char != self.expected[self.index:self.index+1]:
            if (char == self.accept_unnecessary_prefix
                and self.index == self.instrindex):
                return    # ignore the extra character '\x40'
            print self.op
            print "\x09from rx86.py:", hexdump(self.expected[self.instrindex:self.index] + char)+"..."
            print "\x09from 'as':   ", hexdump(self.expected[self.instrindex:self.index+15])+"..."
            raise Exception("Differs")
        self.index += 1

    def done(self):
        assert len(self.expected) == self.index

    def stack_frame_size_delta(self, delta):
        pass   # ignored

    def check_stack_size_at_ret(self):
        pass   # ignored

def hexdump(s):
    return ' '.join(["%02X" % ord(c) for c in s])

def reduce_to_32bit(s):
    if s[:2] != '%r':
        return s
    if s[2:].isdigit():
        return s + 'd'
    else:
        return '%e' + s[2:]

# ____________________________________________________________

COUNT1 = 15
suffixes = {0:'', 1:'b', 2:'w', 4:'l', 8:'q'}


class TestRx86_32(object):
    WORD = 4
    TESTDIR = 'rx86_32'
    X86_CodeBuilder = rx86.X86_32_CodeBuilder
    REGNAMES = ['%eax', '%ecx', '%edx', '%ebx', '%esp', '%ebp', '%esi', '%edi']
    REGNAMES8 = ['%al', '%cl', '%dl', '%bl', '%ah', '%ch', '%dh', '%bh']
    XMMREGNAMES = ['%%xmm%d' % i for i in range(16)]
    REGS = range(8)
    REGS8 = [i|rx86.BYTE_REG_FLAG for i in range(8)]
    NONSPECREGS = [rx86.R.eax, rx86.R.ecx, rx86.R.edx, rx86.R.ebx,
                   rx86.R.esi, rx86.R.edi]
    accept_unnecessary_prefix = None
    methname = '?'

    def reg_tests(self):
        return self.REGS

    def reg8_tests(self):
        return self.REGS8

    def xmm_reg_tests(self):
        return self.reg_tests()

    def stack_bp_tests(self, count=COUNT1):
        return ([0, 4, -4, 124, 128, -128, -132] +
                [random.randrange(-0x20000000, 0x20000000) * 4
                 for i in range(count)])

    def stack_sp_tests(self, count=COUNT1):
        return ([0, 4, 124, 128] +
                [random.randrange(0, 0x20000000) * 4
                 for i in range(count)])

    def memory_tests(self):
        return [(reg, ofs)
                    for reg in self.NONSPECREGS
                    for ofs in self.stack_bp_tests(5)
                ]

    def array_tests(self):
        return [(reg1, reg2, scaleshift, ofs)
                    for reg1 in self.NONSPECREGS
                    for reg2 in self.NONSPECREGS
                    for scaleshift in [0, 1, 2, 3]
                    for ofs in self.stack_bp_tests(1)
                ]

    def imm8_tests(self):
        v = ([-128,-1,0,1,127] +
             [random.randrange(-127, 127) for i in range(COUNT1)])
        return v

    def imm32_tests(self):
        v = ([-0x80000000, 0x7FFFFFFF, 128, 256, -129, -255] +
             [random.randrange(-32768,32768)<<16 |
                 random.randrange(0,65536) for i in range(COUNT1)] +
             [random.randrange(128, 256) for i in range(COUNT1)])
        return self.imm8_tests() + v

    def relative_tests(self):
        py.test.skip("explicit test required for %r" % (self.methname,))

    def get_all_tests(self):
        return {
            'r': self.reg_tests,
            'r8': self.reg8_tests,
            'x': self.xmm_reg_tests,
            'b': self.stack_bp_tests,
            's': self.stack_sp_tests,
            'm': self.memory_tests,
            'a': self.array_tests,
            'i': self.imm32_tests,
            'i8': self.imm8_tests,
            'j': self.imm32_tests,
            'l': self.relative_tests,
            }

    def assembler_operand_reg(self, regnum):
        return self.REGNAMES[regnum]

    def assembler_operand_reg8(self, regnum):
        assert regnum & rx86.BYTE_REG_FLAG
        return self.REGNAMES8[regnum &~ rx86.BYTE_REG_FLAG]

    def assembler_operand_xmm_reg(self, regnum):
        return self.XMMREGNAMES[regnum]

    def assembler_operand_stack_bp(self, position):
        return '%d(%s)' % (position, self.REGNAMES[5])

    def assembler_operand_stack_sp(self, position):
        return '%d(%s)' % (position, self.REGNAMES[4])

    def assembler_operand_memory(self, (reg1, offset)):
        if not offset: offset = ''
        return '%s(%s)' % (offset, self.REGNAMES[reg1])

    def assembler_operand_array(self, (reg1, reg2, scaleshift, offset)):
        if not offset: offset = ''
        return '%s(%s,%s,%d)' % (offset, self.REGNAMES[reg1],
                                 self.REGNAMES[reg2], 1<<scaleshift)

    def assembler_operand_imm(self, value):
        return '$%d' % value

    def assembler_operand_imm_addr(self, value):
        return '%d' % value

    def get_all_assembler_operands(self):
        return {
            'r': self.assembler_operand_reg,
            'r8': self.assembler_operand_reg8,
            'x': self.assembler_operand_xmm_reg,
            'b': self.assembler_operand_stack_bp,
            's': self.assembler_operand_stack_sp,
            'm': self.assembler_operand_memory,
            'a': self.assembler_operand_array,
            'i': self.assembler_operand_imm,
            'i8': self.assembler_operand_imm,
            'j': self.assembler_operand_imm_addr,
            }

    def run_test(self, methname, instrname, argmodes, args_lists,
                 instr_suffix=None):
        global labelcount
        labelcount = 0
        oplist = []
        testdir = udir.ensure(self.TESTDIR, dir=1)
        inputname = str(testdir.join(INPUTNAME % methname))
        filename  = str(testdir.join(FILENAME  % methname))
        g = open(inputname, 'w')
        g.write('\x09.string "%s"\n' % BEGIN_TAG)
        #
        if instrname == 'MOVDQ':
            if self.WORD == 8:
                instrname = 'MOVQ'
            else:
                instrname = 'MOVD'
            if argmodes == 'xb':
                py.test.skip('"as" uses an undocumented alternate encoding??')
            if argmodes == 'xx' and self.WORD != 8:
                instrname = 'MOVQ'
        #
        for args in args_lists:
            suffix = ""
            if (argmodes and not self.is_xmm_insn
                         and not instrname.startswith('FSTP')
                         and not instrname.startswith('FLD')):
                suffix = suffixes[self.WORD]
            # Special case: On 64-bit CPUs, rx86 assumes 64-bit integer
            # operands when converting to/from floating point, so we need to
            # indicate that with a suffix
            if (self.WORD == 8) and (instrname.startswith('CVT') and
                                     'SI' in instrname):
                suffix = suffixes[self.WORD]

            if instr_suffix is not None:
                suffix = instr_suffix    # overwrite

            following = ""
            if False:   # instr.indirect:
                suffix = ""
                if args[-1][0] == i386.REL32: #in (i386.REL8,i386.REL32):
                    labelcount += 1
                    following = "\nL%d:" % labelcount
                elif args[-1][0] in (i386.IMM8,i386.IMM32):
                    args = list(args)
                    args[-1] = ("%d", args[-1][1])  # no '$' sign
                else:
                    suffix += " *"
                k = -1
            else:
                k = len(args)
            #for m, extra in args[:k]:
            #    assert m != i386.REL32  #not in (i386.REL8,i386.REL32)
            assembler_operand = self.get_all_assembler_operands()
            ops = []
            for mode, v in zip(argmodes, args):
                ops.append(assembler_operand[mode](v))
            ops.reverse()
            #
            if (instrname.lower() == 'mov' and suffix == 'q' and
                ops[0].startswith('$') and 0 <= int(ops[0][1:]) <= 4294967295
                and ops[1].startswith('%r')):
                # movq $xxx, %rax => movl $xxx, %eax
                suffix = 'l'
                ops[1] = reduce_to_32bit(ops[1])
            #
            op = '\t%s%s %s%s' % (instrname.lower(), suffix,
                                  ', '.join(ops), following)
            g.write('%s\n' % op)
            oplist.append(op)
        g.write('\t.string "%s"\n' % END_TAG)
        g.close()
        f, g = os.popen4('as --%d "%s" -o "%s"' %
                         (self.WORD*8, inputname, filename), 'r')
        f.close()
        got = g.read()
        g.close()
        error = [line for line in got.splitlines() if 'error' in line.lower()]
        if error:
            if (sys.maxint <= 2**32 and
                    'no compiled in support for x86_64' in error[0]):
                py.test.skip(error)
            raise Exception("Assembler got an error: %r" % error[0])
        error = [line for line in got.splitlines()
                 if 'warning' in line.lower()]
        if error:
            raise Exception("Assembler got a warning: %r" % error[0])
        try:
            f = open(filename, 'rb')
        except IOError:
            raise Exception("Assembler did not produce output?")
        data = f.read()
        f.close()
        i = data.find(BEGIN_TAG)
        assert i>=0
        j = data.find(END_TAG, i)
        assert j>=0
        as_code = data[i+len(BEGIN_TAG)+1:j]
        return oplist, as_code

    def make_all_tests(self, methname, modes, args=[]):
        if modes:
            tests = self.get_all_tests()
            m = modes[0]
            if m == 'p' and self.WORD == 4:
                return []
            lst = tests[m]()
            random.shuffle(lst)
            if methname == 'PSRAD_xi' and m == 'i':
                lst = [x for x in lst if 0 <= x <= 31]
            result = []
            for v in lst:
                result += self.make_all_tests(methname, modes[1:], args+[v])
            return result
        else:
            # special cases
            if methname in ('ADD_ri', 'AND_ri', 'CMP_ri', 'OR_ri',
                            'SUB_ri', 'XOR_ri', 'SBB_ri'):
                if args[0] == rx86.R.eax:
                    return []  # ADD EAX, constant: there is a special encoding
            if methname in ('CMP8_ri',):
                if args[0] == rx86.R.al:
                    return []   # CMP AL, constant: there is a special encoding
            if methname == 'XCHG_rr' and rx86.R.eax in args:
                return [] # special encoding
            if methname == 'MOV_rj' and args[0] == rx86.R.eax:
                return []   # MOV EAX, [immediate]: there is a special encoding
            if methname == 'MOV_jr' and args[1] == rx86.R.eax:
                return []   # MOV [immediate], EAX: there is a special encoding
            if methname == 'MOV8_rj' and args[0] == rx86.R.al:
                return []   # MOV AL, [immediate]: there is a special encoding
            if methname == 'MOV8_jr' and args[1] == rx86.R.al:
                return []   # MOV [immediate], AL: there is a special encoding
            if methname == 'TEST_ri' and args[0] == rx86.R.eax:
                return []  # TEST EAX, constant: there is a special encoding

            return [args]

    def get_code_checker_class(self):
        class X86_CodeBuilder(CodeCheckerMixin, self.X86_CodeBuilder):
            pass
        return X86_CodeBuilder

    def should_skip_instruction(self, instrname, argmodes):
        is_artificial_instruction = (argmodes != '' and argmodes[-1].isdigit())
        is_artificial_instruction |= (instrname[-1].isdigit() and
                                      instrname[-1] != '8')
        return (
                is_artificial_instruction or
                # XXX: Can't tests shifts automatically at the moment
                (instrname[:3] in ('SHL', 'SAR', 'SHR')) or
                # CALL_j is actually relative, so tricky to test
                (instrname == 'CALL' and argmodes == 'j') or
                # SET_ir must be tested manually
                (instrname == 'SET' and argmodes == 'ir') or
                # MULTIBYTE_NOPs can't easily be tested the same way
                (instrname == 'MULTIBYTE')
        )

    def should_skip_instruction_bit32(self, instrname, argmodes):
        if self.WORD != 8:
            # those are tested in the 64 bit test case
            return (
                # the test suite uses 64 bit registers instead of 32 bit...
                (instrname == 'PEXTRQ') or
                (instrname == 'PINSRQ')
            )

        return False


    def complete_test(self, methname):
        if '_' in methname:
            instrname, argmodes = methname.split('_')
        else:
            instrname, argmodes = methname, ''

        if self.should_skip_instruction(instrname, argmodes) or \
           self.should_skip_instruction_bit32(instrname, argmodes):
            print "Skipping %s" % methname
            return

        # XXX: ugly way to deal with the differences between 32 and 64 bit
        if not hasattr(self.X86_CodeBuilder, methname):
            return

        # XXX: hack hack hack
        if methname == 'WORD':
            return

        if instrname.endswith('8'):
            instrname = instrname[:-1]
            if instrname == 'MOVSX' or instrname == 'MOVZX':
                instr_suffix = 'b' + suffixes[self.WORD]
                instrname = instrname[:-1]
                if argmodes[1] == 'r':
                    argmodes = [argmodes[0], 'r8']
            else:
                instr_suffix = 'b'
                realargmodes = []
                for mode in argmodes:
                    if mode == 'r':
                        mode = 'r8'
                    elif mode == 'i':
                        mode = 'i8'
                    realargmodes.append(mode)
                argmodes = realargmodes
        elif instrname == 'CALL' or instrname == 'JMP':
            instr_suffix = suffixes[self.WORD] + ' *'
        else:
            instr_suffix = None

        if instrname.find('EXTR') != -1 or \
           instrname.find('INSR') != -1 or \
           instrname.find('INSERT') != -1 or \
           instrname.find('EXTRACT') != -1 or \
           instrname.find('SRLDQ') != -1 or \
           instrname.find('SHUF') != -1 or \
           instrname.find('PBLEND') != -1 or \
           instrname.find('CMPP') != -1:
            realargmodes = []
            for mode in argmodes:
                if mode == 'i':
                    mode = 'i8'
                realargmodes.append(mode)
            argmodes = realargmodes

        print "Testing %s with argmodes=%r" % (instrname, argmodes)
        self.methname = methname
        self.is_xmm_insn = getattr(getattr(self.X86_CodeBuilder,
                                           methname), 'is_xmm_insn', False)
        ilist = self.make_all_tests(methname, argmodes)
        oplist, as_code = self.run_test(methname, instrname, argmodes, ilist,
                                        instr_suffix)
        cls = self.get_code_checker_class()
        cc = cls(as_code, self.accept_unnecessary_prefix)
        for op, args in zip(oplist, ilist):
            if op:
                cc.begin(op)
                getattr(cc, methname)(*args)
        cc.done()

    def setup_class(cls):
        import os
        g = os.popen('as -version </dev/null -o /dev/null 2>&1')
        data = g.read()
        g.close()
        if not data.startswith('GNU assembler'):
            py.test.skip("full tests require the GNU 'as' assembler")

    def test_all(self):
        for name in rx86.all_instructions:
            yield self.complete_test, name
