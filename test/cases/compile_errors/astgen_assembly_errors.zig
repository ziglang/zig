comptime {
    asm volatile ("");
}
comptime {
    asm (""
        : [_] "" (-> u8),
    );
}
comptime {
    asm (""
        :
        : [_] "" (0),
    );
}
comptime {
    asm ("" ::: .{});
}
export fn a() void {
    asm ("");
}
export fn b() void {
    asm (""
        : [_] "" (-> u8),
          [_] "" (-> u8),
    );
}
export fn c() void {
    var out: u8 = 0;
    asm (""
        : [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
          [_] "" (out),
    );
}
export fn d() void {
    asm volatile (""
        :
        : [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
          [_] "" (0),
    );
}

// error
//
// :2:9: error: volatile is meaningless on global assembly
// :5:5: error: global assembly cannot have inputs, outputs, or clobbers
// :10:5: error: global assembly cannot have inputs, outputs, or clobbers
// :16:5: error: global assembly cannot have inputs, outputs, or clobbers
// :19:5: error: assembly expression with no output must be marked volatile
// :24:12: error: inline assembly allows up to one output value
// :46:12: error: too many asm outputs
// :84:12: error: too many asm inputs
