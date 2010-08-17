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

#import "Plugin.h"
#import "CTFUserDefaultsController.h"
#import "CTFPreferencesDictionary.h"
#import "CTFMenubarMenuController.h"
#import "CTFUtilities.h"
#import "CTFWhitelist.h"
#import "CTFGradient.h"
#import "CTFKiller.h"
#import "CTFKillerVideo.h"
#import "CTFKillerSIFR.h"
#import "CTFLoader.h"
#import "CTFActionButton.h"
#import "CTFMainButton.h"
#import "CTFButtonsView.h"
#import "CTFFullScreenWindow.h"

#import <Carbon/Carbon.h>

// MIME types
static NSString *sFlashOldMIMEType = @"application/x-shockwave-flash";
static NSString *sFlashNewMIMEType = @"application/futuresplash";

// Info.plist key storing the Flash version number
static NSString *CTFFlashVersionNumberKey = @"Flash version number";

// CTFUserDefaultsController keys
static NSString *sAutoLoadInvisibleFlashViewsDefaultsKey = @"autoLoadInvisibleViews";
static NSString *sPluginEnabledDefaultsKey = @"pluginEnabled";
static NSString *sApplicationWhitelist = @"applicationWhitelist";
static NSString *sUseNewStyleUIDefaultsKey =@"use new style UI";
// static NSString *sDrawGearImageOnlyOnMouseOverHiddenPref = @"drawGearImageOnlyOnMouseOver";

// Info.plist key for app developers
static NSString *sCTFOptOutKey = @"ClickToFlashOptOut";

#define CTFDefaultWhitelist [NSArray arrayWithObjects:\
@"com.apple.frontrow",\
@"com.apple.dashboard.client",\
@"com.apple.ScreenSaver.Engine",\
@"com.hulu.HuluDesktop",\
@"com.riverfold.WiiTransfer",\
@"com.bitcartel.pandorajam",\
@"com.adobe.flexbuilder",\
@"com.Zattoo.prefs",\
@"fr.understudy.HuluPlayer",\
@"com.apple.iWeb",\
@"com.realmacsoftware.rapidweaverpro",\
@"com.realmacsoftware.littlesnapper",\
nil]



@interface CTFClickToFlashPlugin (Internal)
- (void) _convertTypesForFlashContainerAfterDelay;

- (void) _drawBackground;
- (BOOL) _isOptionPressed;
- (BOOL) _isCommandPressed;

- (void) _loadContent: (NSNotification*) notification;
- (void) _loadContentForWindow: (NSNotification*) notification;
@end



@implementation CTFClickToFlashPlugin


#pragma mark -
#pragma mark Class Methods

+ (NSView *)plugInViewWithArguments:(NSDictionary *)arguments {
    return [[[self alloc] initWithArguments:arguments] autorelease];
}



#define CTFInitialDefault( initialValue, defaultName ) \
if ( [[CTFUserDefaultsController standardUserDefaults] objectForKey: defaultName] == nil ) { \
[[CTFUserDefaultsController standardUserDefaults] setObject: initialValue forKey: defaultName]; \
}


+ (void) initialize {
	[[self class] _migratePrefsToExternalFile];
	[[self class] _migrateWhitelist];
	[[self class] _uniquePrefsFileWhitelist];
	[[self class] _addApplicationWhitelistArrayToPrefsFile];
	[CTFKillerSIFR migrateDefaults];
	
	// set up initial defaults
	// be enabled
	CTFInitialDefault( [NSNumber numberWithBool: YES], sPluginEnabledDefaultsKey )
	// do not automatically load smaill Flash views
	CTFInitialDefault( [NSNumber numberWithBool: NO], sAutoLoadInvisibleFlashViewsDefaultsKey )
	// use 'new style' UI if possible
	CTFInitialDefault( [NSNumber numberWithBool: YES], sUseNewStyleUIDefaultsKey )

	// for CTFKillerVideo
	// use non-Flash video if possible
	CTFInitialDefault( [NSNumber numberWithBool: YES], sUseYouTubeH264DefaultsKey )
	// use HD video if possible
	CTFInitialDefault( [NSNumber numberWithBool: NO], sUseYouTubeHDH264DefaultsKey )
	// use HTML5 video element or QuickTime plug-in?
	CTFInitialDefault( [NSNumber numberWithBool: NO], sDisableVideoElementDefaultsKey )
	// start playback of videos automatically
	CTFInitialDefault( [NSNumber numberWithBool: YES], sYouTubeAutoPlayDefaultsKey )
									  
	// for QTKit usage in CTFKillerVideo
	// use QTKit
	CTFInitialDefault( [NSNumber numberWithBool: YES], sUseQTKitDefaultsKey )
	// default volume level when using QTKit for playback
	CTFInitialDefault( [NSNumber numberWithFloat: 1.0], sVideoVolumeLevelDefaultsKey )
									  
	// for CTFKillerSIFR
	// automatically handle SiFR?
	CTFInitialDefault( [NSNumber numberWithBool: YES], sSifrAutoHandleDefaultsKey )
	// automatically remove SiFR (and use normal text instead)?
	CTFInitialDefault( [NSNumber numberWithBool: NO], sSifrDeSifrDefaultsKey )
}





#pragma mark -
#pragma mark Initialization and Superclass Overrides

- (id) initWithArguments: (NSDictionary*) arguments {
	self = [super init];
    if (self) {
		// SET UP INSTANCE VARIABLES
		// display related
		[self setWebView:[[[arguments objectForKey:WebPlugInContainerKey] webFrame] webView]];
		[self setContainer:[arguments objectForKey:WebPlugInContainingElementKey]];
		
		// URL related
		NSURL * base = [arguments objectForKey:WebPlugInBaseURLKey];
		[self setBaseURL: base];
		
		// attribute & variable related
		[self setAttributes:[arguments objectForKey:WebPlugInAttributesKey]];

		NSString * srcAttribute = [[self attributes] objectForKey:@"src"];
		if (srcAttribute) {
			[self setSrc:srcAttribute];
		} else {
			NSString * dataAttribute = [[self attributes] objectForKey:@"data"];
			if (dataAttribute) {
				[self setSrc:dataAttribute];
			}
		}

		NSString * flashVars = [[self attributes] objectForKey:@"flashvars"];
		[self setFlashVarsFromString:flashVars];
		
		[self opacitySetup]; // sets up original opacity attributes and changes our opacity

		isImmediatelyConverted = NO;
		isConverted = NO;
		
		[self setupSubviews]; // sets up subview variables
		
		[self setFullScreenWindow: nil];
		
		[self setPreviewURL: nil];
		[self setPreviewImage: nil];
		[self setPreviewImageLoader: nil];
		

#if LOGGING_ENABLED
		NSLog(@"ClickToFlashPlugin %@ -initWithArguments, src: %@", [self description], [self src]);
#if LOGGING_ENABLED > 1
		NSLog( @"ClickToFlash Plugin arguments = %@", arguments );
		NSLog( @"ClickToFlash Plugin flashvars = %@", _flashVars );
#endif
#endif
		
		// FURTHER SETUP & POTENTIAL CONVERSION
		
		// Try to add menu bar items.
		[CTFMenubarMenuController sharedController];
		
		// Check whether plugin is disabled, load all content as normal if so.
		// Do this before setting up Killers.
		if ( [[self class] CTFIsInactive] ) {
			[self convertTypesForContainer:NO];
			return self;
		}


		// Set up the CTFKiller subclass if appropriate.
		[self setKiller: [CTFKiller killerForURL:[self baseURL]
											 src:[self src]
									  attributes:[self attributes]
									   forPlugin:self] ];
		
		
		// Send a notification so that all flash objects can be tracked.
		// We only want to track it if we don't auto-load it.
		[[CTFMenubarMenuController sharedController] registerView: self];
        
        // Observe various things:
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        
        // Observe for additions to the whitelist:
        [self _addWhitelistObserver];
		
		[center addObserver: self
				   selector: @selector( _loadContent: )
					   name: kCTFLoadAllFlashViews
					 object: nil ];
		
		[center addObserver: self
				   selector: @selector( _loadContentForWindow: )
					   name: kCTFLoadFlashViewsForWindow
					 object: nil ];
		
		[center addObserver: self
				   selector: @selector( _loadInvisibleContentForWindow: )
					   name: kCTFLoadInvisibleFlashViewsForWindow
					 object: nil ];

		

		if ( [self shouldConvertImmediately] ) {
			isImmediatelyConverted = YES;
			[self convertTypesForContainer:YES];
		}
	
	}
	
	return self;
}




// If a Flash view has style attributes that make it transparent, the CtF
// view will similarly be transparent; we want to make it temporarily
// visible, and then restore the original attributes so that we don't
// have any display issues once the Flash view is loaded.
//
// Should we apply this to the parent?
// That seems to be problematic.
//
// Well, in my experience w/CSS, to get a layout to work a lot of the
// time, you need to create parent objects and apply styles to parents,
// so it seemed reasonable to check both self and parent for potential
// problems with opacity.

// Changes the DOM, thus needs to be called on main thread only.
// Is only called from -initWithArguments: which WebKit calls on the main thread (?)
- (void) opacitySetup {
	CtFMainThreadAssertion();
	
	NSMutableDictionary *originalOpacityDict = [NSMutableDictionary dictionary];
	NSString *opacityResetString = @"; opacity: 1.000 !important; -moz-opacity: 1 !important; filter: alpha(opacity=1) !important;";
	
	NSString *originalWmode = [[self container] getAttribute:@"wmode"];
	NSString *originalStyle = [[self container] getAttribute:@"style"];
	NSString *originalParentWmode = [(DOMElement *)[[self container] parentNode] getAttribute:@"wmode"];
	NSString *originalParentStyle = [(DOMElement *)[[self container] parentNode] getAttribute:@"style"];
	
	if (originalWmode != nil && [originalWmode length] > 0u && ![originalWmode isEqualToString:@"opaque"]) {
		[originalOpacityDict setObject:originalWmode forKey:@"self-wmode"];
		[[self container] setAttribute:@"wmode" value:@"opaque"];
	}
	
	if (originalStyle != nil && [originalStyle length] > 0u && ![originalStyle hasSuffix:opacityResetString]) {
		[originalOpacityDict setObject:originalStyle forKey:@"self-style"];
		[originalOpacityDict setObject:[originalStyle stringByAppendingString:opacityResetString] forKey:@"modified-self-style"];
		[[self container] setAttribute:@"style" value:[originalStyle stringByAppendingString:opacityResetString]];
	}
	
	if (originalParentWmode != nil && [originalParentWmode length] > 0u && ![originalParentWmode isEqualToString:@"opaque"]) {
		[originalOpacityDict setObject:originalParentWmode forKey:@"parent-wmode"];
		[(DOMElement *)[[self container] parentNode] setAttribute:@"wmode" value:@"opaque"];
	}
	
	if (originalParentStyle != nil && [originalParentStyle length] > 0u && ![originalParentStyle hasSuffix:opacityResetString]) {
		[originalOpacityDict setObject:originalParentStyle forKey:@"parent-style"];
		[originalOpacityDict setObject:[originalParentStyle stringByAppendingString:opacityResetString] forKey:@"modified-parent-style"];
		[(DOMElement *)[[self container] parentNode] setAttribute:@"style" value:[originalParentStyle stringByAppendingString:opacityResetString]];
	}
	
	[self setOriginalOpacityAttributes:originalOpacityDict];
}




/*
 Set up the subviews we are using. They are structured as follows:
 
 self (CTFClickToFlashPlugin)
 -> containerView (NSView)
	-> buttonsContainer (NSView)
		-> mainButton (CTFMainButton)
		-> actionButton (CTFActionButton)
		-> buttonsView (CTFButtonsView) - new style display only
			-> array of buttons (CTFButton) added as needed by CTFKiller classes
 
 This setup can be changed by CTFKillers, e.g. CTFVideoKiller hides the mainButton when clicked and adds a QTMovieView.
 The layout is made in a way that also supports zooming to full screen (used in 'new style' UI only).
 In the 'new style' UI, set these views up with layers, so they draw properly above a playing movie.
*/
- (void) setupSubviews {
	// Add a full size subview which will contain everything. We need this so we can move it to full-screen without removing the plug-in from the web page.
	NSView * myContainerView = [[[NSView alloc] initWithFrame: [self bounds]] autorelease];
	[myContainerView setAutoresizingMask: (NSViewHeightSizable | NSViewWidthSizable) ];
	[self addSubview: myContainerView];
	[self setContainerView: myContainerView];

	// Add view containing all of the buttons
	NSView * theButtonsContainer = [[[NSView alloc] initWithFrame:[self bounds]] autorelease];
	[theButtonsContainer setAutoresizingMask: (NSViewHeightSizable | NSViewWidthSizable) ];
	[myContainerView addSubview: theButtonsContainer];
	[self setButtonsContainer: theButtonsContainer];
		
	// Add main control button, covering the full view. This does the main drawing.
	CTFMainButton * myMainButton = [[[CTFMainButton alloc] initWithFrame: [self bounds]] autorelease];
	[myMainButton setTag: CTFMainButtonTag];
	[myMainButton setAutoresizingMask: (NSViewHeightSizable | NSViewWidthSizable) ];
	[myMainButton setButtonType: NSMomentaryPushInButton];
	[myMainButton setTarget: self];
	[myMainButton setAction: @selector(clicked:)];
	[myMainButton setPlugin: self];
	[theButtonsContainer addSubview: myMainButton];
	[self setMainButton: myMainButton];
	
	// Add action button control
	CTFActionButton * theActionButton = [CTFActionButton actionButton];
	[theActionButton setTag: CTFActionButtonTag];
	[theActionButton setPlugin: self];
	[theActionButton setAutoresizingMask: (NSViewMaxXMargin | NSViewMinYMargin) ];
	[theButtonsContainer addSubview: theActionButton];
	[self setActionButton: theActionButton];

	// attempt to construct a key loop: Plugin -> main button -> actionButton -> buttonsView -> Plugin. Is this the right philosophy?
	[self setNextKeyView: myMainButton];
	[myMainButton setNextKeyView: theActionButton];
	[theActionButton setNextKeyView: self];
	
	
	// the new style UI also adds buttons at the right hand side of the container and displays QuickTime itself.
	if ( [self useNewStyleUI] ) {
		// Add view for additional buttons (proper sizing is done by view itself)
		CTFButtonsView * theButtonsView = [[[CTFButtonsView alloc] initWithFrame: NSZeroRect] autorelease];
		[theButtonsView setAutoresizingMask: NSViewWidthSizable];
		[theButtonsContainer addSubview: theButtonsView];
		[self setButtonsView: theButtonsView];
		
		// adapt key loop to contain the buttons view
		[theActionButton setNextKeyView: buttonsView];
		[buttonsView setNextKeyView: self];
		
		// Our views need layers in case we are using QuickTime so they won't become erased.
		[myMainButton setWantsLayer: YES];
		[theButtonsContainer setWantsLayer: YES];
		[theActionButton setWantsLayer: YES];
		[theButtonsView setWantsLayer: YES];
		[myContainerView setWantsLayer: YES];
	}
}



// We want to convert immediately if ANY of the following is true:
// - we are whitelisted
// - we are considered small/invisible and the user wants to load those automatically
// - our killer wants to convert immediately
// UNLESS the option key is pressed
- (BOOL) shouldConvertImmediately {
	// Whitelisting: check current site as well as SWF src URL (for embedding)
	BOOL loadFromWhiteList = [self isWhitelisted];
	
	// Small/invisible Flash
	BOOL autoLoadInvisibles = NO;
	if ( [ [ CTFUserDefaultsController standardUserDefaults ] boolForKey: sAutoLoadInvisibleFlashViewsDefaultsKey ]
		&& [ self isConsideredInvisible ] ) {
		autoLoadInvisibles = YES;
	}
	

	// Killers
	BOOL killerWantsConversion = NO;
	if ( [self killer] != nil ) {
		killerWantsConversion = [[self killer] shouldConvertImmediately];
	}
	
	
	BOOL result = loadFromWhiteList || autoLoadInvisibles || killerWantsConversion;

	// prevent automatic conversion is the option key is pressed
	result = result && ![self _isOptionPressed];

	return result;
}





- (void)webPlugInDestroy {
#if LOGGING_ENABLED
	NSLog(@"ClickToFlashPlugin %@ -webPlugInDestroy", [self description]);
#endif
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[[self killer] pluginDestroy];
	[self exitFullScreen: self];
	[self _abortAlert];        // to be on the safe side
	
	// notify that this ClickToFlash plugin is going away
	[[CTFMenubarMenuController sharedController] unregisterView:self];
	
	[self setWebView:nil];
	[self setContainer:nil];

	[self setBaseURL:nil];

	[self setAttributes:nil];
	[self setSrc:nil];
	[self setFlashVarsFromString:nil];
	[self setOriginalOpacityAttributes:nil];
	
	[self setKiller:nil];
	
	[self setContainerView:nil];
	[self setMainButton:nil];
	[self setButtonsContainer:nil];
	[self setActionButton:nil];
	[self setButtonsView:nil];

	[self setFullScreenWindow:nil];

	[self setPreviewURL:nil];
	[self setPreviewImage:nil];
	[self setPreviewImageLoader:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}



- (void) dealloc {
#if LOGGING_ENABLED
	NSLog(@"ClickToFlashPlugin %@ -dealloc", [self description]);
#endif
	
	// Just in case...
	[self webPlugInDestroy];
	
    [super dealloc];
}


 
- (BOOL) isConsideredInvisible
{
	int height = (int)([[self webView] frame].size.height);
	int width = (int)([[self webView] frame].size.width);
	
	if ( (height <= maxInvisibleDimension) && (width <= maxInvisibleDimension) )
	{
		return YES;
	}
	
	NSDictionary *attributes = [self attributes];
	if ( attributes != nil )
	{
		NSString *heightObject = [attributes objectForKey:@"height"];
		NSString *widthObject = [attributes objectForKey:@"width"];
		if ( heightObject != nil && widthObject != nil )
		{
			height = [heightObject intValue];
			width = [widthObject intValue];
			if ( (height <= maxInvisibleDimension) && (width <= maxInvisibleDimension) )
			{
				return YES;
			}
		}
	}
	
	return NO;
}



- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize {
//	NSLog(@"ClickToFlash Plugin -resizeSubviewsWithOldSize:");
	[super resizeSubviewsWithOldSize: oldBoundsSize];
	if ([self killer]) {
		[killer pluginResized];
	}
}






#pragma mark -
#pragma mark WebKitPluginScripting

- (id) objectForWebScript {
    return self;
}



// JavaScript may call GetVariable("$version") on us.
+ (NSString *) webScriptNameForSelector: (SEL) aSelector {
	NSString * result = nil;

	if (aSelector == @selector(flashGetVariable:)) {
		result = @"GetVariable";
	}

	return result;
}


+ (BOOL) isSelectorExcludedFromWebScript: (SEL) aSelector {
	BOOL result = YES;
	
	if (aSelector == @selector(flashGetVariable:))
		result = NO;

	return result;
}


- (id) flashGetVariable: (id) flashVar {
	NSString * result = nil;
	
	if ( flashVar && [flashVar isKindOfClass:[NSString class]] ) {
		// we only know how to deal with strings
		
		if ([(NSString *)flashVar isEqualToString:@"$version"]) {
			/*
			 Get Flash version number stored in our Info.plist and hand it over to JavaScript in the 'correct' format.
			 It may be preferable to get the full version number from the Flash plug-in that's actually installed, but doing so may be a lot of work (locate the bundle, full version number seems to be stored in resource file only...).
			*/
			NSDictionary * infoDict = [[NSBundle bundleForClass: [self class]] infoDictionary];
			NSMutableString * versionString = [[[infoDict objectForKey: CTFFlashVersionNumberKey] mutableCopy] autorelease];
			if ( versionString != nil ) {
				[versionString replaceOccurrencesOfString:@"." withString:@"," options:NSLiteralSearch range:NSMakeRange(0, [versionString length])];
				
				result = [NSString stringWithFormat: @"MAC %@", versionString];
			}
		}
		else if ([flashVar isEqualToString:@"$ClickToFlashVersion"]) {
			NSBundle *bundle = [NSBundle bundleForClass:[self class]];
			if (bundle) {
				id version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
				if (version && [version isKindOfClass:[NSString class]]) {
					result = (NSString *)version;
				}
			}
		}
		else {
			// Fall back to using stored flashvars for the other cases
			result = [self flashvarWithName:(NSString *)flashVar];
		}
	}
	
    return result;
}





#pragma mark -
#pragma mark Contextual menu

- (NSMenuItem *) addContextualMenuItemWithTitle: (NSString*) title action: (SEL) selector {
	return [self addContextualMenuItemWithTitle: title action: selector target: self];
}


- (NSMenuItem *) addContextualMenuItemWithTitle: (NSString*) title action: (SEL) selector target:(id) target {
	NSMenuItem * menuItem = [[[NSMenuItem alloc] initWithTitle: title action:selector keyEquivalent:@""] autorelease];
	[menuItem setTarget: target];
	[[self menu] addItem: menuItem];
	return menuItem;
}



// Build contextual menu
- (NSMenu*) menuForEvent: (NSEvent*) event {
	NSMenuItem * menuItem;
	
	[self setMenu: [[[NSMenu alloc] initWithTitle:CtFLocalizedString( @"ClickTo Flash Contextual menu", @"Title of Contextual Menu")] autorelease]];
	
	if ([self killer] != nil) {
		[[self killer] addPrincipalMenuItemToContextualMenu];
	}
	
	[self addContextualMenuItemWithTitle: CtFLocalizedString( @"Load Flash", @"Contextual Menu Item: Load Flash" ) 
								  action: @selector( loadFlash: )];
		
	if ([[CTFMenubarMenuController sharedController] multipleFlashViewsExistForWindow:[self window]]) {
		[self addContextualMenuItemWithTitle: CtFLocalizedString( @"Load All on this Page", @"Load All on this Page contextual menu item" )
									  action: @selector( loadAllOnPage: )];
	}
	
	[self addContextualMenuItemWithTitle: CtFLocalizedString( @"Hide Flash", @"Hide Flash contextual menu item (sets display:none)")
								  action: @selector( hideFlash:)];
	menuItem = [self addContextualMenuItemWithTitle: CtFLocalizedString( @"Remove Flash", @"Remove Flash contextual menu item (sets visibility: hidden)")
											 action: @selector( removeFlash: )];
	[menuItem setAlternate:YES];
	[menuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
	
	[[self menu] addItem: [NSMenuItem separatorItem]];
	
	if ([self killer]) {
		NSInteger itemCount = [[self menu] numberOfItems];
		[[self killer] addAdditionalMenuItemsForContextualMenu];
		if ([[self menu] numberOfItems] != itemCount) {
			[[self menu] addItem: [NSMenuItem separatorItem]];
		}
	}
	
	if ([self host] && ![self isWhitelisted]) {
		[self addContextualMenuItemWithTitle: [NSString stringWithFormat:CtFLocalizedString( @"Add %@ to Whitelist", @"Add <sitename> to Whitelist contextual menu item" ), [self host]]
									  action: @selector( addHostToWhitelist: )];
		
		menuItem = [self addContextualMenuItemWithTitle: CtFLocalizedString( @"Add this Flash item to Whitelist", @"Add this Flash item (src URL) to whitelist") 
												 action: @selector( addSrcToWhitelist: )];
		[menuItem setAlternate: YES];
		[menuItem setKeyEquivalentModifierMask: NSAlternateKeyMask];
		[menuItem setToolTip: [self src]];
		
		[[self menu] addItem: [NSMenuItem separatorItem]];
		
	}
	
	[self addContextualMenuItemWithTitle: CtFLocalizedString( @"ClickToFlash Preferences...", @"Preferences contextual menu item" )
								  action: @selector( editWhitelist: )];
	
	
    return [self menu];
}



- (BOOL) validateMenuItem: (NSMenuItem *) menuItem {
	return YES;
}





#pragma mark -
#pragma mark Loading

- (IBAction) clicked: (id) sender {
#if LOGGING_ENABLED > 0
	NSLog(@"CTFPluginController -clicked:");
#endif
	if (![self isConverted]) {
		if ([self _isCommandPressed]) {
			if ([self _isOptionPressed]) {
				[self removeFlash:self];
			} else {
				[self hideFlash:self];
			}
		} else if ([self _isOptionPressed] && ![self isWhitelisted]) {
			[self _askToAddCurrentSiteToWhitelist];
		} else {
				[self convertTypesForContainer:YES];
		}
	}
}


- (IBAction)removeFlash: (id) sender;
{
    DOMCSSStyleDeclaration *style = [[self container] style];
	[style setProperty:@"display" value:@"none" priority:@"important"];
}

- (IBAction)hideFlash: (id) sender;
{
    DOMCSSStyleDeclaration *style = [[self container] style];
	[style setProperty:@"visibility" value:@"hidden" priority:@"important"];
}

- (IBAction)loadFlash:(id)sender;
{
    [self convertTypesForFlashContainer];
}

- (IBAction)loadAllOnPage:(id)sender
{
    [[CTFMenubarMenuController sharedController] loadFlashForWindow: [self window]];
}


- (void) _loadContent: (NSNotification*) notification
{
    [self convertTypesForContainer:YES];
}

- (void) _loadContentForWindow: (NSNotification*) notification
{
	if( [ notification object ] == [ self window ] )
		[ self convertTypesForContainer :YES];
}

- (void) _loadInvisibleContentForWindow: (NSNotification*) notification
{
	if( [ notification object ] == [ self window ] && [ self isConsideredInvisible ] ) {
		[ self convertTypesForContainer:YES ];
	}
}




#pragma mark -
#pragma mark Helper Methods


+ (NSDictionary*) flashVarDictionary: (NSString*) flashvarString
{
    NSMutableDictionary * flashVarsDictionary = nil;
	
	if (flashvarString != nil) {
		flashVarsDictionary = [ NSMutableDictionary dictionary ];
    
		NSArray* args = [ flashvarString componentsSeparatedByString: @"&" ];
    
		CTFForEachObject( NSString, oneArg, args ) {
			NSRange sepRange = [ oneArg rangeOfString: @"=" ];
			if( sepRange.location != NSNotFound ) {
				NSString* key = [ oneArg substringToIndex: sepRange.location ];
				NSString* val = [ oneArg substringFromIndex: NSMaxRange( sepRange ) ];
				
				[ flashVarsDictionary setObject: val forKey: key ];
			}
		}
	}
    
    return flashVarsDictionary;
}


- (void) setFlashVarsFromString: (NSString *) string {
	[_flashVars release];
	_flashVars = [[[self class] flashVarDictionary: string] retain];
}


- (NSString*) flashvarWithName: (NSString*) argName
{
    return [[[ _flashVars objectForKey: argName ] retain] autorelease];
}


+ (NSString *)launchedAppBundleIdentifier
{
	NSString *appBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	
	if ([appBundleIdentifier isEqualToString:@"com.apple.Safari"]) {
		// additional tests need to be performed, because this can indicate
		// either WebKit *or* Safari; according to @bdash on Twitter, we need
		// to check whether the framework bundle that we're using is 
		// contained within WebKit.app or not
		
		// however, the user may have renamed the bundle, so we have to get
		// its path, then get its bundle identifier
		
		NSString *privateFrameworksPath = [[NSBundle bundleForClass:[WebView class]] privateFrameworksPath];
		
		NSScanner *pathScanner = [[NSScanner alloc] initWithString:privateFrameworksPath];
		NSString *pathString = nil;
		[pathScanner scanUpToString:@".app" intoString:&pathString];
		NSBundle *testBundle = [[NSBundle alloc] initWithPath:[pathString stringByAppendingPathExtension:@"app"]];
		NSString *testBundleIdentifier = [testBundle bundleIdentifier];
		[testBundle release];
		[pathScanner release];
		
		
		// Safari uses the framework inside /System/Library/Frameworks/ , and
		// since there's no ".app" extension in that path, the resulting
		// bundle identifier will be nil; however, if it's WebKit, there *will*
		// be a ".app" in the frameworks path, and we'll get a valid bundle
		// identifier to launch with
		
		if (testBundleIdentifier != nil) appBundleIdentifier = testBundleIdentifier;
	}
	
	return appBundleIdentifier;
}



- (BOOL) _isOptionPressed {
    BOOL isOptionPressed = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
    return isOptionPressed;
}

- (BOOL) _isCommandPressed {
	BOOL isCommandPressed = (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) != 0);
	return isCommandPressed;
}


- (void) browseToURLString: (NSString*) URLString {
	[_webView setMainFrameURL:URLString];
}


- (void) downloadURLString: (NSString*) URLString {
	[[NSWorkspace sharedWorkspace] openURLs: [NSArray arrayWithObject:[NSURL URLWithString: URLString]]
					withAppBundleIdentifier: [[self class] launchedAppBundleIdentifier]
									options: NSWorkspaceLaunchDefault
			 additionalEventParamDescriptor: [NSAppleEventDescriptor nullDescriptor]
						  launchIdentifiers: nil];		
}



- (BOOL) useNewStyleUI {
	BOOL result = NO;

	if ( NSAppKitVersionNumber >= NSAppKitVersionNumber10_5 ) {
		result = [[CTFUserDefaultsController standardUserDefaults] boolForKey: sUseNewStyleUIDefaultsKey];
	}
	
	return result;
}



// returns whether CtF should run or not (depending on preferences and application whitelists, but not the URL)
+ (BOOL) CTFIsInactive {
	CTFUserDefaultsController * standardUserDefaults = [CTFUserDefaultsController standardUserDefaults];
	BOOL pluginEnabled = [standardUserDefaults boolForKey:sPluginEnabledDefaultsKey];

	NSString * hostAppBundleID = [[NSBundle mainBundle] bundleIdentifier];
	BOOL hostAppIsInDefaultWhitelist = [CTFDefaultWhitelist containsObject:hostAppBundleID];
	BOOL hostAppIsInUserWhitelist = [[standardUserDefaults arrayForKey:sApplicationWhitelist] containsObject:hostAppBundleID];

	BOOL hostAppWhitelistedInInfoPlist = NO;
	if ([[[NSBundle mainBundle] infoDictionary] objectForKey:sCTFOptOutKey]) hostAppWhitelistedInInfoPlist = YES;

	BOOL inactive = (!pluginEnabled) || hostAppIsInDefaultWhitelist || hostAppIsInUserWhitelist || hostAppWhitelistedInInfoPlist;
	
	return inactive;
}




/*
 Returns the opacity that should be used for drawing on top of the view.
 Return adapted opacities for highlighted and non-highlighted states.
 Returns greater opacity if a preview image is present.
 Used for the badge and the action button.
*/
- (CGFloat) overlayOpacityHighlighted: (BOOL) highlighted {
	CGFloat result = .5;
	
	if (highlighted == YES) {
		result += .15;
	}
	
	if ([self previewImage] != nil) {
		result += .15;
	}
	
	return result;
}








#pragma mark -
#pragma mark DOM Conversion

// Changes the DOM, thus needs to be called on main thread only.
// Is called from -_convertTypesForFlashContainerAfterDelay which is called on the main thread.
- (void) _convertTypesForElement:(DOMElement *)element {
    NSString *type = [element getAttribute:@"type"];

    if ([type isEqualToString:sFlashOldMIMEType] || [type length] == 0) {
		CtFMainThreadAssertion();
        [element setAttribute:@"type" value:sFlashNewMIMEType];
    }
}


- (void) convertTypesForContainer: (BOOL) keepIt {
	BOOL success = NO;
	if (keepIt && [self killer]) {
		success = [[self killer] convert];
	}

	if (!success) {
        [self performSelectorOnMainThread:@selector(convertTypesForFlashContainer) withObject:nil waitUntilDone:YES];
	}
	
	[self setIsConverted: YES];
}



// Changes the DOM, thus needs to be called on main thread only.
// Is called from:
//   CTFClickToFlashPlugin -convertTypesForContainer (calls us on main thread)
//   CTFKillerVideo -finishedLookups (called by CTFLoader callback on main thread)
- (void) convertTypesForFlashContainer {
	CtFMainThreadAssertion();
	
	[self revertToOriginalOpacityAttributes];
	[self prepareForConversion];
	
	// Delay this until the end of the event loop, because it may cause self to be deallocated.
	[self performSelector:@selector(_convertTypesForFlashContainerAfterDelay) withObject:nil afterDelay:0.0];
}



// Changes the DOM, thus needs to be called on main thread only.
// Is called from CTFClickToFlashPlugin -convertTypesForFlashContainer.
- (void) _convertTypesForFlashContainerAfterDelay
{
    DOMNodeList *nodeList = nil;
    NSUInteger i;

    [self _convertTypesForElement:[self container]];

    nodeList = [[self container] getElementsByTagName:@"object"];
    for (i = 0; i < [nodeList length]; i++) {
        [self _convertTypesForElement:(DOMElement *)[nodeList item:i]];
    }

    nodeList = [[self container] getElementsByTagName:@"embed"];
    for (i = 0; i < [nodeList length]; i++) {
        [self _convertTypesForElement:(DOMElement *)[nodeList item:i]];
    }
    
    // Remove & reinsert the node to persuade the plugin system to notice the type change:
    id parent = [[self container] parentNode];
    id successor = [[self container] nextSibling];
	
	DOMElement *theContainer = [[self container] retain];
    [parent removeChild:theContainer];
    [parent insertBefore:theContainer refChild:successor];
	[theContainer release];
    [self setContainer:nil];
}

- (void) prepareForConversion
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// notify that this ClickToFlash plugin is going away
	[[CTFMenubarMenuController sharedController] unregisterView: self];
	
	[ self _abortAlert ];
}



- (void) revertToOriginalOpacityAttributes {
	[self performSelectorOnMainThread:@selector(_reallyRevertToOriginalOpacityAttributes) withObject:nil waitUntilDone:YES];
}


// Changes the DOM, thus needs to be called on main thread only.
// Is called from -revertToOriginalOpacityAttributes only
- (void) _reallyRevertToOriginalOpacityAttributes {
	CtFMainThreadAssertion();
	NSString *selfWmode = [[self originalOpacityAttributes] objectForKey:@"self-wmode"];
	if (selfWmode != nil ) {
		[[self container] setAttribute:@"wmode" value:selfWmode];
	}
	
	NSString *currentStyle = [[self container] getAttribute:@"style"];
	NSString *originalSelfStyle = [[self originalOpacityAttributes] objectForKey:@"self-style"];
	if (originalSelfStyle != nil ) {
		if ([currentStyle isEqualToString:[[self originalOpacityAttributes] objectForKey:@"modified-self-style"]]) {
			[[self container] setAttribute:@"style" value:originalSelfStyle];
		}
	}
	
	NSString *parentWmode = [[self originalOpacityAttributes] objectForKey:@"parent-wmode"];
	if (parentWmode != nil ) {
		[(DOMElement *)[[self container] parentNode] setAttribute:@"wmode" value:parentWmode];
	}
	
	NSString *currentParentStyle = [(DOMElement *)[[self container] parentNode] getAttribute:@"style"];
	NSString *originalParentStyle = [[self originalOpacityAttributes] objectForKey:@"parent-style"];
	if (originalParentStyle != nil ) {
		if ([currentParentStyle isEqualToString:[[self originalOpacityAttributes] objectForKey:@"modified-parent-style"]]) {
			[(DOMElement *)[[self container] parentNode] setAttribute:@"style" value:originalParentStyle];
		}
	}
}






#pragma mark -
#pragma mark Full screen - for X.5 and higher only

- (IBAction) enterFullScreen: (id) sender {
	SetSystemUIMode(kUIModeAllSuppressed, 0);
	
	NSWindow * myWindow = [self window];
	NSRect originRect;
	originRect.size = [self frame].size;
	originRect.origin = [[self window] convertBaseToScreen:[self convertPoint:NSZeroPoint toView:nil]];
	CTFFullScreenWindow * myFullScreenWindow = [[[CTFFullScreenWindow alloc]
										   initWithContentRect: originRect
										   styleMask: NSBorderlessWindowMask
										   backing: NSBackingStoreBuffered
										   defer: YES] autorelease];
	[self setFullScreenWindow: myFullScreenWindow];
	[myFullScreenWindow setPlugin: self];

	[myFullScreenWindow setLevel:NSNormalWindowLevel];
	[myFullScreenWindow setContentView:[self containerView]];
	[myFullScreenWindow setTitle: CtFLocalizedString(@"ClickToFlash Fullscreen", @"Fullscreen Window Title")];
	[myFullScreenWindow setHasShadow:YES];
	
	NSRect fullScreenFrame = [[myWindow screen] frame];
	// Use animator to go to full screen as using the window's setFrame:display:animate: just jumps to the full screen size
	[[myFullScreenWindow animator] setFrame:[myFullScreenWindow frameRectForContentRect:fullScreenFrame] display:YES];
	[myFullScreenWindow makeKeyAndOrderFront:nil];

	[[[self buttonsView] viewWithTag: CTFFullScreenButtonTag] setImage: [NSImage imageNamed: NSImageNameExitFullScreenTemplate]];
	[[[self buttonsView] viewWithTag: CTFFullScreenButtonTag] setToolTip: CtFLocalizedString( @"Return to Web Page", @"Tooltip for fullscreenbutton while in fullscreen mode")];
	[[self actionButton] setHidden: YES];

	if ( [self killer] != nil ) {
		[[self killer] startFullScreen];
	}
}



- (IBAction) exitFullScreen: (id) sender {
	if ( [self isFullScreen] ) {
		// destination rect in screen coordinates
		SetSystemUIMode(kUIModeNormal, 0);
		NSRect onScreenRect;
		onScreenRect.origin = [[self window] convertBaseToScreen:[self convertPoint:NSZeroPoint toView:nil]];
		onScreenRect.size = [self frame].size;
		
		if ( [self killer] != nil ) {
			NSRect killerRect = [[self killer] stopFullScreen];
			if ( !NSIsEmptyRect(killerRect) ) {
				onScreenRect = killerRect;
			}
		}
		
//		NSLog(@"ClickToFlash Plugin -exitFullScreen: resize to: %f %f %f %f", onScreenRect.origin.x, onScreenRect.origin.y, onScreenRect.size.width, onScreenRect.size.height);

		// move to new location (don't use an animator here as it works asynchronously and we'd need to time the transfer of the view separately then)
		[[self fullScreenWindow] setFrame:onScreenRect display:YES animate:YES];
		
		// transfer the view back into the browser window
		NSPoint insertionPoint = NSZeroPoint;
		insertionPoint.x = round(([self bounds].size.width - [[fullScreenWindow contentView] bounds].size.width) * 0.5);
		insertionPoint.y = round(([self bounds].size.height - [[fullScreenWindow contentView] bounds].size.height) * 0.5);
		[[fullScreenWindow contentView] setFrameOrigin: insertionPoint];
		[self addSubview:[fullScreenWindow contentView]];
		[[self fullScreenWindow] close];
		[self setFullScreenWindow: nil];
		[[self window] makeKeyAndOrderFront:nil];
		
		[[[self buttonsView] viewWithTag: CTFFullScreenButtonTag] setImage: [NSImage imageNamed: NSImageNameEnterFullScreenTemplate]];
		[[[self buttonsView] viewWithTag: CTFFullScreenButtonTag] setToolTip: CtFLocalizedString( @"Fill entire screen", @"Tooltip for fullscreen button while not in fullscreen mode")];

		[[self actionButton] setHidden: NO];
	}
}



- (IBAction) toggleFullScreen: (id) sender {
	if ([self isFullScreen]) {
		[self exitFullScreen: sender];
	}
	else {
		[self enterFullScreen: sender];
	}	
}



- (NSButton *) addFullScreenButton {
	NSButton * button = nil;
	
	// Only add the button if we have the buttons view (are using 'new style' UI on 10.5 and above) and the button doesn't exist yet.
	if ([self buttonsView] && [[self buttonsView] viewWithTag: CTFFullScreenButtonTag] == nil) {
		button = [CTFButton button];
		[button setImage: [NSImage imageNamed:NSImageNameEnterFullScreenTemplate]]; // variable requires 10.5
		[button setToolTip: CtFLocalizedString( @"Fill entire screen", @"Tooltip for fullscreen button" )];
		[button sizeToFit];
		[button setTag: CTFFullScreenButtonTag];
		[button setTarget: self];
		[button setAction: @selector(toggleFullScreen:)];
		[[self buttonsView] addButton: button];
	}
	
	return button;
}





#pragma mark -
#pragma mark Accessibility


- (BOOL) accessibilityIsIgnored {
	return NO;
}



- (NSArray *) accessibilityAttributeNames {
	NSMutableArray * attributes = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	[attributes addObject: NSAccessibilityDescriptionAttribute];
	return attributes;
}



- (id) accessibilityAttributeValue: (NSString *) attribute {
	id value = nil;
//	NSLog(@"AX: %@", attribute);
	
	if ( [attribute isEqualToString: NSAccessibilityTitleAttribute] ) {
		//	value = [self badgeLabelText];
	}
	else if ( [attribute isEqualToString: NSAccessibilityDescriptionAttribute] ) {
		value = CtFLocalizedString( @"Blocked Flash content", @"CTFClickToFlashPlugin Accessibility: Description");
	}
	else if ( [attribute isEqualToString: NSAccessibilityHelpAttribute] ) {
		value = CtFLocalizedString( @"A film or some other interactive content which is implemented in Flash should appear here. ClickToFlash prevented it from loading automatically. Clicking will start loading it.", @"CTFClickToFlashPlugin Accessibility: Help");
	}
	else if ( [attribute isEqualToString: NSAccessibilityParentAttribute] ){
        id webArea = [[[self superview] accessibilityAttributeValue:NSAccessibilityChildrenAttribute] objectAtIndex:0];
		NSArray * webAreaChildren = [webArea accessibilityAttributeValue:NSAccessibilityChildrenAttribute];
		CTFForEachObject( NSObject , child, webAreaChildren ) {
			NSArray * subChildren = [child accessibilityAttributeValue:NSAccessibilityChildrenAttribute];
			if ([subChildren count] == 1) {
				id firstSubChild = [[child accessibilityAttributeValue:NSAccessibilityChildrenAttribute] objectAtIndex:0];
				if ( firstSubChild == self ) {
					value = child;
					break;
				}
			}
		}
	}
	else if ( [attribute isEqualToString: NSAccessibilityChildrenAttribute] ){
		value = NSAccessibilityUnignoredChildren( [NSArray arrayWithObjects: [self viewWithTag: CTFMainButtonTag], [self actionButton], [self buttonsView], nil] );
	} 
	else if ( [attribute isEqualToString: NSAccessibilityRoleAttribute] ) {
		value = NSAccessibilityGroupRole;
	}
	else if ( [attribute isEqualToString: NSAccessibilityRoleDescriptionAttribute] ) {
		value = NSAccessibilityRoleDescription(NSAccessibilityGroupRole, nil);
	}
	else if ( [attribute isEqualToString: NSAccessibilityTopLevelUIElementAttribute] ) {
		value = [self window];
	}
	else if ( [attribute isEqualToString: NSAccessibilityWindowAttribute] ) {
		value = [self window];
	}
	else if ( [attribute isEqualToString: @"AXBlockQuoteLevel"] ) { // does this make any sense? Copying the name and value from what I saw in Accessibility Inspector.
		value = [NSNumber numberWithInt: 0];
	}
	else {
		value =  [super accessibilityAttributeValue:attribute];
	}
	
	return value;
}




#pragma mark -
#pragma mark Preferences

+ (void) _migratePrefsToExternalFile
{
	NSArray *parasiticDefaultsNameArray = [NSArray arrayWithObjects:@"ClickToFlash_pluginEnabled",
										   @"ClickToFlash_useYouTubeH264",
										   @"ClickToFlash_autoLoadInvisibleViews",
										   @"ClickToFlash_sifrMode",
										   @"ClickToFlash_checkForUpdatesOnFirstLoad",
										   @"ClickToFlash_siteInfo",
										   nil];
	
	NSArray *externalDefaultsNameArray = [NSArray arrayWithObjects:sPluginEnabledDefaultsKey,
										  sUseYouTubeH264DefaultsKey,
										  sAutoLoadInvisibleFlashViewsDefaultsKey,
										  @"sifrMode",
										  @"checkForUpdatesOnFirstLoad",
										  @"siteInfo",
										  nil];
	
	NSMutableDictionary *externalFileDefaults = [[CTFUserDefaultsController standardUserDefaults] dictionaryRepresentation];
	
	[[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.github.rentzsch.clicktoflash"];
	unsigned int i;
	for (i = 0; i < [parasiticDefaultsNameArray count]; i++) {
		NSString *currentParasiticDefault = [parasiticDefaultsNameArray objectAtIndex:i];
		id prefValue = [[NSUserDefaults standardUserDefaults] objectForKey:currentParasiticDefault];
		if (prefValue) {
			NSString *externalPrefDefaultName = [externalDefaultsNameArray objectAtIndex:i];
			id existingExternalPref = [[CTFUserDefaultsController standardUserDefaults] objectForKey:externalPrefDefaultName];
			if (! existingExternalPref) {
				// don't overwrite existing external preferences
				[externalFileDefaults setObject:prefValue forKey:externalPrefDefaultName];
			} else {
				if ([currentParasiticDefault isEqualToString:@"ClickToFlash_siteInfo"]) {
					// merge the arrays of whitelisted sites, in case they're not identical
					
					NSMutableArray *combinedWhitelist = [NSMutableArray arrayWithArray:prefValue];
					[combinedWhitelist addObjectsFromArray:existingExternalPref];
					[externalFileDefaults setObject:combinedWhitelist forKey:externalPrefDefaultName];
					
					// because people named Kevin Ballard messed up their preferences file and somehow
					// managed to retain ClickToFlash_siteInfo in their com.github plist file
					[externalFileDefaults removeObjectForKey:currentParasiticDefault];
				}
			}
			// eliminate the parasitic default, regardless of whether we transferred them or not
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:currentParasiticDefault];
		}
	}
	[[NSUserDefaults standardUserDefaults] removeSuiteNamed:@"com.github.rentzsch.clicktoflash"];
}


+ (void) _uniquePrefsFileWhitelist
{
	NSArray *siteInfoArray = [[CTFUserDefaultsController standardUserDefaults] arrayForKey:@"siteInfo"];
	NSSet *siteInfoSet = [NSSet setWithArray:siteInfoArray];
	
	[[CTFUserDefaultsController standardUserDefaults] setValue:[siteInfoSet allObjects] forKeyPath:@"values.siteInfo"];
}


+ (void) _addApplicationWhitelistArrayToPrefsFile
{
	CTFUserDefaultsController *standardUserDefaults = [CTFUserDefaultsController standardUserDefaults];
	NSArray *applicationWhitelist = [standardUserDefaults arrayForKey:sApplicationWhitelist];
	if (! applicationWhitelist) {
		// add an empty array to the plist file so people know exactly where to
		// whitelist apps
		
		[standardUserDefaults setObject:[NSArray array] forKey:sApplicationWhitelist];
	}
}





#pragma mark -
#pragma mark Accessors

- (WebView *) webView {
    return _webView;
}

- (void) setWebView: (WebView *) newValue {
    // Not retained, because the WebView owns the plugin, so we'll get a retain cycle.
    _webView = newValue;
}



- (DOMElement *) container {
    return _container;
}

- (void) setContainer: (DOMElement *) newValue {
    [newValue retain];
    [_container release];
    _container = newValue;
}



- (NSURL *) baseURL {
    return _baseURL;
}

- (void) setBaseURL: (NSURL *) newValue {
    [newValue retain];
    [_baseURL release];
    _baseURL = newValue;
}

- (NSString *) host {
    return [[self baseURL] host];
}



- (NSDictionary *) attributes {
    return _attributes;
}

- (void) setAttributes: (NSDictionary *) newValue {
    [newValue retain];
    [_attributes release];
    _attributes = newValue;
}



- (NSString *) src {
    return _src;
}

- (void) setSrc: (NSString *) newValue {
    [newValue retain];
    [_src release];
    _src = newValue;
}



- (NSDictionary *) originalOpacityAttributes {
    return _originalOpacityAttributes;
}

- (void) setOriginalOpacityAttributes: (NSDictionary *) newValue {
    [newValue retain];
    [_originalOpacityAttributes release];
    _originalOpacityAttributes = newValue;
}



- (BOOL) isImmediatelyConverted {
	return isImmediatelyConverted;
}

- (void) setIsImmediatelyConverted: (BOOL) newIsImmediatelyConverted {
	isImmediatelyConverted = newIsImmediatelyConverted;
}



- (BOOL) isConverted {
	return isConverted;
}

- (void) setIsConverted: (BOOL) newIsConverted {
	[[self mainButton] setHidden: newIsConverted];
	isConverted = newIsConverted;
}



- (NSView *) containerView {
	return containerView;
}

- (void) setContainerView: (NSView *) newContainerView {
	[newContainerView retain];
	[containerView release];
	containerView = newContainerView;
}


- (CTFMainButton *) mainButton {
	return mainButton;
}

- (void) setMainButton: (CTFMainButton *) newMainButton {
	[newMainButton retain];
	[mainButton release];
	mainButton = newMainButton;
}


- (NSView *) buttonsContainer {
	return buttonsContainer;
}

- (void) setButtonsContainer: (NSView *) newButtonsContainer {
	[newButtonsContainer retain];
	[buttonsContainer release];
	buttonsContainer = newButtonsContainer;
}


- (CTFActionButton *)actionButton {
	return actionButton;
}

- (void)setActionButton:(CTFActionButton *)newActionButton {
	[newActionButton retain];
	[actionButton release];
	actionButton = newActionButton;
}


- (CTFButtonsView *) buttonsView {
	return buttonsView;
}

- (void) setButtonsView: (CTFButtonsView *) newButtonsView {
	[newButtonsView retain];
	[buttonsView release];
	buttonsView = newButtonsView;
}



- (CTFFullScreenWindow *) fullScreenWindow {
	return fullScreenWindow;
}

- (void) setFullScreenWindow: (CTFFullScreenWindow *) newFullScreenWindow {
	[newFullScreenWindow retain];
	[[fullScreenWindow retain] autorelease];
	fullScreenWindow = newFullScreenWindow;
}

- (BOOL) isFullScreen {
	SystemUIMode outMode;
	GetSystemUIMode(&outMode, NULL);
	return (outMode != kUIModeNormal);
}



- (CTFKiller *) killer {
	return killer;
}

- (void) setKiller: (CTFKiller *) newKiller {
	[newKiller retain];
	[killer release];
	killer = newKiller;
}



- (NSURL *) previewURL {
	return previewURL;
}

- (void) setPreviewURL: (NSURL *) newPreviewURL {
	[newPreviewURL retain];
	[previewURL release];
	previewURL = newPreviewURL;
	
	if (previewURL != nil) {
		CTFLoader * loader = [CTFLoader loaderWithURL: newPreviewURL
											 delegate: self
											 selector: @selector(receivedPreviewImage:)];
		[self setPreviewImageLoader: loader];
		[loader start];
	}
}



- (NSImage *) previewImage {
    return previewImage;
}

- (void) setPreviewImage: (NSImage *) newPreviewImage {
	[newPreviewImage retain];
	[previewImage release];
	previewImage = newPreviewImage;
	
	[[self mainButton] setNeedsDisplay: YES];
}



- (CTFLoader *) previewImageLoader {
	return previewImageLoader;
}

- (void) setPreviewImageLoader: (CTFLoader *) newPreviewImageLoader {
	[newPreviewImageLoader retain];
	[previewImageLoader cancel];
	[previewImageLoader release];
	previewImageLoader = newPreviewImageLoader;
}

- (void) receivedPreviewImage: (CTFLoader*) loader {
	NSImage * image = [[[NSImage alloc] initWithData: [loader data]] autorelease];
	if (image != nil) {
		[self setPreviewImage: image];
	}
	[self setPreviewImageLoader: nil];
}

@end
