//
//  JLRoutesController.h
//  JLRoutes
//
//  Created by Joel Levin on 5/6/14.
//  Copyright (c) 2014 Afterwork Studios. All rights reserved.
//

#import <Foundation/Foundation.h>


static NSString *const JLRoutesGlobalScheme = @"JLRoutesGlobalScheme";

static NSString *const JLRoutesControllerKey = @"JLRoutesController";
static NSString *const JLRoutesDefinitionKey = @"JLRouteDefinition";
static NSString *const JLRoutesURLKey = @"JLRouteURL";
static NSString *const JLRoutesWildcardComponentsKey = @"JLRouteWildcardComponents";

static NSUInteger const JLRouteDefaultPriority = 0;


@class JLRouteDefinition;


@interface JLRoutesController : NSObject

@property (nonatomic, strong, readonly) NSString *scheme;

/// Controls whether or not this routes controller will try to match a URL with global routes if it can't be matched in the current namespace. Default is NO.
@property (nonatomic, assign) BOOL shouldFallbackToGlobalRoutes;

- (instancetype)initWithScheme:(NSString *)scheme;
- (BOOL)isGlobalRoutesController;

- (JLRouteDefinition *)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary *parameters))handlerBlock;
- (JLRouteDefinition *)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock;

- (NSArray *)addRoutes:(NSArray *)routePatterns handler:(BOOL (^)(NSDictionary *parameters))handlerBlock;
- (NSArray *)addRoutes:(NSArray *)routePatterns priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock;

/// Registers a routePattern with default priority (0) using dictionary-style subscripting.
- (void)setObject:(id)handlerBlock forKeyedSubscript:(NSString *)routePatten;

- (NSArray *)allRoutes;

- (void)removeRoute:(JLRouteDefinition *)route;
- (void)removeRoutes:(NSArray *)routes;
- (void)removeRoutesWithPattern:(NSString *)routePattern;
- (void)removeAllRoutes;

- (BOOL)routeURL:(NSURL *)URL;
- (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters;

- (BOOL)canRouteURL:(NSURL *)URL;
- (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters;

@end
