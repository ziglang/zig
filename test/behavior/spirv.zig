const Sampler = @SpirvType(.sampler);
const Image = @SpirvType(.{ .image = .{
    .usage = .{ .sampled = u32 },
    .format = .unknown,
    .dim = .@"2d",
    .depth = .unknown,
    .arrayed = false,
    .multisampled = false,
    .access = .unknown,
} });
const SampledImage = @SpirvType(.{ .sampled_image = Image });
const StorageImage = @SpirvType(.{ .image = .{
    .usage = .storage,
    .format = .unknown,
    .dim = .@"2d",
    .depth = .unknown,
    .arrayed = false,
    .multisampled = false,
    .access = .unknown,
} });
const RuntimeArray = @SpirvType(.{ .runtime_array = u32 });

extern const sampler: Sampler addrspace(.constant);
extern const sampled_image: SampledImage addrspace(.constant);
extern const storage_image: StorageImage addrspace(.constant);
extern const runtime_array: extern struct { e: RuntimeArray } addrspace(.storage_buffer);

test "@SpirvType" {
    _ = &sampler;
    _ = &sampled_image;
    _ = &storage_image;
    _ = &runtime_array;
}
