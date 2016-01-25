#version("2.0.0")
export library "mathtest";

export fn add(a: i32, b: i32) i32 => {
    a + b
}

export fn hang() unreachable => {
    while (true) { }
}
