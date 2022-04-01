import py
from rpython.flowspace.model import Constant
from rpython.jit.codewriter.format import format_assembler, unformat_assembler
from rpython.jit.codewriter.flatten import Label, TLabel, SSARepr, Register
from rpython.jit.codewriter.flatten import ListOfKind
from rpython.jit.metainterp.history import AbstractDescr
from rpython.jit.codewriter.jitcode import SwitchDictDescr
from rpython.rtyper.lltypesystem import lltype


def test_format_assembler_simple():
    ssarepr = SSARepr("test")
    i0, i1, i2 = Register('int', 0), Register('int', 1), Register('int', 2)
    ssarepr.insns = [
        ('int_add', i0, i1, '->', i2),
        ('int_return', i2),
        ]
    asm = format_assembler(ssarepr)
    expected = """
        int_add %i0, %i1 -> %i2
        int_return %i2
    """
    assert asm == str(py.code.Source(expected)).strip() + '\n'

def test_format_assembler_float():
    ssarepr = SSARepr("test")
    i1, r2, f3 = Register('int', 1), Register('ref', 2), Register('float', 3)
    ssarepr.insns = [
        ('foobar', i1, r2, f3),
        ]
    asm = format_assembler(ssarepr)
    expected = """
        foobar %i1, %r2, %f3
    """
    assert asm == str(py.code.Source(expected)).strip() + '\n'

def test_format_assembler_const_struct():
    S = lltype.GcStruct('S', ('x', lltype.Signed))
    s = lltype.malloc(S)
    s.x = 123
    ssarepr = SSARepr("test")
    ssarepr.insns = [
        ('foobar', '->', Constant(s, lltype.typeOf(s))),
        ]
    asm = format_assembler(ssarepr)
    expected = """
        foobar -> $<* struct S>
    """
    assert asm == str(py.code.Source(expected)).strip() + '\n'

def test_format_assembler_loop():
    ssarepr = SSARepr("test")
    i0, i1 = Register('int', 0), Register('int', 1)
    ssarepr.insns = [
        (Label('L1'),),
        ('goto_if_not_int_gt', i0, Constant(0, lltype.Signed), TLabel('L2')),
        ('int_add', i1, i0, '->', i1),
        ('int_sub', i0, Constant(1, lltype.Signed), '->', i0),
        ('goto', TLabel('L1')),
        (Label('L2'),),
        ('int_return', i1),
        ]
    asm = format_assembler(ssarepr)
    expected = """
        L1:
        goto_if_not_int_gt %i0, $0, L2
        int_add %i1, %i0 -> %i1
        int_sub %i0, $1 -> %i0
        goto L1
        L2:
        int_return %i1
    """
    assert asm == str(py.code.Source(expected)).strip() + '\n'

def test_format_assembler_list():
    ssarepr = SSARepr("test")
    i0, i1 = Register('int', 0), Register('int', 1)
    ssarepr.insns = [
        ('foobar', ListOfKind('int', [i0, Constant(123, lltype.Signed), i1])),
        ]
    asm = format_assembler(ssarepr)
    expected = """
        foobar I[%i0, $123, %i1]
    """
    assert asm == str(py.code.Source(expected)).strip() + '\n'

def test_format_assembler_descr():
    class FooDescr(AbstractDescr):
        def __repr__(self):
            return 'hi_there!'
    ssarepr = SSARepr("test")
    ssarepr.insns = [
        ('foobar', FooDescr()),
        ]
    asm = format_assembler(ssarepr)
    expected = """
        foobar hi_there!
    """
    assert asm == str(py.code.Source(expected)).strip() + '\n'

def test_unformat_assembler_simple():
    input = """
        int_add %i0, %i1 -> %i2
        int_return %i2
    """
    regs = {}
    ssarepr = unformat_assembler(input, regs)
    assert regs['%i2'].kind == 'int'
    assert regs['%i2'].index == 2
    assert ssarepr.insns == [
        ('int_add', regs['%i0'], regs['%i1'], '->', regs['%i2']),
        ('int_return', regs['%i2']),
        ]

def test_unformat_assembler_consts():
    input = """
        foo $123
    """
    ssarepr = unformat_assembler(input)
    assert ssarepr.insns == [
        ('foo', Constant(123, lltype.Signed)),
        ]

def test_unformat_assembler_single_return():
    input = """
        foo -> %i0
    """
    regs = {}
    ssarepr = unformat_assembler(input, regs)
    assert ssarepr.insns == [
        ('foo', '->', regs['%i0']),
        ]

def test_unformat_assembler_label():
    input = """
        L1:
        foo L2
        L2:
        bar L1
    """
    ssarepr = unformat_assembler(input)
    assert ssarepr.insns == [
        (Label('L1'),),
        ('foo', TLabel('L2')),
        (Label('L2'),),
        ('bar', TLabel('L1')),
        ]

def test_unformat_assembler_lists():
    input = """
        foo F[%f0, %f3]
    """
    regs = {}
    ssarepr = unformat_assembler(input, regs)
    assert ssarepr.insns == [
        ('foo', ListOfKind('float', [regs['%f0'], regs['%f3']]))
        ]

def test_unformat_switchdictdescr():
    input = """
        foo <SwitchDictDescr 4:L2, 5:L1>
        L1:
        L2:
    """
    regs = {}
    ssarepr = unformat_assembler(input, regs)
    sdd = ssarepr.insns[0][1]
    assert ssarepr.insns == [
        ('foo', sdd),
        (Label('L1'),),
        (Label('L2'),),
        ]
    assert isinstance(sdd, SwitchDictDescr)
    assert sdd._labels == [(4, TLabel('L2')), (5, TLabel('L1'))]
