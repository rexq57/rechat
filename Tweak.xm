#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <LocalAuthentication/LocalAuthentication.h>
#define RELog(...)

// 指纹识别
void EvaluatePolicy(void(^block)(BOOL success))
{
    LAContext *context = [LAContext new];
    NSError *error;
    context.localizedFallbackTitle = @"输入密码";

    if ([context canEvaluatePolicy:(LAPolicyDeviceOwnerAuthenticationWithBiometrics) error:&error]){
        // RELog(@"支持使用");
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:NSLocalizedString(@"通过验证指纹解锁",nil) reply:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                RELog(@"验证成功");
                if (block)
                    block(YES);
            } else {
                if (error.code == kLAErrorUserFallback){
                    RELog(@"用户选择了另一种方式");
                }else if (error.code == kLAErrorUserCancel){
                    RELog(@"用户取消");
                }else if (error.code == kLAErrorSystemCancel){
                    RELog(@"切换前台被取消");
                }else if (error.code == kLAErrorPasscodeNotSet){
                    RELog(@"身份验证没有设置");
                }else{
                    RELog(@"验证失败");
                }
                if (block)
                    block(NO);
            }
        }];
    }
    else
    {
        // 没有使用指纹的情况
        switch (error.code) {
            case LAErrorBiometryNotEnrolled:{
                RELog(@"TouchID is not enrolled");
                break;
            }
            case LAErrorPasscodeNotSet:{
                RELog(@"A passcode has not been set");
                break;
            }
            case LAErrorBiometryLockout:{
                RELog(@"TouchID lock out");
                break;
            }
            default:{
                RELog(@"TouchID not available");
                break;
            }
        }
        if (block)
            block(YES);
    }
}

////////////////////////////////////////////////////////

static UIView* _maskView = nil;
@interface UIViewController(Hook)

@end
@implementation UIViewController(Hook)

- (void) callPolicy
{
    // 添加一个白色全屏遮罩
    if (!_maskView)
    {
        UIView* view = [[UIView alloc] initWithFrame:self.view.bounds];
        view.backgroundColor = [UIColor whiteColor];
        _maskView = view;
    }
    
    if (!_maskView.superview)
        [self.view addSubview:_maskView];
}

- (void) tryMovePolicy
{
    if (_maskView.superview)
    {
        // 指纹解锁
        EvaluatePolicy(^(BOOL success){
            if (success)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_maskView removeFromSuperview];
                });
            }
        });
    }
}

+ (void)load {
    
    //exit(0);
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(viewWillAppear:)),
                                   class_getInstanceMethod(self, @selector(swizzle_viewWillAppear:)));
}

- (void) swizzle_viewWillAppear:(BOOL)animated
{
    [self swizzle_viewWillAppear:animated];
    
    // 确定根视图控制器
    UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    if (self == rootViewController)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            
            // 注册app进入后台的通知
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                              object:nil
                                                               queue:nil
                                                          usingBlock:^(NSNotification *note){
                                                              [self callPolicy];
                                                          }];
            
            // 注册app激活的通知
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                              object:nil
                                                               queue:nil
                                                          usingBlock:^(NSNotification *note){
                                                              [self tryMovePolicy];
                                                          }];
            
            // rootViewController生效的时候，手动调用第一次添加遮罩，随后会触发UIApplicationDidBecomeActiveNotification通知
            [self callPolicy];
        });
    }
}

@end
