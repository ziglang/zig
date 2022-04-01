import sys
from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib import rposix
from rpython.rlib import rdynload

import os
exec 'import %s as posix' % os.name

class Module(MixedModule):
    """This module provides access to operating system functionality that is
standardized by the C Standard and the POSIX standard (a thinly
disguised Unix interface).  Refer to the library manual and
corresponding Unix manual entries for more information on calls."""

    applevel_name = os.name

    appleveldefs = {
        'error': 'app_posix.error',
        'stat_result': 'app_posix.stat_result',
        'statvfs_result': 'app_posix.statvfs_result',
        'times_result': 'app_posix.times_result',
        'uname_result': 'app_posix.uname_result',
        'urandom': 'app_posix.urandom',
        'terminal_size': 'app_posix.terminal_size',
        'waitstatus_to_exitcode': 'app_posix.waitstatus_to_exitcode',
    }
    if os.name == 'nt':
        del appleveldefs['urandom'] # at interp on win32
        appleveldefs.update({
            'startfile': 'app_startfile.startfile',
        })

    if hasattr(os, 'wait'):
        appleveldefs['wait'] = 'app_posix.wait'
    if hasattr(os, 'wait3'):
        appleveldefs['wait3'] = 'app_posix.wait3'
    if hasattr(os, 'wait4'):
        appleveldefs['wait4'] = 'app_posix.wait4'

    interpleveldefs = {
        'open': 'interp_posix.open',
        'lseek': 'interp_posix.lseek',
        'write': 'interp_posix.write',
        'isatty': 'interp_posix.isatty',
        'read': 'interp_posix.read',
        'close': 'interp_posix.close',
        'closerange': 'interp_posix.closerange',
        'cpu_count': 'interp_posix.cpu_count',

        'fstat': 'interp_posix.fstat',
        'stat': 'interp_posix.stat',
        'lstat': 'interp_posix.lstat',
        'stat_float_times': 'interp_posix.stat_float_times',

        'dup': 'interp_posix.dup',
        'dup2': 'interp_posix.dup2',
        'access': 'interp_posix.access',
        'times': 'interp_posix.times',
        'system': 'interp_posix.system',
        'unlink': 'interp_posix.unlink',
        'remove': 'interp_posix.remove',
        'getcwd': 'interp_posix.getcwd',
        'getcwdb': 'interp_posix.getcwdb',
        'chdir': 'interp_posix.chdir',
        'mkdir': 'interp_posix.mkdir',
        'rmdir': 'interp_posix.rmdir',
        'environ': 'interp_posix.get(space).w_environ',
        'listdir': 'interp_posix.listdir',
        'strerror': 'interp_posix.strerror',
        'pipe': 'interp_posix.pipe',
        'chmod': 'interp_posix.chmod',
        'rename': 'interp_posix.rename',
        'replace': 'interp_posix.replace',
        'link': 'interp_posix.link',
        'umask': 'interp_posix.umask',
        '_exit': 'interp_posix._exit',
        'utime': 'interp_posix.utime',
        '_statfields': 'interp_posix.getstatfields(space)',
        'kill': 'interp_posix.kill',
        'abort': 'interp_posix.abort',
        'urandom': 'interp_posix.urandom',
        'device_encoding': 'interp_posix.device_encoding',
        'get_terminal_size': 'interp_posix.get_terminal_size',
        'symlink': 'interp_posix.symlink',

        'scandir': 'interp_scandir.scandir',
        'DirEntry': 'interp_scandir.W_DirEntry',
        'get_inheritable': 'interp_posix.get_inheritable',
        'set_inheritable': 'interp_posix.set_inheritable',
        'fspath': 'interp_posix.fspath',
        'putenv': 'interp_posix.putenv',
        'unsetenv': 'interp_posix.unsetenv',
        'ftruncate': 'interp_posix.ftruncate',
        'truncate': 'interp_posix.truncate',
    }

    if hasattr(os, 'chown'):
        interpleveldefs['chown'] = 'interp_posix.chown'
    if hasattr(os, 'lchown'):
        interpleveldefs['lchown'] = 'interp_posix.lchown'
    if hasattr(os, 'fchown'):
        interpleveldefs['fchown'] = 'interp_posix.fchown'
    if hasattr(os, 'fchmod'):
        interpleveldefs['fchmod'] = 'interp_posix.fchmod'
    if hasattr(os, 'fsync'):
        interpleveldefs['fsync'] = 'interp_posix.fsync'
    if hasattr(os, 'fdatasync'):
        interpleveldefs['fdatasync'] = 'interp_posix.fdatasync'
    if hasattr(os, 'fchdir'):
        interpleveldefs['fchdir'] = 'interp_posix.fchdir'
    if hasattr(os, 'killpg'):
        interpleveldefs['killpg'] = 'interp_posix.killpg'
    if hasattr(os, 'getpid'):
        interpleveldefs['getpid'] = 'interp_posix.getpid'
    if hasattr(os, 'readlink'):
        interpleveldefs['readlink'] = 'interp_posix.readlink'
    if hasattr(os, 'fork'):
        interpleveldefs['fork'] = 'interp_posix.fork'
        interpleveldefs['register_at_fork'] = 'interp_posix.register_at_fork'
    if hasattr(os, 'openpty'):
        interpleveldefs['openpty'] = 'interp_posix.openpty'
    if hasattr(os, 'forkpty'):
        interpleveldefs['forkpty'] = 'interp_posix.forkpty'
    if hasattr(os, 'waitpid'):
        interpleveldefs['waitpid'] = 'interp_posix.waitpid'
    if hasattr(os, 'execv'):
        interpleveldefs['execv'] = 'interp_posix.execv'
    if hasattr(os, 'execve'):
        interpleveldefs['execve'] = 'interp_posix.execve'
    if hasattr(posix, 'spawnv'):
        interpleveldefs['spawnv'] = 'interp_posix.spawnv'
    if hasattr(posix, 'spawnve'):
        interpleveldefs['spawnve'] = 'interp_posix.spawnve'
    if hasattr(os, 'uname'):
        interpleveldefs['uname'] = 'interp_posix.uname'
    if hasattr(os, 'sysconf'):
        interpleveldefs['sysconf'] = 'interp_posix.sysconf'
        interpleveldefs['sysconf_names'] = 'space.wrap(interp_posix.sysconf_names())'
    if hasattr(os, 'fpathconf'):
        interpleveldefs['fpathconf'] = 'interp_posix.fpathconf'
        interpleveldefs['pathconf_names'] = 'space.wrap(interp_posix.pathconf_names())'
    if hasattr(os, 'pathconf'):
        interpleveldefs['pathconf'] = 'interp_posix.pathconf'
    if hasattr(os, 'confstr'):
        interpleveldefs['confstr'] = 'interp_posix.confstr'
        interpleveldefs['confstr_names'] = 'space.wrap(interp_posix.confstr_names())'
    if hasattr(os, 'ttyname'):
        interpleveldefs['ttyname'] = 'interp_posix.ttyname'
    if hasattr(os, 'getloadavg'):
        interpleveldefs['getloadavg'] = 'interp_posix.getloadavg'
    if hasattr(os, 'makedev'):
        interpleveldefs['makedev'] = 'interp_posix.makedev'
    if hasattr(os, 'major'):
        interpleveldefs['major'] = 'interp_posix.major'
    if hasattr(os, 'minor'):
        interpleveldefs['minor'] = 'interp_posix.minor'
    if hasattr(os, 'mkfifo'):
        interpleveldefs['mkfifo'] = 'interp_posix.mkfifo'
    if hasattr(os, 'mknod'):
        interpleveldefs['mknod'] = 'interp_posix.mknod'
    if hasattr(os, 'nice'):
        interpleveldefs['nice'] = 'interp_posix.nice'
    if hasattr(os, 'getlogin'):
        interpleveldefs['getlogin'] = 'interp_posix.getlogin'
    if hasattr(os, 'ctermid'):
        interpleveldefs['ctermid'] = 'interp_posix.ctermid'
    if hasattr(rposix, 'sched_rr_get_interval'):
        interpleveldefs['sched_rr_get_interval'] = 'interp_posix.sched_rr_get_interval'
    if hasattr(rposix, 'sched_setscheduler'):
        interpleveldefs['sched_setscheduler'] = 'interp_posix.sched_setscheduler'
        interpleveldefs['sched_getscheduler'] = 'interp_posix.sched_getscheduler'
    if hasattr(rposix, 'sched_getparam'):
        interpleveldefs['sched_getparam'] = 'interp_posix.sched_getparam'
        appleveldefs['sched_param'] = 'app_posix.sched_param'
        interpleveldefs['sched_setparam'] = 'interp_posix.sched_setparam'

    for name in ['setsid', 'getuid', 'geteuid', 'getgid', 'getegid', 'setuid',
                 'seteuid', 'setgid', 'setegid', 'getgroups', 'getpgrp',
                 'setpgrp', 'getppid', 'getpgid', 'setpgid', 'setreuid',
                 'setregid', 'getsid', 'setsid', 'fstatvfs', 'statvfs',
                 'setgroups', 'initgroups', 'tcgetpgrp', 'tcsetpgrp',
                 'getresuid', 'getresgid', 'setresuid', 'setresgid']:
        if hasattr(os, name):
            interpleveldefs[name] = 'interp_posix.%s' % (name,)
    if os.name == 'nt':
        interpleveldefs.update({
                '_getfullpathname': 'interp_posix._getfullpathname',
                '_getfileinformation': 'interp_posix._getfileinformation',
                '_getfinalpathname': 'interp_posix._getfinalpathname',
                'get_handle_inheritable': 'interp_posix.get_handle_inheritable',
                'set_handle_inheritable': 'interp_posix.set_handle_inheritable',
                '_path_splitroot': 'interp_posix._path_splitroot',
                '_add_dll_directory': 'interp_posix._add_dll_directory',
                '_remove_dll_directory': 'interp_posix._remove_dll_directory',
        })
    if hasattr(os, 'chroot'):
        interpleveldefs['chroot'] = 'interp_posix.chroot'

    for name in rposix.WAIT_MACROS:
        if hasattr(os, name):
            interpleveldefs[name] = 'interp_posix.' + name

    for _name in ["RTLD_LAZY", "RTLD_NOW", "RTLD_GLOBAL", "RTLD_LOCAL",
                  "RTLD_NODELETE", "RTLD_NOLOAD", "RTLD_DEEPBIND"]:
        if getattr(rdynload.cConfig, _name) is not None:
            interpleveldefs[_name] = 'space.wrap(%d)' % (
                getattr(rdynload.cConfig, _name),)

    # os.py uses this list to build os.supports_dir_fd() and os.supports_fd().
    # Fill with e.g. HAVE_FCHDIR, when os.chdir() supports file descriptors.
    interpleveldefs['_have_functions'] = (
        'space.newlist([space.wrap(x) for x in interp_posix.have_functions])')

    if rposix.HAVE_PIPE2:
        interpleveldefs['pipe2'] = 'interp_posix.pipe2'

    if not rposix._WIN32:
        interpleveldefs['sync'] = 'interp_posix.sync'
        interpleveldefs['get_blocking'] = 'interp_posix.get_blocking'
        interpleveldefs['set_blocking'] = 'interp_posix.set_blocking'
        interpleveldefs['getgrouplist'] = 'interp_posix.getgrouplist'

    if hasattr(rposix, 'getpriority'):
        interpleveldefs['getpriority'] = 'interp_posix.getpriority'
        interpleveldefs['setpriority'] = 'interp_posix.setpriority'
        for _name in ['PRIO_PROCESS', 'PRIO_PGRP', 'PRIO_USER']:
            assert getattr(rposix, _name) is not None, "missing %r" % (_name,)
            interpleveldefs[_name] = 'space.wrap(%d)' % getattr(rposix, _name)

    if sys.platform.startswith('linux'): #hasattr(rposix, 'sendfile'):
        interpleveldefs['sendfile'] = 'interp_posix.sendfile'

    if hasattr(rposix, 'pread'):
        interpleveldefs['pread'] = 'interp_posix.pread'
    if hasattr(rposix, 'pwrite'):
       interpleveldefs['pwrite'] = 'interp_posix.pwrite'

    if hasattr(rposix, 'posix_fadvise'):
        interpleveldefs['posix_fadvise'] = 'interp_posix.posix_fadvise'
        interpleveldefs['posix_fallocate'] = 'interp_posix.posix_fallocate'
        for _name in ['POSIX_FADV_WILLNEED', 'POSIX_FADV_NORMAL', 'POSIX_FADV_SEQUENTIAL',
        'POSIX_FADV_RANDOM', 'POSIX_FADV_NOREUSE', 'POSIX_FADV_DONTNEED']:
            assert getattr(rposix, _name) is not None, "missing %r" % (_name,)
            interpleveldefs[_name] = 'space.wrap(%d)' % getattr(rposix, _name)

    if hasattr(rposix, 'sched_get_priority_max'):
        interpleveldefs['sched_get_priority_max'] = 'interp_posix.sched_get_priority_max'
        interpleveldefs['sched_get_priority_min'] = 'interp_posix.sched_get_priority_min'
        for _name in ['SCHED_FIFO', 'SCHED_RR', 'SCHED_OTHER',
        'SCHED_BATCH']:
            if getattr(rposix, _name) is not None:
                interpleveldefs[_name] = 'space.wrap(%d)' % getattr(rposix, _name)

    if sys.platform.startswith('linux'):
        interpleveldefs['lockf'] = 'interp_posix.lockf'
        for _name in ['F_LOCK', 'F_TLOCK', 'F_ULOCK', 'F_TEST']:
            if getattr(rposix, _name) is not None:
                interpleveldefs[_name] = 'space.wrap(%d)' % getattr(rposix, _name)

    if hasattr(rposix, 'sched_yield'):
        interpleveldefs['sched_yield'] = 'interp_posix.sched_yield'

    for _name in ["O_CLOEXEC"]:
        if getattr(rposix, _name) is not None:
            interpleveldefs[_name] = 'space.wrap(%d)' % getattr(rposix, _name)
    for _name in rposix.constants:
        # note they are prepended with '_'
        if getattr(rposix, _name) is not None:
            interpleveldefs['_' + _name] = 'space.wrap(%d)' % getattr(rposix, _name)

    if hasattr(rposix, 'getxattr'):
        interpleveldefs['getxattr'] = 'interp_posix.getxattr'
        interpleveldefs['setxattr'] = 'interp_posix.setxattr'
        interpleveldefs['removexattr'] = 'interp_posix.removexattr'
        interpleveldefs['listxattr'] = 'interp_posix.listxattr'
        for _name in ['XATTR_SIZE_MAX', 'XATTR_CREATE', 'XATTR_REPLACE']:
            if getattr(rposix, _name) is not None:
                interpleveldefs[_name] = 'space.wrap(%d)' % getattr(rposix, _name)

    if hasattr(rposix, 'memfd_create'):
        interpleveldefs['memfd_create'] = 'interp_posix.memfd_create'
        for name in """
                MFD_CLOEXEC
                MFD_ALLOW_SEALING
                MFD_CLOEXEC
                MFD_HUGETLB
                MFD_HUGE_SHIFT
                MFD_HUGE_MASK
                MFD_HUGE_64KB
                MFD_HUGE_512KB
                MFD_HUGE_1MB
                MFD_HUGE_2MB
                MFD_HUGE_8MB
                MFD_HUGE_16MB
                MFD_HUGE_32MB
                MFD_HUGE_256MB
                MFD_HUGE_512MB
                MFD_HUGE_1GB
                MFD_HUGE_2GB
                MFD_HUGE_16GB
                """.split():
            if getattr(rposix, name, None) is not None:
                interpleveldefs[name] = 'space.wrap(%d)' % getattr(rposix, name)

    def startup(self, space):
        from pypy.module.posix import interp_posix
        from pypy.module.imp import importing
        interp_posix.get(space).startup(space)
        # Import structseq before the full importlib is ready
        importing.importhook(space, '_structseq')

dedup = ['SEEK_SET', 'SEEK_CUR', 'SEEK_END']
if sys.platform != 'win32':
    dedup += ['P_NOWAIT', 'P_NOWAITO', 'P_WAIT']
for constant in dir(os):
    value = getattr(os, constant)
    if constant.isupper() and type(value) is int:
        if constant in dedup:
            # obscure, but these names are not in CPython's posix module
            # and if we put it here then they end up twice in 'os.__all__'
            continue
        Module.interpleveldefs[constant] = "space.wrap(%s)" % value
