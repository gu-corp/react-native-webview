#import "WKWebView+Capture.h"

@implementation WKWebView (Capture)

- (void)contentFrameCapture:(void (^)(UIImage *))completionHandler {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, 0);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    UIImage* capturedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    completionHandler(capturedImage);
}

// Simulate People Action, all the `fixed` element will be repeate
// SwContentCapture will capture all content without simulate people action, more perfect.
- (void)contentScrollCapture:(void(^)(UIImage *))completionHandler {
    
    // Put a fake Cover of View
    UIView *snapShotView = [self snapshotViewAfterScreenUpdates:YES];
    snapShotView.frame = CGRectMake(self.frame.origin.x,self.frame.origin.y, snapShotView.frame.size.width, snapShotView.frame.size.height);
    [self.superview addSubview:snapShotView];
    
    // Backup
    CGPoint bakOffset    = self.scrollView.contentOffset;
    
    // Divide
    CGFloat page  = floorf((CGFloat)(self.scrollView.contentSize.height / self.bounds.size.height));
    
    UIGraphicsBeginImageContextWithOptions(self.scrollView.contentSize, false, [UIScreen mainScreen].scale);
    
    __weak WKWebView *weakSelf = self;
    [self contentScrollPageDraw:0 maxIndex:(NSInteger)page drawCallback:^{
        __strong WKWebView *strongSelf = weakSelf;
        
        UIImage *capturedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // Recover
        [strongSelf.scrollView setContentOffset:bakOffset animated:NO];
        [snapShotView removeFromSuperview];
        
        completionHandler(capturedImage);
    }];
    
}

- (void)contentScrollPageDraw:(NSInteger)index maxIndex:(NSInteger)maxIndex drawCallback:(void(^)())drawCallback{
    
    [self.scrollView setContentOffset:CGPointMake(0,(CGFloat)index * self.scrollView.frame.size.height) animated:NO];
    CGRect splitFrame = CGRectMake(0,(CGFloat)index * self.scrollView.frame.size.height, self.bounds.size.width, self.bounds.size.height);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self drawViewHierarchyInRect:splitFrame afterScreenUpdates:YES];
        
        if (index < maxIndex) {
            [self contentScrollPageDraw:index + 1 maxIndex:maxIndex drawCallback:drawCallback];
        }else{
            drawCallback();
        }
    });
}

@end
