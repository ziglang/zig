
def test_one():
    assert 1 == 10/10

def test_two():
    assert 2 == 3

def test_three():
    assert "hello" == "world"

def test_many():
    for i in range(100):
        yield test_one,

class TestStuff:

    def test_final(self):
        crash
