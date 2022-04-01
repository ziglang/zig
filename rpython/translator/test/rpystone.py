#! /usr/bin/env python

"""
"PYSTONE" Benchmark Program

Version:        Python/1.1 (corresponds to C/1.1 plus 2 Pystone fixes)

Author:         Reinhold P. Weicker,  CACM Vol 27, No 10, 10/84 pg. 1013.

                Translated from ADA to C by Rick Richardson.
                Every method to preserve ADA-likeness has been used,
                at the expense of C-ness.

                Translated from C to Python by Guido van Rossum.

Version History:

                Version 1.1 corrects two bugs in version 1.0:

                First, it leaked memory: in Proc1(), NextRecord ends
                up having a pointer to itself.  I have corrected this
                by zapping NextRecord.PtrComp at the end of Proc1().

                Second, Proc3() used the operator != to compare a
                record to None.  This is rather inefficient and not
                true to the intention of the original benchmark (where
                a pointer comparison to None is intended; the !=
                operator attempts to find a method __cmp__ to do value
                comparison of the record).  Version 1.1 runs 5-10
                percent faster than version 1.0, so benchmark figures
                of different versions can't be compared directly.

"""

LOOPS = 50000

# use a global instance instead of globals
class G:pass
g = G()

import sys

from time import clock

__version__ = "1.1"

[Ident1, Ident2, Ident3, Ident4, Ident5] = range(1, 6)

class Record:

    def __init__(self, PtrComp = None, Discr = 0, EnumComp = 0,
                       IntComp = 0, StringComp = ""):
        self.PtrComp = PtrComp
        self.Discr = Discr
        self.EnumComp = EnumComp
        self.IntComp = IntComp
        self.StringComp = StringComp

    def copy(self):
        return Record(self.PtrComp, self.Discr, self.EnumComp,
                      self.IntComp, self.StringComp)

TRUE = 1
FALSE = 0

def main(loops=LOOPS):
    benchtime, stones = pystones(abs(loops))
    if loops >= 0:
        print "Pystone(%s) time for %d passes = %g" % \
              (__version__, loops, benchtime)
        print "This machine benchmarks at %g pystones/second" % stones


def pystones(loops=LOOPS):
    return Proc0(loops)

g.IntGlob = 0
g.BoolGlob = FALSE
g.Char1Glob = '\0'
g.Char2Glob = '\0'
g.Array1Glob = [0]*51
g.Array2Glob = map(lambda x: x[:], [g.Array1Glob]*51)
g.PtrGlb = None
g.PtrGlbNext = None

def Proc0(loops=LOOPS):
    #global IntGlob
    #global BoolGlob
    #global Char1Glob
    #global Char2Glob
    #global Array1Glob
    #global Array2Glob
    #global PtrGlb
    #global PtrGlbNext

    starttime = clock()
    #for i in range(loops):
    # this is bad with very large values of loops
    # XXX xrange support?
    i = 0
    while i < loops:
        i += 1
    # the above is most likely to vanish in C :-(
    nulltime = clock() - starttime

    g.PtrGlbNext = Record()
    g.PtrGlb = Record()
    g.PtrGlb.PtrComp = g.PtrGlbNext
    g.PtrGlb.Discr = Ident1
    g.PtrGlb.EnumComp = Ident3
    g.PtrGlb.IntComp = 40
    g.PtrGlb.StringComp = "DHRYSTONE PROGRAM, SOME STRING"
    String1Loc = "DHRYSTONE PROGRAM, 1'ST STRING"
    g.Array2Glob[8][7] = 10

    EnumLoc = None # addition for flow space
    starttime = clock()

    #for i in range(loops):
    # this is bad with very large values of loops
    # XXX xrange support?
    i = 0
    while i < loops:
        Proc5()
        Proc4()
        IntLoc1 = 2
        IntLoc2 = 3
        String2Loc = "DHRYSTONE PROGRAM, 2'ND STRING"
        EnumLoc = Ident2
        g.BoolGlob = not Func2(String1Loc, String2Loc)
        while IntLoc1 < IntLoc2:
            IntLoc3 = 5 * IntLoc1 - IntLoc2
            IntLoc3 = Proc7(IntLoc1, IntLoc2)
            IntLoc1 = IntLoc1 + 1
        Proc8(g.Array1Glob, g.Array2Glob, IntLoc1, IntLoc3)
        g.PtrGlb = Proc1(g.PtrGlb)
        CharIndex = 'A'
        while CharIndex <= g.Char2Glob:
            if EnumLoc == Func1(CharIndex, 'C'):
                EnumLoc = Proc6(Ident1)
            CharIndex = chr(ord(CharIndex)+1)
        IntLoc3 = IntLoc2 * IntLoc1
        IntLoc2 = IntLoc3 / IntLoc1
        IntLoc2 = 7 * (IntLoc3 - IntLoc2) - IntLoc1
        IntLoc1 = Proc2(IntLoc1)
        i += 1

    benchtime = clock() - starttime - nulltime
    if benchtime < 1E-8:
        benchtime = 1E-8   # time too short, meaningless results anyway
    return benchtime, (loops / benchtime)

def Proc1(PtrParIn):
    PtrParIn.PtrComp = NextRecord = g.PtrGlb.copy()
    PtrParIn.IntComp = 5
    NextRecord.IntComp = PtrParIn.IntComp
    NextRecord.PtrComp = PtrParIn.PtrComp
    NextRecord.PtrComp = Proc3(NextRecord.PtrComp)
    if NextRecord.Discr == Ident1:
        NextRecord.IntComp = 6
        NextRecord.EnumComp = Proc6(PtrParIn.EnumComp)
        NextRecord.PtrComp = g.PtrGlb.PtrComp
        NextRecord.IntComp = Proc7(NextRecord.IntComp, 10)
    else:
        PtrParIn = NextRecord.copy()
    NextRecord.PtrComp = None
    return PtrParIn

def Proc2(IntParIO):
    IntLoc = IntParIO + 10
    EnumLoc = None # addition for flow space
    while 1:
        if g.Char1Glob == 'A':
            IntLoc = IntLoc - 1
            IntParIO = IntLoc - g.IntGlob
            EnumLoc = Ident1
        if EnumLoc == Ident1:
            break
    return IntParIO

def Proc3(PtrParOut):
    #global IntGlob

    if g.PtrGlb is not None:
        PtrParOut = g.PtrGlb.PtrComp
    else:
        g.IntGlob = 100
    g.PtrGlb.IntComp = Proc7(10, g.IntGlob)
    return PtrParOut

def Proc4():
    #global Char2Glob

    BoolLoc = g.Char1Glob == 'A'
    BoolLoc = BoolLoc or g.BoolGlob
    g.Char2Glob = 'B'

def Proc5():
    #global Char1Glob
    #global BoolGlob

    g.Char1Glob = 'A'
    g.BoolGlob = FALSE

def Proc6(EnumParIn):
    EnumParOut = EnumParIn
    if not Func3(EnumParIn):
        EnumParOut = Ident4
    if EnumParIn == Ident1:
        EnumParOut = Ident1
    elif EnumParIn == Ident2:
        if g.IntGlob > 100:
            EnumParOut = Ident1
        else:
            EnumParOut = Ident4
    elif EnumParIn == Ident3:
        EnumParOut = Ident2
    elif EnumParIn == Ident4:
        pass
    elif EnumParIn == Ident5:
        EnumParOut = Ident3
    return EnumParOut

def Proc7(IntParI1, IntParI2):
    IntLoc = IntParI1 + 2
    IntParOut = IntParI2 + IntLoc
    return IntParOut

def Proc8(Array1Par, Array2Par, IntParI1, IntParI2):
    #global IntGlob

    IntLoc = IntParI1 + 5
    Array1Par[IntLoc] = IntParI2
    Array1Par[IntLoc+1] = Array1Par[IntLoc]
    Array1Par[IntLoc+30] = IntLoc
    for IntIndex in range(IntLoc, IntLoc+2):
        Array2Par[IntLoc][IntIndex] = IntLoc
    Array2Par[IntLoc][IntLoc-1] = Array2Par[IntLoc][IntLoc-1] + 1
    Array2Par[IntLoc+20][IntLoc] = Array1Par[IntLoc]
    g.IntGlob = 5

def Func1(CharPar1, CharPar2):
    CharLoc1 = CharPar1
    CharLoc2 = CharLoc1
    if CharLoc2 != CharPar2:
        return Ident1
    else:
        return Ident2

def Func2(StrParI1, StrParI2):
    IntLoc = 1
    while IntLoc <= 1:
        if Func1(StrParI1[IntLoc], StrParI2[IntLoc+1]) == Ident1:
            CharLoc = 'A'
            IntLoc = IntLoc + 1
    if CharLoc >= 'W' and CharLoc <= 'Z':
        IntLoc = 7
    if CharLoc == 'X':
        return TRUE
    else:
        if StrParI1 > StrParI2:
            IntLoc = IntLoc + 7
            return TRUE
        else:
            return FALSE

def Func3(EnumParIn):
    EnumLoc = EnumParIn
    if EnumLoc == Ident3: return TRUE
    return FALSE

def error(msg):
    print >> sys.stderr, msg,
    print >> sys.stderr, "usage: %s [number_of_loops]" % sys.argv[0]
    sys.exit(100)

def entrypoint(loops=None):
    import string # just a little test
    print string.replace("import works", "s", "x")
    if loops is None:
        loops = LOOPS  # initialize early, for slow space
        nargs = len(sys.argv) - 1
        if nargs > 1:
            error("%d arguments are too many;" % nargs)
        elif nargs == 1:
            try: loops = int(sys.argv[1])
            except ValueError:
                error("Invalid argument %r;" % sys.argv[1])
        else:
            if hasattr(sys, 'pypy_objspaceclass'):
                loops = LOOPS / 2000 # XXX rough estimate, adjust
    main(loops)

if __name__ == '__main__':
    entrypoint()
