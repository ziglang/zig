pub fn main() void {
    false catch |err| switch (err) {
        else => {},
    };
}

// error
// backend=stage2
// target=x86_64-linux
//
// :2:23: error: expected error union type, found 'bool'
