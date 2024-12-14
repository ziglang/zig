const a = bogus; // astgen error (undeclared identifier)
const b: u32 = "hi"; // sema error (type mismatch)

comptime {
    _ = b;
    @compileError("not hit because 'b' failed");
}

comptime {
    @compileError("this should be hit");
}

// error
//
// :1:11: error: use of undeclared identifier 'bogus'
// :2:16: error: expected type 'u32', found '*const [2:0]u8'
// :10:5: error: this should be hit
