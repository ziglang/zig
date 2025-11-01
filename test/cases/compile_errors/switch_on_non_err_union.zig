pub fn main() void {
    false catch |err| switch (err) {
        else => {},
    };
}

// error
// target=x86_64-linux
//
// :2:23: error: expected error union type, found 'bool'
