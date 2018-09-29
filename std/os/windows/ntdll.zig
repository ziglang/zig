use @import("index.zig");

pub extern "NtDll" stdcallcc fn RtlCaptureStackBackTrace(FramesToSkip: DWORD, FramesToCapture: DWORD, BackTrace: **c_void, BackTraceHash: ?*DWORD) WORD;
