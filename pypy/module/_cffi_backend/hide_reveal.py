from rpython.rlib import rgc
from rpython.rlib.rweaklist import RWeakListMixin
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi


class HideRevealRWeakList:
    """Slow implementation of HideReveal: uses a RWeakListMixin."""

    def __init__(self):
        class GlobGcrefs(RWeakListMixin):
            pass
        glob_gcrefs = GlobGcrefs()
        glob_gcrefs.initialize()

        def hide_object(PTR, obj):
            # XXX leaks if we call this function often on the same object
            index = glob_gcrefs.add_handle(obj)
            return rffi.cast(PTR, index + 1)

        def reveal_object(Class, addr):
            index = rffi.cast(lltype.Signed, addr) - 1
            return glob_gcrefs.fetch_handle(index)

        self.hide_object = hide_object
        self.reveal_object = reveal_object

    def _freeze_(self):
        return True


class HideRevealCast:
    """Fast implementation of HideReveal: just a cast."""

    def __init__(self):

        def hide_object(PTR, obj):
            gcref = rgc.cast_instance_to_gcref(obj)
            raw = rgc.hide_nonmovable_gcref(gcref)
            return rffi.cast(PTR, raw)

        def reveal_object(Class, raw_ptr):
            addr = rffi.cast(llmemory.Address, raw_ptr)
            gcref = rgc.reveal_gcref(addr)
            return rgc.try_cast_gcref_to_instance(Class, gcref)

        self.hide_object = hide_object
        self.reveal_object = reveal_object

    def _freeze_(self):
        return True


def make_hide_reveal():
    hide_reveal_slow = HideRevealRWeakList()
    hide_reveal_fast = HideRevealCast()

    def hide_reveal():
        if rgc.must_split_gc_address_space():
            return hide_reveal_slow
        else:
            return hide_reveal_fast

    return hide_reveal

hide_reveal1 = make_hide_reveal()    # for ccallback.py
hide_reveal2 = make_hide_reveal()    # for handles.py
