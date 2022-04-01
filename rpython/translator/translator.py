"""PyPy Translator Frontend

The Translator is a glue class putting together the various pieces of the
translation-related code.  It can be used for interactive testing of the
translator; see pypy/bin/translatorshell.py.
"""
import sys
import types

from rpython.translator import simplify
from rpython.flowspace.model import FunctionGraph, checkgraph, Block
from rpython.flowspace.objspace import build_flow
from rpython.tool.ansi_print import AnsiLogger
from rpython.tool.sourcetools import nice_repr_for_func
from rpython.config.translationoption import get_platform

log = AnsiLogger("flowgraph")

class TranslationContext(object):
    FLOWING_FLAGS = {
        'verbose': False,
        'list_comprehension_operations': False,   # True, - not super-tested
        }

    def __init__(self, config=None, **flowing_flags):
        if config is None:
            from rpython.config.translationoption import get_combined_translation_config
            config = get_combined_translation_config(translating=True)
        # ZZZ should go away in the end
        for attr in ['verbose', 'list_comprehension_operations']:
            if attr in flowing_flags:
                setattr(config.translation, attr, flowing_flags[attr])
        self.config = config
        self.platform = get_platform(config)
        self.annotator = None
        self.rtyper = None
        self.exceptiontransformer = None
        self.graphs = []      # [graph]
        self.callgraph = {}   # {opaque_tag: (caller-graph, callee-graph)}
        self._prebuilt_graphs = {}   # only used by the pygame viewer
        self._call_at_startup = []

    def buildflowgraph(self, func, mute_dot=False):
        """Get the flow graph for a function."""
        if not isinstance(func, types.FunctionType):
            raise TypeError("buildflowgraph() expects a function, "
                            "got %r" % (func,))
        if func in self._prebuilt_graphs:
            graph = self._prebuilt_graphs.pop(func)
        else:
            if self.config.translation.verbose:
                log(nice_repr_for_func(func))
            graph = build_flow(func)
            simplify.simplify_graph(graph)
            if self.config.translation.list_comprehension_operations:
                simplify.detect_list_comprehension(graph)
            if not self.config.translation.verbose and not mute_dot:
                log.dot()
            self.graphs.append(graph)   # store the graph in our list
        return graph

    def update_call_graph(self, caller_graph, callee_graph, position_tag):
        # update the call graph
        key = caller_graph, callee_graph, position_tag
        self.callgraph[key] = caller_graph, callee_graph

    def buildannotator(self, policy=None):
        if self.annotator is not None:
            raise ValueError("we already have an annotator")
        from rpython.annotator.annrpython import RPythonAnnotator
        self.annotator = RPythonAnnotator(
            self, policy=policy, keepgoing=self.config.translation.keepgoing)
        return self.annotator

    def buildrtyper(self):
        if self.annotator is None:
            raise ValueError("no annotator")
        if self.rtyper is not None:
            raise ValueError("we already have an rtyper")
        from rpython.rtyper.rtyper import RPythonTyper
        self.rtyper = RPythonTyper(self.annotator)
        return self.rtyper

    def getexceptiontransformer(self):
        if self.rtyper is None:
            raise ValueError("no rtyper")
        if self.exceptiontransformer is not None:
            return self.exceptiontransformer
        from rpython.translator.exceptiontransform import ExceptionTransformer
        self.exceptiontransformer = ExceptionTransformer(self)
        return self.exceptiontransformer

    def checkgraphs(self):
        for graph in self.graphs:
            checkgraph(graph)

    # debug aids

    def about(self, x, f=None):
        """Interactive debugging helper """
        if f is None:
            f = sys.stdout
        if isinstance(x, Block):
            for graph in self.graphs:
                if x in graph.iterblocks():
                    print >>f, '%s is a %s' % (x, x.__class__)
                    print >>f, 'in %s' % (graph,)
                    break
            else:
                print >>f, '%s is a %s at some unknown location' % (
                    x, x.__class__.__name__)
            print >>f, 'containing the following operations:'
            for op in x.operations:
                print >>f, "   ",op
            print >>f, '--end--'
            return
        raise TypeError("don't know about %r" % x)


    def view(self):
        """Shows the control flow graph with annotations if computed.
        Requires 'dot' and pygame."""
        from rpython.translator.tool.graphpage import FlowGraphPage
        FlowGraphPage(self).display()

    show = view

    def viewcg(self, center_graph=None, huge=100):
        """Shows the whole call graph and the class hierarchy, based on
        the computed annotations."""
        from rpython.translator.tool.graphpage import TranslatorPage
        TranslatorPage(self, center_graph=center_graph, huge=huge).display()

    showcg = viewcg


# _______________________________________________________________
# testing helper

def graphof(translator, func):
    if isinstance(func, FunctionGraph):
        return func
    result = []
    if hasattr(func, 'im_func'):
        # make it possible to translate bound methods
        func = func.im_func
    for graph in translator.graphs:
        if getattr(graph, 'func', None) is func:
            result.append(graph)
    assert len(result) == 1
    return result[0]

TranslationContext._graphof = graphof
