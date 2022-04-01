import os, random, struct
import subprocess
import py
from rpython.jit.backend.zarch import codebuilder
from rpython.rlib.rarithmetic import intmask
from rpython.tool.udir import udir
import itertools
import re

INPUTNAME = 'checkfile_%s.s'
FILENAME = 'checkfile_%s.o'
BEGIN_TAG = '<<<zarch-test-begin>>>'
END_TAG =   '<<<zarch-test-end>>>'

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
            post = self.expected[self.index+1:self.index+15]
            generated = "\x09from codebuilder.py: " + hexdump(self.expected[self.instrindex:self.index]) + "!" + \
                                                      hexdump([char])+ "!" +hexdump(post) + "..."
            expected = "\x09from         gnu as: " + hexdump(self.expected[self.instrindex:self.index+15])+"..."
            raise Exception("Asm line:" + self.op + "\n" + generated + "\n" + expected)
        self.index += 1

    def done(self):
        assert len(self.expected) == self.index

    def stack_frame_size_delta(self, delta):
        pass   # ignored

    def check_stack_size_at_ret(self):
        pass   # ignored

class CodeCheckerZARCH(CodeCheckerMixin, codebuilder.InstrBuilder):
    pass

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

class FakeIndexBaseDisplace(object):
    def __init__(self, index, base, disp):
        self.index = index
        self.base = base
        self.displace = disp

    def __str__(self):
        disp = self.displace
        index = self.index
        base = self.base
        return "{disp}(%r{index},%r{base})".format(**locals())

    __repr__ = __str__

class FakeBaseDisplace(object):
    def __init__(self, base, disp):
        self.base = base
        self.displace = disp

    def __str__(self):
        disp = self.displace
        base = self.base
        return "{disp}(%r{base})".format(**locals())

    __repr__ = __str__

class FakeLengthBaseDisplace(object):
    def __init__(self, len, base, disp):
        self.length = len
        self.base = base
        self.displace = disp

    def __str__(self):
        disp = self.displace
        base = self.base
        length = self.length + 1
        return "{disp}({length},%r{base})".format(**locals())

    __repr__ = __str__

def range_of_bits(bits, signed=False, count=24):
    if isinstance(bits, tuple):
        bits, signed = bits
    if signed:
        bits -= 1
        maximum = 2**bits
        return [-maximum,-1,0,1,maximum-1] + [random.randrange(-maximum,maximum) for i in range(count)]
    maximum = 2**bits
    return [0,1,maximum-1] + [random.randrange(0,maximum) for i in range(count)]

def range_of_halfword_bits(bits, signed=True, count=24):
    elems = range_of_bits(bits, signed, count)
    for i,e in enumerate(elems):
        elems[i] = e >> 1
    return elems

def build_fake(clazz, *arg_bits):
    possibilities = itertools.product(*[range_of_bits(b) for b in arg_bits])
    results = []
    i = 0
    for args in possibilities:
        results.append(clazz(*args))
        i+=1
        if i > 20:
            break
    return results

REGS = range(16)
EVEN_REGS = range(0,16,2)
REGNAMES = ['%%r%d' % i for i in REGS]
FP_REGS = range(16)
FP_REGNAMES = ['%%f%d' % i for i in FP_REGS]
VEC_REGS = ['%%v%d' % i for i in range(16,32)]
TEST_CASE_GENERATE = {
    '-':    [],
    'r':    REGS,
    'f':    FP_REGS,
    'eo':   EVEN_REGS,
    'r/m':  REGS,
    'v':    VEC_REGS,
    'm':    range_of_bits(4),
    'i4':   range_of_bits(4, signed=True),
    'i8':   range_of_bits(8, signed=True),
    'i16':  range_of_bits(16, signed=True),
    'i32':  range_of_bits(32, signed=True),
    'i64':  range_of_bits(64, signed=True),
    'h32':  range_of_halfword_bits(32, signed=True),
    'u4':   range_of_bits(4),
    'u8':   range_of_bits(8),
    'u16':  range_of_bits(16),
    'u32':  range_of_bits(32),
    'u64':  range_of_bits(64),
    'bd':   build_fake(FakeBaseDisplace,4,12),
    'bdl':  build_fake(FakeBaseDisplace,4,19),
    'bid':  build_fake(FakeIndexBaseDisplace,4,4,12),
    'bidl': build_fake(FakeIndexBaseDisplace,4,4,(20,True)),
    'l8bd': build_fake(FakeLengthBaseDisplace,8,4,12),
    'l4bd': build_fake(FakeLengthBaseDisplace,4,4,12),
}

class TestZARCH(object):
    WORD = 4
    TESTDIR = 'zarch'
    accept_unnecessary_prefix = None
    methname = '?'

    def get_func_arg_types(self, methodname):
        from rpython.jit.backend.zarch.instruction_builder import get_arg_types_of
        return get_arg_types_of(methodname)

    def operand_combinations(self, methodname, modes, arguments):
        mapping = {
            'r': (lambda num: REGNAMES[num]),
            'eo': (lambda num: REGNAMES[num]),
            'r/m': (lambda num: REGNAMES[num]),
            'f': (lambda num: FP_REGNAMES[num]),
            'h32': (lambda num: str(num << 1)),
        }
        arg_types = self.get_func_arg_types(methodname)
        for mode, args in zip(arg_types, arguments):
            yield mapping.get(mode, lambda x: str(x))(args)

    def run_test(self, methname, instrname, argmodes, args_lists,
                 instr_suffix=None):
        global labelcount
        labelcount = 0
        oplist = []
        testdir = udir.ensure(self.TESTDIR, dir=1)
        inputname = str(testdir.join(INPUTNAME % methname))
        filename  = str(testdir.join(FILENAME  % methname))
        with open(inputname, 'w') as g:
            g.write('\x09.string "%s"\n' % BEGIN_TAG)
            #
            for args in args_lists:
                suffix = ""
                if instr_suffix is not None:
                    suffix = instr_suffix    # overwrite
                #
                ops = self.operand_combinations(methname, argmodes, args)
                op = '\t%s%s %s' % (instrname.lower(), suffix,
                                      ', '.join(ops))
                g.write('%s\n' % op)
                oplist.append(op)
            g.write('\t.string "%s"\n' % END_TAG)
        proc = subprocess.Popen(['as', '-m64', '-mzarch', '-march=z196',
                                 inputname, '-o', filename],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        stdout, stderr = proc.communicate()
        if proc.returncode or stderr:
            raise Exception("could not execute assembler. error:\n%s" % (stderr))
        with open(inputname, 'r') as g:
            got = g.read()
        error = [line for line in got.splitlines() if 'error' in line.lower()]
        if error:
            raise Exception("Assembler got an error: %r" % error[0])
        error = [line for line in got.splitlines()
                 if 'warning' in line.lower()]
        if error:
            raise Exception("Assembler got a warning: %r" % error[0])
        try:
            with open(filename, 'rb') as f:
                data = f.read()
                i = data.find(BEGIN_TAG)
                assert i>=0
                j = data.find(END_TAG, i)
                assert j>=0
                as_code = data[i+len(BEGIN_TAG)+1:j]
        except IOError:
            raise Exception("Assembler did not produce output?")
        return oplist, as_code

    def modes(self, mode):
        return mode

    def make_all_tests(self, methname, modes, args=[]):
        if methname.startswith("RIS"):
            return []
        arg_types = self.get_func_arg_types(methname)
        combinations = []
        for i,m in enumerate(arg_types):
            elems = TEST_CASE_GENERATE[m]
            #random.shuffle(elems)
            combinations.append(elems)
        results = []
        for args in itertools.product(*combinations):
            results.append(args)
        return results

    def should_skip_instruction(self, instrname, argmodes):
        return False

    def complete_test(self, methname):
        if '_' in methname:
            instrname, argmodes = methname.split('_')[:2]
        else:
            instrname, argmodes = methname, ''
        argmodes = self.modes(argmodes)

        if self.should_skip_instruction(instrname, argmodes):
            print "Skipping %s" % methname
            return

        instr_suffix = None

        print "Testing %s with argmodes=%r" % (instrname, argmodes)
        self.methname = methname
        ilist = self.make_all_tests(methname, argmodes)
        oplist, as_code = self.run_test(methname, instrname, argmodes, ilist,
                                        instr_suffix)
        cc = CodeCheckerZARCH(as_code, self.accept_unnecessary_prefix)
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

    @py.test.mark.parametrize("name", codebuilder.all_instructions)
    def test_all(self, name):
        if name.startswith('V'):
            py.test.skip("objdump might not be able to assemble z13 instr.")
        self.complete_test(name)
