from rpython.translator.backendopt import graphanalyze
from rpython.rtyper.lltypesystem.lloperation import LL_OPERATIONS

# NB. tests are in rpython/memory/gctransform/test/test_framework.py


class CollectAnalyzer(graphanalyze.BoolGraphAnalyzer):

    def analyze_direct_call(self, graph, seen=None):
        try:
            func = graph.func
        except AttributeError:
            pass
        else:
            if getattr(func, '_gctransformer_hint_cannot_collect_', False):
                return False
            if getattr(func, '_gctransformer_hint_close_stack_', False):
                return True
        return graphanalyze.BoolGraphAnalyzer.analyze_direct_call(self, graph,
                                                                  seen)
    def analyze_external_call(self, funcobj, seen=None):
        if funcobj.random_effects_on_gcobjs:
            return True
        return graphanalyze.BoolGraphAnalyzer.analyze_external_call(
            self, funcobj, seen)

    def analyze_simple_operation(self, op, graphinfo):
        if op.opname in ('malloc', 'malloc_varsize'):
            flags = op.args[1].value
            return flags['flavor'] == 'gc'
        else:
            return (op.opname in LL_OPERATIONS and
                    LL_OPERATIONS[op.opname].canmallocgc)
