const std = @import("std");
const expect = std.testing.expect;

var defer_f1: bool = false;
var defer_f2: bool = false;
var defer_f3: bool = false;
var f3_frame: anyframe = undefined;

test "cancel forwards" {
    _ = async atest1();
    resume f3_frame;
}

fn atest1() void {
    const p = async f1();
    cancel &p;
    expect(defer_f1);
    expect(defer_f2);
    expect(defer_f3);
}

async fn f1() void {
    defer {
        defer_f1 = true;
    }
    var f2_frame = async f2();
    await f2_frame;
}

async fn f2() void {
    defer {
        defer_f2 = true;
    }
    f3();
}

async fn f3() void {
    f3_frame = @frame();
    defer {
        defer_f3 = true;
    }
    suspend;
}

var defer_b1: bool = false;
var defer_b2: bool = false;
var defer_b3: bool = false;
var defer_b4: bool = false;

test "cancel backwards" {
    _ = async b1();
    resume b4_handle;
    expect(defer_b1);
    expect(defer_b2);
    expect(defer_b3);
    expect(defer_b4);
}

async fn b1() void {
    defer {
        defer_b1 = true;
    }
    b2();
}

var b4_handle: anyframe = undefined;

async fn b2() void {
    const b3_handle = async b3();
    resume b4_handle;
    defer {
        defer_b2 = true;
    }
    const value = await b3_handle;
    expect(value == 1234);
}

async fn b3() i32 {
    defer {
        defer_b3 = true;
    }
    b4();
    return 1234;
}

async fn b4() void {
    defer {
        defer_b4 = true;
    }
    suspend {
        b4_handle = @frame();
    }
    suspend;
}
