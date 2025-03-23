comptime {
    _ = @SpirvType(.{ .image = .{
        .usage = .storage,
        .format = .unknown,
        .dim = .@"2d",
        .depth = .unknown,
        .arrayed = false,
        .multisampled = false,
        .access = .read_only,
    } });
}

comptime {
    _ = @SpirvType(.{ .image = .{
        .usage = .{ .sampled = bool },
        .format = .unknown,
        .dim = .@"2d",
        .depth = .unknown,
        .arrayed = false,
        .multisampled = false,
        .access = .unknown,
    } });
}

comptime {
    _ = @SpirvType(.{ .image = .{
        .usage = .{ .sampled = void },
        .format = .unknown,
        .dim = .@"2d",
        .depth = .unknown,
        .arrayed = false,
        .multisampled = false,
        .access = .unknown,
    } });
}

comptime {
    _ = @SpirvType(.{ .image = .{
        .usage = .{ .sampled = u24 },
        .format = .unknown,
        .dim = .@"2d",
        .depth = .unknown,
        .arrayed = false,
        .multisampled = false,
        .access = .unknown,
    } });
}

// error
// backend=stage2
// target=spirv64-vulkan
//
// :2:21: error: access qualifer '.read_only' is only valid under the 'opencl' os
// :14:21: error: invalid 'sampled' field value 'bool'
// :26:21: error: 'void' type for 'sampled' field is only valid under the 'opencl' os
// :38:21: error: 'sampled' field value must be a 32-bit int, 64-bit int or 32-bit float under the 'vulkan' os
