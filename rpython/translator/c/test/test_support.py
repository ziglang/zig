import random
from rpython.translator.c.support import gen_assignments


def test_gen_simple_assignments():
    yield gen_check, [('int @', 'a', 'a')]
    yield gen_check, [('int @', 'a', 'b')]
    yield gen_check, [('int @', 'a', 'b'),
                      ('int @', 'c', 'b')]
    yield gen_check, [('int @', 'a', 'b'),
                      ('int @', 'b', 'c')]
    yield gen_check, [('int @', 'b', 'c'),
                      ('int @', 'a', 'b')]
    yield gen_check, [('int @', 'a', 'b'),
                      ('int @', 'b', 'a')]
    yield gen_check, [('int @', 'a', 'b'),
                      ('int @', 'b', 'c'),
                      ('int @', 'd', 'b')]

def gen_check(input):
    for _, dst, src in input:
        print 'input:', dst, src
    result = ' '.join(gen_assignments(input))
    print result
    result = result.replace('{ int', '').replace('}', '').strip()
    d = {}
    for _, dst, src in input:
        d[src] = '<value of %s>' % (src,)
    exec(result, d)
    for _, dst, src in input:
        assert d[dst] == '<value of %s>' % (src,)

def test_gen_check():
    varlist = list('abcdefg')
    for i in range(100):
        random.shuffle(varlist)
        input = [('int @', varlist[n], random.choice(varlist))
                 for n in range(random.randrange(1, 7))]
        yield gen_check, input
