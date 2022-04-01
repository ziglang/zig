"""Implements the main interface for flow graph creation: build_flow().
"""

from inspect import CO_NEWLOCALS, isgeneratorfunction

from rpython.flowspace.model import checkgraph
from rpython.flowspace.bytecode import HostCode
from rpython.flowspace.flowcontext import (FlowContext, fixeggblocks)
from rpython.flowspace.generator import (tweak_generator_graph,
        make_generator_entry_graph)
from rpython.flowspace.pygraph import PyGraph


def _assert_rpythonic(func):
    """Raise ValueError if ``func`` is obviously not RPython"""
    try:
        func.__code__.co_cellvars
    except AttributeError:
        raise ValueError("%r is not RPython: it is likely an unexpected "
                         "built-in function or type" % (func,))
    if getattr(func, "_not_rpython_", False):
        raise ValueError("%r is tagged as @not_rpython" % (func,))
    if func.__doc__ and func.__doc__.lstrip().startswith('NOT_RPYTHON'):
        raise ValueError("%r is tagged as NOT_RPYTHON" % (func,))
    if func.__code__.co_cellvars:
        raise ValueError(
"""RPython functions cannot create closures
Possible causes:
    Function is inner function
    Function uses generator expressions
    Lambda expressions
in %r""" % (func,))
    if not (func.__code__.co_flags & CO_NEWLOCALS):
        raise ValueError("The code object for a RPython function should have "
                         "the flag CO_NEWLOCALS set.")


def build_flow(func):
    """
    Create the flow graph (in SSA form) for the function.
    """
    _assert_rpythonic(func)
    if (isgeneratorfunction(func) and
            not hasattr(func, '_generator_next_method_of_')):
        return make_generator_entry_graph(func)
    code = HostCode._from_code(func.__code__)
    graph = PyGraph(func, code)
    ctx = FlowContext(graph, code)
    ctx.build_flow()
    fixeggblocks(graph)
    if code.is_generator:
        tweak_generator_graph(graph)
    return graph
