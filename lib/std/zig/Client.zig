pub const Message = struct {
    pub const Header = extern struct {
        tag: Tag,
        /// Size of the body only; does not include this Header.
        bytes_len: u32,
    };

    pub const Tag = enum(u32) {
        /// Tells the compiler to shut down cleanly.
        /// No body.
        exit,
        /// Tells the compiler to detect changes in source files and update the
        /// affected output compilation artifacts.
        /// If one of the compilation artifacts is an executable that is
        /// running as a child process, the compiler will wait for it to exit
        /// before performing the update.
        /// No body.
        update,
        /// Tells the compiler to execute the executable as a child process.
        /// No body.
        run,
        /// Tells the compiler to detect changes in source files and update the
        /// affected output compilation artifacts.
        /// If one of the compilation artifacts is an executable that is
        /// running as a child process, the compiler will perform a hot code
        /// swap.
        /// No body.
        hot_update,
        /// Ask the test runner for metadata about all the unit tests that can
        /// be run. Server will respond with a `test_metadata` message.
        /// No body.
        query_test_metadata,
        /// Ask the test runner to run a particular test.
        /// The message body is a u32 test index.
        run_test,
        /// Ask the test runner to start fuzzing a particular test forever or for a given amount of time/iterations.
        /// The message body is:
        /// - a u32 test index.
        /// - a u8 test limit kind (std.Build.api.fuzz.LimitKind)
        /// - a u64 value whose meaning depends on FuzzLimitKind (either a limit amount or an instance id)
        start_fuzzing,

        _,
    };

    comptime {
        const std = @import("std");
        std.debug.assert(@sizeOf(std.Build.abi.fuzz.LimitKind) == 1);
    }
};
