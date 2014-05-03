//
//  JLRoutesTests.m
//  JLRoutesTests
//
//  Created by Joel Levin on 2/9/13.
//  Copyright (c) 2013 Afterwork Studios. All rights reserved.
//

#import "JLRoutesTests.h"
#import "JLRoutes.h"


#define JLValidateParameterCount(expectedCount)\
	XCTAssertNotNil(lastMatch, @"Matched something");\
	XCTAssertEqual((NSInteger)[lastMatch count] - 3, (NSInteger)expectedCount, @"Expected parameter count")

#define JLValidateParameterCountIncludingWildcard(expectedCount)\
	XCTAssertNotNil(lastMatch, @"Matched something");\
	XCTAssertEqual((NSInteger)[lastMatch count] - 4, (NSInteger)expectedCount, @"Expected parameter count")

#define JLValidateParameter(parameter) {\
	NSString *key = [[parameter allKeys] lastObject];\
	NSString *value = [[parameter allValues] lastObject];\
	XCTAssertEqualObjects(lastMatch[key], value, @"Exact parameter pair not found");}

#define JLValidateAnyRouteMatched()\
	XCTAssertNotNil(lastMatch, @"Expected any route to match")

#define JLValidateNoLastMatch()\
	XCTAssertNil(lastMatch, @"Expected not to route successfully")

#define JLValidatePattern(pattern)\
	XCTAssertEqualObjects(lastMatch[kJLRoutePatternKey], pattern, @"Pattern did not match")

#define JLValidatePatternPrefix(prefix)\
	XCTAssertTrue([lastMatch[kJLRoutePatternKey] hasPrefix:prefix], @"Pattern prefix did not match")

#define JLValidateScheme(scheme)\
	XCTAssertEqualObjects(lastMatch[kJLRouteNamespaceKey], scheme, @"Scheme did not match")


static NSDictionary *lastMatch = nil;


@interface JLRoutesTests ()

@property (copy) BOOL (^defaultHandler)(NSDictionary *params);

- (void)route:(NSString *)URLString;

@end


@implementation JLRoutesTests

+ (void)setUp
{
	[JLRoutes setVerboseLoggingEnabled:YES];
	[super setUp];
}

- (void)setUp
{
	self.defaultHandler = ^BOOL (NSDictionary *params) {
		lastMatch = params;
		return YES;
	};
	
	[JLRoutes addRoute:@"/test" handler:self.defaultHandler];
	[JLRoutes addRoute:@"/user/view/:userID" handler:self.defaultHandler];
	[JLRoutes addRoute:@"/:object/:action/:primaryKey" handler:self.defaultHandler];
	
	[super setUp];
}

- (void)tearDown
{
	lastMatch = nil;
	[JLRoutes removeAllRoutes];
	[super tearDown];
}

#pragma mark - Convenience Methods

- (void)route:(NSString *)URLString
{
	[self route:URLString withParameters:nil];
}

- (void)route:(NSString *)URLString withParameters:(NSDictionary *)parameters
{
	NSLog(@"*** Routing %@", URLString);
	lastMatch = nil;
	BOOL didRoute = [JLRoutes routeURL:[NSURL URLWithString:URLString] withParameters:parameters];
	if (!didRoute && lastMatch) {
		// since lastMatch is set inside the handler block, we have to manually handle the case of a block returning NO
		lastMatch = nil;
	}
}

#pragma mark - Tests

- (void)testBasicRouting
{
	[JLRoutes addRoute:@"/" handler:self.defaultHandler];
	[JLRoutes addRoute:@"/:" handler:self.defaultHandler];
	[JLRoutes addRoute:@"/interleaving/:param1/foo/:param2" handler:self.defaultHandler];
	[JLRoutes addRoute:@"/xyz/wildcard/*" handler:self.defaultHandler];
	[JLRoutes addRoute:@"/route/:param/*" handler:self.defaultHandler];
	
	[self route:nil];
	JLValidateNoLastMatch();
	
	[self route:@"tests:/"];
	JLValidateAnyRouteMatched();
	JLValidatePattern(@"/");
	JLValidateParameterCount(0);

	[self route:@"tests://"];
	JLValidateAnyRouteMatched();
	JLValidatePattern(@"/");
	JLValidateParameterCount(0);
	
	[self route:@"tests://test?"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(0);
	JLValidatePattern(@"/test");
	
	[self route:@"tests://test/"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(0);
	JLValidatePattern(@"/test");
	
	[self route:@"tests://test"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(0);
	
	[self route:@"tests://?key=value"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"key": @"value"});
	
	[self route:@"tests://?key=value" withParameters:@{@"foo": @"bar"}];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"key": @"value"});
	JLValidateParameter(@{@"foo": @"bar"});
	
	[self route:@"tests://user/view/joeldev"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});
	
	[self route:@"tests://user/view/joeldev/"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});
	
	[self route:@"tests://user/view/joel%20levin"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joel levin"});
	
	[self route:@"tests://user/view/joeldev?foo=bar&thing=stuff"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"userID": @"joeldev"});
	JLValidateParameter(@{@"foo" : @"bar"});
	JLValidateParameter(@{@"thing" : @"stuff"});

	[self route:@"tests://user/view/joeldev#foo=bar&thing=stuff"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"userID": @"joeldev"});
	JLValidateParameter(@{@"foo" : @"bar"});
	JLValidateParameter(@{@"thing" : @"stuff"});

	[self route:@"tests://user/view/joeldev?userID=evilPerson"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});

	[self route:@"tests://user/view/joeldev?userID=evilPerson&search=evilSearch&evilThing=evil#search=blarg&userID=otherEvilPerson" withParameters:@{@"evilThing": @"notEvil"}];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"userID": @"joeldev"});
	JLValidateParameter(@{@"search": @"blarg"});
	JLValidateParameter(@{@"evilThing": @"notEvil"});
	
	[self route:@"tests://post/edit/123"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"object": @"post"});
	JLValidateParameter(@{@"action": @"edit"});
	JLValidateParameter(@{@"primaryKey": @"123"});
	
	[self route:@"tests://interleaving/paramvalue1/foo/paramvalue2"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"param1": @"paramvalue1"});
	JLValidateParameter(@{@"param2": @"paramvalue2"});
	
	[self route:@"tests://xyz/wildcard"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCountIncludingWildcard(0);
	
	[self route:@"tests://xyz/wildcard/matches/with/extra/path/components"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	NSArray *wildcardMatches = @[@"matches", @"with", @"extra", @"path", @"components"];
	JLValidateParameter(@{kJLRouteWildcardComponentsKey: wildcardMatches});

	[self route:@"tests://route/matches/with/wildcard"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"param": @"matches"});
	NSArray *parameterWildcardMatches = @[@"with", @"wildcard"];
	JLValidateParameter(@{kJLRouteWildcardComponentsKey: parameterWildcardMatches});

	[self route:@"tests://doesnt/exist/and/wont/match"];
	JLValidateNoLastMatch();
}

- (void)testPriority
{
	[JLRoutes addRoute:@"/test/priority/:level" handler:self.defaultHandler];
	[JLRoutes addRoute:@"/test/priority/high" priority:20 handler:self.defaultHandler];
	
	// this should match the /test/priority/high route even though there's one before it that would match if priority wasn't being set
	[self route:@"tests://test/priority/high"];
	JLValidateAnyRouteMatched();
	JLValidatePattern(@"/test/priority/high");
}

- (void)testBlockReturnValue
{
	[JLRoutes addRoute:@"/return/:value" handler:^BOOL(NSDictionary *parameters) {
		lastMatch = parameters;
		NSString *value = parameters[@"value"];
		return [value isEqualToString:@"yes"];
	}];
	
	// even though this matches a route, the block returns NO here so there won't be a valid match
	[self route:@"tests://return/no"];
	JLValidateNoLastMatch();
	
	// this one is the same route but will return yes, causing it to be flagged as a match
	[self route:@"tests://return/yes"];
	JLValidateAnyRouteMatched();
}

- (void)testNamespaces
{
	[[JLRoutes routesForScheme:@"namespaceTest1"] addRoute:@"/test" handler:self.defaultHandler];
	[[JLRoutes routesForScheme:@"namespaceTest2"] addRoute:@"/test" handler:self.defaultHandler];
	
	// test that the same route can be handled differently for three different scheme namespaces
	[self route:@"tests://test"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(kJLRoutesGlobalNamespaceKey);
	
	[self route:@"namespaceTest1://test"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(@"namespaceTest1");
	
	[self route:@"namespaceTest2://test"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(@"namespaceTest2");
	
	[JLRoutes unregisterRouteScheme:@"namespaceTest1"];
	[JLRoutes unregisterRouteScheme:@"namespaceTest2"];
}

- (void)testFallbackToGlobal
{
	[[JLRoutes routesForScheme:@"namespaceTest1"] addRoute:@"/test" handler:self.defaultHandler];
	[[JLRoutes routesForScheme:@"namespaceTest2"] addRoute:@"/test" handler:self.defaultHandler];
	[JLRoutes routesForScheme:@"namespaceTest2"].shouldFallbackToGlobalRoutes = YES;
	
	// first case, fallback is off and so this should fail because this route isnt declared as part of namespaceTest1
	[self route:@"namespaceTest1://user/view/joeldev"];
	JLValidateNoLastMatch();
	
	// fallback is on, so this should route
	[self route:@"namespaceTest2://user/view/joeldev"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(kJLRoutesGlobalNamespaceKey);
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID" : @"joeldev"});
}

- (void)testForRouteExistence
{
    // This should return yes and no for whether we have a matching route.
    
    NSURL *shouldHaveRouteURL = [NSURL URLWithString:@"tests:/test"];
    NSURL *shouldNotHaveRouteURL = [NSURL URLWithString:@"tests:/dfjkbsdkjfbskjdfb/sdasd"];

    XCTAssertTrue([JLRoutes canRouteURL:shouldHaveRouteURL], @"Should state it can route known URL");
    XCTAssertFalse([JLRoutes canRouteURL:shouldNotHaveRouteURL], @"Should not state it can route unknown URL");
}

- (void)testSubscripting
{
	JLRoutes.globalRoutes[@"/subscripting"] = self.defaultHandler;
	
	NSURL *shouldHaveRouteURL = [NSURL URLWithString:@"subscripting"];
	
	XCTAssertTrue([JLRoutes canRouteURL:shouldHaveRouteURL], @"Should state it can route known URL");
}

- (void)testNonSingletonUsage
{
    JLRoutes *routes = [JLRoutes new];
    NSURL *trivialURL = [NSURL URLWithString:@"/success"];
    [routes addRoute:[trivialURL absoluteString] handler:nil];
    XCTAssertTrue([routes routeURL:trivialURL], @"Non-singleton instance should route known URL");
}

- (void)testRouteRemoval
{
	[[JLRoutes routesForScheme:@"namespaceTest3"] addRoute:@"/test1" handler:self.defaultHandler];
	[[JLRoutes routesForScheme:@"namespaceTest3"] addRoute:@"/test2" handler:self.defaultHandler];
	
	[self route:@"namespaceTest3://test1"];
	JLValidateAnyRouteMatched();
	
	[[JLRoutes routesForScheme:@"namespaceTest3"] removeRoute:@"test1"];
	[self route:@"namespaceTest3://test1"];
	JLValidateNoLastMatch();
	
	[self route:@"namespaceTest3://test2"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(@"namespaceTest3");
	
	[JLRoutes unregisterRouteScheme:@"namespaceTest3"];
	
	// this will get matched by our "/:" route in the global namespace - we just want to make sure it doesn't get matched by namespaceTest3
	[self route:@"namespaceTest3://test2"];
	JLValidateNoLastMatch();
}

- (void)testPercentEncoding
{
    /*
     from http://en.wikipedia.org/wiki/Percent-encoding
        !   #   $   &   '   (   )   *   +   ,   /   :   ;   =   ?   @   [   ]
	   %21 %23 %24 %26 %27 %28 %29 %2A %2B %2C %2F %3A %3B %3D %3F %40 %5B %5D
     */
	
	// NOTE: %2F is not supported.
	//  [URL pathComponents] automatically expands values with %2F as if it was just a regular slash.
	
	BOOL oldDecodeSetting = [JLRoutes shouldDecodePlusSymbols];
	[JLRoutes setShouldDecodePlusSymbols:NO];
	
    [self route:@"tests://user/view/joel%21levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel!levin"});
	
    [self route:@"tests://user/view/joel%23levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel#levin"});
	
    [self route:@"tests://user/view/joel%24levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel$levin"});
	
    [self route:@"tests://user/view/joel%26levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel&levin"});
	
    [self route:@"tests://user/view/joel%27levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel'levin"});
	
    [self route:@"tests://user/view/joel%28levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel(levin"});
	
    [self route:@"tests://user/view/joel%29levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel)levin"});
	
    [self route:@"tests://user/view/joel%2Alevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel*levin"});
	
    [self route:@"tests://user/view/joel%2Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel+levin"});
	
    [self route:@"tests://user/view/joel%2Clevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel,levin"});
	
    [self route:@"tests://user/view/joel%3Alevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel:levin"});
	
    [self route:@"tests://user/view/joel%3Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel;levin"});
	
    [self route:@"tests://user/view/joel%3Dlevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel=levin"});
	
    [self route:@"tests://user/view/joel%3Flevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel?levin"});
	
    [self route:@"tests://user/view/joel%40levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel@levin"});
	
    [self route:@"tests://user/view/joel%5Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel[levin"});
	
    [self route:@"tests://user/view/joel%5Dlevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel]levin"});
	
	[JLRoutes setShouldDecodePlusSymbols:oldDecodeSetting];
}

- (void)testOptionalParameters
{
	[[JLRoutes routesForScheme:@"optional"] addRoute:@"/optional1(/:opParam1)" handler:self.defaultHandler];
	[[JLRoutes routesForScheme:@"optional"] addRoute:@"/optional2(/:opParam1(/:opParam2))" handler:self.defaultHandler];
	[[JLRoutes routesForScheme:@"optional"] addRoute:@"/optional3(/:opParam1(/foo/bar/:opParam2/baz(/thing/:opParam3)))" handler:self.defaultHandler];
	
	// test routes with a single optional parameter
	[self route:@"optional://optional1"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional1");
	JLValidateParameterCount(0);
	
	[self route:@"optional://optional1/yay"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional1");
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"opParam1": @"yay"});
	
	[self route:@"optional://optional1/yay/boo"];
	JLValidateNoLastMatch();
	
	// test routes that have two optional parameters
	[self route:@"optional://optional2"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional2");
	JLValidateParameterCount(0);
	
	[self route:@"optional://optional2/yay"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional2");
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"opParam1": @"yay"});
	
	[self route:@"optional://optional2/yay/boo"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional2");
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"opParam1": @"yay"});
	JLValidateParameter(@{@"opParam2": @"boo"});
	
	[self route:@"optional://optional2/yay/boo/bar"];
	JLValidateNoLastMatch();
	
	// test really complex routes with more than two optional parameters and other require components intermixed
	[self route:@"optional://optional3"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional3");
	JLValidateParameterCount(0);
	
	[self route:@"optional://optional3/yay"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional3");
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"opParam1": @"yay"});
	
	[self route:@"optional://optional3/yay/boo"];
	JLValidateNoLastMatch();
	
	[self route:@"optional://optional3/yay/foo/bar/boo"];
	JLValidateNoLastMatch();
	
	[self route:@"optional://optional3/yay/foo/bar/boo/baz"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional3");
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"opParam1": @"yay"});
	JLValidateParameter(@{@"opParam2": @"boo"});
	
	[self route:@"optional://optional3/yay/foo/bar/boo/baz/thing"];
	JLValidateNoLastMatch();
	
	[self route:@"optional://optional3/yay/foo/bar/boo/baz/thing/mars"];
	JLValidateAnyRouteMatched();
	JLValidatePatternPrefix(@"/optional3");
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"opParam1": @"yay"});
	JLValidateParameter(@{@"opParam2": @"boo"});
	JLValidateParameter(@{@"opParam3": @"mars"});
	
	[JLRoutes unregisterRouteScheme:@"optional"];
}

@end
