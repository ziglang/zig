
from rpython.jit.metainterp.test.test_recursive import RecursiveTests
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.backend.llsupport.codemap import unpack_traceback
from rpython.jit.backend.x86.arch import WORD, WIN64

class TestRecursive(Jit386Mixin, RecursiveTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_recursive.py
    def check_get_unique_id(self, codemaps):
        if WORD == 4:
            import py; py.test.skip("this is 64 bit only check")
        if WIN64 and len(codemaps) == 0:
            import py; py.test.skip("Win64 doesn't produce codemaps")

        assert len(codemaps) == 3
        # we want to create a map of differences, so unpacking the tracebacks
        # byte by byte
        codemaps.sort(lambda a, b: cmp(a[1], b[1]))
        # biggest is the big loop, smallest is the bridge
        def get_ranges(c):
            ranges = []
            prev_traceback = None
            for b in range(c[0], c[0] + c[1]):
                tb = unpack_traceback(b)
                if tb != prev_traceback:
                    ranges.append(tb)
                    prev_traceback = tb
            return ranges
        assert get_ranges(codemaps[2]) == [[4], [4, 2], [4]]
        assert get_ranges(codemaps[1]) == [[2]]
        assert get_ranges(codemaps[0]) == [[2], []]
