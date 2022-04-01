import py

from rpython.jit.metainterp.optimizeopt.util import equaloplists
from rpython.jit.metainterp.optimizeopt.vector import (
    GenericCostModel, NotAProfitableLoop, VectorizingOptimizer, CostModel)
from rpython.jit.metainterp.optimizeopt.schedule import VecScheduleState
from rpython.jit.metainterp.optimizeopt.dependency import DependencyGraph
from rpython.jit.metainterp.optimizeopt.test.test_schedule import SchedulerBaseTest
from rpython.jit.metainterp.optimizeopt.test.test_vecopt import (
    FakeJitDriverStaticData)

class FakeMemoryRef(object):
    def __init__(self, array, iv):
        self.index_var = iv
        self.array = array

    def is_adjacent_after(self, other):
        if self.array is not other.array:
            return False
        iv = self.index_var
        ov = other.index_var
        val = (int(str(ov.var)[1:]) - int(str(iv.var)[1:]))
        # i0 and i1 are adjacent
        # i1 and i0 ...
        # but not i0, i2
        # ...
        #print iv, 'is after', ov, "?", val == 1
        return val == 1

def prepost_savings(orig_func):
    def func(self, *args):
        f = getattr(self.proxy, orig_func.__name__)
        before_savings = self.proxy.savings
        r = f(*args)
        after_savings = self.proxy.savings
        print " CM %s (%d -> %d, diff: %d) " % (orig_func.__name__,
              before_savings, after_savings,
              (after_savings - before_savings),)
        print " args: ", args
        return r
    return func

class FakeCostModel(CostModel):
    def __init__(self, proxy):
        self.proxy = proxy

    def getsavings(self):
        return self.proxy.savings

    @prepost_savings
    def reset_savings(self):
        raise NotImplementedError

    @prepost_savings
    def record_cast_int(self, op):
        raise NotImplementedError

    @prepost_savings
    def record_pack_savings(self, pack, times):
        raise NotImplementedError

    @prepost_savings
    def record_vector_pack(self, box, index, count):
        raise NotImplementedError

    @prepost_savings
    def record_vector_unpack(self, box, index, count):
        raise NotImplementedError

    @prepost_savings
    def unpack_cost(self, op, index, count):
        raise NotImplementedError

    @prepost_savings
    def savings_for_pack(self, pack, times):
        raise NotImplementedError

    def profitable(self):
        return self.proxy.savings >= 0

class TestCostModel(SchedulerBaseTest):
    def savings(self, loop):
        jitdriver_sd = FakeJitDriverStaticData()
        opt = VectorizingOptimizer(self.metainterp_sd, jitdriver_sd, 0)
        opt.orig_label_args = loop.label.getarglist()[:]
        graph = opt.dependency_graph = DependencyGraph(loop)
        self.show_dot_graph(graph, 'costmodel')
        for k, m in graph.memory_refs.items():
            graph.memory_refs[k] = FakeMemoryRef(m.array, m.index_var)
        opt.find_adjacent_memory_refs(graph)
        opt.extend_packset()
        opt.combine_packset()
        for pack in opt.packset.packs:
            print "pack: \n   ",
            print '\n    '.join([str(op.getoperation()) for op in pack.operations])
            print
        costmodel = FakeCostModel(GenericCostModel(self.cpu, 0))
        costmodel.reset_savings()
        state = VecScheduleState(graph, opt.packset, self.cpu, costmodel)
        opt.schedule(state)
        return costmodel.getsavings()

    def assert_operations_match(self, loop_a, loop_b):
        assert equaloplists(loop_a.operations, loop_b.operations)

    def test_load_2_unpack(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=double)
        f11 = raw_load_f(p0, i1, descr=double)
        guard_true(i0) [f10]
        guard_true(i1) [f11]
        """)
        # for double the costs are
        # unpack index 1 savings: -2
        # unpack index 0 savings: -1
        savings = self.savings(loop1)
        assert savings == -2

    def test_load_4_unpack(self):
        loop1 = self.parse_trace("""
        i10 = raw_load_i(p0, i0, descr=float)
        i11 = raw_load_i(p0, i1, descr=float)
        i12 = raw_load_i(p0, i2, descr=float)
        i13 = raw_load_i(p0, i3, descr=float)
        guard_true(i0) [i10]
        guard_true(i1) [i11]
        guard_true(i2) [i12]
        guard_true(i3) [i13]
        """)
        savings = self.savings(loop1)
        assert savings == -1

    def test_load_2_unpack_1(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=double)
        f11 = raw_load_f(p0, i1, descr=double)
        guard_true(i0) [f10]
        """)
        assert loop1.operations[2].getfailargs()[0] is loop1.operations[0]
        savings = self.savings(loop1)
        assert savings == 0
        assert loop1.operations[2].getfailargs()[0] is loop1.operations[-2]

    def test_load_2_unpack_1_index1(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=double)
        f11 = raw_load_f(p0, i1, descr=double)
        guard_true(i0) [f11]
        """)
        savings = self.savings(loop1)
        assert savings == -1

    def test_load_arith1(self):
        loop1 = self.parse_trace("""
        i10 = raw_load_i(p0, i0, descr=int)
        i11 = raw_load_i(p0, i1, descr=int)
        i12 = raw_load_i(p0, i2, descr=int)
        i13 = raw_load_i(p0, i3, descr=int)
        i15 = int_add(i10, 1)
        i16 = int_add(i11, 1)
        i17 = int_add(i12, 1)
        i18 = int_add(i13, 1)
        """)
        savings = self.savings(loop1)
        assert savings == 6

    def test_load_arith_store(self):
        import platform
        size = 4
        if not platform.machine().startswith('x86'):
            size = 8
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=double)
        f11 = raw_load_f(p0, i1, descr=double)
        i20 = cast_float_to_int(f10)
        i21 = cast_float_to_int(f11)
        i30 = int_signext(i20, {size})
        i31 = int_signext(i21, {size})
        raw_store(p0, i3, i30, descr=int)
        raw_store(p0, i4, i31, descr=int)
        """.format(size=size))
        savings = self.savings(loop1)
        assert savings >= 0

    def test_sum(self):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=double)
        f11 = raw_load_f(p0, i1, descr=double)
        f12 = float_add(f1, f10)
        f13 = float_add(f12, f11)
        """)
        savings = self.savings(loop1)
        assert savings == -2

    @py.test.mark.parametrize("bytes,s", [(4,0),(8,0)])
    def test_sum_float_to_int(self, bytes, s):
        loop1 = self.parse_trace("""
        f10 = raw_load_f(p0, i0, descr=double)
        f11 = raw_load_f(p0, i1, descr=double)
        i10 = cast_float_to_int(f10)
        i11 = cast_float_to_int(f11)
        i12 = int_signext(i10, {c})
        i13 = int_signext(i11, {c})
        i14 = int_add(i1, i12)
        i16 = int_signext(i14, {c})
        i15 = int_add(i16, i13)
        i17 = int_signext(i15, {c})
        """.format(c=bytes))
        try:
            savings = self.savings(loop1)
            if s is None:
                py.test.fail("must fail")
            # it does not benefit because signext has
            # a very inefficient implementation (x86
            # does not provide nice instr to convert
            # integer sizes)
            # signext -> no benefit, + 2x unpack
            assert savings <= s
        except NotAProfitableLoop:
            if s is not None:
                py.test.fail("must not fail")

    def test_cast(self):
        loop1 = self.parse_trace("""
        i100 = raw_load_i(p0, i1, descr=float)
        i101 = raw_load_i(p0, i2, descr=float)
        i102 = raw_load_i(p0, i3, descr=float)
        i103 = raw_load_i(p0, i4, descr=float)
        #
        i104 = raw_load_i(p1, i1, descr=short)
        i105 = raw_load_i(p1, i2, descr=short)
        i106 = raw_load_i(p1, i3, descr=short)
        i107 = raw_load_i(p1, i4, descr=short)
        i108 = raw_load_i(p1, i5, descr=short)
        i109 = raw_load_i(p1, i6, descr=short)
        i110 = raw_load_i(p1, i7, descr=short)
        i111 = raw_load_i(p1, i8, descr=short)
        #
        f100 = cast_int_to_float(i104)
        f101 = cast_int_to_float(i105)
        f102 = cast_int_to_float(i106)
        f103 = cast_int_to_float(i107)
        f104 = cast_int_to_float(i108)
        f105 = cast_int_to_float(i109)
        f106 = cast_int_to_float(i110)
        f107 = cast_int_to_float(i111)
        """)
        try:
            self.savings(loop1)
            py.test.fail("must not be profitable!")
        except NotAProfitableLoop:
            pass

    def test_force_int_to_float_cast(self):
        trace = self.parse_trace("""
        i10 = raw_load_i(p0, i1, descr=long)
        i11 = raw_load_i(p0, i2, descr=long)
        f10 = cast_int_to_float(i10)
        f11 = cast_int_to_float(i11)
        """)
        number = self.savings(trace)
        assert number >= 1
