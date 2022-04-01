import pytest
import platform
import sys
from os.path import commonprefix, dirname

THIS_DIR = dirname(__file__)

@pytest.hookimpl(tryfirst=True)
def pytest_ignore_collect(path, config):
    path = str(path)
    if sys.platform == 'win32' or platform.machine() == 's390x':
        if commonprefix([path, THIS_DIR]) == THIS_DIR:  # workaround for bug in pytest<3.0.5
            return True
