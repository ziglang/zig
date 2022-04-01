
import py, sys, ctypes, os
from rpython.tool.udir import udir
from rpython.translator.platform import CompilationError, Platform
from rpython.translator.platform import host
from rpython.translator.tool.cbuild import ExternalCompilationInfo

def test_compilationerror_repr():
    # compilation error output/stdout may be large, but we don't want
    # repr to create a limited version
    c = CompilationError('', '*'*1000)
    assert repr(c) == 'CompilationError(err="""\n\t%s""")' % ('*'*1000,)
    c = CompilationError('*'*1000, '')
    assert repr(c) == 'CompilationError(out="""\n\t%s""")' % ('*'*1000,)

class TestPlatform(object):
    platform = host
    strict_on_stderr = True

    def check_res(self, res, expected='42\n'):
        assert res.out == expected
        if self.strict_on_stderr:
            assert res.err == ''
        assert res.returncode == 0

    def test_simple_enough(self):
        cfile = udir.join('test_simple_enough.c')
        cfile.write('''
        #include <stdio.h>
        int main()
        {
            printf("42\\n");
            return 0;
        }
        ''')
        executable = self.platform.compile([cfile], ExternalCompilationInfo())
        res = self.platform.execute(executable)
        self.check_res(res)

    def test_two_files(self):
        cfile = udir.join('test_two_files.c')
        cfile.write('''
        #include <stdio.h>
        int func();
        int main()
        {
            printf("%d\\n", func());
            return 0;
        }
        ''')
        cfile2 = udir.join('implement1.c')
        cfile2.write('''
        int func()
        {
            return 42;
        }
        ''')
        executable = self.platform.compile([cfile, cfile2], ExternalCompilationInfo())
        res = self.platform.execute(executable)
        self.check_res(res)

    def test_nice_errors(self):
        cfile = udir.join('test_nice_errors.c')
        cfile.write('')
        try:
            executable = self.platform.compile([cfile], ExternalCompilationInfo())
        except CompilationError as e:
            filename = cfile.dirpath().join(cfile.purebasename + '.errors')
            assert filename.read('r') == e.err
        else:
            py.test.fail("Did not raise")

    def test_use_eci(self):
        tmpdir = udir.join('use_eci').ensure(dir=1)
        hfile = tmpdir.join('needed.h')
        hfile.write('#define SOMEHASHDEFINE 42\n')
        eci = ExternalCompilationInfo(include_dirs=[tmpdir])
        cfile = udir.join('use_eci_c.c')
        cfile.write('''
        #include <stdio.h>
        #include "needed.h"
        int main()
        {
            printf("%d\\n", SOMEHASHDEFINE);
            return 0;
        }
        ''')
        executable = self.platform.compile([cfile], eci)
        res = self.platform.execute(executable)
        self.check_res(res)

    def test_standalone_library(self):
        tmpdir = udir.join('standalone_library').ensure(dir=1)
        c_file = tmpdir.join('stand1.c')
        c_file.write('''
        #include <math.h>
        #include <stdio.h>

        int main()
        {
            printf("%f\\n", pow(2.0, 2.0));
        }''')
        if sys.platform != 'win32':
            eci = ExternalCompilationInfo(
                libraries = ['m'],
                )
        else:
            eci = ExternalCompilationInfo()
        executable = self.platform.compile([c_file], eci)
        res = self.platform.execute(executable)
        assert res.out.startswith('4.0')

    def test_environment_inheritance(self):
        # make sure that environment is inherited
        cmd = 'import os; print os.environ["_SOME_VARIABLE_%d"]'
        env = {'_SOME_VARIABLE_1':'xyz'}
        env['PATH'] = os.environ['PATH']
        res = self.platform.execute(sys.executable, ['-c', cmd % 1],
                                    env=env)
        assert 'xyz' in res.out
        os.environ['_SOME_VARIABLE_2'] = 'zyz'
        try:
            res = self.platform.execute('python', ['-c', cmd % 2])
            assert 'zyz' in res.out
        finally:
            del os.environ['_SOME_VARIABLE_2']

    def test_key(self):
        class XPlatform(Platform):
            relevant_environ = ['CPATH']

            def __init__(self):
                self.cc = 'xcc'
        x = XPlatform()
        res = x.key()
        assert res.startswith("XPlatform cc='xcc' CPATH=")

def test_equality():
    class X(Platform):
        def __init__(self):
            pass
    class Y(Platform):
        def __init__(self, x):
            self.x = x

    assert X() == X()
    assert Y(3) == Y(3)
    assert Y(2) != Y(3)


def test_is_host_build():
    from platform import machine
    from rpython.translator import platform
    assert platform.host == platform.platform

    assert platform.is_host_build()
    # do we support non-host builds?
    if machine().startswith('arm'):
        platform.set_platform('arm', None)
        assert platform.host != platform.platform
        assert not platform.is_host_build()
