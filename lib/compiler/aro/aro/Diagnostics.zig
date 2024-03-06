const std = @import("std");
const Allocator = mem.Allocator;
const mem = std.mem;
const Source = @import("Source.zig");
const Compilation = @import("Compilation.zig");
const Attribute = @import("Attribute.zig");
const Builtins = @import("Builtins.zig");
const Builtin = Builtins.Builtin;
const Header = @import("Builtins/Properties.zig").Header;
const Tree = @import("Tree.zig");
const is_windows = @import("builtin").os.tag == .windows;
const LangOpts = @import("LangOpts.zig");

pub const Message = struct {
    tag: Tag,
    kind: Kind = undefined,
    loc: Source.Location = .{},
    extra: Extra = .{ .none = {} },

    pub const Extra = union {
        str: []const u8,
        tok_id: struct {
            expected: Tree.Token.Id,
            actual: Tree.Token.Id,
        },
        tok_id_expected: Tree.Token.Id,
        arguments: struct {
            expected: u32,
            actual: u32,
        },
        codepoints: struct {
            actual: u21,
            resembles: u21,
        },
        attr_arg_count: struct {
            attribute: Attribute.Tag,
            expected: u32,
        },
        attr_arg_type: struct {
            expected: Attribute.ArgumentType,
            actual: Attribute.ArgumentType,
        },
        attr_enum: struct {
            tag: Attribute.Tag,
        },
        ignored_record_attr: struct {
            tag: Attribute.Tag,
            specifier: enum { @"struct", @"union", @"enum" },
        },
        builtin_with_header: struct {
            builtin: Builtin.Tag,
            header: Header,
        },
        invalid_escape: struct {
            offset: u32,
            char: u8,
        },
        actual_codepoint: u21,
        ascii: u7,
        unsigned: u64,
        offset: u64,
        pow_2_as_string: u8,
        signed: i64,
        normalized: []const u8,
        none: void,
    };
};

const Properties = struct {
    msg: []const u8,
    kind: Kind,
    extra: std.meta.FieldEnum(Message.Extra) = .none,
    opt: ?u8 = null,
    all: bool = false,
    w_extra: bool = false,
    pedantic: bool = false,
    suppress_version: ?LangOpts.Standard = null,
    suppress_unless_version: ?LangOpts.Standard = null,
    suppress_gnu: bool = false,
    suppress_gcc: bool = false,
    suppress_clang: bool = false,
    suppress_msvc: bool = false,

    pub fn makeOpt(comptime str: []const u8) u16 {
        return @offsetOf(Options, str);
    }
    pub fn getKind(prop: Properties, options: *Options) Kind {
        const opt = @as([*]Kind, @ptrCast(options))[prop.opt orelse return prop.kind];
        if (opt == .default) return prop.kind;
        return opt;
    }
    pub const max_bits = Compilation.bit_int_max_bits;
};

pub const Tag = @import("Diagnostics/messages.zig").with(Properties).Tag;

pub const Kind = enum { @"fatal error", @"error", note, warning, off, default };

pub const Options = struct {
    // do not directly use these, instead add `const NAME = true;`
    all: Kind = .default,
    extra: Kind = .default,
    pedantic: Kind = .default,

    @"unsupported-pragma": Kind = .default,
    @"c99-extensions": Kind = .default,
    @"implicit-int": Kind = .default,
    @"duplicate-decl-specifier": Kind = .default,
    @"missing-declaration": Kind = .default,
    @"extern-initializer": Kind = .default,
    @"implicit-function-declaration": Kind = .default,
    @"unused-value": Kind = .default,
    @"unreachable-code": Kind = .default,
    @"unknown-warning-option": Kind = .default,
    @"gnu-empty-struct": Kind = .default,
    @"gnu-alignof-expression": Kind = .default,
    @"macro-redefined": Kind = .default,
    @"generic-qual-type": Kind = .default,
    multichar: Kind = .default,
    @"pointer-integer-compare": Kind = .default,
    @"compare-distinct-pointer-types": Kind = .default,
    @"literal-conversion": Kind = .default,
    @"cast-qualifiers": Kind = .default,
    @"array-bounds": Kind = .default,
    @"int-conversion": Kind = .default,
    @"pointer-type-mismatch": Kind = .default,
    @"c23-extensions": Kind = .default,
    @"incompatible-pointer-types": Kind = .default,
    @"excess-initializers": Kind = .default,
    @"division-by-zero": Kind = .default,
    @"initializer-overrides": Kind = .default,
    @"incompatible-pointer-types-discards-qualifiers": Kind = .default,
    @"unknown-attributes": Kind = .default,
    @"ignored-attributes": Kind = .default,
    @"builtin-macro-redefined": Kind = .default,
    @"gnu-label-as-value": Kind = .default,
    @"malformed-warning-check": Kind = .default,
    @"#pragma-messages": Kind = .default,
    @"newline-eof": Kind = .default,
    @"empty-translation-unit": Kind = .default,
    @"implicitly-unsigned-literal": Kind = .default,
    @"c99-compat": Kind = .default,
    @"unicode-zero-width": Kind = .default,
    @"unicode-homoglyph": Kind = .default,
    unicode: Kind = .default,
    @"return-type": Kind = .default,
    @"dollar-in-identifier-extension": Kind = .default,
    @"unknown-pragmas": Kind = .default,
    @"predefined-identifier-outside-function": Kind = .default,
    @"many-braces-around-scalar-init": Kind = .default,
    uninitialized: Kind = .default,
    @"gnu-statement-expression": Kind = .default,
    @"gnu-imaginary-constant": Kind = .default,
    @"gnu-complex-integer": Kind = .default,
    @"ignored-qualifiers": Kind = .default,
    @"integer-overflow": Kind = .default,
    @"extra-semi": Kind = .default,
    @"gnu-binary-literal": Kind = .default,
    @"variadic-macros": Kind = .default,
    varargs: Kind = .default,
    @"#warnings": Kind = .default,
    @"deprecated-declarations": Kind = .default,
    @"backslash-newline-escape": Kind = .default,
    @"pointer-to-int-cast": Kind = .default,
    @"gnu-case-range": Kind = .default,
    @"c++-compat": Kind = .default,
    vla: Kind = .default,
    @"float-overflow-conversion": Kind = .default,
    @"float-zero-conversion": Kind = .default,
    @"float-conversion": Kind = .default,
    @"gnu-folding-constant": Kind = .default,
    undef: Kind = .default,
    @"ignored-pragmas": Kind = .default,
    @"gnu-include-next": Kind = .default,
    @"include-next-outside-header": Kind = .default,
    @"include-next-absolute-path": Kind = .default,
    @"enum-too-large": Kind = .default,
    @"fixed-enum-extension": Kind = .default,
    @"designated-init": Kind = .default,
    @"attribute-warning": Kind = .default,
    @"invalid-noreturn": Kind = .default,
    @"zero-length-array": Kind = .default,
    @"old-style-flexible-struct": Kind = .default,
    @"gnu-zero-variadic-macro-arguments": Kind = .default,
    @"main-return-type": Kind = .default,
    @"expansion-to-defined": Kind = .default,
    @"bit-int-extension": Kind = .default,
    @"keyword-macro": Kind = .default,
    @"pointer-arith": Kind = .default,
    @"sizeof-array-argument": Kind = .default,
    @"pre-c23-compat": Kind = .default,
    @"pointer-bool-conversion": Kind = .default,
    @"string-conversion": Kind = .default,
    @"gnu-auto-type": Kind = .default,
    @"gnu-union-cast": Kind = .default,
    @"pointer-sign": Kind = .default,
    @"fuse-ld-path": Kind = .default,
    @"language-extension-token": Kind = .default,
    @"complex-component-init": Kind = .default,
    @"microsoft-include": Kind = .default,
    @"microsoft-end-of-file": Kind = .default,
    @"invalid-source-encoding": Kind = .default,
    @"four-char-constants": Kind = .default,
    @"unknown-escape-sequence": Kind = .default,
    @"invalid-pp-token": Kind = .default,
    @"deprecated-non-prototype": Kind = .default,
    @"duplicate-embed-param": Kind = .default,
    @"unsupported-embed-param": Kind = .default,
    @"unused-result": Kind = .default,
    normalized: Kind = .default,
    @"shift-count-negative": Kind = .default,
    @"shift-count-overflow": Kind = .default,
};

const Diagnostics = @This();

list: std.ArrayListUnmanaged(Message) = .{},
arena: std.heap.ArenaAllocator,
fatal_errors: bool = false,
options: Options = .{},
errors: u32 = 0,
macro_backtrace_limit: u32 = 6,

pub fn warningExists(name: []const u8) bool {
    inline for (std.meta.fields(Options)) |f| {
        if (mem.eql(u8, f.name, name)) return true;
    }
    return false;
}

pub fn set(d: *Diagnostics, name: []const u8, to: Kind) !void {
    inline for (std.meta.fields(Options)) |f| {
        if (mem.eql(u8, f.name, name)) {
            @field(d.options, f.name) = to;
            return;
        }
    }
    try d.addExtra(.{}, .{
        .tag = .unknown_warning,
        .extra = .{ .str = name },
    }, &.{}, true);
}

pub fn init(gpa: Allocator) Diagnostics {
    return .{
        .arena = std.heap.ArenaAllocator.init(gpa),
    };
}

pub fn deinit(d: *Diagnostics) void {
    d.list.deinit(d.arena.child_allocator);
    d.arena.deinit();
}

pub fn add(comp: *Compilation, msg: Message, expansion_locs: []const Source.Location) Compilation.Error!void {
    return comp.diagnostics.addExtra(comp.langopts, msg, expansion_locs, true);
}

pub fn addExtra(
    d: *Diagnostics,
    langopts: LangOpts,
    msg: Message,
    expansion_locs: []const Source.Location,
    note_msg_loc: bool,
) Compilation.Error!void {
    const kind = d.tagKind(msg.tag, langopts);
    if (kind == .off) return;
    var copy = msg;
    copy.kind = kind;

    if (expansion_locs.len != 0) copy.loc = expansion_locs[expansion_locs.len - 1];
    try d.list.append(d.arena.child_allocator, copy);
    if (expansion_locs.len != 0) {
        // Add macro backtrace notes in reverse order omitting from the middle if needed.
        var i = expansion_locs.len - 1;
        const half = d.macro_backtrace_limit / 2;
        const limit = if (i < d.macro_backtrace_limit) 0 else i - half;
        try d.list.ensureUnusedCapacity(
            d.arena.child_allocator,
            if (limit == 0) expansion_locs.len else d.macro_backtrace_limit + 1,
        );
        while (i > limit) {
            i -= 1;
            d.list.appendAssumeCapacity(.{
                .tag = .expanded_from_here,
                .kind = .note,
                .loc = expansion_locs[i],
            });
        }
        if (limit != 0) {
            d.list.appendAssumeCapacity(.{
                .tag = .skipping_macro_backtrace,
                .kind = .note,
                .extra = .{ .unsigned = expansion_locs.len - d.macro_backtrace_limit },
            });
            i = half -| 1;
            while (i > 0) {
                i -= 1;
                d.list.appendAssumeCapacity(.{
                    .tag = .expanded_from_here,
                    .kind = .note,
                    .loc = expansion_locs[i],
                });
            }
        }

        if (note_msg_loc) d.list.appendAssumeCapacity(.{
            .tag = .expanded_from_here,
            .kind = .note,
            .loc = msg.loc,
        });
    }
    if (kind == .@"fatal error" or (kind == .@"error" and d.fatal_errors))
        return error.FatalError;
}

pub fn render(comp: *Compilation, config: std.io.tty.Config) void {
    if (comp.diagnostics.list.items.len == 0) return;
    var m = defaultMsgWriter(config);
    defer m.deinit();
    renderMessages(comp, &m);
}
pub fn defaultMsgWriter(config: std.io.tty.Config) MsgWriter {
    return MsgWriter.init(config);
}

pub fn renderMessages(comp: *Compilation, m: anytype) void {
    var errors: u32 = 0;
    var warnings: u32 = 0;
    for (comp.diagnostics.list.items) |msg| {
        switch (msg.kind) {
            .@"fatal error", .@"error" => errors += 1,
            .warning => warnings += 1,
            .note => {},
            .off => continue, // happens if an error is added before it is disabled
            .default => unreachable,
        }
        renderMessage(comp, m, msg);
    }
    const w_s: []const u8 = if (warnings == 1) "" else "s";
    const e_s: []const u8 = if (errors == 1) "" else "s";
    if (errors != 0 and warnings != 0) {
        m.print("{d} warning{s} and {d} error{s} generated.\n", .{ warnings, w_s, errors, e_s });
    } else if (warnings != 0) {
        m.print("{d} warning{s} generated.\n", .{ warnings, w_s });
    } else if (errors != 0) {
        m.print("{d} error{s} generated.\n", .{ errors, e_s });
    }

    comp.diagnostics.list.items.len = 0;
    comp.diagnostics.errors += errors;
}

pub fn renderMessage(comp: *Compilation, m: anytype, msg: Message) void {
    var line: ?[]const u8 = null;
    var end_with_splice = false;
    const width = if (msg.loc.id != .unused) blk: {
        var loc = msg.loc;
        switch (msg.tag) {
            .escape_sequence_overflow,
            .invalid_universal_character,
            => loc.byte_offset += @truncate(msg.extra.offset),
            .non_standard_escape_char,
            .unknown_escape_sequence,
            => loc.byte_offset += msg.extra.invalid_escape.offset,
            else => {},
        }
        const source = comp.getSource(loc.id);
        var line_col = source.lineCol(loc);
        line = line_col.line;
        end_with_splice = line_col.end_with_splice;
        if (msg.tag == .backslash_newline_escape) {
            line = line_col.line[0 .. line_col.col - 1];
            line_col.col += 1;
            line_col.width += 1;
        }
        m.location(source.path, line_col.line_no, line_col.col);
        break :blk line_col.width;
    } else 0;

    m.start(msg.kind);
    const prop = msg.tag.property();
    switch (prop.extra) {
        .str => printRt(m, prop.msg, .{"{s}"}, .{msg.extra.str}),
        .tok_id => printRt(m, prop.msg, .{ "{s}", "{s}" }, .{
            msg.extra.tok_id.expected.symbol(),
            msg.extra.tok_id.actual.symbol(),
        }),
        .tok_id_expected => printRt(m, prop.msg, .{"{s}"}, .{msg.extra.tok_id_expected.symbol()}),
        .arguments => printRt(m, prop.msg, .{ "{d}", "{d}" }, .{
            msg.extra.arguments.expected,
            msg.extra.arguments.actual,
        }),
        .codepoints => printRt(m, prop.msg, .{ "{X:0>4}", "{u}" }, .{
            msg.extra.codepoints.actual,
            msg.extra.codepoints.resembles,
        }),
        .attr_arg_count => printRt(m, prop.msg, .{ "{s}", "{d}" }, .{
            @tagName(msg.extra.attr_arg_count.attribute),
            msg.extra.attr_arg_count.expected,
        }),
        .attr_arg_type => printRt(m, prop.msg, .{ "{s}", "{s}" }, .{
            msg.extra.attr_arg_type.expected.toString(),
            msg.extra.attr_arg_type.actual.toString(),
        }),
        .actual_codepoint => printRt(m, prop.msg, .{"{X:0>4}"}, .{msg.extra.actual_codepoint}),
        .ascii => printRt(m, prop.msg, .{"{c}"}, .{msg.extra.ascii}),
        .unsigned => printRt(m, prop.msg, .{"{d}"}, .{msg.extra.unsigned}),
        .pow_2_as_string => printRt(m, prop.msg, .{"{s}"}, .{switch (msg.extra.pow_2_as_string) {
            63 => "9223372036854775808",
            64 => "18446744073709551616",
            127 => "170141183460469231731687303715884105728",
            128 => "340282366920938463463374607431768211456",
            else => unreachable,
        }}),
        .signed => printRt(m, prop.msg, .{"{d}"}, .{msg.extra.signed}),
        .attr_enum => printRt(m, prop.msg, .{ "{s}", "{s}" }, .{
            @tagName(msg.extra.attr_enum.tag),
            Attribute.Formatting.choices(msg.extra.attr_enum.tag),
        }),
        .ignored_record_attr => printRt(m, prop.msg, .{ "{s}", "{s}" }, .{
            @tagName(msg.extra.ignored_record_attr.tag),
            @tagName(msg.extra.ignored_record_attr.specifier),
        }),
        .builtin_with_header => printRt(m, prop.msg, .{ "{s}", "{s}" }, .{
            @tagName(msg.extra.builtin_with_header.header),
            Builtin.nameFromTag(msg.extra.builtin_with_header.builtin).span(),
        }),
        .invalid_escape => {
            if (std.ascii.isPrint(msg.extra.invalid_escape.char)) {
                const str: [1]u8 = .{msg.extra.invalid_escape.char};
                printRt(m, prop.msg, .{"{s}"}, .{&str});
            } else {
                var buf: [3]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "x{x}", .{std.fmt.fmtSliceHexLower(&.{msg.extra.invalid_escape.char})}) catch unreachable;
                printRt(m, prop.msg, .{"{s}"}, .{str});
            }
        },
        .normalized => {
            const f = struct {
                pub fn f(
                    bytes: []const u8,
                    comptime _: []const u8,
                    _: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    var it: std.unicode.Utf8Iterator = .{
                        .bytes = bytes,
                        .i = 0,
                    };
                    while (it.nextCodepoint()) |codepoint| {
                        if (codepoint < 0x7F) {
                            try writer.writeByte(@intCast(codepoint));
                        } else if (codepoint < 0xFFFF) {
                            try writer.writeAll("\\u");
                            try std.fmt.formatInt(codepoint, 16, .upper, .{
                                .fill = '0',
                                .width = 4,
                            }, writer);
                        } else {
                            try writer.writeAll("\\U");
                            try std.fmt.formatInt(codepoint, 16, .upper, .{
                                .fill = '0',
                                .width = 8,
                            }, writer);
                        }
                    }
                }
            }.f;
            printRt(m, prop.msg, .{"{s}"}, .{
                std.fmt.Formatter(f){ .data = msg.extra.normalized },
            });
        },
        .none, .offset => m.write(prop.msg),
    }

    if (prop.opt) |some| {
        if (msg.kind == .@"error" and prop.kind != .@"error") {
            m.print(" [-Werror,-W{s}]", .{optName(some)});
        } else if (msg.kind != .note) {
            m.print(" [-W{s}]", .{optName(some)});
        }
    }

    m.end(line, width, end_with_splice);
}

fn printRt(m: anytype, str: []const u8, comptime fmts: anytype, args: anytype) void {
    var i: usize = 0;
    inline for (fmts, args) |fmt, arg| {
        const new = std.mem.indexOfPos(u8, str, i, fmt).?;
        m.write(str[i..new]);
        i = new + fmt.len;
        m.print(fmt, .{arg});
    }
    m.write(str[i..]);
}

fn optName(offset: u16) []const u8 {
    return std.meta.fieldNames(Options)[offset / @sizeOf(Kind)];
}

fn tagKind(d: *Diagnostics, tag: Tag, langopts: LangOpts) Kind {
    const prop = tag.property();
    var kind = prop.getKind(&d.options);

    if (prop.all) {
        if (d.options.all != .default) kind = d.options.all;
    }
    if (prop.w_extra) {
        if (d.options.extra != .default) kind = d.options.extra;
    }
    if (prop.pedantic) {
        if (d.options.pedantic != .default) kind = d.options.pedantic;
    }
    if (prop.suppress_version) |some| if (langopts.standard.atLeast(some)) return .off;
    if (prop.suppress_unless_version) |some| if (!langopts.standard.atLeast(some)) return .off;
    if (prop.suppress_gnu and langopts.standard.isExplicitGNU()) return .off;
    if (prop.suppress_gcc and langopts.emulate == .gcc) return .off;
    if (prop.suppress_clang and langopts.emulate == .clang) return .off;
    if (prop.suppress_msvc and langopts.emulate == .msvc) return .off;
    if (kind == .@"error" and d.fatal_errors) kind = .@"fatal error";
    return kind;
}

const MsgWriter = struct {
    w: std.io.BufferedWriter(4096, std.fs.File.Writer),
    config: std.io.tty.Config,

    fn init(config: std.io.tty.Config) MsgWriter {
        std.debug.getStderrMutex().lock();
        return .{
            .w = std.io.bufferedWriter(std.io.getStdErr().writer()),
            .config = config,
        };
    }

    pub fn deinit(m: *MsgWriter) void {
        m.w.flush() catch {};
        std.debug.getStderrMutex().unlock();
    }

    pub fn print(m: *MsgWriter, comptime fmt: []const u8, args: anytype) void {
        m.w.writer().print(fmt, args) catch {};
    }

    fn write(m: *MsgWriter, msg: []const u8) void {
        m.w.writer().writeAll(msg) catch {};
    }

    fn setColor(m: *MsgWriter, color: std.io.tty.Color) void {
        m.config.setColor(m.w.writer(), color) catch {};
    }

    fn location(m: *MsgWriter, path: []const u8, line: u32, col: u32) void {
        m.setColor(.bold);
        m.print("{s}:{d}:{d}: ", .{ path, line, col });
    }

    fn start(m: *MsgWriter, kind: Kind) void {
        switch (kind) {
            .@"fatal error", .@"error" => m.setColor(.bright_red),
            .note => m.setColor(.bright_cyan),
            .warning => m.setColor(.bright_magenta),
            .off, .default => unreachable,
        }
        m.write(switch (kind) {
            .@"fatal error" => "fatal error: ",
            .@"error" => "error: ",
            .note => "note: ",
            .warning => "warning: ",
            .off, .default => unreachable,
        });
        m.setColor(.white);
    }

    fn end(m: *MsgWriter, maybe_line: ?[]const u8, col: u32, end_with_splice: bool) void {
        const line = maybe_line orelse {
            m.write("\n");
            m.setColor(.reset);
            return;
        };
        const trailer = if (end_with_splice) "\\ " else "";
        m.setColor(.reset);
        m.print("\n{s}{s}\n{s: >[3]}", .{ line, trailer, "", col });
        m.setColor(.bold);
        m.setColor(.bright_green);
        m.write("^\n");
        m.setColor(.reset);
    }
};
