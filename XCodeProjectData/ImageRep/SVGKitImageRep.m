//
//  SVGKitImageRep.m
//  SVGKit
//
//  Created by C.W. Betts on 12/5/12.
//
//

//This will cause problems...
#define Comment AIFFComment
#include <CoreServices/CoreServices.h>
#undef Comment

#import "SVGKit.h"

#import "SVGKitImageRep.h"

@interface SVGKImage ()
-(void) renderToContext:(CGContextRef) context antiAliased:(BOOL) shouldAntialias curveFlatnessFactor:(CGFloat) multiplyFlatness interpolationQuality:(CGInterpolationQuality) interpolationQuality flipYaxis:(BOOL) flipYaxis;
@end

@interface SVGKitImageRep ()
- (id)initWithSVGSource:(SVGKSource*)theSource;

@property (nonatomic, retain, readwrite) SVGKImage *image;
@end

@implementation SVGKitImageRep

- (NSData *)TIFFRepresentation
{
	return [self.image.bitmapImageRep TIFFRepresentation];
}

- (NSData *)TIFFRepresentationUsingCompression:(NSTIFFCompression)comp factor:(float)factor
{
	return [self.image.bitmapImageRep TIFFRepresentationUsingCompression:comp factor:factor];
}

+ (NSArray *)imageUnfilteredFileTypes
{
	static NSArray *types = nil;
	if (types == nil) {
		types = [[NSArray alloc] initWithObjects:@"svg", nil];
	}
	return types;
}

+ (NSArray *)imageUnfilteredTypes
{
	static NSArray *UTItypes = nil;
	if (UTItypes == nil) {
		UTItypes = [[NSArray alloc] initWithObjects:@"public.svg-image", nil];
	}
	return UTItypes;
}

+ (NSArray *)imageUnfilteredPasteboardTypes
{
	/* TODO */
	return nil;
}

+ (BOOL)canInitWithData:(NSData *)d
{
	SVGKParseResult *parseResult = nil;
	@autoreleasepool {
		parseResult = [[SVGKParser parseSourceUsingDefaultSVGKParser:[SVGKSource sourceFromData:d]] retain];
	}
	if (parseResult == nil) {
		return NO;
	}
	if (!parseResult.parsedDocument) {
		[parseResult release];
		return NO;
	}
	[parseResult release];
	return YES;
}

+ (NSImageRep *)imageRepWithData:(NSData *)d
{
	return [[[self alloc] initWithData:d] autorelease];
}

+ (id)imageRepWithContentsOfFile:(NSString *)filename
{
	return [[[self alloc] initWithContentsOfFile:filename] autorelease];
}

+ (id)imageRepWithContentsOfURL:(NSURL *)url
{
	return [[[self alloc] initWithContentsOfURL:url] autorelease];
}

+ (void)load
{
	[NSImageRep registerImageRepClass:[SVGKitImageRep class]];
}

- (id)initWithData:(NSData *)theData
{
	return [self initWithSVGSource:[SVGKSource sourceFromData:theData]];
}

- (id)initWithContentsOfURL:(NSURL *)theURL
{
	return [self initWithSVGSource:[SVGKSource sourceFromURL:theURL]];
}

- (id)initWithContentsOfFile:(NSString *)thePath
{
	return [self initWithSVGSource:[SVGKSource sourceFromFilename:thePath]];
}

- (id)initWithSVGString:(NSString *)theString
{
	return [self initWithSVGSource:[SVGKSource sourceFromContentsOfString:theString]];
}

static NSDateFormatter* debugDateFormatter()
{
	static NSDateFormatter* theFormatter = nil;
	if (theFormatter == nil) {
		theFormatter = [[NSDateFormatter alloc] init];
		[theFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[theFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss:SSS"];
	}
	return theFormatter;
}

- (id)initWithSVGSource:(SVGKSource*)theSource
{
	if (self = [super init]) {
		self.image = [SVGKImage imageWithSource:theSource];
		if (self.image == nil) {
			[self autorelease];
			return nil;
		}
		BOOL hasGrad = ![SVGKFastImageView svgImageHasNoGradients:self.image];
		BOOL hasText = ![SVGKFastImageView svgImageHasNoText:self.image];

		if (hasGrad || hasText) {
			NSDateFormatter *formatter = debugDateFormatter();
			
			NSString *errstuff = nil;
			
			if (hasGrad) {
				errstuff = @"gradients";
				if (hasText) {
					errstuff = [errstuff stringByAppendingString:@" and text"];
				}
			} else if (hasText) {
				errstuff = @"text";
			}
			
			if (errstuff == nil) {
				//We shouldn't get here!
				errstuff = @"";
			}
			
			fprintf(stderr, "%s SVGKitImageRep: the image \"%s\" might have problems rendering correctly due to %s.\n", [[formatter stringFromDate:[NSDate date]] UTF8String], [[self.image description] UTF8String], [errstuff UTF8String]);
		}
		
		if (![self.image hasSize]) {
			self.image.size = CGSizeMake(32, 32);
		}
		
		[self setColorSpaceName:NSCalibratedRGBColorSpace];
		[self setAlpha:YES];
		[self setBitsPerSample:0];
		[self setOpaque:NO];
		{
			NSSize renderSize = self.image.size;
			[self setSize:renderSize];
			[self setPixelsHigh:ceil(renderSize.height)];
			[self setPixelsWide:ceil(renderSize.width)];
		}
	}
	return self;
}

- (void)dealloc
{
	self.image = nil;
	
	[super dealloc];
}

- (BOOL)draw
{
	//Just in case someone resized the image rep.
	NSSize scaledSize = self.size;
	if (!CGSizeEqualToSize(self.image.size, scaledSize)) {
		[self.image scaleToFitInside:scaledSize];
	}
	if ([self.image respondsToSelector:@selector(renderToContext:antiAliased:curveFlatnessFactor:interpolationQuality:flipYaxis:)]) {
		//We'll use this because it's probably faster, and we're drawing almost directly to the graphics context...
		CGContextRef imRepCtx = [[NSGraphicsContext currentContext] graphicsPort];
		CGLayerRef layerRef = CGLayerCreateWithContext(imRepCtx, self.size, NULL);
		if (!layerRef) {
			return NO;
		}
		
		CGContextRef layerCont = CGLayerGetContext(layerRef);
		CGContextSaveGState(layerCont);
		[self.image renderToContext:layerCont antiAliased:YES curveFlatnessFactor:1.0 interpolationQuality:kCGInterpolationDefault flipYaxis:YES];
		CGContextRestoreGState(layerCont);
		
		CGContextDrawLayerAtPoint(imRepCtx, NSZeroPoint, layerRef);
		CGLayerRelease(layerRef);
	} else {
		//...But should the method be removed in a future version, fall back to the old method
		NSImage *tmpImage = self.image.NSImage;
		if (!tmpImage) {
			return NO;
		}
		
		NSRect imageRect;
		imageRect.size = self.size;
		imageRect.origin = NSZeroPoint;
		
		[tmpImage drawAtPoint:NSZeroPoint fromRect:imageRect operation:NSCompositeCopy fraction:1];
	}
	
	return YES;
}

@end

@implementation SVGKitImageRep (deprecated)

#define DEPRECATE_WARN_ONCE(NewMethodSel) { \
static BOOL HasBeenWarned = NO; \
if (HasBeenWarned == NO) \
{ \
NSDateFormatter *formatter = debugDateFormatter(); \
fprintf(stderr, "%s SVGKImageRep: -[SVGKitImageRep %s] has been deprecated, use -[SVGKitImageRep %s] instead.\n", [[formatter stringFromDate:[NSDate date]] UTF8String], sel_getName(_cmd), sel_getName(NewMethodSel)); \
HasBeenWarned = YES; \
} \
}

- (id)initWithPath:(NSString *)thePath
{
	DEPRECATE_WARN_ONCE(@selector(initWithContentsOfPath:));
	return [self initWithContentsOfFile:thePath];
}

- (id)initWithURL:(NSURL *)theURL
{
	DEPRECATE_WARN_ONCE(@selector(initWithContentsOfURL:));
	return [self initWithContentsOfURL:theURL];
}

#undef DEPRECATE_WARN_ONCE

@end
