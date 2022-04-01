# Executes "Expect" tests.


import py
import sys
from tempfile import NamedTemporaryFile

class ExpectTest(object):
    def _spawn(self, *args, **kwds):
        import pexpect
        kwds.setdefault('timeout', 600)
        child = pexpect.spawn(*args, **kwds)
        child.logfile = sys.stdout
        return child

    def spawn(self, argv):
        return self._spawn(sys.executable, argv)

    def run_test(self, func):
        try:
            import pexpect
        except ImportError:
            py.test.skip("pexpect not found")
        source = py.code.Source(func)[1:].deindent()
        tmpfile = NamedTemporaryFile(suffix='.py')
        fname = tmpfile.name
        dir_to_insert = py.path.local(__file__).join('..', '..', '..', '..')
        source.lines = ['import sys',
                        'sys.path.insert(0, %s)' % repr(str(dir_to_insert))
                        ] + source.lines
        source.lines.append('print "%s ok!"' % fname)
        f = py.path.local(fname)
        f.write(source)
        # run target in the guarded environment
        child = self.spawn([str(f)])
        import re
        child.expect(re.escape(fname + " ok!"))
