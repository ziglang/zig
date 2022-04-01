import py
import os, time, sys
from rpython.tool.udir import udir
from rpython.rlib.rarithmetic import r_longlong
from rpython.annotator import model as annmodel
from rpython.translator.c.test.test_genc import compile
from rpython.translator.c.test.test_standalone import StandaloneTests
posix = __import__(os.name)

def test_time_clock():
    def does_stuff():
        t1 = t2 = time.clock()
        while abs(t2 - t1) < 0.01:
            t2 = time.clock()
        return t2 - t1
    f1 = compile(does_stuff, [])
    t = f1()
    assert 0 < t < 1.5

def test_time_sleep():
    def does_nothing():
        time.sleep(0.19)
    f1 = compile(does_nothing, [])
    t0 = time.time()
    f1()
    t1 = time.time()
    assert t0 <= t1
    assert t1 - t0 >= 0.15


def test_os_open():
    tmpfile = str(udir.join('test_os_open.txt'))
    def does_stuff():
        fd = os.open(tmpfile, os.O_WRONLY | os.O_CREAT, 0777)
        os.close(fd)
        return fd

    f1 = compile(does_stuff, [])
    fd = f1()
    assert os.path.exists(tmpfile)

def test_failing_os_open():
    tmpfile = str(udir.join('test_failing_os_open.DOESNTEXIST'))
    def does_stuff():
        fd = os.open(tmpfile, os.O_RDONLY, 0777)
        return fd

    f1 = compile(does_stuff, [])
    f1(expected_exception_name='OSError')
    assert not os.path.exists(tmpfile)

def test_open_read_write_seek_close():
    filename = str(udir.join('test_open_read_write_close.txt'))
    def does_stuff():
        fd = os.open(filename, os.O_WRONLY | os.O_CREAT, 0777)
        count = os.write(fd, "hello world\n")
        assert count == len("hello world\n")
        os.close(fd)
        fd = os.open(filename, os.O_RDONLY, 0777)
        result = os.lseek(fd, 1, 0)
        assert result == 1
        data = os.read(fd, 500)
        assert data == "ello world\n"
        os.close(fd)

    f1 = compile(does_stuff, [])
    f1()
    with open(filename, 'r') as fid:
        assert fid.read() == "hello world\n"
    os.unlink(filename)

def test_big_read():
    filename = str(udir.join('test_open_read_write_close.txt'))
    def does_stuff():
        fd = os.open(filename, os.O_WRONLY | os.O_CREAT, 0777)
        count = os.write(fd, "hello world\n")
        os.close(fd)
        fd = os.open(filename, os.O_RDONLY, 0777)
        data = os.read(fd, 500000)
        os.close(fd)

    f1 = compile(does_stuff, [])
    f1()
    os.unlink(filename)


def test_ftruncate():
    if not hasattr(os, 'ftruncate'):
        py.test.skip("this os has no ftruncate :-(")
    filename = str(udir.join('test_open_read_write_close.txt'))
    def does_stuff():
        fd = os.open(filename, os.O_WRONLY | os.O_CREAT, 0777)
        os.write(fd, "hello world\n")
        os.close(fd)
        fd = os.open(filename, os.O_RDWR, 0777)
        os.ftruncate(fd, 5)
        data = os.read(fd, 500)
        assert data == "hello"
        os.close(fd)
    does_stuff()
    f1 = compile(does_stuff, [])
    f1()
    os.unlink(filename)

def need_sparse_files():
    if sys.platform == 'darwin':
        py.test.skip("no sparse files on default Mac OS X file system")
    if os.name == 'nt':
        py.test.skip("no sparse files on Windows")

def test_largefile():
    if not hasattr(os, 'ftruncate'):
        py.test.skip("this os has no ftruncate :-(")
    need_sparse_files()
    filename = str(udir.join('test_largefile'))
    r4800000000  = r_longlong(4800000000L)
    r4900000000  = r_longlong(4900000000L)
    r5000000000  = r_longlong(5000000000L)
    r5200000000  = r_longlong(5200000000L)
    r9900000000  = r_longlong(9900000000L)
    r10000000000 = r_longlong(10000000000L)
    def does_stuff():
        fd = os.open(filename, os.O_RDWR | os.O_CREAT, 0666)
        os.ftruncate(fd, r10000000000)
        res = os.lseek(fd, r9900000000, 0)
        assert res == r9900000000
        res = os.lseek(fd, -r5000000000, 1)
        assert res == r4900000000
        res = os.lseek(fd, -r5200000000, 2)
        assert res == r4800000000
        os.close(fd)
        try:
            os.lseek(fd, 0, 0)
        except OSError:
            pass
        else:
            print "DID NOT RAISE"
            raise AssertionError
        st = os.stat(filename)
        assert st.st_size == r10000000000
    does_stuff()
    os.unlink(filename)
    f1 = compile(does_stuff, [])
    f1()
    os.unlink(filename)

def test_os_access():
    filename = str(py.path.local(__file__))
    def call_access(path, mode):
        return os.access(path, mode)
    f = compile(call_access, [str, int])
    for mode in os.R_OK, os.W_OK, os.X_OK, (os.R_OK | os.W_OK | os.X_OK):
        assert f(filename, mode) == os.access(filename, mode)


def test_os_stat():
    filename = str(py.path.local(__file__))
    has_blksize = hasattr(os.stat_result, 'st_blksize')
    has_blocks = hasattr(os.stat_result, 'st_blocks')
    def call_stat():
        st = os.stat(filename)
        res = (st[0], st.st_ino, st.st_ctime)
        if has_blksize: res += (st.st_blksize,)
        if has_blocks: res += (st.st_blocks,)
        return str(res)
    f = compile(call_stat, [])
    res = eval(f())
    assert res[0] == os.stat(filename).st_mode
    # windows zeros out st_ino in the app-level os.stat
    if sys.platform != 'win32':
        assert res[1] == os.stat(filename).st_ino
    st_ctime = res[2]
    if isinstance(st_ctime, float):
        assert (st_ctime - os.stat(filename).st_ctime) < 0.1
    else:
        assert st_ctime == int(os.stat(filename).st_ctime)
    if has_blksize:
        assert res[3] == os.stat(filename).st_blksize
        if has_blocks:
            assert res[4] == os.stat(filename).st_blocks

def test_os_stat_raises_winerror():
    if sys.platform != 'win32':
        py.test.skip("no WindowsError on this platform")
    def call_stat():
        try:
            os.stat("nonexistentdir/nonexistentfile")
        except WindowsError as e:
            return e.winerror
        return 0    
    f = compile(call_stat, [])
    res = f()
    expected = call_stat()
    assert res == expected

def test_os_fstat():
    if os.environ.get('PYPY_CC', '').startswith('tcc'):
        py.test.skip("segfault with tcc :-(")
    filename = str(py.path.local(__file__))
    def call_fstat():
        fd = os.open(filename, os.O_RDONLY, 0777)
        st = os.fstat(fd)
        os.close(fd)
        return str((st.st_mode, st[1], st.st_mtime))
    f = compile(call_fstat, [])
    osstat = os.stat(filename)
    st_mode, st_ino, st_mtime = eval(f())
    assert st_mode  == osstat.st_mode
    if sys.platform != 'win32':
        assert st_ino  == osstat.st_ino
    if isinstance(st_mtime, float):
        assert (st_mtime - osstat.st_mtime) < 0.1
    else:
        assert st_mtime == int(osstat.st_mtime)

def test_os_isatty():
    def call_isatty(fd):
        return os.isatty(fd)
    f = compile(call_isatty, [int])
    assert f(0) == os.isatty(0)
    assert f(1) == os.isatty(1)
    assert f(2) == os.isatty(2)

def test_getcwd():
    def does_stuff():
        return os.getcwd()
    f1 = compile(does_stuff, [])
    res = f1()
    assert res == os.getcwd()

def test_system():
    def does_stuff(cmd):
        return os.system(cmd)
    f1 = compile(does_stuff, [str])
    res = f1("echo hello")
    assert res == 0

def test_os_path_exists():
    tmpfile = str(udir.join('test_os_path_exists.TMP'))
    def fn():
        return os.path.exists(tmpfile)
    f = compile(fn, [])
    open(tmpfile, 'w').close()
    assert f() == True
    os.unlink(tmpfile)
    assert f() == False

def test_os_path_isdir():
    directory = "./."
    def fn():
        return os.path.isdir(directory)
    f = compile(fn, [])
    assert f() == True
    directory = "some/random/name"
    def fn():
        return os.path.isdir(directory)
    f = compile(fn, [])
    assert f() == False

def test_time_time():
    import time
    def fn():
        return time.time()
    f = compile(fn, [])
    t0 = time.time()
    res = fn()
    t1 = time.time()
    assert t0 <= res <= t1


def test_formatd():
    from rpython.rlib.rfloat import formatd
    def fn(x):
        return formatd(x, 'f', 2, 0)

    f = compile(fn, [float])

    assert f(0.0) == "0.00"
    assert f(1.5) == "1.50"
    assert f(2.0) == "2.00"

def test_float_to_str():
    def fn(f):
        return str(f)
    f = compile(fn, [float])
    res = f(1.5)
    assert eval(res) == 1.5

def test_os_unlink():
    tmpfile = str(udir.join('test_os_path_exists.TMP'))
    def fn():
        os.unlink(tmpfile)
    f = compile(fn, [])
    open(tmpfile, 'w').close()
    fn()
    assert not os.path.exists(tmpfile)

def test_chdir():
    def does_stuff(path):
        os.chdir(path)
        return os.getcwd()
    f1 = compile(does_stuff, [str])
    if os.name == 'nt':
        assert f1(os.environ['TEMP']) == os.path.realpath(os.environ['TEMP'])
    else:
        assert f1('/tmp') == os.path.realpath('/tmp')

def test_mkdir_rmdir():
    def does_stuff(path, delete):
        if delete:
            os.rmdir(path)
        else:
            os.mkdir(path, 0777)
    f1 = compile(does_stuff, [str, bool])
    dirname = str(udir.join('test_mkdir_rmdir'))
    f1(dirname, False)
    assert os.path.exists(dirname) and os.path.isdir(dirname)
    f1(dirname, True)
    assert not os.path.exists(dirname)

def test_strerror():
    def does_stuff(n):
        return os.strerror(n)
    f1 = compile(does_stuff, [int])
    for i in range(4):
        res = f1(i)
        assert res == os.strerror(i)

def test_pipe_dup_dup2():
    def does_stuff():
        a, b = os.pipe()
        c = os.dup(a)
        d = os.dup(b)
        assert a != b
        assert a != c
        assert a != d
        assert b != c
        assert b != d
        assert c != d
        os.close(c)
        os.dup2(d, c)
        e, f = os.pipe()
        assert e != a
        assert e != b
        assert e != c
        assert e != d
        assert f != a
        assert f != b
        assert f != c
        assert f != d
        assert f != e
        os.close(a)
        os.close(b)
        os.close(c)
        os.close(d)
        os.close(e)
        os.close(f)
        return 42
    f1 = compile(does_stuff, [])
    res = f1()
    assert res == 42

def test_os_chmod():
    tmpfile = str(udir.join('test_os_chmod.txt'))
    f = open(tmpfile, 'w')
    f.close()
    # use a witness for the permissions we should expect -
    # on Windows it is not possible to change all the bits with chmod()
    tmpfile2 = str(udir.join('test_os_chmod_witness.txt'))
    f = open(tmpfile2, 'w')
    f.close()
    def does_stuff(mode):
        os.chmod(tmpfile, mode)
    f1 = compile(does_stuff, [int])
    f1(0000)
    os.chmod(tmpfile2, 0000)
    assert os.stat(tmpfile).st_mode & 0777 == os.stat(tmpfile2).st_mode & 0777
    f1(0644)
    os.chmod(tmpfile2, 0644)
    assert os.stat(tmpfile).st_mode & 0777 == os.stat(tmpfile2).st_mode & 0777

if hasattr(os, 'fchmod'):
    def test_os_fchmod():
        tmpfile1 = str(udir.join('test_os_fchmod.txt'))
        def does_stuff():
            fd = os.open(tmpfile1, os.O_WRONLY | os.O_CREAT, 0777)
            os.fchmod(fd, 0200)
            os.close(fd)
        f1 = compile(does_stuff, [])
        f1()
        assert os.stat(tmpfile1).st_mode & 0777 == 0200

def test_os_rename():
    tmpfile1 = str(udir.join('test_os_rename_1.txt'))
    tmpfile2 = str(udir.join('test_os_rename_2.txt'))
    f = open(tmpfile1, 'w')
    f.close()
    def does_stuff():
        os.rename(tmpfile1, tmpfile2)
    f1 = compile(does_stuff, [])
    f1()
    assert os.path.exists(tmpfile2)
    assert not os.path.exists(tmpfile1)

if hasattr(os, 'mkfifo'):
    def test_os_mkfifo():
        tmpfile = str(udir.join('test_os_mkfifo.txt'))
        def does_stuff():
            os.mkfifo(tmpfile, 0666)
        f1 = compile(does_stuff, [])
        f1()
        import stat
        st = os.lstat(tmpfile)
        assert stat.S_ISFIFO(st.st_mode)

if hasattr(os, 'mknod'):
    def test_os_mknod():
        import stat
        tmpfile = str(udir.join('test_os_mknod.txt'))
        def does_stuff():
            os.mknod(tmpfile, 0600 | stat.S_IFIFO, 0)
        f1 = compile(does_stuff, [])
        f1()
        st = os.lstat(tmpfile)
        assert stat.S_ISFIFO(st.st_mode)

def test_os_umask():
    def does_stuff():
        mask1 = os.umask(0660)
        mask2 = os.umask(mask1)
        return mask2
    f1 = compile(does_stuff, [])
    res = f1()
    assert res == does_stuff()

if hasattr(os, 'getpid'):
    def test_os_getpid():
        def does_stuff():
            return os.getpid()
        f1 = compile(does_stuff, [])
        res = f1()
        assert res != os.getpid()

if hasattr(os, 'getpgrp'):
    def test_os_getpgrp():
        def does_stuff():
            return os.getpgrp()
        f1 = compile(does_stuff, [])
        res = f1()
        assert res == os.getpgrp()

if hasattr(os, 'setpgrp'):
    def test_os_setpgrp():
        def does_stuff():
            return os.setpgrp()
        f1 = compile(does_stuff, [])
        res = f1()
        assert res == os.setpgrp()

if hasattr(os, 'link'):
    def test_links():
        import stat
        tmpfile1 = str(udir.join('test_links_1.txt'))
        tmpfile2 = str(udir.join('test_links_2.txt'))
        tmpfile3 = str(udir.join('test_links_3.txt'))
        f = open(tmpfile1, 'w')
        f.close()
        def does_stuff():
            os.symlink(tmpfile1, tmpfile2)
            os.link(tmpfile1, tmpfile3)
            assert os.readlink(tmpfile2) == tmpfile1
            flag= 0
            st = os.lstat(tmpfile1)
            flag = flag*10 + stat.S_ISREG(st[0])
            flag = flag*10 + stat.S_ISLNK(st[0])
            st = os.lstat(tmpfile2)
            flag = flag*10 + stat.S_ISREG(st[0])
            flag = flag*10 + stat.S_ISLNK(st[0])
            st = os.lstat(tmpfile3)
            flag = flag*10 + stat.S_ISREG(st[0])
            flag = flag*10 + stat.S_ISLNK(st[0])
            return flag
        f1 = compile(does_stuff, [])
        res = f1()
        assert res == 100110
        assert os.path.islink(tmpfile2)
        assert not os.path.islink(tmpfile3)

if hasattr(os, 'fork'):
    def test_fork():
        def does_stuff():
            pid = os.fork()
            if pid == 0:   # child
                os._exit(4)
            pid1, status1 = os.waitpid(pid, 0)
            assert pid1 == pid
            return status1
        f1 = compile(does_stuff, [])
        status1 = f1()
        assert os.WIFEXITED(status1)
        assert os.WEXITSTATUS(status1) == 4
    if hasattr(os, 'kill'):
        def test_kill():
            import signal
            def does_stuff():
                pid = os.fork()
                if pid == 0:   # child
                    time.sleep(5)
                    os._exit(4)
                os.kill(pid, signal.SIGTERM)  # in the parent
                pid1, status1 = os.waitpid(pid, 0)
                assert pid1 == pid
                return status1
            f1 = compile(does_stuff, [])
            status1 = f1()
            assert os.WIFSIGNALED(status1)
            assert os.WTERMSIG(status1) == signal.SIGTERM
elif hasattr(os, 'waitpid'):
    # windows has no fork but some waitpid to be emulated
    def test_waitpid():
        prog = str(sys.executable)
        def does_stuff():
            args = [prog]
#            args = [prog, '-c', '"import os;os._exit(4)"']
#           note that the above variant creates a bad array
            args.append('-c')
            args.append('"import os;os._exit(4)"')
            pid = os.spawnv(os.P_NOWAIT, prog, args)
            #if pid == 0:   # child
            #    os._exit(4)
            pid1, status1 = os.waitpid(pid, 0)
            assert pid1 == pid
            return status1
        f1 = compile(does_stuff, [])
        status1 = f1()
        # for what reason do they want us to shift by 8? See the doc
        assert status1 >> 8 == 4

if hasattr(os, 'kill'):
    def test_kill_to_send_sigusr1():
        import signal
        from rpython.rlib import rsignal
        if not 'SIGUSR1' in dir(signal):
            py.test.skip("no SIGUSR1 available")
        def does_stuff():
            rsignal.pypysig_setflag(signal.SIGUSR1)
            os.kill(os.getpid(), signal.SIGUSR1)
            rsignal.pypysig_ignore(signal.SIGUSR1)
            while True:
                n = rsignal.pypysig_poll()
                if n < 0 or n == signal.SIGUSR1:
                    break
            return n
        f1 = compile(does_stuff, [])
        got_signal = f1()
        assert got_signal == signal.SIGUSR1

if hasattr(os, 'killpg'):
    def test_killpg():
        import signal
        from rpython.rlib import rsignal
        def does_stuff():
            os.setpgid(0, 0)     # become its own separated process group
            rsignal.pypysig_setflag(signal.SIGUSR1)
            os.killpg(os.getpgrp(), signal.SIGUSR1)
            rsignal.pypysig_ignore(signal.SIGUSR1)
            while True:
                n = rsignal.pypysig_poll()
                if n < 0 or n == signal.SIGUSR1:
                    break
            return n
        f1 = compile(does_stuff, [])
        got_signal = f1()
        assert got_signal == signal.SIGUSR1

if hasattr(os, 'chown') and hasattr(os, 'lchown'):
    def test_os_chown_lchown():
        path1 = udir.join('test_os_chown_lchown-1.txt')
        path2 = udir.join('test_os_chown_lchown-2.txt')
        path1.write('foobar')
        path2.mksymlinkto('some-broken-symlink')
        tmpfile1 = str(path1)
        tmpfile2 = str(path2)
        def does_stuff():
            # xxx not really a test, just checks that they are callable
            os.chown(tmpfile1, os.getuid(), os.getgid())
            os.lchown(tmpfile1, os.getuid(), os.getgid())
            os.lchown(tmpfile2, os.getuid(), os.getgid())
            try:
                os.chown(tmpfile2, os.getuid(), os.getgid())
            except OSError:
                pass
            else:
                raise AssertionError("os.chown(broken symlink) should raise")
        f1 = compile(does_stuff, [])
        f1()

if hasattr(os, 'fchown'):
    def test_os_fchown():
        path1 = udir.join('test_os_fchown.txt')
        tmpfile1 = str(path1)
        def does_stuff():
            # xxx not really a test, just checks that it is callable
            fd = os.open(tmpfile1, os.O_WRONLY | os.O_CREAT, 0777)
            os.fchown(fd, os.getuid(), os.getgid())
            os.close(fd)
        f1 = compile(does_stuff, [])
        f1()

if hasattr(os, 'getlogin'):
    def test_os_getlogin():
        def does_stuff():
            return os.getlogin()

        try:
            expected = os.getlogin()
        except OSError as e:
            py.test.skip("the underlying os.getlogin() failed: %s" % e)
        f1 = compile(does_stuff, [])
        assert f1() == expected

# ____________________________________________________________

def _real_getenv(var):
    cmd = '''%s -c "import os; x=os.environ.get('%s'); print (x is None) and 'F' or ('T'+x)"''' % (
        sys.executable, var)
    g = os.popen(cmd, 'r')
    output = g.read().strip()
    g.close()
    if output == 'F':
        return None
    elif output.startswith('T'):
        return output[1:]
    else:
        raise ValueError('probing for env var returned %r' % (output,))

def test_dictlike_environ_getitem():
    def fn(s):
        try:
            return os.environ[s]
        except KeyError:
            return '--missing--'
    func = compile(fn, [str])
    os.environ.setdefault('USER', 'UNNAMED_USER')
    result = func('USER')
    assert result == os.environ['USER']
    result = func('PYPY_TEST_DICTLIKE_MISSING')
    assert result == '--missing--'

def test_dictlike_environ_get():
    def fn(s):
        res = os.environ.get(s)
        if res is None: res = '--missing--'
        return res
    func = compile(fn, [str])
    os.environ.setdefault('USER', 'UNNAMED_USER')
    result = func('USER')
    assert result == os.environ['USER']
    result = func('PYPY_TEST_DICTLIKE_MISSING')
    assert result == '--missing--'

def test_dictlike_environ_setitem():
    def fn(s, t1, t2, t3, t4, t5):
        os.environ[s] = t1
        os.environ[s] = t2
        os.environ[s] = t3
        os.environ[s] = t4
        os.environ[s] = t5
        return os.environ[s]
    func = compile(fn, [str] * 6)
    r = func('PYPY_TEST_DICTLIKE_ENVIRON', 'a', 'b', 'c', 'FOOBAR', '42')
    assert r == '42'

def test_dictlike_environ_delitem():
    def fn(s1, s2, s3, s4, s5):
        for n in range(10):
            os.environ[s1] = 't1'
            os.environ[s2] = 't2'
            os.environ[s3] = 't3'
            os.environ[s4] = 't4'
            os.environ[s5] = 't5'
            del os.environ[s3]
            del os.environ[s1]
            del os.environ[s2]
            del os.environ[s4]
            try:
                del os.environ[s2]
            except KeyError:
                pass
            else:
                raise Exception("should have raised!")
            # os.environ[s5] stays
    func = compile(fn, [str] * 5)
    func('PYPY_TEST_DICTLIKE_ENVDEL1',
         'PYPY_TEST_DICTLIKE_ENVDEL_X',
         'PYPY_TEST_DICTLIKE_ENVDELFOO',
         'PYPY_TEST_DICTLIKE_ENVDELBAR',
         'PYPY_TEST_DICTLIKE_ENVDEL5')

def test_dictlike_environ_keys():
    def fn():
        return '\x00'.join(os.environ.keys())
    func = compile(fn, [])
    os.environ.setdefault('USER', 'UNNAMED_USER')
    try:
        del os.environ['PYPY_TEST_DICTLIKE_ENVKEYS']
    except:
        pass
    result1 = func().split('\x00')
    os.environ['PYPY_TEST_DICTLIKE_ENVKEYS'] = '42'
    result2 = func().split('\x00')
    assert 'USER' in result1
    assert 'PYPY_TEST_DICTLIKE_ENVKEYS' not in result1
    assert 'USER' in result2
    assert 'PYPY_TEST_DICTLIKE_ENVKEYS' in result2

def test_dictlike_environ_items():
    def fn():
        result = []
        for key, value in os.environ.items():
            result.append('%s/%s' % (key, value))
        return '\x00'.join(result)
    func = compile(fn, [])
    os.environ.setdefault('USER', 'UNNAMED_USER')
    result1 = func().split('\x00')
    os.environ['PYPY_TEST_DICTLIKE_ENVITEMS'] = '783'
    result2 = func().split('\x00')
    assert ('USER/%s' % (os.environ['USER'],)) in result1
    assert 'PYPY_TEST_DICTLIKE_ENVITEMS/783' not in result1
    assert ('USER/%s' % (os.environ['USER'],)) in result2
    assert 'PYPY_TEST_DICTLIKE_ENVITEMS/783' in result2

def test_listdir():
    def mylistdir(s):
        try:
            os.listdir('this/directory/really/cannot/exist')
        except OSError:
            pass
        else:
            raise AssertionError("should have failed!")
        result = os.listdir(s)
        return '/'.join(result)
    func = compile(mylistdir, [str])
    for testdir in [str(udir), os.curdir]:
        result = func(testdir)
        result = result.split('/')
        result.sort()
        compared_with = os.listdir(testdir)
        compared_with.sort()
        assert result == compared_with

if hasattr(posix, 'execv') and hasattr(posix, 'fork'):
    def test_execv():
        progname = str(sys.executable)
        filename = str(udir.join('test_execv.txt'))
        def does_stuff():
            l = [progname, '-c', 'open(%r,"w").write("1")' % filename]
            pid = os.fork()
            if pid == 0:
                os.execv(progname, l)
            else:
                os.waitpid(pid, 0)
        func = compile(does_stuff, [], backendopt=False)
        func()
        assert open(filename).read() == "1"

    def test_execv_raising():
        def does_stuff():
            try:
                l = []
                l.append("asddsadw32eewdfwqdqwdqwd")
                os.execv(l[0], l)
                return 1
            except OSError:
                return -2

        func = compile(does_stuff, [])
        assert func() == -2

    def test_execve():
        filename = str(udir.join('test_execve.txt'))
        progname = sys.executable
        def does_stuff():
            l = []
            l.append(progname)
            l.append("-c")
            l.append('import os; open(%r, "w").write(os.environ["STH"])' % filename)
            env = {}
            env["STH"] = "42"
            env["sthelse"] = "a"
            pid = os.fork()
            if pid == 0:
                os.execve(progname, l, env)
            else:
                os.waitpid(pid, 0)

        func = compile(does_stuff, [])
        func()
        assert open(filename).read() == "42"

if hasattr(posix, 'spawnv'):
    def test_spawnv():
        filename = str(udir.join('test_spawnv.txt'))
        progname = str(sys.executable)
        scriptpath = udir.join('test_spawnv.py')
        scriptpath.write('f=open(%r,"w")\nf.write("2")\nf.close\n' % filename)
        scriptname = str(scriptpath)
        def does_stuff():
            # argument quoting on Windows is completely ill-defined.
            # don't let yourself be fooled by the idea that if os.spawnv()
            # takes a list of strings, then the receiving program will
            # nicely see these strings as arguments with no further quote
            # processing.  Achieving this is nearly impossible - even
            # CPython doesn't try at all.
            l = [progname, scriptname]
            pid = os.spawnv(os.P_NOWAIT, progname, l)
            os.waitpid(pid, 0)
        func = compile(does_stuff, [])
        func()
        assert open(filename).read() == "2"

if hasattr(posix, 'spawnve'):
    def test_spawnve():
        filename = str(udir.join('test_spawnve.txt'))
        progname = str(sys.executable)
        scriptpath = udir.join('test_spawnve.py')
        scriptpath.write('import os\n' +
                         'f=open(%r,"w")\n' % filename +
                         'f.write(os.environ["FOOBAR"])\n' +
                         'f.close\n')
        scriptname = str(scriptpath)
        def does_stuff():
            l = [progname, scriptname]
            pid = os.spawnve(os.P_NOWAIT, progname, l, {'FOOBAR': '42'})
            os.waitpid(pid, 0)
        func = compile(does_stuff, [])
        func()
        assert open(filename).read() == "42"

def test_utime():
    path = str(udir.ensure("test_utime.txt"))
    from time import time, sleep
    t0 = time()
    sleep(1)

    def does_stuff(flag):
        if flag:
            os.utime(path, None)
        else:
            os.utime(path, (int(t0), int(t0)))

    func = compile(does_stuff, [int])
    func(1)
    assert os.stat(path).st_atime > t0
    func(0)
    assert int(os.stat(path).st_atime) == int(t0)

if hasattr(os, 'uname'):
    def test_os_uname():
        def does_stuff(num):
            tup = os.uname()
            lst = [tup[0], tup[1], tup[2], tup[3], tup[4]]
            return lst[num]
        func = compile(does_stuff, [int])
        for i in range(5):
            res = func(i)
            assert res == os.uname()[i]

if hasattr(os, 'getloadavg'):
    def test_os_getloadavg():
        def does_stuff():
            a, b, c = os.getloadavg()
            print a, b, c
            return a + b + c
        f = compile(does_stuff, [])
        res = f()
        assert type(res) is float and res >= 0.0

if hasattr(os, 'major'):
    def test_os_major_minor():
        def does_stuff(n):
            a = os.major(n)
            b = os.minor(n)
            x = os.makedev(a, b)
            return '%d,%d,%d' % (a, b, x)
        f = compile(does_stuff, [int])
        res = f(12345)
        assert res == '%d,%d,12345' % (os.major(12345), os.minor(12345))

if hasattr(os, 'fchdir'):
    def test_os_fchdir():
        def does_stuff():
            fd = os.open('/', os.O_RDONLY, 0400)
            try:
                os.fchdir(fd)
                s = os.getcwd()
            finally:
                os.close(fd)
            return s == '/'
        f = compile(does_stuff, [])
        localdir = os.getcwd()
        try:
            res = f()
        finally:
            os.chdir(localdir)
        assert res == True

# ____________________________________________________________


class TestExtFuncStandalone(StandaloneTests):

    if hasattr(os, 'nice'):
        def test_os_nice(self):
            def does_stuff(argv):
                res =  os.nice(3)
                print 'os.nice returned', res
                return 0
            t, cbuilder = self.compile(does_stuff)
            data = cbuilder.cmdexec('')
            res = os.nice(0) + 3
            if res > 19: res = 19    # xxx Linux specific, probably
            assert data.startswith('os.nice returned %d\n' % res)
