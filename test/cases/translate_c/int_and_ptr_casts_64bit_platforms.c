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
// var ptr: ?*anyopaque = @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -@as(c_int, 1))))));
//
// var s: c_short = @as(c_short, @bitCast(@as(c_ushort, @truncate(@intFromPtr(ptr)))));
//
// var us: c_ushort = @as(c_ushort, @truncate(@intFromPtr(ptr)));
//
// ptr = @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, @truncate(bigint))))));
//
// ptr = @as(?*anyopaque, @ptrFromInt(@as(usize, @truncate(biguint))));
