import py, sys
from rpython.jit.codewriter import support
from rpython.jit.codewriter.regalloc import perform_register_allocation
from rpython.jit.codewriter.flatten import flatten_graph, ListOfKind
from rpython.jit.codewriter.format import assert_format
from rpython.jit.metainterp.history import AbstractDescr
from rpython.flowspace.model import Variable, Constant, SpaceOperation
from rpython.flowspace.model import FunctionGraph, Block, Link
from rpython.flowspace.model import c_last_exception
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper import rclass
from rpython.rlib.rarithmetic import ovfcheck


class TestRegAlloc:

    def make_graphs(self, func, values):
        self.rtyper = support.annotate(func, values)
        return self.rtyper.annotator.translator.graphs

    def check_assembler(self, graph, expected, transform=False,
                        callcontrol=None):
        # 'transform' can be False only for simple graphs.  More complex
        # graphs must first be transformed by jtransform.py before they can be
        # subjected to register allocation and flattening.
        if transform:
            from rpython.jit.codewriter.jtransform import transform_graph
            transform_graph(graph, callcontrol=callcontrol)
        regalloc = perform_register_allocation(graph, 'int')
        regalloc2 = perform_register_allocation(graph, 'ref')
        ssarepr = flatten_graph(graph, {'int': regalloc,
                                        'ref': regalloc2})
        assert_format(ssarepr, expected)

    def test_regalloc_simple(self):
        def f(a, b):
            return a + b
        graph = self.make_graphs(f, [5, 6])[0]
        regalloc = perform_register_allocation(graph, 'int')
        va, vb = graph.startblock.inputargs
        vc = graph.startblock.operations[0].result
        assert regalloc.getcolor(va) == 0
        assert regalloc.getcolor(vb) == 1
        assert regalloc.getcolor(vc) == 0

    def test_regalloc_void(self):
        def f(a, b):
            while a > 0:
                b += a
                a -= 1
            return b
        graph = self.make_graphs(f, [5, 6])[0]
        regalloc = perform_register_allocation(graph, 'float')
        # assert did not crash

    def test_regalloc_loop(self):
        def f(a, b):
            while a > 0:
                b += a
                a -= 1
            return b
        graph = self.make_graphs(f, [5, 6])[0]
        self.check_assembler(graph, """
            L1:
            int_gt %i0, $0 -> %i2
            -live-
            goto_if_not %i2, L2
            int_add %i1, %i0 -> %i1
            int_sub %i0, $1 -> %i0
            goto L1
            ---
            L2:
            int_return %i1
        """)

    def test_regalloc_loop_swap(self):
        def f(a, b):
            while a > 0:
                a, b = b, a
            return b
        graph = self.make_graphs(f, [5, 6])[0]
        self.check_assembler(graph, """
            L1:
            int_gt %i0, $0 -> %i2
            -live-
            goto_if_not %i2, L2
            int_push %i1
            int_copy %i0 -> %i1
            int_pop -> %i0
            goto L1
            ---
            L2:
            int_return %i1
        """)

    def test_regalloc_loop_constant(self):
        def f(a, b):
            while a > 0:
                a, b = b, 2
            return b
        graph = self.make_graphs(f, [5, 6])[0]
        self.check_assembler(graph, """
            L1:
            int_gt %i0, $0 -> %i0
            -live-
            goto_if_not %i0, L2
            int_copy %i1 -> %i0
            int_copy $2 -> %i1
            goto L1
            ---
            L2:
            int_return %i1
        """)

    def test_regalloc_cycle(self):
        def f(a, b, c):
            while a > 0:
                a, b, c = b, c, a
            return b
        graph = self.make_graphs(f, [5, 6, 7])[0]
        self.check_assembler(graph, """
            L1:
            int_gt %i0, $0 -> %i3
            -live-
            goto_if_not %i3, L2
            int_push %i1
            int_copy %i2 -> %i1
            int_copy %i0 -> %i2
            int_pop -> %i0
            goto L1
            ---
            L2:
            int_return %i1
        """)

    def test_regalloc_same_as_var(self):
        def f(a, b, c):
            while a > 0:
                b = c
            return b
        graph = self.make_graphs(f, [5, 6, 7])[0]
        self.check_assembler(graph, """
            L1:
            int_gt %i0, $0 -> %i3
            -live-
            goto_if_not %i3, L2
            int_copy %i2 -> %i1
            goto L1
            ---
            L2:
            int_return %i1
        """)

    def test_regalloc_call(self):
        v1 = Variable(); v1.concretetype = lltype.Signed
        v2 = Variable(); v2.concretetype = lltype.Signed
        v3 = Variable(); v3.concretetype = lltype.Signed
        v4 = Variable(); v4.concretetype = lltype.Signed
        block = Block([v1])
        block.operations = [
            SpaceOperation('int_add', [v1, Constant(1, lltype.Signed)], v2),
            SpaceOperation('rescall', [ListOfKind('int', [v1, v2])], v3),
            ]
        graph = FunctionGraph('f', block, v4)
        block.closeblock(Link([v3], graph.returnblock))
        #
        self.check_assembler(graph, """
            int_add %i0, $1 -> %i1
            rescall I[%i0, %i1] -> %i0
            int_return %i0
        """)

    def test_regalloc_exitswitch_2(self):
        v1 = Variable(); v1.concretetype = rclass.CLASSTYPE
        v2 = Variable(); v2.concretetype = rclass.CLASSTYPE
        v3 = Variable(); v3.concretetype = rclass.CLASSTYPE
        v4 = Variable(); v4.concretetype = rclass.CLASSTYPE
        block = Block([])
        block.operations = [
            SpaceOperation('res_call', [], v1),
            SpaceOperation('-live-', [], None),
            ]
        graph = FunctionGraph('f', block, v4)
        exclink = Link([v2], graph.returnblock)
        exclink.llexitcase = 123     # normally an exception class
        exclink.last_exception = v2
        exclink.last_exc_value = "unused"
        block.exitswitch = c_last_exception
        block.closeblock(Link([v1], graph.returnblock),
                         exclink)
        #
        self.check_assembler(graph, """
            res_call -> %i0
            -live-
            catch_exception L1
            int_return %i0
            ---
            L1:
            goto_if_exception_mismatch $123, L2
            last_exception -> %i0
            int_return %i0
            ---
            L2:
            reraise
        """)

    def test_regalloc_lists(self):
        v1 = Variable(); v1.concretetype = lltype.Signed
        v2 = Variable(); v2.concretetype = lltype.Signed
        v3 = Variable(); v3.concretetype = lltype.Signed
        v4 = Variable(); v4.concretetype = lltype.Signed
        v5 = Variable(); v5.concretetype = lltype.Signed
        block = Block([v1])
        block.operations = [
            SpaceOperation('int_add', [v1, Constant(1, lltype.Signed)], v2),
            SpaceOperation('rescall', [ListOfKind('int', [v1, v2])], v5),
            SpaceOperation('rescall', [ListOfKind('int', [v1, v2])], v3),
            ]
        graph = FunctionGraph('f', block, v4)
        block.closeblock(Link([v3], graph.returnblock))
        #
        self.check_assembler(graph, """
            int_add %i0, $1 -> %i1
            rescall I[%i0, %i1] -> %i2
            rescall I[%i0, %i1] -> %i0
            int_return %i0
        """)

    def test_regalloc_bug_1(self):
        def _ll_2_int_lshift_ovf(x, y):
            result = x << y
            if (result >> y) != x:
                raise OverflowError
            return result
        graph = self.make_graphs(_ll_2_int_lshift_ovf, [5, 6])[0]
        self.check_assembler(graph, """
            int_lshift %i0, %i1 -> %i2
            int_rshift %i2, %i1 -> %i1
            -live-
            goto_if_not_int_ne %i1, %i0, L1
            raise $<* struct object>
            ---
            L1:
            int_return %i2
        """, transform=True)

    def test_regalloc_bug_2(self):
        class FakeDescr(AbstractDescr):
            def __repr__(self):
                return '<Descr>'
        class FakeCallControl:
            def guess_call_kind(self, op):
                return 'residual'
            def getcalldescr(self, op, **kwds):
                return FakeDescr()
            def calldescr_canraise(self, calldescr):
                return True
        class FooError(Exception):
            def __init__(self, num):
                self.num = num
        def g(n):
            if n > 100:
                raise FooError(n)
            return lltype.nullptr(llmemory.GCREF.TO)
        def foo(e):
            print "hello"
            return e
        def bar(e):
            print "world"
            return e
        def f(n, kref):
            kref2 = bar(kref)
            try:
                return g(n)
            except FooError as e:
                if foo(e):
                    return kref
                else:
                    return kref2
        graph = self.make_graphs(f, [5, lltype.nullptr(llmemory.GCREF.TO)])[0]
        # this used to produce bogus code, containing these two
        # lines in the following broken order:
        #    last_exc_value -> %r0
        #    ref_copy %r0 -> %r1    -- but expect to read the old value of %r0!
        self.check_assembler(graph, """
            residual_call_r_r $<* fn bar>, R[%r0], <Descr> -> %r1
            -live-
            residual_call_ir_r $<* fn g>, I[%i0], R[], <Descr> -> %r1
            -live-
            catch_exception L1
            ref_return %r1
            ---
            L1:
            goto_if_exception_mismatch $<* struct object_vtable>, L2
            ref_copy %r0 -> %r1
            last_exc_value -> %r0
            residual_call_r_r $<* fn foo>, R[%r0], <Descr> -> %r0
            -live-
            ref_return %r1
            ---
            L2:
            reraise
        """, transform=True, callcontrol=FakeCallControl())
