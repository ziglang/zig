========================
What's new in PyPy 2.2.1
========================

.. this is a revision shortly after release-2.2.x
.. startrev: 4cd1bc8b3111

.. branch: release-2.2.x

.. branch: numpy-newbyteorder

Clean up numpy types, add newbyteorder functionality

.. branch: windows-packaging

Package tk/tcl runtime with win32

.. branch: armhf-singlefloat

JIT support for singlefloats on ARM using the hardfloat ABI

.. branch: voidtype_strformat

Better support for record numpy arrays

.. branch: osx-eci-frameworks-makefile

OSX: Ensure frameworks end up in Makefile when specified in External compilation info

.. branch: less-stringly-ops

Use subclasses of SpaceOperation instead of SpaceOperator objects.
Random cleanups in flowspace and annotator.

.. branch: ndarray-buffer

adds support for the buffer= argument to the ndarray ctor

.. branch: better_ftime_detect2

On OpenBSD do not pull in libcompat.a as it is about to be removed.
And more generally, if you have gettimeofday(2) you will not need ftime(3).

.. branch: timeb_h

Remove dependency upon <sys/timeb.h> on OpenBSD. This will be disappearing
along with libcompat.a.

.. branch: OlivierBlanvillain/fix-3-broken-links-on-pypy-published-pap-1386250839215

Fix 3 broken links on PyPy published papers in docs.

.. branch: jit-ordereddict

.. branch: refactor-str-types

Remove multimethods on str/unicode/bytearray and make the implementations share code.

.. branch: remove-del-from-generatoriterator

Speed up generators that don't yield inside try or wait blocks by skipping
unnecessary cleanup.

.. branch: annotator

Remove FlowObjSpace.
Improve cohesion between rpython.flowspace and rpython.annotator.

.. branch: detect-immutable-fields

mapdicts keep track of whether or not an attribute is every assigned to
multiple times. If it's only assigned once then an elidable lookup is used when
possible.

.. branch: precompiled-headers

Create a Makefile using precompiled headers for MSVC platforms.
The downside is a messy nmake-compatible Makefile. Since gcc shows minimal
speedup, it was not implemented.

.. branch: camelot

With a properly configured 256-color terminal (TERM=...-256color), the
Mandelbrot set shown during translation now uses a range of 50 colours.
Essential!

.. branch: NonConstant

Simplify implementation of NonConstant.

.. branch: array-propagate-len

Kill some guards and operations in JIT traces by adding integer bounds
propagation for getfield_(raw|gc) and getarrayitem_(raw|gc).

.. branch: optimize-int-and

Optimize away INT_AND with constant mask of 1s that fully cover the bitrange
of other operand.

.. branch: bounds-int-add-or

Propagate appropriate bounds through INT_(OR|XOR|AND) operations if the
operands are positive to kill some guards

.. branch: remove-intlong-smm

kills int/long/smalllong/bool multimethods

.. branch: numpy-refactor

Cleanup micronumpy module

.. branch: int_w-refactor

In a lot of places CPython allows objects with __int__ and __float__ instead of actual ints and floats, while until now pypy disallowed them. We fix it by making space.{int_w,float_w,etc.} accepting those objects by default, and disallowing conversions only when explicitly needed.

.. branch: test-58c3d8552833

Fix for getarrayitem_gc_pure optimization

.. branch: simple-range-strategy

Implements SimpleRangeListStrategy for case range(n) where n is a positive number.
Makes some traces nicer by getting rid of multiplication for calculating loop counter
and propagates that n > 0 further to get rid of guards.

.. branch: popen-pclose

Provide an exit status for popen'ed RFiles via pclose

.. branch: stdlib-2.7.6

Update stdlib to v2.7.6

.. branch: virtual-raw-store-load

Support for virtualizing raw_store/raw_load operations

.. branch: refactor-buffer-api

Separate the interp-level buffer API from the buffer type exposed to
app-level.  The `Buffer` class is now used by `W_MemoryView` and
`W_Buffer`, which is not present in Python 3.  Previously `W_Buffer` was
an alias to `Buffer`, which was wrappable itself.

.. branch: improve-consecutive-dict-lookups

Improve the situation when dict lookups of the same key are performed in a chain

.. branch: add_PyErr_SetFromErrnoWithFilenameObject_try_2
.. branch: test_SetFromErrnoWithFilename_NULL
.. branch: test_SetFromErrnoWithFilename__tweaks

.. branch: refactor_PyErr_SetFromErrnoWithFilename

Add support for PyErr_SetFromErrnoWithFilenameObject to cpyext

.. branch: win32-fixes4

fix more tests for win32

.. branch: latest-improve-doc

Fix broken links in documentation

.. branch: ast-issue1673

fix ast classes __dict__ are always empty problem and fix the ast deepcopy issue when 
there is missing field

.. branch: issue1514

Fix issues with reimporting builtin modules

.. branch: numpypy-nditer

Implement the core of nditer, without many of the fancy flags (external_loop, buffered)

.. branch: numpy-speed

Separate iterator from its state so jit can optimize better

.. branch: numpy-searchsorted

Implement searchsorted without sorter kwarg

.. branch: openbsd-lib-prefix

add 'lib' prefix to link libraries on OpenBSD

.. branch: small-unroll-improvements

Improve optimization of small allocation-heavy loops in the JIT

.. branch: reflex-support

.. branch: asmosoinio/fixed-pip-installation-url-github-githu-1398674840188

.. branch: lexer_token_position_class

.. branch: refactor-buffer-api

Properly implement old/new buffer API for objects and start work on replacing bufferstr usage

.. branch: issue1430

Add a lock for unsafe calls to gethostbyname and gethostbyaddr

.. branch: fix-tpname

Changes hacks surrounding W_TypeObject.name to match CPython's tp_name

.. branch: tkinter_osx_packaging

OS/X specific header path
