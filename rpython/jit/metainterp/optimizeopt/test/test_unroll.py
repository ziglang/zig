"""
More direct tests for unrolling
"""

from rpython.jit.metainterp.optimizeopt.test.test_util import BaseTest
from rpython.jit.metainterp.optimizeopt.util import equaloplists
from rpython.jit.metainterp.history import TreeLoop
from rpython.jit.metainterp.resoperation import (
    rop, ResOperation, InputArgRef, InputArgInt)
from rpython.jit.metainterp.support import ptr2int
from rpython.jit.metainterp.optimizeopt.shortpreamble import (
    ShortPreambleBuilder, PreambleOp, ShortInputArg)
from rpython.jit.metainterp.compile import PreambleCompileData
from rpython.jit.metainterp.optimizeopt.virtualstate import (
    NotVirtualStateInfo, LEVEL_CONSTANT, LEVEL_UNKNOWN, LEVEL_KNOWNCLASS,
    VirtualStateInfo)
from rpython.jit.metainterp.optimizeopt import info, optimizer
from rpython.jit.tool import oparser

class FakeOptimizer(object):
    optearlyforce = None
    optimizer = optimizer.Optimizer

    class cpu:
        remove_gctypeptr = True

    def setinfo_from_preamble(self, *args):
        pass

    def get_box_replacement(self, box):
        return box

class BaseTestUnroll(BaseTest):
    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap:unroll"

    def optimize(self, ops):
        loop = self.parse(ops)
        self.add_guard_future_condition(loop)
        operations = loop.operations
        jumpop = operations[-1]
        assert jumpop.getopnum() == rop.JUMP
        inputargs = loop.inputargs
        preamble = TreeLoop('preamble')
        trace = oparser.convert_loop_to_trace(loop, self.metainterp_sd)
        compile_data = PreambleCompileData(
            trace, inputargs, enable_opts=self.enable_opts)
        start_state, newops = compile_data.optimize_trace(
            self.metainterp_sd, None, {})
        preamble.operations = newops
        preamble.inputargs = start_state.renamed_inputargs
        return start_state, loop, preamble

    def compare_short(self, short, expected_short):
        expected_short = self.parse(expected_short)
        remap = {}
        exp = ([ResOperation(rop.LABEL, expected_short.inputargs)] +
               expected_short.operations)
        for k, v in zip(short[0].getarglist(), expected_short.inputargs):
            remap[v] = k
        equaloplists(short, exp, remap=remap)

def producable_short_boxes(l):
    return [x for x in l if not isinstance(x.short_op, ShortInputArg)]

class TestUnroll(BaseTestUnroll):
    def test_simple(self):
        loop = """
        [i0]
        i1 = int_add(i0, 1)
        guard_value(i1, 1) []
        jump(i1)
        """
        es, loop, preamble = self.optimize(loop)
        vs = es.virtual_state
        assert isinstance(vs.state[0], NotVirtualStateInfo)
        # the virtual state is constant, so we don't need to have it in
        # inputargs
        assert vs.make_inputargs([1], FakeOptimizer()) == []
        assert vs.state[0].level == LEVEL_CONSTANT
        # we have exported values for i1, which happens to be an inputarg
        sb = ShortPreambleBuilder([], es.short_boxes, es.short_inputargs,
                                  es.exported_infos)
        sp = sb.build_short_preamble()
        exp = """
        []
        jump()
        """
        self.compare_short(sp, exp)
        # sb = ShortPreambleBuilder(es.short_boxes, es.short_inputargs,
        #                           es.exported_infos)
        # sb.use_box(es.short_boxes[0].short_op.res)
        # assert len(es.short_boxes) == 1
        # exp = """
        # [i0]
        # i1 = int_add(i0, 1)
        # guard_value(i1, 1) []
        # jump()
        # """
        # self.compare_short(sb.build_short_preamble(), exp)

    def test_not_constant(self):
        loop = """
        [i0]
        i1 = int_add(i0, 1)
        jump(i0)
        """
        es, loop, preamble = self.optimize(loop)
        vs = es.virtual_state
        assert isinstance(vs.state[0], NotVirtualStateInfo)
        assert vs.state[0].level == LEVEL_UNKNOWN
        op = preamble.operations[0]
        short_boxes = [box for box in es.short_boxes
                       if not isinstance(box.short_op, ShortInputArg)]
        assert len(short_boxes) == 1
        assert short_boxes[0].short_op.res is op

    def test_guard_class(self):
        loop = """
        [p0]
        guard_class(p0, ConstClass(node_vtable)) []
        jump(p0)
        """
        es, loop, preamble = self.optimize(loop)
        p0 = preamble.inputargs[0]
        expected_class = ptr2int(self.node_vtable)
        assert expected_class == es.exported_infos[p0]._known_class.getint()
        vs = es.virtual_state
        assert vs.state[0].level == LEVEL_KNOWNCLASS
        assert vs.state[0].known_class.getint() == expected_class

    def test_virtual(self):
        loop = """
        [p1, p2, i3]
        p0 = new_with_vtable(descr=simpledescr)
        setfield_gc(p0, i3, descr=simplevalue)
        jump(p0, p0, i3)
        """
        es, loop, preamble = self.optimize(loop)
        vs = es.virtual_state
        assert vs.state[0] is vs.state[1]
        assert isinstance(vs.state[0], VirtualStateInfo)
        assert isinstance(vs.state[0].fieldstate[0], NotVirtualStateInfo)
        assert vs.state[0].fieldstate[0].level == LEVEL_UNKNOWN
        assert vs.numnotvirtuals == 1
        p = InputArgRef()
        i = InputArgInt()
        ptrinfo = info.StructPtrInfo(self.nodesize, is_virtual=True)
        ptrinfo._fields = [i]
        p.set_forwarded(ptrinfo)
        vs.make_inputargs([p, p, i], FakeOptimizer())

    def test_short_boxes_heapcache(self):
        loop = """
        [p0, i1]
        i0 = getfield_gc_i(p0, descr=valuedescr)
        jump(p0, i1)
        """
        es, loop, preamble = self.optimize(loop)
        op = preamble.operations[0]
        short_boxes = [box for box in es.short_boxes
                       if not isinstance(box.short_op, ShortInputArg)]
        assert len(short_boxes) == 1
        assert short_boxes[0].short_op.res is op
        sb = ShortPreambleBuilder(loop.inputargs,
                                  es.short_boxes, es.short_inputargs,
                                  es.exported_infos, FakeOptimizer())
        op = preamble.operations[0]
        short_op = sb.use_box(op, short_boxes[0].preamble_op, FakeOptimizer())
        sb.add_preamble_op(PreambleOp(op, short_op, False))
        exp_short = """
        [p0, i1]
        guard_nonnull(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        i0 = getfield_gc_i(p0, descr=valuedescr)
        jump(i0)
        """
        self.compare_short(sb.build_short_preamble(), exp_short)

    def test_int_is_true(self):
        loop = """
        [i0]
        i1 = int_is_true(i0)
        guard_true(i1) []
        jump(i0)
        """
        es, loop, preamble = self.optimize(loop)
        op = preamble.operations[0]
        short_boxes = [box for box in es.short_boxes
                       if not isinstance(box.short_op, ShortInputArg)]
        assert short_boxes[0].short_op.res is op
        assert es.exported_infos[op].is_constant()

    def test_only_setfield(self):
        loop = """
        [p0, p1]
        setfield_gc(p0, 5, descr=valuedescr)
        setfield_gc(p1, 5, descr=nextdescr)
        jump(p0, p1)
        """
        es, loop, preamble = self.optimize(loop)
        p0, p1 = es.short_inputargs
        short_boxes = [box for box in es.short_boxes
                       if not isinstance(box.short_op, ShortInputArg)]
        assert short_boxes[0].short_op.res.getint() == 5
        assert short_boxes[1].short_op.res.getint() == 5
        assert short_boxes[0].preamble_op.getarg(0) is p0
        assert short_boxes[1].preamble_op.getarg(0) is p1

    def test_double_getfield_plus_pure(self):
        loop = """
        [p0]
        pc = getfield_gc_r(p0, descr=nextdescr3)
        escape_n(p0) # that should flush the caches
        p1 = getfield_gc_r(pc, descr=nextdescr3)
        i0 = getfield_gc_i(p1, descr=valuedescr3)
        jump(p0)
        """
        es, loop, preamble = self.optimize(loop)
        assert len(es.short_boxes) == 4
        # both getfields are available as
        # well as getfield_gc

    def test_p123_anti_nested(self):
        loop = """
        [i1, p2, p3]
        p3sub = getfield_gc_r(p3, descr=nextdescr)
        i3 = getfield_gc_i(p3sub, descr=valuedescr)
        escape_n(i3)
        p1 = new_with_vtable(descr=nodesize)
        p2sub = new_with_vtable(descr=nodesize2)
        setfield_gc(p2sub, i1, descr=valuedescr)
        setfield_gc(p2, p2sub, descr=nextdescr)
        jump(i1, p1, p2)
        """
        es, loop, preamble = self.optimize(loop)
        assert len(producable_short_boxes(es.short_boxes)) == 1

    def test_setfield_forced_virtual(self):
        loop = """
        [p1, p2]
        i1 = getfield_gc_i(p1, descr=valuedescr)
        setfield_gc(p2, i1, descr=valuedescr)
        p3 = new_with_vtable(descr=nodesize)
        jump(p2, p3)
        """
        es, loop, preamble = self.optimize(loop)
        sb = ShortPreambleBuilder(loop.inputargs, es.short_boxes,
                                  es.short_inputargs,
                                  es.exported_infos)
        short_boxes = [box for box in es.short_boxes
                       if not isinstance(box.short_op, ShortInputArg)]
        op = short_boxes[0].short_op.res
        pop = sb.use_box(op, short_boxes[0].preamble_op, FakeOptimizer())
        sb.add_preamble_op(PreambleOp(op, pop, False))
        exp_short = """
        [p0, p1]
        guard_nonnull(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        i1 = getfield_gc_i(p0, descr=valuedescr)
        jump(i1)
        """
        self.compare_short(sb.build_short_preamble(), exp_short)

    def test_loopinvariant(self):
        loop = """
        [i1]
        i2 = call_loopinvariant_i(1, i1, descr=nonwritedescr)
        guard_no_exception() []
        guard_value(i2, 1) []
        jump(i1)
        """
        es, loop, preamble = self.optimize(loop)
        assert len(es.short_boxes) == 2

    def test_circular_force(self):
        ops = """
        [p0]
        p41 = getfield_gc_r(p0, descr=nextdescr)
        i0 = getfield_gc_i(p41, descr=valuedescr)
        p1 = new_with_vtable(descr=nodesize2)
        p2 = new_with_vtable(descr=nodesize2)
        setfield_gc(p2, p1, descr=nextdescr)
        setfield_gc(p1, p2, descr=nextdescr)
        i1 = int_add(i0, 1)
        setfield_gc(p2, i1, descr=valuedescr)
        setfield_gc(p0, p1, descr=nextdescr)
        jump(p1)
        """
        es, loop, preamble = self.optimize(ops)
        # assert did not crash
