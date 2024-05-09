const std = @import("std");
const mem = std.mem;
const Compilation = @import("../Compilation.zig");
const Pragma = @import("../Pragma.zig");
const Diagnostics = @import("../Diagnostics.zig");
const Preprocessor = @import("../Preprocessor.zig");
const Parser = @import("../Parser.zig");
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
original_options: Diagnostics.Options = .{},
options_stack: std.ArrayListUnmanaged(Diagnostics.Options) = .{},

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
    self.original_options = comp.diagnostics.options;
}

fn beforeParse(pragma: *Pragma, comp: *Compilation) void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    comp.diagnostics.options = self.original_options;
    self.options_stack.items.len = 0;
}

fn afterParse(pragma: *Pragma, comp: *Compilation) void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    comp.diagnostics.options = self.original_options;
    self.options_stack.items.len = 0;
}

pub fn init(allocator: mem.Allocator) !*Pragma {
    var gcc = try allocator.create(GCC);
    gcc.* = .{};
    return &gcc.pragma;
}

fn deinit(pragma: *Pragma, comp: *Compilation) void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    self.options_stack.deinit(comp.gpa);
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
                    return pp.comp.addDiagnostic(.{
                        .tag = .pragma_requires_string_literal,
                        .loc = diagnostic_tok.loc,
                        .extra = .{ .str = "GCC diagnostic" },
                    }, pp.expansionSlice(start_idx));
                },
                else => |e| return e,
            };
            if (!mem.startsWith(u8, str, "-W")) {
                const next = pp.tokens.get(start_idx + 1);
                return pp.comp.addDiagnostic(.{
                    .tag = .malformed_warning_check,
                    .loc = next.loc,
                    .extra = .{ .str = "GCC diagnostic" },
                }, pp.expansionSlice(start_idx + 1));
            }
            const new_kind: Diagnostics.Kind = switch (diagnostic) {
                .ignored => .off,
                .warning => .warning,
                .@"error" => .@"error",
                .fatal => .@"fatal error",
                else => unreachable,
            };

            try pp.comp.diagnostics.set(str[2..], new_kind);
        },
        .push => try self.options_stack.append(pp.comp.gpa, pp.comp.diagnostics.options),
        .pop => pp.comp.diagnostics.options = self.options_stack.popOrNull() orelse self.original_options,
    }
}

fn preprocessorHandler(pragma: *Pragma, pp: *Preprocessor, start_idx: TokenIndex) Pragma.Error!void {
    var self: *GCC = @fieldParentPtr("pragma", pragma);
    const directive_tok = pp.tokens.get(start_idx + 1);
    if (directive_tok.id == .nl) return;

    const gcc_pragma = std.meta.stringToEnum(Directive, pp.expandedSlice(directive_tok)) orelse
        return pp.comp.addDiagnostic(.{
        .tag = .unknown_gcc_pragma,
        .loc = directive_tok.loc,
    }, pp.expansionSlice(start_idx + 1));

    switch (gcc_pragma) {
        .warning, .@"error" => {
            const text = Pragma.pasteTokens(pp, start_idx + 2) catch |err| switch (err) {
                error.ExpectedStringLiteral => {
                    return pp.comp.addDiagnostic(.{
                        .tag = .pragma_requires_string_literal,
                        .loc = directive_tok.loc,
                        .extra = .{ .str = @tagName(gcc_pragma) },
                    }, pp.expansionSlice(start_idx + 1));
                },
                else => |e| return e,
            };
            const extra = Diagnostics.Message.Extra{ .str = try pp.comp.diagnostics.arena.allocator().dupe(u8, text) };
            const diagnostic_tag: Diagnostics.Tag = if (gcc_pragma == .warning) .pragma_warning_message else .pragma_error_message;
            return pp.comp.addDiagnostic(
                .{ .tag = diagnostic_tag, .loc = directive_tok.loc, .extra = extra },
                pp.expansionSlice(start_idx + 1),
            );
        },
        .diagnostic => return self.diagnosticHandler(pp, start_idx + 2) catch |err| switch (err) {
            error.UnknownPragma => {
                const tok = pp.tokens.get(start_idx + 2);
                return pp.comp.addDiagnostic(.{
                    .tag = .unknown_gcc_pragma_directive,
                    .loc = tok.loc,
                }, pp.expansionSlice(start_idx + 2));
            },
            else => |e| return e,
        },
        .poison => {
            var i: u32 = 2;
            while (true) : (i += 1) {
                const tok = pp.tokens.get(start_idx + i);
                if (tok.id == .nl) break;

                if (!tok.id.isMacroIdentifier()) {
                    return pp.comp.addDiagnostic(.{
                        .tag = .pragma_poison_identifier,
                        .loc = tok.loc,
                    }, pp.expansionSlice(start_idx + i));
                }
                const str = pp.expandedSlice(tok);
                if (pp.defines.get(str) != null) {
                    try pp.comp.addDiagnostic(.{
                        .tag = .pragma_poison_macro,
                        .loc = tok.loc,
                    }, pp.expansionSlice(start_idx + i));
                }
                try pp.poisoned_identifiers.put(str, {});
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
