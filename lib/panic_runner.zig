//! Panic test runner
//! assume: process spawning + IPC capabilities to keep things simple and test behavior = code behavior
//! Control starts itself as Runner as childprocess as
//! [test_runner_exe_path, test_nr, msg_pipe handle].
//! Runner writes
//! [passed, skipped, failed, panic_type]
//! into msg_pipe to Control.

// TODO async signal safety => reads can fail or be interrupted
const std = @import("std");
const io = std.io;
const builtin = @import("builtin");
const os = std.os;
const ChildProcess = std.ChildProcess;
const child_process = std.child_process;
const pipe_rd = child_process.pipe_rd;
const pipe_wr = child_process.pipe_wr;

const Global = struct {
    const max_panic_msg_size = 4096;
    // used by runner
    msg_pipe: os.fd_t,
    buf_panic_msg: [Global.max_panic_msg_size]u8,
    buf_panic_msg_fill: usize,

    // used by controller and runner
    is_runner_panic: bool,
    passed: usize,
    skipped: usize,
    failed: usize,
};
var global = Global{
    .msg_pipe = undefined,
    .is_runner_panic = false,
    .passed = 0,
    .skipped = 0,
    .failed = 0,
    .buf_panic_msg = [_]u8{0} ** Global.max_panic_msg_size,
    .buf_panic_msg_fill = 0,
};

const PanicT = enum(u8) {
    nopanic,
    expected_panic,
    unexpected_panic,
};

/// This function is only working correctly inside test blocks. It writes an
/// expected panic message to a global buffer only available in panic_testrunner.zig,
/// which is compared by the Runner in the panic handler once it is called.
pub fn writeExpectedPanicMsg(panic_msg: []const u8) void {
    // do bounds checks for first and last element manually, but omit the others.
    std.debug.assert(panic_msg.len < global.buf_panic_msg.len);
    std.debug.assert(panic_msg.len > 0);
    global.buf_panic_msg[0] = panic_msg[0];
    @memcpy(@ptrCast([*]u8, &global.buf_panic_msg[0]), panic_msg.ptr, panic_msg.len);
    global.buf_panic_msg_fill = panic_msg.len;
}

/// Overwritten panic routine
/// This function handles signals installed for the platform in start.zig and
/// direct calls to `@panic`, but it can be modified by installing and removing
/// signal handler on the platform.
/// TODO: make this signal safe
pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    _ = stack_trace;
    if (global.is_runner_panic) {
        var msg_pipe_file = std.fs.File{
            .handle = global.msg_pipe,
        };

        const msg_wr = msg_pipe_file.writer();
        // [passed, skipped, failed, nopanic|panic|expected_panic]
        msg_wr.writeIntNative(usize, global.passed) catch unreachable;
        msg_wr.writeIntNative(usize, global.skipped) catch unreachable;
        msg_wr.writeIntNative(usize, global.failed) catch unreachable;

        if (std.mem.eql(u8, message, global.buf_panic_msg[0..global.buf_panic_msg_fill])) {
            std.debug.print("execpted panic\n", .{});
            msg_wr.writeByte(@intCast(u8, @enumToInt(PanicT.expected_panic))) catch unreachable;
            msg_pipe_file.close(); // workaround process.exit
            std.process.exit(0);
        } else {
            std.debug.print("unexecpted panic\n", .{});
            msg_wr.writeByte(@intCast(u8, @enumToInt(PanicT.unexpected_panic))) catch unreachable;
            msg_pipe_file.close(); // workaround process.exit
            std.debug.panic("{s}", .{message});
        }
    }
    std.debug.panic("{s}", .{message});
    switch (builtin.os.tag) {
        .freestanding, .other, .amdhsa, .amdpal => while (true) {},
        else => std.os.abort(),
    }
}

const State = enum {
    Control,
    Worker,
};

const Cli = struct {
    state: State,
    test_nr: u64,
    test_runner_exe_path: []u8,
};

// path_to_testbinary, test number(u32), string(*anyopaque = 64bit)
var buffer: [std.fs.MAX_PATH_BYTES + 30]u8 = undefined;
var FixedBufferAlloc = std.heap.FixedBufferAllocator.init(buffer[0..]);
var fixed_alloc = FixedBufferAlloc.allocator();

fn processArgs(static_alloc: std.mem.Allocator) Cli {
    const args = std.process.argsAlloc(static_alloc) catch {
        @panic("Too many bytes passed over the CLI to Test Runner/Control.");
    };
    var cli = Cli{
        .state = undefined,
        .test_nr = undefined,
        .test_runner_exe_path = undefined,
    };
    if (args.len == 3) {
        // disable inheritance asap
        global.msg_pipe = std.os.stringToHandle(args[2]) catch unreachable;
        os.disableInheritance(global.msg_pipe) catch unreachable;
        global.is_runner_panic = true;

        cli.state = .Worker;
        cli.test_nr = std.fmt.parseUnsigned(u64, args[1], 10) catch unreachable;
        std.debug.print("test worker (exe_path test_nr handle: ", .{});
        std.debug.print("{s} {s} {s}\n", .{ args[0], args[1], args[2] });
    } else {
        cli.state = .Control;
        cli.test_nr = 0;
        std.debug.print("test control: {s}\n", .{args[0]});
    }
    cli.test_runner_exe_path = args[0];
    return cli;
}

// args: path_to_testbinary, [test_nr pipe_worker_to_ctrl]
pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const gpa = general_purpose_allocator.allocator();

    var cli = processArgs(fixed_alloc);
    switch (cli.state) {
        .Control => {
            // pipe Worker => Controller
            var buf_handle: [os.handleCharSize]u8 = comptime [_]u8{0} ** os.handleCharSize;
            var buf_tests_done: [10]u8 = [_]u8{0} ** 10;
            var tests_done: usize = 0;
            const tests_todo = builtin.test_functions.len;

            while (tests_done < tests_todo) {
                var pipe = try child_process.portablePipe();
                defer os.close(pipe[pipe_rd]);
                const handle_s = os.handleToString(pipe[pipe_wr], &buf_handle) catch unreachable;
                const tests_done_s = std.fmt.bufPrint(&buf_tests_done, "{d}", .{tests_done}) catch unreachable;
                var child_proc = ChildProcess.init(
                    &.{ cli.test_runner_exe_path, tests_done_s, handle_s },
                    gpa,
                );

                {
                    // close pipe end asap before it leaks anywhere
                    defer os.close(pipe[pipe_wr]);
                    try os.enableInheritance(pipe[pipe_wr]);

                    try child_proc.spawn();
                }
                const stderr = std.io.getStdErr();
                const ret_term = try child_proc.wait();
                std.debug.print("ret_term: {any}\n", .{ret_term.Exited});
                if (ret_term.Exited != @enumToInt(ChildProcess.Term.Exited)) {
                    try stderr.writeAll("Worker did stop due to other reason than exit");
                    std.os.exit(1);
                }
                if (ret_term.Exited != 0) {
                    try stderr.writeAll("Worker did stop with exit code: ");
                    var exit_buf: [10]u8 = undefined;
                    const exit_buf_s = std.fmt.bufPrint(&exit_buf, "{d}", .{ret_term.Exited}) catch unreachable;
                    try stderr.writeAll(exit_buf_s);
                    try stderr.writeAll("\n");
                    std.os.exit(1);
                }

                var file = std.fs.File{
                    .handle = pipe[pipe_rd],
                };
                const file_rd = file.reader();
                const ret_passed = try file_rd.readIntNative(usize);
                std.debug.print("ctrl passed: {d}\n", .{ret_passed});
                const ret_skipped = try file_rd.readIntNative(usize);
                std.debug.print("ctrl skipped: {d}\n", .{ret_skipped});
                const ret_failed = try file_rd.readIntNative(usize);
                std.debug.print("ctrl fail: {d}\n", .{ret_failed});
                global.passed += ret_passed;
                global.skipped += ret_skipped;
                global.failed += ret_failed;
                tests_done += ret_passed + ret_skipped + ret_failed;

                const ret_panic_u = try file_rd.readByte();
                const panic_t = @intToEnum(PanicT, ret_panic_u);
                switch (panic_t) {
                    .nopanic => {
                        // tests must be finished or this is in an error
                        break;
                    },
                    .expected_panic => {
                        // sum numbers + restart on new test fn
                        global.passed += 1;
                        tests_done += 1;
                        continue;
                    },
                    .unexpected_panic => {
                        // clean exit with writing total count status
                        // error message has been already written by child process
                        stderr.writeAll("FAIL: unexpected panic: ") catch {};
                        writeInt(stderr, global.passed) catch {};
                        stderr.writeAll(" passed; ") catch {};
                        writeInt(stderr, global.skipped) catch {};
                        stderr.writeAll(" skipped; ") catch {};
                        writeInt(stderr, global.failed) catch {};
                        stderr.writeAll(" failed.\n") catch {};
                        std.process.exit(1);
                    },
                }
            }
            const stderr = std.io.getStdErr();
            stderr.writeAll("SUCCESS: ") catch {};
            writeInt(stderr, global.passed) catch {};
            stderr.writeAll(" passed; ") catch {};
            writeInt(stderr, global.skipped) catch {};
            stderr.writeAll(" skipped; ") catch {};
            writeInt(stderr, global.failed) catch {};
            stderr.writeAll(" failed.\n") catch {};
            std.process.exit(0);
        },
        .Worker => {
            // state is global, so that panic function has access to it.
            global.passed = 0;
            global.skipped = 0;
            global.failed = 0;

            for (builtin.test_functions[cli.test_nr..]) |test_fn| {
                test_fn.func() catch |err| {
                    if (err != error.SkipZigTest) {
                        global.failed += 1;
                    } else {
                        global.skipped += 1;
                    }
                };
                global.passed += 1;
            }

            var msg_pipe_file = std.fs.File{
                .handle = global.msg_pipe,
            };
            defer msg_pipe_file.close();
            const msg_wr = msg_pipe_file.writer();
            // [passed, skipped, failed, panic?, message_len, optional_message]
            try msg_wr.writeIntNative(usize, global.passed);
            try msg_wr.writeIntNative(usize, global.skipped);
            try msg_wr.writeIntNative(usize, global.failed);
            try msg_wr.writeByte(@intCast(u8, @boolToInt(false)));
            try msg_wr.writeIntNative(usize, 0);
        },
    }
}

fn writeInt(stderr: std.fs.File, int: usize) anyerror!void {
    const base = 10;
    var buf: [100]u8 = undefined;
    var a: usize = int;
    var index: usize = buf.len;
    while (true) {
        const digit = a % base;
        index -= 1;
        buf[index] = std.fmt.digitToChar(@intCast(u8, digit), .lower);
        a /= base;
        if (a == 0) break;
    }
    const slice = buf[index..];
    try stderr.writeAll(slice);
}
