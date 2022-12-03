fn Observable(comptime T: type) type {
    return struct {
        fn map(Src: T, Dst: anytype, function: fn (T) Dst) Dst {
            _ = Src;
            _ = function;
            return Observable(Dst);
        }
    };
}

fn u32Tou64(x: u32) u64 {
    _ = x;
    return 0;
}

pub export fn entry() void {
    Observable(u32).map(u32, u64, u32Tou64(0));
}

// error
// backend=stage2
// target=native
//
// :17:25: error: expected type 'u32', found 'type'
// :3:21: note: parameter type declared here
