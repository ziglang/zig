const Obj = struct { a: [1]?u32, b: u32 = 0 };

fn func(comptime dummy: u32, obj: Obj) void {
    _ = dummy;
    _ = obj;
}

pub fn main() void {
    var c: u32 = 0;
    func(0, .{ .a = [1]?u32{42}, .b = c });
    c = undefined;
}

// compile
//
