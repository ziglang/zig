import os
import pytest

if os.name != 'posix':
    pytest.skip('pwd module only available on unix')

class AppTestPwd:
    spaceconfig = dict(usemodules=['pwd'])

    def test_getpwuid(self):
        import pwd, sys, re
        raises(KeyError, pwd.getpwuid, -1)
        pw = pwd.getpwuid(0)
        assert pw.pw_name == 'root'
        assert isinstance(pw.pw_passwd, str)
        assert pw.pw_uid == 0
        assert pw.pw_gid == 0
        if sys.platform.startswith('linux'):
            assert pw.pw_dir == '/root'
        else:
            assert pw.pw_dir.startswith('/')
        assert pw.pw_shell.startswith('/')
        assert type(pw.pw_uid) is int
        assert type(pw.pw_gid) is int
        raises(TypeError, pwd.getpwuid)
        raises(TypeError, pwd.getpwuid, 3.14)
        raises(KeyError, pwd.getpwuid, sys.maxsize)
        # -1 is allowed, cast to uid_t
        exc = raises(KeyError, pwd.getpwuid, -1)
        m = re.match('getpwuid\(\): uid not found: ([0-9]+)', exc.value.args[0])
        assert m, exc.value.args[0]
        maxval = int(m.group(1))
        assert maxval >= 2**32 - 1
        # shouldn't overflow
        exc = raises(KeyError, pwd.getpwuid, maxval)
        m = re.match('getpwuid\(\): uid not found: ([0-9]+)', exc.value.args[0])
        assert m, exc.value.args[0]
        # should be out of uid_t range
        for v in [-2, maxval+1, 2**128, -2**128]:
            exc = raises(KeyError, pwd.getpwuid, v)
            assert exc.value.args[0] == 'getpwuid(): uid not found'

    def test_getpwnam(self):
        import pwd
        raises(TypeError, pwd.getpwnam)
        raises(TypeError, pwd.getpwnam, 42)
        raises(TypeError, pwd.getpwnam, b'root')
        raises(KeyError, pwd.getpwnam, '~invalid~')
        assert pwd.getpwnam('root').pw_name == 'root'

    def test_getpwall(self):
        import pwd
        raises(TypeError, pwd.getpwall, 42)
        assert pwd.getpwnam('root') in pwd.getpwall()
