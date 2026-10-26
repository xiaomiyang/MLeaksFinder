//
//  MLeaksMessenger.m
//  MLeaksFinder
//
//  Created by 佘泽坡 on 7/17/16.
//  Copyright © 2016 zeposhe. All rights reserved.
//

//  fork 内置补丁（2026-10，xiaomiyang）：iOS 26 起 UIScene 生命周期的应用弹 UIAlertView 直接抛
//  NSObjectNotAvailableException 崩溃，内部实现迁移为 UIAlertController。
//  方法签名与 buttonIndex 语义保持不变（OK 固定为 0，additionalButton 为 1）；
//  delegate 仍按 UIAlertViewDelegate 协议回调（alertView 参数恒为 nil）。

#import "MLeaksMessenger.h"

static __weak UIAlertController *alertController;

@implementation MLeaksMessenger

+ (void)alertWithTitle:(NSString *)title message:(NSString *)message {
    [self alertWithTitle:title message:message delegate:nil additionalButtonTitle:nil];
}

+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(id<UIAlertViewDelegate>)delegate
 additionalButtonTitle:(NSString *)additionalButtonTitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 弹出前先收起上一个泄漏提示，与原 dismissWithClickedButtonIndex 语义一致（不触发 delegate）
        [alertController dismissViewControllerAnimated:NO completion:nil];

        UIAlertController *alertControllerTemp = [UIAlertController alertControllerWithTitle:title
                                                                                      message:message
                                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alertControllerTemp addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                style:UIAlertActionStyleCancel
                                                              handler:nil]];
        if (additionalButtonTitle.length > 0) {
            __weak id weakDelegate = delegate;
            [alertControllerTemp addAction:[UIAlertAction actionWithTitle:additionalButtonTitle
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
                if (weakDelegate && [weakDelegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
                    // buttonIndex 1 对应原来的 additionalButton，alertView 参数恒为 nil
                    [(id<UIAlertViewDelegate>)weakDelegate alertView:nil clickedButtonAtIndex:1];
                }
            }]];
        }
        alertController = alertControllerTemp;

        // MLeaksFinder 可能在任意时机检测到泄漏，此处已在主线程；找顶层 presented VC 弹出，保证覆盖所有页面
        UIViewController *presentingVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (presentingVC.presentedViewController) {
            presentingVC = presentingVC.presentedViewController;
        }
        if (presentingVC) {
            [presentingVC presentViewController:alertControllerTemp animated:NO completion:nil];
        }

        NSLog(@"%@: %@", title, message);
    });
}

@end
