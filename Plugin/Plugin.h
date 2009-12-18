/*

The MIT License

Copyright (c) 2008-2009 ClickToFlash Developers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "CTFUtilities.h"



// Subview Tags
enum subviewTags {
	CTFMainButtonTag,
	CTFActionButtonTag,
	CTFButtonsViewTag,
	CTFFullScreenButtonTag,
	CTFHDButtonTag
};


@class CTFKiller;
@class CTFMainButton;
@class CTFActionButton;
@class CTFButtonsView;
@class CTFFullScreenWindow;

@interface CTFClickToFlashPlugin : NSView <WebPlugInViewFactory> {
    DOMElement *_container;
    NSString *_host;
    NSDictionary* _flashVars;
    id trackingArea;
    NSAlert* _activeAlert;
    BOOL mouseIsDown;
    BOOL _isLoadingFromWhitelist;
	WebView *_webView;
	NSString *_baseURL;
	NSDictionary *_attributes;
	NSDictionary *_originalOpacityAttributes;
	NSString *_src;

	BOOL isConverted;
	
	NSView * containerView;
	CTFMainButton * mainButton;
	NSView * buttonsContainer;
	CTFActionButton * actionButton;
	CTFButtonsView * buttonsView;
	CTFKiller * killer;
	
	CTFFullScreenWindow * fullScreenWindow;
	
	NSURL * previewURL;
	NSImage * previewImage;

	BOOL _sparkleUpdateInProgress;
}

+ (NSView *)plugInViewWithArguments:(NSDictionary *)arguments;
- (void) setupSubviews;

- (void) revertToOriginalOpacityAttributes;
- (void) prepareForConversion;

- (NSMenuItem*) addContextualMenuItemWithTitle: (NSString*) title action: (SEL) selector;
- (NSMenuItem *) addContextualMenuItemWithTitle: (NSString*) title action: (SEL) selector target:(id) target;

- (IBAction) clicked: (id) sender;

- (IBAction)loadFlash:(id)sender;
- (IBAction)loadAllOnPage:(id)sender;
- (IBAction)removeFlash: (id) sender;
- (IBAction)hideFlash: (id) sender;
- (void) convertTypesForContainer: (BOOL) keepIt;

+ (NSDictionary*) flashVarDictionary: (NSString*) flashvarString;
+ (NSString *)launchedAppBundleIdentifier;
- (void) browseToURLString: (NSString*) URLString;
- (void) downloadURLString: (NSString*) URLString;
- (BOOL) useNewStyleUI;

- (IBAction) enterFullScreen: (id) sender;
- (IBAction) exitFullScreen: (id) sender;
- (IBAction) toggleFullScreen: (id) sender;
- (NSButton*) addFullScreenButton;

- (BOOL) isConsideredInvisible;

- (id) initWithArguments:(NSDictionary *)arguments;

+ (void) _migratePrefsToExternalFile;
+ (void) _uniquePrefsFileWhitelist;
+ (void) _addApplicationWhitelistArrayToPrefsFile;


#pragma mark Accessors
- (CTFKiller *) killer;
- (void)setKiller:(CTFKiller *)newKiller;
- (NSView *) containerView;
- (void) setContainerView: (NSView *) newContainerView;
- (CTFMainButton *) mainButton;
- (void) setMainButton:(CTFMainButton *) newMainButton;
- (NSView *) buttonsContainer;
- (void) setButtonsContainer: (NSView *) newButtonsContainer;
- (CTFActionButton *) actionButton;
- (void) setActionButton: (CTFActionButton *) newActionButton;
- (CTFButtonsView *) buttonsView;
- (void) setButtonsView: (CTFButtonsView *) newButtonsView;
- (CTFFullScreenWindow *) fullScreenWindow;
- (void) setFullScreenWindow: (CTFFullScreenWindow *) newFullScreenWindow;
- (BOOL)isFullScreen;
- (DOMElement *)container;
- (void)setContainer:(DOMElement *)newValue;
- (NSString *)host;
- (void)setHost:(NSString *)newValue;
- (WebView *)webView;
- (void)setWebView:(WebView *)newValue;
- (NSString *)baseURL;
- (void)setBaseURL:(NSString *)newValue;
- (NSDictionary *)attributes;
- (void)setAttributes:(NSDictionary *)newValue;
- (NSDictionary *)originalOpacityAttributes;
- (void)setOriginalOpacityAttributes:(NSDictionary *)newValue;
- (NSString *)src;
- (void)setSrc:(NSString *)newValue;
- (BOOL)isConverted;
- (void)setIsConverted:(BOOL)newIsConverted;
+ (NSString *)launchedAppBundleIdentifier;

- (NSURL *) previewURL;
- (void) setPreviewURL: (NSURL *) newPreviewURL;
- (NSImage *) previewImage;
- (void) setPreviewImage: (NSImage *) newPreviewImage;


@end
