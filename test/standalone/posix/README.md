## Zig standalone POSIX tests

This directory is just for std.posix-related test cases that depend on
process-wide state like the current-working directory, signal handlers,
fork, the main thread, environment variables, etc.  Most tests (e.g,
around file descriptors, etc) are with the unit tests in
`lib/std/posix/test.zig`.  New tests should be with the unit tests, unless
there is a specific reason they cannot.
