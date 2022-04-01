import sys, py
import random
from rpython.jit.backend.x86 import rx86
from rpython.jit.backend.x86.test import test_rx86_32_auto_encoding

if sys.maxint <= 2**32:
    py.test.skip("skipping this test on x86-32")


class TestRx86_64(test_rx86_32_auto_encoding.TestRx86_32):
    WORD = 8
    TESTDIR = 'rx86_64'
    X86_CodeBuilder = rx86.X86_64_CodeBuilder
    REGNAMES = ['%rax', '%rcx', '%rdx', '%rbx', '%rsp', '%rbp', '%rsi', '%rdi',
                '%r8', '%r9', '%r10', '%r11', '%r12', '%r13', '%r14', '%r15']
    REGNAMES8 = ['%al', '%cl', '%dl', '%bl', '%spl', '%bpl', '%sil', '%dil',
                '%r8b', '%r9b', '%r10b', '%r11b',
                 '%r12b', '%r13b', '%r14b', '%r15b']
    REGS = range(16)
    REGS8 = [i|rx86.BYTE_REG_FLAG for i in range(16)]
    NONSPECREGS = [rx86.R.eax, rx86.R.ecx, rx86.R.edx, rx86.R.ebx,
                   rx86.R.esi, rx86.R.edi,
                   rx86.R.r8,  rx86.R.r9,  rx86.R.r10, rx86.R.r11,
                   rx86.R.r12, rx86.R.r13, rx86.R.r14, rx86.R.r15]
    accept_unnecessary_prefix = '\x40'

    def should_skip_instruction(self, instrname, argmodes):
        return (
                super(TestRx86_64, self).should_skip_instruction(instrname, argmodes) or
                # Not testing FSTP on 64-bit for now
                (instrname == 'FSTP') or
                # the test suite uses 64 bit registers instead of 32 bit...
                # it is tested in the 32 bit test!
                (instrname == 'PEXTRD') or
                (instrname == 'PINSRD')
        )

    def array_tests(self):
        # reduce a little bit -- we spend too long in these tests
        lst = super(TestRx86_64, self).array_tests()
        random.shuffle(lst)
        return lst[:int(len(lst) * 0.2)]

    def imm64_tests(self):
        v = [-0x80000001, 0x80000000,
             -0x8000000000000000, 0x7FFFFFFFFFFFFFFF]
        for i in range(test_rx86_32_auto_encoding.COUNT1):
            x = ((random.randrange(-32768,32768)<<48) |
                 (random.randrange(0,65536)<<32) |
                 (random.randrange(0,65536)<<16) |
                 (random.randrange(0,65536)<<0))
            v.append(x)
        return v + super(TestRx86_64, self).imm32_tests()

    def test_extra_MOV_ri64(self):
        self.imm32_tests = self.imm64_tests      # patch on 'self'
        self.complete_test('MOV_ri')

    def rip_relative_tests(self):
        return [-0x80000000, 0x7FFFFFFF, 128, 256, -129, -255, 0, 127]

    def get_all_tests(self):
        d = super(TestRx86_64, self).get_all_tests()
        d['p'] = self.rip_relative_tests
        return d

    def assembler_operand_rip_relative(self, value):
        return '%d(%%rip)' % value

    def get_all_assembler_operands(self):
        d = super(TestRx86_64, self).get_all_assembler_operands()
        d['p'] = self.assembler_operand_rip_relative
        return d
