import os

# Tests variant functions which also accept file descriptors,
# dir_fd and follow_symlinks.
def test_have_functions():
    assert os.stat in os.supports_fd  # fstat() is supported everywhere
    if os.name != 'nt':
        assert os.chdir in os.supports_fd  # fchdir()
    else:
        assert os.chdir not in os.supports_fd
    if os.name == 'posix':
        assert os.open in os.supports_dir_fd  # openat()

def test_popen():
    for i in range(5):
        stream = os.popen('echo 1')
        res = stream.read()
        assert res == '1\n'
        assert stream.close() is None

def test_popen_with():
    stream = os.popen('echo 1')
    with stream as fp:
        res = fp.read()
        assert res == '1\n'

def test_pickle():
    import pickle
    st = os.stat('.')
    # print(type(st).__module__)
    s = pickle.dumps(st)
    # print(repr(s))
    new = pickle.loads(s)
    assert new == st
    assert type(new) is type(st)

if hasattr(os, "fork"):
    def test_fork_hook_creates_thread_bug():
        import threading
        def daemon():
            while 1:
                time.sleep(10)

        daemon_thread = None
        def create_thread():
            nonlocal daemon_thread
            daemon_thread = threading.Thread(name="b", target=daemon, daemon=True)
            daemon_thread.start()

        os.register_at_fork(after_in_child=create_thread)
        pid = os.fork()
        if pid == 0:   # child
            os._exit(daemon_thread._ident in threading._active)

        pid1, status1 = os.waitpid(pid, 0)
        assert status1
