from rpython.rlib import rwin32
from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    applevel_name = '__exceptions__'
    appleveldefs = {}

    interpleveldefs = {
        'ArithmeticError' : 'interp_exceptions.W_ArithmeticError',
        'AssertionError' : 'interp_exceptions.W_AssertionError',
        'AttributeError' : 'interp_exceptions.W_AttributeError',
        'BaseException' : 'interp_exceptions.W_BaseException',
        'BlockingIOError': 'interp_exceptions.W_BlockingIOError',
        'BrokenPipeError': 'interp_exceptions.W_BrokenPipeError',
        'BufferError' : 'interp_exceptions.W_BufferError',
        'BytesWarning'  : 'interp_exceptions.W_BytesWarning',
        'ChildProcessError': 'interp_exceptions.W_ChildProcessError',
        'ConnectionAbortedError': 'interp_exceptions.W_ConnectionAbortedError',
        'ConnectionError': 'interp_exceptions.W_ConnectionError',
        'ConnectionRefusedError': 'interp_exceptions.W_ConnectionRefusedError',
        'ConnectionResetError': 'interp_exceptions.W_ConnectionResetError',
        'DeprecationWarning' : 'interp_exceptions.W_DeprecationWarning',
        'EOFError' : 'interp_exceptions.W_EOFError',
        'EnvironmentError' : 'interp_exceptions.W_OSError',
        'Exception' : 'interp_exceptions.W_Exception',
        'FileExistsError': 'interp_exceptions.W_FileExistsError',
        'FileNotFoundError': 'interp_exceptions.W_FileNotFoundError',
        'FloatingPointError' : 'interp_exceptions.W_FloatingPointError',
        'FutureWarning' : 'interp_exceptions.W_FutureWarning',
        'GeneratorExit' : 'interp_exceptions.W_GeneratorExit',
        'IOError' : 'interp_exceptions.W_OSError',
        'ImportError' : 'interp_exceptions.W_ImportError',
        'ImportWarning' : 'interp_exceptions.W_ImportWarning',
        'IndentationError' : 'interp_exceptions.W_IndentationError',
        'IndexError' : 'interp_exceptions.W_IndexError',
        'InterruptedError': 'interp_exceptions.W_InterruptedError',
        'IsADirectoryError': 'interp_exceptions.W_IsADirectoryError',
        'KeyError' : 'interp_exceptions.W_KeyError',
        'KeyboardInterrupt' : 'interp_exceptions.W_KeyboardInterrupt',
        'LookupError' : 'interp_exceptions.W_LookupError',
        'MemoryError' : 'interp_exceptions.W_MemoryError',
        'ModuleNotFoundError': 'interp_exceptions.W_ModuleNotFoundError',
        'NameError' : 'interp_exceptions.W_NameError',
        'NotADirectoryError': 'interp_exceptions.W_NotADirectoryError',
        'NotImplementedError' : 'interp_exceptions.W_NotImplementedError',
        'OSError' : 'interp_exceptions.W_OSError',
        'OverflowError' : 'interp_exceptions.W_OverflowError',
        'PendingDeprecationWarning' : 'interp_exceptions.W_PendingDeprecationWarning',
        'PermissionError': 'interp_exceptions.W_PermissionError',
        'ProcessLookupError': 'interp_exceptions.W_ProcessLookupError',
        'RecursionError' : 'interp_exceptions.W_RecursionError',
        'ReferenceError' : 'interp_exceptions.W_ReferenceError',
        'ResourceWarning'  : 'interp_exceptions.W_ResourceWarning',
        'RuntimeError' : 'interp_exceptions.W_RuntimeError',
        'RuntimeWarning' : 'interp_exceptions.W_RuntimeWarning',
        'StopAsyncIteration' : 'interp_exceptions.W_StopAsyncIteration',
        'StopIteration' : 'interp_exceptions.W_StopIteration',
        'SyntaxError' : 'interp_exceptions.W_SyntaxError',
        'SyntaxWarning' : 'interp_exceptions.W_SyntaxWarning',
        'SystemError' : 'interp_exceptions.W_SystemError',
        'SystemExit' : 'interp_exceptions.W_SystemExit',
        'TabError' : 'interp_exceptions.W_TabError',
        'TimeoutError': 'interp_exceptions.W_TimeoutError',
        'TypeError' : 'interp_exceptions.W_TypeError',
        'UnboundLocalError' : 'interp_exceptions.W_UnboundLocalError',
        'UnicodeDecodeError' : 'interp_exceptions.W_UnicodeDecodeError',
        'UnicodeEncodeError' : 'interp_exceptions.W_UnicodeEncodeError',
        'UnicodeError' : 'interp_exceptions.W_UnicodeError',
        'UnicodeTranslateError' : 'interp_exceptions.W_UnicodeTranslateError',
        'UnicodeWarning' : 'interp_exceptions.W_UnicodeWarning',
        'UserWarning' : 'interp_exceptions.W_UserWarning',
        'ValueError' : 'interp_exceptions.W_ValueError',
        'Warning' : 'interp_exceptions.W_Warning',
        'ZeroDivisionError' : 'interp_exceptions.W_ZeroDivisionError',
        }

    if rwin32.WIN32:
        interpleveldefs['WindowsError'] = 'interp_exceptions.W_OSError'

    def setup_after_space_initialization(self):
        from pypy.objspace.std.transparent import register_proxyable
        from pypy.module.exceptions import interp_exceptions

        for name, exc in interp_exceptions.__dict__.items():
            if isinstance(exc, type) and issubclass(exc, interp_exceptions.W_BaseException):
                register_proxyable(self.space, exc)
