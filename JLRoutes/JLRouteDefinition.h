//
//  JLRouteDefinition.h
//  JLRoutes
//
//  Created by Joel Levin on 5/5/14.
//  Copyright (c) 2014 Afterwork Studios. All rights reserved.
//

#import <Foundation/Foundation.h>


@class JLRoutesController;

@interface JLRouteDefinition : NSObject

@property (nonatomic, strong, readonly) NSString *pattern;
@property (nonatomic, assign, readonly) NSUInteger priority;
@property (nonatomic, copy) BOOL (^handlerBlock)(NSDictionary *parameters);
@property (nonatomic, weak) JLRoutesController *parentRoutesController;

- (instancetype)initWithPattern:(NSString *)pattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *))handlerBlock;
- (NSDictionary *)routeURL:(NSURL *)URL components:(NSArray *)URLComponents;

- (void)prepareRoute;

@end
