pub const GpioRegister = packed struct(u8) {
    GPIO0: bool,
    GPIO1: bool,
    GPIO2: bool,
    GPIO3: bool,
    reserved: u4 = 0,
};

const gpio: *volatile GpioRegister = @ptrFromInt(0x0123);

pub fn writeToGpio(new_states: GpioRegister) void {
    // Example of what not to do:
    // BAD! gpio.GPIO0 = true; BAD!

    // Instead, do this:
    gpio.* = new_states;
}

// syntax
