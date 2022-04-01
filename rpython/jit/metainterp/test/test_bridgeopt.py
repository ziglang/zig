# tests that check that information is fed from the optimizer into the bridges

import pytest

import math

from rpython.rlib import jit
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp.optimizeopt.bridgeopt import serialize_optimizer_knowledge
from rpython.jit.metainterp.optimizeopt.bridgeopt import deserialize_optimizer_knowledge
from rpython.jit.metainterp.resoperation import InputArgRef, InputArgInt
from rpython.jit.metainterp.resume import NumberingState
from rpython.jit.metainterp.resumecode import unpack_numbering
from rpython.jit.metainterp.optimizeopt.info import InstancePtrInfo

from hypothesis import strategies, given


class FakeCPU(object):
    def __init__(self, dct):
        self.dct = dct

    def cls_of_box(self, box):
        return self.dct[box]

class FakeOptimizer(object):
    metainterp_sd = None
    optheap = None
    optrewrite = None

    def __init__(self, cpu=None):
        self.constant_classes = {}
        self.cpu = cpu

    def make_constant_class(self, arg, cls):
        self.constant_classes[arg] = cls

class FakeClass(object):
    pass

class FakeStorage(object):
    def __init__(self, numb):
        self.rd_numb = numb

def test_known_classes():
    cls = FakeClass()
    box1 = InputArgRef()
    box1.set_forwarded(InstancePtrInfo(known_class=cls))
    box2 = InputArgRef()
    box3 = InputArgRef()
    optimizer = FakeOptimizer()

    numb_state = NumberingState(4)
    numb_state.append_int(1) # size of resume block
    liveboxes = [InputArgInt(), box2, box1, box3]

    serialize_optimizer_knowledge(optimizer, numb_state, liveboxes, {}, None)

    assert unpack_numbering(numb_state.create_numbering()) == [
            1, 0b010000, 0, 0, 0]

    rbox1 = InputArgRef()
    rbox2 = InputArgRef()
    rbox3 = InputArgRef()
    after_optimizer = FakeOptimizer(cpu=FakeCPU({rbox1: cls}))
    deserialize_optimizer_knowledge(
        after_optimizer, FakeStorage(numb_state.create_numbering()),
        [InputArgInt(), rbox2, rbox1, rbox3], liveboxes)
    assert box1 in after_optimizer.constant_classes
    assert box2 not in after_optimizer.constant_classes
    assert box3 not in after_optimizer.constant_classes


box_strategy = strategies.builds(InputArgInt) | strategies.builds(InputArgRef)
def _make_tup(box, known_class):
    if isinstance(box, InputArgInt):
        known_class = False
    return box, known_class
tuples = strategies.builds(_make_tup, box_strategy, strategies.booleans())
boxes_known_classes = strategies.lists(tuples, min_size=1)

@given(boxes_known_classes)
def test_random_class_knowledge(boxes_known_classes):
    cls = FakeClass()
    for box, known_class in boxes_known_classes:
        if known_class:
            box.set_forwarded(InstancePtrInfo(known_class=cls))
    optimizer = FakeOptimizer()

    refboxes = [box for (box, _) in boxes_known_classes
                    if isinstance(box, InputArgRef)]

    numb_state = NumberingState(1)
    numb_state.append_int(1) # size of resume block
    liveboxes = [box for (box, _) in boxes_known_classes]

    serialize_optimizer_knowledge(optimizer, numb_state, liveboxes, {}, None)

    assert len(numb_state.create_numbering().code) == 4 + math.ceil(len(refboxes) / 6.0)

    dct = {box: cls
              for box, known_class in boxes_known_classes
                  if known_class}
    after_optimizer = FakeOptimizer(cpu=FakeCPU(dct))
    deserialize_optimizer_knowledge(
        after_optimizer, FakeStorage(numb_state.create_numbering()),
        liveboxes, liveboxes)
    for box, known_class in boxes_known_classes:
        assert (box in after_optimizer.constant_classes) == known_class

class TestOptBridge(LLJitMixin):
    # integration tests
    def test_bridge_guard_class(self):
        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n', 'a'])
        class A(object):
            def f(self):
                return 1
        class B(A):
            def f(self):
                return 2
        def f(x, y, n):
            if x:
                a = A()
            else:
                a = B()
            a.x = 0
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res, a=a)
                res += a.f()
                a.x += 1
                if y > n:
                    res += 1
                res += a.f()
                y -= 1
            return res
        res = self.meta_interp(f, [6, 32, 16])
        assert res == f(6, 32, 16)
        self.check_trace_count(3)
        self.check_resops(guard_class=1)

    def test_bridge_guard_class_return(self):
        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n', 'a'])
        class A(object):
            def f(self):
                return 1
        class B(A):
            def f(self):
                return 2
        def f(x, y, n):
            if x:
                a = A()
            else:
                a = B()
            a.x = 0
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res, a=a)
                res += a.f()
                a.x += 1
                if y < n:
                    res += 1
                    res += a.f()
                    return res
                res += a.f()
                y -= 1
            return res
        def g(i):
            res = 0
            for i in range(i):
                res += f(6, 32, 16-i)
        res1 = g(10)
        res2 = self.meta_interp(g, [10])
        assert res1 == res2
        self.check_trace_count(2)
        self.check_resops(guard_class=1, omit_finish=False)

    def test_bridge_field_read(self):
        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n', 'a'])
        class A(object):
            pass
        class M(object):
            _immutable_fields_ = ['x']
            def __init__(self, x):
                self.x = x

        m1 = M(1)
        m2 = M(2)
        def f(x, y, n):
            a = A()
            a.n = n
            if x:
                a.m = m1
            else:
                a.m = m2
            a.x = 0
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res, a=a)
                n1 = a.n
                m = jit.promote(a.m)
                res += m.x
                a.x += 1
                if y > n:
                    res += 1
                m = jit.promote(a.m)
                res += m.x
                res += n1 + a.n
                y -= 1
            return res
        res = self.meta_interp(f, [6, 32, 16])
        assert res == f(6, 32, 16)
        self.check_trace_count(3)
        self.check_resops(guard_value=1)
        self.check_resops(getfield_gc_i=4) # 3x a.x, 1x a.n
        self.check_resops(getfield_gc_r=1) # in main loop

    def test_bridge_field_read_constants(self):
        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n'])
        class A(object):
            pass
        class M(object):
            _immutable_fields_ = ['x']
            def __init__(self, x):
                self.x = x

        m1 = M(1)
        m2 = M(2)
        a = A()
        a.m = m1
        a.n = 0
        def f(x, y, n):
            if x:
                a.m = m1
                a.n = n
            else:
                a.m = m2
                a.n = n
            a.x = 0
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res)
                n1 = a.n
                m = jit.promote(a.m)
                res += m.x
                a.x += 1
                if y > n:
                    res += 1
                m = jit.promote(a.m)
                res += m.x
                res += n1 + a.n
                y -= 1
            return res
        res = self.meta_interp(f, [6, 32, 16])
        assert res == f(6, 32, 16)
        self.check_trace_count(3)
        self.check_resops(guard_value=1)
        self.check_resops(getfield_gc_i=4) # 3x a.x, 1x a.n
        self.check_resops(getfield_gc_r=1) # in main loop

    def test_bridge_array_read(self):
        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n', 'a'])
        def f(x, y, n):
            if x:
                a = [1, n, 0]
            else:
                a = [2, n, 0]
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res, a=a)
                n1 = a[1]
                m = jit.promote(a[0])
                res += m
                a[2] += 1
                if y > n:
                    res += 1
                m = jit.promote(a[0])
                res += m
                res += n1 + a[1]
                y -= 1
            return res
        res = self.meta_interp(f, [6, 32, 16])
        assert res == f(6, 32, 16)
        self.check_trace_count(3)
        self.check_resops(guard_value=1)
        self.check_resops(getarrayitem_gc_i=4)

    def test_bridge_array_read_constant(self):
        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n'])
        class A(object):
            pass
        a = A()
        a.l = [1, -65, 0]
        def f(x, y, n):
            if x:
                a.l[0] = 1
            else:
                a.l[0] = 2
            a.l[1] = n
            a.l[2] = 0
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res)
                n1 = a.l[1]
                m = jit.promote(a.l[0])
                res += m
                a.l[2] += 1
                if y > n:
                    res += 1
                m = jit.promote(a.l[0])
                res += m
                res += n1 + a.l[1]
                y -= 1
            return res
        res = self.meta_interp(f, [6, 32, 16])
        assert res == f(6, 32, 16)
        self.check_trace_count(3)
        self.check_resops(guard_value=1)
        self.check_resops(getarrayitem_gc_i=5)

    def test_bridge_call_loopinvariant(self):
        class A(object):
            pass
        class B(object):
            pass

        aholder = B()
        aholder.a = A()

        @jit.loop_invariant
        def get():
            return aholder.a

        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n'])
        def f(x, y, n):
            if x == 10001121:
                aholder.a = A()
            if x:
                get().x = 1
            else:
                get().x = 2
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res)
                a = get()
                a = get()
                res += a.x
                if y > n:
                    res += 1
                res += get().x + a.x
                y -= 1
            return res
        res = self.meta_interp(f, [6, 32, 16])
        self.check_trace_count(3)
        self.check_resops(call_r=1)

    @pytest.mark.xfail()
    def test_bridge_call_loopinvariant_2(self):
        class A(object):
            pass
        class B(object):
            pass

        aholder = B()
        aholder.a = A()

        @jit.loop_invariant
        def get():
            return aholder.a

        myjitdriver = jit.JitDriver(greens=[], reds=['y', 'res', 'n'])
        def f(x, y, n):
            if x == 10001121:
                aholder.a = A()
            if x:
                get().x = 1
            else:
                get().x = 2
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point(y=y, n=n, res=res)
                if y > n:
                    res += get().x
                    res += 1
                res += get().x
                y -= 1
            return res
        res = self.meta_interp(f, [6, 32, 16])
        self.check_trace_count(3)
        self.check_resops(call_r=1)
