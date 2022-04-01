import pytest
import sys
import py
import pypy

pytest_plugins = "pytester"

def setpypyconftest(testdir):
    path = str(py.path.local(pypy.__file__).dirpath().dirpath())
    testdir.makeconftest("""
        import sys
        sys.path.insert(0, %r)
        from pypy.conftest import *
    """ % path)

def test_pypy_collection(testdir):
    testdir.makepyfile("""
        def test_func():
            pass
        class TestClassInt:
            def test_method(self, space):
                pass
        class AppTestClass:
            def test_method(self):
                pass
    """)
    testdir.makepyfile(apptest_collection="""
        def test_app():
            pass
    """)
    setpypyconftest(testdir)
    result = testdir.runpytest("--collectonly")
    assert result.ret == 0
    result.stdout.fnmatch_lines([
        "*AppTestModule*apptest_collection*",
        "*AppTestFunction*test_app*",
        "*Function*test_func*",
        "*Class*TestClassInt*",
        "*Function*test_method*",
        "*AppClassCollector*AppTestClass*",
        "*AppTestMethod*",
    ])

def test_interp_spaceconfig(testdir):
    setpypyconftest(testdir)
    p = testdir.makepyfile("""
        class TestClass:
            spaceconfig = {"objspace.usemodules._random": False}
            def setup_class(cls):
                assert not cls.space.config.objspace.usemodules._random
            def test_interp(self, space):
                assert self.space is space
            def test_interp2(self, space):
                assert self.space is space
    """)
    result = testdir.runpytest(p)
    assert result.ret == 0
    result.stdout.fnmatch_lines(["*2 passed*"])

def test_spaceconfig_param(testdir):
    setpypyconftest(testdir)
    p = testdir.makepyfile("""
        import pytest

        @pytest.mark.parametrize('spaceconfig',
            [{"objspace.usemodules._random": False}])
        def test_interp(space):
            assert not space.config.objspace.usemodules._random

        def test_interp2(space):
            assert space.config.objspace.usemodules._random
    """)
    result = testdir.runpytest(p)
    assert result.ret == 0
    result.stdout.fnmatch_lines(["*2 passed*"])

def test_applevel_raises_simple_display(testdir):
    setpypyconftest(testdir)
    p = testdir.makepyfile("""
        class AppTestRaises:
            def test_func(self):
                raises (ValueError, x)
        #
    """)
    result = testdir.runpytest(p, "-s")
    assert result.ret == 1
    result.stdout.fnmatch_lines([
        "*test_func(self)*",
        ">*raises*ValueError*",
        "*E*application-level*NameError*x*not defined",
        "*test_applevel_raises_simple_display*",
    ])
    result = testdir.runpytest(p) # this time we may run the pyc file
    assert result.ret == 1
    result.stdout.fnmatch_lines([
        "*E*application-level*NameError*x*not defined",
    ])

def test_apptest_raise(testdir):
    setpypyconftest(testdir)
    p = testdir.makepyfile(apptest_raise="""
        def test_raise():
            raise KeyError(42)
    """)
    result = testdir.runpytest(p)
    assert result.ret == 1
    result.stdout.fnmatch_lines([
        "*E*application-level*KeyError*42*",
    ])

def test_apptest_fail_plain(testdir):
    setpypyconftest(testdir)
    p = testdir.makepyfile(apptest_fail="""
        def test_fail():
            x = 'foo'
            assert x == 'bar'
    """)
    result = testdir.runpytest(p)
    assert result.ret == 1
    result.stdout.fnmatch_lines([
        "*E*(application-level) AssertionError*",
    ])

def test_apptest_spaceconfig(testdir):
    setpypyconftest(testdir)
    p = testdir.makepyfile(apptest_raise="""
        # spaceconfig = {"usemodules":["array"]}
        import array
        def test_array():
            a = array.array('i', [1,2,3])
            assert len(a) == 3
            assert a[2] == 3
    """)
    result = testdir.runpytest(p)
    assert result.ret == 0

def test_rename_module():
    from pypy.tool.pytest.apptest import _rename_module
    assert _rename_module("sys") == "sys"
    if sys.platform == "win32":
        assert _rename_module("_winreg") == "winreg"
    assert _rename_module("struct") == "_struct"
    assert _rename_module("operator") == "_operator"
    assert _rename_module("signal") == "_signal"

def test_apptest_skipif(testdir):
    setpypyconftest(testdir)
    p = testdir.makepyfile(apptest_raise="""
        import pytest

        @pytest.mark.skipif(True, reason="Bad test")
        def test_bad():
            assert False

        def test_success():
            assert True
    """)
    result = testdir.runpytest(p)
    assert result.ret == 0
    result.assert_outcomes(passed=1, skipped=1)
