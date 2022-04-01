import py
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.ppc.arch import WORD
from rpython.jit.tool.oparser import parse
CPU = getcpuclass()

def run(inputargs, ops):
    cpu = CPU(None, None)
    cpu.setup_once()
    loop = parse(ops, cpu, namespace=locals())
    looptoken = JitCellToken()
    cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
    deadframe = cpu.execute_token(looptoken, *inputargs)
    return cpu, deadframe

def test_bug_rshift():
    cpu, deadframe = run([9], '''
    [i1]
    i2 = int_add(i1, i1)
    i3 = int_invert(i2)
    i4 = uint_rshift(i1, 3)
    i5 = int_add(i4, i3)
    finish(i5)
    ''')
    assert cpu.get_int_value(deadframe, 0) == (9 >> 3) + (~18)

def test_bug_int_is_true_1():
    cpu, deadframe = run([-10], '''
    [i1]
    i2 = int_mul(i1, i1)
    i3 = int_mul(i2, i1)
    i5 = int_is_true(i2)
    i4 = int_is_zero(i5)
    guard_false(i5) [i4, i3]
    finish(42)
    ''')
    assert cpu.get_int_value(deadframe, 0) == 0
    assert cpu.get_int_value(deadframe, 1) == -1000

def test_bug_0():
    cpu, deadframe = run([-13, 10, 10, 8, -8, -16, -18, 46, -12, 26], '''
    [i1, i2, i3, i4, i5, i6, i7, i8, i9, i10]
    i11 = uint_gt(i3, -48)
    i12 = int_xor(i8, i1)
    i13 = int_gt(i6, -9)
    i14 = int_le(i13, i2)
    i15 = int_le(i11, i5)
    i16 = uint_ge(i13, i13)
    i17 = int_or(i9, -23)
    i18 = int_lt(i10, i13)
    i19 = int_or(i15, i5)
    i20 = int_xor(i17, 54)
    i21 = int_mul(i8, i10)
    i22 = int_or(i3, i9)
    i41 = int_and(i11, -4)
    i42 = int_or(i41, 1)
    i23 = int_mul(i12, 0)
    i24 = int_is_true(i6)
    i25 = uint_rshift(i15, 6)
    i26 = int_or(-4, i25)
    i27 = int_invert(i8)
    i28 = int_sub(-113, i11)
    i29 = int_neg(i7)
    i30 = int_neg(i24)
    i31 = int_mul(i3, 53)
    i32 = int_mul(i28, i27)
    i43 = int_and(i18, -4)
    i44 = int_or(i43, 1)
    i33 = int_mul(i26, i44)
    i34 = int_or(i27, i19)
    i35 = uint_lt(i13, 1)
    i45 = int_and(i21, 31)
    i36 = int_rshift(i21, i45)
    i46 = int_and(i20, 31)
    i37 = uint_rshift(i4, i46)
    i38 = uint_gt(i33, -11)
    i39 = int_neg(i7)
    i40 = int_gt(i24, i32)
    i99 = same_as_i(0)
    guard_true(i99) [i40, i36, i37, i31, i16, i34, i35, i23, i22, i29, i14, i39, i30, i38]
    finish(42)
    ''')
    assert cpu.get_int_value(deadframe, 0) == 0
    assert cpu.get_int_value(deadframe, 1) == 0
    assert cpu.get_int_value(deadframe, 2) == 0
    assert cpu.get_int_value(deadframe, 3) == 530
    assert cpu.get_int_value(deadframe, 4) == 1
    assert cpu.get_int_value(deadframe, 5) == -7
    assert cpu.get_int_value(deadframe, 6) == 1
    assert cpu.get_int_value(deadframe, 7) == 0
    assert cpu.get_int_value(deadframe, 8) == -2
    assert cpu.get_int_value(deadframe, 9) == 18
    assert cpu.get_int_value(deadframe, 10) == 1
    assert cpu.get_int_value(deadframe, 11) == 18
    assert cpu.get_int_value(deadframe, 12) == -1
    assert cpu.get_int_value(deadframe, 13) == 1

def test_bug_1():
    cpu, deadframe = run([17, -20, -6, 6, 1, 13, 13, 9, 49, 8], '''
    [i1, i2, i3, i4, i5, i6, i7, i8, i9, i10]
    i11 = uint_lt(i6, 0)
    i41 = int_and(i3, 31)
    i12 = int_rshift(i3, i41)
    i13 = int_neg(i2)
    i14 = int_add(i11, i7)
    i15 = int_or(i3, i2)
    i16 = int_or(i12, i12)
    i17 = int_ne(i2, i5)
    i42 = int_and(i5, 31)
    i18 = uint_rshift(i14, i42)
    i43 = int_and(i14, 31)
    i19 = int_lshift(7, i43)
    i20 = int_neg(i19)
    i21 = int_and(i3, 0)
    i22 = uint_ge(i15, i1)
    i44 = int_and(i16, 31)
    i23 = int_lshift(i8, i44)
    i24 = int_is_true(i17)
    i45 = int_and(i5, 31)
    i25 = int_lshift(i14, i45)
    i26 = int_lshift(i5, 17)
    i27 = int_eq(i9, i15)
    i28 = int_ge(0, i6)
    i29 = int_neg(i15)
    i30 = int_neg(i22)
    i31 = int_add(i7, i16)
    i32 = uint_lt(i19, i19)
    i33 = int_add(i2, 1)
    i34 = int_neg(i5)
    i35 = int_add(i17, i24)
    i36 = uint_lt(2, i16)
    i37 = int_neg(i9)
    i38 = int_gt(i4, i11)
    i39 = int_lt(i27, i22)
    i40 = int_neg(i27)
    i99 = same_as_i(0)
    guard_true(i99) [i40, i10, i36, i26, i13, i30, i21, i33, i18, i25, i31, i32, i28, i29, i35, i38, i20, i39, i34, i23, i37]
    finish(-42)
    ''')
    assert cpu.get_int_value(deadframe, 0) == 0
    assert cpu.get_int_value(deadframe, 1) == 8
    assert cpu.get_int_value(deadframe, 2) == 1
    assert cpu.get_int_value(deadframe, 3) == 131072
    assert cpu.get_int_value(deadframe, 4) == 20
    assert cpu.get_int_value(deadframe, 5) == -1
    assert cpu.get_int_value(deadframe, 6) == 0
    assert cpu.get_int_value(deadframe, 7) == -19
    assert cpu.get_int_value(deadframe, 8) == 6
    assert cpu.get_int_value(deadframe, 9) == 26
    assert cpu.get_int_value(deadframe, 10) == 12
    assert cpu.get_int_value(deadframe, 11) == 0
    assert cpu.get_int_value(deadframe, 12) == 0
    assert cpu.get_int_value(deadframe, 13) == 2
    assert cpu.get_int_value(deadframe, 14) == 2
    assert cpu.get_int_value(deadframe, 15) == 1
    assert cpu.get_int_value(deadframe, 16) == -57344
    assert cpu.get_int_value(deadframe, 17) == 1
    assert cpu.get_int_value(deadframe, 18) == -1
    if WORD == 4:
        assert cpu.get_int_value(deadframe, 19) == -2147483648
    elif WORD == 8:
        assert cpu.get_int_value(deadframe, 19) == 19327352832
    assert cpu.get_int_value(deadframe, 20) == -49
