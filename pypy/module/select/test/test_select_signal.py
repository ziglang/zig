import pytest
import sys

class AppTestSelectSignal:
    spaceconfig = {
        "usemodules": ['select', 'time', 'signal'],
    }

    @pytest.mark.skipif(sys.platform=="win32", reason="not supported on windows")
    def test_pep475_retry(self):
        import select, time
        import _signal as signal

        def foo(*args):
            signalled.append("ALARM")

        # a list of functions that will do nothing more than sleep for 3
        # seconds
        cases = [(select.select, [], [], [], 3.0)]

        if hasattr(select, 'poll'):
            import posix
            poll = select.poll()
            cases.append((poll.poll, 3000))    # milliseconds

        if hasattr(select, 'epoll'):
            epoll = select.epoll()
            cases.append((epoll.poll, 3.0))

        if hasattr(select, 'kqueue'):
            kqueue = select.kqueue()
            cases.append((kqueue.control, [], 1, 3.0))

        if hasattr(select, 'devpoll'):
            raise NotImplementedError("write this test if we have devpoll")

        for wait_for_three_seconds in cases:
            print(wait_for_three_seconds[0])
            signalled = []
            signal.signal(signal.SIGALRM, foo)
            try:
                t1 = time.time()
                signal.alarm(1)
                wait_for_three_seconds[0](*wait_for_three_seconds[1:])
                t2 = time.time()
            finally:
                signal.signal(signal.SIGALRM, signal.SIG_DFL)

            print("result: signalled = %r in %s seconds" % (signalled, t2 - t1))
            assert signalled != []
            assert t2 - t1 > 2.99
