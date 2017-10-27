const builtin = @import("builtin");
const io = @import("std").io;
const os = @import("std").os;
const heap = @import("std").mem;

// TODO: OutSteam and InStream interface
// TODO: move allocator to heap namespace
// TODO: sync up CLI with c++ code

error InvalidArgument;
error MissingArg0;

var arg0: []u8 = undefined;

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
    
    arg0 = %return (args_it.next(allocator) ?? error.MissingArg0);
    defer allocator.free(arg0);

    var build_mode = builtin.Mode.Debug;
    var strip = false;
    var is_static = false;
    var verbose = false;
    var verbose_link = false;
    var verbose_ir = false;
    var mwindows = false;
    var mconsole = false;

    while (args_it.next()) |arg_or_err| {
        const arg = %return arg_or_err;

        if (arg[0] == '-') {
            if (strcmp(arg, "--release-fast") == 0) {
                build_mode = builtin.Mode.ReleaseFast;
            } else if (strcmp(arg, "--release-safe") == 0) {
                build_mode = builtin.Mode.ReleaseSafe;
            } else if (strcmp(arg, "--strip") == 0) {
                strip = true;
            } else if (strcmp(arg, "--static") == 0) {
                is_static = true;
            } else if (strcmp(arg, "--verbose") == 0) {
                verbose = true;
            } else if (strcmp(arg, "--verbose-link") == 0) {
                verbose_link = true;
            } else if (strcmp(arg, "--verbose-ir") == 0) {
                verbose_ir = true;
            } else if (strcmp(arg, "-mwindows") == 0) {
                mwindows = true;
            } else if (strcmp(arg, "-mconsole") == 0) {
                mconsole = true;
            } else if (strcmp(arg, "-municode") == 0) {
                municode = true;
            } else if (strcmp(arg, "-rdynamic") == 0) {
                rdynamic = true;
            } else if (strcmp(arg, "--each-lib-rpath") == 0) {
                each_lib_rpath = true;
            } else if (strcmp(arg, "--enable-timing-info") == 0) {
                timing_info = true;
            } else if (strcmp(arg, "--test-cmd-bin") == 0) {
                test_exec_args.append(nullptr);
            } else if (arg[1] == 'L' && arg[2] != 0) {
                // alias for --library-path
                lib_dirs.append(&arg[2]);
            } else if (strcmp(arg, "--pkg-begin") == 0) {
                if (i + 2 >= argc) {
                    fprintf(stderr, "Expected 2 arguments after --pkg-begin\n");
                    return usage(arg0);
                }
                CliPkg *new_cur_pkg = allocate<CliPkg>(1);
                i += 1;
                new_cur_pkg->name = argv[i];
                i += 1;
                new_cur_pkg->path = argv[i];
                new_cur_pkg->parent = cur_pkg;
                cur_pkg->children.append(new_cur_pkg);
                cur_pkg = new_cur_pkg;
            } else if (strcmp(arg, "--pkg-end") == 0) {
                if (cur_pkg->parent == nullptr) {
                    fprintf(stderr, "Encountered --pkg-end with no matching --pkg-begin\n");
                    return EXIT_FAILURE;
                }
                cur_pkg = cur_pkg->parent;
            } else if (i + 1 >= argc) {
                fprintf(stderr, "Expected another argument after %s\n", arg);
                return usage(arg0);
            } else {
                i += 1;
                if (strcmp(arg, "--output") == 0) {
                    out_file = argv[i];
                } else if (strcmp(arg, "--output-h") == 0) {
                    out_file_h = argv[i];
                } else if (strcmp(arg, "--color") == 0) {
                    if (strcmp(argv[i], "auto") == 0) {
                        color = ErrColorAuto;
                    } else if (strcmp(argv[i], "on") == 0) {
                        color = ErrColorOn;
                    } else if (strcmp(argv[i], "off") == 0) {
                        color = ErrColorOff;
                    } else {
                        fprintf(stderr, "--color options are 'auto', 'on', or 'off'\n");
                        return usage(arg0);
                    }
                } else if (strcmp(arg, "--name") == 0) {
                    out_name = argv[i];
                } else if (strcmp(arg, "--libc-lib-dir") == 0) {
                    libc_lib_dir = argv[i];
                } else if (strcmp(arg, "--libc-static-lib-dir") == 0) {
                    libc_static_lib_dir = argv[i];
                } else if (strcmp(arg, "--libc-include-dir") == 0) {
                    libc_include_dir = argv[i];
                } else if (strcmp(arg, "--msvc-lib-dir") == 0) {
                    msvc_lib_dir = argv[i];
                } else if (strcmp(arg, "--kernel32-lib-dir") == 0) {
                    kernel32_lib_dir = argv[i];
                } else if (strcmp(arg, "--zig-install-prefix") == 0) {
                    zig_install_prefix = argv[i];
                } else if (strcmp(arg, "--dynamic-linker") == 0) {
                    dynamic_linker = argv[i];
                } else if (strcmp(arg, "-isystem") == 0) {
                    clang_argv.append("-isystem");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-dirafter") == 0) {
                    clang_argv.append("-dirafter");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-mllvm") == 0) {
                    clang_argv.append("-mllvm");
                    clang_argv.append(argv[i]);

                    llvm_argv.append(argv[i]);
                } else if (strcmp(arg, "--library-path") == 0 || strcmp(arg, "-L") == 0) {
                    lib_dirs.append(argv[i]);
                } else if (strcmp(arg, "--library") == 0) {
                    link_libs.append(argv[i]);
                } else if (strcmp(arg, "--object") == 0) {
                    objects.append(argv[i]);
                } else if (strcmp(arg, "--assembly") == 0) {
                    asm_files.append(argv[i]);
                } else if (strcmp(arg, "--cache-dir") == 0) {
                    cache_dir = argv[i];
                } else if (strcmp(arg, "--target-arch") == 0) {
                    target_arch = argv[i];
                } else if (strcmp(arg, "--target-os") == 0) {
                    target_os = argv[i];
                } else if (strcmp(arg, "--target-environ") == 0) {
                    target_environ = argv[i];
                } else if (strcmp(arg, "-mmacosx-version-min") == 0) {
                    mmacosx_version_min = argv[i];
                } else if (strcmp(arg, "-mios-version-min") == 0) {
                    mios_version_min = argv[i];
                } else if (strcmp(arg, "-framework") == 0) {
                    frameworks.append(argv[i]);
                } else if (strcmp(arg, "--linker-script") == 0) {
                    linker_script = argv[i];
                } else if (strcmp(arg, "-rpath") == 0) {
                    rpath_list.append(argv[i]);
                } else if (strcmp(arg, "--test-filter") == 0) {
                    test_filter = argv[i];
                } else if (strcmp(arg, "--test-name-prefix") == 0) {
                    test_name_prefix = argv[i];
                } else if (strcmp(arg, "--ver-major") == 0) {
                    ver_major = atoi(argv[i]);
                } else if (strcmp(arg, "--ver-minor") == 0) {
                    ver_minor = atoi(argv[i]);
                } else if (strcmp(arg, "--ver-patch") == 0) {
                    ver_patch = atoi(argv[i]);
                } else if (strcmp(arg, "--test-cmd") == 0) {
                    test_exec_args.append(argv[i]);
                } else {
                    fprintf(stderr, "Invalid argument: %s\n", arg);
                    return usage(arg0);
                }
            }
        }
    }
}

fn printUsage(outstream: &io.OutStream) -> %void {
    %return outstream.print("Usage: {} [command] [options]\n", arg0);
    %return outstream.write(
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

const ZIG_ZEN =
    \\ * Communicate intent precisely.
    \\ * Edge cases matter.
    \\ * Favor reading code over writing code.
    \\ * Only one obvious way to do things.
    \\ * Runtime crashes are better than bugs.
    \\ * Compile errors are better than runtime crashes.
    \\ * Incremental improvements.
    \\ * Avoid local maximums.
    \\ * Reduce the amount one must remember.
    \\ * Minimize energy spent on coding style.
    \\ * Together we serve end users.
    \\
;
