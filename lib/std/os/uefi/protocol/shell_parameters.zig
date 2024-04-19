const bits = @import("../bits.zig");

const Guid = bits.Guid;

/// An instance of this protocol is installed on each shell application’s image handle prior to calling StartImage().
/// It describes all of the command-line parameters passed on the command line, as well as the standard file handles
/// for standard input, output and error output.
pub const ShellParameters = extern struct {
    argv: [*][*:0]const u16,
    argc: usize,
    stdin: bits.FileHandle,
    stdout: bits.FileHandle,
    stderr: bits.FileHandle,

    pub const guid align(8) = Guid{
        .time_low = 0x752f3136,
        .time_mid = 0x4e16,
        .time_high_and_version = 0x4fdc,
        .clock_seq_high_and_reserved = 0xa2,
        .clock_seq_low = 0x2a,
        .node = [_]u8{ 0xe5, 0xf4, 0x68, 0x12, 0xf4, 0xca },
    };
};
