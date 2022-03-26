const x = if (undefined) true else false;

export fn entry() usize { return @sizeOf(@TypeOf(x)); }

// branch on undefined value
//
// tmp.zig:1:15: error: use of undefined value here causes undefined behavior
