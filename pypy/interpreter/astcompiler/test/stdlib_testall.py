import py
from pypy.interpreter.astcompiler.test.test_compiler import compile_with_astcompiler

class TestStdlib:

    def check_file_compile(self, filepath):
        space = self.space
        print 'Compiling:', filepath
        source = filepath.read()
        compile_with_astcompiler(source, mode='exec', space=space)

    def test_all(self):
        space = self.space
        libpythondir = space.str_w(space.appexec((), """():
        import os
        return os.path.dirname(os.__file__)"""))
        p = py.path.local(libpythondir)
        files = p.listdir("*.py")
        files.sort()
        for s in files:
            yield self.check_file_compile, s
