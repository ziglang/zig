#import "Foo.h"
#import <assert.h>
#include <iostream>

int main(int argc, char *argv[])
{
  @autoreleasepool {
      Foo *foo = [[Foo alloc] init];
      NSString *result = [foo name];
      std::cout << "Hello from C++ and " << [result UTF8String];
      assert([result isEqualToString:@"Zig"]);
      return 0;
  }
}
