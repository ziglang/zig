const std = @import("../std.zig");
const Step = std.Build.Step;
const fs = std.fs;
const ArrayList = std.ArrayList;

const WriteFileStep = @This();

pub const base_id = .write_file;

step: Step,
builder: *std.Build,
files: std.TailQueue(File),

pub const File = struct {
    source: std.Build.GeneratedFile,
    basename: []const u8,
    bytes: []const u8,
};

pub fn init(builder: *std.Build) WriteFileStep {
    return WriteFileStep{
        .builder = builder,
        .step = Step.init(.write_file, "writefile", builder.allocator, make),
        .files = .{},
    };
}

pub fn add(self: *WriteFileStep, basename: []const u8, bytes: []const u8) void {
    const node = self.builder.allocator.create(std.TailQueue(File).Node) catch @panic("unhandled error");
    node.* = .{
        .data = .{
            .source = std.Build.GeneratedFile{ .step = &self.step },
            .basename = self.builder.dupePath(basename),
            .bytes = self.builder.dupe(bytes),
        },
    };

    self.files.append(node);
}

/// Gets a file source for the given basename. If the file does not exist, returns `null`.
pub fn getFileSource(step: *WriteFileStep, basename: []const u8) ?std.Build.FileSource {
    var it = step.files.first;
    while (it) |node| : (it = node.next) {
        if (std.mem.eql(u8, node.data.basename, basename))
            return std.Build.FileSource{ .generated = &node.data.source };
    }
    return null;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(WriteFileStep, "step", step);

    // The cache is used here not really as a way to speed things up - because writing
    // the data to a file would probably be very fast - but as a way to find a canonical
    // location to put build artifacts.

    // If, for example, a hard-coded path was used as the location to put WriteFileStep
    // files, then two WriteFileSteps executing in parallel might clobber each other.

    // TODO port the cache system from the compiler to zig std lib. Until then
    // we directly construct the path, and no "cache hit" detection happens;
    // the files are always written.
    // Note there is similar code over in ConfigHeaderStep.
    const Hasher = std.crypto.auth.siphash.SipHash128(1, 3);
    // Random bytes to make WriteFileStep unique. Refresh this with
    // new random bytes when WriteFileStep implementation is modified
    // in a non-backwards-compatible way.
    var hash = Hasher.init("eagVR1dYXoE7ARDP");

    {
        var it = self.files.first;
        while (it) |node| : (it = node.next) {
            hash.update(node.data.basename);
            hash.update(node.data.bytes);
            hash.update("|");
        }
    }
    var digest: [16]u8 = undefined;
    hash.final(&digest);
    var hash_basename: [digest.len * 2]u8 = undefined;
    _ = std.fmt.bufPrint(
        &hash_basename,
        "{s}",
        .{std.fmt.fmtSliceHexLower(&digest)},
    ) catch unreachable;

    const output_dir = try fs.path.join(self.builder.allocator, &[_][]const u8{
        self.builder.cache_root, "o", &hash_basename,
    });
    var dir = fs.cwd().makeOpenPath(output_dir, .{}) catch |err| {
        std.debug.print("unable to make path {s}: {s}\n", .{ output_dir, @errorName(err) });
        return err;
    };
    defer dir.close();
    {
        var it = self.files.first;
        while (it) |node| : (it = node.next) {
            dir.writeFile(node.data.basename, node.data.bytes) catch |err| {
                std.debug.print("unable to write {s} into {s}: {s}\n", .{
                    node.data.basename,
                    output_dir,
                    @errorName(err),
                });
                return err;
            };
            node.data.source.path = try fs.path.join(
                self.builder.allocator,
                &[_][]const u8{ output_dir, node.data.basename },
            );
        }
    }
}
