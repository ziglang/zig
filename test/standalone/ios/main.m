#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

int main() {
  @autoreleasepool {
    return UIApplicationMain(0, nil, nil, NSStringFromClass([AppDelegate class]));
  }
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)options {
  CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
  self.window = [[UIWindow alloc] initWithFrame:mainScreenBounds];
  UIViewController *viewController = [[UIViewController alloc] init];
  viewController.view.frame = mainScreenBounds;

  NSString* msg = @"Hello world";

  UILabel *label = [[UILabel alloc] initWithFrame:mainScreenBounds];
  [label setText:msg];
  [viewController.view addSubview: label];

  self.window.rootViewController = viewController;

  [self.window makeKeyAndVisible];

  return YES;
}

@end
