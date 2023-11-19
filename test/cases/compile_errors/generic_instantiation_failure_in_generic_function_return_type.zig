const std = @import("std");

pub export fn entry() void {
    var ohnoes: *usize = undefined;
    _ = sliceAsBytes(ohnoes);
    _ = &ohnoes;
}
fn sliceAsBytes(slice: anytype) std.meta.trait.isPtrTo(.Array)(@TypeOf(slice)) {}

// error
// backend=llvm
// target=native
//
// :8:63: error: expected type 'type', found 'bool'
