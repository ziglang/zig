# Testing sha module (NIST's Secure Hash Algorithm)

# use the three examples from Federal Information Processing Standards
# Publication 180-1, Secure Hash Standard,  1995 April 17
# http://www.itl.nist.gov/div897/pubs/fip180-1.htm

from rpython.rlib import rsha

class TestSHA: 
    def check(self, data, digest):
        computed = rsha.new(data).hexdigest()
        assert computed == digest
        d = rsha.sha()
        d.update(data)
        computed = d.digest()
        assert computed == digest.decode('hex')

    def test_case_1(self):
        self.check("abc",
                   "a9993e364706816aba3e25717850c26c9cd0d89d")

    def test_case_2(self):
        self.check("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                   "84983e441c3bd26ebaae4aa1f95129e5e54670f1")

    def disabled_too_slow_test_case_3(self):
        self.check("a" * 1000000,
                   "34aa973cd4c4daa4f61eeb2bdbad27316534016f")

    def test_copy(self):
        import sha
        for repeat in [1, 10, 100]:
            d1 = rsha.sha("abc" * repeat)
            d2 = d1.copy()
            d1.update("def" * repeat)
            d2.update("gh" * repeat)
            assert d1.digest() == sha.sha("abc"*repeat+"def"*repeat).digest()
            assert d2.digest() == sha.sha("abc"*repeat+"gh"*repeat).digest()

    def test_random(self):
        import random, sha
        for i in range(20):
            input = ''.join([chr(random.randrange(256))
                             for i in range(random.randrange(1000))])
            m1 = rsha.RSHA()
            m1.update(input)
            m2 = sha.new()
            m2.update(input)
            assert m2.hexdigest() == m1.hexdigest()
