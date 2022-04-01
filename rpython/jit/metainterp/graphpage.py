
from rpython.translator.tool.graphpage import GraphPage
from rpython.translator.tool.make_dot import DotGen
from rpython.jit.metainterp.resoperation import rop

class SubGraph:
    def __init__(self, op):
        self.failargs = op.getfailargs()
        self.subinputargs = op.getdescr()._debug_subinputargs
        self.suboperations = op.getdescr()._debug_suboperations
    def get_operations(self):
        return self.suboperations
    def get_display_text(self, memo):
        # copy the display of variables in this subgraph (a bridge)
        # so that they match variables in the parent graph across the
        # guard failure
        for failarg, inputarg in zip(self.failargs, self.subinputargs):
            try:
                memo[inputarg] = memo[failarg]
            except KeyError:
                pass
        return None

def display_procedures(procedures, errmsg=None, highlight_procedures={}, metainterp_sd=None):
    graphs = [(procedure, highlight_procedures.get(procedure, 0))
              for procedure in procedures]
    for graph, highlight in graphs:
        for op in graph.get_operations():
            if is_interesting_guard(op):
                graphs.append((SubGraph(op), highlight))
    graphpage = ResOpGraphPage(graphs, errmsg, metainterp_sd)
    graphpage.display()

def is_interesting_guard(op):
    return hasattr(op.getdescr(), '_debug_suboperations')

def getdescr(op):
    if op._descr is not None:
        return op._descr
    if hasattr(op, '_descr_wref'):
        return op._descr_wref()
    return None


class ResOpGraphPage(GraphPage):

    def compute(self, graphs, errmsg=None, metainterp_sd=None):
        resopgen = ResOpGen(metainterp_sd)
        for graph, highlight in graphs:
            resopgen.add_graph(graph, highlight)
        if errmsg:
            resopgen.set_errmsg(errmsg)
        self.source = resopgen.getsource()
        self.links = resopgen.getlinks()


class ResOpGen(object):
    CLUSTERING = True
    BOX_COLOR = (128, 0, 96)

    def __init__(self, metainterp_sd=None):
        self.graphs = []
        self.highlight_graphs = {}
        self.block_starters = {}    # {graphindex: {set-of-operation-indices}}
        self.all_operations = {}
        self.errmsg = None
        self.target_tokens = {}
        self.metainterp_sd = metainterp_sd
        self.memo = {}

    def op_name(self, graphindex, opindex):
        return 'g%dop%d' % (graphindex, opindex)

    def mark_starter(self, graphindex, opindex):
        self.block_starters[graphindex][opindex] = True

    def add_graph(self, graph, highlight=False):
        graphindex = len(self.graphs)
        self.graphs.append(graph)
        self.highlight_graphs[graph] = highlight
        for i, op in enumerate(graph.get_operations()):
            self.all_operations[op] = graphindex, i

    def find_starters(self):
        for graphindex in range(len(self.graphs)):
            self.block_starters[graphindex] = {0: True}
        for graphindex, graph in enumerate(self.graphs):
            mergepointblock = None
            for i, op in enumerate(graph.get_operations()):
                if is_interesting_guard(op):
                    self.mark_starter(graphindex, i+1)
                if op.getopnum() == rop.DEBUG_MERGE_POINT:
                    if mergepointblock is None:
                        mergepointblock = i
                elif op.getopnum() == rop.LABEL:
                    self.mark_starter(graphindex, i)
                    self.target_tokens[getdescr(op)] = (graphindex, i)
                    mergepointblock = i
                else:
                    if mergepointblock is not None:
                        self.mark_starter(graphindex, mergepointblock)
                        mergepointblock = None

    def set_errmsg(self, errmsg):
        self.errmsg = errmsg

    def getsource(self):
        self.find_starters()
        self.pendingedges = []
        self.dotgen = DotGen('resop')
        self.dotgen.emit('clusterrank="local"')
        self.generrmsg()
        for i, graph in enumerate(self.graphs):
            self.gengraph(graph, i)
        # we generate the edges at the end of the file; otherwise, and edge
        # could mention a node before it's declared, and this can cause the
        # node declaration to occur too early -- in the wrong subgraph.
        for frm, to, kwds in self.pendingedges:
            self.dotgen.emit_edge(frm, to, **kwds)
        return self.dotgen.generate(target=None)

    def generrmsg(self):
        if self.errmsg:
            self.dotgen.emit_node('errmsg', label=self.errmsg,
                                  shape="box", fillcolor="red")
            if self.graphs and self.block_starters[0]:
                opindex = max(self.block_starters[0])
                blockname = self.op_name(0, opindex)
                self.pendingedges.append((blockname, 'errmsg', {}))

    def getgraphname(self, graphindex):
        return 'graph%d' % graphindex

    def gengraph(self, graph, graphindex):
        graphname = self.getgraphname(graphindex)
        if self.CLUSTERING:
            self.dotgen.emit('subgraph cluster%d {' % graphindex)
        label = graph.get_display_text(self.memo)
        if label is not None:
            colorindex = self.highlight_graphs.get(graph, 0)
            if colorindex == 1:
                fillcolor = '#f084c2'    # highlighted graph
            elif colorindex == 2:
                fillcolor = '#808080'    # invalidated graph
            else:
                fillcolor = '#84f0c2'    # normal color
            self.dotgen.emit_node(graphname, shape="octagon",
                                  label=label, fillcolor=fillcolor)
            self.pendingedges.append((graphname,
                                      self.op_name(graphindex, 0),
                                      {}))
        operations = graph.get_operations()
        for opindex in self.block_starters[graphindex]:
            self.genblock(operations, graphindex, opindex)
        if self.CLUSTERING:
            self.dotgen.emit('}')   # closes the subgraph

    def genedge(self, frm, to, **kwds):
        self.pendingedges.append((self.op_name(*frm),
                                  self.op_name(*to),
                                  kwds))

    def genblock(self, operations, graphindex, opstartindex):
        if opstartindex >= len(operations):
            return
        blockname = self.op_name(graphindex, opstartindex)
        block_starters = self.block_starters[graphindex]
        lines = []
        opindex = opstartindex
        while True:
            op = operations[opindex]
            op_repr = op.repr(self.memo, graytext=True)
            if (op.getopnum() == rop.DEBUG_MERGE_POINT and
                    self.metainterp_sd is not None):
                jd_sd = self.metainterp_sd.jitdrivers_sd[op.getarg(0).getint()]
                if jd_sd._get_printable_location_ptr:
                    s = jd_sd.warmstate.get_location_str(op.getarglist()[3:])
                    s = s.replace(',', '.') # we use comma for argument splitting
                    op_repr = "debug_merge_point(%d, %d, '%s')" % (op.getarg(1).getint(), op.getarg(2).getint(), s)
            lines.append(op_repr)
            if is_interesting_guard(op):
                tgt = op.getdescr()._debug_suboperations[0]
                tgt_g, tgt_i = self.all_operations[tgt]
                self.genedge((graphindex, opstartindex),
                             (tgt_g, tgt_i),
                             color='red')
            opindex += 1
            if opindex >= len(operations):
                break
            if opindex in block_starters:
                self.genedge((graphindex, opstartindex),
                             (graphindex, opindex))
                break
        if op.getopnum() == rop.JUMP:
            tgt_descr = getdescr(op)
            if tgt_descr is not None and tgt_descr in self.target_tokens:
                self.genedge((graphindex, opstartindex),
                             self.target_tokens[tgt_descr],
                             weight="0")
        lines.append("")
        label = "\\l".join(lines)
        kwds = {}
        #if op in self.highlightops:
        #    kwds['color'] = 'red'
        #    kwds['fillcolor'] = '#ffe8e8'
        self.dotgen.emit_node(blockname, shape="box", label=label, **kwds)

    def getlinks(self):
        boxes = {}
        for op in self.all_operations:
            args = op.getarglist() + [op]
            for box in args:
                s = box.repr_short(self.memo)
                if len(s) > 1 and s[0] in 'irf' and s[1:].isdigit():
                    boxes[box] = s
        links = {}
        for box, s in boxes.items():
            links.setdefault(s, (box.repr(self.memo), self.BOX_COLOR))
        return links
