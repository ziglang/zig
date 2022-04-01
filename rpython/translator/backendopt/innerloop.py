"""
This is optional support code for backends: it finds which cycles
in a graph are likely to correspond to source-level 'inner loops'.
"""
from rpython.tool.algo import graphlib
from rpython.flowspace.model import Variable
from rpython.translator.backendopt.ssa import DataFlowFamilyBuilder


class Loop:
    def __init__(self, headblock, links):
        self.headblock = headblock
        self.links = links   # list of Links making the cycle,
                             # starting from one of the exits of headblock


def find_inner_loops(graph, check_exitswitch_type=None):
    """Enumerate what look like the innermost loops of the graph.
    Returns a list of non-overlapping Loop() instances.
    """
    # Heuristic (thanks Stakkars for the idea):
    # to find the "best" cycle to pick,
    #
    #   * look for variables that don't change over the whole cycle
    #
    #   * cycles with _more_ of them are _inside_ cycles with less of them,
    #     because any variable that doesn't change over an outer loop will
    #     not change over an inner loop either, and on the other hand the
    #     outer loop is likely to use and modify variables that remain
    #     constant over the inner loop.
    #
    #   * if the numbers are the same, fall back to a more arbitrary
    #     measure: loops involving less blocks may be more important
    #     to optimize
    #
    #   * in a cycle, which block is the head of the loop?  Somewhat
    #     arbitrarily we pick the first Bool-switching block that has
    #     two exits.  The "first" means the one closest to the
    #     startblock of the graph.
    #
    startdistance = {}     # {block: distance-from-startblock}
    pending = [graph.startblock]
    edge_list = []
    dist = 0
    while pending:
        newblocks = []
        for block in pending:
            if block not in startdistance:
                startdistance[block] = dist
                for link in block.exits:
                    newblocks.append(link.target)
                    edge = graphlib.Edge(block, link.target)
                    edge.link = link
                    edge_list.append(edge)
        dist += 1
        pending = newblocks

    vertices = startdistance
    edges = graphlib.make_edge_dict(edge_list)
    cycles = graphlib.all_cycles(graph.startblock, vertices, edges)
    loops = []
    variable_families = None

    for cycle in cycles:
        # find the headblock
        candidates = []
        for i in range(len(cycle)):
            block = cycle[i].source
            v = block.exitswitch
            if isinstance(v, Variable) and len(block.exits) == 2:
                if getattr(v, 'concretetype', None) is check_exitswitch_type:
                    dist = startdistance[block]
                    candidates.append((dist, i))
        if not candidates:
            continue
        _, i = min(candidates)
        links = [edge.link for edge in cycle[i:] + cycle[:i]]
        loop = Loop(cycle[i].source, links)

        # count the variables that remain constant across the cycle,
        # detected as having its SSA family present across all blocks.
        if variable_families is None:
            dffb = DataFlowFamilyBuilder(graph)
            variable_families = dffb.get_variable_families()

        num_loop_constants = 0
        for v in loop.headblock.inputargs:
            v = variable_families.find_rep(v)
            for link in loop.links:
                block1 = link.target
                for v1 in block1.inputargs:
                    v1 = variable_families.find_rep(v1)
                    if v1 is v:
                        break    # ok, found in this block
                else:
                    break   # not found in this block, fail
            else:
                # found in all blocks, this variable is a loop constant
                num_loop_constants += 1

        # smaller keys are "better"
        key = (-num_loop_constants,   # maximize num_loop_constants
               len(cycle))            # minimize len(cycle)
        loops.append((key, loop))

    loops.sort()

    # returns 'loops' without overlapping blocks
    result = []
    blocks_seen = {}
    for key, loop in loops:
        for link in loop.links:
            if link.target in blocks_seen:
                break     # overlapping
        else:
            # non-overlapping
            result.append(loop)
            for link in loop.links:
                blocks_seen[link.target] = True
    return result
