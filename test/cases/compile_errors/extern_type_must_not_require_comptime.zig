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
// :2:18: note: only extern unions, ABI sized packed unions and empty unions are extern compatible
// :2:18: note: extern compatible unions cannot have comptime dependency
// :1:12: note: union requires comptime because of its tag
// :1:12: note: union declared here
// :7:18: error: parameter of type 'tmp.U' not allowed in function with calling convention 'C'
// :7:18: note: only extern unions, ABI sized packed unions and empty unions are extern compatible
// :7:18: note: extern compatible unions cannot have comptime dependency
// :6:22: note: union requires comptime because of this field
// :6:11: note: union declared here
// :12:18: error: parameter of type 'tmp.S' not allowed in function with calling convention 'C'
// :12:18: note: only extern structs, ABI sized packed structs and empty structs are extern compatible
// :12:18: note: extern compatible structs cannot have comptime dependency
// :11:23: note: struct requires comptime because of this field
// :11:11: note: struct declared here
