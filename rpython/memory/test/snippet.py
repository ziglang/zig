import os, py
from rpython.tool.udir import udir
from rpython.rlib import rgc
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop


class SemiSpaceGCTestDefines:
    large_tests_ok = False

    def definestr_finalizer_order(cls):
        import random
        from rpython.tool.algo import graphlib

        cls.finalizer_order_examples = examples = []
        if cls.large_tests_ok:
            letters = 'abcdefghijklmnopqrstuvwxyz'
            COUNT = 20
        else:
            letters = 'abcdefghijklm'
            COUNT = 2
        for i in range(COUNT):
            input = []
            edges = {}
            for c in letters:
                edges[c] = []
            # make up a random graph
            for c in letters:
                for j in range(random.randrange(0, 4)):
                    d = random.choice(letters)
                    edges[c].append(graphlib.Edge(c, d))
                    input.append((c, d))
            # find the expected order in which destructors should be called
            components = list(graphlib.strong_components(edges, edges))
            head = {}
            for component in components:
                c = component.keys()[0]
                for d in component:
                    assert d not in head
                    head[d] = c
            assert len(head) == len(letters)
            strict = []
            for c, d in input:
                if head[c] != head[d]:
                    strict.append((c, d))
            examples.append((input, components, strict))

        class State:
            pass
        state = State()
        def age_of(c):
            return state.age[ord(c) - ord('a')]
        def set_age_of(c, newvalue):
            # NB. this used to be a dictionary, but setting into a dict
            # consumes memory.  This has the effect that this test's
            # finalizer_trigger method can consume more memory and potentially
            # cause another collection.  This would result in objects
            # being unexpectedly destroyed at the same 'state.time'.
            state.age[ord(c) - ord('a')] = newvalue

        class A:
            def __init__(self, key):
                self.key = key
                self.refs = []
                fq.register_finalizer(self)

        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                from rpython.rlib.debug import debug_print
                while True:
                    a = self.next_dead()
                    if a is None:
                        break
                    debug_print("DEL:", a.key)
                    assert age_of(a.key) == -1
                    set_age_of(a.key, state.time)
                    state.progress = True
        fq = FQ()

        def build_example(input):
            state.time = 0
            state.age = [-1] * len(letters)
            vertices = {}
            for c in letters:
                vertices[c] = A(c)
            for c, d in input:
                vertices[c].refs.append(vertices[d])

        def f(_):
            i = 0
            while i < len(examples):
                input, components, strict = examples[i]
                build_example(input)
                while state.time < len(letters):
                    from rpython.rlib.debug import debug_print
                    debug_print("STATE.TIME:", state.time)
                    state.progress = False
                    llop.gc__collect(lltype.Void)
                    if not state.progress:
                        break
                    state.time += 1
                # summarize the finalization order
                lst = []
                for c in letters:
                    lst.append('%s:%d' % (c, age_of(c)))
                summary = ', '.join(lst)

                # check that all instances have been finalized
                if -1 in state.age:
                    return error(i, summary, "not all instances finalized")
                # check that if a -> b and a and b are not in the same
                # strong component, then a is finalized strictly before b
                for c, d in strict:
                    if age_of(c) >= age_of(d):
                        return error(i, summary,
                                     "%s should be finalized before %s"
                                     % (c, d))
                # check that two instances in the same strong component
                # are never finalized during the same collection
                for component in components:
                    seen = {}
                    for c in component:
                        age = age_of(c)
                        if age in seen:
                            d = seen[age]
                            return error(i, summary,
                                         "%s and %s should not be finalized"
                                         " at the same time" % (c, d))
                        seen[age] = c
                i += 1
            return "ok"

        def error(i, summary, msg):
            return '%d\n%s\n%s' % (i, summary, msg)

        return f

    def test_finalizer_order(self):
        res = self.run('finalizer_order')
        if res != "ok":
            i, summary, msg = res.split('\n')
            i = int(i)
            import pprint
            print 'Example:'
            pprint.pprint(self.finalizer_order_examples[i])
            print 'Finalization ages:'
            print summary
            print msg
            py.test.fail(msg)


    def define_from_objwithfinalizer_to_youngobj(cls):
        import gc
        if cls.large_tests_ok:
            MAX = 500000
        else:
            MAX = 150

        class B:
            count = 0
        class A:
            pass

        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while True:
                    a = self.next_dead()
                    if a is None:
                        break
                    a.b.count += 1
        fq = FQ()

        def g():
            b = B()
            a = A()
            fq.register_finalizer(a)
            a.b = b
            i = 0
            lst = [None]
            while i < MAX:
                lst[0] = str(i)
                i += 1
            return a.b, lst
        g._dont_inline_ = True

        def f():
            b, lst = g()
            gc.collect()
            return b.count
        return f

    def test_from_objwithfinalizer_to_youngobj(self):
        res = self.run('from_objwithfinalizer_to_youngobj')
        assert res == 1

class SemiSpaceGCTests(SemiSpaceGCTestDefines):
    # xxx messy

    def run(self, name): # for test_gc.py
        if name == 'finalizer_order':
            func = self.definestr_finalizer_order()
            res = self.interpret(func, [-1])
            return ''.join(res.chars) 
        elif name == 'from_objwithfinalizer_to_youngobj':
            func = self.define_from_objwithfinalizer_to_youngobj()
            return self.interpret(func, [])
        else:
            assert 0, "don't know what to do with that"
