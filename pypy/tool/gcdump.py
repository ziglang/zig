#! /usr/bin/env python
"""
Prints a human-readable total out of a dumpfile produced
by gc.dump_rpy_heap(), and optionally a typeids.txt.

Syntax:  dump.py  <dumpfile>  [<typeids.txt>]

By default, typeids.txt is loaded from the same dir as dumpfile.
"""
import sys, array, struct, os


class Stat(object):
    summary = {}
    typeids = {0: '<GCROOT>'}
    BIGOBJ = 65536   # bytes

    def summarize(self, filename):
        a = self.load_dump_file(filename)
        self.summary = {}     # {typenum: [count, totalsize]}
        self.bigobjs = []     # list of individual (size, typenum)
        for obj in self.walk(a):
            self.add_object_summary(obj[2], obj[3])

    def load_typeids(self, filename_or_iter):
        self.typeids = Stat.typeids.copy()
        if isinstance(filename_or_iter, str):
            iter = open(filename_or_iter)
        else:
            iter = filename_or_iter
        for num, line in enumerate(iter):
            if num == 0:
                continue
            if not line:
                continue
            words = line.split()
            if words[0].startswith('member'):
                del words[0]
            if words[0] == 'GcStruct':
                del words[0]
            self.typeids[num] = ' '.join(words)

    def get_type_name(self, num):
        return self.typeids.get(num, '<typenum %d>' % num)

    def print_summary(self):
        items = self.summary.items()
        items.sort(key=lambda (typenum, stat): stat[1])    # sort by totalsize
        totalsize = 0
        for typenum, stat in items:
            totalsize += stat[1]
            print '%8d %8.2fM  %s' % (stat[0], stat[1] / (1024.0*1024.0),
                                      self.get_type_name(typenum))
        print 'total %.1fM' % (totalsize / (1024.0*1024.0),)
        print
        lst = sorted(self.bigobjs)[-10:]
        if lst:
            if len(lst) == len(self.bigobjs):
                print '%d objects take at least %d bytes each:' % (len(lst), self.BIGOBJ)
            else:
                print '%d largest single objects:' % (len(lst),)
            for size, typenum in lst:
                print '%8s %8.2fM  %s' % ('', size / (1024.0*1024.0),
                                          self.get_type_name(typenum))
        else:
            print 'No object takes at least %d bytes on its own.' % (self.BIGOBJ,)

    def load_dump_file(self, filename):
        f = open(filename, 'rb')
        f.seek(0, 2)
        end = f.tell()
        f.seek(0)
        a = array.array('l')
        a.fromfile(f, end / struct.calcsize('l'))
        f.close()
        return a

    def add_object_summary(self, typenum, sizeobj):
        if sizeobj >= self.BIGOBJ:
            self.bigobjs.append((sizeobj, typenum))
        try:
            stat = self.summary[typenum]
        except KeyError:
            stat = self.summary[typenum] = [0, 0]
        stat[0] += 1
        stat[1] += sizeobj

    def walk(self, a, start=0, stop=None):
        assert a[-1] == -1, "invalid or truncated dump file (or 32/64-bit mix)"
        assert a[-2] != -1, "invalid or truncated dump file (or 32/64-bit mix)"
        print >> sys.stderr, 'walking...',
        i = start
        if stop is None:
            stop = len(a)
        while i < stop:
            j = i + 3
            while a[j] != -1:
                j += 1
            yield (i, a[i], a[i+1], a[i+2], a[i+3:j])
            i = j + 1
        print >> sys.stderr, 'done'


if __name__ == '__main__':
    if len(sys.argv) <= 1:
        print >> sys.stderr, __doc__
        sys.exit(2)
    stat = Stat()
    stat.summarize(sys.argv[1])
    #
    if len(sys.argv) > 2:
        typeid_name = sys.argv[2]
    else:
        typeid_name = os.path.join(os.path.dirname(sys.argv[1]), 'typeids.txt')
    if os.path.isfile(typeid_name):
        stat.load_typeids(typeid_name)
    else:
        import zlib, gc
        stat.load_typeids(zlib.decompress(gc.get_typeids_z()).split("\n"))
    #
    stat.print_summary()
