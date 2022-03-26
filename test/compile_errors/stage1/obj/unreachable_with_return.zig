fn a() noreturn {return;}
export fn entry() void { a(); }

// unreachable with return
//
// tmp.zig:1:18: error: expected type 'noreturn', found 'void'
