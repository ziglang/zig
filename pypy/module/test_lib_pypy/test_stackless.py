"""
These tests are supposed to run on the following platforms:
1. CStackless
2. CPython (with the stackless_new module in the path
3. pypy-c
"""
from py.test import skip
try:
    import stackless
except ImportError:
    try:
        from lib_pypy import stackless
    except ImportError as e:
        skip('cannot import stackless: %s' % (e,))

SHOW_STRANGE = False

def dprint(txt):
    if SHOW_STRANGE:
        print(txt)

class Test_Stackless:

    def test_simple(self):
        rlist = []

        def f():
            rlist.append('f')

        def g():
            rlist.append('g')
            stackless.schedule()

        def main():
            rlist.append('m')
            cg = stackless.tasklet(g)()
            cf = stackless.tasklet(f)()
            stackless.run()
            rlist.append('m')

        main()

        assert stackless.getcurrent() is stackless.getmain()
        assert rlist == 'm g f m'.split()

    def test_with_channel(self):
        pref = {}
        pref[-1] = ['s0', 'r0', 's1', 'r1', 's2', 'r2', 
                    's3', 'r3', 's4', 'r4', 's5', 'r5', 
                    's6', 'r6', 's7', 'r7', 's8', 'r8', 
                    's9', 'r9']
        pref[0] =  ['s0', 'r0', 's1', 's2', 'r1', 'r2', 
                    's3', 's4', 'r3', 'r4', 's5', 's6', 
                    'r5', 'r6', 's7', 's8', 'r7', 'r8', 
                    's9', 'r9']
        pref[1] =  ['s0', 's1', 'r0', 's2', 'r1', 's3', 
                    'r2', 's4', 'r3', 's5', 'r4', 's6', 
                    'r5', 's7', 'r6', 's8', 'r7', 's9', 
                    'r8', 'r9']
        rlist = []

        def f(outchan):
            for i in range(10):
                rlist.append('s%s' % i)
                outchan.send(i)
            outchan.send(-1)

        def g(inchan):
            while 1:
                val = inchan.receive()
                if val == -1:
                    break
                rlist.append('r%s' % val)

        for preference in [-1, 0, 1]:
            rlist = []
            ch = stackless.channel()
            ch.preference = preference
            t1 = stackless.tasklet(f)(ch)
            t2 = stackless.tasklet(g)(ch)

            stackless.run()

            assert len(rlist) == 20
            assert rlist == pref[preference]

    def test_send_counter(self):
        import random

        numbers = list(range(20))
        random.shuffle(numbers)

        def counter(n, ch):
            for i in range(n):
                stackless.schedule()
            ch.send(n)

        ch = stackless.channel()
        for each in numbers:
            stackless.tasklet(counter)(each, ch)

        stackless.run()

        rlist = []
        while ch.balance:
            rlist.append(ch.receive())

        numbers.sort()
        assert rlist == numbers

    def test_receive_counter(self):
        import random

        numbers = list(range(20))
        random.shuffle(numbers)

        rlist = []
        def counter(n, ch):
            for i in range(n):
                stackless.schedule()
            ch.receive()
            rlist.append(n)

        ch = stackless.channel()
        for each in numbers:
            stackless.tasklet(counter)(each, ch)

        stackless.run()

        while ch.balance:
            ch.send(None)

        numbers.sort()
        assert rlist == numbers

    def test_scheduling_cleanup(self):
        rlist = []
        def f():
            rlist.append('fb')
            stackless.schedule()
            rlist.append('fa')

        def g():
            rlist.append('gb')
            stackless.schedule()
            rlist.append('ga')

        def h():
            rlist.append('hb')
            stackless.schedule()
            rlist.append('ha')

        tf = stackless.tasklet(f)()
        tg = stackless.tasklet(g)()
        th = stackless.tasklet(h)()

        rlist.append('mb')
        stackless.run()
        rlist.append('ma')

        assert rlist == 'mb fb gb hb fa ga ha ma'.split()

    def test_except(self):
        rlist = []
        def f():
            rlist.append('f')
            return 1/0

        def g():
            rlist.append('bg')
            stackless.schedule()
            rlist.append('ag')

        def h():
            rlist.append('bh')
            stackless.schedule()
            rlist.append('ah')

        tg = stackless.tasklet(g)()
        tf = stackless.tasklet(f)()
        th = stackless.tasklet(h)()

        try:
            stackless.run()
        # cheating, can't test for ZeroDivisionError
        except Exception as e:
            rlist.append('E')
        stackless.schedule()
        stackless.schedule()

        assert rlist == "bg f E bh ag ah".split()

    def test_except_full(self):
        rlist = []
        def f():
            rlist.append('f')
            return 1/0

        def g():
            rlist.append('bg')
            stackless.schedule()
            rlist.append('ag')

        def h():
            rlist.append('bh')
            stackless.schedule()
            rlist.append('ah')

        tg = stackless.tasklet(g)()
        tf = stackless.tasklet(f)()
        th = stackless.tasklet(h)()

        try:
            stackless.run()
        except ZeroDivisionError:
            rlist.append('E')
        stackless.schedule()
        stackless.schedule()

        assert rlist == "bg f E bh ag ah".split()

    def test_kill(self):
        def f():pass
        t =  stackless.tasklet(f)()
        t.kill()
        assert not t.alive

    def test_catch_taskletexit(self):
        # Tests if TaskletExit can be caught in the tasklet being killed.
        global taskletexit
        taskletexit = False
        
        def f():
            try:
                stackless.schedule()
            except TaskletExit:
                global TaskletExit
                taskletexit = True
                raise
            
            t =  stackless.tasklet(f)()
            t.run()
            assert t.alive
            t.kill()
            assert not t.alive
            assert taskletexit
            
    def test_autocatch_taskletexit(self):
        # Tests if TaskletExit is caught correctly in stackless.tasklet.setup(). 
        def f():
            stackless.schedule()
        
        t = stackless.tasklet(f)()
        t.run()
        t.kill()


    # tests inspired from simple stackless.com examples

    def test_construction(self):
        output = []
        def print_(*args):
            output.append(args)

        def aCallable(value):
            print_("aCallable:", value)

        task = stackless.tasklet(aCallable)
        task.setup('Inline using setup')

        stackless.run()
        assert output == [("aCallable:", 'Inline using setup')]


        del output[:]
        task = stackless.tasklet(aCallable)
        task('Inline using ()')

        stackless.run()
        assert output == [("aCallable:", 'Inline using ()')]
        
        del output[:]
        task = stackless.tasklet()
        task.bind(aCallable)
        task('Bind using ()')

        stackless.run()
        assert output == [("aCallable:", 'Bind using ()')]

    def test_simple_channel(self):
        output = []
        def print_(*args):
            output.append(args)
            
        def Sending(channel):
            print_("sending")
            channel.send("foo")

        def Receiving(channel):
            print_("receiving")
            print_(channel.receive())

        ch=stackless.channel()

        task=stackless.tasklet(Sending)(ch)

        # Note: the argument, schedule is taking is the value,
        # schedule returns, not the task that runs next

        #stackless.schedule(task)
        stackless.schedule()
        task2=stackless.tasklet(Receiving)(ch)
        #stackless.schedule(task2)
        stackless.schedule()

        stackless.run()

        assert output == [('sending',), ('receiving',), ('foo',)]

    def test_balance_zero(self):
        ch=stackless.channel()
        assert ch.balance == 0
        
    def test_balance_send(self):
        def Sending(channel):
            channel.send("foo")

        ch=stackless.channel()

        task=stackless.tasklet(Sending)(ch)
        stackless.run()

        assert ch.balance == 1

    def test_balance_recv(self):
        def Receiving(channel):
            channel.receive()

        ch=stackless.channel()

        task=stackless.tasklet(Receiving)(ch)
        stackless.run()

        assert ch.balance == -1

    def test_run(self):
        output = []
        def print_(*args):
            output.append(args)

        def f(i):
            print_(i)

        stackless.tasklet(f)(1)
        stackless.tasklet(f)(2)
        stackless.run()

        assert output == [(1,), (2,)]

    def test_schedule(self):
        output = []
        def print_(*args):
            output.append(args)

        def f(i):
            print_(i)

        stackless.tasklet(f)(1)
        stackless.tasklet(f)(2)
        stackless.schedule()

        assert output == [(1,), (2,)]


    def test_cooperative(self):
        output = []
        def print_(*args):
            output.append(args)

        def Loop(i):
            for x in range(3):
                stackless.schedule()
                print_("schedule", i)

        stackless.tasklet(Loop)(1)
        stackless.tasklet(Loop)(2)
        stackless.run()

        assert output == [('schedule', 1), ('schedule', 2),
                          ('schedule', 1), ('schedule', 2),
                          ('schedule', 1), ('schedule', 2),]

    def test_channel_callback(self):
        res = []
        cb = []
        def callback_function(chan, task, sending, willblock):
            cb.append((chan, task, sending, willblock))
        stackless.set_channel_callback(callback_function)
        def f(chan):
            chan.send('hello')
            val = chan.receive()
            res.append(val)

        chan = stackless.channel()
        task = stackless.tasklet(f)(chan)
        val = chan.receive()
        res.append(val)
        chan.send('world')
        assert res == ['hello','world']
        maintask = stackless.getmain()
        assert cb == [
            (chan, maintask, 0, 1), 
            (chan, task, 1, 0), 
            (chan, maintask, 1, 1), 
            (chan, task, 0, 0)
        ]

    def test_schedule_callback(self):
        res = []
        cb = []
        def schedule_cb(prev, next):
            cb.append((prev, next))

        stackless.set_schedule_callback(schedule_cb)
        def f(i):
            res.append('A_%s' % i)
            stackless.schedule()
            res.append('B_%s' % i)

        t1 = stackless.tasklet(f)(1)
        t2 = stackless.tasklet(f)(2)
        maintask = stackless.getmain()
        stackless.run()
        assert res == ['A_1', 'A_2', 'B_1', 'B_2']
        assert len(cb) == 5
        assert cb[0] == (maintask, t1)
        assert cb[1] == (t1, t2)
        assert cb[2] == (t2, t1)
        assert cb[3] == (t1, t2)
        assert cb[4] == (t2, maintask)

    def test_bomb(self):
        try:
            1/0
        except:
            import sys
            b = stackless.bomb(*sys.exc_info())
        assert b.type is ZeroDivisionError
        assert str(b.value).startswith('integer division')
        assert b.traceback is not None

    def test_send_exception(self):
        def exp_sender(chan):
            chan.send_exception(Exception, 'test')

        def exp_recv(chan):
            try:
                val = chan.receive()
            except Exception as exp:
                assert exp.__class__ is Exception
                assert str(exp) == 'test'

        chan = stackless.channel()
        t1 = stackless.tasklet(exp_recv)(chan)
        t2 = stackless.tasklet(exp_sender)(chan)
        stackless.run()

    def test_send_sequence(self):
        res = []
        lst = [1,2,3,4,5,6,None]
        iterable = iter(lst)
        chan = stackless.channel()
        def f(chan):
            r = chan.receive()
            while r:
                res.append(r)
                r = chan.receive()

        t = stackless.tasklet(f)(chan)
        chan.send_sequence(iterable)
        assert res == [1,2,3,4,5,6]

    def test_getruncount(self):
        assert stackless.getruncount() == 1
        def with_schedule():
            assert stackless.getruncount() == 2

        t1 = stackless.tasklet(with_schedule)()
        assert stackless.getruncount() == 2
        stackless.schedule()
        def with_run():
            assert stackless.getruncount() == 1

        t2 = stackless.tasklet(with_run)()
        stackless.run()

    def test_schedule_return(self):
        def f():pass
        t1= stackless.tasklet(f)()
        r = stackless.schedule()
        assert r is stackless.getmain()
        t2 = stackless.tasklet(f)()
        r = stackless.schedule('test')
        assert r == 'test'

    def test_simple_pipe(self):
        def pipe(X_in, X_out):
            foo = X_in.receive()
            X_out.send(foo)

        X, Y = stackless.channel(), stackless.channel()
        t = stackless.tasklet(pipe)(X, Y)
        stackless.run()
        X.send(42)
        assert Y.receive() == 42

    def test_nested_pipe(self):
        dprint('tnp ==== 1')
        def pipe(X, Y):
            dprint('tnp_P ==== 1')
            foo = X.receive()
            dprint('tnp_P ==== 2')
            Y.send(foo)
            dprint('tnp_P ==== 3')

        def nest(X, Y):
            X2, Y2 = stackless.channel(), stackless.channel()
            t = stackless.tasklet(pipe)(X2, Y2)
            dprint('tnp_N ==== 1')
            X_Val = X.receive()
            dprint('tnp_N ==== 2')
            X2.send(X_Val)
            dprint('tnp_N ==== 3')
            Y2_Val = Y2.receive() 
            dprint('tnp_N ==== 4')
            Y.send(Y2_Val)
            dprint('tnp_N ==== 5')

        X, Y = stackless.channel(), stackless.channel()
        t1 = stackless.tasklet(nest)(X, Y)
        X.send(13)
        dprint('tnp ==== 2')
        res = Y.receive() 
        dprint('tnp ==== 3')
        assert res == 13
        if SHOW_STRANGE:
            raise Exception('force prints')

    def test_wait_two(self):
        """
        A tasklets/channels adaptation of the test_wait_two from the
        logic object space
        """
        def sleep(X, Y):
            dprint('twt_S ==== 1')
            value = X.receive()
            dprint('twt_S ==== 2')
            Y.send((X, value))
            dprint('twt_S ==== 3')

        def wait_two(X, Y, Ret_chan):
            Barrier = stackless.channel()
            stackless.tasklet(sleep)(X, Barrier)
            stackless.tasklet(sleep)(Y, Barrier)
            dprint('twt_W ==== 1')
            ret = Barrier.receive()
            dprint('twt_W ==== 2')
            if ret[0] == X:
                Ret_chan.send((1, ret[1]))
            else:
                Ret_chan.send((2, ret[1]))
            dprint('twt_W ==== 3')

        X = stackless.channel()
        Y = stackless.channel()
        Ret_chan = stackless.channel()

        stackless.tasklet(wait_two)(X, Y, Ret_chan)

        dprint('twt ==== 1')
        Y.send(42)

        dprint('twt ==== 2')
        X.send(42)
        dprint('twt ==== 3')
        value = Ret_chan.receive() 
        dprint('twt ==== 4')
        assert value == (2, 42)
        

    def test_schedule_return_value(self):

        def task(val):
            value = stackless.schedule(val)
            assert value == val

        stackless.tasklet(task)(10)
        stackless.tasklet(task)(5)

        stackless.run()

    def test_kill_tasklet_waiting_for_channel(self):
        # issue #2595
        c = stackless.channel()
        def sender():
            c.send(1)
        def receiver():
            v = c.receive()
        def killer(tl):
            tl.kill()
        def main():
            trk = stackless.tasklet(receiver)()
            stackless.schedule()
            killer(trk)
            stackless.schedule()
            stackless.tasklet(sender)()
            stackless.schedule()
            stackless.tasklet(receiver)()
            stackless.schedule()
        stackless.tasklet(main)()
        stackless.run()
