Frequently Asked Questions
==========================

.. contents::

See also: `Frequently ask questions about RPython.`__

.. __: https://rpython.readthedocs.org/en/latest/faq.html

---------------------------


What is PyPy?
-------------

PyPy is a reimplementation of Python in Python, using the RPython translation
toolchain.

PyPy tries to find new answers about ease of creation, flexibility,
maintainability and speed trade-offs for language implementations.
For further details see our :doc:`goal and architecture document <architecture>`.


Is PyPy a drop in replacement for CPython?
------------------------------------------

Almost!

The most likely stumbling block for any given project is support for
:ref:`extension modules <extension-modules>`.  PyPy supports a continually growing
number of extension modules, but so far mostly only those found in the
standard library.

The language features (including builtin types and functions) are very
refined and well tested, so if your project doesn't use many
extension modules there is a good chance that it will work with PyPy.

We list the known differences in :doc:`cpython differences <cpython_differences>`.


Module xyz does not work with PyPy: ImportError
-----------------------------------------------

A module installed for CPython is not automatically available for PyPy
--- just like a module installed for CPython 2.6 is not automatically
available for CPython 2.7 if you installed both.  In other words, you
need to install the module xyz specifically for PyPy.

On Linux, this means that you cannot use ``apt-get`` or some similar
package manager: these tools are only meant *for the version of CPython
provided by the same package manager.*  So forget about them for now
and read on.

It is quite common nowadays that xyz is available on PyPI_ and
installable with ``<pypy> -mpip install xyz``.  The simplest solution is to
`use virtualenv (as documented here)`_.  Then enter (activate) the virtualenv
and type: ``pypy -mpip install xyz``.  If you don't know or don't want
virtualenv, you can also use ``pip`` locally after ``pypy -m ensurepip``.
The `ensurepip module`_ is built-in to the PyPy downloads we provide.
Best practices with ``pip`` is to always call it as ``<python> -mpip ...``,
but if you wish to be able to call ``pip`` directly from the command line, you
must call ``pypy -mensurepip --default-pip``.

If you get errors from the C compiler, the module is a CPython C
Extension module using unsupported features.  `See below.`_

Alternatively, if either the module xyz is not available on PyPI or you
don't want to use virtualenv, then download the source code of xyz,
decompress the zip/tarball, and run the standard command: ``pypy
setup.py install``.  (Note: `pypy` here instead of `python`.)  As usual
you may need to run the command with `sudo` for a global installation.
The other commands of ``setup.py`` are available too, like ``build``.

.. _PyPI: https://pypi.org
.. _`use virtualenv (as documented here)`: install.html#installing-using-virtualenv
.. _`ensurepip module`: https://docs.python.org/3.6/library/ensurepip.html


Module xyz does not work in the sandboxed PyPy?
-----------------------------------------------

You cannot import *any* extension module in a `sandboxed PyPy`_,
sorry.  Even the built-in modules available are very limited.
Sandboxing in PyPy is a good proof of concept, and is without a doubt
safe IMHO, however it is only a proof of concept.  It currently requires 
some work from a motivated developer. However, until then it can only be used for "pure Python"
example: programs that import mostly nothing (or only pure Python
modules, recursively).

.. _`sandboxed PyPy`: sandbox.html


.. _`See below.`:

Do C-extension modules work with PyPy?
--------------------------------------

**First note that some Linux distributions (e.g. Ubuntu, Debian) split
PyPy into several packages.  If you installed a package called "pypy",
then you may also need to install "pypy-dev" for the following to work.**

We have support for c-extension modules (modules written using the C-API), so
they run without modifications.  This has been a part of PyPy since
the 1.4 release, and support is almost complete.  CPython
extension modules in PyPy are often much slower than in CPython due to
the need to emulate refcounting.  It is often faster to take out your
c-extension and replace it with a pure python or CFFI version that the
JIT can optimize.  If trying to install module xyz, and the module has both
a C and a Python version of the same code, try first to disable the C
version; this is usually easily done by changing some line in ``setup.py``.

We fully support ctypes-based extensions. But for best performance, we
recommend that you use the cffi_ module to interface with C code.

For more information about how we manage refcounting semamtics see 
rawrefcount_

.. _cffi: https://cffi.readthedocs.org/
.. _rawrefcount: discussion/rawrefcount.html   


On which platforms does PyPy run?
---------------------------------

PyPy currently supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32/64 bits, OpenBSD, FreeBSD),
  
  * 64-bit **AArch**, also known as ARM64,

  * **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux
    (we no longer provide prebuilt binaries for these),
  
  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

PyPy is regularly and extensively tested on Linux machines. It
works on Mac and Windows: it is tested there, but most of us are running
Linux so fixes may depend on 3rd-party contributions.

To bootstrap from sources, PyPy can use either CPython 2.7 or
another (e.g. older) PyPy.  Cross-translation is not really supported:
e.g. to build a 32-bit PyPy, you need to have a 32-bit environment.

Which Python version (2.x?) does PyPy implement?
------------------------------------------------

PyPy comes in two versions:

* one is fully compatible with Python 2.7;

* the other is fully compatible with one 3.x version.  At the time of
  this writing, this is 3.7.


.. _threading:

Does PyPy have a GIL?  Why?
-------------------------------------------------

Yes, PyPy has a GIL.  Removing the GIL is very hard.  On top of CPython,
you have two problems:  (1) GC, in this case reference counting; (2) the
whole Python language.

For PyPy, the hard issue is (2): by that I mean issues like what occurs
if a mutable object is changed from one thread and read from another
concurrently.  This is a problem for *any* mutable type: it needs
careful review and fixes (fine-grained locks, mostly) through the
*whole* Python interpreter.  It is a major effort, although not
completely impossible, as Jython/IronPython showed.  This includes
subtle decisions about whether some effects are ok or not for the user
(i.e. the Python programmer).

CPython has additionally the problem (1) of reference counting.  With
PyPy, this sub-problem is simpler: we need to make our GC
multithread-aware.  This is easier to do efficiently in PyPy than in
CPython.  It doesn't solve the issue (2), though.

Note that there was work to support a
:doc:`Software Transactional Memory <stm>` (STM) version of PyPy.  This
should give an alternative PyPy which works without a GIL, while at the
same time continuing to give the Python programmer the complete illusion
of having one.  This work is currently a bit stalled because of its own
technical difficulties.

What about numpy, numpypy, micronumpy?
--------------------------------------

Way back in 2011, the PyPy team `started to reimplement`_ numpy in PyPy.  It
has two pieces:

  * the builtin module :source:`pypy/module/micronumpy`: this is written in
    RPython and roughly covers the content of the ``numpy.core.multiarray``
    module. Confusingly enough, this is available in PyPy under the name
    ``_numpypy``.  It is included by default in all the official releases of
    PyPy (but it might be dropped in the future).

  * a fork_ of the official numpy repository maintained by us and informally
    called ``numpypy``: even more confusing, the name of the repo on bitbucket
    is ``numpy``.  The main difference with the upstream numpy, is that it is
    based on the micronumpy module written in RPython, instead of of
    ``numpy.core.multiarray`` which is written in C.


Should I install numpy or numpypy?
-----------------------------------

TL;DR version: you should use numpy. You can install it by doing ``pypy -m pip
install numpy``.  You might also be interested in using the experimental `PyPy
binary wheels`_ to save compilation time.

The upstream ``numpy`` is written in C, and runs under the cpyext
compatibility layer.  Nowadays, cpyext is mature enough that you can simply
use the upstream ``numpy``, since it passes the test suite. At the
moment of writing (October 2017) the main drawback of ``numpy`` is that cpyext
is infamously slow, and thus it has worse performance compared to
``numpypy``. However, we are actively working on improving it, as we expect to
reach the same speed when HPy_ can be used.

On the other hand, ``numpypy`` is more JIT-friendly and very fast to call,
since it is written in RPython: but it is a reimplementation, and it's hard to
be completely compatible: over the years the project slowly matured and
eventually it was able to call out to the LAPACK and BLAS libraries to speed
matrix calculations, and reached around an 80% parity with the upstream
numpy. However, 80% is far from 100%.  Since cpyext/numpy compatibility is
progressing fast, we have discontinued support for ``numpypy``.

.. _`started to reimplement`: https://morepypy.blogspot.co.il/2011/05/numpy-in-pypy-status-and-roadmap.html
.. _fork: https://bitbucket.org/pypy/numpy
.. _`PyPy binary wheels`: https://github.com/antocuni/pypy-wheels
.. _HPy: https://morepypy.blogspot.com/2019/12/hpy-kick-off-sprint-report.html

Is PyPy more clever than CPython about Tail Calls?
--------------------------------------------------

No.  PyPy follows the Python language design, including the built-in
debugger features.  This prevents tail calls, as summarized by Guido
van Rossum in two__ blog__ posts.  Moreover, neither the JIT nor
Stackless__ change anything to that.

.. __: https://neopythonic.blogspot.com/2009/04/tail-recursion-elimination.html
.. __: https://neopythonic.blogspot.com/2009/04/final-words-on-tail-calls.html
.. __: stackless.html


How do I write extension modules for PyPy?
------------------------------------------

See :doc:`extending`.


.. _how-fast-is-pypy:

How fast is PyPy?
-----------------
This really depends on your code.
For pure Python algorithmic code, it is very fast.  For more typical
Python programs we generally are 3 times the speed of CPython 2.7.
You might be interested in our `benchmarking site`_ and our
:ref:`jit documentation <rpython:jit>`.

`Your tests are not a benchmark`_: tests tend to be slow under PyPy
because they run exactly once; if they are good tests, they exercise
various corner cases in your code.  This is a bad case for JIT
compilers.  Note also that our JIT has a very high warm-up cost, meaning
that any program is slow at the beginning.  If you want to compare the
timings with CPython, even relatively simple programs need to run *at
least* one second, preferrably at least a few seconds.  Large,
complicated programs need even more time to warm-up the JIT.

.. _benchmarking site: https://speed.pypy.org

.. _your tests are not a benchmark: https://alexgaynor.net/2013/jul/15/your-tests-are-not-benchmark/

I wrote a 3-lines benchmark and it's not faster than CPython.  Why?
-------------------------------------------------------------------

Three-lines benchmarks are benchmarks that either do absolutely nothing (in
which case PyPy is probably a lot faster than CPython), or more likely, they
are benchmarks that spend most of their time doing things in C.

For example, a loop that repeatedly issues one complex SQL operation will only
measure how performant the SQL database is.  Similarly, computing many elements
from the Fibonacci series builds very large integers, so it only measures how
performant the long integer library is.  This library is written in C for
CPython, and in RPython for PyPy, but that boils down to the same thing.

PyPy speeds up the code written *in Python*.


Couldn't the JIT dump and reload already-compiled machine code?
---------------------------------------------------------------

No, we found no way of doing that.  The JIT generates machine code
containing a large number of constant addresses --- constant at the time
the machine code is generated.  The vast majority is probably not at all
constants that you find in the executable, with a nice link name.  E.g.
the addresses of Python classes are used all the time, but Python
classes don't come statically from the executable; they are created anew
every time you restart your program.  This makes saving and reloading
machine code completely impossible without some very advanced way of
mapping addresses in the old (now-dead) process to addresses in the new
process, including checking that all the previous assumptions about the
(now-dead) object are still true about the new object.



Would type annotations help PyPy's performance?
-----------------------------------------------

Two examples of type annotations that are being proposed for improved
performance are `Cython types`__ and `PEP 484 - Type Hints`__.

.. __: https://docs.cython.org/src/reference/language_basics.html#declaring-data-types
.. __: https://www.python.org/dev/peps/pep-0484/

**Cython types** are, by construction, similar to C declarations.  For
example, a local variable or an instance attribute can be declared
``"cdef int"`` to force a machine word to be used.  This changes the
usual Python semantics (e.g. no overflow checks, and errors when
trying to write other types of objects there).  It gives some extra
performance, but the exact benefits are unclear: right now
(January 2015) for example we are investigating a technique that would
store machine-word integers directly on instances, giving part of the
benefits without the user-supplied ``"cdef int"``.

**PEP 484 - Type Hints,** on the other hand, is almost entirely
useless if you're looking at performance.  First, as the name implies,
they are *hints:* they must still be checked at runtime, like PEP 484
says.  Or maybe you're fine with a mode in which you get very obscure
crashes when the type annotations are wrong; but even in that case the
speed benefits would be extremely minor.

There are several reasons for why.  One of them is that annotations
are at the wrong level (e.g. a PEP 484 "int" corresponds to Python 3's
int type, which does not necessarily fits inside one machine word;
even worse, an "int" annotation allows arbitrary int subclasses).
Another is that a lot more information is needed to produce good code
(e.g. "this ``f()`` called here really means this function there, and
will never be monkey-patched" -- same with ``len()`` or ``list()``,
btw).  The third reason is that some "guards" in PyPy's JIT traces
don't really have an obvious corresponding type (e.g. "this dict is so
far using keys which don't override ``__hash__`` so a more efficient
implementation was used").  Many guards don't even have any correspondence
with types at all ("this class attribute was not modified"; "the loop
counter did not reach zero so we don't need to release the GIL"; and
so on).

As PyPy works right now, it is able to derive far more useful
information than can ever be given by PEP 484, and it works
automatically.  As far as we know, this is true even if we would add
other techniques to PyPy, like a fast first-pass JIT.



.. _`prolog and javascript`:

Can I use PyPy's translation toolchain for other languages besides Python?
--------------------------------------------------------------------------

Yes. The toolsuite that translates the PyPy interpreter is quite
general and can be used to create optimized versions of interpreters
for any language, not just Python.  Of course, these interpreters
can make use of the same features that PyPy brings to Python:
translation to various languages, stackless features,
garbage collection, implementation of various things like arbitrarily long
integers, etc.

Currently, we have `Topaz`_, a Ruby interpreter; `Hippy`_, a PHP
interpreter; preliminary versions of a `JavaScript interpreter`_
(Leonardo Santagada as his Summer of PyPy project); a `Prolog interpreter`_
(Carl Friedrich Bolz as his Bachelor thesis); and a `SmallTalk interpreter`_
(produced during a sprint).  On the `PyPy bitbucket page`_ there is also a
Scheme and an Io implementation; both of these are unfinished at the moment.

.. _Topaz: https://github.com/topazproject/topaz
.. _Hippy: https://morepypy.blogspot.ch/2012/07/hello-everyone.html
.. _JavaScript interpreter: https://bitbucket.org/pypy/lang-js/
.. _Prolog interpreter: https://bitbucket.org/cfbolz/pyrolog/
.. _SmallTalk interpreter: https://dx.doi.org/10.1007/978-3-540-89275-5_7
.. _PyPy bitbucket page: https://bitbucket.org/pypy/


How do I get into PyPy development?  Can I come to sprints?
-----------------------------------------------------------

Certainly you can come to sprints! We always welcome newcomers and try
to help them as much as possible to get started with the project.  We
provide tutorials and pair them with experienced PyPy
developers. Newcomers should have some Python experience and read some
of the PyPy documentation before coming to a sprint.

Coming to a sprint is usually the best way to get into PyPy development.
If you get stuck or need advice, :doc:`contact us <index>`. IRC is
the most immediate way to get feedback (at least during some parts of the day;
most PyPy developers are in Europe) and the `mailing list`_ is better for long
discussions.

We also encourage engagement via the gitlab repo at
https://foss.heptapod.net/pypy/pypy. Issues can be filed and discussed in the
`issue tracker`_ and we welcome `merge requests`.

.. _`issue tracker`: https://foss.heptapod.net/heptapod/foss.heptapod.net/-/issues
.. _`merge requests`: https://foss.heptapod.net/heptapod/foss.heptapod.net/-/merge_requests

.. _mailing list: https://mail.python.org/mailman/listinfo/pypy-dev


OSError: ... cannot restore segment prot after reloc... Help?
-------------------------------------------------------------

On Linux, if SELinux is enabled, you may get errors along the lines of
"OSError: externmod.so: cannot restore segment prot after reloc: Permission
denied." This is caused by a slight abuse of the C compiler during
configuration, and can be disabled by running the following command with root
privileges:

.. code-block:: console

    # setenforce 0

This will disable SELinux's protection and allow PyPy to configure correctly.
Be sure to enable it again if you need it!


How should I report a bug?
--------------------------

Our bug tracker is here: https://foss.heptapod.net/pypy/pypy/issues/

Missing features or incompatibilities with CPython are considered
bugs, and they are welcome.  (See also our list of `known
incompatibilities`__.)

.. __: https://pypy.org/compat.html

For bugs of the kind "I'm getting a PyPy crash or a strange
exception", please note that: **We can't do anything without
reproducing the bug ourselves**.  We cannot do anything with
tracebacks from gdb, or core dumps.  This is not only because the
standard PyPy is compiled without debug symbols.  The real reason is
that a C-level traceback is usually of no help at all in PyPy.
Debugging PyPy can be annoying.

`This is a clear and useful bug report.`__  (Admittedly, sometimes
the problem is really hard to reproduce, but please try to.)

.. __: https://foss.heptapod.net/pypy/pypy/issues/2363/segfault-in-gc-pinned-object-in

In more details:

* First, please give the exact PyPy version, and the OS.

* It might help focus our search if we know if the bug can be
  reproduced on a "``pypy --jit off``" or not.  If "``pypy --jit
  off``" always works, then the problem might be in the JIT.
  Otherwise, we know we can ignore that part.

* If you got the bug using only Open Source components, please give a
  step-by-step guide that we can follow to reproduce the problem
  ourselves.  Don't assume we know anything about any program other
  than PyPy.  We would like a guide that we can follow point by point
  (without guessing or having to figure things out)
  on a machine similar to yours, starting from a bare PyPy, until we
  see the same problem.  (If you can, you can try to reduce the number
  of steps and the time it needs to run, but that is not mandatory.)

* If the bug involves Closed Source components, or just too many Open
  Source components to install them all ourselves, then maybe you can
  give us some temporary ssh access to a machine where the bug can be
  reproduced.  Or, maybe we can download a VirtualBox or VMWare
  virtual machine where the problem occurs.

* If giving us access would require us to use tools other than ssh,
  make appointments, or sign a NDA, then we can consider a commerical
  support contract for a small sum of money.

* If even that is not possible for you, then sorry, we can't help.

Of course, you can try to debug the problem yourself, and we can help
you get started if you ask on the #pypy IRC channel, but be prepared:
debugging an annoying PyPy problem usually involves quite a lot of gdb
in auto-generated C code, and at least some knowledge about the
various components involved, from PyPy's own RPython source code to
the GC and possibly the JIT.


.. _git:
.. _github:

Why doesn't PyPy use Git and move to GitHub?
---------------------------------------------

We discussed it during the switch away from bitbucket.  We concluded that (1)
the Git workflow is not as well suited as the Mercurial workflow for our style,
and (2) moving to github "just because everybody else does" is a argument on
thin grounds.

For (1), there are a few issues, but maybe the most important one is that the
PyPy repository has got thousands of *named* branches.  Git has no equivalent
concept.  Git has *branches,* of course, which in Mercurial are called
bookmarks.  We're not talking about bookmarks.

The difference between git branches and named branches is not that important in
a repo with 10 branches (no matter how big).  But in the case of PyPy, we have
at the moment 1840 branches.  Most are closed by now, of course.  But we would
really like to retain (both now and in the future) the ability to look at a
commit from the past, and know in which branch it was made.  Please make sure
you understand the difference between the Git and the Mercurial branches to
realize that this is not always possible with Git--- we looked hard, and there
is no built-in way to get this workflow.

Still not convinced?  Consider this git repo with three commits: commit #2 with
parent #1 and head of git branch "A"; commit #3 with also parent #1 but head of
git branch "B".  When commit #1 was made, was it in the branch "A" or "B"?
(It could also be yet another branch whose head was also moved forward, or even
completely deleted.)


What is needed for better Windows 64 support of PyPy?
-----------------------------------------------------

As of PyPy 7.3.5, PyPy supports Windows 64-bits. Since only on that platform
``sizeof(long) != sizeof(void *)``, and the underlying data type for RPython is
``long``, this proved to be challenging. It seems we have crossed that bridge,
and welcome help in bringing the Windows version into parity with CPython. In
particular, we still do not support Windows-specific features like
``winconsoleio``, windows audit events, and the Windows ``faulthandler``.
Performance may lag behind Linux64, and the ``wininstaller`` branch is still
unfinished.

Help is welcome!

How long will PyPy support Python2?
-----------------------------------

Since RPython is built on top of Python2 and that is extremely unlikely to
change, the Python2 version of PyPy will be around "forever", i.e. as long as
PyPy itself is around.
