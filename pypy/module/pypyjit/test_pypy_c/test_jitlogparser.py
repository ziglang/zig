import py
import re

from rpython.tool.logparser import extract_category
from rpython.jit.backend.tool.viewcode import ObjdumpNotFound

from rpython.tool.jitlogparser.parser import (import_log, parse_log_counts,
        mangle_descr)
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestLogParser(BaseTestPyPyC):
    log_string = 'jit-log-opt,jit-backend'

    def test(self):
        def fn_with_bridges(N):
            def is_prime(x):
                for y in range(2, x):
                    if x % y == 0:
                        return False
                return True
            result = 0
            for x in range(N):
                if x % 3 == 0:
                    result += 5
                elif x % 5 == 0:
                    result += 3
                elif is_prime(x):
                    result += x
                elif x == 99:
                    result *= 2
            return result
        #
        N = 10000
        _log = self.run(fn_with_bridges, [N])
        log, loops = import_log(_log.logfile)
        parse_log_counts(extract_category(log, 'jit-backend-count'), loops)

        is_prime_loops = []
        fn_with_bridges_loops = []
        bridges = {}

        for loop in loops:
            if hasattr(loop, 'force_asm'):
                try:
                    loop.force_asm()
                except ObjdumpNotFound:
                    py.test.skip("ObjDump was not found, skipping")
            assert loop.count > 0
            if 'is_prime' in loop.comment:
                is_prime_loops.append(loop)
            elif 'fn_with_bridges' in loop.comment:
                fn_with_bridges_loops.append(loop)
            elif 'tuple.contains' in loop.comment:
                pass
            elif ' bridge ' in loop.comment:
                key = mangle_descr(loop.descr)
                assert key not in bridges
                bridges[key] = loop

        by_count = lambda l: -l.count
        is_prime_loops.sort(key=by_count)
        fn_with_bridges_loops.sort(key=by_count)

        # check that we can find bridges corresponding to " % 3" and " % 5"
        mod_bridges = []
        for op in fn_with_bridges_loops[0].operations:
            if op.descr is not None:
                bridge = bridges.get(mangle_descr(op.descr))
                if bridge is not None:
                    mod_bridges.append(bridge)
        assert len(mod_bridges) in (1, 2, 3)

        # check that counts are reasonable (precise # may change in the future)
        assert N - 2000 < sum(l.count for l in fn_with_bridges_loops) < N + 1500


