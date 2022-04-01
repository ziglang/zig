
import unittest

class ExceptionTestCase(unittest.TestCase):
    def test_try_except_else_finally(self):
        hit_except = False
        hit_else = False
        hit_finally = False

        try:
            raise Exception('nyaa!')
        except:
            hit_except = True
        else:
            hit_else = True
        finally:
            hit_finally = True

        self.assertTrue(hit_except)
        self.assertTrue(hit_finally)
        self.assertFalse(hit_else)

    def test_try_except_else_finally_no_exception(self):
        hit_except = False
        hit_else = False
        hit_finally = False

        try:
            pass
        except:
            hit_except = True
        else:
            hit_else = True
        finally:
            hit_finally = True

        self.assertFalse(hit_except)
        self.assertTrue(hit_finally)
        self.assertTrue(hit_else)

    def test_try_except_finally(self):
        hit_except = False
        hit_finally = False

        try:
            raise Exception('yarr!')
        except:
            hit_except = True
        finally:
            hit_finally = True

        self.assertTrue(hit_except)
        self.assertTrue(hit_finally)

    def test_try_except_finally_no_exception(self):
        hit_except = False
        hit_finally = False

        try:
            pass
        except:
            hit_except = True
        finally:
            hit_finally = True

        self.assertFalse(hit_except)
        self.assertTrue(hit_finally)

    def test_try_except(self):
        hit_except = False

        try:
            raise Exception('ahoy!')
        except:
            hit_except = True

        self.assertTrue(hit_except)

    def test_try_except_no_exception(self):
        hit_except = False

        try:
            pass
        except:
            hit_except = True

        self.assertFalse(hit_except)

    def test_try_except_else(self):
        hit_except = False
        hit_else = False

        try:
            raise Exception('foo!')
        except:
            hit_except = True
        else:
            hit_else = True

        self.assertFalse(hit_else)
        self.assertTrue(hit_except)

    def test_try_except_else_no_exception(self):
        hit_except = False
        hit_else = False

        try:
            pass
        except:
            hit_except = True
        else:
            hit_else = True

        self.assertFalse(hit_except)
        self.assertTrue(hit_else)

    def test_try_finally_no_exception(self):
        hit_finally = False

        try:
            pass
        finally:
            hit_finally = True

        self.assertTrue(hit_finally)

    def test_nested(self):
        hit_finally = False
        hit_inner_except = False
        hit_inner_finally = False

        try:
            try:
                raise Exception('inner exception')
            except:
                hit_inner_except = True
            finally:
                hit_inner_finally = True
        finally:
            hit_finally = True

        self.assertTrue(hit_inner_except)
        self.assertTrue(hit_inner_finally)
        self.assertTrue(hit_finally)

    def test_nested_else(self):
        hit_else = False
        hit_finally = False
        hit_except = False
        hit_inner_except = False
        hit_inner_else = False

        try:
            try:
                pass
            except:
                hit_inner_except = True
            else:
                hit_inner_else = True

            raise Exception('outer exception')
        except:
            hit_except = True
        else:
            hit_else = True
        finally:
            hit_finally = True

        self.assertFalse(hit_inner_except)
        self.assertTrue(hit_inner_else)
        self.assertFalse(hit_else)
        self.assertTrue(hit_finally)
        self.assertTrue(hit_except)

if __name__ == '__main__':
    unittest.main()
