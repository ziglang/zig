from rpython.rlib.debug import debug_start, debug_stop, debug_print
from rpython.rlib.objectmodel import compute_unique_id, we_are_translated

class InvalidRawOperation(Exception):
    pass

class InvalidRawWrite(InvalidRawOperation):
    pass

class InvalidRawRead(InvalidRawOperation):
    pass

class RawBuffer(object):
    def __init__(self, cpu, logops=None):
        # the following lists represents the writes in the buffer: values[i]
        # is the value of length lengths[i] stored at offset[i].
        #
        # the invariant is that they are ordered by offset, and that
        # offset[i]+length[i] <= offset[i+1], i.e. that the writes never
        # overlaps
        self.cpu = cpu
        self.logops = logops
        self.offsets = []
        self.lengths = []
        self.descrs = []
        self.values = []

    def _get_memory(self):
        """
        NOT_RPYTHON
        for testing only
        """
        return zip(self.offsets, self.lengths, self.descrs, self.values)

    def _repr_of_descr(self, descr):
        if self.logops:
            s = self.logops.repr_of_descr(descr)
        else:
            s = str(descr)
        s += " at %d" % compute_unique_id(descr)
        return s

    def _repr_of_value(self, value):
        if not we_are_translated() and isinstance(value, str):
            return value # for tests
        if self.logops:
            s = self.logops.repr_of_arg(value)
        else:
            s = str(value)
        s += " at %d" % compute_unique_id(value)
        return s

    def _dump_to_log(self):
        debug_print("RawBuffer state")
        debug_print("offset, length, descr, box")
        debug_print("(box == None means that the value is still virtual)")
        for i in range(len(self.offsets)):
            descr = self._repr_of_descr(self.descrs[i])
            box = self._repr_of_value(self.values[i])
            debug_print("%d, %d, %s, %s" % (self.offsets[i], self.lengths[i], descr, box))

    def _invalid_write(self, message, offset, length, descr, value):
        debug_start('jit-log-rawbuffer')
        debug_print('Invalid write: %s' % message)
        debug_print("  offset: %d" % offset)
        debug_print("  length: %d" % length)
        debug_print("  descr:  %s" % self._repr_of_descr(descr))
        debug_print("  value:  %s" % self._repr_of_value(value))
        self._dump_to_log()
        debug_stop('jit-log-rawbuffer')
        raise InvalidRawWrite

    def _invalid_read(self, message, offset, length, descr):
        debug_start('jit-log-rawbuffer')
        debug_print('Invalid read: %s' % message)
        debug_print("  offset: %d" % offset)
        debug_print("  length: %d" % length)
        debug_print("  descr:  %s" % self._repr_of_descr(descr))
        self._dump_to_log()
        debug_stop('jit-log-rawbuffer')
        raise InvalidRawRead

    def _descrs_are_compatible(self, d1, d2):
        # two arraydescrs are compatible if they have the same basesize,
        # itemsize and sign, even if they are not identical
        unpack = self.cpu.unpack_arraydescr_size
        return unpack(d1) == unpack(d2)

    def write_value(self, offset, length, descr, value):
        i = 0
        N = len(self.offsets)
        while i < N:
            if self.offsets[i] == offset:
                if (length != self.lengths[i] or not
                    self._descrs_are_compatible(descr, self.descrs[i])):
                    # in theory we could add support for the cases in which
                    # the length or descr is different, but I don't think we
                    # need it in practice
                    self._invalid_write('length or descr not compatible',
                                        offset, length, descr, value)
                # update the value at this offset
                self.values[i] = value
                return
            elif self.offsets[i] > offset:
                break
            i += 1
        #
        if i < len(self.offsets) and offset+length > self.offsets[i]:
            self._invalid_write("overlap with next bytes",
                                offset, length, descr, value)
        if i > 0 and self.offsets[i-1]+self.lengths[i-1] > offset:
            self._invalid_write("overlap with previous bytes",
                                offset, length, descr, value)
        # insert a new value at offset
        self.offsets.insert(i, offset)
        self.lengths.insert(i, length)
        self.descrs.insert(i, descr)
        self.values.insert(i, value)

    def read_value(self, offset, length, descr):
        i = 0
        N = len(self.offsets)
        while i < N:
            if self.offsets[i] == offset:
                if (length != self.lengths[i] or
                    not self._descrs_are_compatible(descr, self.descrs[i])):
                    self._invalid_read('length or descr not compatible',
                                       offset, length, descr)
                return self.values[i]
            i += 1
        # memory location not found: this means we are reading from
        # uninitialized memory, give up the optimization
        self._invalid_read('uninitialized memory',
                           offset, length, descr)
