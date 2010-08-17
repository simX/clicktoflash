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

#import "CTFButtonsView.h"
#import "Plugin.h"
#import "CTFButton.h"



static CGFloat interButtonGap = 4.;
static CGFloat topMargin = 4.;
static CGFloat rightMargin = 6.;
static CGFloat leftMargin = 32.;
static CGFloat height = 32.;


@implementation CTFButtonsView

- (id) initWithFrame: (NSRect) frame {
	self = [super initWithFrame: frame];
	
	if (self != nil) {
		buttons = [[NSMutableArray alloc] initWithCapacity:5];
	}
	
	return self;
}


- (void) dealloc {
	[buttons release];
	[super dealloc];
}






#pragma mark -
#pragma mark NSView subclassing

- (void) resizeWithOldSuperviewSize: (NSSize) oldBoundsSize {
	NSRect superRect = [[self superview] bounds];
	CGFloat width = superRect.size.width - rightMargin - leftMargin;
	CGFloat bottom = superRect.size.height - height;
	
	if ( bottom > 8. && width > 16.) {
		NSRect newFrame = NSMakeRect(leftMargin, bottom, width, height);
		[self setFrame: newFrame];
		[self arrangeButtons];
		[self setHidden: NO];
	}
	else {
		[self setHidden: YES];
	}
	
}



- (NSInteger) tag {
	return CTFButtonsViewTag;
}




#pragma mark -
#pragma mark Manage Buttons

- (void) insertButton: (NSControl*) button atIndex: (NSInteger) index {
	[buttons insertObject:button atIndex:index];
	[button setWantsLayer:YES];
	[self addSubview: button];
	[self arrangeButtons];
}


- (void) addButton: (NSControl*) button {
	[self insertButton:button atIndex:[buttons count]];
}


- (void) removeButton: (NSControl*) button {
	[buttons removeObject:button];
	[self arrangeButtons];
}

	 

// Buttons are arranged at the top right of the view from the right;
- (void) arrangeButtons {
	NSSize mySize = [self bounds].size;
	CGFloat currentPosition = mySize.width;
	
	for (NSUInteger i = 0; i < [buttons count]; i++) {
		NSControl * button = [buttons objectAtIndex: i];
		NSRect buttonFrame = [button frame];

		CGFloat buttonLeft = currentPosition - buttonFrame.size.width;
		CGFloat buttonBottom = mySize.height - topMargin - buttonFrame.size.height;
		[button setFrameOrigin:NSMakePoint(buttonLeft, buttonBottom)];
		
		// completely hide buttons that would be cut off
		[button setHidden: (buttonLeft < 0)];
		
		currentPosition = buttonLeft - interButtonGap;

		// set up key loop
		if ( i == 0 ) { // first item
			[self setNextKeyView: button];
		}
		else {
			[[buttons objectAtIndex: i-1] setNextKeyView: button];
		}
		if ( i == [buttons count] ) {
			[button setNextKeyView: (CTFClickToFlashPlugin *)[[self superview] superview]];
		}
	}
	
	if ( [buttons count] == 0) {
		[self setNextKeyView: (CTFClickToFlashPlugin *)[[self superview] superview]];
	}
	
}


@end
