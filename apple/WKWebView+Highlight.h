#import <Foundation/Foundation.h>
#import <Webkit/WebKit.h>

//参考：http://www.icab.de/blog/2010/01/12/search-and-highlight-text-in-uiwebview/
//参考：http://d.hatena.ne.jp/KishikawaKatsumi/20091229/1262052856

@interface WKWebView (Highlight)

- (NSInteger)highlightAllOccurencesOfString:(NSString*)str;
- (void)scrollToHighlightTop;
- (void)removeAllHighlights;

@end
