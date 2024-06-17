export fn entry() void {
    @import("std").debug.print("hello {}", .{"world"});
}

// error
// backend=llvm
// target=native
//
// :?:?: error: cannot format array without a specifier (i.e. {s} or {any}) in "hello {}"
