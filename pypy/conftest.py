import py, pytest, sys, os, textwrap
from inspect import isclass

LOOK_FOR_PYTHON3 = 'python3.9'
PYTHON3 = os.getenv('PYTHON3') or py.path.local.sysfind(LOOK_FOR_PYTHON3)
if PYTHON3 is not None:
    PYTHON3 = str(PYTHON3)
HOST_IS_PY3 = sys.version_info[0] > 2
APPLEVEL_FN = 'apptest_*.py'

# pytest settings
rsyncdirs = ['.', '../lib-python', '../lib_pypy', '../demo']
rsyncignore = ['_cache']

try:
    from hypothesis import settings, __version__
except ImportError:
    pass
else:
    try:
        settings.register_profile('default', deadline=None)
    except Exception:
        import warnings
        warnings.warn("Version of hypothesis too old, "
                      "cannot set the deadline to None")
    settings.load_profile('default')

# PyPy's command line extra options (these are added
# to py.test's standard options)
#
option = None

def braindead_deindent(self):
    """monkeypatch that wont end up doing stupid in the python tokenizer"""
    text = '\n'.join(self.lines)
    short = py.std.textwrap.dedent(text)
    newsource = py.code.Source()
    newsource.lines[:] = short.splitlines()
    return newsource

py.code.Source.deindent = braindead_deindent

def get_marker(item, name):
    try:
        return item.get_closest_marker(name=name)
    except AttributeError:
        # pytest < 3.6
        return item.get_marker(name=name)

def pytest_report_header():
    return "pytest-%s from %s" % (pytest.__version__, pytest.__file__)

@pytest.hookimpl(tryfirst=True)
def pytest_cmdline_preparse(config, args):
    if not (set(args) & {'-D', '--direct-apptest'}):
        args.append('--assert=reinterp')

def pytest_configure(config):
    if HOST_IS_PY3 and not config.getoption('direct_apptest'):
        raise ValueError(
            "On top of a Python 3 interpreter, the -D flag is mandatory")
    global option
    option = config.option
    mode_A = config.getoption('runappdirect')
    mode_D = config.getoption('direct_apptest')
    def py3k_skip(message):
        py.test.skip('[py3k] %s' % message)
    py.test.py3k_skip = py3k_skip
    if mode_D or not mode_A:
        config.addinivalue_line('python_files', APPLEVEL_FN)
    if not mode_A and not mode_D:  # 'own' tests
        from rpython.conftest import LeakFinder
        config.pluginmanager.register(LeakFinder())
        # pypy.interpreter.astcompiler and pypy.module._cppyy need this,
        # as well as a few others
        sys.setrecursionlimit(2000)
    if mode_A:
        from pypy.tool.pytest.apptest import PythonInterpreter
        config.applevel = PythonInterpreter(config.option.python)
    else:
        config.applevel = None

def pytest_addoption(parser):
    group = parser.getgroup("pypy options")
    group.addoption('-A', '--runappdirect', action="store_true",
           default=False, dest="runappdirect",
           help="run legacy applevel tests directly on the python interpreter " +
                "specified by --python")
    group.addoption('--python', type="string", default=PYTHON3,
           help="python interpreter to run appdirect tests with")
    group.addoption('-D', '--direct-apptest', action="store_true",
           default=False, dest="direct_apptest",
           help="run '%s' tests directly on host interpreter" % APPLEVEL_FN)
    group.addoption('--direct', action="store_true",
           default=False, dest="rundirect",
           help="run pexpect tests directly")
    group.addoption('--raise-operr', action="store_true",
            default=False, dest="raise_operr",
            help="Show the interp-level OperationError in app-level tests")
    group.addoption('--no-applevel-rewrite', action="store_false",
            default=True, dest="applevel_rewrite",
            help="Don't use assert rewriting in app-level test files")

@pytest.fixture(scope='class')
def spaceconfig(request):
    return getattr(request.cls, 'spaceconfig', {})

@pytest.fixture(scope='function')
def space(spaceconfig):
    from pypy.tool.pytest.objspace import gettestobjspace
    return gettestobjspace(**spaceconfig)


#
# Interfacing/Integrating with py.test's collection process
#
#

def ensure_pytest_builtin_helpers(helpers='skip raises'.split()):
    """ hack (py.test.) raises and skip into builtins, needed
        for applevel tests to run directly on cpython but
        apparently earlier on "raises" was already added
        to module's globals.
    """
    try:
        import builtins
    except ImportError:
        import __builtin__ as builtins
    for helper in helpers:
        if not hasattr(builtins, helper):
            setattr(builtins, helper, getattr(py.test, helper))

def pytest_sessionstart(session):
    """ before session.main() is called. """
    # stick py.test raise in module globals -- carefully
    ensure_pytest_builtin_helpers()

def pytest_pycollect_makemodule(path, parent):
    if path.fnmatch(APPLEVEL_FN):
        if parent.config.getoption('direct_apptest'):
            return
        from pypy.tool.pytest.apptest2 import AppTestModule
        rewrite = parent.config.getoption('applevel_rewrite')
        return AppTestModule(path, parent, rewrite_asserts=rewrite)
    else:
        return PyPyModule(path, parent)

def is_applevel(item):
    from pypy.tool.pytest.apptest import AppTestMethod
    return isinstance(item, AppTestMethod)

def pytest_collection_modifyitems(config, items):
    if config.getoption('runappdirect') or config.getoption('direct_apptest'):
        return
    for item in items:
        if isinstance(item, py.test.Function):
            if is_applevel(item):
                item.add_marker('applevel')
            else:
                item.add_marker('interplevel')


class PyPyModule(pytest.Module):
    """ we take care of collecting classes both at app level
        and at interp-level (because we need to stick a space
        at the class) ourselves.
    """
    def accept_regular_test(self):
        if self.config.option.runappdirect:
            # only collect regular tests if we are in test_lib_pypy
            for name in self.listnames():
                if "test_lib_pypy" in name:
                    return True
            return False
        return True

    def funcnamefilter(self, name):
        if name.startswith('test_'):
            return self.accept_regular_test()
        return False

    def classnamefilter(self, name):
        if name.startswith('Test'):
            return self.accept_regular_test()
        if name.startswith('AppTest'):
            return True
        return False

    def makeitem(self, name, obj):
        if isclass(obj) and self.classnamefilter(name):
            if name.startswith('AppTest'):
                from pypy.tool.pytest.apptest import AppClassCollector
                return AppClassCollector(name, parent=self)
        return super(PyPyModule, self).makeitem(name, obj)

def skip_on_missing_buildoption(**ropts):
    __tracebackhide__ = True
    import sys
    options = getattr(sys, 'pypy_translation_info', None)
    if options is None:
        py.test.skip("not running on translated pypy3 "
                     "(btw, i would need options: %s)" %
                     (ropts,))
    for opt in ropts:
        if not options.has_key(opt) or options[opt] != ropts[opt]:
            break
    else:
        return
    py.test.skip("need translated pypy3 with: %s, got %s"
                 %(ropts,options))

@pytest.hookimpl(tryfirst=True)
def pytest_runtest_setup(item):
    if isinstance(item, py.test.collect.Function):
        config = item.config
        if item.get_marker(name='pypy_only'):
            if config.applevel is not None and not config.applevel.is_pypy:
                pytest.skip('PyPy-specific test')
        appclass = item.getparent(py.test.Class)
        if appclass is not None:
            from pypy.tool.pytest.objspace import gettestobjspace
            # Make cls.space and cls.runappdirect available in tests.
            spaceconfig = getattr(appclass.obj, 'spaceconfig', {})
            appclass.obj.space = gettestobjspace(**spaceconfig)
            appclass.obj.runappdirect = config.option.runappdirect

def pytest_ignore_collect(path, config):
    if (config.getoption('direct_apptest') and not path.isdir()
            and not path.fnmatch(APPLEVEL_FN)):
        return True
    return path.check(link=1)
