pub const GPIORegister = packed struct(u8) {
    GPIO0: bool,
    GPIO1: bool,
    GPIO2: bool,
    GPIO3: bool,
    _reserved: u4 = 0,
};

/// Write a new state to the memory-mapped IO.
pub fn writeToGPIO(new_states: GPIORegister) void {
    const gpio_register_address = 0x0123;
    const raw_ptr: *align(1) volatile GPIORegister = @ptrFromInt(gpio_register_address);
    raw_ptr.* = new_states;
}

// syntax
