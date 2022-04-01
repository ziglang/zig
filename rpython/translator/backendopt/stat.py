from rpython.translator.simplify import get_graph
from hashlib import md5

def get_statistics(graph, translator, save_per_graph_details=None, ignore_stack_checks=False):
    seen_graphs = {}
    stack = [graph]
    num_graphs = 0
    num_blocks = 0
    num_ops = 0
    num_mallocs = 0
    per_graph = {}
    while stack:
        graph = stack.pop()
        if graph in seen_graphs:
            continue
        seen_graphs[graph] = True
        num_graphs += 1
        old_num_blocks = num_blocks
        old_num_ops = num_ops
        old_num_mallocs = num_mallocs
        for block in graph.iterblocks():
            num_blocks += 1
            for op in block.operations:
                if op.opname == "direct_call":
                    called_graph = get_graph(op.args[0], translator)
                    if called_graph is not None and ignore_stack_checks:
                        if called_graph.name.startswith('ll_stack_check'):
                            continue
                    if called_graph is not None:
                        stack.append(called_graph)
                elif op.opname == "indirect_call":
                    called_graphs = op.args[-1].value
                    if called_graphs is not None:
                        stack.extend(called_graphs)
                elif op.opname.startswith("malloc"):
                    num_mallocs += 1
                num_ops += 1
        per_graph[graph] = (num_blocks-old_num_blocks, num_ops-old_num_ops, num_mallocs-old_num_mallocs)
    if save_per_graph_details:
        details = []
        for graph, (nblocks, nops, nmallocs) in per_graph.iteritems():
            try:
                code = graph.func.__code__.co_code
            except AttributeError:
                code = "None"
            hash = md5(code).hexdigest()
            details.append((hash, graph.name, nblocks, nops, nmallocs))
        details.sort()
        f = open(save_per_graph_details, "w")
        try:
            for hash, name, nblocks, nops, nmallocs in details:
                print >>f, hash, name, nblocks, nops, nmallocs
        finally:
            f.close()
    return num_graphs, num_blocks, num_ops, num_mallocs

def print_statistics(graph, translator, save_per_graph_details=None, ignore_stack_checks=False):
    num_graphs, num_blocks, num_ops, num_mallocs = get_statistics(
            graph, translator, save_per_graph_details,
            ignore_stack_checks=ignore_stack_checks)
    print ("Statistics:\nnumber of graphs %s\n"
           "number of blocks %s\n"
           "number of operations %s\n"
           "number of mallocs %s\n"
           ) % (num_graphs, num_blocks, num_ops, num_mallocs)
