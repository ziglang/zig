"""
Support routines for subprocess and multiprocess module.
Currently, this extension module is only required when using the
modules on Windows.
"""

import sys

if sys.platform != 'win32':
    raise ImportError("The '_winapi' module is only available on Windows", name="_winapi")

# Declare external Win32 functions

if sys.maxsize > 2 ** 31:
    from _pypy_winbase_cffi64 import ffi as _ffi
else:
    from _pypy_winbase_cffi import ffi as _ffi
_kernel32 = _ffi.dlopen('kernel32')

GetVersion = _kernel32.GetVersion
NULL = _ffi.NULL

def SetLastError(errno):
    return _kernel32.SetLastError(errno)

def GetLastError():
    return _kernel32.GetLastError()

def GetACP():
    return _kernel32.GetACP()

# Now the _subprocess module implementation
def raise_WinError(type=WindowsError):
    code, message = _ffi.getwinerror()
    excep = type(None, message, None ,code)
    raise excep

# In CPython PyErr_SetFromWindowsErr converts a windows error into a python object
# Not sure what we should do here.
def RaiseFromWindowsErr(err):
    if err == 0:
       err = _kernel32.GetLastError()

    if err == ERROR_CONNECTION_REFUSED:
        type = ConnectionRefusedError
    elif err == ERROR_CONNECTION_ABORTED:
        type = ConnectionAbortedError
    else:
        type = WindowsError

    raise_WinError(type)

def _int2handle(val):
    return _ffi.cast("HANDLE", val)

def _handle2int(handle):
    return int(_ffi.cast("intptr_t", handle))

def CreatePipe(attributes, size):
    handles = _ffi.new("HANDLE[2]")
    
    res = _kernel32.CreatePipe(handles, handles + 1, NULL, size)

    if not res:
        RaiseFromWindowsErr(GetLastError())

    return _handle2int(handles[0]), _handle2int(handles[1])

def CreateNamedPipe(*args):
    handle = _kernel32.CreateNamedPipeW(*args)
    if handle == INVALID_HANDLE_VALUE:
        RaiseFromWindowsErr(0)
    return _handle2int(handle)

def CreateFile(*args):
    handle = _kernel32.CreateFileW(*args)
    if handle == INVALID_HANDLE_VALUE:
        RaiseFromWindowsErr(0)
    return _handle2int(handle)

def SetNamedPipeHandleState(namedpipe, mode, max_collection_count, collect_data_timeout):
    d0 = _ffi.new('DWORD[1]', [mode])
    if max_collection_count is None:
        d1 = NULL
    else:
        d1 = _ffi.new('DWORD[1]', [max_collection_count])
    if collect_data_timeout is None:
        d2 = NULL
    else:
        d2 = _ffi.new('DWORD[1]', [collect_data_timeout])
    ret = _kernel32.SetNamedPipeHandleState(_int2handle(namedpipe), d0, d1, d2)
    if not ret:
        raise_WinError()

class Overlapped(object):
    def __init__(self, handle):
        self.overlapped = _ffi.new('OVERLAPPED[1]')
        self.handle = _handle2int(handle)
        self.readbuffer = None
        self.pending = 0
        self.completed = 0
        self.writebuffer = None
        self.overlapped[0].hEvent = \
                _kernel32.CreateEventW(NULL, True, False, NULL)
        if not self.overlapped[0].hEvent:
            raise_WinError(IOError)
    def __del__(self):
        # do this somehow else
        err = _kernel32.GetLastError()
        bytes = _ffi.new('DWORD[1]')
        if self.pending:
            result = _kernel32.CancelIoEx(_int2handle(self.handle), self.overlapped)
            if result: 
                _kernel32.GetOverlappedResult(_int2handle(self.handle), self.overlapped, bytes, True)
                # The operation is no longer pending, nothing to do
                
            #else:
                # We need to raise a warning here and not crash pypy
                #raise RuntimeError('deleting an overlapped struct with a pending operation not supported')
        CloseHandle(_int2handle(self.overlapped[0].hEvent))
        _kernel32.SetLastError(err)

    @property
    def event(self):
        return _handle2int(self.overlapped[0].hEvent)

    def GetOverlappedResult(self, wait):
        transferred = _ffi.new('DWORD[1]', [0])
        res = _kernel32.GetOverlappedResult(_int2handle(self.handle), self.overlapped, transferred, wait != 0)
        
        if res:
            err = ERROR_SUCCESS
        else:
            err = _kernel32.GetLastError()

        if err in (ERROR_SUCCESS, ERROR_MORE_DATA, ERROR_OPERATION_ABORTED):
            self.completed = 1
            self.pending = 0
        elif res != ERROR_IO_INCOMPLETE:
            self.pending = 0
            print('GetOverlappedResult got err', err)
            raise_WinError(IOError)

        if self.completed and self.readbuffer:
            if transferred[0] != len(self.readbuffer):
                tempbuffer = _ffi.new("CHAR[]", transferred[0])
                _ffi.memmove(tempbuffer, self.readbuffer, transferred[0])
                self.readbuffer = tempbuffer
        return transferred[0], err

    def getbuffer(self):
        if not self.completed:
            raise ValueError("can't get read buffer before GetOverlappedResult() "
                        "signals the operation completed")
        if self.readbuffer:
            result = bytes(_ffi.buffer(self.readbuffer))
        else:
            result = None
        return result

    def cancel(self):
        ret = True
        if self.pending:
            ret = _kernel32.CancelIoEx(_int2handle(self.handle), self.overlapped)
        if not ret and _kernel32.GetLastError() != ERROR_NOT_FOUND:
            raise_WinError(IOError)
        self.pending = 0
        return None


def ReadFile(handle, size, overlapped):
    nread = _ffi.new("DWORD*")
    use_overlapped = overlapped

    buf = _ffi.new("CHAR[]", size)
    if not buf:
        raise_WinError(IOError)
    err = 0
    if use_overlapped:
        overlapped = Overlapped(handle)
        overlapped.readbuffer = buf
        ret = _kernel32.ReadFile(_int2handle(handle), buf, size, nread,
                       overlapped.overlapped)
        if not ret:
            err = _kernel32.GetLastError()
            if err == ERROR_IO_PENDING:
                overlapped.pending = 1
            elif err != ERROR_MORE_DATA:
                raise_WinError(IOError)
        return overlapped, err
    else:
        ret = _kernel32.ReadFile(_int2handle(handle), buf, size, nread,
                       _ffi.NULL)
 
    if not ret:
        err = _kernel32.GetLastError()
        if err != ERROR_MORE_DATA:
            raise_WinError(IOError)
    return nread[0], err

def WriteFile(handle, buffer, overlapped=False):
    written = _ffi.new("DWORD*")
    use_overlapped = overlapped
    overlapped = None    
    err = 0
    if use_overlapped:
        overlapped = Overlapped(handle)
        if not overlapped:
            return _ffi.NULL
        overlapped.writebuffer = bytes(buffer)
        buf = overlapped.writebuffer
        ret = _kernel32.WriteFile(_int2handle(handle), buf , len(buf), written, overlapped.overlapped)
        if not ret:
            err = _kernel32.GetLastError()
            if err == ERROR_IO_PENDING:
                overlapped.pending = 1
            else:
                raise_WinError(IOError)
        return overlapped, err
    else:
        buf = _ffi.new("CHAR[]", bytes(buffer))
        ret = _kernel32.WriteFile(_int2handle(handle), buf , len(buf), written, _ffi.NULL)
        if not ret:
            raise_WinError(IOError)
        return written[0], err

 
def ConnectNamedPipe(handle, overlapped=False):
    handle = _int2handle(handle)
    if overlapped:
        ov = Overlapped(handle)
    else:
        ov = Overlapped(None)
    success = _kernel32.ConnectNamedPipe(handle, ov.overlapped)
    if overlapped:
        # Overlapped ConnectNamedPipe never returns a success code
        assert success == 0
        err = _kernel32.GetLastError()
        if err == ERROR_IO_PENDING:
            ov.pending = 1
        elif err == ERROR_PIPE_CONNECTED:
            _kernel32.SetEvent(ov.overlapped[0].hEvent)
        else:
            del ov
            RaiseFromWindowsErr(err)
        return ov
    elif not success:
        RaiseFromWindowsErr(0)

def GetCurrentProcess():
    return _handle2int(_kernel32.GetCurrentProcess())

def DuplicateHandle(source_process, source, target_process, access, inherit, options=0):
    # CPython: the first three arguments are expected to be integers
    target = _ffi.new("HANDLE[1]")

    res = _kernel32.DuplicateHandle(
        _int2handle(source_process),
        _int2handle(source),
        _int2handle(target_process),
        target, access, inherit, options)

    if not res:
        raise_WinError()
    
    return _handle2int(target[0])

def _Z(input):
    if input is None:
        return _ffi.NULL
    if isinstance(input, str):
        return input
    raise TypeError("str or None expected, got %r" % (
        type(input).__name__,))

def CreateProcess(name, command_line, process_attr, thread_attr,
                  inherit, flags, env, start_dir, startup_info):
    si = _ffi.new("STARTUPINFO *")
    if startup_info is not None:
        si.dwFlags = startup_info.dwFlags
        si.wShowWindow = startup_info.wShowWindow
        # CPython: these three handles are expected to be
        # subprocess.Handle (int) objects
        if startup_info.hStdInput:
            si.hStdInput = _int2handle(startup_info.hStdInput)
        if startup_info.hStdOutput:
            si.hStdOutput = _int2handle(startup_info.hStdOutput)
        if startup_info.hStdError:
            si.hStdError = _int2handle(startup_info.hStdError)

    pi = _ffi.new("PROCESS_INFORMATION *")
    flags |= CREATE_UNICODE_ENVIRONMENT

    if env is not None:
        envbuf = ""
        for k, v in env.items():
            envbuf += "%s=%s\0" % (k, v)
        envbuf += '\0'
    else:
        envbuf = _ffi.NULL

    res = _kernel32.CreateProcessW(_Z(name), _Z(command_line), _ffi.NULL,
                                   _ffi.NULL, inherit, flags, envbuf,
                                   _Z(start_dir), si, pi)

    if not res:
        raise_WinError()

    return (_handle2int(pi.hProcess),
            _handle2int(pi.hThread),
            pi.dwProcessId,
            pi.dwThreadId)

def OpenProcess(desired_access, inherit_handle, process_id):
    handle = _kernel32.OpenProcess(desired_access, inherit_handle, process_id)
    if handle == _ffi.NULL:
        RaiseFromWindowsErr(0)
        handle = INVALID_HANDLE_VALUE

    return _handle2int(handle)

def PeekNamedPipe(handle, size=0):
    nread = _ffi.new("DWORD*")
    navail = _ffi.new("DWORD*")
    nleft = _ffi.new("DWORD*")

    if size < 0:
        raise ValueError("negative size")

    if size:
        buf = _ffi.new("CHAR[]", size)
        if not buf:
            return _ffi.NULL

        ret = _kernel32.PeekNamedPipe(_int2handle(handle), buf, size, nread,
                                      navail, nleft)
        if not ret:
            # In CPython SetExcFromWindowsErr is called here.
            # Not sure what that is doing currently.
            RaiseFromWindowsErr(0)


        return  buf, navail[0], nleft[0]
    else:
        ret = _kernel32.PeekNamedPipe(_int2handle(handle), _ffi.NULL, 0, _ffi.NULL, navail, nleft)
        if not ret:
            # In CPython SetExcFromWindowsErr is called here.
            # Not sure what that is doing currently.
            RaiseFromWindowsErr(0)
        return  navail[0], nleft[0]

def WaitForSingleObject(handle, milliseconds):
    # CPython: the first argument is expected to be an integer.
    res = _kernel32.WaitForSingleObject(_int2handle(handle), milliseconds)
    if res < 0:
        raise_WinError()
    return res


def WaitNamedPipe(namedpipe, milliseconds):
    namedpipe = _ffi.new("CHAR[]", namedpipe.encode("ascii", "ignore"))
    res = _kernel32.WaitNamedPipeA(namedpipe, milliseconds)

    if res < 0:
        raise RaiseFromWindowsErr(0)


def WaitForMultipleObjects(handle_sequence, waitflag, milliseconds):
    if len(handle_sequence) > MAXIMUM_WAIT_OBJECTS:
        return None
    handle_sequence = list(map(_int2handle, handle_sequence))
    handle_sequence = _ffi.new("HANDLE[]", handle_sequence)
    # CPython makes the wait interruptible by ctrl-c. We need to add this in at some point
    res = _kernel32.WaitForMultipleObjects(len(handle_sequence), handle_sequence, waitflag, milliseconds)

    if res == WAIT_FAILED:
        raise_WinError()
    return int(res)


def GetExitCodeProcess(handle):
    # CPython: the first argument is expected to be an integer.
    code = _ffi.new("DWORD[1]")

    res = _kernel32.GetExitCodeProcess(_int2handle(handle), code)

    if not res:
        raise_WinError()

    return code[0]

def TerminateProcess(handle, exitcode):
    # CPython: the first argument is expected to be an integer.
    # The second argument is silently wrapped in a UINT.
    res = _kernel32.TerminateProcess(_int2handle(handle),
                                     _ffi.cast("UINT", exitcode))

    if not res:
        raise_WinError()

def GetStdHandle(stdhandle):
    stdhandle = _ffi.cast("DWORD", stdhandle)
    res = _kernel32.GetStdHandle(stdhandle)

    if not res:
        return None
    else:
        return _handle2int(res)

def CloseHandle(handle):
    res = _kernel32.CloseHandle(_int2handle(handle))

    if not res:
        raise_WinError()

def GetFileType(handle):
    res = _kernel32.GetFileType(_int2handle(handle))

    if res == FILE_TYPE_UNKNOWN and GetLastError() != 0:
        raise_WinError()
    return res

def GetModuleFileName(module):
    buf = _ffi.new("wchar_t[]", _MAX_PATH)
    res = _kernel32.GetModuleFileNameW(_int2handle(module), buf, _MAX_PATH)

    if not res:
        raise_WinError()
    return _ffi.string(buf)

def ExitProcess(exitcode):
    _kernel32.ExitProcess(exitcode)

ZERO_MEMORY = 0x00000008

def malloc(size):
    return _kernel32.HeapAlloc(_kernel32.GetProcessHeap(),ZERO_MEMORY,size)

def free(voidptr):
    _kernel32.HeapFree(_kernel32.GetProcessHeap(),0, voidptr)

def CreateFileMapping(*args):
    handle = _kernel32.CreateFileMappingW(*args)
    if handle == INVALID_HANDLE_VALUE:
        RaiseFromWindowsErr(0)
    return _handle2int(handle)

def OpenFileMapping(*args):
    handle = _kernel32.OpenFileMappingW(*args)
    if not handle:
        RaiseFromWindowsErr(0)
    return _handle2int(handle)

def MapViewOfFile(handle, *args):
    address = _kernel32.MapViewOfFile(_int2handle(handle), *args)
    if not address:
        RaiseFromWindowsErr(0)
    return address
        
def VirtualQuerySize(address):
    mem_basic_info = _ffi.new("MEMORY_BASIC_INFORMATION[1]")
  
    size_of_buf = _kernel32.VirtualQuery(address, mem_basic_info, _ffi.sizeof(mem_basic_info))
    if size_of_buf == 0:
        RaiseFromWindowsErr(0)
    return mem_basic_info[0].RegionSize
    
# #define macros from WinBase.h and elsewhere
STD_INPUT_HANDLE = -10
STD_OUTPUT_HANDLE = -11
STD_ERROR_HANDLE = -12
DUPLICATE_SAME_ACCESS = 2
DUPLICATE_CLOSE_SOURCE = 1
STARTF_USESTDHANDLES = 0x100
STARTF_USESHOWWINDOW = 0x001
SW_HIDE = 0
INFINITE = 0xffffffff
WAIT_OBJECT_0 = 0
WAIT_ABANDONED_0 = 0x80
WAIT_TIMEOUT = 0x102
WAIT_FAILED = 0xFFFFFFFF
DEBUG_PROCESS           = 0x00000001
DEBUG_ONLY_THIS_PROCESS = 0x00000002
CREATE_SUSPENDED        = 0x00000004
DETACHED_PROCESS        = 0x00000008
CREATE_NEW_CONSOLE         = 0x010
CREATE_NEW_PROCESS_GROUP   = 0x200
CREATE_UNICODE_ENVIRONMENT = 0x400
STILL_ACTIVE = 259
_MAX_PATH = 260

ERROR_SUCCESS           = 0
ERROR_NETNAME_DELETED   = 64
ERROR_BROKEN_PIPE       = 109
ERROR_SEM_TIMEOUT       = 121
ERROR_PIPE_BUSY         = 231
ERROR_NO_DATA           = 232 
ERROR_MORE_DATA         = 234
ERROR_PIPE_CONNECTED    = 535
ERROR_OPERATION_ABORTED = 995
ERROR_IO_INCOMPLETE     = 996
ERROR_IO_PENDING        = 997
ERROR_NOT_FOUND          = 1168
ERROR_CONNECTION_REFUSED = 1225
ERROR_CONNECTION_ABORTED = 1236
ERROR_ALREADY_EXISTS = 0xB7


PIPE_ACCESS_INBOUND = 0x00000001
PIPE_ACCESS_OUTBOUND = 0x00000002
PIPE_ACCESS_DUPLEX   = 0x00000003
PIPE_WAIT                  = 0x00000000
PIPE_NOWAIT                = 0x00000001
PIPE_READMODE_BYTE         = 0x00000000
PIPE_READMODE_MESSAGE      = 0x00000002
PIPE_TYPE_BYTE             = 0x00000000
PIPE_TYPE_MESSAGE          = 0x00000004
PIPE_ACCEPT_REMOTE_CLIENTS = 0x00000000
PIPE_REJECT_REMOTE_CLIENTS = 0x00000008

PIPE_UNLIMITED_INSTANCES = 255

GENERIC_READ   =  0x80000000
GENERIC_WRITE  =  0x40000000
GENERIC_EXECUTE=  0x20000000
GENERIC_ALL    =  0x10000000
INVALID_HANDLE_VALUE = _int2handle(-1)
FILE_FLAG_WRITE_THROUGH       =  0x80000000
FILE_FLAG_OVERLAPPED          =  0x40000000
FILE_FLAG_NO_BUFFERING        =  0x20000000
FILE_FLAG_RANDOM_ACCESS       =  0x10000000
FILE_FLAG_SEQUENTIAL_SCAN     =  0x08000000
FILE_FLAG_DELETE_ON_CLOSE     =  0x04000000
FILE_FLAG_BACKUP_SEMANTICS    =  0x02000000
FILE_FLAG_POSIX_SEMANTICS     =  0x01000000
FILE_FLAG_OPEN_REPARSE_POINT  =  0x00200000
FILE_FLAG_OPEN_NO_RECALL      =  0x00100000
FILE_FLAG_FIRST_PIPE_INSTANCE =  0x00080000

NMPWAIT_WAIT_FOREVER          =  0xffffffff
NMPWAIT_NOWAIT                =  0x00000001
NMPWAIT_USE_DEFAULT_WAIT      =  0x00000000

FILE_READ_DATA = 1
FILE_WRITE_DATA = 2
FILE_APPEND_DATA = 4
FILE_READ_EA = 8
FILE_WRITE_EA = 16
FILE_EXECUTE = 32
FILE_READ_ATTRIBUTES = 128 
FILE_WRITE_ATTRIBUTES = 256
READ_CONTROL = 0x00020000
SYNCHRONIZE = 0x00100000
STANDARD_RIGHTS_EXECUTE = READ_CONTROL
STANDARD_RIGHTS_READ = READ_CONTROL
STANDARD_RIGHTS_WRITE = READ_CONTROL

FILE_GENERIC_EXECUTE = FILE_EXECUTE | FILE_READ_ATTRIBUTES | STANDARD_RIGHTS_EXECUTE | SYNCHRONIZE
FILE_GENERIC_READ = FILE_READ_ATTRIBUTES | FILE_READ_DATA | FILE_READ_EA | STANDARD_RIGHTS_READ | SYNCHRONIZE
FILE_GENERIC_WRITE = FILE_APPEND_DATA | FILE_WRITE_ATTRIBUTES | FILE_WRITE_DATA | FILE_WRITE_EA | STANDARD_RIGHTS_WRITE | SYNCHRONIZE

PROCESS_DUP_HANDLE = 0x0040

CREATE_NEW        = 1
CREATE_ALWAYS     = 2
OPEN_EXISTING     = 3
OPEN_ALWAYS       = 4
TRUNCATE_EXISTING = 5

MAXIMUM_WAIT_OBJECTS = 64

BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
ABOVE_NORMAL_PRIORITY_CLASS = 0x00008000
NORMAL_PRIORITY_CLASS       = 0x00000020
IDLE_PRIORITY_CLASS         = 0x00000040
HIGH_PRIORITY_CLASS         = 0x00000080
REALTIME_PRIORITY_CLASS     = 0x00000100
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
CREATE_BREAKAWAY_FROM_JOB   = 0x01000000
CREATE_DEFAULT_ERROR_MODE   = 0x04000000
CREATE_NO_WINDOW            = 0x08000000

FILE_TYPE_CHAR = 2
FILE_TYPE_DISK = 1
FILE_TYPE_PIPE = 3
FILE_TYPE_REMOTE = 32768
FILE_TYPE_UNKNOWN = 0

# Used in CreateFileMapping
PAGE_EXECUTE_READ = 0x20
PAGE_EXECUTE_READWRITE = 0x40
PAGE_EXECUTE_WRITECOPY = 0x80
PAGE_READONLY = 0x02
PAGE_READWRITE = 0x04
PAGE_WRITECOPY = 0x08
SEC_COMMIT = 0x8000000
SEC_IMAGE = 0x1000000
SEC_IMAGE_NO_EXECUTE = 0x11000000
SEC_LARGE_PAGES = 0x80000000
SEC_NOCACHE = 0x10000000
SEC_RESERVE = 0x4000000
SEC_WRITECOMBINE = 0x40000000

# Used in MapViewOfFile
STANDARD_RIGHTS_REQUIRED     = 0x000F0000
SECTION_QUERY                = 0x0001
SECTION_MAP_WRITE            = 0x0002
SECTION_MAP_READ             = 0x0004
SECTION_MAP_EXECUTE          = 0x0008
SECTION_EXTEND_SIZE          = 0x0010
SECTION_MAP_EXECUTE_EXPLICIT = 0x0020 
SECTION_ALL_ACCESS = (STANDARD_RIGHTS_REQUIRED|SECTION_QUERY|
                            SECTION_MAP_WRITE |
                            SECTION_MAP_READ |
                            SECTION_MAP_EXECUTE |
                            SECTION_EXTEND_SIZE)


FILE_MAP_WRITE           = SECTION_MAP_WRITE
FILE_MAP_READ            = SECTION_MAP_READ
FILE_MAP_ALL_ACCESS      = SECTION_ALL_ACCESS
FILE_MAP_EXECUTE         = SECTION_MAP_EXECUTE_EXPLICIT
FILE_MAP_COPY            = 0x00000001
FILE_MAP_RESERVE         = 0x80000000
FILE_MAP_TARGETS_INVALID = 0x40000000
FILE_MAP_LARGE_PAGES     = 0x20000000
