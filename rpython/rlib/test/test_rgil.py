from rpython.rlib import rgil
from rpython.rlib.debug import debug_print
from rpython.translator.c.test.test_standalone import StandaloneTests
from rpython.config.translationoption import get_combined_translation_config


class BaseTestGIL(StandaloneTests):

    def test_simple(self):
        def main(argv):
            rgil.release()
            # don't have the GIL here
            rgil.acquire()
            rgil.yield_thread()
            print "OK"   # there is also a release/acquire pair here
            return 0

        main([])

        t, cbuilder = self.compile(main)
        data = cbuilder.cmdexec('')
        assert data == "OK\n"

    def test_after_thread_switch(self):
        class Foo:
            pass
        foo = Foo()
        foo.counter = 0
        def seeme():
            foo.counter += 1
        def main(argv):
            rgil.invoke_after_thread_switch(seeme)
            print "Test"     # one release/acquire pair here
            print foo.counter
            print foo.counter
            return 0

        t, cbuilder = self.compile(main)
        data = cbuilder.cmdexec('')
        assert data == "Test\n1\n2\n"

    def test_am_I_holding_the_GIL(self):
        def check(name, expected=True):
            # we may not have the GIL here, don't use "print"
            debug_print(name)
            if rgil.am_I_holding_the_GIL() != expected:
                debug_print('assert failed at point', name)
                debug_print('rgil.gil_get_holder() ==', rgil.gil_get_holder())
                assert False

        def main(argv):
            check('1')
            rgil.release()
            # don't have the GIL here
            check('2', False)
            rgil.acquire()
            check('3')
            rgil.yield_thread()
            check('4')
            print "OK"   # there is also a release/acquire pair here
            check('5')
            return 0

        main([])

        t, cbuilder = self.compile(main)
        data = cbuilder.cmdexec('')
        assert data == "OK\n"

    def test_multiple_threads(self):
        import time, random
        from rpython.rlib import rthread

        def check(name, nextop, expected=True):
            # we may not have the GIL here, don't use "print"
            if rgil.am_I_holding_the_GIL() != expected:
                debug_print('assert failed at point', name, 'at', nextop)
                debug_print('rgil.gil_get_holder() ==', rgil.gil_get_holder())
                assert False

        seed = int(time.time())
        print "Random seed:", seed
        random.seed(seed)

        # This is just a complicated way of simulating random work.
        # We randomly release the GIL in various ways from 4 different threads
        # and check that at least rgil.am_I_holding_the_GIL() is sane.

        OP_YIELD = 0
        OP_RELEASE_AND_ACQUIRE = 1
        OP_BUSY = 2       # without releasing the GIL
        OP_SLEEP = 3      # time.sleep() always releases the GIL
        OPS = [OP_YIELD, OP_RELEASE_AND_ACQUIRE, OP_BUSY, OP_SLEEP]

        N_THREADS = 4
        ops_by_thread = []
        for i in range(N_THREADS):
            ops = []
            for j in range(10000):
                op = random.choice(OPS)
                ops.append(op)
                if op >= 2:
                    ops.append(random.randint(0, 1000))
            ops_by_thread.append(ops)

        class Glob:
            def __init__(self):
                self.my_locks = []
                self.n_threads = 0
        glob = Glob()

        def do_random_work():
            thread_index = glob.n_threads
            glob.n_threads += 1
            ops = ops_by_thread[thread_index]
            nextop = 0
            while nextop < len(ops):
                op = ops[nextop]
                nextop += 1
                if op == OP_YIELD:
                    rgil.yield_thread()
                    check("after yield", nextop)
                elif op == OP_RELEASE_AND_ACQUIRE:
                    rgil.release()
                    check("after release_gil", nextop, expected=False)
                    rgil.acquire()
                    check("after acquire_gil", nextop)
                else:
                    arg = ops[nextop]
                    nextop += 1
                    if op == OP_BUSY:
                        end_time = time.time() + arg * 1e-6
                        while time.time() < end_time:
                            pass
                        check("after busy work", nextop)
                    else:
                        time.sleep(arg * 1e-6)
                        check("after time.sleep()", nextop)
            finish_lock = glob.my_locks[thread_index]
            finish_lock.release()

        def main(argv):
            for j in range(N_THREADS):
                lock = rthread.allocate_lock()
                lock.acquire(True)
                glob.my_locks.append(lock)

            for j in range(N_THREADS):
                rthread.start_new_thread(do_random_work, ())

            for j in range(N_THREADS):
                glob.my_locks[j].acquire(True)

            print "OK"
            return 0

        self.config = get_combined_translation_config(
            overrides={"translation.thread": True})
        t, cbuilder = self.compile(main)
        data = cbuilder.cmdexec('')
        assert data == "OK\n"


class TestGILShadowStack(BaseTestGIL):
    gc = 'minimark'
    gcrootfinder = 'shadowstack'
