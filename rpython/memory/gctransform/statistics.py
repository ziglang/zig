# calculate some statistics about the number of variables that need
# to be cared for across a call

from rpython.rtyper.lltypesystem import lltype


relevant_ops = ["direct_call", "indirect_call", "malloc", "malloc_varsize"]

def filter_for_ptr(arg):
    return isinstance(arg.concretetype, lltype.Ptr)

def filter_for_nongcptr(arg):
    return isinstance(arg.concretetype, lltype.Ptr) and not arg.concretetype._needsgc()

def relevant_gcvars_block(block, filter=filter_for_ptr):
    result = []
    def filter_ptr(args):
        return [arg for arg in args if filter(arg)]
    def live_vars_before(index):
        if index == 0:
            return set(filter_ptr(block.inputargs))
        op = block.operations[index - 1]
        result = live_vars_before(index - 1).union(filter_ptr(op.args + [op.result]))
        return result
    def live_vars_after(index):
        if index == len(block.operations) - 1:
            result = set()
            for exit in block.exits:
                result = result.union(filter_ptr(exit.args))
            return result
        op = block.operations[index + 1]
        result = live_vars_after(index + 1).union(filter_ptr(op.args + [op.result]))
        return result
    for i, op in enumerate(block.operations):
        if op.opname not in relevant_ops:
            continue
        live_before = live_vars_before(i)
        live_after = live_vars_after(i)
        result.append(len(live_before.intersection(live_after)))
    return result

def relevant_gcvars_graph(graph, filter=filter_for_ptr):
    result = []
    for block in graph.iterblocks():
        result += relevant_gcvars_block(block, filter)
    return result

def relevant_gcvars(t, filter=filter_for_ptr):
    result = []
    for graph in t.graphs:
        result.extend(relevant_gcvars_graph(graph, filter))
    return result

