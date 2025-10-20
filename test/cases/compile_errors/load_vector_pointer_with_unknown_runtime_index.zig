export fn entry() void {
    var v: @Vector(4, i31) = [_]i31{ 1, 5, 3, undefined };

    var i: u32 = 0;
    var x = loadv(&v[i]);
    _ = .{ &i, &x };
}

fn loadv(ptr: anytype) i31 {
    return ptr.*;
}

// error
//
// :5:22: error: vector index not comptime known
