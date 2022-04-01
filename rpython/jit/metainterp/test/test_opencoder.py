import py
from rpython.jit.metainterp.opencoder import Trace, untag, TAGINT, TAGBOX
from rpython.jit.metainterp.resoperation import rop, AbstractResOp
from rpython.jit.metainterp.history import ConstInt, IntFrontendOp
from rpython.jit.metainterp.optimizeopt.optimizer import Optimizer
from rpython.jit.metainterp import resume
from rpython.jit.metainterp.test.strategies import lists_of_operations
from rpython.jit.metainterp.optimizeopt.test.test_util import BaseTest
from rpython.jit.metainterp.history import TreeLoop, AbstractDescr
from rpython.jit.metainterp.history import SwitchToBlackhole
from hypothesis import given, strategies

class JitCode(object):
    def __init__(self, index):
        self.index = index

class SomeDescr(AbstractDescr):
    pass

class metainterp_sd(object):
    all_descrs = []

class FakeOp(AbstractResOp):
    def __init__(self, pos):
        self.pos = pos

    def get_position(self):
        return self.pos

class FakeFrame(object):
    parent_snapshot = None

    def __init__(self, pc, jitcode, boxes):
        self.pc = pc
        self.jitcode = jitcode
        self.boxes = boxes

    def get_list_of_active_boxes(self, flag, new_array, encode):
        a = new_array(len(self.boxes))
        for i, box in enumerate(self.boxes):
            a[i] = encode(box)
        return a

def unpack_snapshot(t, op, pos):
    op.framestack = []
    si = t.get_snapshot_iter(op.rd_resume_position)
    virtualizables = si.unpack_array(si.vable_array)
    vref_boxes = si.unpack_array(si.vref_array)
    for snapshot in si.framestack:
        jitcode, pc = si.unpack_jitcode_pc(snapshot)
        boxes = si.unpack_array(snapshot.box_array)
        op.framestack.append(FakeFrame(JitCode(jitcode), pc, boxes))
    op.virtualizables = virtualizables
    op.vref_boxes = vref_boxes

class TestOpencoder(object):
    def unpack(self, t):
        iter = t.get_iter()
        l = []
        while not iter.done():
            op = iter.next()
            if op.is_guard():
                unpack_snapshot(iter, op, op.rd_resume_position)
            l.append(op)
        return iter.inputargs, l, iter

    def test_simple_iterator(self):
        i0, i1 = IntFrontendOp(0), IntFrontendOp(0)
        t = Trace([i0, i1], metainterp_sd)
        add = FakeOp(t.record_op(rop.INT_ADD, [i0, i1]))
        t.record_op(rop.INT_ADD, [add, ConstInt(1)])
        (i0, i1), l, _ = self.unpack(t)
        assert len(l) == 2
        assert l[0].opnum == rop.INT_ADD
        assert l[1].opnum == rop.INT_ADD
        assert l[1].getarg(1).getint() == 1
        assert l[1].getarg(0) is l[0]
        assert l[0].getarg(0) is i0
        assert l[0].getarg(1) is i1

    def test_rd_snapshot(self):
        i0, i1 = IntFrontendOp(0), IntFrontendOp(0)
        t = Trace([i0, i1], metainterp_sd)
        add = FakeOp(t.record_op(rop.INT_ADD, [i0, i1]))
        t.record_op(rop.GUARD_FALSE, [add])
        # now we write rd_snapshot and friends
        frame0 = FakeFrame(1, JitCode(2), [i0, i1])
        frame1 = FakeFrame(3, JitCode(4), [i0, i0, add])
        framestack = [frame0]
        resume.capture_resumedata(framestack, None, [], t)
        (i0, i1), l, iter = self.unpack(t)
        assert l[1].opnum == rop.GUARD_FALSE
        assert l[1].framestack[0].boxes == [i0, i1]
        t.record_op(rop.GUARD_FALSE, [add])
        resume.capture_resumedata([frame0, frame1], None, [], t)
        t.record_op(rop.INT_ADD, [add, add])
        (i0, i1), l, iter = self.unpack(t)
        assert l[1].opnum == rop.GUARD_FALSE
        assert l[1].framestack[0].boxes == [i0, i1]
        assert l[2].opnum == rop.GUARD_FALSE
        fstack = l[2].framestack
        assert fstack[0].boxes == [i0, i1]
        assert fstack[1].boxes == [i0, i0, l[0]]

    def test_read_snapshot_interface(self):
        i0, i1, i2 = IntFrontendOp(0), IntFrontendOp(0), IntFrontendOp(0)
        t = Trace([i0, i1, i2], metainterp_sd)
        t.record_op(rop.GUARD_TRUE, [i1])
        frame0 = FakeFrame(1, JitCode(2), [i0, i1])
        frame1 = FakeFrame(3, JitCode(4), [i2, i2])
        resume.capture_resumedata([frame0, frame1], None, [], t)
        t.record_op(rop.GUARD_TRUE, [i1])
        resume.capture_resumedata([frame0, frame1], None, [], t)
        (i0, i1, i2), l, iter = self.unpack(t)
        pos = l[0].rd_resume_position
        snapshot_iter = iter.get_snapshot_iter(pos)
        assert snapshot_iter.vable_array == []
        assert snapshot_iter.vref_array == []
        framestack = snapshot_iter.framestack
        jc_index, pc = snapshot_iter.unpack_jitcode_pc(framestack[1])
        assert jc_index == 4
        assert pc == 3
        assert snapshot_iter.unpack_array(framestack[1].box_array) == [i2, i2]
        jc_index, pc = snapshot_iter.unpack_jitcode_pc(framestack[0])
        assert jc_index == 2
        assert pc == 1
        assert snapshot_iter.unpack_array(framestack[0].box_array) == [i0, i1]
        pos = l[1].rd_resume_position
        snapshot_iter = iter.get_snapshot_iter(pos)
        framestack = snapshot_iter.framestack
        assert snapshot_iter.vable_array == []
        assert snapshot_iter.vref_array == []
        jc_index, pc = snapshot_iter.unpack_jitcode_pc(framestack[1])
        assert jc_index == 4
        assert pc == 3
        assert snapshot_iter.unpack_array(framestack[1].box_array) == [i2, i2]

    # XXXX fixme
    @given(lists_of_operations())
    def xxx_test_random_snapshot(self, lst):
        inputargs, ops = lst
        t = Trace(inputargs, metainterp_sd)
        for op in ops:
            newop = FakeOp(t.record_op(op.getopnum(), op.getarglist()))
            newop.orig_op = op
            if newop.is_guard():
                resume.capture_resumedata(op.framestack,
                    None, [], t)
            op.position = newop.get_position()
        inpargs, l, iter = self.unpack(t)
        loop1 = TreeLoop("loop1")
        loop1.inputargs = inputargs
        loop1.operations = ops
        loop2 = TreeLoop("loop2")
        loop2.inputargs = inpargs
        loop2.operations = l
        BaseTest.assert_equal(loop1, loop2)

    def test_cut_trace_from(self):
        i0, i1, i2 = IntFrontendOp(0), IntFrontendOp(0), IntFrontendOp(0)
        t = Trace([i0, i1, i2], metainterp_sd)
        add1 = FakeOp(t.record_op(rop.INT_ADD, [i0, i1]))
        cut_point = t.cut_point()
        add2 = FakeOp(t.record_op(rop.INT_ADD, [add1, i1]))
        t.record_op(rop.GUARD_TRUE, [add2])
        resume.capture_resumedata([FakeFrame(3, JitCode(4), [add2, add1, i1])],
            None, [], t)
        t.record_op(rop.INT_SUB, [add2, add1])
        t2 = t.cut_trace_from(cut_point, [add1, i1])
        (i0, i1), l, iter = self.unpack(t2)
        assert len(l) == 3
        assert l[0].getarglist() == [i0, i1]

    def test_virtualizable_virtualref(self):
        i0, i1, i2 = IntFrontendOp(0), IntFrontendOp(0), IntFrontendOp(0)
        t = Trace([i0, i1, i2], metainterp_sd)
        p0 = FakeOp(t.record_op(rop.NEW_WITH_VTABLE, [], descr=SomeDescr()))
        t.record_op(rop.GUARD_TRUE, [i0])
        resume.capture_resumedata([], [i1, i2, p0], [p0, i1], t)
        (i0, i1, i2), l, iter = self.unpack(t)
        assert not l[1].framestack
        assert l[1].virtualizables == [l[0], i1, i2]
        assert l[1].vref_boxes == [l[0], i1]

    def test_liveranges(self):
        i0, i1, i2 = IntFrontendOp(0), IntFrontendOp(0), IntFrontendOp(0)
        t = Trace([i0, i1, i2], metainterp_sd)
        p0 = FakeOp(t.record_op(rop.NEW_WITH_VTABLE, [], descr=SomeDescr()))
        t.record_op(rop.GUARD_TRUE, [i0])
        resume.capture_resumedata([], [i1, i2, p0], [p0, i1], t)
        assert t.get_live_ranges() == [4, 4, 4, 4]

    def test_deadranges(self):
        i0, i1, i2 = IntFrontendOp(0), IntFrontendOp(0), IntFrontendOp(0)
        t = Trace([i0, i1, i2], metainterp_sd)
        p0 = FakeOp(t.record_op(rop.NEW_WITH_VTABLE, [], descr=SomeDescr()))
        t.record_op(rop.GUARD_TRUE, [i0])
        resume.capture_resumedata([], [i1, i2, p0], [p0, i1], t)
        i3 = FakeOp(t.record_op(rop.INT_ADD, [i1, ConstInt(1)]))
        i4 = FakeOp(t.record_op(rop.INT_ADD, [i3, ConstInt(1)]))
        t.record_op(rop.ESCAPE_N, [ConstInt(3)])
        t.record_op(rop.ESCAPE_N, [ConstInt(3)])
        t.record_op(rop.ESCAPE_N, [ConstInt(3)])
        t.record_op(rop.ESCAPE_N, [ConstInt(3)])
        t.record_op(rop.ESCAPE_N, [ConstInt(3)])
        t.record_op(rop.FINISH, [i4])
        assert t.get_dead_ranges() == [0, 0, 0, 0, 0, 3, 4, 5]

    def test_tag_overflow(self):
        t = Trace([], metainterp_sd)
        i0 = FakeOp(100000)
        # if we overflow, we can keep recording
        for i in range(10):
            t.record_op(rop.FINISH, [i0])
            assert t.unpack() == ([], [])
        assert t.tag_overflow
