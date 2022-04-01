from rpython.jit.metainterp import history
from rpython.tool.udir import udir
from rpython.tool.ansi_print import AnsiLogger

log = AnsiLogger('jitcodewriter')


class JitPolicy(object):
    def __init__(self, jithookiface=None):
        self.unsafe_loopy_graphs = set()
        self.supports_floats = False
        self.supports_longlong = False
        self.supports_singlefloats = False
        self.jithookiface = jithookiface

    def set_supports_floats(self, flag):
        self.supports_floats = flag

    def set_supports_longlong(self, flag):
        self.supports_longlong = flag

    def set_supports_singlefloats(self, flag):
        self.supports_singlefloats = flag

    def dump_unsafe_loops(self):
        f = udir.join("unsafe-loops.txt").open('w')
        strs = [str(graph) for graph in self.unsafe_loopy_graphs]
        strs.sort()
        for graph in strs:
            print >> f, graph
        f.close()

    def look_inside_function(self, func):
        return True # look into everything by default

    def _reject_function(self, func):
        # explicitly elidable functions are always opaque
        if getattr(func, '_elidable_function_', False):
            return True
        # rpython.rtyper.module.* are opaque helpers
        mod = func.__module__ or '?'
        if mod.startswith('rpython.rtyper.module.'):
            return True
        return False

    def look_inside_graph(self, graph):
        from rpython.translator.backendopt.support import find_backedges
        contains_loop = bool(find_backedges(graph))
        try:
            func = graph.func
        except AttributeError:
            see_function = True
        else:
            if hasattr(func, '_jit_look_inside_'):
                see_function = func._jit_look_inside_   # override guessing
            else:
                see_function = (self.look_inside_function(func) and not
                                self._reject_function(func))
            contains_loop = contains_loop and not getattr(
                    func, '_jit_unroll_safe_', False)

        res = see_function and not contains_unsupported_variable_type(graph,
                            self.supports_floats,
                            self.supports_longlong,
                            self.supports_singlefloats)
        if res and contains_loop:
            self.unsafe_loopy_graphs.add(graph)
        res = res and not contains_loop
        if (see_function and not res and
            getattr(graph, "access_directly", False)):
            # This happens when we have a function which has an argument with
            # the access_directly flag, and the annotator has determined we will
            # see the function. (See
            # pypy/annotation/specialize.py:default_specialize) However,
            # look_inside_graph just decided that we will not see it. (It has a
            # loop or unsupported variables.) If we return False, the call will
            # be turned into a residual call, but the graph is access_directly!
            # If such a function is called and accesses a virtualizable, the JIT
            # will not notice, and the virtualizable will fall out of sync. So,
            # we fail loudly now.
            raise ValueError("access_directly on a function which we don't see %s" % graph)
        return res

def contains_unsupported_variable_type(graph, supports_floats,
                                              supports_longlong,
                                              supports_singlefloats):
    getkind = history.getkind
    try:
        for block in graph.iterblocks():
            for v in block.inputargs:
                getkind(v.concretetype, supports_floats,
                                        supports_longlong,
                                        supports_singlefloats)
            for op in block.operations:
                for v in op.args:
                    getkind(v.concretetype, supports_floats,
                                            supports_longlong,
                                            supports_singlefloats)
                v = op.result
                getkind(v.concretetype, supports_floats,
                                        supports_longlong,
                                        supports_singlefloats)
    except NotImplementedError as e:
        log.WARNING('%s, ignoring graph' % (e,))
        log.WARNING('  %s' % (graph,))
        return True
    return False

# ____________________________________________________________

class StopAtXPolicy(JitPolicy):
    def __init__(self, *funcs):
        JitPolicy.__init__(self)
        self.funcs = funcs

    def look_inside_function(self, func):
        return func not in self.funcs
