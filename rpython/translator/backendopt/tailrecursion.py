from rpython.flowspace.model import mkentrymap, checkgraph

# this transformation is very academical -- I had too much time

def _remove_tail_call(translator, graph, block):
    print "removing tail call"
    assert len(block.exits) == 1
    assert block.exits[0].target is graph.returnblock
    assert block.operations[-1].result == block.exits[0].args[0]
    op = block.operations[-1]
    block.operations = block.operations[:-1]
    block.exits[0].args = op.args[1:]
    block.exits[0].target = graph.startblock

def remove_tail_calls_to_self(translator, graph):
    entrymap = mkentrymap(graph)
    changed = False
    for link in entrymap[graph.returnblock]:
        block = link.prevblock
        if (len(block.exits) == 1 and
            len(block.operations) > 0 and
            block.operations[-1].opname == 'direct_call' and
            block.operations[-1].result == link.args[0]):
            print "getgraph", graph
            if graph is graph:
                _remove_tail_call(translator, graph, block)
                changed = True
    if changed:
        from rpython.translator import simplify
        checkgraph(graph)
        simplify.remove_identical_vars(graph)
        simplify.eliminate_empty_blocks(graph)
        simplify.join_blocks(graph)
