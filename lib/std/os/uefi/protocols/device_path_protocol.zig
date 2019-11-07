const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;

pub const DevicePathProtocol = extern struct {
    type: u8,
    subtype: u8,
    length: u16,

    pub const guid align(8) = Guid{
        .time_low = 0x09576e91,
        .time_mid = 0x6d3f,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};
