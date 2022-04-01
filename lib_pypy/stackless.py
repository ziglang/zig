"""
The Stackless module allows you to do multitasking without using threads.
The essential objects are tasklets and channels.
Please refer to their documentation.
"""


import _continuation

class TaskletExit(Exception):
    pass

CoroutineExit = TaskletExit


def _coroutine_getcurrent():
    "Returns the current coroutine (i.e. the one which called this function)."
    try:
        return _tls.current_coroutine
    except AttributeError:
        # first call in this thread: current == main
        return _coroutine_getmain()

def _coroutine_getmain():
    try:
        return _tls.main_coroutine
    except AttributeError:
        # create the main coroutine for this thread
        continulet = _continuation.continulet
        main = coroutine()
        main._frame = continulet.__new__(continulet)
        main._is_started = -1
        _tls.current_coroutine = _tls.main_coroutine = main
        return _tls.main_coroutine


class coroutine(object):
    _is_started = 0      # 0=no, 1=yes, -1=main

    def __init__(self):
        self._frame = None

    def bind(self, func, *argl, **argd):
        """coro.bind(f, *argl, **argd) -> None.
           binds function f to coro. f will be called with
           arguments *argl, **argd
        """
        if self.is_alive:
            raise ValueError("cannot bind a bound coroutine")
        def run(c):
            _tls.current_coroutine = self
            self._is_started = 1
            return func(*argl, **argd)
        self._is_started = 0
        self._frame = _continuation.continulet(run)

    def switch(self):
        """coro.switch() -> returnvalue
           switches to coroutine coro. If the bound function
           f finishes, the returnvalue is that of f, otherwise
           None is returned
        """
        current = _coroutine_getcurrent()
        try:
            current._frame.switch(to=self._frame)
        finally:
            _tls.current_coroutine = current

    def kill(self):
        """coro.kill() : kill coroutine coro"""
        current = _coroutine_getcurrent()
        try:
            current._frame.throw(CoroutineExit, to=self._frame)
        finally:
            _tls.current_coroutine = current

    @property
    def is_alive(self):
        return self._is_started < 0 or (
            self._frame is not None and self._frame.is_pending())

    @property
    def is_zombie(self):
        return self._is_started > 0 and not self._frame.is_pending()

    getcurrent = staticmethod(_coroutine_getcurrent)

    def __reduce__(self):
        if self._is_started < 0:
            return _coroutine_getmain, ()
        else:
            return type(self), (), self.__dict__


try:
    from threading import local as _local
except ImportError:
    class _local(object):    # assume no threads
        pass

_tls = _local()


# ____________________________________________________________


from collections import deque

import operator
__all__ = 'run getcurrent getmain schedule tasklet channel coroutine'.split()

_global_task_id = 0
_squeue = None
_main_tasklet = None
_main_coroutine = None
_last_task = None
_channel_callback = None
_schedule_callback = None

def _scheduler_remove(value):
    try:
        del _squeue[operator.indexOf(_squeue, value)]
    except ValueError:
        pass

def _scheduler_append(value, normal=True):
    if normal:
        _squeue.append(value)
    else:
        _squeue.rotate(-1)
        _squeue.appendleft(value)
        _squeue.rotate(1)

def _scheduler_contains(value):
    try:
        operator.indexOf(_squeue, value)
        return True
    except ValueError:
        return False

def _scheduler_switch(current, next):
    global _last_task
    prev = _last_task
    if (_schedule_callback is not None and
        prev is not next):
        _schedule_callback(prev, next)
    _last_task = next
    assert not next.blocked
    if next is not current:
        next.switch()
    return current

def set_schedule_callback(callback):
    global _schedule_callback
    _schedule_callback = callback

def set_channel_callback(callback):
    global _channel_callback
    _channel_callback = callback

def getruncount():
    return len(_squeue)

class bomb(object):
    def __init__(self, exp_type=None, exp_value=None, exp_traceback=None):
        self.type = exp_type
        self.value = exp_value
        self.traceback = exp_traceback

    def raise_(self):
        raise self.type(self.value).with_traceback(self.traceback)

#
#

class channel(object):
    """
    A channel object is used for communication between tasklets.
    By sending on a channel, a tasklet that is waiting to receive
    is resumed. If there is no waiting receiver, the sender is suspended.
    By receiving from a channel, a tasklet that is waiting to send
    is resumed. If there is no waiting sender, the receiver is suspended.

    Attributes:

    preference
    ----------
    -1: prefer receiver
     0: don't prefer anything
     1: prefer sender

    Pseudocode that shows in what situation a schedule happens:

    def send(arg):
        if !receiver:
            schedule()
        elif schedule_all:
            schedule()
        else:
            if (prefer receiver):
                schedule()
            else (don't prefer anything, prefer sender):
                pass

        NOW THE INTERESTING STUFF HAPPENS

    def receive():
        if !sender:
            schedule()
        elif schedule_all:
            schedule()
        else:
            if (prefer sender):
                schedule()
            else (don't prefer anything, prefer receiver):
                pass

        NOW THE INTERESTING STUFF HAPPENS

    schedule_all
    ------------
    True: overwrite preference. This means that the current tasklet always
          schedules before returning from send/receive (it always blocks).
          (see Stackless/module/channelobject.c)
    """

    def __init__(self, label=''):
        self.balance = 0
        self.closing = False
        self.queue = deque()
        self.label = label
        self.preference = -1
        self.schedule_all = False

    def __str__(self):
        return 'channel[%s](%s,%s)' % (self.label, self.balance, self.queue)

    def close(self):
        """
        channel.close() -- stops the channel from enlarging its queue.
        
        If the channel is not empty, the flag 'closing' becomes true.
        If the channel is empty, the flag 'closed' becomes true.
        """
        self.closing = True

    @property
    def closed(self):
        return self.closing and not self.queue

    def open(self):
        """
        channel.open() -- reopen a channel. See channel.close.
        """
        self.closing = False

    def _channel_action(self, arg, d):
        """
        d == -1 : receive
        d ==  1 : send

        the original CStackless has an argument 'stackl' which is not used
        here.

        'target' is the peer tasklet to the current one
        """
        do_schedule=False
        assert abs(d) == 1
        source = getcurrent()
        source.tempval = arg
        while True:
            if d > 0:
                cando = self.balance < 0
                dir = d
            else:
                cando = self.balance > 0
                dir = 0

            if cando and self.queue[0]._tasklet_killed:
                # issue #2595: the tasklet was killed while waiting.
                # drop that tasklet from consideration and try again.
                self.balance += d
                self.queue.popleft()
            else:
                # normal path
                break

        if _channel_callback is not None:
            _channel_callback(self, source, dir, not cando)
        self.balance += d
        if cando:
            # communication 1): there is somebody waiting
            target = self.queue.popleft()
            source.tempval, target.tempval = target.tempval, source.tempval
            target.blocked = 0
            if self.schedule_all:
                # always schedule 
                _scheduler_append(target)
                do_schedule = True
            elif self.preference == -d:
                _scheduler_append(target, False)
                do_schedule = True
            else:
                _scheduler_append(target)
        else:
            # communication 2): there is nobody waiting
#            if source.block_trap:
#                raise RuntimeError("this tasklet does not like to be blocked")
#            if self.closing:
#                raise StopIteration()
            source.blocked = d
            self.queue.append(source)
            _scheduler_remove(getcurrent())
            do_schedule = True

        if do_schedule:
            schedule()

        retval = source.tempval
        if isinstance(retval, bomb):
            retval.raise_()
        return retval

    def receive(self):
        """
        channel.receive() -- receive a value over the channel.
        If no other tasklet is already sending on the channel,
        the receiver will be blocked. Otherwise, the receiver will
        continue immediately, and the sender is put at the end of
        the runnables list.
        The above policy can be changed by setting channel flags.
        """
        return self._channel_action(None, -1)

    def send_exception(self, exp_type, msg):
        self.send(bomb(exp_type, exp_type(msg)))

    def send_sequence(self, iterable):
        for item in iterable:
            self.send(item)

    def send(self, msg):
        """
        channel.send(value) -- send a value over the channel.
        If no other tasklet is already receiving on the channel,
        the sender will be blocked. Otherwise, the receiver will
        be activated immediately, and the sender is put at the end of
        the runnables list.
        """
        return self._channel_action(msg, 1)


class tasklet(coroutine):
    """
    A tasklet object represents a tiny task in a Python thread.
    At program start, there is always one running main tasklet.
    New tasklets can be created with methods from the stackless
    module.
    """
    tempval = None
    _tasklet_killed = False

    def __new__(cls, func=None, label=''):
        res = coroutine.__new__(cls)
        res.label = label
        res._task_id = None
        return res

    def __init__(self, func=None, label=''):
        coroutine.__init__(self)
        self._init(func, label)

    def _init(self, func=None, label=''):
        global _global_task_id
        self.func = func
        self.alive = False
        self.blocked = False
        self._task_id = _global_task_id
        self.label = label
        _global_task_id += 1

    def __str__(self):
        return '<tasklet[%s, %s]>' % (self.label,self._task_id)

    __repr__ = __str__

    def __call__(self, *argl, **argd):
        return self.setup(*argl, **argd)

    def bind(self, func):
        """
        Binding a tasklet to a callable object.
        The callable is usually passed in to the constructor.
        In some cases, it makes sense to be able to re-bind a tasklet,
        after it has been run, in order to keep its identity.
        Note that a tasklet can only be bound when it doesn't have a frame.
        """
        if not callable(func):
            raise TypeError('tasklet function must be a callable')
        self.func = func

    def kill(self):
        """
        tasklet.kill -- raise a TaskletExit exception for the tasklet.
        Note that this is a regular exception that can be caught.
        The tasklet is immediately activated.
        If the exception passes the toplevel frame of the tasklet,
        the tasklet will silently die.
        """
        self._tasklet_killed = True
        if not self.is_zombie:
            # Killing the tasklet by throwing TaskletExit exception.
            coroutine.kill(self)
            _scheduler_remove(self)
            self.alive = False

    def setup(self, *argl, **argd):
        """
        supply the parameters for the callable
        """
        if self.func is None:
            raise TypeError('cframe function must be callable')
        func = self.func
        def _func():
            try:
                try:
                    coroutine.switch(back)
                    func(*argl, **argd)
                except TaskletExit:
                    pass
            finally:
                _scheduler_remove(self)
                self.alive = False

        self.func = None
        coroutine.bind(self, _func)
        back = _coroutine_getcurrent()
        coroutine.switch(self)
        self.alive = True
        _scheduler_append(self)
        return self

    def run(self):
        self.insert()
        _scheduler_switch(getcurrent(), self)

    def insert(self):
        if self.blocked:
            raise RuntimeError("You cannot run a blocked tasklet")
        if not self.alive:
            raise RuntimeError("You cannot run an unbound(dead) tasklet")
        _scheduler_append(self)

    def remove(self):
        if self.blocked:
            raise RuntimeError("You cannot remove a blocked tasklet.")
        if self is getcurrent():
            raise RuntimeError("The current tasklet cannot be removed.")
            # not sure if I will revive this  " Use t=tasklet().capture()"
        _scheduler_remove(self)

def getmain():
    """
    getmain() -- return the main tasklet.
    """
    return _main_tasklet

def getcurrent():
    """
    getcurrent() -- return the currently executing tasklet.
    """

    curr = coroutine.getcurrent()
    if curr is _main_coroutine:
        return _main_tasklet
    else:
        return curr

_run_calls = []
def run():
    """
    run_watchdog(timeout) -- run tasklets until they are all
    done, or timeout instructions have passed. Tasklets must
    provide cooperative schedule() calls.
    If the timeout is met, the function returns.
    The calling tasklet is put aside while the tasklets are running.
    It is inserted back after the function stops, right before the
    tasklet that caused a timeout, if any.
    If an exception occours, it will be passed to the main tasklet.

    Please note that the 'timeout' feature is not yet implemented
    """
    curr = getcurrent()
    _run_calls.append(curr)
    _scheduler_remove(curr)
    try:
        schedule()
        assert not _squeue
    finally:
        _scheduler_append(curr)
    
def schedule_remove(retval=None):
    """
    schedule(retval=stackless.current) -- switch to the next runnable tasklet.
    The return value for this call is retval, with the current
    tasklet as default.
    schedule_remove(retval=stackless.current) -- ditto, and remove self.
    """
    _scheduler_remove(getcurrent())
    r = schedule(retval)
    return r


def schedule(retval=None):
    """
    schedule(retval=stackless.current) -- switch to the next runnable tasklet.
    The return value for this call is retval, with the current
    tasklet as default.
    schedule_remove(retval=stackless.current) -- ditto, and remove self.
    """
    mtask = getmain()
    curr = getcurrent()
    if retval is None:
        retval = curr
    while True:
        if _squeue:
            if _squeue[0] is curr:
                # If the current is at the head, skip it.
                _squeue.rotate(-1)
                
            task = _squeue[0]
            #_squeue.rotate(-1)
        elif _run_calls:
            task = _run_calls.pop()
        else:
            raise RuntimeError('No runnable tasklets left.')
        _scheduler_switch(curr, task)
        if curr is _last_task:
            # We are in the tasklet we want to resume at this point.
            return retval

def _init():
    global _main_tasklet
    global _global_task_id
    global _squeue
    global _last_task
    _global_task_id = 0
    _main_tasklet = coroutine.getcurrent()
    _main_tasklet.__class__ = tasklet         # XXX HAAAAAAAAAAAAAAAAAAAAACK
    _last_task = _main_tasklet
    tasklet._init(_main_tasklet, label='main')
    _squeue = deque()
    _scheduler_append(_main_tasklet)

_init()
