const std = @import("../std.zig");
const testing = std.testing;

/// Performs multiple async functions in parallel, without heap allocation.
/// Async function frames are managed externally to this abstraction, and
/// passed in via the `add` function. Once all the jobs are added, call `wait`.
/// This API is *not* thread-safe. The object must be accessed from one thread at
/// a time, however, it need not be the same thread.
pub fn Batch(
    /// The return value for each job.
    /// If a job slot was re-used due to maxed out concurrency, then its result
    /// value will be overwritten. The values can be accessed with the `results` field.
    comptime Result: type,
    /// How many jobs to run in parallel.
    comptime max_jobs: comptime_int,
    /// Controls whether the `add` and `wait` functions will be async functions.
    comptime async_behavior: enum {
        /// Observe the value of `std.io.is_async` to decide whether `add`
        /// and `wait` will be async functions. Asserts that the jobs do not suspend when
        /// `std.options.io_mode == .blocking`. This is a generally safe assumption, and the
        /// usual recommended option for this parameter.
        auto_async,

        /// Always uses the `nosuspend` keyword when using `await` on the jobs,
        /// making `add` and `wait` non-async functions. Asserts that the jobs do not suspend.
        never_async,

        /// `add` and `wait` use regular `await` keyword, making them async functions.
        always_async,
    },
) type {
    return struct {
        jobs: [max_jobs]Job,
        next_job_index: usize,
        collected_result: CollectedResult,

        const Job = struct {
            frame: ?anyframe->Result,
            result: Result,
        };

        const Self = @This();

        const CollectedResult = switch (@typeInfo(Result)) {
            .ErrorUnion => Result,
            else => void,
        };

        const async_ok = switch (async_behavior) {
            .auto_async => std.io.is_async,
            .never_async => false,
            .always_async => true,
        };

        pub fn init() Self {
            return Self{
                .jobs = [1]Job{
                    .{
                        .frame = null,
                        .result = undefined,
                    },
                } ** max_jobs,
                .next_job_index = 0,
                .collected_result = {},
            };
        }

        /// Add a frame to the Batch. If all jobs are in-flight, then this function
        /// waits until one completes.
        /// This function is *not* thread-safe. It must be called from one thread at
        /// a time, however, it need not be the same thread.
        /// TODO: "select" language feature to use the next available slot, rather than
        /// awaiting the next index.
        pub fn add(self: *Self, frame: anyframe->Result) void {
            const job = &self.jobs[self.next_job_index];
            self.next_job_index = (self.next_job_index + 1) % max_jobs;
            if (job.frame) |existing| {
                job.result = if (async_ok) await existing else nosuspend await existing;
                if (CollectedResult != void) {
                    job.result catch |err| {
                        self.collected_result = err;
                    };
                }
            }
            job.frame = frame;
        }

        /// Wait for all the jobs to complete.
        /// Safe to call any number of times.
        /// If `Result` is an error union, this function returns the last error that occurred, if any.
        /// Unlike the `results` field, the return value of `wait` will report any error that occurred;
        /// hitting max parallelism will not compromise the result.
        /// This function is *not* thread-safe. It must be called from one thread at
        /// a time, however, it need not be the same thread.
        pub fn wait(self: *Self) CollectedResult {
            for (self.jobs) |*job|
                if (job.frame) |f| {
                    job.result = if (async_ok) await f else nosuspend await f;
                    if (CollectedResult != void) {
                        job.result catch |err| {
                            self.collected_result = err;
                        };
                    }
                    job.frame = null;
                };
            return self.collected_result;
        }
    };
}

test "std.event.Batch" {
    if (true) return error.SkipZigTest;
    var count: usize = 0;
    var batch = Batch(void, 2, .auto_async).init();
    batch.add(&async sleepALittle(&count));
    batch.add(&async increaseByTen(&count));
    batch.wait();
    try testing.expect(count == 11);

    var another = Batch(anyerror!void, 2, .auto_async).init();
    another.add(&async somethingElse());
    another.add(&async doSomethingThatFails());
    try testing.expectError(error.ItBroke, another.wait());
}

fn sleepALittle(count: *usize) void {
    std.time.sleep(1 * std.time.ns_per_ms);
    _ = @atomicRmw(usize, count, .Add, 1, .SeqCst);
}

fn increaseByTen(count: *usize) void {
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        _ = @atomicRmw(usize, count, .Add, 1, .SeqCst);
    }
}

fn doSomethingThatFails() anyerror!void {}
fn somethingElse() anyerror!void {
    return error.ItBroke;
}
