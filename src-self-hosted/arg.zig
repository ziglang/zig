const std = @import("std");
const debug = std.debug;
const mem = std.mem;

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;

fn trimStart(slice: []const u8, ch: u8) []const u8 {
    var i: usize = 0;
    for (slice) |b| {
        if (b != '-') break;
        i += 1;
    }

    return slice[i..];
}

fn argInAllowedSet(maybe_set: ?[]const []const u8, arg: []const u8) bool {
    if (maybe_set) |set| {
        for (set) |possible| {
            if (mem.eql(u8, arg, possible)) {
                return true;
            }
        }
        return false;
    } else {
        return true;
    }
}

// Modifies the current argument index during iteration
fn readFlagArguments(allocator: *Allocator, args: []const []const u8, required: usize, allowed_set: ?[]const []const u8, index: *usize) !FlagArg {
    switch (required) {
        0 => return FlagArg{ .None = undefined }, // TODO: Required to force non-tag but value?
        1 => {
            if (index.* + 1 >= args.len) {
                return error.MissingFlagArguments;
            }

            index.* += 1;
            const arg = args[index.*];

            if (!argInAllowedSet(allowed_set, arg)) {
                return error.ArgumentNotInAllowedSet;
            }

            return FlagArg{ .Single = arg };
        },
        else => |needed| {
            var extra = ArrayList([]const u8).init(allocator);
            errdefer extra.deinit();

            var j: usize = 0;
            while (j < needed) : (j += 1) {
                if (index.* + 1 >= args.len) {
                    return error.MissingFlagArguments;
                }

                index.* += 1;
                const arg = args[index.*];

                if (!argInAllowedSet(allowed_set, arg)) {
                    return error.ArgumentNotInAllowedSet;
                }

                try extra.append(arg);
            }

            return FlagArg{ .Many = extra };
        },
    }
}

const HashMapFlags = HashMap([]const u8, FlagArg, std.hash.Fnv1a_32.hash, mem.eql_slice_u8);

// A store for querying found flags and positional arguments.
pub const Args = struct {
    flags: HashMapFlags,
    positionals: ArrayList([]const u8),

    pub fn parse(allocator: *Allocator, comptime spec: []const Flag, args: []const []const u8) !Args {
        var parsed = Args{
            .flags = HashMapFlags.init(allocator),
            .positionals = ArrayList([]const u8).init(allocator),
        };

        var i: usize = 0;
        next: while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (arg.len != 0 and arg[0] == '-') {
                // TODO: hashmap, although the linear scan is okay for small argument sets as is
                for (spec) |flag| {
                    if (mem.eql(u8, arg, flag.name)) {
                        const flag_name_trimmed = trimStart(flag.name, '-');
                        const flag_args = readFlagArguments(allocator, args, flag.required, flag.allowed_set, &i) catch |err| {
                            switch (err) {
                                error.ArgumentNotInAllowedSet => {
                                    std.debug.warn("argument '{}' is invalid for flag '{}'\n", args[i], arg);
                                    std.debug.warn("allowed options are ");
                                    for (flag.allowed_set.?) |possible| {
                                        std.debug.warn("'{}' ", possible);
                                    }
                                    std.debug.warn("\n");
                                },
                                error.MissingFlagArguments => {
                                    std.debug.warn("missing argument for flag: {}\n", arg);
                                },
                                else => {},
                            }

                            return err;
                        };

                        if (flag.mergable) {
                            var prev = if (parsed.flags.get(flag_name_trimmed)) |entry| entry.value.Many else ArrayList([]const u8).init(allocator);

                            // MergeN creation disallows 0 length flag entry (doesn't make sense)
                            switch (flag_args) {
                                FlagArg.None => unreachable,
                                FlagArg.Single => |inner| try prev.append(inner),
                                FlagArg.Many => |inner| try prev.appendSlice(inner.toSliceConst()),
                            }

                            _ = try parsed.flags.put(flag_name_trimmed, FlagArg{ .Many = prev });
                        } else {
                            _ = try parsed.flags.put(flag_name_trimmed, flag_args);
                        }

                        continue :next;
                    }
                }

                // TODO: Better errors with context, global error state and return is sufficient.
                std.debug.warn("could not match flag: {}\n", arg);
                return error.UnknownFlag;
            } else {
                try parsed.positionals.append(arg);
            }
        }

        return parsed;
    }

    pub fn deinit(self: *Args) void {
        self.flags.deinit();
        self.positionals.deinit();
    }

    // e.g. --help
    pub fn present(self: *Args, name: []const u8) bool {
        return self.flags.contains(name);
    }

    // e.g. --name value
    pub fn single(self: *Args, name: []const u8) ?[]const u8 {
        if (self.flags.get(name)) |entry| {
            switch (entry.value) {
                FlagArg.Single => |inner| {
                    return inner;
                },
                else => @panic("attempted to retrieve flag with wrong type"),
            }
        } else {
            return null;
        }
    }

    // e.g. --names value1 value2 value3
    pub fn many(self: *Args, name: []const u8) []const []const u8 {
        if (self.flags.get(name)) |entry| {
            switch (entry.value) {
                FlagArg.Many => |inner| {
                    return inner.toSliceConst();
                },
                else => @panic("attempted to retrieve flag with wrong type"),
            }
        } else {
            return []const []const u8{};
        }
    }
};

// Arguments for a flag. e.g. arg1, arg2 in `--command arg1 arg2`.
const FlagArg = union(enum) {
    None,
    Single: []const u8,
    Many: ArrayList([]const u8),
};

// Specification for how a flag should be parsed.
pub const Flag = struct {
    name: []const u8,
    required: usize,
    mergable: bool,
    allowed_set: ?[]const []const u8,

    pub fn Bool(comptime name: []const u8) Flag {
        return ArgN(name, 0);
    }

    pub fn Arg1(comptime name: []const u8) Flag {
        return ArgN(name, 1);
    }

    pub fn ArgN(comptime name: []const u8, comptime n: usize) Flag {
        return Flag{
            .name = name,
            .required = n,
            .mergable = false,
            .allowed_set = null,
        };
    }

    pub fn ArgMergeN(comptime name: []const u8, comptime n: usize) Flag {
        if (n == 0) {
            @compileError("n must be greater than 0");
        }

        return Flag{
            .name = name,
            .required = n,
            .mergable = true,
            .allowed_set = null,
        };
    }

    pub fn Option(comptime name: []const u8, comptime set: []const []const u8) Flag {
        return Flag{
            .name = name,
            .required = 1,
            .mergable = false,
            .allowed_set = set,
        };
    }
};

test "parse arguments" {
    const spec1 = comptime []const Flag{
        Flag.Bool("--help"),
        Flag.Bool("--init"),
        Flag.Arg1("--build-file"),
        Flag.Option("--color", []const []const u8{
            "on",
            "off",
            "auto",
        }),
        Flag.ArgN("--pkg-begin", 2),
        Flag.ArgMergeN("--object", 1),
        Flag.ArgN("--library", 1),
    };

    const cliargs = []const []const u8{
        "build",
        "--help",
        "pos1",
        "--build-file",
        "build.zig",
        "--object",
        "obj1",
        "--object",
        "obj2",
        "--library",
        "lib1",
        "--library",
        "lib2",
        "--color",
        "on",
        "pos2",
    };

    var args = try Args.parse(std.debug.global_allocator, spec1, cliargs);

    debug.assert(args.present("help"));
    debug.assert(!args.present("help2"));
    debug.assert(!args.present("init"));

    debug.assert(mem.eql(u8, args.single("build-file").?, "build.zig"));
    debug.assert(mem.eql(u8, args.single("color").?, "on"));

    const objects = args.many("object").?;
    debug.assert(mem.eql(u8, objects[0], "obj1"));
    debug.assert(mem.eql(u8, objects[1], "obj2"));

    debug.assert(mem.eql(u8, args.single("library").?, "lib2"));

    const pos = args.positionals.toSliceConst();
    debug.assert(mem.eql(u8, pos[0], "build"));
    debug.assert(mem.eql(u8, pos[1], "pos1"));
    debug.assert(mem.eql(u8, pos[2], "pos2"));
}
