
from pypy.interpreter.mixedmodule import MixedModule 

class Module(MixedModule):
    """Functional tools for creating and using iterators.

    Infinite iterators:
    count([n]) --> n, n+1, n+2, ...
    cycle(p) --> p0, p1, ... plast, p0, p1, ...
    repeat(elem [,n]) --> elem, elem, elem, ... endlessly or up to n times

    Iterators terminating on the shortest input sequence:
    ifilter(pred, seq) --> elements of seq where pred(elem) is True
    ifilterfalse(pred, seq) --> elements of seq where pred(elem) is False
    islice(seq, [start,] stop [, step]) --> elements from
           seq[start:stop:step]
    starmap(fun, seq) --> fun(*seq[0]), fun(*seq[1]), ...
    tee(it, n=2) --> (it1, it2 , ... itn) splits one iterator into n
    chain(p, q, ...) --> p0, p1, ... plast, q0, q1, ... 
    takewhile(pred, seq) --> seq[0], seq[1], until pred fails
    dropwhile(pred, seq) --> seq[n], seq[n+1], starting when pred fails
    groupby(iterable[, keyfunc]) --> sub-iterators grouped by value of keyfunc(v)
    izip(p, q, ...) --> (p[0], q[0]), (p[1], q[1]), ...
    izip_longest(p, q, ...) --> (p[0], q[0]), (p[1], q[1]), ...

    Combinatoric generators:
    product(p, q, ... [repeat=1]) --> cartesian product
    permutations(p[, r])
    combinations(p, r)
    combinations_with_replacement(p, r)
    """

    interpleveldefs = {
        'accumulate'    : 'interp_itertools.W_Accumulate',
        'chain'         : 'interp_itertools.W_Chain',
        'combinations'  : 'interp_itertools.W_Combinations',
        'combinations_with_replacement' : 'interp_itertools.W_CombinationsWithReplacement',
        'compress'      : 'interp_itertools.W_Compress',
        'count'         : 'interp_itertools.W_Count',
        'cycle'         : 'interp_itertools.W_Cycle',
        'dropwhile'     : 'interp_itertools.W_DropWhile',
        'groupby'       : 'interp_itertools.W_GroupBy',
        '_groupby'      : 'interp_itertools.W_GroupByIterator',
        'filterfalse'   : 'interp_itertools.W_FilterFalse',
        'islice'        : 'interp_itertools.W_ISlice',
        'permutations'  : 'interp_itertools.W_Permutations',
        'product'       : 'interp_itertools.W_Product',
        'repeat'        : 'interp_itertools.W_Repeat',
        'starmap'       : 'interp_itertools.W_StarMap',
        'takewhile'     : 'interp_itertools.W_TakeWhile',
        'tee'           : 'interp_itertools.tee',
        '_tee'          : 'interp_itertools.W_TeeIterable',
        '_tee_dataobject' : 'interp_itertools.W_TeeChainedListNode',
        'zip_longest'  : 'interp_itertools.W_ZipLongest',
    }

    appleveldefs = {
    }
