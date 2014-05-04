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


static NSMutableDictionary *routeControllersMap = nil;
static BOOL verboseLoggingEnabled = NO;
static BOOL shouldDecodePlusSymbols = YES;


@interface JLRoutes ()

@property (nonatomic, strong) NSMutableArray *routes;
@property (nonatomic, strong) NSString *namespaceKey;

+ (void)verboseLogWithFormat:(NSString *)format, ...;
+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController parameters:(NSDictionary *)parameters;
- (BOOL)isGlobalRoutesController;

@end


@interface _JLRoute : NSObject

@property (nonatomic, weak) JLRoutes *parentRoutesController;
@property (nonatomic, strong) NSString *pattern;
@property (nonatomic, strong) BOOL (^block)(NSDictionary *parameters);
@property (nonatomic, assign) NSUInteger priority;
@property (nonatomic, strong) NSArray *patternPathComponents;
@property (nonatomic, strong) NSArray *optionalComponentSequences;
@property (nonatomic, assign) NSUInteger optionalComponentsCount;

- (instancetype)initWithPattern:(NSString *)pattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *))handlerBlock;
- (NSDictionary *)parametersForURL:(NSURL *)URL components:(NSArray *)URLComponents;
- (void)parsePattern;

@end


@implementation _JLRoute

- (instancetype)initWithPattern:(NSString *)pattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	if ((self = [super init])) {
		self.block = handlerBlock;
		self.priority = priority;
		self.pattern = pattern;
		[self parsePattern];
	}
	return self;
}

- (void)parsePattern
{
	NSString *patternString = self.pattern;
	NSRange optionalRange = NSMakeRange(NSNotFound, NSNotFound);
	optionalRange = [self.pattern JLRoutes_innermostRangeBetweenStartString:@"(" endString:@")"];
	
	if (optionalRange.location != NSNotFound) {
		// this pattern contains optional parameter definitions
		// for each 'sequence' of option params, store them in their own array within a wrapper array
		//
		// this is to handle routes like this: /test(/:optionalParam1(/:optionalParam2/foo(/:optionalParam3)))
		// the idea is to take the above route and create this data structure:
		// [[optionalParam1], [optionalParam2, foo], [optionalParam3]]
		//
		// this way we can require specific sequences (such as requiring both optionalParam2 and foo) without matching subsequent optional sections.
		
		NSMutableArray *optionalParamSequences = [NSMutableArray array];
		NSMutableString *modifiedPatternString = [patternString mutableCopy];
		
		// loop until we run out of optional ranges (or hit a broken one)
		while (optionalRange.location != NSNotFound) {
			NSString *optionalSubstring = [modifiedPatternString substringWithRange:optionalRange];
			NSArray *optionalComponents = [optionalSubstring JLRoutes_filteredPathComponents];
			[optionalParamSequences insertObject:optionalComponents atIndex:0];
			self.optionalComponentsCount += [optionalComponents count];
			
			[modifiedPatternString deleteCharactersInRange:NSMakeRange(optionalRange.location - 1, optionalRange.length + 2)];
			optionalRange = [modifiedPatternString JLRoutes_innermostRangeBetweenStartString:@"(" endString:@")"];
		}
		
		self.optionalComponentSequences = [NSArray arrayWithArray:optionalParamSequences]; // force immutability
		patternString = [NSString stringWithString:modifiedPatternString]; // update the pattern string while also forcing immutability
	}
	self.patternPathComponents = [patternString JLRoutes_filteredPathComponents];
}

- (NSDictionary *)parametersForURL:(NSURL *)URL components:(NSArray *)URLComponents
{
	NSDictionary *routeParameters = nil;
	
	if (!self.patternPathComponents) {
		[self parsePattern];
	}
	
	// gather facts
	BOOL componentCountsEqual = self.patternPathComponents.count == URLComponents.count;
	BOOL routeContainsWildcard = !NSEqualRanges([self.pattern rangeOfString:@"*"], NSMakeRange(NSNotFound, 0));
	BOOL patternContainsOptionalComponents = [self.optionalComponentSequences count] > 0;
	
	NSArray *lastOptionalSequence = [self.optionalComponentSequences lastObject];
	BOOL isLastOptionalComponentWildcard = [[lastOptionalSequence lastObject] isEqualToString:@"*"];
	
	// if theres a component count mismatch, but this pattern has optional components, figure out if it could still be a match
	if (!componentCountsEqual && patternContainsOptionalComponents) {
		NSUInteger componentMismatchCount = [URLComponents count] - [self.patternPathComponents count];
		
		if (componentMismatchCount <= self.optionalComponentsCount || isLastOptionalComponentWildcard) {
			componentCountsEqual = YES;
		}
	}
	
	// if valid, move into identifying a match
	if (componentCountsEqual || routeContainsWildcard) {
		NSUInteger componentIndex = 0;
		NSMutableDictionary *variables = [NSMutableDictionary dictionary];
		NSArray *patternComponents = self.patternPathComponents;
		BOOL isMatch = YES;
		
		if (patternContainsOptionalComponents) {
			// the pattern contains optional stuff - let's see if the sequence mapping lines up with these URL components
			NSUInteger componentMismatchCount = [URLComponents count] - [self.patternPathComponents count];
			NSUInteger optionalComponentsIndex = 0;
			NSMutableArray *optionalComponents = [NSMutableArray array];
			
			while (componentMismatchCount > 0 && optionalComponentsIndex < [self.optionalComponentSequences count]) {
				NSArray *optionalComponentSequence = self.optionalComponentSequences[optionalComponentsIndex];
				NSUInteger sequenceComponentCount = [optionalComponentSequence count];
				
				if ([[optionalComponentSequence lastObject] isEqualToString:@"*"]) {
					sequenceComponentCount--;
				}
				
				if (componentMismatchCount >= sequenceComponentCount) {
					componentMismatchCount -= sequenceComponentCount;
					[optionalComponents addObjectsFromArray:optionalComponentSequence];
				} else {
					// not enough URL components to correctly fulfill the mapping of sequences, so this isn't a match
					break;
				}
				optionalComponentsIndex++;
			}
			
			if (componentMismatchCount == 0 || isLastOptionalComponentWildcard) {
				patternComponents = [patternComponents arrayByAddingObjectsFromArray:optionalComponents];
			} else {
				// couldn't resolve the mismatch in the above while loop - this isn't a match
				isMatch = NO;
			}
		}
		
		// now that we've identified a possible match, move component by component to check if it's a match
		if (isMatch) {
			for (NSString *patternComponent in patternComponents) {
				NSString *URLComponent = nil;
				if (componentIndex < [URLComponents count]) {
					URLComponent = URLComponents[componentIndex];
				} else if ([patternComponent isEqualToString:@"*"]) { // match /foo by /foo/*
					URLComponent = [URLComponents lastObject];
				}
				
				if ([patternComponent hasPrefix:@":"]) {
					// this component is a variable
					NSString *variableName = [patternComponent substringFromIndex:1];
					NSString *variableValue = URLComponent;
					if ([variableName length] > 0) {
						variables[variableName] = [variableValue JLRoutes_URLDecodedStringReplacingPlusSymbols:shouldDecodePlusSymbols];
					}
				} else if ([patternComponent isEqualToString:@"*"]) {
					// match wildcards
					variables[kJLRouteWildcardComponentsKey] = [URLComponents subarrayWithRange:NSMakeRange(componentIndex, URLComponents.count-componentIndex)];
					isMatch = YES;
					break;
				} else if (![patternComponent isEqualToString:URLComponent]) {
					// a non-variable component did not match, so this route doesn't match up - on to the next one
					isMatch = NO;
					break;
				}
				componentIndex++;
			}
		}
		
		if (isMatch) {
			routeParameters = variables;
		}
	}
	
	return routeParameters;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"JLRoute %@:/%@ (priority %@)", ([self.parentRoutesController.namespaceKey isEqualToString:kJLRoutesGlobalNamespaceKey] ? @"global" : self.parentRoutesController.namespaceKey), self.pattern, @(self.priority)];
}

@end


@implementation JLRoutes

- (id)init
{
	if ((self = [super init])) {
		self.routes = [NSMutableArray array];
	}
	return self;
}

- (NSString *)description
{
	return [self.routes description];
}

+ (NSString *)description
{
	NSMutableString *descriptionString = [NSMutableString stringWithString:@"JLRoutes \n"];
	
	for (NSString *routesNamespace in routeControllersMap) {
		JLRoutes *routesController = routeControllersMap[routesNamespace];
		[descriptionString appendFormat:@"\"%@\":\n%@\n\n", routesController.namespaceKey, routesController.routes];
	}
	
	return descriptionString;
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

#pragma mark - Routing API

+ (instancetype)globalRoutes
{
	return [self routesForScheme:kJLRoutesGlobalNamespaceKey];
}

+ (instancetype)routesForScheme:(NSString *)scheme
{
	NSParameterAssert(scheme != nil);
	
	JLRoutes *routesController = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		routeControllersMap = [[NSMutableDictionary alloc] init];
	});
	
	if (!routeControllersMap[scheme]) {
		routesController = [[JLRoutes alloc] init];
		routesController.namespaceKey = scheme;
		routeControllersMap[scheme] = routesController;
	}
	
	routesController = routeControllersMap[scheme];
	
	return routesController;
}

+ (void)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
	[[self globalRoutes] addRoute:routePattern handler:handlerBlock];
}

+ (void)addRoutes:(NSArray *)routePatterns handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	for (NSString *route in routePatterns) {
		[self addRoute:route handler:handlerBlock];
	}
}

+ (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
	[[self globalRoutes] addRoute:routePattern priority:priority handler:handlerBlock];
}

+ (void)addRoutes:(NSArray *)routePatterns priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	for (NSString *route in routePatterns) {
		[self addRoute:route priority:priority handler:handlerBlock];
	}
}

- (void)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
	[self addRoute:routePattern priority:0 handler:handlerBlock];
}

- (void)addRoutes:(NSArray *)routePatterns handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	for (NSString *route in routePatterns) {
		[self addRoute:route handler:handlerBlock];
	}
}

- (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
	NSParameterAssert(routePattern != nil);
	
	_JLRoute *route = [[_JLRoute alloc] initWithPattern:routePattern priority:priority handler:handlerBlock];
	route.parentRoutesController = self;
	
	if (!route.block) {
		route.block = [^BOOL (NSDictionary *params) {
			return YES;
		} copy];
	}
	
	if (priority == 0) {
		[self.routes addObject:route];
	} else {
		NSArray *existingRoutes = self.routes;
		NSUInteger index = 0;
		for (_JLRoute *existingRoute in existingRoutes) {
			if (existingRoute.priority < priority) {
				[self.routes insertObject:route atIndex:index];
				break;
			}
			index++;
		}
	}
}

- (void)addRoutes:(NSArray *)routePatterns priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	for (NSString *route in routePatterns) {
		[self addRoute:route priority:priority handler:handlerBlock];
	}
}

+ (void)removeRoute:(NSString *)routePattern
{
	[[JLRoutes globalRoutes] removeRoute:routePattern];
}

- (void)removeRoute:(NSString *)routePattern
{
	NSParameterAssert(routePattern != nil);
	
	if (![routePattern hasPrefix:@"/"]) {
		routePattern = [NSString stringWithFormat:@"/%@", routePattern];
	}
	
	NSInteger routeIndex = NSNotFound;
	NSInteger index = 0;
	
	for (_JLRoute *route in self.routes) {
		if ([route.pattern isEqualToString:routePattern]) {
			routeIndex = index;
			break;
		}
		index++;
	}
	
	if (routeIndex != NSNotFound) {
		[self.routes removeObjectAtIndex:(NSUInteger)routeIndex];
	}
}

+ (void)removeAllRoutes
{
	[[JLRoutes globalRoutes] removeAllRoutes];
}

- (void)removeAllRoutes
{
	[self.routes removeAllObjects];
}

+ (void)unregisterRouteScheme:(NSString *)scheme
{
	NSParameterAssert(scheme != nil);
	
	[routeControllersMap removeObjectForKey:scheme];
}

+ (BOOL)routeURL:(NSURL *)URL
{
	return [self routeURL:URL withParameters:nil executeRouteBlock:YES];
}

+ (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    return [self routeURL:URL withParameters:parameters executeRouteBlock:YES];
}

+ (BOOL)canRouteURL:(NSURL *)URL
{
    return [self routeURL:URL withParameters:nil executeRouteBlock:NO];
}

+ (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    return [self routeURL:URL withParameters:parameters executeRouteBlock:NO];
}

+ (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters executeRouteBlock:(BOOL)execute
{
	NSParameterAssert(URL != nil);
	
	if (!URL) {
		return NO;
	}

	// figure out which routes controller to use based on the scheme
	JLRoutes *routesController = routeControllersMap[[URL scheme]] ?: [self globalRoutes];

	return [self routeURL:URL withController:routesController parameters:parameters executeBlock:execute];
}

- (BOOL)routeURL:(NSURL *)URL
{
	return [[self class] routeURL:URL withController:self];
}

- (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
	return [[self class] routeURL:URL withController:self parameters:parameters];
}

- (BOOL)canRouteURL:(NSURL *)URL
{
	return [[self class] routeURL:URL withController:self parameters:nil executeBlock:NO];
}

- (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
	return [[self class] routeURL:URL withController:self parameters:parameters executeBlock:NO];
}

#pragma mark - Subscripting

- (void)setObject:(id)handlerBlock forKeyedSubscript:(NSString *)routePatten
{
	[self addRoute:routePatten handler:handlerBlock];
}

#pragma mark - SPI

+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController
{
    return [self routeURL:URL withController:routesController parameters:nil executeBlock:YES];
}

+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController parameters:(NSDictionary *)parameters
{
    return [self routeURL:URL withController:routesController parameters:parameters executeBlock:YES];
}

+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController parameters:(NSDictionary *)parameters executeBlock:(BOOL)executeBlock
{
	[self verboseLogWithFormat:@"Trying to route URL %@", URL];
	BOOL didRoute = NO;
	NSArray *routes = routesController.routes;
	NSDictionary *queryParameters = [URL.query JLRoutes_URLParameterDictionaryReplacePlusSymbols:shouldDecodePlusSymbols];
	[self verboseLogWithFormat:@"Parsed query parameters: %@", queryParameters];

	NSDictionary *fragmentParameters = [URL.fragment JLRoutes_URLParameterDictionaryReplacePlusSymbols:shouldDecodePlusSymbols];
	[self verboseLogWithFormat:@"Parsed fragment parameters: %@", fragmentParameters];

	// break the URL down into path components and filter out any leading/trailing slashes from it
	NSArray *pathComponents = [(URL.pathComponents ?: @[]) filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF like '/'"]];
	
	if ([URL.host rangeOfString:@"."].location == NSNotFound) {
		// For backward compatibility, handle scheme://path/to/ressource as if path was part of the
		// path if it doesn't look like a domain name (no dot in it)
		pathComponents = [@[URL.host] arrayByAddingObjectsFromArray:pathComponents];
	}
	
	[self verboseLogWithFormat:@"URL path components: %@", pathComponents];
	
	for (_JLRoute *route in routes) {
		NSDictionary *matchParameters = [route parametersForURL:URL components:pathComponents];
		if (matchParameters) {
			[self verboseLogWithFormat:@"Successfully matched %@", route];
            if (!executeBlock) {
                return YES;
            }

			// add the URL parameters
			NSMutableDictionary *finalParameters = [NSMutableDictionary dictionary];

			// in increasing order of precedence: query, fragment, route, builtin
			[finalParameters addEntriesFromDictionary:queryParameters];
			[finalParameters addEntriesFromDictionary:fragmentParameters];
			[finalParameters addEntriesFromDictionary:matchParameters];
			[finalParameters addEntriesFromDictionary:parameters];
			finalParameters[kJLRoutePatternKey] = route.pattern;
			finalParameters[kJLRouteURLKey] = URL;
            __strong __typeof(route.parentRoutesController) strongParentRoutesController = route.parentRoutesController;
			finalParameters[kJLRouteNamespaceKey] = strongParentRoutesController.namespaceKey ?: [NSNull null];

			[self verboseLogWithFormat:@"Final parameters are %@", finalParameters];
			didRoute = route.block(finalParameters);
			if (didRoute) {
				break;
			}
		}
	}
	
	if (!didRoute) {
		[self verboseLogWithFormat:@"Could not find a matching route, returning NO"];
	}
	
	// if we couldn't find a match and this routes controller specifies to fallback and its also not the global routes controller, then...
	if (!didRoute && routesController.shouldFallbackToGlobalRoutes && ![routesController isGlobalRoutesController]) {
		[self verboseLogWithFormat:@"Falling back to global routes..."];
		didRoute = [self routeURL:URL withController:[self globalRoutes] parameters:parameters executeBlock:executeBlock];
	}
	
	// if, after everything, we did not route anything and we have an unmatched URL handler, then call it
	if (!didRoute && routesController.unmatchedURLHandler) {
		routesController.unmatchedURLHandler(routesController, URL, parameters);
	}
	
	return didRoute;
}

- (BOOL)isGlobalRoutesController
{
	return [self.namespaceKey isEqualToString:kJLRoutesGlobalNamespaceKey];
}

+ (void)verboseLogWithFormat:(NSString *)format, ...
{
	if (verboseLoggingEnabled && format) {
		va_list argsList;
		va_start(argsList, format);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
		NSString *formattedLogMessage = [[NSString alloc] initWithFormat:format arguments:argsList];
#pragma clang diagnostic pop
		
		va_end(argsList);
		NSLog(@"[JLRoutes]: %@", formattedLogMessage);
	}
}

@end
