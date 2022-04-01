import py
import sys
import pytest

from rpython.jit.metainterp.optimizeopt.test.test_dependency import DependencyBaseTest
from rpython.jit.metainterp.optimizeopt.vector import (VectorizingOptimizer,
        MemoryRef, isomorphic, Pair, NotAVectorizeableLoop,
        NotAProfitableLoop, GuardStrengthenOpt, CostModel, GenericCostModel,
        PackSet, optimize_vector)
from rpython.jit.metainterp.optimizeopt.schedule import (Scheduler,
        SchedulerState, VecScheduleState, Pack)
from rpython.jit.metainterp.optimizeopt.optimizer import BasicLoopInfo
from rpython.jit.metainterp.resoperation import rop, ResOperation
from rpython.jit.metainterp.optimizeopt.version import LoopVersionInfo
from rpython.jit.backend.llsupport.descr import ArrayDescr
from rpython.jit.metainterp.optimizeopt.dependency import Node, DependencyGraph
from rpython.jit.backend.detect_cpu import getcpuclass

CPU = getcpuclass()

if sys.maxint == 2**31-1:
    pytest.skip("32bit platforms are not supported")

class FakeJitDriverStaticData(object):
    vec=True

class FakePackSet(PackSet):
    def __init__(self, packs):
        self.packs = packs
        self.vec_reg_size = 16

class FakeLoopInfo(LoopVersionInfo):
    def __init__(self, loop):
        self.target_token = loop.label.getdescr()
        self.label_op = loop.label
        self.insert_index = -1
        self.versions = []
        self.leads_to = {}
        self.descrs = []

class FakeCostModel(CostModel):
    def __init__(self, cpu):
        CostModel.__init__(self, cpu, 16)
    def record_cast_int(self): pass
    def record_pack_savings(self, pack, times): pass
    def record_vector_pack(self, box, index, count): pass
    def record_vector_unpack(self, box, index, count): pass
    def unpack_cost(self, op, index, count): pass
    def savings_for_pack(self, pack, times): pass
    def profitable(self):
        return True

def index_of_first(opnum, operations, pass_by=0):
    for i,op in enumerate(operations):
        if op.getopnum() == opnum:
            if pass_by == 0:
                return i
            else:
                pass_by -= 1
    return -1

def find_first_index(loop, opnum, pass_by=0):
    """ return the first index of the operation having the same opnum or -1 """
    return index_of_first(opnum, loop.operations, pass_by)

ARCH_VEC_REG_SIZE = 16

class FakeWarmState(object):
    vec_all = False
    vec_cost = 0


class VecTestHelper(DependencyBaseTest):

    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap"

    jitdriver_sd = FakeJitDriverStaticData()

    def assert_vectorize(self, loop, expected_loop, call_pure_results=None):
        jump = ResOperation(rop.JUMP, loop.jump.getarglist(), loop.jump.getdescr())
        warmstate = FakeWarmState()
        loop.operations += [loop.jump]
        loop_info = BasicLoopInfo(loop.jump.getarglist(), None, jump)
        loop_info.label_op = ResOperation(
            rop.LABEL, loop.jump.getarglist(), loop.jump.getdescr())
        optimize_vector(None, self.metainterp_sd, self.jitdriver_sd, warmstate,
                        loop_info, loop.operations)
        loop.operations = loop.operations[:-1]
        #loop.label = state[0].label_op
        #loop.operations = state[1]
        self.assert_equal(loop, expected_loop)

    def vectoroptimizer(self, loop):
        jitdriver_sd = FakeJitDriverStaticData()
        opt = VectorizingOptimizer(self.metainterp_sd, jitdriver_sd, 0)
        opt.orig_label_args = loop.label.getarglist()[:]
        return opt

    def earlyexit(self, loop):
        opt = self.vectoroptimizer(loop)
        graph = opt.analyse_index_calculations(loop)
        state = SchedulerState(self.cpu, graph)
        opt.schedule(state)
        return graph.loop

    def vectoroptimizer_unrolled(self, loop, unroll_factor=-1):
        opt = self.vectoroptimizer(loop)
        opt.linear_find_smallest_type(loop)
        loop.setup_vectorization()
        if unroll_factor == -1 and opt.smallest_type_bytes == 0:
            raise NotAVectorizeableLoop()
        if unroll_factor == -1:
            unroll_factor = opt.get_unroll_count(ARCH_VEC_REG_SIZE)
            print ""
            print "unroll factor: ", unroll_factor, opt.smallest_type_bytes
        self.show_dot_graph(DependencyGraph(loop), "original_" + self.test_name)
        graph = opt.analyse_index_calculations(loop)
        if graph is not None:
            cycle = graph.cycles()
            if cycle is not None:
                print "CYCLE found %s" % cycle
            self.show_dot_graph(graph, "early_exit_" + self.test_name)
            assert cycle is None
            state = SchedulerState(self.cpu, graph)
            opt.schedule(state)
        opt.unroll_loop_iterations(loop, unroll_factor)
        self.debug_print_operations(loop)
        graph = DependencyGraph(loop)
        self.last_graph = graph # legacy for test_dependency
        self.show_dot_graph(graph, self.test_name)
        def gmr(i):
            return graph.memory_refs[graph.nodes[i]]
        graph.getmemref = gmr
        return opt, graph

    def init_packset(self, loop, unroll_factor=-1):
        opt, graph = self.vectoroptimizer_unrolled(loop, unroll_factor)
        opt.find_adjacent_memory_refs(graph)
        return opt, graph

    def extend_packset(self, loop, unroll_factor=-1):
        opt, graph = self.vectoroptimizer_unrolled(loop, unroll_factor)
        opt.find_adjacent_memory_refs(graph)
        opt.extend_packset()
        return opt, graph

    def combine_packset(self, loop, unroll_factor=-1):
        opt, graph = self.vectoroptimizer_unrolled(loop, unroll_factor)
        opt.find_adjacent_memory_refs(graph)
        opt.extend_packset()
        opt.combine_packset()
        return opt, graph

    def schedule(self, loop, unroll_factor=-1, with_guard_opt=False):
        info = FakeLoopInfo(loop)
        info.snapshot(loop)
        opt, graph = self.vectoroptimizer_unrolled(loop, unroll_factor)
        opt.find_adjacent_memory_refs(graph)
        opt.extend_packset()
        opt.combine_packset()
        costmodel = FakeCostModel(self.cpu)
        state = VecScheduleState(graph, opt.packset, self.cpu, costmodel)
        opt.schedule(state)
        if with_guard_opt:
            gso = GuardStrengthenOpt(graph.index_vars)
            gso.propagate_all_forward(info, loop)
        # re-schedule
        graph = DependencyGraph(loop)
        state = SchedulerState(self.cpu, graph)
        state.prepare()
        Scheduler().walk_and_emit(state)
        state.post_schedule()
        return opt

    def vectorize(self, loop, unroll_factor=-1):
        info = FakeLoopInfo(loop)
        info.snapshot(loop)
        opt, graph = self.vectoroptimizer_unrolled(loop, unroll_factor)
        opt.find_adjacent_memory_refs(graph)
        opt.extend_packset()
        opt.combine_packset()
        costmodel = GenericCostModel(self.cpu, 0)
        state = VecScheduleState(graph, opt.packset, self.cpu, costmodel)
        opt.schedule(state)
        if not costmodel.profitable():
            raise NotAProfitableLoop()
        gso = GuardStrengthenOpt(graph.index_vars)
        gso.propagate_all_forward(info, loop)
        #
        # re-schedule
        graph = DependencyGraph(loop)
        state = SchedulerState(self.cpu, graph)
        state.prepare()
        Scheduler().walk_and_emit(state)
        state.post_schedule()
        #
        oplist = loop.operations

        loop.operations = loop.prefix[:]
        if loop.prefix_label:
            loop.operations += [loop.prefix_label]
        loop.operations += oplist
        return opt

    def assert_unroll_loop_equals(
            self, loop, expected_loop, unroll_factor=-1):
        self.vectoroptimizer_unrolled(loop, unroll_factor)
        self.assert_equal(loop, expected_loop)

    def assert_pack(self, pack, indices):
        assert len(pack.operations) == len(indices)
        for op, i in zip(pack.operations, indices):
            assert op.opidx == i

    def assert_has_pack_with(self, packset, opindices):
        for pack in packset.packs:
            for op, i in zip(pack.operations, opindices):
                if op.opidx != i:
                    break
            else:
                # found a pack that points to the specified operations
                break
        else:
            pytest.fail("could not find a packset that points to %s" % str(opindices))

    def assert_packset_empty(self, packset, instr_count, exceptions):
        for a,b in exceptions:
            self.assert_packset_contains_pair(packset, a, b)
        import itertools
        combintations = set(itertools.product(range(instr_count),
                                              range(instr_count)))
        combintations -= set(exceptions)
        for a,b in combintations:
            self.assert_packset_not_contains_pair(packset, a, b)

    def assert_packset_not_contains_pair(self, packset, x, y):
        for pack in packset.packs:
            if pack.leftmost(node=True).opidx == x and \
               pack.rightmost(node=True).opidx == y:
                pytest.fail(
                    "must not find packset with indices {x},{y}".format(
                        x=x, y=y))

    def assert_packset_contains_pair(self, packset, x, y):
        for pack in packset.packs:
            if isinstance(pack, Pair):
                if pack.leftmost(node=True).opidx == x and \
                   pack.rightmost(node=True).opidx == y:
                    break
        else:
            pytest.fail(
                "can't find a pack set for indices {x},{y}".format(x=x, y=y))

    def assert_has_memory_ref_at(self, graph, idx):
        idx -= 1 # label is not in the nodes
        node = graph.nodes[idx]
        assert node in graph.memory_refs, \
            "operation %s at pos %d has no memory ref!" % \
                (node.getoperation(), node.getindex())

class FakeInput(object):
    def __init__(self, type='f', datatype='f', size=8, signed=False):
        self.type = type
        self.datatype = datatype
        self.bytesize = size
        self.signed = signed

def arg(type='f', size=8, signed=False, datatype='f'):
    return FakeInput(type, datatype, size, signed)

class TestVectorize(VecTestHelper):

    def test_opcount_filling_store(self):
        descr = ArrayDescr(0, 8, None, 'F', concrete_type='f')
        pack = Pack([Node(ResOperation(rop.RAW_STORE, [0,0,arg('f',4)], descr), 0),
                     Node(ResOperation(rop.RAW_STORE, [0,0,arg('f',4)], descr), 0),
                    ])
        assert pack.opcount_filling_vector_register(16, self.cpu.vector_ext) == 2

    def test_opcount_filling_guard(self):
        descr = ArrayDescr(0, 4, None, 'S')
        vec = ResOperation(rop.VEC_LOAD_I, ['a','i', 8, 0], descr=descr)
        vec.count = 4
        pack = Pack([Node(ResOperation(rop.GUARD_TRUE, [vec]), 0),
                     Node(ResOperation(rop.GUARD_TRUE, [vec]), 1),
                     Node(ResOperation(rop.GUARD_TRUE, [vec]), 2),
                     Node(ResOperation(rop.GUARD_TRUE, [vec]), 3),
                     Node(ResOperation(rop.GUARD_TRUE, [vec]), 4),
                     Node(ResOperation(rop.GUARD_TRUE, [vec]), 5),
                    ])
        assert pack.pack_load(16) == 24-16
        assert pack.pack_load(8) == 24-8
        assert pack.pack_load(32) == 24-32
        ext = self.cpu.vector_ext
        assert pack.opcount_filling_vector_register(16, ext) == 4
        ops, newops = pack.slice_operations(16, ext)
        assert len(ops) == 4
        assert len(newops) == 2
        assert pack.opcount_filling_vector_register(8, ext) == 2
        ops, newops = pack.slice_operations(8, ext)
        assert len(ops) == 2
        assert len(newops) == 4

    def test_move_guard_first(self):
        trace = self.parse_trace("""
        i10 = int_add(i0, i1)
        #
        i11 = int_add(i0, i1)
        guard_true(i11) []
        """)
        add = trace.operations[1]
        guard = trace.operations[2]
        trace = self.earlyexit(trace)
        assert trace.operations[0] is add
        assert trace.operations[1] is guard

    def test_vectorize_guard(self):
        trace = self.parse_loop("""
        [p0,p1,i0]
        i100 = getarrayitem_raw_i(p0,i0,descr=int16arraydescr)
        i10 = getarrayitem_raw_i(p0,i0,descr=int32arraydescr)
        i20 = int_is_true(i10)
        guard_true(i20) [i20]
        i1 = int_add(i0, 1)
        jump(p0,p1,i1)
        """)
        self.vectorize(trace)
        self.debug_print_operations(trace)
        self.ensure_operations([
            'v10[4xi32] = vec_load_i(p0,i0,4,0,descr=int32arraydescr)',
            'v11[4xi32] = vec_int_is_true(v10[4xi32])',
            'i100 = vec_unpack_i(v11[4xi32], 0, 1)',
            'vec_guard_true(v11[4xi32]) [i100]',
        ], trace)

    def test_vectorize_skip(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0,1)
        i2 = int_le(i1, 10)
        guard_true(i2) []
        jump(p0,i1)
        """
        self.assert_vectorize(self.parse_loop(ops), self.parse_loop(ops))

    def test_unroll_empty_stays_empty(self):
        """ has no operations in this trace, thus it stays empty
        after unrolling it 2 times """
        ops = """
        []
        jump()
        """
        self.assert_unroll_loop_equals(self.parse_loop(ops), self.parse_loop(ops), 2)

    def test_vectorize_empty_with_early_exit(self):
        ops = """
        []
        jump()
        """
        with pytest.raises(NotAVectorizeableLoop):
            self.schedule(self.parse_loop(ops), 1)

    def test_unroll_empty_stays_empty_parameter(self):
        """ same as test_unroll_empty_stays_empty but with a parameter """
        ops = """
        [i0]
        jump(i0)
        """
        self.assert_unroll_loop_equals(self.parse_loop(ops), self.parse_loop(ops), 2)

    def test_vect_pointer_fails(self):
        """ it currently rejects pointer arrays """
        ops = """
        [p0,i0]
        getarrayitem_gc_r(p0,i0,descr=arraydescr2)
        jump(p0,i0)
        """
        self.assert_vectorize(self.parse_loop(ops), self.parse_loop(ops))

    def test_load_primitive_python_list(self):
        """ it currently rejects pointer arrays """
        ops = """
        [p0,i0]
        i2 = getarrayitem_gc_i(p0,i0,descr=arraydescr)
        i1 = int_add(i0,1)
        i3 = getarrayitem_gc_i(p0,i1,descr=arraydescr)
        i4 = int_add(i1,1)
        jump(p0,i4)
        """
        opt = """
        [p0,i0]
        v3[2xi64] = vec_load_i(p0,i0,8,0,descr=arraydescr)
        i2 = int_add(i0,2)
        jump(p0,i2)
        """
        loop = self.parse_loop(ops)
        vopt = self.vectorize(loop,0)
        self.assert_equal(loop, self.parse_loop(opt))

    def test_vect_unroll_char(self):
        """ a 16 byte vector register can hold 16 bytes thus
        it is unrolled 16 times. (it is the smallest type in the trace) """
        ops = """
        [p0,i0]
        raw_load_i(p0,i0,descr=chararraydescr)
        jump(p0,i0)
        """
        opt_ops = """
        [p0,i0]
        {}
        jump(p0,i0)
        """.format(('\n' + ' ' *8).join(['raw_load_i(p0,i0,descr=chararraydescr)'] * 16))
        self.assert_unroll_loop_equals(self.parse_loop(ops), self.parse_loop(opt_ops))

    def test_unroll_vector_addition(self):
        """ a more complex trace doing vector addition (smallest type is float
        8 byte) """
        ops = """
        [p0,p1,p2,i0]
        i1 = raw_load_i(p1, i0, descr=floatarraydescr)
        i2 = raw_load_i(p2, i0, descr=floatarraydescr)
        i3 = int_add(i1,i2)
        raw_store(p0, i0, i3, descr=floatarraydescr)
        i4 = int_add(i0, 1)
        i5 = int_le(i4, 10)
        guard_true(i5) []
        jump(p0,p1,p2,i4)
        """
        opt_ops = """
        [p0,p1,p2,i0]
        i4 = int_add(i0, 1)
        i5 = int_le(i4, 10)
        guard_true(i5) [p0,p1,p2,i0]
        i1 = raw_load_i(p1, i0, descr=floatarraydescr)
        i2 = raw_load_i(p2, i0, descr=floatarraydescr)
        i3 = int_add(i1,i2)
        raw_store(p0, i0, i3, descr=floatarraydescr)
        i9 = int_add(i4, 1)
        i10 = int_le(i9, 10)
        guard_true(i10) [p0,p1,p2,i4]
        i6 = raw_load_i(p1, i4, descr=floatarraydescr)
        i7 = raw_load_i(p2, i4, descr=floatarraydescr)
        i8 = int_add(i6,i7)
        raw_store(p0, i4, i8, descr=floatarraydescr)
        jump(p0,p1,p2,i9)
        """
        self.assert_unroll_loop_equals(self.parse_loop(ops), self.parse_loop(opt_ops), 1)

    def test_estimate_unroll_factor_smallest_byte_zero(self):
        ops = """
        [p0,i0]
        raw_load_i(p0,i0,descr=arraydescr)
        jump(p0,i0)
        """
        vopt = self.vectoroptimizer(self.parse_loop(ops))
        assert 0 == vopt.smallest_type_bytes
        assert 0 == vopt.get_unroll_count(ARCH_VEC_REG_SIZE)

    def test_array_operation_indices_not_unrolled(self):
        ops = """
        [p0,i0]
        raw_load_i(p0,i0,descr=arraydescr)
        jump(p0,i0)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        assert len(graph.memory_refs) == 1
        self.assert_has_memory_ref_at(graph, 1)

    def test_array_operation_indices_unrolled_1(self):
        ops = """
        [p0,i0]
        raw_load_i(p0,i0,descr=chararraydescr)
        jump(p0,i0)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),1)
        assert len(graph.memory_refs) == 2
        self.assert_has_memory_ref_at(graph, 1)
        self.assert_has_memory_ref_at(graph, 2)

    def test_array_operation_indices_unrolled_2(self):
        ops = """
        [p0,i0,i1]
        i3 = raw_load_i(p0,i0,descr=chararraydescr)
        i4 = raw_load_i(p0,i1,descr=chararraydescr)
        jump(p0,i3,i4)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.vectoroptimizer_unrolled(loop,0)
        assert len(graph.memory_refs) == 2
        self.assert_has_memory_ref_at(graph, 1)
        self.assert_has_memory_ref_at(graph, 2)
        #
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),1)
        assert len(graph.memory_refs) == 4
        for i in [1,2,3,4]:
            self.assert_has_memory_ref_at(graph, i)
        #
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),3)
        assert len(graph.memory_refs) == 8
        for i in [1,2,3,4,5,6,7,8]:
            self.assert_has_memory_ref_at(graph, i)

    def test_array_memory_ref_adjacent_1(self):
        ops = """
        [p0,i0]
        i3 = raw_load_i(p0,i0,descr=chararraydescr)
        i1 = int_add(i0,1)
        jump(p0,i1)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.vectoroptimizer_unrolled(loop,1)
        vopt.find_adjacent_memory_refs(graph)
        assert len(graph.memory_refs) == 2

        mref1 = graph.getmemref(find_first_index(loop, rop.RAW_LOAD_I))
        mref3 = graph.getmemref(find_first_index(loop, rop.RAW_LOAD_I,1))
        assert isinstance(mref1, MemoryRef)
        assert isinstance(mref3, MemoryRef)

        assert mref1.is_adjacent_to(mref3)
        assert mref3.is_adjacent_to(mref1)

    def test_array_memory_ref_1(self):
        ops = """
        [p0,i0]
        i3 = raw_load_i(p0,i0,descr=chararraydescr)
        jump(p0,i0)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref1 = graph.getmemref(0)
        assert isinstance(mref1, MemoryRef)
        assert mref1.index_var.coefficient_mul == 1
        assert mref1.index_var.constant == 0

    def test_array_memory_ref_2(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0,1)
        i3 = raw_load_i(p0,i1,descr=chararraydescr)
        jump(p0,i1)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref1 = graph.getmemref(1)
        assert isinstance(mref1, MemoryRef)
        assert mref1.index_var.coefficient_mul == 1
        assert mref1.index_var.constant == 1

    def test_array_memory_ref_sub_index(self):
        ops = """
        [p0,i0]
        i1 = int_sub(i0,1)
        i3 = raw_load_i(p0,i1,descr=chararraydescr)
        jump(p0,i1)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref1 = graph.getmemref(1)
        assert isinstance(mref1, MemoryRef)
        assert mref1.index_var.coefficient_mul == 1
        assert mref1.index_var.constant == -1

    def test_array_memory_ref_add_mul_index(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0,1)
        i2 = int_mul(i1,3)
        i3 = raw_load_i(p0,i2,descr=chararraydescr)
        jump(p0,i1)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref1 = graph.getmemref(2)
        assert isinstance(mref1, MemoryRef)
        assert mref1.index_var.coefficient_mul == 3
        assert mref1.index_var.constant == 3

    def test_array_memory_ref_add_mul_index_interleaved(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0,1)
        i2 = int_mul(i1,3)
        i3 = int_add(i2,5)
        i4 = int_mul(i3,6)
        i5 = raw_load_i(p0,i4,descr=chararraydescr)
        jump(p0,i4)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref1 = graph.getmemref(4)
        assert isinstance(mref1, MemoryRef)
        assert mref1.index_var.coefficient_mul == 18
        assert mref1.index_var.constant == 48

        ops = """
        [p0,i0]
        i1 = int_add(i0,1)
        i2 = int_mul(i1,3)
        i3 = int_add(i2,5)
        i4 = int_mul(i3,6)
        i5 = int_add(i4,30)
        i6 = int_mul(i5,57)
        i7 = raw_load_i(p0,i6,descr=chararraydescr)
        jump(p0,i6)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref1 = graph.getmemref(6)
        assert isinstance(mref1, MemoryRef)
        assert mref1.index_var.coefficient_mul == 1026
        assert mref1.index_var.coefficient_div == 1
        assert mref1.index_var.constant == 57*(30) + 57*6*(5) + 57*6*3*(1)

    def test_array_memory_ref_sub_mul_index_interleaved(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0,1)
        i2 = int_mul(i1,3)
        i3 = int_sub(i2,3)
        i4 = int_mul(i3,2)
        i5 = raw_load_i(p0,i4,descr=chararraydescr)
        jump(p0,i4)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref1 = graph.getmemref(4)
        assert isinstance(mref1, MemoryRef)
        assert mref1.index_var.coefficient_mul == 6
        assert mref1.index_var.coefficient_div == 1
        assert mref1.index_var.constant == 0

    def test_array_memory_ref_not_adjacent_1(self):
        ops = """
        [p0,i0,i4]
        i3 = raw_load_i(p0,i0,descr=chararraydescr)
        i1 = int_add(i0,1)
        i5 = raw_load_i(p0,i4,descr=chararraydescr)
        i6 = int_add(i4,1)
        jump(p0,i1,i6)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.vectoroptimizer_unrolled(loop,1)
        vopt.find_adjacent_memory_refs(graph)

        f = lambda x: find_first_index(loop, rop.RAW_LOAD_I, x)
        indices = [f(0),f(1),f(2),f(3)]
        for i in indices:
            self.assert_has_memory_ref_at(graph, i+1)
        assert len(graph.memory_refs) == 4

        mref1, mref3, mref5, mref7 = [graph.getmemref(i) for i in indices]
        assert isinstance(mref1, MemoryRef)
        assert isinstance(mref3, MemoryRef)
        assert isinstance(mref5, MemoryRef)
        assert isinstance(mref7, MemoryRef)

        self.assert_memory_ref_adjacent(mref1, mref5)
        self.assert_memory_ref_not_adjacent(mref1, mref3)
        self.assert_memory_ref_not_adjacent(mref1, mref7)
        self.assert_memory_ref_adjacent(mref3, mref7)
        assert mref1.is_adjacent_after(mref5)

    def test_array_memory_ref_div(self):
        py.test.skip("XXX rewrite or kill this test for the new divisions")
        ops = """
        [p0,i0]
        i1 = int_floordiv(i0,2)
        i2 = int_floordiv(i1,8)
        i3 = raw_load_i(p0,i2,descr=chararraydescr)
        jump(p0,i2)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref = graph.getmemref(2)
        assert mref.index_var.coefficient_div == 16
        ops = """
        [p0,i0]
        i1 = int_add(i0,8)
        i2 = uint_floordiv(i1,2)
        i3 = raw_load_i(p0,i2,descr=chararraydescr)
        jump(p0,i2)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref = graph.getmemref(2)
        assert mref.index_var.coefficient_div == 2
        assert mref.index_var.constant == 4
        ops = """
        [p0,i0]
        i1 = int_add(i0,8)
        i2 = int_floordiv(i1,2)
        i3 = raw_load_i(p0,i2,descr=chararraydescr)
        i4 = int_add(i0,4)
        i5 = int_mul(i4,2)
        i6 = raw_load_i(p0,i5,descr=chararraydescr)
        jump(p0,i2)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref = graph.getmemref(2)
        mref2 = graph.getmemref(5)

        self.assert_memory_ref_not_adjacent(mref, mref2)
        assert mref != mref2

    def test_array_memory_ref_diff_calc_but_equal(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0,4)
        i2 = int_mul(i1,2)
        i3 = raw_load_i(p0,i2,descr=chararraydescr)
        i4 = int_add(i0,2)
        i5 = int_mul(i4,2)
        i6 = int_add(i5,4)
        i7 = raw_load_i(p0,i6,descr=chararraydescr)
        jump(p0,i2)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref = graph.getmemref(2)
        mref2 = graph.getmemref(6)

        self.assert_memory_ref_not_adjacent(mref, mref2)
        assert mref == mref2

    def test_array_memory_ref_diff_not_equal(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0,4)
        i2 = int_sub(i1,3)   # XXX used to be "divide by 2", not sure about it
        i3 = raw_load_i(p0,i2,descr=chararraydescr)
        i4 = int_add(i0,2)
        i5 = int_mul(i4,2)
        i6 = int_add(i5,4)
        i7 = raw_load_i(p0,i6,descr=chararraydescr)
        jump(p0,i2)
        """
        vopt, graph = self.vectoroptimizer_unrolled(self.parse_loop(ops),0)
        vopt.find_adjacent_memory_refs(graph)
        mref = graph.getmemref(2)
        mref2 = graph.getmemref(6)

        self.assert_memory_ref_not_adjacent(mref, mref2)
        assert mref != mref2

    def test_packset_init_simple(self):
        ops = """
        [p0,i0]
        i3 = getarrayitem_raw_i(p0, i0, descr=chararraydescr)
        i1 = int_add(i0, 1)
        i2 = int_le(i1, 16)
        guard_true(i2) [p0, i0]
        jump(p0,i1)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.init_packset(loop,1)
        self.assert_independent(graph, 4,8)
        assert vopt.packset is not None
        assert len(graph.memory_refs) == 2
        assert len(vopt.packset.packs) == 1

    def test_packset_init_raw_load_not_adjacent_and_adjacent(self):
        ops = """
        [p0,i0]
        i3 = raw_load_i(p0, i0, descr=chararraydescr)
        jump(p0,i0)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.init_packset(loop,3)
        assert len(graph.memory_refs) == 4
        assert len(vopt.packset.packs) == 0
        ops = """
        [p0,i0]
        i2 = int_add(i0,1)
        raw_load_i(p0, i2, descr=chararraydescr)
        jump(p0,i2)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.init_packset(loop,3)
        assert len(graph.memory_refs) == 4
        assert len(vopt.packset.packs) == 3
        for i in range(3):
            x = (i+1)*2
            y = x + 2
            self.assert_independent(graph, x,y)
            self.assert_packset_contains_pair(vopt.packset, x,y)

    def test_packset_init_2(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0, 1)
        i2 = int_le(i1, 16)
        guard_true(i2) [p0, i0]
        i3 = getarrayitem_raw_i(p0, i1, descr=chararraydescr)
        jump(p0,i1)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.init_packset(loop,15)
        assert len(graph.memory_refs) == 16
        assert len(vopt.packset.packs) == 15
        # assure that memory refs are not adjacent for all
        for i in range(15):
            for j in range(15):
                try:
                    mref1 = graph.getmemref(i)
                    mref2 = graph.getmemref(j)
                    if i-4 == j or i+4 == j:
                        assert mref1.is_adjacent_to(mref2)
                    else:
                        assert not mref1.is_adjacent_to(mref2)
                except KeyError:
                    pass
        for i in range(15):
            x = (i+1)*4
            y = x + 4
            self.assert_independent(graph, x,y)
            self.assert_packset_contains_pair(vopt.packset, x, y)

    def test_isomorphic_operations(self):
        ops_src = """
        [p1,p0,i0]
        i3 = getarrayitem_raw_i(p0, i0, descr=chararraydescr)
        i1 = int_add(i0, 1)
        i2 = int_le(i1, 16)
        i4 = getarrayitem_raw_i(p0, i1, descr=chararraydescr)
        f5 = getarrayitem_raw_f(p1, i1, descr=floatarraydescr)
        f6 = getarrayitem_raw_f(p0, i1, descr=floatarraydescr)
        guard_true(i2) [p0, i0]
        jump(p1,p0,i1)
        """
        loop = self.parse_loop(ops_src)
        ops = loop.operations
        assert isomorphic(ops[0], ops[3])
        assert not isomorphic(ops[0], ops[1])
        assert not isomorphic(ops[0], ops[5])

    def test_packset_extend_simple(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0, 1)
        i2 = int_le(i1, 16)
        guard_true(i2) [p0, i0]
        i3 = getarrayitem_raw_i(p0, i1, descr=chararraydescr)
        i4 = int_add(i3, 1)
        jump(p0,i1)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.extend_packset(loop,1)
        assert len(graph.memory_refs) == 2
        self.assert_independent(graph, 3,7)
        # the delayed scheduling strips away the vectorized addition,
        # because it is never used
        assert len(vopt.packset.packs) == 1
        self.assert_packset_empty(vopt.packset,
                                  len(loop.operations),
                                  [(4,8)])

    def test_packset_extend_load_modify_store(self):
        ops = """
        [p0,i0]
        i1 = int_add(i0, 1)
        i2 = int_le(i1, 16)
        guard_true(i2) [p0, i0]
        i3 = getarrayitem_raw_i(p0, i1, descr=chararraydescr)
        i4 = int_mul(i3, 2)
        setarrayitem_raw(p0, i1, i4, descr=chararraydescr)
        jump(p0,i1)
        """
        loop = self.parse_loop(ops)
        vopt, graph = self.extend_packset(loop,1)
        assert len(graph.memory_refs) == 4
        self.assert_independent(graph, 4,10)
        self.assert_independent(graph, 5,11)
        self.assert_independent(graph, 6,12)
        assert len(vopt.packset.packs) == 3
        self.assert_packset_empty(vopt.packset, len(loop.operations),
                                  [(6,12), (5,11), (4,10)])

    @pytest.mark.parametrize("descr,packs,packidx",
                             [('char',  0,       []),
                              ('float', 2,       [(0,(1,3)),(1,(5,7))]),
                              ('',   2,       [(0,(1,3)),(1,(5,7))]),
                              ('float32', 1, [(0,(1,3,5,7))]),
                             ])
    def test_packset_combine_simple(self,descr,packs,packidx):
        suffix = '_i'
        if 'float' in descr:
            suffix = '_f'
        ops = """
        [p0,i0]
        i3 = getarrayitem_raw{suffix}(p0, i0, descr={descr}arraydescr)
        i1 = int_add(i0,1)
        jump(p0,i1)
        """.format(descr=descr,suffix=suffix)
        loop = self.parse_loop(ops)
        vopt, graph = self.combine_packset(loop,3)
        assert len(graph.memory_refs) == 4
        assert len(vopt.packset.packs) == packs
        for i,t in packidx:
            self.assert_pack(vopt.packset.packs[i], t)

    @pytest.mark.parametrize("descr,stride,packs,suffix",
            [('char',1,0,'_i'),('float',8,4,'_f'),('',8,4,'_i'),('float32',4,2,'_i')])
    def test_packset_combine_2_loads_in_trace(self, descr, stride, packs, suffix):
        ops = """
        [p0,i0]
        i3 = raw_load{suffix}(p0, i0, descr={type}arraydescr)
        i1 = int_add(i0,{stride})
        i4 = raw_load{suffix}(p0, i1, descr={type}arraydescr)
        i2 = int_add(i1,{stride})
        jump(p0,i2)
        """.format(type=descr,stride=stride,suffix=suffix)
        loop = self.parse_loop(ops)
        vopt, graph = self.combine_packset(loop,3)
        assert len(graph.memory_refs) == 8
        assert len(vopt.packset.packs) == packs

    def test_packset_combine_no_candidates_packset_empty(self):
        ops = """
        []
        jump()
        """
        with pytest.raises(NotAVectorizeableLoop):
            self.combine_packset(self.parse_loop(ops), 15)

        ops = """
        [p0,i0]
        f3 = getarrayitem_raw_f(p0, i0, descr=floatarraydescr)
        jump(p0,i0)
        """
        loop = self.parse_loop(ops)
        with pytest.raises(NotAVectorizeableLoop):
            self.combine_packset(loop, 15)

    @pytest.mark.parametrize("op,descr,stride",
            [('int_add','char',1),
             ('int_sub','char',1),
             ('int_mul','char',1),
             ('float_add','float',8),
             ('float_sub','float',8),
             ('float_mul','float',8),
             ('float_add','float32',4),
             ('float_sub','float32',4),
             ('float_mul','float32',4),
             ('int_add','',8),
             ('int_sub','',8),
             ('int_mul','',8),
            ])
    def test_packset_vector_operation(self, op, descr, stride):
        suffix = '_i'
        if 'float' in descr:
            suffix = '_f'
        ops = """
        [p0,p1,p2,i0]
        i1 = int_add(i0, {stride})
        i10 = int_le(i1, 128)
        guard_true(i10) []
        i2 = raw_load{suffix}(p0, i0, descr={descr}arraydescr)
        i3 = raw_load{suffix}(p1, i0, descr={descr}arraydescr)
        i4 = {op}(i2,i3)
        raw_store(p2, i0, i4, descr={descr}arraydescr)
        jump(p0,p1,p2,i1)
        """.format(op=op,descr=descr,stride=stride,suffix=suffix)
        loop = self.parse_loop(ops)
        vopt, graph = self.combine_packset(loop,3)
        assert len(graph.memory_refs) == 12
        if stride == 8:
            assert len(vopt.packset.packs) == 8
        else:
            if descr != 'char':
                assert len(vopt.packset.packs) == 4
        if descr == 'char':
            return
        for opindices in [(4,11,18,25),(5,12,19,26),
                          (6,13,20,27),(4,11,18,25)]:
            self.assert_has_pack_with(vopt.packset, opindices)

    @pytest.mark.parametrize('op,descr,stride',
            [('float_add','float',8),
             ('float_sub','float',8),
             ('float_mul','float',8),
             ('int_add','',8),
             ('int_sub','',8),
            ])
    def test_schedule_vector_operation(self, op, descr, stride):
        suffix = '_i'
        if 'float' in descr:
            suffix = '_f'
        ops = """
        [p0,p1,p2,i0] # 0
        i10 = int_le(i0, 128)  # 1, 8, 15, 22
        guard_true(i10) [p0,p1,p2,i0] # 2, 9, 16, 23
        i2 = getarrayitem_raw{suffix}(p0, i0, descr={descr}arraydescr) # 3, 10, 17, 24
        i3 = getarrayitem_raw{suffix}(p1, i0, descr={descr}arraydescr) # 4, 11, 18, 25
        i4 = {op}(i2,i3) # 5, 12, 19, 26
        setarrayitem_raw(p2, i0, i4, descr={descr}arraydescr) # 6, 13, 20, 27
        i1 = int_add(i0, {stride}) # 7, 14, 21, 28
        jump(p0,p1,p2,i1) # 29
        """.format(op=op,descr=descr,stride=1,suffix=suffix)
        vops = """
        [p0,p1,p2,i0]
        i10 = int_le(i0, 128)
        guard_true(i10) [p0,p1,p2,i0]
        i1 = int_add(i0, {stride})
        i11 = int_le(i1, 128)
        guard_true(i11) [p0,p1,p2,i1]
        v1 = vec_load{suffix}(p0, i0,8,0, descr={descr}arraydescr)
        v2 = vec_load{suffix}(p1, i0,8,0, descr={descr}arraydescr)
        v3 = {op}(v1,v2)
        vec_store(p2, i0, v3,8,0, descr={descr}arraydescr)
        i12 = int_add(i0, 2)
        jump(p0,p1,p2,i12)
        """.format(op='vec_'+op,descr=descr,stride=1,suffix=suffix)
        loop = self.parse_loop(ops)
        vopt = self.schedule(loop, 1)
        self.assert_equal(loop, self.parse_loop(vops))

    def test_vschedule_trace_1(self):
        ops = """
        [i0, i1, i2, i3, i4]
        i6 = int_mul(i0, 8)
        i7 = raw_load_i(i2, i6, descr=arraydescr)
        i8 = raw_load_i(i3, i6, descr=arraydescr)
        i9 = int_add(i7, i8)
        raw_store(i4, i6, i9, descr=arraydescr)
        i11 = int_add(i0, 1)
        i12 = int_lt(i11, i1)
        guard_true(i12) [i4, i3, i2, i1, i11]
        jump(i11, i1, i2, i3, i4)
        """
        opt="""
        [i0, i1, i2, i3, i4]
        i11 = int_add(i0, 1)
        i12 = int_lt(i11, i1)
        guard_true(i12) [i0,i1,i2,i3,i4]
        i13 = int_add(i0, 2)
        i18 = int_lt(i13, i1)
        guard_true(i18) [i11,i1,i2,i3,i4]
        i6 = int_mul(i0, 8)
        v19[2xi64] = vec_load_i(i2, i6, 1, 0, descr=arraydescr)
        v20[2xi64] = vec_load_i(i3, i6, 1, 0, descr=arraydescr)
        v21[2xi64] = vec_int_add(v19, v20)
        vec_store(i4, i6, v21, 1, 0, descr=arraydescr)
        jump(i13, i1, i2, i3, i4)
        """
        loop = self.parse_loop(ops)
        vopt = self.schedule(loop,1)
        self.assert_equal(loop, self.parse_loop(opt))

    def test_collapse_index_guard_1(self):
        ops = """
        [p0,i0]
        i1 = getarrayitem_raw_i(p0, i0, descr=chararraydescr)
        i2 = int_add(i0, 1)
        i3 = int_lt(i2, 102)
        guard_true(i3) [p0,i0]
        jump(p0,i2)
        """
        opt="""
        [p0,i0]
        i2 = int_add(i0, 16)
        i3 = int_lt(i2, 102)
        guard_true(i3) [p0,i0]
        v10[16xi8] = vec_load_i(p0, i0, 1, 0, descr=chararraydescr)
        jump(p0,i2)
        """
        loop = self.parse_loop(ops)
        vopt = self.schedule(loop,15,with_guard_opt=True)
        self.assert_equal(loop, self.parse_loop(opt))

    def test_too_small_vector(self):
        ops = """
        [p0,i0]
        i1 = getarrayitem_raw_i(p0, 0, descr=chararraydescr) # constant index
        i2 = getarrayitem_raw_i(p0, 1, descr=chararraydescr) # constant index
        i4 = int_add(i1, i2)
        i3 = int_add(i0,1)
        i5 = int_lt(i3, 10)
        guard_true(i5) [p0, i0]
        jump(p0,i1)
        """
        with pytest.raises(NotAVectorizeableLoop):
            self.vectorize(self.parse_loop(ops))

    def test_constant_expansion(self):
        ops = """
        [p0,i0]
        i1 = getarrayitem_raw_i(p0, i0, descr=arraydescr)
        i4 = int_sub(i1, 42)
        setarrayitem_raw(p0, i0, i4, descr=arraydescr)
        i3 = int_add(i0,1)
        i5 = int_lt(i3, 10)
        guard_true(i5) [p0, i0]
        jump(p0,i3)
        """
        opt="""
        [p0,i0]
        v3[2xf64] = vec_expand_i(42)
        label(p0,i0,v3[2xf64])
        i2 = int_add(i0, 2)
        i3 = int_lt(i2, 10)
        guard_true(i3) [p0,i0]
        v1[2xf64] = vec_load_i(p0, i0, 8, 0, descr=arraydescr)
        v2[2xf64] = vec_int_sub(v1[2xf64], v3[2xf64])
        vec_store(p0, i0, v2[2xf64], 8, 0, descr=arraydescr)
        jump(p0,i2,v3[2xf64])
        """
        loop = self.parse_loop(ops)
        vopt = self.vectorize(loop,1)
        self.assert_equal(loop, self.parse_loop(opt))

    def test_variable_expansion(self):
        ops = """
        [p0,i0,f3]
        f1 = getarrayitem_raw_f(p0, i0, descr=floatarraydescr)
        f4 = float_add(f1, f3)
        setarrayitem_raw(p0, i0, f4, descr=floatarraydescr)
        i3 = int_add(i0,1)
        i5 = int_lt(i3, 10)
        guard_true(i5) [p0, i0]
        jump(p0,i3,f3)
        """
        opt="""
        [p0,i0,f3]
        v3[2xf64] = vec_expand_f(f3)
        label(p0,i0,f3,v3[2xf64])
        i2 = int_add(i0, 2)
        i3 = int_lt(i2, 10)
        guard_true(i3) [p0,i0,f3]
        v1[2xf64] = vec_load_f(p0, i0, 8, 0, descr=floatarraydescr)
        v2[2xf64] = vec_float_add(v1[2xf64], v3[2xf64])
        vec_store(p0, i0, v2[2xf64], 8, 0, descr=floatarraydescr)
        jump(p0,i2,f3,v3[2xf64])
        """
        loop = self.parse_loop(ops)
        vopt = self.vectorize(loop,1)
        self.assert_equal(loop, self.parse_loop(opt))

    #def test_accumulate_basic(self):
    #    trace = """
    #    [p0, i0, f0]
    #    f1 = raw_load_f(p0, i0, descr=floatarraydescr)
    #    f2 = float_add(f0, f1)
    #    i1 = int_add(i0, 8)
    #    i2 = int_lt(i1, 100)
    #    guard_true(i2) [p0, i0, f2]
    #    jump(p0, i1, f2)
    #    """
    #    trace_opt = """
    #    [p0, i0, f0]
    #    v6[0xf64] = vec_f()
    #    v7[2xf64] = vec_float_xor(v6[0xf64], v6[0xf64])
    #    v2[2xf64] = vec_pack_f(v7[2xf64], f0, 0, 1)
    #    label(p0, i0, v2[2xf64])
    #    i1 = int_add(i0, 16)
    #    i2 = int_lt(i1, 100)
    #    guard_true(i2) [p0, i0, v2[2xf64]]
    #    v1[2xf64] = vec_load_f(p0, i0, 1, 0, descr=floatarraydescr)
    #    v3[2xf64] = vec_float_add(v2[2xf64], v1[2xf64])
    #    jump(p0, i1, v3[2xf64])
    #    """
    #    loop = self.parse_loop(trace)
    #    opt = self.vectorize(loop)
    #    self.assert_equal(loop, self.parse_loop(trace_opt))

    def test_element_f45_in_guard_failargs(self):
        trace = self.parse_loop("""
        [p36, i28, p9, i37, p14, f34, p12, p38, f35, p39, i40, i41, p42, i43, i44, i21, i4, i0, i18]
        f45 = raw_load_f(i21, i44, descr=floatarraydescr)
        guard_not_invalidated() [p38, p12, p9, p14, f45, p39, i37, i44, f35, i40, p42, i43, None, i28, p36, i41]
        i46 = int_add(i44, 8)
        f47 = raw_load_f(i4, i41, descr=floatarraydescr)
        i48 = int_add(i41, 8)
        f49 = float_add(f45, f47)
        raw_store(i0, i37, f49, descr=floatarraydescr)
        i50 = int_add(i28, 1)
        i51 = int_add(i37, 8)
        i52 = int_ge(i50, i18)
        guard_false(i52) [p38, p12, p9, p14, i48, i46, f47, i51, i50, f45, p39, None, None, None, i40, p42, i43, None, None, p36, None]
        jump(p36, i50, p9, i51, p14, f45, p12, p38, f47, p39, i40, i48, p42, i43, i46, i21, i4, i0, i18)
        """)
        trace_opt = self.parse_loop("""
        [p36, i28, p9, i37, p14, f34, p12, p38, f35, p39, i40, i41, p42, i43, i44, i21, i4, i0, i18]
        guard_not_invalidated() [p36, i28, p9, i37, p14, f34, p12, p38, f35, p39, i40, i41, p42, i43, i44, i21, i4, i0, i18]
        i54 = int_add(i28, 2)
        i638 = int_ge(i54, i18)
        guard_false(i638) [p36, i28, p9, i37, p14, f34, p12, p38, f35, p39, i40, i41, p42, i43, i44, i21, i4, i0, i18]
        v61[2xf64] = vec_load_f(i21, i44, 1, 0, descr=floatarraydescr)
        v62[2xf64] = vec_load_f(i4, i41, 1, 0, descr=floatarraydescr)
        v63[2xf64] = vec_float_add(v61, v62)
        vec_store(i0, i37, v63, 1, 0, descr=floatarraydescr)
        i637 = int_add(i37, 16)
        i629 = int_add(i41, 16)
        i55 = int_add(i44, 16)
        f100 = vec_unpack_f(v61, 1, 1)
        f101 = vec_unpack_f(v62, 1, 1)
        jump(p36, i637, p9, i629, p14, f100, p12, p38, f101, p39, i40, i54, p42, i43, i55, i21, i4, i0, i18)
        """)
        vopt = self.vectorize(trace)
        self.assert_equal(trace, trace_opt)

    def test_shrink_vector_size(self):
        ops = """
        [p0,p1,i1]
        f1 = getarrayitem_raw_f(p0, i1, descr=floatarraydescr)
        i2 = cast_float_to_singlefloat(f1)
        setarrayitem_raw(p1, i1, i2, descr=float32arraydescr)
        i3 = int_add(i1, 1)
        i4 = int_ge(i3, 36)
        guard_false(i4) []
        jump(p0, p1, i3)
        """
        opt = """
        [p0, p1, i1]
        i50 = int_add(i1, 4)
        i51 = int_ge(i50, 36)
        guard_false(i51) [p0, p1, i1]
        v17 = vec_load_f(p0, i1, 8, 0, descr=floatarraydescr)
        i5 = int_add(i1, 2)
        v18 = vec_load_f(p0, i5, 8, 0, descr=floatarraydescr)
        v19 = vec_cast_float_to_singlefloat(v17)
        v20 = vec_cast_float_to_singlefloat(v18)
        v21 = vec_pack_i(v19, v20, 2, 2)
        vec_store(p1, i1, v21, 4, 0, descr=float32arraydescr)
        jump(p0, p1, i50)
        """
        loop = self.parse_loop(ops)
        vopt = self.vectorize(loop)
        self.assert_equal(loop, self.parse_loop(opt))

    def test_castup_arith_castdown(self):
        trace = self.parse_loop("""
        [p0,p1,p2,i0,i4]
        i10 = raw_load_i(p0, i0, descr=float32arraydescr)
        i1 = int_add(i0, 4)
        i11 = raw_load_i(p1, i1, descr=float32arraydescr)
        f1 = cast_singlefloat_to_float(i10)
        f2 = cast_singlefloat_to_float(i11)
        f3 = float_add(f1, f2)
        i12  = cast_float_to_singlefloat(f3)
        raw_store(p2, i4, i12, descr=float32arraydescr)
        i5  = int_add(i4, 4)
        i186 = int_lt(i5, 100)
        guard_true(i186) []
        jump(p0,p1,p2,i1,i5)
        """)
        trace_opt = self.parse_loop("""
        [p0, p1, p2, i0, i4]
        i500 = int_add(i4, 16)
        i501 = int_lt(i500, 100)
        guard_true(i501) [p0, p1, p2, i0, i4]
        v228[4xi32] = vec_load_i(p0, i0, 1, 0, descr=float32arraydescr)
        i189 = int_add(i0, 4)
        v232 = vec_load_i(p1, i189, 1, 0, descr=float32arraydescr)
        v229[2xf64] = vec_cast_singlefloat_to_float(v228)
        v233 = vec_cast_singlefloat_to_float(v232)
        v236 = vec_float_add(v229, v233)
        v238 = vec_cast_float_to_singlefloat(v236)
        v230 = vec_unpack_i(v228, 2, 2)
        v231 = vec_cast_singlefloat_to_float(v230)
        v234 = vec_unpack_i(v232, 2, 2)
        v235 = vec_cast_singlefloat_to_float(v234)
        v237 = vec_float_add(v231, v235)
        v239 = vec_cast_float_to_singlefloat(v237)
        v240 = vec_pack_i(v238, v239, 2, 2)
        vec_store(p2, i4, v240, 1, 0, descr=float32arraydescr)
        i207 = int_add(i0, 16)
        jump(p0, p1, p2, i207, i500)
        """)
        vopt = self.vectorize(trace)
        self.assert_equal(trace, trace_opt)

    def test_sum_int16_prevent(self):
        trace = self.parse_loop("""
        [i0, p1, i2, p3, i4, i5, i6]
        i7 = raw_load_i(i5, i4, descr=int16arraydescr)
        i8 = int_add(i0, i7)
        i10 = int_add(i2, 1)
        i12 = int_add(i4, 2)
        i13 = int_ge(i10, i6)
        guard_false(i13, descr=<rpython.jit.metainterp.compile.ResumeGuardFalseDescr object at 0x7fe5a1848150>) [p3, i10, i8, i12, None, p1, None, None]
        jump(i8, p1, i10, p3, i12, i5, i6)
        """)
        with pytest.raises(NotAVectorizeableLoop):
            vopt = self.vectorize(trace)

    def test_pass(self):
        trace = self.parse_loop("""
        [p0,i0]
        f0 = raw_load_f(p0, i0, descr=floatarraydescr)
        f1 = float_mul(f0, 0.0)
        i2 = float_eq(f1, f1)
        guard_true(i2) [p0, i0]
        f2 = call_f(0, f0)
        f21 = float_mul(f2, 0.0)
        i3 = float_eq(f21, f21)
        guard_true(i3) [p0, i0]
        raw_store(p0, i0, f21, descr=floatarraydescr)
        i4 = int_add(i0, 8)
        jump(p0, i4)
        """)
        vopt = self.schedule(trace)
        self.ensure_operations([
            'v10[2xf64] = vec_load_f(p0,i0,8,0,descr=floatarraydescr)',
            'v11[2xf64] = vec_float_mul(v10[2xf64], v9[2xf64])',
            'v12[2xf64] = vec_float_eq(v11[2xf64], v11[2xf64])',
            'i100 = vec_unpack_f(v12[4xi32], 0, 1)',
            'guard_true(i100) [p0, i0]',
        ], trace)

    def test_guard_failarg_do_not_rename_to_const(self):
        # Loop -2 (pre vectorize) : noopt with 15 ops
        trace = self.parse_loop("""
        [p0, p1, p2, p3, p4, i5, i6, p7, p8, p9, p10, i11, i12, f13, p14, p15, i16, i17]
        i19 = int_and(i6, 7)
        i20 = int_is_zero(i19)
        guard_true(i20, descr=<ResumeGuardDescr object at 0x3fffab60d7b0>) [p7, p3, p2, p1, p0, p8, p10, i11, i19, i6, i12, i5, p4]
        f21 = raw_load_f(i12, i6, descr=floatarraydescr)
        guard_not_invalidated(descr=<ResumeGuardCopiedDescr object at 0x3fffab5fcde8>) [p7, p3, p2, p1, p0, p8, p10, i11, i19, i6, i12, i5, p4]
        f22 = float_mul(f21, f13)
        raw_store(i16, i6, f22, descr=floatarraydescr)
        i24 = int_add(i5, 1)
        i26 = int_add(i6, 8)
        i27 = int_ge(i24, i17)
        guard_false(i27) [i17, i24, p7, p3, p2, p1, p0, i26, None, p4]
        jump(p0, p1, p2, p3, p4, i24, i26, p7, p8, p9, p10, 1, i12, f13, p14, p15, i16, i17)
        """)
        vopt = self.schedule(trace)
        for op in trace.operations:
            if op.is_guard():
                for arg in op.getfailargs():
                    assert not arg.is_constant()

    def test_delay_pure_ops(self):
        """ Pure operations can be delayed. Often (e.g. for index calc.) this means they can be omitted.
        """
        trace = self.parse_loop("""
        [p0,i0]
        f0 = raw_load_f(p0, i0, descr=floatarraydescr)
        i1 = int_add(i0,8)
        f1 = raw_load_f(p0, i1, descr=floatarraydescr)
        i2 = int_add(i1,8)
        jump(p0,i2)
        """)
        self.schedule(trace, unroll_factor=0)
        self.ensure_operations([
            'v0[2xf64] = vec_load_f(p0, i0, 8, 0, descr=floatarraydescr)',
            'i2 = int_add(i0, 16)',
        ], trace)

    def test_schedule_signext_twice(self):
        trace = self.parse_loop("""
        [p0, i1, p2, i3, p4, p5, i6, i7]
        i8 = raw_load_i(i6, i3, descr=chararraydescr)
        i10 = int_signext(i8, 1)
        guard_not_invalidated() [p2, i10, i3, i1, p0]
        i11 = int_is_true(i10)
        guard_false(i11) [p2, i10, i3, i1, p0]
        i13 = int_add(i1, 1)
        i15 = int_add(i3, 1)
        i16 = int_ge(i13, i7)
        guard_false(i16) [p2, i10, i3, i1, p0]
        jump(p0, i13, p2, i15, p4, p5, i6, i7)
        """)
        self.schedule(trace, unroll_factor=15)
        dups = set()
        for op in trace.operations:
            assert op not in dups
            dups.add(op)
