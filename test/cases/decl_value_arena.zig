pub const Protocols: struct {
    list: *const fn (*Connection) void = undefined,
    handShake: type = struct {
        const stepStart: u8 = 0;
    },
} = .{};

pub const Connection = struct {
    streamBuffer: [0]u8 = undefined,
    __lastReceivedPackets: [0]u8 = undefined,

    handShakeState: u8 = Protocols.handShake.stepStart,
};

pub fn main() void {
    var conn: Connection = undefined;
    _ = &conn;
}

// run
//
