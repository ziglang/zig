from rpython.rlib import jit
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rlib.rstruct.error import StructError
from rpython.rlib.rstruct.nativefmttable import native_is_bigendian, native_fmttable
from rpython.rlib.rstruct.standardfmttable import standard_fmttable
from rpython.rlib.unroll import unrolling_iterable


class FormatIterator(object):
    """
    An iterator-like object that follows format strings step by step.
    It provides input to the packer/unpacker and accumulates their output.
    The subclasses are specialized for either packing, unpacking, or
    just computing the size.
    """
    _mixin_ = True
    _operate_is_specialized_ = False

    @jit.look_inside_iff(lambda self, fmt: jit.isconstant(fmt))
    def interpret(self, fmt):
        # decode the byte order, size and alignment based on the 1st char
        table = unroll_native_fmtdescs
        self.bigendian = native_is_bigendian
        index = 0
        if len(fmt) > 0:
            c = fmt[0]
            index = 1
            if c == '@':
                pass
            elif c == '=':
                table = unroll_standard_fmtdescs
            elif c == '<':
                table = unroll_standard_fmtdescs
                self.bigendian = False
            elif c == '>' or c == '!':
                table = unroll_standard_fmtdescs
                self.bigendian = True
            else:
                index = 0

        # interpret the format string,
        # calling self.operate() for each format unit
        while index < len(fmt):
            c = fmt[index]
            index += 1
            if c.isspace():
                continue
            if c.isdigit():
                repetitions = ord(c) - ord('0')
                while True:
                    if index == len(fmt):
                        raise StructError("incomplete struct format")
                    c = fmt[index]
                    index += 1
                    if not c.isdigit():
                        break
                    try:
                        repetitions = ovfcheck(repetitions * 10)
                        repetitions = ovfcheck(repetitions + (ord(c) -
                                                              ord('0')))
                    except OverflowError:
                        raise StructError("overflow in item count")
                assert repetitions >= 0
            else:
                repetitions = 1

            for fmtdesc in table:
                if c == fmtdesc.fmtchar:
                    if self._operate_is_specialized_:
                        if fmtdesc.alignment > 1:
                            self.align(fmtdesc.mask)
                        self.operate(fmtdesc, repetitions)
                    break
            else:
                if c == '\0':
                    raise StructError("embedded null character")
                raise StructError("bad char in struct format")
            if not self._operate_is_specialized_:
                if fmtdesc.alignment > 1:
                    self.align(fmtdesc.mask)
                self.operate(fmtdesc, repetitions)
        self.finished()

    def finished(self):
        pass


class CalcSizeFormatIterator(FormatIterator):
    totalsize = 0

    def operate(self, fmtdesc, repetitions):
        try:
            size = ovfcheck(fmtdesc.size * repetitions)
            self.totalsize = ovfcheck(self.totalsize + size)
        except OverflowError:
            raise StructError("total struct size too long")

    def align(self, mask):
        pad = (-self.totalsize) & mask
        try:
            self.totalsize = ovfcheck(self.totalsize + pad)
        except OverflowError:
            raise StructError("total struct size too long")


class FmtDesc(object):
    def __init__(self, fmtchar, attrs):
        self.fmtchar = fmtchar
        self.alignment = 1      # by default
        self.needcount = False  # by default
        self.__dict__.update(attrs)
        self.mask = self.alignment - 1
        assert self.alignment & self.mask == 0, (
            "this module assumes that all alignments are powers of two")
    def _freeze_(self):
        return True

def table2desclist(table):
    items = table.items()
    items.sort()
    lst = [FmtDesc(key, attrs) for key, attrs in items]
    return unrolling_iterable(lst)


unroll_standard_fmtdescs = table2desclist(standard_fmttable)
unroll_native_fmtdescs   = table2desclist(native_fmttable)
