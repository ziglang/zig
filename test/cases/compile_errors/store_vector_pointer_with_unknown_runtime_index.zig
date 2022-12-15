export fn entry() void {
    var v: @Vector(4, i31) = [_]i31{ 1, 5, 3, undefined };

    var i: u32 = 0;
    storev(&v[i], 42);
}

fn storev(ptr: anytype, val: i31) void {
    ptr.* = val;
}

// error
// backend=llvm
// target=native
//
// :9:8: error: unable to determine vector element index of type '*align(16:0:4:?) i31'
