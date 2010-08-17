/*

The MIT License

Copyright (c) 2008-2010 ClickToFlash Developers

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

#define LOGGING_ENABLED 0



/*
 Define a number of 10.5 numbers/types/methods when building for 10.4 as well.
 Both to make things work and to reduce the number of errors that are reported.
 This should simplify the spotting of potential 10.4 problems.
*/
#ifndef NSAppKitVersionNumber10_5

#define NSAppKitVersionNumber10_5 949

#if __LP64__ || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef double CGFloat;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
typedef float CGFloat;
#endif

#import <WebKit/WebKit.h>
@interface DOMElement (retro)
- (void) setAttribute: (NSString *) name value: (NSString *) value;
@end

@interface DOMCSSStyleDeclaration (retro)
- (void) setProperty: (NSString *) propertyName value: (NSString *) value priority: (NSString *) priority;
@end

@interface WebView (retro)
- (void)setMainFrameURL:(NSString *)URLString;
@end

@interface DOMNode (retro)
- (DOMNode *)insertBefore:(DOMNode *)newChild refChild:(DOMNode *)refChild;
- (DOMNode *)replaceChild:(DOMNode *)newChild oldChild:(DOMNode *)oldChild;
- (void) setTextContent: (NSString *) text;
@end

#endif



    // Simple ForEach macro to make life easier on those porting to Tiger
    // than using Leopard's fast enumeration and "in" keyword:
#define CTFForEachObject( Type, varName, container ) \
    NSEnumerator* feoEnum_##__LINE__ = [ container objectEnumerator ]; \
    Type* varName; \
    while( ( varName = [ feoEnum_##__LINE__ nextObject ] ) )


    // Load our localised strings from the correct bundle [use genstrings -s CtFLocalizedString]
#define CtFLocalizedString(key, explanation) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:(nil)]


    // Assert that we're running on the main thread
#define CtFMainThreadAssertion() \
do { \
   if ([NSThread respondsToSelector:@selector(mainThread)]) { \
      NSString * assertionMessage = [NSString stringWithFormat:@"%@ not called on main thread", [NSString stringWithUTF8String:__PRETTY_FUNCTION__]]; \
      NSAssert([[NSThread currentThread] isEqual: [NSThread mainThread]], assertionMessage); \
   } \
} while(0)
