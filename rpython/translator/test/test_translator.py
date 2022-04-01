from rpython.translator.translator import TranslationContext


def example(d):
    try:
        d['key']
    except KeyError:
        d['key'] = 'value'

def test_example():
    t = TranslationContext()
    t.buildflowgraph(example)
    # this specific example triggered a bug in simplify.py
    #t.view()
