import os

import py
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform as platform
from rpython.translator import cdir
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib import rposix

from pypy.interpreter.error import (
    OperationError, oefmt, wrap_oserror)
from pypy.interpreter.gateway import unwrap_spec
from pypy.module.posix.interp_posix import run_fork_hooks

thisdir = py.path.local(__file__).dirpath()

class CConfig:
    _compilation_info_ = ExternalCompilationInfo(
        includes=['unistd.h', 'sys/syscall.h', 'sys/stat.h', 'grp.h'])
    HAVE_SYS_SYSCALL_H = platform.Has("syscall")
    HAVE_SYS_STAT_H = platform.Has("stat")
    HAVE_SETSID = platform.Has("setsid")
    HAVE_SETGROUPS = platform.Has("setgroups")
    NGROUPS_MAX = platform.DefinedConstantInteger('NGROUPS_MAX')
    HAVE_SETREGID = platform.Has("setregid")
    HAVE_SETREUID = platform.Has("setreuid")

    uid_t = platform.SimpleType("uid_t")
    gid_t = platform.SimpleType("gid_t")

config = platform.configure(CConfig)

eci = ExternalCompilationInfo(
    includes=[thisdir.join('_posixsubprocess.h')],
    include_dirs=[str(thisdir), cdir],
    separate_module_files=[thisdir.join('_posixsubprocess.c')])

compile_extra = []
if config['HAVE_SYS_SYSCALL_H']:
    compile_extra.append("-DHAVE_SYS_SYSCALL_H")
if config['HAVE_SYS_STAT_H']:
    compile_extra.append("-DHAVE_SYS_STAT_H")
if config['HAVE_SETSID']:
    compile_extra.append("-DHAVE_SETSID")
HAVE_SETGROUPS = config['HAVE_SETGROUPS']
if HAVE_SETGROUPS:
    compile_extra.append("-DHAVE_SETGROUPS")
HAVE_SETREGID = config['HAVE_SETREGID']
if HAVE_SETREGID:
    compile_extra.append("-DHAVE_SETREGID")
HAVE_SETREUID = config['HAVE_SETREUID']
if HAVE_SETREUID:
    compile_extra.append("-DHAVE_SETREUID")
gid_t = config['gid_t']
uid_t = config['uid_t']
if config["NGROUPS_MAX"] is not None:
    MAX_GROUPS = config['NGROUPS_MAX']
else:
    MAX_GROUPS = 64

class CConfig:
    _compilation_info_ = ExternalCompilationInfo(includes=['dirent.h'])
    HAVE_DIRENT_H = platform.Has("opendir")

config = platform.configure(CConfig)

if config['HAVE_DIRENT_H']:
    compile_extra.append("-DHAVE_DIRENT_H")

eci = eci.merge(
    rposix.eci_inheritable,
    ExternalCompilationInfo(
        compile_extra=compile_extra))

c_child_exec = rffi.llexternal(
    'pypy_subprocess_child_exec',
    [rffi.CCHARPP, rffi.CCHARPP, rffi.CCHARPP, rffi.CCHARP,
     rffi.INT, rffi.INT, rffi.INT, rffi.INT, rffi.INT, rffi.INT,
     rffi.INT, rffi.INT, rffi.INT, rffi.INT, rffi.INT,
     rffi.INT, gid_t, # call_setgid, gid
     rffi.INT, rffi.SIZE_T, rffi.CArrayPtr(gid_t), # call_setgroups, groups_size, groups
     rffi.INT, uid_t, rffi.INT, # call_setuid, uid child_umask
     rffi.CArrayPtr(rffi.LONG), lltype.Signed,
     lltype.Ptr(lltype.FuncType([rffi.VOIDP], rffi.INT)), rffi.VOIDP],
    lltype.Void,
    compilation_info=eci,
    releasegil=True)
c_init = rffi.llexternal(
    'pypy_subprocess_init',
    [], lltype.Void,
    compilation_info=eci,
    releasegil=True)


class PreexecCallback:
    def __init__(self):
        self.space = None
        self.w_preexec_fn = None

    @staticmethod
    def run_function(unused):
        self = preexec
        if self.w_preexec_fn:
            try:
                self.space.call_function(self.w_preexec_fn)
            except OperationError:
                return rffi.cast(rffi.INT, 0)
        return rffi.cast(rffi.INT, 1)
preexec = PreexecCallback()


def build_fd_sequence(space, w_fd_list):
    result = [space.int_w(w_fd)
              for w_fd in space.unpackiterable(w_fd_list)]
    prev_fd = -1
    for fd in result:
        if fd < 0 or fd < prev_fd or fd > 1 << 30:
            raise oefmt(space.w_ValueError, "bad value(s) in fds_to_keep")
    return result


def seqstr2charpp(space, w_seqstr):
    """Sequence of bytes -> char**, NULL terminated"""
    w_iter = space.iter(w_seqstr)
    return rffi.liststr2charpp([space.bytes0_w(space.next(w_iter))
                                for i in range(space.len_w(w_seqstr))])


@unwrap_spec(p2cread=int, p2cwrite=int, c2pread=int, c2pwrite=int,
             errread=int, errwrite=int, errpipe_read=int, errpipe_write=int,
             restore_signals=int, call_setsid=int, child_umask=int)
def fork_exec(space, w_process_args, w_executable_list,
              w_close_fds, w_fds_to_keep, w_cwd, w_env_list,
              p2cread, p2cwrite, c2pread, c2pwrite,
              errread, errwrite, errpipe_read, errpipe_write,
              restore_signals, call_setsid,
              w_gid, w_groups_list, w_uid, child_umask,
              w_preexec_fn):
    """\
    fork_exec(args, executable_list, close_fds, cwd, env,
              p2cread, p2cwrite, c2pread, c2pwrite,
              errread, errwrite, errpipe_read, errpipe_write,
              restore_signals, call_setsid, preexec_fn)

    Forks a child process, closes parent file descriptors as appropriate in the
    child and dups the few that are needed before calling exec() in the child
    process.

    The preexec_fn, if supplied, will be called immediately before exec.
    WARNING: preexec_fn is NOT SAFE if your application uses threads.
             It may trigger infrequent, difficult to debug deadlocks.

    If an error occurs in the child process before the exec, it is
    serialized and written to the errpipe_write fd per subprocess.py.

    Returns: the child process's PID.

    Raises: Only on an error in the parent process.
    """
    close_fds = space.is_true(w_close_fds)
    if close_fds and errpipe_write < 3:  # precondition
        raise oefmt(space.w_ValueError, "errpipe_write must be >= 3")
    fds_to_keep = build_fd_sequence(space, w_fds_to_keep)

    # No need to disable GC in PyPy:
    # - gc.disable() only disables __del__ anyway.
    # - appelvel __del__ are only called at specific points of the
    #   interpreter.

    l_exec_array = lltype.nullptr(rffi.CCHARPP.TO)
    l_argv = lltype.nullptr(rffi.CCHARPP.TO)
    l_envp = lltype.nullptr(rffi.CCHARPP.TO)
    l_cwd = lltype.nullptr(rffi.CCHARP.TO)
    l_fds_to_keep = lltype.nullptr(rffi.CArrayPtr(rffi.LONG).TO)
    l_groups = lltype.nullptr(rffi.CArrayPtr(gid_t).TO)

    # Convert args and env into appropriate arguments for exec()
    # These conversions are done in the parent process to avoid allocating
    # or freeing memory in the child process.
    try:
        l_exec_array = seqstr2charpp(space, w_executable_list)

        if not space.is_none(w_process_args):
            w_iter = space.iter(w_process_args)
            argv = [space.fsencode_w(space.next(w_iter))
                    for i in range(space.len_w(w_process_args))]
            l_argv = rffi.liststr2charpp(argv)

        if not space.is_none(w_env_list):
            l_envp = seqstr2charpp(space, w_env_list)

        l_fds_to_keep = lltype.malloc(rffi.CArrayPtr(rffi.LONG).TO,
                                      len(fds_to_keep) + 1, flavor='raw')
        for i in range(len(fds_to_keep)):
            l_fds_to_keep[i] = fds_to_keep[i]

        if not space.is_none(w_preexec_fn):
            preexec.space = space
            preexec.w_preexec_fn = w_preexec_fn
            need_after_fork = 1
        else:
            preexec.w_preexec_fn = None
            need_after_fork = 0

        if not space.is_none(w_cwd):
            cwd = space.fsencode_w(w_cwd)
            l_cwd = rffi.str2charp(cwd)

        call_setgroups = 0
        num_groups = 0
        if not space.is_none(w_groups_list):
            if not HAVE_SETGROUPS:
                raise oefmt(space.w_SystemError, "bad internal call, setgroups not supported")
            groups_w = space.unpackiterable(w_groups_list)

            if len(groups_w) > MAX_GROUPS:
                raise oefmt(space.w_ValueError, "too many groups")
            l_groups = lltype.malloc(rffi.CArrayPtr(gid_t).TO,
                                     len(groups_w), flavor='raw')
            for i, w_group in enumerate(groups_w):
                l_groups[i] = rffi.cast(gid_t, space.c_uid_t_w(w_group))
            num_groups = len(groups_w)
            call_setgroups = 1

        call_setgid = 0
        gid = rffi.cast(gid_t, 0)
        if not space.is_none(w_gid):
            if not HAVE_SETREGID:
                raise oefmt(space.w_SystemError, "bad internal call, setregid not supported")
            call_setgid = 1
            gid = rffi.cast(gid_t, space.c_uid_t_w(w_gid))

        call_setuid = 0
        uid = rffi.cast(uid_t, 0)
        if not space.is_none(w_uid):
            if not HAVE_SETREUID:
                raise oefmt(space.w_SystemError, "bad internal call, setreuid not supported")
            call_setuid = 1
            uid = rffi.cast(uid_t, space.c_uid_t_w(w_uid))

        if need_after_fork:
            run_fork_hooks('before', space)

        try:
            try:
                pid = os.fork()
            except OSError as e:
                raise wrap_oserror(space, e)

            if pid == 0:
                # Child process
                # Code from here to _exit() must only use
                # async-signal-safe functions, listed at `man 7 signal`
                # http://www.opengroup.org/onlinepubs/009695399/functions/xsh_chap02_04.html.
                if not space.is_none(w_preexec_fn):
                    # We'll be calling back into Python later so we need
                    # to do this. This call may not be async-signal-safe
                    # but neither is calling back into Python.  The user
                    # asked us to use hope as a strategy to avoid
                    # deadlock...
                    run_fork_hooks('child', space)

                c_child_exec(
                    l_exec_array, l_argv, l_envp, l_cwd,
                    p2cread, p2cwrite, c2pread, c2pwrite,
                    errread, errwrite, errpipe_read, errpipe_write,
                    close_fds, restore_signals, call_setsid,
                    call_setgid, gid, call_setgroups, num_groups, l_groups,
                    call_setuid, uid, child_umask,
                    l_fds_to_keep, len(fds_to_keep),
                    PreexecCallback.run_function, None)
                os._exit(255)
        finally:
            # parent process
            if need_after_fork:
                run_fork_hooks('parent', space)

    finally:
        preexec.w_preexec_fn = None

        if l_cwd:
            rffi.free_charp(l_cwd)
        if l_envp:
            rffi.free_charpp(l_envp)
        if l_argv:
            rffi.free_charpp(l_argv)
        if l_exec_array:
            rffi.free_charpp(l_exec_array)
        if l_fds_to_keep:
            lltype.free(l_fds_to_keep, flavor='raw')
        if l_groups:
            lltype.free(l_groups, flavor='raw')

    return space.newint(pid)
