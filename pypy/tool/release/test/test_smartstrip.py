import pytest
import sys
import os
from commands import getoutput
from pypy.tool.release.smartstrip import smartstrip

@pytest.fixture
def exe(tmpdir):
    src = tmpdir.join("myprog.c")
    src.write("""
    int foo(int a, int b) {
        return a+b;
    }
    int main(void) { }
    """)
    exe = tmpdir.join("myprog")
    ret = os.system("gcc -o %s %s" % (exe, src))
    assert ret == 0
    return exe

def info_symbol(exe, symbol):
    out = getoutput("gdb %s -ex 'info symbol %s' -ex 'quit'" % (exe, symbol))
    lines = out.splitlines()
    return lines[-1]

@pytest.mark.skipif(sys.platform == 'win32',
                    reason='strip not supported on windows')
class TestSmarStrip(object):

    def test_info_symbol(self, exe):
        info = info_symbol(exe, "foo")
        assert info == "foo in section .text"

    def test_strip(self, exe):
        smartstrip(exe, keep_debug=False)
        info = info_symbol(exe, "foo")
        assert info.startswith("No symbol table is loaded")

    @pytest.mark.skipif(sys.platform != 'linux2',
                        reason='keep_debug not supported')
    def test_keep_debug(self, exe, tmpdir):
        smartstrip(exe, keep_debug=True)
        debug = tmpdir.join("myprog.debug")
        assert debug.check(file=True)
        perm = debug.stat().mode & 0777
        assert perm & 0111 == 0 # 'x' bit not set
        #
        info = info_symbol(exe, "foo")
        assert info == "foo in section .text of %s" % exe
        #
        debug.remove()
        info = info_symbol(exe, "foo")
        assert info.startswith("No symbol table is loaded")
