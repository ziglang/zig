What is PyPy?
=============

Historically, PyPy has been used to mean two things.  The first is the
:ref:`RPython translation toolchain <rpython:index>` for generating
interpreters for dynamic programming languages.  And the second is one
particular implementation of Python_ produced with it. Because RPython
uses the same syntax as Python, this generated version became known as
Python interpreter written in Python. It is designed to be flexible and
easy to experiment with.

To make it more clear, we start with source code written in RPython,
apply the RPython translation toolchain, and end up with PyPy as a
binary executable. This executable is the Python interpreter.

Double usage has proven to be confusing, so we've moved away from using
the word PyPy to mean both toolchain and generated interpreter.  Now we
use word PyPy to refer to the Python implementation, and explicitly
mention
:ref:`RPython translation toolchain <rpython:index>` when we mean the framework.

Some older documents, presentations, papers and videos will still have the old
usage.  You are hereby warned.

We target a large variety of platforms, small and large, by providing a
compiler toolsuite that can produce custom Python versions.  Platform, memory
and threading models, as well as the JIT compiler itself, are aspects of the
translation process - as opposed to encoding low level details into the
language implementation itself.

For more details, have a look at our :doc:`architecture overview <architecture>`.

.. _Python: https://python.org
.. _
