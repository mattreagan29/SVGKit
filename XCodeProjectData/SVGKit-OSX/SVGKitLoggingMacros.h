//
//  SVGKitLoggingMacros.h
//  SVGKit
//
//  Created by Matt Reagan on 4/9/15.
//  Copyright (c) 2015 C.W. Betts. All rights reserved.
//

#ifndef SVGKit_SVGKitLoggingMacros_h
#define SVGKit_SVGKitLoggingMacros_h

	//	======================================================================================= //
	/*	CocoaLumberjack wrappers. For now we're taking the easy approach to disabling
	 the CocoaLumberjack dependency by simply overriding the DD* macros to behave
	 either as NOP's or as standard NSLog's (in the future these could also easily be funneled
	 into our own logging if needed etc.). Overriding these macros shouldn't ever
	 be an issue unless for some reason we decide to link Storyline against CocoaLumberjack
	 in which case that solves our problem anyways and these can be removed. */

		#define DDLogVerbose(frmt, ...)
		#define DDLogInfo(frmt, ...)
		#define DDLogTrace(frmt, ...)
		#define DDLogWarn(frmt, ...)
		#define DDLogError NSLog
	//	======================================================================================= //

#endif
