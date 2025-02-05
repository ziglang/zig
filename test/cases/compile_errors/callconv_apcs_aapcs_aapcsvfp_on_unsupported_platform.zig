export fn entry1() callconv(.APCS) void {}
export fn entry2() callconv(.AAPCS) void {}
export fn entry3() callconv(.AAPCSVFP) void {}

// error
// target=x86_64-linux-none
//
// :1:30: error: calling convention 'arm_apcs' only available on architectures 'arm', 'armeb', 'thumb', 'thumbeb'
// :2:30: error: calling convention 'arm_aapcs' only available on architectures 'arm', 'armeb', 'thumb', 'thumbeb'
// :3:30: error: calling convention 'arm_aapcs_vfp' only available on architectures 'arm', 'armeb', 'thumb', 'thumbeb'
