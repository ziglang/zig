import os, pytest, sys
import signal as cpy_signal
from pypy.tool.pytest.objspace import gettestobjspace

GET_POSIX = "(): import %s as m ; return m" % os.name
USEMODULES = ['posix', 'signal']

def setup_module(mod):
    mod.space = gettestobjspace(usemodules=USEMODULES)

class TestCheckSignals:
    spaceconfig = {'usemodules': USEMODULES}

    def setup_class(cls):
        if not hasattr(os, 'kill') or not hasattr(os, 'getpid'):
            pytest.skip("requires os.kill() and os.getpid()")
        if not hasattr(cpy_signal, 'SIGUSR1'):
            pytest.skip("requires SIGUSR1 in signal")

    def test_checksignals(self):
        import os
        space = self.space
        w_received = space.appexec([], """():
            import _signal as signal
            received = []
            def myhandler(signum, frame):
                received.append(signum)
            signal.signal(signal.SIGUSR1, myhandler)
            return received""")
        #
        assert not space.is_true(w_received)
        #
        # send the signal now
        os.kill(os.getpid(), cpy_signal.SIGUSR1)
        #
        # myhandler() should not be immediately called
        assert not space.is_true(w_received)
        #
        # calling ec.checksignals() should call it
        print(space.getexecutioncontext().checksignals)
        space.getexecutioncontext().checksignals()
        assert space.is_true(w_received)


class AppTestSignal:
    spaceconfig = {
        "usemodules": ['signal', 'time', '_socket'] + (['fcntl'] if os.name != 'nt' else []),
    }

    def setup_class(cls):
        cls.w_temppath = cls.space.wrap(
            str(pytest.ensuretemp("signal").join("foo.txt")))
        cls.w_appdirect = cls.space.wrap(cls.runappdirect)
        cls.w_posix = space.appexec([], GET_POSIX)

    def test_exported_names(self):
        import sys, _signal
        _signal.__dict__   # crashes if the interpleveldefs are invalid
        if sys.platform == 'win32':
            assert _signal.CTRL_BREAK_EVENT == 1
            assert _signal.CTRL_C_EVENT == 0

    def test_basics(self):
        import types, _signal
        os = self.posix
        if not hasattr(os, 'kill') or not hasattr(os, 'getpid'):
            skip("requires os.kill() and os.getpid()")
        signal = _signal   # the signal module to test
        if not hasattr(signal, 'SIGUSR1'):
            skip("requires SIGUSR1 in signal")
        signum = signal.SIGUSR1

        received = []
        def myhandler(signum, frame):
            assert isinstance(frame, types.FrameType)
            received.append(signum)
        signal.signal(signum, myhandler)

        os.kill(os.getpid(), signum)
        # the signal should be delivered to the handler immediately
        assert received == [signum]
        del received[:]

        os.kill(os.getpid(), signum)
        # the signal should be delivered to the handler immediately
        assert received == [signum]
        del received[:]

        signal.signal(signum, signal.SIG_IGN)

        os.kill(os.getpid(), signum)
        for i in range(10000):
            # wait a bit - signal should not arrive
            if received:
                break
        assert received == []

        signal.signal(signum, signal.SIG_DFL)

    def test_default_return(self):
        """
        Test that signal.signal returns SIG_DFL if that is the current handler.
        """
        from _signal import signal, SIGINT, SIG_DFL, SIG_IGN

        try:
            for handler in SIG_DFL, SIG_IGN, lambda *a: None:
                signal(SIGINT, SIG_DFL)
                assert signal(SIGINT, handler) == SIG_DFL
        finally:
            signal(SIGINT, SIG_DFL)

    def test_ignore_return(self):
        """
        Test that signal.signal returns SIG_IGN if that is the current handler.
        """
        from _signal import signal, SIGINT, SIG_DFL, SIG_IGN

        try:
            for handler in SIG_DFL, SIG_IGN, lambda *a: None:
                signal(SIGINT, SIG_IGN)
                assert signal(SIGINT, handler) == SIG_IGN
        finally:
            signal(SIGINT, SIG_DFL)

    def test_obj_return(self):
        """
        Test that signal.signal returns a Python object if one is the current
        handler.
        """
        from _signal import signal, SIGINT, SIG_DFL, SIG_IGN
        def installed(*a):
            pass

        try:
            for handler in SIG_DFL, SIG_IGN, lambda *a: None:
                signal(SIGINT, installed)
                assert signal(SIGINT, handler) is installed
        finally:
            signal(SIGINT, SIG_DFL)

    def test_getsignal(self):
        """
        Test that signal.getsignal returns the currently installed handler.
        """
        from _signal import getsignal, signal, SIGINT, SIG_DFL, SIG_IGN

        def handler(*a):
            pass

        try:
            if not self.appdirect:
                assert getsignal(SIGINT) == SIG_DFL
            signal(SIGINT, SIG_DFL)
            assert getsignal(SIGINT) == SIG_DFL
            signal(SIGINT, SIG_IGN)
            assert getsignal(SIGINT) == SIG_IGN
            signal(SIGINT, handler)
            assert getsignal(SIGINT) is handler
        finally:
            signal(SIGINT, SIG_DFL)

    def test_check_signum(self):
        import sys
        from _signal import getsignal, signal, NSIG

        # signum out of range fails
        raises(ValueError, getsignal, NSIG)
        raises(ValueError, signal, NSIG, lambda *args: None)

        # on windows invalid signal within range should pass getsignal but fail signal
        if sys.platform == 'win32':
            assert getsignal(7) == None
            raises(ValueError, signal, 7, lambda *args: None)

    def test_alarm(self):
        try:
            from _signal import alarm, signal, SIG_DFL, SIGALRM
        except:
            skip('no alarm on this platform')
        import time
        l = []
        def handler(*a):
            l.append(42)

        try:
            signal(SIGALRM, handler)
            alarm(1)
            time.sleep(2)
            assert l == [42]
            alarm(0)
            assert l == [42]
        finally:
            signal(SIGALRM, SIG_DFL)

    def test_set_wakeup_fd(self):
        try:
            import _signal as signal, posix, fcntl
        except ImportError:
            skip('cannot import posix or fcntl')
        def myhandler(signum, frame):
            pass
        signal.signal(signal.SIGINT, myhandler)
        #
        def cannot_read():
            try:
                posix.read(fd_read, 1)
            except OSError:
                pass
            else:
                raise AssertionError("posix.read(fd_read, 1) succeeded?")
        #
        fd_read, fd_write = posix.pipe()
        flags = fcntl.fcntl(fd_write, fcntl.F_GETFL, 0)
        flags = flags | posix.O_NONBLOCK
        fcntl.fcntl(fd_write, fcntl.F_SETFL, flags)
        flags = fcntl.fcntl(fd_read, fcntl.F_GETFL, 0)
        flags = flags | posix.O_NONBLOCK
        fcntl.fcntl(fd_read, fcntl.F_SETFL, flags)
        #
        old_wakeup = signal.set_wakeup_fd(fd_write, warn_on_full_buffer=False)
        try:
            cannot_read()
            posix.kill(posix.getpid(), signal.SIGINT)
            res = posix.read(fd_read, 1)
            assert res == bytes([signal.SIGINT])
            cannot_read()
        finally:
            old_wakeup = signal.set_wakeup_fd(old_wakeup)
        #
        signal.signal(signal.SIGINT, signal.SIG_DFL)

    def test_set_wakeup_fd_socket_result(self):
        import _socket as socket
        import _signal as signal
        sock1 = socket.socket()
        sock2 = socket.socket()
        try:
            sock1.setblocking(False)
            fd1 = sock1.fileno()
            sock2.setblocking(False)
            fd2 = sock2.fileno()

            signal.set_wakeup_fd(fd1)
            signal.set_wakeup_fd(fd2) == fd1
            assert signal.set_wakeup_fd(-1) == fd2
        finally:
            sock1.close()
            sock2.close()

    def test_set_wakeup_fd_invalid(self):
        import _signal as signal
        with open(self.temppath, 'wb') as f:
            fd = f.fileno()
        raises((ValueError, OSError), signal.set_wakeup_fd, fd)

    def test_siginterrupt(self):
        import _signal as signal, time
        os = self.posix
        if not hasattr(signal, 'siginterrupt'):
            skip('non siginterrupt in signal')
        signum = signal.SIGUSR1
        def readpipe_is_not_interrupted():
            # from CPython's test_signal.readpipe_interrupted()
            r, w = os.pipe()
            ppid = os.getpid()
            pid = os.fork()
            if pid == 0:
                try:
                    time.sleep(1)
                    os.kill(ppid, signum)
                    time.sleep(1)
                finally:
                    os._exit(0)
            else:
                try:
                    os.close(w)
                    # we expect not to be interrupted.  If we are, the
                    # following line raises OSError(EINTR).
                    os.read(r, 1)
                finally:
                    os.waitpid(pid, 0)
                    os.close(r)
        #
        oldhandler = signal.signal(signum, lambda x,y: None)
        try:
            signal.siginterrupt(signum, 0)
            readpipe_is_not_interrupted()
            readpipe_is_not_interrupted()
        finally:
            signal.signal(signum, oldhandler)

    def test_default_int_handler(self):
        import signal
        for args in [(), (1, 2)]:
            try:
                signal.default_int_handler(*args)
            except KeyboardInterrupt:
                pass
            else:
                raise AssertionError("did not raise!")

    def test_valid_signals(self):
        import signal, sys
        s = signal.valid_signals()
        assert isinstance(s, set)
        assert signal.Signals.SIGINT in s
        if sys.platform != "win32":
            assert signal.Signals.SIGALRM in s
        assert 0 not in s
        assert signal.NSIG not in s
        assert len(s) < signal.NSIG

    def test_strsignal(self):
        import signal
        assert signal.strsignal(signal.Signals.SIGSEGV) == "Segmentation fault"
        raises(ValueError, signal.strsignal, 4242)


class AppTestSignalSocket:
    spaceconfig = dict(usemodules=['signal', '_socket'])

    def test_alarm_raise(self):
        try:
            from _signal import alarm, signal, SIG_DFL, SIGALRM
        except ImportError:
            skip("no SIGALRM on this platform")
        import _socket
        class Alarm(Exception):
            pass
        def handler(*a):
            raise Alarm()

        s = _socket.socket()
        s.listen(1)
        try:
            signal(SIGALRM, handler)
            alarm(1)
            try:
                s._accept()
            except Alarm:
                pass
            else:
                raise Exception("should have raised Alarm")
            alarm(0)
        finally:
            signal(SIGALRM, SIG_DFL)


@pytest.mark.skipif(sys.platform == 'win32', reason='posix-only')
class AppTestItimer:
    spaceconfig = dict(usemodules=['signal'])

    def test_itimer_real(self):
        import _signal as signal

        def sig_alrm(*args):
            self.called = True

        signal.signal(signal.SIGALRM, sig_alrm)
        old = signal.setitimer(signal.ITIMER_REAL, 1.0)
        assert old == (0, 0)

        val, interval = signal.getitimer(signal.ITIMER_REAL)
        assert val <= 1.0
        assert interval == 0.0

        signal.pause()
        assert self.called

    def test_itimer_exc(self):
        import _signal as signal

        raises(signal.ItimerError, signal.setitimer, -1, 0)

@pytest.mark.skipif(sys.platform == 'win32', reason='posix-only')
class AppTestPThread:
    spaceconfig = dict(usemodules=['signal', 'thread', 'time'])

    def test_pthread_kill(self):
        import _signal as signal
        import _thread
        signum = signal.SIGUSR1
        def handler(signum, frame):
            1/0
        signal.signal(signum, handler)
        tid = _thread.get_ident()
        raises(ZeroDivisionError, signal.pthread_kill, tid, signum)
        
    def test_sigwait(self):
        import _signal as signal
        def handler(signum, frame):
            1/0
        signal.signal(signal.SIGALRM, handler)
        signal.alarm(1)
        received = signal.sigwait([signal.SIGALRM])
        assert received == signal.SIGALRM
        
    def test_sigmask(self):
        import _signal as signal, posix
        signum1 = signal.SIGUSR1
        signum2 = signal.SIGUSR2

        def handler(signum, frame):
            pass
        signal.signal(signum1, handler)
        signal.signal(signum2, handler)

        signal.pthread_sigmask(signal.SIG_BLOCK, (signum1, signum2))
        posix.kill(posix.getpid(), signum1)
        posix.kill(posix.getpid(), signum2)
        assert signal.sigpending() == set((signum1, signum2))
        # Unblocking the 2 signals calls the C signal handler twice
        signal.pthread_sigmask(signal.SIG_UNBLOCK, (signum1, signum2))
        assert signal.sigpending() == set()

    def test_raise_signal(self):
        import types, _signal, sys
        signal = _signal   # the signal module to test
        if sys.platform == 'win32':
            raises(OSError, signal.raise_signal, 1)
        if not hasattr(signal, 'SIGUSR1'):
            skip("requires SIGUSR1 in signal")
        signum = signal.SIGUSR1

        received = []
        def myhandler(signum, frame):
            assert isinstance(frame, types.FrameType)
            received.append(signum)
        signal.signal(signum, myhandler)

        signal.raise_signal(signum)
        # the signal should be delivered to the handler immediately
        assert received == [signum]
        del received[:]

        signal.raise_signal(signum)
        # the signal should be delivered to the handler immediately
        assert received == [signum]
        del received[:]

        signal.signal(signum, signal.SIG_IGN)

        signal.raise_signal(signum)
        for i in range(10000):
            # wait a bit - signal should not arrive
            if received:
                break
        assert received == []

        signal.signal(signum, signal.SIG_DFL)

