
=============================
Software Transactional Memory
=============================

.. contents::

**Warning:** The below is relatively out of date, the ``pypy-stm``-variant is
no longer actively being developed. For a description of the technical details
as well as the pros and cons of the approach, you can read the 2019 `paper`__
by Remi Meier and also his `PhD thesis`__.

.. __: https://dl.acm.org/doi/abs/10.1145/3359619.3359747
.. __: https://www.research-collection.ethz.ch/handle/20.500.11850/371019

This page is about ``pypy-stm``, a special in-development version of
PyPy which can run multiple independent CPU-hungry threads in the same
process in parallel.  It is a solution to what is known in the Python
world as the "global interpreter lock (GIL)" problem --- it is an
implementation of Python without the GIL.

"STM" stands for Software `Transactional Memory`_, the technique used
internally.  This page describes ``pypy-stm`` from the perspective of a
user, describes work in progress, and finally gives references to more
implementation details.

This work was done by Remi Meier and Armin Rigo.  Thanks to all donors
for crowd-funding the work so far!  Please have a look at the `2nd call
for donation`_.

.. _`Transactional Memory`: https://en.wikipedia.org/wiki/Transactional_memory
.. _`2nd call for donation`: https://pypy.org/tmdonate2.html


What pypy-stm is for
====================

``pypy-stm`` is a variant of the regular PyPy interpreter.  (This
version supports Python 2.7; see below for `Python 3, CPython,
and others`_.)  With caveats_
listed below, it should be in theory within 20%-50% slower than a
regular PyPy, comparing the JIT version in both cases (but see below!).
It is called
STM for Software Transactional Memory, which is the internal technique
used (see `Reference to implementation details`_).

The benefit is that the resulting ``pypy-stm`` can execute multiple
threads of Python code in parallel.  Programs running two threads or
more in parallel should ideally run faster than in a regular PyPy
(either now, or soon as bugs are fixed).

* ``pypy-stm`` is fully compatible with a GIL-based PyPy; you can use
  it as a drop-in replacement and multithreaded programs will run on
  multiple cores.

* ``pypy-stm`` provides (but does not impose) a special API to the
  user in the pure Python module ``transaction``.  This module is based
  on the lower-level module ``pypystm``, but also provides some
  compatibily with non-STM PyPy's or CPython's.

* Building on top of the way the GIL is removed, we will talk
  about `How to write multithreaded programs: the 10'000-feet view`_
  and `transaction.TransactionQueue`_.


...and what pypy-stm is not for
-------------------------------

``pypy-stm`` gives a Python without the GIL.  This means that it is
useful in situations where the GIL is the problem in the first place.
(This includes cases where the program can easily be modified to run
in multiple threads; often, we don't consider doing that precisely
because of the GIL.)

However, there are plenty of cases where the GIL is not the problem.
Do not hope ``pypy-stm`` to be helpful in these cases!  This includes
all programs that use multiple threads but don't actually spend a lot
of time running Python code.  For example, it may be spending all its
time waiting for I/O to occur, or performing some long computation on
a huge matrix.  These are cases where the CPU is either idle, or in
some C/Fortran library anyway; in both cases, the interpreter (either
CPython or the regular PyPy) should release the GIL around the
external calls.  The threads will thus not end up fighting for the
GIL.



Getting Started
===============

**pypy-stm requires 64-bit Linux for now.**

Development is done in the branch `stmgc-c8`_.  If you are only
interested in trying it out, please pester us until we upload a recent
prebuilt binary.  The current version supports four "segments", which
means that it will run up to four threads in parallel.

To build a version from sources, you first need to compile a custom
version of gcc(!).  See the instructions here:
https://bitbucket.org/pypy/stmgc/src/default/gcc-seg-gs/
(Note that these patches are being incorporated into gcc.  It is likely
that future versions of gcc will not need to be patched any more.)

Then get the branch `stmgc-c8`_ of PyPy and run::

   cd pypy/goal
   ../../rpython/bin/rpython -Ojit --stm

At the end, this will try to compile the generated C code by calling
``gcc-seg-gs``, which must be the script you installed in the
instructions above.

.. _`stmgc-c8`: https://bitbucket.org/pypy/pypy/src/stmgc-c8/


.. _caveats:

Current status (stmgc-c7)
-------------------------

.. warning::
    
    THIS PAGE IS OLD, THE REST IS ABOUT STMGC-C7 WHEREAS THE CURRENT
    DEVELOPMENT WORK IS DONE ON STMGC-C8


* **NEW:** It seems to work fine, without crashing any more.  Please `report
  any crash`_ you find (or other bugs).

* It runs with an overhead as low as 20% on examples like "richards".
  There are also other examples with higher overheads --currently up to
  2x for "translate.py"-- which we are still trying to understand.
  One suspect is our partial GC implementation, see below.

* **NEW:** the ``PYPYSTM`` environment variable and the
  ``pypy/stm/print_stm_log.py`` script let you know exactly which
  "conflicts" occurred.  This is described in the section
  `transaction.TransactionQueue`_ below.

* **NEW:** special transaction-friendly APIs (like ``stmdict``),
  described in the section `transaction.TransactionQueue`_ below.  The
  old API changed again, mostly moving to different modules.  Sorry
  about that.  I feel it's a better idea to change the API early
  instead of being stuck with a bad one later...

* Currently limited to 1.5 GB of RAM (this is just a parameter in
  `core.h`__ -- theoretically.  In practice, increase it too much and
  clang crashes again).  Memory overflows are not correctly handled;
  they cause segfaults.

* **NEW:** The JIT warm-up time improved again, but is still
  relatively large.  In order to produce machine code, the JIT needs
  to enter "inevitable" mode.  This means that you will get bad
  performance results if your program doesn't run for several seconds,
  where *several* can mean *many.* When trying benchmarks, be sure to
  check that you have reached the warmed state, i.e. the performance
  is not improving any more.

* The GC is new; although clearly inspired by PyPy's regular GC, it
  misses a number of optimizations for now.  Programs allocating large
  numbers of small objects that don't immediately die (surely a common
  situation) suffer from these missing optimizations.  (The bleeding
  edge ``stmgc-c8`` is better at that.)

* Weakrefs might appear to work a bit strangely for now, sometimes
  staying alive throught ``gc.collect()``, or even dying but then
  un-dying for a short time before dying again.  A similar problem can
  show up occasionally elsewhere with accesses to some external
  resources, where the (apparent) serialized order doesn't match the
  underlying (multithreading) order.  These are bugs (partially fixed
  already in ``stmgc-c8``).  Also, debugging helpers like
  ``weakref.getweakrefcount()`` might give wrong answers.

* The STM system is based on very efficient read/write barriers, which
  are mostly done (their placement could be improved a bit in
  JIT-generated machine code).

* Forking the process is slow because the complete memory needs to be
  copied manually.  A warning is printed to this effect.

* Very long-running processes (on the order of days) will eventually
  crash on an assertion error because of a non-implemented overflow of
  an internal 28-bit counter.

* The recursion detection code was not reimplemented.  Infinite
  recursion just segfaults for now.


.. _`report any crash`: https://bitbucket.org/pypy/pypy/issues?status=new&status=open
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/translator/stm/src_stm/stm/core.h



Python 3, CPython, and others
=============================

In this document I describe "pypy-stm", which is based on PyPy's Python
2.7 interpreter.  Supporting Python 3 should take about half an
afternoon of work.  Obviously, what I *don't* mean is that by tomorrow
you can have a finished and polished "pypy3-stm" product.  General py3k
work is still missing; and general stm work is also still missing.  But
they are rather independent from each other, as usual in PyPy.  The
required afternoon of work will certainly be done one of these days now
that the internal interfaces seem to stabilize.

The same is true for other languages implemented in the RPython
framework, although the amount of work to put there might vary, because
the STM framework within RPython is currently targeting the PyPy
interpreter and other ones might have slightly different needs.
But in general, all the tedious transformations are done by RPython
and you're only left with the (hopefully few) hard and interesting bits.

The core of STM works as a library written in C (see `reference to
implementation details`_ below).  It means that it can be used on
other interpreters than the ones produced by RPython.  Duhton_ is an
early example of that.  At this point, you might think about adapting
this library for CPython.  You're warned, though: as far as I can
tell, it is a doomed idea.  I had a hard time debugging Duhton, and
that's infinitely simpler than CPython.  Even ignoring that, you can
see in the C sources of Duhton that many core design decisions are
different than in CPython: no refcounting; limited support for
prebuilt "static" objects; ``stm_read()`` and ``stm_write()`` macro
calls everywhere (and getting very rare and very obscure bugs if you
forget one); and so on.  You could imagine some custom special-purpose
extension of the C language, which you would preprocess to regular C.
In my opinion that's starting to look a lot like RPython itself, but
maybe you'd prefer this approach.  Of course you still have to worry
about each and every C extension module you need, but maybe you'd have
a way forward.

.. _Duhton: https://bitbucket.org/pypy/duhton



User Guide
==========

How to write multithreaded programs: the 10'000-feet view
---------------------------------------------------------

PyPy-STM offers two ways to write multithreaded programs:

* the traditional way, using the ``thread`` or ``threading`` modules,
  described first__.

* using ``TransactionQueue``, described next__, as a way to hide the
  low-level notion of threads.

.. __: `Drop-in replacement`_
.. __: `transaction.TransactionQueue`_

The issues with low-level threads are well known (particularly in other
languages that don't have GIL-based interpreters): memory corruption,
deadlocks, livelocks, and so on.  There are alternative approaches to
dealing directly with threads, like OpenMP_.  These approaches
typically enforce some structure on your code.  ``TransactionQueue``
is in part similar: your program needs to have "some chances" of
parallelization before you can apply it.  But I believe that the scope
of applicability is much larger with ``TransactionQueue`` than with
other approaches.  It usually works without forcing a complete
reorganization of your existing code, and it works on any Python
program which has got *latent* and *imperfect* parallelism.  Ideally,
it only requires that the end programmer identifies where this
parallelism is likely to be found, and communicates it to the system
using a simple API.

.. _OpenMP: https://en.wikipedia.org/wiki/OpenMP


Drop-in replacement
-------------------

Multithreaded, CPU-intensive Python programs should work unchanged on
``pypy-stm``.  They will run using multiple CPU cores in parallel.

The existing semantics of the GIL (Global Interpreter Lock) are
unchanged: although running on multiple cores in parallel, ``pypy-stm``
gives the illusion that threads are run serially, with switches only
occurring between bytecodes, not in the middle of them.  Programs can
rely on this: using ``shared_list.append()/pop()`` or
``shared_dict.setdefault()`` as synchronization mecanisms continues to
work as expected.

This works by internally considering the points where a standard PyPy or
CPython would release the GIL, and replacing them with the boundaries of
"transactions".  Like their database equivalent, multiple transactions
can execute in parallel, but will commit in some serial order.  They
appear to behave as if they were completely run in this serialization
order.


transaction.TransactionQueue
----------------------------

In CPU-hungry programs, we can often easily identify outermost loops
over some data structure, or other repetitive algorithm, where each
"block" consists of processing a non-trivial amount of data, and where
the blocks "have a good chance" to be independent from each other.  We
don't need to prove that they are actually independent: it is enough
if they are *often independent* --- or, more precisely, if we *think
they should be* often independent.

One typical example would look like this, where the function ``func()``
typically invokes a large amount of code::

    for key, value in bigdict.items():
        func(key, value)

Then you simply replace the loop with::

    from transaction import TransactionQueue

    tr = TransactionQueue()
    for key, value in bigdict.items():
        tr.add(func, key, value)
    tr.run()

This code's behavior is equivalent.  Internally, the
``TransactionQueue`` object will start N threads and try to run the
``func(key, value)`` calls on all threads in parallel.  But note the
difference with a regular thread-pooling library, as found in many
lower-level languages than Python: the function calls are not randomly
interleaved with each other just because they run in parallel.  The
behavior did not change because we are using ``TransactionQueue``.
All the calls still *appear* to execute in some serial order.

A typical usage of ``TransactionQueue`` goes like that: at first,
the performance does not increase.
In fact, it is likely to be worse.  Typically, this is
indicated by the total CPU usage, which remains low (closer to 1 than
N cores).  First note that it is expected that the CPU usage should
not go much higher than 1 in the JIT warm-up phase: you must run a
program for several seconds, or for larger programs at least one
minute, to give the JIT a chance to warm up enough.  But if CPU usage
remains low even afterwards, then the ``PYPYSTM`` environment variable
can be used to track what is going on.

Run your program with ``PYPYSTM=logfile`` to produce a log file called
``logfile``.  Afterwards, use the ``pypy/stm/print_stm_log.py``
utility to inspect the content of this log file.  It produces output
like this (sorted by amount of time lost, largest first)::

    10.5s lost in aborts, 1.25s paused (12412x STM_CONTENTION_WRITE_WRITE)
    File "foo.py", line 10, in f
      someobj.stuff = 5
    File "bar.py", line 20, in g
      someobj.other = 10

This means that 10.5 seconds were lost running transactions that were
aborted (which caused another 1.25 seconds of lost time by pausing),
because of the reason shown in the two independent single-entry
tracebacks: one thread ran the line ``someobj.stuff = 5``, whereas
another thread concurrently ran the line ``someobj.other = 10`` on the
same object.  These two writes are done to the same object.  This
causes a conflict, which aborts one of the two transactions.  In the
example above this occurred 12412 times.

The two other conflict sources are ``STM_CONTENTION_INEVITABLE``,
which means that two transactions both tried to do an external
operation, like printing or reading from a socket or accessing an
external array of raw data; and ``STM_CONTENTION_WRITE_READ``, which
means that one transaction wrote to an object but the other one merely
read it, not wrote to it (in that case only the writing transaction is
reported; the location for the reads is not recorded because doing so
is not possible without a very large performance impact).

Common causes of conflicts:

* First of all, any I/O or raw manipulation of memory turns the
  transaction inevitable ("must not abort").  There can be only one
  inevitable transaction running at any time.  A common case is if
  each transaction starts with sending data to a log file.  You should
  refactor this case so that it occurs either near the end of the
  transaction (which can then mostly run in non-inevitable mode), or
  delegate it to a separate transaction or even a separate thread.

* Writing to a list or a dictionary conflicts with any read from the
  same list or dictionary, even one done with a different key.  For
  dictionaries and sets, you can try the types ``transaction.stmdict``
  and ``transaction.stmset``, which behave mostly like ``dict`` and
  ``set`` but allow concurrent access to different keys.  (What is
  missing from them so far is lazy iteration: for example,
  ``stmdict.iterkeys()`` is implemented as ``iter(stmdict.keys())``;
  and, unlike PyPy's dictionaries and sets, the STM versions are not
  ordered.)  There are also experimental ``stmiddict`` and
  ``stmidset`` classes using the identity of the key.

* ``time.time()`` and ``time.clock()`` turn the transaction inevitable
  in order to guarantee that a call that appears to be later will really
  return a higher number.  If getting slightly unordered results is
  fine, use ``transaction.time()`` or ``transaction.clock()``.  The
  latter operations guarantee to return increasing results only if you
  can "prove" that two calls occurred in a specific order (for example
  because they are both called by the same thread).  In cases where no
  such proof is possible, you might get randomly interleaved values.
  (If you have two independent transactions, they normally behave as if
  one of them was fully executed before the other; but using
  ``transaction.time()`` you might see the "hidden truth" that they are
  actually interleaved.)

* ``transaction.threadlocalproperty`` can be used at class-level::

      class Foo(object):     # must be a new-style class!
          x = transaction.threadlocalproperty()
          y = transaction.threadlocalproperty(dict)

  This declares that instances of ``Foo`` have two attributes ``x``
  and ``y`` that are thread-local: reading or writing them from
  concurrently-running transactions will return independent results.
  (Any other attributes of ``Foo`` instances will be globally visible
  from all threads, as usual.)  This is useful together with
  ``TransactionQueue`` for these two cases:

  - For attributes of long-lived objects that change during one
    transaction, but should always be reset to some initial value
    around transaction (for example, initialized to 0 at the start of
    a transaction; or, if used for a list of pending things to do
    within this transaction, it will always be empty at the end of one
    transaction).

  - For general caches across transactions.  With ``TransactionQueue``
    you get a pool of a fixed number N of threads, each running the
    transactions serially.  A thread-local property will have the
    value last stored in it by the same thread, which may come from a
    random previous transaction.  Basically, you get N copies of the
    property's value, and each transaction accesses a random copy.  It
    works fine for caches.

  In more details, the optional argument to ``threadlocalproperty()``
  is the default value factory: in case no value was assigned in the
  current thread yet, the factory is called and its result becomes the
  value in that thread (like ``collections.defaultdict``).  If no
  default value factory is specified, uninitialized reads raise
  ``AttributeError``.

* In addition to all of the above, there are cases where write-write
  conflicts are caused by writing the same value to an attribute again
  and again.  See for example ea2e519614ab_: this fixes two such
  issues where we write an object field without first checking if we
  already did it.  The ``dont_change_any_more`` field is a flag set to
  ``True`` in that part of the code, but usually this
  ``rtyper_makekey()`` method will be called many times for the same
  object; the code used to repeatedly set the flag to ``True``, but
  now it first checks and only does the write if it is ``False``.
  Similarly, in the second half of the checkin, the method
  ``setup_block_entry()`` used to both assign the ``concretetype``
  fields and return a list, but its two callers were different: one
  would really need the ``concretetype`` fields initialized, whereas
  the other would only need to get its result list --- the
  ``concretetype`` field in that case might already be set or not, but
  that would not matter.

.. _ea2e519614ab: https://bitbucket.org/pypy/pypy/commits/ea2e519614ab

Note that Python is a complicated language; there are a number of less
common cases that may cause conflict (of any kind) where we might not
expect it at priori.  In many of these cases it could be fixed; please
report any case that you don't understand.


Atomic sections
---------------

The ``TransactionQueue`` class described above is based on *atomic
sections,* which are blocks of code which you want to execute without
"releasing the GIL".  In STM terms, this means blocks of code that are
executed while guaranteeing that the transaction is not interrupted in
the middle.  *This is experimental and may be removed in the future*
if `Software lock elision`_ is ever implemented.

Here is a direct usage example::

    with transaction.atomic:
        assert len(lst1) == 10
        x = lst1.pop(0)
        lst1.append(x)

In this example, we are sure that the item popped off one end of
the list is appened again at the other end atomically.  It means that
another thread can run ``len(lst1)`` or ``x in lst1`` without any
particular synchronization, and always see the same results,
respectively ``10`` and ``True``.  It will never see the intermediate
state where ``lst1`` only contains 9 elements.  Atomic sections are
similar to re-entrant locks (they can be nested), but additionally they
protect against the concurrent execution of *any* code instead of just
code that happens to be protected by the same lock in other threads.

Note that the notion of atomic sections is very strong. If you write
code like this::

    with __pypy__.thread.atomic:
        time.sleep(10)

then, if you think about it as if we had a GIL, you are executing a
10-seconds-long atomic transaction without releasing the GIL at all.
This prevents all other threads from progressing at all.  While it is
not strictly true in ``pypy-stm``, the exact rules for when other
threads can progress or not are rather complicated; you have to consider
it likely that such a piece of code will eventually block all other
threads anyway.

Note that if you want to experiment with ``atomic``, you may have to
manually add a transaction break just before the atomic block.  This is
because the boundaries of the block are not guaranteed to be the
boundaries of the transaction: the latter is at least as big as the
block, but may be bigger.  Therefore, if you run a big atomic block, it
is a good idea to break the transaction just before.  This can be done
by calling ``transaction.hint_commit_soon()``.  (This may be fixed at
some point.)

There are also issues with the interaction of regular locks and atomic
blocks.  This can be seen if you write to files (which have locks),
including with a ``print`` to standard output.  If one thread tries to
acquire a lock while running in an atomic block, and another thread
has got the same lock at that point, then the former may fail with a
``thread.error``.  (Don't rely on it; it may also deadlock.)
The reason is that "waiting" for some condition to
become true --while running in an atomic block-- does not really make
sense.  For now you can work around it by making sure that, say, all
your prints are either in an ``atomic`` block or none of them are.
(This kind of issue is theoretically hard to solve and may be the
reason for atomic block support to eventually be removed.)


Locks
-----

**Not Implemented Yet**

The thread module's locks have their basic semantic unchanged.  However,
using them (e.g. in ``with my_lock:`` blocks) starts an alternative
running mode, called `Software lock elision`_.  This means that PyPy
will try to make sure that the transaction extends until the point where
the lock is released, and if it succeeds, then the acquiring and
releasing of the lock will be "elided".  This means that in this case,
the whole transaction will technically not cause any write into the lock
object --- it was unacquired before, and is still unacquired after the
transaction.

This is specially useful if two threads run ``with my_lock:`` blocks
with the same lock.  If they each run a transaction that is long enough
to contain the whole block, then all writes into the lock will be elided
and the two transactions will not conflict with each other.  As usual,
they will be serialized in some order: one of the two will appear to run
before the other.  Simply, each of them executes an "acquire" followed
by a "release" in the same transaction.  As explained above, the lock
state goes from "unacquired" to "unacquired" and can thus be left
unchanged.

This approach can gracefully fail: unlike atomic sections, there is no
guarantee that the transaction runs until the end of the block.  If you
perform any input/output while you hold the lock, the transaction will
end as usual just before the input/output operation.  If this occurs,
then the lock elision mode is cancelled and the lock's "acquired" state
is really written.

Even if the lock is really acquired already, a transaction doesn't have
to wait for it to become free again.  It can enter the elision-mode anyway
and tentatively execute the content of the block.  It is only at the end,
when trying to commit, that the thread will pause.  As soon as the real
value stored in the lock is switched back to "unacquired", it can then
proceed and attempt to commit its already-executed transaction (which
can fail and abort and restart from the scratch, as usual).

Note that this is all *not implemented yet,* but we expect it to work
even if you acquire and release several locks.  The elision-mode
transaction will extend until the first lock you acquired is released,
or until the code performs an input/output or a wait operation (for
example, waiting for another lock that is currently not free).  In the
common case of acquiring several locks in nested order, they will all be
elided by the same transaction.

.. _`software lock elision`: https://www.repository.cam.ac.uk/handle/1810/239410


Miscellaneous functions
-----------------------

* First, note that the ``transaction`` module is found in the file
  ``lib_pypy/transaction.py``.  This file can be copied around to
  execute the same programs on CPython or on non-STM PyPy, with
  fall-back behavior.  (One case where the behavior differs is
  ``atomic``, which is in this fall-back case just a regular lock; so
  ``with atomic`` only prevent other threads from entering other
  ``with atomic`` sections, but won't prevent other threads from
  running non-atomic code.)

* ``transaction.getsegmentlimit()``: return the number of "segments" in
  this pypy-stm.  This is the limit above which more threads will not be
  able to execute on more cores.  (Right now it is limited to 4 due to
  inter-segment overhead, but should be increased in the future.  It
  should also be settable, and the default value should depend on the
  number of actual CPUs.)  If STM is not available, this returns 1.

* ``__pypy__.thread.signals_enabled``: a context manager that runs its
  block of code with signals enabled.  By default, signals are only
  enabled in the main thread; a non-main thread will not receive
  signals (this is like CPython).  Enabling signals in non-main
  threads is useful for libraries where threads are hidden and the end
  user is not expecting his code to run elsewhere than in the main
  thread.

* ``pypystm.exclusive_atomic``: a context manager similar to
  ``transaction.atomic`` but which complains if it is nested.

* ``transaction.is_atomic()``: return True if called from an atomic
  context.

* ``pypystm.count()``: return a different positive integer every time
  it is called.  This works without generating conflicts.  The
  returned integers are only roughly in increasing order; this should
  not be relied upon.


More details about conflicts
----------------------------

Based on Software Transactional Memory, the ``pypy-stm`` solution is
prone to "conflicts".  To repeat the basic idea, threads execute their code
speculatively, and at known points (e.g. between bytecodes) they
coordinate with each other to agree on which order their respective
actions should be "committed", i.e. become globally visible.  Each
duration of time between two commit-points is called a transaction.

A conflict occurs when there is no consistent ordering.  The classical
example is if two threads both tried to change the value of the same
global variable.  In that case, only one of them can be allowed to
proceed, and the other one must be either paused or aborted (restarting
the transaction).  If this occurs too often, parallelization fails.

How much actual parallelization a multithreaded program can see is a bit
subtle.  Basically, a program not using ``transaction.atomic`` or
eliding locks, or doing so for very short amounts of time, will
parallelize almost freely (as long as it's not some artificial example
where, say, all threads try to increase the same global counter and do
nothing else).

However, if the program requires longer transactions, it comes
with less obvious rules.  The exact details may vary from version to
version, too, until they are a bit more stabilized.  Here is an
overview.

Parallelization works as long as two principles are respected.  The
first one is that the transactions must not *conflict* with each
other.  The most obvious sources of conflicts are threads that all
increment a global shared counter, or that all store the result of
their computations into the same list --- or, more subtly, that all
``pop()`` the work to do from the same list, because that is also a
mutation of the list.  (You can work around it with
``transaction.stmdict``, but for that specific example, some STM-aware
queue should eventually be designed.)

A conflict occurs as follows: when a transaction commits (i.e. finishes
successfully) it may cause other transactions that are still in progress
to abort and retry.  This is a waste of CPU time, but even in the worst
case senario it is not worse than a GIL, because at least one
transaction succeeds (so we get at worst N-1 CPUs doing useless jobs and
1 CPU doing a job that commits successfully).

Conflicts do occur, of course, and it is pointless to try to avoid them
all.  For example they can be abundant during some warm-up phase.  What
is important is to keep them rare enough in total.

Another issue is that of avoiding long-running so-called "inevitable"
transactions ("inevitable" is taken in the sense of "which cannot be
avoided", i.e. transactions which cannot abort any more).  Transactions
like that should only occur if you use ``atomic``,
generally because of I/O in atomic blocks.  They work, but the
transaction is turned inevitable before the I/O is performed.  For all
the remaining execution time of the atomic block, they will impede
parallel work.  The best is to organize the code so that such operations
are done completely outside ``atomic``.

(This is not unrelated to the fact that blocking I/O operations are
discouraged with Twisted, and if you really need them, you should do
them on their own separate thread.)

In case lock elision eventually replaces atomic sections, we wouldn't
get long-running inevitable transactions, but the same problem occurs
in a different way: doing I/O cancels lock elision, and the lock turns
into a real lock.  This prevents other threads from committing if they
also need this lock.  (More about it when lock elision is implemented
and tested.)



Implementation
==============

XXX this section mostly empty for now


Technical reports
-----------------

STMGC-C7 is described in detail in a `technical report`__.

A separate `position paper`__ gives an overview of our position about
STM in general.

.. __: https://bitbucket.org/pypy/extradoc/src/extradoc/talk/dls2014/paper/paper.pdf
.. __: https://bitbucket.org/pypy/extradoc/src/extradoc/talk/icooolps2014/


Reference to implementation details
-----------------------------------

The core of the implementation is in a separate C library called
stmgc_, in the c7_ subdirectory (current version of pypy-stm) and in
the c8_ subdirectory (bleeding edge version).  Please see the
`README.txt`_ for more information.  In particular, the notion of
segment is discussed there.

.. _stmgc: https://bitbucket.org/pypy/stmgc/src/default/
.. _c7: https://bitbucket.org/pypy/stmgc/src/default/c7/
.. _c8: https://bitbucket.org/pypy/stmgc/src/default/c8/
.. _`README.txt`: https://bitbucket.org/pypy/stmgc/raw/default/c7/README.txt

PyPy itself adds on top of it the automatic placement of read__ and write__
barriers and of `"becomes-inevitable-now" barriers`__, the logic to
`start/stop transactions as an RPython transformation`__ and as
`supporting`__ `C code`__, and the support in the JIT (mostly as a
`transformation step on the trace`__ and generation of custom assembler
in `assembler.py`__).

.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/translator/stm/readbarrier.py
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/memory/gctransform/stmframework.py
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/translator/stm/inevitable.py
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/translator/stm/jitdriver.py
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/translator/stm/src_stm/stmgcintf.h
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/translator/stm/src_stm/stmgcintf.c
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/jit/backend/llsupport/stmrewrite.py
.. __: https://bitbucket.org/pypy/pypy/raw/stmgc-c7/rpython/jit/backend/x86/assembler.py



See also
========

See also
https://bitbucket.org/pypy/pypy/raw/default/pypy/doc/project-ideas.rst
(section about STM).
