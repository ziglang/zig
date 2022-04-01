import errno

class AppTestErrno:
    spaceconfig = dict(usemodules=['errno'])

    def setup_class(cls):
        cls.w_errno = cls.space.appexec([], "(): import errno ; return errno")
        cls.w_errorcode = cls.space.wrap(errno.errorcode)

    def test_posix(self):
        assert not hasattr(self.errno, '__file__')

    def test_constants(self):
        # Assumes that our constants are a superset of the host's
        for code, name in self.errorcode.items():
            assert getattr(self.errno, name) == code

    def test_errorcode(self):
        # Assumes that our codes are a superset of the host's
        for value, name in self.errorcode.items():
            assert self.errno.errorcode[value] == name
