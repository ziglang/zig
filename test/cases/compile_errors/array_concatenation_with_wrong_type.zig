const src = "aoeu";
const derp: usize = 1234;
const a = derp ++ "foo";

export fn entry() usize {
    return @sizeOf(@TypeOf(a));
}

// error
// backend=stage2
// target=native
//
// :3:11: error: expected indexable; found 'usize'
