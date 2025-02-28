//! std.log is a standardized interface for logging which allows for the logging
//! of programs and libraries using this interface to be formatted and filtered
//! by the implementer of the `std.options.logFn` function.
//!
//! Each log message has an associated scope enum, which can be used to give
//! context to the logging. The logging functions in std.log implicitly use a
//! scope of .default.
//!
//! A logging namespace using a custom scope can be created using the
//! std.log.scoped function, passing the scope as an argument; the logging
//! functions in the resulting struct use the provided scope parameter.
//! For example, a library called 'libfoo' might use
//! `const log = std.log.scoped(.libfoo);` to use .libfoo as the scope of its
//! log messages.
//!
//! An example `logFn` might look something like this:
//!
//! ```
//! const std = @import("std");
//!
//! pub const std_options = .{
//!     // Set the log level to info
//!     .log_level = .info,
//!
//!     // Define logFn to override the std implementation
//!     .logFn = myLogFn,
//! };
//!
//! pub fn myLogFn(
//!     comptime level: std.log.Level,
//!     comptime scope: @Type(.enum_literal),
//!     comptime format: []const u8,
//!     args: anytype,
//! ) void {
//!     // Ignore all non-error logging from sources other than
//!     // .my_project, .nice_library and the default
//!     const scope_prefix = "(" ++ switch (scope) {
//!         .my_project, .nice_library, std.log.default_log_scope => @tagName(scope),
//!         else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
//!             @tagName(scope)
//!         else
//!             return,
//!     } ++ "): ";
//!
//!     const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;
//!
//!     // Print the message to stderr, silently ignoring any errors
//!     std.debug.lockStdErr();
//!     defer std.debug.unlockStdErr();
//!     const stderr = std.io.getStdErr().writer();
//!     nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
//! }
//!
//! pub fn main() void {
//!     // Using the default scope:
//!     std.log.debug("A borderline useless debug log message", .{}); // Won't be printed as log_level is .info
//!     std.log.info("Flux capacitor is starting to overheat", .{});
//!
//!     // Using scoped logging:
//!     const my_project_log = std.log.scoped(.my_project);
//!     const nice_library_log = std.log.scoped(.nice_library);
//!     const verbose_lib_log = std.log.scoped(.verbose_lib);
//!
//!     my_project_log.debug("Starting up", .{}); // Won't be printed as log_level is .info
//!     nice_library_log.warn("Something went very wrong, sorry", .{});
//!     verbose_lib_log.warn("Added 1 + 1: {}", .{1 + 1}); // Won't be printed as it gets filtered out by our log function
//! }
//! ```
//! Which produces the following output:
//! ```
//! [info] (default): Flux capacitor is starting to overheat
//! [warning] (nice_library): Something went very wrong, sorry
//! ```

const std = @import("std.zig");
const builtin = @import("builtin");

pub const Level = enum {
    /// Error: something has gone wrong. This might be recoverable or might
    /// be followed by the program exiting.
    err,
    /// Warning: it is uncertain if something has gone wrong or not, but the
    /// circumstances would be worth investigating.
    warn,
    /// Info: general messages about the state of the program.
    info,
    /// Debug: messages only useful for debugging.
    debug,

    /// Returns a string literal of the given level in full text form.
    pub fn asText(comptime self: Level) []const u8 {
        return switch (self) {
            .err => "error",
            .warn => "warning",
            .info => "info",
            .debug => "debug",
        };
    }
};

/// The default log level is based on build mode.
pub const default_level: Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe => .info,
    .ReleaseFast, .ReleaseSmall => .err,
};

const level = std.options.log_level;

pub const ScopeLevel = struct {
    scope: @Type(.enum_literal),
    level: Level,
};

const scope_levels = std.options.log_scope_levels;

fn log(
    comptime message_level: Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (comptime !logEnabled(message_level, scope)) return;

    std.options.logFn(message_level, scope, format, args);
}

/// Determine if a specific log message level and scope combination are enabled for logging.
pub fn logEnabled(comptime message_level: Level, comptime scope: @Type(.enum_literal)) bool {
    inline for (scope_levels) |scope_level| {
        if (scope_level.scope == scope) return @intFromEnum(message_level) <= @intFromEnum(scope_level.level);
    }
    return @intFromEnum(message_level) <= @intFromEnum(level);
}

/// Determine if a specific log message level using the default log scope is enabled for logging.
pub fn defaultLogEnabled(comptime message_level: Level) bool {
    return comptime logEnabled(message_level, default_log_scope);
}

/// The default implementation for the log function, custom log functions may
/// forward log messages to this function.
pub fn defaultLog(
    comptime message_level: Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        writer.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
        bw.flush() catch return;
    }
}

/// Returns a scoped logging namespace that logs all messages using the scope
/// provided here.
pub fn scoped(comptime scope: @Type(.enum_literal)) type {
    return struct {
        /// Log an error message. This log level is intended to be used
        /// when something has gone wrong. This might be recoverable or might
        /// be followed by the program exiting.
        pub fn err(
            comptime format: []const u8,
            args: anytype,
        ) void {
            @branchHint(.cold);
            log(.err, scope, format, args);
        }

        /// Log a warning message. This log level is intended to be used if
        /// it is uncertain whether something has gone wrong or not, but the
        /// circumstances would be worth investigating.
        pub fn warn(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.warn, scope, format, args);
        }

        /// Log an info message. This log level is intended to be used for
        /// general messages about the state of the program.
        pub fn info(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.info, scope, format, args);
        }

        /// Log a debug message. This log level is intended to be used for
        /// messages which are only useful for debugging.
        pub fn debug(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.debug, scope, format, args);
        }
    };
}

pub const default_log_scope = .default;

/// The default scoped logging namespace.
pub const default = scoped(default_log_scope);

/// Log an error message using the default scope. This log level is intended to
/// be used when something has gone wrong. This might be recoverable or might
/// be followed by the program exiting.
pub const err = default.err;

/// Log a warning message using the default scope. This log level is intended
/// to be used if it is uncertain whether something has gone wrong or not, but
/// the circumstances would be worth investigating.
pub const warn = default.warn;

/// Log an info message using the default scope. This log level is intended to
/// be used for general messages about the state of the program.
pub const info = default.info;

/// Log a debug message using the default scope. This log level is intended to
/// be used for messages which are only useful for debugging.
pub const debug = default.debug;
