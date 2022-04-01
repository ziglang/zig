import os, py
from rpython.rlib import rlocale
from pypy.module.sys.interp_encoding import _getfilesystemencoding
from pypy.module.sys.interp_encoding import base_encoding


def test__getfilesystemencoding(space):
    if not (rlocale.HAVE_LANGINFO and rlocale.CODESET):
        py.test.skip("requires HAVE_LANGINFO and CODESET")

    def clear():
        for key in os.environ.keys():
            if key == 'LANG' or key.startswith('LC_'):
                del os.environ[key]

    def get(**env):
        original_env = os.environ.copy()
        try:
            clear()
            os.environ.update(env)
            return _getfilesystemencoding(space)
        finally:
            clear()
            os.environ.update(original_env)

    assert get() in (base_encoding, 'ascii')
    assert get(LANG='foobar') in (base_encoding, 'ascii')
    assert get(LANG='en_US.UTF-8') == 'utf-8'
    assert get(LC_ALL='en_US.UTF-8') == 'utf-8'
    assert get(LC_CTYPE='en_US.UTF-8') == 'utf-8'
