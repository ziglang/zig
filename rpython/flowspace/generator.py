"""Flow graph building for generators"""

from rpython.flowspace.argument import Signature
from rpython.flowspace.bytecode import HostCode
from rpython.flowspace.pygraph import PyGraph
from rpython.flowspace.model import (Block, Link, Variable,
    Constant, checkgraph, const)
from rpython.flowspace.operation import op
from rpython.translator.unsimplify import insert_empty_startblock, split_block
from rpython.translator.simplify import eliminate_empty_blocks, simplify_graph
from rpython.tool.sourcetools import func_with_new_name


class AbstractPosition(object):
    _immutable_ = True
    _attrs_ = ()

def make_generator_entry_graph(func):
    # This is the first copy of the graph.  We replace it with
    # a small bootstrap graph.
    code = HostCode._from_code(func.__code__)
    graph = PyGraph(func, code)
    block = graph.startblock
    for name, w_value in zip(code.co_varnames, block.framestate.mergeable):
        if isinstance(w_value, Variable):
            w_value.rename(name)
    varnames = get_variable_names(graph.startblock.inputargs)
    GeneratorIterator = make_generatoriterator_class(varnames)
    replace_graph_with_bootstrap(GeneratorIterator, graph)
    # We attach a 'next' method to the GeneratorIterator class
    # that will invoke the real function, based on a second
    # copy of the graph.
    attach_next_method(GeneratorIterator, graph)
    return graph

def tweak_generator_graph(graph):
    # This is the second copy of the graph.  Tweak it.
    GeneratorIterator = graph.func._generator_next_method_of_
    tweak_generator_body_graph(GeneratorIterator.Entry, graph)


def make_generatoriterator_class(var_names):
    class GeneratorIterator(object):
        class Entry(AbstractPosition):
            _immutable_ = True
            varnames = var_names

        def __init__(self, entry):
            self.current = entry

        def __iter__(self):
            return self

    return GeneratorIterator

def replace_graph_with_bootstrap(GeneratorIterator, graph):
    Entry = GeneratorIterator.Entry
    newblock = Block(graph.startblock.inputargs)
    op_entry = op.simple_call(const(Entry))
    v_entry = op_entry.result
    newblock.operations.append(op_entry)
    assert len(graph.startblock.inputargs) == len(Entry.varnames)
    for v, name in zip(graph.startblock.inputargs, Entry.varnames):
        newblock.operations.append(op.setattr(v_entry, Constant(name), v))
    op_generator = op.simple_call(const(GeneratorIterator), v_entry)
    newblock.operations.append(op_generator)
    newblock.closeblock(Link([op_generator.result], graph.returnblock))
    graph.startblock = newblock

def attach_next_method(GeneratorIterator, graph):
    func = graph.func
    func = func_with_new_name(func, '%s__next' % (func.__name__,))
    func._generator_next_method_of_ = GeneratorIterator
    func._always_inline_ = True
    #
    def next(self):
        entry = self.current
        self.current = None
        assert entry is not None      # else, recursive generator invocation
        (next_entry, return_value) = func(entry)
        self.current = next_entry
        return return_value
    GeneratorIterator.next = next
    graph._tweaked_func = func  # for testing

def get_variable_names(variables):
    seen = set()
    result = []
    for v in variables:
        name = v._name.strip('_')
        while name in seen:
            name += '_'
        result.append('g_' + name)
        seen.add(name)
    return result

def _insert_reads(block, varnames):
    assert len(varnames) == len(block.inputargs)
    v_entry1 = Variable('entry')
    for i, name in enumerate(varnames):
        hlop = op.getattr(v_entry1, const(name))
        hlop.result = block.inputargs[i]
        block.operations.insert(i, hlop)
    block.inputargs = [v_entry1]

def tweak_generator_body_graph(Entry, graph):
    # First, always run simplify_graph in order to reduce the number of
    # variables passed around
    simplify_graph(graph)
    insert_empty_startblock(graph)
    _insert_reads(graph.startblock, Entry.varnames)
    Entry.block = graph.startblock
    #
    mappings = [Entry]
    #
    stopblock = Block([])
    op0 = op.simple_call(const(StopIteration))
    op1 = op.type(op0.result)
    stopblock.operations = [op0, op1]
    stopblock.closeblock(Link([op1.result, op0.result], graph.exceptblock))
    #
    for block in list(graph.iterblocks()):
        for exit in block.exits:
            if exit.target is graph.returnblock:
                exit.args = []
                exit.target = stopblock
        assert block is not stopblock
        for index in range(len(block.operations)-1, -1, -1):
            hlop = block.operations[index]
            if hlop.opname == 'yield_':
                [v_yielded_value] = hlop.args
                del block.operations[index]
                newlink = split_block(block, index)
                newblock = newlink.target
                varnames = get_variable_names(newlink.args)
                #
                class Resume(AbstractPosition):
                    _immutable_ = True
                    _attrs_ = varnames
                    block = newblock
                Resume.__name__ = 'Resume%d' % len(mappings)
                mappings.append(Resume)
                #
                _insert_reads(newblock, varnames)
                #
                op_resume = op.simple_call(const(Resume))
                block.operations.append(op_resume)
                v_resume = op_resume.result
                for i, name in enumerate(varnames):
                    block.operations.append(
                        op.setattr(v_resume, const(name), newlink.args[i]))
                op_pair = op.newtuple(v_resume, v_yielded_value)
                block.operations.append(op_pair)
                newlink.args = [op_pair.result]
                newlink.target = graph.returnblock
    #
    regular_entry_block = Block([Variable('entry')])
    block = regular_entry_block
    for Resume in mappings:
        op_check = op.isinstance(block.inputargs[0], const(Resume))
        block.operations.append(op_check)
        block.exitswitch = op_check.result
        link1 = Link([block.inputargs[0]], Resume.block)
        link1.exitcase = True
        nextblock = Block([Variable('entry')])
        link2 = Link([block.inputargs[0]], nextblock)
        link2.exitcase = False
        block.closeblock(link1, link2)
        block = nextblock
    block.closeblock(Link([Constant(AssertionError),
                           Constant(AssertionError("bad generator class"))],
                          graph.exceptblock))
    graph.startblock = regular_entry_block
    graph.signature = Signature(['entry'])
    graph.defaults = ()
    checkgraph(graph)
    eliminate_empty_blocks(graph)
