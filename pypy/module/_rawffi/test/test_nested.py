class AppTestNested:
    spaceconfig = dict(usemodules=['_rawffi', 'struct'])

    def test_inspect_structure(self):
        import _rawffi, struct

        E = _rawffi.Structure([])
        assert E.size == 0
        assert E.alignment == 1
        
        align = max(struct.calcsize("i"), struct.calcsize("P"))
        assert align & (align-1) == 0, "not a power of 2??"
        def round_up(x):
            return (x+align-1) & -align

        S = _rawffi.Structure([('a', 'i'), ('b', 'P'), ('c', 'c')])
        assert S.size == round_up(struct.calcsize("iPc"))
        assert S.alignment == align
        assert S.fieldoffset('a') == 0
        assert S.fieldoffset('b') == align
        assert S.fieldoffset('c') == round_up(struct.calcsize("iP"))
        assert S.size_alignment() == (S.size, S.alignment)
        assert S.size_alignment(1) == (S.size, S.alignment)

    def test_opaque_structure(self):
        import _rawffi
        # define opaque structure with size = 200 and aligment = 16
        N = _rawffi.Structure((200, 16))
        assert N.size == 200
        assert N.alignment == 16
        assert N.size_alignment() == (200, 16)
        assert N.size_alignment(1) == (200, 16)
        raises(AttributeError, N.fieldoffset, '_')
        n = N()
        n.free()

    def test_nested_structures(self):
        import _rawffi
        S1 = _rawffi.Structure([('a', 'i'), ('b', 'P'), ('c', 'c')])
        S = _rawffi.Structure([('x', 'c'), ('s1', (S1, 1))])
        assert S.size == S1.alignment + S1.size
        assert S.alignment == S1.alignment
        assert S.fieldoffset('x') == 0
        assert S.fieldoffset('s1') == S1.alignment
        s = S()
        s.x = b'G'
        raises(TypeError, 's.s1')
        assert s.fieldaddress('s1') == s.buffer + S.fieldoffset('s1')
        s1 = S1.fromaddress(s.fieldaddress('s1'))
        s1.c = b'H'
        rawbuf = _rawffi.Array('c').fromaddress(s.buffer, S.size)
        assert rawbuf[0] == b'G'
        assert rawbuf[S1.alignment + S1.fieldoffset('c')] == b'H'
        s.free()

    def test_array_of_structures(self):
        import _rawffi
        S = _rawffi.Structure([('a', 'i'), ('b', 'P'), ('c', 'c')])
        A = _rawffi.Array((S, 1))
        a = A(3)
        raises(TypeError, "a[0]")
        s0 = S.fromaddress(a.buffer)
        s0.c = b'B'
        assert a.itemaddress(1) == a.buffer + S.size
        s1 = S.fromaddress(a.itemaddress(1))
        s1.c = b'A'
        s2 = S.fromaddress(a.itemaddress(2))
        s2.c = b'Z'
        rawbuf = _rawffi.Array('c').fromaddress(a.buffer, S.size * len(a))
        ofs = S.fieldoffset('c')
        assert rawbuf[0*S.size+ofs] == b'B'
        assert rawbuf[1*S.size+ofs] == b'A'
        assert rawbuf[2*S.size+ofs] == b'Z'
        a.free()

    def test_array_of_array(self):
        import _rawffi, struct
        B = _rawffi.Array('i')
        sizeofint = struct.calcsize("i")
        assert B.size_alignment(100) == (sizeofint * 100, sizeofint)
        A = _rawffi.Array((B, 4))
        a = A(2)
        b0 = B.fromaddress(a.itemaddress(0), 4)
        b0[0] = 3
        b0[3] = 7
        b1 = B.fromaddress(a.itemaddress(1), 4)
        b1[0] = 13
        b1[3] = 17
        rawbuf = _rawffi.Array('i').fromaddress(a.buffer, 2 * 4)
        assert rawbuf[0] == 3
        assert rawbuf[3] == 7
        assert rawbuf[4] == 13
        assert rawbuf[7] == 17
        a.free()

    def test_array_in_structures(self):
        import _rawffi, struct
        A = _rawffi.Array('i')
        S = _rawffi.Structure([('x', 'c'), ('ar', (A, 5))])
        A5size, A5alignment = A.size_alignment(5)
        assert S.size == A5alignment + A5size
        assert S.alignment == A5alignment
        assert S.fieldoffset('x') == 0
        assert S.fieldoffset('ar') == A5alignment
        s = S()
        s.x = b'G'
        raises(TypeError, 's.ar')
        assert s.fieldaddress('ar') == s.buffer + S.fieldoffset('ar')
        a1 = A.fromaddress(s.fieldaddress('ar'), 5)
        a1[4] = 33
        rawbuf = _rawffi.Array('c').fromaddress(s.buffer, S.size)
        assert rawbuf[0] == b'G'
        sizeofint = struct.calcsize("i")
        v = 0
        for i in range(sizeofint):
            v += ord(rawbuf[A5alignment + sizeofint*4+i])
        assert v == 33
        s.free()
