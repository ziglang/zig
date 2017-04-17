const debug = @import("../debug.zig");
const assert = debug.assert;
const mem = @import("../mem.zig");
const Allocator = mem.Allocator;

/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: &Allocator, dirname: []const u8, basename: []const u8) -> %[]const u8 {
    const buf = %return allocator.alloc(u8, dirname.len + basename.len + 1);
    %defer allocator.free(buf);

    mem.copy(u8, buf, dirname);
    if (dirname[dirname.len - 1] == '/') {
        mem.copy(u8, buf[dirname.len...], basename);
        return buf[0...buf.len - 1];
    } else {
        buf[dirname.len] = '/';
        mem.copy(u8, buf[dirname.len + 1 ...], basename);
        return buf;
    }
}

test "os.path.join" {
    assert(mem.eql(u8, %%join(&debug.global_allocator, "/a/b", "c"), "/a/b/c"));
    assert(mem.eql(u8, %%join(&debug.global_allocator, "/a/b/", "c"), "/a/b/c"));
}
