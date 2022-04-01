import os, py, errno
from rpython.translator.c.test.test_genc import compile
from rpython.rlib import rsignal

def setup_module(mod):
    if not hasattr(os, 'kill') or not hasattr(os, 'getpid'):
        py.test.skip("requires os.kill() and os.getpid()")
    if not hasattr(rsignal, 'SIGUSR1'):
        py.test.skip("requires SIGUSR1 in signal")


def check(expected):
    res = rsignal.pypysig_poll()
    os.write(1, "poll() => %d, expected %d\n" % (res, expected))
    assert res == expected

def test_simple():
    import os
    check(-1)
    check(-1)
    for i in range(3):
        rsignal.pypysig_setflag(rsignal.SIGUSR1)
        os.kill(os.getpid(), rsignal.SIGUSR1)
        check(rsignal.SIGUSR1)
        check(-1)
        check(-1)

    rsignal.pypysig_ignore(rsignal.SIGUSR1)
    os.kill(os.getpid(), rsignal.SIGUSR1)
    check(-1)
    check(-1)

    rsignal.pypysig_default(rsignal.SIGUSR1)
    check(-1)


def test_compile():
    fn = compile(test_simple, [])
    fn()

def test_compile_wakeup_fd():
    def fn():
        rd, wr = os.pipe()
        rsignal.pypysig_set_wakeup_fd(wr, False)
        for i in range(3):
            rsignal.pypysig_setflag(rsignal.SIGUSR1)
            os.kill(os.getpid(), rsignal.SIGUSR1)
            check(rsignal.SIGUSR1)
            check(-1)
            check(-1)
        x = os.read(rd, 10)
        assert x == chr(rsignal.SIGUSR1) * 3
        #
        rsignal.pypysig_set_wakeup_fd(rd, False)   # can't write there
        os.kill(os.getpid(), rsignal.SIGUSR1)

    fn = compile(fn, [], return_stderr=True)
    stderr = fn()
    assert stderr.endswith('Exception ignored when trying to write to the '
                           'signal wakeup fd: Errno %d\n' % errno.EBADF)


def test_raise():
    import os
    check(-1)
    check(-1)
    for i in range(3):
        rsignal.pypysig_setflag(rsignal.SIGUSR1)
        rsignal.c_raise(rsignal.SIGUSR1)
        check(rsignal.SIGUSR1)
        check(-1)
        check(-1)

    rsignal.pypysig_ignore(rsignal.SIGUSR1)
    rsignal.c_raise(rsignal.SIGUSR1)
    check(-1)
    check(-1)

    rsignal.pypysig_default(rsignal.SIGUSR1)
    check(-1)

def test_strsignal():
    assert rsignal.strsignal(rsignal.SIGSEGV) == "Segmentation fault"
