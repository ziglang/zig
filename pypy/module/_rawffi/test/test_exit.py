
class AppTestFfi:
    spaceconfig = dict(usemodules=['_rawffi', 'posix'])

    def test_exit(self):
        try:
            import posix, _rawffi
        except ImportError:
            skip("requires posix.fork() to test")
        #
        pid = posix.fork()
        if pid == 0:
            _rawffi.exit(5)   # in the child
        pid, status = posix.waitpid(pid, 0)
        assert posix.WIFEXITED(status)
        assert posix.WEXITSTATUS(status) == 5
