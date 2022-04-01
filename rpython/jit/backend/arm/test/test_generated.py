import py
py.test.skip("XXX FIX ME OR KILL ME")

from rpython.jit.metainterp.history import (AbstractFailDescr,
                                         AbstractDescr,
                                         BasicFailDescr,
                                         BoxInt, Box, BoxPtr,
                                         ConstInt, ConstPtr,
                                         Const, BoxFloat, ConstFloat)
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.metainterp.resoperation import ResOperation, rop
from rpython.rtyper.test.test_llinterp import interpret
from rpython.jit.backend.detect_cpu import getcpuclass

CPU = getcpuclass()
class TestStuff(object):

    def test0(self):
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_SUB, [ConstInt(-1073741824), v7], v11),
            ResOperation(rop.INT_GE, [v3, ConstInt(23)], v12),
            ResOperation(rop.GUARD_TRUE, [v12], None, descr=faildescr1),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr2),
            ]
        looptoken = JitCellToken()
        operations[2].setfailargs([v12, v8, v3, v2, v1, v11])
        operations[3].setfailargs([v9, v6, v10, v2, v8, v5, v1, v4])
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [-12 , -26 , -19 , 7 , -5 , -24 , -37 , 62 , 9 , 12]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_int_value(deadframe, 0) == 0
        assert cpu.get_int_value(deadframe, 1) == 62
        assert cpu.get_int_value(deadframe, 2) == -19
        assert cpu.get_int_value(deadframe, 3) == -26
        assert cpu.get_int_value(deadframe, 4) == -12
        assert cpu.get_int_value(deadframe, 5) == -1073741787

    def test_overflow(self):
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        faildescr3 = BasicFailDescr(3)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        v15 = BoxInt()
        v16 = BoxInt()
        v17 = BoxInt()
        v18 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_SUB, [ConstInt(21), v5], v11),
            ResOperation(rop.INT_MUL_OVF, [v8, v4], v12),
            ResOperation(rop.GUARD_NO_OVERFLOW, [], None, descr=faildescr1),
            ResOperation(rop.UINT_LT, [v10, v3], v13),
            ResOperation(rop.INT_IS_TRUE, [v3], v14),
            ResOperation(rop.INT_XOR, [v9, v8], v15),
            ResOperation(rop.INT_LE, [v12, v6], v16),
            ResOperation(rop.UINT_GT, [v15, v5], v17),
            ResOperation(rop.UINT_LE, [ConstInt(-9), v13], v18),
            ResOperation(rop.GUARD_FALSE, [v13], None, descr=faildescr2),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr3),
            ]
        operations[2].setfailargs([v10, v6])
        operations[9].setfailargs([v15, v7, v10, v18, v4, v17, v1])
        operations[-1].setfailargs([v7, v1, v2])
        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [16 , 5 , 5 , 16 , 46 , 6 , 63 , 39 , 78 , 0]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_int_value(deadframe, 0) == 105
        assert cpu.get_int_value(deadframe, 1) == 63
        assert cpu.get_int_value(deadframe, 2) == 0
        assert cpu.get_int_value(deadframe, 3) == 0
        assert cpu.get_int_value(deadframe, 4) == 16
        assert cpu.get_int_value(deadframe, 5) == 1
        assert cpu.get_int_value(deadframe, 6) == 16

    def test_sub_with_neg_const_first_arg(self):
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        faildescr3 = BasicFailDescr(3)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        tmp13 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_EQ, [ConstInt(17), v9], v11),
            ResOperation(rop.INT_SUB_OVF, [ConstInt(-32), v7], v12),
            ResOperation(rop.GUARD_NO_OVERFLOW, [], None, descr=faildescr1),
            ResOperation(rop.INT_IS_ZERO, [v12], tmp13),
            ResOperation(rop.GUARD_TRUE, [tmp13], None, descr=faildescr2),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr3)
            ]
        operations[2].setfailargs([v8, v3])
        operations[4].setfailargs([v2, v12, v1, v3, v4])
        operations[-1].setfailargs([v5, v2, v1, v10, v3, v8, v4, v6])

        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [-5 , 24 , 46 , -15 , 13 , -8 , 0 , -6 , 6 , 6]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_latest_descr(deadframe).identifier == 2
        assert cpu.get_int_value(deadframe, 0) == 24
        assert cpu.get_int_value(deadframe, 1) == -32
        assert cpu.get_int_value(deadframe, 2) == -5
        assert cpu.get_int_value(deadframe, 3) == 46
        assert cpu.get_int_value(deadframe, 4) == -15

    def test_tempbox_spilling_in_sub(self):
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        v15 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_LT, [v9, v9], v11),
            ResOperation(rop.INT_ADD, [ConstInt(715827882), v4], v12),
            ResOperation(rop.INT_NEG, [v11], v13),
            ResOperation(rop.INT_IS_TRUE, [v3], v14),
            ResOperation(rop.INT_SUB_OVF, [v3, ConstInt(-95)], v15),
            ResOperation(rop.GUARD_NO_OVERFLOW, [], None, descr=faildescr1),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr2),
            ]
        operations[5].setfailargs([])
        operations[-1].setfailargs([v8, v2, v6, v5, v7, v1, v10])
        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [19 , -3 , -58 , -7 , 12 , 22 , -54 , -29 , -19 , -64]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_int_value(deadframe, 0) == -29
        assert cpu.get_int_value(deadframe, 1) == -3
        assert cpu.get_int_value(deadframe, 2) == 22
        assert cpu.get_int_value(deadframe, 3) == 12
        assert cpu.get_int_value(deadframe, 4) == -54
        assert cpu.get_int_value(deadframe, 5) == 19
        assert cpu.get_int_value(deadframe, 6) == -64

    def test_tempbox2(self):
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        v15 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_LT, [v5, ConstInt(-67)], v11),
            ResOperation(rop.INT_INVERT, [v2], v12),
            ResOperation(rop.INT_SUB, [ConstInt(-45), v2], v13),
            ResOperation(rop.INT_SUB, [ConstInt(99), v6], v14),
            ResOperation(rop.INT_MUL_OVF, [v6, v9], v15),
            ResOperation(rop.GUARD_NO_OVERFLOW, [], None, descr=faildescr1),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr2),
            ]
        looptoken = JitCellToken()
        operations[5].setfailargs([])
        operations[-1].setfailargs([v1, v4, v10, v8, v7, v3])
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [1073741824 , 95 , -16 , 5 , 92 , 12 , 32 , 17 , 37 , -63]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_int_value(deadframe, 0) == 1073741824
        assert cpu.get_int_value(deadframe, 1) == 5
        assert cpu.get_int_value(deadframe, 2) == -63
        assert cpu.get_int_value(deadframe, 3) == 17
        assert cpu.get_int_value(deadframe, 4) == 32
        assert cpu.get_int_value(deadframe, 5) == -16

    def test_wrong_guard(self):
        # generated by:
        # ../test/ test/test_zll_random.py -l -k arm -s --block-length=10 --random-seed=4338

        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        faildescr3 = BasicFailDescr(3)
        faildescr4 = BasicFailDescr(4)
        v1 = BoxInt(32)
        v2 = BoxInt(41)
        v3 = BoxInt(-9)
        v4 = BoxInt(12)
        v5 = BoxInt(-18)
        v6 = BoxInt(46)
        v7 = BoxInt(15)
        v8 = BoxInt(17)
        v9 = BoxInt(10)
        v10 = BoxInt(12)
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        tmp15 = BoxInt()
        tmp16 = BoxInt()
        tmp17 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_IS_TRUE, [v1], tmp15),
            ResOperation(rop.GUARD_TRUE, [tmp15], None, descr=faildescr1),
            ResOperation(rop.INT_GT, [v4, v5], v11),
            ResOperation(rop.INT_XOR, [ConstInt(-4), v7], v12),
            ResOperation(rop.INT_MUL, [ConstInt(23), v11], v13),
            ResOperation(rop.UINT_GE, [ConstInt(1), v13], v14),
            ResOperation(rop.INT_IS_ZERO, [v14], tmp16),
            ResOperation(rop.GUARD_TRUE, [tmp16], None, descr=faildescr2),
            ResOperation(rop.INT_IS_TRUE, [v12], tmp17),
            ResOperation(rop.GUARD_FALSE, [tmp17], None, descr=faildescr3),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr4),
            ]
        looptoken = JitCellToken()
        operations[1].setfailargs([v8, v6, v1])
        operations[7].setfailargs([v4])
        operations[9].setfailargs([v10, v13])
        operations[-1].setfailargs([v8, v10, v6, v3, v2, v9])
        args = [32 , 41 , -9 , 12 , -18 , 46 , 15 , 17 , 10 , 12]
        cpu.compile_loop(inputargs, operations, looptoken)
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_latest_descr(deadframe).identifier == 3
        assert cpu.get_int_value(deadframe, 0) == 12
        assert cpu.get_int_value(deadframe, 1) == 23

    def test_wrong_guard2(self):
        # random seed: 8029
        # block length: 10
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        faildescr3 = BasicFailDescr(3)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        v15 = BoxInt()
        v16 = BoxInt()
        tmp17 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_ADD_OVF, [v8, ConstInt(-30)], v11),
            ResOperation(rop.GUARD_NO_OVERFLOW, [], None, descr=faildescr1),
            ResOperation(rop.UINT_LE, [v11, v1], v12),
            ResOperation(rop.INT_AND, [v11, ConstInt(31)], tmp17),
            ResOperation(rop.UINT_RSHIFT, [v12, tmp17], v13),
            ResOperation(rop.INT_NE, [v3, v2], v14),
            ResOperation(rop.INT_NE, [ConstInt(1), v11], v15),
            ResOperation(rop.INT_NE, [ConstInt(23), v15], v16),
            ResOperation(rop.GUARD_FALSE, [v15], None, descr=faildescr2),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr3),
            ]
        operations[1].setfailargs([v6, v8, v1, v4])
        operations[8].setfailargs([v5, v9])
        operations[-1].setfailargs([v4, v10, v6, v5, v9, v7])
        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [-8 , 0 , 62 , 35 , 16 , 9 , 30 , 581610154 , -1 , 738197503]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_latest_descr(deadframe).identifier == 2
        assert cpu.get_int_value(deadframe, 0) == 16
        assert cpu.get_int_value(deadframe, 1) == -1

    def test_wrong_guard3(self):
        # random seed: 8029
        # block length: 10
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        faildescr3 = BasicFailDescr(3)
        faildescr4 = BasicFailDescr(4)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        v15 = BoxInt()
        v16 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.UINT_LT, [ConstInt(-11), v7], v11),
            ResOperation(rop.INT_GE, [v3, v5], v12),
            ResOperation(rop.INT_INVERT, [v9], v13),
            ResOperation(rop.GUARD_VALUE, [v13, ConstInt(14)], None, descr=faildescr3),
            ResOperation(rop.INT_IS_ZERO, [v12], v14),
            ResOperation(rop.INT_SUB, [v2, v13], v15),
            ResOperation(rop.GUARD_VALUE, [v15, ConstInt(-32)], None, descr=faildescr4),
            ResOperation(rop.INT_FLOORDIV, [v3, ConstInt(805306366)], v16),
            ResOperation(rop.GUARD_VALUE, [v15, ConstInt(0)], None, descr=faildescr1),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr2),
            ]
        operations[3].setfailargs([])
        operations[-4].setfailargs([v15])
        operations[-2].setfailargs([v9, v4, v10, v11, v14])
        operations[-1].setfailargs([v10, v8, v1, v6, v4])
        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [-39 , -18 , 1588243114 , -9 , -4 , 1252698794 , 0 , 715827882 , -15 , 536870912]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_latest_descr(deadframe).identifier == 1
        assert cpu.get_int_value(deadframe, 0) == -15
        assert cpu.get_int_value(deadframe, 1) == -9
        assert cpu.get_int_value(deadframe, 2) == 536870912
        assert cpu.get_int_value(deadframe, 3) == 0
        assert cpu.get_int_value(deadframe, 4) == 0

    def test_wrong_result(self):
        # generated by:
        # ../test/ test/test_zll_random.py -l -k arm -s --block-length=10 --random-seed=7389
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        faildescr3 = BasicFailDescr(3)
        faildescr4 = BasicFailDescr(4)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        v15 = BoxInt()
        tmp16 = BoxInt()
        tmp17 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_IS_TRUE, [v3], tmp16),
            ResOperation(rop.GUARD_TRUE, [tmp16], None, descr=faildescr1),
            ResOperation(rop.INT_AND, [v7, ConstInt(31)], tmp17),
            ResOperation(rop.INT_RSHIFT, [v5, tmp17], v11),
            ResOperation(rop.INT_OR, [v6, v8], v12),
            ResOperation(rop.GUARD_VALUE, [v11, ConstInt(-2)], None, descr=faildescr2),
            ResOperation(rop.INT_LE, [ConstInt(1789569706), v10], v13),
            ResOperation(rop.INT_IS_TRUE, [v4], v14),
            ResOperation(rop.INT_XOR, [v14, v3], v15),
            ResOperation(rop.GUARD_VALUE, [v8, ConstInt(-8)], None, descr=faildescr3),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr4),
            ]
        operations[1].setfailargs([v9, v1])
        operations[5].setfailargs([v10, v2, v11, v3])
        operations[9].setfailargs([v5, v7, v12, v14, v2, v13, v8])
        operations[-1].setfailargs([v1, v2, v9])
        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [0 , -2 , 24 , 1 , -4 , 13 , -95 , 33 , 2 , -44]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_latest_descr(deadframe).identifier == 3
        assert cpu.get_int_value(deadframe, 0) == -4
        assert cpu.get_int_value(deadframe, 1) == -95
        assert cpu.get_int_value(deadframe, 2) == 45
        assert cpu.get_int_value(deadframe, 3) == 1
        assert cpu.get_int_value(deadframe, 4) == -2
        assert cpu.get_int_value(deadframe, 5) == 0
        assert cpu.get_int_value(deadframe, 6) == 33

    def test_int_add(self):
        # random seed: 1202
        # block length: 4
        # AssertionError: Got 1431655764, expected 357913940 for value #3
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        tmp12 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_ADD, [ConstInt(-1073741825), v3], v11),
            ResOperation(rop.INT_IS_TRUE, [v1], tmp12),
            ResOperation(rop.GUARD_FALSE, [tmp12], None, descr=faildescr1),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=faildescr2),
            ]
        operations[2].setfailargs([v10, v3, v6, v11, v9, v2])
        operations[-1].setfailargs([v8, v2, v10, v6, v7, v9, v5, v4])
        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [3 , -5 , 1431655765 , 47 , 12 , 1789569706 , 15 , 939524096 , 16 , -43]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_latest_descr(deadframe).identifier == 1
        assert cpu.get_int_value(deadframe, 0) == -43
        assert cpu.get_int_value(deadframe, 1) == 1431655765
        assert cpu.get_int_value(deadframe, 2) == 1789569706
        assert cpu.get_int_value(deadframe, 3) == 357913940
        assert cpu.get_int_value(deadframe, 4) == 16
        assert cpu.get_int_value(deadframe, 5) == -5

    def test_wrong_result2(self):
        # block length 10
        # random seed 1
        f1 = BasicFailDescr(1)
        f2 = BasicFailDescr(2)
        f3 = BasicFailDescr(3)
        v1 = BoxInt()
        v2 = BoxInt()
        v3 = BoxInt()
        v4 = BoxInt()
        v5 = BoxInt()
        v6 = BoxInt()
        v7 = BoxInt()
        v8 = BoxInt()
        v9 = BoxInt()
        v10 = BoxInt()
        v11 = BoxInt()
        v12 = BoxInt()
        v13 = BoxInt()
        v14 = BoxInt()
        v15 = BoxInt()
        cpu = CPU(None, None)
        cpu.setup_once()
        inputargs = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10]
        operations = [
            ResOperation(rop.INT_LE, [v6, v1], v11),
            ResOperation(rop.SAME_AS, [ConstInt(-14)], v12),
            ResOperation(rop.INT_ADD, [ConstInt(24), v4], v13),
            ResOperation(rop.UINT_RSHIFT, [v6, ConstInt(0)], v14),
            ResOperation(rop.GUARD_VALUE, [v14, ConstInt(1)], None, descr=f3),
            ResOperation(rop.INT_MUL, [v13, ConstInt(12)], v15),
            ResOperation(rop.GUARD_FALSE, [v11], None, descr=f1),
            ResOperation(rop.GUARD_FALSE, [v1], None, descr=f2),
            ]
        operations[-2].setfailargs([v4, v10, v3, v9, v14, v2])
        operations[-1].setfailargs([v2, v3, v5, v7, v10, v8, v9])
        operations[4].setfailargs([v14])
        looptoken = JitCellToken()
        cpu.compile_loop(inputargs, operations, looptoken)
        args = [14 , -20 , 18 , -2058005163 , 6 , 1 , -16 , 11 , 0 , 19]
        deadframe = cpu.execute_token(looptoken, *args)
        assert cpu.get_latest_descr(deadframe).identifier == 1
        assert cpu.get_int_value(deadframe, 0) == -2058005163
        assert cpu.get_int_value(deadframe, 1) == 19
        assert cpu.get_int_value(deadframe, 2) == 18
        assert cpu.get_int_value(deadframe, 3) == 0
        assert cpu.get_int_value(deadframe, 4) == 1
        assert cpu.get_int_value(deadframe, 5) == -20
