Use the '_weakref' module, necessary for the standard lib 'weakref' module.
PyPy's weakref implementation is not completely stable yet. The first
difference to CPython is that weak references only go away after the next
garbage collection, not immediately. The other problem seems to be that under
certain circumstances (that we have not determined) weak references keep the
object alive.
