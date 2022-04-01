from rpython.rtyper.llinterp import LLInterpreter
from rpython.translator.backendopt.tailrecursion import remove_tail_calls_to_self
from rpython.translator.translator import TranslationContext, graphof


def test_recursive_gcd():
    def gcd(a, b):
        if a == 1 or a == 0:
            return b
        if a > b:
            return gcd(b, a)
        return gcd(b % a, a)
    t = TranslationContext()
    t.buildannotator().build_types(gcd, [int, int])
    t.buildrtyper().specialize()
    gcd_graph = graphof(t, gcd)
    remove_tail_calls_to_self(t, gcd_graph)
    lli = LLInterpreter(t.rtyper)
    res = lli.eval_graph(gcd_graph, (15, 25))
    assert res == 5
