import py, sys, os, signal, cStringIO, tempfile

import runner
import pypy

pytest_script = py.path.local(pypy.__file__).dirpath('test_all.py')


def test_busywait():
    class FakeProcess:
        def poll(self):
            if timers[0] >= timers[1]:
                return 42
            return None
    class FakeTime:
        def sleep(self, delay):
            timers[0] += delay
        def time(self):
            timers[2] += 1
            return 12345678.9 + timers[0]
    p = FakeProcess()
    prevtime = runner.time
    try:
        runner.time = FakeTime()
        #
        timers = [0.0, 0.0, 0]
        returncode = runner.busywait(p, 10)
        assert returncode == 42 and 0.0 <= timers[0] <= 1.0
        #
        timers = [0.0, 3.0, 0]
        returncode = runner.busywait(p, 10)
        assert returncode == 42 and 3.0 <= timers[0] <= 5.0 and timers[2] <= 10
        #
        timers = [0.0, 500.0, 0]
        returncode = runner.busywait(p, 1000)
        assert returncode == 42 and 500.0<=timers[0]<=510.0 and timers[2]<=100
        #
        timers = [0.0, 500.0, 0]
        returncode = runner.busywait(p, 100)    # get a timeout
        assert returncode == None and 100.0 <= timers[0] <= 110.0
        #
    finally:
        runner.time = prevtime

def test_should_report_failure():
    should_report_failure = runner.should_report_failure
    assert should_report_failure("")
    assert should_report_failure(". Abc\n. Def\n")
    assert should_report_failure("s Ghi\n")
    assert not should_report_failure(". Abc\nF Def\n")
    assert not should_report_failure(". Abc\nE Def\n")
    assert not should_report_failure(". Abc\nP Def\n")
    assert not should_report_failure("F Def\n. Ghi\n. Jkl\n")



class TestRunHelper(object):
    def pytest_funcarg__out(self, request):
        tmpdir = request.getfuncargvalue('tmpdir')
        return tmpdir.ensure('out')

    def test_run(self, out):
        res = runner.run([sys.executable, "-c", "print 42"], '.', out)
        assert res == 0
        assert out.read() == "42\n"

    def test_error(self, out):
        res = runner.run([sys.executable, "-c", "import sys; sys.exit(3)"], '.', out)
        assert res == 3

    def test_signal(self, out):
        if sys.platform == 'win32':
            py.test.skip("no death by signal on windows")
        res = runner.run([sys.executable, "-c", "import os; os.kill(os.getpid(), 9)"], '.', out)
        assert res == -9

    def test_timeout(self, out):
        res = runner.run([sys.executable, "-c", "while True: pass"], '.', out, timeout=3)
        assert res == -999

    def test_timeout_lock(self, out):
        res = runner.run([sys.executable, "-c", "import threading; l=threading.Lock(); l.acquire(); l.acquire()"], '.', out, timeout=3)
        assert res == -999

    def test_timeout_syscall(self, out):
        res = runner.run([sys.executable, "-c", "import socket; s=s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.bind(('', 0)); s.recv(1000)"], '.', out, timeout=3)
        assert res == -999

    def test_timeout_success(self, out):
        res = runner.run([sys.executable, "-c", "print 42"], '.',
                         out, timeout=2)
        assert res == 0
        out = out.read()
        assert out == "42\n"


class TestExecuteTest(object):

    def setup_class(cls):
        cls.real_run = (runner.run,)
        cls.called = []
        cls.exitcode = [0]

        def fake_run(args, cwd, out, timeout):
            cls.called = (args, cwd, out, timeout)
            return cls.exitcode[0]
        runner.run = fake_run

    def teardown_class(cls):
        runner.run = cls.real_run[0]

    def test_explicit(self):
        res = runner.execute_test('/wd', 'test_one', 'out', 'LOGFILE',
                                  interp=['INTERP', 'IARG'],
                                  test_driver=['driver', 'darg'],
                                  timeout='secs')

        expected = ['INTERP', 'IARG',
                    'driver', 'darg',
                    '-p', 'resultlog',
                    '--resultlog=LOGFILE',
                    #'--junitxml=LOGFILE.junit',

                    'test_one']

        assert self.called == (expected, '/wd', 'out', 'secs')
        assert res == 0

    def test_explicit_win32(self):
        res = runner.execute_test('/wd', 'test_one', 'out', 'LOGFILE',
                                  interp=['./INTERP', 'IARG'],
                                  test_driver=['driver', 'darg'],
                                  timeout='secs',
                                  _win32=True
                                  )

        expected = ['/wd' + os.sep + './INTERP', 'IARG',
                    'driver', 'darg',
                    '-p', 'resultlog',
                    '--resultlog=LOGFILE',
                    #'--junitxml=LOGFILE.junit',
                    'test_one']
        assert self.called[0] == expected
        assert self.called == (expected, '/wd', 'out', 'secs')
        assert res == 0

    def test_error(self):
        self.exitcode[:] = [1]
        res = runner.execute_test('/wd', 'test_one', 'out', 'LOGFILE',
                                  interp=['INTERP', 'IARG'],
                                  test_driver=['driver', 'darg'])
        assert res == 1


        self.exitcode[:] = [-signal.SIGSEGV]
        res = runner.execute_test('/wd', 'test_one', 'out', 'LOGFILE',
                                  interp=['INTERP', 'IARG'],
                                  test_driver=['driver', 'darg'])
        assert res == -signal.SIGSEGV

    def test_interpret_exitcode(self):
        failure, extralog = runner.interpret_exitcode(0, "test_foo")
        assert not failure
        assert extralog == ""

        failure, extralog = runner.interpret_exitcode(1, "test_foo", "")
        assert failure
        assert extralog == """! test_foo
 Exit code 1.
"""

        failure, extralog = runner.interpret_exitcode(1, "test_foo", "F Foo\n")
        assert failure
        assert extralog == "  (somefailed=True in test_foo)\n"

        failure, extralog = runner.interpret_exitcode(2, "test_foo")
        assert failure
        assert extralog == """! test_foo
 Exit code 2.
"""

        failure, extralog = runner.interpret_exitcode(-signal.SIGSEGV,
                                                      "test_foo")
        assert failure
        assert extralog == """! test_foo
 Killed by SIGSEGV.
"""

class RunnerTests(object):
    with_thread = True

    def setup_class(cls):
        cls.real_invoke_in_thread = (runner.invoke_in_thread,)
        if not cls.with_thread:
            runner.invoke_in_thread = lambda func, args: func(*args)

        cls.udir = py.path.local.make_numbered_dir(prefix='usession-runner-',
                                              keep=3)
        cls.manydir = cls.udir.join('many').ensure(dir=1)

        cls.udir.join("conftest.py").write("pytest_plugins = 'resultlog'\n")

        def fill_test_dir(test_dir, fromdir='normal'):
            for p in py.path.local(__file__).dirpath(
                'examples', fromdir).listdir("*.py"):
                p.copy(test_dir.join('test_'+p.basename))


        test_normal_dir0 = cls.manydir.join('one', 'test_normal').ensure(dir=1)
        cls.one_test_dir = cls.manydir.join('one')

        fill_test_dir(test_normal_dir0)


        test_normal_dir1 = cls.manydir.join('two', 'test_normal1').ensure(dir=1)
        test_normal_dir2 = cls.manydir.join('two', 'pkg',
                                         'test_normal2').ensure(dir=1)
        cls.two_test_dir = cls.manydir.join('two')

        fill_test_dir(test_normal_dir1)
        fill_test_dir(test_normal_dir2)

        cls.test_stall_dir = cls.udir.join('stall').ensure(dir=1)
        test_stall_dir0 = cls.test_stall_dir.join('zero').ensure(dir=1)
        fill_test_dir(test_stall_dir0, 'stall')

    def teardown_class(cls):
        runner.invoke_in_thread = cls.real_invoke_in_thread[0]

    def test_one_dir(self):
        test_driver = [pytest_script]

        log = cStringIO.StringIO()
        out = cStringIO.StringIO()

        run_param = runner.RunParam(self.one_test_dir)
        run_param.test_driver = test_driver
        run_param.parallel_runs = 3

        res = runner.execute_tests(run_param, ['test_normal'], log, out)

        assert res

        out = out.getvalue()
        assert out
        assert '\r\n' not in out
        assert '\n' in out

        log = log.getvalue()
        assert '\r\n' not in log
        assert '\n' in log
        log_lines = log.splitlines()

        assert ". test_example.py::test_one" in log_lines
        nfailures = 0
        noutcomes = 0
        for line in log_lines:
            if line[0] != ' ':
                noutcomes += 1
                if line[0] != '.':
                    nfailures += 1

        assert noutcomes == 107
        assert nfailures == 6

    def test_one_dir_dry_run(self):
        test_driver = [pytest_script]

        log = cStringIO.StringIO()
        out = cStringIO.StringIO()

        run_param = runner.RunParam(self.one_test_dir)
        run_param.test_driver = test_driver
        run_param.parallel_runs = 3
        run_param.dry_run = True

        res = runner.execute_tests(run_param, ['test_normal'], log, out)

        assert not res

        assert log.getvalue() == ""

        out_lines = out.getvalue().splitlines()

        assert len(out_lines) == 7

        assert 'starting' in out_lines[4]
        assert out_lines[6].startswith("run [")
        for line in out_lines[4:]:
            assert "test_normal" in line

    def test_many_dirs(self):
        test_driver = [pytest_script]

        log = cStringIO.StringIO()
        out = cStringIO.StringIO()

        cleanedup = []
        def cleanup(testdir):
            cleanedup.append(testdir)

        run_param = runner.RunParam(self.manydir)
        run_param.test_driver = test_driver
        run_param.parallel_runs = 3
        run_param.cleanup = cleanup

        testdirs = []
        run_param.collect_testdirs(testdirs)
        alltestdirs = testdirs[:]

        res = runner.execute_tests(run_param, testdirs, log, out)

        assert res

        assert out.getvalue()

        log_lines = log.getvalue().splitlines()

        nfailures = 0
        noutcomes = 0
        for line in log_lines:
            if line[0] != ' ':
                noutcomes += 1
                if line[0] != '.':
                    nfailures += 1

        assert noutcomes == 3*107
        assert nfailures == 3*6

        assert set(cleanedup) == set(alltestdirs)

    def test_timeout(self):
        test_driver = [pytest_script]

        log = cStringIO.StringIO()
        out = cStringIO.StringIO()

        run_param = runner.RunParam(self.test_stall_dir)
        run_param.test_driver = test_driver
        run_param.parallel_runs = 3
        run_param.timeout = 3

        testdirs = []
        run_param.collect_testdirs(testdirs)
        res = runner.execute_tests(run_param, testdirs, log, out)
        assert res

        log_lines = log.getvalue().splitlines()
        assert log_lines[1] == ' TIMEOUT'

    def test_run_wrong_interp(self):
        log = cStringIO.StringIO()
        out = cStringIO.StringIO()

        run_param = runner.RunParam(self.one_test_dir)
        run_param.interp = ['wrong-interp']
        run_param.parallel_runs = 3

        testdirs = []
        run_param.collect_testdirs(testdirs)
        res = runner.execute_tests(run_param, testdirs, log, out)
        assert res

        log_lines = log.getvalue().splitlines()
        assert log_lines[1] == ' Failed to run interp'

    def test_run_bad_get_test_driver(self):
        test_driver = [pytest_script]

        log = cStringIO.StringIO()
        out = cStringIO.StringIO()

        run_param = runner.RunParam(self.one_test_dir)
        run_param.parallel_runs = 3
        def boom(testdir):
            raise RuntimeError("Boom")
        run_param.get_test_driver = boom

        testdirs = []
        run_param.collect_testdirs(testdirs)
        res = runner.execute_tests(run_param, testdirs, log, out)
        assert res

        log_lines = log.getvalue().splitlines()
        assert log_lines[1] == ' Failed with exception in execute-test'


class TestRunnerNoThreads(RunnerTests):
    with_thread = False

    def test_collect_testdirs(self):
        res = []
        seen = []
        run_param = runner.RunParam(self.one_test_dir)
        real_collect_one_testdir = run_param.collect_one_testdir

        def witness_collect_one_testdir(testdirs, reldir, tests):
            seen.append((reldir, sorted(map(str, tests))))
            real_collect_one_testdir(testdirs, reldir, tests)

        run_param.collect_one_testdir = witness_collect_one_testdir

        run_param.collect_testdirs(res)

        assert res == ['test_normal']
        assert len(seen) == 1
        reldir, tests = seen[0]
        assert reldir == 'test_normal'
        for test in tests:
            assert test.startswith('test_normal/')

        run_param.collect_one_testdir = real_collect_one_testdir
        res = []
        run_param = runner.RunParam(self.two_test_dir)

        run_param.collect_testdirs(res)

        assert sorted(res) == ['pkg/test_normal2', 'test_normal1']


class TestRunner(RunnerTests):
    pass

