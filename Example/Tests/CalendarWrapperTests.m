#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>

#import "HTTPStubs.h"
#import "HTTPStubsPathHelpers.h"
#import "GCWCalendar.h"
#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "GCWUserAccount.h"
#import "GCWCalendarAuthorization.h"
#import "MockCalendarAuthorizationManager.h"
#import "MockCalendarAuthorization.h"

@import Nimble;
@import XCTest;

static NSString *const kUserIDs = @"googleUserIDsKey";

@interface CalendarWrapperTests : XCTestCase

@property (nonatomic) NSUserDefaults *userDefaults;
@property (nonatomic) MockCalendarAuthorizationManager *authorizationManager;
@property (nonatomic) GCWCalendar *calendar;

@end

@implementation CalendarWrapperTests

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

- (void)testLoadAuthorizationsSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary* responseJson = @{@"name": @"Test Name"};
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseJson
                                                           options:(NSJSONWritingOptions)NSJSONWritingPrettyPrinted
                                                             error:&error];
        return [HTTPStubsResponse responseWithData:jsonData statusCode:200 headers:nil];
    }];
    [self.userDefaults setObject:@[@"1", @"2", @"3"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load authorizations expectation"];

    self.authorizationManager.canAuthorize = YES;
    [self.calendar loadAuthorizationsOnSuccess:^{
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];

    expect(self.calendar.userAccounts.count).to(equal(3));

    expect([self.calendar.userAccounts valueForKey:@"1"]).notTo(beNil());
    GCWUserAccount *user1 = self.calendar.userAccounts[@"1"];
    expect(user1.name).to(contain(@"Test Name"));

    expect([self.calendar.userAccounts valueForKey:@"2"]).notTo(beNil());
    GCWUserAccount *user2 = self.calendar.userAccounts[@"2"];
    expect(user2.name).to(contain(@"Test Name"));

    expect([self.calendar.userAccounts valueForKey:@"3"]).notTo(beNil());
    GCWUserAccount *user3 = self.calendar.userAccounts[@"3"];
    expect(user3.name).to(contain(@"Test Name"));
}

- (void)testAccountEntries {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"calendar_list.json", self.class)
                                                  statusCode:200
                                                     headers:@{@"Content-Type":@"application/json"}];
        } else {
            NSDictionary* responseJson = @{@"name": @"Test Name"};
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseJson
                                                               options:(NSJSONWritingOptions)NSJSONWritingPrettyPrinted
                                                                 error:&error];
            return [HTTPStubsResponse responseWithData:jsonData statusCode:200 headers:nil];
        }
    }];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    XCTestExpectation *loadAuthorizationExpectation = [[XCTestExpectation alloc] initWithDescription:@"Load authorizations expectation"];

    self.authorizationManager.canAuthorize = YES;
    [self.calendar loadAuthorizationsOnSuccess:^{
        [loadAuthorizationExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[loadAuthorizationExpectation] timeout:10.0];

    XCTestExpectation *calendarListExpectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar list expectation"];

    [self.calendar loadCalendarListsForRole:@"test" success:^(NSDictionary *calendarList) {
        [calendarListExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[calendarListExpectation] timeout:10.0];

    expect(self.calendar.accountEntries.count).to(equal(2));

    //NSArray *entries1 = self.calendar.accountEntries[@"dterzic@gmail.com"];
    //NSArray *entries2 = self.calendar.accountEntries[@"dterzictest@gmail.com"];
}

- (void)testLoadCalendarListForRoleSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"calendar_list.json", self.class)
                                              statusCode:200
                                                 headers:@{@"Content-Type":@"application/json"}];
    }];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar list expectation"];

    [self.calendar loadCalendarListsForRole:@"test" success:^(NSDictionary *calendarList) {
        expect(calendarList.count).to(equal(3));
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];

    expect(self.calendar.calendarEntries.count).to(equal(3));
    
    GCWCalendarEntry *entry1 = self.calendar.calendarEntries[@"dterzictest@gmail.com"];
    expect(entry1.identifier).to(equal(@"dterzictest@gmail.com"));
    expect(entry1.summary).to(equal(@"dterzictest@gmail.com"));
    expect(entry1.colorId).to(equal(@"12"));
    expect(entry1.accessRole).to(equal(@"owner"));
    expect(entry1.hideEvents).to(beFalse());

    GCWCalendarEntry *entry2 = self.calendar.calendarEntries[@"sr.rs#holiday@group.v.calendar.google.com"];
    expect(entry2.identifier).to(equal(@"sr.rs#holiday@group.v.calendar.google.com"));
    expect(entry2.summary).to(equal(@"Празници у Србији"));
    expect(entry2.colorId).to(equal(@"8"));
    expect(entry2.accessRole).to(equal(@"reader"));
    expect(entry2.hideEvents).to(beFalse());

    GCWCalendarEntry *entry3 = self.calendar.calendarEntries[@"addressbook#contacts@group.v.calendar.google.com"];
    expect(entry3.identifier).to(equal(@"addressbook#contacts@group.v.calendar.google.com"));
    expect(entry3.summary).to(equal(@"Рођендани"));
    expect(entry3.descriptionProperty).to(equal(@"Приказује рођендане, годишњице и друге датуме догађаја за људе у Google контактима."));
    expect(entry3.colorId).to(equal(@"13"));
    expect(entry3.accessRole).to(equal(@"reader"));
    expect(entry3.hideEvents).to(beFalse());
}

- (void)testLoadCalendarEventsSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"calendar_list.json", self.class)
                                                  statusCode:200
                                                     headers:@{@"Content-Type":@"application/json"}];
        } else {
            return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"calendar_events.json", self.class)
                                                  statusCode:200
                                                     headers:@{@"Content-Type":@"application/json"}];
        }
    }];

    XCTestExpectation *calendarListExpectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar list expectation"];

    [self.calendar loadCalendarListsForRole:@"test" success:^(NSDictionary *calendarList) {
        [calendarListExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[calendarListExpectation] timeout:10.0];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar events expectation"];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:1601503200];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:1604185199];
    [self.calendar getEventsListForCalendar:@"dterzictest@gmail.com"
                             startDate:startDate
                               endDate:endDate
                            maxResults:200
                               success:^(NSDictionary *events) {
        expect(events.count).to(equal(4));

        GCWCalendarEvent *event1 = events.allValues[0];
        expect(event1.summary).to(equal(@"Test meeting"));
        expect(event1.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1601658000]));
        expect(event1.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1601659800]));
        expect(event1.attendeesEmailAddresses.count).to(equal(1));
        expect(event1.attendeesEmailAddresses[0]).to(equal(@"dterzictest@gmail.com"));

        GCWCalendarEvent *event2 = events.allValues[2];
        expect(event2.summary).to(equal(@"Test meeting 2"));
        expect(event2.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603809000]));
        expect(event2.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603812600]));
        expect(event2.attendeesEmailAddresses.count).to(equal(2));
        expect(event2.attendeesEmailAddresses[0]).to(equal(@"dterzic@gmail.com"));
        expect(event2.attendeesEmailAddresses[1]).to(equal(@"dterzictest@gmail.com"));
        expect(event2.hangoutLink).to(equal(@"https://meet.google.com/hpr-bwei-rqc"));

        GCWCalendarEvent *event3 = events.allValues[3];
        expect(event3.summary).to(equal(@"Test reccurring"));
        expect(event3.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603800000]));
        expect(event3.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603886400]));
        expect(event3.recurringEventId).to(equal(@"5nek4vfo0j9u8vn5kf2l0jufe0"));

        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testSyncCalendarEventsSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"calendar_list.json", self.class)
                                                  statusCode:200
                                                     headers:@{@"Content-Type":@"application/json"}];
        } else {
            return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(@"calendar_events.json", self.class)
                                                  statusCode:200
                                                     headers:@{@"Content-Type":@"application/json"}];
        }
    }];

    XCTestExpectation *calendarListExpectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar list expectation"];

    [self.calendar loadCalendarListsForRole:@"test" success:^(NSDictionary *calendarList) {
        [calendarListExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[calendarListExpectation] timeout:10.0];

    XCTestExpectation *calendarEventsExpectation = [[XCTestExpectation alloc] initWithDescription:@"Syncing calendar events expectation"];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:1603753200];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:1604185199];
    [self.calendar syncEventsFrom:startDate
                          to:endDate
                     success:^(NSDictionary *events) {
        expect(events.count).to(equal(2));

        GCWCalendarEvent *event1 = events.allValues[0];
        expect(event1.summary).to(equal(@"Test meeting 2"));
        expect(event1.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603809000]));
        expect(event1.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603812600]));
        expect(event1.attendeesEmailAddresses.count).to(equal(2));
        expect(event1.attendeesEmailAddresses[0]).to(equal(@"dterzic@gmail.com"));
        expect(event1.attendeesEmailAddresses[1]).to(equal(@"dterzictest@gmail.com"));
        expect(event1.hangoutLink).to(equal(@"https://meet.google.com/hpr-bwei-rqc"));

        GCWCalendarEvent *event2 = events.allValues[1];
        expect(event2.summary).to(equal(@"Test reccurring"));
        expect(event2.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603800000]));
        expect(event2.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603886400]));
        expect(event2.recurringEventId).to(equal(@"5nek4vfo0j9u8vn5kf2l0jufe0"));

        [calendarEventsExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[calendarEventsExpectation] timeout:10.0];
}

@end

