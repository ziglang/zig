export fn entry2() callconv(.{ .arm_aapcs = .{} }) void {}
export fn entry3() callconv(.{ .arm_aapcs_vfp = .{} }) void {}

// error
// target=x86_64-linux-none
//
// :1:30: error: calling convention 'arm_aapcs' only available on architectures 'arm', 'armeb', 'thumb', 'thumbeb'
// :2:30: error: calling convention 'arm_aapcs_vfp' only available on architectures 'arm', 'armeb', 'thumb', 'thumbeb'
