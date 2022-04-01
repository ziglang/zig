import py
import sys
import pytest
import platform

from rpython.jit.metainterp.optimizeopt.renamer import Renamer
from rpython.jit.metainterp.optimizeopt.vector import (
    VecScheduleState, Pack, Pair, VectorizingOptimizer, GenericCostModel,
    PackSet, SchedulerState)
from rpython.jit.backend.llsupport.vector_ext import VectorExt
from rpython.jit.metainterp.optimizeopt.dependency import DependencyGraph
from rpython.jit.metainterp.optimizeopt.schedule import Scheduler
from rpython.jit.metainterp.optimizeopt.test.test_dependency import (
    DependencyBaseTest)
from rpython.jit.metainterp.optimizeopt.test.test_vecopt import (
    FakeJitDriverStaticData, FakePackSet)
from rpython.jit.metainterp.resoperation import (
    rop, ResOperation, VectorizationInfo)

if sys.maxint == 2 ** 31 - 1:
    pytest.skip("32bit platforms are not supported")

class FakeVecScheduleState(VecScheduleState):
    def __init__(self):
        self.expanded_map = {}


class SchedulerBaseTest(DependencyBaseTest):

    def setup_class(self):
        self.namespace = {
            'double': self.floatarraydescr,
            'float': self.float32arraydescr,
            'long': self.arraydescr,
            'int': self.int32arraydescr,
            'short': self.int16arraydescr,
            'char': self.chararraydescr,
        }

    def setup_method(self, name):
        self.vector_ext = VectorExt()
        self.vector_ext.enable(16, True)

    def pack(self, loop, l, r, input_type=None, output_type=None):
        return Pack(loop.graph.nodes[l:r])

    def schedule(self, loop, packs, vec_reg_size=16,
                 prepend_invariant=False, overwrite_funcs=None):
        cm = GenericCostModel(self.cpu, 0)
        cm.profitable = lambda: True
        pairs = []
        for pack in packs:
            for i in range(len(pack.operations)-1):
                o1 = pack.operations[i]
                o2 = pack.operations[i+1]
                pair = Pair(o1,o2)
                pairs.append(pair)
        packset = FakePackSet(pairs)
        state = VecScheduleState(loop.graph, packset, self.cpu, cm)
        for name, overwrite in (overwrite_funcs or {}).items():
            setattr(state, name, overwrite)
        renamer = Renamer()
        jitdriver_sd = FakeJitDriverStaticData()
        opt = VectorizingOptimizer(self.metainterp_sd, jitdriver_sd, 0)
        opt.packset = packset
        opt.combine_packset()
        opt.schedule(state)
        # works for now. might be the wrong class?
        # wrap label + operations + jump it in tree loop otherwise
        loop = state.graph.loop
        if prepend_invariant:
            loop.operations = loop.prefix + loop.operations
        return loop

class TestScheduler(SchedulerBaseTest):

    def test_next_must_not_loop_forever(self):
        scheduler = Scheduler()
        def delay(node, state):
            node.count += 1
            return True
        scheduler.delay = delay
        class State(object): pass
        class Node(object): emitted = False; pack = None; count = 0
        state = State()
        state.worklist = [Node(), Node(), Node(), Node(), Node()]
        assert scheduler.next(state) is None
        for node in state.worklist:
            assert node.count == 1
        # must return here, then the test passed

    def test_split_pack(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=double)
        f11 = raw_load_f(p0, i1, descr=double)
        f12 = raw_load_f(p0, i2, descr=double)
        """)
        ps = PackSet(16)
        ps.packs = [self.pack(loop1, 0, 3)]
        op1 = ps.packs[0].operations[0]
        op2 = ps.packs[0].operations[1]
        ps.split_overloaded_packs(self.vector_ext)
        assert len(ps.packs) == 1
        assert ps.packs[0].leftmost() is op1.getoperation()
        assert ps.packs[0].rightmost() is op2.getoperation()

    def test_schedule_split_load(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=float)
        f11 = raw_load_f(p0, i1, descr=float)
        f12 = raw_load_f(p0, i2, descr=float)
        f13 = raw_load_f(p0, i3, descr=float)
        f14 = raw_load_f(p0, i4, descr=float)
        f15 = raw_load_f(p0, i5, descr=float)
        """)
        pack1 = self.pack(loop1, 0, 6)
        loop2 = self.schedule(loop1, [pack1])
        loop3 = self.parse_trace("""
        v10[4xi32] = vec_load_f(p0, i0, 1, 0, descr=float)
        f10 = raw_load_f(p0, i4, descr=float)
        f11 = raw_load_f(p0, i5, descr=float)
        """, False)
        self.assert_equal(loop2, loop3)

    @py.test.mark.skipif("not platform.machine().startswith('x86')")
    def test_int_to_float(self):
        loop1 = self.parse_trace("""
        i10 = raw_load_i(p0, i0, descr=long)
        i11 = raw_load_i(p0, i1, descr=long)
        i12 = int_signext(i10, 4)
        i13 = int_signext(i11, 4)
        f10 = cast_int_to_float(i12)
        f11 = cast_int_to_float(i13)
        """)
        pack1 = self.pack(loop1, 0, 2)
        pack2 = self.pack(loop1, 2, 4)
        pack3 = self.pack(loop1, 4, 6)
        loop2 = self.schedule(loop1, [pack1, pack2, pack3])
        loop3 = self.parse_trace("""
        v10[2xi64] = vec_load_i(p0, i0, 1, 0, descr=long)
        v20[2xi32] = vec_int_signext(v10[2xi64], 4)
        v30[2xf64] = vec_cast_int_to_float(v20[2xi32])
        """, False)
        self.assert_equal(loop2, loop3)

    def test_scalar_pack(self):
        loop1 = self.parse_trace("""
        i10 = int_add(i0, 73)
        i11 = int_add(i1, 73)
        """)
        pack1 = self.pack(loop1, 0, 2)
        loop2 = self.schedule(loop1, [pack1], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v10[0xi64] = vec_i()
        v20[1xi64] = vec_pack_i(v10[2xi64], i0, 0, 1)
        v30[2xi64] = vec_pack_i(v20[2xi64], i1, 1, 1)
        v40[2xi64] = vec_expand_i(73)
        #
        v50[2xi64] = vec_int_add(v30[2xi64], v40[2xi64])
        """, False)
        self.assert_equal(loop2, loop3)

        loop1 = self.parse_trace("""
        f10 = float_add(f0, 73.0)
        f11 = float_add(f1, 73.0)
        """)
        pack1 = self.pack(loop1, 0, 2)
        loop2 = self.schedule(loop1, [pack1], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v10[0xf64] = vec_f()
        v20[1xf64] = vec_pack_f(v10[2xf64], f0, 0, 1)
        v30[2xf64] = vec_pack_f(v20[2xf64], f1, 1, 1)
        v40[2xf64] = vec_expand_f(73.0)
        #
        v50[2xf64] = vec_float_add(v30[2xf64], v40[2xf64])
        """, False)
        self.assert_equal(loop2, loop3)

    def test_scalar_remember_expansion(self):
        loop1 = self.parse_trace("""
        f10 = float_add(f0, f5)
        f11 = float_add(f1, f5)
        f12 = float_add(f10, f5)
        f13 = float_add(f11, f5)
        """)
        pack1 = self.pack(loop1, 0, 2)
        pack2 = self.pack(loop1, 2, 4)
        loop2 = self.schedule(loop1, [pack1, pack2], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v10[0xf64] = vec_f()
        v20[1xf64] = vec_pack_f(v10[2xf64], f0, 0, 1)
        v30[2xf64] = vec_pack_f(v20[2xf64], f1, 1, 1)
        v40[2xf64] = vec_expand_f(f5) # only expaned once
        #
        v50[2xf64] = vec_float_add(v30[2xf64], v40[2xf64])
        v60[2xf64] = vec_float_add(v50[2xf64], v40[2xf64])
        """, False)
        self.assert_equal(loop2, loop3)

    def find_input_arg(self, name, loop):
        for arg in loop.inputargs:
            if str(arg).startswith(name):
                return arg
        raise Exception("could not find %s in args %s" % (name, loop.inputargs))

    def test_signext_int32(self):
        loop1 = self.parse_trace("""
        i10 = int_signext(i1, 4)
        i11 = int_signext(i1, 4)
        """, additional_args=['v10[2xi64]'])
        pack1 = self.pack(loop1, 0, 2)
        var = loop1.inputargs[-1]
        vi = VectorizationInfo(None)
        vi.datatype = 'i'
        vi.bytesize = 8
        vi.count = 2
        vi.signed = True
        var.set_forwarded(vi)
        loop2 = self.schedule(loop1, [pack1], prepend_invariant=True,
                              overwrite_funcs = {
                                'getvector_of_box': lambda v: (0, var),
                              })
        loop3 = self.parse_trace("""
        v11[2xi32] = vec_int_signext(v10[2xi64], 4)
        """, False, additional_args=['v10[2xi64]'])
        self.assert_equal(loop2, loop3)

    @py.test.mark.skipif("not platform.machine().startswith('x86')")
    def test_cast_float_to_int(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i1, descr=double)
        f11 = raw_load_f(p0, i2, descr=double)
        f12 = raw_load_f(p0, i3, descr=double)
        f13 = raw_load_f(p0, i4, descr=double)
        f14 = raw_load_f(p0, i5, descr=double)
        f15 = raw_load_f(p0, i6, descr=double)
        f16 = raw_load_f(p0, i7, descr=double)
        f17 = raw_load_f(p0, i8, descr=double)
        #
        i10 = cast_float_to_int(f10)
        i11 = cast_float_to_int(f11)
        i12 = cast_float_to_int(f12)
        i13 = cast_float_to_int(f13)
        i14 = cast_float_to_int(f14)
        i15 = cast_float_to_int(f15)
        i16 = cast_float_to_int(f16)
        i17 = cast_float_to_int(f17)
        #
        i18 = int_signext(i10, 2)
        i19 = int_signext(i11, 2)
        i20 = int_signext(i12, 2)
        i21 = int_signext(i13, 2)
        i22 = int_signext(i14, 2)
        i23 = int_signext(i15, 2)
        i24 = int_signext(i16, 2)
        i25 = int_signext(i17, 2)
        #
        raw_store(p1, i1, i18, descr=short)
        raw_store(p1, i2, i19, descr=short)
        raw_store(p1, i3, i20, descr=short)
        raw_store(p1, i4, i21, descr=short)
        raw_store(p1, i5, i22, descr=short)
        raw_store(p1, i6, i23, descr=short)
        raw_store(p1, i7, i24, descr=short)
        raw_store(p1, i8, i25, descr=short)
        """)
        pack1 = self.pack(loop1, 0, 8)
        pack2 = self.pack(loop1, 8, 16)
        pack3 = self.pack(loop1, 16, 24)
        pack4 = self.pack(loop1, 24, 32)
        def void(b,c):
            pass
        loop2 = self.schedule(loop1, [pack1,pack2,pack3,pack4],
                              overwrite_funcs={
                                  '_prevent_signext': void
                              })
        loop3 = self.parse_trace("""
        v10[2xf64] = vec_load_f(p0, i1, 1, 0, descr=double)
        v11[2xf64] = vec_load_f(p0, i3, 1, 0, descr=double)
        v12[2xf64] = vec_load_f(p0, i5, 1, 0, descr=double)
        v13[2xf64] = vec_load_f(p0, i7, 1, 0, descr=double)
        v14[2xi32] = vec_cast_float_to_int(v10[2xf64])
        v15[2xi32] = vec_cast_float_to_int(v11[2xf64])
        v16[2xi32] = vec_cast_float_to_int(v12[2xf64])
        v17[2xi32] = vec_cast_float_to_int(v13[2xf64])
        v22[4xi32] = vec_pack_i(v14[2xi32], v15[2xi32], 2, 2)
        v18[4xi16] = vec_int_signext(v22[4xi32],2)
        v23[6xi16] = vec_pack_i(v16[2xi32], v17[2xi32], 2, 2)
        v20[4xi16] = vec_int_signext(v23[4xi32],2)
        v24[8xi16] = vec_pack_i(v18[4xi16], v20[4xi16], 4, 4)
        vec_store(p1, i1, v24[8xi16], 1, 0, descr=short)
        """, False)
        self.assert_equal(loop2, loop3)

    def test_cast_float_to_single_float(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i1, descr=double)
        f11 = raw_load_f(p0, i2, descr=double)
        f12 = raw_load_f(p0, i3, descr=double)
        f13 = raw_load_f(p0, i4, descr=double)
        #
        i10 = cast_float_to_singlefloat(f10)
        i11 = cast_float_to_singlefloat(f11)
        i12 = cast_float_to_singlefloat(f12)
        i13 = cast_float_to_singlefloat(f13)
        #
        raw_store(p1, i1, i10, descr=float)
        raw_store(p1, i2, i11, descr=float)
        raw_store(p1, i3, i12, descr=float)
        raw_store(p1, i4, i13, descr=float)
        """)
        pack1 = self.pack(loop1, 0, 4)
        pack2 = self.pack(loop1, 4, 8)
        pack3 = self.pack(loop1, 8, 12)
        loop2 = self.schedule(loop1, [pack1,pack2,pack3])
        loop3 = self.parse_trace("""
        v44[2xf64] = vec_load_f(p0, i1, 1, 0, descr=double)
        v45[2xf64] = vec_load_f(p0, i3, 1, 0, descr=double)
        v46[2xi32] = vec_cast_float_to_singlefloat(v44[2xf64])
        v47[2xi32] = vec_cast_float_to_singlefloat(v45[2xf64])
        v41[4xi32] = vec_pack_i(v46[2xi32], v47[2xi32], 2, 2)
        vec_store(p1, i1, v41[4xi32], 1, 0, descr=float)
        """, False)
        self.assert_equal(loop2, loop3)

    def test_all(self):
        loop1 = self.parse_trace("""
        i10 = raw_load_i(p0, i1, descr=long)
        i11 = raw_load_i(p0, i2, descr=long)
        #
        i12 = int_and(i10, 255)
        i13 = int_and(i11, 255)
        #
        guard_true(i12) []
        guard_true(i13) []
        """)
        pack1 = self.pack(loop1, 0, 2)
        pack2 = self.pack(loop1, 2, 4)
        pack3 = self.pack(loop1, 4, 6)
        loop2 = self.schedule(loop1, [pack1,pack2,pack3], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v9[2xi64] = vec_expand_i(255)
        v10[2xi64] = vec_load_i(p0, i1, 1, 0, descr=long)
        v11[2xi64] = vec_int_and(v10[2xi64], v9[2xi64])
        vec_guard_true(v11[2xi64]) []
        """, False)
        self.assert_equal(loop2, loop3)

    def test_split_load_store(self):
        loop1 = self.parse_trace("""
        i10 = raw_load_i(p0, i1, descr=float)
        i11 = raw_load_i(p0, i2, descr=float)
        i12 = raw_load_i(p0, i3, descr=float)
        i13 = raw_load_i(p0, i4, descr=float)
        raw_store(p0, i3, i10, descr=float)
        raw_store(p0, i4, i11, descr=float)
        """)
        pack1 = self.pack(loop1, 0, 4)
        pack2 = self.pack(loop1, 4, 6)
        loop2 = self.schedule(loop1, [pack1,pack2], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v1[4xi32] = vec_load_i(p0, i1, 1, 0, descr=float)
        i10 = vec_unpack_i(v1[4xi32], 0, 1)
        raw_store(p0, i3, i10, descr=float)
        i11 = vec_unpack_i(v1[4xi32], 1, 1)
        raw_store(p0, i4, i11, descr=float)
        """, False)
        # unfortunate ui32 is the type for float32... the unsigned u is for
        # the tests
        self.assert_equal(loop2, loop3)

    def test_split_arith(self):
        loop1 = self.parse_trace("""
        i10 = int_and(255, i1)
        i11 = int_and(255, i1)
        """)
        pack1 = self.pack(loop1, 0, 2)
        loop2 = self.schedule(loop1, [pack1], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v1[2xi64] = vec_expand_i(255)
        v2[2xi64] = vec_expand_i(i1)
        v3[2xi64] = vec_int_and(v1[2xi64], v2[2xi64])
        """, False)
        self.assert_equal(loop2, loop3)

    def test_split_arith(self):
        loop1 = self.parse_trace("""
        i10 = int_and(255, i1)
        i11 = int_and(255, i1)
        """)
        pack1 = self.pack(loop1, 0, 2)
        loop2 = self.schedule(loop1, [pack1], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v1[2xi64] = vec_expand_i(255)
        v2[2xi64] = vec_expand_i(i1)
        v3[2xi64] = vec_int_and(v1[2xi64], v2[2xi64])
        """, False)
        self.assert_equal(loop2, loop3)

    def test_no_vec_impl(self):
        loop1 = self.parse_trace("""
        i10 = int_and(255, i1)
        i11 = int_and(255, i2)
        i12 = call_pure_i(321, i10)
        i13 = call_pure_i(321, i11)
        i14 = int_and(i1, i12)
        i15 = int_and(i2, i13)
        """)
        pack1 = self.pack(loop1, 0, 2)
        pack4 = self.pack(loop1, 4, 6)
        loop2 = self.schedule(loop1, [pack1,pack4], prepend_invariant=True)
        loop3 = self.parse_trace("""
        v1[2xi64] = vec_expand_i(255)
        v2[0xi64] = vec_i()
        v3[1xi64] = vec_pack_i(v2[2xi64], i1, 0, 1)
        v4[2xi64] = vec_pack_i(v3[2xi64], i2, 1, 1)
        v5[2xi64] = vec_int_and(v1[2xi64], v4[2xi64])
        i10 = vec_unpack_i(v5[2xi64], 0, 1)
        i12 = call_pure_i(321, i10)
        i11 = vec_unpack_i(v5[2xi64], 1, 1)
        i13 = call_pure_i(321, i11)
        v6[0xi64] = vec_i()
        v7[1xi64] = vec_pack_i(v6[2xi64], i12, 0, 1)
        v8[2xi64] = vec_pack_i(v7[2xi64], i13, 1, 1)
        v9[2xi64] = vec_int_and(v4[2xi64], v8[i64])
        """, False)
        self.assert_equal(loop2, loop3)

    def test_split_cast(self):
        trace = self.parse_trace("""
        f10 = cast_int_to_float(i1)
        f11 = cast_int_to_float(i2)
        f12 = cast_int_to_float(i3)
        f13 = cast_int_to_float(i4)
        """)
        pack = self.pack(trace, 0, 4)
        packs = []
        pack.split(packs, 16, self.vector_ext)
        packs.append(pack)
        assert len(packs) == 2

    def test_combine_packset_nearly_empty_pack(self):
        trace = self.parse_trace("""
        i10 = int_add(i1, i1)
        i11 = int_add(i2, i2)
        i12 = int_add(i3, i3)
        """)
        pack = self.pack(trace, 0, 2)
        packset = FakePackSet([pack])
        packset.split_overloaded_packs(self.vector_ext)
        assert len(packset.packs) == 1

    def test_expand(self):
        state = FakeVecScheduleState()
        assert state.find_expanded([]) == None
        state.expand(['a'], 'a')
        assert state.find_expanded(['a']) == 'a'
        state.expand(['a','b','c'], 'abc')
        assert state.find_expanded(['a','b','c']) == 'abc'
        state.expand(['a','d','c'], 'adc')
        assert state.find_expanded(['a','b','c']) == 'abc'
        assert state.find_expanded(['a','d','c']) == 'adc'
        assert state.find_expanded(['d','d','c']) == None
        state.expand(['d','d','c'], 'ddc')
        assert state.find_expanded(['d','d','c']) == 'ddc'

    def test_delayed_schedule(self):
        loop = self.parse("""
        [i0]
        i1 = int_add(i0,1)
        i2 = int_add(i0,1)
        jump(i2)
        """)
        loop.prefix_label = None
        loop.label = ResOperation(rop.LABEL, loop.inputargs)
        ops = loop.operations
        loop.operations = ops[:-1]
        loop.jump = ops[-1]
        state = SchedulerState(self.cpu, DependencyGraph(loop))
        state.schedule()
        assert len(loop.operations) == 1
