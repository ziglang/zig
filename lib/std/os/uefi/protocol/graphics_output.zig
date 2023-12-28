const bits = @import("../bits.zig");

const cc = bits.cc;
const Status = @import("../status.zig").Status;

const Guid = bits.Guid;

/// Provides a basic abstraction to set video modes and copy pixels to and from the graphics controller’s frame
/// buffer. The linear address of the hardware frame buffer is also exposed so software can write directly to the
/// video hardware.
pub const GraphicsOutput = extern struct {
    _query_mode: *const fn (*const GraphicsOutput, u32, *usize, **const Mode.Info) callconv(cc) Status,
    _set_mode: *const fn (*const GraphicsOutput, u32) callconv(cc) Status,
    _blt: *const fn (*const GraphicsOutput, ?[*]BltPixel, BltOperation, usize, usize, usize, usize, usize, usize, usize) callconv(cc) Status,
    mode: *const Mode,

    pub const Mode = extern struct {
        /// The number of valid modes supported by `setMode()` and `queryMode()`.
        ///
        /// This will be one higher than the highest mode number supported.
        max_mode: u32,

        /// Current mode of the graphics device.
        mode: u32,

        /// Pointer to this mode's mode information structure.
        info: *const Info,

        /// Size of the info structure in bytes. This size may be increased in future revisions.
        size_of_info: usize,

        /// Base address of graphics linear frame buffer. This field is only valid if the pixel mode is not `.blt_only`.
        frame_buffer_base: bits.PhysicalAddress,

        /// The size in bytes of the graphics linear frame buffer. This is defined as
        /// `pixels_per_scan_line` * vertical_resolution * pixelElementSize()`.
        frame_buffer_size: usize,

        pub const Info = extern struct {
            /// The version of this data structure. A value of zero represents the this structure. Future version of
            /// this specification may extend this data structure in a backwards compatible way and increase the
            /// value of Version.
            version: u32 = 0,

            /// The size of video screen in pixels in the X dimension.
            horizontal_resolution: u32,

            /// The size of video screen in pixels in the Y dimension.
            vertical_resolution: u32,

            /// The physical format of the pixel.
            pixel_format: PixelFormat,

            /// When format is `.bitmask`, this field defines the mask of each color channel.
            pixel_bitmask: PixelBitmask,

            /// The number of pixel elements per video memory line. This value must be used instead of
            /// `horizontal_resolution` to calculate the offset to the next line.
            pixels_per_scan_line: u32,

            /// The size of a pixel element in bytes.
            pub fn pixelElementSize(self: *const Info) usize {
                switch (self.pixel_format) {
                    .rgb_8bit => return 4,
                    .bgr_8bit => return 4,
                    .bitmask => return @divExact(self.pixel_bitmask.bitSizeOf(), 8),
                    .blt_only => return 0,
                }
            }
        };
    };

    pub const PixelFormat = enum(u32) {
        /// A pixel is 32 bits, byte zero represents red, byte one represents green, byte two represents blue, and
        /// byte three is reserved. The values range from the minimum intensity of 0 to maximum intensity of 255.
        rgb_8bit,

        /// A pixel is 32 bits, byte zero represents blue, byte one represents green, byte two represents red, and
        /// byte three is reserved. The values range from the minimum intensity of 0 to maximum intensity of 255.
        bgr_8bit,

        /// The pixel format is defined by the `PixelBitmask` structure.
        bitmask,

        /// This mode does not support a physical framebuffer.
        blt_only,
    };

    pub const PixelBitmask = extern struct {
        red: u32,
        green: u32,
        blue: u32,
        reserved: u32,

        pub const PixelField = enum {
            red,
            green,
            blue,
            reserved,
        };

        /// Finds the size in bits of a single pixel.
        pub fn bitSizeOf(self: *const PixelBitmask) usize {
            const highest_red_bit = 32 - @clz(self.red_mask);
            const highest_green_bit = 32 - @clz(self.green_mask);
            const highest_blue_bit = 32 - @clz(self.blue_mask);
            const highest_reserved_bit = 32 - @clz(self.reserved_mask);

            return @max(@max(highest_red_bit, highest_green_bit), @max(highest_blue_bit, highest_reserved_bit));
        }

        /// Finds the size in bits of a pixel field.
        pub fn bitSizeOfField(self: *const PixelBitmask, field: PixelField) usize {
            switch (field) {
                .red => return @popCount(self.red_mask),
                .green => return @popCount(self.green_mask),
                .blue => return @popCount(self.blue_mask),
                .reserved => return @popCount(self.reserved_mask),
            }
        }

        /// Finds the offset from zero (ie. a shift) in bits of a pixel field.
        pub fn bitOffsetOfField(self: *const PixelBitmask, field: PixelField) usize {
            switch (field) {
                .red => return @ctz(self.red_mask),
                .green => return @ctz(self.green_mask),
                .blue => return @ctz(self.blue_mask),
                .reserved => return @ctz(self.reserved_mask),
            }
        }

        /// Pulls the value of a pixel field out of a pixel.
        pub fn getValue(self: *const PixelBitmask, field: PixelField, pixel_ptr: [*]const u8) u32 {
            const pixel: *align(1) const u32 = @ptrCast(pixel_ptr);

            switch (field) {
                .red => return (pixel.* & self.red_mask) >> @ctz(self.red_mask),
                .green => return (pixel.* & self.green_mask) >> @ctz(self.green_mask),
                .blue => return (pixel.* & self.blue_mask) >> @ctz(self.blue_mask),
                .reserved => return (pixel.* & self.reserved_mask) >> @ctz(self.reserved_mask),
            }
        }
    };

    /// Returns information for an available graphics mode that the graphics device and the set of active video
    /// output devices supports.
    pub fn queryMode(self: *const GraphicsOutput, mode: u32) !*const Mode.Info {
        var size: usize = undefined;
        var info: *const Mode.Info = undefined;
        try self._query_mode(self, mode, &size, &info).err();

        if (size < @sizeOf(Mode.Info)) return error.Unsupported;
        return info;
    }

    /// Set the video device into the specified mode and clears the visible portions of the output display to black.
    pub fn setMode(self: *const GraphicsOutput, mode: u32) !void {
        try self._set_mode(self, mode).err();
    }

    pub const BltPixel = extern struct {
        blue: u8,
        green: u8,
        red: u8,
        reserved: u8 = 0,
    };

    pub const BltOperation = enum(u32) {
        /// Write data from the `blt_buffer` pixel (0, 0) directly to every pixel of the video display rectangle
        /// (`destination_x`, `destination_y`) (`destination_x + width`, `destination_y + height`). Only one pixel
        /// will be used from the `blt_buffer`. `delta` is NOT used.
        video_fill,

        /// Read data from the video display rectangle (`source_x`, `source_y`) (`source_x + width`, `source_y + height`)
        /// and place it in the `blt_buffer` rectangle (`destination_x`, `destination_y`) (`destination_x + width`,
        /// `destination_y + height`). If `destination_x` or `destination_y` is not zero then `delta` must be set to
        /// the length in bytes of a row in the `blt_buffer`.
        video_to_blt_buffer,

        /// Write data from the `blt_buffer` rectangle (`source_x`, `source_x`) (`source_x + width`, `source_y + height`)
        /// directly to the video display rectangle (`destination_x`, `destination_y`) (`destination_x + width`,
        /// `destination_y + height`). If `source_x` or `source_x` is not zero then `delta` must be set to the length
        /// in bytes of a row in the `blt_buffer`.
        blt_buffer_to_video,

        /// Copy from the video display rectangle (`source_x`, `source_y`) (`source_x + width`, `source_y + height`)
        /// to the video display rectangle (`destination_x`, `destination_y`) (`destination_x + width`,
        /// `destination_y + height`. The `blt_buffer` and `delta` are not used in this mode. There is no limitation
        /// on the overlapping of the source and destination rectangles
        video_to_video,
    };

    /// Blt a rectangle of pixels on the graphics screen. Blt stands for BLock Transfer.
    pub fn blt(
        self: *const GraphicsOutput,
        /// The data to transfer to the graphics screen. Must be at least `width * height`.
        blt_buffer: ?[*]BltPixel,
        /// The operation to perform.
        blt_operation: BltOperation,
        /// The X coordinate of the source for the `blt_operation`. The origin of the screen is 0, 0 and that is the
        /// upper left-hand corner of the screen
        source_x: usize,
        /// The Y coordinate of the source for the `blt_operation`. The origin of the screen is 0, 0 and that is the
        /// upper left-hand corner of the screen.
        source_y: usize,
        /// The X coordinate of the destination for the `blt_operation`. The origin of the screen is 0, 0 and that is
        /// the upper left-hand corner of the screen.
        destination_x: usize,
        /// The Y coordinate of the destination for the `blt_operation`. The origin of the screen is 0, 0 and that is
        /// the upper left-hand corner of the screen.
        destination_y: usize,
        /// The width of a rectangle in the blt rectangle in pixels.
        width: usize,
        /// The height of a rectangle in the blt rectangle in pixels.
        height: usize,
        /// Not used for `.video_fill` or the `.video_to_video` operation. If a `delta` of zero is used, the entire
        /// `blt_buffer` is being operated on. If a subrectangle of the `blt_buffer` is being used then `delta`
        /// represents the number of bytes in a row of the `blt_buffer`.
        delta: usize,
    ) !void {
        try self._blt(self, blt_buffer, blt_operation, source_x, source_y, destination_x, destination_y, width, height, delta).err();
    }

    pub const guid align(8) = Guid{
        .time_low = 0x9042a9de,
        .time_mid = 0x23dc,
        .time_high_and_version = 0x4a38,
        .clock_seq_high_and_reserved = 0x96,
        .clock_seq_low = 0xfb,
        .node = [_]u8{ 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a },
    };
};
