const UntaggedUnion = union {};
comptime {
    @intFromEnum(@as(UntaggedUnion, undefined));
}

// error
// backend=stage2
// target=native
//
// :3:18: error: untagged union 'tmp.UntaggedUnion' cannot be converted to integer
// :1:23: note: union declared here
