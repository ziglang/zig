import gc, sys
import py
import platform
from rpython.rtyper.tool.rffi_platform import CompilationError
try:
    from rpython.rlib import rstacklet
except CompilationError as e:
    py.test.skip("cannot import rstacklet: %s" % e)

from rpython.config.translationoption import DEFL_ROOTFINDER_WITHJIT
from rpython.rlib import rrandom, rgc
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.nonconst import NonConstant
from rpython.rlib import rvmprof
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.translator.c.test.test_standalone import StandaloneTests



class Runner:
    STATUSMAX = 5000

    def init(self, seed):
        self.sthread = rstacklet.StackletThread()
        self.random = rrandom.Random(seed)

    def done(self):
        self.sthread = None
        gc.collect(); gc.collect(); gc.collect()

    TESTS = []
    def here_is_a_test(fn, TESTS=TESTS):
        TESTS.append((fn.__name__, fn))
        return fn

    @here_is_a_test
    def test_new(self):
        print 'start'
        h = self.sthread.new(empty_callback, rffi.cast(llmemory.Address, 123))
        print 'end', h
        assert self.sthread.is_empty_handle(h)

    def nextstatus(self, nextvalue):
        print 'expected nextvalue to be %d, got %d' % (nextvalue,
                                                       self.status + 1)
        assert self.status + 1 == nextvalue
        self.status = nextvalue

    @here_is_a_test
    def test_simple_switch(self):
        self.status = 0
        h = self.sthread.new(switchbackonce_callback,
                             rffi.cast(llmemory.Address, 321))
        assert not self.sthread.is_empty_handle(h)
        self.nextstatus(2)
        h = self.sthread.switch(h)
        self.nextstatus(4)
        print 'end', h
        assert self.sthread.is_empty_handle(h)

    @here_is_a_test
    def test_various_depths(self):
        self.tasks = [Task(i) for i in range(10)]
        self.nextstep = -1
        self.comefrom = -1
        self.status = 0
        while self.status < self.STATUSMAX or self.any_alive():
            self.tasks[0].withdepth(self.random.genrand32() % 50)
            assert len(self.tasks[0].lst) == 0

    @here_is_a_test
    def test_destroy(self):
        # this used to give MemoryError in shadowstack tests
        for i in range(100000):
            self.status = 0
            h = self.sthread.new(switchbackonce_callback,
                                 rffi.cast(llmemory.Address, 321))
            # 'h' ignored
            if (i % 2000) == 1000:
                rgc.collect()  # This should run in < 1.5GB virtual memory

    def any_alive(self):
        for task in self.tasks:
            if task.h:
                return True
        return False

    @here_is_a_test
    def test_c_callback(self):
        #
        self.steps = [0]
        self.main_h = self.sthread.new(cb_stacklet_callback, llmemory.NULL)
        self.steps.append(2)
        call_qsort_rec(10)
        self.steps.append(9)
        assert not self.sthread.is_empty_handle(self.main_h)
        self.main_h = self.sthread.switch(self.main_h)
        assert self.sthread.is_empty_handle(self.main_h)
        #
        # check that self.steps == [0,1,2, 3,4,5,6, 3,4,5,6, 3,4,5,6,..., 9]
        print self.steps
        expected = 0
        assert self.steps[-1] == 9
        for i in range(len(self.steps)-1):
            if expected == 7:
                expected = 3
            assert self.steps[i] == expected
            expected += 1
        assert expected == 7


class FooObj:
    def __init__(self, n, d, next=None):
        self.n = n
        self.d = d
        self.next = next


class Task:
    def __init__(self, n):
        self.n = n
        self.h = runner.sthread.get_null_handle()
        self.lst = []

    def withdepth(self, d):
        if d > 0:
            foo = FooObj(self.n, d)
            foo2 = FooObj(self.n + 100, d, foo)
            self.lst.append(foo)
            res = self.withdepth(d-1)
            foo = self.lst.pop()
            assert foo2.n == self.n + 100
            assert foo2.d == d
            assert foo2.next is foo
            assert foo.n == self.n
            assert foo.d == d
            assert foo.next is None
        else:
            res = 0
            n = intmask(runner.random.genrand32() % 10)
            if n == self.n or (runner.status >= runner.STATUSMAX and
                               not runner.tasks[n].h):
                return 1

            print "status == %d, self.n = %d" % (runner.status, self.n)
            assert not self.h
            assert runner.nextstep == -1
            runner.status += 1
            runner.nextstep = runner.status
            runner.comefrom = self.n
            runner.gointo = n
            task = runner.tasks[n]
            if not task.h:
                # start a new stacklet
                print "NEW", n
                h = runner.sthread.new(variousstackdepths_callback,
                                       rffi.cast(llmemory.Address, n))
            else:
                # switch to this stacklet
                print "switch to", n
                h = task.h
                task.h = runner.sthread.get_null_handle()
                h = runner.sthread.switch(h)

            print "back in self.n = %d, coming from %d" % (self.n,
                                                           runner.comefrom)
            assert runner.nextstep == runner.status
            runner.nextstep = -1
            assert runner.gointo == self.n
            assert runner.comefrom != self.n
            assert not self.h
            if runner.comefrom != -42:
                assert 0 <= runner.comefrom < 10
                task = runner.tasks[runner.comefrom]
                assert not task.h
                task.h = h
            else:
                assert runner.sthread.is_empty_handle(h)
            runner.comefrom = -1
            runner.gointo = -1
        assert (res & (res-1)) == 0   # to prevent a tail-call to withdepth()
        return res


runner = Runner()


def empty_callback(h, arg):
    print 'in empty_callback:', h, arg
    assert rffi.cast(lltype.Signed, arg) == 123
    return h

def switchbackonce_callback(h, arg):
    print 'in switchbackonce_callback:', h, arg
    assert rffi.cast(lltype.Signed, arg) == 321
    runner.nextstatus(1)
    assert not runner.sthread.is_empty_handle(h)
    h = runner.sthread.switch(h)
    runner.nextstatus(3)
    assert not runner.sthread.is_empty_handle(h)
    return h

def variousstackdepths_callback(h, arg):
    assert runner.nextstep == runner.status
    runner.nextstep = -1
    arg = rffi.cast(lltype.Signed, arg)
    assert arg == runner.gointo
    self = runner.tasks[arg]
    assert self.n == runner.gointo
    assert not self.h
    assert 0 <= runner.comefrom < 10
    task = runner.tasks[runner.comefrom]
    assert not task.h
    assert bool(h) and not runner.sthread.is_empty_handle(h)
    task.h = h
    runner.comefrom = -1
    runner.gointo = -1

    while self.withdepth(runner.random.genrand32() % 20) == 0:
        assert len(self.lst) == 0

    assert len(self.lst) == 0
    assert not self.h
    while 1:
        n = intmask(runner.random.genrand32() % 10)
        h = runner.tasks[n].h
        if h:
            break

    assert not runner.sthread.is_empty_handle(h)
    runner.tasks[n].h = runner.sthread.get_null_handle()
    runner.comefrom = -42
    runner.gointo = n
    assert runner.nextstep == -1
    runner.status += 1
    runner.nextstep = runner.status
    print "LEAVING %d to go to %d" % (self.n, n)
    return h

QSORT_CALLBACK_PTR = lltype.Ptr(lltype.FuncType(
    [llmemory.Address, llmemory.Address], rffi.INT))
qsort = rffi.llexternal('qsort',
                        [llmemory.Address, rffi.SIZE_T, rffi.SIZE_T,
                         QSORT_CALLBACK_PTR],
                        lltype.Void)
def cb_compare_callback(a, b):
    runner.steps.append(3)
    assert not runner.sthread.is_empty_handle(runner.main_h)
    runner.main_h = runner.sthread.switch(runner.main_h)
    assert not runner.sthread.is_empty_handle(runner.main_h)
    runner.steps.append(6)
    return rffi.cast(rffi.INT, 1)
def cb_stacklet_callback(h, arg):
    runner.steps.append(1)
    while True:
        assert not runner.sthread.is_empty_handle(h)
        h = runner.sthread.switch(h)
        assert not runner.sthread.is_empty_handle(h)
        if runner.steps[-1] == 9:
            return h
        runner.steps.append(4)
        rgc.collect()
        runner.steps.append(5)
class GcObject(object):
    num = 1234
def call_qsort_rec(r):
    if r > 0:
        g = GcObject()
        g.num += r
        call_qsort_rec(r - 1)
        assert g.num == 1234 + r
    else:
        raw = llmemory.raw_malloc(5)
        qsort(raw, 5, 1, cb_compare_callback)
        llmemory.raw_free(raw)


# <vmprof-hack>
# bah, we need to make sure that vmprof_execute_code is annotated, else
# rvmprof.c does not compile correctly
class FakeVMProfCode(object):
    pass
rvmprof.register_code_object_class(FakeVMProfCode, lambda code: 'name')
@rvmprof.vmprof_execute_code("xcode1", lambda code, num: code)
def fake_vmprof_main(code, num):
    return 42
# </vmprof-hack>

def entry_point(argv):
    # <vmprof-hack>
    if NonConstant(False):
        fake_vmprof_main(FakeVMProfCode(), 42)
    # </vmprof-hack>
    #
    seed = 0
    if len(argv) > 1:
        seed = int(argv[1])
    runner.init(seed)
    for name, meth in Runner.TESTS:
        print '-----', name, '-----'
        meth(runner)
    print '----- all done -----'
    runner.done()
    return 0


class BaseTestStacklet(StandaloneTests):

    def setup_class(cls):
        from rpython.config.translationoption import get_combined_translation_config
        config = get_combined_translation_config(translating=True)
        config.translation.gc = cls.gc
        if cls.gcrootfinder is not None:
            config.translation.continuation = True
            config.translation.gcrootfinder = cls.gcrootfinder
            GCROOTFINDER = cls.gcrootfinder
        cls.config = config
        cls.old_status_max = Runner.STATUSMAX
        Runner.STATUSMAX = 25000

    def teardown_class(cls):
        Runner.STATUSMAX = cls.old_status_max

    def test_demo1(self):
        t, cbuilder = self.compile(entry_point)

        for i in range(15):
            if (i & 1) == 0:
                env = {}
            else:
                env = {'PYPY_GC_NURSERY': '2k'}
            print 'running %s/%s with arg=%d and env=%r' % (
                self.gc, self.gcrootfinder, i, env)
            data = cbuilder.cmdexec('%d' % i, env=env)
            assert data.endswith("----- all done -----\n")
            for name, meth in Runner.TESTS:
                assert ('----- %s -----\n' % name) in data


class DONTTestStackletBoehm(BaseTestStacklet):
    # Boehm does not work well with stacklets, probably because the
    # moved-away copies of the stack are parsed using a different
    # selection logic than the real stack
    gc = 'boehm'
    gcrootfinder = None


class TestStackletShadowStack(BaseTestStacklet):
    gc = 'minimark'
    gcrootfinder = 'shadowstack'


def test_dont_keep_debug_to_true():
    assert not rstacklet.DEBUG


def target(*args):
    return entry_point, None

if __name__ == '__main__':
    import sys
    sys.exit(entry_point(sys.argv))
