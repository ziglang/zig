import py
import sys
import subprocess

innertest = py.path.local(__file__).dirpath('conftest1_innertest.py')
#pytest_plugins = "pytester"


def subproc_run(*args):
    # similar to testdir.inline_run(), but running a subprocess to avoid
    # confusion.  Parses the standard output of test_all.py, so somehow
    # dependent on how it looks like.
    cur_dir = str(py.path.local(__file__).dirpath())
    test_all = py.path.local(__file__).dirpath('..', '..', '..', 'test_all.py')
    args = [sys.executable, str(test_all), "-v"] + map(str, args)
    print '=========>', args
    passed, failed = [], []
    popen = subprocess.Popen(args, stdout=subprocess.PIPE, cwd=cur_dir)
    output, _ = popen.communicate()

    for line in output.splitlines(False):
        if line.startswith('conftest1_innertest.py'):
            line = line[len('conftest1_innertest.py'):]
            testname, result = line.lstrip(':').strip().split()
            if result == 'PASSED':
                passed.append(testname)
            elif result == 'FAILED':
                failed.append(testname)
            else:
                assert False, "unexpected output line: %r" % (line,)
    return passed, failed


class TestPyPyTests:
    def test_selection_by_keyword_interp(self):
        passed, failed = subproc_run("-m", "interplevel", innertest)
        assert len(passed) == 2, len(passed)
        assert not failed
        assert "test_something" in passed[0]
        assert "test_method" in passed[1]

    def test_selection_by_keyword_app(self):
        passed, failed = subproc_run("-m", "applevel -docstring", innertest)
        assert len(passed) == 2
        assert len(failed) == 1
        assert "test_method_app" in passed[0]

    def test_docstring_in_methods(self):
        passed, failed = subproc_run("-k", "AppTestSomething and test_code_in_docstring",
                                    innertest)
        assert len(passed) == 1
        assert len(failed) == 1
        assert "test_code_in_docstring_ignored" in passed[0]
        assert "test_code_in_docstring_failing" in failed[0]

    @py.test.mark.xfail(reason='fails on buildslave')
    def test_docstring_runappdirect(self):
        passed, failed = subproc_run(innertest,
                                    '-k', 'test_code_in_docstring',
                                    '--runappdirect')
        assert len(passed) == 1
        assert len(failed) == 2
        assert "test_code_in_docstring_ignored" in passed[0]
        assert "app_test_code_in_docstring_failing" in failed[0]
        assert "test_code_in_docstring_failing" in failed[1]

    @py.test.mark.xfail(reason='fails on buildslave')
    def test_raises_inside_closure(self):
        passed, failed = subproc_run(innertest, '-k', 'app_test_raise_in_a_closure',
                                    '--runappdirect')
        assert len(passed) == 1
        print passed
        assert "app_test_raise_in_a_closure" in passed[0]
