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

#import "CTFActionButton.h"
#import "CTFUtilities.h"
#import "Plugin.h"


@implementation CTFActionButton

+ (id) actionButton {
	CGFloat margin = 5.;
	CGFloat size = 20.;
	NSRect gearButtonRect = NSMakeRect( .0, .0, size + 2.*margin , size + 2.*margin );

	CTFActionButton * gearButton = [[[CTFActionButton alloc] initWithFrame: gearButtonRect] autorelease];
	[gearButton setPullsDown: YES];
	
	return gearButton;
}




#pragma mark -
#pragma mark Subclassing

/*
 Return and use our own NSPopupButtonCell subclass.
 Overriding NSButton.
*/
+ (Class) cellClass {
	return [CTFActionButtonCell class];
}



- (id) initWithFrame: (NSRect) frameRect {
	self = [super initWithFrame: frameRect];
	if (self != nil) {
		[self setPlugin: nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillPopup:) name:NSPopUpButtonWillPopUpNotification object:self ];
	}
	return self;
}



- (void) dealloc {
	[self setPlugin: nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}



/*
 Automatically Show/Hide ourselves depending on whether the plugin is large enough for us.
 Overriding NSView.
*/
- (void) resizeWithOldSuperviewSize:(NSSize) oldBoundsSize {
	if ( [[self cell] gearVisible] && ![[self plugin] isFullScreen]) {
		[self setHidden:NO];
		NSRect myRect = [self bounds];
		NSSize superSize = [[self superview] bounds].size;
		NSPoint	newOrigin = NSMakePoint(.0, superSize.height - myRect.size.height);
		[self setFrameOrigin: newOrigin];
	}
	else {
		[self setHidden:YES];
	}
}



/*
 Ignore clicks while in the background.
 Overriding NSView.
*/
- (BOOL) acceptsFirstMouse:(NSEvent*) theEvent {
	return NO;
}





#pragma mark -
#pragma mark Notification

/*
 Called by NSPopUpButtonWillPopUpNotification.
 Sets up the menu on-the-fly.
*/
- (void) menuWillPopup: (NSNotification *) notification {
	[self setMenu: [[self plugin] menuForEvent: [NSApp currentEvent]]];
}


	



#pragma mark -
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

@implementation CTFActionButtonCell

#pragma mark NSCell subclassing

- (void) drawWithFrame: (NSRect) rect inView:(NSView *) controlView {
	NSRect bounds = [[self controlView] bounds];
			
	NSImage * gearImage = [NSImage imageNamed:@"NSActionTemplate"];
	// On systems older than 10.5 we need to supply our own image.
	if (gearImage == nil) {
		NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"NSActionTemplate" ofType:@"png"];
		gearImage = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	}
			
	if( gearImage ) {
		const CGFloat padding = 3.;
		CGFloat gearSize = [gearImage size].width; // assumes the gear to be square
		CGFloat size = gearSize + 2.0 * padding;
		CGFloat x = round(bounds.size.width * .5) - round(size * .5);
		CGFloat y = round(bounds.size.height * .5 ) - round(size * .5);										
		NSRect backgroundFrame = NSMakeRect(x, y, size, size);
		
		NSBezierPath * circle = [NSBezierPath bezierPathWithOvalInRect:backgroundFrame];
		CGFloat alpha = [[(CTFActionButton *)[self controlView] plugin] overlayOpacityHighlighted: [self isHighlighted]];
		[[NSColor colorWithDeviceWhite:1.0 alpha:alpha] set];
		[circle fill];
				
		// draw the gear image
		[gearImage drawAtPoint:NSMakePoint(x + padding, y + padding)
					  fromRect:NSZeroRect
					 operation:NSCompositeSourceOver
					  fraction:.9];
	}
}



#pragma mark -
#pragma mark Helper

- (BOOL) gearVisible {
	NSRect bounds = [[[self controlView] superview] bounds ];
	return NSWidth( bounds ) > 32 && NSHeight( bounds ) > 32;
}





#pragma mark -
#pragma mark Accessibility


/*
 Say that we also provide an AXDescription.
*/
- (NSArray *) accessibilityAttributeNames {
	NSMutableArray * attributes = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	[attributes addObject: NSAccessibilityDescriptionAttribute];
	return attributes;
}



/*
 Provide values for accessibility attributes.
 AXDescription -> description
 AXParent -> plugin
*/
- (id) accessibilityAttributeValue: (NSString *) attribute {
	id value;
	
	if ( [attribute isEqualToString: NSAccessibilityDescriptionAttribute] ) {
		value = CtFLocalizedString( @"ClickTo Flash Menu", @"CTFActionButton Accessibility: Description");
	}
	else if ( [attribute isEqualToString: NSAccessibilityParentAttribute] ) {
		// the plugin's view is our parent
		value = NSAccessibilityUnignoredAncestor([self controlView]);
	}
	else {
		value = [super accessibilityAttributeValue:attribute];
	}
	return value;
}



@end
