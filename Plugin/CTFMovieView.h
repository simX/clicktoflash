//
//  CTFMovieView.h
//  ClickToFlash
//
//  Created by  Sven on 31.03.10.
//  Copyright 2010 earthlingsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>



/*
 QTMovieView Subclass with slightly different scroll wheel behaviour:
 
 When the movie is at the very beginning or end, grab the scroll wheel events  and forward them to the superview.
 This makes pages (mostly) scrollable even when the mouse happens to be above a film during scrolling without fully destroying the in-movie scroll wheel usage.

 Unfortunately QTMovieView's and WebKit's sense of scrolling direction are opposed:
    QTMovieView: scroll down -> reverse film
    WebKit: scroll down -> scroll down
*/


@interface CTFMovieView : QTMovieView {

}



- (BOOL) canScrubWithEvent: (NSEvent *) theEvent;


@end
