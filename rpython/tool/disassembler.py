"""Disassembler of Python byte code into mnemonics.

Comes from standard library, modified for the purpose of having a structured
view on things
"""

from __future__ import print_function
import sys
import types
import inspect

from opcode import *
from opcode import __all__ as _opcodes_all

__all__ = ["dis","disassemble","distb","disco"] + _opcodes_all
del _opcodes_all

class Opcode(object):
    """ An abstract base class for all opcode implementations
    """
    def __init__(self, pos, lineno, arg=None, argstr=''):
        self.pos = pos
        self.arg = arg
        self.argstr = argstr
        self.lineno = lineno
        self.line_starts_here = False

    def __str__(self):
        if self.arg is None:
            return "%s" % (self.__class__.__name__,)
        return "%s (%s)" % (self.__class__.__name__, self.arg)

    def __repr__(self):
        if self.arg is None:
            return "<%s at %d>" % (self.__class__.__name__, self.pos)
        return "<%s (%s) at %d>" % (self.__class__.__name__, self.arg, self.pos)

class CodeRepresentation(object):
    """ Representation of opcodes
    """
    def __init__(self, opcodes, co, source):
        self.opcodes = opcodes
        self.co = co
        self.map = {}
        current_lineno = None
        for opcode in opcodes:
            self.map[opcode.pos] = opcode
            if opcode.lineno != current_lineno:
                opcode.line_starts_here = True
            current_lineno = opcode.lineno
        self.source = source.split("\n")

    def get_opcode_from_info(self, info):
        return self.map[info.bytecode_no]

    @property
    def filename(self):
        return self.co.co_filename

    @property
    def startlineno(self):
        return self.co.co_firstlineno

    @property
    def name(self):
        return self.co.co_name

    def match_name(self, opcode_name):
        return self.__class__.__name__ == opcode_name


def _setup():
    for opcode in opname:
        if not opcode.startswith('<'):
            class O(Opcode):
                pass
            opcode = opcode.replace('+', '_')
            O.__name__ = opcode
            globals()[opcode] = O

_setup()

def dis(x=None):
    """Disassemble classes, methods, functions, or code.

    With no argument, disassemble the last traceback.

    """
    if x is None:
        distb()
        return
    if type(x) is types.InstanceType:
        x = x.__class__
    if hasattr(x, 'im_func'):
        x = x.im_func
    if hasattr(x, 'func_code'):
        x = x.__code__
    if hasattr(x, '__dict__'):
        xxx
        items = sorted(x.__dict__.items())
        for name, x1 in items:
            if type(x1) in (types.MethodType,
                            types.FunctionType,
                            types.CodeType,
                            types.ClassType):
                print("Disassembly of %s:" % name)
                try:
                    dis(x1)
                except TypeError as msg:
                    print("Sorry:", msg)
                print()
    elif hasattr(x, 'co_code'):
        return disassemble(x)
    elif isinstance(x, str):
        return disassemble_string(x)
    else:
        raise TypeError("don't know how to disassemble %s objects" % \
              type(x).__name__)

def distb(tb=None):
    """Disassemble a traceback (default: last traceback)."""
    if tb is None:
        try:
            tb = sys.last_traceback
        except AttributeError:
            raise RuntimeError("no last traceback to disassemble")
        while tb.tb_next: tb = tb.tb_next
    disassemble(tb.tb_frame.f_code, tb.tb_lasti)

def disassemble(co, lasti=-1):
    """Disassemble a code object."""
    source = inspect.getsource(co)
    code = co.co_code
    labels = findlabels(code)
    linestarts = dict(findlinestarts(co))
    n = len(code)
    i = 0
    extended_arg = 0
    free = None
    res = []
    lastline = co.co_firstlineno
    while i < n:
        c = code[i]
        op = ord(c)
        if i in linestarts:
            lastline = linestarts[i]

        #if i == lasti:
        #    xxx
        #    print '-->',
        #else:
        #    xxx
        #    print '   ',
        #if i in labels:
        #    xxx
        #    print '>>',
        #else:
        #    xxx
        #    print '  ',
        #xxx
        pos = i
        i = i + 1
        if op >= HAVE_ARGUMENT:
            oparg = ord(code[i]) + ord(code[i+1])*256 + extended_arg
            opargstr = str(oparg)
            extended_arg = 0
            i = i+2
            if op == EXTENDED_ARG:
                extended_arg = oparg*65536
            if op in hasconst:
                opargstr = repr(co.co_consts[oparg])
            elif op in hasname:
                opargstr = co.co_names[oparg]
            elif op in hasjrel:
                opargstr = 'to ' + repr(i + oparg)
            elif op in haslocal:
                opargstr = co.co_varnames[oparg]
            elif op in hascompare:
                opargstr = cmp_op[oparg]
            elif op in hasfree:
                if free is None:
                    free = co.co_cellvars + co.co_freevars
                opargstr = free[oparg]
        else:
            oparg = None
            opargstr = ''
        opcls = globals()[opname[op].replace('+', '_')]
        res.append(opcls(pos, lastline, oparg, opargstr))
    return CodeRepresentation(res, co, source)

def disassemble_string(code, lasti=-1, varnames=None, names=None,
                       constants=None):
    labels = findlabels(code)
    n = len(code)
    i = 0
    while i < n:
        c = code[i]
        op = ord(c)
        if i == lasti:
            xxx
            print('-->', end=' ')
        else:
            xxx
            print('   ', end=' ')
        if i in labels:
            xxx
            print('>>', end=' ')
        else:
            xxx
            print('  ', end=' ')
        xxxx
        print(repr(i).rjust(4), end=' ')
        print(opname[op].ljust(15), end=' ')
        i = i+1
        if op >= HAVE_ARGUMENT:
            oparg = ord(code[i]) + ord(code[i+1])*256
            i = i+2
            xxx
            print(repr(oparg).rjust(5), end=' ')
            if op in hasconst:
                if constants:
                    xxx
                    print('(' + repr(constants[oparg]) + ')', end=' ')
                else:
                    xxx
                    print('(%d)'%oparg, end=' ')
            elif op in hasname:
                if names is not None:
                    xxx
                    print('(' + names[oparg] + ')', end=' ')
                else:
                    xxx
                    print('(%d)'%oparg, end=' ')
            elif op in hasjrel:
                xxx
                print('(to ' + repr(i + oparg) + ')', end=' ')
            elif op in haslocal:
                if varnames:
                    xxx
                    print('(' + varnames[oparg] + ')', end=' ')
                else:
                    xxx
                    print('(%d)' % oparg, end=' ')
            elif op in hascompare:
                xxx
                print('(' + cmp_op[oparg] + ')', end=' ')
        xxx
        print()

disco = disassemble                     # XXX For backwards compatibility

def findlabels(code):
    """Detect all offsets in a byte code which are jump targets.

    Return the list of offsets.

    """
    labels = []
    n = len(code)
    i = 0
    while i < n:
        c = code[i]
        op = ord(c)
        i = i+1
        if op >= HAVE_ARGUMENT:
            oparg = ord(code[i]) + ord(code[i+1])*256
            i = i+2
            label = -1
            if op in hasjrel:
                label = i+oparg
            elif op in hasjabs:
                label = oparg
            if label >= 0:
                if label not in labels:
                    labels.append(label)
    return labels

def findlinestarts(code):
    """Find the offsets in a byte code which are start of lines in the source.

    Generate pairs (offset, lineno) as described in Python/compile.c.

    """
    byte_increments = [ord(c) for c in code.co_lnotab[0::2]]
    line_increments = [ord(c) for c in code.co_lnotab[1::2]]

    lastlineno = None
    lineno = code.co_firstlineno
    addr = 0
    for byte_incr, line_incr in zip(byte_increments, line_increments):
        if byte_incr:
            if lineno != lastlineno:
                yield (addr, lineno)
                lastlineno = lineno
            addr += byte_incr
        lineno += line_incr
    if lineno != lastlineno:
        yield (addr, lineno)

def _test():
    """Simple test program to disassemble a file."""
    if sys.argv[1:]:
        if sys.argv[2:]:
            sys.stderr.write("usage: python dis.py [-|file]\n")
            sys.exit(2)
        fn = sys.argv[1]
        if not fn or fn == "-":
            fn = None
    else:
        fn = None
    if fn is None:
        f = sys.stdin
    else:
        f = open(fn)
    source = f.read()
    if fn is not None:
        f.close()
    else:
        fn = "<stdin>"
    code = compile(source, fn, "exec")
    dis(code)
