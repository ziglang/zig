import sys

from pypy.module.thread.test.support import GenericTestThread

class AppTestMinimal:
    spaceconfig = dict(usemodules=['__pypy__'])

    def test_signal(self):
        from __pypy__ import thread
        assert type(thread.signals_enabled).__module__ == '__pypy__.thread'
        with thread.signals_enabled:
            pass
        # assert did not crash


class AppTestThreadSignal(GenericTestThread):
    spaceconfig = dict(usemodules=['__pypy__', 'thread', 'signal', 'time'])

    def test_exit_twice(self):
        import __pypy__, _thread
        __pypy__.thread._signals_exit()
        try:
            raises(_thread.error, __pypy__.thread._signals_exit)
        finally:
            __pypy__.thread._signals_enter()

    def test_enable_signals(self):
        if not self.runappdirect:
            skip("test is flaky when untranslated on bencher4 and aarch64")

        import __pypy__, _thread, signal, time, sys

        def subthread():
            print('subthread started')
            try:
                with __pypy__.thread.signals_enabled:
                    _thread.interrupt_main()
                    for i in range(10):
                        print('x')
                        time.sleep(0.25)
            except BaseException as e:
                interrupted.append(e)
            finally:
                print('subthread stops, interrupted=%r' % (interrupted,))
                done.append(None)

        # This is normally called by app_main.py
        signal.signal(signal.SIGINT, signal.default_int_handler)

        if sys.platform.startswith('win'):
            # Windows seems to hang on _setmode when the first print comes from
            # a thread, so make sure we've initialized io
            sys.stderr

        for i in range(10):
            __pypy__.thread._signals_exit()
            try:
                done = []
                interrupted = []
                print('--- start ---')
                _thread.start_new_thread(subthread, ())
                for j in range(30):
                    if len(done): break
                    print('.')
                    time.sleep(0.25)
                print('main thread loop done')
                assert len(done) == 1
                assert len(interrupted) == 1
                assert 'KeyboardInterrupt' in interrupted[0].__class__.__name__
            finally:
                __pypy__.thread._signals_enter()

    def test_thread_fork_signals(self):
        import __pypy__
        import os, _thread, signal, time

        if not hasattr(os, 'fork'):
            skip("No fork on this platform")

        def fork():
            time.sleep(0.1)
            with __pypy__.thread.signals_enabled:
                return os.fork()

        def threadfunction():
            pid = fork()
            if pid == 0:
                # signal() only works from the 'main' thread
                signal.signal(signal.SIGUSR1, signal.SIG_IGN)
                os._exit(42)
            else:
                self.timeout_killer(pid, 5)
                exitcode = os.waitpid(pid, 0)[1]
                feedback.append(exitcode)

        feedback = []
        _thread.start_new_thread(threadfunction, ())
        time.sleep(3)
        self.waitfor(lambda: feedback)
        # if 0, an (unraisable) exception was raised from the forked thread.
        # if 9, process was killed by timer.
        # if 42<<8, os._exit(42) was correctly reached.
        assert feedback == [42<<8]


class AppTestThreadSignalLock:
    spaceconfig = dict(usemodules=['__pypy__', 'thread', 'signal'])

    def setup_class(cls):
        if (not cls.runappdirect):
            import py
            py.test.skip("this is only a test for -A runs on top of pypy")

    def test_enable_signals(self):
        import __pypy__, _thread, time

        interrupted = []
        lock = _thread.allocate_lock()
        lock.acquire()

        def subthread():
            try:
                time.sleep(0.5)
                with __pypy__.thread.signals_enabled:
                    _thread.interrupt_main()
            except BaseException as e:
                interrupted.append(e)
            finally:
                lock.release()

        _thread.start_new_thread(subthread, ())
        lock.acquire()
        assert len(interrupted) == 1
        assert 'KeyboardInterrupt' in interrupted[0].__class__.__name__
