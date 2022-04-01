"""
Reference tracker for lltype data structures.
"""

import sys, os
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.memory.gcheader import header2obj
from rpython.translator.tool.reftracker import BaseRefTrackerPage, MARKER
from rpython.tool.uid import uid
from rpython.tool.identity_dict import identity_dict


class LLRefTrackerPage(BaseRefTrackerPage):
    def compute(self, objectlist, size_gc_header):
        self.size_gc_header = size_gc_header
        return BaseRefTrackerPage.compute(self, objectlist)

    def formatobject(self, o):
        lines = []
        for name, value in self.enum_content(o):
            if not isinstance(value, str):
                value = '0x%x' % uid(value)
            lines.append('%s = %s' % (name, value))
        s = '\n'.join(lines)
        t = shorttypename(lltype.typeOf(o))
        return t, s, ''

    def get_referrers(self, o):
        return []    # not implemented

    def get_referents(self, o):
        for name, value in self.enum_content(o):
            if not isinstance(value, str):
                yield value

    def edgelabel(self, o1, o2):
        slst = []
        for name, value in self.enum_content(o1):
            if value is o2:
                slst.append(name)
        return '/'.join(slst)

    def newpage(self, objectlist):
        return self.__class__(objectlist, self.size_gc_header)

    def normalize(self, o):
        if self.size_gc_header is not None:
            try:
                return header2obj[o]._obj
            except (KeyError, TypeError):
                pass
        return o

    def enum_content(self, o, name='', with_header=True):
        # XXX clean up
        T = lltype.typeOf(o)
        if (self.size_gc_header is not None and with_header
            and isinstance(T, lltype.ContainerType) and T._gckind == 'gc'):
            adr = llmemory.cast_ptr_to_adr(o._as_ptr())
            adr -= self.size_gc_header
            o = adr.get()._obj
            T = lltype.typeOf(o)
        if isinstance(T, lltype.Struct):
            try:
                gcobjptr = header2obj[o]
                fmt = '(%s)'
            except KeyError:
                gcobjptr = None
                fmt = '%s'
            for name in T._names:
                for name, value in self.enum_content(getattr(o, name), name,
                                                     with_header=False):
                    yield fmt % (name,), value
            if gcobjptr:
                if self.size_gc_header is not None:
                    for sub in self.enum_content(gcobjptr._obj,
                                                 with_header=False):
                        yield sub
                else:
                    # display as a link to avoid the same data showing up
                    # twice in the graph
                    yield 'header of', gcobjptr._obj
        elif isinstance(T, lltype.Array):
            for index, o1 in enumerate(o.items):
                for sub in self.enum_content(o1, str(index)):
                    yield sub
        elif isinstance(T, lltype.Ptr):
            if not o:
                yield name, 'null'
            else:
                yield name, self.normalize(lltype.normalizeptr(o)._obj)
        elif isinstance(T, lltype.OpaqueType) and hasattr(o, 'container'):
            T = lltype.typeOf(o.container)
            yield 'container', '<%s>' % (shorttypename(T),)
            for sub in self.enum_content(o.container, name, with_header=False):
                yield sub
        elif T == llmemory.Address:
            if not o:
                yield name, 'NULL'
            else:
                addrof = o.ref()
                T1 = lltype.typeOf(addrof)
                if (isinstance(T1, lltype.Ptr) and
                    isinstance(T1.TO, lltype.Struct) and
                    addrof._obj in header2obj):
                    yield name + ' @hdr', self.normalize(addrof._obj)
                else:
                    yield name + ' @', self.normalize(o.ptr._obj)
        else:
            yield name, str(o)

def shorttypename(T):
    return '%s %s' % (T.__class__.__name__, getattr(T, '__name__', ''))


def track(*ll_objects):
    """Invoke a dot+pygame object reference tracker."""
    lst = [MARKER]
    size_gc_header = None
    seen = identity_dict()
    for ll_object in ll_objects:
        if isinstance(ll_object, llmemory.GCHeaderOffset):
            size_gc_header = ll_object
            continue
        #if isinstance(lltype.typeOf(ll_object), lltype.Ptr):
        #    ptr = lltype.normalizeptr(ll_object)
        #    if ptr is not None:
        #        ll_object = ptr._obj
        #    else:
        #        ll_object = None
        if ll_object is not None and ll_object not in seen:
            lst.append(ll_object)
            seen[ll_object] = ll_object
    page = LLRefTrackerPage(lst, size_gc_header)
    # auto-expand one level, for now
    auto_expand = 1
    for i in range(auto_expand):
        page = page.content()
        for ll_object in lst[1:]:
            for name, value in page.enum_content(ll_object):
                if not isinstance(value, str) and value not in seen:
                    lst.append(value)
                    seen[value] = value
        page = page.newpage(lst)
    page.display()


if __name__ == '__main__':
    try:
        sys.path.remove(os.getcwd())
    except ValueError:
        pass
    T = lltype.GcArray(lltype.Signed)
    S = lltype.GcForwardReference()
    S.become(lltype.GcStruct('S', ('t', lltype.Ptr(T)),
                                  ('next', lltype.Ptr(S))))
    s = lltype.malloc(S)
    s.next = lltype.malloc(S)
    s.next.t = lltype.malloc(T, 5)
    s.next.t[1] = 123
    track(s)
