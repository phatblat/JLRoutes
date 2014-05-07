/*
 Copyright (c) 2013, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "JLRoutes.h"
#import "NSString+JLRoutesAdditions.h"


static BOOL verboseLoggingEnabled = NO;
static BOOL shouldDecodePlusSymbols = YES;


@interface JLRoutes ()

+ (NSMutableDictionary *)routesControllerMap;

@end


@implementation JLRoutes

/*+ (NSString *)fullRoutingTableDescription
{
	NSMutableString *descriptionString = [NSMutableString stringWithString:@"JLRoutes \n"];
	
	for (NSString *routesNamespace in routeControllersMap) {
		JLRoutesController *routesController = routeControllersMap[routesNamespace];
		[descriptionString appendFormat:@"\"%@\":\n%@\n\n", routesController.scheme, routesController.allRoutes];
	}
	
	return descriptionString;
}*/

#pragma mark - Schemes

+ (NSMutableDictionary *)routesControllerMap
{
	static NSMutableDictionary *sharedRoutesControllerMap = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedRoutesControllerMap = [[NSMutableDictionary alloc] init];
	});
	return sharedRoutesControllerMap;
}

+ (JLRoutesController *)globalRoutes
{
	return [self routesForScheme:JLRoutesGlobalScheme];
}

+ (JLRoutesController *)routesForScheme:(NSString *)scheme
{
	NSParameterAssert(scheme != nil);
	
	NSMutableDictionary *routesControllerMap = [self routesControllerMap];
	JLRoutesController *routesController = routesControllerMap[scheme];
	
	if (!routesControllerMap[scheme]) {
		routesController = [[JLRoutesController alloc] initWithScheme:scheme];
		[self registerRoutesController:routesController];
	}
	
	return routesController;
}

+ (void)registerRoutesController:(JLRoutesController *)routesController
{
	[self routesControllerMap][routesController.scheme] = routesController;
}

+ (void)unregisterRoutesController:(JLRoutesController *)routesController
{
	[[self routesControllerMap] removeObjectForKey:routesController.scheme];
}

+ (void)unregisterRoutesControllerForScheme:(NSString *)scheme
{
	[[self routesControllerMap] removeObjectForKey:scheme];
}

#pragma mark - Routing

+ (BOOL)routeURL:(NSURL *)URL
{
	return [self routeURL:URL withParameters:nil];
}

+ (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
	NSParameterAssert(URL != nil);
	
	if (!URL) {
		return NO;
	}
	
	// figure out which routes controller to use based on the scheme
	JLRoutesController *routesController = [self routesControllerMap][[URL scheme]] ?: [self globalRoutes];
	return [routesController routeURL:URL withParameters:parameters];
}

+ (BOOL)canRouteURL:(NSURL *)URL
{
    return [self canRouteURL:URL withParameters:nil];
}

+ (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    return [[self globalRoutes] canRouteURL:URL withParameters:parameters];
}

+ (void)reset
{
	[[self routesControllerMap] removeAllObjects];
}

#pragma mark - Settings

+ (void)setShouldDecodePlusSymbols:(BOOL)shouldDecode
{
	shouldDecodePlusSymbols = shouldDecode;
}

+ (BOOL)shouldDecodePlusSymbols
{
	return shouldDecodePlusSymbols;
}

+ (void)setVerboseLoggingEnabled:(BOOL)loggingEnabled
{
	verboseLoggingEnabled = loggingEnabled;
}

+ (BOOL)isVerboseLoggingEnabled
{
	return verboseLoggingEnabled;
}

@end
