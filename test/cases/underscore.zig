const std = @import("std");
const assert = std.debug.assert;

test "ignore lval with underscore" {
    _ = false;
}

test "ignore lval with underscore (for loop)" {
    for ([]void{}) |_, i| {
        for ([]void{}) |_, j| {
            break;
        }
        break;
    }
}

test "ignore lval with underscore (while loop)" {
    while (optionalReturn()) |_| {
      while (optionalReturn()) |_| {
          break;
      }
//      else |_| {
//
//      }
      break;
    }
//    else |_| {
//
//    }
}

fn optionalReturn() ?u32 {
    return 1;
}
