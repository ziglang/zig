const builtin = @import("builtin");
const Os = builtin.Os;
const debug = @import("../debug.zig");
const assert = debug.assert;
const mem = @import("../mem.zig");
const fmt = @import("../fmt.zig");
const Allocator = mem.Allocator;
const os = @import("index.zig");
const math = @import("../math.zig");
const posix = os.posix;

pub const sep = switch (builtin.os) {
    Os.windows => '\\',
    else => '/',
};
pub const delimiter = switch (builtin.os) {
    Os.windows => ';',
    else => ':',
};

/// Naively combines a series of paths with the native path seperator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: &Allocator, paths: ...) -> %[]u8 {
    comptime assert(paths.len >= 2);
    var total_paths_len: usize = paths.len; // 1 slash per path
    {
        comptime var path_i = 0;
        inline while (path_i < paths.len) : (path_i += 1) {
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
        mem.copy(u8, buf[buf_index..], arg);
        buf_index += arg.len;
        if (path_i >= paths.len) break;
        if (buf[buf_index - 1] != sep) {
            buf[buf_index] = sep;
            buf_index += 1;
        }
    }

    return buf[0..buf_index];
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
    switch (builtin.os) {
        Os.windows => @compileError("Unsupported OS"),
        else => return path[0] == sep,
    }
}

/// This function is like a series of `cd` statements executed one after another.
/// The result does not have a trailing path separator.
pub fn resolve(allocator: &Allocator, args: ...) -> %[]u8 {
    var paths: [args.len][]const u8 = undefined;
    comptime var arg_i = 0;
    inline while (arg_i < args.len) : (arg_i += 1) {
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

    for (paths[first_index..]) |p, i| {
        var it = mem.split(p, '/');
        while (it.next()) |component| {
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
                mem.copy(u8, result[result_index..], component);
                result_index += component.len;
            }
        }
    }

    if (result_index == 0) {
        result[0] = '/';
        result_index += 1;
    }

    return result[0..result_index];
}

test "os.path.resolve" {
    assert(mem.eql(u8, testResolve("/a/b", "c"), "/a/b/c"));
    assert(mem.eql(u8, testResolve("/a/b", "c", "//d", "e///"), "/d/e"));
    assert(mem.eql(u8, testResolve("/a/b/c", "..", "../"), "/a"));
    assert(mem.eql(u8, testResolve("/", "..", ".."), "/"));
    assert(mem.eql(u8, testResolve("/a/b/c/"), "/a/b/c"));
}
fn testResolve(args: ...) -> []u8 {
    return %%resolve(&debug.global_allocator, args);
}

pub fn dirname(path: []const u8) -> []const u8 {
    if (path.len == 0)
        return path[0..0];
    var end_index: usize = path.len - 1;
    while (path[end_index] == '/') {
        if (end_index == 0)
            return path[0..1];
        end_index -= 1;
    }

    while (path[end_index] != '/') {
        if (end_index == 0)
            return path[0..0];
        end_index -= 1;
    }

    if (end_index == 0 and path[end_index] == '/')
        return path[0..1];

    return path[0..end_index];
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

pub fn basename(path: []const u8) -> []const u8 {
    if (path.len == 0)
        return []u8{};

    var end_index: usize = path.len - 1;
    while (path[end_index] == '/') {
        if (end_index == 0)
            return []u8{};
        end_index -= 1;
    }
    var start_index: usize = end_index;
    end_index += 1;
    while (path[start_index] != '/') {
        if (start_index == 0)
            return path[0..end_index];
        start_index -= 1;
    }

    return path[start_index + 1..end_index];
}

test "os.path.basename" {
    testBasename("", "");
    testBasename("/", "");
    testBasename("/dir/basename.ext", "basename.ext");
    testBasename("/basename.ext", "basename.ext");
    testBasename("basename.ext", "basename.ext");
    testBasename("basename.ext/", "basename.ext");
    testBasename("basename.ext//", "basename.ext");
    testBasename("/aaa/bbb", "bbb");
    testBasename("/aaa/", "aaa");
    testBasename("/aaa/b", "b");
    testBasename("/a/b", "b");
    testBasename("//a", "a");
}
fn testBasename(input: []const u8, expected_output: []const u8) {
    assert(mem.eql(u8, basename(input), expected_output));
}

/// Returns the relative path from ::from to ::to. If ::from and ::to each
/// resolve to the same path (after calling ::resolve on each), a zero-length
/// string is returned.
pub fn relative(allocator: &Allocator, from: []const u8, to: []const u8) -> %[]u8 {
    const resolved_from = %return resolve(allocator, from);
    defer allocator.free(resolved_from);

    const resolved_to = %return resolve(allocator, to);
    defer allocator.free(resolved_to);

    var from_it = mem.split(resolved_from, '/');
    var to_it = mem.split(resolved_to, '/');
    while (true) {
        const from_component = from_it.next() ?? return mem.dupe(allocator, u8, to_it.rest());
        const to_rest = to_it.rest();
        if (to_it.next()) |to_component| {
            if (mem.eql(u8, from_component, to_component))
                continue;
        }
        var up_count: usize = 1;
        while (from_it.next()) |_| {
            up_count += 1;
        }
        const up_index_end = up_count * "../".len;
        const result = %return allocator.alloc(u8, up_index_end + to_rest.len);
        %defer allocator.free(result);

        var result_index: usize = 0;
        while (result_index < up_index_end) {
            result[result_index] = '.';
            result_index += 1;
            result[result_index] = '.';
            result_index += 1;
            result[result_index] = '/';
            result_index += 1;
        }
        if (to_rest.len == 0) {
            // shave off the trailing slash
            return result[0..result_index - 1];
        }

        mem.copy(u8, result[result_index..], to_rest);
        return result;
    }

    return []u8{};
}

test "os.path.relative" {
    testRelative("/var/lib", "/var", "..");
    testRelative("/var/lib", "/bin", "../../bin");
    testRelative("/var/lib", "/var/lib", "");
    testRelative("/var/lib", "/var/apache", "../apache");
    testRelative("/var/", "/var/lib", "lib");
    testRelative("/", "/var/lib", "var/lib");
    testRelative("/foo/test", "/foo/test/bar/package.json", "bar/package.json");
    testRelative("/Users/a/web/b/test/mails", "/Users/a/web/b", "../..");
    testRelative("/foo/bar/baz-quux", "/foo/bar/baz", "../baz");
    testRelative("/foo/bar/baz", "/foo/bar/baz-quux", "../baz-quux");
    testRelative("/baz-quux", "/baz", "../baz");
    testRelative("/baz", "/baz-quux", "../baz-quux");
}
fn testRelative(from: []const u8, to: []const u8, expected_output: []const u8) {
    const result = %%relative(&debug.global_allocator, from, to);
    assert(mem.eql(u8, result, expected_output));
}

/// Return the canonicalized absolute pathname.
/// Expands all symbolic links and resolves references to `.`, `..`, and
/// extra `/` characters in ::pathname.
/// Caller must deallocate result.
pub fn real(allocator: &Allocator, pathname: []const u8) -> %[]u8 {
    const fd = %return os.posixOpen(pathname, posix.O_PATH|posix.O_NONBLOCK|posix.O_CLOEXEC, 0, allocator);
    defer os.posixClose(fd);

    var buf: ["/proc/self/fd/-2147483648".len]u8 = undefined;
    const proc_path = fmt.bufPrint(buf[0..], "/proc/self/fd/{}", fd);

    return os.readLink(allocator, proc_path);
}
