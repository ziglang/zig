:orphan:

.. _windows64:

64 bit PyPy and Windows
=======================

Getting 64-bit windows to work with PyPy was a long-standing request that was
finally cracked in the otherwise cursed year of 2020. The problem is that we
assume that the integer type of RPython (``rffi.Signed``) is
large enough to (occasionally) contain a pointer value cast to an
integer. On most platforms the corresponding C type of ``long`` satisfies this
condition. But on 64-bit windows, a ``long`` is 32-bits, while
``sizeof(void*)`` is 64-bits. The simplest fix is to make sure that
``rffi.Signed`` can hold a 64-bit integer, which resutls in a python2 with the
following incompatibility between CPython and PyPy on Win64:

CPython: ``sys.maxint == 2**31-1, sys.maxsize == 2**63-1``

PyPy: ``sys.maxint == sys.maxsize == 2**63-1``

...and, correspondingly, PyPy2 supports ints up to the larger value of
sys.maxint before they are converted to ``long``.

What we did
-----------

The first thing done was to do hack a *CPython2*
until it fits this model: replace the field in PyIntObject with a ``long
long`` field, and change the value of ``sys.maxint``.  This is available in
`nulano's branch of cpython`_ (again: this is **python2**).

This hacked pyton was used in the next steps.  We'll call it CPython64/64.

First the tests in
``rpython/translator/c/test/``, like ``test_standalone.py`` and
``test_newgc.py`` were made to pass on top of CPython64/64.

This runs small translations, and some details were
wrong.  The most obvious one is to make 
the integer type ``Signed`` 
equal to ``long`` on every other platform, but on Win64 it
should be something like ``long long``.

Then a more generally review of all the C files in
``rpython/translator/c/src`` for the word ``long``, which means a
32-bit integer even on Win64, replaced it with ``Signed``.

Then, these two C types have corresponding RPython types: ``rffi.LONG``
and ``lltype.Signed`` respectively.  The first should really correspond
to the C ``long``, as verified by the ``test_rffi_sizeof`` test. The
size of the latter is verified in ``rpython/rlib/rarithmetic``.

Once these basic tests worked, we reviewed ``rpython/rlib/`` for
uses of ``rffi.LONG`` versus ``lltype.Signed``.  The goal was to
fix some more ``LONG-versus-Signed`` issues, by fixing the tests --- as
always run on top of CPython64/64.  Note that there was some early work
done in ``rarithmetic`` with the goal of running all the
tests on Win64 on the regular CPython, but this early work was abandoned as a
bad idea.  Look only at CPython64/64.

This was enough to get a translation of PyPy with ``-O2``
with a minimal set of modules, starting with ``--no-allworkingmodules``;
using CPython64/64 to run this translation too.  Careful checking of
the warnings of the C compiler at the end revealed more places that needed
work. By default, MSVC
reports a lot of mismatches of integer sizes as warnings instead of
errors.

Then we reviewed ``pypy/module/*/`` for ``LONG-versus-Signed``
issues.  This got us a working translated
PyPy on Windows 64 that includes all ``--translationmodules``, i.e.
everything needed to run translations.  Once we had that, the hacked
CPython64/64 becomes much less important, because we can run future
translations on top of this translated PyPy.  This made it to the nightly
builds on the default branch, and needs to be used by anyone else who wants to
working on Win64. The whole process
ends up with a strange kind of dependency --- we need a translated PyPy in
order to translate a PyPy ---, but that's ok here, as Windows executables are
supposed to never be broken by newer versions of Windows.

Happy hacking :-)

.. _`nulano's branch of cpython`: https://github.com/nulano/cpython
.. 
