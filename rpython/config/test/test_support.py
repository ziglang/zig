
from cStringIO import StringIO
from rpython.config import support
import os, sys, py

cpuinfo = """
processor\t: 0

processor\t: 1
vendor_id\t: GenuineIntel
cpu family\t: 6
model\t\t: 37
model name\t: Intel(R) Core(TM) i7 CPU       L 620  @ 2.00GHz
stepping\t: 2

processor\t: 2
vendor_id\t: GenuineIntel
cpu family\t: 6
model\t\t: 37
model name\t: Intel(R) Core(TM) i7 CPU       L 620  @ 2.00GHz
stepping\t: 2

processor\t: 3
vendor_id\t: GenuineIntel
cpu family\t: 6
model\t\t: 37
model name\t: Intel(R) Core(TM) i7 CPU       L 620  @ 2.00GHz
stepping\t: 2
cpu MHz\t\t: 1199.000
cache size\t: 4096 KB
physical id\t: 0
siblings\t: 4
"""

class FakeEnviron:
    def __init__(self, value):
        self._value = value
    def get(self, varname):
        assert varname == 'MAKEFLAGS'
        return self._value

def test_cpuinfo_linux():
    if not sys.platform.startswith('linux'):
        py.test.skip("linux only")
    saved = os.environ
    try:
        os.environ = FakeEnviron(None)
        assert support.detect_number_of_processors(StringIO(cpuinfo)) == 3
        assert support.detect_number_of_processors('random crap that does not exist') == 1
        os.environ = FakeEnviron('-j2')
        assert support.detect_number_of_processors(StringIO(cpuinfo)) == 1
    finally:
        os.environ = saved

def test_cpuinfo_sysctl():
    if sys.platform != 'darwin' and not sys.platform.startswith('freebsd'):
        py.test.skip('mac and bsd only')
    saved_func = support.sysctl_get_cpu_count
    saved = os.environ
    def count(cmd):
        if sys.platform == 'darwin':
            assert cmd == '/usr/sbin/sysctl'
        else:
            assert cmd == '/sbin/sysctl'
        return 42
    try:
        support.sysctl_get_cpu_count = count
        os.environ = FakeEnviron(None)
        assert support.detect_number_of_processors() == 42
        os.environ = FakeEnviron('-j2')
        assert support.detect_number_of_processors() == 1
    finally:
        os.environ = saved
        support.sysctl_get_cpu_count = saved_func

def test_sysctl_get_cpu_count():
    if sys.platform != 'darwin' and not sys.platform.startswith('freebsd'):
        py.test.skip('mac and bsd only')
    cmd = '/usr/sbin/sysctl' if sys.platform != 'darwin' else '/sbin/sysctl'
    assert support.sysctl_get_cpu_count(cmd) > 0 # hopefully
    assert support.sysctl_get_cpu_count(cmd, "false") == 1
