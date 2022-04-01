import sys, os, signal, thread, Queue, time
import py
import subprocess, optparse

if sys.platform == 'win32':
    PROCESS_TERMINATE = 0x1
    try:
        import win32api, pywintypes
    except ImportError:
        def _kill(pid, sig):
            import ctypes
            winapi = ctypes.windll.kernel32
            proch = winapi.OpenProcess(PROCESS_TERMINATE, 0, pid)
            winapi.TerminateProcess(proch, 1) == 1
            winapi.CloseHandle(proch)
    else:
        def _kill(pid, sig):
            try:
                proch = win32api.OpenProcess(PROCESS_TERMINATE, 0, pid)
                win32api.TerminateProcess(proch, 1)
                win32api.CloseHandle(proch)
            except pywintypes.error, e:
                pass
    #Try to avoid opening a dialog box if one of the tests causes a system error
    import ctypes
    winapi = ctypes.windll.kernel32
    SetErrorMode = winapi.SetErrorMode
    SetErrorMode.argtypes=[ctypes.c_int]

    SEM_FAILCRITICALERRORS = 1
    SEM_NOGPFAULTERRORBOX  = 2
    SEM_NOOPENFILEERRORBOX = 0x8000
    flags = SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX
    #Since there is no GetErrorMode, do a double Set
    old_mode = SetErrorMode(flags)
    SetErrorMode(old_mode | flags)

    SIGKILL = SIGTERM = 0
    READ_MODE = 'rU'
    WRITE_MODE = 'wb'
else:
    def _kill(pid, sig):
        try:
            os.kill(pid, sig)
        except OSError:
            pass

    SIGKILL = signal.SIGKILL
    SIGTERM = signal.SIGTERM
    READ_MODE = 'r'
    WRITE_MODE = 'w'

EXECUTEFAILED = -1001
RUNFAILED  = -1000
TIMEDOUT = -999

def busywait(p, timeout):
    t0 = time.time()
    delay = 0.5
    while True:
        time.sleep(delay)
        returncode = p.poll()
        if returncode is not None:
            return returncode
        tnow = time.time()
        if (tnow-t0) >= timeout:
            return None
        delay = min(delay * 1.15, 7.2)

def run(args, cwd, out, timeout=None):
    f = out.open('w')
    try:
        try:
            p = subprocess.Popen(args, cwd=str(cwd), stdout=f, stderr=f)
        except Exception, e:
            f.write("Failed to run %s with cwd='%s' timeout=%s:\n"
                    " %s\n"
                    % (args, cwd, timeout, e))
            return RUNFAILED

        if timeout is None:
            return p.wait()
        else:
            returncode = busywait(p, timeout)
            if returncode is not None:
                return returncode
            # timeout!
            _kill(p.pid, SIGTERM)
            if busywait(p, 10) is None:
                _kill(p.pid, SIGKILL)
            return TIMEDOUT
    finally:
        f.close()

def dry_run(args, cwd, out, timeout=None):
    f = out.open('w')
    try:
        f.write("run %s with cwd='%s' timeout=%s\n" % (args, cwd, timeout))
    finally:
        f.close()
    return 0

def getsignalname(n):
    # "sorted()" to pick a deterministic answer in case of synonyms.
    # Also, getting SIGABRT is more understandable than SIGIOT...
    for name, value in sorted(signal.__dict__.items()):
        if value == n and name.startswith('SIG'):
            return name
    return 'signal %d' % (n,)

def execute_test(cwd, test, out, logfname, interp, test_driver,
                 do_dry_run=False, timeout=None,
                 _win32=(sys.platform=='win32')):
    args = interp + test_driver
    args += ['-p', 'resultlog',
             '--resultlog=%s' % logfname,
             #'--junitxml=%s.junit' % logfname,
             test]

    args = map(str, args)
    interp0 = args[0]
    if (_win32 and not os.path.isabs(interp0) and
        ('\\' in interp0 or '/' in interp0)):
        args[0] = os.path.join(str(cwd), interp0)

    if do_dry_run:
        runfunc = dry_run
    else:
        runfunc = run

    exitcode = runfunc(args, cwd, out, timeout=timeout)

    return exitcode

def should_report_failure(logdata):
    # When we have an exitcode of 1, it might be because of failures
    # that occurred "regularly", or because of another crash of py.test.
    # We decide heuristically based on logdata: if it looks like it
    # contains "F", "E" or "P" then it's a regular failure, otherwise
    # we have to report it.
    for line in logdata.splitlines():
        if (line.startswith('F ') or
            line.startswith('E ') or
            line.startswith('P ')):
            return False
    return True

def interpret_exitcode(exitcode, test, logdata=""):
    extralog = ""
    if exitcode not in (0, 5):
        failure = True
        if exitcode != 1 or should_report_failure(logdata):
            if exitcode > 0:
                msg = "Exit code %d." % exitcode
            elif exitcode == TIMEDOUT:
                msg = "TIMEOUT"
            elif exitcode == RUNFAILED:
                msg = "Failed to run interp"
            elif exitcode == EXECUTEFAILED:
                msg = "Failed with exception in execute-test"
            else:
                msg = "Killed by %s." % getsignalname(-exitcode)
            extralog = "! %s\n %s\n" % (test, msg)
        else:
            extralog = "  (somefailed=True in %s)\n" % (test,)
    else:
        failure = False
    return failure, extralog

def worker(num, n, run_param, testdirs, result_queue):
    sessdir = run_param.sessdir
    root = run_param.root
    get_test_driver = run_param.get_test_driver
    interp = run_param.interp
    dry_run = run_param.dry_run
    timeout = run_param.timeout
    cleanup = run_param.cleanup
    # xxx cfg thread start
    while 1:
        try:
            test = testdirs.pop(0)
        except IndexError:
            result_queue.put(None) # done
            return
        result_queue.put(('start', test))
        basename = py.path.local(test).purebasename
        logfname = sessdir.join("%d-%s-pytest-log" % (num, basename))
        one_output = sessdir.join("%d-%s-output" % (num, basename))
        num += n

        try:
            test_driver = get_test_driver(test)
            exitcode = execute_test(root, test, one_output, logfname,
                                    interp, test_driver, do_dry_run=dry_run,
                                    timeout=timeout)

            cleanup(test)
        except:
            print "execute-test for %r failed with:" % test
            import traceback
            traceback.print_exc()
            exitcode = EXECUTEFAILED

        if one_output.check(file=1):
            output = one_output.read(READ_MODE)
        else:
            output = ""
        if logfname.check(file=1):
            logdata = logfname.read(READ_MODE)
        else:
            logdata = ""

        failure, extralog = interpret_exitcode(exitcode, test, logdata)

        if extralog:
            logdata += extralog

        result_queue.put(('done', test, failure, logdata, output))

invoke_in_thread = thread.start_new_thread

def start_workers(n, run_param, testdirs):
    result_queue = Queue.Queue()
    for i in range(n):
        invoke_in_thread(worker, (i, n, run_param, testdirs,
                                  result_queue))
    return result_queue


def execute_tests(run_param, testdirs, logfile, out):
    sessdir = py.path.local.make_numbered_dir(prefix='usession-testrunner-',
                                              keep=4)
    run_param.sessdir = sessdir

    run_param.startup()

    N = run_param.parallel_runs
    if N > 1:
        out.write("running %d parallel test workers\n" % N)
        s = 'setting'
        if os.environ.get('MAKEFLAGS'):
            s = 'overriding'
        out.write("%s MAKEFLAGS to ' ' (space)\n" % s)
        os.environ['MAKEFLAGS'] = ' '
    failure = False

    for testname in testdirs:
        out.write("-- %s\n" % testname)
    out.write("-- total: %d to run\n" % len(testdirs))

    result_queue = start_workers(N, run_param, testdirs)

    done = 0
    started = 0

    worker_done = 0
    while True:
        res = result_queue.get()
        if res is None:
            worker_done += 1
            if worker_done == N:
                break
            continue

        if res[0] == 'start':
            started += 1
            now = time.strftime('%H:%M:%S')
            out.write("++ %s starting %s [%d started in total]\n" % (now, res[1],
                                                                  started))
            continue

        testname, somefailed, logdata, output = res[1:]
        done += 1
        failure = failure or somefailed

        heading = "__ %s [%d done in total, somefailed=%s] " % (
            testname, done, somefailed)

        out.write(heading + (79-len(heading))*'_'+'\n')

        out.write(output)
        if logdata:
            logfile.write(logdata)

    run_param.shutdown()

    return failure


class RunParam(object):
    dry_run = False
    interp = [os.path.abspath(sys.executable)]
    pytestpath = os.path.abspath(os.path.join('py', 'bin', 'py.test'))
    if not os.path.exists(pytestpath):
        pytestpath = os.path.abspath(os.path.join('pytest.py'))
        assert os.path.exists(pytestpath)
    test_driver = [pytestpath]

    parallel_runs = 1
    timeout = None
    cherrypick = None

    def __init__(self, root):
        self.root = root
        self.self = self

    def startup(self):
        pass

    def shutdown(self):
        pass

    def get_test_driver(self, testdir):
        return self.test_driver

    def is_test_py_file(self, p):
        name = p.basename
        return name.startswith('test_') and name.endswith('.py')

    def reltoroot(self, p):
        rel = p.relto(self.root)
        return rel.replace(os.sep, '/')

    def collect_one_testdir(self, testdirs, reldir, tests):
        testdirs.append(reldir)
        return

    def collect_testdirs(self, testdirs, p=None):
        if p is None:
            p = self.root

        reldir = self.reltoroot(p)
        if p.check():
            entries = [p1 for p1 in p.listdir(fil=lambda x: 'test_pypy_c' not in str(x)) if p1.check(dotfile=0)]
        else:
            entries = []
        entries.sort()

        if p != self.root:
            for p1 in entries:
                if self.is_test_py_file(p1):
                    self.collect_one_testdir(testdirs, reldir,
                                   [self.reltoroot(t) for t in entries
                                    if self.is_test_py_file(t)])
                    break

        for p1 in entries:
            if p1.check(dir=1, link=0):
                self.collect_testdirs(testdirs, p1)

    def cleanup(self, testdir):
        pass


def main(args):
    parser = optparse.OptionParser()
    parser.add_option("--logfile", dest="logfile", default=None,
                      help="accumulated machine-readable logfile")
    parser.add_option("--output", dest="output", default='-',
                      help="plain test output (default: stdout)")
    parser.add_option("--config", dest="config", default=[],
                      action="append",
                      help="configuration python file (optional)")
    parser.add_option("--root", dest="root", default=".",
                      help="root directory for the run")
    parser.add_option("--parallel-runs", dest="parallel_runs", default=0,
                      type="int",
                      help="number of parallel test runs")
    parser.add_option("--dry-run", dest="dry_run", default=False,
                      action="store_true",
                      help="dry run"),
    parser.add_option("--timeout", dest="timeout", default=None,
                      type="int",
                      help="timeout in secs for test processes")

    opts, args = parser.parse_args(args)

    if opts.logfile is None:
        print "no logfile specified"
        sys.exit(2)

    logfile = open(opts.logfile, WRITE_MODE)
    if opts.output == '-':
        out = sys.stdout
    else:
        out = open(opts.output, WRITE_MODE)

    root = py.path.local(opts.root)

    testdirs = []

    run_param = RunParam(root)
    # the config files are python files whose run overrides the content
    # of the run_param instance namespace
    # in that code function overriding method should not take self
    # though a self and self.__class__ are available if needed
    for config_py_file in opts.config:
        config_py_file = os.path.expanduser(config_py_file)
        if py.path.local(config_py_file).check(file=1):
            print >>out, "using config", config_py_file
            execfile(config_py_file, run_param.__dict__)
        else:
            print >>out, "ignoring non-existant config", config_py_file

    if run_param.cherrypick:
        for p in run_param.cherrypick:
            run_param.collect_testdirs(testdirs, root.join(p))
    else:
        run_param.collect_testdirs(testdirs)

    if opts.parallel_runs:
        run_param.parallel_runs = opts.parallel_runs
    if opts.timeout:
        run_param.timeout = opts.timeout
    run_param.dry_run = opts.dry_run

    if run_param.dry_run:
        print >>out, '\n'.join([str((k, getattr(run_param, k))) \
                        for k in dir(run_param) if k[:2] != '__'])

    res = execute_tests(run_param, testdirs, logfile, out)

    if res:
        sys.exit(1)


if __name__ == '__main__':
    main(sys.argv)
