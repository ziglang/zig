const std = @import("std");
const builtin = @import("builtin");
const Pool = @This();
const WaitGroup = @import("WaitGroup.zig");
const assert = std.debug.assert;

mutex: std.Thread.Mutex,
cond: std.Thread.Condition,
run_queue: RunQueue,
end_flag: bool,
allocator: std.mem.Allocator,
threads: []std.Thread,
job_server_options: Options.JobServer,
job_server: ?*JobServer,

const RunQueue = std.SinglyLinkedList(Runnable);
const Runnable = struct {
    runFn: RunProto,
};

const RunProto = *const fn (*Runnable) void;

pub const Options = struct {
    /// Not required to be thread-safe; protected by the pool's mutex.
    allocator: std.mem.Allocator,

    /// Max number of threads to be actively working at the same time.
    ///
    /// `null` means to use the logical core count, leaving the main thread to
    /// fill in the last slot.
    ///
    /// `0` is an illegal value.
    n_jobs: ?u32 = null,

    /// For coordinating amongst an entire process tree.
    job_server: Options.JobServer = .abstain,

    pub const JobServer = union(enum) {
        /// The thread pool neither hosts a jobserver nor connects to an existing one.
        abstain,
        /// The thread pool uses the Jobserver2 protocol to coordinate a global
        /// thread pool across the entire process tree, avoiding cache
        /// thrashing.
        connect: std.net.Address,
        /// The thread pool assumes the role of the root process and spawns a
        /// dedicated thread for hosting the Jobserver2 protocol.
        ///
        /// Suggested to use a UNIX domain socket.
        host: std.net.Address,
    };
};

pub fn init(pool: *Pool, options: Options) !void {
    const allocator = options.allocator;

    pool.* = .{
        .mutex = .{},
        .cond = .{},
        .run_queue = .{},
        .end_flag = false,
        .allocator = allocator,
        .threads = &.{},
        .job_server_options = options.job_server,
        .job_server = null,
    };

    if (builtin.single_threaded)
        return;

    const thread_count = options.n_jobs orelse @max(1, std.Thread.getCpuCount() catch 1);
    assert(thread_count > 0);

    // Kill and join any threads we spawned and free memory on error.
    pool.threads = try allocator.alloc(std.Thread, thread_count);
    var spawned: usize = 0;
    errdefer pool.join(spawned);

    for (pool.threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, worker, .{pool});
        spawned += 1;
    }

    switch (options.job_server) {
        .abstain, .connect => {},
        .host => |addr| {
            var server = try addr.listen(.{});
            errdefer server.deinit();

            const pollfds = try allocator.alloc(std.posix.pollfd, thread_count + 1);
            errdefer allocator.free(pollfds);

            const job_server = try allocator.create(JobServer);
            errdefer allocator.destroy(job_server);

            job_server.* = .{
                .server = server,
                .pollfds = pollfds,
                .thread = try std.Thread.spawn(.{}, JobServer.run, .{job_server}),
            };

            pool.job_server = job_server;
        },
    }
}

pub fn deinit(pool: *Pool) void {
    pool.join(pool.threads.len);
    pool.* = undefined;
}

fn join(pool: *Pool, spawned: usize) void {
    if (builtin.single_threaded)
        return;

    {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        // Ensure future worker threads exit the dequeue loop.
        pool.end_flag = true;
    }

    // Wake up any sleeping threads (this can be done outside the mutex) then
    // wait for all the threads we know are spawned to complete.
    pool.cond.broadcast();

    if (pool.job_server) |job_server| {
        // Interrupt the jobserver thread from accepting connections.
        // Since the server fd is also in the poll set, this handles both
        // places where control flow could be blocked.
        std.posix.shutdown(job_server.server.stream.handle, .both) catch {};
        job_server.thread.join();
    }

    for (pool.threads[0..spawned]) |thread|
        thread.join();

    pool.allocator.free(pool.threads);
}

pub const JobServer = struct {
    server: std.net.Server,
    /// Has length n_jobs + 1. The first entry contains the server socket
    /// itself, so that calling shutdown() in the other thread will both cause
    /// the accept to return error.SocketNotListening and cause the poll() to
    /// return.
    pollfds: []std.posix.pollfd,
    thread: std.Thread,

    pub fn run(js: *JobServer) void {
        @memset(js.pollfds, .{
            .fd = -1,
            // Only interested in errors and hangups.
            .events = 0,
            .revents = 0,
        });

        js.pollfds[0].fd = js.server.stream.handle;

        main_loop: while (true) {
            for (js.pollfds[1..]) |*pollfd| {
                const err_event = (pollfd.revents & std.posix.POLL.ERR) != 0;
                const hup_event = (pollfd.revents & std.posix.POLL.HUP) != 0;
                if (err_event or hup_event) {
                    std.posix.close(pollfd.fd);
                    pollfd.fd = -1;
                    pollfd.revents = 0;
                }

                if (pollfd.fd >= 0) continue;

                const connection = js.server.accept() catch |err| switch (err) {
                    error.SocketNotListening => break :main_loop, // Indicates a shutdown request.
                    else => |e| {
                        std.log.debug("job server accept failure: {s}", .{@errorName(e)});
                        continue;
                    },
                };
                _ = std.posix.send(connection.stream.handle, &.{0}, std.posix.MSG.NOSIGNAL) catch {
                    connection.stream.close();
                    continue;
                };
                pollfd.fd = connection.stream.handle;
            }

            _ = std.posix.poll(js.pollfds, -1) catch continue;
        }

        // Closes the active connections as well as the server itself.
        for (js.pollfds) |pollfd| {
            if (pollfd.fd >= 0) {
                std.posix.close(pollfd.fd);
            }
        }

        // Delete the UNIX domain socket.
        switch (js.server.listen_address.any.family) {
            std.posix.AF.UNIX => {
                const path = std.mem.sliceTo(&js.server.listen_address.un.path, 0);
                std.fs.cwd().deleteFile(path) catch {};
            },
            else => {},
        }
    }
};

/// Runs `func` in the thread pool, calling `WaitGroup.start` beforehand, and
/// `WaitGroup.finish` after it returns.
///
/// In the case that queuing the function call fails to allocate memory, or the
/// target is single-threaded, the function is called directly.
pub fn spawnWg(pool: *Pool, wait_group: *WaitGroup, comptime func: anytype, args: anytype) void {
    wait_group.start();

    if (builtin.single_threaded) {
        @call(.auto, func, args);
        wait_group.finish();
        return;
    }

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        pool: *Pool,
        run_node: RunQueue.Node = .{ .data = .{ .runFn = runFn } },
        wait_group: *WaitGroup,

        fn runFn(runnable: *Runnable) void {
            const run_node: *RunQueue.Node = @fieldParentPtr("data", runnable);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, func, closure.arguments);
            closure.wait_group.finish();

            // The thread pool's allocator is protected by the mutex.
            const mutex = &closure.pool.mutex;
            mutex.lock();
            defer mutex.unlock();

            closure.pool.allocator.destroy(closure);
        }
    };

    {
        pool.mutex.lock();

        const closure = pool.allocator.create(Closure) catch {
            pool.mutex.unlock();
            @call(.auto, func, args);
            wait_group.finish();
            return;
        };
        closure.* = .{
            .arguments = args,
            .pool = pool,
            .wait_group = wait_group,
        };

        pool.run_queue.prepend(&closure.run_node);
        pool.mutex.unlock();
    }

    // Notify waiting threads outside the lock to try and keep the critical section small.
    pool.cond.signal();
}

pub fn spawn(pool: *Pool, comptime func: anytype, args: anytype) void {
    if (builtin.single_threaded) {
        @call(.auto, func, args);
        return;
    }

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        pool: *Pool,
        run_node: RunQueue.Node = .{ .data = .{ .runFn = runFn } },

        fn runFn(runnable: *Runnable) void {
            const run_node: *RunQueue.Node = @fieldParentPtr("data", runnable);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, func, closure.arguments);

            // The thread pool's allocator is protected by the mutex.
            const mutex = &closure.pool.mutex;
            mutex.lock();
            defer mutex.unlock();

            closure.pool.allocator.destroy(closure);
        }
    };

    {
        pool.mutex.lock();

        const closure = pool.allocator.create(Closure) catch {
            pool.mutex.unlock();
            @call(.auto, func, args);
            return;
        };
        closure.* = .{
            .arguments = args,
            .pool = pool,
        };

        pool.run_queue.prepend(&closure.run_node);
        pool.mutex.unlock();
    }

    // Notify waiting threads outside the lock to try and keep the critical section small.
    pool.cond.signal();
}

fn worker(pool: *Pool) void {
    var trash_buf: [1]u8 = undefined;
    var connection: ?std.posix.fd_t = null;
    defer if (connection) |fd| std.posix.close(fd);

    pool.mutex.lock();
    defer pool.mutex.unlock();

    while (true) {
        while (pool.run_queue.popFirst()) |run_node| {
            // Temporarily unlock the mutex in order to execute the run_node.
            pool.mutex.unlock();
            defer pool.mutex.lock();

            if (connection == null) switch (pool.job_server_options) {
                .abstain => {},
                .connect, .host => |addr| lock: {
                    const sockfd = std.posix.socket(
                        std.posix.AF.UNIX,
                        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC,
                        0,
                    ) catch |err| {
                        std.log.debug("failed to make socket: {s}", .{@errorName(err)});
                        break :lock;
                    };
                    connection = sockfd;

                    std.posix.connect(sockfd, &addr.any, addr.getOsSockLen()) catch |err| {
                        std.log.debug("failed to connect: {s}", .{@errorName(err)});
                        break :lock;
                    };

                    _ = std.posix.read(sockfd, &trash_buf) catch |err| {
                        std.log.debug("failed to read: {s}", .{@errorName(err)});
                        break :lock;
                    };
                },
            };

            const runFn = run_node.data.runFn;
            runFn(&run_node.data);
        }

        // Stop executing instead of waiting if the thread pool is no longer running.
        if (pool.end_flag)
            break;

        if (connection) |fd| {
            std.posix.close(fd);
            connection = null;
        }

        pool.cond.wait(&pool.mutex);
    }
}

pub fn waitAndWork(pool: *Pool, wait_group: *WaitGroup) void {
    while (!wait_group.isDone()) {
        if (blk: {
            pool.mutex.lock();
            defer pool.mutex.unlock();
            break :blk pool.run_queue.popFirst();
        }) |run_node| {
            run_node.data.runFn(&run_node.data);
            continue;
        }

        wait_group.wait();
        return;
    }
}
