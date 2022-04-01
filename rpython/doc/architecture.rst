Goals and Architecture Overview
===============================

High Level Goals
----------------

Traditionally, language interpreters are written in a target platform language
such as C/Posix, Java or C#.  Each implementation provides
a fundamental mapping between application source code and the target
environment.  One of
the goals of the "all-encompassing" environments, such as the .NET framework
and to some extent the Java virtual machine, is to provide standardized
and higher level functionalities in order to support language implementers
for writing language implementations.

PyPy is experimenting with a more ambitious approach.  We are using a
subset of the high-level language Python, called :doc:`rpython`, in which we
write languages as simple interpreters with few references to and
dependencies on lower level details.  The RPython toolchain
produces a concrete virtual machine for the platform of our choice by
inserting appropriate lower level aspects.  The result can be customized
by selecting other feature and platform configurations.

Our goal is to provide a possible solution to the problem of language
implementers: having to write ``l * o * p`` interpreters for ``l``
dynamic languages and ``p`` platforms with ``o`` crucial design
decisions.  PyPy aims at making it possible to change each of these
variables independently such that:

* ``l``: the language that we analyze can be evolved or entirely replaced;

* ``o``: we can tweak and optimize the translation process to produce
  platform specific code based on different models and trade-offs;

* ``p``: we can write new translator back-ends to target different
  physical and virtual platforms.

By contrast, a standardized target environment - say .NET -
enforces ``p=1`` as far as it's concerned.  This helps making ``o`` a
bit smaller by providing a higher-level base to build upon.  Still,
we believe that enforcing the use of one common environment
is not necessary.  PyPy's goal is to give weight to this claim - at least
as far as language implementation is concerned - showing an approach
to the ``l * o * p`` problem that does not rely on standardization.

The most ambitious part of this goal is to :doc:`generate Just-In-Time
Compilers <jit/index>` in a language-independent way, instead of only translating
the source interpreter into an interpreter for the target platform.
This is an area of language implementation that is commonly considered
very challenging because of the involved complexity.


Architecture
------------

The job of the RPython toolchain is to translate :doc:`rpython` programs
into an efficient version of that program for one of the various target
platforms, generally one that is considerably lower-level than Python.

The approach we have taken is to reduce the level of abstraction of the
source RPython program in several steps, from the high level down to the
level of the target platform, whatever that may be.  Currently we
support two broad flavours of target platforms: the ones that assume a
C-like memory model with structures and pointers, and the ones that
assume an object-oriented model with classes, instances and methods (as,
for example, the Java and .NET virtual machines do).

The RPython toolchain never sees the RPython source code or syntax
trees, but rather starts with the *code objects* that define the
behaviour of the function objects one gives it as input.  It can be
considered as "freezing" a pre-imported RPython program into an
executable form suitable for the target platform.

The steps of the translation process can be summarized as follows:

* The code object of each source functions is converted to a :ref:`control
  flow graph <flow-model>` by the :ref:`flow graph builder<flow-graphs>`.

* The control flow graphs are processed by the :ref:`Annotator <annotator>`, which
  performs whole-program type inference to annotate each variable of
  the control flow graph with the types it may take at run-time.

* The information provided by the annotator is used by the :doc:`RTyper <rtyper>` to
  convert the high level operations of the control flow graphs into
  operations closer to the abstraction level of the target platform.

* Optionally, `various transformations <optional-transformations>` can then be applied which, for
  example, perform optimizations such as inlining, add capabilities
  such as stackless-style concurrency, or insert code for the
  :doc:`garbage collector <garbage_collection>`.

* Then, the graphs are converted to source code for the target platform
  and compiled into an executable.

This process is described in much more detail in the :doc:`document about
the RPython toolchain <translation>` and in the paper `Compiling dynamic language
implementations`_.

.. _Compiling dynamic language implementations: https://bitbucket.org/pypy/extradoc/raw/tip/eu-report/D05.1_Publish_on_translating_a_very-high-level_description.pdf

Further reading
---------------

 * :doc:`getting-started`: a hands-on guide to getting involved with the
   PyPy source code.

 * `PyPy's approach to virtual machine construction`_: a paper
   presented to the Dynamic Languages Symposium attached to OOPSLA
   2006.

 * :doc:`The translation document <translation>`: a detailed description of our
   translation process.

 * :doc:`JIT Generation in PyPy <jit/index>`, describing how we produce a Just-in-time
   Compiler from an interpreter.

 * A tutorial of how to use the :doc:`RPython toolchain <translation>` to `implement your own
   interpreter`_.

.. _PyPy's approach to virtual machine construction: https://bitbucket.org/pypy/extradoc/raw/tip/talk/dls2006/pypy-vm-construction.pdf
.. _implement your own interpreter: http://morepypy.blogspot.com/2011/04/tutorial-writing-interpreter-with-pypy.html
