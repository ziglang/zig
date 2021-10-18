const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

// comptime array passed as slice argument
comptime {
    const S = struct {
        fn indexOfScalarPos(comptime T: type, slice: []const T, start_index: usize, value: T) ?usize {
            var i: usize = start_index;
            while (i < slice.len) : (i += 1) {
                if (slice[i] == value) return i;
            }
            return null;
        }

        fn indexOfScalar(comptime T: type, slice: []const T, value: T) ?usize {
            return indexOfScalarPos(T, slice, 0, value);
        }
    };
    const unsigned = [_]type{ c_uint, c_ulong, c_ulonglong };
    const list: []const type = &unsigned;
    var pos = S.indexOfScalar(type, list, c_ulong).?;
    if (pos != 1) @compileError("bad pos");
}
