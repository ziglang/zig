const debug = @import("../debug.zig");
const assert = debug.assert;
const mem = @import("../mem.zig");
const Allocator = mem.Allocator;

/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: &Allocator, paths: ...) -> %[]u8 {
    assert(paths.len >= 2);
    var total_paths_len: usize = paths.len; // 1 slash per path
    {
        comptime var path_i = 0;
        inline while (path_i < paths.len; path_i += 1) {
            const arg = ([]const u8)(paths[path_i]);
            total_paths_len += arg.len;
        }
    }

    const buf = %return allocator.alloc(u8, total_paths_len);
    %defer allocator.free(buf);

    var buf_index: usize = 0;
    comptime var path_i = 0;
    inline while (true) {
        const arg = ([]const u8)(paths[path_i]);
        path_i += 1;
        mem.copy(u8, buf[buf_index...], arg);
        buf_index += arg.len;
        if (path_i >= paths.len) break;
        if (arg[arg.len - 1] != '/') {
            buf[buf_index] = '/';
            buf_index += 1;
        }
    }

    return buf[0...buf_index];
}

test "os.path.join" {
    assert(mem.eql(u8, %%join(&debug.global_allocator, "/a/b", "c"), "/a/b/c"));
    assert(mem.eql(u8, %%join(&debug.global_allocator, "/a/b/", "c"), "/a/b/c"));

    assert(mem.eql(u8, %%join(&debug.global_allocator, "/", "a", "b/", "c"), "/a/b/c"));
    assert(mem.eql(u8, %%join(&debug.global_allocator, "/a/", "b/", "c"), "/a/b/c"));
}

pub fn dirname(allocator: &Allocator, path: []const u8) -> %[]u8 {
    if (path.len != 0) {
        var last_index: usize = path.len - 1;
        if (path[last_index] == '/')
            last_index -= 1;

        var i: usize = last_index;
        while (true) {
            const c = path[i];
            if (c == '/')
                return mem.dupe(allocator, u8, path[0...i]);
            if (i == 0)
                break;
            i -= 1;
        }
    }

    return mem.dupe(allocator, u8, ".");
}
