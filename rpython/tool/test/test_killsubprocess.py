import sys, time
import subprocess
from rpython.tool.killsubprocess import killsubprocess

def waitdead(process):
    for i in range(50):
        time.sleep(0.1)
        if process.poll() is not None:
            break       # ok
    else:
        raise AssertionError("the subprocess did not die within 5 seconds")

def test_killsubprocess():
    popen = subprocess.Popen([sys.executable, '-c', 'raw_input()'],
                             stdin=subprocess.PIPE)
    time.sleep(0.9)
    assert popen.poll() is None
    assert popen.poll() is None
    killsubprocess(popen)
    waitdead(popen)

def test_already_dead_but_no_poll():
    popen = subprocess.Popen([sys.executable, '-c', 'pass'],
                             stdin=subprocess.PIPE)
    time.sleep(3)    # a safe margin to be sure the subprocess is already dead
    killsubprocess(popen)
    assert popen.poll() is not None

def test_already_dead_and_polled():
    popen = subprocess.Popen([sys.executable, '-c', 'pass'],
                             stdin=subprocess.PIPE)
    waitdead(popen)
    killsubprocess(popen)
    assert popen.poll() is not None
