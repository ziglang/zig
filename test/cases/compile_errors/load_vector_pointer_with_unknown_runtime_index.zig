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
// backend=llvm
// target=native
//
// :10:15: error: unable to determine vector element index of type '*align(16:0:4:?) i31'
