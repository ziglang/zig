from rpython.tool.algo import regalloc
from rpython.jit.metainterp.history import getkind
from rpython.jit.codewriter.flatten import ListOfKind


def perform_register_allocation(graph, kind):
    checkkind = lambda v: getkind(v.concretetype) == kind
    return regalloc.perform_register_allocation(graph, checkkind, ListOfKind)
