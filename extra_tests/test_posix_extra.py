import pytest
import sys, os, subprocess


CODE = """
import sys, os, _thread, time

fd1, fd2 = os.pipe()
f1 = os.fdopen(fd1, 'rb', 0)
f2 = os.fdopen(fd2, 'wb', 0)

def f():
    print("thread started")
    x = f1.read(1)
    assert x == b"X"
    print("thread exit")

_thread.start_new_thread(f, ())
time.sleep(0.5)
if os.fork() == 0:   # in the child
    time.sleep(0.5)
    x = f1.read(1)
    assert x == b"Y"
    print("ok!")
    sys.exit()

f2.write(b"X")   # in the parent
f2.write(b"Y")   # in the parent
time.sleep(1.0)
"""


@pytest.mark.skipif("not getattr(os, 'fork', None)")
def test_thread_fork_file_lock():
    output = subprocess.check_output([sys.executable, '-u', '-c', CODE])
    assert output.splitlines() == [
        b'thread started',
        b'thread exit',
        b'ok!']
