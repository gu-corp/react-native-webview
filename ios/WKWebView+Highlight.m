#import "WKWebView+Highlight.h"
#import "WKWebView+BrowserHack.h"

@implementation WKWebView (Highlight)

- (void)highlightAllOccurencesOfString:(NSString*)str
{
    NSString *startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@')",str];
    [self stringByEvaluatingJavaScriptFromString:startSearch];
    
}

- (void)findNext {
    [self stringByEvaluatingJavaScriptFromString:@"myAppSearchNextInThePage()"];
}

- (void)findPrevious {
    [self stringByEvaluatingJavaScriptFromString:@"myAppSearchPreviousInThePage()"];
}

- (void)removeAllHighlights {
    [self stringByEvaluatingJavaScriptFromString:@"myAppSearchDoneInThePage()"];
}

@end
