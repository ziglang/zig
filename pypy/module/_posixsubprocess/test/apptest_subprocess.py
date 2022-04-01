# spaceconfig = {"usemodules": ["_posixsubprocess", "signal", "fcntl", "select", "time", "struct"]}
import pytest

_posixsubprocess = pytest.importorskip('_posixsubprocess')

from os.path import dirname
import traceback  # Work around a recursion limit
import subprocess
import os
import posix
import errno
try:
    import pwd
    import grp
except ImportError:
    pwd = grp = None

directory = dirname(__file__)

# XXX write more tests

def test_close_fds_true():
    fds = os.pipe()

    open_fds = set(fds)
    # add a bunch more fds
    for _ in range(9):
        fd = os.open("/dev/null", os.O_RDONLY)
        open_fds.add(fd)

    p = subprocess.Popen(['/usr/bin/env', 'python', os.path.join(directory, 'fd_status.py')], stdout=subprocess.PIPE, close_fds=True)
    output, ignored = p.communicate()
    remaining_fds = set(map(int, output.split(b',')))

    assert not (remaining_fds & open_fds), "Some fds were left open"
    assert 1 in remaining_fds, "Subprocess failed"

def test_start_new_session():
    # For code coverage of calling setsid().  We don't care if we get an
    # EPERM error from it depending on the test execution environment, that
    # still indicates that it was called.
    try:
        output = subprocess.check_output(
                ['/usr/bin/env', 'python', "-c",
                 "import os; print(os.getpgid(os.getpid()))"],
                start_new_session=True)
    except OSError as e:
        if e.errno != errno.EPERM:
            raise
    else:
        parent_pgid = os.getpgid(os.getpid())
        child_pgid = int(output)
        assert parent_pgid != child_pgid

def test_cpython_issue15736():
    n = 0
    class Z(object):
        def __len__(self):
            import sys
            return sys.maxsize + n
        def __getitem__(self, i):
            return b'x'
    pytest.raises(MemoryError, _posixsubprocess.fork_exec,
           1,Z(),3,(1, 2),5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)
    n = 1
    pytest.raises(OverflowError, _posixsubprocess.fork_exec,
           1,Z(),3,(1, 2),5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)

def test_pass_fds_make_inheritable():
    fd1, fd2 = posix.pipe()
    assert posix.get_inheritable(fd1) is False
    assert posix.get_inheritable(fd2) is False

    subprocess.check_call(['/usr/bin/env', 'python', '-c',
                           'import os;os.write(%d,b"K")' % fd2],
                          close_fds=True, pass_fds=[fd2])
    res = posix.read(fd1, 1)
    assert res == b"K"
    posix.close(fd1)
    posix.close(fd2)

def test_user():
    uid = os.geteuid()
    test_users = [65534 if uid != 65534 else 65533, uid]

    for user in test_users:
        try:
            output = subprocess.check_output(
                    ["python", "-c",
                     "import os; print(os.getuid())"],
                    user=user)
        except OSError as e:
            if e.errno != errno.EPERM:
                raise
        else:
            if isinstance(user, str):
                user_uid = pwd.getpwnam(user).pw_uid
            else:
                user_uid = user
            child_user = int(output)
            assert child_user == user_uid

    with pytest.raises(ValueError):
        subprocess.check_call(["python", "-c", "pass"], user=-1)

def test_extra_groups():
    gid = os.getegid()
    group_list = [65534 if gid != 65534 else 65533]
    perm_error = False

    try:
        output = subprocess.check_output(
                ["python", "-c",
                 "import os, sys, json; json.dump(os.getgroups(), sys.stdout)"],
                extra_groups=group_list)
    except OSError as ex:
        if ex.errno != errno.EPERM:
            raise
        perm_error = True

    else:
        parent_groups = os.getgroups()
        child_groups = json.loads(output)

        if grp is not None:
            desired_gids = [grp.getgrnam(g).gr_gid if isinstance(g, str) else g
                            for g in group_list]
        else:
            desired_gids = group_list

        if perm_error:
            assert set(child_groups) == set(parent_groups)
        else:
            assert set(desired_gids) == set(parent_groups)

def test_umask():
    import tempfile, shutil
    tmpdir = None
    try:
        tmpdir = tempfile.mkdtemp()
        name = os.path.join(tmpdir, "beans")
        # We set an unusual umask in the child so as a unique mode
        # for us to test the child's touched file for.
        subprocess.check_call(
                ["python", "-c", f"open({name!r}, 'w').close()"],
                umask=0o053)
        # Ignore execute permissions entirely in our test,
        # filesystems could be mounted to ignore or force that.
        st_mode = os.stat(name).st_mode & 0o666
        expected_mode = 0o624
        assert expected_mode == st_mode
    finally:
        if tmpdir is not None:
            shutil.rmtree(tmpdir)

def test_issue_3630():
    import time
    # Make sure the registered callback functions are not called unless
    # fork_exec has a preexec_fn

    tmpfile = 'fork_exec.txt'
    with open(tmpfile, 'w'):
        pass


    # from multiprocessing.util.py
    def spawnv_passfds(path, args, passfds, preexec_fn=None):
        passfds = tuple(sorted(map(int, fds_to_pass)))
        errpipe_read, errpipe_write = os.pipe()
        try:
            return _posixsubprocess.fork_exec(
                args, [os.fsencode(path)], True, passfds, None, None,
                -1, -1, -1, -1, -1, -1, errpipe_read, errpipe_write,
                False, False,
                None, None, None, -1,
                preexec_fn)
        finally:
            os.close(errpipe_read)
            os.close(errpipe_write)

    def preexec_fn():
        pass
    
    def before():
        with open(tmpfile, mode='a') as fid:
            fid.write('before\n')
        print('before hook done')

    def parent():
        print('parent hook')
        for i in range(10):
            time.sleep(0.1)
            with open(tmpfile, mode='r') as fid:
                if 'child' in fid.read():
                    break
        else:
            print('tmpfile not updated')
        with open(tmpfile, mode='a') as fid:
            fid.write('parent\n')
        print('parent hook done')

    def child():
        with open(tmpfile, mode='a') as fid:
            fid.write('child\n')
        print('child hook done')

    os.register_at_fork(before=before, after_in_parent=parent, after_in_child=child)
    fds_to_pass = []
    try:
        fds_to_pass.append(sys.stderr.fileno())
    except Exception:
        pass
    
    r, w = os.pipe()
    fds_to_pass.append(r)
    args = ['ls', '.']
    
    try:
        spawnv_passfds('ls', args, fds_to_pass)
        with open(tmpfile, mode='r') as fid:
            contents = fid.read()
        assert len(contents) == 0

        spawnv_passfds('ls', args, fds_to_pass, preexec_fn=preexec_fn)
        with open(tmpfile, mode='r') as fid:
            contents = fid.read()
        assert 'child' in contents
        assert 'parent' in contents
        assert 'before' in contents
    finally:
        os.remove(tmpfile)

def test_restore_signals():
    import posix as os
    # Copied from lib-python/3/subprocess._execute_child
    # when calling subprocess.check_output(['cat', '/proc/self/status'],
    #       restore_signals=True, universal_newlines=True)
    def check_output(restore_signals):
        c2pread, c2pwrite = os.pipe()
        errpipe_read, errpipe_write = os.pipe()
        try:
            low_fds_to_close = []
            while errpipe_write < 3:
                low_fds_to_close.append(errpipe_write)
                errpipe_write = os.dup(errpipe_write)
            for low_fd in low_fds_to_close:
                os.close(low_fd)
            args = [b'cat', b'/proc/self/status']
            executable_list=[b'/usr/bin/cat']
            close_fds = True
            fds_to_keep = (errpipe_write,)
            cwd = None
            env_list = None
            p2cread = p2cwrite = -1
            errread = errwrite = umask = -1
            call_setsid = False
            preexec_fn = None
            gid = gids = uid = None
            pid = _posixsubprocess.fork_exec(args, executable_list, close_fds,
                        fds_to_keep, cwd, env_list, p2cread, p2cwrite, c2pread,
                        c2pwrite, errread, errwrite, errpipe_read,
                        errpipe_write, restore_signals, call_setsid,
                        gid, gids, uid, umask,
                        preexec_fn)
            os.close(errpipe_write)
            # Wait for exec to fail or succeed; possibly raising an
            # exception (limited in size)
            errpipe_data = bytearray()
            while True:
                part = os.read(errpipe_read, 50000)
                errpipe_data += part
                if not part or len(errpipe_data) > 50000:
                    break
            if errpipe_data:
                newpid, sts = os.waitpid(pid, 0)
                raise RuntimeError('running commande returned %s' % sts)
            out = os.read(c2pread, 50000)
        finally:
            os.close(c2pwrite)
            os.close(c2pread)
            os.close(errpipe_read)
        return out

    sig_ign_mask1 = ''
    sig_ign_mask2 = ''
    for line in check_output(True).splitlines():
        if line.startswith(b'SigIgn'):
            sig_ign_mask1 = line
    for line in check_output(False).splitlines():
        if line.startswith(b'SigIgn'):
            sig_ign_mask2 = line
    assert b'1' not in sig_ign_mask1
    assert sig_ign_mask2 
    assert sig_ign_mask1 != sig_ign_mask2        
