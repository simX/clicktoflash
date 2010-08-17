/*

The MIT License

Copyright (c) 2008-2010 ClickToFlash Developers

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


@class CTFLoader;
@class CTFKiller;
@class CTFMainButton;
@class CTFActionButton;
@class CTFButtonsView;
@class CTFFullScreenWindow;

@interface CTFClickToFlashPlugin : NSView <WebPlugInViewFactory> {
	WebView * _webView;
    DOMElement * _container;
	
	NSURL * _baseURL;
    NSString * _host;

   	NSDictionary * _attributes;
	NSString * _src;
	NSDictionary * _flashVars;
	NSDictionary * _originalOpacityAttributes;

	BOOL isImmediatelyConverted;
	BOOL isConverted;
	
	NSView * containerView;
	CTFMainButton * mainButton;
	NSView * buttonsContainer;
	CTFActionButton * actionButton;
	CTFButtonsView * buttonsView;
	
	CTFFullScreenWindow * fullScreenWindow;

	CTFKiller * killer;

	NSURL * previewURL;
	NSImage * previewImage;
	CTFLoader * previewImageLoader;
	
	// used by CTFClickToFlashPlugin+Whitelist
    NSAlert* _activeAlert;
}

+ (NSView *) plugInViewWithArguments: (NSDictionary *) arguments;
- (id) initWithArguments: (NSDictionary *) arguments;

- (void) opacitySetup;
- (void) setupSubviews;
- (BOOL) shouldConvertImmediately;

- (BOOL) isConsideredInvisible;

- (NSMenuItem*) addContextualMenuItemWithTitle: (NSString*) title action: (SEL) selector;
- (NSMenuItem *) addContextualMenuItemWithTitle: (NSString*) title action: (SEL) selector target:(id) target;

- (IBAction) clicked: (id) sender;
- (IBAction) removeFlash: (id) sender;
- (IBAction) hideFlash: (id) sender;
- (IBAction) loadFlash:(id)sender;
- (IBAction) loadAllOnPage:(id)sender;


+ (NSDictionary *) flashVarDictionary: (NSString *) flashvarString;
- (void) setFlashVarsFromString: (NSString *) string;
- (NSString *) flashvarWithName: (NSString *) argName;

+ (NSString *)launchedAppBundleIdentifier;
- (void) browseToURLString: (NSString*) URLString;
- (void) downloadURLString: (NSString*) URLString;
- (BOOL) useNewStyleUI;
+ (BOOL) CTFIsInactive;
- (CGFloat) overlayOpacityHighlighted: (BOOL) highlighted;

- (void) convertTypesForContainer: (BOOL) keepIt;
- (void) convertTypesForFlashContainer;
- (void) prepareForConversion;
- (void) revertToOriginalOpacityAttributes;

- (IBAction) enterFullScreen: (id) sender;
- (IBAction) exitFullScreen: (id) sender;
- (IBAction) toggleFullScreen: (id) sender;
- (NSButton*) addFullScreenButton;

+ (void) _migratePrefsToExternalFile;
+ (void) _uniquePrefsFileWhitelist;
+ (void) _addApplicationWhitelistArrayToPrefsFile;


#pragma mark Accessors
- (WebView *) webView;
- (void) setWebView: (WebView *) newValue;
- (DOMElement *) container;
- (void) setContainer: (DOMElement *) newValue;

- (NSURL *) baseURL;
- (void) setBaseURL: (NSURL *) newValue;
- (NSString *) host;

- (NSDictionary *) attributes;
- (void) setAttributes: (NSDictionary *) newValue;
- (NSString *) src;
- (void) setSrc: (NSString *) newValue;
- (NSDictionary *) originalOpacityAttributes;
- (void) setOriginalOpacityAttributes: (NSDictionary *) newValue;

- (BOOL) isImmediatelyConverted;
- (void) setIsImmediatelyConverted: (BOOL) newIsImmediatelyConverted;
- (BOOL) isConverted;
- (void) setIsConverted: (BOOL) newIsConverted;


- (NSView *) containerView;
- (void) setContainerView: (NSView *) newContainerView;
- (CTFMainButton *) mainButton;
- (void) setMainButton: (CTFMainButton *) newMainButton;
- (NSView *) buttonsContainer;
- (void) setButtonsContainer: (NSView *) newButtonsContainer;
- (CTFActionButton *) actionButton;
- (void) setActionButton: (CTFActionButton *) newActionButton;
- (CTFButtonsView *) buttonsView;
- (void) setButtonsView: (CTFButtonsView *) newButtonsView;

- (CTFFullScreenWindow *) fullScreenWindow;
- (void) setFullScreenWindow: (CTFFullScreenWindow *) newFullScreenWindow;
- (BOOL) isFullScreen;

- (CTFKiller *) killer;
- (void) setKiller: (CTFKiller *) newKiller;

- (NSURL *) previewURL;
- (void) setPreviewURL: (NSURL *) newPreviewURL;
- (NSImage *) previewImage;
- (void) setPreviewImage: (NSImage *) newPreviewImage;
- (CTFLoader *) previewImageLoader;
- (void) setPreviewImageLoader: (CTFLoader *) newPreviewImageLoader;


@end
