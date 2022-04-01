.. TODO cleanup after merge of gc-del


.. _garbage-collection:

=============================
Garbage Collection in RPython
=============================

.. contents::


Introduction
============

The overview and description of our garbage collection strategy and
framework can be found in the `EU-report on this topic`_.  Please refer
to that file for an old, but still more or less accurate, description.
The present document describes the specific garbage collectors that we
wrote in our framework.

.. _EU-report on this topic: https://bitbucket.org/pypy/extradoc/raw/tip/eu-report/D07.1_Massive_Parallelism_and_Translation_Aspects-2007-02-28.pdf


Garbage collectors currently written for the GC framework
=========================================================

Reminder: to select which GC you want to include in a translated
RPython program, use the ``--gc=NAME`` option of ``translate.py``.
For more details, see the `overview of command line options for
translation`_.

The following overview is written in chronological order, so the "best"
GC (which is the default when translating) is the last one below.

.. _overview of command line options for translation: config/commandline.html#translation

Mark and Sweep
--------------

Classical Mark and Sweep collector.  Also contained a lot of experimental
and half-unmaintained features.  Was removed.

Semispace copying collector
---------------------------

Two arenas of equal size, with only one arena in use and getting filled
with new objects.  When the arena is full, the live objects are copied
into the other arena using Cheney's algorithm.  The old arena is then
cleared.  See :source:`rpython/memory/gc/semispace.py`.

On Unix the clearing is done by reading ``/dev/zero`` into the arena,
which is extremely memory efficient at least on Linux: it lets the
kernel free the RAM that the old arena used and replace it all with
allocated-on-demand memory.

The size of each semispace starts at 8MB but grows as needed when the
amount of objects alive grows.

Generational GC
---------------

This is a two-generations GC.  See :source:`rpython/memory/gc/generation.py`.

It is implemented as a subclass of the Semispace copying collector.  It
adds a nursery, which is a chunk of the current semispace.  Its size is
computed to be half the size of the CPU Level 2 cache.  Allocations fill
the nursery, and when it is full, it is collected and the objects still
alive are moved to the rest of the current semispace.

The idea is that it is very common for objects to die soon after they
are created.  Generational GCs help a lot in this case, particularly if
the amount of live objects really manipulated by the program fits in the
Level 2 cache.  Moreover, the semispaces fill up much more slowly,
making full collections less frequent.

Hybrid GC
---------

This is a three-generations GC.

It is implemented as a subclass of the Generational GC.  The Hybrid GC
can handle both objects that are inside and objects that are outside the
semispaces ("external").  The external objects are not moving and
collected in a mark-and-sweep fashion.  Large objects are allocated as
external objects to avoid costly moves.  Small objects that survive for
a long enough time (several semispace collections) are also made
external so that they stop moving.

This is coupled with a segregation of the objects in three generations.
Each generation is collected much less often than the previous one.  The
division of the generations is slightly more complicated than just
nursery / semispace / external; see the diagram at the start of the
source code, in :source:`rpython/memory/gc/hybrid.py`.

Mark & Compact GC
-----------------

Killed in trunk.  The following documentation is for historical purposes
only.

Inspired, at least partially, by Squeak's garbage collector, this is a
single-arena GC in which collection compacts the objects in-place.  The
main point of this GC is to save as much memory as possible (to be not
worse than the Semispace), but without the peaks of double memory usage
during collection.

Unlike the Semispace GC, collection requires a number of passes over the
data.  This makes collection quite slower.  Future improvements could be
to add a nursery to Mark & Compact in order to mitigate this issue.

During a collection, we reuse the space in-place if it is still large
enough.  If not, we need to allocate a new, larger space, and move the
objects there; however, this move is done chunk by chunk, and chunks are
cleared (i.e. returned to the OS) as soon as they have been moved away.
This means that (from the point of view of the OS) a collection will
never cause an important temporary growth of total memory usage.

More precisely, a collection is triggered when the space contains more
than N*M bytes, where N is the number of bytes alive after the previous
collection and M is a constant factor, by default 1.5.  This guarantees
that the total memory usage of the program never exceeds 1.5 times the
total size of its live objects.

The objects themselves are quite compact: they are allocated next to
each other in the heap, separated by a GC header of only one word (4
bytes on 32-bit platforms) and possibly followed by up to 3 bytes of
padding for non-word-sized objects (e.g. strings).  There is a small
extra memory usage during collection: an array containing 2 bytes per
surviving object is needed to make a backup of (half of) the surviving
objects' header, in order to let the collector store temporary relation
information in the regular headers.

Minimark GC
-----------

This is a simplification and rewrite of the ideas from the Hybrid GC.
It uses a nursery for the young objects, and mark-and-sweep for the old
objects.  This is a moving GC, but objects may only move once (from
the nursery to the old stage).

The main difference with the Hybrid GC is that the mark-and-sweep
objects (the "old stage") are directly handled by the GC's custom
allocator, instead of being handled by malloc() calls.  The gain is that
it is then possible, during a major collection, to walk through all old
generation objects without needing to store a list of pointers to them.
So as a first approximation, when compared to the Hybrid GC, the
Minimark GC saves one word of memory per old object.

There are :ref:`a number of environment variables
<minimark-environment-variables>` that can be tweaked to influence the
GC.  (Their default value should be ok for most usages.)

In more detail:

- The small newly malloced objects are allocated in the nursery (case 1).
  All objects living in the nursery are "young".

- The big objects are always handled directly by the system malloc().
  But the big newly malloced objects are still "young" when they are
  allocated (case 2), even though they don't live in the nursery.

- When the nursery is full, we do a minor collection, i.e. we find
  which "young" objects are still alive (from cases 1 and 2).  The
  "young" flag is then removed.  The surviving case 1 objects are moved
  to the old stage. The dying case 2 objects are immediately freed.

- The old stage is an area of memory containing old (small) objects.  It
  is handled by :source:`rpython/memory/gc/minimarkpage.py`.  It is organized
  as "arenas" of 256KB or 512KB, subdivided into "pages" of 4KB or 8KB.
  Each page can either be free, or contain small objects of all the same
  size.  Furthermore at any point in time each object location can be
  either allocated or freed.  The basic design comes from ``obmalloc.c``
  from CPython (which itself comes from the same source as the Linux
  system malloc()).

- New objects are added to the old stage at every minor collection.
  Immediately after a minor collection, when we reach some threshold, we
  trigger a major collection.  This is the mark-and-sweep step.  It walks
  over *all* objects (mark), and then frees some fraction of them (sweep).
  This means that the only time when we want to free objects is while
  walking over all of them; we never ask to free an object given just its
  address.  This allows some simplifications and memory savings when
  compared to ``obmalloc.c``.

- As with all generational collectors, this GC needs a write barrier to
  record which old objects have a reference to young objects.

- Additionally, we found out that it is useful to handle the case of
  big arrays specially: when we allocate a big array (with the system
  malloc()), we reserve a small number of bytes before.  When the array
  grows old, we use the extra bytes as a set of bits.  Each bit
  represents 128 entries in the array.  Whenever the write barrier is
  called to record a reference from the Nth entry of the array to some
  young object, we set the bit number ``(N/128)`` to 1.  This can
  considerably speed up minor collections, because we then only have to
  scan 128 entries of the array instead of all of them.

- As usual, we need special care about weak references, and objects with
  finalizers.  Weak references are allocated in the nursery, and if they
  survive they move to the old stage, as usual for all objects; the
  difference is that the reference they contain must either follow the
  object, or be set to NULL if the object dies.  And the objects with
  finalizers, considered rare enough, are immediately allocated old to
  simplify the design.  In particular their ``__del__`` method can only
  be called just after a major collection.

- The objects move once only, so we can use a trick to implement id()
  and hash().  If the object is not in the nursery, it won't move any
  more, so its id() and hash() are the object's address, cast to an
  integer.  If the object is in the nursery, and we ask for its id()
  or its hash(), then we pre-reserve a location in the old stage, and
  return the address of that location.  If the object survives the
  next minor collection, we move it there, and so its id() and hash()
  are preserved.  If the object dies then the pre-reserved location
  becomes free garbage, to be collected at the next major collection.

The exact name of this GC is either `minimark` or `incminimark`.  The
latter is a version that does major collections incrementally (i.e.  one
major collection is split along some number of minor collections, rather
than being done all at once after a specific minor collection).  The
default is `incminimark`, as it seems to have a very minimal impact on
performance and memory usage at the benefit of avoiding the long pauses
of `minimark`.
