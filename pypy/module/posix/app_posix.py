# NOT_RPYTHON
from _structseq import structseqtype, structseqfield, structseq_new

# XXX we need a way to access the current module's globals more directly...
import errno
import sys
if 'posix' in sys.builtin_module_names:
    import posix
    osname = 'posix'
elif 'nt' in sys.builtin_module_names:
    import nt as posix
    osname = 'nt'
else:
    raise ImportError("XXX")

error = OSError


class stat_result(metaclass=structseqtype):

    name = "os.stat_result"
    __module__ = "os"

    st_mode  = structseqfield(0, "protection bits")
    st_ino   = structseqfield(1, "inode")
    st_dev   = structseqfield(2, "device")
    st_nlink = structseqfield(3, "number of hard links")
    st_uid   = structseqfield(4, "user ID of owner")
    st_gid   = structseqfield(5, "group ID of owner")
    st_size  = structseqfield(6, "total size, in bytes")

    # NOTE: float times are disabled for now, for compatibility with CPython.
    # access to indices 7 to 9 gives the timestamps as integers:
    _integer_atime = structseqfield(7)
    _integer_mtime = structseqfield(8)
    _integer_ctime = structseqfield(9)

    # further fields, not accessible by index (the numbers are still needed
    # but not visible because they are no longer consecutive)
    st_atime = structseqfield(11, "time of last access")
    st_mtime = structseqfield(12, "time of last modification")
    st_ctime = structseqfield(13, "time of last change")

    if "st_blksize" in posix._statfields:
        st_blksize = structseqfield(20, "blocksize for filesystem I/O")
    if "st_blocks" in posix._statfields:
        st_blocks = structseqfield(21, "number of blocks allocated")
    if "st_rdev" in posix._statfields:
        st_rdev = structseqfield(22, "device ID (if special file)")
    if "st_flags" in posix._statfields:
        st_flags = structseqfield(23, "user defined flags for file")

    def __init__(self, *args, **kw):
        # If we have been initialized from a tuple,
        # st_?time might be set to None. Initialize it
        # from the int slots.
        if self.st_atime is None:
            self.__dict__['st_atime'] = self[7]
        if self.st_mtime is None:
            self.__dict__['st_mtime'] = self[8]
        if self.st_ctime is None:
            self.__dict__['st_ctime'] = self[9]

    @property
    def st_atime_ns(self):
        "time of last access in nanoseconds"
        return int(self[7]) * 1000000000 + self.nsec_atime

    @property
    def st_mtime_ns(self):
        "time of last modification in nanoseconds"
        return int(self[8]) * 1000000000 + self.nsec_mtime

    @property
    def st_ctime_ns(self):
        "time of last change in nanoseconds"
        return int(self[9]) * 1000000000 + self.nsec_ctime


class statvfs_result(metaclass=structseqtype):
    """
    Result from statvfs or fstatvfs.

    This object may be accessed either as a tuple of
      (bsize, frsize, blocks, bfree, bavail, files, ffree, favail, flag, namemax),
    or via the attributes f_bsize, f_frsize, f_blocks, f_bfree, and so on.
    """

    name = "os.statvfs_result"
    __module__ = "os"

    f_bsize = structseqfield(0)
    f_frsize = structseqfield(1)
    f_blocks = structseqfield(2)
    f_bfree = structseqfield(3)
    f_bavail = structseqfield(4)
    f_files = structseqfield(5)
    f_ffree = structseqfield(6)
    f_favail = structseqfield(7)
    f_flag = structseqfield(8)
    f_namemax = structseqfield(9)
    f_fsid = structseqfield(20) # gap to make it a non-indexed field


class uname_result(metaclass=structseqtype):

    name = osname + ".uname_result"    # and NOT "os.uname_result"

    sysname  = structseqfield(0, "operating system name")
    nodename = structseqfield(1, "name of machine on network "
                              "(implementation-defined")
    release  = structseqfield(2, "operating system release")
    version  = structseqfield(3, "operating system version")
    machine  = structseqfield(4, "hardware identifier")

class terminal_size(metaclass=structseqtype):

    name = "os.terminal_size"
    __module__ = "os"

    columns  = structseqfield(0, "width of the terminal window in characters")
    lines = structseqfield(1, "height of the terminal window in characters")


class times_result(metaclass=structseqtype):

    name = "posix.times_result"
    __module__ = "posix"

    user = structseqfield(0, "user time")
    system = structseqfield(1, "system time")
    children_user = structseqfield(2, "user time of children")
    children_system = structseqfield(3, "system time of children")
    elapsed = structseqfield(4, "elapsed time since an arbitray point in the past")


class sched_param(metaclass=structseqtype):
    name = "posix.sched_param"
    __module__ = "posix"

    sched_priority = structseqfield(0, "sched_priority")

    def __new__(cls, sched_priority):
        return structseq_new(cls, sched_priority)

def waitstatus_to_exitcode(status):
    """
    Convert a wait status to an exit code.

    On Unix:

    * If WIFEXITED(status) is true, return WEXITSTATUS(status).
    * If WIFSIGNALED(status) is true, return -WTERMSIG(status).
    * Otherwise, raise a ValueError.

    On Windows, return status shifted right by 8 bits.

    On Unix, if the process is being traced or if waitpid() was called with
    WUNTRACED option, the caller must first check if WIFSTOPPED(status) is true.
    This function must not be called if WIFSTOPPED(status) is true.
    """
    if not isinstance(status, int):
        raise TypeError("integer argument expected, got float")
    if sys.platform == "win32":
        return status >> 8
    if posix.WIFEXITED(status):
        exitcode = posix.WEXITSTATUS(status)
        if exitcode < 0: # should not occur in practice
            raise ValueError("invalid WEXITSTATUS: %s" % (exitcode, ))
        return exitcode
    elif posix.WIFSIGNALED(status):
        signum = posix.WTERMSIG(status)
        if signum < 0: # should not occur in practice
            raise ValueError("invalid WTERMSIG: %s" % (exitcode, ))
        return -signum
    elif posix.WIFSTOPPED(status):
        signum = posix.WSTOPSIG(status)
        raise ValueError("process stopped by delivery of signal %s" % (signum, ))
    raise ValueError("invalid wait status %s" % (status, ))


if osname == 'posix':
    def wait():
        """ wait() -> (pid, status)

        Wait for completion of a child process.
        """
        return posix.waitpid(-1, 0)

    def wait3(options):
        """ wait3(options) -> (pid, status, rusage)

        Wait for completion of a child process and provides resource usage information
        """
        from _pypy_wait import wait3
        return wait3(options)

    def wait4(pid, options):
        """ wait4(pid, options) -> (pid, status, rusage)

        Wait for completion of the child process "pid" and provides resource usage information
        """
        from _pypy_wait import wait4
        return wait4(pid, options)

    def urandom(n):
        """urandom(n) -> str

        Return a string of n random bytes suitable for cryptographic use.

        """
        if n < 0:
            raise ValueError("negative argument not allowed")
        try:
            with open('/dev/urandom', 'rb', buffering=0) as fd:
                return fd.read(n)
        except OSError as e:
            if e.errno in (errno.ENOENT, errno.ENXIO, errno.ENODEV, errno.EACCES):
                raise NotImplementedError("/dev/urandom (or equivalent) not found")
            raise
