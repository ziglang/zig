Logging environment variables
=============================

PyPy, and all other RPython programs, support some special environment
variables used to tweak various advanced parameters.


Garbage collector
-----------------

Right now the default GC is (an incremental version of) MiniMark__.
It has :ref:`a number of environment variables
<minimark-environment-variables>` that can be tweaked.  Their default
value should be ok for most usages.

.. __: garbage_collection.html#minimark-gc


PYPYLOG
-------

The ``PYPYLOG`` environment variable enables debugging output.  For
example::

   PYPYLOG=jit:log

means enabling all debugging output from the JIT, and writing to a
file called ``log``.  More precisely, the condition ``jit`` means
enabling output of all sections whose name start with ``jit``; other
interesting names to use here are ``gc`` to get output from the GC, or
``jit-backend`` to get only output from the JIT's machine code
backend.  It is possible to use several prefixes, like in the
following example::

   PYPYLOG=jit-log-opt,jit-backend:log

which outputs sections containing to the optimized loops plus anything
produced from the JIT backend.  The above example is what you need for
jitviewer_.

.. _jitviewer: https://bitbucket.org/pypy/jitviewer

The filename can be given as ``-`` to dump the log to stderr.

As a special case, the value ``PYPYLOG=+filename`` means that only
the section markers are written (for any section).  This is mostly
only useful for ``rpython/tool/logparser.py``.


PYPYSTM
-------

Only available in ``pypy-stm``.  Names a log file into which the
PyPy-STM will output contention information.  Can be read with
``pypy/stm/print_stm_log.py``.
