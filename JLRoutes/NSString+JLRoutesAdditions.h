//
//  NSString+JLRoutesAdditions.h
//  JLRoutes
//
//  Created by Joel Levin on 5/2/14.
//  Copyright (c) 2014 Afterwork Studios. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (JLRoutesAdditions)

- (NSArray *)JLRoutes_filteredPathComponents;
- (NSRange)JLRoutes_innermostRangeBetweenStartString:(NSString *)startString endString:(NSString *)endString;

- (NSString *)JLRoutes_URLDecodedStringReplacingPlusSymbols:(BOOL)replacePlusSymbols;
- (NSDictionary *)JLRoutes_URLParameterDictionaryReplacePlusSymbols:(BOOL)replacePlusSymbols;

@end
