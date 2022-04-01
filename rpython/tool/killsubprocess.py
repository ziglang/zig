"""Kill a subprocess created by subprocess.Popen().
The two Windows versions come from the Python cookbook.
"""
import sys, os

if sys.platform != "win32":
    import signal
    assert hasattr(os, 'kill')

    def killsubprocess(process):
        if process.poll() is None:
            os.kill(process.pid, signal.SIGTERM)

else:
    # on Windows, we need either win32api or ctypes
    try:
        import ctypes
        TerminateProcess = ctypes.windll.kernel32.TerminateProcess
    except ImportError:
        from win32api import TerminateProcess

    def killsubprocess(process):
        if process.poll() is None:
            TerminateProcess(int(process._handle), -1)
