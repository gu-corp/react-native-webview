#import "WKWebView+Highlight.h"
#import "WKWebView+BrowserHack.h"

@implementation WKWebView (Highlight)

- (NSInteger)highlightAllOccurencesOfString:(NSString*)str
{
	/*
	 NSString *js = @"document.getElementsByTagName('html')[0].innerHTML;";
	 NSString *src = [self stringByEvaluatingJavaScriptFromString:js];
	 NSLog(@"HTML: %@", src);
	 */
	
	NSInteger resultInt = 0;
	NSArray *words1 = [str componentsSeparatedByString: @" "]; // 半角スペース
	NSMutableArray *tokens = [NSMutableArray array];
	for (int i = 0; i < [words1 count]; i++) {
		NSString *word1 = [words1 objectAtIndex:i];
		if ([word1 isEqualToString:@""] == YES) {
			continue;
		}
		NSArray *words2 = [word1 componentsSeparatedByString: @"　"]; //全角スペース
		for (int j = 0; j < [words2 count]; j++) {
			BOOL shouldAdd = YES;
			NSString *word2 = [words2 objectAtIndex:j];
			if ([word2 isEqualToString:@""] == YES) {
				continue;
			}
			for (int k = 0; k < [tokens count]; k++) { // 重複キーワードを無視
				//NSLog(@"tokens: %@, %@", [tokens objectAtIndex:k], word2);
				if ([[tokens objectAtIndex:k] isEqualToString:word2] == YES) {
					shouldAdd = NO;
					continue;
				}
			}
			if (shouldAdd == YES) {
				//NSLog(@"tokens: addObject: %@", word2);
				[tokens addObject: word2];
			}
		}
	}		
	for (int i = 0; i < [tokens count]; i++) {
		NSString *word = [tokens objectAtIndex:i];
		if ([word isEqualToString:@""] == YES) {
			continue;
		}
		//NSLog(@"%d: %@", i, word);		
		NSString *path = [[NSBundle mainBundle] pathForResource:@"SearchWebView" ofType:@"js"];
		NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
		[self stringByEvaluatingJavaScriptFromString:jsCode];
		
		NSString *startSearch = @"";
		switch (i) {
			case 0:
				startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@','%@')",word, @"yellow"];
				break;
			case 1:
				startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@','%@')",word, @"cyan"];
				break;
			case 2:
				startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@','%@')",word, @"magenta"];
				break;
			case 3:
				startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@','%@')",word, @"greenyellow"];
				break;
			case 4:
				startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@','%@')",word, @"tomato"];
				break;
			default:
				startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@','%@')",word, @"lightskyblue"];
				break;
		}
		[self stringByEvaluatingJavaScriptFromString:startSearch];
		
		NSString *result = [self stringByEvaluatingJavaScriptFromString:@"MyApp_SearchResultCount"];
		
		resultInt = resultInt + [result integerValue];
	}
	
    return resultInt;
}

- (void)scrollToHighlightTop {
    [self stringByEvaluatingJavaScriptFromString:@"MyApp_ScrollToHighlightTop()"];
}

- (void)removeAllHighlights
{
    [self stringByEvaluatingJavaScriptFromString:@"MyApp_RemoveAllHighlights()"];
}

@end
