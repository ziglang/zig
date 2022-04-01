======================
What's new in PyPy 2.2
======================

.. this is a revision shortly after release-2.1-beta
.. startrev: 4eb52818e7c0

.. branch: sanitise_bytecode_dispatch

Make PyPy's bytecode dispatcher easy to read, and less reliant on RPython
magic. There is no functional change, though the removal of dead code leads
to many fewer tests to execute.

.. branch: fastjson

Fast json decoder written in RPython, about 3-4x faster than the pure Python
decoder which comes with the stdlib

.. branch: improve-str2charp

Improve the performance of I/O writing up to 15% by using memcpy instead of
copying char-by-char in str2charp and get_nonmovingbuffer

.. branch: flowoperators

Simplify rpython/flowspace/ code by using more metaprogramming.  Create
SpaceOperator class to gather static information about flow graph operations.

.. branch: package-tk

Adapt package.py script to compile CFFI tk extension. Add a --without-tk switch
to optionally skip it.

.. branch: distutils-cppldflags

Copy CPython's implementation of customize_compiler, dont call split on
environment variables, honour CFLAGS, CPPFLAGS, LDSHARED and LDFLAGS on Unices.

.. branch: precise-instantiate

When an RPython class is instantiated via an indirect call (that is, which
class is being instantiated isn't known precisely) allow the optimizer to have
more precise information about which functions can be called. Needed for Topaz.

.. branch: ssl_moving_write_buffer

.. branch: pythoninspect-fix

Make PyPy respect PYTHONINSPECT variable set via os.putenv in the same process
to start interactive prompt when the script execution finishes. This adds
new __pypy__.os.real_getenv call that bypasses Python cache and looksup env
in the underlying OS. Translatorshell now works on PyPy.

.. branch: add-statvfs

Added os.statvfs and os.fstatvfs

.. branch: statvfs_tests

Added some addition tests for statvfs.

.. branch: ndarray-subtype

Allow subclassing ndarray, i.e. matrix

.. branch: ndarray-sort

Implement ndarray in-place sorting (for numeric types, no non-native byte order)

.. branch: pypy-pyarray

Implement much of numpy's c api in cpyext, allows (slow) access to ndarray
from c

.. branch: kill-ootype

.. branch: fast-slowpath

Added an abstraction for functions with a fast and slow path in the JIT. This
speeds up list.append() and list.pop().

.. branch: curses_fixes

.. branch: foldable-getarrayitem-indexerror

Constant-fold reading out of constant tuples in PyPy.

.. branch: mro-reorder-numpypy-str

No longer delegate numpy string methods to space.StringObject, in numpy
this works by kind of by accident. Support for merging the refactor-str-types
branch

.. branch: kill-typesystem

Remove the "type system" abstraction, now that there is only ever one kind of
type system used.

.. branch: kill-gen-store-back-in

Kills gen_store_back_in_virtualizable - should improve non-inlined calls by
a bit

.. branch: dotviewer-linewidth
.. branch: reflex-support
.. branch: numpypy-inplace-op
.. branch: rewritten-loop-logging
.. branch: no-release-gil
.. branch: safe-win-mmap
.. branch: boolean-indexing-cleanup
.. branch: cpyext-best_base
.. branch: cpyext-int
.. branch: fileops2

.. branch: nobold-backtrace

Work on improving UnionError messages and stack trace displays.

.. branch: improve-errors-again

More improvements and refactorings of error messages.

.. branch: improve-errors-again2

Unbreak tests in rlib.

.. branch: less-stringly-ops

Use subclasses of SpaceOperation instead of SpaceOperator objects.
Random cleanups in flowspace.

.. branch: file-support-in-rpython

make open() and friends rpython

.. branch: incremental-gc

Added the new incminimark GC which performs GC in incremental steps

.. branch: fast_cffi_list_init

fastpath for cffi.new("long[]")

.. branch: remove-eval-frame

remove a pointless abstraction

.. branch: jit-settrace

Allow the jit to continue running when sys.settrace() is active, necessary to
make coverage.py fast

.. branch: remove-numpypy

Remove lib_pypy/numpypy in favor of external numpy fork

.. branch: jit-counter

Tweak the jit counters: decay them at minor collection (actually
only every 32 minor collection is enough). Should avoid the "memory
leaks" observed in long-running processes, actually created by the
jit compiling more and more rarely executed paths.

.. branch: fix-trace-jit

Fixed the usage of sys.settrace() with the JIT. Also made it so using
sys.settrace() doesn't cause the GIL to be released on every single iteration.

.. branch: rordereddict

Implement OrderedDict in RPython
