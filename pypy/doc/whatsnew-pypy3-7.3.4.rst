=========================
What's new in PyPy3 7.3.4
=========================

.. this is the revision after release-pypy3.6-v7.3.3
.. startrev: a57ea1224248

.. branches merged to py3.6 and are not reported in the test. Re-enable
    these lines for the release or when fixing the test
    .. branch: py3.6-resync

    .. branch: fix-crypt-py3-import

    Fix bad merge of crypt cffi module

    .. branch: issue3348

    Fix utf_8_decode for final=False, error=ignore

.. 3.8 branches  ------------------------

.. branch: fstring-debugging
Add support for the debugging sigil ``=`` in f-strings.

.. branch: some-other-38-features
Implement ``typed_ast`` features in the ``ast``-module.

.. branch: some-3.8-features
Implement named expression (the walrus operator ``:=``).


.. 3.7 branches -----------------------------------------

.. branch: py3.7-rsre

Fix rsre module for python 3.7

.. branch: incremental_decoder

Fix utf_8_decode for final=False 


.. branch: refactor-posonly

Refactor how positional-only arguments are represented in signature objects,
which brings it more in line with Python 3.8, and simplifies the code.

.. branch: const

Change `char *`` to ``const char *`` in ``PyStructSequence_Field``,
``PyStructSequence_Desc``, ``PyGetSetDef``, ``wrapperbase``

.. branch: win64-py3.7

Merge win64 into this branch

.. branch: win64-cpyext

Fix the cpyext module for win64

.. branch: py3.7-winreg

Fix various problems with ``winreg``: add ``REG_QWORD``, implement reflection
on win64, (bpo-21151) preserve None passed as ``REG_BINARY``, (bpo-25778),
truncate ``REG_SZ`` at first ``NULL``, use surrogatepass in ``UTF-16`` decoding
(issue 3342).

.. branch: py3.7-win64-hash

Prevent overflow in ``_hash_long`` on win64 using method from CPython, and
speed it up.

.. branch: issue-3371

Allow compiler to inherit flags from ``__future__.annotations``. Fixes
``>>> x : X``

.. branch: win32consoleio2

Re-enable ``_io.win32console`` on windows

.. branch: meth-fastcall

Implement METH_FASTCALL

.. branch: py3.7-win64-cpyext-longobject 

Fix ``cpyext.longobject`` for win64

.. branch: py3.7-big-sur-dyld-cache

Fix loading system libraries with ctypes on macOS Big Sur. (issue 3314)

.. branch: map-improvements-3.7

Port map-improvements to py3.7

.. branch: win64-hpy

Enable _hpy_universal on win64

.. branch: vendor/stdlib-3.7

Update stdlib to 3.7.10

.. branch: fix-issue-3181

Fix ElementTree.extend not working on iterators (issue 3181 and bpo43399)
