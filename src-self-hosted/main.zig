const io = @import("std").io;
const os = @import("std").os;
const heap = @import("std").mem;

// TODO: OutSteam and InStream interface
// TODO: move allocator to heap namespace

error InvalidArgument;
error MissingArg0;

pub fn main() -> %void {
    if (internal_main()) |_| {
        return;
    } else |err| {
        if (err == error.InvalidArgument) {
            io.stderr.printf("\n") %% return err;
            printUsage(&io.stderr) %% return err;
        } else {
            io.stderr.printf("{}\n", err) %% return err;
        }
        return err;
    }
}

pub fn internal_main() -> %void {
    var args_it = os.args();

    var incrementing_allocator = heap.IncrementingAllocator.init(10 * 1024 * 1024) %% |err| {
        io.stderr.printf("Unable to allocate memory") %% {};
        return err;
    };
    defer incrementing_allocator.deinit();

    const allocator = &incrementing_allocator.allocator;
    
    const arg0 = %return (args_it.next(allocator) ?? error.MissingArg0);
    defer allocator.free(arg0);

    %return printUsage(&io.stdout);
}

fn printUsage(outstream: &io.OutStream) -> %void {
    %return outstream.write(
        \\Usage: zig [command] [options]
        \\Commands:
        \\  build                        build project from build.zig
        \\  build-exe [source]           create executable from source or object files
        \\  build-lib [source]           create library from source or object files
        \\  build-obj [source]           create object from source or assembly
        \\  parsec [source]              convert c code to zig code
        \\  targets                      list available compilation targets
        \\  test [source]                create and run a test build
        \\  version                      print version number and exit
        \\  zen                          print zen of zig and exit
        \\Compile Options:
        \\  --assembly [source]          add assembly file to build
        \\  --cache-dir [path]           override the cache directory
        \\  --color [auto|off|on]        enable or disable colored error messages
        \\  --enable-timing-info         print timing diagnostics
        \\  --libc-include-dir [path]    directory where libc stdlib.h resides
        \\  --name [name]                override output name
        \\  --output [file]              override destination path
        \\  --output-h [file]            override generated header file path
        \\  --pkg-begin [name] [path]    make package available to import and push current pkg
        \\  --pkg-end                    pop current pkg
        \\  --release-fast               build with optimizations on and safety off
        \\  --release-safe               build with optimizations on and safety on
        \\  --static                     output will be statically linked
        \\  --strip                      exclude debug symbols
        \\  --target-arch [name]         specify target architecture
        \\  --target-environ [name]      specify target environment
        \\  --target-os [name]           specify target operating system
        \\  --verbose                    turn on compiler debug output
        \\  --verbose-link               turn on compiler debug output for linking only
        \\  --verbose-ir                 turn on compiler debug output for IR only
        \\  --zig-install-prefix [path]  override directory where zig thinks it is installed
        \\  -dirafter [dir]              same as -isystem but do it last
        \\  -isystem [dir]               add additional search path for other .h files
        \\  -mllvm [arg]                 additional arguments to forward to LLVM's option processing
        \\Link Options:
        \\  --ar-path [path]             set the path to ar
        \\  --dynamic-linker [path]      set the path to ld.so
        \\  --each-lib-rpath             add rpath for each used dynamic library
        \\  --libc-lib-dir [path]        directory where libc crt1.o resides
        \\  --libc-static-lib-dir [path] directory where libc crtbegin.o resides
        \\  --msvc-lib-dir [path]        (windows) directory where vcruntime.lib resides
        \\  --kernel32-lib-dir [path]    (windows) directory where kernel32.lib resides
        \\  --library [lib]              link against lib
        \\  --library-path [dir]         add a directory to the library search path
        \\  --linker-script [path]       use a custom linker script
        \\  --object [obj]               add object file to build
        \\  -L[dir]                      alias for --library-path
        \\  -rdynamic                    add all symbols to the dynamic symbol table
        \\  -rpath [path]                add directory to the runtime library search path
        \\  -mconsole                    (windows) --subsystem console to the linker
        \\  -mwindows                    (windows) --subsystem windows to the linker
        \\  -municode                    (windows) link with unicode
        \\  -framework [name]            (darwin) link against framework
        \\  -mios-version-min [ver]      (darwin) set iOS deployment target
        \\  -mmacosx-version-min [ver]   (darwin) set Mac OS X deployment target
        \\  --ver-major [ver]            dynamic library semver major version
        \\  --ver-minor [ver]            dynamic library semver minor version
        \\  --ver-patch [ver]            dynamic library semver patch version
        \\Test Options:
        \\  --test-filter [text]         skip tests that do not match filter
        \\  --test-name-prefix [text]    add prefix to all tests
        \\  --test-cmd [arg]             specify test execution command one arg at a time
        \\  --test-cmd-bin               appends test binary path to test cmd args
        \\
    );
    %return outstream.flush();
}
