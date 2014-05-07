//
//  JLRoutesController.m
//  JLRoutes
//
//  Created by Joel Levin on 5/6/14.
//  Copyright (c) 2014 Afterwork Studios. All rights reserved.
//

#import "JLRoutesController.h"
#import "JLRouteDefinition.h"
#import "JLRoutes.h"
#import "NSString+JLRoutesAdditions.h"



@interface JLRoutesController ()

@property (nonatomic, strong, readwrite) NSString *scheme;
@property (nonatomic, strong) NSMutableArray *routes;


@end


@implementation JLRoutesController

- (instancetype)init
{
	if ((self = [super init])) {
		self.routes = [NSMutableArray array];
	}
	return self;
}

- (instancetype)initWithScheme:(NSString *)scheme
{
	if ((self = [self init])) {
		self.scheme = scheme;
	}
	return self;
}

- (BOOL)isGlobalRoutesController
{
	return [self.scheme isEqualToString:JLRoutesGlobalScheme];
}

- (JLRouteDefinition *)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
	return [self addRoute:routePattern priority:JLRouteDefaultPriority handler:handlerBlock];
}

- (JLRouteDefinition *)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
	NSParameterAssert(routePattern != nil);
	
	JLRouteDefinition *route = [[JLRouteDefinition alloc] initWithPattern:routePattern priority:priority handler:handlerBlock];
	route.parentRoutesController = self;
	
	if (priority == 0) {
		[self.routes addObject:route];
	} else {
		NSArray *existingRoutes = self.routes;
		NSUInteger index = 0;
		for (JLRouteDefinition *existingRoute in existingRoutes) {
			if (existingRoute.priority < priority) {
				[self.routes insertObject:route atIndex:index];
				break;
			}
			index++;
		}
	}
	
	return route;
}

- (NSArray *)addRoutes:(NSArray *)routePatterns handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	return [self addRoutes:routePatterns priority:0 handler:handlerBlock];
}

- (NSArray *)addRoutes:(NSArray *)routePatterns priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	NSMutableArray *routeDefinitions = [NSMutableArray array];
	
	for (NSString *route in routePatterns) {
		JLRouteDefinition *definition = [self addRoute:route priority:priority handler:handlerBlock];
		[routeDefinitions addObject:definition];
	}
	
	return routeDefinitions;
}

- (void)setObject:(id)handlerBlock forKeyedSubscript:(NSString *)routePatten
{
	[self addRoute:routePatten handler:handlerBlock];
}

- (NSArray *)allRoutes
{
	return [NSArray arrayWithArray:self.routes];
}

- (void)removeRoute:(JLRouteDefinition *)route
{
	[self.routes removeObject:route];
}

- (void)removeRoutes:(NSArray *)routes
{
	[self.routes removeObjectsInArray:routes];
}

- (void)removeRoutesWithPattern:(NSString *)routePattern
{
	NSParameterAssert(routePattern != nil);
	
	if (![routePattern hasPrefix:@"/"]) {
		routePattern = [NSString stringWithFormat:@"/%@", routePattern];
	}
	
	NSUInteger index = 0;
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	
	for (JLRouteDefinition *route in self.routes) {
		if ([route.pattern isEqualToString:routePattern]) {
			[indexSet addIndex:index];
			break;
		}
		index++;
	}
	
	if ([indexSet count] > 0) {
		[self.routes removeObjectsAtIndexes:indexSet];
	}
}

- (void)removeAllRoutes
{
	[self.routes removeAllObjects];
}

- (BOOL)routeURL:(NSURL *)URL
{
	return [self routeURL:URL withParameters:nil];
}

- (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
	return [self routeURL:URL withParameters:parameters executeBlock:YES];
}

- (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters executeBlock:(BOOL)executeBlock
{
	[self verboseLogWithFormat:@"Trying to route URL %@", URL];
	BOOL didRoute = NO;
	NSDictionary *queryParameters = [URL.query JLRoutes_URLParameterDictionaryReplacePlusSymbols:[JLRoutes shouldDecodePlusSymbols]];
	[self verboseLogWithFormat:@"Parsed query parameters: %@", queryParameters];
	
	NSDictionary *fragmentParameters = [URL.fragment JLRoutes_URLParameterDictionaryReplacePlusSymbols:[JLRoutes shouldDecodePlusSymbols]];
	[self verboseLogWithFormat:@"Parsed fragment parameters: %@", fragmentParameters];
	
	// break the URL down into path components and filter out any leading/trailing slashes from it
	NSArray *pathComponents = [(URL.pathComponents ?: @[]) filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF like '/'"]];
	
	if ([URL.host rangeOfString:@"."].location == NSNotFound) {
		// For backward compatibility, handle scheme://path/to/ressource as if path was part of the
		// path if it doesn't look like a domain name (no dot in it)
		pathComponents = [@[URL.host] arrayByAddingObjectsFromArray:pathComponents];
	}
	
	[self verboseLogWithFormat:@"URL path components: %@", pathComponents];
	
	for (JLRouteDefinition *route in self.routes) {
		NSDictionary *matchParameters = [route routeURL:URL components:pathComponents];
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
			
			finalParameters[JLRoutesDefinitionKey] = route;
			finalParameters[JLRoutesControllerKey] = self;
			finalParameters[JLRoutesURLKey] = URL;
			
			[self verboseLogWithFormat:@"Final parameters are %@", finalParameters];
			didRoute = route.handlerBlock ? route.handlerBlock(finalParameters) : YES;
			if (didRoute) {
				break;
			}
		}
	}
	
	if (!didRoute) {
		[self verboseLogWithFormat:@"Could not find a matching route, returning NO"];
	}
	
	// if we couldn't find a match and this routes controller specifies to fallback and its also not the global routes controller, then...
	if (!didRoute && self.shouldFallbackToGlobalRoutes && ![self isGlobalRoutesController]) {
		[self verboseLogWithFormat:@"Falling back to global routes..."];
		didRoute = [[JLRoutes globalRoutes] routeURL:URL withParameters:parameters executeBlock:executeBlock];
	}
	
	return didRoute;
}

- (BOOL)canRouteURL:(NSURL *)URL
{
	return [self canRouteURL:URL withParameters:nil];
}

- (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
	return [self routeURL:URL withParameters:parameters executeBlock:NO];
}

- (void)verboseLogWithFormat:(NSString *)format, ...
{
	if ([JLRoutes isVerboseLoggingEnabled] && format) {
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
