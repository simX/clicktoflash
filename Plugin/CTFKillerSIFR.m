/*
 CTFKillerSIFR.m
 ClickToFlash
 
 The MIT License
 
 Copyright (c) 2009 ClickToFlash Developers
 
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


#import "CTFKillersIFR.h"
#import "CTFUtilities.h"
#import "CTFUserDefaultsController.h"
#import "CTFPreferencesDictionary.h"
#import "Plugin.h"
#import <WebKit/WebKit.h>

NSString *sSifrAutoHandleDefaultsKey = @"autoHandleSIFR";
NSString *sSifrDeSifrDefaultsKey = @"deSIFR";

static NSString *sSifr2Test		= @"sIFR != null && typeof sIFR == \"function\"";
static NSString *sSifr3Test		= @"sIFR != null && typeof sIFR == \"object\"";
static NSString *sSifrAddOnTest	= @"sIFR.rollback == null || typeof sIFR.rollback != \"function\"";
static NSString *sSifrRollbackJS	= @"sIFR.rollback()";
static NSString *sSifr2AddOnJSFilename = @"sifr2-addons";
static NSString *sSifr3AddOnJSFilename = @"sifr3-addons";



@implementation CTFKillerSIFR

#pragma mark Class Methods

+ (BOOL) isSIFRText: (NSDictionary*) attributes
{
    // Check for sIFR - http://www.mikeindustries.com/sifr/
    
    NSString* classValue = [attributes objectForKey: @"class"];
    NSString* sifrValue = [attributes objectForKey: @"sifr"];
	
    return [classValue isEqualToString: @"sIFR-flash"] || (sifrValue && ([sifrValue intValue] != 0));
}



+ (void) migrateDefaults {
	typedef enum {
		CTFSifrModeDoNothing	= 0, 
		CTFSifrModeAutoLoadSifr	= 1, 
		CTFSifrModeDeSifr		= 2
	} CTFSifrMode;
	
	static NSString * sSifrModeDefaultsKey = @"sifrMode";
	
	BOOL autoHandle = NO;
	BOOL deSIFR = NO;
	
	if (![[CTFUserDefaultsController standardUserDefaults] objectForKey: sSifrAutoHandleDefaultsKey]) {
		// no new-style setting present: if there is an old-style setting, migrate it, otherwise go for defaults
		NSNumber * SIFRMode = [[CTFUserDefaultsController standardUserDefaults] objectForKey:sSifrModeDefaultsKey];
		if (SIFRMode != nil) {
			switch ([SIFRMode intValue]) {
				case CTFSifrModeAutoLoadSifr:
					autoHandle = YES;
					break;
				case CTFSifrModeDeSifr:
					autoHandle = YES;
					deSIFR = YES;
					break;
				default:
					break;
			}
		}
	
		[[CTFUserDefaultsController standardUserDefaults] setBool:autoHandle forKey: sSifrAutoHandleDefaultsKey];
		[[CTFUserDefaultsController standardUserDefaults] setBool:deSIFR forKey: sSifrDeSifrDefaultsKey];
	}	
}





# pragma mark CTFKiller subclassing

+ (BOOL) canHandleFlashAtURL: (NSURL*) theURL src: (NSString*) theSrc attributes: (NSDictionary*) attributes forPlugin:(CTFClickToFlashPlugin*) thePlugin {
	return [[self class] isSIFRText: attributes];
}



// Indicate whether we want the CtF view to be converted right away.
- (BOOL) shouldConvertImmediately {
	BOOL result = [[self class] shouldAutoLoadSIFR];
	result = result || [self shouldDeSIFR];
	
	return result;
}



- (void) pluginDestroy {
	[super pluginDestroy];
}



- (NSString*) badgeLabelText {
	return CtFLocalizedString( @"sIFR Flash", @"sIFR Flash badge text" );
}



- (void) addPrincipalMenuItemToContextualMenu {
	[[self plugin] addContextualMenuItemWithTitle: CtFLocalizedString( @"Don't use Text Replacement", @"Don't use Text Replacement (CTFKillerSIFR)" )	
										   action: @selector( disableSIFR )
										   target: self ];
}



- (BOOL) convert {
	// default to NO, meaning that CTFClickToFlashPlugin will convert by inserting the Flash
	BOOL result = NO;
	
	if ([[self plugin] isImmediatelyConverted]) {
		// we have been converted 'immediately': potentially deSIFR
		if ([self shouldDeSIFR]) {
			[self performSelector:@selector(disableSIFR) withObject:nil afterDelay:0];
			result = YES;
		}
	}
	
	return result;
}






#pragma mark Support Methods (formerly CTFsIFRSupport)

- (NSUInteger) sifrVersionInstalled {	
	// get the container's WebView
	WebView *sifrWebView = [[self plugin] webView];
	NSUInteger version = 0;
    
	if (sifrWebView) {
		if ([[sifrWebView stringByEvaluatingJavaScriptFromString: sSifr2Test] isEqualToString: @"true"])        // test for sIFR v.2
			version = 2;
		else if([[sifrWebView stringByEvaluatingJavaScriptFromString: sSifr3Test] isEqualToString: @"true"])    // test for sIFR v.3
			version = 3;
	}
	
	return version;
}


- (BOOL) shouldDeSIFR {
    BOOL result = NO;

	if ([[CTFUserDefaultsController standardUserDefaults] boolForKey: sSifrAutoHandleDefaultsKey] 
		&& [[CTFUserDefaultsController standardUserDefaults] boolForKey: sSifrDeSifrDefaultsKey]) {

		result = ([self sifrVersionInstalled] != 0);
    }
    
    return result;
}


+ (BOOL) shouldAutoLoadSIFR {
    return [[CTFUserDefaultsController standardUserDefaults] boolForKey: sSifrAutoHandleDefaultsKey] 
	&& ![[CTFUserDefaultsController standardUserDefaults] boolForKey: sSifrDeSifrDefaultsKey];
}        


- (void) disableSIFR {
	WebView *sifrWebView = [[self plugin] webView];
	
	// Should check for sifrWebView's existence.
	// sifrWebView could be nil if the plugin is removed while we're waiting for execution.
	if ( sifrWebView != nil ) {
		// If sIFR add-ons are not installed, load version-appropriate version into page.
		if ([[sifrWebView stringByEvaluatingJavaScriptFromString: sSifrAddOnTest] isEqualToString: @"true"]) {
			NSBundle *clickBundle = [NSBundle bundleForClass: [self class]];
			
			NSString *jsFileName;
			if ( [self sifrVersionInstalled] == 2 ) {
				jsFileName = sSifr2AddOnJSFilename;
			}
			else {
				jsFileName = sSifr3AddOnJSFilename;
			}

			NSString *addOnPath = [clickBundle pathForResource: jsFileName ofType: @"js"];
			
			if( addOnPath ) {
				NSStringEncoding enc ;
				NSString *sifrAddOnJS = [NSString stringWithContentsOfFile: addOnPath usedEncoding: &enc error: nil];
				
				if (sifrAddOnJS && ![sifrAddOnJS isEqualToString: @""])
					[[sifrWebView windowScriptObject] evaluateWebScript: sifrAddOnJS];
			}
		}
		
		// implement rollback
		[[sifrWebView windowScriptObject] evaluateWebScript: sSifrRollbackJS];
	}
}


@end
