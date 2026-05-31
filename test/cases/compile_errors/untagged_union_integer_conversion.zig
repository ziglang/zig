const UntaggedUnion = union {};
comptime {
    @intFromEnum(@as(UntaggedUnion, undefined));
}

// error
//
// :3:18: error: untagged union 'tmp.UntaggedUnion' cannot be converted to integer
// :1:23: note: union declared here
