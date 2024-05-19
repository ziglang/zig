//! An abstract tree representation of a Markdown document.

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Renderer = @import("renderer.zig").Renderer;

nodes: Node.List.Slice,
extra: []u32,
string_bytes: []u8,

const Document = @This();

pub const Node = struct {
    tag: Tag,
    data: Data,

    pub const Index = enum(u32) {
        root = 0,
        _,
    };
    pub const List = std.MultiArrayList(Node);

    pub const Tag = enum {
        /// Data is `container`.
        root,

        // Blocks
        /// Data is `list`.
        list,
        /// Data is `list_item`.
        list_item,
        /// Data is `container`.
        table,
        /// Data is `container`.
        table_row,
        /// Data is `table_cell`.
        table_cell,
        /// Data is `heading`.
        heading,
        /// Data is `code_block`.
        code_block,
        /// Data is `container`.
        blockquote,
        /// Data is `container`.
        paragraph,
        /// Data is `none`.
        thematic_break,

        // Inlines
        /// Data is `link`.
        link,
        /// Data is `text`.
        autolink,
        /// Data is `link`.
        image,
        /// Data is `container`.
        strong,
        /// Data is `container`.
        emphasis,
        /// Data is `text`.
        code_span,
        /// Data is `text`.
        text,
        /// Data is `none`.
        line_break,
    };

    pub const Data = union {
        none: void,
        container: struct {
            children: ExtraIndex,
        },
        text: struct {
            content: StringIndex,
        },
        list: struct {
            start: ListStart,
            children: ExtraIndex,
        },
        list_item: struct {
            tight: bool,
            children: ExtraIndex,
        },
        table_cell: struct {
            info: packed struct {
                alignment: TableCellAlignment,
                header: bool,
            },
            children: ExtraIndex,
        },
        heading: struct {
            /// Between 1 and 6, inclusive.
            level: u3,
            children: ExtraIndex,
        },
        code_block: struct {
            tag: StringIndex,
            content: StringIndex,
        },
        link: struct {
            target: StringIndex,
            children: ExtraIndex,
        },

        comptime {
            // In Debug and ReleaseSafe builds, there may be hidden extra fields
            // included for safety checks. Without such safety checks enabled,
            // we always want this union to be 8 bytes.
            if (builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
                assert(@sizeOf(Data) == 8);
            }
        }
    };

    /// The starting number of a list. This is either a number between 0 and
    /// 999,999,999, inclusive, or `unordered` to indicate an unordered list.
    pub const ListStart = enum(u30) {
        // When https://github.com/ziglang/zig/issues/104 is implemented, this
        // type can be more naturally expressed as ?u30. As it is, we want
        // values to fit within 4 bytes, so ?u30 does not yet suffice for
        // storage.
        unordered = std.math.maxInt(u30),
        _,

        pub fn asNumber(start: ListStart) ?u30 {
            if (start == .unordered) return null;
            assert(@intFromEnum(start) <= 999_999_999);
            return @intFromEnum(start);
        }
    };

    pub const TableCellAlignment = enum(u2) {
        unset,
        left,
        center,
        right,
    };

    /// Trailing: `len` times `Node.Index`
    pub const Children = struct {
        len: u32,
    };
};

pub const ExtraIndex = enum(u32) { _ };

/// The index of a null-terminated string in `string_bytes`.
pub const StringIndex = enum(u32) {
    empty = 0,
    _,
};

pub fn deinit(doc: *Document, allocator: Allocator) void {
    doc.nodes.deinit(allocator);
    allocator.free(doc.extra);
    allocator.free(doc.string_bytes);
    doc.* = undefined;
}

/// Renders a document directly to a writer using the default renderer.
pub fn render(doc: Document, writer: anytype) @TypeOf(writer).Error!void {
    const renderer: Renderer(@TypeOf(writer), void) = .{ .context = {} };
    try renderer.render(doc, writer);
}

pub fn ExtraData(comptime T: type) type {
    return struct { data: T, end: usize };
}

pub fn extraData(doc: Document, comptime T: type, index: ExtraIndex) ExtraData(T) {
    const fields = @typeInfo(T).Struct.fields;
    var i: usize = @intFromEnum(index);
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => doc.extra[i],
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{ .data = result, .end = i };
}

pub fn extraChildren(doc: Document, index: ExtraIndex) []const Node.Index {
    const children = doc.extraData(Node.Children, index);
    return @ptrCast(doc.extra[children.end..][0..children.data.len]);
}

pub fn string(doc: Document, index: StringIndex) [:0]const u8 {
    const start = @intFromEnum(index);
    return std.mem.span(@as([*:0]u8, @ptrCast(doc.string_bytes[start..].ptr)));
}
