const std = @import("std");
const Version = std.SemanticVersion;
const print = @import("std").debug.print;

fn readVersion() Version {
    const version_file = "foo";
    const len = std.mem.indexOfAny(u8, version_file, " \n") orelse version_file.len;
    const version_string = version_file[0..len];
    return Version.parse(version_string) catch unreachable;
}

const version: Version = readVersion();
pub export fn entry() void {
    print("Version {}.{}.{}+{?s}\n", .{ version.major, version.minor, version.patch, version.build });
}

// error
// backend=llvm
// target=native
//
// :9:48: error: caught unexpected error 'InvalidVersion'
// :?:?: note: error returned here
// :?:?: note: error returned here
// :?:?: note: error returned here
// :?:?: note: error returned here
// :?:?: note: error returned here
// :12:37: note: called from here
