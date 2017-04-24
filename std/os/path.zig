const debug = @import("../debug.zig");
const assert = debug.assert;
const mem = @import("../mem.zig");
const Allocator = mem.Allocator;
const os = @import("index.zig");

pub const sep = '/';

/// Naively combines a series of paths with the native path seperator.
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
        if (buf[buf_index - 1] != sep) {
            buf[buf_index] = sep;
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

    assert(mem.eql(u8, %%join(&debug.global_allocator, "/home/andy/dev/zig/build/lib/zig/std", "io.zig"),
        "/home/andy/dev/zig/build/lib/zig/std/io.zig"));
}

pub fn isAbsolute(path: []const u8) -> bool {
    switch (@compileVar("os")) {
        Os.windows => @compileError("Unsupported OS"),
        else => return path[0] == sep,
    }
}

/// This function is like a series of `cd` statements executed one after another.
/// The result does not have a trailing path separator.
pub fn resolve(allocator: &Allocator, args: ...) -> %[]u8 {
    var paths: [args.len][]const u8 = undefined;
    comptime var arg_i = 0;
    inline while (arg_i < args.len; arg_i += 1) {
        paths[arg_i] = args[arg_i];
    }
    return resolveSlice(allocator, paths);
}

pub fn resolveSlice(allocator: &Allocator, paths: []const []const u8) -> %[]u8 {
    if (paths.len == 0)
        return os.getCwd(allocator);

    var first_index: usize = 0;
    var have_abs = false;
    var max_size: usize = 0;
    for (paths) |p, i| {
        if (isAbsolute(p)) {
            first_index = i;
            have_abs = true;
            max_size = 0;
        }
        max_size += p.len + 1;
    }

    var result: []u8 = undefined;
    var result_index: usize = 0;

    if (have_abs) {
        result = %return allocator.alloc(u8, max_size);
    } else {
        const cwd = %return os.getCwd(allocator);
        defer allocator.free(cwd);
        result = %return allocator.alloc(u8, max_size + cwd.len + 1);
        mem.copy(u8, result, cwd);
        result_index += cwd.len;
    }
    %defer allocator.free(result);

    for (paths[first_index...]) |p, i| {
        var it = mem.split(p, '/');
        while (true) {
            const component = it.next() ?? break;
            if (mem.eql(u8, component, ".")) {
                continue;
            } else if (mem.eql(u8, component, "..")) {
                while (true) {
                    if (result_index == 0)
                        break;
                    result_index -= 1;
                    if (result[result_index] == '/')
                        break;
                }
            } else {
                result[result_index] = '/';
                result_index += 1;
                mem.copy(u8, result[result_index...], component);
                result_index += component.len;
            }
        }
    }

    if (result_index == 0) {
        result[0] = '/';
        result_index += 1;
    }

    return result[0...result_index];
}

test "os.path.resolve" {
    assert(mem.eql(u8, testResolve("/a/b", "c"), "/a/b/c"));
    assert(mem.eql(u8, testResolve("/a/b", "c", "//d", "e///"), "/d/e"));
    assert(mem.eql(u8, testResolve("/a/b/c", "..", "../"), "/a"));
    assert(mem.eql(u8, testResolve("/", "..", ".."), "/"));
}
fn testResolve(args: ...) -> []u8 {
    return %%resolve(&debug.global_allocator, args);
}

pub fn dirname(path: []const u8) -> []const u8 {
    if (path.len == 0)
        return path[0...0];
    var end_index: usize = path.len - 1;
    while (path[end_index] == '/') {
        if (end_index == 0)
            return path[0...1];
        end_index -= 1;
    }

    while (path[end_index] != '/') {
        if (end_index == 0)
            return path[0...0];
        end_index -= 1;
    }

    if (end_index == 0 and path[end_index] == '/')
        return path[0...1];

    return path[0...end_index];
}

test "os.path.dirname" {
    testDirname("/a/b/c", "/a/b");
    testDirname("/a/b/c///", "/a/b");
    testDirname("/a", "/");
    testDirname("/", "/");
    testDirname("////", "/");
    testDirname("", "");
    testDirname("a", "");
    testDirname("a/", "");
    testDirname("a//", "");
}
fn testDirname(input: []const u8, expected_output: []const u8) {
    assert(mem.eql(u8, dirname(input), expected_output));
}
