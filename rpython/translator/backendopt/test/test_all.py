import py
from rpython.translator.backendopt.all import backend_optimizations
from rpython.translator.backendopt.all import INLINE_THRESHOLD_FOR_TEST
from rpython.translator.backendopt.support import md5digest
from rpython.translator.backendopt.test.test_malloc import TestMallocRemoval as MallocRemovalTest
from rpython.translator.translator import TranslationContext, graphof
from rpython.flowspace.model import Constant, summary
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rlib.rarithmetic import intmask
from rpython.conftest import option

class A:
    def __init__(self, x, y):
        self.bounds = (x, y)
    def mean(self, percentage=50):
        x, y = self.bounds
        total = x*percentage + y*(100-percentage)
        return total//100

def condition(n):
    return n >= 100

def firstthat(function, condition):
    for n in range(101):
        if condition(function(n)):
            return n
    else:
        return -1

def myfunction(n):
    a = A(117, n)
    return a.mean()

def big():
    """This example should be turned into a simple 'while' loop with no
    malloc nor direct_call by back-end optimizations, given a high enough
    inlining threshold.
    """
    return firstthat(myfunction, condition)

LARGE_THRESHOLD  = 10*INLINE_THRESHOLD_FOR_TEST
HUGE_THRESHOLD  = 100*INLINE_THRESHOLD_FOR_TEST

class TestLLType(object):
    check_malloc_removed = MallocRemovalTest.check_malloc_removed

    def translateopt(self, func, sig, **optflags):
        t = TranslationContext()
        opts = {'translation.list_comprehension_operations': True}
        t.config.set(**opts)
        t.buildannotator().build_types(func, sig)
        t.buildrtyper().specialize()
        if option.view:
            t.view()
        backend_optimizations(t, **optflags)
        if option.view:
            t.view()
        return t

    def test_big(self):
        assert big() == 83

        t = self.translateopt(big, [], inline_threshold=HUGE_THRESHOLD,
                              mallocs=True)

        big_graph = graphof(t, big)
        self.check_malloc_removed(big_graph)

        interp = LLInterpreter(t.rtyper)
        res = interp.eval_graph(big_graph, [])
        assert res == 83


    def test_for_loop(self):
        def f(n):
            total = 0
            for i in range(n):
                total += i
            return total

        t  = self.translateopt(f, [int], mallocs=True)
        # this also checks that the BASE_INLINE_THRESHOLD is enough
        # for 'for' loops

        f_graph = graph = graphof(t, f)
        self.check_malloc_removed(f_graph)

        interp = LLInterpreter(t.rtyper)
        res = interp.eval_graph(f_graph, [11])
        assert res == 55

    def test_premature_death(self):
        import os
        from rpython.annotator.listdef import s_list_of_strings

        inputtypes = [s_list_of_strings]

        def debug(msg):
            os.write(2, "debug: " + msg + '\n')

        def entry_point(argv):
            #debug("entry point starting")
            for arg in argv:
                #debug(" argv -> " + arg)
                r = arg.replace('_', '-')
                #debug(' replaced -> ' + r)
                a = r.lower()
                #debug(" lowered -> " + a)
            return 0

        t  = self.translateopt(entry_point, inputtypes, mallocs=True)

        entry_point_graph = graphof(t, entry_point)

        argv = t.rtyper.getrepr(inputtypes[0]).convert_const(['./pypy-c'])

        interp = LLInterpreter(t.rtyper)
        interp.eval_graph(entry_point_graph, [argv])


    def test_idempotent(self):
        def s(x):
            res = 0
            i = 1
            while i <= x:
                res += i
                i += 1
            return res

        def g(x):
            return s(100) + s(1) + x

        def idempotent(n1, n2):
            c = [i for i in range(n2)]
            return 33 + big() + g(10)

        t  = self.translateopt(idempotent, [int, int],
                               constfold=False)
        #backend_optimizations(t, inline_threshold=0, constfold=False)

        digest1 = md5digest(t)

        digest2 = md5digest(t)
        def compare(digest1, digest2):
            diffs = []
            assert digest1.keys() == digest2.keys()
            for name in digest1:
                if digest1[name] != digest2[name]:
                    diffs.append(name)
            assert not diffs

        compare(digest1, digest2)

        #XXX Inlining and constfold are currently non-idempotent.
        #    Maybe they just renames variables but the graph changes in some way.
        backend_optimizations(t, inline_threshold=0, constfold=False)
        digest3 = md5digest(t)
        compare(digest1, digest3)

    def test_bug_inlined_if(self):
        def f(x, flag):
            if flag:
                y = x
            else:
                y = x+1
            return y*5
        def myfunc(x):
            return f(x, False) - f(x, True)

        assert myfunc(10) == 5

        t = self.translateopt(myfunc, [int], inline_threshold=HUGE_THRESHOLD)
        interp = LLInterpreter(t.rtyper)
        res = interp.eval_graph(graphof(t, myfunc), [10])
        assert res == 5

    def test_range_iter(self):
        def fn(start, stop, step):
            res = 0
            if step == 0:
                if stop >= start:
                    r = range(start, stop, 1)
                else:
                    r = range(start, stop, -1)
            else:
                r = range(start, stop, step)
            for i in r:
                res = res * 51 + i
            return res
        t = self.translateopt(fn, [int, int, int], merge_if_blocks=True)
        interp = LLInterpreter(t.rtyper)
        for args in [2, 7, 0], [7, 2, 0], [10, 50, 7], [50, -10, -3]:
            assert interp.eval_graph(graphof(t, fn), args) == intmask(fn(*args))

    def test_constant_diffuse(self):
        def g(x,y):
            if x < 0:
                return 0
            return x + y

        def f(x):
            return g(x,7)+g(x,11)

        t = self.translateopt(f, [int])
        fgraph = graphof(t, f)

        for link in fgraph.iterlinks():
            assert Constant(7) not in link.args
            assert Constant(11) not in link.args

    def test_isinstance(self):
        class A:
            pass
        class B(A):
            pass
        def g(n):
            if n > 10:
                return A()
            else:
                b = B()
                b.value = 321
                return b
        def fn(n):
            x = g(n)
            assert isinstance(x, B)
            return x.value
        t = self.translateopt(fn, [int], really_remove_asserts=True,
                              remove_asserts=True)
        graph = graphof(t, fn)
        assert "direct_call" not in summary(graph)

    def test_list_comp(self):
        def f(n1, n2):
            c = [i for i in range(n2)]
            return 33

        t  = self.translateopt(f, [int, int], inline_threshold=LARGE_THRESHOLD,
                               mallocs=True)

        f_graph = graphof(t, f)
        self.check_malloc_removed(f_graph)

        interp = LLInterpreter(t.rtyper)
        res = interp.eval_graph(f_graph, [11, 22])
        assert res == 33

    def test_secondary_backendopt(self):
        # checks an issue with a newly added graph that calls an
        # already-exception-transformed graph.  This can occur e.g.
        # from a late-seen destructor added by the GC transformer
        # which ends up calling existing code.
        def common(n):
            if n > 5:
                raise ValueError
        def main(n):
            common(n)
        def later(n):
            try:
                common(n)
                return 0
            except ValueError:
                return 1

        t = TranslationContext()
        t.buildannotator().build_types(main, [int])
        t.buildrtyper().specialize()
        exctransformer = t.getexceptiontransformer()
        exctransformer.create_exception_handling(graphof(t, common))
        from rpython.annotator import model as annmodel
        from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
        annhelper = MixLevelHelperAnnotator(t.rtyper)
        later_graph = annhelper.getgraph(later, [annmodel.SomeInteger()],
                                         annmodel.SomeInteger())
        annhelper.finish()
        annhelper.backend_optimize()
        # ^^^ as the inliner can't handle exception-transformed graphs,
        # this should *not* inline common() into later().
        if option.view:
            later_graph.show()
        common_graph = graphof(t, common)
        found = False
        for block in later_graph.iterblocks():
            for op in block.operations:
                if (op.opname == 'direct_call' and
                    op.args[0].value._obj.graph is common_graph):
                    found = True
        assert found, "cannot find the call (buggily inlined?)"
        from rpython.rtyper.llinterp import LLInterpreter
        llinterp = LLInterpreter(t.rtyper)
        res = llinterp.eval_graph(later_graph, [10])
        assert res == 1

    def test_replace_we_are_jitted(self):
        from rpython.rlib import jit
        def f():
            if jit.we_are_jitted():
                return 1
            return 2 + jit.we_are_jitted()

        t = self.translateopt(f, [])
        graph = graphof(t, f)
        # by default, replace_we_are_jitted is off
        assert graph.startblock.operations[0].args[0].value is jit._we_are_jitted

        t = self.translateopt(f, [], replace_we_are_jitted=True)
        graph = graphof(t, f)
        assert graph.startblock.exits[0].args[0].value == 2
