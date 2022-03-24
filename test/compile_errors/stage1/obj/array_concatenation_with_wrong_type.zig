const src = "aoeu";
const derp: usize = 1234;
const a = derp ++ "foo";

export fn entry() usize { return @sizeOf(@TypeOf(a)); }

// array concatenation with wrong type
//
// tmp.zig:3:11: error: expected array, found 'usize'
