==================================
PyPy 1.2: Just-in-Time Compilation
==================================

Welcome to the PyPy 1.2 release.  The highlight of this release is
to be the first that ships with a Just-in-Time compiler that is
known to be faster than CPython (and unladen swallow) on some
real-world applications (or the best benchmarks we could get for
them).  The main theme for the 1.2 release is speed.

Main site:

    https://pypy.org/

The JIT is stable and we don't observe crashes. Nevertheless we
would recommend you to treat it as beta software and as a way to try
out the JIT to see how it works for you.


Highlights of This Release
==========================

* The JIT compiler.

* Various interpreter optimizations that improve performance
  as well as help save memory.

* Introducing a new PyPy website at https://pypy.org/ , made by
  tav and improved by the PyPy team.

* Introducing https://speed.pypy.org/ , a new service that
  monitors our performance nightly, made by Miquel Torres.

* There will be ubuntu packages on "PyPy's PPA" made by
  Bartosz Skowron; however various troubles prevented us from
  having them as of now.


Known JIT problems (or why you should consider this beta software):

* The only supported platform is 32bit x86 for now, we're
  looking for help with other platforms.

* It is still memory-hungry.  There is no limit on the amount
  of RAM that the assembler can consume; it is thus possible
  (although unlikely) that the assembler ends up using
  unreasonable amounts of memory.


If you want to try PyPy, go to the "download page" on our excellent
new site at https://pypy.org/download.html and find the binary for
your platform. If the binary does not work (e.g. on Linux, because
of different versions of external .so dependencies), or if your
platform is not supported, you can try building from the source.


What is PyPy?
=============

Technically, PyPy is both a Python interpreter implementation and an
advanced compiler, or more precisely a framework for implementing
dynamic languages and generating virtual machines for them.  The
focus of this release is the introduction of a new transformation,
the JIT Compiler Generator, and its application to the Python
interpreter.

Socially, PyPy is a collaborative effort of many individuals working
together in a distributed and sprint-driven way since 2003.  PyPy
would not have gotten as far as it has without the coding, feedback
and general support from numerous people.


The PyPy release team,
    Armin Rigo, Maciej Fijalkowski and Amaury Forgeot d'Arc

Together with
    Antonio Cuni, Carl Friedrich Bolz, Holger Krekel and
    Samuele Pedroni

and many others:
    https://codespeak.net/pypy/dist/pypy/doc/contributor.html
