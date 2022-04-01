"""
General-purpose reference tracker.
Usage: call track(obj).
"""

import sys, os, types
import gc
from rpython.translator.tool.graphpage import GraphPage, DotGen
from rpython.tool.uid import uid


MARKER = object()


class BaseRefTrackerPage(GraphPage):

    def compute(self, objectlist):
        assert objectlist[0] is MARKER
        self.objectlist = objectlist
        dotgen = DotGen('reftracker')
        id2typename = {}
        nodes = {}
        edges = {}

        def addedge(o1, o2):
            key = (uid(o1), uid(o2))
            edges[key] = self.edgelabel(o1, o2)

        for i in range(1, len(objectlist)):
            typename, s, linktext = self.formatobject(objectlist[i])
            word = '0x%x' % uid(objectlist[i])
            if linktext:
                self.links[word] = linktext
            s = '<%s> %s\\n%s' % (typename, word, s)
            nodename = 'node%d' % len(nodes)
            dotgen.emit_node(nodename, label=s, shape="box")
            nodes[uid(objectlist[i])] = nodename
            for o2 in self.get_referents(objectlist[i]):
                if o2 is None:
                    continue
                addedge(objectlist[i], o2)
                id2typename[uid(o2)] = self.shortrepr(o2)
                del o2
            for o2 in self.get_referrers(objectlist[i]):
                if o2 is None:
                    continue
                if type(o2) is list and o2 and o2[0] is MARKER:
                    continue
                addedge(o2, objectlist[i])
                id2typename[uid(o2)] = self.shortrepr(o2)
                del o2

        for ids, label in edges.items():
            for id1 in ids:
                if id1 not in nodes:
                    nodename = 'node%d' % len(nodes)
                    word = '0x%x' % id1
                    s = '<%s> %s' % (id2typename[id1], word)
                    dotgen.emit_node(nodename, label=s)
                    nodes[id1] = nodename
                    self.links[word] = s
            id1, id2 = ids
            dotgen.emit_edge(nodes[id1], nodes[id2], label=label)

        self.source = dotgen.generate(target=None)

    def followlink(self, word):
        id1 = int(word, 16)
        found = None
        objectlist = self.objectlist
        for i in range(1, len(objectlist)):
            for o2 in self.get_referents(objectlist[i]):
                if uid(o2) == id1:
                    found = o2
            for o2 in self.get_referrers(objectlist[i]):
                if uid(o2) == id1:
                    found = o2
        if found is not None:
            objectlist = objectlist + [found]
        else:
            print '*** NOTE: object not found'
        return self.newpage(objectlist)

    def formatobject(self, o):
        header = self.shortrepr(o, compact=False)
        secondline = repr(o.__class__)
        return header, secondline, repr(o)

    def shortrepr(self, o, compact=True):
        t = type(o)
        if t is types.FrameType:
            if compact:
                return 'frame %r' % (o.f_code.co_name,)
            else:
                return 'frame %r' % (o.f_code,)
        s = repr(o)
        if len(s) > 50:
            s = s[:20] + ' ... ' + s[-20:]
        if s.startswith('<') and s.endswith('>'):
            s = s[1:-1]
        return s

    def edgelabel(self, o1, o2):
        return ''

    def newpage(self, objectlist):
        return self.__class__(objectlist)


class RefTrackerPage(BaseRefTrackerPage):

    get_referrers = staticmethod(gc.get_referrers)
    get_referents = staticmethod(gc.get_referents)

    def edgelabel(self, o1, o2):
        slst = []
        if type(o1) in (list, tuple):
            for i in range(len(o1)):
                if o1[i] is o2:
                    slst.append('[%d]' % i)
        elif type(o1) is dict:
            for k, v in o1.items():
                if v is o2:
                    slst.append('[%r]' % (k,))
        else:
            for basetype in type(o1).__mro__:
                for key, value in basetype.__dict__.items():
                    if (type(value) is MemberDescriptorType or
                        type(value) is AttributeType):
                        try:
                            o1value = value.__get__(o1)
                        except:
                            pass
                        else:
                            if o1value is o2:
                                slst.append(str(key))
        return ', '.join(slst)


def track(*objs):
    """Invoke a dot+pygame object reference tracker."""
    page = RefTrackerPage([MARKER] + list(objs))
    del objs
    gc.collect()
    gc.collect()
    page.display()

def track_server(*objs, **kwds):
    page = RefTrackerPage([MARKER] + list(objs))
    del objs
    gc.collect()
    gc.collect()
    try:
        port = kwds.pop('port')
    except KeyError:
        port = 8888
    from rpython.translator.tool.graphserver import run_server
    run_server(page, port)


class _A(object):
    __slots__ = 'a'
class _B(object):
    pass
MemberDescriptorType = type(_A.a)
AttributeType = type(_B.__dict__['__dict__'])


if __name__ == '__main__':
    try:
        sys.path.remove(os.getcwd())
    except ValueError:
        pass
    class A(object):
        __slots__ = ['a']
    d = {"lskjadldjslkj": "adjoiadoixmdoiemdwoi"}
    a1 = A()
    a1.a = d
    track(d)
