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

#import "CTFKillerVideo-QT.h"
#import "CTFUserDefaultsController.h"
#import "Plugin.h"
#import <QTKit/QTKit.h>
#import "CTFButtonsView.h"
#import "CTFButton.h"
#import "CTFMovieView.h"
#import <sys/xattr.h>


NSString * sVideoVolumeLevelDefaultsKey = @"Video Volume Level";



@implementation CTFKillerVideo (QuickTime)

/* This is 10.5 and higher only. It is only used for QTMovie-style playback which requires 10.5 as well. */
+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *) key {
	NSSet * result = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"HDButtonTooltip"]) {
		result = [result setByAddingObject: @"usingHD"];
	}
	
	return result;
}



+ (BOOL) shouldUseQTKit {
	BOOL result = (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_5);
	result = result && [[CTFUserDefaultsController standardUserDefaults] boolForKey: sUseQTKitDefaultsKey];
	return result;
}





#pragma mark -
#pragma mark Insert Video using QTKit

- (void) setupQuickTimeUsingHD: (NSNumber*) useHDNumber {
	CtFMainThreadAssertion();

	// Remove Save button in case it is visible (e.g. when switching to HD version).
	[self hideEndOfMovieButtons];
	
	// Create QTMovieView if necessary.
	[self createAndInsertMovieView];
	QTMovieView * myMovieView = [self movieView];
		
	// Add progress indicator. It will be removed when the film has loaded sufficiently or when loading fails.
	[self addProgressIndicator];
	
	// Create the movie.
	QTMovie * myMovie = [self movieForHD: useHDNumber];
	
	// Add movie to QTMovie view and set it up.
	if ( myMovie != nil && myMovieView ) {
		[self setMovie: myMovie];
		[myMovieView setMovie: myMovie];

		// It seems like QTMovieView has two subviews: one displaying the film, one for the controller. The controller view seems to end up _not_ wanting the layer. This can cause the controller to disappear after switching tabs. So we sneakily set all subviews of the QTMovieView to want a layer here.
		NSEnumerator * viewEnumerator = [[myMovieView subviews] objectEnumerator];
		NSView * view;
		while ( ( view = [viewEnumerator nextObject] ) ) {
			[view setWantsLayer:YES];
		}
		
		[[[self plugin] mainButton] setHidden:YES];
		[[[self plugin] window] makeFirstResponder: myMovieView];
	}
	
	// not doing this on the main thread seems to hang the application
	// [self performSelectorOnMainThread:@selector(resizeToFitMovie) withObject:nil waitUntilDone:NO];
}



// Creates the movieView if it doesn't exist already.
// Should run on main thread only as it potentially changes views.
// Is called from -setupQuickTimeUsingHD: only.
- (void) createAndInsertMovieView {
	if ( [self movieView] == nil ) {
		NSView * mainContainer = [[self plugin] containerView];
		NSRect bounds;
		if (mainContainer != nil) {
			bounds = [mainContainer bounds];
		}
		else {
			bounds = NSZeroRect;
		}
		
		QTMovieView * myMovieView = [[[CTFMovieView alloc] initWithFrame:bounds] autorelease];
		
		if ( myMovieView != nil ) {
			[myMovieView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
			[myMovieView setPreservesAspectRatio:YES];
			[myMovieView setWantsLayer: YES]; // video seems invisible without the layer
			
			// Use black background in full screen mode.
			if ( [[self plugin] isFullScreen] ) {
				[myMovieView setFillColor: [NSColor blackColor]];
			}
			else {
				[myMovieView setFillColor: [NSColor clearColor]];
			}
			
			// Insert movieView into view hierarchy
			[mainContainer addSubview: myMovieView positioned: NSWindowBelow relativeTo: nil];
			[[self plugin] setNextKeyView: myMovieView];
			[myMovieView setNextKeyView: (NSView *)[[self plugin] mainButton]];
			
			[self setMovieView: myMovieView];
		}
		else {
			NSLog(@"CTFKillerVideo -createAndInsertMovieView: Could not create movieView");
		}
	}
}



// Should run on main thread only as initialising QTMovie causes strange behaviour on X.5 otherwise.
// Is called from -setupQuickTimeUsingHD: only.
- (QTMovie *) movieForHD: (NSNumber *) useHDNumber {
	BOOL useHD = [self useVideoHD];
	if ( useHDNumber != nil ) {
		useHD = [useHDNumber boolValue];
	}
	
	NSURL * movieURL = [NSURL URLWithString: [self videoURLStringForHD: useHD]];
	float volumeLevel = 1.;
	NSNumber * volumeNumber = [[CTFUserDefaultsController standardUserDefaults] objectForKey: sVideoVolumeLevelDefaultsKey];
	if ( volumeNumber != nil ) {
		volumeLevel = MAX(.0 , MIN( [volumeNumber floatValue], 1.));
	}
	volumeNumber = [NSNumber numberWithFloat: volumeLevel];
	
	NSDictionary * movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
									  movieURL, QTMovieURLAttribute, 
									  [NSNumber numberWithBool:YES], QTMovieOpenAsyncOKAttribute,
									  volumeNumber, QTMovieVolumeAttribute,
									  [self title], QTMovieDisplayNameAttribute,
									  nil];
	
	NSError * error = nil;
	QTMovie * myMovie = [QTMovie movieWithAttributes:movieAttributes error:&error];

	if ( myMovie == nil ) {
		// If we get nil, just try again. This seems to cover a bunch of the random loading problems. It would probably be better to load the 'hash' or other extra info again before retrying to also cover timeout problems
		myMovie = [QTMovie movieWithAttributes:movieAttributes error:&error];
	}
	
	if (myMovie == nil){
		// It seems like we occasionally get an error "The file is not a movie file" here. No idea why as the same URL appears to work again a bit later. Some clever retrying or reasonable handling of that might be nice.
		NSLog(@"ClickToFlash CTFKillerVideo -movieForHD: Error: %@ (%@)", [error localizedDescription], [self videoURLStringForHD: useHD]);
	}	
	else {
		if ([self autoPlay]) {
			[myMovie autoplay];
		}		
	}
	
	return myMovie;	
}






#pragma mark -
#pragma mark Notifications


/*
 Called by QTMovieVolumeDidChangeNotification.
 Stores the new volume level in defaults, so future movies can use it.
*/
- (void) movieVolumeChanged: (NSNotification *) notification {
	NSNumber * volumeNumber = [NSNumber numberWithFloat:[[self movie] volume]];
	[[CTFUserDefaultsController standardUserDefaults] setObject:volumeNumber forKey: sVideoVolumeLevelDefaultsKey];
}



/*
 Called by QTMovieLoadStateDidChangeNotification.
 When movie has loaded: adjust button positions to fit into the movie's frame.
 When movie is playable: start auto-playing if required, hide progress indicator.
 When an error occurs: try refreshing the video's URL and loading again.
 
 TODO: sometimes Vimeo videos don't get us a changed load state…
       … before the film is completely loaded. Hence we cannot hide the progress indicator or autoplay.
 TODO: figure out how to handle persistent failures of video loading
*/
- (void) movieLoadStateChanged: (NSNotification *) notification {
    long loadState = [[[self movie] attributeForKey:QTMovieLoadStateAttribute] longValue];
	
#if LOGGING_ENABLED
	NSLog(@"CTFKillerVideo -movieLoadStateChanged: %i", loadState);
#endif
	
    if (loadState >= QTMovieLoadStatePlayable) {
        // The movie has loaded enough media data to begin playing. Remove the progress indicator first and then start playing, if appropriate.
		[self removeProgressIndicator];
		
		// Sometimes loading is slow and the load state keeps toggling between Playable and PlaythroughOK. This can cause the film to toggle stopping and starting many times in a row. To prevent that from happening, make sure we only autoPlay once.
		if ([self autoPlay] && ![self hasAutoPlayed] && loadState >= QTMovieLoadStatePlaythroughOK) {
			[[self movie] play];
			[self setHasAutoPlayed:YES];
		}
    }
	if (loadState >= QTMovieLoadStateLoaded) {
        // The movie atom has loaded. It's safe to query movie properties like the size now.
		[self adjustButtonPositions:YES];
		
		// Set refresh status back to NO in case a HD toggle is coming and could use a refresh again.
		hasRefreshedURLs = NO;
    }
    else if (loadState == QTMovieLoadStateError) {
		// Loading the movie failed.
		
		// Try refreshing the URL once. It may just be that the hash/token used in our URL has expired because it has been a while since we set things up.
		if ( ![self hasRefreshedURLs] ) {
			[self refreshVideoURLs];
			[self setupQuickTimeUsingHD: nil];
			[self setHasRefreshedURLs: YES];
		}
		else {
			// Refreshing the URL did not do the trick. Remove progress indicator.
			[self removeProgressIndicator];
			// It'd be nice to do something helpful here (fall back to Flash? display error message?)
			NSLog(@"CTFKillerVideo -movieLoadStateChanged: An error occurred when trying to load the movie\n%@", [[[self movie] movieAttributes] description]);
		}
    }
}



/*
 Called by QTMovieDidEndNotification.
 Shows end of movie buttons.
*/
- (void) movieDidEnd: (NSNotification *) notification {
#ifdef LOGGING_ENABLED
	NSLog(@"CTFKillerVideo QuickTime: movie did end");
#endif
	
	[self showEndOfMovieButtons];
}



/*
 Called by QTMovieTimeDidChangeNotification.
 Determines whether we are at the end of the movie and shows/hides the end of movie buttons accordingsly.
*/
- (void) movieTimeDidChange: (NSNotification *) notification {
#ifdef LOGGING_ENABLED
	NSLog(@"CTFKillerVideo QuickTime: movie time changed");
#endif

	QTMovie * const myMovie = [self movie];
	
	if ( [myMovie currentTime].timeValue == [myMovie duration].timeValue ) {
		[self showEndOfMovieButtons];
	}
	else{
		[self hideEndOfMovieButtons];
	}
}



/*
 Called by QTMovieRateDidChangeNotification.
 Hide the 'loading' progress indicator.
 It seems that the QTMovieLoadStateChanged notification is not sent reliably (occasionally happens with the movies from vimeo). This is to make sure the progress indicator is removed when the film starts playing.
*/
- (void) movieRateDidChange: (NSNotification *) notification {
#ifdef LOGGING_ENABLED
	NSLog(@"CTFKillerVideo QuickTime: movie rate changed");
#endif
	
	[self removeProgressIndicator];
	[self adjustButtonPositions:YES];
}



/*
 Fade in buttons.
 Create them when needed.
 TODO: sort out key loop?
 ... not sure we're actually having much of a key loop in the WebView
 TODO: Accessibility
 TODO: Draw translucent background behind buttons?
 TODO: Buttons don't show up when movie is in background tab at the time
 ... (it seems that our NSView's -window is nil if it is added to the containerView while in a backgroud tab. Any ideas?)
*/
- (void) showEndOfMovieButtons {
	NSView * myView = [self endOfMovieButtonsView];
	if ( myView == nil ) {
		// Create view with buttons if it doesn't exist yet.
		
		// Download button
		CTFButton * downloadButton = [CTFButton button];
		[downloadButton setTarget: self];
		[downloadButton setAction: @selector(saveMovie:)];
		NSString * buttonTitle = CtFLocalizedString(@"Save Movie", @"CTFKillerVideo QuickTime: Title of Save Movie button at end of Movie");
		NSMutableParagraphStyle * paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[paragraphStyle setAlignment: NSCenterTextAlignment];
		NSDictionary * fontStyle = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 16.0], NSFontAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
		NSAttributedString * attributedTitle = [[[NSAttributedString alloc] initWithString: buttonTitle attributes: fontStyle] autorelease];
		[downloadButton setAttributedTitle: attributedTitle];
		[downloadButton sizeToFit];
		[downloadButton setWantsLayer: YES];
		
		NSSize buttonSize = [downloadButton frame].size;
		NSRect containerRect;
		containerRect.origin = NSZeroPoint;
		containerRect.size = buttonSize;

		// Go to Video Page button
		CTFButton * gotoVideoPageButton = nil;
		
		if ( ![self isOnVideoPage] ) {
			// not on the video page -> show button to visit the video's page as well
			gotoVideoPageButton = [CTFButton button];
			[gotoVideoPageButton setTarget: self];
			[gotoVideoPageButton setAction: @selector(gotoVideoPage:)];
			buttonTitle = [NSString stringWithFormat: CtFLocalizedString(@"Go to %@ page", @"CTFKillerVideo QuickTime: Title of Go to video page button at end of Movie. %@ is the video site's name"), [self siteName]];
			attributedTitle = [[[NSAttributedString alloc] initWithString: buttonTitle attributes: fontStyle] autorelease];
			[gotoVideoPageButton setAttributedTitle: attributedTitle];
			[gotoVideoPageButton sizeToFit];
			[gotoVideoPageButton setWantsLayer: YES];
		
			// Both buttons have the same height. Make them the same width as well
			CGFloat buttonWidth = MAX(buttonSize.width, [gotoVideoPageButton frame].size.width);
			buttonSize.width = buttonWidth;
			[downloadButton setFrameSize: buttonSize];
			[gotoVideoPageButton setFrameSize: buttonSize];

			// Adjust size of containing view
			containerRect.size.width = buttonWidth;
			containerRect.size.height = 2 * containerRect.size.height + 8.0;
		}
		
		
		// Create tightly fitting view containing the button(s)
		NSView * endOfMovieButtonsContainer = [[[NSView alloc] initWithFrame: containerRect] autorelease];
		[endOfMovieButtonsContainer setAlphaValue: .0];
		[endOfMovieButtonsContainer setWantsLayer: YES];
/*		[[endOfMovieButtonsContainer layer] setBackgroundColor: CGColorCreateGenericGray(1., .7)];
		CIFilter * blurFilter = [CIFilter filterWithName: @"CIGaussianBlur"];
		[blurFilter setDefaults];
		[endOfMovieButtonsContainer setBackgroundFilters: [NSArray arrayWithObject: blurFilter]];
*/
		[endOfMovieButtonsContainer addSubview: downloadButton];
	
		if ( gotoVideoPageButton != nil ) {
			NSPoint buttonOrigin = NSMakePoint( .0, containerRect.size.height - [gotoVideoPageButton frame].size.height );
			[gotoVideoPageButton setFrameOrigin: buttonOrigin];
			[endOfMovieButtonsContainer addSubview: gotoVideoPageButton];
		}
		
		// Add the buttons view to the containerView of the plugin
		NSRect pluginFrame = [[[self plugin] containerView] frame];
		CGFloat x = (pluginFrame.size.width - containerRect.size.width) / 2.;
		CGFloat y = (pluginFrame.size.height - containerRect.size.height) / 2.;
		NSPoint buttonContainerOrigin = NSMakePoint( floor(x), floor(y) );
		[endOfMovieButtonsContainer setFrameOrigin: buttonContainerOrigin];
		[endOfMovieButtonsContainer setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
		[[[self plugin] containerView] addSubview: endOfMovieButtonsContainer];
		
		[self setEndOfMovieButtonsView: endOfMovieButtonsContainer];
		myView = endOfMovieButtonsContainer;
	}
	
	// Fade in
	[[myView animator] setAlphaValue: 1.];
}



/*
 Fade out the button(s).
 Do this a bit more quickly than the default to not get in people's way in case they want to re-watch part of the movie.
 Does horrible stuff to avoid linking to CoreAnimation libraries.
*/
- (void) hideEndOfMovieButtons {
	NSView * view = [self endOfMovieButtonsView];
	if ( view != nil && [view alphaValue] != .0) {
		// Create class object from string so we don't have to link to Core Quartz Core
		Class CAT = NSClassFromString(@"CATransaction");
		[CAT begin];
		// BAD: makes kCATransactionAnimationDuration explicit because we don't have the symbolic constant
		[CAT setValue: [NSNumber numberWithFloat:.05] forKey:@"animationDuration"];
		[[view animator] setAlphaValue: .0];
		[CAT commit];
	}
}





/*
 Save our loaded movie (includes a whacky workaround for slightly incompatible videos as found on vimeo).
 Try to figure out the downloads folder and use that as the location.
 If we know the video's name, use that as the file name.
 Otherwise use the video site's name in the file name.
 Make sure file names are unique.
*/
- (IBAction) saveMovie: (id) sender {
	QTMovie * const myMovie = [self movie];
	
	NSAssert( myMovie != nil, @"CTFKillerVideo-QT -saveMovie called even though movie == nil");
	long loadState = [[myMovie attributeForKey:QTMovieLoadStateAttribute] longValue];
	
	NSAssert( loadState == QTMovieLoadStateComplete, @"CTFKillerVideo-QT -saveMovie called even though the movie is not loaded completely");
	
	NSString * destinationPath = [self pathForSavingMovie];
	if (destinationPath != nil) {
		NSError * error = nil;
		NSDictionary * saveAttributes = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: YES], QTMovieFlatten, nil];
		BOOL saveSuccessful = [myMovie writeToFile: destinationPath withAttributes: saveAttributes error: &error];
		
		// Careful: whacky code which tries to work around a save problem by removing a frame from the movie.
		if ( !saveSuccessful && error ) {
			// Check whether we are in a 'vimeo-type' situation which gives a -2015 "The movie contains an incorrect time value." error when saving. In that case, trimming a frame from the film's beginning seems to fix things.
			if ( [error code] == -2015 ) {
				// Find out frame rate. It is stored in movie -> video track -> media -> QTMediaTimeScaleAttribute and has to be divided by 1000.
				NSArray * videoTracks = [myMovie tracksOfMediaType: QTMediaTypeVideo];
				if ( [videoTracks count] > 0 ) {
					QTTrack * track = [videoTracks objectAtIndex: 0];
					QTMedia * media = [track media];
					NSNumber * timeScale = [media attributeForKey: QTMediaTimeScaleAttribute];
					if (timeScale) {
						// use a length of 1.5 frames as 1 frame doesn't seem to do the trick (perhaps some rounding problem?)
						CGFloat length = 1500. / [timeScale floatValue];
						QTTimeRange timeRange = QTMakeTimeRange(QTMakeTimeWithTimeInterval(0), QTMakeTimeWithTimeInterval(length));
						
						// Need to make movie editable before removing frame.
						[myMovie setAttribute: [NSNumber numberWithBool:YES] forKey: QTMovieEditableAttribute];
						[myMovie deleteSegment: timeRange];
						
						saveSuccessful = [myMovie writeToFile: destinationPath withAttributes: saveAttributes error: &error];
					}
				}
			}
		}
		
		if (saveSuccessful) {
			// saved successfully, add extended attribute with URL of video page
			if ( [self videoPageURLString] != nil ) {
				NSString * errorDescription = nil;
				NSData * xAttrPlistData = [NSPropertyListSerialization dataFromPropertyList: [self videoPageURLString] format:NSPropertyListBinaryFormat_v1_0 errorDescription: &errorDescription];
				if ( errorDescription != nil) {
					NSLog(@"ClickToFlash: could not convert string for extended attributes when saving movie file: %@", errorDescription);
					[errorDescription release];
				}
				
				int result = setxattr( [destinationPath fileSystemRepresentation],
									  "com.apple.metadata:kMDItemWhereFroms",
									  [xAttrPlistData bytes],
									  [xAttrPlistData length],
									  0, 0);
				if (result == -1) {
					NSLog(@"ClickToFlash: could not write extended attributes when saving movie file: %i", errno);
				}
			}
		}
		else{
			// couldn't save file, sort-of handle errors
			if (error != nil) {
				NSString * errorDescription = CtFLocalizedString(@"ClickToFlash could not save the movie file.", @"CTFKillerVideo QuickTime: Could not save movie QuickTime error");
				NSString * recoverySuggestion = [NSString stringWithFormat:CtFLocalizedString(@"QuickTime reported the error '%@' (%i) while trying to save the file.\nYou can try re-downloading the movie without QuickTime.", @"CTFKillerVideo QuickTime: Could not save movie QuickTime error recovery suggestion."), [error localizedDescription], [error code]];
				NSArray * recoveryOptions = [NSArray arrayWithObjects: CtFLocalizedString(@"Re-download without QuickTime", @"CTFKillerVideo QuickTime: Could not save movie QuickTime error recovery option 0: Re-download without QuickTime"), CtFLocalizedString(@"Cancel", @"Cancel"), nil];
				
				NSDictionary * errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											errorDescription, NSLocalizedDescriptionKey,
											recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
											error, NSUnderlyingErrorKey,
											recoveryOptions, NSLocalizedRecoveryOptionsErrorKey,
											self, NSRecoveryAttempterErrorKey,
											nil];
				
				NSError * myError = [NSError errorWithDomain:@"ClickToFlashErrorDomain" code:[error code] userInfo:errorInfo];
				[[self plugin] presentError: myError];
				NSLog(@"ClickToFlash failed to Save the movie with error: %@", [error description]);
			}
		}
	}
	else {
		NSLog(@"ClickToFlash: Could not save the movie because we couldn't figure out a good file name. This should not happen.");
	}
}



/*
 For NSErrorRecoveryAttempting Protocol.
 Only used for movie saving error at the moment.
 Options are:
    0 -> Download without QuickTime
    1 -> Cancel
*/
- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex {
	BOOL result = NO;
	if ( recoveryOptionIndex == 0 ) {
		[self downloadVideo: nil];
		result = YES;
	}
	return result;
}







#pragma mark -
#pragma mark Helpers

// Adds the progress indicator shown used while loading the video
- (void) addProgressIndicator {
	// We only want a single progress indicator, so make sure we don't create a new one in case it already exists.
	if ([self progressIndicator] == nil) {
		const CGFloat pISize = 32.;
		
		NSRect pIRect = NSMakeRect(NSMidX([[self plugin] bounds]) - pISize*.5,
								   NSMidY([[self plugin] bounds]) - pISize*.5,
								   pISize,
								   pISize);
		
		NSProgressIndicator * theProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:pIRect];
		[self setProgressIndicator: theProgressIndicator];
		
		[theProgressIndicator setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
		[theProgressIndicator setStyle: NSProgressIndicatorSpinningStyle];
		[theProgressIndicator setWantsLayer: YES];
		
		[theProgressIndicator startAnimation: self];
		[[[self plugin] containerView] addSubview:theProgressIndicator];
	}
}



// Removes the progress indicator shown while loading the video.
- (void) removeProgressIndicator {
	if ([self progressIndicator]) {
		[[self progressIndicator] stopAnimation: self];
		[progressIndicator removeFromSuperview];
		[self setProgressIndicator: nil];
	}
}



/* 
 Move the buttons container around if necessary.  
 We want:
 * standard display behaviour before the film is loaded
 * The buttons container to be full width at the top of the screen in fullscreen mode 
 * The buttons container fitting into the bounds of the displayed movie when the movie view is present
*/
- (void) adjustButtonPositions:(BOOL) smoothly {
	NSRect movieRect;
	
	if ([self movieView]) {
		if ([[self plugin] isFullScreen]) {
			movieRect = [[[[self plugin] window] screen] frame];
		}
		else {
			movieRect = [[self movieView] movieBounds];
			movieRect.size.height += [[self movieView] controllerBarHeight];
			movieRect.origin.y -= [[self movieView] controllerBarHeight];		
		}
		
		if (smoothly && (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_5)) {
			[[[[self plugin] buttonsContainer] animator] setFrame: movieRect];
		}
		else {
			[[[self plugin] buttonsContainer] setFrame: movieRect];
		}
	}
}



// Adds button to toggle between the SD and HD version of a film.
// Only appears when two versions are available and serves as an indicator for the currently playing version.
- (NSButton *) addHDButton {
	NSButton * button = nil;
	
	if ([self hasVideo] && [self hasVideoHD]) {
		button = [[[self plugin] buttonsView] viewWithTag: CTFHDButtonTag];
		if (button == nil) {
			NSCellStateValue state = NSOnState;
			if ( ![self useVideoHD] ) { state = NSOffState; }
			[self setUsingHD: state];
			
			button = [CTFButton button];
			[button setTitle: CtFLocalizedString( @"HD", @"CTFKillerVideo: Label for HD button")];
			[button sizeToFit];
			[button setButtonType: NSPushOnPushOffButton];
			[button setTag: CTFHDButtonTag];
			[button setTarget: self];
			[button setAction: @selector(toggleHD:)];
			[[[self plugin] buttonsView] addButton: button];
			[button bind:@"toolTip" toObject:self withKeyPath:@"HDButtonTooltip" options:nil];
			[button bind:@"value" toObject:self withKeyPath:@"usingHD" options:nil];
		}
	}	
	return button;
}



// Used for tooltip in HD button via bindings
- (NSString *) HDButtonTooltip {
	NSString * tooltip = @"";
	
	if ([self usingHD] == NSOnState) {
		tooltip = CtFLocalizedString( @"Use smaller version of the movie", @"CTFKillerVideo: Tooltip for HD button when it is turned ON" );
	}
	else {
		tooltip = CtFLocalizedString( @"Use larger version of the movie", @"CTFKillerVideo: Tooltip for HD button when it is turned OFF" );	
	}
	
	return tooltip;
}



// called from the -setVideo: and -setVideoHD: setters
- (void) addButtons {
	[[self plugin] addFullScreenButton];
	[self addHDButton];
}



- (IBAction) toggleHD: (id) sender {
	[self setupQuickTimeUsingHD: [NSNumber numberWithBool: [self usingHD]]];
}



// TODO: figure out how to resize ourselves well
// If someone can figure out how we can resize our view to fully fill the width of the containing DOM element and setting the height of said element while remaining flexibe (i.e. just like using width:100%; in CSS), please speak up. 
/*
// Resize the plugin view to keep its width and have the aspect ratio of the movie
- (void) resizeToFitMovie {
	if ( [self movie] != nil && [self movieView] != nil ) {
		CGFloat movieAspectRatio = [[self movieView] movieBounds].size.width / [[self movieView] movieBounds].size.height;
		CGFloat newWidth = [[self plugin] frame].size.width;
		CGFloat newHeight = newWidth / movieAspectRatio + [[self movieView] controllerBarHeight];
		[[[self plugin] animator] setFrameSize: NSMakeSize(newWidth,newHeight)];
		[[self plugin] setNeedsDisplay:YES];
		// DOMCSSStyleDeclaration * style = [[[self plugin] container] style];
		//[style setProperty:@"height" value:@"auto" priority:nil];	
		// [style setProperty:@"width" value:@"100%" priority:nil];
	}
}
*/



/*
 Returns a string that is a path for saving the Movie at.
 Location: Uses the System's Downloads folder (X.5 and higher only) for that.
 File Name: Uses video title if available, removes leading dots, replaces / by -, and truncates if necessary.
			Otherwise falls back to using a name with the video site title in it.
*/
- (NSString *) pathForSavingMovie {
	NSString * destinationPath = nil;
	
	if ( [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask ) {
		// Display a save dialogue when the option key is held
		NSSavePanel * savePanel = [NSSavePanel savePanel];
		if ( [savePanel runModal] == NSFileHandlingPanelOKButton ) {
			destinationPath = [[savePanel URL] path];
		}
	}
	else {
		NSArray * searchPaths = NSSearchPathForDirectoriesInDomains( NSDownloadsDirectory, NSUserDomainMask, YES );
		if ( [searchPaths count] > 0 ) {
			NSString * basePath = [searchPaths objectAtIndex: 0];
			NSString * fileName = [self title];
			
			// probably slashes in the file name are a bad idea as we're working with Unix-Style paths rather than reasonable file references
			fileName = [fileName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
			// remove dots from beginning of file name to avoid ivisibility
			while ([fileName rangeOfString:@"." options: NSAnchoredSearch|NSLiteralSearch].location != NSNotFound) {
				if ( [fileName length] > 1 ) {
					fileName = [fileName substringFromIndex:1];
				}
				else {
					fileName = @"";
				}
			}
			
			if ( [fileName length] > 50 ) {
				// cut off long file names
				fileName = [[fileName substringToIndex: 40] stringByAppendingString: NSLocalizedString(@"...", @"ellipsis")];
			}
			
			if ( fileName == nil || [fileName length] == 0) {
				fileName = [NSString stringWithFormat: CtFLocalizedString(@"%@ Video", @"CTFKillerVideo QuickTime: default file name for saved movie. %@ will be the name of the video site"), [self siteName]];
			}
			
			
			// NSString * fileNameExtension = @"";
			NSString * fullName = fileName; //[videoTitle stringByAppendingPathExtension: fileNameExtension];
			destinationPath = [basePath stringByAppendingPathComponent: fullName];
			
			unsigned i = 2;
			const unsigned maximumNumber = 10000;
			// make sure we have a unique name
			while ([[NSFileManager defaultManager] fileExistsAtPath: destinationPath] && i < maximumNumber) {
				fullName = [fileName stringByAppendingFormat:@"-%u", i++]; // if one used file name extensions, the format would need to be adapted
				destinationPath = [basePath stringByAppendingPathComponent: fullName];
			}
			if ( i == maximumNumber) { // yeah right, we totally need this!
				NSLog(@"ClickToFlash: could not determine video file name because all the file names I want are already used");
				destinationPath = nil;
			}
		}
	}
	
	return destinationPath;
}







#pragma mark -
#pragma mark Accessors

- (BOOL)hasAutoPlayed {
	return hasAutoPlayed;
}

- (void)setHasAutoPlayed:(BOOL)newHasAutoPlayed {
	hasAutoPlayed = newHasAutoPlayed;
}


- (NSCellStateValue) usingHD {
	return usingHD;
}

- (void) setUsingHD:(NSCellStateValue)newUsingHD {
	usingHD = newUsingHD;
}


- (NSProgressIndicator *) progressIndicator {
	return progressIndicator;
}

- (void) setProgressIndicator: (NSProgressIndicator *) newProgressIndicator {
	[newProgressIndicator retain];
	[progressIndicator release];
	progressIndicator = newProgressIndicator;
}


- (QTMovieView *) movieView {
	return movieView;
}

- (void) setMovieView: (QTMovieView *) newMovieView {
	[newMovieView retain];
	[movieView release];
	movieView = newMovieView;
}


- (QTMovie *) movie {
	return movie;
}

- (void) setMovie: (QTMovie *) newMovie {
	if (newMovie != nil) {
		[newMovie retain];

		// track volume changes, so we can store them in defaults
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieVolumeChanged:) name:QTMovieVolumeDidChangeNotification object:newMovie];
		// track load state, so we can resize the UI and remove the progress indicator ASAP
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieLoadStateChanged:) name:QTMovieLoadStateDidChangeNotification object:newMovie];
		// track playback end and manual position changes, so we can show/hide the end of movie buttons
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieDidEnd:) name:QTMovieDidEndNotification object:newMovie];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieTimeDidChange:) name:QTMovieTimeDidChangeNotification object:newMovie];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieRateDidChange:) name:QTMovieRateDidChangeNotification object:newMovie];
	}
	
	if (movie != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:movie];
		[movie stop];
		[movie release];
	}
	
	movie = newMovie;
}


- (NSView *) endOfMovieButtonsView {
	return endOfMovieButtonsView;
}

- (void) setEndOfMovieButtonsView: (NSView *) newEndOfMovieButtonsView {
	[newEndOfMovieButtonsView retain];
	[endOfMovieButtonsView release];
	endOfMovieButtonsView = newEndOfMovieButtonsView;
}


@end
