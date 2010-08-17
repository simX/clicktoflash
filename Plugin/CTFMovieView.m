//
//  CTFMovieView.m
//  ClickToFlash
//
//  Created by  Sven on 31.03.10.
//  Copyright 2010 earthlingsoft. All rights reserved.
//

#import "CTFMovieView.h"


@implementation CTFMovieView


// if we cannot scrub, pass the scroll event on to the superview
- (void) scrollWheel: (NSEvent *) theEvent {
	if ( [self canScrubWithEvent: theEvent] ) {
		[super scrollWheel: theEvent];
	}
	else {
		[[self superview] scrollWheel: theEvent];
	}
}



- (BOOL) canScrubWithEvent: (NSEvent *) theEvent {
	BOOL canScrub = YES;
	QTMovie * myMovie = [self movie];
	
	if ( myMovie != nil ) {		
		if ( QTTimeCompare([myMovie currentTime], [myMovie duration]) == NSOrderedSame  ||
			 [myMovie currentTime].timeValue == 0 ) {
			// at the beginning or end of the film: do not scrub but go scrolling
			if ( [theEvent type] == NSScrollWheel && [theEvent deltaY] != 0 ) {
				canScrub = NO;
			}
		}
	}
	else {
		canScrub = NO;
	}
	
	return canScrub;
}



@end
