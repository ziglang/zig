import random, py
from rpython.jit.backend.llsupport.asmmemmgr import AsmMemoryManager
from rpython.jit.backend.llsupport.asmmemmgr import MachineDataBlockWrapper
from rpython.jit.backend.llsupport.asmmemmgr import BlockBuilderMixin
from rpython.jit.backend.llsupport.codemap import CodemapStorage
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import debug


def test_get_index():
    memmgr = AsmMemoryManager(min_fragment=8,
                              num_indices=5)
    index = 0
    for length in range(100):
        assert memmgr._get_index(length) == index
        if length in [8, 11, 15, 21]:
            index += 1

def test_get_index_default_values():
    memmgr = AsmMemoryManager()
    jumps = [64, 86, 115, 154, 206, 275, 367, 490, 654, 873, 1165,
             1554, 2073, 2765, 3687, 4917, 6557, 8743, 11658, 15545,
             20727, 27637, 36850, 49134, 65513, 87351, 116469, 155293,
             207058, 276078, 368105]
    for i, jump in enumerate(jumps):
        assert memmgr._get_index(jump) == i
        assert memmgr._get_index(jump + 1) == i + 1

def test_add_free_block():
    memmgr = AsmMemoryManager(min_fragment=8,
                              num_indices=5)
    memmgr._add_free_block(10, 18)
    assert memmgr.free_blocks == {10: 18}
    assert memmgr.free_blocks_end == {18: 10}
    assert memmgr.blocks_by_size == [[10], [], [], [], []]
    memmgr._add_free_block(20, 30)
    assert memmgr.free_blocks == {10: 18, 20: 30}
    assert memmgr.free_blocks_end == {18: 10, 30: 20}
    assert memmgr.blocks_by_size == [[10], [20], [], [], []]
    memmgr._add_free_block(18, 20)   # merge both left and right
    assert memmgr.free_blocks == {10: 30}
    assert memmgr.free_blocks_end == {30: 10}
    assert memmgr.blocks_by_size == [[], [], [], [10], []]

def test_allocate_block():
    memmgr = AsmMemoryManager(min_fragment=8,
                              num_indices=5)
    memmgr._add_free_block(10, 18)
    memmgr._add_free_block(20, 30)
    (start, stop) = memmgr._allocate_block(4)
    assert (start, stop) == (10, 18)
    assert memmgr.free_blocks == {20: 30}
    assert memmgr.free_blocks_end == {30: 20}
    assert memmgr.blocks_by_size == [[], [20], [], [], []]
    (start, stop) = memmgr._allocate_block(4)
    assert (start, stop) == (20, 30)
    assert memmgr.free_blocks == {}
    assert memmgr.free_blocks_end == {}
    assert memmgr.blocks_by_size == [[], [], [], [], []]

def test_malloc_without_fragment():
    memmgr = AsmMemoryManager(min_fragment=8,
                              num_indices=5)
    memmgr._add_free_block(10, 18)
    memmgr._add_free_block(20, 30)
    for minsize in range(1, 11):
        for maxsize in range(minsize, 14):
            (start, stop) = memmgr.malloc(minsize, maxsize)
            if minsize <= 8:
                assert (start, stop) == (10, 18)
            else:
                assert (start, stop) == (20, 30)
            memmgr._add_free_block(start, stop)
    memmgr._add_free_block(40, 49)
    (start, stop) = memmgr.malloc(10, 10)
    assert (start, stop) == (20, 30)

def test_malloc_with_fragment():
    for reqsize in range(1, 33):
        memmgr = AsmMemoryManager(min_fragment=8,
                                  num_indices=5)
        memmgr._add_free_block(12, 44)
        (start, stop) = memmgr.malloc(reqsize, reqsize)
        if reqsize + 8 <= 32:
            assert (start, stop) == (12, 12 + reqsize)
            assert memmgr.free_blocks == {stop: 44}
            assert memmgr.free_blocks_end == {44: stop}
            assert [stop] in memmgr.blocks_by_size
        else:
            assert (start, stop) == (12, 44)
            assert memmgr.free_blocks == {}
            assert memmgr.free_blocks_end == {}
            assert memmgr.blocks_by_size == [[], [], [], [], []]


class TestAsmMemoryManager:
    AMMClass = AsmMemoryManager

    def setup_method(self, _):
        self.asmmemmgr = self.AMMClass(min_fragment=8,
                                       num_indices=10,
                                       large_alloc_size=8192)
        self.codemap = CodemapStorage()

    def teardown_method(self, _):
        self.asmmemmgr._delete()

    def test_malloc_simple(self):
        for i in range(100):
            while self.asmmemmgr.total_memory_allocated < 16384:
                reqsize = random.randrange(1, 200)
                (start, stop) = self.asmmemmgr.malloc(reqsize, reqsize)
                assert reqsize <= stop - start < reqsize + 8
                assert self.asmmemmgr.total_memory_allocated in [8192, 16384]
            self.teardown_method(None)
            self.setup_method(None)

    def test_random(self):
        seed = random.randrange(0, 10**5)
        print "random seed:", seed
        r = random.Random(seed)
        got = []
        real_use = 0
        prev_total = 0
        iterations_without_allocating_more = 0
        while True:
            #
            if got and (r.random() < 0.4 or len(got) == 1000):
                # free
                start, stop = got.pop(r.randrange(0, len(got)))
                self.asmmemmgr.free(start, stop)
                real_use -= (stop - start)
                assert real_use >= 0
            #
            else:
                # allocate
                reqsize = r.randrange(1, 200)
                if r.random() < 0.5:
                    reqmaxsize = reqsize
                else:
                    reqmaxsize = reqsize + r.randrange(0, 200)
                (start, stop) = self.asmmemmgr.malloc(reqsize, reqmaxsize)
                assert reqsize <= stop - start < reqmaxsize + 8
                for otherstart, otherstop in got:           # no overlap
                    assert otherstop <= start or stop <= otherstart
                got.append((start, stop))
                real_use += (stop - start)
                if self.asmmemmgr.total_memory_allocated == prev_total:
                    iterations_without_allocating_more += 1
                    if iterations_without_allocating_more == 40000:
                        break    # ok
                else:
                    new_total = self.asmmemmgr.total_memory_allocated
                    iterations_without_allocating_more = 0
                    print real_use, new_total
                    # We seem to never see a printed value greater
                    # than 131072.  Be reasonable and allow up to 147456.
                    assert new_total <= 147456
                    prev_total = new_total

    def test_insert_gcroot_marker(self):
        if self.AMMClass is not AsmMemoryManager:
            py.test.skip("not for TestFakeAsmMemoryManager")
        puts = []
        class FakeGcRootMap:
            def register_asm_addr(self, retaddr, mark):
                puts.append((retaddr, mark))

        #
        mc = BlockBuilderMixin()
        mc.writechar('X')
        mc.writechar('x')
        mc.insert_gcroot_marker(['a', 'b', 'c', 'd'])
        mc.writechar('Y')
        mc.writechar('y')
        mc.insert_gcroot_marker(['e', 'f', 'g'])
        mc.writechar('Z')
        mc.writechar('z')
        #
        gcrootmap = FakeGcRootMap()
        allblocks = []
        self.HAS_CODEMAP = False
        rawstart = mc.materialize(self, allblocks, gcrootmap)
        p = rffi.cast(rffi.CArrayPtr(lltype.Char), rawstart)
        assert p[0] == 'X'
        assert p[1] == 'x'
        assert p[2] == 'Y'
        assert p[3] == 'y'
        assert p[4] == 'Z'
        assert p[5] == 'z'
        # 'allblocks' should be one block of length 6 + 15
        # (15 = alignment - 1) containing the range(rawstart, rawstart + 6)
        [(blockstart, blockend)] = allblocks
        assert blockend == blockstart + 6 + (mc.ALIGN_MATERIALIZE - 1)
        assert blockstart <= rawstart < rawstart + 6 <= blockend
        assert puts == [(rawstart + 2, ['a', 'b', 'c', 'd']),
                        (rawstart + 4, ['e', 'f', 'g'])]


class TestFakeAsmMemoryManager(TestAsmMemoryManager):
    class AMMClass(AsmMemoryManager):
        def __init__(self, *args, **kwds):
            AsmMemoryManager.__init__(self, *args, **kwds)
            self._pool = [0x100000 + n * 8192 for n in range(18)]
            random.shuffle(self._pool)
        def _mmap_alloc(self, size):
            assert size == 8192
            return self._pool.pop()
        def _delete(self):
            pass


def test_blockbuildermixin(translated=True):
    mc = BlockBuilderMixin(translated)
    writtencode = []
    for i in range(mc.SUBBLOCK_SIZE * 2 + 3):
        assert mc.get_relative_pos() == i
        mc.writechar(chr(i % 255))
        writtencode.append(chr(i % 255))
    if translated:
        assert mc._cursubindex == 3
        assert mc._cursubblock
        assert mc._cursubblock.prev
        assert mc._cursubblock.prev.prev
        assert not mc._cursubblock.prev.prev.prev
    #
    for i in range(0, mc.SUBBLOCK_SIZE * 2 + 3, 2):
        mc.overwrite(i, chr((i + 63) % 255))
        writtencode[i] = chr((i + 63) % 255)
    #
    p = lltype.malloc(rffi.CCHARP.TO, mc.SUBBLOCK_SIZE * 2 + 3, flavor='raw')
    addr = rffi.cast(lltype.Signed, p)
    mc.copy_to_raw_memory(addr)
    #
    for i in range(mc.SUBBLOCK_SIZE * 2 + 3):
        assert p[i] == writtencode[i]
    #
    debug._log = debug.DebugLog()
    try:
        mc._dump(addr, 'test-logname-section')
        log = list(debug._log) 
    finally:
        debug._log = None
    encoded = ''.join(writtencode).encode('hex').upper()
    ataddr = '@%x' % addr
    assert log == [('test-logname-section',
                    [('debug_print', 'SYS_EXECUTABLE', '??'),
                     ('debug_print', 'CODE_DUMP', ataddr, '+0 ', encoded)])]
    
    lltype.free(p, flavor='raw')

def test_blockbuildermixin2():
    test_blockbuildermixin(translated=False)

def test_machinedatablock():
    ops = []
    class FakeMemMgr:
        _addr = 1597
        def open_malloc(self, minsize):
            result = (self._addr, self._addr + 100)
            ops.append(('malloc', minsize) + result)
            self._addr += 200
            return result
        def open_free(self, frm, to):
            ops.append(('free', frm, to))
            return to - frm >= 8
    #
    allblocks = []
    md = MachineDataBlockWrapper(FakeMemMgr(), allblocks)
    p = md.malloc_aligned(26, 16)
    assert p == 1600
    assert ops == [('malloc', 26 + 15, 1597, 1697)]
    del ops[:]
    #
    p = md.malloc_aligned(26, 16)
    assert p == 1632
    p = md.malloc_aligned(26, 16)
    assert p == 1664
    assert allblocks == []
    assert ops == []
    #
    p = md.malloc_aligned(27, 16)
    assert p == 1808
    assert allblocks == [(1597, 1697)]
    assert ops == [('free', 1690, 1697),
                   ('malloc', 27 + 15, 1797, 1897)]
    del ops[:]
    #
    md.done()
    assert allblocks == [(1597, 1697), (1797, 1835)]
    assert ops == [('free', 1835, 1897)]
