pub fn main() void {
    false catch |err| switch (err) {
        else => {},
    };
}

// error
// backend=stage2
// target=native
//
// :2:23: error: expected error union type, found 'bool'
