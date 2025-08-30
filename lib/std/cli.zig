const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;
const isAlphabetic = std.ascii.isAlphabetic;
const Writer = std.Io.Writer;
const ArgIterator = std.process.ArgIterator;
const ArenaAllocator = std.heap.ArenaAllocator;
const StructField = std.builtin.Type.StructField;
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Options = struct {
    /// Parsing/validation errors and the long `--help` documentation will be written to this writer.
    /// By default, parsing/validation errors are written to stderr, and the long `--help` documentation is written to stdout.
    /// Any error while writing is silently ignored.
    writer: ?*Writer = null,

    /// The program name used in the help output, e.g. "my-command" in "usage: my-command [options] ...".
    /// By default uses the last path component of the process's first argument (`argv[0]`).
    /// When there is no `argv[0]` (such as with `parseSlice`), the default is `"<prog>"`.
    prog: ?[]const u8 = null,

    /// Call `std.process.exit` with an error status instead of returning `error.Usage` or `error.Help`.
    /// The default is `true` for `parse` and `@"error"`, and `false` otherwise.
    exit: ?bool = null,
};

pub const Error = error{
    /// Caused by unrecognized option names, values that cannot be parsed into the appropriate field type,
    /// missing arguments for fields with no default value, and other similar parsing errors.
    /// See also `options.exit`, which can supersede this error.
    Usage,
    /// The --help argument was given (and `options.exit` resolved to `false`).
    Help,
} || Allocator.Error;

/// Parses CLI args from a `std.process.ArgIterator` according to the configuration in `Args`.
/// `Args` is a struct that you define looking like this:
/// ```
/// const Args = struct {
///     named: struct {
///         // ...
///     },
///     positional: struct {
///         // ...
///     },
/// };
/// ```
/// Either or both of `named` and `positional` may be omitted, which is effectively equivalent to them having no fields.
///
/// The sequence of arg strings from the `ArgIterator` is parsed to determine named and positional arguments.
///
/// Each arg string takes one of these forms:
/// ```
/// --<name>          (1)
/// --no-<name>       (2)
/// --<name>=<value>  (3)
/// --help            (4)
/// -<alpha><any>     (5) always an error
/// --                (6)
/// <other>           (7)
/// ```
/// Forms (1), (2), and (3) must correspond to a field `Args.named.<name>`; see below for named argument handling.
/// Form (4) immediately prints the long help documentation and exits or returns `error.Help` depending on options.exit.
/// Form (6) signals that all following arg strings are positional.
/// Form (7) and all arg strings following form (6) are considered positional arguments, discussed below.
///
/// Form (5) is always an error.
/// This API does not support single letter aliases like `-v` or `-lA` or named arguments prefixed by only a single hyphen like `-flag`.
/// Form (5) is defined by any arg string where the first byte is '-' and the second byte is `'A'...'Z', 'a'...'z'`
/// (and any following bytes are ignored).
/// A `-9` or other second byte outside the ascii-alpha range is Form (7).
///
/// For forms (1), (2), and (3), let `T` be the type of `Args.named.<name>`.
/// `T` may be any of the following: `bool`, any integer such as `i32`, any float such as `f64`, any `enum` with at least 1 member,
/// any string that `[:0]const u8` can coerce into such as `[]const u8`,
/// or a slice that `[]C` can coerce into such as `[]const C` where `C` is one of:
/// any integer, any float, or any string that `[:0]const u8` can coerce into.
/// Note that slice of bool and slice of enum are not allowed; see https://github.com/ziglang/zig/issues/24601 for discussion.
///
/// If `T` is `bool`, then form (1) sets it to `true`, form (2) sets it to `false`, and form (3) is not allowed.
/// Otherwise, form (3) specifies the `<value>`, form (1) must be immediately followed by another string arg which is the `<value>`,
/// and form (2) is not allowed.
/// For non-bool `T` or for `C` in slice types, the `<value>` is parsed from its string representation:
/// for integers using `std.fmt.parseInt` with base `0`; for floats using `std.fmt.parseFloat`;
/// for enums using `std.meta.stringToEnum`; and for strings no modification or copying is done.
///
/// Each `Args.named.<name>` may have a default value, which makes the `--<name>` argument optional.
/// Slice arguments `[]const C` (where `C` is not `u8`) must have a default value, usually `&.{}`.
/// If a bool argument has no default value, then at least one of `--<name>` or `--no-<name>` must be given.
///
/// Each positional arg string corresponds to a field in `Args.positional` in declaration order.
/// Each field in `Args.positional` may have a default value, making the corresponding argument optional.
/// Fields for required positional arguments must precede fields for optional arguments.
/// For each field, let `T` be its type.
/// Similar to `Args.named` described above, `T` may be any of the following:
/// any integer, any float, any `enum` with at least 1 member, or any string that `[:0]const u8` can coerce into.
/// Only the last declared field of `Args.positional` may alternatively have type `[]const C` where `C` is one of:
/// any integer, any float, any `enum` with at least 1 member, or any string that `[:0]const u8` can coerce into.
/// Similar to `Args.named`, a positional field declared with such a `[]const C` must have a default value, usually `&.{}`.
/// Such a `[]const C` field corresponds to all positional arguments after the positional arguments for the other fields.
///
/// It's possible to override the automatically-generated long help documentation by declaring a public constant named `help` in `Args`.
/// The value must coerce to `[]const u8`.
///
/// ```
/// const Args = struct {
///     pub const help =
///         \\usage: your-command --your-usage goes-here
///         \\
///         \\arguments:
///         \\  [...]
///         \\  --help
///         \\
///     ;
///     named: struct {
///         // [...]
///     },
/// };
/// ```
///
/// The first arg returned by the `ArgIterator` (`argv[0]`) is skipped by all the above parsing logic.
/// If `options.prog` is `null`, then the final path component of `argv[0]` is used by default.
///
/// If a parsing/validation error occurs or the `--help` arg is given,
/// this function calls `std.process.exit` with `1` and `0` respectively unless `options.exit` is set to `false`,
/// in which case parsing/validation errors return `error.Usage` and `--help` returns `error.Help`.
/// Allocator errors are always returned from the function.
///
/// It is not possible to precisely deallocate the memory allocated by this function.
/// An `ArenaAllocator` is recommended to prevent memory leaks.
pub fn parse(comptime Args: type, arena: Allocator, options: Options) (Error || ArgIterator.InitError)!Args {
    var iter: ArgIterator = try .initWithAllocator(arena);
    // Do not call iter.deinit(). It holds the string data returned in the Args.

    const argv0 = iter.next();
    const prog = options.prog orelse if (argv0) |arg| std.fs.path.basename(arg) else "<prog>";
    return innerParse(Args, arena, &iter, prog, options.writer, options.exit orelse true);
}

test parse {
    const Args = struct {
        named: struct {
            /// Specified as `--output path.txt` or `--output=path.txt`
            output: [:0]const u8 = "",
            /// Supports `--level=9`, `--level -12`, `--level=0x7f`, etc.
            level: i8 = -1,
            /// Parsed as the name of the member `--color=never`.
            color: enum { auto, never, always } = .auto,

            // The below parameters are actually passed into the `zig test` process,
            // so we have to receive them here (as of zig 0.15.1).
            seed: u32 = 0,
            @"cache-dir": []const u8 = "",
            listen: []const u8 = "",
        },
        positional: struct {
            /// First positional (non-named) argument:
            input: [:0]const u8 = "",
            /// Second positional argument is declared as optional:
            repititions: u32 = 1,
            /// Receives the rest of the positional arguments.
            @"the-rest": []const [:0]const u8 = &.{},
        },
    };

    var arena: ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const args = try std.cli.parse(Args, arena.allocator(), .{});

    try testing.expectEqual(@as(i8, -1), args.named.level);
}

/// Like `parse`, but allows specifying a custom arg iterator.
/// `iter` is typically a mutable pointer to a struct and must have a method:
/// ```
/// pub fn next(self: *Self) ?String { ... }
/// ```
/// Where `String` is `[]const u8` or `[:0]const u8` or something else that coerces to `[]const u8`.
/// If `String` does not coerce to `[:0]const u8`, then `Args` cannot have any `[:0]const u8` in its fields.
///
/// The first string arg returned by the `iter` (`argv[0]`) is skipped by all the parsing logic.
/// If `options.prog` is `null`, then the final path component of `argv[0]` is used by default.
///
/// If a parsing/validation error occurs or the `--help` arg is given,
/// this function returns `error.Usage` or `error.Help` respectively,
/// unless `options.exit` is set to `true`, in which case `std.process.exit` is called with `1` or `0` respectively.
/// Allocator errors are always returned from the function.
///
/// An `ArenaAllocator` is recommended to cleanup the memory allocated from this function;
/// however, it's also possible to free all the memory by freeing every slice field `[]const C` (other than `u8`)
/// in the returned `args.named` and `args.positional`.
pub fn parseIter(comptime Args: type, arena: Allocator, iter: anytype, options: Options) Error!Args {
    const argv0 = iter.next();
    const prog = options.prog orelse if (argv0) |arg| std.fs.path.basename(arg) else "<prog>";
    return innerParse(Args, arena, iter, prog, options.writer, options.exit orelse false);
}

/// Like `parse`, but takes a slice of strings in place of using an `ArgIterator`.
/// `argv` must be either be a slice of `String` or a single-item pointer to an array of `String`,
/// where `String` is `[]const u8` or `[:0]const u8` or something else that coerces to `[]const u8`.
/// If `String` does not coerce to `[:0]const u8`, then `Args` cannot have `[:0]const u8` fields.
///
/// Unlike `parse` and `parseIter`, this function does not skip the first item of `argv`.
/// Use `options.prog` instead.
///
/// If a parsing/validation error occurs or the `--help` arg is given,
/// this function returns `error.Usage` or `error.Help` respectively,
/// unless `options.exit` is set to `true`, in which case `std.process.exit` is called with `1` or `0` respectively.
/// Allocator errors are always returned from the function.
///
/// An `ArenaAllocator` is recommended to cleanup the memory allocated from this function;
/// however, it's also possible to free all the memory by freeing every slice field `[]const C` (other than `u8`)
/// in the returned `args.named` and `args.positional`.
pub fn parseSlice(comptime Args: type, arena: Allocator, argv: anytype, options: Options) Error!Args {
    const argvInfo = @typeInfo(@TypeOf(argv)).pointer;
    const String = if (argvInfo.size == .one)
        @typeInfo(argvInfo.child).array.child
    else if (argvInfo.size == .slice)
        argvInfo.child
    else
        @compileError("expected argv to be `*const [_]String` or `[]const String` where `String` is `[]const u8` or similar");
    var iter = ArgIteratorSlice(String){ .slice = argv };
    return innerParse(Args, arena, &iter, options.prog orelse "<prog>", options.writer, options.exit orelse false);
}

test parseSlice {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Args = struct {
        named: struct {
            example_required: []const u8,
            example_optional: []const u8 = "-",
            level: i32 = -1,
            flag: bool = true,
            @"enum-option": enum { auto, always, never } = .auto,
        },
        positional: struct {
            args: []const []const u8 = &.{},
        },
    };
    const args = try parseSlice(Args, allocator, &[_][]const u8{
        "--example_required", "a.txt",
        // --example_optional not given
        "--level=0xff",       "--no-flag",
        "--enum-option",      "always",
        "positional1",        "positional2",
        "-12345678",          "--",
        "--positional4",      "--positional=5",
    }, .{});

    try testing.expectEqualDeep(Args{
        .named = .{
            .example_required = "a.txt",
            .example_optional = "-",
            .level = 255,
            .flag = false,
            .@"enum-option" = .always,
        },
        .positional = .{ .args = &.{ "positional1", "positional2", "-12345678", "--positional4", "--positional=5" } },
    }, args);
}

fn innerParse(comptime Args: type, allocator: Allocator, iter: anytype, prog: []const u8, writer: ?*Writer, exit_on_error: bool) Error!Args {
    // argv0 has already been consumed.

    // Do all comptime checks up front so that we can be sure any compile error the user sees is the one we wrote.
    const named_fields, const positional_fields = comptime checkArgsType(Args);

    var named_array_lists = arrayListsForFields(named_fields);
    var positional_array_lists = arrayListsForFields(positional_fields);

    var result: Args = undefined;
    var named_fields_seen = [_]bool{false} ** named_fields.len;
    var positional_field_index: usize = 0;

    var the_rest_is_positional = false;

    while (iter.next()) |arg| {
        if (!the_rest_is_positional and mem.eql(u8, arg, "--help")) {
            if (@hasDecl(Args, "help")) {
                // Custom help.
                if (writer) |w| {
                    w.writeAll(Args.help) catch {};
                    w.flush() catch {};
                } else {
                    var file_writer = std.fs.File.stdout().writer(&.{});
                    file_writer.interface.writeAll(Args.help) catch {};
                    file_writer.interface.flush() catch {};
                }
            } else {
                printGeneratedHelp(named_fields, positional_fields, writer, prog);
            }
            if (exit_on_error) {
                std.process.exit(0);
            }
            return error.Help;
        }

        if (!the_rest_is_positional and arg.len >= 2 and arg[0] == '-' and isAlphabetic(arg[1])) {
            // Always invalid.
            // Examples: -h, -flag, -I/path
            return usageError(named_fields, positional_fields, writer, "unrecognized argument: {s}", .{arg}, prog, exit_on_error);
        }
        if (!the_rest_is_positional and mem.eql(u8, arg, "--")) {
            // Stop recognizing named arguments. Everything else is positional.
            the_rest_is_positional = true;
            continue;
        }
        if (the_rest_is_positional or !(arg.len >= 3 and arg[0] == '-' and arg[1] == '-')) {
            // Positional.
            // Examples: "", "a", "-", "-1", "other"
            if (positional_field_index >= positional_fields.len) return usageError(named_fields, positional_fields, writer, "unexpected positional argument: {s}", .{arg}, prog, exit_on_error);
            inline for (positional_fields, 0..) |field, i| {
                if (positional_field_index == i) {
                    if (getArrayChild(field.type)) |C| {
                        try @field(positional_array_lists, field.name).append(allocator, try parseValue(named_fields, positional_fields, C, arg, field.name, writer, prog, exit_on_error));
                        // Don't increment positional_field_index.
                    } else {
                        @field(result.positional, field.name) = try parseValue(named_fields, positional_fields, field.type, arg, field.name, writer, prog, exit_on_error);
                        positional_field_index += 1;
                    }
                    break;
                }
            } else unreachable;
            continue;
        }

        // Named.
        const arg_name, const immediate_value, const no_prefixed = blk: {
            if (mem.startsWith(u8, arg, "--no-")) {
                break :blk .{ arg["--no-".len..], null, true };
            }
            if (mem.indexOfScalarPos(u8, arg, "--".len, '=')) |index| {
                if (@typeInfo(@TypeOf(arg)).pointer.sentinel_ptr != null) {
                    break :blk .{ arg["--".len..index], arg[index + 1 .. :0], false };
                } else {
                    break :blk .{ arg["--".len..index], arg[index + 1 ..], false };
                }
            }
            break :blk .{ arg["--".len..], null, false };
        };

        inline for (named_fields, 0..) |field, i| {
            if (mem.eql(u8, field.name, arg_name)) {
                named_fields_seen[i] = true;
                if (field.type == bool) {
                    if (immediate_value != null) return usageError(named_fields, positional_fields, writer, "cannot specify value for bool argument: {s}", .{arg}, prog, exit_on_error);
                    @field(result.named, field.name) = !no_prefixed;
                    break;
                }
                if (no_prefixed) return usageError(named_fields, positional_fields, writer, "unrecognized argument: {s}", .{arg}, prog, exit_on_error);

                // All other argument types require a value.
                const arg_value = immediate_value orelse iter.next() orelse return usageError(named_fields, positional_fields, writer, "expected argument after --{s}", .{field.name}, prog, exit_on_error);

                if (getArrayChild(field.type)) |C| {
                    try @field(named_array_lists, field.name).append(allocator, try parseValue(named_fields, positional_fields, C, arg_value, field.name, writer, prog, exit_on_error));
                } else {
                    @field(result.named, field.name) = try parseValue(named_fields, positional_fields, field.type, arg_value, field.name, writer, prog, exit_on_error);
                }
                break;
            }
        } else {
            // Didn't match anything.
            return usageError(named_fields, positional_fields, writer, "unrecognized argument: {s}", .{arg}, prog, exit_on_error);
        }
    }

    // Fill default values.
    inline for (named_fields, 0..) |field, i| {
        if (getArrayChild(field.type)) |_| {
            // Array.
            @field(result.named, field.name) = try @field(named_array_lists, field.name).toOwnedSlice(allocator);
        } else {
            // Scalar.
            if (!named_fields_seen[i]) {
                // Unspecified.
                if (field.defaultValue()) |default| {
                    @field(result.named, field.name) = default;
                } else {
                    if (field.type == bool) {
                        return usageError(named_fields, positional_fields, writer, "missing required argument: --" ++ field.name ++ " or --no-" ++ field.name, .{}, prog, exit_on_error);
                    } else {
                        return usageError(named_fields, positional_fields, writer, "missing required argument: --" ++ field.name, .{}, prog, exit_on_error);
                    }
                }
            }
        }
    }
    inline for (positional_fields, 0..) |field, i| {
        if (getArrayChild(field.type)) |_| {
            // Array.
            @field(result.positional, field.name) = try @field(positional_array_lists, field.name).toOwnedSlice(allocator);
        } else {
            // Scalar.
            if (positional_field_index <= i) {
                // Unspecified.
                if (field.defaultValue()) |default| {
                    @field(result.positional, field.name) = default;
                } else {
                    return usageError(named_fields, positional_fields, writer, "missing required argument: " ++ field.name, .{}, prog, exit_on_error);
                }
            }
        }
    }

    return result;
}

/// arg_value is []const u8 or [:0]const u8.
fn parseValue(comptime named_fields: []const StructField, comptime positional_fields: []const StructField, comptime T: type, arg_value: anytype, comptime field_name: []const u8, writer: ?*Writer, prog: []const u8, exit_on_error: bool) !T {
    switch (@typeInfo(T)) {
        .bool => comptime unreachable, // Handled elsewhere.
        .float => {
            return std.fmt.parseFloat(T, arg_value) catch |err| {
                return usageError(named_fields, positional_fields, writer, "unable to parse --{s}={s}: {s}", .{ field_name, arg_value, @errorName(err) }, prog, exit_on_error);
            };
        },
        .int => {
            return std.fmt.parseInt(T, arg_value, 0) catch |err| {
                return usageError(named_fields, positional_fields, writer, "unable to parse --{s}={s}: {s}", .{ field_name, arg_value, @errorName(err) }, prog, exit_on_error);
            };
        },
        .@"enum" => {
            return std.meta.stringToEnum(T, arg_value) orelse {
                return usageError(named_fields, positional_fields, writer, "unrecognized value: --{s}={s}, expected one of: {s}", .{ field_name, arg_value, enumValuesExpr(T) }, prog, exit_on_error);
            };
        },
        .pointer => |ptrInfo| {
            comptime assert(ptrInfo.size == .slice);
            comptime assert(ptrInfo.child == u8);
            return arg_value; // To resolve compile errors between `[:0]const u8` and `[]const u8` on this line, ensure the passed-in args are `[:0]const u8`.
        },
        else => comptime unreachable,
    }
}

fn checkArgsType(comptime Args: type) struct { []const StructField, []const StructField } {
    var has_named = false;
    var has_positional = false;
    inline for (@typeInfo(Args).@"struct".fields) |field| {
        if (mem.eql(u8, field.name, "named")) {
            has_named = true;
        } else if (mem.eql(u8, field.name, "positional")) {
            has_positional = true;
        } else @compileError("unrecognized Args name: " ++ field.name);
    }

    const named_fields = if (has_named) @typeInfo(@TypeOf(@as(Args, undefined).named)).@"struct".fields else &.{};
    const positional_fields = if (has_positional) @typeInfo(@TypeOf(@as(Args, undefined).positional)).@"struct".fields else &.{};

    // Named arguments are more lenient.
    inline for (named_fields) |field| {
        validateField(field);
    }

    // Positional arguments have stricter rules.
    var everything_still_required = true;
    var everything_still_scalar = true;
    inline for (positional_fields) |field| {
        if (field.type == bool) @compileError("Args.positional cannot have bool fields: " ++ field.name);
        validateField(field);
        const is_scalar = getArrayChild(field.type) == null;

        const is_required = field.default_value_ptr == null;

        // There can only be one array parameter, and it must be last.
        if (everything_still_scalar) {
            if (!is_scalar) {
                everything_still_scalar = false;
            }
        } else @compileError("a positional array argument must be last. found: " ++ field.name);

        // Required positional parameters must come first.
        if (everything_still_required) {
            if (!is_required) {
                everything_still_required = false;
            }
        } else {
            if (is_required) @compileError("cannot have a required positional argument after an optional one: " ++ field.name);
        }
    }

    return .{ named_fields, positional_fields };
}

fn validateField(field: StructField) void {
    if (field.is_comptime) @compileError("comptime fields are not supported: " ++ field.name);
    if (comptime mem.eql(u8, field.name, "help")) @compileError("A field named help is not allowed. add a `pub const help = \"...\";` to your `Args` to provide a custom help string.");
    if (comptime mem.startsWith(u8, field.name, "no-")) @compileError("Field name starts with @\"no-\": " ++ field.name ++ ". Note: use a bool type field, and --<name> and --no-<name> will turn it on and off.");
    if (comptime mem.indexOfScalar(u8, field.name, '=') != null) @compileError("Field name contains @\"=\": " ++ field.name);

    switch (@typeInfo(field.type)) {
        .bool => {},
        .float => {},
        .int => {},
        .@"enum" => {
            if (@typeInfo(field.type).@"enum".fields.len == 0) @compileError("Empty enums not allowed");
        },
        .pointer => |ptrInfo| {
            if (ptrInfo.size != .slice) @compileError("Unsupported field type: " ++ @typeName(field.type));
            if (ptrInfo.child == u8) {
                // String.
            } else {
                // Array.
                if (field.default_value_ptr == null) @compileError("Array arguments must have a default value: " ++ field.name);
                switch (@typeInfo(ptrInfo.child)) {
                    .bool => @compileError("Unsupported field type: " ++ @typeName(field.type)),
                    .float => {},
                    .int => {},
                    .@"enum" => @compileError("Unsupported field type: " ++ @typeName(field.type)),
                    .pointer => |ptrInfo2| {
                        if (ptrInfo2.size != .slice) @compileError("Unsupported field type: " ++ @typeName(field.type));
                        if (ptrInfo2.child == u8) {
                            // String.
                        } else {
                            @compileError("Unsupported field type: " ++ @typeName(field.type));
                        }
                    },
                    else => @compileError("Unsupported field type: " ++ @typeName(field.type)),
                }
            }
        },
        else => @compileError("Unsupported field type: " ++ @typeName(field.type)),
    }
}

/// returns null if T is a scalar type.
fn getArrayChild(comptime T: type) ?type {
    // This logic assumes the type has already passed validation.
    return switch (@typeInfo(T)) {
        .pointer => |ptrInfo| if (ptrInfo.child == u8) null else ptrInfo.child,
        else => null,
    };
}

fn arrayListsForFields(comptime fields: []const StructField) ArrayListsForFields(fields) {
    var array_lists: ArrayListsForFields(fields) = undefined;
    inline for (@typeInfo(@TypeOf(array_lists)).@"struct".fields) |field| {
        @field(array_lists, field.name) = .{};
    }
    return array_lists;
}
fn ArrayListsForFields(comptime fields: []const StructField) type {
    // Declare and initialize an ArrayList(C) for every []const C field (other than u8).
    comptime var array_list_fields: []const StructField = &.{};
    inline for (fields) |field| {
        const info = @typeInfo(field.type);
        if (info == .pointer) {
            comptime assert(info.pointer.size == .slice);
            if (info.pointer.child == u8) {
                // String. skip.
            } else {
                // Array of scalar.
                array_list_fields = array_list_fields ++ @as([]const StructField, &.{.{
                    .name = field.name,
                    .type = ArrayList(info.pointer.child),
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(ArrayList(info.pointer.child)),
                }});
            }
        }
    }
    return @Type(.{ .@"struct" = .{ .layout = .auto, .fields = array_list_fields, .decls = &.{}, .is_tuple = false } });
}

/// If you do your own validation after getting an `args` from `parse` or similar,
/// call this function to produce the same error behavior as if this API's validation failed.
/// An error message will be written to `options.writer` or stderr by default, and `error.Usage` is returned.
/// The given `msg` template is prefixed by `"error: "` and suffixed by a newline and a prompt to try passing in `--help`.
/// `options.prog` is not used by this function, but could be in the future. TODO: yes it is.
///
/// This function calls `std.process.exit` with an error status unless `options.exit` is set to `false`, in which case it returns `error.Usage`.
/// This matches the default behavior of `parse`, not `parseIter` or `parseSlice`.
pub fn @"error"(comptime Args: type, comptime msg: []const u8, msg_args: anytype, options: Options) error{Usage} {
    const named_fields, const positional_fields = comptime checkArgsType(Args);
    var buf: [0x1000]u8 = undefined;
    const prog: ?[]const u8 = options.prog orelse blk: {
        var fba: std.heap.FixedBufferAllocator = .init(&buf);
        var iter = ArgIterator.initWithAllocator(fba.allocator()) catch break :blk null;
        const argv0 = iter.next();
        break :blk if (argv0) |arg| std.fs.path.basename(arg) else null;
    };
    return usageError(named_fields, positional_fields, options.writer, msg, msg_args, prog orelse "<prog>", options.exit orelse true);
}

test @"error" {
    const Args = struct {
        named: struct {
            output: []const u8 = "",
        },
        positional: struct {
            input: []const u8,
        },
    };

    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const args = try parseSlice(Args, arena.allocator(), &[_][]const u8{ "--output=o.txt", "i.txt" }, .{});

    if (std.fs.path.isAbsolute(args.named.output)) {
        return std.cli.@"error"(Args, "--output must not be absolute: {s}", .{args.named.output}, .{ .exit = false });
    }
}

fn ArgIteratorSlice(comptime String: type) type {
    return struct {
        slice: []const String,
        index: usize = 0,

        pub fn next(self: *@This()) ?String {
            if (self.index >= self.slice.len) return null;
            const result = self.slice[self.index];
            self.index += 1;
            return result;
        }
    };
}

fn enumValuesExpr(comptime Enum: type) []const u8 {
    comptime var values_str: []const u8 = "{";
    inline for (@typeInfo(Enum).@"enum".fields) |enum_field| {
        if (values_str.len > 1) {
            values_str = values_str ++ ",";
        }
        values_str = values_str ++ enum_field.name;
    }
    values_str = values_str ++ "}";
    return values_str;
}

fn usageError(comptime named_fields: []const StructField, comptime positional_fields: []const StructField, writer: ?*Writer, comptime msg: []const u8, args: anytype, prog: []const u8, exit_on_error: bool) error{Usage} {
    const whole_msg =
        "error: " ++ msg ++ "\n" ++ //
        "usage: {s} " ++ comptime usageLineFmt(named_fields, positional_fields) ++ "\n" ++
            \\try --help for full help info
            \\
        ;
    if (writer) |w| {
        w.print(whole_msg, args ++ .{prog}) catch {};
    } else {
        std.debug.print(whole_msg, args ++ .{prog});
    }
    if (exit_on_error) {
        std.process.exit(1);
    }
    return error.Usage;
}

/// returns a string with all "{" escaped for passing into std.fmt.
fn usageLineFmt(comptime named_fields: []const StructField, comptime positional_fields: []const StructField) []const u8 {
    comptime var usage_parts: []const []const u8 = &.{};
    var at_least_one_optional_named_argument = false;
    inline for (named_fields) |field| {
        if (field.default_value_ptr != null) {
            // Don't mention optional named arguments.
            at_least_one_optional_named_argument = true;
            continue;
        }
        usage_parts = usage_parts ++ .{switch (@typeInfo(field.type)) {
            .bool => "--[no-]" ++ field.name,
            .int, .float => "--" ++ field.name ++ "=" ++ @typeName(field.type),
            .@"enum" => "--" ++ field.name ++ "=" ++ enumValuesExpr(field.type),
            else => blk: {
                comptime assert(@typeInfo(field.type).pointer.size == .slice and @typeInfo(field.type).pointer.child == u8);
                break :blk "--" ++ field.name ++ "=string";
            },
        }};
    }

    if (at_least_one_optional_named_argument) {
        // Prepend with an [options] placeholder.
        usage_parts = [_][]const u8{"[options]"} ++ usage_parts;
    }

    inline for (positional_fields) |field| {
        if (field.default_value_ptr != null) {
            if (getArrayChild(field.type) != null) {
                // Array
                usage_parts = usage_parts ++ .{"[" ++ field.name ++ "...]"};
            } else {
                // Scalar
                usage_parts = usage_parts ++ .{"[" ++ field.name ++ "]"};
            }
        } else {
            usage_parts = usage_parts ++ .{field.name};
        }
    }

    comptime var usage_str: []const u8 = "";
    inline for (usage_parts) |part| {
        if (usage_str.len > 0) {
            usage_str = usage_str ++ " ";
        }
        usage_str = usage_str ++ part;
    }
    return escapeFmt(usage_str);
}
fn printGeneratedHelp(comptime named_fields: []const StructField, comptime positional_fields: []const StructField, writer: ?*Writer, prog: []const u8) void {
    comptime var arguments_table: []const []const []const u8 = &.{};

    comptime var arguments_str: []const u8 = ""; // TODO: delete

    if (positional_fields.len > 0) {
        arguments_table = arguments_table ++ .{&[_][]const u8{"positional arguments:"}};
    }
    //inline for (positional_fields) |field| {}

    arguments_table = arguments_table ++ .{&[_][]const u8{"named arguments:"}}; // The --help option is always there.
    inline for (named_fields) |field| {
        switch (@typeInfo(field.type)) {
            .bool => {
                if (field.defaultValue()) |default| {
                    if (default) {
                        arguments_table = arguments_table ++ .{&[_][]const u8{ "  --no-" ++ field.name, "default: --" ++ field.name }};
                    } else {
                        arguments_table = arguments_table ++ .{&[_][]const u8{ "  --" ++ field.name, "default: --no-" ++ field.name }};
                    }
                } else {
                    arguments_table = arguments_table ++ .{&[_][]const u8{ "  --[no-]" ++ field.name, "required" }};
                }
            },
            .int, .float => {
                arguments_table = arguments_table ++ .{&[_][]const u8{
                    "  --" ++ field.name ++ "=" ++ @typeName(field.type),
                    if (field.defaultValue()) |default|
                        "default: " ++ std.fmt.comptimePrint("{}", .{default})
                    else
                        "required",
                }};
            },
            .@"enum" => {
                arguments_table = arguments_table ++ .{&[_][]const u8{
                    "  --" ++ field.name ++ "=" ++ comptime enumValuesExpr(field.type),
                    if (field.defaultValue()) |default|
                        "default: " ++ @tagName(default)
                    else
                        "required",
                }};
            },
            .pointer => |ptrInfo| {
                if (ptrInfo.size == .slice and ptrInfo.child == u8) {
                    // String
                    arguments_table = arguments_table ++ .{&[_][]const u8{
                        "  --" ++ field.name ++ "=string",
                        if (field.defaultValue()) |default|
                            "default: " ++ quoteIfEmpty(default)
                        else
                            "required",
                    }};
                } else {
                    // Array
                    const type_name = switch (@typeInfo(ptrInfo.child)) {
                        .bool => comptime unreachable,
                        .int, .float => @typeName(ptrInfo.child),
                        .@"enum" => comptime unreachable,
                        .pointer => "string", // The array-of-pointer that doesn't cause compile errors elsewhere.
                        else => comptime unreachable,
                    };
                    arguments_str = arguments_str ++ "\n  " ++ //
                        "--" ++ field.name ++ " " ++ type_name ++ " " ++ //
                        "[--" ++ field.name ++ " " ++ type_name ++ " ...]";
                    arguments_table = arguments_table ++ .{&[_][]const u8{
                        "  --" ++ field.name ++ "=" ++ type_name ++ " " ++ //
                            "[--" ++ field.name ++ "=" ++ type_name ++ " ...]",
                    }};
                }
            },
            else => comptime unreachable,
        }
    }

    arguments_table = arguments_table ++ .{&[_][]const u8{ "  --help", "print this help and exit" }};

    comptime var width = 0;
    inline for (arguments_table) |row| {
        width = @max(width, row[0].len);
    }

    comptime var help_str: []const u8 = "";
    inline for (arguments_table) |row| {
        help_str = help_str ++ "\n";
        inline for (row, 0..) |cell, c| {
            help_str = help_str ++ cell;
            if (c == 0 and row.len > 1) {
                help_str = help_str ++ " " ** (width + 2 - cell.len);
            }
        }
    }

    const msg = "usage: {s} " ++ comptime usageLineFmt(named_fields, positional_fields) ++ //
        escapeFmt(help_str) ++ "\n";
    if (writer) |w| {
        w.print(msg, .{prog}) catch {};
        w.flush() catch {};
    } else {
        var buffer: [0x100]u8 = undefined;
        var file_writer = std.fs.File.stdout().writer(&buffer);
        file_writer.interface.print(msg, .{prog}) catch {};
        file_writer.interface.flush() catch {};
    }
}

inline fn quoteIfEmpty(comptime s: []const u8) []const u8 {
    if (s.len == 0) return "''";
    return s;
}

inline fn escapeFmt(comptime s: []const u8) []const u8 {
    var result: []const u8 = "";
    comptime var cursor = 0;
    for (s, 0..) |c, i| {
        switch (c) {
            '{' => {
                result = result ++ s[cursor..i] ++ "{{";
                cursor = i + 1;
            },
            '}' => {
                result = result ++ s[cursor..i] ++ "}}";
                cursor = i + 1;
            },
            else => {},
        }
    }
    result = result ++ s[cursor..];
    return result;
}

var failing_writer: Writer = .failing;
const silent_options = Options{ .writer = &failing_writer, .exit = false };

test "bool" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Args = struct {
        named: struct {
            b: bool,
        },
    };

    try testing.expectEqualDeep(Args{ .named = .{ .b = true } }, try parseSlice(Args, allocator, &[_][]const u8{"--b"}, .{}));
    try testing.expectEqualDeep(Args{ .named = .{ .b = false } }, try parseSlice(Args, allocator, &[_][]const u8{"--no-b"}, .{}));
    try testing.expectEqualDeep(Args{ .named = .{ .b = true } }, try parseSlice(Args, allocator, &[_][]const u8{ "--no-b", "--b" }, .{}));
    try testing.expectEqualDeep(Args{ .named = .{ .b = false } }, try parseSlice(Args, allocator, &[_][]const u8{ "--b", "--no-b" }, .{}));

    try testing.expectError(error.Usage, parseSlice(Args, allocator, &[_][]const u8{"--b=true"}, silent_options));
    try testing.expectError(error.Usage, parseSlice(Args, allocator, &[_][]const u8{"--b=false"}, silent_options));
}

test "string" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Args = struct {
        named: struct {
            a: []const u8,
            b: [:0]const u8,
        },
    };
    const args = try parseSlice(Args, allocator, &[_][:0]const u8{
        "--a", "a",
        "--b", "b",
    }, .{});

    try testing.expectEqualDeep(Args{
        .named = .{
            .a = "a",
            .b = "b",
        },
    }, args);
}

test "ints and floats" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Args = struct {
        named: struct {
            int_u32: u32,
            int_i32: i32,
            int_u8: u8,
            int_u256: u256,
            float_f32: f32,
            float_f64: f64,
            inf_f32: f32,
            ninf_f64: f64,
        },
    };
    const args = try parseSlice(Args, allocator, &[_][]const u8{
        "--int_u32",   "0xffffffff",
        "--int_i32",   "-0x80000000",
        "--int_u8",    "0o310",
        "--int_u256",  "115792089237316195423570985008687907853269984665640564039457584007913129639935",
        "--float_f32", "1.25",
        "--float_f64", "-0xab.cdef012345p-12",
        "--inf_f32",   "inf",
        "--ninf_f64",  "-INF",
    }, .{});

    try testing.expectEqualDeep(Args{
        .named = .{
            .int_u32 = 0xffffffff,
            .int_i32 = -0x80000000,
            .int_u8 = 0o310,
            .int_u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935,
            .float_f32 = 1.25,
            .float_f64 = -0xab.cdef012345p-12,
            .inf_f32 = std.math.inf(f32),
            .ninf_f64 = -std.math.inf(f64),
        },
    }, args);

    const Args2 = struct {
        named: struct {
            nan: f64,
        },
    };
    const args2 = try parseSlice(Args2, allocator, &[_][]const u8{
        "--nan", "nAN",
    }, .{});

    try testing.expect(std.math.isNan(args2.named.nan));
}

test "array" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Args = struct {
        named: struct {
            path: []const []const u8 = &.{},
            id: []const i32 = &.{},
        },
        positional: struct {
            args: []const []const u8 = &.{},
        },
    };

    try testing.expectEqualDeep(Args{
        .named = .{
            .path = &[_][]const u8{ "a", "b", "a" },
            .id = &[_]i32{ 1, -12 },
        },
        .positional = .{
            .args = &[_][]const u8{ "x", "y" },
        },
    }, try parseSlice(Args, allocator, &[_][]const u8{
        "--path", "a",
        "--path", "b",
        "--path", "a",
        "--id",   "1",
        "--id",   "-12",
        "x",      "y",
    }, .{}));
}

test "enum" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Args = struct {
        named: struct {
            color: enum {
                always,
                never,
                auto,
            },
            guess: enum {
                @"the-only-option",
            },
            signal: enum(u8) {
                KILL = 9,
                TERM = 15,
                VTALRM = 26,
            },
        },
    };
    const args = try parseSlice(Args, allocator, &[_][]const u8{
        "--color",  "always",
        "--guess",  "the-only-option",
        "--signal", "TERM",
    }, .{});

    try testing.expectEqualDeep(Args{
        .named = .{
            .color = .always,
            .guess = .@"the-only-option",
            .signal = .TERM,
        },
    }, args);
}

test "defaults" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Args = struct {
        named: struct {
            level: i8 = -1,
            ratio: f32 = 0.5,
            path: []const u8 = "-",
            color: enum {
                always,
                never,
                auto,
            } = .auto,
            file: []const []const u8 = &.{},
            force: bool = false,
            cleanup: bool = true,
        },
    };

    try testing.expectEqualDeep(Args{
        .named = .{},
    }, try parseSlice(Args, allocator, &[_][]const u8{}, .{}));
    try testing.expectEqualDeep(Args{
        .named = .{
            .color = .always,
        },
    }, try parseSlice(Args, allocator, &[_][]const u8{ "--color", "always" }, .{}));
    try testing.expectEqualDeep(Args{
        .named = .{
            .file = &[_][]const u8{"file.txt"},
        },
    }, try parseSlice(Args, allocator, &[_][]const u8{ "--file", "file.txt" }, .{}));

    try testing.expectEqualDeep(Args{
        .named = .{
            .force = true,
            .cleanup = false,
        },
    }, try parseSlice(Args, allocator, &[_][]const u8{ "--force", "--no-cleanup" }, .{}));
}

test "positional" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // defaults
    {
        const Args = struct {
            positional: struct {
                level: i8 = -1,
                ratio: f32 = 0.5,
                path: []const u8 = "-",
                color: enum {
                    always,
                    never,
                    auto,
                } = .auto,
                file: []const []const u8 = &.{},
            },
        };

        try testing.expectEqualDeep(Args{
            .positional = .{},
        }, try parseSlice(Args, allocator, &[_][]const u8{}, .{}));
        try testing.expectEqualDeep(Args{
            .positional = .{
                .level = 1,
                .ratio = 2,
                .path = "a.txt",
                .color = .always,
                .file = &[_][]const u8{ "file1", "file2" },
            },
        }, try parseSlice(Args, allocator, &[_][]const u8{ "1", "2", "a.txt", "always", "file1", "file2" }, .{}));
    }

    // required
    {
        const Args = struct {
            positional: struct {
                level: i8,
                ratio: f32,
                path: []const u8,
                color: enum {
                    always,
                    never,
                    auto,
                },
                file: []const []const u8 = &.{},
            },
        };

        try testing.expectError(error.Usage, parseSlice(Args, allocator, &[_][]const u8{}, silent_options));
        try testing.expectError(error.Usage, parseSlice(Args, allocator, &[_][]const u8{ "1", "2", "a.txt" }, silent_options));
        try testing.expectEqualDeep(Args{
            .positional = .{
                .level = 1,
                .ratio = 2,
                .path = "a.txt",
                .color = .always,
            },
        }, try parseSlice(Args, allocator, &[_][]const u8{ "1", "2", "a.txt", "always" }, .{}));
    }
}

test "usage errors" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var aw: Writer.Allocating = .init(allocator);
    const options = Options{ .prog = "test-prog", .writer = &aw.writer };

    // unrecognized argument
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: []const u8 = "",
        },
    }, allocator, &[_][]const u8{"--bogus"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--bogus") != null);

    // expected argument
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: []const u8 = "",
        },
    }, allocator, &[_][]const u8{"--name"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);

    // --no-<name> for non-bool.
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: []const u8 = "",
        },
    }, allocator, &[_][]const u8{"--no-name"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--no-name") != null);

    // --name=false for bool
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: bool = false,
        },
    }, allocator, &[_][]const u8{"--name=true"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);

    // missing required argument
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: []const u8,
        },
    }, allocator, &[_][]const u8{}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);

    // parse int error
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: i32,
        },
    }, allocator, &[_][]const u8{"--name=abc"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: []const i32 = &.{},
        },
    }, allocator, &[_][]const u8{"--name=abc"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);

    // parse float error
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: f32,
        },
    }, allocator, &[_][]const u8{"--name=abc"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: []const f32 = &.{},
        },
    }, allocator, &[_][]const u8{"--name=abc"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);

    // parse enum error
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            name: enum { auto, never, always },
        },
    }, allocator, &[_][]const u8{"--name=abc"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "--name") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "abc") != null);
    // Error should suggest the set of options.
    try testing.expect(mem.indexOf(u8, aw.written(), "always") != null);

    // reject single-letter alias-looking arguments
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        named: struct {
            z: bool = false,
        },
        positional: struct {
            args: []const []const u8 = &.{},
        },
    }, allocator, &[_][]const u8{"-z"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "-z") != null);

    // expected required positional argument
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        positional: struct {
            input_file: []const u8,
        },
    }, allocator, &[_][]const u8{}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "input_file") != null);
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        positional: struct {
            input_file: []const u8,
            output_file: []const u8 = "",
        },
    }, allocator, &[_][]const u8{}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "input_file") != null);
    aw.clearRetainingCapacity();
    try testing.expectError(error.Usage, parseSlice(struct {
        positional: struct {
            input_file: []const u8,
            output_file: []const u8,
            other: []const u8 = "",
        },
    }, allocator, &[_][]const u8{"input.txt"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "output_file") != null);
}

test "help" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var aw: Writer.Allocating = .init(allocator);
    const options = Options{ .prog = "test-prog", .writer = &aw.writer };

    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            str: []const u8,
            int: i32,
            flag: bool,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    // Because the help output is primarily for humans, don't get too strict in the unit test.
    // Only verify that we see the important stuff that should definitely be there somewhere,
    // but otherwise allow maintainers to adjust the layout, formatting, notation, etc. without causing friction here.
    try testing.expect(mem.indexOf(u8, aw.written(), "test-prog") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "--str string") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "--int") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "--flag") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "--no-flag") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "--help") != null);

    aw.clearRetainingCapacity();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            color: enum { never, auto, always } = .auto,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    // All allowed values for an enum should be spelled out.
    try testing.expect(mem.indexOf(u8, aw.written(), "--color") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "never") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "auto") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "always") != null);

    // Test that arrays are represented differently from scalars somehow.
    aw.clearRetainingCapacity();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            name: []const u8,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    const scalar_help = try aw.toOwnedSlice();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            name: []const []const u8 = &.{},
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    try testing.expect(!mem.eql(u8, scalar_help, aw.written()));

    // Default values should be rendered somehow.
    aw.clearRetainingCapacity();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            str: []const u8 = "hello",
            int: i32 = 3,
            f: f32 = 1.25,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    try testing.expect(mem.indexOf(u8, aw.written(), "hello") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "3") != null);
    try testing.expect(mem.indexOf(u8, aw.written(), "1.25") != null);

    // Test that bool arguments express the default somehow.
    aw.clearRetainingCapacity();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            b: bool,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    const bool_required_help = try aw.toOwnedSlice();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            b: bool = true,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    const default_true_help = try aw.toOwnedSlice();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            b: bool = false,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    const default_false_help = try aw.toOwnedSlice();
    try testing.expect(!mem.eql(u8, bool_required_help, default_true_help));
    try testing.expect(!mem.eql(u8, bool_required_help, default_false_help));
    try testing.expect(!mem.eql(u8, default_true_help, default_false_help));

    // Test that enum arguments express the default somehow.
    aw.clearRetainingCapacity();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            color: enum { never, auto, always },
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    const enum_required_help = try aw.toOwnedSlice();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            color: enum { never, auto, always } = .auto,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    const default_auto_help = try aw.toOwnedSlice();
    try testing.expectError(error.Help, parseSlice(struct {
        named: struct {
            color: enum { never, auto, always } = .never,
        },
    }, allocator, &[_][]const u8{"--help"}, options));
    const default_never_help = try aw.toOwnedSlice();
    try testing.expect(!mem.eql(u8, enum_required_help, default_auto_help));
    try testing.expect(!mem.eql(u8, enum_required_help, default_never_help));
    try testing.expect(!mem.eql(u8, default_auto_help, default_never_help));
}

test "minimal" {
    const Args = struct {};

    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    _ = try parseSlice(Args, arena.allocator(), &[_][]const u8{}, .{});
}

test "manual deinit" {
    const Args = struct {
        named: struct {
            str_arr: []const []const u8 = &.{},
            int_arr: []const i32 = &.{},
            empty_arr: []const []const u8 = &.{},
        },
        positional: struct {
            args: []const []const u8 = &.{},
        },
    };

    const args = try parseSlice(Args, testing.allocator, &[_][]const u8{
        "--str_arr=hello1", "--str_arr", "hello2",
        "--int_arr=123456", "--int_arr", "789012",
        "positional-12345", "--",        "positi",
    }, .{});

    try testing.expectEqualDeep(Args{
        .named = .{
            .str_arr = &.{ "hello1", "hello2" },
            .int_arr = &.{ 123456, 789012 },
        },
        .positional = .{
            .args = &.{ "positional-12345", "positi" },
        },
    }, args);

    // Surgically cleanup memory.
    testing.allocator.free(args.named.str_arr);
    testing.allocator.free(args.named.int_arr);
    testing.allocator.free(args.named.empty_arr);
    testing.allocator.free(args.positional.args);
    // Should be no memory leak errors now.
}

test "actually calling error" {
    const Args = struct {
        named: struct {
            output: []const u8 = "",
        },
        positional: struct {
            args: []const []const u8 = &.{},
        },
    };

    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const args = try parseSlice(Args, arena.allocator(), &[_][]const u8{
        "--output=/absolute/path", "too", "many", "other", "args",
    }, .{});

    try testing.expectEqual(error.Usage, @"error"(Args, "--output must not be absolute: {s}", .{args.named.output}, silent_options));
    try testing.expectEqual(error.Usage, @"error"(Args, "expected exactly 1 positional arg", .{}, silent_options));
}

test "custom help" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var aw: Writer.Allocating = .init(allocator);
    const options = Options{ .prog = "unused-prog", .writer = &aw.writer };

    const Args = struct {
        pub const help =
            \\usage: the-zip-thing --output path [options] input.zip
            \\
            \\arguments:
            \\  --output path     where to write the output stuff
            \\  --[no-]force      overwrite output if already exists
            \\  input.zip         the zip file to read
            \\  --help            print this help and exit
            \\
        ;
        named: struct {
            output: []const u8,
            force: bool = false,
        },
        positional: struct {
            args: []const []const u8 = &.{},
        },
    };
    try testing.expectError(error.Help, parseSlice(Args, allocator, &[_][]const u8{"--help"}, options));
    try testing.expectEqualStrings(Args.help, aw.written());
}
