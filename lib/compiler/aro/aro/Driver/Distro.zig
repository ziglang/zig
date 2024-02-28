//! Tools for figuring out what Linux distro we're running on

const std = @import("std");
const mem = std.mem;
const Filesystem = @import("Filesystem.zig").Filesystem;

const MAX_BYTES = 1024; // TODO: Can we assume 1024 bytes enough for the info we need?

/// Value for linker `--hash-style=` argument
pub const HashStyle = enum {
    both,
    gnu,
};

pub const Tag = enum {
    alpine,
    arch,
    debian_lenny,
    debian_squeeze,
    debian_wheezy,
    debian_jessie,
    debian_stretch,
    debian_buster,
    debian_bullseye,
    debian_bookworm,
    debian_trixie,
    exherbo,
    rhel5,
    rhel6,
    rhel7,
    fedora,
    gentoo,
    open_suse,
    ubuntu_hardy,
    ubuntu_intrepid,
    ubuntu_jaunty,
    ubuntu_karmic,
    ubuntu_lucid,
    ubuntu_maverick,
    ubuntu_natty,
    ubuntu_oneiric,
    ubuntu_precise,
    ubuntu_quantal,
    ubuntu_raring,
    ubuntu_saucy,
    ubuntu_trusty,
    ubuntu_utopic,
    ubuntu_vivid,
    ubuntu_wily,
    ubuntu_xenial,
    ubuntu_yakkety,
    ubuntu_zesty,
    ubuntu_artful,
    ubuntu_bionic,
    ubuntu_cosmic,
    ubuntu_disco,
    ubuntu_eoan,
    ubuntu_focal,
    ubuntu_groovy,
    ubuntu_hirsute,
    ubuntu_impish,
    ubuntu_jammy,
    ubuntu_kinetic,
    ubuntu_lunar,
    unknown,

    pub fn getHashStyle(self: Tag) HashStyle {
        if (self.isOpenSUSE()) return .both;
        return switch (self) {
            .ubuntu_lucid,
            .ubuntu_jaunty,
            .ubuntu_karmic,
            => .both,
            else => .gnu,
        };
    }

    pub fn isRedhat(self: Tag) bool {
        return switch (self) {
            .fedora,
            .rhel5,
            .rhel6,
            .rhel7,
            => true,
            else => false,
        };
    }

    pub fn isOpenSUSE(self: Tag) bool {
        return self == .open_suse;
    }

    pub fn isDebian(self: Tag) bool {
        return switch (self) {
            .debian_lenny,
            .debian_squeeze,
            .debian_wheezy,
            .debian_jessie,
            .debian_stretch,
            .debian_buster,
            .debian_bullseye,
            .debian_bookworm,
            .debian_trixie,
            => true,
            else => false,
        };
    }
    pub fn isUbuntu(self: Tag) bool {
        return switch (self) {
            .ubuntu_hardy,
            .ubuntu_intrepid,
            .ubuntu_jaunty,
            .ubuntu_karmic,
            .ubuntu_lucid,
            .ubuntu_maverick,
            .ubuntu_natty,
            .ubuntu_oneiric,
            .ubuntu_precise,
            .ubuntu_quantal,
            .ubuntu_raring,
            .ubuntu_saucy,
            .ubuntu_trusty,
            .ubuntu_utopic,
            .ubuntu_vivid,
            .ubuntu_wily,
            .ubuntu_xenial,
            .ubuntu_yakkety,
            .ubuntu_zesty,
            .ubuntu_artful,
            .ubuntu_bionic,
            .ubuntu_cosmic,
            .ubuntu_disco,
            .ubuntu_eoan,
            .ubuntu_focal,
            .ubuntu_groovy,
            .ubuntu_hirsute,
            .ubuntu_impish,
            .ubuntu_jammy,
            .ubuntu_kinetic,
            .ubuntu_lunar,
            => true,

            else => false,
        };
    }
    pub fn isAlpine(self: Tag) bool {
        return self == .alpine;
    }
    pub fn isGentoo(self: Tag) bool {
        return self == .gentoo;
    }
};

fn scanForOsRelease(buf: []const u8) ?Tag {
    var it = mem.splitScalar(u8, buf, '\n');
    while (it.next()) |line| {
        if (mem.startsWith(u8, line, "ID=")) {
            const rest = line["ID=".len..];
            if (mem.eql(u8, rest, "alpine")) return .alpine;
            if (mem.eql(u8, rest, "fedora")) return .fedora;
            if (mem.eql(u8, rest, "gentoo")) return .gentoo;
            if (mem.eql(u8, rest, "arch")) return .arch;
            if (mem.eql(u8, rest, "sles")) return .open_suse;
            if (mem.eql(u8, rest, "opensuse")) return .open_suse;
            if (mem.eql(u8, rest, "exherbo")) return .exherbo;
        }
    }
    return null;
}

fn detectOsRelease(fs: Filesystem) ?Tag {
    var buf: [MAX_BYTES]u8 = undefined;
    const data = fs.readFile("/etc/os-release", &buf) orelse fs.readFile("/usr/lib/os-release", &buf) orelse return null;
    return scanForOsRelease(data);
}

fn scanForLSBRelease(buf: []const u8) ?Tag {
    var it = mem.splitScalar(u8, buf, '\n');
    while (it.next()) |line| {
        if (mem.startsWith(u8, line, "DISTRIB_CODENAME=")) {
            const rest = line["DISTRIB_CODENAME=".len..];
            if (mem.eql(u8, rest, "hardy")) return .ubuntu_hardy;
            if (mem.eql(u8, rest, "intrepid")) return .ubuntu_intrepid;
            if (mem.eql(u8, rest, "jaunty")) return .ubuntu_jaunty;
            if (mem.eql(u8, rest, "karmic")) return .ubuntu_karmic;
            if (mem.eql(u8, rest, "lucid")) return .ubuntu_lucid;
            if (mem.eql(u8, rest, "maverick")) return .ubuntu_maverick;
            if (mem.eql(u8, rest, "natty")) return .ubuntu_natty;
            if (mem.eql(u8, rest, "oneiric")) return .ubuntu_oneiric;
            if (mem.eql(u8, rest, "precise")) return .ubuntu_precise;
            if (mem.eql(u8, rest, "quantal")) return .ubuntu_quantal;
            if (mem.eql(u8, rest, "raring")) return .ubuntu_raring;
            if (mem.eql(u8, rest, "saucy")) return .ubuntu_saucy;
            if (mem.eql(u8, rest, "trusty")) return .ubuntu_trusty;
            if (mem.eql(u8, rest, "utopic")) return .ubuntu_utopic;
            if (mem.eql(u8, rest, "vivid")) return .ubuntu_vivid;
            if (mem.eql(u8, rest, "wily")) return .ubuntu_wily;
            if (mem.eql(u8, rest, "xenial")) return .ubuntu_xenial;
            if (mem.eql(u8, rest, "yakkety")) return .ubuntu_yakkety;
            if (mem.eql(u8, rest, "zesty")) return .ubuntu_zesty;
            if (mem.eql(u8, rest, "artful")) return .ubuntu_artful;
            if (mem.eql(u8, rest, "bionic")) return .ubuntu_bionic;
            if (mem.eql(u8, rest, "cosmic")) return .ubuntu_cosmic;
            if (mem.eql(u8, rest, "disco")) return .ubuntu_disco;
            if (mem.eql(u8, rest, "eoan")) return .ubuntu_eoan;
            if (mem.eql(u8, rest, "focal")) return .ubuntu_focal;
            if (mem.eql(u8, rest, "groovy")) return .ubuntu_groovy;
            if (mem.eql(u8, rest, "hirsute")) return .ubuntu_hirsute;
            if (mem.eql(u8, rest, "impish")) return .ubuntu_impish;
            if (mem.eql(u8, rest, "jammy")) return .ubuntu_jammy;
            if (mem.eql(u8, rest, "kinetic")) return .ubuntu_kinetic;
            if (mem.eql(u8, rest, "lunar")) return .ubuntu_lunar;
        }
    }
    return null;
}

fn detectLSBRelease(fs: Filesystem) ?Tag {
    var buf: [MAX_BYTES]u8 = undefined;
    const data = fs.readFile("/etc/lsb-release", &buf) orelse return null;

    return scanForLSBRelease(data);
}

fn scanForRedHat(buf: []const u8) Tag {
    if (mem.startsWith(u8, buf, "Fedora release")) return .fedora;
    if (mem.startsWith(u8, buf, "Red Hat Enterprise Linux") or mem.startsWith(u8, buf, "CentOS") or mem.startsWith(u8, buf, "Scientific Linux")) {
        if (mem.indexOfPos(u8, buf, 0, "release 7") != null) return .rhel7;
        if (mem.indexOfPos(u8, buf, 0, "release 6") != null) return .rhel6;
        if (mem.indexOfPos(u8, buf, 0, "release 5") != null) return .rhel5;
    }

    return .unknown;
}

fn detectRedhat(fs: Filesystem) ?Tag {
    var buf: [MAX_BYTES]u8 = undefined;
    const data = fs.readFile("/etc/redhat-release", &buf) orelse return null;
    return scanForRedHat(data);
}

fn scanForDebian(buf: []const u8) Tag {
    var it = mem.splitScalar(u8, buf, '.');
    if (std.fmt.parseInt(u8, it.next().?, 10)) |major| {
        return switch (major) {
            5 => .debian_lenny,
            6 => .debian_squeeze,
            7 => .debian_wheezy,
            8 => .debian_jessie,
            9 => .debian_stretch,
            10 => .debian_buster,
            11 => .debian_bullseye,
            12 => .debian_bookworm,
            13 => .debian_trixie,
            else => .unknown,
        };
    } else |_| {}

    it = mem.splitScalar(u8, buf, '\n');
    const name = it.next().?;
    if (mem.eql(u8, name, "squeeze/sid")) return .debian_squeeze;
    if (mem.eql(u8, name, "wheezy/sid")) return .debian_wheezy;
    if (mem.eql(u8, name, "jessie/sid")) return .debian_jessie;
    if (mem.eql(u8, name, "stretch/sid")) return .debian_stretch;
    if (mem.eql(u8, name, "buster/sid")) return .debian_buster;
    if (mem.eql(u8, name, "bullseye/sid")) return .debian_bullseye;
    if (mem.eql(u8, name, "bookworm/sid")) return .debian_bookworm;

    return .unknown;
}

fn detectDebian(fs: Filesystem) ?Tag {
    var buf: [MAX_BYTES]u8 = undefined;
    const data = fs.readFile("/etc/debian_version", &buf) orelse return null;
    return scanForDebian(data);
}

pub fn detect(target: std.Target, fs: Filesystem) Tag {
    if (target.os.tag != .linux) return .unknown;

    if (detectOsRelease(fs)) |tag| return tag;
    if (detectLSBRelease(fs)) |tag| return tag;
    if (detectRedhat(fs)) |tag| return tag;
    if (detectDebian(fs)) |tag| return tag;

    if (fs.exists("/etc/gentoo-release")) return .gentoo;

    return .unknown;
}

test scanForDebian {
    try std.testing.expectEqual(Tag.debian_squeeze, scanForDebian("squeeze/sid"));
    try std.testing.expectEqual(Tag.debian_bullseye, scanForDebian("11.1.2"));
    try std.testing.expectEqual(Tag.unknown, scanForDebian("None"));
    try std.testing.expectEqual(Tag.unknown, scanForDebian(""));
}

test scanForRedHat {
    try std.testing.expectEqual(Tag.fedora, scanForRedHat("Fedora release 7"));
    try std.testing.expectEqual(Tag.rhel7, scanForRedHat("Red Hat Enterprise Linux release 7"));
    try std.testing.expectEqual(Tag.rhel5, scanForRedHat("CentOS release 5"));
    try std.testing.expectEqual(Tag.unknown, scanForRedHat("CentOS release 4"));
    try std.testing.expectEqual(Tag.unknown, scanForRedHat(""));
}

test scanForLSBRelease {
    const text =
        \\DISTRIB_ID=Ubuntu
        \\DISTRIB_RELEASE=20.04
        \\DISTRIB_CODENAME=focal
        \\DISTRIB_DESCRIPTION="Ubuntu 20.04.6 LTS"
        \\
    ;
    try std.testing.expectEqual(Tag.ubuntu_focal, scanForLSBRelease(text).?);
}

test scanForOsRelease {
    const text =
        \\NAME="Alpine Linux"
        \\ID=alpine
        \\VERSION_ID=3.18.2
        \\PRETTY_NAME="Alpine Linux v3.18"
        \\HOME_URL="https://alpinelinux.org/"
        \\BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
        \\
    ;
    try std.testing.expectEqual(Tag.alpine, scanForOsRelease(text).?);
}
