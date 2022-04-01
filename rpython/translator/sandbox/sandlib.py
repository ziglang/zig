"""
A Python library to execute and communicate with a subprocess that
was translated from RPython code with --sandbox.  This library is
for the outer process, which can run CPython or PyPy.
"""

import sys, os, posixpath, errno, stat, time
import subprocess
from rpython.tool.killsubprocess import killsubprocess
from rpython.translator.sandbox.vfs import UID, GID
import py

WIN32 = os.name == "nt"


def create_log():
    """Make and return a log for the sandbox to use, if needed."""
    from rpython.tool.ansi_print import AnsiLogger
    return AnsiLogger("sandlib")

# Note: we use lib_pypy/marshal.py instead of the built-in marshal
# for two reasons.  The built-in module could be made to segfault
# or be attackable in other ways by sending malicious input to
# load().  Also, marshal.load(f) blocks with the GIL held when
# f is a pipe with no data immediately avaialble, preventing the
# _waiting_thread to run.
from rpython.translator.sandbox import _marshal as marshal

# Non-marshal result types
RESULTTYPE_STATRESULT = object()
RESULTTYPE_LONGLONG = object()

def read_message(f):
    return marshal.load(f)

def write_message(g, msg, resulttype=None):
    if resulttype is None:
        if sys.version_info < (2, 4):
            marshal.dump(msg, g)
        else:
            marshal.dump(msg, g, 0)
    elif resulttype is RESULTTYPE_STATRESULT:
        # Hand-coded marshal for stat results that mimics what rmarshal expects.
        # marshal.dump(tuple(msg)) would have been too easy. rmarshal insists
        # on 64-bit ints at places, even when the value fits in 32 bits.
        import struct
        st = tuple(msg)
        fmt = "iIIiiiIfff"
        buf = []
        buf.append(struct.pack("<ci", '(', len(st)))
        for c, v in zip(fmt, st):
            if c == 'i':
                buf.append(struct.pack("<ci", c, v))
            elif c == 'I':
                buf.append(struct.pack("<cq", c, v))
            elif c == 'f':
                fstr = "%g" % v
                buf.append(struct.pack("<cB", c, len(fstr)))
                buf.append(fstr)
        g.write(''.join(buf))
    elif resulttype is RESULTTYPE_LONGLONG:
        import struct
        g.write(struct.pack("<cq", 'I', msg))
    else:
        raise Exception("Can't marshal: %r (%r)" % (msg, resulttype))

# keep the table in sync with rsandbox.reraise_error()
EXCEPTION_TABLE = [
    (1, OSError),
    (2, IOError),
    (3, OverflowError),
    (4, ValueError),
    (5, ZeroDivisionError),
    (6, MemoryError),
    (7, KeyError),
    (8, IndexError),
    (9, RuntimeError),
    ]

def write_exception(g, exception, tb=None):
    for i, excclass in EXCEPTION_TABLE:
        if isinstance(exception, excclass):
            write_message(g, i)
            if excclass is OSError:
                error = exception.errno
                if error is None:
                    error = errno.EPERM
                write_message(g, error)
            g.flush()
            break
    else:
        # just re-raise the exception
        raise exception.__class__, exception, tb

def shortrepr(x):
    r = repr(x)
    if len(r) >= 80:
        r = r[:20] + '...' + r[-8:]
    return r

def signal_name(n):
    import signal
    for key, value in signal.__dict__.items():
        if key.startswith('SIG') and not key.startswith('SIG_') and value == n:
            return key
    return 'signal %d' % (n,)


class SandboxedProc(object):
    """Base class to control a sandboxed subprocess.
    Inherit from this class and implement all the do_xxx() methods
    for the external functions xxx that you want to support.
    """
    debug = False
    log = None
    os_level_sandboxing = False   # Linux only: /proc/PID/seccomp

    def __init__(self, args, executable=None):
        """'args' should a sequence of argument for the subprocess,
        starting with the full path of the executable.
        """
        self.popen = subprocess.Popen(args, executable=executable,
                                      bufsize=-1,
                                      stdin=subprocess.PIPE,
                                      stdout=subprocess.PIPE,
                                      close_fds=False if WIN32 else True,
                                      env={})
        self.popenlock = None
        self.currenttimeout = None
        self.currentlyidlefrom = None

        if self.debug:
            self.log = create_log()

    def withlock(self, function, *args, **kwds):
        lock = self.popenlock
        if lock is not None:
            lock.acquire()
        try:
            return function(*args, **kwds)
        finally:
            if lock is not None:
                lock.release()

    def settimeout(self, timeout, interrupt_main=False):
        """Start a timeout that will kill the subprocess after the given
        amount of time.  Only one timeout can be active at a time.
        """
        import thread

        def _waiting_thread():
            while True:
                while self.currentlyidlefrom is not None:
                    time.sleep(1)   # can't timeout while idle
                t = self.currenttimeout
                if t is None:
                    return  # cancelled
                delay = t - time.time()
                if delay <= 0.0:
                    break   # expired!
                time.sleep(min(delay*1.001, 1))
            if self.log:
                self.log.timeout("timeout!")
            self.kill()
            #if interrupt_main:
            #    if hasattr(os, 'kill'):
            #        import signal
            #        os.kill(os.getpid(), signal.SIGINT)
            #    else:
            #        thread.interrupt_main()

        def _settimeout():
            need_new_thread = self.currenttimeout is None
            self.currenttimeout = time.time() + timeout
            if need_new_thread:
                thread.start_new_thread(_waiting_thread, ())

        if self.popenlock is None:
            self.popenlock = thread.allocate_lock()
        self.withlock(_settimeout)

    def canceltimeout(self):
        """Cancel the current timeout."""
        self.currenttimeout = None
        self.currentlyidlefrom = None

    def enter_idle(self):
        self.currentlyidlefrom = time.time()

    def leave_idle(self):
        def _postpone_timeout():
            t = self.currentlyidlefrom
            if t is not None and self.currenttimeout is not None:
                self.currenttimeout += time.time() - t
        try:
            self.withlock(_postpone_timeout)
        finally:
            self.currentlyidlefrom = None

    def poll(self):
        returncode = self.withlock(self.popen.poll)
        if returncode is not None:
            self.canceltimeout()
        return returncode

    def wait(self):
        returncode = self.withlock(self.popen.wait)
        if returncode is not None:
            self.canceltimeout()
        return returncode

    def kill(self):
        self.withlock(killsubprocess, self.popen)

    def handle_forever(self):
        returncode = self.handle_until_return()
        if returncode != 0:
            raise OSError("the sandboxed subprocess exited with code %d" % (
                returncode,))

    def handle_until_return(self):
        child_stdin  = self.popen.stdin
        child_stdout = self.popen.stdout
        if self.os_level_sandboxing and sys.platform.startswith('linux'):
            # rationale: we wait until the child process started completely,
            # letting the C library do any system calls it wants for
            # initialization.  When the RPython code starts up, it quickly
            # does its first system call.  At this point we turn seccomp on.
            import select
            select.select([child_stdout], [], [])
            f = open('/proc/%d/seccomp' % self.popen.pid, 'w')
            print >> f, 1
            f.close()
        while True:
            try:
                fnname = read_message(child_stdout)
                args   = read_message(child_stdout)
            except EOFError as e:
                break
            if self.log and not self.is_spam(fnname, *args):
                self.log.call('%s(%s)' % (fnname,
                                     ', '.join([shortrepr(x) for x in args])))
            try:
                answer, resulttype = self.handle_message(fnname, *args)
            except Exception as e:
                tb = sys.exc_info()[2]
                write_exception(child_stdin, e, tb)
                if self.log:
                    if str(e):
                        self.log.exception('%s: %s' % (e.__class__.__name__, e))
                    else:
                        self.log.exception('%s' % (e.__class__.__name__,))
            else:
                if self.log and not self.is_spam(fnname, *args):
                    self.log.result(shortrepr(answer))
                try:
                    write_message(child_stdin, 0)  # error code - 0 for ok
                    write_message(child_stdin, answer, resulttype)
                    child_stdin.flush()
                except (IOError, OSError):
                    # likely cause: subprocess is dead, child_stdin closed
                    if self.poll() is not None:
                        break
                    else:
                        raise
        returncode = self.wait()
        return returncode

    def is_spam(self, fnname, *args):
        # To hide the spamming amounts of reads and writes to stdin and stdout
        # in interactive sessions
        return (fnname in ('ll_os.ll_os_read', 'll_os.ll_os_write') and
                args[0] in (0, 1, 2))

    def handle_message(self, fnname, *args):
        if '__' in fnname:
            raise ValueError("unsafe fnname")
        try:
            handler = getattr(self, 'do_' + fnname.replace('.', '__'))
        except AttributeError:
            raise RuntimeError("no handler for this function")
        resulttype = getattr(handler, 'resulttype', None)
        return handler(*args), resulttype


class SimpleIOSandboxedProc(SandboxedProc):
    """Control a sandboxed subprocess which is only allowed to read from
    its stdin and write to its stdout and stderr.
    """
    _input = None
    _output = None
    _error = None
    inputlogfile = None

    def communicate(self, input=None):
        """Send data to stdin. Read data from stdout and stderr,
        until end-of-file is reached. Wait for process to terminate.
        """
        import cStringIO
        if input:
            if isinstance(input, str):
                input = cStringIO.StringIO(input)
            self._input = input
        self._output = cStringIO.StringIO()
        self._error = cStringIO.StringIO()
        self.handle_forever()
        output = self._output.getvalue()
        self._output = None
        error = self._error.getvalue()
        self._error = None
        return (output, error)

    def interact(self, stdin=None, stdout=None, stderr=None):
        """Interact with the subprocess.  By default, stdin, stdout and
        stderr are set to the ones from 'sys'."""
        import sys
        self._input  = stdin  or sys.stdin
        self._output = stdout or sys.stdout
        self._error  = stderr or sys.stderr
        returncode = self.handle_until_return()
        if returncode != 0:
            if os.name == 'posix' and returncode < 0:
                print >> self._error, "[Subprocess killed by %s]" % (
                    signal_name(-returncode),)
            else:
                print >> self._error, "[Subprocess exit code: %d]" % (
                    returncode,)
        self._input = None
        self._output = None
        self._error = None
        return returncode

    def setlogfile(self, filename):
        self.inputlogfile = open(filename, 'a')

    def do_ll_os__ll_os_read(self, fd, size):
        if fd == 0:
            if self._input is None:
                return ""
            elif (getattr(self, 'virtual_console_isatty', False) or
                  self._input.isatty()):
                # don't wait for all 'size' chars if reading from a tty,
                # to avoid blocking.  Instead, stop after reading a line.

                # For now, waiting at the interactive console is the
                # only time that counts as idle.
                self.enter_idle()
                try:
                    inputdata = self._input.readline(size)
                finally:
                    self.leave_idle()
            else:
                inputdata = self._input.read(size)
            if self.inputlogfile is not None:
                self.inputlogfile.write(inputdata)
            return inputdata
        raise OSError("trying to read from fd %d" % (fd,))

    def do_ll_os__ll_os_write(self, fd, data):
        if fd == 1:
            self._output.write(data)
            return len(data)
        if fd == 2:
            self._error.write(data)
            return len(data)
        raise OSError("trying to write to fd %d" % (fd,))

    # let's allow access to the real time
    def do_ll_time__ll_time_sleep(self, seconds):
        # regularly check for timeouts that could have killed the
        # subprocess
        while seconds > 5.0:
            time.sleep(5.0)
            seconds -= 5.0
            if self.poll() is not None:   # subprocess finished?
                return
        time.sleep(seconds)

    def do_ll_time__ll_time_time(self):
        return time.time()

    def do_ll_time__ll_time_clock(self):
        # measuring the CPU time of the controller process has
        # not much meaning, so let's emulate this and return
        # the real time elapsed since the first call to clock()
        # (this is one of the behaviors allowed by the docs)
        try:
            starttime = self.starttime
        except AttributeError:
            starttime = self.starttime = time.time()
        return time.time() - starttime

class VirtualizedSandboxedProc(SandboxedProc):
    """Control a virtualized sandboxed process, which is given a custom
    view on the filesystem and a custom environment.
    """
    virtual_env = {}
    virtual_cwd = '/tmp'
    virtual_console_isatty = False
    virtual_fd_range = range(3, 50)

    def __init__(self, *args, **kwds):
        super(VirtualizedSandboxedProc, self).__init__(*args, **kwds)
        self.virtual_root = self.build_virtual_root()
        self.open_fds = {}   # {virtual_fd: (real_file_object, node)}

    def build_virtual_root(self):
        raise NotImplementedError("must be overridden")

    def do_ll_os__ll_os_envitems(self):
        return self.virtual_env.items()

    def do_ll_os__ll_os_getenv(self, name):
        return self.virtual_env.get(name)

    def translate_path(self, vpath):
        # XXX this assumes posix vpaths for now, but os-specific real paths
        vpath = posixpath.normpath(posixpath.join(self.virtual_cwd, vpath))
        dirnode = self.virtual_root
        components = [component for component in vpath.split('/')]
        for component in components[:-1]:
            if component:
                dirnode = dirnode.join(component)
                if dirnode.kind != stat.S_IFDIR:
                    raise OSError(errno.ENOTDIR, component)
        return dirnode, components[-1]

    def get_node(self, vpath):
        dirnode, name = self.translate_path(vpath)
        if name:
            node = dirnode.join(name)
        else:
            node = dirnode
        if self.log:
            self.log.vpath('%r => %r' % (vpath, node))
        return node

    def do_ll_os__ll_os_stat(self, vpathname):
        node = self.get_node(vpathname)
        return node.stat()
    do_ll_os__ll_os_stat.resulttype = RESULTTYPE_STATRESULT

    do_ll_os__ll_os_lstat = do_ll_os__ll_os_stat

    def do_ll_os__ll_os_access(self, vpathname, mode):
        try:
            node = self.get_node(vpathname)
        except OSError as e:
            if e.errno == errno.ENOENT:
                return False
            raise
        return node.access(mode)

    def do_ll_os__ll_os_isatty(self, fd):
        return self.virtual_console_isatty and fd in (0, 1, 2)

    def allocate_fd(self, f, node=None):
        for fd in self.virtual_fd_range:
            if fd not in self.open_fds:
                self.open_fds[fd] = (f, node)
                return fd
        else:
            raise OSError(errno.EMFILE, "trying to open too many files")

    def get_fd(self, fd, throw=True):
        """Get the objects implementing file descriptor `fd`.

        Returns a pair, (open file, vfs node)

        `throw`: if true, raise OSError for bad fd, else return (None, None).
        """
        try:
            f, node = self.open_fds[fd]
        except KeyError:
            if throw:
                raise OSError(errno.EBADF, "bad file descriptor")
            return None, None
        return f, node

    def get_file(self, fd, throw=True):
        """Return the open file for file descriptor `fd`."""
        return self.get_fd(fd, throw)[0]

    def do_ll_os__ll_os_open(self, vpathname, flags, mode):
        node = self.get_node(vpathname)
        if flags & (os.O_RDONLY|os.O_WRONLY|os.O_RDWR) != os.O_RDONLY:
            raise OSError(errno.EPERM, "write access denied")
        # all other flags are ignored
        f = node.open()
        return self.allocate_fd(f, node)

    def do_ll_os__ll_os_close(self, fd):
        f = self.get_file(fd)
        del self.open_fds[fd]
        f.close()

    def do_ll_os__ll_os_read(self, fd, size):
        f = self.get_file(fd, throw=False)
        if f is None:
            return super(VirtualizedSandboxedProc, self).do_ll_os__ll_os_read(
                fd, size)
        else:
            if not (0 <= size <= sys.maxint):
                raise OSError(errno.EINVAL, "invalid read size")
            # don't try to read more than 256KB at once here
            return f.read(min(size, 256*1024))

    def do_ll_os__ll_os_fstat(self, fd):
        f, node = self.get_fd(fd)
        return node.stat()
    do_ll_os__ll_os_fstat.resulttype = RESULTTYPE_STATRESULT

    def do_ll_os__ll_os_lseek(self, fd, pos, how):
        f = self.get_file(fd)
        f.seek(pos, how)
        return f.tell()
    do_ll_os__ll_os_lseek.resulttype = RESULTTYPE_LONGLONG

    def do_ll_os__ll_os_getcwd(self):
        return self.virtual_cwd

    def do_ll_os__ll_os_strerror(self, errnum):
        # unsure if this shouldn't be considered safeboxsafe
        return os.strerror(errnum) or ('Unknown error %d' % (errnum,))

    def do_ll_os__ll_os_listdir(self, vpathname):
        node = self.get_node(vpathname)
        return node.keys()

    def do_ll_os__ll_os_unlink(self, vpathname):
        raise OSError(errno.EPERM, "write access denied")

    def do_ll_os__ll_os_mkdir(self, vpathname, mode=None):
        raise OSError(errno.EPERM, "write access denied")

    def do_ll_os__ll_os_getuid(self):
        return UID
    do_ll_os__ll_os_geteuid = do_ll_os__ll_os_getuid

    def do_ll_os__ll_os_getgid(self):
        return GID
    do_ll_os__ll_os_getegid = do_ll_os__ll_os_getgid


class VirtualizedSocketProc(VirtualizedSandboxedProc):
    """ Extends VirtualizedSandboxProc with socket
    options, ie tcp://host:port as args to os.open
    """
    def __init__(self, *args, **kwds):
        super(VirtualizedSocketProc, self).__init__(*args, **kwds)
        self.sockets = {}

    def do_ll_os__ll_os_open(self, name, flags, mode):
        if not name.startswith("tcp://"):
            return super(VirtualizedSocketProc, self).do_ll_os__ll_os_open(
                name, flags, mode)
        import socket
        host, port = name[6:].split(":")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((host, int(port)))
        fd = self.allocate_fd(sock)
        self.sockets[fd] = True
        return fd

    def do_ll_os__ll_os_read(self, fd, size):
        if fd in self.sockets:
            return self.get_file(fd).recv(size)
        return super(VirtualizedSocketProc, self).do_ll_os__ll_os_read(
            fd, size)

    def do_ll_os__ll_os_write(self, fd, data):
        if fd in self.sockets:
            return self.get_file(fd).send(data)
        return super(VirtualizedSocketProc, self).do_ll_os__ll_os_write(
            fd, data)

