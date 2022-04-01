from rpython.flowspace.model import Block, Link, FunctionGraph
from rpython.flowspace.model import safe_iterblocks, safe_iterlinks
from rpython.translator.tool.make_dot import DotGen, make_dot_graphs
from rpython.annotator.model import SomePBC
from rpython.annotator.description import MethodDesc
from rpython.annotator.classdesc import ClassDef
from rpython.tool.uid import uid
from rpython.tool.udir import udir

from dotviewer.graphpage import GraphPage as BaseGraphPage

class GraphPage(BaseGraphPage):
    save_tmp_file = str(udir.join('graph.dot'))

class VariableHistoryGraphPage(GraphPage):
    """ A GraphPage showing the history of variable bindings. """

    def compute(self, translator, name, info, caused_by, history, func_names):
        self.linkinfo = {}
        self.translator = translator
        self.func_names = func_names
        dotgen = DotGen('binding')
        label = "Most recent binding of %s\\n\\n%s" % (name, nottoowide(info))
        if info.origin is not None:
            label += "\\n" + self.createlink(info.origin, 'Originated at')
        if caused_by is not None:
            label += '\\n' + self.createlink(caused_by)

        dotgen.emit_node('0', shape="box", color="red", label=label)
        for n, (data, caused_by) in zip(range(len(history)), history):
            label = nottoowide(data)
            if data.origin is not None:
                label += "\\n" + self.createlink(data.origin, 'Originated at')
            if caused_by is not None:
                label += '\\n' + self.createlink(caused_by)
            dotgen.emit_node(str(n+1), shape="box", label=label)
            dotgen.emit_edge(str(n+1), str(n))
        self.source = dotgen.generate(target=None)

    def createlink(self, position_key, wording='Caused by a call from'):
        graph, block, pos = position_key
        basename = self.func_names.get(graph, graph.name)
        linkname = basename
        n = 1
        while self.linkinfo.get(linkname, position_key) != position_key:
            n += 1
            linkname = '%s_%d' % (basename, n)
        self.linkinfo[linkname] = position_key
        # It would be nice to get the block name somehow
        blockname = block.__class__.__name__
        self.links[linkname] = '%s, %s, position %r:\n%s' % (basename,
                                        blockname, pos, block.operations[pos])
        return '%s %s' % (wording, linkname)

    def followlink(self, funcname):
        graph, block, pos = self.linkinfo[funcname]
        # It would be nice to focus on the block
        return FlowGraphPage(self.translator, [graph], self.func_names)


def graphsof(translator, func):
    if isinstance(func, (FunctionGraph, IncompleteGraph)):
        return [func]   # already a graph
    graphs = []
    if translator.annotator:
        funcdesc = translator.annotator.bookkeeper.getdesc(func)
        graphs = funcdesc._cache.values()
    if not graphs:
        # build a new graph, mark it as "to be returned to the annotator the
        # next time it asks for a graph for the same function"
        # (note that this buildflowgraph() call will return the same graph
        # if called again, from the _prebuilt_graphs cache)
        graph = translator.buildflowgraph(func)
        translator._prebuilt_graphs[func] = graph
        graphs = [graph]
    return graphs


class FlowGraphPage(GraphPage):
    """ A GraphPage showing a Flow Graph (or a few flow graphs).
    """
    def compute(self, translator, functions=None, func_names=None):
        self.translator = translator
        self.annotator = getattr(translator, 'annotator', None)
        self.func_names = func_names or {}
        if functions:
            graphs = []
            for func in functions:
                graphs += graphsof(translator, func)
        else:
            graphs = self.translator.graphs
            if not graphs and hasattr(translator, 'entrypoint'):
                graphs = list(graphs)
                graphs += graphsof(translator, translator.entrypoint)
        gs = [(graph.name, graph) for graph in graphs]
        gs.sort(lambda (_, g), (__ ,h): cmp(g.tag, h.tag))
        if self.annotator and self.annotator.blocked_graphs:
            for block, was_annotated in self.annotator.annotated.items():
                if not was_annotated:
                    block.blockcolor = "red"
        if graphs:
            name = graphs[0].name+"_graph"
        else:
            name = 'no_graph'
        self.source = make_dot_graphs(name, gs, target=None)
        # make the dictionary of links -- one per annotated variable
        self.current_value = {}

        #from rpython.jit.hintannotator.annotator import HintAnnotator
        #if isinstance(self.annotator, HintAnnotator):
        #    return

        vars = {}
        for graph in graphs:
            for block in safe_iterblocks(graph):
                if isinstance(block, Block):
                    for v in block.getvariables():
                        vars[v] = True
            for link in safe_iterlinks(graph):
                if isinstance(link, Link):
                    for v in link.getextravars():
                        vars[v] = True
        for var in vars:
            s_value = var.annotation
            if s_value is not None:
                info = '%s: %s' % (var.name, s_value)
                annotationcolor = getattr(s_value, 'annotationcolor', None)
                self.links[var.name] = info, annotationcolor
                self.current_value[var.name] = s_value
            if hasattr(var, 'concretetype'):
                #info = self.links.get(var.name, var.name)
                #info = '(%s) %s' % (var.concretetype, info)
                info = str(var.concretetype)
                if info == 'Void':     # gray out Void variables
                    info = info, (160,160,160)
                self.links[var.name] = info


class SingleGraphPage(FlowGraphPage):
    """ A GraphPage showing a single precomputed FlowGraph."""

    def compute(self, graph):
        return FlowGraphPage.compute(self, None, [graph])


def nottoowide(text, width=72):
    parts = str(text).split(' ')
    lines = []
    line = parts.pop(0)
    for s in parts:
        if len(line)+len(s) < width:
            line = line + ' ' + s
        else:
            lines.append(line)
            line = s
    lines.append(line)
    return '\\n'.join(lines)


class ClassDefPage(GraphPage):
    """A GraphPage showing the attributes of a class.
    """
    def compute(self, translator, cdef):
        self.translator = translator
        dotgen = DotGen(cdef.shortname, rankdir="LR")

        def writecdef(cdef):
            lines = [cdef.name, '']
            attrs = cdef.attrs.items()
            attrs.sort()

            def writeadefs(prefix, classattrs):
                for name, attrdef in attrs:
                    if bool(attrdef.readonly) == bool(classattrs):
                        s_value = attrdef.s_value
                        linkname = name
                        info = s_value
                        if (classattrs and isinstance(s_value, SomePBC)
                            and s_value.getKind() == MethodDesc):
                            name += '()'
                            info = 'SomePBC(%s)' % ', '.join(
                                ['method %s.%s' % (
                                  desc.originclassdef.shortname,
                                  desc.name) for desc in s_value.descriptions],)
                        lines.append(name)
                        self.links[linkname] = '%s.%s: %s' % (prefix, name, info)

            prefix = cdef.shortname
            writeadefs(prefix + '()', False)
            lines.append('')
            writeadefs(prefix, True)
            dotgen.emit_node(nameof(cdef), color="red", shape="box",
                             label='\n'.join(lines))

        prevcdef = None
        while cdef is not None:
            writecdef(cdef)
            if prevcdef:
                dotgen.emit_edge(nameof(cdef), nameof(prevcdef), color="red")
            prevcdef = cdef
            cdef = cdef.basedef

        self.source = dotgen.generate(target=None)

    def followlink(self, name):
        return self

class BaseTranslatorPage(GraphPage):
    """Abstract GraphPage for showing some of the call graph between functions
    and possibily the class hierarchy."""

    def allgraphs(self):
        return list(self.translator.graphs)

    def graph_name(self, *args):
        raise NotImplementedError

    def compute(self, translator, *args, **kwds):
        self.translator = translator
        self.object_by_name = {}
        self.name_by_object = {}
        dotgen = DotGen(self.graph_name(*args))
        dotgen.emit('mclimit=15.0')

        self.do_compute(dotgen, *args, **kwds)

        self.source = dotgen.generate(target=None)

        # link the function names to the individual flow graphs
        for name, obj in self.object_by_name.items():
            if isinstance(obj, ClassDef):
                data = repr(obj)
            elif isinstance(obj, FunctionGraph):
                graph = obj
                data = graph.name
                if hasattr(graph, 'func'):
                    data += ':%d' % graph.func.__code__.co_firstlineno
                if hasattr(graph, 'source'):
                    data += '\n%s' % graph.source.split('\n', 1)[0]
            else:
                continue
            self.links.setdefault(name, data)

    def get_blocked_graphs(self, graphs):
        translator = self.translator
        blocked_graphs = {}
        if translator.annotator:
            # don't use translator.annotator.blocked_graphs here because
            # it is not populated until the annotator finishes.
            annotated = translator.annotator.annotated
            for graph in graphs:
                for block in graph.iterblocks():
                    if annotated.get(block) is False:
                        blocked_graphs[graph] = True
        return blocked_graphs

    def compute_class_hieararchy(self, dotgen):
        # show the class hierarchy
        if self.translator.annotator:
            dotgen.emit_node(nameof(None), color="red", shape="octagon",
                             label="Root Class\\nobject")
            for classdef in self.translator.annotator.getuserclassdefinitions():
                data = self.labelof(classdef, classdef.shortname)
                dotgen.emit_node(nameof(classdef), label=data, shape="box")
                dotgen.emit_edge(nameof(classdef.basedef), nameof(classdef))

    def labelof(self, obj, objname):
        name = objname
        i = 1
        while name in self.object_by_name:
            i += 1
            name = '%s__%d' % (objname, i)
        self.object_by_name[name] = obj
        self.name_by_object[obj] = name
        return name

    def followlink(self, name):
        if name.endswith('...'):
            obj = self.object_by_name[name]
            return LocalizedCallGraphPage(self.translator, [obj])
        obj = self.object_by_name[name]
        if isinstance(obj, ClassDef):
            return ClassDefPage(self.translator, obj)
        else:
            return FlowGraphPage(self.translator, [obj], self.name_by_object)

class TranslatorPage(BaseTranslatorPage):
    """A GraphPage showing a the call graph between functions
    as well as the class hierarchy."""

    def graph_name(self, huge=0):
        return 'translator'

    def do_compute(self, dotgen, huge=100, center_graph=None):
        translator = self.translator

        # show the call graph
        callgraph = translator.callgraph.values()
        graphs = self.allgraphs()

        if len(graphs) > huge:
            assert graphs, "no graph to show!"
            graphs = [center_graph or graphs[0]]
            LocalizedCallGraphPage.do_compute.im_func(self, dotgen, graphs)
            return

        blocked_graphs = self.get_blocked_graphs(graphs)

        highlight_graphs = getattr(translator, 'highlight_graphs', {}) # XXX
        dotgen.emit_node('entry', fillcolor="green", shape="octagon",
                         label="Translator\\nEntry Point")
        for graph in graphs:
            data = self.labelof(graph, graph.name)
            if graph in blocked_graphs:
                kw = {'fillcolor': 'red'}
            elif graph in highlight_graphs:
                kw = {'fillcolor': '#ffcccc'}
            else:
                kw = {}
            dotgen.emit_node(nameof(graph), label=data, shape="box", **kw)
        if graphs:
            dotgen.emit_edge('entry', nameof(graphs[0]), color="green")
        for g1, g2 in callgraph:  # captured above (multithreading fun)
            dotgen.emit_edge(nameof(g1), nameof(g2))

        # show the class hierarchy
        self.compute_class_hieararchy(dotgen)


class LocalizedCallGraphPage(BaseTranslatorPage):
    """A GraphPage showing the localized call graph for a function,
    that means just including direct callers and callees"""

    def graph_name(self, centers):
        if centers:
            return 'LCG_%s' % nameof(centers[0])
        else:
            return 'EMPTY'

    def do_compute(self, dotgen, centers):
        centers = dict.fromkeys(centers)

        translator = self.translator

        graphs = {}

        for g1, g2 in translator.callgraph.values():
            if g1 in centers  or g2 in centers:
                graphs[g1] = True
                graphs[g2] = True

        # show all edges that exist between these graphs
        for g1, g2 in translator.callgraph.values():
            if g1 in graphs and g2 in graphs:
                dotgen.emit_edge(nameof(g1), nameof(g2))

        graphs = graphs.keys()

        # show the call graph
        blocked_graphs = self.get_blocked_graphs(graphs)

        highlight_graphs = getattr(translator, 'highlight_graphs', {}) # XXX
        for graph in graphs:
            data = self.labelof(graph, graph.name)
            if graph in blocked_graphs:
                kw = {'fillcolor': 'red'}
            elif graph in highlight_graphs:
                kw = {'fillcolor': '#ffcccc'}
            else:
                kw = {}
            dotgen.emit_node(nameof(graph), label=data, shape="box", **kw)

            if graph  not in centers:
                lcg = 'LCG_%s' % nameof(graph)
                label = data+'...'
                dotgen.emit_node(lcg, label=label)
                dotgen.emit_edge(nameof(graph), lcg)
                self.links[label] = 'go to its localized call graph'
                self.object_by_name[label] = graph

class ClassHierarchyPage(BaseTranslatorPage):
    """A GraphPage showing the class hierarchy."""

    def graph_name(self):
        return 'class_hierarchy'

    def do_compute(self, dotgen):
        # show the class hierarchy
        self.compute_class_hieararchy(dotgen)

def nameof(obj, cache={}):
    # NB. the purpose of the cache is not performance, but to ensure that
    # two objects that compare equal get the same name
    try:
        return cache[obj]
    except KeyError:
        result = '%s__0x%x' % (getattr(obj, '__name__', ''), uid(obj))
        cache[obj] = result
        return result

# ____________________________________________________________
#
# Helpers to try to show a graph when we only have a Block or a Link

def try_show(obj):
    if isinstance(obj, FunctionGraph):
        obj.show()
        return obj
    elif isinstance(obj, Link):
        return try_show(obj.prevblock)
    elif isinstance(obj, Block):
        graph = obj._slowly_get_graph()
        if isinstance(graph, FunctionGraph):
            graph.show()
            return graph
        graph = IncompleteGraph(graph)
        SingleGraphPage(graph).display()
    else:
        raise TypeError("try_show(%r object)" % (type(obj).__name__,))

def try_get_functiongraph(obj):
    if isinstance(obj, FunctionGraph):
        obj.show()
    elif isinstance(obj, Link):
        try_show(obj.prevblock)
    elif isinstance(obj, Block):
        import gc
        pending = [obj]   # pending blocks
        seen = {obj: True, None: True}
        for x in pending:
            for y in gc.get_referrers(x):
                if isinstance(y, FunctionGraph):
                    return y
                elif isinstance(y, Link):
                    block = y.prevblock
                    if block not in seen:
                        pending.append(block)
                        seen[block] = True
        return pending
    else:
        raise TypeError("try_get_functiongraph(%r object)" % (type(obj).__name__,))

class IncompleteGraph:
    name = '(incomplete graph)'
    tag = None

    def __init__(self, bunch_of_blocks):
        self.bunch_of_blocks = bunch_of_blocks

    def iterblocks(self):
        return iter(self.bunch_of_blocks)
