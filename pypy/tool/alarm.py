"""
Usage:

    python alarm.py <timeout> <scriptname> <args...>

Run the given script.  If the timeout elapses, trying interrupting it by
sending KeyboardInterrupts.
"""

def _main_with_alarm(finished):
    import sys, os
    import time
    import thread


    def timeout_thread(timeout, finished):
        stderr = sys.stderr
        interrupt_main = thread.interrupt_main
        sleep = time.sleep
        now = time.time
        while now() < timeout and not finished:
            sleep(1.65123)
        if not finished:
            stderr.write("="*26 + "timedout" + "="*26 + "\n")
            while not finished:
                # send KeyboardInterrupt repeatedly until the main
                # thread dies.  Then quit (in case we are on a system
                # where exiting the main thread doesn't kill us too).
                interrupt_main()
                sleep(0.031416)


    timeout = time.time() + float(sys.argv[1])
    thread.start_new_thread(timeout_thread, (timeout, finished))
    del sys.argv[:2]
    sys.path.insert(0, os.path.dirname(sys.argv[0]))
    return sys.argv[0]

if __name__ == '__main__':
    finished = []
    try:
        execfile(_main_with_alarm(finished))
    finally:
        finished.append(True)
