fn a() noreturn {return;}
export fn entry() void { a(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:18: error: expected type 'noreturn', found 'void'
