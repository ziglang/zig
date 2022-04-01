import py
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestImport(BaseTestPyPyC):

    def test_import_in_function(self):
        def main(n):
            i = 0
            while i < n:
                from sys import version  # ID: import
                i += 1
            return i
        #
        log = self.run(main, [500])
        assert log.result == 500
        loop, = log.loops_by_id('import')
        assert loop.match_by_id('import', """
            guard_not_invalidated(descr=...)
        """)

    def test_import_fast_path(self, tmpdir):
        pkg = tmpdir.join('mypkg').ensure(dir=True)
        pkg.join('__init__.py').write("")
        pkg.join('mod.py').write(str(py.code.Source("""
            def do_the_import():
                import sys
        """)))
        def main(path, n):
            import sys
            sys.path.append(path)
            from mypkg.mod import do_the_import
            for i in range(n):
                do_the_import()
        #
        log = self.run(main, [str(tmpdir), 300])
        loop, = log.loops_by_filename(self.filepath)
        # this is a check for a slow-down that introduced a
        # call_may_force(absolute_import_with_lock).
        for opname in log.opnames(loop.allops(opcode="IMPORT_NAME")):
            assert 'call' not in opname    # no call-like opcode

    def test_import_fast_path_package(self, tmpdir):
        print tmpdir
        pkg = tmpdir.join('mypkg').ensure(dir=True)
        subdir = pkg.join("sub").ensure(dir=True)
        pkg.join('__init__.py').write("")
        subdir.join('__init__.py').write("")
        subdir.join('mod.py').write(str(py.code.Source("""
            def do_the_import():
                import sys
        """)))
        def main(path, n):
            def do_the_import():
                from mypkg.sub import mod
            import sys
            sys.path.append(path)
            for i in range(n):
                do_the_import()
        #
        log = self.run(main, [str(tmpdir), 300])
        loop, = log.loops_by_filename(self.filepath)
        # check that no string compares and other calls are there
        for opname in log.opnames(loop.allops(opcode="IMPORT_NAME")):
            assert 'call' not in opname    # no call-like opcode
