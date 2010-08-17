/*
 CTFKillerVideo.m
 ClickToFlash
 
 The MIT License
 
 Copyright (c) 2009-2010 ClickToFlash Developers
 
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

#import "CTFKillerVideo.h"
#import "CTFKillerVideo-QT.h"
#import "CTFKillerVideo-HTML.h"
#import "CTFUserDefaultsController.h"
#import "CTFLoader.h"
#import "CTFUtilities.h"
#import "Plugin.h"
#import <QTKit/QTKit.h>


NSString * sDisableVideoElementDefaultsKey = @"disableVideoElement";
NSString * sUseYouTubeH264DefaultsKey = @"useYouTubeH264";
NSString * sUseYouTubeHDH264DefaultsKey = @"useYouTubeHDH264";
NSString * sYouTubeAutoPlayDefaultsKey = @"enableYouTubeAutoPlay";
NSString * sUseQTKitDefaultsKey = @"use QTKit";

@implementation CTFKillerVideo

#pragma mark Come and Go

- (id) init {
	self = [super init];
	if (self != nil) {
		autoPlay = NO;
		hasAutoPlayed = NO;
		hasVideo = NO;
		hasVideoHD = NO;
		
		[self setTitle: nil];
		
		[self setVideoLookup: nil];
		[self setVideoHDLookup: nil];
		activeLookups = 0;
		lookupStatus = nothing;
		requiresConversion = NO;
		
		[self setProgressIndicator: nil];
		
		[self setMovieView: nil];
		[self setMovie: nil];
		[self setEndOfMovieButtonsView: nil];
		
		hasRefreshedURLs = NO;
	}
	
	return self;
}



- (void) dealloc {
	[self pluginDestroy]; // just in case, should have been called already
	[super dealloc];
}





#pragma mark -
#pragma mark Default implementations to be overridden by subclasses

// Name of the video service that can be used for automatic link text generation 
- (NSString*) siteName { return nil; }

// Name of the current video. Return nil if unknown.
- (NSString*) videoName { return nil; }

// URL to the video file used for loading it in the player.
- (NSString*) videoURLString { return nil;} 
- (NSString*) videoHDURLString { return nil; }

// HTML needed to embed the video
- (NSString *) embedString { return nil; }

// If lookups are required to determine the correct URL to the video, redo them. When returning, the URLs should be refreshed and ready to use.
- (void) refreshVideoURLs { }

// Text used for video file download link. Return nil to use standard text.
- (NSString *) videoDownloadLinkText { return nil; }

// URL of the web page displaying the video. Return nil if there is none.
- (NSString *) videoPageURLString { return nil; }

// Text used for link to video page. Return nil to use standard text.
- (NSString *) videoPageLinkText { return nil; }

// Edit or replace the markup that is added for the links beneath the video. The descriptionElement passed to the method already conatins Go to Webpage and Download Video File links.
- (DOMElement *) enhanceVideoDescriptionElement: (DOMElement*) descriptionElement {
	return descriptionElement;
}

// If we are on the video's home page return YES, otherwise NO. This is used to determine whether we need links pointing to the video's home page.
- (BOOL) isOnVideoPage {
	BOOL result = NO;
	NSString * videoPage = [self cleanURLString:[self videoPageURLString]];
	
	if (videoPage != nil) {
		NSString * URLString = [self cleanURLString:[[self pageURL] absoluteString]];
		result = [URLString hasPrefix: videoPage];
	}
	return result;
}








					
#pragma mark -
#pragma mark Subclass override of CTFKiller

// Called when our plug-in is destroyed, so pending actions can be stopped in a controlled way
- (void) pluginDestroy {
	NSButton * button = [[[self plugin] buttonsView] viewWithTag: CTFHDButtonTag];
	if (button != nil) {
		[button unbind:@"toolTip"];
		[button unbind:@"value"];		
	}
	[self setTitle: nil];
	[self setVideoLookup: nil];
	[self setVideoHDLookup: nil];
	[self setProgressIndicator: nil];
	[self setMovie:nil];
	[[self movieView] setMovie:nil];
	[self setMovieView: nil];
	[self setEndOfMovieButtonsView: nil];
}



// Create generic labels based on the Service's name, so our subclasses don't need to.
- (NSString*) badgeLabelText {
	NSString * label = nil;
	if( [ self useVideoHD ] ) {
		label = CtFLocalizedString( @"HD H.264", @"HD H.264 badge text" );
	} 
	else if( [ self useVideo ] ) {
		NSString * H264Name = CtFLocalizedString( @"H.264", @"H.264 badge text" );
		if ( [self lookupStatus] == finished ) {
			label = H264Name;
		} else {
			NSString * ellipsisFormat = CtFLocalizedString(@"%@...", @"");
			label = [NSString stringWithFormat: ellipsisFormat, H264Name];
		}
    } 
	else  {
		NSString * serviceName = [NSString stringWithFormat: CtFLocalizedString( @"%@ (VideoServiceName)", @"Format for badge text for video service. This should probably just be %@" ), [self siteName]];
		if ( [self lookupStatus] >= finished ) {
			label = serviceName;
		} else {
			NSString * ellipsisFormat = CtFLocalizedString(@"%@...", @"");
			label = [NSString stringWithFormat:ellipsisFormat, serviceName];
		}
	}
	
	return label;
}



// Create a default principal menu item, so our subclasses don't need to. The menu item loads the MP4 video according the current settings. If the video is available in another size as well, holding the option key will reveal a command to load that version instead.
- (void) addPrincipalMenuItemToContextualMenu {
	NSMenuItem * menuItem;
	
	if ([self hasVideo] && [self movieView] == nil) {
		[[self plugin] addContextualMenuItemWithTitle: CtFLocalizedString( @"Load H.264", @"Load H.264 contextual menu item" ) 
											   action: @selector( loadVideo: )
											   target: self ];
		if ( [self hasVideoHD] ) {
			if ( [self useVideoHD] ) {
				menuItem = [[self plugin] addContextualMenuItemWithTitle: CtFLocalizedString( @"Load H.264 SD Version", @"Load Smaller Version contextual menu item (alternate for the standard Load H.264 item when the default uses the 'HD' version)" )
																  action: @selector( loadVideoSD: )
																  target: self ];
			}
			else {
				menuItem = [[self plugin] addContextualMenuItemWithTitle: CtFLocalizedString( @"Load H.264 HD Version", @"Load Larger Version  contextual menu item (alternate for the standard item when the default uses the non-'HD' version)" )
																  action: @selector( loadVideoHD: )
																  target: self ];
			}
			[menuItem setAlternate:YES];
			[menuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
		}
	}
}



/* 
 Create a default set of additional menu items, so our subclasses don't need to. These consist of:
 1. A command to go to the web page belonging to the video (if there is one)
 2. A command for fullscreen playback in QuickTime Player. If the video is available in another size as well, holding the option key will reveal a command to load that version in QuickTime Player instead.
 3. A command to download the video file. If the video is available in another size as well, holding the option key will reveal a command to download that version instead.
*/
- (void) addAdditionalMenuItemsForContextualMenu {
	NSMenuItem * menuItem;
	NSString * formatString;
	NSString * labelString;
	
	if (![self isOnVideoPage] && [self videoPageURLString] != nil) {
		// Command to Open web page for embedded videos
		formatString = CtFLocalizedString( @"Load %@ page for this video", @"Load SITENAME page for this video contextual menu item" );
		labelString = [NSString stringWithFormat: formatString, [self siteName]];
		[[self plugin] addContextualMenuItemWithTitle: labelString
											   action: @selector( gotoVideoPage: )
											   target: self ];
	}
	
	if ( [self hasVideo] ) {
		// menu item and alternate for full screen viewing in QuickTime Player
		labelString = CtFLocalizedString( @"Play Fullscreen in QuickTime Player", @"Open Fullscreen in QT Player contextual menu item" );
		[[self plugin] addContextualMenuItemWithTitle: labelString
											   action: @selector( openFullscreenInQTPlayer: )
											   target: self ];
		if ( [self hasVideoHD]) {
			if ( [self useVideoHD] ) {
				labelString = CtFLocalizedString( @"Play Smaller Version Fullscreen in QuickTime Player", @"Open Smaller Version Fullscreen in QT Player contextual menu item (alternate for the standard item when the default uses the 'HD' version)" );
				menuItem = [[self plugin] addContextualMenuItemWithTitle: labelString
																  action: @selector( openFullscreenInQTPlayerSD: )
																  target: self ];
			}
			else {
				labelString = CtFLocalizedString( @"Play Larger Version Fullscreen in QuickTime Player", @"Open Larger Version Fullscreen in QT Player contextual menu item (alternate for the standard item when the default uses the non-'HD' version)" );
				menuItem = [[self plugin] addContextualMenuItemWithTitle: labelString
																  action: @selector( openFullscreenInQTPlayerHD: ) 
																  target: self ];
			}
			[menuItem setAlternate:YES];
			[menuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
		}
		
		// menu item and alternate for downloading movie file
		labelString = CtFLocalizedString( @"Download H.264", @"Download H.264 menu item" );
		[[self plugin] addContextualMenuItemWithTitle: labelString
											   action: @selector( downloadVideo: )
											   target: self ];
		
		if ( [self hasVideoHD]) {
			if ( [self useVideoHD] ) {
				labelString = CtFLocalizedString( @"Download SD H.264", @"Download small size H.264 menu item (alternate for the standard item when the default uses the 'HD' version)" );
				menuItem = [[self plugin] addContextualMenuItemWithTitle: labelString
																  action: @selector( downloadVideoSD: ) 
																  target: self ];
			}
			else {
				labelString = CtFLocalizedString( @"Download HD H.264", @"Download large size H.264 menu item (alternate for the standard item when the default uses the non-'HD' version)" );
				menuItem = [[self plugin] addContextualMenuItemWithTitle: labelString
																  action: @selector( downloadVideoHD: ) 
																  target: self ];
			}
			[menuItem setAlternate:YES];
			[menuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
		}
	}

	// menu item to copy <embed> tag
	NSString * myEmbedString = [self embedString];
	if ( myEmbedString != nil ) {
		labelString = CtFLocalizedString( @"Copy embed tag to Clipboard", @"CTFKillerVideo: Copy embed tag to Clipboard menu item" );
		menuItem = [[self plugin] addContextualMenuItemWithTitle: labelString
														  action: @selector( copyEmbedTag: )
														  target: self ];
		[menuItem setToolTip: myEmbedString];
	}
}



/* 
 Implement default container conversion: If there is a film, use it.
 Depending on the OS version and preferences it is inserted into the DOM as a video or embed element or we display it in our own QTMovieView.
*/
- (BOOL) convert {
	return [self convertUsingHD: nil];
}




// Called when full screen mode starts and ends.
// In fullscreen mode: To get good letterboxing, fill the extra space around the movie view in black.
- (void) startFullScreen { 
	if ( [self movieView] != nil ) {
		[[self movieView] setFillColor: [NSColor blackColor]];
		[[[self plugin] buttonsContainer] setAutoresizingMask: NSViewNotSizable];
		[NSCursor setHiddenUntilMouseMoves:YES];
	}
	[self adjustButtonPositions:YES];
}



// In the web page: To minimise distraction, if there is extra background space, fill it transparently.
- (NSRect) stopFullScreen { 	
	if ( [self movieView] != nil ) {
		[[self movieView] setFillColor: [NSColor clearColor]];
	}
	[[[self plugin] buttonsContainer] setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
	NSRect pluginRect;
	pluginRect.origin = [[[self plugin] window] convertBaseToScreen:[[self plugin] convertPoint:NSZeroPoint toView:nil]];
	pluginRect.size = [[self plugin] frame].size;
	
	NSRect newRect = NSZeroRect;
	
	if ([self movieView]) {
		NSSize movieSize = [[self movieView] movieBounds].size;
		CGFloat aspectRatio = movieSize.width / movieSize.height;
		CGFloat effectivePluginHeight = pluginRect.size.height - [[self movieView] controllerBarHeight];
		CGFloat pluginAspectRatio = pluginRect.size.width / effectivePluginHeight;
		
		newRect = pluginRect;
		
		if (aspectRatio > pluginAspectRatio) {
			newRect.size.height = pluginRect.size.width / aspectRatio + [[self movieView] controllerBarHeight];
			newRect.origin.y += floor((pluginRect.size.height - newRect.size.height) * .5);
		}
		else {
			newRect.size.width = (pluginRect.size.height - [[self movieView] controllerBarHeight]) * aspectRatio;
			newRect.origin.x += floor((pluginRect.size.width - newRect.size.width) * .5);
		}		
	}
	
	return newRect;
}
 


// Called when the plug-in's view resizes.
- (void) pluginResized {
	[self adjustButtonPositions:NO];
}






#pragma mark -
#pragma mark Actions

// Load the video in the WebView
- (IBAction) loadVideo:(id)sender {
    [self convert];
}

- (IBAction) loadVideoSD:(id)sender {
	[self convertUsingHD: [NSNumber numberWithBool:NO]];
}

- (IBAction) loadVideoHD:(id)sender {
	[self convertUsingHD: [NSNumber numberWithBool:YES]];
}


// Download the video's movie file
- (void) downloadVideoUsingHD: (BOOL) useHD {
	NSString * URLString = [self videoURLStringForHD: useHD];
	[[self plugin] downloadURLString: URLString];
}

- (IBAction) downloadVideo: (id) sender {
	BOOL wantHD = [[CTFUserDefaultsController standardUserDefaults] boolForKey:sUseYouTubeHDH264DefaultsKey];
	[self downloadVideoUsingHD: wantHD];
}

- (IBAction) downloadVideoSD: (id) sender {
	[self downloadVideoUsingHD: NO];
}

- (IBAction) downloadVideoHD: (id) sender {
	[self downloadVideoUsingHD: YES];
}


// Go to video's page in the browser
- (IBAction) gotoVideoPage:(id)sender {
	[[self plugin] browseToURLString:[self videoPageURLString]];
}


- (IBAction) copyEmbedTag: (id) sender {
	NSPasteboard * pB = [NSPasteboard generalPasteboard];
	[pB declareTypes: [NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pB setString: [self embedString] forType:NSStringPboardType];
}


// Play the film fullscreen in QuickTime Player
- (void)openFullscreenInQTPlayerUsingHD:(BOOL) useHD {
	NSString * URLString = [self videoURLStringForHD: useHD];
	
	NSString *scriptSource = nil;
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) {
		// Snowy Leopard
		scriptSource = [NSString stringWithFormat:
						@"tell application \"QuickTime Player\"\nactivate\nopen URL \"%@\"\nrepeat while (front document is not presenting)\ndelay 1\npresent front document\nend repeat\nrepeat while (playing of front document is false)\ndelay 1\nplay front document\nend repeat\nend tell", URLString];
	} else {
		scriptSource = [NSString stringWithFormat:
						@"tell application \"QuickTime Player\"\nactivate\ngetURL \"%@\"\nrepeat while (display state of front document is not presentation)\ndelay 1\npresent front document scale screen\nend repeat\nrepeat while (playing of front document is false)\ndelay 1\nplay front document\nend repeat\nend tell",URLString];
	}
	
	NSAppleScript *openInQTPlayerScript = [[NSAppleScript alloc] initWithSource:scriptSource];
	[openInQTPlayerScript executeAndReturnError:nil];
	[openInQTPlayerScript release];	
}


- (IBAction)openFullscreenInQTPlayer:(id)sender {
	BOOL useHD = [[CTFUserDefaultsController standardUserDefaults] boolForKey:sUseYouTubeHDH264DefaultsKey];
	
	[self openFullscreenInQTPlayerUsingHD: useHD];
}

- (IBAction)openFullscreenInQTPlayerSD:(id)sender{
	[self openFullscreenInQTPlayerUsingHD: NO];	
}

- (IBAction)openFullscreenInQTPlayerHD:(id)sender{
	[self openFullscreenInQTPlayerUsingHD: YES];	
}









#pragma mark -
#pragma mark Helpers

// Determine whether we want to use the video. Returns YES if a video is available and the relevant preference is set.
- (BOOL) useVideo {
    return [ self hasVideo ] 
	&& [ [ CTFUserDefaultsController standardUserDefaults ] boolForKey: sUseYouTubeH264DefaultsKey ]; 
}


// Determine whether we want to use the video's HD version. Returns YES if the HD version is available and the relevant preferences are set.
- (BOOL) useVideoHD {
	return [ self hasVideoHD ] && [self hasVideo]
	&& [ [ CTFUserDefaultsController standardUserDefaults ] boolForKey: sUseYouTubeH264DefaultsKey ] 
	&& [ [ CTFUserDefaultsController standardUserDefaults ] boolForKey: sUseYouTubeHDH264DefaultsKey ];
}


// Return the URL to the video. When told to provide a HD version the SD version may be provided if no HD version exists.
- (NSString *) videoURLStringForHD: (BOOL) useHD {
	NSString * URLString;
	
	if (useHD && [self hasVideoHD]) {
		URLString = [ self videoHDURLString ];
	} else {
		URLString = [ self videoURLString ];
	}
	
	return URLString;
}



// Return the NSURL of the video that would currently be used.
- (NSURL *) downloadURL {
	BOOL useHD;
	
	NSButton * HDButton = [[[self plugin] buttonsView] viewWithTag: CTFHDButtonTag];
	if (HDButton != nil) {
		useHD = ([HDButton state] == NSOnState);
	}
	else {
		useHD = [self useVideoHD];
	}
	
	NSString * URLString = [self videoURLStringForHD: useHD];
	NSURL * result = [NSURL URLWithString:URLString];
	return result;
}



// Remove http:// and www. from beginning of URL.
- (NSString *) cleanURLString: (NSString*) URLString {
	NSString * result = URLString;
	
	NSRange range = [URLString rangeOfString:@"http://www." options:NSAnchoredSearch];
	if (range.location == NSNotFound) {
		range = [URLString rangeOfString:@"http://" options:NSAnchoredSearch];
	}
	if (range.location != NSNotFound) {
		result = [URLString substringFromIndex: range.length];
	}
	
	return result;
}



// Helper method used by subclasses to determine whether we want to handle video without Flash.
+ (BOOL) isActive {
	BOOL result = [[CTFUserDefaultsController standardUserDefaults] boolForKey: sUseYouTubeH264DefaultsKey];
	return result;
}



- (BOOL) convertUsingHD: (NSNumber *) useHD {
	BOOL result = NO;
	
	if ([self lookupStatus] == finished && [self hasVideo] && [[self class] isActive]) {
		if ( [[self class] shouldUseQTKit] ) {
			// use QTKit
			[self setupQuickTimeUsingHD: useHD];
		}
		else {
			// use DOM based conversion
			[self convertToMP4ContainerUsingHD: useHD];
		}
		result = YES;
	}
	else if ([self lookupStatus] == inProgress) {
		[self setRequiresConversion: YES];
		result = YES;
	}
	
	return result;
}



// Called when asynchronous lookups are finished. This will convert the element if it has been marked for conversion previously but the kind of conversion wasn't clear yet because of the pending lookups.
- (void) finishedLookups {
	if ([self requiresConversion]) {
		if (![self convert]) {
			[[self plugin] convertTypesForFlashContainer];
		}
	}
}



// We don't handle anything but HTTP requests.
- (BOOL) canPlayResponseResult: (NSURLResponse *) response {
	BOOL result = NO;
	
	if (  [((NSHTTPURLResponse*)response) statusCode] == 200 ) {
		if ( [[response MIMEType] isEqualToString:@"video/mp4"] ) {
			result = YES;
		}
		else if ( [[response MIMEType] isEqualToString:@"video/x-flv"] ) {
			if ( [[QTMovie movieFileTypes: QTIncludeCommonTypes] containsObject: @"flv"] ) {
				// QuickTime can play flv (Perian?)
				result = YES;
			}
		}
	}
	
	return result;
}







#pragma mark -
#pragma mark Accessors


- (NSString *) title {
	return title;
}

- (void) setTitle: (NSString *) newTitle {
	[newTitle retain];
	[title release];
	title = newTitle;
}


- (BOOL) autoPlay {
	BOOL result = autoPlay;
	result = result && [[CTFUserDefaultsController standardUserDefaults] objectForKey:sYouTubeAutoPlayDefaultsKey];
	return result;
}

- (void) setAutoPlay: (BOOL) newAutoPlay {
	autoPlay = newAutoPlay;
}

- (BOOL) hasVideo {
	return hasVideo;
}

- (void) setHasVideo: (BOOL) newHasVideo {
	hasVideo = newHasVideo;
	[self addButtons];
	[[[self plugin] mainButton] setNeedsDisplay:YES];
}


- (BOOL) hasVideoHD {
	return hasVideoHD;
}

- (void) setHasVideoHD: (BOOL) newHasVideoHD {
	hasVideoHD = newHasVideoHD;
	[self addButtons];
	[[[self plugin] mainButton] setNeedsDisplay: YES];
}



- (void) increaseActiveLookups {
	activeLookups++;
	[self setLookupStatus: inProgress];
}

- (void) decreaseActiveLookups {
	activeLookups--;
	if ( activeLookups == 0 && [self lookupStatus] != failed ) {
		[self setLookupStatus: finished];
	}
}


- (CTFLoader *) videoLookup {
	return videoLookup;
}

- (void) setVideoLookup: (CTFLoader *) newVideoLookup {
	[newVideoLookup retain];
	[videoLookup cancel];
	[videoLookup release];
	videoLookup = newVideoLookup;
}


- (CTFLoader *) videoHDLookup {
	return videoHDLookup;
}

- (void) setVideoHDLookup: (CTFLoader *) newVideoHDLookup {
	[newVideoHDLookup retain];
	[videoHDLookup cancel];
	[videoHDLookup release];
	videoHDLookup = newVideoHDLookup;
}


- (enum CTFKVLookupStatus) lookupStatus {
	return lookupStatus;
}

- (void) setLookupStatus: (enum CTFKVLookupStatus) newLookupStatus {
	lookupStatus = newLookupStatus;
	if (lookupStatus == finished || lookupStatus == failed) {
		[self finishedLookups];
	}
	[[[self plugin] mainButton] setNeedsDisplay: YES];
}


- (BOOL) requiresConversion {
	return requiresConversion;
}

- (void) setRequiresConversion: (BOOL) newRequiresConversion {
	requiresConversion = newRequiresConversion;
}


- (BOOL) hasRefreshedURLs {
	return hasRefreshedURLs;
}

- (void) setHasRefreshedURLs: (BOOL) newHasRefreshedURLs {
	hasRefreshedURLs = newHasRefreshedURLs;
}

@end

