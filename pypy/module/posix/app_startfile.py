# NOT_RPYTHON

class CFFIWrapper(object):
    def __init__(self):
        import cffi
        ffi = cffi.FFI()
        ffi.cdef("""
        HINSTANCE ShellExecuteA(HWND, LPCSTR, LPCSTR, LPCSTR, LPCSTR, INT);
        HINSTANCE ShellExecuteW(HWND, LPCWSTR, LPCWSTR, LPCWSTR, LPCWSTR, INT);
        """)
        self.NULL = ffi.NULL
        self.cast = ffi.cast
        self.lib = ffi.dlopen("Shell32.dll")
        self.SW_SHOWNORMAL = 1
        self.getwinerror = ffi.getwinerror

_cffi_wrapper = None


def startfile(filepath, operation=None):
    global _cffi_wrapper
    if _cffi_wrapper is None:
        _cffi_wrapper = CFFIWrapper()
    w = _cffi_wrapper
    #
    if operation is None:
        operation = w.NULL
    if isinstance(filepath, bytes):
        if isinstance(operation, str):
            operation = operation.encode("ascii")
        rc = w.lib.ShellExecuteA(w.NULL, operation, filepath,
                                 w.NULL, w.NULL, w.SW_SHOWNORMAL)
    elif isinstance(filepath, str):
        if isinstance(operation, bytes):
            operation = operation.decode("ascii")
        rc = w.lib.ShellExecuteW(w.NULL, operation, filepath,
                                 w.NULL, w.NULL, w.SW_SHOWNORMAL)
    else:
        raise TypeError("argument 1 must be str or bytes")
    rc = int(w.cast("uintptr_t", rc))
    if rc <= 32:
        code, msg = w.getwinerror()
        raise WindowsError(code, msg, filepath)
