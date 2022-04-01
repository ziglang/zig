from rpython.flowspace.model import Constant, checkgraph
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rtyper import LowLevelOpList, inputconst
from rpython.translator.backendopt.support import log
from rpython.translator.simplify import eliminate_empty_blocks, join_blocks


def remove_asserts(translator, graphs):
    rtyper = translator.rtyper
    excdata = rtyper.exceptiondata
    clsdef = translator.annotator.bookkeeper.getuniqueclassdef(AssertionError)
    ll_AssertionError = excdata.get_standard_ll_exc_instance(rtyper, clsdef)
    total_count = [0, 0]

    for graph in graphs:
        count = 0
        morework = True
        while morework:
            morework = False
            eliminate_empty_blocks(graph)
            join_blocks(graph)
            for link in graph.iterlinks():
                if (link.target is graph.exceptblock
                    and isinstance(link.args[1], Constant)
                    and link.args[1].value == ll_AssertionError):
                    if kill_assertion_link(graph, link):
                        count += 1
                        morework = True
                        break
                    else:
                        total_count[0] += 1
                        if translator.config.translation.verbose:
                            log.removeassert("cannot remove an assert from %s" % (graph.name,))
        if count:
            # now melt away the (hopefully) dead operation that compute
            # the condition
            total_count[1] += count
            if translator.config.translation.verbose:
                log.removeassert("removed %d asserts in %s" % (count, graph.name))
            checkgraph(graph)
    total_count = tuple(total_count)
    if total_count[0] == 0:
        if total_count[1] == 0:
            msg = None
        else:
            msg = "Removed %d asserts" % (total_count[1],)
    else:
        if total_count[1] == 0:
            msg = "Could not remove %d asserts" % (total_count[0],)
        else:
            msg = "Could not remove %d asserts, but removed %d asserts." % total_count
    if msg is not None:
        log.removeassert(msg)


def kill_assertion_link(graph, link):
    block = link.prevblock
    exits = list(block.exits)
    if len(exits) <= 1:
        return False
    remove_condition = len(exits) == 2
    if block.canraise:
        if link is exits[0]:
            return False       # cannot remove the non-exceptional path
    else:
        if block.exitswitch.concretetype is not lltype.Bool:   # a switch
            remove_condition = False
        else:
            # common case: if <cond>: raise AssertionError
            # turn it into a debug_assert operation
            assert remove_condition
            newops = LowLevelOpList()
            if link.exitcase:
                v = newops.genop('bool_not', [block.exitswitch],
                                 resulttype=lltype.Bool)
            else:
                v = block.exitswitch
            msg = "assertion failed in %s" % (graph.name,)
            c_msg = inputconst(lltype.Void, msg)
            newops.genop('debug_assert', [v, c_msg])
            block.operations.extend(newops)

    exits.remove(link)
    if remove_condition:
        # condition no longer necessary
        block.exitswitch = None
        exits[0].exitcase = None
        exits[0].llexitcase = None
    block.recloseblock(*exits)
    return True
