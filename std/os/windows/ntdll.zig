use @import("../windows.zig");

pub extern "NtDll" stdcallcc fn RtlCaptureStackBackTrace(FramesToSkip: DWORD, FramesToCapture: DWORD, BackTrace: **c_void, BackTraceHash: ?*DWORD) WORD;
