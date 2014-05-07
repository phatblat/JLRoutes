/*
 Copyright (c) 2013, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "JLRoutesController.h"
#import "JLRouteDefinition.h"


/*!
	@class JLRoutes
	@discussion This abstract class provides methods 
 */

@interface JLRoutes : NSObject

/// Returns the global routing namespace (this is used by the +addRoute methods by default)
+ (JLRoutesController *)globalRoutes;

/// Returns a routing namespace for the given scheme
+ (JLRoutesController *)routesForScheme:(NSString *)scheme;
+ (void)registerRoutesController:(JLRoutesController *)routesController;
+ (void)unregisterRoutesController:(JLRoutesController *)routesController;
+ (void)unregisterRoutesControllerForScheme:(NSString *)scheme;

/// Routes a URL, calling handler blocks (for patterns that match URL) until one returns YES
+ (BOOL)routeURL:(NSURL *)URL;

/// Routes a URL, calling handler blocks (for patterns that match URL) until one returns YES, optionally specifying add'l parameters
+ (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters;

/// Returns whether a route exists for a URL
+ (BOOL)canRouteURL:(NSURL *)URL;

/// Removes all routes and unregisters all schemes
+ (void)reset;

/// Prints the entire routing table
//+ (NSString *)fullRoutingTableDescription;

/// Tells JLRoutes that it should manually replace '+' in parsed values to ' '. Defaults to YES.
+ (void)setShouldDecodePlusSymbols:(BOOL)shouldDeecode;
+ (BOOL)shouldDecodePlusSymbols;

/// Allows configuration of verbose logging. Default is NO. This is mostly just helpful with debugging.
+ (void)setVerboseLoggingEnabled:(BOOL)loggingEnabled;
+ (BOOL)isVerboseLoggingEnabled;

@end
