//! A Markdown document renderer.
//!
//! Each concrete `Renderer` type has a `renderDefault` function, with the
//! intention that custom `renderFn` implementations can call `renderDefault`
//! for node types for which they require no special rendering.

const std = @import("std");
const Document = @import("Document.zig");
const Node = Document.Node;
const Render = @This();

context: ?*const anyopaque,
renderFn: *const fn (
    r: Render,
    doc: Document,
    node: Node.Index,
    writer: *std.io.BufferedWriter,
) std.io.Writer.Error!void = renderDefault,

pub fn render(r: Render, doc: Document, writer: *std.io.BufferedWriter) std.io.Writer.Error!void {
    try r.renderFn(r, doc, .root, writer);
}

pub fn renderDefault(
    r: Render,
    doc: Document,
    node: Node.Index,
    writer: *std.io.BufferedWriter,
) std.io.Writer.Error!void {
    const data = doc.nodes.items(.data)[@intFromEnum(node)];
    switch (doc.nodes.items(.tag)[@intFromEnum(node)]) {
        .root => {
            for (doc.extraChildren(data.container.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
        },
        .list => {
            if (data.list.start.asNumber()) |start| {
                if (start == 1) {
                    try writer.writeAll("<ol>\n");
                } else {
                    try writer.print("<ol start=\"{}\">\n", .{start});
                }
            } else {
                try writer.writeAll("<ul>\n");
            }
            for (doc.extraChildren(data.list.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            if (data.list.start.asNumber() != null) {
                try writer.writeAll("</ol>\n");
            } else {
                try writer.writeAll("</ul>\n");
            }
        },
        .list_item => {
            try writer.writeAll("<li>");
            for (doc.extraChildren(data.list_item.children)) |child| {
                if (data.list_item.tight and doc.nodes.items(.tag)[@intFromEnum(child)] == .paragraph) {
                    const para_data = doc.nodes.items(.data)[@intFromEnum(child)];
                    for (doc.extraChildren(para_data.container.children)) |para_child| {
                        try r.renderFn(r, doc, para_child, writer);
                    }
                } else {
                    try r.renderFn(r, doc, child, writer);
                }
            }
            try writer.writeAll("</li>\n");
        },
        .table => {
            try writer.writeAll("<table>\n");
            for (doc.extraChildren(data.container.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.writeAll("</table>\n");
        },
        .table_row => {
            try writer.writeAll("<tr>\n");
            for (doc.extraChildren(data.container.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.writeAll("</tr>\n");
        },
        .table_cell => {
            if (data.table_cell.info.header) {
                try writer.writeAll("<th");
            } else {
                try writer.writeAll("<td");
            }
            switch (data.table_cell.info.alignment) {
                .unset => try writer.writeAll(">"),
                else => |a| try writer.print(" style=\"text-align: {s}\">", .{@tagName(a)}),
            }

            for (doc.extraChildren(data.table_cell.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }

            if (data.table_cell.info.header) {
                try writer.writeAll("</th>\n");
            } else {
                try writer.writeAll("</td>\n");
            }
        },
        .heading => {
            try writer.print("<h{}>", .{data.heading.level});
            for (doc.extraChildren(data.heading.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.print("</h{}>\n", .{data.heading.level});
        },
        .code_block => {
            const content = doc.string(data.code_block.content);
            try writer.print("<pre><code>{f}</code></pre>\n", .{fmtHtml(content)});
        },
        .blockquote => {
            try writer.writeAll("<blockquote>\n");
            for (doc.extraChildren(data.container.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.writeAll("</blockquote>\n");
        },
        .paragraph => {
            try writer.writeAll("<p>");
            for (doc.extraChildren(data.container.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.writeAll("</p>\n");
        },
        .thematic_break => {
            try writer.writeAll("<hr />\n");
        },
        .link => {
            const target = doc.string(data.link.target);
            try writer.print("<a href=\"{f}\">", .{fmtHtml(target)});
            for (doc.extraChildren(data.link.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.writeAll("</a>");
        },
        .autolink => {
            const target = doc.string(data.text.content);
            try writer.print("<a href=\"{0f}\">{0f}</a>", .{fmtHtml(target)});
        },
        .image => {
            const target = doc.string(data.link.target);
            try writer.print("<img src=\"{f}\" alt=\"", .{fmtHtml(target)});
            for (doc.extraChildren(data.link.children)) |child| {
                try renderInlineNodeText(doc, child, writer);
            }
            try writer.writeAll("\" />");
        },
        .strong => {
            try writer.writeAll("<strong>");
            for (doc.extraChildren(data.container.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.writeAll("</strong>");
        },
        .emphasis => {
            try writer.writeAll("<em>");
            for (doc.extraChildren(data.container.children)) |child| {
                try r.renderFn(r, doc, child, writer);
            }
            try writer.writeAll("</em>");
        },
        .code_span => {
            const content = doc.string(data.text.content);
            try writer.print("<code>{f}</code>", .{fmtHtml(content)});
        },
        .text => {
            const content = doc.string(data.text.content);
            try writer.print("{f}", .{fmtHtml(content)});
        },
        .line_break => {
            try writer.writeAll("<br />\n");
        },
    }
}

/// Renders an inline node as plain text. Asserts that the node is an inline and
/// has no non-inline children.
pub fn renderInlineNodeText(
    doc: Document,
    node: Node.Index,
    writer: *std.io.BufferedWriter,
) std.io.Writer.Error!void {
    const data = doc.nodes.items(.data)[@intFromEnum(node)];
    switch (doc.nodes.items(.tag)[@intFromEnum(node)]) {
        .root,
        .list,
        .list_item,
        .table,
        .table_row,
        .table_cell,
        .heading,
        .code_block,
        .blockquote,
        .paragraph,
        .thematic_break,
        => unreachable, // Blocks

        .link, .image => {
            for (doc.extraChildren(data.link.children)) |child| {
                try renderInlineNodeText(doc, child, writer);
            }
        },
        .strong => {
            for (doc.extraChildren(data.container.children)) |child| {
                try renderInlineNodeText(doc, child, writer);
            }
        },
        .emphasis => {
            for (doc.extraChildren(data.container.children)) |child| {
                try renderInlineNodeText(doc, child, writer);
            }
        },
        .autolink, .code_span, .text => {
            const content = doc.string(data.text.content);
            try writer.print("{f}", .{fmtHtml(content)});
        },
        .line_break => {
            try writer.writeAll("\n");
        },
    }
}

pub fn fmtHtml(bytes: []const u8) std.fmt.Formatter(formatHtml) {
    return .{ .data = bytes };
}

fn formatHtml(bytes: []const u8, writer: *std.io.BufferedWriter, comptime fmt: []const u8) !void {
    _ = fmt;
    for (bytes) |b| {
        switch (b) {
            '<' => try writer.writeAll("&lt;"),
            '>' => try writer.writeAll("&gt;"),
            '&' => try writer.writeAll("&amp;"),
            '"' => try writer.writeAll("&quot;"),
            else => try writer.writeByte(b),
        }
    }
}
