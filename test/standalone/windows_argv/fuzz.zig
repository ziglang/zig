const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) return error.MissingArgs;

    const verify_path_wtf8 = args[1];
    const verify_path_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, verify_path_wtf8);
    defer allocator.free(verify_path_w);

    const iterations: u64 = iterations: {
        if (args.len < 3) break :iterations 0;
        break :iterations try std.fmt.parseUnsigned(u64, args[2], 10);
    };

    var rand_seed = false;
    const seed: u64 = seed: {
        if (args.len < 4) {
            rand_seed = true;
            var buf: [8]u8 = undefined;
            try std.posix.getrandom(&buf);
            break :seed std.mem.readInt(u64, &buf, builtin.cpu.arch.endian());
        }
        break :seed try std.fmt.parseUnsigned(u64, args[3], 10);
    };
    var random = std.Random.DefaultPrng.init(seed);
    const rand = random.random();

    // If the seed was not given via the CLI, then output the
    // randomly chosen seed so that this run can be reproduced
    if (rand_seed) {
        std.debug.print("rand seed: {}\n", .{seed});
    }

    var cmd_line_w_buf = std.ArrayList(u16).init(allocator);
    defer cmd_line_w_buf.deinit();

    var i: u64 = 0;
    var errors: u64 = 0;
    while (iterations == 0 or i < iterations) {
        const cmd_line_w = try randomCommandLineW(allocator, rand);
        defer allocator.free(cmd_line_w);

        // avoid known difference for 0-length command lines
        if (cmd_line_w.len == 0 or cmd_line_w[0] == '\x00') continue;

        const exit_code = try spawnVerify(verify_path_w, cmd_line_w);
        if (exit_code != 0) {
            std.debug.print(">>> found discrepancy <<<\n", .{});
            const cmd_line_wtf8 = try std.unicode.wtf16LeToWtf8Alloc(allocator, cmd_line_w);
            defer allocator.free(cmd_line_wtf8);
            std.debug.print("\"{}\"\n\n", .{std.zig.fmtEscapes(cmd_line_wtf8)});

            errors += 1;
        }

        i += 1;
    }
    if (errors > 0) {
        // we never get here if iterations is 0 so we don't have to worry about that case
        std.debug.print("found {} discrepancies in {} iterations\n", .{ errors, iterations });
        return error.FoundDiscrepancies;
    }
}

fn randomCommandLineW(allocator: Allocator, rand: std.Random) ![:0]const u16 {
    const Choice = enum {
        backslash,
        quote,
        space,
        tab,
        control,
        printable,
        non_ascii,
    };

    const choices = rand.uintAtMostBiased(u16, 256);
    var buf = try std.ArrayList(u16).initCapacity(allocator, choices);
    errdefer buf.deinit();

    for (0..choices) |_| {
        const choice = rand.enumValue(Choice);
        const code_unit = switch (choice) {
            .backslash => '\\',
            .quote => '"',
            .space => ' ',
            .tab => '\t',
            .control => switch (rand.uintAtMostBiased(u8, 0x21)) {
                0x21 => '\x7F',
                else => |b| b,
            },
            .printable => '!' + rand.uintAtMostBiased(u8, '~' - '!'),
            .non_ascii => rand.intRangeAtMostBiased(u16, 0x80, 0xFFFF),
        };
        try buf.append(std.mem.nativeToLittle(u16, code_unit));
    }

    return buf.toOwnedSliceSentinel(0);
}

/// Returns the exit code of the verify process
fn spawnVerify(verify_path: [:0]const u16, cmd_line: [:0]const u16) !windows.DWORD {
    const child_proc = spawn: {
        var startup_info: windows.STARTUPINFOW = .{
            .cb = @sizeOf(windows.STARTUPINFOW),
            .lpReserved = null,
            .lpDesktop = null,
            .lpTitle = null,
            .dwX = 0,
            .dwY = 0,
            .dwXSize = 0,
            .dwYSize = 0,
            .dwXCountChars = 0,
            .dwYCountChars = 0,
            .dwFillAttribute = 0,
            .dwFlags = windows.STARTF_USESTDHANDLES,
            .wShowWindow = 0,
            .cbReserved2 = 0,
            .lpReserved2 = null,
            .hStdInput = null,
            .hStdOutput = null,
            .hStdError = windows.GetStdHandle(windows.STD_ERROR_HANDLE) catch null,
        };
        var proc_info: windows.PROCESS_INFORMATION = undefined;

        try windows.CreateProcessW(
            @constCast(verify_path.ptr),
            @constCast(cmd_line.ptr),
            null,
            null,
            windows.TRUE,
            0,
            null,
            null,
            &startup_info,
            &proc_info,
        );
        windows.CloseHandle(proc_info.hThread);

        break :spawn proc_info.hProcess;
    };
    defer windows.CloseHandle(child_proc);
    try windows.WaitForSingleObjectEx(child_proc, windows.INFINITE, false);

    var exit_code: windows.DWORD = undefined;
    if (windows.kernel32.GetExitCodeProcess(child_proc, &exit_code) == 0) {
        return error.UnableToGetExitCode;
    }
    return exit_code;
}
