const UsbDeviceRequest = struct {
    Type: u8,
};

export fn foo() void {
    comptime assert(@sizeOf(UsbDeviceRequest) == 0x8);
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// referring to a struct that is invalid
//
// tmp.zig:10:14: error: reached unreachable code
