const std = @import("std");
const io = std.io;
const builtin = @import("builtin");
const test_fn_list = builtin.test_functions;
const warn = std.debug.warn;
const Thread = std.Thread;

const A = std.atomic.Int(usize);

const Context = struct {
    fn_index: *A,
    ok_count: *A,
    skip_count: *A,
};

pub fn main() !void {
    if (builtin.single_threaded) {
        var ok_count: usize = 0;
        var skip_count: usize = 0;

        for (test_fn_list) |test_fn, i| {
            warn("{}/{} {}...", i + 1, test_fn_list.len, test_fn.name);

            if (test_fn.func()) |_| {
                ok_count += 1;
                warn("OK\n");
            } else |err| switch (err) {
                error.SkipZigTest => {
                    skip_count += 1;
                    warn("SKIP\n");
                },
                else => return err,
            }
        }
        if (ok_count == test_fn_list.len) {
            warn("All tests passed.\n");
        } else {
            warn("{} passed; {} skipped.\n", ok_count, skip_count);
        }
    } else {
        var ok_count = A.init(0);
        var skip_count = A.init(0);
        var fn_index = A.init(0);
        var context =  Context{
          .ok_count = &ok_count,
          .skip_count = &skip_count,
          .fn_index = &fn_index
        };

        var threads: [256]*Thread = undefined;
        var nproc = std.os.getNProcs();
        if (nproc > 256) nproc = 256;
        var i: usize = 0;
        while (i < nproc) : (i += 1) {
            threads[i] = try Thread.spawn(context, threadRunner);
        }
        i = 0;
        while (i < nproc) : (i += 1) {
            threads[i].wait();
        }
        if (context.ok_count.get() == test_fn_list.len) {
            warn("All tests passed.\n");
        } else {
            warn("{} passed; {} skipped.\n", context.ok_count.get(), context.skip_count.get());
        }
    }
}

fn threadRunner(context: Context) void {
    var cur = context.fn_index.incr();
    while (cur < test_fn_list.len) : (cur = context.fn_index.incr()) {
        if (test_fn_list[cur].func()) |_| {
            _ = context.ok_count.incr();
            warn("{}/{} {}...OK\n", cur + 1, test_fn_list.len, test_fn_list[cur].name);
        } else |err| switch (err) {
            error.SkipZigTest => {
                _ = context.skip_count.incr();
                warn("{}/{} {}...SKIP\n", cur + 1, test_fn_list.len, test_fn_list[cur].name);
            },
            else => {
                warn("{}/{} {}...error: {}\n", cur + 1, test_fn_list.len, test_fn_list[cur].name, @errorName(err));
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                std.os.abort();
            },
        }
    }
}
