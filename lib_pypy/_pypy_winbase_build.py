# This module provides interfaces needed by both msvcrt and
# _subprocess.py.
#
# Note: uses the CFFI out-of-line ABI mode.  We can't use the API
# mode because ffi.compile() needs to run the compiler, which
# needs 'subprocess', which needs 'msvcrt' and '_subprocess',
# which depend on '_pypy_winbase_cffi' already.
#
# Note that if you need to regenerate _pypy_winbase_cffi and
# can't use a preexisting PyPy to do that, then running this
# file should work as long as 'subprocess' is not imported
# by cffi. (CPython+CFFI should work)

from cffi import FFI

ffi = FFI()

if ffi.sizeof('HANDLE') == 8:
    # 64 bit windows
    ffi.set_source("_pypy_winbase_cffi64", None)
else:
    ffi.set_source("_pypy_winbase_cffi", None)

# ---------- MSVCRT ----------

ffi.cdef("""
typedef unsigned short wint_t;

int _open_osfhandle(intptr_t osfhandle, int flags);
intptr_t _get_osfhandle(int fd);
int _setmode(int fd, int mode);
int _locking(int fd, int mode, long nbytes);

int _kbhit(void);
int _getch(void);
wint_t _getwch(void);
int _getche(void);
wint_t _getwche(void);
int _putch(int);
wint_t _putwch(wchar_t);
int _ungetch(int);
wint_t _ungetwch(wint_t);
""")

# ---------- SUBPROCESS ----------

ffi.cdef("""
typedef struct {
    DWORD  cb;
    char * lpReserved;
    char * lpDesktop;
    char * lpTitle;
    DWORD  dwX;
    DWORD  dwY;
    DWORD  dwXSize;
    DWORD  dwYSize;
    DWORD  dwXCountChars;
    DWORD  dwYCountChars;
    DWORD  dwFillAttribute;
    DWORD  dwFlags;
    WORD   wShowWindow;
    WORD   cbReserved2;
    LPBYTE lpReserved2;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
} STARTUPINFO, *LPSTARTUPINFO;

typedef struct _SECURITY_ATTRIBUTES {
    DWORD nLength;
    LPVOID lpSecurityDescriptor;
    BOOL bInheritHandle;
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

typedef struct {
    HANDLE hProcess;
    HANDLE hThread;
    DWORD  dwProcessId;
    DWORD  dwThreadId;
} PROCESS_INFORMATION, *LPPROCESS_INFORMATION;

typedef struct _OVERLAPPED {
    ULONG_PTR Internal;
    ULONG_PTR InternalHigh;
    union {
        struct {
            DWORD Offset;
            DWORD OffsetHigh;
        } DUMMYSTRUCTNAME;
        PVOID Pointer;
    } DUMMYUNIONNAME;

    HANDLE  hEvent;
} OVERLAPPED, *LPOVERLAPPED;

typedef struct _MEMORY_BASIC_INFORMATION {
  PVOID  BaseAddress;
  PVOID  AllocationBase;
  DWORD  AllocationProtect;
  WORD   PartitionId;
  SIZE_T RegionSize;
  DWORD  State;
  DWORD  Protect;
  DWORD  Type;
} MEMORY_BASIC_INFORMATION, *PMEMORY_BASIC_INFORMATION;

DWORD WINAPI GetVersion(void);
DWORD WINAPI GetFileType(HANDLE);
BOOL WINAPI CreatePipe(PHANDLE, PHANDLE, void *, DWORD);
HANDLE WINAPI CreateNamedPipeA(LPCSTR, DWORD, DWORD, DWORD, DWORD, DWORD,
                         DWORD , LPSECURITY_ATTRIBUTES);
HANDLE WINAPI CreateNamedPipeW(LPWSTR, DWORD, DWORD, DWORD, DWORD, DWORD,
                         DWORD , LPSECURITY_ATTRIBUTES);
HANDLE WINAPI CreateFileA(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES,
                   DWORD, DWORD, HANDLE);
HANDLE WINAPI CreateFileW(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES,
                   DWORD, DWORD, HANDLE);
BOOL ReadFile(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED);
BOOL WaitNamedPipeA(LPCSTR, DWORD);
BOOL WINAPI WriteFile(HANDLE, LPCVOID, DWORD, LPDWORD, LPOVERLAPPED);
BOOL WINAPI SetNamedPipeHandleState(HANDLE, LPDWORD, LPDWORD, LPDWORD);
BOOL WINAPI ConnectNamedPipe(HANDLE, LPOVERLAPPED);
BOOL WINAPI PeekNamedPipe(HANDLE, LPVOID, DWORD, LPDWORD, LPDWORD, LPDWORD);
HANDLE WINAPI CreateEventA(LPSECURITY_ATTRIBUTES, BOOL, BOOL, LPCSTR);
HANDLE WINAPI CreateEventW(LPSECURITY_ATTRIBUTES, BOOL, BOOL, LPCWSTR);
BOOL WINAPI SetEvent(HANDLE);
BOOL WINAPI CancelIo(HANDLE);
BOOL WINAPI CancelIoEx(HANDLE, LPOVERLAPPED);
BOOL WINAPI CloseHandle(HANDLE);
DWORD WINAPI GetLastError(VOID);
void WINAPI SetLastError(DWORD);
BOOL WINAPI GetOverlappedResult(HANDLE, LPOVERLAPPED, LPDWORD, BOOL);
HANDLE WINAPI GetCurrentProcess(void);
HANDLE OpenProcess(DWORD, BOOL, DWORD);
UINT WINAPI GetACP(VOID);
void ExitProcess(UINT);
BOOL WINAPI DuplicateHandle(HANDLE, HANDLE, HANDLE, LPHANDLE,
                            DWORD, BOOL, DWORD);
BOOL WINAPI CreateProcessA(char *, char *, void *,
                           void *, BOOL, DWORD, char *,
                           char *, LPSTARTUPINFO, LPPROCESS_INFORMATION);
BOOL WINAPI CreateProcessW(wchar_t *, wchar_t *, void *,
                           void *, BOOL, DWORD, wchar_t *,
                           wchar_t *, LPSTARTUPINFO, LPPROCESS_INFORMATION);
DWORD WINAPI WaitForSingleObject(HANDLE, DWORD);
DWORD WaitForMultipleObjects(DWORD, HANDLE*, BOOL, DWORD);
BOOL WINAPI GetExitCodeProcess(HANDLE, LPDWORD);
BOOL WINAPI TerminateProcess(HANDLE, UINT);
HANDLE WINAPI GetStdHandle(DWORD);
DWORD WINAPI GetModuleFileNameW(HANDLE, wchar_t *, DWORD);
UINT WINAPI SetErrorMode(UINT);
#define SEM_FAILCRITICALERRORS     0x0001
#define SEM_NOGPFAULTERRORBOX      0x0002
#define SEM_NOALIGNMENTFAULTEXCEPT 0x0004
#define SEM_NOOPENFILEERRORBOX     0x8000

typedef struct _PostCallbackData {
    HANDLE hCompletionPort;
    LPOVERLAPPED Overlapped;
} PostCallbackData, *LPPostCallbackData;

typedef VOID (WINAPI *WAITORTIMERCALLBACK) (PVOID, BOOL);  
BOOL WINAPI RegisterWaitForSingleObject(PHANDLE, HANDLE, WAITORTIMERCALLBACK, PVOID, ULONG, ULONG);

BOOL WINAPI PostQueuedCompletionStatus(HANDLE,  DWORD, ULONG_PTR, LPOVERLAPPED);
BOOL WINAPI UnregisterWaitEx(HANDLE, HANDLE);
BOOL WINAPI UnregisterWait(HANDLE);

BOOL WINAPI GetQueuedCompletionStatus(HANDLE, LPDWORD, ULONG**, LPOVERLAPPED*, DWORD);
HANDLE WINAPI CreateIoCompletionPort(HANDLE, HANDLE, ULONG_PTR, DWORD);
HANDLE WINAPI CreateFileMappingW(HANDLE, LPSECURITY_ATTRIBUTES, DWORD, DWORD, DWORD, LPCWSTR);
HANDLE OpenFileMappingW(DWORD, BOOL, LPWSTR);
LPVOID MapViewOfFile(HANDLE, DWORD, DWORD, DWORD, SIZE_T);
SIZE_T VirtualQuery(LPCVOID, PMEMORY_BASIC_INFORMATION, SIZE_T);

#define WT_EXECUTEINWAITTHREAD 0x00000004
#define WT_EXECUTEONLYONCE 0x00000008

HANDLE GetProcessHeap();
LPVOID HeapAlloc(HANDLE, DWORD, SIZE_T);
BOOL HeapFree(HANDLE, DWORD, LPVOID);

typedef struct _COORD {
  SHORT X;
  SHORT Y;
} COORD, *PCOORD;

typedef struct _FOCUS_EVENT_RECORD {
  BOOL bSetFocus;
} FOCUS_EVENT_RECORD;

typedef struct _WINDOW_BUFFER_SIZE_RECORD {
  COORD dwSize;
} WINDOW_BUFFER_SIZE_RECORD;

typedef struct _KEY_EVENT_RECORD {
  BOOL  bKeyDown;
  WORD  wRepeatCount;
  WORD  wVirtualKeyCode;
  WORD  wVirtualScanCode;
  union {
    WCHAR UnicodeChar;
    CHAR  AsciiChar;
  } uChar;
  DWORD dwControlKeyState;
} KEY_EVENT_RECORD;

typedef struct _MENU_EVENT_RECORD {
  UINT dwCommandId;
} MENU_EVENT_RECORD, *PMENU_EVENT_RECORD;

typedef struct _MOUSE_EVENT_RECORD {
  COORD dwMousePosition;
  DWORD dwButtonState;
  DWORD dwControlKeyState;
  DWORD dwEventFlags;
} MOUSE_EVENT_RECORD;

typedef struct _INPUT_RECORD {
  WORD  EventType;
  union {
    KEY_EVENT_RECORD          KeyEvent;
    MOUSE_EVENT_RECORD        MouseEvent;
    WINDOW_BUFFER_SIZE_RECORD WindowBufferSizeEvent;
    MENU_EVENT_RECORD         MenuEvent;
    FOCUS_EVENT_RECORD        FocusEvent;
  } Event;
} INPUT_RECORD;

BOOL WINAPI WriteConsoleInputW(HANDLE, const INPUT_RECORD*, DWORD, LPDWORD);

""")

# -------------------- Win Sock 2 ----------------------

ffi.cdef("""
typedef struct _WSABUF {
  ULONG len;
  CHAR  *buf;
} WSABUF, *LPWSABUF;

typedef HANDLE SOCKET;
SOCKET __stdcall socket(int, int, int);
int closesocket(SOCKET);


typedef BOOL (__stdcall * LPFN_DISCONNECTEX) (SOCKET, LPOVERLAPPED, DWORD, DWORD);
typedef VOID (*LPOVERLAPPED_COMPLETION_ROUTINE) (DWORD, DWORD, LPVOID);

int __stdcall WSARecv(SOCKET, LPWSABUF, DWORD, LPDWORD, LPDWORD, LPOVERLAPPED, LPOVERLAPPED_COMPLETION_ROUTINE);
int __stdcall WSASend(SOCKET, LPWSABUF, DWORD, LPDWORD, DWORD, LPOVERLAPPED,  LPOVERLAPPED_COMPLETION_ROUTINE);
int __stdcall WSAIoctl(SOCKET, DWORD, LPVOID, DWORD, LPVOID, DWORD, LPDWORD, LPOVERLAPPED, LPOVERLAPPED_COMPLETION_ROUTINE);


typedef struct _GUID {
  DWORD Data1;
  WORD  Data2;
  WORD  Data3;
  BYTE  Data4[8];
} GUID;

typedef USHORT ADDRESS_FAMILY;

typedef struct in6_addr {
  union {
    UCHAR  Byte[16];
    USHORT Word[8];
  } u;
} IN6_ADDR, *PIN6_ADDR, *LPIN6_ADDR;

typedef struct {
  union {
    struct {
      ULONG  Zone : 28;
      ULONG  Level : 4;
    };
    ULONG  Value;
  };
} SCOPE_ID, *PSCOPE_ID;

typedef struct sockaddr_in6 {
  ADDRESS_FAMILY sin6_family;
  USHORT         sin6_port;
  ULONG          sin6_flowinfo;
  IN6_ADDR       sin6_addr;
  union {
    ULONG    sin6_scope_id;
    SCOPE_ID sin6_scope_struct;
  };
} SOCKADDR_IN6_LH, *PSOCKADDR_IN6_LH, *LPSOCKADDR_IN6_LH;

typedef struct in_addr {
  union {
    struct {
      UCHAR s_b1;
      UCHAR s_b2;
      UCHAR s_b3;
      UCHAR s_b4;
    } S_un_b;
    struct {
      USHORT s_w1;
      USHORT s_w2;
    } S_un_w;
    ULONG S_addr;
  } S_un;
} INADDR, *PINADDR;

typedef struct sockaddr_in {
  SHORT          sin_family;
  USHORT         sin_port;
  INADDR         sin_addr;
  CHAR           sin_zero[8];
} SOCKADDR_IN, *PSOCKADDR_IN, *LPSOCKADDR_IN;

typedef struct sockaddr {
    USHORT  sa_family;
    CHAR    sa_data[14];
} SOCKADDR, *PSOCKADDR, *LPSOCKADDR;

int bind(SOCKET, const PSOCKADDR, int);

#define MAX_PROTOCOL_CHAIN 7

typedef struct _WSAPROTOCOLCHAIN {
  int   ChainLen;
  DWORD ChainEntries[MAX_PROTOCOL_CHAIN];
} WSAPROTOCOLCHAIN, *LPWSAPROTOCOLCHAIN;

#define WSAPROTOCOL_LEN  255

typedef struct _WSAPROTOCOL_INFOW {
  DWORD            dwServiceFlags1;
  DWORD            dwServiceFlags2;
  DWORD            dwServiceFlags3;
  DWORD            dwServiceFlags4;
  DWORD            dwProviderFlags;
  GUID             ProviderId;
  DWORD            dwCatalogEntryId;
  WSAPROTOCOLCHAIN ProtocolChain;
  int              iVersion;
  int              iAddressFamily;
  int              iMaxSockAddr;
  int              iMinSockAddr;
  int              iSocketType;
  int              iProtocol;
  int              iProtocolMaxOffset;
  int              iNetworkByteOrder;
  int              iSecurityScheme;
  DWORD            dwMessageSize;
  DWORD            dwProviderReserved;
  WCHAR            szProtocol[WSAPROTOCOL_LEN + 1];
} WSAPROTOCOL_INFOW, *LPWSAPROTOCOL_INFOW;

int __stdcall WSAStringToAddressW(LPWSTR, int, LPWSAPROTOCOL_INFOW, LPSOCKADDR, int* );

typedef BOOL (WINAPI* AcceptExPtr)(SOCKET, SOCKET, PVOID, DWORD, DWORD, DWORD, LPDWORD, LPOVERLAPPED);  
typedef BOOL (WINAPI *ConnectExPtr)(SOCKET, const PSOCKADDR, int, PVOID, DWORD, LPDWORD, LPOVERLAPPED);
typedef BOOL (WINAPI *DisconnectExPtr)(SOCKET, LPOVERLAPPED, DWORD, DWORD);

USHORT htons(USHORT);
""")

if __name__ == "__main__":
    ffi.compile()
