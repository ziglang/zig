from pypy.tool.release import package
from pypy.module.sys import version

def test_version():
    assert package.STDLIB_VER == '%d' % version.CPYTHON_VERSION[0]
