/*
 CTFKillerYouTube.m
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

#import "CTFKillerYouTube.h"
#import "CTFUserDefaultsController.h"
#import "Plugin.h"
#import "CTFUtilities.h"
#import "CTFLoader.h"

@implementation CTFKillerYouTube


#pragma mark CTFKiller subclassing overrides

+ (BOOL) canHandleFlashAtURL: (NSURL*) theURL src: (NSString*) theSrc attributes: (NSDictionary*) theAttributes forPlugin:(CTFClickToFlashPlugin*) thePlugin {
	BOOL result = NO;
	
	if ([[self class] isActive]) {
		if (theSrc != nil) {
			NSURL * srcURL = [NSURL URLWithString: theSrc];
			NSString * host = [srcURL host];
			if (host != nil ) {
				result = result 
				|| ( [host rangeOfString: @"youtube.com" options: NSAnchoredSearch|NSBackwardsSearch].location != NSNotFound )
				|| ( [host rangeOfString: @"youtube-nocookie.com" options: NSAnchoredSearch|NSBackwardsSearch].location != NSNotFound )
				|| ( [host rangeOfString: @"ytimg.com" options: NSAnchoredSearch|NSBackwardsSearch].location != NSNotFound );
			}
		}
		
		if (!result) {
			NSString* fV = [theAttributes objectForKey: @"flashvars" ];
			if (fV != nil) {
				NSDictionary * flashVars = [CTFClickToFlashPlugin flashVarDictionary:fV];
				NSString * URLString = [flashVars objectForKey:@"rv.0.url"];
				if (URLString != nil) {
					result = result || ([URLString rangeOfString: @"youtube.com"].location != NSNotFound )
					|| ([URLString rangeOfString: @"youtube-nocookie.com"].location != NSNotFound );
				}		
			}
		}
	}
	
	return result;
}




- (void) setup {
	lookupStatus = nothing;
	[self setInfoFromFlashVars];

	NSString * myVideoID = [self videoID];
	NSString * myVideoHash = [self videoHash];
	
	if (myVideoID != nil && myVideoHash != nil) {
		// We are on a YouTube page which contains all relevant info right there.
		// We already checked for video: check for videos. Now get the video's name.
		 
		// first get <html> and <head> nodes
		DOMDocument * d = [[[self plugin] container] ownerDocument];
		DOMNode * HTML = [[d firstChild] nextSibling];
		DOMNodeList * nodeList = [HTML childNodes];
		DOMNode * headNode = nil;
		NSUInteger i;
		for ( i = 0; i < [nodeList length]; i++ ) {
			headNode = [nodeList item: i];
			if ( [[headNode nodeName] isEqualToString: @"HEAD"] ) {
				// found <head> node, now scan for <meta title="name"...
				break;
			}
		}
		
		if ( i < [nodeList length] ) {
			// we break-ed out of the previous loop -> continue
			nodeList = [headNode childNodes];
			DOMNode * metaNode = nil;
			for ( i = 0; i < [nodeList length]; i++ ) {
				metaNode = [nodeList item: i];
				if ( [[metaNode nodeName] isEqualToString: @"META"] ) {
					DOMNode * theAttribute = [[metaNode attributes] getNamedItem:@"name"];
					if ( theAttribute != nil ) {
						// found a name attribute
						NSString * theValue = [theAttribute nodeValue];
						if ( [theValue isEqualToString: @"title"] ) {
							// found a name attribute called title -> set it
							theAttribute = [[metaNode attributes] getNamedItem:@"content"];
							if ( theAttribute != nil ) {
								[self setTitle: [theAttribute nodeValue]];
							}
							break;
						}
					}
				}
			}		
		}
		
	} 
	else {
		// it's an embedded YouTube flash view; scrub the URL to
		// determine the video_id, then get the source of the YouTube
		// page to get the Flash vars
		
		if ( myVideoID == nil ) {
			NSURL * ytURL = [NSURL URLWithString: srcURLString];
			NSString * host = [ytURL host];
			if (([host rangeOfString:@"youtube.com" options: NSAnchoredSearch | NSBackwardsSearch].location != NSNotFound) || ([host rangeOfString:@"youtube-nocookie.com" options: NSAnchoredSearch | NSBackwardsSearch].location != NSNotFound ) ) {
				
				NSString * path = [ytURL path];
				NSRange lastSlashRange = [path rangeOfString:@"/" options:NSLiteralSearch | NSBackwardsSearch];
				NSInteger lastSlash = lastSlashRange.location;
				NSRange firstAmpersandRange = [path rangeOfString:@"&" options:NSLiteralSearch];
				if ( lastSlash != NSNotFound ) {
					NSInteger firstAmpersand = firstAmpersandRange.location;
					if (firstAmpersand == NSNotFound) {
						firstAmpersand = [path length];
					}
					if (lastSlash < firstAmpersand ) {
						NSRange IDRange = NSMakeRange(lastSlash + 1, firstAmpersand - lastSlash - 1);
						myVideoID = [path substringWithRange:IDRange];
					}
				}
			}			
		}
		
		
		if (myVideoID != nil) {
			[self setVideoID: myVideoID];
			
			// Download the video information asynchronously.
			[self retrieveYouTubeInfoAndCheck];
		}
	}
	
	if ( myVideoID != nil ) {
		[[self plugin] setPreviewURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://img.youtube.com/vi/%@/0.jpg", myVideoID]]];
	}
	
	if ([[self class] isYouTubeSiteURL: pageURL]) {
		[self setAutoPlay: YES];
	} else {
		[self setAutoPlay: [[self flashVarWithName: @"autoplay"] isEqualToString:@"1"]];
	}
}



- (void) dealloc {
	[self setVideoID: nil];
	[self setVideoHash: nil];
	[self setInfoLoader: nil];
	
	[super dealloc];
}





#pragma mark -
#pragma mark CTFVideoKiller subclassing overrides

// Name of the video service that can be used for automatic link text generation 
- (NSString*) siteName { 
	return CtFLocalizedString(@"YouTube", @"Name of YouTube");
}



// URL to the video file used for loading it in the player.
- (NSString*) videoURLString { 
	NSString * result = nil;
	NSString * ID = [self videoID];
	NSString * hash = [self videoHash];
	if (ID != nil && hash != nil) {
		result = [ NSString stringWithFormat: @"http://www.youtube.com/get_video?fmt=18&video_id=%@&t=%@", ID, hash ];		
	}

	return result;
} 



- (NSString*) videoHDURLString { 
	NSString * result = nil;
	NSString * ID = [self videoID];
	NSString * hash = [self videoHash];
	if (ID != nil && hash != nil) {	
		result = [ NSString stringWithFormat: @"http://www.youtube.com/get_video?fmt=22&video_id=%@&t=%@", ID, hash ];
	}
	
	return result; 
}



// HTML needed to embed the video
- (NSString *) embedString {
	NSString * youTubeEmbedTemplate = @"<object width='480' height='385'>\n<param name='movie' value='http://www.youtube.com/v/%1$@&amp;hl=%2$@&amp;fs=1'></param>\n<param name='allowFullScreen' value='true'></param>\n<param name='allowscriptaccess' value='always'></param>\n<embed src='http://www.youtube.com/v/%1$@&amp;hl=%2$@&amp;fs=1' type='application/x-shockwave-flash' allowscriptaccess='always' allowfullscreen='true' width='480' height='385'></embed>\n</object>\n";
	NSString * countryCode = @"de";
	
	NSString * youTubeEmbedTag = [NSString stringWithFormat:youTubeEmbedTemplate, [self videoID], countryCode];
	
	return youTubeEmbedTag;
}




// If lookups are required to determine the correct URL to the video, redo them. When returning, the URLs should be refreshed and ready to use.
- (void) refreshVideoURLs {
	[self synchronouslyRetrieveYouTubeInfoAndCheck];
}



// URL of the web page displaying the video. Return nil if there is none.
- (NSString *) videoPageURLString {
	return [ NSString stringWithFormat: @"http://www.youtube.com/watch?v=%@", [self videoID] ];
}






#pragma mark -
#pragma mark CTFKillerYouTube methods

+ (BOOL) isYouTubeSiteURL: (NSURL*) theURL {
	NSString * host = [theURL host];
	BOOL result = [host isEqualToString:@"www.youtube.com"]	|| [host isEqualToString:@"www.youtube-nocookie.com"];

	return result;
}



- (NSURL *) YouTubeInfoURL {
	NSURL * infoURL = nil;
	NSString * theVideoID = [self videoID];
	
	if ( theVideoID != nil ) {
		NSString * YouTubeInfoURLString = [NSString stringWithFormat:@"http://www.youtube.com/get_video_info?video_id=%@", theVideoID];
		infoURL = [NSURL URLWithString: YouTubeInfoURLString];
	}
	
	return infoURL;
}






#pragma mark -
#pragma mark Check for Videos

- (void)_checkForH264VideoVariants {
	CTFLoader * loader;
	
	loader = [CTFLoader loaderWithURL: [NSURL URLWithString:[self videoURLString]]
							 delegate: self
							 selector: @selector(HEADDownloadFinished:)];
	[self setVideoLookup: loader];
	if (loader != nil) {
		[loader setHEADOnly: YES];
		[loader start];
		[self increaseActiveLookups];
	}
	else {
		[self setLookupStatus: failed];
	}
	
	loader = [CTFLoader loaderWithURL: [NSURL URLWithString:[self videoHDURLString]]
							 delegate: self
							 selector: @selector(HEADHDDownloadFinished:)];
	[self setVideoHDLookup: loader];
	if (loader != nil) {
		[loader setHEADOnly: YES];
		[loader start];
		[self increaseActiveLookups];
	}
	else {
		[self setLookupStatus: failed];
	}
}



- (void) HEADDownloadFinished: (CTFLoader *) loader {
	if ( [self canPlayResponseResult: [loader response]] ) {
		[self setHasVideo: YES];
	}

	[self decreaseActiveLookups];
	[self setVideoLookup: nil];
}


- (void) HEADHDDownloadFinished: (CTFLoader *) loader {
	if ( [self canPlayResponseResult: [loader response]] ) {
		[self setHasVideoHD: YES];
	}

	[self decreaseActiveLookups];
	[self setVideoHDLookup: nil];
}






#pragma mark -
#pragma mark Get and evaluate Video Information


- (void) setInfoFromFlashVars {
	NSString * myVideoID = [self flashVarWithName: @"video_id"];
	if ( myVideoID != nil ) {
		if ( ![myVideoID isEqualToString: [self videoID]] ) {
			if ([self videoID] != nil) {
				NSLog(@"ClickToFlashKillerYouTube -setInfoFromFlashVars: YouTube video with ambiguous IDs at %@ (%@, %@)", [self pageURL], [self videoID], myVideoID);
			}
			[self setVideoID: myVideoID];
		}
		
		// 'hash' value is in the 't' or 'token' flashvar
		NSString * myHash = [self flashVarWithName: @"t"];
		if ( myHash == nil ) {
			myHash = [self flashVarWithName: @"token"];
		}
		if ( myHash != nil ) {
			[self setVideoHash: myHash];
			[self _checkForH264VideoVariants];
		}
		else {
			NSLog(@"ClickToFlashKillerYouTube -setInfoFromFlashVars: No 't' or 'token' Flash variable found for video %@", [self videoID]);
		}
		
		NSString * myTitle = [self flashVarWithName: @"title"];
		if ( myTitle != nil ) {
			// NSLog(@"CTFKillerYouTube - setInfoFramFlashVars: found 'title' flash var and setting name from it: %@", myTitle);
			// There seem to exist cases in which all spaces in the Title are represented as +:
			// Replace all + by a space if no spaces are present.
			if ( [myTitle rangeOfString:@" "].location == NSNotFound ) {
				NSMutableString * changedTitle = [[myTitle mutableCopy] autorelease];
				if ([changedTitle replaceOccurrencesOfString:@"+" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [changedTitle length])] > 0 ) {
					myTitle = changedTitle;
				}
			}
			[self setTitle: myTitle];
		}
		
	}
}



- (void) evaluateYouTubeInfoString: (NSString *) YouTubeInfoString {
	if (YouTubeInfoString != nil) {
		NSArray * argumentArray = [YouTubeInfoString componentsSeparatedByString:@"&"];
		NSMutableDictionary * myFlashVars = [NSMutableDictionary dictionaryWithCapacity: [argumentArray count]];
		CTFForEachObject( NSString, argument, argumentArray ) {
			NSRange equalsRange = [argument rangeOfString:@"=" options:NSLiteralSearch];
			if ( equalsRange.location != NSNotFound && [argument length] > equalsRange.location ) {
				NSString * argumentName = [argument substringToIndex: equalsRange.location];
				NSString * argumentInfo = [argument substringFromIndex: equalsRange.location + 1];
				argumentInfo = [argumentInfo stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
				[myFlashVars setObject: argumentInfo forKey: argumentName];
			}
		}
		
		[self setFlashVars: myFlashVars];
		[self setInfoFromFlashVars];
	}
}



// get video information from the net _a_synchronously
- (void) retrieveYouTubeInfoAndCheck {
	CTFLoader * loader = [[[CTFLoader alloc] initWithURL: [self YouTubeInfoURL]
												delegate: self
												selector: @selector(YouTubeInfoDownloadFinished:)] autorelease];
	[self setInfoLoader: loader];
	
	if ( loader != nil ) {
		[loader start];
		[self increaseActiveLookups];
	}
}



// Callback for the infoLoader
- (void) YouTubeInfoDownloadFinished: (CTFLoader *) loader {
	NSString * YouTubeInfo = [[[NSString alloc] initWithData: [loader data] encoding:NSUTF8StringEncoding] autorelease];
	
	if ( YouTubeInfo != nil ) {
		[self evaluateYouTubeInfoString: YouTubeInfo];
	}

	[self decreaseActiveLookups];
	[self setInfoLoader: nil];
}



// get video information from the net _synchronously_
// if possible, use the asynchronous -retrieveYouTubeInfoAndCheck instead
- (void) synchronouslyRetrieveYouTubeInfoAndCheck {
	[self increaseActiveLookups];
	
	NSError * YouTubeInfoError = nil;
	NSString * YouTubeInfoString = [NSString stringWithContentsOfURL: [self YouTubeInfoURL]
														usedEncoding: nil
															   error: &YouTubeInfoError];
	
	if ( YouTubeInfoString != nil ) {
		[self evaluateYouTubeInfoString: YouTubeInfoString];
	}
	else {
		if (YouTubeInfoError != nil) {
			NSLog(@"ClickToFlashKillerYouTube, Error in -synchronouslyRetrieveYouTubeInfoAndCheck: %@", [YouTubeInfoError localizedDescription]);
		}
	}
	 
	[self decreaseActiveLookups];
}






#pragma mark -
#pragma mark Accessors

- (NSString *)videoID {
	return videoID;
}

- (void)setVideoID:(NSString *)newVideoID {
	[newVideoID retain];
	[videoID release];
	videoID = newVideoID;
}


- (NSString*) videoHash {
	return videoHash;
}

- (void)setVideoHash:(NSString *)newVideoHash {
	[newVideoHash retain];
	[videoHash release];
	videoHash = newVideoHash;
}


- (CTFLoader *) infoLoader {
	return infoLoader;
}

- (void) setInfoLoader: (CTFLoader *) newInfoLoader {
	[newInfoLoader retain];
	[infoLoader cancel];
	[infoLoader release];
	infoLoader = newInfoLoader;
}



@end
