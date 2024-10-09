const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

export var _tls_index: u32 = std.os.windows.TLS_OUT_OF_INDEXES;
export var _tls_start: ?*anyopaque linksection(".tls") = null;
export var _tls_end: ?*anyopaque linksection(".tls$ZZZ") = null;
export var __xl_a: windows.PIMAGE_TLS_CALLBACK linksection(".CRT$XLA") = null;
export var __xl_z: windows.PIMAGE_TLS_CALLBACK linksection(".CRT$XLZ") = null;

comptime {
    if (builtin.cpu.arch == .x86 and !builtin.abi.isGnu() and builtin.zig_backend != .stage2_c) {
        // The __tls_array is the offset of the ThreadLocalStoragePointer field
        // in the TEB block whose base address held in the %fs segment.
        asm (
            \\ .global __tls_array
            \\ __tls_array = 0x2C
        );
    }
}

// TODO this is how I would like it to be expressed
//export const _tls_used linksection(".rdata$T") = std.os.windows.IMAGE_TLS_DIRECTORY {
//    .StartAddressOfRawData = @intFromPtr(&_tls_start),
//    .EndAddressOfRawData = @intFromPtr(&_tls_end),
//    .AddressOfIndex = @intFromPtr(&_tls_index),
//    .AddressOfCallBacks = @intFromPtr(__xl_a),
//    .SizeOfZeroFill = 0,
//    .Characteristics = 0,
//};
// This is the workaround because we can't do @intFromPtr at comptime like that.
pub const IMAGE_TLS_DIRECTORY = extern struct {
    StartAddressOfRawData: *?*anyopaque,
    EndAddressOfRawData: *?*anyopaque,
    AddressOfIndex: *u32,
    AddressOfCallBacks: [*:null]windows.PIMAGE_TLS_CALLBACK,
    SizeOfZeroFill: u32,
    Characteristics: u32,
};
export const _tls_used linksection(".rdata$T") = IMAGE_TLS_DIRECTORY{
    .StartAddressOfRawData = &_tls_start,
    .EndAddressOfRawData = &_tls_end,
    .AddressOfIndex = &_tls_index,
    // __xl_a is just a global variable containing a null pointer; the actual callbacks sit in
    // between __xl_a and __xl_z. So we need to skip over __xl_a here. If there are no callbacks,
    // this just means we point to __xl_z (the null terminator).
    .AddressOfCallBacks = @as([*:null]windows.PIMAGE_TLS_CALLBACK, @ptrCast(&__xl_a)) + 1,
    .SizeOfZeroFill = 0,
    .Characteristics = 0,
};
