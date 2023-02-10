const UsbDeviceRequest = struct {
    Type: u8,
};

export fn foo() void {
    comptime assert(@sizeOf(UsbDeviceRequest) == 0x8);
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// error
// backend=stage2
// target=native
//
// :10:14: error: reached unreachable code
// :6:20: note: called from here
