const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

/// Random Number Generator protocol
pub const Rng = extern struct {
    _get_info: *const fn (*const Rng, *usize, [*]Guid) callconv(cc) Status,
    _get_rng: *const fn (*const Rng, ?*const Guid, usize, [*]u8) callconv(cc) Status,

    pub const GetInfoError = uefi.UnexpectedError || error{
        Unsupported,
        DeviceError,
        BufferTooSmall,
    };
    pub const GetRNGError = uefi.UnexpectedError || error{
        Unsupported,
        DeviceError,
        NotReady,
        InvalidParameter,
    };

    /// Returns information about the random number generation implementation.
    pub fn getInfo(self: *const Rng, list: []Guid) GetInfoError![]Guid {
        var len: usize = list.len;
        switch (self._get_info(self, &len, list.ptr)) {
            .success => return list[0..len],
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            .buffer_too_small => return Error.BufferTooSmall,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Produces and returns an RNG value using either the default or specified RNG algorithm.
    pub fn getRNG(self: *const Rng, algo: ?*const Guid, value: []u8) GetRNGError!void {
        switch (self._get_rng(self, algo, value.len, value.ptr)) {
            .success => {},
            .unsupported => return Error.Unsupported,
            .device_error => return Error.DeviceError,
            .not_ready => return Error.NotReady,
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    pub const guid = Guid{
        .time_low = 0x3152bca5,
        .time_mid = 0xeade,
        .time_high_and_version = 0x433d,
        .clock_seq_high_and_reserved = 0x86,
        .clock_seq_low = 0x2e,
        .node = [_]u8{ 0xc0, 0x1c, 0xdc, 0x29, 0x1f, 0x44 },
    };
    pub const algorithm_sp800_90_hash_256 = Guid{
        .time_low = 0xa7af67cb,
        .time_mid = 0x603b,
        .time_high_and_version = 0x4d42,
        .clock_seq_high_and_reserved = 0xba,
        .clock_seq_low = 0x21,
        .node = [_]u8{ 0x70, 0xbf, 0xb6, 0x29, 0x3f, 0x96 },
    };
    pub const algorithm_sp800_90_hmac_256 = Guid{
        .time_low = 0xc5149b43,
        .time_mid = 0xae85,
        .time_high_and_version = 0x4f53,
        .clock_seq_high_and_reserved = 0x99,
        .clock_seq_low = 0x82,
        .node = [_]u8{ 0xb9, 0x43, 0x35, 0xd3, 0xa9, 0xe7 },
    };
    pub const algorithm_sp800_90_ctr_256 = Guid{
        .time_low = 0x44f0de6e,
        .time_mid = 0x4d8c,
        .time_high_and_version = 0x4045,
        .clock_seq_high_and_reserved = 0xa8,
        .clock_seq_low = 0xc7,
        .node = [_]u8{ 0x4d, 0xd1, 0x68, 0x85, 0x6b, 0x9e },
    };
    pub const algorithm_x9_31_3des = Guid{
        .time_low = 0x63c4785a,
        .time_mid = 0xca34,
        .time_high_and_version = 0x4012,
        .clock_seq_high_and_reserved = 0xa3,
        .clock_seq_low = 0xc8,
        .node = [_]u8{ 0x0b, 0x6a, 0x32, 0x4f, 0x55, 0x46 },
    };
    pub const algorithm_x9_31_aes = Guid{
        .time_low = 0xacd03321,
        .time_mid = 0x777e,
        .time_high_and_version = 0x4d3d,
        .clock_seq_high_and_reserved = 0xb1,
        .clock_seq_low = 0xc8,
        .node = [_]u8{ 0x20, 0xcf, 0xd8, 0x88, 0x20, 0xc9 },
    };
    pub const algorithm_raw = Guid{
        .time_low = 0xe43176d7,
        .time_mid = 0xb6e8,
        .time_high_and_version = 0x4827,
        .clock_seq_high_and_reserved = 0xb7,
        .clock_seq_low = 0x84,
        .node = [_]u8{ 0x7f, 0xfd, 0xc4, 0xb6, 0x85, 0x61 },
    };
};
