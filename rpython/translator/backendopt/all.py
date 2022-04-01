from rpython.translator.backendopt import removenoops
from rpython.translator.backendopt import inline
from rpython.translator.backendopt.malloc import remove_mallocs
from rpython.translator.backendopt.constfold import constant_fold_graph
from rpython.translator.backendopt.constfold import replace_we_are_jitted
from rpython.translator.backendopt.stat import print_statistics
from rpython.translator.backendopt.merge_if_blocks import merge_if_blocks
from rpython.translator import simplify
from rpython.translator.backendopt import mallocprediction
from rpython.translator.backendopt.removeassert import remove_asserts
from rpython.translator.backendopt.support import log
from rpython.translator.backendopt.storesink import storesink_graph
from rpython.translator.backendopt import gilanalysis
from rpython.flowspace.model import checkgraph

INLINE_THRESHOLD_FOR_TEST = 33

def get_function(dottedname):
    parts = dottedname.split('.')
    module = '.'.join(parts[:-1])
    name = parts[-1]
    try:
        mod = __import__(module, {}, {}, ['__doc__'])
    except ImportError as e:
        raise Exception("Import error loading %s: %s" % (dottedname, e))

    try:
        func = getattr(mod, name)
    except AttributeError:
        raise Exception("Function %s not found in module" % dottedname)

    return func

def backend_optimizations(translator, graphs=None, secondary=False,
                          inline_graph_from_anywhere=False, **kwds):
    # sensible keywords are
    # inline_threshold, mallocs
    # merge_if_blocks, constfold, heap2stack
    # clever_malloc_removal, remove_asserts
    # replace_we_are_jitted

    config = translator.config.translation.backendopt.copy(as_default=True)
    config.set(**kwds)

    if graphs is None:
        graphs = translator.graphs
    for graph in graphs:
        assert not hasattr(graph, '_seen_by_the_backend')

    if config.print_statistics:
        print "before optimizations:"
        print_statistics(translator.graphs[0], translator, "per-graph.txt")

    if config.replace_we_are_jitted:
        for graph in graphs:
            replace_we_are_jitted(graph)

    if config.remove_asserts:
        constfold(config, graphs)
        remove_asserts(translator, graphs)

    if config.really_remove_asserts:
        for graph in graphs:
            removenoops.remove_debug_assert(graph)
        # the dead operations will be killed by the remove_obvious_noops below

    # remove obvious no-ops
    def remove_obvious_noops():
        for graph in graphs:
            removenoops.remove_same_as(graph)
            simplify.eliminate_empty_blocks(graph)
            simplify.transform_dead_op_vars(graph, translator)
            removenoops.remove_duplicate_casts(graph, translator)

        if config.print_statistics:
            print "after no-op removal:"
            print_statistics(translator.graphs[0], translator)

    remove_obvious_noops()

    if config.inline or config.mallocs:
        heuristic = get_function(config.inline_heuristic)
        if config.inline:
            threshold = config.inline_threshold
        else:
            threshold = 0
        inline_malloc_removal_phase(config, translator, graphs,
                                    threshold,
                                    inline_heuristic=heuristic,
                         inline_graph_from_anywhere=inline_graph_from_anywhere)
        constfold(config, graphs)

    if config.clever_malloc_removal:
        threshold = config.clever_malloc_removal_threshold
        heuristic = get_function(config.clever_malloc_removal_heuristic)
        log.inlineandremove("phase with threshold factor: %s" % threshold)
        log.inlineandremove("heuristic: %s.%s" % (heuristic.__module__,
                                                  heuristic.__name__))
        count = mallocprediction.clever_inlining_and_malloc_removal(
            translator, graphs,
            threshold = threshold,
            heuristic=heuristic)
        log.inlineandremove("removed %d simple mallocs in total" % count)
        constfold(config, graphs)
        if config.print_statistics:
            print "after clever inlining and malloc removal"
            print_statistics(translator.graphs[0], translator)

    if config.storesink:
        for graph in graphs:
            storesink_graph(graph)

    if config.profile_based_inline and not secondary:
        threshold = config.profile_based_inline_threshold
        heuristic = get_function(config.profile_based_inline_heuristic)
        inline.instrument_inline_candidates(graphs, threshold)
        counters = translator.driver_instrument_result(
            config.profile_based_inline)
        n = len(counters)
        def call_count_pred(label):
            if label >= n:
                return False
            return counters[label] > 250 # xxx introduce an option for this
        inline_malloc_removal_phase(config, translator, graphs,
                                    threshold,
                                    inline_heuristic=heuristic,
                                    call_count_pred=call_count_pred)
    constfold(config, graphs)

    if config.merge_if_blocks:
        log.mergeifblocks("starting to merge if blocks")
        for graph in graphs:
            merge_if_blocks(graph, translator.config.translation.verbose)

    if config.print_statistics:
        print "after if-to-switch:"
        print_statistics(translator.graphs[0], translator)

    remove_obvious_noops()

    for graph in graphs:
        checkgraph(graph)

    gilanalysis.analyze(graphs, translator)


def constfold(config, graphs):
    if config.constfold:
        for graph in graphs:
            constant_fold_graph(graph)

def inline_malloc_removal_phase(config, translator, graphs, inline_threshold,
                                inline_heuristic,
                                call_count_pred=None,
                                inline_graph_from_anywhere=False):
    # inline functions in each other
    if inline_threshold:
        log.inlining("phase with threshold factor: %s" % inline_threshold)
        log.inlining("heuristic: %s.%s" % (inline_heuristic.__module__,
                                           inline_heuristic.__name__))

        inline.auto_inline_graphs(translator, graphs, inline_threshold,
                                  heuristic=inline_heuristic,
                                  call_count_pred=call_count_pred,
                         inline_graph_from_anywhere=inline_graph_from_anywhere)

        if config.print_statistics:
            print "after inlining:"
            print_statistics(translator.graphs[0], translator)

    # vaporize mallocs
    if config.mallocs:
        log.malloc("starting malloc removal")
        remove_mallocs(translator, graphs)

        if config.print_statistics:
            print "after malloc removal:"
            print_statistics(translator.graphs[0], translator)
