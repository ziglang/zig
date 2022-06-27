fn a() noreturn {return;}
export fn entry() void { a(); }

// error
// backend=stage2
// target=native
//
// :1:18: error: expected type 'noreturn', found 'void'
