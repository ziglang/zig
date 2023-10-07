//! WriteFile is primarily used to create a directory in an appropriate
//! location inside the local cache which has a set of files that have either
//! been generated during the build, or are copied from the source package.
//!
//! However, this step has an additional capability of writing data to paths
//! relative to the package root, effectively mutating the package's source
//! files. Be careful with the latter functionality; it should not be used
//! during the normal build process, but as a utility run by a developer with
//! intention to update source files, which will then be committed to version
//! control.
const std = @import("std");
const Step = std.Build.Step;
const fs = std.fs;
const ArrayList = std.ArrayList;
const WriteFile = @This();

step: Step,
/// The elements here are pointers because we need stable pointers for the
/// GeneratedFile field.
files: std.ArrayListUnmanaged(*File),
output_source_files: std.ArrayListUnmanaged(OutputSourceFile),
generated_directory: std.Build.GeneratedFile,

pub const base_id = .write_file;

pub const File = struct {
    generated_file: std.Build.GeneratedFile,
    sub_path: []const u8,
    contents: Contents,

    /// deprecated: use `getPath`
    pub const getFileSource = getPath;

    pub fn getPath(self: *File) std.Build.LazyPath {
        return .{ .generated = &self.generated_file };
    }
};

pub const OutputSourceFile = struct {
    contents: Contents,
    sub_path: []const u8,
};

pub const Contents = union(enum) {
    bytes: []const u8,
    copy: std.Build.LazyPath,
};

pub fn create(owner: *std.Build) *WriteFile {
    const wf = owner.allocator.create(WriteFile) catch @panic("OOM");
    wf.* = .{
        .step = Step.init(.{
            .id = .write_file,
            .name = "WriteFile",
            .owner = owner,
            .makeFn = make,
        }),
        .files = .{},
        .output_source_files = .{},
        .generated_directory = .{ .step = &wf.step },
    };
    return wf;
}

pub fn add(wf: *WriteFile, sub_path: []const u8, bytes: []const u8) std.Build.LazyPath {
    const b = wf.step.owner;
    const gpa = b.allocator;
    const file = gpa.create(File) catch @panic("OOM");
    file.* = .{
        .generated_file = .{ .step = &wf.step },
        .sub_path = b.dupePath(sub_path),
        .contents = .{ .bytes = b.dupe(bytes) },
    };
    wf.files.append(gpa, file) catch @panic("OOM");
    wf.maybeUpdateName();
    return file.getPath();
}

/// Place the file into the generated directory within the local cache,
/// along with all the rest of the files added to this step. The parameter
/// here is the destination path relative to the local cache directory
/// associated with this WriteFile. It may be a basename, or it may
/// include sub-directories, in which case this step will ensure the
/// required sub-path exists.
/// This is the option expected to be used most commonly with `addCopyFile`.
pub fn addCopyFile(wf: *WriteFile, source: std.Build.LazyPath, sub_path: []const u8) std.Build.LazyPath {
    const b = wf.step.owner;
    const gpa = b.allocator;
    const file = gpa.create(File) catch @panic("OOM");
    file.* = .{
        .generated_file = .{ .step = &wf.step },
        .sub_path = b.dupePath(sub_path),
        .contents = .{ .copy = source },
    };
    wf.files.append(gpa, file) catch @panic("OOM");

    wf.maybeUpdateName();
    source.addStepDependencies(&wf.step);
    return file.getPath();
}

/// A path relative to the package root.
/// Be careful with this because it updates source files. This should not be
/// used as part of the normal build process, but as a utility occasionally
/// run by a developer with intent to modify source files and then commit
/// those changes to version control.
pub fn addCopyFileToSource(wf: *WriteFile, source: std.Build.LazyPath, sub_path: []const u8) void {
    const b = wf.step.owner;
    wf.output_source_files.append(b.allocator, .{
        .contents = .{ .copy = source },
        .sub_path = sub_path,
    }) catch @panic("OOM");
    source.addStepDependencies(&wf.step);
}

/// A path relative to the package root.
/// Be careful with this because it updates source files. This should not be
/// used as part of the normal build process, but as a utility occasionally
/// run by a developer with intent to modify source files and then commit
/// those changes to version control.
pub fn addBytesToSource(wf: *WriteFile, bytes: []const u8, sub_path: []const u8) void {
    const b = wf.step.owner;
    wf.output_source_files.append(b.allocator, .{
        .contents = .{ .bytes = bytes },
        .sub_path = sub_path,
    }) catch @panic("OOM");
}

pub const getFileSource = @compileError("Deprecated; use the return value from add()/addCopyFile(), or use files[i].getPath()");

pub const getDirectorySource = getDirectory;

/// Returns a `LazyPath` representing the base directory that contains all the
/// files from this `WriteFile`.
pub fn getDirectory(wf: *WriteFile) std.Build.LazyPath {
    return .{ .generated = &wf.generated_directory };
}

fn maybeUpdateName(wf: *WriteFile) void {
    if (wf.files.items.len == 1) {
        // First time adding a file; update name.
        if (std.mem.eql(u8, wf.step.name, "WriteFile")) {
            wf.step.name = wf.step.owner.fmt("WriteFile {s}", .{wf.files.items[0].sub_path});
        }
    }
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const wf = @fieldParentPtr(WriteFile, "step", step);

    // Writing to source files is kind of an extra capability of this
    // WriteFile - arguably it should be a different step. But anyway here
    // it is, it happens unconditionally and does not interact with the other
    // files here.
    var any_miss = false;
    for (wf.output_source_files.items) |output_source_file| {
        if (fs.path.dirname(output_source_file.sub_path)) |dirname| {
            b.build_root.handle.makePath(dirname) catch |err| {
                return step.fail("unable to make path '{}{s}': {s}", .{
                    b.build_root, dirname, @errorName(err),
                });
            };
        }
        switch (output_source_file.contents) {
            .bytes => |bytes| {
                b.build_root.handle.writeFile(output_source_file.sub_path, bytes) catch |err| {
                    return step.fail("unable to write file '{}{s}': {s}", .{
                        b.build_root, output_source_file.sub_path, @errorName(err),
                    });
                };
                any_miss = true;
            },
            .copy => |file_source| {
                const source_path = file_source.getPath(b);
                const prev_status = fs.Dir.updateFile(
                    fs.cwd(),
                    source_path,
                    b.build_root.handle,
                    output_source_file.sub_path,
                    .{},
                ) catch |err| {
                    return step.fail("unable to update file from '{s}' to '{}{s}': {s}", .{
                        source_path, b.build_root, output_source_file.sub_path, @errorName(err),
                    });
                };
                any_miss = any_miss or prev_status == .stale;
            },
        }
    }

    // The cache is used here not really as a way to speed things up - because writing
    // the data to a file would probably be very fast - but as a way to find a canonical
    // location to put build artifacts.

    // If, for example, a hard-coded path was used as the location to put WriteFile
    // files, then two WriteFiles executing in parallel might clobber each other.

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make WriteFile unique. Refresh this with
    // new random bytes when WriteFile implementation is modified
    // in a non-backwards-compatible way.
    man.hash.add(@as(u32, 0xd767ee59));

    for (wf.files.items) |file| {
        man.hash.addBytes(file.sub_path);
        switch (file.contents) {
            .bytes => |bytes| {
                man.hash.addBytes(bytes);
            },
            .copy => |file_source| {
                _ = try man.addFile(file_source.getPath(b), null);
            },
        }
    }

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        for (wf.files.items) |file| {
            file.generated_file.path = try b.cache_root.join(b.allocator, &.{
                "o", &digest, file.sub_path,
            });
        }
        wf.generated_directory.path = try b.cache_root.join(b.allocator, &.{ "o", &digest });
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ fs.path.sep_str ++ digest;

    wf.generated_directory.path = try b.cache_root.join(b.allocator, &.{ "o", &digest });

    var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
        return step.fail("unable to make path '{}{s}': {s}", .{
            b.cache_root, cache_path, @errorName(err),
        });
    };
    defer cache_dir.close();

    for (wf.files.items) |file| {
        if (fs.path.dirname(file.sub_path)) |dirname| {
            cache_dir.makePath(dirname) catch |err| {
                return step.fail("unable to make path '{}{s}{c}{s}': {s}", .{
                    b.cache_root, cache_path, fs.path.sep, dirname, @errorName(err),
                });
            };
        }
        switch (file.contents) {
            .bytes => |bytes| {
                cache_dir.writeFile(file.sub_path, bytes) catch |err| {
                    return step.fail("unable to write file '{}{s}{c}{s}': {s}", .{
                        b.cache_root, cache_path, fs.path.sep, file.sub_path, @errorName(err),
                    });
                };
            },
            .copy => |file_source| {
                const source_path = file_source.getPath(b);
                const prev_status = fs.Dir.updateFile(
                    fs.cwd(),
                    source_path,
                    cache_dir,
                    file.sub_path,
                    .{},
                ) catch |err| {
                    return step.fail("unable to update file from '{s}' to '{}{s}{c}{s}': {s}", .{
                        source_path,
                        b.cache_root,
                        cache_path,
                        fs.path.sep,
                        file.sub_path,
                        @errorName(err),
                    });
                };
                // At this point we already will mark the step as a cache miss.
                // But this is kind of a partial cache hit since individual
                // file copies may be avoided. Oh well, this information is
                // discarded.
                _ = prev_status;
            },
        }

        file.generated_file.path = try b.cache_root.join(b.allocator, &.{
            cache_path, file.sub_path,
        });
    }

    try step.writeManifest(&man);
}
