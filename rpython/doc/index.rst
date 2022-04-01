.. _index:

Welcome to RPython's documentation!
===================================

RPython is a translation and support framework for producing implementations of
dynamic languages, emphasizing a clean separation between language
specification and implementation aspects.

By separating concerns in this way, our implementation of Python - and other
dynamic languages - is able to automatically generate a Just-in-Time compiler
for any dynamic language.  It also allows a mix-and-match approach to
implementation decisions, including many that have historically been outside of
a user's control, such as target platform, memory and threading models, garbage
collection strategies, and optimizations applied, including whether or not to
have a JIT in the first place.


General
-------

.. toctree::
   :maxdepth: 1

   architecture
   faq

User Documentation
------------------

These documents are mainly interesting for users of interpreters written in
RPython.

.. toctree::
   :maxdepth: 1

   arm
   logging


Writing your own interpreter in RPython
---------------------------------------

.. toctree::
   :maxdepth: 1

   rpython
   rlib
   rffi
   examples
   rstrategies


RPython internals
-----------------

.. toctree::
   :maxdepth: 1

   glossary
   getting-started
   dir-reference
   jit/index
   arch/index
   translation
   rtyper
   garbage_collection


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
