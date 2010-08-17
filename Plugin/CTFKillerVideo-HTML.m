/*
 
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

#import "CTFKillerVideo-HTML.h"
#import "CTFKillerVideo.h"
#import "Plugin.h"
#import "CTFUserDefaultsController.h"
#import <WebKit/WebKit.h>

static NSString * divCSS = @"margin:auto;padding:0px;border:0px none;text-align:center;display:block;float:none;";




@implementation CTFKillerVideo (HTML)


#pragma mark -
#pragma mark Insert Video using the DOM

- (void) _convertElementForMP4: (DOMElement*) element atURL: (NSString*) URLString {
	// some tags (OBJECT) want a data attribute, and some want a src attribute
	// for some reason, though, some cloned elements are not reporting themselves
	// as OBJECT tags, even though they are; more investigation on this is needed,
	// but for now, setting both the data and the src attribute corrects the problem
	// (see bug #294)
	
	[ element setAttribute: @"data" value: URLString ];
	[ element setAttribute: @"src" value: URLString ];
	[ element setAttribute: @"type" value: @"video/mp4" ];
    [ element setAttribute: @"scale" value: @"aspect" ];
    if ([self autoPlay]) {
		[ element setAttribute: @"autoplay" value: @"true" ];
	} else {
		[ element setAttribute: @"autoplay" value: @"false" ];
	}
    [ element setAttribute: @"cache" value: @"false" ];
	[ element setAttribute: @"bgcolor" value: @"transparent" ];
    [ element setAttribute: @"flashvars" value: nil ];
}



- (void) _convertElementForVideoElement: (DOMElement*) element atURL: (NSString*) URLString {
    [ element setAttribute: @"src" value: URLString ];
	if ([self autoPlay]) {
		[ element setAttribute: @"autoplay" value:@"autoplay" ];
	} else {
		if ( [element hasAttribute:@"autoplay"] ) {
			[ element removeAttribute:@"autoplay" ];
		}
		// we're not autoplaying, so don't preload the film if supported by WebKit
		if ( [self isVideoPreloadAvailable] && [[self plugin] isImmediatelyConverted] ) {
			[element setAttribute:@"preload" value:@"none"];
		}
	}
	
	if ([[self plugin] previewURL] != nil) {
		[element setAttribute: @"poster"  value: [[[self plugin] previewURL] absoluteString]];
	}
	[ element setAttribute: @"controls" value:@"controls"];
	[ element setAttribute:@"width" value:@"100%"];
}



/*
 The useHD parameter indicates whether we want to override the default behaviour to use or not use HD.
 Passing nil invokes the default behaviour based on user preferences and HD availability.
*/
- (void) convertToMP4ContainerUsingHD: (NSNumber*) useHD {
	NSNumber * myUseHD = useHD;
	if ( useHD == nil ) {
		myUseHD = [NSNumber numberWithBool:[self useVideoHD]];
	}
	
	// Delay this until the end of the event loop, because it may cause self to be deallocated.
	[self performSelector:@selector(_convertToMP4ContainerAfterDelayUsingHD:) withObject:myUseHD afterDelay:0.0];
}



// Is called from CTFKillerVideo-HTML -convertToMP4ContainerUsingHD: only.
- (void) _convertToMP4ContainerAfterDelayUsingHD: (NSNumber*) useHDNumber {
 	// Continue on main thread as DOM will be changed.
	[self performSelectorOnMainThread:@selector(_convertToMP4ContainerUsingHD:) withObject:useHDNumber waitUntilDone:YES];
}



// Replace our plugin element in DOM by a <video> or <embed> element for the video.
// Changes the DOM, thus needs to be called on main thread.
// Is called from CTFKillerVideo-HTML -_convertToMP4ContainerAfterDelayUsingHD: only.
- (void) _convertToMP4ContainerUsingHD: (BOOL) useHD {
	CtFMainThreadAssertion();
	
	[plugin revertToOriginalOpacityAttributes];
	[plugin prepareForConversion];

	DOMElement * container = [[self plugin] container];
	DOMDocument * document = [container ownerDocument];
	NSString * URLString = [self videoURLStringForHD: useHD];
	
	DOMElement * videoElement;
	if ([ self isVideoElementAvailable ]) {
		// replace with HTML 5 <video> element
		videoElement = [document createElement:@"video"];
		[ self _convertElementForVideoElement: videoElement atURL: URLString ];
	} else {
		// replace with <embed> tag for QuickTime video
		videoElement = (DOMElement*) [container cloneNode: NO ];
		[ self _convertElementForMP4: videoElement atURL: URLString ];
	}
	
	
	DOMNode * widthNode = [[container attributes ] getNamedItem:@"width"];
	NSString * width = @"100%"; // default to 100% width
	if (widthNode != nil) {
		// width is already set explicitly, preserve that
		width = [widthNode nodeValue];
		if ( [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[width characterAtIndex:[width length] - 1]] ) {
			// add 'px' if existing width is just a number (ends with a digit)
			width = [width stringByAppendingString:@"px"];
		}
	}
	NSString * widthCSS = [NSString stringWithFormat:@"%@width:%@;", divCSS, width];
	
	DOMElement * CtFContainerElement = [document createElement: @"div"];
	[CtFContainerElement setAttribute: @"style" value: widthCSS];
	[CtFContainerElement setAttribute: @"class" value: @"clicktoflash-container"];
	[CtFContainerElement appendChild: videoElement];
	
	DOMElement * linkContainerElement = [self linkContainerElementUsingHD: useHD];
	if ( linkContainerElement != nil ) {
		[CtFContainerElement appendChild: linkContainerElement];
	}
	
	// Just to be safe, since we are about to replace our containing element
	[[self retain] autorelease];
	
	// Replace self with element.
	[[container parentNode] replaceChild: CtFContainerElement oldChild: container];
	
	[[self plugin] setContainer:nil];
}



- (DOMElement*) linkContainerElementUsingHD: (BOOL) useHD {
	// Link container
	DOMDocument* document = [[[self plugin] container] ownerDocument];
	DOMElement* linkContainerElement = [document createElement: @"div"];
	NSString * linkCSS = @"margin:0px 0.5em;padding:0px;border:0px none;";
	[linkContainerElement setAttribute: @"style" value: divCSS];
	[linkContainerElement setAttribute: @"class" value: @"clicktoflash-linkcontainer"];
	
	// Link to the video's web page if we're not there already
	NSString * videoPageURLString = [self videoPageURLString];
	if ( videoPageURLString != nil && ![self isOnVideoPage] )  {
		DOMElement* videoPageLinkElement = [document createElement: @"a"];
		[videoPageLinkElement setAttribute: @"href" value: videoPageURLString];
		[videoPageLinkElement setAttribute: @"style" value: linkCSS];
		[videoPageLinkElement setAttribute: @"class" value: @"clicktoflash-link"];
		NSString * videoPageLinkText = [self videoPageLinkText];
		if (videoPageLinkText == nil) {
			NSString * formatString = CtFLocalizedString(@"Go to %@ Page", @"Text of link to the video page on SITENAME appearing beneath the video");
			videoPageLinkText = [NSString stringWithFormat:formatString, [self siteName]];
		}
		[videoPageLinkElement setTextContent: videoPageLinkText];
		
		[linkContainerElement appendChild: videoPageLinkElement];
	}
	
	// Link to Movie file download(s)
	DOMElement* downloadLinkElement;
	
	if ( !([self hasVideoHD] && !useHD) ) {
		// standard case with a single link
		downloadLinkElement = [document createElement: @"a"];
		[downloadLinkElement setAttribute: @"href" value: [self videoURLStringForHD: useHD]];
		[downloadLinkElement setAttribute: @"style" value: linkCSS];
		[downloadLinkElement setAttribute: @"class" value: @"clicktoflash-link videodownload"];
		NSString * videoDownloadLinkText = [self videoDownloadLinkText];
		if (videoDownloadLinkText == nil) {
			videoDownloadLinkText = CtFLocalizedString(@"Download video file", @"Text of link to Video Download appearing beneath the video");
		}
		[downloadLinkElement setTextContent: videoDownloadLinkText];
		
		[linkContainerElement appendChild:downloadLinkElement];
	}
	else {
		// special case with a HD video available but HD turned off: offer links for downloading the standard and the larger size
		linkCSS = @"margin:0px 0.3em;padding:0px;border:0px none;";
		
		DOMElement * initialTextElement = [document createElement: @"span"];
		[initialTextElement setTextContent: CtFLocalizedString(@"Download: ", @"Label for download links appearing beneath the video")];
		[linkContainerElement appendChild: initialTextElement];
		
		downloadLinkElement = [document createElement: @"a"];
		[downloadLinkElement setAttribute: @"href" value: [self videoURLString]];
		[downloadLinkElement setAttribute: @"style" value: linkCSS];
		[downloadLinkElement setAttribute: @"class" value: @"clicktoflash-link videodownload"];
		[downloadLinkElement setTextContent: CtFLocalizedString(@"Current Size", @"Text of link for downloading a version of the video in the current size; appearing beneath the video")];
		[linkContainerElement appendChild: downloadLinkElement];
		
		DOMElement * extraDownloadLinkElement = [document createElement: @"a"];
		[extraDownloadLinkElement setAttribute: @"href" value: [self videoHDURLString]];
		[extraDownloadLinkElement setAttribute: @"style" value: linkCSS];
		[extraDownloadLinkElement setAttribute: @"class" value: @"clicktoflash-link videodownload"];
		[extraDownloadLinkElement setTextContent: CtFLocalizedString(@"Larger Size", @"Text of link to additional Large Size Video Download appearing beneath the video after the standard link")];
		[linkContainerElement appendChild: extraDownloadLinkElement];
	}
	
	// Let subclasses add their own link (or delete ours)
	linkContainerElement = [self enhanceVideoDescriptionElement: linkContainerElement];
	
	return linkContainerElement;
}




#pragma mark -
#pragma mark Helper


- (BOOL) isVideoElementAvailable
{
	if ( [[CTFUserDefaultsController standardUserDefaults] boolForKey:sDisableVideoElementDefaultsKey] )
		return NO;
	
	/* <video> element compatibility was added to WebKit in or shortly before version 525. */
	
    NSBundle* webKitBundle;
    webKitBundle = [ NSBundle bundleForClass: [ WebView class ] ];
    if (webKitBundle) {
		/* ref. http://lists.apple.com/archives/webkitsdk-dev/2008/Nov/msg00003.html:
		 * CFBundleVersion is 5xxx.y on WebKits built to run on Leopard, 4xxx.y on Tiger.
		 * Unspecific builds (such as the ones in OmniWeb) get xxx.y numbers without a prefix.
		 */
		int normalizedVersion;
		float wkVersion = [ (NSString*) [ [ webKitBundle infoDictionary ] 
										 valueForKey: @"CFBundleVersion" ] 
						   floatValue ];
		if (wkVersion > 4000)
			normalizedVersion = (int)wkVersion % 1000;
		else
			normalizedVersion = wkVersion;
		
		// unfortunately, versions of WebKit above 531.5 also introduce a nasty
		// scrolling bug with video elements that cause them to be unviewable;
		// this bug was fixed shortly after being reported by @simX, so we can
		// now re-enable it for correct WebKit versions
		//
		// this bug actually only affected certain machines that had graphics
		// cards with a certain max texture size, and it was partially fixed, but
		// still didn't work for MacBooks with embedded graphics, and we could
		// detect that if we really wanted, but that would require importing
		// the OpenGL framework, which we probably shouldn't do, so we'll just
		// wholesale disable for certain WebKit versions
		//
		// https://bugs.webkit.org/show_bug.cgi?id=28705
		
		if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) {
			// Snowy Leopard; this bug doesn't seem to be exhibited here
			return (normalizedVersion >= 525);
		} else {
			// this bug was introduced in version 531.5, but has been fixed in
			// 532 and above
			
			return ((normalizedVersion >= 532) ||
					((normalizedVersion >= 525) && (normalizedVersion < 531.5))
					);
		}
	}
	return NO;
}



// The preload parmeter for media elements was added to the HTML5 spec in spring 2010.
// It seems to be in WebKit since revision 55463.
// That seems to work out as a bundle version of 533+.
- (BOOL) isVideoPreloadAvailable {
	BOOL result = NO;
	NSBundle* webKitBundle;
    webKitBundle = [ NSBundle bundleForClass: [ WebView class ] ];

    if (webKitBundle) {
		/* ref. http://lists.apple.com/archives/webkitsdk-dev/2008/Nov/msg00003.html:
		 * CFBundleVersion is Nxxx.y on WebKits built into Mac OS X.N.
		 * Unspecific builds (such as the ones in OmniWeb) get xxx.y numbers without a prefix.
		 */
		int normalizedVersion;
		float wkVersion = [ (NSString*) [ [ webKitBundle infoDictionary ]
										 valueForKey: @"CFBundleVersion" ]
						   floatValue ];
		if (wkVersion > 4000)
			normalizedVersion = ((int)wkVersion % 1000);
		else
			normalizedVersion = wkVersion;
		
		if (normalizedVersion >= 533) {
			result = YES;
		}
	}
	
	return result;
}



@end
