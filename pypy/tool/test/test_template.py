from rpython.tool.sourcetools import compile_template


some_global = 5

def test_template():
    init_value = 50

    def template(n):
        args = ['arg%d' % i for i in range(n)]
        yield     'def add(%s):' % (', '.join(args),)
        yield     '    total = init_value + some_global'
        for i in range(n):
            yield '    total += arg%d' % i
        yield     '    return total'

    add = compile_template(template(5), 'add')
    assert add(10000, 1000, 100, 10, 1) == 11166
