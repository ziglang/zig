======================
PyPy 1.5: Catching Up
======================

We're pleased to announce the 1.5 release of PyPy. This release updates
PyPy with the features of CPython 2.7.1, including the standard library. Thus
all the features of `CPython 2.6`_ and `CPython 2.7`_ are now supported. It
also contains additional performance improvements. You can download it here:

    https://pypy.org/download.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7.1. It's fast (`pypy 1.5 and cpython 2.6.2`_ performance comparison)
due to its integrated tracing JIT compiler.

This release includes the features of CPython 2.6 and 2.7. It also includes a
large number of small improvements to the tracing JIT compiler. It supports
Intel machines running Linux 32/64 or Mac OS X.  Windows is beta (it roughly
works but a lot of small issues have not been fixed so far).  Windows 64 is
not yet supported.

Numerous speed achievements are described on `our blog`_. Normalized speed
charts comparing `pypy 1.5 and pypy 1.4`_ as well as `pypy 1.5 and cpython
2.6.2`_ are available on our benchmark website. The speed improvement over 1.4
seems to be around 25% on average.

More highlights
===============

- The largest change in PyPy's tracing JIT is adding support for `loop invariant
  code motion`_, which was mostly done by Håkan Ardö. This feature improves the
  performance of tight loops doing numerical calculations.

- The CPython extension module API has been improved and now supports many more
  extensions.

- These changes make it possible to support `Tkinter and IDLE`_.

- The `cProfile`_ profiler is now working with the JIT. However, it skews the
  performance in unstudied ways. Therefore it is not yet usable to analyze
  subtle performance problems (the same is true for CPython of course).

- There is an `external fork`_ which includes an RPython version of the
  ``postgresql``.  However, there are no prebuilt binaries for this.

- Our developer documentation was moved to Sphinx and cleaned up.
  (click 'Dev Site' on https://pypy.org/ .)

- and many small things :-)


Cheers,

Carl Friedrich Bolz, Laura Creighton, Antonio Cuni, Maciej Fijalkowski,
Amaury Forgeot d'Arc, Alex Gaynor, Armin Rigo and the PyPy team


.. _`CPython 2.6`: https://docs.python.org/dev/whatsnew/2.6.html
.. _`CPython 2.7`: https://docs.python.org/dev/whatsnew/2.7.html

.. _`our blog`: https://morepypy.blogspot.com
.. _`pypy 1.5 and pypy 1.4`: https://bit.ly/joPhHo
.. _`pypy 1.5 and cpython 2.6.2`: https://bit.ly/mbVWwJ

.. _`loop invariant code motion`: https://morepypy.blogspot.com/2011/01/loop-invariant-code-motion.html
.. _`Tkinter and IDLE`: https://morepypy.blogspot.com/2011/04/using-tkinter-and-idle-with-pypy.html
.. _`cProfile`: https://docs.python.org/library/profile.html
.. _`external fork`: https://bitbucket.org/alex_gaynor/pypy-postgresql
