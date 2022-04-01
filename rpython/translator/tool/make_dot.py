import os
import inspect, linecache
from rpython.flowspace.model import *
from rpython.tool.udir import udir
from py.process import cmdexec
from rpython.tool.error import offset2lineno

class DotGen:

    def __init__(self, graphname, rankdir=None):
        self.graphname = safename(graphname)
        self.lines = []
        self.source = None
        self.emit("digraph %s {" % self.graphname)
        if rankdir:
            self.emit('rankdir="%s"' % rankdir)

    def generate(self, storedir=None, target='ps'):
        source = self.get_source()
        if target is None:
            return source    # unprocessed
        if storedir is None:
            storedir = udir
        pdot = storedir.join('%s.dot' % self.graphname)
        pdot.write(source)
        ptarget = pdot.new(ext=target)
        cmdexec('dot -T%s %s>%s' % (target, str(pdot),str(ptarget)))
        return ptarget

    def get_source(self):
        if self.source is None:
            self.emit("}")
            self.source = '\n'.join(self.lines)
            del self.lines
        return self.source

    def emit(self, line):
        self.lines.append(line)

    def enter_subgraph(self, name):
        self.emit("subgraph %s {" % (safename(name),))

    def leave_subgraph(self):
        self.emit("}")

    def emit_edge(self, name1, name2, label="",
                  style="dashed",
                  color="black",
                  dir="forward",
                  weight="5",
                  ports=None,
                  ):
        d = locals()
        attrs = [('%s="%s"' % (x, d[x].replace('"', '\\"').replace('\n', '\\n')))
                 for x in ['label', 'style', 'color', 'dir', 'weight']]
        self.emit('edge [%s];' % ", ".join(attrs))
        if ports:
            self.emit('%s:%s -> %s:%s' % (safename(name1), ports[0],
                                          safename(name2), ports[1]))
        else:
            self.emit('%s -> %s' % (safename(name1), safename(name2)))

    def emit_node(self, name,
                  shape="diamond",
                  label="",
                  color="black",
                  fillcolor="white",
                  style="filled",
                  width="0.75",
                  ):
        d = locals()
        attrs = [('%s="%s"' % (x, d[x].replace('"', '\\"').replace('\n', '\\n')))
                 for x in ['shape', 'label', 'color', 'fillcolor', 'style', 'width']]
        self.emit('%s [%s];' % (safename(name), ", ".join(attrs)))


TAG_TO_COLORS = {
    "timeshifted":  "#cfa5f0",
    "portal":       "#cfa5f0",
    "PortalEntry": "#84abf0",
    "PortalReentry": "#f084c2",
}
DEFAULT_TAG_COLOR = "#a5e6f0"
RETURN_COLOR = "green"
EXCEPT_COLOR = "#ffa000"

class FlowGraphDotGen(DotGen):
    VERBOSE = False

    def __init__(self, graphname, rankdir=None):
        DotGen.__init__(self, graphname.replace('.', '_'), rankdir)

    def emit_subgraph(self, name, node):
        name = name.replace('.', '_') + '_'
        self.blocks = {id(None): '(None)'}
        self.func = None
        self.prefix = name
        self.enter_subgraph(name)
        tagcolor = TAG_TO_COLORS.get(node.tag, DEFAULT_TAG_COLOR)
        self.visit_FunctionGraph(node, tagcolor)
        for block in safe_iterblocks(node):
            self.visit_Block(block, tagcolor)
        self.leave_subgraph()

    def blockname(self, block):
        i = id(block)
        try:
            return self.blocks[i]
        except KeyError:
            self.blocks[i] = name = "%s_%d" % (self.prefix, len(self.blocks))
            return name

    def visit_FunctionGraph(self, funcgraph, tagcolor):
        name = self.prefix # +'_'+funcgraph.name
        data = funcgraph.name
        if getattr(funcgraph, 'source', None) is not None:
            source = funcgraph.source
            if self.VERBOSE:
                data += "\\n"
            else:
                data = ""
            data += "\\l".join(source.split('\n'))
        if hasattr(funcgraph, 'func'):
            self.func = funcgraph.func
        self.emit_node(name, label=data, shape="box", fillcolor=tagcolor, style="filled")
        if hasattr(funcgraph, 'startblock'):
            self.emit_edge(name, self.blockname(funcgraph.startblock), 'startblock')

    def visit_Block(self, block, tagcolor):
        # do the block itself
        name = self.blockname(block)
        if not isinstance(block, Block):
            data = "BROKEN BLOCK\\n%r" % (block,)
            self.emit_node(name, label=data)
            return

        lines = []
        for op in block.operations:
            lines.extend(repr(op).split('\n'))
        lines.append("")
        numblocks = len(block.exits)
        color = "black"
        fillcolor = getattr(block, "blockcolor", "white")
        if not numblocks:
            shape = "box"
            if len(block.inputargs) == 1:
                lines[-1] += 'return %s' % tuple(block.inputargs)
                fillcolor = RETURN_COLOR
            elif len(block.inputargs) == 2:
                lines[-1] += 'raise %s, %s' % tuple(block.inputargs)
                fillcolor = EXCEPT_COLOR
        elif numblocks == 1:
            shape = "box"
        else:
            color = "red"
            shape = "octagon"

        if block.exitswitch is not None:
            lines.append("exitswitch: %s" % (block.exitswitch,))

        iargs = " ".join(map(repr, block.inputargs))
        if self.VERBOSE:
            if block.exc_handler:
                eh = ' (EH)'
            else:
                eh = ''
            data = "%s%s%s\\n" % (name, block.at(), eh)
        else:
            data = "%s\\n" % (name,)
        data += "inputargs: %s\\n\\n" % (iargs,)
        if self.VERBOSE and block.operations and self.func:
            maxoffs = max([op.offset for op in block.operations])
            if maxoffs >= 0:
                minoffs = min([op.offset for op in block.operations
                               if op.offset >= 0])
                minlineno = offset2lineno(self.func.__code__, minoffs)
                maxlineno = offset2lineno(self.func.__code__, maxoffs)
                filename = inspect.getsourcefile(self.func)
                source = "\l".join([linecache.getline(filename, line).rstrip()
                                    for line in range(minlineno, maxlineno+1)])
                if minlineno == maxlineno:
                    data = data + r"line %d:\n%s\l\n" % (minlineno, source)
                else:
                    data = data + r"lines %d-%d:\n%s\l\n" % (minlineno,
                                                             maxlineno, source)

        data = data + "\l".join(lines)

        self.emit_node(name, label=data, shape=shape, color=color, style="filled", fillcolor=fillcolor)

        # do links/exits
        for link in block.exits:
            name2 = self.blockname(link.target)
            label = " ".join(map(repr, link.args))
            if link.exitcase is not None:
                label = "%s: %s" %(repr(link.exitcase).replace('\\', '\\\\'), label)
                self.emit_edge(name, name2, label, style="dotted", color="red")
            else:
                self.emit_edge(name, name2, label, style="solid")


def make_dot(graphname, graph, storedir=None, target='ps'):
    return make_dot_graphs(graph.name, [(graphname, graph)], storedir, target)

def show_dot(graph, storedir = None, target = 'ps'):
    name = graph.name
    fn = make_dot(name, graph, storedir, target)
    os.system('gv %s' % fn)

def make_dot_graphs(basefilename, graphs, storedir=None, target='ps'):
    dotgen = FlowGraphDotGen(basefilename)
    names = {basefilename: True}
    for graphname, graph in graphs:
        if graphname in names:
            i = 2
            while graphname + str(i) in names:
                i += 1
            graphname = graphname + str(i)
        names[graphname] = True
        dotgen.emit_subgraph(graphname, graph)
    return dotgen.generate(storedir, target)

def _makecharmap():
    result = {}
    for i in range(256):
        result[chr(i)] = '_%02X' % i
    for c in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789':
        result[c] = c
    result['_'] = '__'
    return result
CHAR_MAP = _makecharmap()
del _makecharmap

def safename(name):
    # turn a random string into something that is a valid dot identifier,
    # avoiding invalid characters and prepending '_' to make sure it is
    # not a keyword
    name = ''.join([CHAR_MAP[c] for c in name])
    return '_' + name
