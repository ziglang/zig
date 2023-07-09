const std = @import("std");
const builtin = @import("builtin");

export var _tls_index: u32 = std.os.windows.TLS_OUT_OF_INDEXES;
export var _tls_start: u8 linksection(".tls") = 0;
export var _tls_end: u8 linksection(".tls$ZZZ") = 0;
export var __xl_a: std.os.windows.PIMAGE_TLS_CALLBACK linksection(".CRT$XLA") = null;
export var __xl_z: std.os.windows.PIMAGE_TLS_CALLBACK linksection(".CRT$XLZ") = null;

comptime {
    if (builtin.target.cpu.arch == .x86 and builtin.zig_backend != .stage2_c) {
        // The __tls_array is the offset of the ThreadLocalStoragePointer field
        // in the TEB block whose base address held in the %fs segment.
        asm (
            \\ .global __tls_array
            \\ __tls_array = 0x2C
        );
    }
}

// TODO this is how I would like it to be expressed
// TODO also note, ReactOS has a +1 on StartAddressOfRawData and AddressOfCallBacks. Investigate
// why they do that.
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
    StartAddressOfRawData: *anyopaque,
    EndAddressOfRawData: *anyopaque,
    AddressOfIndex: *anyopaque,
    AddressOfCallBacks: *anyopaque,
    SizeOfZeroFill: u32,
    Characteristics: u32,
};
export const _tls_used linksection(".rdata$T") = IMAGE_TLS_DIRECTORY{
    .StartAddressOfRawData = &_tls_start,
    .EndAddressOfRawData = &_tls_end,
    .AddressOfIndex = &_tls_index,
    .AddressOfCallBacks = @as(*anyopaque, @ptrCast(&__xl_a)),
    .SizeOfZeroFill = 0,
    .Characteristics = 0,
};
