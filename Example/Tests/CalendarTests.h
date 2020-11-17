#import "HTTPStubs.h"
#import "HTTPStubsPathHelpers.h"
#import "MockCalendarAuthorizationManager.h"
#import "MockCalendarAuthorization.h"

#import "GCWCalendar.h"
#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "GCWUserAccount.h"
#import "GCWCalendarAuthorization.h"

@import Nimble;
@import XCTest;

@interface CalendarTests : XCTestCase

@property (nonatomic) NSUserDefaults *userDefaults;
@property (nonatomic) MockCalendarAuthorizationManager *authorizationManager;
@property (nonatomic) GCWCalendar *calendar;

- (void)loadAuthorizations;
- (void)loadCalendarLists;
- (HTTPStubsResponse *)responseWithUserInfoJson;
- (HTTPStubsResponse *)responseWithJson:(NSDictionary *)responseJson;
- (HTTPStubsResponse *)responseWithJsonFile:(NSString *)fileName;
- (HTTPStubsResponse *)responseWithMultipartContentFile:(NSString *)fileName boundary:(NSString *)boundary;
- (void)stubGoogleApisRequestIndentifiedByLastPathComponent:(NSString *)lastPathComponent withJsonFile:(NSString *)fileName;
- (void)stubGoogleApisRequestWithError:(int)errorCode;
- (void)stubGoogleApisRequestIndentifiedByLastPathComponent:(NSString *)lastPathComponent withError:(int)errorCode;

@end

