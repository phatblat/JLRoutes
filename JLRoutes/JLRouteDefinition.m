//
//  JLRouteDefinition.m
//  JLRoutes
//
//  Created by Joel Levin on 5/5/14.
//  Copyright (c) 2014 Afterwork Studios. All rights reserved.
//

#import "JLRouteDefinition.h"
#import "JLRoutesController.h"
#import "JLRoutes.h"
#import "NSString+JLRoutesAdditions.h"


@interface JLRouteDefinition ()

@property (nonatomic, strong, readwrite) NSString *pattern;
@property (nonatomic, assign, readwrite) NSUInteger priority;

@property (nonatomic, strong) NSArray *patternPathComponents;
@property (nonatomic, strong) NSArray *optionalComponentSequences;
@property (nonatomic, assign) NSUInteger optionalComponentsCount;

@end


@implementation JLRouteDefinition

- (instancetype)initWithPattern:(NSString *)pattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *))handlerBlock
{
	if ((self = [super init])) {
		self.handlerBlock = handlerBlock;
		self.priority = priority;
		self.pattern = pattern;
		[self prepareRoute];
	}
	return self;
}

- (void)prepareRoute
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
		patternString = modifiedPatternString;
	}
	self.patternPathComponents = [patternString JLRoutes_filteredPathComponents];
}

- (NSDictionary *)routeURL:(NSURL *)URL components:(NSArray *)URLComponents
{
	NSDictionary *routeParameters = nil;
	
	if (!self.patternPathComponents) {
		[self prepareRoute];
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
						variables[variableName] = [variableValue JLRoutes_URLDecodedStringReplacingPlusSymbols:[JLRoutes shouldDecodePlusSymbols]];
					}
				} else if ([patternComponent isEqualToString:@"*"]) {
					// match wildcards
					variables[JLRoutesWildcardComponentsKey] = [URLComponents subarrayWithRange:NSMakeRange(componentIndex, URLComponents.count-componentIndex)];
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
	return [NSString stringWithFormat:@"JLRoute %@:/%@ (priority %@)", ([self.parentRoutesController isGlobalRoutesController] ? @"global" : self.parentRoutesController.scheme), self.pattern, @(self.priority)];
}

@end
