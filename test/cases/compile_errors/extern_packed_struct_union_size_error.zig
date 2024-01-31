const PU = packed union { a: u33, b: u32 };
export fn entry1(v: PU) void {
    _ = v;
}

const PS = packed struct { a: u33, b: u32 };
export fn entry2(v: PS) void {
    _ = v;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: parameter of type 'tmp.PU' not allowed in function with calling convention 'C'
// :2:18: note: only extern unions, ABI sized packed unions and empty unions are extern compatible
// :1:19: note: union declared here
// :7:18: error: parameter of type 'tmp.PS' not allowed in function with calling convention 'C'
// :7:18: note: only extern structs, ABI sized packed structs and empty structs are extern compatible
// :6:19: note: struct declared here
