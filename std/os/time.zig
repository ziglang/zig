const std = @import("../index.zig");
const builtin = @import("builtin");
const Os = builtin.Os;
const debug = std.debug;

const windows = std.os.windows;
const linux = std.os.linux;
const darwin = std.os.darwin;
const posix = std.os.posix;

pub const epoch = @import("epoch.zig");

/// Sleep for the specified duration
pub fn sleep(seconds: usize, nanoseconds: usize) void {
    switch (builtin.os) {
        Os.linux, Os.macosx, Os.ios => {
            posixSleep(@intCast(u63, seconds), @intCast(u63, nanoseconds));
        },
        Os.windows => {
            const ns_per_ms = ns_per_s / ms_per_s;
            const milliseconds = seconds * ms_per_s + nanoseconds / ns_per_ms;
            windows.Sleep(@intCast(windows.DWORD, milliseconds));
        },
        else => @compileError("Unsupported OS"),
    }
}

const u63 = @IntType(false, 63);
pub fn posixSleep(seconds: u63, nanoseconds: u63) void {
    var req = posix.timespec{
        .tv_sec = seconds,
        .tv_nsec = nanoseconds,
    };
    var rem: posix.timespec = undefined;
    while (true) {
        const ret_val = posix.nanosleep(&req, &rem);
        const err = posix.getErrno(ret_val);
        if (err == 0) return;
        switch (err) {
            posix.EFAULT => unreachable,
            posix.EINVAL => {
                // Sometimes Darwin returns EINVAL for no reason.
                // We treat it as a spurious wakeup.
                return;
            },
            posix.EINTR => {
                req = rem;
                continue;
            },
            else => return,
        }
    }
}

/// Get the posix timestamp, UTC, in seconds
pub fn timestamp() u64 {
    return @divFloor(milliTimestamp(), ms_per_s);
}

/// Get the posix timestamp, UTC, in milliseconds
pub const milliTimestamp = switch (builtin.os) {
    Os.windows => milliTimestampWindows,
    Os.linux => milliTimestampPosix,
    Os.macosx, Os.ios => milliTimestampDarwin,
    else => @compileError("Unsupported OS"),
};

fn milliTimestampWindows() u64 {
    //FileTime has a granularity of 100 nanoseconds
    //  and uses the NTFS/Windows epoch
    var ft: windows.FILETIME = undefined;
    windows.GetSystemTimeAsFileTime(&ft);
    const hns_per_ms = (ns_per_s / 100) / ms_per_s;
    const epoch_adj = epoch.windows * ms_per_s;

    const ft64 = (u64(ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
    return @divFloor(ft64, hns_per_ms) - -epoch_adj;
}

fn milliTimestampDarwin() u64 {
    //Sources suggest MacOS 10.12 has support for
    //  posix clock_gettime.
    var tv: darwin.timeval = undefined;
    var err = darwin.gettimeofday(&tv, null);
    debug.assert(err == 0);
    const sec_ms = @intCast(u64, tv.tv_sec) * ms_per_s;
    const usec_ms = @divFloor(@intCast(u64, tv.tv_usec), us_per_s / ms_per_s);
    return u64(sec_ms) + u64(usec_ms);
}

fn milliTimestampPosix() u64 {
    //From what I can tell there's no reason clock_gettime
    //  should ever fail for us with CLOCK_REALTIME,
    //  seccomp aside.
    var ts: posix.timespec = undefined;
    const err = posix.clock_gettime(posix.CLOCK_REALTIME, &ts);
    debug.assert(err == 0);
    const sec_ms = @intCast(u64, ts.tv_sec) * ms_per_s;
    const nsec_ms = @divFloor(@intCast(u64, ts.tv_nsec), ns_per_s / ms_per_s);
    return sec_ms + nsec_ms;
}

/// Divisions of a second
pub const ns_per_s = 1000000000;
pub const us_per_s = 1000000;
pub const ms_per_s = 1000;
pub const cs_per_s = 100;

/// Common time divisions
pub const s_per_min = 60;
pub const s_per_hour = s_per_min * 60;
pub const s_per_day = s_per_hour * 24;
pub const s_per_week = s_per_day * 7;

/// A monotonic high-performance timer.
/// Timer.start() must be called to initialize the struct, which captures
///   the counter frequency on windows and darwin, records the resolution,
///   and gives the user an oportunity to check for the existnece of
///   monotonic clocks without forcing them to check for error on each read.
/// .resolution is in nanoseconds on all platforms but .start_time's meaning
///   depends on the OS. On Windows and Darwin it is a hardware counter
///   value that requires calculation to convert to a meaninful unit.
pub const Timer = struct {

    //if we used resolution's value when performing the
    //  performance counter calc on windows/darwin, it would
    //  be less precise
    frequency: switch (builtin.os) {
        Os.windows => u64,
        Os.macosx, Os.ios => darwin.mach_timebase_info_data,
        else => void,
    },
    resolution: u64,
    start_time: u64,

    //At some point we may change our minds on RAW, but for now we're
    //  sticking with posix standard MONOTONIC. For more information, see:
    //  https://github.com/ziglang/zig/pull/933
    //
    //const monotonic_clock_id = switch(builtin.os) {
    //    Os.linux => linux.CLOCK_MONOTONIC_RAW,
    //    else => posix.CLOCK_MONOTONIC,
    //};
    const monotonic_clock_id = posix.CLOCK_MONOTONIC;
    /// Initialize the timer structure.
    //This gives us an oportunity to grab the counter frequency in windows.
    //On Windows: QueryPerformanceCounter will succeed on anything >= XP/2000.
    //On Posix: CLOCK_MONOTONIC will only fail if the monotonic counter is not
    //  supported, or if the timespec pointer is out of bounds, which should be
    //  impossible here barring cosmic rays or other such occurances of
    //  incredibly bad luck.
    //On Darwin: This cannot fail, as far as I am able to tell.
    const TimerError = error{
        TimerUnsupported,
        Unexpected,
    };
    pub fn start() TimerError!Timer {
        var self: Timer = undefined;

        switch (builtin.os) {
            Os.windows => {
                var freq: i64 = undefined;
                var err = windows.QueryPerformanceFrequency(&freq);
                if (err == windows.FALSE) return error.TimerUnsupported;
                self.frequency = @intCast(u64, freq);
                self.resolution = @divFloor(ns_per_s, self.frequency);

                var start_time: i64 = undefined;
                err = windows.QueryPerformanceCounter(&start_time);
                debug.assert(err != windows.FALSE);
                self.start_time = @intCast(u64, start_time);
            },
            Os.linux => {
                //On Linux, seccomp can do arbitrary things to our ability to call
                //  syscalls, including return any errno value it wants and
                //  inconsistently throwing errors. Since we can't account for
                //  abuses of seccomp in a reasonable way, we'll assume that if
                //  seccomp is going to block us it will at least do so consistently
                var ts: posix.timespec = undefined;
                var result = posix.clock_getres(monotonic_clock_id, &ts);
                var errno = posix.getErrno(result);
                switch (errno) {
                    0 => {},
                    posix.EINVAL => return error.TimerUnsupported,
                    else => return std.os.unexpectedErrorPosix(errno),
                }
                self.resolution = @intCast(u64, ts.tv_sec) * u64(ns_per_s) + @intCast(u64, ts.tv_nsec);

                result = posix.clock_gettime(monotonic_clock_id, &ts);
                errno = posix.getErrno(result);
                if (errno != 0) return std.os.unexpectedErrorPosix(errno);
                self.start_time = @intCast(u64, ts.tv_sec) * u64(ns_per_s) + @intCast(u64, ts.tv_nsec);
            },
            Os.macosx, Os.ios => {
                darwin.mach_timebase_info(&self.frequency);
                self.resolution = @divFloor(self.frequency.numer, self.frequency.denom);
                self.start_time = darwin.mach_absolute_time();
            },
            else => @compileError("Unsupported OS"),
        }
        return self;
    }

    /// Reads the timer value since start or the last reset in nanoseconds
    pub fn read(self: *Timer) u64 {
        var clock = clockNative() - self.start_time;
        return switch (builtin.os) {
            Os.windows => @divFloor(clock * ns_per_s, self.frequency),
            Os.linux => clock,
            Os.macosx, Os.ios => @divFloor(clock * self.frequency.numer, self.frequency.denom),
            else => @compileError("Unsupported OS"),
        };
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        self.start_time = clockNative();
    }

    /// Returns the current value of the timer in nanoseconds, then resets it
    pub fn lap(self: *Timer) u64 {
        var now = clockNative();
        var lap_time = self.read();
        self.start_time = now;
        return lap_time;
    }

    const clockNative = switch (builtin.os) {
        Os.windows => clockWindows,
        Os.linux => clockLinux,
        Os.macosx, Os.ios => clockDarwin,
        else => @compileError("Unsupported OS"),
    };

    fn clockWindows() u64 {
        var result: i64 = undefined;
        var err = windows.QueryPerformanceCounter(&result);
        debug.assert(err != windows.FALSE);
        return @intCast(u64, result);
    }

    fn clockDarwin() u64 {
        return darwin.mach_absolute_time();
    }

    fn clockLinux() u64 {
        var ts: posix.timespec = undefined;
        var result = posix.clock_gettime(monotonic_clock_id, &ts);
        debug.assert(posix.getErrno(result) == 0);
        return @intCast(u64, ts.tv_sec) * u64(ns_per_s) + @intCast(u64, ts.tv_nsec);
    }
};

test "os.time.sleep" {
    sleep(0, 1);
}

test "os.time.timestamp" {
    const ns_per_ms = (ns_per_s / ms_per_s);
    const margin = 50;

    const time_0 = milliTimestamp();
    sleep(0, ns_per_ms);
    const time_1 = milliTimestamp();
    const interval = time_1 - time_0;
    debug.assert(interval > 0 and interval < margin);
}

test "os.time.Timer" {
    const ns_per_ms = (ns_per_s / ms_per_s);
    const margin = ns_per_ms * 150;

    var timer = try Timer.start();
    sleep(0, 10 * ns_per_ms);
    const time_0 = timer.read();
    debug.assert(time_0 > 0 and time_0 < margin);

    const time_1 = timer.lap();
    debug.assert(time_1 >= time_0);

    timer.reset();
    debug.assert(timer.read() < time_1);
}
