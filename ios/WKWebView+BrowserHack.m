#import "WKWebView+BrowserHack.h"

@implementation WKWebView (BrowserHack)
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script
{
    __block NSString *resultString = nil;
    __block BOOL finished = NO;
    
    [self evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error == nil) {
            if (result != nil) {
                resultString = [result copy];
                NSLog(@"evaluateJavaScript: %@", resultString);
            }
        } else {
            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
        }
        finished = YES;
    }];
    
    while (!finished)
    {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    return resultString;
}

- (CGSize)windowSize
{
    return CGSizeMake([[self stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] integerValue],
                      [[self stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] integerValue]);
}

- (CGPoint)scrollOffset
{
    return CGPointMake([[self stringByEvaluatingJavaScriptFromString:@"window.pageXOffset"] integerValue],
                       [[self stringByEvaluatingJavaScriptFromString:@"window.pageYOffset"] integerValue]);
}

-(NSDictionary*)respondToTapAndHoldAtLocation:(CGPoint)location
{
    CGPoint pt = [self convertPointFromWindowToHtml:location];
    return [self openContextualMenuAt:pt];
}

- (void)closeContextMenu:(WKWebView *)targetView
{
    [self stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
}

- (CGPoint)convertPointFromWindowToHtml:(CGPoint)pt
{
    // convert point from view to HTML coordinate system
    
    CGPoint offset  = [self scrollOffset];
    CGSize viewSize = [self frame].size;
    CGSize windowSize = [self windowSize];
    
    CGFloat f = windowSize.width / viewSize.width;
    pt.x = pt.x * f + offset.x;
    pt.y = pt.y * f + offset.y;
    
    return pt;
}

- (void)getUrlAt:(CGPoint)pt completion:(void (^)(NSDictionary* urlInfo, NSError *error))completion {
    [self evaluateJavaScript:[NSString stringWithFormat:@"MyAppGetIMGSRCAtPoint(%zd,%zd);",(NSInteger)pt.x,(NSInteger)pt.y] completionHandler:^(NSString* result, NSError * _Nullable error) {
        
    }];
}

- (NSDictionary*)openContextualMenuAt:(CGPoint)pt
{
    NSLog(@"Open Context Menu A x:%f y:%f", pt.x, pt.y);
    
    NSString *jsCodeDocumentCoordinateToViewportCoordinate = @"\
    function documentCoordinateToViewportCoordinate(x,y) {\
    var coord = new Object();\
    coord.x = x - window.pageXOffset;\
    coord.y = y - window.pageYOffset;\
    return coord;\
    }\
    ";
    
    NSString *jsCodeViewportCoordinateToDocumentCoordinate = @"\
    function viewportCoordinateToDocumentCoordinate(x,y) {\
    var coord = new Object();\
    coord.x = x + window.pageXOffset;\
    coord.y = y + window.pageYOffset;\
    return coord;\
    }\
    ";
    NSString *jsCodeElementFromPointIsUsingViewPortCoordinates = @"\
    function elementFromPointIsUsingViewPortCoordinates() {\
    if (window.pageYOffset > 0) {\
    return (window.document.elementFromPoint(0, window.pageYOffset + window.innerHeight -1) == null);\
    } else if (window.pageXOffset > 0) {\
    return (window.document.elementFromPoint(window.pageXOffset + window.innerWidth -1, 0) == null);\
    }\
    return false;\
    }\
    ";
    
    NSString *jsCodeElementFromViewportPoint = @"\
    function elementFromViewportPoint(x,y) {\
    if (elementFromPointIsUsingViewPortCoordinates()) {\
    return window.document.elementFromPoint(x,y);\
    } else {\
    var coord = viewportCoordinateToDocumentCoordinate(x,y);\
    return window.document.elementFromPoint(coord.x,coord.y);\
    }\
    }\
    ";
    
    NSString *jsCodeElementFromDocumentPoint = @"\
    function elementFromDocumentPoint(x,y) {\
    if ( elementFromPointIsUsingViewPortCoordinates() ) {\
    var coord = documentCoordinateToViewportCoordinate(x,y);\
    return window.document.elementFromPoint(x,coord.y);\
    } else {\
    return window.document.elementFromPoint(x,y);\
    }\
    }\
    ";
    
    NSString *jsCode1 = @"\
    function MyAppGetHTMLElementsAtPoint(x,y) {\
    var tags = ',';\
    var e = elementFromDocumentPoint(x,y);\
    while (e) {\
    if (e.tagName) {\
    tags += e.tagName + ',';\
    }\
    e = e.parentNode;\
    }\
    return tags;\
    }\
    ";
    
    NSString *jsCode2 = @"\
    function MyAppGetHREFAtPoint(x,y) {\
    var attr = \"\";\
    var e = elementFromDocumentPoint(x,y);\
    while (e) {\
    if (e.tagName == 'A') {\
    attr = e.getAttribute(\"href\");\
    }\
    e = e.parentNode;\
    }\
    return attr;\
    }\
    ";
    
    NSString *jsCode3 = @"\
    function MyAppGetIMGSRCAtPoint(x,y) {\
    var attr = \"\";\
    var e = elementFromDocumentPoint(x,y);\
    while (e) {\
    if (e.tagName == \"IMG\") {\
    attr = e.getAttribute(\"src\");\
    }\
    e = e.parentNode;\
    }\
    return attr;\
    }\
    ";
    
    WKWebView *webView = self;
    
    [webView stringByEvaluatingJavaScriptFromString: jsCodeDocumentCoordinateToViewportCoordinate];
    [webView stringByEvaluatingJavaScriptFromString: jsCodeViewportCoordinateToDocumentCoordinate];
    [webView stringByEvaluatingJavaScriptFromString: jsCodeElementFromPointIsUsingViewPortCoordinates];
    [webView stringByEvaluatingJavaScriptFromString: jsCodeElementFromViewportPoint];
    [webView stringByEvaluatingJavaScriptFromString: jsCodeElementFromDocumentPoint];
    [webView stringByEvaluatingJavaScriptFromString: jsCode1];
    [webView stringByEvaluatingJavaScriptFromString: jsCode2];
    [webView stringByEvaluatingJavaScriptFromString: jsCode3];
    
    // get the Tags at the touch location
    NSString *tags = [webView stringByEvaluatingJavaScriptFromString:
                      [NSString stringWithFormat:@"MyAppGetHTMLElementsAtPoint(%zd,%zd);",(NSInteger)pt.x,(NSInteger)pt.y]];
    
    NSLog(@"tags1: %@", tags);
    if (tags && [tags rangeOfString:@",A,"].location == NSNotFound)
    {
        tags = [webView stringByEvaluatingJavaScriptFromString:
                [NSString stringWithFormat:@"MyAppGetHTMLElementsAtPoint(%zd,%zd);",(NSInteger)pt.x + 3,(NSInteger)pt.y + 3]];
        
    }
    
    NSLog(@"tags2: %@", tags);
    if (tags && [tags rangeOfString:@",A,"].location == NSNotFound)
    {
        tags = [webView stringByEvaluatingJavaScriptFromString:
                [NSString stringWithFormat:@"MyAppGetHTMLElementsAtPoint(%zd,%zd);",(NSInteger)pt.x - 3,(NSInteger)pt.y - 3]];
        
    }
    NSLog(@"tags3: %@", tags);
    
    // If a link was touched, add link-related buttons
    NSString *href = @"";
    NSString *imgsrc = @"";
    if (tags && ([tags rangeOfString:@",IMG,"].location != NSNotFound)&&([tags rangeOfString:@",A,"].location != NSNotFound))
    {
        href = [webView stringByEvaluatingJavaScriptFromString:
                [NSString stringWithFormat:@"MyAppGetHREFAtPoint(%zd,%zd);",(NSInteger)pt.x,(NSInteger)pt.y]];
        
        // 空白を含む場合URLエンコーディングする
        NSRange range = [href rangeOfString:@" "];
        if (range.location != NSNotFound)
        {
            href = [href stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        
        //NSLog(@"href1: %@", href);
        
        imgsrc = [webView stringByEvaluatingJavaScriptFromString:
                  [NSString stringWithFormat:@"MyAppGetIMGSRCAtPoint(%zd,%zd);",(NSInteger)pt.x,(NSInteger)pt.y]];
        
        // 空白を含む場合URLエンコーディングする
        range = [imgsrc rangeOfString:@" "];
        if (range.location != NSNotFound) {
            imgsrc = [imgsrc stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        
        if (imgsrc.length) {
            NSString *jsCode = @"document.getElementsByTagName('base')[0].href";
            NSString *result = [webView stringByEvaluatingJavaScriptFromString:jsCode];
            
            NSURL *baseUrl = ([result length] > 0) ? [NSURL URLWithString:result] : webView.URL;
            
            NSURL *absoluteUrl = [NSURL URLWithString:imgsrc relativeToURL:baseUrl];
            imgsrc = [absoluteUrl absoluteString];
        }
        
        NSLog(@"imgsrc: %@", imgsrc);
        NSURL *url = [NSURL URLWithString:href];
        if ([[url scheme] isEqualToString:@"newtab"])
        {
            NSString *urlString = [[url resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            href = urlString;
        }
        else if (([[url scheme] isEqualToString:@"http"]) || ([[url scheme] isEqualToString:@"https"]))
        {
            //doing nothing
        }
        else
        {
            NSString *jsCode = @"document.getElementsByTagName('base')[0].href";
            NSString *result = [webView stringByEvaluatingJavaScriptFromString:jsCode];
            
            NSURL *baseUrl = ([result length] > 0) ? [NSURL URLWithString:result] : self.URL;
            
            NSURL *absoluteUrl = [NSURL URLWithString:href relativeToURL:baseUrl];
            href = [absoluteUrl absoluteString];
        }
    }
    else if ([tags rangeOfString:@",A,"].location != NSNotFound)
    {
        
        href = [webView stringByEvaluatingJavaScriptFromString:
                [NSString stringWithFormat:@"MyAppGetHREFAtPoint(%zd,%zd);",(NSInteger)pt.x,(NSInteger)pt.y]];
        
        // 空白を含む場合URLエンコーディングする
        NSRange range = [href rangeOfString:@" "];
        if (range.location != NSNotFound)
        {
            href = [href stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        
        NSURL *url = [NSURL URLWithString:href];
        if ([[url scheme] isEqualToString:@"newtab"])
        {
            NSString *urlString = [[url resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            href = urlString;
        }
        else if (([[url scheme] isEqualToString:@"http"]) || ([[url scheme] isEqualToString:@"https"]))
        {
            //Doing nothing
        }
        // Send bookmarlet links to the on Message
        // else if ([[url scheme] isEqualToString:@"javascript"])
        // {
        //     href = nil;
        // }
        else
        {
            
            NSString *jsCode = @"document.getElementsByTagName('base')[0].href";
            NSString *result = [webView stringByEvaluatingJavaScriptFromString:jsCode];
            
            NSURL *baseUrl = ([result length] > 0) ? [NSURL URLWithString:result] : self.URL;
            
            NSURL *absoluteUrl = [NSURL URLWithString:href relativeToURL: baseUrl];
            href = [absoluteUrl absoluteString];
        }
    }
    else if ([tags rangeOfString:@",IMG,"].location != NSNotFound)
    {
        
        imgsrc = [webView stringByEvaluatingJavaScriptFromString:
                  [NSString stringWithFormat:@"MyAppGetIMGSRCAtPoint(%zd,%zd);",(NSInteger)pt.x,(NSInteger)pt.y]];
        
        // 空白を含む場合URLエンコーディングする
        NSRange range = [imgsrc rangeOfString:@" "];
        if (imgsrc && range.location != NSNotFound)
        {
            imgsrc = [imgsrc stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        
        {
            
            NSString *jsCode = @"document.getElementsByTagName('base')[0].href";
            NSString *result = [webView stringByEvaluatingJavaScriptFromString:jsCode];
            
            NSURL *baseUrl = ([result length] > 0) ? [NSURL URLWithString:result] : webView.URL;
            
            
            NSURL *absoluteUrl = [NSURL URLWithString:imgsrc relativeToURL: baseUrl];
            imgsrc = [absoluteUrl absoluteString];
        }
        
        NSLog(@"imgsrc: %@", imgsrc);
        
        NSURL *url = [NSURL URLWithString:imgsrc];
        if (([[url scheme] isEqualToString:@"http"]) || ([[url scheme] isEqualToString:@"https"]))
        {
            //Doing nothing
        }
        else
        {
            // 相対パスの場合絶対パスにする
            NSString *jsCode = @"document.getElementsByTagName('base')[0].href";
            NSString *result = [webView stringByEvaluatingJavaScriptFromString:jsCode];
            NSURL *baseUrl = ([result length] > 0) ? [NSURL URLWithString:result] : webView.URL;
            
            NSURL *absoluteUrl = [NSURL URLWithString:imgsrc relativeToURL: baseUrl];
            href = [absoluteUrl absoluteString];
        }
    }
    
    NSMutableDictionary* result = [NSMutableDictionary new];
    if(href.length) {
        [result setObject:href forKey:@"url"];
    }
    if(imgsrc.length) {
        [result setObject:imgsrc forKey:@"image_url"];
    }
    return result;
}
@end

