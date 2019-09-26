## Contributing

### Start a Project Using Zig

One of the best ways you can contribute to Zig is to start using it for a
personal project. Here are some great examples:

 * [Oxid](https://github.com/dbandstra/oxid) - arcade style game
 * [TM35-Metronome](https://github.com/TM35-Metronome) - tools for modifying and randomizing Pokémon games
 * [trOS](https://github.com/sjdh02/trOS) - tiny aarch64 baremetal OS thingy

Without fail, these projects lead to discovering bugs and helping flesh out use
cases, which lead to further design iterations of Zig. Importantly, each issue
found this way comes with real world motivations, so it is easy to explain
your reasoning behind proposals and feature requests.

Ideally, such a project will help you to learn new skills and add something
to your personal portfolio at the same time.

### Spread the Word

Another way to contribute is to write about Zig, or speak about Zig at a
conference, or do either of those things for your project which uses Zig.
Here are some examples:

 * [Iterative Replacement of C with Zig](http://tiehuis.github.io/blog/zig1.html)
 * [The Right Tool for the Right Job: Redis Modules & Zig](https://www.youtube.com/watch?v=eCHM8-_poZY)
 * [Writing a small ray tracer in Rust and Zig](https://nelari.us/post/raytracer_with_rust_and_zig/)

Zig is a brand new language, with no advertising budget. Word of mouth is the
only way people find out about the project, and the more people hear about it,
the more people will use it, and the better chance we have to take over the
world.

### Finding Contributor Friendly Issues

Please note that issues labeled
[Proposal](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3Aproposal)
but do not also have the
[Accepted](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3Aaccepted)
label are still under consideration, and efforts to implement such a proposal
have a high risk of being wasted. If you are interested in a proposal which is
still under consideration, please express your interest in the issue tracker,
providing extra insights and considerations that others have not yet expressed.
The most highly regarded argument in such a discussion is a real world use case.

The issue label
[Contributor Friendly](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3A%22contributor+friendly%22)
exists to help you find issues that are **limited in scope and/or
knowledge of Zig internals.**

### Editing Source Code

First, build the Stage 1 compiler as described in [the Building section](#building).

One modification you may want to make is adding `-DZIG_SKIP_INSTALL_LIB_FILES=ON`
to the cmake line. If you use the build directory as a working directory to run
tests with, zig will find the lib files in the source directory, and they will not
be "installed" every time you run `make`. This will allow you to make modifications
directly to the standard library, for example, and have them effective immediately.
Note that if you already ran `make` or `make install` with the default cmake
settings, there will already be a `lib/` directory in your build directory. When
executed from the build directory, zig will find this instead of the source lib/
directory. Remove the unwanted directory so that the desired one can be found.

To test changes, do the following from the build directory:

1. Run `make install` (on POSIX) or
   `msbuild -p:Configuration=Release INSTALL.vcxproj` (on Windows).
2. `bin/zig build test` (on POSIX) or `bin\zig.exe build test` (on Windows).

That runs the whole test suite, which does a lot of extra testing that you
likely won't always need, and can take upwards of 1 hour. This is what the
CI server runs when you make a pull request. (Note: actually it runs a few
more tests; keep reading.)

To save time, you can add the `--help` option to the `zig build` command and
see what options are available. One of the most helpful ones is
`-Dskip-release`. Adding this option to the command in step 2 above will take
the time down from around 2 hours to about 6 minutes, and this is a good
enough amount of testing before making a pull request.

Another example is choosing a different set of things to test. For example,
`test-std` instead of `test` will only run the standard library tests, and
not the other ones. Combining this suggestion with the previous one, you could
do this:

`bin/zig build test-std -Dskip-release` (on POSIX) or
`bin\zig.exe build test-std -Dskip-release` (on Windows).

This will run only the standard library tests, in debug mode only, for all
targets (it will cross-compile the tests for non-native targets but not run
them).

When making changes to the compiler source code, the most helpful test step to
run is `test-behavior`. When editing documentation it is `docs`. You can find
this information and more in the `--help` menu.

#### Testing Non-Native Architectures with QEMU

The Linux CI server additionally has qemu installed and sets `-Denable-qemu`.
This provides test coverage for, e.g. aarch64 even on x86_64 machines. It's 
recommended for Linux users to install qemu and enable this testing option
when editing the standard library or anything related to a non-native
architecture.

##### glibc

Testing foreign architectures with dynamically linked glibc is one step trickier.
This requires enabling `-Denable-foreign-glibc=/path/to/glibc/multi/install/glibcs`.
This path is obtained by building glibc for multiple architectures. This
process for me took an entire day to complete and takes up 65 GiB on my hard
drive. The CI server does not provide this test coverage. Instructions for
producing this path can be found
[on the wiki](https://github.com/ziglang/zig/wiki/Updating-libc#glibc).
Just the part with `build-many-glibcs.py`.

It's understood that most contributors will not have these tests enabled.

#### Testing Windows from a Linux Machine with Wine

When developing on Linux, another option is available to you: `-Denable-wine`.
This will enable running behavior tests and std lib tests with Wine. It's
recommended for Linux users to install Wine and enable this testing option 
when editing the standard library or anything Windows-related.
