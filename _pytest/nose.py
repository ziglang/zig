""" run test suites written for nose. """

import sys

import py
import pytest
from _pytest import unittest


def get_skip_exceptions():
    skip_classes = set()
    for module_name in ('unittest', 'unittest2', 'nose'):
        mod = sys.modules.get(module_name)
        if hasattr(mod, 'SkipTest'):
            skip_classes.add(mod.SkipTest)
    return tuple(skip_classes)


def pytest_runtest_makereport(item, call):
    if call.excinfo and call.excinfo.errisinstance(get_skip_exceptions()):
        # let's substitute the excinfo with a pytest.skip one
        call2 = call.__class__(lambda:
                    pytest.skip(str(call.excinfo.value)), call.when)
        call.excinfo = call2.excinfo


@pytest.hookimpl(trylast=True)
def pytest_runtest_setup(item):
    if is_potential_nosetest(item):
        if isinstance(item.parent, pytest.Generator):
            gen = item.parent
            if not hasattr(gen, '_nosegensetup'):
                call_optional(gen.obj, 'setup')
                if isinstance(gen.parent, pytest.Instance):
                    call_optional(gen.parent.obj, 'setup')
                gen._nosegensetup = True
        if not call_optional(item.obj, 'setup'):
            # call module level setup if there is no object level one
            call_optional(item.parent.obj, 'setup')
        #XXX this implies we only call teardown when setup worked
        item.session._setupstate.addfinalizer((lambda: teardown_nose(item)), item)

def teardown_nose(item):
    if is_potential_nosetest(item):
        if not call_optional(item.obj, 'teardown'):
            call_optional(item.parent.obj, 'teardown')
        #if hasattr(item.parent, '_nosegensetup'):
        #    #call_optional(item._nosegensetup, 'teardown')
        #    del item.parent._nosegensetup


def pytest_make_collect_report(collector):
    if isinstance(collector, pytest.Generator):
        call_optional(collector.obj, 'setup')


def is_potential_nosetest(item):
    # extra check needed since we do not do nose style setup/teardown
    # on direct unittest style classes
    return isinstance(item, pytest.Function) and \
        not isinstance(item, unittest.TestCaseFunction)


def call_optional(obj, name):
    method = getattr(obj, name, None)
    isfixture = hasattr(method, "_pytestfixturefunction")
    if method is not None and not isfixture and py.builtin.callable(method):
        # If there's any problems allow the exception to raise rather than
        # silently ignoring them
        method()
        return True
