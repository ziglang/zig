from rpython.rtyper.lltypesystem.lloperation import LL_OPERATIONS
from rpython.tool.ansi_print import AnsiLogger
from rpython.translator.backendopt import graphanalyze

log = AnsiLogger("canraise")


class RaiseAnalyzer(graphanalyze.BoolGraphAnalyzer):
    ignore_exact_class = None

    def do_ignore_memory_error(self):
        self.ignore_exact_class = MemoryError

    def analyze_simple_operation(self, op, graphinfo):
        try:
            canraise = LL_OPERATIONS[op.opname].canraise
            return bool(canraise) and canraise != (self.ignore_exact_class,)
        except KeyError:
            log.WARNING("Unknown operation: %s" % op.opname)
            return True

    def analyze_external_call(self, fnobj, seen=None):
        return getattr(fnobj, 'canraise', True)

    analyze_exceptblock = None    # don't call this

    def analyze_exceptblock_in_graph(self, graph, block, seen=None):
        if self.ignore_exact_class is not None:
            from rpython.translator.backendopt.ssa import DataFlowFamilyBuilder
            dff = DataFlowFamilyBuilder(graph)
            variable_families = dff.get_variable_families()
            v_exc_instance = variable_families.find_rep(block.inputargs[1])
            for link1 in graph.iterlinks():
                v = link1.last_exc_value
                if v is not None:
                    if variable_families.find_rep(v) is v_exc_instance:
                        # this is a case of re-raise the exception caught;
                        # it doesn't count.  We'll see the place that really
                        # raises the exception in the first place.
                        return False
        return True

    # backward compatible interface
    def can_raise(self, op, seen=None):
        return self.analyze(op, seen)
