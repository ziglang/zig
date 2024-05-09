const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lex.zig").Token;
const CodePage = @import("code_pages.zig").CodePage;

pub const Tree = struct {
    node: *Node,
    input_code_pages: CodePageLookup,
    output_code_pages: CodePageLookup,

    /// not owned by the tree
    source: []const u8,

    arena: std.heap.ArenaAllocator.State,
    allocator: Allocator,

    pub fn deinit(self: *Tree) void {
        self.arena.promote(self.allocator).deinit();
    }

    pub fn root(self: *Tree) *Node.Root {
        return @alignCast(@fieldParentPtr("base", self.node));
    }

    pub fn dump(self: *Tree, writer: anytype) @TypeOf(writer).Error!void {
        try self.node.dump(self, writer, 0);
    }
};

pub const CodePageLookup = struct {
    lookup: std.ArrayListUnmanaged(CodePage) = .{},
    allocator: Allocator,
    default_code_page: CodePage,

    pub fn init(allocator: Allocator, default_code_page: CodePage) CodePageLookup {
        return .{
            .allocator = allocator,
            .default_code_page = default_code_page,
        };
    }

    pub fn deinit(self: *CodePageLookup) void {
        self.lookup.deinit(self.allocator);
    }

    /// line_num is 1-indexed
    pub fn setForLineNum(self: *CodePageLookup, line_num: usize, code_page: CodePage) !void {
        const index = line_num - 1;
        if (index >= self.lookup.items.len) {
            const new_size = line_num;
            const missing_lines_start_index = self.lookup.items.len;
            try self.lookup.resize(self.allocator, new_size);

            // If there are any gaps created, we need to fill them in with the value of the
            // last line before the gap. This can happen for e.g. string literals that
            // span multiple lines, or if the start of a file has multiple empty lines.
            const fill_value = if (missing_lines_start_index > 0)
                self.lookup.items[missing_lines_start_index - 1]
            else
                self.default_code_page;
            var i: usize = missing_lines_start_index;
            while (i < new_size - 1) : (i += 1) {
                self.lookup.items[i] = fill_value;
            }
        }
        self.lookup.items[index] = code_page;
    }

    pub fn setForToken(self: *CodePageLookup, token: Token, code_page: CodePage) !void {
        return self.setForLineNum(token.line_number, code_page);
    }

    /// line_num is 1-indexed
    pub fn getForLineNum(self: CodePageLookup, line_num: usize) CodePage {
        return self.lookup.items[line_num - 1];
    }

    pub fn getForToken(self: CodePageLookup, token: Token) CodePage {
        return self.getForLineNum(token.line_number);
    }
};

test "CodePageLookup" {
    var lookup = CodePageLookup.init(std.testing.allocator, .windows1252);
    defer lookup.deinit();

    try lookup.setForLineNum(5, .utf8);
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(1));
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(2));
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(3));
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(4));
    try std.testing.expectEqual(CodePage.utf8, lookup.getForLineNum(5));
    try std.testing.expectEqual(@as(usize, 5), lookup.lookup.items.len);

    try lookup.setForLineNum(7, .windows1252);
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(1));
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(2));
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(3));
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(4));
    try std.testing.expectEqual(CodePage.utf8, lookup.getForLineNum(5));
    try std.testing.expectEqual(CodePage.utf8, lookup.getForLineNum(6));
    try std.testing.expectEqual(CodePage.windows1252, lookup.getForLineNum(7));
    try std.testing.expectEqual(@as(usize, 7), lookup.lookup.items.len);
}

pub const Node = struct {
    id: Id,

    pub const Id = enum {
        root,
        resource_external,
        resource_raw_data,
        literal,
        binary_expression,
        grouped_expression,
        not_expression,
        accelerators,
        accelerator,
        dialog,
        control_statement,
        toolbar,
        menu,
        menu_item,
        menu_item_separator,
        menu_item_ex,
        popup,
        popup_ex,
        version_info,
        version_statement,
        block,
        block_value,
        block_value_value,
        string_table,
        string_table_string,
        language_statement,
        font_statement,
        simple_statement,
        invalid,

        pub fn Type(comptime id: Id) type {
            return switch (id) {
                .root => Root,
                .resource_external => ResourceExternal,
                .resource_raw_data => ResourceRawData,
                .literal => Literal,
                .binary_expression => BinaryExpression,
                .grouped_expression => GroupedExpression,
                .not_expression => NotExpression,
                .accelerators => Accelerators,
                .accelerator => Accelerator,
                .dialog => Dialog,
                .control_statement => ControlStatement,
                .toolbar => Toolbar,
                .menu => Menu,
                .menu_item => MenuItem,
                .menu_item_separator => MenuItemSeparator,
                .menu_item_ex => MenuItemEx,
                .popup => Popup,
                .popup_ex => PopupEx,
                .version_info => VersionInfo,
                .version_statement => VersionStatement,
                .block => Block,
                .block_value => BlockValue,
                .block_value_value => BlockValueValue,
                .string_table => StringTable,
                .string_table_string => StringTableString,
                .language_statement => LanguageStatement,
                .font_statement => FontStatement,
                .simple_statement => SimpleStatement,
                .invalid => Invalid,
            };
        }
    };

    pub fn cast(base: *Node, comptime id: Id) ?*id.Type() {
        if (base.id == id) {
            return @alignCast(@fieldParentPtr("base", base));
        }
        return null;
    }

    pub const Root = struct {
        base: Node = .{ .id = .root },
        body: []*Node,
    };

    pub const ResourceExternal = struct {
        base: Node = .{ .id = .resource_external },
        id: Token,
        type: Token,
        common_resource_attributes: []Token,
        filename: *Node,
    };

    pub const ResourceRawData = struct {
        base: Node = .{ .id = .resource_raw_data },
        id: Token,
        type: Token,
        common_resource_attributes: []Token,
        begin_token: Token,
        raw_data: []*Node,
        end_token: Token,
    };

    pub const Literal = struct {
        base: Node = .{ .id = .literal },
        token: Token,
    };

    pub const BinaryExpression = struct {
        base: Node = .{ .id = .binary_expression },
        operator: Token,
        left: *Node,
        right: *Node,
    };

    pub const GroupedExpression = struct {
        base: Node = .{ .id = .grouped_expression },
        open_token: Token,
        expression: *Node,
        close_token: Token,
    };

    pub const NotExpression = struct {
        base: Node = .{ .id = .not_expression },
        not_token: Token,
        number_token: Token,
    };

    pub const Accelerators = struct {
        base: Node = .{ .id = .accelerators },
        id: Token,
        type: Token,
        common_resource_attributes: []Token,
        optional_statements: []*Node,
        begin_token: Token,
        accelerators: []*Node,
        end_token: Token,
    };

    pub const Accelerator = struct {
        base: Node = .{ .id = .accelerator },
        event: *Node,
        idvalue: *Node,
        type_and_options: []Token,
    };

    pub const Dialog = struct {
        base: Node = .{ .id = .dialog },
        id: Token,
        type: Token,
        common_resource_attributes: []Token,
        x: *Node,
        y: *Node,
        width: *Node,
        height: *Node,
        help_id: ?*Node,
        optional_statements: []*Node,
        begin_token: Token,
        controls: []*Node,
        end_token: Token,
    };

    pub const ControlStatement = struct {
        base: Node = .{ .id = .control_statement },
        type: Token,
        text: ?Token,
        /// Only relevant for the user-defined CONTROL control
        class: ?*Node,
        id: *Node,
        x: *Node,
        y: *Node,
        width: *Node,
        height: *Node,
        style: ?*Node,
        exstyle: ?*Node,
        help_id: ?*Node,
        extra_data_begin: ?Token,
        extra_data: []*Node,
        extra_data_end: ?Token,

        /// Returns true if this node describes a user-defined CONTROL control
        /// https://learn.microsoft.com/en-us/windows/win32/menurc/control-control
        pub fn isUserDefined(self: *const ControlStatement) bool {
            return self.class != null;
        }
    };

    pub const Toolbar = struct {
        base: Node = .{ .id = .toolbar },
        id: Token,
        type: Token,
        common_resource_attributes: []Token,
        button_width: *Node,
        button_height: *Node,
        begin_token: Token,
        /// Will contain Literal and SimpleStatement nodes
        buttons: []*Node,
        end_token: Token,
    };

    pub const Menu = struct {
        base: Node = .{ .id = .menu },
        id: Token,
        type: Token,
        common_resource_attributes: []Token,
        optional_statements: []*Node,
        /// `help_id` will never be non-null if `type` is MENU
        help_id: ?*Node,
        begin_token: Token,
        items: []*Node,
        end_token: Token,
    };

    pub const MenuItem = struct {
        base: Node = .{ .id = .menu_item },
        menuitem: Token,
        text: Token,
        result: *Node,
        option_list: []Token,
    };

    pub const MenuItemSeparator = struct {
        base: Node = .{ .id = .menu_item_separator },
        menuitem: Token,
        separator: Token,
    };

    pub const MenuItemEx = struct {
        base: Node = .{ .id = .menu_item_ex },
        menuitem: Token,
        text: Token,
        id: ?*Node,
        type: ?*Node,
        state: ?*Node,
    };

    pub const Popup = struct {
        base: Node = .{ .id = .popup },
        popup: Token,
        text: Token,
        option_list: []Token,
        begin_token: Token,
        items: []*Node,
        end_token: Token,
    };

    pub const PopupEx = struct {
        base: Node = .{ .id = .popup_ex },
        popup: Token,
        text: Token,
        id: ?*Node,
        type: ?*Node,
        state: ?*Node,
        help_id: ?*Node,
        begin_token: Token,
        items: []*Node,
        end_token: Token,
    };

    pub const VersionInfo = struct {
        base: Node = .{ .id = .version_info },
        id: Token,
        versioninfo: Token,
        common_resource_attributes: []Token,
        /// Will contain VersionStatement and/or SimpleStatement nodes
        fixed_info: []*Node,
        begin_token: Token,
        block_statements: []*Node,
        end_token: Token,
    };

    /// Used for FILEVERSION and PRODUCTVERSION statements
    pub const VersionStatement = struct {
        base: Node = .{ .id = .version_statement },
        type: Token,
        /// Between 1-4 parts
        parts: []*Node,
    };

    pub const Block = struct {
        base: Node = .{ .id = .block },
        /// The BLOCK token itself
        identifier: Token,
        key: Token,
        /// This is undocumented but BLOCK statements support values after
        /// the key just like VALUE statements.
        values: []*Node,
        begin_token: Token,
        children: []*Node,
        end_token: Token,
    };

    pub const BlockValue = struct {
        base: Node = .{ .id = .block_value },
        /// The VALUE token itself
        identifier: Token,
        key: Token,
        /// These will be BlockValueValue nodes
        values: []*Node,
    };

    pub const BlockValueValue = struct {
        base: Node = .{ .id = .block_value_value },
        expression: *Node,
        /// Whether or not the value has a trailing comma is relevant
        trailing_comma: bool,
    };

    pub const StringTable = struct {
        base: Node = .{ .id = .string_table },
        type: Token,
        common_resource_attributes: []Token,
        optional_statements: []*Node,
        begin_token: Token,
        strings: []*Node,
        end_token: Token,
    };

    pub const StringTableString = struct {
        base: Node = .{ .id = .string_table_string },
        id: *Node,
        maybe_comma: ?Token,
        string: Token,
    };

    pub const LanguageStatement = struct {
        base: Node = .{ .id = .language_statement },
        /// The LANGUAGE token itself
        language_token: Token,
        primary_language_id: *Node,
        sublanguage_id: *Node,
    };

    pub const FontStatement = struct {
        base: Node = .{ .id = .font_statement },
        /// The FONT token itself
        identifier: Token,
        point_size: *Node,
        typeface: Token,
        weight: ?*Node,
        italic: ?*Node,
        char_set: ?*Node,
    };

    /// A statement with one value associated with it.
    /// Used for CAPTION, CHARACTERISTICS, CLASS, EXSTYLE, MENU, STYLE, VERSION,
    /// as well as VERSIONINFO-specific statements FILEFLAGSMASK, FILEFLAGS, FILEOS,
    /// FILETYPE, FILESUBTYPE
    pub const SimpleStatement = struct {
        base: Node = .{ .id = .simple_statement },
        identifier: Token,
        value: *Node,
    };

    pub const Invalid = struct {
        base: Node = .{ .id = .invalid },
        context: []Token,
    };

    pub fn isNumberExpression(node: *const Node) bool {
        switch (node.id) {
            .literal => {
                const literal: *const Node.Literal = @alignCast(@fieldParentPtr("base", node));
                return switch (literal.token.id) {
                    .number => true,
                    else => false,
                };
            },
            .binary_expression, .grouped_expression, .not_expression => return true,
            else => return false,
        }
    }

    pub fn isStringLiteral(node: *const Node) bool {
        switch (node.id) {
            .literal => {
                const literal: *const Node.Literal = @alignCast(@fieldParentPtr("base", node));
                return switch (literal.token.id) {
                    .quoted_ascii_string, .quoted_wide_string => true,
                    else => false,
                };
            },
            else => return false,
        }
    }

    pub fn getFirstToken(node: *const Node) Token {
        switch (node.id) {
            .root => unreachable,
            .resource_external => {
                const casted: *const Node.ResourceExternal = @alignCast(@fieldParentPtr("base", node));
                return casted.id;
            },
            .resource_raw_data => {
                const casted: *const Node.ResourceRawData = @alignCast(@fieldParentPtr("base", node));
                return casted.id;
            },
            .literal => {
                const casted: *const Node.Literal = @alignCast(@fieldParentPtr("base", node));
                return casted.token;
            },
            .binary_expression => {
                const casted: *const Node.BinaryExpression = @alignCast(@fieldParentPtr("base", node));
                return casted.left.getFirstToken();
            },
            .grouped_expression => {
                const casted: *const Node.GroupedExpression = @alignCast(@fieldParentPtr("base", node));
                return casted.open_token;
            },
            .not_expression => {
                const casted: *const Node.NotExpression = @alignCast(@fieldParentPtr("base", node));
                return casted.not_token;
            },
            .accelerators => {
                const casted: *const Node.Accelerators = @alignCast(@fieldParentPtr("base", node));
                return casted.id;
            },
            .accelerator => {
                const casted: *const Node.Accelerator = @alignCast(@fieldParentPtr("base", node));
                return casted.event.getFirstToken();
            },
            .dialog => {
                const casted: *const Node.Dialog = @alignCast(@fieldParentPtr("base", node));
                return casted.id;
            },
            .control_statement => {
                const casted: *const Node.ControlStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.type;
            },
            .toolbar => {
                const casted: *const Node.Toolbar = @alignCast(@fieldParentPtr("base", node));
                return casted.id;
            },
            .menu => {
                const casted: *const Node.Menu = @alignCast(@fieldParentPtr("base", node));
                return casted.id;
            },
            inline .menu_item, .menu_item_separator, .menu_item_ex => |menu_item_type| {
                const casted: *const menu_item_type.Type() = @alignCast(@fieldParentPtr("base", node));
                return casted.menuitem;
            },
            inline .popup, .popup_ex => |popup_type| {
                const casted: *const popup_type.Type() = @alignCast(@fieldParentPtr("base", node));
                return casted.popup;
            },
            .version_info => {
                const casted: *const Node.VersionInfo = @alignCast(@fieldParentPtr("base", node));
                return casted.id;
            },
            .version_statement => {
                const casted: *const Node.VersionStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.type;
            },
            .block => {
                const casted: *const Node.Block = @alignCast(@fieldParentPtr("base", node));
                return casted.identifier;
            },
            .block_value => {
                const casted: *const Node.BlockValue = @alignCast(@fieldParentPtr("base", node));
                return casted.identifier;
            },
            .block_value_value => {
                const casted: *const Node.BlockValueValue = @alignCast(@fieldParentPtr("base", node));
                return casted.expression.getFirstToken();
            },
            .string_table => {
                const casted: *const Node.StringTable = @alignCast(@fieldParentPtr("base", node));
                return casted.type;
            },
            .string_table_string => {
                const casted: *const Node.StringTableString = @alignCast(@fieldParentPtr("base", node));
                return casted.id.getFirstToken();
            },
            .language_statement => {
                const casted: *const Node.LanguageStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.language_token;
            },
            .font_statement => {
                const casted: *const Node.FontStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.identifier;
            },
            .simple_statement => {
                const casted: *const Node.SimpleStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.identifier;
            },
            .invalid => {
                const casted: *const Node.Invalid = @alignCast(@fieldParentPtr("base", node));
                return casted.context[0];
            },
        }
    }

    pub fn getLastToken(node: *const Node) Token {
        switch (node.id) {
            .root => unreachable,
            .resource_external => {
                const casted: *const Node.ResourceExternal = @alignCast(@fieldParentPtr("base", node));
                return casted.filename.getLastToken();
            },
            .resource_raw_data => {
                const casted: *const Node.ResourceRawData = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .literal => {
                const casted: *const Node.Literal = @alignCast(@fieldParentPtr("base", node));
                return casted.token;
            },
            .binary_expression => {
                const casted: *const Node.BinaryExpression = @alignCast(@fieldParentPtr("base", node));
                return casted.right.getLastToken();
            },
            .grouped_expression => {
                const casted: *const Node.GroupedExpression = @alignCast(@fieldParentPtr("base", node));
                return casted.close_token;
            },
            .not_expression => {
                const casted: *const Node.NotExpression = @alignCast(@fieldParentPtr("base", node));
                return casted.number_token;
            },
            .accelerators => {
                const casted: *const Node.Accelerators = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .accelerator => {
                const casted: *const Node.Accelerator = @alignCast(@fieldParentPtr("base", node));
                if (casted.type_and_options.len > 0) return casted.type_and_options[casted.type_and_options.len - 1];
                return casted.idvalue.getLastToken();
            },
            .dialog => {
                const casted: *const Node.Dialog = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .control_statement => {
                const casted: *const Node.ControlStatement = @alignCast(@fieldParentPtr("base", node));
                if (casted.extra_data_end) |token| return token;
                if (casted.help_id) |help_id_node| return help_id_node.getLastToken();
                if (casted.exstyle) |exstyle_node| return exstyle_node.getLastToken();
                // For user-defined CONTROL controls, the style comes before 'x', but
                // otherwise it comes after 'height' so it could be the last token if
                // it's present.
                if (!casted.isUserDefined()) {
                    if (casted.style) |style_node| return style_node.getLastToken();
                }
                return casted.height.getLastToken();
            },
            .toolbar => {
                const casted: *const Node.Toolbar = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .menu => {
                const casted: *const Node.Menu = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .menu_item => {
                const casted: *const Node.MenuItem = @alignCast(@fieldParentPtr("base", node));
                if (casted.option_list.len > 0) return casted.option_list[casted.option_list.len - 1];
                return casted.result.getLastToken();
            },
            .menu_item_separator => {
                const casted: *const Node.MenuItemSeparator = @alignCast(@fieldParentPtr("base", node));
                return casted.separator;
            },
            .menu_item_ex => {
                const casted: *const Node.MenuItemEx = @alignCast(@fieldParentPtr("base", node));
                if (casted.state) |state_node| return state_node.getLastToken();
                if (casted.type) |type_node| return type_node.getLastToken();
                if (casted.id) |id_node| return id_node.getLastToken();
                return casted.text;
            },
            inline .popup, .popup_ex => |popup_type| {
                const casted: *const popup_type.Type() = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .version_info => {
                const casted: *const Node.VersionInfo = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .version_statement => {
                const casted: *const Node.VersionStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.parts[casted.parts.len - 1].getLastToken();
            },
            .block => {
                const casted: *const Node.Block = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .block_value => {
                const casted: *const Node.BlockValue = @alignCast(@fieldParentPtr("base", node));
                if (casted.values.len > 0) return casted.values[casted.values.len - 1].getLastToken();
                return casted.key;
            },
            .block_value_value => {
                const casted: *const Node.BlockValueValue = @alignCast(@fieldParentPtr("base", node));
                return casted.expression.getLastToken();
            },
            .string_table => {
                const casted: *const Node.StringTable = @alignCast(@fieldParentPtr("base", node));
                return casted.end_token;
            },
            .string_table_string => {
                const casted: *const Node.StringTableString = @alignCast(@fieldParentPtr("base", node));
                return casted.string;
            },
            .language_statement => {
                const casted: *const Node.LanguageStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.sublanguage_id.getLastToken();
            },
            .font_statement => {
                const casted: *const Node.FontStatement = @alignCast(@fieldParentPtr("base", node));
                if (casted.char_set) |char_set_node| return char_set_node.getLastToken();
                if (casted.italic) |italic_node| return italic_node.getLastToken();
                if (casted.weight) |weight_node| return weight_node.getLastToken();
                return casted.typeface;
            },
            .simple_statement => {
                const casted: *const Node.SimpleStatement = @alignCast(@fieldParentPtr("base", node));
                return casted.value.getLastToken();
            },
            .invalid => {
                const casted: *const Node.Invalid = @alignCast(@fieldParentPtr("base", node));
                return casted.context[casted.context.len - 1];
            },
        }
    }

    pub fn dump(
        node: *const Node,
        tree: *const Tree,
        writer: anytype,
        indent: usize,
    ) @TypeOf(writer).Error!void {
        try writer.writeByteNTimes(' ', indent);
        try writer.writeAll(@tagName(node.id));
        switch (node.id) {
            .root => {
                try writer.writeAll("\n");
                const root: *Node.Root = @alignCast(@fieldParentPtr("base", node));
                for (root.body) |body_node| {
                    try body_node.dump(tree, writer, indent + 1);
                }
            },
            .resource_external => {
                const resource: *Node.ResourceExternal = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} common_resource_attributes]\n", .{ resource.id.slice(tree.source), resource.type.slice(tree.source), resource.common_resource_attributes.len });
                try resource.filename.dump(tree, writer, indent + 1);
            },
            .resource_raw_data => {
                const resource: *Node.ResourceRawData = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} common_resource_attributes] raw data: {}\n", .{ resource.id.slice(tree.source), resource.type.slice(tree.source), resource.common_resource_attributes.len, resource.raw_data.len });
                for (resource.raw_data) |data_expression| {
                    try data_expression.dump(tree, writer, indent + 1);
                }
            },
            .literal => {
                const literal: *Node.Literal = @alignCast(@fieldParentPtr("base", node));
                try writer.writeAll(" ");
                try writer.writeAll(literal.token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .binary_expression => {
                const binary: *Node.BinaryExpression = @alignCast(@fieldParentPtr("base", node));
                try writer.writeAll(" ");
                try writer.writeAll(binary.operator.slice(tree.source));
                try writer.writeAll("\n");
                try binary.left.dump(tree, writer, indent + 1);
                try binary.right.dump(tree, writer, indent + 1);
            },
            .grouped_expression => {
                const grouped: *Node.GroupedExpression = @alignCast(@fieldParentPtr("base", node));
                try writer.writeAll("\n");
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(grouped.open_token.slice(tree.source));
                try writer.writeAll("\n");
                try grouped.expression.dump(tree, writer, indent + 1);
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(grouped.close_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .not_expression => {
                const not: *Node.NotExpression = @alignCast(@fieldParentPtr("base", node));
                try writer.writeAll(" ");
                try writer.writeAll(not.not_token.slice(tree.source));
                try writer.writeAll(" ");
                try writer.writeAll(not.number_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .accelerators => {
                const accelerators: *Node.Accelerators = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} common_resource_attributes]\n", .{ accelerators.id.slice(tree.source), accelerators.type.slice(tree.source), accelerators.common_resource_attributes.len });
                for (accelerators.optional_statements) |statement| {
                    try statement.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(accelerators.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (accelerators.accelerators) |accelerator| {
                    try accelerator.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(accelerators.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .accelerator => {
                const accelerator: *Node.Accelerator = @alignCast(@fieldParentPtr("base", node));
                for (accelerator.type_and_options, 0..) |option, i| {
                    if (i != 0) try writer.writeAll(",");
                    try writer.writeByte(' ');
                    try writer.writeAll(option.slice(tree.source));
                }
                try writer.writeAll("\n");
                try accelerator.event.dump(tree, writer, indent + 1);
                try accelerator.idvalue.dump(tree, writer, indent + 1);
            },
            .dialog => {
                const dialog: *Node.Dialog = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} common_resource_attributes]\n", .{ dialog.id.slice(tree.source), dialog.type.slice(tree.source), dialog.common_resource_attributes.len });
                inline for (.{ "x", "y", "width", "height" }) |arg| {
                    try writer.writeByteNTimes(' ', indent + 1);
                    try writer.writeAll(arg ++ ":\n");
                    try @field(dialog, arg).dump(tree, writer, indent + 2);
                }
                if (dialog.help_id) |help_id| {
                    try writer.writeByteNTimes(' ', indent + 1);
                    try writer.writeAll("help_id:\n");
                    try help_id.dump(tree, writer, indent + 2);
                }
                for (dialog.optional_statements) |statement| {
                    try statement.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(dialog.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (dialog.controls) |control| {
                    try control.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(dialog.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .control_statement => {
                const control: *Node.ControlStatement = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s}", .{control.type.slice(tree.source)});
                if (control.text) |text| {
                    try writer.print(" text: {s}", .{text.slice(tree.source)});
                }
                try writer.writeByte('\n');
                if (control.class) |class| {
                    try writer.writeByteNTimes(' ', indent + 1);
                    try writer.writeAll("class:\n");
                    try class.dump(tree, writer, indent + 2);
                }
                inline for (.{ "id", "x", "y", "width", "height" }) |arg| {
                    try writer.writeByteNTimes(' ', indent + 1);
                    try writer.writeAll(arg ++ ":\n");
                    try @field(control, arg).dump(tree, writer, indent + 2);
                }
                inline for (.{ "style", "exstyle", "help_id" }) |arg| {
                    if (@field(control, arg)) |val_node| {
                        try writer.writeByteNTimes(' ', indent + 1);
                        try writer.writeAll(arg ++ ":\n");
                        try val_node.dump(tree, writer, indent + 2);
                    }
                }
                if (control.extra_data_begin != null) {
                    try writer.writeByteNTimes(' ', indent);
                    try writer.writeAll(control.extra_data_begin.?.slice(tree.source));
                    try writer.writeAll("\n");
                    for (control.extra_data) |data_node| {
                        try data_node.dump(tree, writer, indent + 1);
                    }
                    try writer.writeByteNTimes(' ', indent);
                    try writer.writeAll(control.extra_data_end.?.slice(tree.source));
                    try writer.writeAll("\n");
                }
            },
            .toolbar => {
                const toolbar: *Node.Toolbar = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} common_resource_attributes]\n", .{ toolbar.id.slice(tree.source), toolbar.type.slice(tree.source), toolbar.common_resource_attributes.len });
                inline for (.{ "button_width", "button_height" }) |arg| {
                    try writer.writeByteNTimes(' ', indent + 1);
                    try writer.writeAll(arg ++ ":\n");
                    try @field(toolbar, arg).dump(tree, writer, indent + 2);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(toolbar.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (toolbar.buttons) |button_or_sep| {
                    try button_or_sep.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(toolbar.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .menu => {
                const menu: *Node.Menu = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} common_resource_attributes]\n", .{ menu.id.slice(tree.source), menu.type.slice(tree.source), menu.common_resource_attributes.len });
                for (menu.optional_statements) |statement| {
                    try statement.dump(tree, writer, indent + 1);
                }
                if (menu.help_id) |help_id| {
                    try writer.writeByteNTimes(' ', indent + 1);
                    try writer.writeAll("help_id:\n");
                    try help_id.dump(tree, writer, indent + 2);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(menu.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (menu.items) |item| {
                    try item.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(menu.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .menu_item => {
                const menu_item: *Node.MenuItem = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} options]\n", .{ menu_item.menuitem.slice(tree.source), menu_item.text.slice(tree.source), menu_item.option_list.len });
                try menu_item.result.dump(tree, writer, indent + 1);
            },
            .menu_item_separator => {
                const menu_item: *Node.MenuItemSeparator = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s}\n", .{ menu_item.menuitem.slice(tree.source), menu_item.separator.slice(tree.source) });
            },
            .menu_item_ex => {
                const menu_item: *Node.MenuItemEx = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s}\n", .{ menu_item.menuitem.slice(tree.source), menu_item.text.slice(tree.source) });
                inline for (.{ "id", "type", "state" }) |arg| {
                    if (@field(menu_item, arg)) |val_node| {
                        try writer.writeByteNTimes(' ', indent + 1);
                        try writer.writeAll(arg ++ ":\n");
                        try val_node.dump(tree, writer, indent + 2);
                    }
                }
            },
            .popup => {
                const popup: *Node.Popup = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} options]\n", .{ popup.popup.slice(tree.source), popup.text.slice(tree.source), popup.option_list.len });
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(popup.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (popup.items) |item| {
                    try item.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(popup.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .popup_ex => {
                const popup: *Node.PopupEx = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s}\n", .{ popup.popup.slice(tree.source), popup.text.slice(tree.source) });
                inline for (.{ "id", "type", "state", "help_id" }) |arg| {
                    if (@field(popup, arg)) |val_node| {
                        try writer.writeByteNTimes(' ', indent + 1);
                        try writer.writeAll(arg ++ ":\n");
                        try val_node.dump(tree, writer, indent + 2);
                    }
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(popup.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (popup.items) |item| {
                    try item.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(popup.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .version_info => {
                const version_info: *Node.VersionInfo = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s} [{d} common_resource_attributes]\n", .{ version_info.id.slice(tree.source), version_info.versioninfo.slice(tree.source), version_info.common_resource_attributes.len });
                for (version_info.fixed_info) |fixed_info| {
                    try fixed_info.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(version_info.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (version_info.block_statements) |block| {
                    try block.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(version_info.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .version_statement => {
                const version_statement: *Node.VersionStatement = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s}\n", .{version_statement.type.slice(tree.source)});
                for (version_statement.parts) |part| {
                    try part.dump(tree, writer, indent + 1);
                }
            },
            .block => {
                const block: *Node.Block = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s}\n", .{ block.identifier.slice(tree.source), block.key.slice(tree.source) });
                for (block.values) |value| {
                    try value.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(block.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (block.children) |child| {
                    try child.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(block.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .block_value => {
                const block_value: *Node.BlockValue = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} {s}\n", .{ block_value.identifier.slice(tree.source), block_value.key.slice(tree.source) });
                for (block_value.values) |value| {
                    try value.dump(tree, writer, indent + 1);
                }
            },
            .block_value_value => {
                const block_value: *Node.BlockValueValue = @alignCast(@fieldParentPtr("base", node));
                if (block_value.trailing_comma) {
                    try writer.writeAll(" ,");
                }
                try writer.writeAll("\n");
                try block_value.expression.dump(tree, writer, indent + 1);
            },
            .string_table => {
                const string_table: *Node.StringTable = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} [{d} common_resource_attributes]\n", .{ string_table.type.slice(tree.source), string_table.common_resource_attributes.len });
                for (string_table.optional_statements) |statement| {
                    try statement.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(string_table.begin_token.slice(tree.source));
                try writer.writeAll("\n");
                for (string_table.strings) |string| {
                    try string.dump(tree, writer, indent + 1);
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll(string_table.end_token.slice(tree.source));
                try writer.writeAll("\n");
            },
            .string_table_string => {
                try writer.writeAll("\n");
                const string: *Node.StringTableString = @alignCast(@fieldParentPtr("base", node));
                try string.id.dump(tree, writer, indent + 1);
                try writer.writeByteNTimes(' ', indent + 1);
                try writer.print("{s}\n", .{string.string.slice(tree.source)});
            },
            .language_statement => {
                const language: *Node.LanguageStatement = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s}\n", .{language.language_token.slice(tree.source)});
                try language.primary_language_id.dump(tree, writer, indent + 1);
                try language.sublanguage_id.dump(tree, writer, indent + 1);
            },
            .font_statement => {
                const font: *Node.FontStatement = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s} typeface: {s}\n", .{ font.identifier.slice(tree.source), font.typeface.slice(tree.source) });
                try writer.writeByteNTimes(' ', indent + 1);
                try writer.writeAll("point_size:\n");
                try font.point_size.dump(tree, writer, indent + 2);
                inline for (.{ "weight", "italic", "char_set" }) |arg| {
                    if (@field(font, arg)) |arg_node| {
                        try writer.writeByteNTimes(' ', indent + 1);
                        try writer.writeAll(arg ++ ":\n");
                        try arg_node.dump(tree, writer, indent + 2);
                    }
                }
            },
            .simple_statement => {
                const statement: *Node.SimpleStatement = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" {s}\n", .{statement.identifier.slice(tree.source)});
                try statement.value.dump(tree, writer, indent + 1);
            },
            .invalid => {
                const invalid: *Node.Invalid = @alignCast(@fieldParentPtr("base", node));
                try writer.print(" context.len: {}\n", .{invalid.context.len});
                for (invalid.context) |context_token| {
                    try writer.writeByteNTimes(' ', indent + 1);
                    try writer.print("{s}:{s}", .{ @tagName(context_token.id), context_token.slice(tree.source) });
                    try writer.writeByte('\n');
                }
            },
        }
    }
};
