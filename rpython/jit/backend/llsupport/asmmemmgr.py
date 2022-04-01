import sys
from rpython.rlib.rarithmetic import intmask, r_uint, LONG_BIT
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib import rmmap
from rpython.rlib.debug import debug_start, debug_print, debug_stop
from rpython.rlib.debug import have_debug_prints
from rpython.rtyper.lltypesystem import lltype, rffi


class AsmMemoryManager(object):
    LARGE_ALLOC_SIZE = 1024 * 1024   # 1MB
    MIN_FRAGMENT = 64
    NUM_INDICES = 32     # good for all sizes between 64 bytes and ~490 KB
    _allocated = None

    def __init__(self, large_alloc_size = LARGE_ALLOC_SIZE,
                       min_fragment     = MIN_FRAGMENT,
                       num_indices      = NUM_INDICES):
        self.total_memory_allocated = r_uint(0)
        self.total_mallocs = r_uint(0)
        self.large_alloc_size = large_alloc_size
        self.min_fragment = min_fragment
        self.num_indices = num_indices
        self.free_blocks = {}      # map {start: stop}
        self.free_blocks_end = {}  # map {stop: start}
        self.blocks_by_size = [[] for i in range(self.num_indices)]

    def get_stats(self):
        """Returns stats for rlib.jit.jit_hooks.stats_asmmemmgr_*()."""
        return (self.total_memory_allocated, self.total_mallocs)

    def malloc(self, minsize, maxsize):
        """Allocate executable memory, between minsize and maxsize bytes,
        and return a pair (start, stop).  Does not perform any rounding
        of minsize and maxsize.
        """
        result = self._allocate_block(minsize)
        (start, stop) = result
        if maxsize <= stop - start - self.min_fragment:
            smaller_stop = start + maxsize
            self._add_free_block(smaller_stop, stop)
            stop = smaller_stop
            result = (start, stop)
        self.total_mallocs += r_uint(stop - start)
        return result   # pair (start, stop)

    def free(self, start, stop):
        """Free a block (start, stop) returned by a previous malloc()."""
        if r_uint is not None:
            self.total_mallocs -= r_uint(stop - start)
        self._add_free_block(start, stop)

    def open_malloc(self, minsize):
        """Allocate at least minsize bytes.  Returns (start, stop)."""
        result = self._allocate_block(minsize)
        (start, stop) = result
        self.total_mallocs += r_uint(stop - start)
        return result

    def open_free(self, middle, stop):
        """Used for freeing the end of an open-allocated block of memory."""
        if stop - middle >= self.min_fragment:
            self.total_mallocs -= r_uint(stop - middle)
            self._add_free_block(middle, stop)
            return True
        else:
            return False    # too small to record

    def _mmap_alloc(self, size):
        # overridden by a test
        data = rmmap.alloc(size)
        if not we_are_translated():
            if self._allocated is None:
                self._allocated = []
            self._allocated.append((data, size))
            if sys.maxint > 2147483647:
                # Hack to make sure that mcs are not within 32-bits of one
                # another for testing purposes
                rmmap.hint.pos += 0x80000000 - size
        return data

    def _allocate_large_block(self, minsize):
        # Compute 'size' from 'minsize': it must be rounded up to
        # 'large_alloc_size'.  Additionally, we use the following line
        # to limit how many mmap() requests the OS will see in total:
        minsize = max(minsize, intmask(self.total_memory_allocated >> 4))
        size = minsize + self.large_alloc_size - 1
        size = (size // self.large_alloc_size) * self.large_alloc_size
        data = self._mmap_alloc(size)
        self.total_memory_allocated += r_uint(size)
        data = rffi.cast(lltype.Signed, data)
        return self._add_free_block(data, data + size)

    def _get_index(self, length):
        i = 0
        while length > self.min_fragment:
            length = (length * 3) >> 2
            i += 1
            if i == self.num_indices - 1:
                break
        return i

    def _add_free_block(self, start, stop):
        # Merge with the block on the left
        if start in self.free_blocks_end:
            left_start = self.free_blocks_end[start]
            self._del_free_block(left_start, start)
            start = left_start
            assert start not in self.free_blocks_end
        # Merge with the block on the right
        if stop in self.free_blocks:
            right_stop = self.free_blocks[stop]
            self._del_free_block(stop, right_stop)
            stop = right_stop
            assert stop not in self.free_blocks
        # Add it to the dicts
        assert start not in self.free_blocks
        self.free_blocks[start] = stop
        assert stop not in self.free_blocks_end
        self.free_blocks_end[stop] = start
        i = self._get_index(stop - start)
        self.blocks_by_size[i].append(start)
        return start

    def _del_free_block(self, start, stop):
        del self.free_blocks[start]
        del self.free_blocks_end[stop]
        i = self._get_index(stop - start)
        self.blocks_by_size[i].remove(start)

    def _allocate_block(self, length):
        # First look in the group of index i0 if there is a block that is
        # big enough.  Following an idea found in the Linux malloc.c, we
        # prefer the oldest entries rather than the newest one, to let
        # them have enough time to coalesce into bigger blocks.  It makes
        # a big difference on the purely random test (30% of total usage).
        i0 = self._get_index(length)
        bbs = self.blocks_by_size[i0]
        for j in range(len(bbs)):
            start = bbs[j]
            stop = self.free_blocks[start]
            if start + length <= stop:
                del bbs[j]
                break   # found a block big enough
        else:
            # Then look in the larger groups
            i = i0 + 1
            while i < self.num_indices:
                if len(self.blocks_by_size[i]) > 0:
                    # any block found in a larger group is big enough
                    start = self.blocks_by_size[i].pop(0)
                    stop = self.free_blocks[start]
                    assert start + length <= stop
                    break
                i += 1
            else:
                # Exhausted the memory.  Allocate the resulting block.
                start = self._allocate_large_block(length)
                stop = self.free_blocks[start]
                i = self._get_index(stop - start)
                assert self.blocks_by_size[i][-1] == start
                self.blocks_by_size[i].pop()
        #
        del self.free_blocks[start]
        del self.free_blocks_end[stop]
        return (start, stop)

    def _delete(self):
        "NOT_RPYTHON"
        if self._allocated:
            for data, size in self._allocated:
                rmmap.free(data, size)
        self._allocated = None


class MachineDataBlockWrapper(object):
    def __init__(self, asmmemmgr, allblocks):
        self.asmmemmgr = asmmemmgr
        self.allblocks = allblocks
        self.rawstart    = 0
        self.rawposition = 0
        self.rawstop     = 0

    def done(self):
        if self.rawstart != 0:
            if self.asmmemmgr.open_free(self.rawposition, self.rawstop):
                self.rawstop = self.rawposition
            self.allblocks.append((self.rawstart, self.rawstop))
            self.rawstart    = 0
            self.rawposition = 0
            self.rawstop     = 0

    def _allocate_next_block(self, minsize):
        self.done()
        self.rawstart, self.rawstop = self.asmmemmgr.open_malloc(minsize)
        self.rawposition = self.rawstart

    def malloc_aligned(self, size, alignment):
        p = self.rawposition
        p = (p + alignment - 1) & (-alignment)
        if p + size > self.rawstop:
            self._allocate_next_block(size + alignment - 1)
            p = self.rawposition
            p = (p + alignment - 1) & (-alignment)
            assert p + size <= self.rawstop
        self.rawposition = p + size
        return p


class BlockBuilderMixin(object):
    _mixin_ = True
    # A base class to generate assembler.  It is equivalent to just a list
    # of chars, but it is potentially more efficient for that usage.
    # It works by allocating the assembler SUBBLOCK_SIZE bytes at a time.
    # Ideally, this number should be a power of two that fits the GC's most
    # compact allocation scheme (which is so far 35 * WORD for minimark.py).
    WORD = LONG_BIT // 8
    SUBBLOCK_SIZE = 32 * WORD
    SUBBLOCK_PTR = lltype.Ptr(lltype.GcForwardReference())
    SUBBLOCK = lltype.GcStruct('SUBBLOCK',
                   ('prev', SUBBLOCK_PTR),
                   ('data', lltype.FixedSizeArray(lltype.Char, SUBBLOCK_SIZE)))
    SUBBLOCK_PTR.TO.become(SUBBLOCK)

    ALIGN_MATERIALIZE = 16

    gcroot_markers = None

    def __init__(self, translated=None):
        if translated is None:
            translated = we_are_translated()
        if translated:
            self.init_block_builder()
        else:
            self._become_a_plain_block_builder()
        self.rawstart = 0

    def init_block_builder(self):
        self._cursubblock = lltype.nullptr(self.SUBBLOCK)
        self._baserelpos = -self.SUBBLOCK_SIZE
        self._make_new_subblock()

    def _make_new_subblock(self):
        nextsubblock = lltype.malloc(self.SUBBLOCK)
        nextsubblock.prev = self._cursubblock
        self._cursubblock = nextsubblock
        self._cursubindex = 0
        self._baserelpos += self.SUBBLOCK_SIZE
    _make_new_subblock._dont_inline_ = True

    def writechar(self, char):
        index = self._cursubindex
        if index == self.SUBBLOCK_SIZE:
            self._make_new_subblock()
            index = 0
        self._cursubblock.data[index] = char
        self._cursubindex = index + 1

    def absolute_addr(self):
        return self.rawstart

    def overwrite(self, index, char):
        assert 0 <= index < self.get_relative_pos(break_basic_block=False)
        block = self._cursubblock
        index -= self._baserelpos
        while index < 0:
            block = block.prev
            index += self.SUBBLOCK_SIZE
        block.data[index] = char

    def overwrite32(self, index, val):
        self.overwrite(index, chr(val & 0xff))
        self.overwrite(index + 1, chr((val >> 8) & 0xff))
        self.overwrite(index + 2, chr((val >> 16) & 0xff))
        self.overwrite(index + 3, chr((val >> 24) & 0xff))

    def get_relative_pos(self, break_basic_block=True):
        # 'break_basic_block' is only used in x86
        return self._baserelpos + self._cursubindex

    def copy_to_raw_memory(self, addr):
        # indirection for _become_a_plain_block_builder() and for subclasses
        self._copy_to_raw_memory(addr)

    def _copy_to_raw_memory(self, addr):
        block = self._cursubblock
        blocksize = self._cursubindex
        targetindex = self._baserelpos
        while targetindex >= 0:
            dst = rffi.cast(rffi.CCHARP, addr + targetindex)
            for j in range(blocksize):
                dst[j] = block.data[j]
            block = block.prev
            blocksize = self.SUBBLOCK_SIZE
            targetindex -= self.SUBBLOCK_SIZE
        assert not block

    def copy_core_dump(self, addr, offset=0, count=-1):
        HEX = '0123456789ABCDEF'
        dump = []
        src = rffi.cast(rffi.CCHARP, addr)
        end = self.get_relative_pos(break_basic_block=False)
        if count != -1:
            end = offset + count
        for p in range(offset, end):
            o = ord(src[p])
            dump.append(HEX[o >> 4])
            dump.append(HEX[o & 15])
        return ''.join(dump)

    def _dump(self, addr, logname, backend=None):
        debug_start(logname)
        if have_debug_prints():
            #
            if backend is not None:
                debug_print('BACKEND', backend)
            #
            from rpython.jit.backend.hlinfo import highleveljitinfo
            if highleveljitinfo.sys_executable:
                debug_print('SYS_EXECUTABLE', highleveljitinfo.sys_executable)
            else:
                debug_print('SYS_EXECUTABLE', '??')
            #
            dump = self.copy_core_dump(addr)
            debug_print('CODE_DUMP',
                        '@%x' % addr,
                        '+0 ',     # backwards compatibility
                        dump)
            #
        debug_stop(logname)

    def materialize(self, cpu, allblocks, gcrootmap=None):
        size = self.get_relative_pos()
        align = self.ALIGN_MATERIALIZE
        size += align - 1
        malloced = cpu.asmmemmgr.malloc(size, size)
        allblocks.append(malloced)
        rawstart = malloced[0]
        rawstart = (rawstart + align - 1) & (-align)
        self.rawstart = rawstart
        self.copy_to_raw_memory(rawstart)
        if self.gcroot_markers is not None:
            assert gcrootmap is not None
            for pos, mark in self.gcroot_markers:
                gcrootmap.register_asm_addr(rawstart + pos, mark)
        return rawstart

    def _become_a_plain_block_builder(self):
        # hack purely for speed of tests
        self._data = _data = []
        self.writechar = _data.append
        self.overwrite = _data.__setitem__
        def get_relative_pos(break_basic_block=True):
            return len(_data)
        self.get_relative_pos = get_relative_pos
        def plain_copy_to_raw_memory(addr):
            dst = rffi.cast(rffi.CCHARP, addr)
            for i, c in enumerate(_data):
                dst[i] = c
        self._copy_to_raw_memory = plain_copy_to_raw_memory

    def insert_gcroot_marker(self, mark):
        if self.gcroot_markers is None:
            self.gcroot_markers = []
        self.gcroot_markers.append(
            (self.get_relative_pos(break_basic_block=False), mark))
