from pypy.module.thread.test.support import GenericTestThread

class AppTestFork(GenericTestThread):
    spaceconfig = dict(usemodules=GenericTestThread.spaceconfig['usemodules'] + ('imp',))

    def test_fork_with_thread(self):
        # XXX This test depends on a multicore machine, as busy_thread must
        # aquire the GIL the instant that the main thread releases it.
        # It will incorrectly pass if the GIL is not grabbed in time.
        import _thread
        import os
        import time

        if not hasattr(os, 'fork'):
            skip("No fork on this platform")
        if not self.runappdirect:
            skip("Not reliable before translation")

        def busy_thread():
            print('sleep')
            while run:
                time.sleep(0)
            done.append(None)

        for i in range(150):
            run = True
            done = []
            try:
                print('sleep')
                _thread.start_new(busy_thread, ())

                pid = os.fork()
                if pid == 0:
                    os._exit(0)
                else:
                    self.timeout_killer(pid, 10)
                    exitcode = os.waitpid(pid, 0)[1]
                    assert exitcode == 0 # if 9, process was killed by timer!
            finally:
                run = False
                self.waitfor(lambda: done)
                assert done

    def test_forked_can_thread(self):
        "Checks that a forked interpreter can start a thread"
        import _thread
        import os

        if not hasattr(os, 'fork'):
            skip("No fork on this platform")

        for i in range(10):
            # pre-allocate some locks
            _thread.start_new_thread(lambda: None, ())
            print('sleep')

            pid = os.fork()
            if pid == 0:
                _thread.start_new_thread(lambda: None, ())
                os._exit(0)
            else:
                self.timeout_killer(pid, 10)
                exitcode = os.waitpid(pid, 0)[1]
                assert exitcode == 0 # if 9, process was killed by timer!

    def test_forked_is_main_thread(self):
        "Checks that a forked interpreter is the main thread"
        import os, _thread, signal

        if not hasattr(os, 'fork'):
            skip("No fork on this platform")

        def threadfunction():
            pid = os.fork()
            if pid == 0:
                print('in child')
                # signal() only works from the 'main' thread
                signal.signal(signal.SIGUSR1, signal.SIG_IGN)
                os._exit(42)
            else:
                self.timeout_killer(pid, 10)
                exitcode = os.waitpid(pid, 0)[1]
                feedback.append(exitcode)

        feedback = []
        _thread.start_new_thread(threadfunction, ())
        self.waitfor(lambda: feedback)
        # if 0, an (unraisable) exception was raised from the forked thread.
        # if 9, process was killed by timer.
        # if 42<<8, os._exit(42) was correctly reached.
        assert feedback == [42<<8]

    def test_nested_import_lock_fork(self):
        """Check fork() in main thread works while the main thread is doing an import"""
        # Issue 9573: this used to trigger RuntimeError in the child process
        import imp
        import os
        import time

        if not hasattr(os, 'fork'):
            skip("No fork on this platform")

        def fork_with_import_lock(level):
            release = 0
            in_child = False
            try:
                try:
                    for i in range(level):
                        imp.acquire_lock()
                        release += 1
                    pid = os.fork()
                    in_child = not pid
                finally:
                    for i in range(release):
                        imp.release_lock()
            except RuntimeError:
                if in_child:
                    if verbose > 1:
                        print("RuntimeError in child")
                    os._exit(1)
                raise
            if in_child:
                os._exit(0)

            for i in range(10):
                spid, status = os.waitpid(pid, os.WNOHANG)
                if spid == pid:
                    break
                time.sleep(1.0)
            assert spid == pid
            assert status == 0

        # Check this works with various levels of nested
        # import in the main thread
        for level in range(5):
            fork_with_import_lock(level)
