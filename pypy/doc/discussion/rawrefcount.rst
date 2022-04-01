======================
Rawrefcount and the GC
======================


GC Interface
------------

"PyObject" is a raw structure with at least two fields, ob_refcnt and
ob_pypy_link.  The ob_refcnt is the reference counter as used on
CPython.  If the PyObject structure is linked to a live PyPy object,
its current address is stored in ob_pypy_link and ob_refcnt is bumped
by either the constant REFCNT_FROM_PYPY, or the constant
REFCNT_FROM_PYPY_LIGHT (== REFCNT_FROM_PYPY + SOME_HUGE_VALUE)
(to mean "light finalizer").

Most PyPy objects exist outside cpyext, and conversely in cpyext it is
possible that a lot of PyObjects exist without being seen by the rest
of PyPy.  At the interface, however, we can "link" a PyPy object and a
PyObject.  There are two kinds of link:

rawrefcount.create_link_pypy(p, ob)

    Makes a link between an exising object gcref 'p' and a newly
    allocated PyObject structure 'ob'.  ob->ob_refcnt must be
    initialized to either REFCNT_FROM_PYPY, or
    REFCNT_FROM_PYPY_LIGHT.  (The second case is an optimization:
    when the GC finds the PyPy object and PyObject no longer
    referenced, it can just free() the PyObject.)

rawrefcount.create_link_pyobj(p, ob)

    Makes a link from an existing PyObject structure 'ob' to a newly
    allocated W_CPyExtPlaceHolderObject 'p'.  You must also add
    REFCNT_FROM_PYPY to ob->ob_refcnt.  For cases where the PyObject
    contains all the data, and the PyPy object is just a proxy.  The
    W_CPyExtPlaceHolderObject should have only a field that contains
    the address of the PyObject, but that's outside the scope of the
    GC.

rawrefcount.from_obj(p)

    If there is a link from object 'p' made with create_link_pypy(),
    returns the corresponding 'ob'.  Otherwise, returns NULL.

rawrefcount.to_obj(Class, ob)

    Returns ob->ob_pypy_link, cast to an instance of 'Class'.


Collection logic
----------------

Objects existing purely on the C side have ob->ob_pypy_link == 0;
these are purely reference counted.  On the other hand, if
ob->ob_pypy_link != 0, then ob->ob_refcnt is at least REFCNT_FROM_PYPY
and the object is part of a "link".

The idea is that links whose 'p' is not reachable from other PyPy
objects *and* whose 'ob->ob_refcnt' is REFCNT_FROM_PYPY or
REFCNT_FROM_PYPY_LIGHT are the ones who die.  But it is more messy
because PyObjects still (usually) need to have a tp_dealloc called,
and this cannot occur immediately (and can do random things like
accessing other references this object points to, or resurrecting the
object).

Let P = list of links created with rawrefcount.create_link_pypy()
and O = list of links created with rawrefcount.create_link_pyobj().
The PyPy objects in the list O are all W_CPyExtPlaceHolderObject: all
the data is in the PyObjects, and all outsite references (if any) are
in C, as ``PyObject *`` fields.

So, during the collection we do this about P links:

.. code-block:: python

    for (p, ob) in P:
        if ob->ob_refcnt != REFCNT_FROM_PYPY
               and ob->ob_refcnt != REFCNT_FROM_PYPY_LIGHT:
            mark 'p' as surviving, as well as all its dependencies

At the end of the collection, the P and O links are both handled like
this:

.. code-block:: python

    for (p, ob) in P + O:
        if p is not surviving:    # even if 'ob' might be surviving
            unlink p and ob
            if ob->ob_refcnt == REFCNT_FROM_PYPY_LIGHT:
                free(ob)
            elif ob->ob_refcnt > REFCNT_FROM_PYPY_LIGHT:
                ob->ob_refcnt -= REFCNT_FROM_PYPY_LIGHT
            else:
                ob->ob_refcnt -= REFCNT_FROM_PYPY
                if ob->ob_refcnt == 0:
                    invoke _Py_Dealloc(ob) later, outside the GC


GC Implementation
-----------------

We need two copies of both the P list and O list, for young or old
objects.  All four lists can be regular AddressLists of 'ob' objects.

We also need an AddressDict mapping 'p' to 'ob' for all links in the P
list, and update it when PyPy objects move.


Further notes
-------------

XXX
XXX the rest is the ideal world, but as a first step, we'll look
XXX for the minimal tweaks needed to adapt the existing cpyext
XXX

For objects that are opaque in CPython, like <dict>, we always create
a PyPy object, and then when needed we make an empty PyObject and
attach it with create_link_pypy()/REFCNT_FROM_PYPY_LIGHT.

For <int> and <float> objects, the corresponding PyObjects contain a
"long" or "double" field too.  We link them with create_link_pypy()
and we can use REFCNT_FROM_PYPY_LIGHT too: 'tp_dealloc' doesn't
need to be called, and instead just calling free() is fine.

For <type> objects, we need both a PyPy and a PyObject side.  These
are made with create_link_pypy()/REFCNT_FROM_PYPY.

For custom PyXxxObjects allocated from the C extension module, we
need create_link_pyobj().

For <str> or <unicode> objects coming from PyPy, we use
create_link_pypy()/REFCNT_FROM_PYPY_LIGHT with a PyObject
preallocated with the size of the string.  We copy the string
lazily into that area if PyString_AS_STRING() is called.

For <str>, <unicode>, <tuple> or <list> objects in the C extension
module, we first allocate it as only a PyObject, which supports
mutation of the data from C, like CPython.  When it is exported to
PyPy we could make a W_CPyExtPlaceHolderObject with
create_link_pyobj().

For <tuple> objects coming from PyPy, if they are not specialized,
then the PyPy side holds a regular reference to the items.  Then we
can allocate a PyTupleObject and store in it borrowed PyObject
pointers to the items.  Such a case is created with
create_link_pypy()/REFCNT_FROM_PYPY_LIGHT.  If it is specialized,
then it doesn't work because the items are created just-in-time on the
PyPy side.  In this case, the PyTupleObject needs to hold real
references to the PyObject items, and we use create_link_pypy()/
REFCNT_FROM_PYPY.  In all cases, we have a C array of PyObjects
that we can directly return from PySequence_Fast_ITEMS, PyTuple_ITEMS,
PyTuple_GetItem, and so on.

For <list> objects coming from PyPy, we can use a cpyext list
strategy.  The list turns into a PyListObject, as if it had been
allocated from C in the first place.  The special strategy can hold
(only) a direct reference to the PyListObject, and we can use either
create_link_pyobj() or create_link_pypy() (to be decided).
PySequence_Fast_ITEMS then works for lists too, and PyList_GetItem
can return a borrowed reference, and so on.
