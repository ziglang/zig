# NOT_RPYTHON

import gc

def dump_rpy_heap(file):
    """Write a full dump of the objects in the heap to the given file
    (which can be a file, a file name, or a file descritor).
    Format for each object (each item is one machine word):

        [addr] [typeindex] [size] [addr1]..[addrn] [-1]

    where [addr] is the address of the object, [typeindex] and [size]
    are as get_rpy_type_index() and get_rpy_memory_usage() would return,
    and [addr1]..[addrn] are addresses of other objects that this object
    points to.  The full dump is a list of such objects, with a marker
    [0][0][0][-1] inserted after all GC roots, before all non-roots.

    If the argument is a filename and the 'zlib' module is available,
    we also write 'typeids.txt' and 'typeids.lst' in the same directory,
    if they don't already exist.
    """
    if isinstance(file, str):
        f = open(file, 'wb')
        gc._dump_rpy_heap(f.fileno())
        f.close()
        try:
            import zlib, os
        except ImportError:
            pass
        else:
            filename2 = os.path.join(os.path.dirname(file), 'typeids.txt')
            if not os.path.exists(filename2):
                data = zlib.decompress(gc.get_typeids_z())
                f = open(filename2, 'wb')
                f.write(data)
                f.close()
            filename2 = os.path.join(os.path.dirname(file), 'typeids.lst')
            if not os.path.exists(filename2):
                data = ''.join(['%d\n' % n for n in gc.get_typeids_list()])
                f = open(filename2, 'w')
                f.write(data)
                f.close()
    else:
        if isinstance(file, int):
            fd = file
        else:
            if hasattr(file, 'flush'):
                file.flush()
            fd = file.fileno()
        gc._dump_rpy_heap(fd)

class GcStats(object):
    def __init__(self, s):
        self._s = s
        for item in ('total_gc_memory', 'jit_backend_used',
                     'total_memory_pressure',
                     'total_allocated_memory', 'jit_backend_allocated',
                     'peak_memory', 'peak_allocated_memory', 'total_arena_memory',
                     'total_rawmalloced_memory', 'nursery_size',
                     'peak_arena_memory', 'peak_rawmalloced_memory',
                     ):
            setattr(self, item, self._format(getattr(self._s, item)))
        self.memory_used_sum = self._format(self._s.total_gc_memory + self._s.total_memory_pressure +
                                            self._s.jit_backend_used)
        self.memory_allocated_sum = self._format(self._s.total_allocated_memory + self._s.total_memory_pressure +
                                            self._s.jit_backend_allocated)
        self.total_gc_time = self._s.total_gc_time

    def _format(self, v):
        if v < 1000000:
            # bit unlikely ;-)
            return "%.1fkB" % (v / 1024.)
        return "%.1fMB" % (v / 1024. / 1024.)

    def __repr__(self):
        if self._s.total_memory_pressure != -1:
            extra = "\n    memory pressure:    %s" % self.total_memory_pressure
        else:
            extra = ""
        return """Total memory consumed:
    GC used:            %s (peak: %s)
       in arenas:            %s
       rawmalloced:          %s
       nursery:              %s
    raw assembler used: %s%s
    -----------------------------
    Total:              %s

    Total memory allocated:
    GC allocated:            %s (peak: %s)
       in arenas:            %s
       rawmalloced:          %s
       nursery:              %s
    raw assembler allocated: %s%s
    -----------------------------
    Total:                   %s

    Total time spent in GC:  %s
    """ % (self.total_gc_memory, self.peak_memory,
              self.total_arena_memory,
              self.total_rawmalloced_memory,
              self.nursery_size,
           self.jit_backend_used,
           extra,
           self.memory_used_sum,

           self.total_allocated_memory, self.peak_allocated_memory,
              self.peak_arena_memory,
              self.peak_rawmalloced_memory,
              self.nursery_size,
           self.jit_backend_allocated,
           extra,
           self.memory_allocated_sum,
           self.total_gc_time / 1000.0)


def get_stats(memory_pressure=False):
    return GcStats(gc._get_stats(memory_pressure=memory_pressure))
