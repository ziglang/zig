import py
from rpython.rlib.jit import JitDriver
from rpython.jit.metainterp.test import test_loop
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp.optimizeopt import ALL_OPTS_NAMES

allopts = ALL_OPTS_NAMES.split(':')
del allopts[allopts.index('unroll')]
for optnum in range(len(allopts)):
    myopts = allopts[:]
    del myopts[optnum]

    class TestLLtype(test_loop.LoopTest, LLJitMixin):
        enable_opts = ':'.join(myopts)

        def check_resops(self, *args, **kwargs):
            pass
        def check_trace_count(self, count):
            pass

    opt = allopts[optnum]
    exec("TestLoopNo%sLLtype = TestLLtype" % (opt[0].upper() + opt[1:]))

del TestLLtype # No need to run the last set twice
#del TestLoopNoUnrollLLtype # This case is take care of by test_loop

