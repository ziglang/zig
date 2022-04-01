import sys
import pytest

def get_marker(item, name):
    try:
        return item.get_closest_marker(name=name)
    except AttributeError:
        # pytest < 3.6
        return item.get_marker(name=name)


def pytest_runtest_setup(item):
    if get_marker(item, name='pypy_only'):
        if '__pypy__' not in sys.builtin_module_names:
            pytest.skip('PyPy-specific test')


def pytest_configure(config):
    config.addinivalue_line("markers", "pypy_only: PyPy-specific test")


def pytest_addoption(parser):
    parser.addoption(
        "--compiler-v", action="store_true",
        help="Print to stdout the commands used to invoke the compiler")

