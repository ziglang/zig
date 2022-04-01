class AppTestOs:
    spaceconfig = dict(usemodules=['__pypy__'])

    def test_real_getenv(self):
        import __pypy__.os
        import os

        key = 'UNLIKELY_SET'
        assert key not in os.environ
        os.putenv(key, '42')
        # this one skips Python cache
        assert __pypy__.os.real_getenv(key) == '42'
        # this one can only see things set on interpter start (cached)
        assert os.getenv(key) is None
        os.unsetenv(key)
        assert __pypy__.os.real_getenv(key) is None
