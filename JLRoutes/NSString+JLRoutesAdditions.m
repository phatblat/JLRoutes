//
//  NSString+JLRoutesAdditions.m
//  JLRoutes
//
//  Created by Joel Levin on 5/2/14.
//  Copyright (c) 2014 Afterwork Studios. All rights reserved.
//

#import "NSString+JLRoutesAdditions.h"


@implementation NSString (JLRoutesAdditions)

- (NSArray *)JLRoutes_filteredPathComponents
{
	return [[self pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF like '/'"]];
}

- (NSRange)JLRoutes_innermostRangeBetweenStartString:(NSString *)startString endString:(NSString *)endString
{
	NSParameterAssert(startString != nil);
	NSParameterAssert(endString != nil);
	
	NSRange returnRange = NSMakeRange(NSNotFound, NSNotFound);
	NSRange startRange = [self rangeOfString:startString options:NSBackwardsSearch];
	NSRange endRange = [self rangeOfString:endString];
	
	if (startRange.location != NSNotFound && endRange.location != NSNotFound) {
		returnRange = NSMakeRange(startRange.location + startRange.length, endRange.location - (startRange.location + startRange.length));
	}
	
	return returnRange;
}

- (NSString *)JLRoutes_URLDecodedStringReplacingPlusSymbols:(BOOL)replacePlusSymbols
{
	NSString *input = replacePlusSymbols ? [self stringByReplacingOccurrencesOfString:@"+" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, self.length)] : self;
	return [input stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSDictionary *)JLRoutes_URLParameterDictionaryReplacePlusSymbols:(BOOL)replacePlusSymbols
{
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	
	if (self.length && [self rangeOfString:@"="].location != NSNotFound) {
		NSArray *keyValuePairs = [self componentsSeparatedByString:@"&"];
		for (NSString *keyValuePair in keyValuePairs) {
			NSArray *pair = [keyValuePair componentsSeparatedByString:@"="];
			// don't assume we actually got a real key=value pair. start by assuming we only got @[key] before checking count
			NSString *paramValue = pair.count == 2 ? pair[1] : @"";
			// CFURLCreateStringByReplacingPercentEscapesUsingEncoding may return NULL
			parameters[pair[0]] = [paramValue JLRoutes_URLDecodedStringReplacingPlusSymbols:replacePlusSymbols] ?: @"";
		}
	}
	
	return parameters;
}

@end
