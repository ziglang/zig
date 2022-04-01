import sys
from rpython.flowspace.model import Variable
from rpython.tool.algo.color import DependencyGraph
from rpython.tool.algo.unionfind import UnionFind

def perform_register_allocation(graph, consider_var, ListOfKind=()):
    """Perform register allocation for the Variables of the given 'kind'
    in the 'graph'."""
    regalloc = RegAllocator(graph, consider_var, ListOfKind)
    regalloc.make_dependencies()
    regalloc.coalesce_variables()
    regalloc.find_node_coloring()
    return regalloc


class RegAllocator(object):
    DEBUG_REGALLOC = False

    def __init__(self, graph, consider_var, ListOfKind):
        self.graph = graph
        self.consider_var = consider_var
        self.ListOfKind = ListOfKind

    def make_dependencies(self):
        dg = DependencyGraph()
        for block in self.graph.iterblocks():
            # Compute die_at = {Variable: index_of_operation_with_last_usage}
            die_at = dict.fromkeys(block.inputargs, 0)
            for i, op in enumerate(block.operations):
                for v in op.args:
                    if isinstance(v, Variable):
                        die_at[v] = i
                    elif isinstance(v, self.ListOfKind):
                        for v1 in v:
                            if isinstance(v1, Variable):
                                die_at[v1] = i
                if op.result is not None:
                    die_at[op.result] = i + 1
            if isinstance(block.exitswitch, tuple):
                for x in block.exitswitch:
                    die_at.pop(x, None)
            else:
                die_at.pop(block.exitswitch, None)
            for link in block.exits:
                for v in link.args:
                    die_at.pop(v, None)
            die_at = [(value, key) for (key, value) in die_at.items()]
            die_at.sort()
            die_at.append((sys.maxint,))
            # Done.  XXX the code above this line runs 3 times
            # (for kind in KINDS) to produce the same result...
            livevars = [v for v in block.inputargs
                          if self.consider_var(v)]
            # Add the variables of this block to the dependency graph
            for i, v in enumerate(livevars):
                dg.add_node(v)
                for j in range(i):
                    dg.add_edge(livevars[j], v)
            livevars = set(livevars)
            die_index = 0
            for i, op in enumerate(block.operations):
                while die_at[die_index][0] == i:
                    try:
                        livevars.remove(die_at[die_index][1])
                    except KeyError:
                        pass
                    die_index += 1
                if (op.result is not None and
                        self.consider_var(op.result)):
                    dg.add_node(op.result)
                    for v in livevars:
                        if self.consider_var(v):
                            dg.add_edge(v, op.result)
                    livevars.add(op.result)
        self._depgraph = dg

    def coalesce_variables(self):
        self._unionfind = UnionFind()
        pendingblocks = list(self.graph.iterblocks())
        while pendingblocks:
            block = pendingblocks.pop()
            # Aggressively try to coalesce each source variable with its
            # target.  We start from the end of the graph instead of
            # from the beginning.  This is a bit arbitrary, but the idea
            # is that the end of the graph runs typically more often
            # than the start, given that we resume execution from the
            # middle during blackholing.
            for link in block.exits:
                if link.last_exception is not None:
                    self._depgraph.add_node(link.last_exception)
                if link.last_exc_value is not None:
                    self._depgraph.add_node(link.last_exc_value)
                for i, v in enumerate(link.args):
                    self._try_coalesce(v, link.target.inputargs[i])

    def _try_coalesce(self, v, w):
        if isinstance(v, Variable) and self.consider_var(v)  \
                                   and self.consider_var(w):
            dg = self._depgraph
            uf = self._unionfind
            v0 = uf.find_rep(v)
            w0 = uf.find_rep(w)
            if v0 is not w0 and v0 not in dg.neighbours[w0]:
                _, rep, _ = uf.union(v0, w0)
                assert uf.find_rep(v0) is uf.find_rep(w0) is rep
                if rep is v0:
                    dg.coalesce(w0, v0)
                else:
                    assert rep is w0
                    dg.coalesce(v0, w0)

    def find_node_coloring(self):
        self._coloring = self._depgraph.find_node_coloring()
        if self.DEBUG_REGALLOC:
            for block in self.graph.iterblocks():
                print block
                for v in block.getvariables():
                    print '\t', v, '\t', self.getcolor(v)

    def find_num_colors(self):
        if self._coloring:
            numcolors = max(self._coloring.values()) + 1
        else:
            numcolors = 0
        self.numcolors = numcolors

    def getcolor(self, v):
        return self._coloring[self._unionfind.find_rep(v)]

    def checkcolor(self, v, color):
        try:
            return self.getcolor(v) == color
        except KeyError:
            return False

    def swapcolors(self, col1, col2):
        for key, value in self._coloring.items():
            if value == col1:
                self._coloring[key] = col2
            elif value == col2:
                self._coloring[key] = col1
