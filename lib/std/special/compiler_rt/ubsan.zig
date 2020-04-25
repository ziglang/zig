// Mini runtime support for Clang's Undefined Behavior sanitizer
const std = @import("std");
const builtin = std.builtin;

// Creates two handlers for a given error, both of them print the specified
// return message but the `abort_` version stops the execution of the program
// XXX: Don't depend on the stdlib
fn makeHandler(comptime error_msg: []const u8) type {
    return struct {
        pub fn recover_handler() callconv(.C) void {
            const PC = @returnAddress() -% 1;
            std.debug.warn("ubsan: " ++ error_msg ++ " @ 0x{x}\n", .{PC});
        }
        pub fn abort_handler() callconv(.C) noreturn {
            const PC = @returnAddress() -% 1;
            std.debug.panic("ubsan: " ++ error_msg ++ " @ 0x{x}\n", .{PC});
        }
    };
}

comptime {
    const HANDLERS = .{
        .{ "type_mismatch", "type-mismatch", .Both },
        .{ "alignment_assumption", "alignment-assumption", .Both },
        .{ "add_overflow", "add-overflow", .Both },
        .{ "sub_overflow", "sub-overflow", .Both },
        .{ "mul_overflow", "mul-overflow", .Both },
        .{ "negate_overflow", "negate-overflow", .Both },
        .{ "divrem_overflow", "divrem-overflow", .Both },
        .{ "shift_out_of_bounds", "shift-out-of-bounds", .Both },
        .{ "out_of_bounds", "out-of-bounds", .Both },
        .{ "builtin_unreachable", "builtin-unreachable", .Recover },
        .{ "missing_return", "missing-return", .Recover },
        .{ "vla_bound_not_positive", "vla-bound-not-positive", .Both },
        .{ "float_cast_overflow", "float-cast-overflow", .Both },
        .{ "load_invalid_value", "load-invalid-value", .Both },
        .{ "invalid_builtin", "invalid-builtin", .Both },
        .{ "function_type_mismatch", "function-type-mismatch", .Both },
        .{ "implicit_conversion", "implicit-conversion", .Both },
        .{ "nonnull_arg", "nonnull-arg", .Both },
        .{ "nonnull_return", "nonnull-return", .Both },
        .{ "nullability_arg", "nullability-arg", .Both },
        .{ "nullability_return", "nullability-return", .Both },
        .{ "pointer_overflow", "pointer-overflow", .Both },
        .{ "cfi_check_fail", "cfi-check-fail", .Both },
    };

    const linkage: builtin.GlobalLinkage = if (std.builtin.is_test) .Internal else .Weak;

    inline for (HANDLERS) |entry| {
        const S = makeHandler(entry[1]);

        // The non-aborting variant is always needed
        {
            const N = "__ubsan_handle_" ++ entry[0] ++ "_minimal";
            const O = std.builtin.ExportOptions{ .name = N, .linkage = linkage };
            @export(S.recover_handler, O);
        }

        if (entry[2] == .Both) {
            const N = "__ubsan_handle_" ++ entry[0] ++ "_minimal_abort";
            const O = std.builtin.ExportOptions{ .name = N, .linkage = linkage };
            @export(S.abort_handler, O);
        }
    }
}
