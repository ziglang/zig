from rpython.jit.metainterp.counter import JitCounter


def test_get_index():
    jc = JitCounter(size=128)    # 7 bits
    for i in range(10):
        hash = 400000001 * i
        index = jc._get_index(hash)
        assert index == (hash >> (32 - 7))

def test_get_subhash():
    assert JitCounter._get_subhash(0x518ebd) == 0x8ebd

def test_fetch_next_hash():
    jc = JitCounter(size=2048)
    # check the distribution of "fetch_next_hash() & ~7".
    blocks = [[jc.fetch_next_hash() & ~7 for i in range(65536)]
              for j in range(2)]
    for block in blocks:
        assert 0 <= jc._get_index(block[0]) < 2048
        assert 0 <= jc._get_index(block[-1]) < 2048
        assert 0 <= jc._get_index(block[2531]) < 2048
        assert 0 <= jc._get_index(block[45981]) < 2048
        # should be correctly distributed: ideally 2047 or 2048 different
        # values
        assert len(set([jc._get_index(x) for x in block])) >= 2040
    # check that the subkeys are distinct for same-block entries
    subkeys = {}
    for block in blocks:
        for x in block:
            idx = jc._get_index(x)
            subkeys.setdefault(idx, []).append(jc._get_subhash(x))
    collisions = 0
    for idx, sks in subkeys.items():
        collisions += len(sks) - len(set(sks))
    assert collisions < 5

def index2hash(jc, index, subhash=0):
    assert 0 <= subhash < 65536
    return (index << jc.shift) | subhash

def test_tick():
    jc = JitCounter()
    jc._tick_slowpath = "not callable in this test!"
    incr = jc.compute_threshold(4)
    for i in range(5):
        r = jc.tick(index2hash(jc, 104), incr)
        assert r is (i == 3)
    for i in range(5):
        r = jc.tick(index2hash(jc, 108), incr)
        s = jc.tick(index2hash(jc, 109), incr)
        assert r is (i == 3)
        assert s is (i == 3)
    jc.reset(index2hash(jc, 108))
    for i in range(5):
        r = jc.tick(index2hash(jc, 108), incr)
        assert r is (i == 3)

def test_collisions():
    jc = JitCounter(size=4)     # 2 bits
    incr = jc.compute_threshold(4)
    for i in range(5):
        for sk in range(100, 105):
            r = jc.tick(index2hash(jc, 3, subhash=sk), incr)
            assert r is (i == 3)

    jc = JitCounter()
    incr = jc.compute_threshold(4)
    misses = 0
    for i in range(5):
        for sk in range(100, 106):
            r = jc.tick(index2hash(jc, 3, subhash=sk), incr)
            if r:
                assert i == 3
            elif i == 3:
                misses += 1
    assert misses < 5


def test_install_new_chain():
    class Dead:
        next = None
        def should_remove_jitcell(self):
            return True
    class Alive:
        next = None
        def should_remove_jitcell(self):
            return False
    #
    jc = JitCounter()
    assert jc.lookup_chain(104) is None
    d1 = Dead() 
    jc.install_new_cell(104, d1)
    assert jc.lookup_chain(104) is d1
    d2 = Dead()
    jc.install_new_cell(104, d2)
    assert jc.lookup_chain(104) is d2
    assert d2.next is None
    #
    d3 = Alive()
    jc.install_new_cell(104, d3)
    assert jc.lookup_chain(104) is d3
    assert d3.next is None
    d4 = Alive()
    jc.install_new_cell(104, d4)
    assert jc.lookup_chain(104) is d3
    assert d3.next is d4
    assert d4.next is None


def test_change_current_fraction():
    jc = JitCounter()
    incr = jc.compute_threshold(8)
    # change_current_fraction() with a fresh new hash
    jc.change_current_fraction(index2hash(jc, 104), 0.95)
    r = jc.tick(index2hash(jc, 104), incr)
    assert r is True
    # change_current_fraction() with an already-existing hash
    r = jc.tick(index2hash(jc, 104), incr)
    assert r is False
    jc.change_current_fraction(index2hash(jc, 104), 0.95)
    r = jc.tick(index2hash(jc, 104), incr)
    assert r is True
    # change_current_fraction() with a smaller incr
    incr = jc.compute_threshold(32)
    jc.change_current_fraction(index2hash(jc, 104), 0.95)
    r = jc.tick(index2hash(jc, 104), incr)
    assert r is False
    r = jc.tick(index2hash(jc, 104), incr)
    assert r is True
