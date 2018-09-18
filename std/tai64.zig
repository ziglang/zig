/// Support for TAI64 https://cr.yp.to/libtai/tai64.html

const std = @import("index.zig");
const builtin = @import("builtin");
const mem = std.mem;
const time = std.os.time;

const TAI64N_EPOCH: u64 = 0x400000000000000a;

/// TAI64N
/// Use public methods to interact with internal 12 byte TAI64N format
pub const TAI64N = struct {
    // A TAI64 label is an integer between 0 and 2^64 referring to a
    // particular second of real time. Integer s refers to the TAI second
    // beginning exactly 2^62 - s seconds before the beginning of 1970 TAI,
    // if s is between 0 inclusive and 2^62 exclusive; or the TAI second
    // beginning exactly s - 2^62 seconds after the beginning of 1970 TAI, if
    // s is between 2^62 inclusive and 2^63 exclusive. Integers 2^63 and
    // larger are reserved for future extensions. Under many cosmological
    // theories, the integers under 2^63 are adequate to cover the entire
    // expected lifetime of the universe; in this case no extensions will be
    // necessary. A TAI64 label is normally stored or communicated in
    // external TAI64 format, consisting of eight 8-bit bytes in big-endian
    // format. This means that bytes b0 b1 b2 b3 b4 b5 b6 b7 represent the
    // label b0 * 2^56 + b1 * 2^48 + b2 * 2^40 + b3 * 2^32 + b4 * 2^24 + b5 *
    // 2^16 + b6 * 2^8 + b7.

    // A TAI64N label refers to a particular nanosecond of real time.
    // It has two parts: 1) a TAI64 label and 2) an integer, between 0
    // and 999999999 inclusive, counting nanoseconds from the
    // beginning of the second represented by the TAI64 label.
    tai64n: [12]u8,

    pub fn from_unixtime(tnow: u64) TAI64N {
        var out: TAI64N = undefined;
        var tnow_secs: u64 = tnow / 1000;
        var tnow_nsecs: u32 = @intCast(u32, (tnow % 1000) * 1000);

        mem.writeInt(out.tai64n[0..8], u64(TAI64N_EPOCH + tnow_secs), builtin.Endian.Big);
        mem.writeInt(out.tai64n[8..12], @intCast(u32, tnow_nsecs), builtin.Endian.Big);

        return out;
    }

    pub fn now() TAI64N {
        return TAI64N.from_unixtime( time.milliTimestamp() );
    }

    /// this function assumes that its internal data will not be touched from outside of its own methods
    pub fn to_unixtime(self: *TAI64N) u64 {
        var out: u64 = 0;
        // adjust for epoch and convert from seconds to milliseconds
        out = (mem.readIntBE(u64, self.tai64n[0..8]) - TAI64N_EPOCH) * 1000;
        // convert nanoseconds to milliseconds;
        out += (mem.readIntBE(u32, self.tai64n[8..]) / 1000);
        return out;
    }

    pub fn to_bytes(self: *TAI64N) []const u8 {
        return self.tai64n;
    }

    pub fn from_bytes(bytes: []const u8) !TAI64N {
        var tai64n: TAI64N = undefined;
        // make sure that data is sane.
        var seconds = mem.readIntBE(u64, bytes[0..8]);
        if (seconds < TAI64N_EPOCH)
            return error.InvalidFormat;

        mem.copy(u8, tai64n.tai64n[0..], bytes);

        return tai64n;
    }

    /// Test equality between two TAI64N
    pub fn eql(self: *TAI64N, rhs: *const TAI64N) bool {
        return mem.eql(u8, self.tai64n, rhs.tai64n);
    }

    /// Compare two TAI64N
    pub fn compare(self: *TAI64N, rhs: *const TAI64N) mem.Compare {
        return mem.compare(u8, self.tai64n, rhs.tai64n);
    }
};

test "TAI64N" {
  var t = TAI64N.now();
  var t2 = try TAI64N.from_bytes( t.to_bytes() );
  std.debug.assert( t.eql( t2 ) );

  var t_unixtime = t.to_unixtime();
  var t3 = TAI64N.from_unixtime( t_unixtime );
  std.debug.assert( t.eql( t3 ) );
  std.debug.assert( t2.eql( t3 ) );

  std.debug.assert( t2.compare( t3 ) == mem.Compare.Equal );
}
