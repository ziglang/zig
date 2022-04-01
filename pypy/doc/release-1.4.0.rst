===============================
PyPy 1.4: Ouroboros in practice
===============================

We're pleased to announce the 1.4 release of PyPy. This is a major breakthrough
in our long journey, as PyPy 1.4 is the first PyPy release that can translate
itself faster than CPython.  Starting today, we are using PyPy more for
our every-day development.  So may you :) You can download it here:

    https://pypy.org/download.html

What is PyPy
============

PyPy is a very compliant Python interpreter, almost a drop-in replacement
for CPython. It's fast (`pypy 1.4 and cpython 2.6`_ comparison)

Among its new features, this release includes numerous performance improvements
(which made fast self-hosting possible), a 64-bit JIT backend, as well
as serious stabilization. As of now, we can consider the 32-bit and 64-bit
linux versions of PyPy stable enough to run `in production`_.

Numerous speed achievements are described on `our blog`_. Normalized speed
charts comparing `pypy 1.4 and pypy 1.3`_ as well as `pypy 1.4 and cpython 2.6`_
are available on benchmark website. For the impatient: yes, we got a lot faster!

More highlights
===============

* PyPy's built-in Just-in-Time compiler is fully transparent and
  automatically generated; it now also has very reasonable memory
  requirements.  The total memory used by a very complex and
  long-running process (translating PyPy itself) is within 1.5x to
  at most 2x the memory needed by CPython, for a speed-up of 2x.

* More compact instances.  All instances are as compact as if
  they had ``__slots__``.  This can give programs a big gain in
  memory.  (In the example of translation above, we already have
  carefully placed ``__slots__``, so there is no extra win.)

* `Virtualenv support`_: now PyPy is fully compatible with virtualenv_: note that
  to use it, you need a recent version of virtualenv (>= 1.5).

* Faster (and JITted) regular expressions - huge boost in speeding up
  the `re` module.

* Other speed improvements, like JITted calls to functions like map().

.. _virtualenv: https://pypi.python.org/pypi/virtualenv
.. _`Virtualenv support`: https://morepypy.blogspot.com/2010/08/using-virtualenv-with-pypy.html
.. _`in production`: https://morepypy.blogspot.com/2010/11/running-large-radio-telescope-software.html
.. _`our blog`: https://morepypy.blogspot.com
.. _`pypy 1.4 and pypy 1.3`: https://speed.pypy.org/comparison/?exe=1%2B41,1%2B172&ben=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20&env=1&hor=false&bas=1%2B41&chart=normal+bars
.. _`pypy 1.4 and cpython 2.6`: https://speed.pypy.org/comparison/?exe=2%2B35,1%2B172&ben=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20&env=1&hor=false&bas=2%2B35&chart=normal+bars

Cheers,

Carl Friedrich Bolz, Antonio Cuni, Maciej Fijalkowski,
Amaury Forgeot d'Arc, Armin Rigo and the PyPy team
