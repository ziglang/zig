const UE = union(enum(comptime_int)) { a, b };
export fn entry1(v: UE) void {
    _ = v;
}

const U = union { a: comptime_int, b: void };
export fn entry2(v: U) void {
    _ = v;
}

const S = struct { a: comptime_int, b: void };
export fn entry3(v: S) void {
    _ = v;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: parameter of type 'tmp.UE' not allowed in function with calling convention 'C'
// :2:18: note: only empty union without comptime dependency are extern compatible
// :1:12: note: union declared here
// :7:18: error: parameter of type 'tmp.U' not allowed in function with calling convention 'C'
// :7:18: note: only empty union without comptime dependency are extern compatible
// :6:11: note: union declared here
// :12:18: error: parameter of type 'tmp.S' not allowed in function with calling convention 'C'
// :12:18: note: only empty struct without comptime dependency are extern compatible
// :11:11: note: struct declared here
