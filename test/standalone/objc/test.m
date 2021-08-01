#import "Foo.h"
#import <assert.h>

int main(int argc, char *argv[])
{
  @autoreleasepool {
      Foo *foo = [[Foo alloc] init];
      NSString *result = [foo name];
      assert([result isEqualToString:@"Zig"]);
      return 0;
  }
}
