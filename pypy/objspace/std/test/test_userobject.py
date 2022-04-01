from pypy.interpreter import gateway


class AppTestUserObject:
    spaceconfig = {}

    def setup_class(cls):
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)
        def rand(space):
            import random
            return space.wrap(random.randrange(0, 5))
        cls.w_rand = cls.space.wrap(gateway.interp2app(rand))

    def test_hash(self):
        if not hasattr(self, 'runappdirect'):
            skip("disabled")
        if self.runappdirect:
            total = 500000
            def rand():
                import random
                return random.randrange(0, 5)
        else:
            total = 50
            rand = self.rand
        #
        class A(object):
            hash = None
        tail = any = A()
        tail.next = tail
        i = 0
        while i < total:
            a = A()
            a.next = tail.next
            tail.next = a
            for j in range(rand()):
                any = any.next
            if any.hash is None:
                any.hash = hash(any)
            else:
                assert any.hash == hash(any)
            i += 1
        i = 0
        while i < total:
            if any.hash is not None:
                assert any.hash == hash(any)
            any = any.next
            i += 1
