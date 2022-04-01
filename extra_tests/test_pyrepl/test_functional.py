#   Copyright 2000-2007 Michael Hudson-Doyle <micahel@gmail.com>
#                       Maciek Fijalkowski
# License: MIT
# some functional tests, to see if this is really working

import pytest
import sys


@pytest.fixture()
def child():
    try:
        import pexpect
    except ImportError:
        pytest.skip("no pexpect module")
    except SyntaxError:
        pytest.skip('pexpect wont work on py3k')
    child = pexpect.spawn(sys.executable, ['-S'], timeout=10)
    child.logfile = sys.stdout
    child.sendline('from pyrepl.python_reader import main')
    child.sendline('main()')
    return child


def test_basic(child):
    child.sendline('a = 3')
    child.sendline('a')
    child.expect('3')
