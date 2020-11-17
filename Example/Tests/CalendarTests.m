#import "CalendarTests.h"

@implementation CalendarTests

- (void)loadAuthorizations {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load authorizations expectation"];

    self.authorizationManager.canAuthorize = YES;
    [self.calendar loadAuthorizationsOnSuccess:^{
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)loadCalendarLists {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar list expectation"];

    [self.calendar loadCalendarListsForRole:@"test" success:^(NSDictionary *calendarList) {
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (HTTPStubsResponse *)responseWithUserInfoJson {
    return [self responseWithJson:@{@"name": @"Test Name"}];
}

- (HTTPStubsResponse *)responseWithJson:(NSDictionary *)responseJson {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseJson
                                                       options:(NSJSONWritingOptions)NSJSONWritingPrettyPrinted
                                                         error:&error];
    return [HTTPStubsResponse responseWithData:jsonData statusCode:200 headers:@{@"Content-Type":@"application/json"}];
}

- (HTTPStubsResponse *)responseWithJsonFile:(NSString *)fileName {
    return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(fileName, self.class)
                                          statusCode:200
                                             headers:@{@"Content-Type":@"application/json"}];
}

- (HTTPStubsResponse *)responseWithMultipartContentFile:(NSString *)fileName boundary:(NSString *)boundary {
    NSString *contentType = [NSString stringWithFormat:@"multipart/mixed; boundary=%@", boundary];
    return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(fileName, self.class)
                                          statusCode:200
                                             headers:@{@"Content-Type":contentType}];
}

- (void)stubGoogleApisRequestIndentifiedByLastPathComponent:(NSString *)lastPathComponent withJsonFile:(NSString *)fileName {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:lastPathComponent]) {
            return [self responseWithJsonFile:fileName];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];
}

- (void)stubGoogleApisRequestWithError:(int)errorCode {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        return [HTTPStubsResponse responseWithData:[NSData data] statusCode:errorCode headers:nil];
    }];
}

- (void)stubGoogleApisRequestIndentifiedByLastPathComponent:(NSString *)lastPathComponent withError:(int)errorCode {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:lastPathComponent]) {
            return [HTTPStubsResponse responseWithData:[NSData data] statusCode:errorCode headers:nil];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];
}

- (void)setUp {
    [super setUp];
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"CalendarUnitTests"];
    self.authorizationManager = [[MockCalendarAuthorizationManager alloc] init];
    self.calendar = [[GCWCalendar alloc] initWithClientId:@"testclientid"
                                 presentingViewController:nil
                                     authorizationManager:self.authorizationManager
                                             userDefaults:self.userDefaults];

    MockCalendarAuthorization *auth1 = [[MockCalendarAuthorization alloc] initWithUserID:@"dterzic@gmail.com"];
    MockCalendarAuthorization *auth2 = [[MockCalendarAuthorization alloc] initWithUserID:@"dterzictest@gmail.com"];
    self.authorizationManager.authorizations = [NSMutableArray array];
    [self.authorizationManager.authorizations addObject:auth1];
    [self.authorizationManager.authorizations addObject:auth2];
}

- (void)tearDown {
    [HTTPStubs removeAllStubs];
    [self.userDefaults removeSuiteNamed:@"CalendarUnitTests"];
    self.authorizationManager = nil;
    self.calendar = nil;
    [super tearDown];
}


@end
