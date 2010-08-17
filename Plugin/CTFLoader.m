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

#import "CTFLoader.h"
#import "CTFUtilities.h"



@implementation CTFLoader

+ (CTFLoader *) loaderWithURL: (NSURL *) theURL delegate: (id) theDelegate selector: (SEL) theSelector {
	return [[[CTFLoader alloc] initWithURL:theURL delegate:theDelegate selector:theSelector] autorelease];
}



- (id) initWithURL: (NSURL *) theURL delegate: (id) theDelegate selector: (SEL) theSelector {
	self = [super init];
	id result = nil;
	
	if (self != nil && theURL != nil && theDelegate != nil && theSelector != NULL) {
		[self setURL: theURL];
		[self setDelegate: theDelegate];
		[self setCallbackSelector: theSelector];

		data = [[NSMutableData alloc] init];
		identifier = nil;
		response = nil;
		connection = nil;
		
		result = self;
	}
	
	return result;
}



// Calls -reallyStart on the main thread. -reallyStart opens an NSURLConnection which calls its delegate methods on the same thread it was initialised on (and does nothing when that thread doesn't exist anymore). As this method can be called on a different thread, we make sure that the delegate methods can be called when they are due.
- (void) start {
#if LOGGING_ENABLED > 1
	NSLog(@"CTFLoader %@ -start for address: %@", [self description], [[self URL] absoluteString]);
#endif
	
	[self performSelectorOnMainThread:@selector(reallyStart) withObject:nil waitUntilDone:YES];
}



// Starts the NSURLConnection to do the fetching. This should be invoked by calling the -start method.
- (void) reallyStart {
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL: URL];
	if ([self HEADOnly]) {
		[request setHTTPMethod:@"HEAD"];
	}
	NSURLConnection * myConnection = [[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
	[self setConnection: myConnection];
#if LOGGING_ENABLED > 2
	NSLog(@"CTFLoader %@ -reallyStart: started URLConnection %@", [self description], [myConnection description]);
#endif
}



- (void) finish {
#if LOGGING_ENABLED > 2
	NSLog(@"CTFLoader %@ -finish", [self description]);
#endif

	[self setConnection: nil];
	
	if ( [self delegate] && [[self delegate] respondsToSelector:[self callbackSelector]] ) {
		[[self delegate] performSelector:[self callbackSelector] withObject:self];
	}
	else {
		NSLog(@"CTFLoader %@ -finish: could NOT use callbackSelector on delegate %@", [self description], [[self delegate] description]);
	}
}



- (void) cancel {
#if LOGGING_ENABLED > 2
	NSLog(@"CTFLoader %@ -cancel", [self description]);
#endif
	
	[self setDelegate: nil];
	[[self connection] cancel];
	[self setConnection: nil];
}



- (void) dealloc {
#if LOGGING_ENABLED > 2
	NSLog(@"CTFLoader %@ -dealloc", [self description]);
#endif
	
	[data release];
    [URL release];
    [response release];
    [lastRequest release];
	[connection release];
	[identifier release];
	[super dealloc];
}




#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *) newData {
	[data appendData: newData];
}



- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)theResponse {
#if LOGGING_ENABLED > 1
	NSLog(@"CTFLoader %@ --connection:didReceiveResponse with status: %ld", [self description], [(NSHTTPURLResponse*) theResponse statusCode]);
#endif
	[self setResponse: theResponse];
	
	// We need to cancel HEAD fetching connections here as 10.5 may proceed to download the whole file otherwise ( http://openradar.appspot.com/7019347 )
	if ( [self HEADOnly] && [(NSHTTPURLResponse*) theResponse statusCode] == 200 ) {
		[theConnection cancel];
#if LOGGING_ENABLED > 2
		NSLog(@"CTFLoader %@ --connection:didReceiveResponse: cancelled connection: %@", [self description], [theConnection description]);
#endif
		[self finish];
	}
}



- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
#if LOGGING_ENABLED > 1
	NSLog(@"CTFLoader %@ finished Loading for delegate: %@", [self description], [[self delegate] description]);
#endif
	
	[self finish];		
}



- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"CTFlashLoader %@ download failure: %@", [self description], [error description]);
	[self finish];
}



- (NSURLRequest *)connection:(NSURLConnection *)connection 
			 willSendRequest:(NSURLRequest *)request 
			redirectResponse:(NSURLResponse *)redirectResponse
{
#if LOGGING_ENABLED > 1
	NSLog(@"CTFLoader %@ redirect to: %@", [self description], [[request URL] absoluteString]);
#endif
	NSURLRequest * result = request;
	
	// For the head fetching we need to fix the redirects to make sure the method they use is HEAD.
	if ( [self HEADOnly] ) {
		if (![[request HTTPMethod] isEqualTo:@"HEAD"]) {
			NSMutableURLRequest * newRequest = [[request mutableCopy] autorelease];
			[newRequest setHTTPMethod:@"HEAD"];
			result = newRequest;
		}
	} 		
	
	[self setLastRequest: request];

	return result;
}






#pragma mark -
#pragma mark Accessors

- (NSData*)data {
	return data;
}


- (NSURL *)URL {
	return URL;
}

- (void)setURL:(NSURL *)newURL {
	[newURL retain];
	[URL release];
	URL = newURL;
}


- (NSURLResponse *)response {
	return response;
}

- (void)setResponse:(NSURLResponse *)newResponse {
	[newResponse retain];
	[response release];
	response = newResponse;
}


- (NSURLRequest *)lastRequest {
	return lastRequest;
}

- (void)setLastRequest:(NSURLRequest *)newLastRequest {
	[newLastRequest retain];
	[lastRequest release];
	lastRequest = newLastRequest;
}


- (NSURLConnection *)connection {
	return connection;
}

- (void)setConnection:(NSURLConnection *)newConnection {
	[newConnection retain];
	[connection release];
	connection = newConnection;
}


- (id)identifier {
	return identifier;
}

- (void)setIdentifier:(id)newIdentifier {
	[newIdentifier retain];
	[identifier release];
	identifier = newIdentifier;
}


- (BOOL)HEADOnly {
	return HEADOnly;
}

- (void)setHEADOnly:(BOOL)newHEADOnly {
	HEADOnly = newHEADOnly;
}


- (id)delegate {
	return delegate;
}

- (void)setDelegate:(id)newDelegate {
	// don't retain delegates
	delegate = newDelegate;
}


- (SEL)callbackSelector {
	return callbackSelector;
}

- (void)setCallbackSelector:(SEL)newCallbackSelector {
	callbackSelector = newCallbackSelector;
}


@end
