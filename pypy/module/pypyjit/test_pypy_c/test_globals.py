from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


class TestGlobals(BaseTestPyPyC):
    def test_load_builtin(self):
        def main(n):
            import pypyjit

            i = 0
            while i < n:
                l = len # ID: loadglobal
                i += pypyjit.residual_call(l, "a")
            return i
        #
        log = self.run(main, [500])
        assert log.result == 500
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id("loadglobal", """
            guard_not_invalidated(descr=...)
        """)
