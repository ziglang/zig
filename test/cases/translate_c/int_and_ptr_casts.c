#include <stdint.h>

int main() {
  void* ptr = (void *)-1;
  short s = (short)ptr;
  unsigned short us = (unsigned short)ptr;
  __int128 bigint = -1;
  unsigned __int128 biguint = -1;
  ptr = (void *)bigint;
  ptr = (void *)biguint;
  return 0;
}

// translate-c
// c_frontends=clang
// targets=x86_64-linux-none,x86_64-macos-none,x86_64-windows-non
// 
//     var ptr: ?*anyopaque = blk: {
//         if (@sizeOf(c_int) > @sizeOf(?*anyopaque)) {
//             break :blk @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, @truncate(-@as(c_int, 1)))))));
//         } else {
//             break :blk @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -@as(c_int, 1))))));
//         }
//     };
//     
//     var s: c_short = blk: {
//         if (@sizeOf(?*anyopaque) > @sizeOf(c_short)) {
//             break :blk @as(c_short, @bitCast(@as(c_ushort, @truncate(@intFromPtr(ptr)))));
//         } else {
//             break :blk @as(c_short, @bitCast(@as(c_ushort, @intFromPtr(ptr))));
//         }
//     };
//     
//     var us: c_ushort = blk: {
//         if (@sizeOf(?*anyopaque) > @sizeOf(c_ushort)) {
//             break :blk @as(c_ushort, @truncate(@intFromPtr(ptr)));
//         } else {
//             break :blk @as(c_ushort, @intFromPtr(ptr));
//         }
//     };
//     
//     ptr = blk: {
//         if (@sizeOf(i128) > @sizeOf(?*anyopaque)) {
//             break :blk @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, @truncate(bigint))))));
//         } else {
//             break :blk @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, bigint)))));
//         }
//     };
//    
//     ptr = blk: {
//         if (@sizeOf(u128) > @sizeOf(?*anyopaque)) {
//             break :blk @as(?*anyopaque, @ptrFromInt(@as(usize, @truncate(biguint))));
//         } else {
//             break :blk @as(?*anyopaque, @ptrFromInt(@as(usize, biguint)));
//         }
//     };
