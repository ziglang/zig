const std = @import("std");
const mem = std.mem;

const Compilation = @import("../Compilation.zig");
const Diagnostics = @import("../Diagnostics.zig");
const Parser = @import("../Parser.zig");
const Pragma = @import("../Pragma.zig");
const Preprocessor = @import("../Preprocessor.zig");
const TokenIndex = @import("../Tree.zig").TokenIndex;

const GCC = @This();

pragma: Pragma = .{
    .beforeParse = beforeParse,
    .beforePreprocess = beforePreprocess,
    .afterParse = afterParse,
    .deinit = deinit,
    .preprocessorHandler = preprocessorHandler,
    .parserHandler = parserHandler,
    .preserveTokens = preserveTokens,
},
original_state: Diagnostics.State = .{},
state_stack: std.ArrayList(Diagnostics.State) = .empty,

const Directive = enum {
    warning,
    @"error",
    diagnostic,
    poison,
    const Diagnostics = enum {
        ignored,
        warning,
        @"error",
        fatal,
        push,
        pop,
    };
};

fn beforePreprocess(pragma: *Pragma, comp: *Compilation) void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    self.original_state = comp.diagnostics.state;
}

fn beforeParse(pragma: *Pragma, comp: *Compilation) void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    comp.diagnostics.state = self.original_state;
    self.state_stack.items.len = 0;
}

fn afterParse(pragma: *Pragma, comp: *Compilation) void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    comp.diagnostics.state = self.original_state;
    self.state_stack.items.len = 0;
}

pub fn init(allocator: mem.Allocator) !*Pragma {
    var gcc = try allocator.create(GCC);
    gcc.* = .{};
    return &gcc.pragma;
}

fn deinit(pragma: *Pragma, comp: *Compilation) void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    self.state_stack.deinit(comp.gpa);
    comp.gpa.destroy(self);
}

fn diagnosticHandler(self: *GCC, pp: *Preprocessor, start_idx: TokenIndex) Pragma.Error!void {
    const diagnostic_tok = pp.tokens.get(start_idx);
    if (diagnostic_tok.id == .nl) return;

    const diagnostic = std.meta.stringToEnum(Directive.Diagnostics, pp.expandedSlice(diagnostic_tok)) orelse
        return error.UnknownPragma;

    switch (diagnostic) {
        .ignored, .warning, .@"error", .fatal => {
            const str = Pragma.pasteTokens(pp, start_idx + 1) catch |err| switch (err) {
                error.ExpectedStringLiteral => {
                    return Pragma.err(pp, start_idx, .pragma_requires_string_literal, .{"GCC diagnostic"});
                },
                else => |e| return e,
            };
            if (!mem.startsWith(u8, str, "-W")) {
                return Pragma.err(pp, start_idx + 1, .malformed_warning_check, .{"GCC diagnostic"});
            }
            const new_kind: Diagnostics.Message.Kind = switch (diagnostic) {
                .ignored => .off,
                .warning => .warning,
                .@"error" => .@"error",
                .fatal => .@"fatal error",
                else => unreachable,
            };

            try pp.diagnostics.set(str[2..], new_kind);
        },
        .push => try self.state_stack.append(pp.comp.gpa, pp.diagnostics.state),
        .pop => pp.diagnostics.state = self.state_stack.pop() orelse self.original_state,
    }
}

fn preprocessorHandler(pragma: *Pragma, pp: *Preprocessor, start_idx: TokenIndex) Pragma.Error!void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    const directive_tok = pp.tokens.get(start_idx + 1);
    if (directive_tok.id == .nl) return;

    const gcc_pragma = std.meta.stringToEnum(Directive, pp.expandedSlice(directive_tok)) orelse {
        return Pragma.err(pp, start_idx + 1, .unknown_gcc_pragma, .{});
    };

    switch (gcc_pragma) {
        .warning, .@"error" => {
            const text = Pragma.pasteTokens(pp, start_idx + 2) catch |err| switch (err) {
                error.ExpectedStringLiteral => {
                    return Pragma.err(pp, start_idx + 1, .pragma_requires_string_literal, .{@tagName(gcc_pragma)});
                },
                else => |e| return e,
            };

            return Pragma.err(pp, start_idx + 1, if (gcc_pragma == .warning) .pragma_warning_message else .pragma_error_message, .{text});
        },
        .diagnostic => return self.diagnosticHandler(pp, start_idx + 2) catch |err| switch (err) {
            error.UnknownPragma => {
                return Pragma.err(pp, start_idx + 2, .unknown_gcc_pragma_directive, .{});
            },
            else => |e| return e,
        },
        .poison => {
            var i: u32 = 2;
            while (true) : (i += 1) {
                const tok = pp.tokens.get(start_idx + i);
                if (tok.id == .nl) break;

                if (!tok.id.isMacroIdentifier()) {
                    return Pragma.err(pp, start_idx + i, .pragma_poison_identifier, .{});
                }
                const str = pp.expandedSlice(tok);
                if (pp.defines.get(str) != null) {
                    try Pragma.err(pp, start_idx + i, .pragma_poison_macro, .{});
                }
                try pp.poisoned_identifiers.put(pp.comp.gpa, str, {});
            }
            return;
        },
    }
}

fn parserHandler(pragma: *Pragma, p: *Parser, start_idx: TokenIndex) Compilation.Error!void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    const directive_tok = p.pp.tokens.get(start_idx + 1);
    if (directive_tok.id == .nl) return;
    const name = p.pp.expandedSlice(directive_tok);
    if (mem.eql(u8, name, "diagnostic")) {
        return self.diagnosticHandler(p.pp, start_idx + 2) catch |err| switch (err) {
            error.UnknownPragma => {}, // handled during preprocessing
            error.StopPreprocessing => unreachable, // Only used by #pragma once
            else => |e| return e,
        };
    }
}

fn preserveTokens(_: *Pragma, pp: *Preprocessor, start_idx: TokenIndex) bool {
    const next = pp.tokens.get(start_idx + 1);
    if (next.id != .nl) {
        const name = pp.expandedSlice(next);
        if (mem.eql(u8, name, "poison")) {
            return false;
        }
    }
    return true;
}
