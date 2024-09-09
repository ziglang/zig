fn doNothing() !void {}

fn nestedSwitchReturnBeforeTry(t: u32) !void {
    try switch (t) {
        7 => doNothing(),
        0x70000000...0x7fffffff => doNothing(),
        else => {
            return switch (t) {
                else => doNothing(),
            };
        },
    };
}

pub fn main() !void {
    try nestedSwitchReturnBeforeTry(42);
}

// compile
//
