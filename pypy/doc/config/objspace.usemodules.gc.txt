Use the 'gc' module. 
This module is expected to be working and is included by default.
Note that since the gc module is highly implementation specific, it contains
only the ``collect`` function in PyPy, which forces a collection when compiled
with the framework or with Boehm.
