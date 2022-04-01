import py, pytest
from rpython.tool import leakfinder

pytest_plugins = 'rpython.tool.pytest.expecttest'

option = None

try:
    from hypothesis import settings
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

def braindead_deindent(self):
    """monkeypatch that wont end up doing stupid in the python tokenizer"""
    text = '\n'.join(self.lines)
    short = py.std.textwrap.dedent(text)
    newsource = py.code.Source()
    newsource.lines[:] = short.splitlines()
    return newsource

py.code.Source.deindent = braindead_deindent

def pytest_report_header():
    return "pytest-%s from %s" %(pytest.__version__, pytest.__file__)

def pytest_configure(config):
    global option
    option = config.option
    from rpython.config.translationoption import PLATFORMS
    from rpython.translator.platform import set_platform
    platform = config.option.platform
    if platform not in PLATFORMS:
        raise ValueError("%s not in %s" % (platform, PLATFORMS))
    set_platform(platform, None)


def pytest_addoption(parser):
    group = parser.getgroup("rpython options")
    group.addoption('--view', action="store_true", dest="view", default=False,
           help="view translation tests' flow graphs with Pygame")
    group.addoption('-P', '--platform', action="store", dest="platform",
                    type="string", default="host",
           help="set up tests to use specified platform as compile/run target")
    group = parser.getgroup("JIT options")
    group.addoption('--viewloops', action="store_true",
           default=False, dest="viewloops",
           help="show only the compiled loops")
    group.addoption('--viewdeps', action="store_true",
           default=False, dest="viewdeps",
           help="show the dependencies that have been constructed from a trace")


def pytest_addhooks(pluginmanager):
    pluginmanager.register(LeakFinder())

class LeakFinder:
    """Track memory allocations during test execution.

    So far, only used by the function lltype.malloc(flavor='raw').
    """
    @pytest.hookimpl(trylast=True)
    def pytest_runtest_setup(self, item):
        if not isinstance(item, py.test.collect.Function):
            return
        if not getattr(item.obj, 'dont_track_allocations', False):
            leakfinder.start_tracking_allocations()
        from rpython.rlib import rgil
        rgil._reset_emulated_gil_holder()

    @pytest.hookimpl(trylast=True)
    def pytest_runtest_call(self, item):
        if not isinstance(item, py.test.collect.Function):
            return
        item._success = True

    @pytest.hookimpl(trylast=True)
    def pytest_runtest_teardown(self, item):
        if not isinstance(item, py.test.collect.Function):
            return
        if (not getattr(item.obj, 'dont_track_allocations', False)
            and leakfinder.TRACK_ALLOCATIONS):
            kwds = {}
            try:
                kwds['do_collection'] = item.track_allocations_collect
            except AttributeError:
                pass
            item._pypytest_leaks = leakfinder.stop_tracking_allocations(False,
                                                                        **kwds)
        else:            # stop_tracking_allocations() already called
            item._pypytest_leaks = None

        # check for leaks, but only if the test passed so far
        if getattr(item, '_success', False) and item._pypytest_leaks:
            raise leakfinder.MallocMismatch(item._pypytest_leaks)
