//! Zig Object Intermediate Representation.
//! Simplified AST for the ZON (Zig Object Notation) format.
//! `ZonGen` converts `Ast` to `Zoir`.

nodes: std.MultiArrayList(Node.Repr).Slice,
extra: []u32,
limbs: []std.math.big.Limb,
string_bytes: []u8,

compile_errors: []Zoir.CompileError,
error_notes: []Zoir.CompileError.Note,

/// The data stored at byte offset 0 when ZOIR is stored in a file.
pub const Header = extern struct {
    nodes_len: u32,
    extra_len: u32,
    limbs_len: u32,
    string_bytes_len: u32,
    compile_errors_len: u32,
    error_notes_len: u32,

    /// We could leave this as padding, however it triggers a Valgrind warning because
    /// we read and write undefined bytes to the file system. This is harmless, but
    /// it's essentially free to have a zero field here and makes the warning go away,
    /// making it more likely that following Valgrind warnings will be taken seriously.
    unused: u64 = 0,

    stat_inode: std.fs.File.INode,
    stat_size: u64,
    stat_mtime: i128,

    comptime {
        // Check that `unused` is working as expected
        assert(std.meta.hasUniqueRepresentation(Header));
    }
};

pub fn hasCompileErrors(zoir: Zoir) bool {
    if (zoir.compile_errors.len > 0) {
        assert(zoir.nodes.len == 0);
        assert(zoir.extra.len == 0);
        assert(zoir.limbs.len == 0);
        return true;
    } else {
        assert(zoir.error_notes.len == 0);
        return false;
    }
}

pub fn deinit(zoir: Zoir, gpa: Allocator) void {
    var nodes = zoir.nodes;
    nodes.deinit(gpa);

    gpa.free(zoir.extra);
    gpa.free(zoir.limbs);
    gpa.free(zoir.string_bytes);
    gpa.free(zoir.compile_errors);
    gpa.free(zoir.error_notes);
}

pub const Node = union(enum) {
    /// A literal `true` value.
    true,
    /// A literal `false` value.
    false,
    /// A literal `null` value.
    null,
    /// A literal `inf` value.
    pos_inf,
    /// A literal `-inf` value.
    neg_inf,
    /// A literal `nan` value.
    nan,
    /// An integer literal.
    int_literal: union(enum) {
        small: i32,
        big: std.math.big.int.Const,
    },
    /// A floating-point literal.
    float_literal: f128,
    /// A Unicode codepoint literal.
    char_literal: u21,
    /// An enum literal. The string is the literal, i.e. `foo` for `.foo`.
    enum_literal: NullTerminatedString,
    /// A string literal.
    string_literal: []const u8,
    /// An empty struct/array literal, i.e. `.{}`.
    empty_literal,
    /// An array literal. The `Range` gives the elements of the array literal.
    array_literal: Node.Index.Range,
    /// A struct literal. `names.len` is always equal to `vals.len`.
    struct_literal: struct {
        names: []const NullTerminatedString,
        vals: Node.Index.Range,
    },

    pub const Index = enum(u32) {
        root = 0,
        _,

        pub fn get(idx: Index, zoir: Zoir) Node {
            const repr = zoir.nodes.get(@intFromEnum(idx));
            return switch (repr.tag) {
                .true => .true,
                .false => .false,
                .null => .null,
                .pos_inf => .pos_inf,
                .neg_inf => .neg_inf,
                .nan => .nan,
                .int_literal_small => .{ .int_literal = .{ .small = @bitCast(repr.data) } },
                .int_literal_pos, .int_literal_neg => .{ .int_literal = .{ .big = .{
                    .limbs = l: {
                        const limb_count, const limbs_idx = zoir.extra[repr.data..][0..2].*;
                        break :l zoir.limbs[limbs_idx..][0..limb_count];
                    },
                    .positive = switch (repr.tag) {
                        .int_literal_pos => true,
                        .int_literal_neg => false,
                        else => unreachable,
                    },
                } } },
                .float_literal_small => .{ .float_literal = @as(f32, @bitCast(repr.data)) },
                .float_literal => .{ .float_literal = @bitCast(zoir.extra[repr.data..][0..4].*) },
                .char_literal => .{ .char_literal = @intCast(repr.data) },
                .enum_literal => .{ .enum_literal = @enumFromInt(repr.data) },
                .string_literal => .{ .string_literal = s: {
                    const start, const len = zoir.extra[repr.data..][0..2].*;
                    break :s zoir.string_bytes[start..][0..len];
                } },
                .string_literal_null => .{ .string_literal = NullTerminatedString.get(@enumFromInt(repr.data), zoir) },
                .empty_literal => .empty_literal,
                .array_literal => .{ .array_literal = a: {
                    const elem_count, const first_elem = zoir.extra[repr.data..][0..2].*;
                    break :a .{ .start = @enumFromInt(first_elem), .len = elem_count };
                } },
                .struct_literal => .{ .struct_literal = s: {
                    const elem_count, const first_elem = zoir.extra[repr.data..][0..2].*;
                    const field_names = zoir.extra[repr.data + 2 ..][0..elem_count];
                    break :s .{
                        .names = @ptrCast(field_names),
                        .vals = .{ .start = @enumFromInt(first_elem), .len = elem_count },
                    };
                } },
            };
        }

        pub fn getAstNode(idx: Index, zoir: Zoir) std.zig.Ast.Node.Index {
            return zoir.nodes.items(.ast_node)[@intFromEnum(idx)];
        }

        pub const Range = struct {
            start: Index,
            len: u32,

            pub fn at(r: Range, i: u32) Index {
                assert(i < r.len);
                return @enumFromInt(@intFromEnum(r.start) + i);
            }
        };
    };

    pub const Repr = struct {
        tag: Tag,
        data: u32,
        ast_node: std.zig.Ast.Node.Index,

        pub const Tag = enum(u8) {
            /// `data` is ignored.
            true,
            /// `data` is ignored.
            false,
            /// `data` is ignored.
            null,
            /// `data` is ignored.
            pos_inf,
            /// `data` is ignored.
            neg_inf,
            /// `data` is ignored.
            nan,
            /// `data` is the `i32` value.
            int_literal_small,
            /// `data` is index into `extra` of:
            /// * `limb_count: u32`
            /// * `limbs_idx: u32`
            int_literal_pos,
            /// Identical to `int_literal_pos`, except the value is negative.
            int_literal_neg,
            /// `data` is the `f32` value.
            float_literal_small,
            /// `data` is index into `extra` of 4 elements which are a bitcast `f128`.
            float_literal,
            /// `data` is the `u32` value.
            char_literal,
            /// `data` is a `NullTerminatedString`.
            enum_literal,
            /// `data` is index into `extra` of:
            /// * `start: u32`
            /// * `len: u32`
            string_literal,
            /// Null-terminated string literal,
            /// `data` is a `NullTerminatedString`.
            string_literal_null,
            /// An empty struct/array literal, `.{}`.
            /// `data` is ignored.
            empty_literal,
            /// `data` is index into `extra` of:
            /// * `elem_count: u32`
            /// * `first_elem: Node.Index`
            /// The nodes `first_elem .. first_elem + elem_count` are the children.
            array_literal,
            /// `data` is index into `extra` of:
            /// * `elem_count: u32`
            /// * `first_elem: Node.Index`
            /// * `field_name: NullTerminatedString` for each `elem_count`
            /// The nodes `first_elem .. first_elem + elem_count` are the children.
            struct_literal,
        };
    };
};

pub const NullTerminatedString = enum(u32) {
    _,
    pub fn get(nts: NullTerminatedString, zoir: Zoir) [:0]const u8 {
        const idx = std.mem.indexOfScalar(u8, zoir.string_bytes[@intFromEnum(nts)..], 0).?;
        return zoir.string_bytes[@intFromEnum(nts)..][0..idx :0];
    }
};

pub const CompileError = extern struct {
    msg: NullTerminatedString,
    token: Ast.TokenIndex,
    /// If `token == invalid_token`, this is an `Ast.Node.Index`.
    /// Otherwise, this is a byte offset into `token`.
    node_or_offset: u32,

    /// Ignored if `note_count == 0`.
    first_note: u32,
    note_count: u32,

    pub fn getNotes(err: CompileError, zoir: Zoir) []const Note {
        return zoir.error_notes[err.first_note..][0..err.note_count];
    }

    pub const Note = extern struct {
        msg: NullTerminatedString,
        token: Ast.TokenIndex,
        /// If `token == invalid_token`, this is an `Ast.Node.Index`.
        /// Otherwise, this is a byte offset into `token`.
        node_or_offset: u32,
    };

    pub const invalid_token: Ast.TokenIndex = std.math.maxInt(Ast.TokenIndex);

    comptime {
        assert(std.meta.hasUniqueRepresentation(CompileError));
        assert(std.meta.hasUniqueRepresentation(Note));
    }
};

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Ast = std.zig.Ast;
const Zoir = @This();
