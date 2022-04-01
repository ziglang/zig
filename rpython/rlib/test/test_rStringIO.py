from rpython.rlib.rStringIO import RStringIO


def test_simple():
    f = RStringIO()
    f.write('hello')
    f.write(' world')
    assert f.getvalue() == 'hello world'

def test_write_many():
    f = RStringIO()
    for j in range(10):
        for i in range(253):
            f.write(chr(i))
    expected = ''.join([chr(i) for j in range(10) for i in range(253)])
    assert f.getvalue() == expected

def test_seek():
    f = RStringIO()
    f.write('0123')
    f.write('456')
    f.write('789')
    f.seek(4)
    f.write('AB')
    assert f.getvalue() == '0123AB6789'
    f.seek(-2, 2)
    f.write('CDE')
    assert f.getvalue() == '0123AB67CDE'
    f.seek(2, 0)
    f.seek(5, 1)
    f.write('F')
    assert f.getvalue() == '0123AB6FCDE'

def test_write_beyond_end():
    f = RStringIO()
    f.seek(20, 1)
    assert f.tell() == 20
    f.write('X')
    assert f.getvalue() == '\x00' * 20 + 'X'

def test_tell():
    f = RStringIO()
    f.write('0123')
    f.write('456')
    assert f.tell() == 7
    f.seek(2)
    for i in range(3, 20):
        f.write('X')
        assert f.tell() == i
    assert f.getvalue() == '01XXXXXXXXXXXXXXXXX'

    f.seek(1)
    f.close()
    assert f.tell() == 0

def test_read():
    f = RStringIO()
    assert f.read() == ''
    f.write('0123')
    f.write('456')
    assert f.read() == ''
    assert f.read(5) == ''
    assert f.tell() == 7
    f.seek(1)
    assert f.read() == '123456'
    assert f.tell() == 7
    f.seek(1)
    assert f.read(12) == '123456'
    assert f.tell() == 7
    f.seek(1)
    assert f.read(2) == '12'
    assert f.read(1) == '3'
    assert f.tell() == 4
    f.seek(0)
    assert f.read() == '0123456'
    assert f.tell() == 7
    f.seek(0)
    assert f.read(7) == '0123456'
    assert f.tell() == 7
    f.seek(15)
    assert f.read(2) == ''
    assert f.tell() == 15

def test_readline():
    f = RStringIO()
    f.write('foo\nbar\nbaz')
    f.seek(0)
    assert f.readline() == 'foo\n'
    assert f.readline(2) == 'ba'
    assert f.readline() == 'r\n'
    assert f.readline() == 'baz'
    assert f.readline() == ''

    f.seek(100000, 0)
    assert f.tell() == 100000
    assert f.readline() == ''

def test_truncate():
    f = RStringIO()
    f.truncate(20)
    assert f.getvalue() == ''
    assert f.tell() == 0
    f.write('\x00' * 25)
    f.seek(12)
    f.truncate(20)
    assert f.getvalue() == '\x00' * 20
    assert f.tell() == 20
    f.write('more')
    f.truncate(20)
    assert f.getvalue() == '\x00' * 20
    assert f.tell() == 20
    f.write('hello')
    f.write(' world')
    f.truncate(30)
    assert f.getvalue() == '\x00' * 20 + 'hello worl'
    f.truncate(25)
    assert f.getvalue() == '\x00' * 20 + 'hello'
    f.write('baz')
    f.write('egg')
    f.truncate(3)
    assert f.getvalue() == '\x00' * 3
    assert f.tell() == 3

def test_truncate_end():
    f = RStringIO()
    f.write("abc")
    f.seek(0)
    f.truncate(0)
    assert f.getvalue() == ""

def test_bug():
    f = RStringIO()
    f.write('0')
    f.write('1')
    f.write('2')
    assert f.getvalue() == '012'
    f.write('3')
    assert f.getvalue() == '0123'

def test_stress():
    import cStringIO, random
    f = RStringIO()
    expected = cStringIO.StringIO()
    for i in range(2000):
        r = random.random()
        if r < 0.15:
            p = random.randrange(-5000, 10000)
            if r < 0.05:
                mode = 0
            elif r < 0.1:
                mode = 1
            else:
                mode = 2
            print 'seek', p, mode
            f.seek(p, mode)
            expected.seek(p, mode)
        elif r < 0.6:
            buf = str(random.random())
            print 'write %d bytes' % len(buf)
            f.write(buf)
            expected.write(buf)
        elif r < 0.92:
            n = random.randrange(0, 100)
            print 'read %d bytes' % n
            data1 = f.read(n)
            data2 = expected.read(n)
            assert data1 == data2
        elif r < 0.97:
            print 'check tell()'
            assert f.tell() == expected.tell()
        else:
            print 'check getvalue()'
            assert f.getvalue() == expected.getvalue()
    assert f.getvalue() == expected.getvalue()
    assert f.tell() == expected.tell()
