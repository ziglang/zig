from rpython.jit.metainterp.optimizeopt.rewrite import OptRewrite
from rpython.jit.metainterp.optimizeopt.intbounds import OptIntBounds
from rpython.jit.metainterp.optimizeopt.virtualize import OptVirtualize
from rpython.jit.metainterp.optimizeopt.heap import OptHeap
from rpython.jit.metainterp.optimizeopt.vstring import OptString
from rpython.jit.metainterp.optimizeopt.simplify import OptSimplify
from rpython.jit.metainterp.optimizeopt.pure import OptPure
from rpython.jit.metainterp.optimizeopt.earlyforce import OptEarlyForce
from rpython.rlib.jit import PARAMETERS, ENABLE_ALL_OPTS
from rpython.rlib.unroll import unrolling_iterable


ALL_OPTS = [('intbounds', OptIntBounds),
            ('rewrite', OptRewrite),
            ('virtualize', OptVirtualize),
            ('string', OptString),
            ('pure', OptPure),
            ('earlyforce', OptEarlyForce),
            ('heap', OptHeap),
            ('unroll', None)]
# no direct instantiation of unroll
unroll_all_opts = unrolling_iterable(ALL_OPTS)

ALL_OPTS_DICT = dict.fromkeys([name for name, _ in ALL_OPTS])
ALL_OPTS_LIST = [name for name, _ in ALL_OPTS]
ALL_OPTS_NAMES = ':'.join([name for name, _ in ALL_OPTS])

assert ENABLE_ALL_OPTS == ALL_OPTS_NAMES, (
    'please fix rlib/jit.py to say ENABLE_ALL_OPTS = %r' % (ALL_OPTS_NAMES,))

def build_opt_chain(enable_opts):
    optimizations = []
    for name, opt in unroll_all_opts:
        if name in enable_opts:
            if opt is not None:
                o = opt()
                optimizations.append(o)
    if ('rewrite' not in enable_opts or 'virtualize' not in enable_opts or
            'heap' not in enable_opts or 'pure' not in enable_opts):
        optimizations.append(OptSimplify())
    return optimizations

if __name__ == '__main__':
    print ALL_OPTS_NAMES
