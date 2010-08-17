/*
 
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

#import "CTFMainButton.h"
#import "CTFGradient.h"
#import "Plugin.h"
#import "CTFUtilities.h"
#import "NSBezierPath-RoundedRectangle.h"
// #import "NSBezierPath+ESPoints.h"


@implementation CTFMainButton

#pragma mark NSButton subclassing

+ (Class) cellClass {
	return NSClassFromString(@"CTFMainButtonCell");
}


- (BOOL) isFlipped {
	return NO;
}


- (NSMenu*) menuForEvent: (NSEvent*) event {
	return [[self plugin] menuForEvent: event];
}




#pragma mark Accessors

- (CTFClickToFlashPlugin *) plugin {
	return plugin;
}

- (void) setPlugin: (CTFClickToFlashPlugin *) newPlugin {
	[newPlugin retain];
	[plugin release];
	plugin = newPlugin;
}


@end






#pragma mark -

@implementation CTFMainButtonCell


#pragma mark NSCell subclassing

- (void) drawWithFrame: (NSRect) rect inView:(NSView *) controlView {
	NSRect bounds = [[self controlView] bounds];
	NSRect fillRect = NSInsetRect(bounds, 1.0, 1.0);
    
	[self drawGradientInRect: fillRect];
	[self drawPreviewInRect: fillRect];
	
    // Draw border
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.50] set];
    [NSBezierPath setDefaultLineWidth:2.0];
    [NSBezierPath setDefaultLineCapStyle:NSSquareLineCapStyle];
    [[NSBezierPath bezierPathWithRect:bounds] stroke];
	
	// Draw 'glossy' overlay which can give some visual feedback on clicks when an preview image is set.
	if ([[self plugin] previewImage] != nil) {
		[self drawGlossForBounds3: bounds];		
	}
	
    // Draw label
    [self drawBadgeForBounds: bounds];	
}





#pragma mark Drawing

- (void) drawGradientInRect: (NSRect) rect {
    NSColor *startingColor = [NSColor colorWithDeviceWhite: 1.0 alpha: 0.15];
    NSColor *endingColor = [NSColor colorWithDeviceWhite: 0.0 alpha: 0.15];
	
    // When the view is 'On', use a convex look: draw the gradient downwards (90+180=270 degrees).
    // When the view is 'Off' use a concave look: draw the gradient upwards (90 degrees).
	CGFloat angle;
	if ( [self isHighlighted] ) {
		angle = 90.;
	}
	else {
		angle = 270.;
	}
	
	NSBezierPath * rectPath = [NSBezierPath bezierPathWithRect:rect];
	id gradient = [NSClassFromString(@"NSGradient") alloc];
	
	if (gradient != nil) {
        gradient = [gradient initWithStartingColor:startingColor endingColor:endingColor];
        [gradient drawInBezierPath:rectPath angle:angle];
		
        [gradient release];
    }
    else {
		//tweak the opacity of the endingColor for compatibility with CTGradient
		endingColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.00];
		
		gradient = [CTFGradient gradientWithBeginningColor:startingColor endingColor:endingColor];
		
		//angle is reversed compared to NSGradient
		[gradient fillBezierPath:rectPath angle:-angle];
	}
}



- (void) drawPreviewInRect: (NSRect) rect {
	// Overlay the preview image if there is one
	NSImage * image = [[self plugin] previewImage];

	if ( image != nil ) {
		// Determine the destination rect. The approach is to scale the preview image until it fills the view horizontally. This risks losing pixels at the top and bottom but seems to match what the sites providing preview images do for widescreen movies, thus giving better results than 'clean' scaling to fit the whole image inside the view.
		NSRect destinationRect;
		NSSize imageSize = [image size];
		CGFloat scale = rect.size.width / imageSize.width;
		CGFloat destinationWidth = imageSize.width * scale;
		CGFloat destinationHeight = imageSize.height * scale;
		CGFloat destinationBottom = rect.origin.y + ( rect.size.height - destinationHeight) / 2.0;
		
		destinationRect = NSMakeRect(rect.origin.x, destinationBottom, destinationWidth, destinationHeight);
		
		[image drawInRect:destinationRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction: 1.0];
	}
}




- (NSString*) badgeLabelText {
	NSString * labelText = nil;
	CTFKiller * killer = [[self plugin] killer];
	
	
	if (killer != nil) {
		labelText = [killer badgeLabelText];
	}
	
	if (labelText == nil) {
		labelText = CtFLocalizedString( @"Flash", @"Flash badge text" );
	}
	
	return labelText;
}



- (void) drawBadgeForBounds: (NSRect) bounds {	
	// What and how are we going to draw?
	const float kFrameXInset = 10;
	const float kFrameYInset =  4;
	const float kMinMargin   = 11;
	const float kMinHeight   =  6;
	
	NSString* str = [ self badgeLabelText ];
	
	NSShadow *superAwesomeShadow = [[NSShadow alloc] init];
	// NSShadow offsets differ by a pixel between X.5 and X.6
	if ( floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5 ) {
		[superAwesomeShadow setShadowOffset: NSMakeSize(1., -1.)];
	}
	else {
		[superAwesomeShadow setShadowOffset: NSMakeSize(2., -2.)];
	}
	[superAwesomeShadow setShadowColor:[NSColor whiteColor]];
	[superAwesomeShadow autorelease];
	NSDictionary* attrs = [ NSDictionary dictionaryWithObjectsAndKeys: 
						   [ NSFont boldSystemFontOfSize: 20 ], NSFontAttributeName,
						   [ NSNumber numberWithInt: -1 ], NSKernAttributeName,
						   [ NSColor blackColor ], NSForegroundColorAttributeName,
						   superAwesomeShadow, NSShadowAttributeName,
						   nil ];
	
	// How large would this text be?
	
	NSSize strSize = [ str sizeWithAttributes: attrs ];
	
	float w = strSize.width  + kFrameXInset * 2;
	float h = strSize.height + kFrameYInset * 2;
	
	// Compute a scale factor based on the view's size.
	
	float maxW = NSWidth( bounds ) - kMinMargin;
	float maxH = NSHeight( bounds ) - kMinMargin;
	float minW = kMinHeight * w / h;
	
	BOOL rotate = NO;
	if( maxW <= minW )	// too narrow in width, so rotate it
		rotate = YES;
	
	if( rotate ) {		// swap the dimensions to scale into
		float temp = maxW;
		maxW = maxH;
		maxH = temp;
	}
	
	if( maxH <= kMinHeight ) {
		// Too short in height for full margin.
		
		// Draw at the smallest size, with less margin,
		// unless even that would get clipped off.
		
		if( maxH + kMinMargin < kMinHeight )
			return;
        
		maxH = kMinHeight;
	}
	
	float scaleFactor = 1.0;
	
	if( maxW < w )
		scaleFactor = maxW / w;
    
	if( maxH < h && maxH / h < scaleFactor )
		scaleFactor = maxH / h;
	
	// Apply the scale, and a transform so the result is centered in the view.
	
	[ NSGraphicsContext saveGraphicsState ];
    
	NSAffineTransform* xform = [ NSAffineTransform transform ];
	[ xform translateXBy: NSWidth( bounds ) / 2 yBy: NSHeight( bounds ) / 2 ];
    
	[ xform scaleBy: scaleFactor ];
	if( rotate )
		[ xform rotateByDegrees: 90 ];
	[ xform concat ];
	
    CGContextRef context = [ [ NSGraphicsContext currentContext ] graphicsPort ];
    
	CGFloat opacity = [[(CTFMainButton *)[self controlView] plugin] overlayOpacityHighlighted: [self isHighlighted]];
	
	CGContextSetAlpha( context, opacity );
	CGContextBeginTransparencyLayer( context, nil );
	
	// Draw everything at full size, centered on the origin.
	
	NSPoint loc = { -strSize.width / 2, -strSize.height / 2 };
	NSRect borderRect = NSMakeRect( loc.x - kFrameXInset, loc.y - kFrameYInset, w, h );
	
    NSBezierPath* fillPath = bezierPathWithRoundedRectCornerRadius( borderRect, 4 );
    [ [ NSColor colorWithCalibratedWhite: 1.0 alpha: 1. ] set ];
    [ fillPath fill ];
    
    NSBezierPath* darkBorderPath = bezierPathWithRoundedRectCornerRadius( borderRect, 4 );
    [[NSColor blackColor] set];
    [ darkBorderPath setLineWidth: 3 ];
    [ darkBorderPath stroke ];
    
    NSBezierPath* lightBorderPath = bezierPathWithRoundedRectCornerRadius( NSInsetRect(borderRect, -2, -2), 6 );
    [ [ NSColor colorWithCalibratedWhite: 1.0 alpha: 1. ] set ];
    [ lightBorderPath setLineWidth: 2 ];
    [ lightBorderPath stroke ];
    
    [ str drawAtPoint: loc withAttributes: attrs ];
	
	// Now restore the graphics state:
	CGContextEndTransparencyLayer( context );
    [NSGraphicsContext restoreGraphicsState ];
}



// First attempt to add an S-shaped gloss.
- (void) drawGlossForBounds: (NSRect) bounds {
	NSBezierPath * bP = [NSBezierPath bezierPath];
	const CGFloat glowStartFraction = .3;
	const CGFloat cP1YFraction = .5;
	const CGFloat cP2XFraction = .0;
	const CGFloat cP2YFraction = .48;
	
	CGFloat startY = .0;
	if ([self isHighlighted]) {
		startY = NSMaxY(bounds);
	}
	
	[bP moveToPoint: NSMakePoint( .0, startY ) ];
	[bP lineToPoint: NSMakePoint( .0, NSMaxY(bounds) * glowStartFraction )];
	[bP curveToPoint: NSMakePoint( NSMidX(bounds), NSMidY(bounds) )
	   controlPoint1: NSMakePoint( .0 , cP1YFraction * NSMaxY(bounds))
	   controlPoint2: NSMakePoint( cP2XFraction * NSMaxX(bounds), cP2YFraction * NSMaxY(bounds)) ];
	[bP curveToPoint: NSMakePoint( NSMaxX(bounds), (1. - glowStartFraction) * NSMaxY(bounds) )
	   controlPoint1: NSMakePoint( (1. - cP2XFraction) * NSMaxX(bounds) , (1. - cP2YFraction) * NSMaxY(bounds) ) 
	   controlPoint2: NSMakePoint( NSMaxX(bounds), (1. - cP1YFraction) * NSMaxY(bounds) ) ];
	[bP lineToPoint: NSMakePoint( NSMaxX(bounds), startY ) ];
	[bP closePath];
	
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.07] set];
	[bP fill];
}



// More glossy gloss. Thanks to Henrik Cederblad for the recommendations on how to do this.
- (void) drawGlossForBounds2: (NSRect) bounds {
	const CGFloat glowStartFraction = .46;
	const CGFloat cP1XFraction = .3;
	const CGFloat cP1YFraction = .5;
	const CGFloat cP2XFraction = .4;
	const CGFloat cP2YFraction = .5;
	
	CGFloat startY = .0;
	CGFloat gradientRotation = 180.;
	if ([self isHighlighted]) {
		startY = NSMaxY(bounds);
		gradientRotation = .0;
	}
	
	NSBezierPath * bP = [NSBezierPath bezierPath];
	[bP moveToPoint: NSMakePoint( .0, startY ) ];
	[bP lineToPoint: NSMakePoint( .0, NSMaxY(bounds) * glowStartFraction )];
	[bP curveToPoint: NSMakePoint( NSMidX(bounds), NSMidY(bounds) )
	   controlPoint1: NSMakePoint( cP1XFraction * NSMaxX(bounds), cP1YFraction * NSMaxY(bounds))
	   controlPoint2: NSMakePoint( cP2XFraction * NSMaxX(bounds), cP2YFraction * NSMaxY(bounds)) ];
	[bP curveToPoint: NSMakePoint( NSMaxX(bounds), glowStartFraction * NSMaxY(bounds) )
	   controlPoint1: NSMakePoint( (1. - cP2XFraction) * NSMaxX(bounds), (cP2YFraction) * NSMaxY(bounds) ) 
	   controlPoint2: NSMakePoint( (1. - cP1XFraction) * NSMaxX(bounds), (cP1YFraction) * NSMaxY(bounds) ) ];
	[bP lineToPoint: NSMakePoint( NSMaxX(bounds), startY ) ];
	[bP closePath];
	
//	[bP drawPointsAndHandles];
	
	NSColor * startColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.2];
	NSColor * endColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.00];

	id gradient = [NSClassFromString(@"NSGradient") alloc];
	if ( gradient != nil ) {
		gradient = [[gradient initWithColorsAndLocations: startColor, .0, endColor, .8, nil] autorelease];
		[gradient drawInBezierPath: bP angle: 90. + gradientRotation];
	}
	else {
		gradient = [CTFGradient gradientWithBeginningColor:startColor endingColor:endColor];
		[(CTFGradient*)gradient addColorStop: endColor atPosition: .8];
		[(CTFGradient*)gradient fillBezierPath: bP angle: -(90. + gradientRotation)];
	}
}







// More glossy gloss. Thanks to Henrik Cederblad for the recommendations on how to do this.
- (void) drawGlossForBounds3: (NSRect) bounds {
	const CGFloat glowStartFraction = .7;
	const CGFloat cP1XFraction = .0;
	const CGFloat cP2XFraction = .35;
	const CGFloat middleY = NSMidY(bounds) - 8.;
	
	CGFloat startY = bounds.size.height;
	CGFloat gradientRotation = .0;
	
	NSBezierPath * bP = [NSBezierPath bezierPath];
	[bP moveToPoint: NSMakePoint( .0, startY ) ];
	[bP lineToPoint: NSMakePoint( .0, NSMaxY(bounds) * glowStartFraction )];
	[bP curveToPoint: NSMakePoint( NSMidX(bounds), middleY )
	   controlPoint1: NSMakePoint( cP1XFraction * NSMaxX(bounds), middleY)
	   controlPoint2: NSMakePoint( cP2XFraction * NSMaxX(bounds), middleY) ];
	[bP curveToPoint: NSMakePoint( NSMaxX(bounds), glowStartFraction * NSMaxY(bounds) )
	   controlPoint1: NSMakePoint( (1. - cP2XFraction) * NSMaxX(bounds), middleY ) 
	   controlPoint2: NSMakePoint( (1. - cP1XFraction) * NSMaxX(bounds), middleY ) ];
	[bP lineToPoint: NSMakePoint( NSMaxX(bounds), startY ) ];
	[bP closePath];
	
//	[bP drawPointsAndHandles];
	
	NSColor * startColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.5];
	NSColor * endColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.00];
	if ([self isHighlighted]) {
		startColor = [NSColor colorWithCalibratedWhite:1. alpha:0.7];
		endColor = [NSColor colorWithCalibratedWhite:1. alpha:0.1];
	}
	
	id gradient = [NSClassFromString(@"NSGradient") alloc];
	if ( gradient != nil ) {
		gradient = [[gradient initWithColorsAndLocations: startColor, .0, endColor, 1., nil] autorelease];
		[gradient drawInBezierPath: bP angle: 90. + gradientRotation];
	}
	else {
		gradient = [CTFGradient gradientWithBeginningColor: startColor endingColor: endColor];
		[(CTFGradient*)gradient fillBezierPath: bP angle: -(90. + gradientRotation)];
	}
}






#pragma mark Helper

- (CTFClickToFlashPlugin*) plugin {
	CTFMainButton * button = (CTFMainButton*) [self controlView];
	CTFClickToFlashPlugin * myPlugin = [button plugin];
	return myPlugin;
}






#pragma mark Accessibility

/*
 Say that we provide and AXTitle and AXDescription.
*/
- (NSArray *) accessibilityAttributeNames {
	NSMutableArray * attributes = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	[attributes addObject: NSAccessibilityTitleAttribute];
	[attributes addObject: NSAccessibilityDescriptionAttribute];
	return attributes;
}



/*
 Provide values for accessibility attributes.
 AXTitle -> badge label
 AXDescription -> Load Flash Content
 AXParent -> The plug-in's containerView
*/
- (id) accessibilityAttributeValue: (NSString *) attribute {
	id value = nil;
	
	if ( [attribute isEqualToString: NSAccessibilityTitleAttribute] ) {
		value = [self badgeLabelText];
	}
	else if ( [attribute isEqualToString: NSAccessibilityDescriptionAttribute] ) {
		value = CtFLocalizedString( @"Load Flash Content", @"NSAccessibilityDescriptionAttribute for CTFMainButton");
	}
	else if ( [attribute isEqualToString: NSAccessibilityParentAttribute] ){
		value = NSAccessibilityUnignoredAncestor([[(id)[self controlView] plugin] containerView]);
	}
	else {
		value =  [super accessibilityAttributeValue:attribute];
	}
	
	return value;
}



/*
 Advertise our Actions:
 -> AXPress: normal clicking of button
 -> AXShowMenu: view's contextual menu
*/
- (NSArray *) accessibilityActionNames {
	NSArray * actionNames = [NSArray arrayWithObjects: 
							 NSAccessibilityPressAction, 
							 NSAccessibilityShowMenuAction, 
							 nil];
	return actionNames;
}
 
 

@end
