/*
 CTFKillerVideo.h
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

#import <Cocoa/Cocoa.h>
#import "CTFKiller.h"

@class DOMElement;
@class QTMovie;
@class QTMovieView;
@class CTFLoader;

enum CTFKVLookupStatus {
	nothing = 0,
	inProgress = 1,
	finished = 2,
	failed = 3
};

extern NSString * sDisableVideoElementDefaultsKey;
extern NSString * sUseYouTubeH264DefaultsKey;
extern NSString * sUseYouTubeHDH264DefaultsKey;
extern NSString * sYouTubeAutoPlayDefaultsKey;
extern NSString * sUseQTKitDefaultsKey;
// defined in CTFKillerVideo-QT
extern NSString * sVideoVolumeLevelDefaultsKey;



@interface CTFKillerVideo : CTFKiller {
	BOOL autoPlay;
	BOOL hasAutoPlayed;
	BOOL hasVideo;
	BOOL hasVideoHD;
	NSCellStateValue usingHD;
	
	NSString * title;
	
	CTFLoader * videoLookup;
	CTFLoader * videoHDLookup;
	NSInteger activeLookups;
	enum CTFKVLookupStatus lookupStatus;
	BOOL requiresConversion;
	
	BOOL hasRefreshedURLs;

	// used in CTFKillerVideo-QT
	NSProgressIndicator * progressIndicator;
	
	QTMovieView * movieView;
	QTMovie * movie;
	NSView * endOfMovieButtonsView;
}


/*
 Subclasses use setHasVideo and setHasVideoHD to indicate when they have determined movie paths.
 They set lookupStatus to indicate whether they are still busy doing lookups. Doing this will cause a redraw which can then alter the label text.
*/

// to be implemented by subclasses if they want to

// Name of the video service that can be used for automatic link text generation 
- (NSString*) siteName;

// URL to the video file used for loading it in the player.
- (NSString*) videoURLString;
- (NSString*) videoHDURLString;

// HTML needed to embed the video
- (NSString *) embedString;

// If lookups are required to determine the correct URL to the video, redo them. When returning, the URLs should be refreshed and ready to use.
- (void) refreshVideoURLs;

// Text used for video file download link. Return nil to use standard text.
- (NSString *) videoDownloadLinkText;

// URL of the web page displaying the video. Return nil if there is none.
- (NSString *) videoPageURLString;

// Text used for link to video page. Return nil to use standard text.
- (NSString *) videoPageLinkText;

// Edit or replace the markup that is added for the links beneath the video. The descriptionElement passed to the method already conatins Go to Webpage and Download Video File links.
- (DOMElement *) enhanceVideoDescriptionElement: (DOMElement*) descriptionElement;

// Indicate whether the current web page is the 'canonical' web page for the video. The default implementation compares the videoPageURLString with the current page's URL for that
- (BOOL) isOnVideoPage;




// Helper
+ (BOOL) isActive;
- (BOOL) convertUsingHD: (NSNumber *) useHD;

// Actions
- (IBAction) loadVideo:(id)sender;
- (IBAction) loadVideoSD:(id)sender;
- (IBAction) loadVideoHD:(id)sender;
- (void) downloadVideoUsingHD: (BOOL) useHD;
- (IBAction) downloadVideo: (id) sender;
- (IBAction) downloadVideoSD: (id) sender;
- (IBAction) downloadVideoHD: (id) sender;
- (IBAction) gotoVideoPage: (id) sender;
- (IBAction) copyEmbedTag: (id) sender;
- (void) openFullscreenInQTPlayerUsingHD: (BOOL) useHD;
- (IBAction) openFullscreenInQTPlayer: (id) sender;
- (IBAction) openFullscreenInQTPlayerSD: (id) sender;
- (IBAction) openFullscreenInQTPlayerHD: (id) sender;


// Helpers
- (BOOL) useVideo;
- (BOOL) useVideoHD;
- (NSString *) videoURLStringForHD: (BOOL) useHD;
- (NSURL *) downloadURL;
- (NSString *) cleanURLString: (NSString*) URLString;
- (void) finishedLookups;
- (BOOL) canPlayResponseResult: (NSURLResponse *) result;


// Accessors
- (NSString *) title;
- (void) setTitle: (NSString *) newTitle;
- (BOOL) autoPlay;
- (void) setAutoPlay:(BOOL)newAutoPlay;
- (BOOL) hasVideo;
- (void) setHasVideo:(BOOL)newHasVideo;
- (BOOL) hasVideoHD;
- (void) setHasVideoHD:(BOOL)newHasVideoHD;

- (void) increaseActiveLookups;
- (void) decreaseActiveLookups;
- (CTFLoader *) videoLookup;
- (void) setVideoLookup: (CTFLoader *) newVideoLookup;
- (CTFLoader *) videoHDLookup;
- (void) setVideoHDLookup: (CTFLoader *) newVideoHDLookup;
- (enum CTFKVLookupStatus) lookupStatus;
- (void) setLookupStatus: (enum CTFKVLookupStatus) newLookupStatus;
- (BOOL) requiresConversion;
- (void) setRequiresConversion: (BOOL) newRequiresConversion;

- (BOOL) hasRefreshedURLs;
- (void) setHasRefreshedURLs: (BOOL) newHasRefreshedURLs;

@end
