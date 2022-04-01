import md5    # for comparison
from rpython.rlib import rmd5


def test_digest_size():
    assert rmd5.digest_size == 16


def test_cases():
    """
    Feed example strings into a md5 object and check the digest and
    hexdigest.
    """
    cases = (
      ("",
       "d41d8cd98f00b204e9800998ecf8427e"),
      ("a",
       "0cc175b9c0f1b6a831c399e269772661"),
      ("abc",
       "900150983cd24fb0d6963f7d28e17f72"),
      ("message digest",
       "f96b697d7cb7938d525a2f31aaf161d0"),
      ("abcdefghijklmnopqrstuvwxyz",
       "c3fcd3d76192e4007dfb496cca67e13b"),
      ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
       "d174ab98d277d9f5a5611c2c9f419d9f"),
      ("1234567890"*8,
       "57edf4a22be3c955ac49da2e2107b67a"),
    )
    for input, expected in cases:
        d = rmd5.RMD5()
        d.update(input)
        assert d.hexdigest() == expected
        assert d.digest() == expected.decode('hex')


def test_more():
    "Test cases without known digest result."

    cases = (
      "123",
      "1234",
      "12345",
      "123456",
      "1234567",
      "12345678",
      "123456789 123456789 123456789 ",
      "123456789 123456789 ",
      "123456789 123456789 1",
      "123456789 123456789 12",
      "123456789 123456789 123",
      "123456789 123456789 1234",
      "123456789 123456789 123456789 1",
      "123456789 123456789 123456789 12",
      "123456789 123456789 123456789 123",
      "123456789 123456789 123456789 1234",
      "123456789 123456789 123456789 12345",
      "123456789 123456789 123456789 123456",
      "123456789 123456789 123456789 1234567",
      "123456789 123456789 123456789 12345678",
     )

    for input in cases:
        d = rmd5.RMD5(input)
        assert d.hexdigest() == md5.md5(input).hexdigest()
        assert d.digest() == md5.md5(input).digest()


def test_long():
    "Test cases with long messages (can take a while)."

    cases = (
      2**10*'a',
      2**10*'abcd',
      ##2**20*'a',  ## 1 MB, takes about 160 sec. on a 233 Mhz Pentium.
     )

    for input in cases:
        d = rmd5.RMD5(input)
        assert d.hexdigest() == md5.md5(input).hexdigest()
        assert d.digest() == md5.md5(input).digest()


def test_updating_many_times():
    "Test with an increasingly growing message."

    d1 = rmd5.RMD5()
    d2 = md5.md5()
    for i in range(300):
        d1.update(chr(i & 0xFF))
        d2.update(chr(i & 0xFF))
        assert d1.digest() == d2.digest()


def test_copy():
    "Test updating cloned objects."

    cases = (
      "123",
      "1234",
      "12345",
      "123456",
      "1234567",
      "12345678",
      "123456789 123456789 123456789 ",
      "123456789 123456789 ",
      "123456789 123456789 1",
      "123456789 123456789 12",
      "123456789 123456789 123",
      "123456789 123456789 1234",
      "123456789 123456789 123456789 1",
      "123456789 123456789 123456789 12",
      "123456789 123456789 123456789 123",
      "123456789 123456789 123456789 1234",
      "123456789 123456789 123456789 12345",
      "123456789 123456789 123456789 123456",
      "123456789 123456789 123456789 1234567",
      "123456789 123456789 123456789 12345678",
     )

    # Load both with same prefix.    
    prefix1 = 2**10 * 'a'

    m1 = md5.md5()
    m1.update(prefix1)

    m2 = rmd5.RMD5()
    m2.update(prefix1)

    # Update and compare...
    for message in cases:
        m1c = m1.copy()
        m1c.update(message)
        d1 = m1c.hexdigest()

        m2c = m2.copy()
        m2c.update(message)
        d2 = m2c.hexdigest()

        assert d1 == d2

def test_random():
    import random, md5
    for i in range(20):
        input = ''.join([chr(random.randrange(256))
                         for i in range(random.randrange(1000))])
        m1 = rmd5.RMD5()
        m1.update(input)
        m2 = md5.new()
        m2.update(input)
        assert m2.hexdigest() == m1.hexdigest()

