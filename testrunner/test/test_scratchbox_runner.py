import scratchbox_runner

def test_scratchbox():
    expected = ['/scratchbox/login', '-d', 'x/y', 'a', 'b']
    assert scratchbox_runner.args_for_scratchbox('x/y', ['a', 'b']) == expected
