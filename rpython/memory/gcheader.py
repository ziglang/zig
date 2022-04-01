import weakref
from rpython.rtyper.lltypesystem import lltype, llmemory


# this is global because a header cannot be a header of more than one GcObj
header2obj = weakref.WeakKeyDictionary()


class GCHeaderBuilder(object):

    def __init__(self, HDR):
        """NOT_RPYTHON"""
        self.HDR = HDR
        #
        # The following used to be a weakref.WeakKeyDictionary(), but
        # the problem is that if you have a gcobj which has already a
        # weakref cached on it and the hash already cached in that
        # weakref, and later the hash of the gcobj changes (because it
        # is ll2ctypes-ified), then that gcobj cannot be used as a key
        # in a WeakKeyDictionary any more: from this point on,
        # 'ref(gcobj)' and 'ref(gcobj, callback)' return two objects
        # with different hashes... and so e.g. the sequence of
        # operations 'obj2header[x]=y; assert x in obj2header' fails.
        #
        # Instead, just use a regular dictionary and hope that not too
        # many objects would be reclaimed in a given GCHeaderBuilder
        # instance.
        self.obj2header = {}
        self.size_gc_header = llmemory.GCHeaderOffset(self)

    def header_of_object(self, gcptr):
        # XXX hackhackhack
        gcptr = gcptr._as_obj(check=False)
        if isinstance(gcptr, llmemory._gctransformed_wref):
            return self.obj2header[gcptr._ptr._as_obj(check=False)]
        return self.obj2header[gcptr]

    def object_from_header(headerptr):
        return header2obj[headerptr._as_obj(check=False)]
    object_from_header = staticmethod(object_from_header)

    def get_header(self, gcptr):
        return self.obj2header.get(gcptr._as_obj(check=False), None)

    def attach_header(self, gcptr, headerptr):
        gcobj = gcptr._as_obj()
        assert gcobj not in self.obj2header
        # sanity checks
        assert gcobj._TYPE._gckind == 'gc'
        assert not isinstance(gcobj._TYPE, lltype.GcOpaqueType)
        assert not gcobj._parentstructure()
        self.obj2header[gcobj] = headerptr
        header2obj[headerptr._obj] = gcptr._as_ptr()

    def new_header(self, gcptr):
        headerptr = lltype.malloc(self.HDR, immortal=True)
        self.attach_header(gcptr, headerptr)
        return headerptr

    def _freeze_(self):
        return True     # for reads of size_gc_header
