//! WriteFile is used to create a directory in an appropriate location inside
//! the local cache which has a set of files that have either been generated
//! during the build, or are copied from the source package.
const std = @import("std");
const Step = std.Build.Step;
const fs = std.fs;
const ArrayList = std.ArrayList;
const WriteFile = @This();

step: Step,

// The elements here are pointers because we need stable pointers for the GeneratedFile field.
files: std.ArrayListUnmanaged(File),
directories: std.ArrayListUnmanaged(Directory),
generated_directory: std.Build.GeneratedFile,

pub const base_id: Step.Id = .write_file;

pub const File = struct {
    sub_path: []const u8,
    contents: Contents,
};

pub const Directory = struct {
    source: std.Build.LazyPath,
    sub_path: []const u8,
    options: Options,

    pub const Options = struct {
        /// File paths that end in any of these suffixes will be excluded from copying.
        exclude_extensions: []const []const u8 = &.{},
        /// Only file paths that end in any of these suffixes will be included in copying.
        /// `null` means that all suffixes will be included.
        /// `exclude_extensions` takes precedence over `include_extensions`.
        include_extensions: ?[]const []const u8 = null,

        pub fn dupe(opts: Options, b: *std.Build) Options {
            return .{
                .exclude_extensions = b.dupeStrings(opts.exclude_extensions),
                .include_extensions = if (opts.include_extensions) |incs| b.dupeStrings(incs) else null,
            };
        }

        pub fn pathIncluded(opts: Options, path: []const u8) bool {
            for (opts.exclude_extensions) |ext| {
                if (std.mem.endsWith(u8, path, ext))
                    return false;
            }
            if (opts.include_extensions) |incs| {
                for (incs) |inc| {
                    if (std.mem.endsWith(u8, path, inc))
                        return true;
                } else {
                    return false;
                }
            }
            return true;
        }
    };
};

pub const Contents = union(enum) {
    bytes: []const u8,
    copy: std.Build.LazyPath,
};

pub fn create(owner: *std.Build) *WriteFile {
    const write_file = owner.allocator.create(WriteFile) catch @panic("OOM");
    write_file.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "WriteFile",
            .owner = owner,
            .makeFn = make,
        }),
        .files = .{},
        .directories = .{},
        .generated_directory = .{ .step = &write_file.step },
    };
    return write_file;
}

pub fn add(write_file: *WriteFile, sub_path: []const u8, bytes: []const u8) std.Build.LazyPath {
    const b = write_file.step.owner;
    const gpa = b.allocator;
    const file = File{
        .sub_path = b.dupePath(sub_path),
        .contents = .{ .bytes = b.dupe(bytes) },
    };
    write_file.files.append(gpa, file) catch @panic("OOM");
    write_file.maybeUpdateName();
    return .{
        .generated = .{
            .file = &write_file.generated_directory,
            .sub_path = file.sub_path,
        },
    };
}

/// Place the file into the generated directory within the local cache,
/// along with all the rest of the files added to this step. The parameter
/// here is the destination path relative to the local cache directory
/// associated with this WriteFile. It may be a basename, or it may
/// include sub-directories, in which case this step will ensure the
/// required sub-path exists.
/// This is the option expected to be used most commonly with `addCopyFile`.
pub fn addCopyFile(write_file: *WriteFile, source: std.Build.LazyPath, sub_path: []const u8) std.Build.LazyPath {
    const b = write_file.step.owner;
    const gpa = b.allocator;
    const file = File{
        .sub_path = b.dupePath(sub_path),
        .contents = .{ .copy = source },
    };
    write_file.files.append(gpa, file) catch @panic("OOM");

    write_file.maybeUpdateName();
    source.addStepDependencies(&write_file.step);
    return .{
        .generated = .{
            .file = &write_file.generated_directory,
            .sub_path = file.sub_path,
        },
    };
}

/// Copy files matching the specified exclude/include patterns to the specified subdirectory
/// relative to this step's generated directory.
/// The returned value is a lazy path to the generated subdirectory.
pub fn addCopyDirectory(
    write_file: *WriteFile,
    source: std.Build.LazyPath,
    sub_path: []const u8,
    options: Directory.Options,
) std.Build.LazyPath {
    const b = write_file.step.owner;
    const gpa = b.allocator;
    const dir = Directory{
        .source = source.dupe(b),
        .sub_path = b.dupePath(sub_path),
        .options = options.dupe(b),
    };
    write_file.directories.append(gpa, dir) catch @panic("OOM");

    write_file.maybeUpdateName();
    source.addStepDependencies(&write_file.step);
    return .{
        .generated = .{
            .file = &write_file.generated_directory,
            .sub_path = dir.sub_path,
        },
    };
}

/// Returns a `LazyPath` representing the base directory that contains all the
/// files from this `WriteFile`.
pub fn getDirectory(write_file: *WriteFile) std.Build.LazyPath {
    return .{ .generated = .{ .file = &write_file.generated_directory } };
}

fn maybeUpdateName(write_file: *WriteFile) void {
    if (write_file.files.items.len == 1 and write_file.directories.items.len == 0) {
        // First time adding a file; update name.
        if (std.mem.eql(u8, write_file.step.name, "WriteFile")) {
            write_file.step.name = write_file.step.owner.fmt("WriteFile {s}", .{write_file.files.items[0].sub_path});
        }
    } else if (write_file.directories.items.len == 1 and write_file.files.items.len == 0) {
        // First time adding a directory; update name.
        if (std.mem.eql(u8, write_file.step.name, "WriteFile")) {
            write_file.step.name = write_file.step.owner.fmt("WriteFile {s}", .{write_file.directories.items[0].sub_path});
        }
    }
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const arena = b.allocator;
    const gpa = arena;
    const write_file: *WriteFile = @fieldParentPtr("step", step);
    step.clearWatchInputs();

    // The cache is used here not really as a way to speed things up - because writing
    // the data to a file would probably be very fast - but as a way to find a canonical
    // location to put build artifacts.

    // If, for example, a hard-coded path was used as the location to put WriteFile
    // files, then two WriteFiles executing in parallel might clobber each other.

    var man = b.graph.cache.obtain();
    defer man.deinit();

    for (write_file.files.items) |file| {
        man.hash.addBytes(file.sub_path);

        switch (file.contents) {
            .bytes => |bytes| {
                man.hash.addBytes(bytes);
            },
            .copy => |lazy_path| {
                const path = lazy_path.getPath3(b, step);
                _ = try man.addFilePath(path, null);
                try step.addWatchInput(lazy_path);
            },
        }
    }

    const open_dir_cache = try arena.alloc(fs.Dir, write_file.directories.items.len);
    var open_dirs_count: usize = 0;
    defer closeDirs(open_dir_cache[0..open_dirs_count]);

    for (write_file.directories.items, open_dir_cache) |dir, *open_dir_cache_elem| {
        man.hash.addBytes(dir.sub_path);
        for (dir.options.exclude_extensions) |ext| man.hash.addBytes(ext);
        if (dir.options.include_extensions) |incs| for (incs) |inc| man.hash.addBytes(inc);

        const need_derived_inputs = try step.addDirectoryWatchInput(dir.source);
        const src_dir_path = dir.source.getPath3(b, step);

        var src_dir = src_dir_path.root_dir.handle.openDir(src_dir_path.subPathOrDot(), .{ .iterate = true }) catch |err| {
            return step.fail("unable to open source directory '{}': {s}", .{
                src_dir_path, @errorName(err),
            });
        };
        open_dir_cache_elem.* = src_dir;
        open_dirs_count += 1;

        var it = try src_dir.walk(gpa);
        defer it.deinit();
        while (try it.next()) |entry| {
            if (!dir.options.pathIncluded(entry.path)) continue;

            switch (entry.kind) {
                .directory => {
                    if (need_derived_inputs) {
                        const entry_path = try src_dir_path.join(arena, entry.path);
                        try step.addDirectoryWatchInputFromPath(entry_path);
                    }
                },
                .file => {
                    const entry_path = try src_dir_path.join(arena, entry.path);
                    _ = try man.addFilePath(entry_path, null);
                },
                else => continue,
            }
        }
    }

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        write_file.generated_directory.path = try b.cache_root.join(arena, &.{ "o", &digest });
        step.result_cached = true;
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ fs.path.sep_str ++ digest;

    write_file.generated_directory.path = try b.cache_root.join(arena, &.{ "o", &digest });

    var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
        return step.fail("unable to make path '{}{s}': {s}", .{
            b.cache_root, cache_path, @errorName(err),
        });
    };
    defer cache_dir.close();

    const cwd = fs.cwd();

    for (write_file.files.items) |file| {
        if (fs.path.dirname(file.sub_path)) |dirname| {
            cache_dir.makePath(dirname) catch |err| {
                return step.fail("unable to make path '{}{s}{c}{s}': {s}", .{
                    b.cache_root, cache_path, fs.path.sep, dirname, @errorName(err),
                });
            };
        }
        switch (file.contents) {
            .bytes => |bytes| {
                cache_dir.writeFile(.{ .sub_path = file.sub_path, .data = bytes }) catch |err| {
                    return step.fail("unable to write file '{}{s}{c}{s}': {s}", .{
                        b.cache_root, cache_path, fs.path.sep, file.sub_path, @errorName(err),
                    });
                };
            },
            .copy => |file_source| {
                const source_path = file_source.getPath2(b, step);
                const prev_status = fs.Dir.updateFile(
                    cwd,
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
    }

    for (write_file.directories.items, open_dir_cache) |dir, already_open_dir| {
        const src_dir_path = dir.source.getPath3(b, step);
        const dest_dirname = dir.sub_path;

        if (dest_dirname.len != 0) {
            cache_dir.makePath(dest_dirname) catch |err| {
                return step.fail("unable to make path '{}{s}{c}{s}': {s}", .{
                    b.cache_root, cache_path, fs.path.sep, dest_dirname, @errorName(err),
                });
            };
        }

        var it = try already_open_dir.walk(gpa);
        defer it.deinit();
        while (try it.next()) |entry| {
            if (!dir.options.pathIncluded(entry.path)) continue;

            const src_entry_path = try src_dir_path.join(arena, entry.path);
            const dest_path = b.pathJoin(&.{ dest_dirname, entry.path });
            switch (entry.kind) {
                .directory => try cache_dir.makePath(dest_path),
                .file => {
                    const prev_status = fs.Dir.updateFile(
                        src_entry_path.root_dir.handle,
                        src_entry_path.sub_path,
                        cache_dir,
                        dest_path,
                        .{},
                    ) catch |err| {
                        return step.fail("unable to update file from '{}' to '{}{s}{c}{s}': {s}", .{
                            src_entry_path, b.cache_root, cache_path, fs.path.sep, dest_path, @errorName(err),
                        });
                    };
                    _ = prev_status;
                },
                else => continue,
            }
        }
    }

    try step.writeManifest(&man);
}

fn closeDirs(dirs: []fs.Dir) void {
    for (dirs) |*d| d.close();
}
