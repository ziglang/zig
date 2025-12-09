export fn foo() void {
    comptime var a: u32 = 0;
    asm volatile (""
        :
        : [in] "r" (&a),
    );
}

export fn bar() void {
    comptime var a: u32 = 0;
    asm volatile (""
        : [out] "=r" (a),
    );
}

// error
//
// :5:21: error: assembly input contains reference to comptime var
// :2:14: note: 'in' points to comptime var declared here
// :12:23: error: assembly output contains reference to comptime var
// :10:14: note: 'out' points to comptime var declared here
