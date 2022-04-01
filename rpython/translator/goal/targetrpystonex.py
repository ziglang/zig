from rpython.translator.test import rpystone
from rpython.rlib.objectmodel import current_object_addr_as_int


def make_target_definition(LOOPS):
    def entry_point(loops):
        g = rpystone.g
        g.IntGlob = 0
        g.BoolGlob = 0
        g.Char1Glob = '\0'
        g.Char2Glob = '\0'
        for i in range(51):
            g.Array1Glob[i] = 0
        for i in range(51):
            for j in range(51):
                g.Array2Glob[i][j] = 0
        g.PtrGlb = None
        g.PtrGlbNext = None
        return rpystone.pystones(loops), current_object_addr_as_int(g)

    def target(*args):
        return entry_point, [int]
    
    def run(c_entry_point):
        res = c_entry_point(LOOPS)
        (benchtime, stones), _ = res
        print "translated rpystone.pystones time for %d passes = %g" % \
              (LOOPS, benchtime)
        print "This machine benchmarks at %g translated rpystone pystones/second" % (stones,)
        res = c_entry_point(50000)
        _, g_addr = res
        print "CPython:"
        benchtime, stones = rpystone.pystones(50000)
        print "rpystone.pystones time for %d passes = %g" % \
              (50000, benchtime)
        print "This machine benchmarks at %g rpystone pystones/second" % (stones,)

    return entry_point, target, run

