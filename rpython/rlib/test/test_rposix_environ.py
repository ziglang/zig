from rpython.translator.c.test.test_genc import compile
import os

def test_environ_items():
    def foo(x):
        if x:
            return len(os.environ.items())
        else:
            return 0

    f = compile(foo, [int], backendopt=False)
    assert f(1) > 0

def test_unset_error():
    import sys
    def foo(x):
        if x:
            os.environ['TEST'] = 'STRING'
            assert os.environ['TEST'] == 'STRING'
            del os.environ['TEST']
            try:
                del os.environ['key=']
            except (KeyError, OSError):
                return 1
            return 2
        else:
            return 0

    f = compile(foo, [int], backendopt=False)
    if sys.platform.startswith('win'):
        # Do not open error dialog box
        import ctypes
        SEM_NOGPFAULTERRORBOX = 0x0002 # From MSDN
        old_err_mode = ctypes.windll.kernel32.GetErrorMode()
        new_err_mode = old_err_mode | SEM_NOGPFAULTERRORBOX
        ctypes.windll.kernel32.SetErrorMode(new_err_mode)
    assert f(1) == 1
    if sys.platform.startswith('win'):
        ctypes.windll.kernel32.SetErrorMode(old_err_mode)
