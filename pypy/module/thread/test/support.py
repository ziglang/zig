import gc
import time
import thread
import os
import errno

from pypy.interpreter.gateway import interp2app, unwrap_spec
from rpython.rlib import rgil


NORMAL_TIMEOUT = 300.0   # 5 minutes


def waitfor(space, w_condition, delay=1):
    adaptivedelay = 0.04
    limit = time.time() + delay * NORMAL_TIMEOUT
    while time.time() <= limit:
        rgil.release()
        time.sleep(adaptivedelay)
        rgil.acquire()
        gc.collect()
        if space.is_true(space.call_function(w_condition)):
            return
        adaptivedelay *= 1.05
    print '*** timed out ***'


def timeout_killer(cls, pid, delay):
    def kill():
        for x in range(delay * 10):
            time.sleep(0.1)
            try:
                os.kill(pid, 0)
            except OSError as e:
                if e.errno == errno.ESRCH: # no such process
                    return
                raise
        os.kill(pid, 9)
        print("process %s killed!" % (pid,))
    import threading
    threading.Thread(target=kill).start()


class GenericTestThread:
    spaceconfig = dict(usemodules=('thread', 'time', 'signal'))

    def setup_class(cls):
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)
        if cls.runappdirect:
            cls.w_NORMAL_TIMEOUT = NORMAL_TIMEOUT
            def plain_waitfor(cls, condition, delay=1):
                import gc
                import time
                adaptivedelay = 0.04
                limit = time.time() + cls.NORMAL_TIMEOUT * delay
                while time.time() <= limit:
                    time.sleep(adaptivedelay)
                    gc.collect()
                    if condition():
                        return
                    adaptivedelay *= 1.05
                print('*** timed out ***')
            cls.w_waitfor = plain_waitfor

            cls.w_timeout_killer = timeout_killer
        else:
            @unwrap_spec(delay=int)
            def py_waitfor(space, w_condition, delay=1):
                waitfor(space, w_condition, delay)
            cls.w_waitfor = cls.space.wrap(interp2app(py_waitfor))

            def py_timeout_killer(space, __args__):
                args_w, kwargs_w = __args__.unpack()
                args = map(space.unwrap, args_w)
                kwargs = dict([
                    (k, space.unwrap(v))
                    for k, v in kwargs_w.iteritems()
                ])
                timeout_killer(cls, *args, **kwargs)
            cls.w_timeout_killer = cls.space.wrap(interp2app(py_timeout_killer))

        cls.w_busywait = cls.space.appexec([], """():
            import time
            return time.sleep
        """)
