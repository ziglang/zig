fn okay_func() void {}

const a align(64) = okay_func;
const b addrspace(.generic) = okay_func;
const c linksection("irrelevant") = okay_func;

const d align(64) = 1.23;
const e addrspace(.generic) = 1.23;
const f linksection("irrelevant") = 1.23;

const g: comptime_float align(64) = 1.23;
const h: comptime_float addrspace(.generic) = 1.23;
const i: comptime_float linksection("irrelevant") = 1.23;

// zig fmt: off
comptime { _ = a; }
comptime { _ = b; }
comptime { _ = c; }
comptime { _ = d; }
comptime { _ = e; }
comptime { _ = f; }
comptime { _ = g; }
comptime { _ = h; }
comptime { _ = i; }
// zig fmt: on

// error
//
// :3:15: error: cannot specify alignment of function alias
// :4:20: error: cannot specify addrspace of function alias
// :5:21: error: cannot specify linksection of function alias
// :7:15: error: cannot specify alignment of comptime-only type
// :8:20: error: cannot specify addrspace of comptime-only type
// :9:21: error: cannot specify linksection of comptime-only type
// :11:31: error: cannot specify alignment of comptime-only type
// :12:36: error: cannot specify addrspace of comptime-only type
// :13:37: error: cannot specify linksection of comptime-only type
