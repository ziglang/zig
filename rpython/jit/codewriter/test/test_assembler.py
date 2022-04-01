import py, struct, sys
from rpython.jit.codewriter.assembler import Assembler, AssemblerError
from rpython.jit.codewriter.flatten import SSARepr, Label, TLabel, Register
from rpython.jit.codewriter.flatten import ListOfKind, IndirectCallTargets
from rpython.jit.codewriter.jitcode import MissingLiveness
from rpython.jit.codewriter import longlong
from rpython.jit.metainterp.history import AbstractDescr
from rpython.jit.metainterp.support import ptr2int
from rpython.flowspace.model import Constant
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rlib.rarithmetic import r_int, r_uint


def test_assemble_simple():
    ssarepr = SSARepr("test")
    i0, i1, i2 = Register('int', 0), Register('int', 1), Register('int', 2)
    ssarepr.insns = [
        ('int_add', i0, i1, '->', i2),
        ('int_return', i2),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\x00\x01\x02"
                            "\x01\x02")
    assert assembler.insns == {'int_add/ii>i': 0,
                               'int_return/i': 1}
    assert jitcode.num_regs_i() == 3
    assert jitcode.num_regs_r() == 0
    assert jitcode.num_regs_f() == 0

def test_assemble_consts():
    ssarepr = SSARepr("test")
    ssarepr.insns = [
        ('int_return', Register('int', 13)),
        ('int_return', Constant(18, lltype.Signed)),
        ('int_return', Constant(-4, lltype.Signed)),
        ('int_return', Constant(128, lltype.Signed)),
        ('int_return', Constant(-129, lltype.Signed)),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\x0D"
                            "\x01\x12"   # use int_return/c for one-byte consts
                            "\x01\xFC"
                            "\x00\xFF"   # use int_return/i for larger consts
                            "\x00\xFE")
    assert assembler.insns == {'int_return/i': 0,
                               'int_return/c': 1}
    assert jitcode.constants_i == [128, -129]

def test_assemble_float_consts():
    ssarepr = SSARepr("test")
    ssarepr.insns = [
        ('float_return', Register('float', 13)),
        ('float_return', Constant(18.0, lltype.Float)),
        ('float_return', Constant(-4.0, lltype.Float)),
        ('float_return', Constant(128.1, lltype.Float)),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\x0D"
                            "\x00\xFF"
                            "\x00\xFE"
                            "\x00\xFD")
    assert assembler.insns == {'float_return/f': 0}
    assert jitcode.constants_f == [longlong.getfloatstorage(18.0),
                                   longlong.getfloatstorage(-4.0),
                                   longlong.getfloatstorage(128.1)]

def test_assemble_llong_consts():
    if sys.maxint > 2147483647:
        py.test.skip("only for 32-bit platforms")
    from rpython.rlib.rarithmetic import r_longlong, r_ulonglong
    ssarepr = SSARepr("test")
    ssarepr.insns = [
        ('float_return', Constant(r_longlong(-18000000000000000),
                                  lltype.SignedLongLong)),
        ('float_return', Constant(r_ulonglong(9900000000000000000),
                                  lltype.UnsignedLongLong)),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\xFF"
                            "\x00\xFE")
    assert assembler.insns == {'float_return/f': 0}
    assert jitcode.constants_f == [r_longlong(-18000000000000000),
                                   r_longlong(-8546744073709551616)]

def test_assemble_cast_consts():
    ssarepr = SSARepr("test")
    S = lltype.GcStruct('S')
    s = lltype.malloc(S)
    F = lltype.FuncType([], lltype.Signed)
    f = lltype.functionptr(F, 'f')
    ssarepr.insns = [
        ('int_return', Constant('X', lltype.Char)),
        ('int_return', Constant(unichr(0x1234), lltype.UniChar)),
        ('int_return', Constant(f, lltype.Ptr(F))),
        ('ref_return', Constant(s, lltype.Ptr(S))),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\x58"
                            "\x01\xFF"
                            "\x01\xFE"
                            "\x02\xFF")
    assert assembler.insns == {'int_return/c': 0,
                               'int_return/i': 1,
                               'ref_return/r': 2}
    f_int = ptr2int(f)
    assert jitcode.constants_i == [0x1234, f_int]
    s_gcref = lltype.cast_opaque_ptr(llmemory.GCREF, s)
    assert jitcode.constants_r == [s_gcref]

def test_assemble_loop():
    ssarepr = SSARepr("test")
    i0, i1 = Register('int', 0x16), Register('int', 0x17)
    ssarepr.insns = [
        (Label('L1'),),
        ('goto_if_not_int_gt', i0, Constant(4, lltype.Signed), TLabel('L2')),
        ('int_add', i1, i0, '->', i1),
        ('int_sub', i0, Constant(1, lltype.Signed), '->', i0),
        ('goto', TLabel('L1')),
        (Label('L2'),),
        ('int_return', i1),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\x16\x04\x10\x00"
                            "\x01\x17\x16\x17"
                            "\x02\x16\x01\x16"
                            "\x03\x00\x00"
                            "\x04\x17")
    assert assembler.insns == {'goto_if_not_int_gt/icL': 0,
                               'int_add/ii>i': 1,
                               'int_sub/ic>i': 2,
                               'goto/L': 3,
                               'int_return/i': 4}

def test_assemble_list():
    ssarepr = SSARepr("test")
    i0, i1 = Register('int', 0x16), Register('int', 0x17)
    ssarepr.insns = [
        ('foobar', ListOfKind('int', [i0, i1, Constant(42, lltype.Signed)]),
                   ListOfKind('ref', [])),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == "\x00\x03\x16\x17\xFF\x00"
    assert assembler.insns == {'foobar/IR': 0}
    assert jitcode.constants_i == [42]

def test_assemble_list_semibug():
    # the semibug is that after forcing 42 into the dict of constants,
    # it would be reused for all future 42's, even ones that can be
    # encoded directly.
    ssarepr = SSARepr("test")
    ssarepr.insns = [
        ('foobar', ListOfKind('int', [Constant(42, lltype.Signed)])),
        ('foobar', ListOfKind('int', [Constant(42, lltype.Signed)])),
        ('baz', Constant(42, lltype.Signed)),
        ('bok', Constant(41, lltype.Signed)),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\x01\xFF"
                            "\x00\x01\xFF"
                            "\x01\x2A"
                            "\x02\xFE")
    assert assembler.insns == {'foobar/I': 0,
                               'baz/c': 1,    # in USE_C_FORM
                               'bok/i': 2}    # not in USE_C_FORM
    assert jitcode.constants_i == [42, 41]

def test_assemble_descr():
    class FooDescr(AbstractDescr):
        pass
    descrs = [FooDescr() for i in range(300)]
    ssarepr = SSARepr("test")
    ssarepr.insns = [('foobar', d) for d in descrs[::-1]]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ''.join(["\x00" + struct.pack("<H", i)
                                       for i in range(300)])
    assert assembler.insns == {'foobar/d': 0}
    assert assembler.descrs == descrs[::-1]

def test_assemble_indirect_call():
    lst1 = ["somejitcode1", "somejitcode2"]
    lst2 = ["somejitcode1", "somejitcode3"]
    ssarepr = SSARepr("test")
    ssarepr.insns = [('foobar', IndirectCallTargets(lst1)),
                     ('foobar', IndirectCallTargets(lst2))]
    assembler = Assembler()
    assembler.assemble(ssarepr)
    assert assembler.indirectcalltargets == set(lst1).union(lst2)

def test_num_regs():
    assembler = Assembler()
    ssarepr = SSARepr("test")
    ssarepr.insns = []
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.num_regs_i() == 0
    assert jitcode.num_regs_r() == 0
    assert jitcode.num_regs_f() == 0
    ssarepr = SSARepr("test")
    ssarepr.insns = [('foobar', Register('int', 51),
                                Register('ref', 27),
                                Register('int', 12))]
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.num_regs_i() == 52
    assert jitcode.num_regs_r() == 28
    assert jitcode.num_regs_f() == 0

def test_liveness():
    ssarepr = SSARepr("test")
    i0, i1, i2 = Register('int', 0), Register('int', 1), Register('int', 2)
    ssarepr.insns = [
        ('int_add', i0, Constant(10, lltype.Signed), '->', i1),
        ('-live-', i0, i1),
        ('-live-', i1, i2),
        ('int_add', i0, Constant(3, lltype.Signed), '->', i2),
        ('-live-', i2),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.code == ("\x00\x00\x0A\x01"   # ends at 4
                            "\x00\x00\x03\x02")  # ends at 8
    assert assembler.insns == {'int_add/ic>i': 0}
    for i in range(8):
        if i != 4:
            py.test.raises(MissingLiveness, jitcode._live_vars, i)
    assert jitcode._live_vars(4) == '%i0 %i1 %i2'
    assert jitcode._live_vars(8) == '%i2'

def test_assemble_error_string_constant():
    ssarepr = SSARepr("test")
    c = Constant('foobar', lltype.Void)
    ssarepr.insns = [
        ('duh', c),
        ]
    assembler = Assembler()
    py.test.raises(AssemblerError, assembler.assemble, ssarepr)

def test_assemble_r_int():
    # r_int is a strange type, which the jit should replace with int.
    # r_uint is also replaced with int.
    ssarepr = SSARepr("test")
    i0, i1, i2 = Register('int', 0), Register('int', 1), Register('int', 2)
    ssarepr.insns = [
        ('uint_add', i0, Constant(r_uint(42424242), lltype.Unsigned), '->', i1),
        ('int_add', i0, Constant(r_int(42424243), lltype.Signed), '->', i2),
        ]
    assembler = Assembler()
    jitcode = assembler.assemble(ssarepr)
    assert jitcode.constants_i == [42424242, 42424243]
    assert map(type, jitcode.constants_i) == [int, int]
