from rpython.flowspace.model import *
from rpython.rlib.unroll import SpecTag
from rpython.flowspace.flowcontext import FlowContext
from rpython.flowspace.bytecode import HostCode
from rpython.flowspace.pygraph import PyGraph

class TestFrameState:
    def get_context(self, func):
        try:
            func = func.im_func
        except AttributeError:
            pass
        code = HostCode._from_code(func.__code__)
        graph = PyGraph(func, code)
        ctx = FlowContext(graph, code)
        # hack the frame
        ctx.setstate(graph.startblock.framestate)
        ctx.locals_w[-1] = Constant(None)
        return ctx

    def func_simple(x):
        spam = 5
        return spam

    def test_eq_framestate(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        fs2 = ctx.getstate(0)
        assert fs1.matches(fs2)

    def test_neq_hacked_framestate(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        ctx.locals_w[-1] = Variable()
        fs2 = ctx.getstate(0)
        assert not fs1.matches(fs2)

    def test_union_on_equal_framestates(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        fs2 = ctx.getstate(0)
        assert fs1.union(fs2).matches(fs1)

    def test_union_on_hacked_framestates(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        ctx.locals_w[-1] = Variable()
        fs2 = ctx.getstate(0)
        assert fs1.union(fs2).matches(fs2)  # fs2 is more general
        assert fs2.union(fs1).matches(fs2)  # fs2 is more general

    def test_restore_frame(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        ctx.locals_w[-1] = Variable()
        ctx.setstate(fs1)
        assert fs1.matches(ctx.getstate(0))

    def test_copy(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        fs2 = fs1.copy()
        assert fs1.matches(fs2)

    def test_getvariables(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        vars = fs1.getvariables()
        assert len(vars) == 1

    def test_getoutputargs(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        ctx.locals_w[-1] = Variable()
        fs2 = ctx.getstate(0)
        outputargs = fs1.getoutputargs(fs2)
        # 'x' -> 'x' is a Variable
        # locals_w[n-1] -> locals_w[n-1] is Constant(None)
        assert outputargs == [ctx.locals_w[0], Constant(None)]

    def test_union_different_constants(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        ctx.locals_w[-1] = Constant(42)
        fs2 = ctx.getstate(0)
        fs3 = fs1.union(fs2)
        ctx.setstate(fs3)
        assert isinstance(ctx.locals_w[-1], Variable)   # generalized

    def test_union_spectag(self):
        ctx = self.get_context(self.func_simple)
        fs1 = ctx.getstate(0)
        ctx.locals_w[-1] = Constant(SpecTag())
        fs2 = ctx.getstate(0)
        assert fs1.union(fs2) is None   # UnionError
