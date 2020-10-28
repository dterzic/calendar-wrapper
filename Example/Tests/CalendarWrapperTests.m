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
    NSDictionary* responseJson = @{@"name": @"Test Name"};
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseJson
                                                       options:(NSJSONWritingOptions)NSJSONWritingPrettyPrinted
                                                         error:&error];
    return [HTTPStubsResponse responseWithData:jsonData statusCode:200 headers:nil];
}

- (HTTPStubsResponse *)responseWithJsonFile:(NSString *)fileName {
    return [HTTPStubsResponse responseWithFileAtPath:OHPathForFile(fileName, self.class)
                                          statusCode:200
                                             headers:@{@"Content-Type":@"application/json"}];
}

/// Tests

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
        return [self responseWithUserInfoJson];
    }];
    [self.userDefaults setObject:@[@"1", @"2", @"3"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];

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
    __block NSUInteger calendarListCallCount = 0;
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            // Have to use the calendarListCallCount because without valid authorization
            // there's no way to distinct requests per user (no Bearer in header fields)
            return [self responseWithJsonFile:(calendarListCallCount++ == 0) ? @"calendar_list_2.json" : @"calendar_list.json"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    expect(self.calendar.userAccounts.count).to(equal(2));

    [self loadCalendarLists];
    expect(self.calendar.accountEntries.count).to(equal(2));

    NSArray *entries1 = self.calendar.accountEntries[@"dterzic@gmail.com"];
    NSArray *entries2 = self.calendar.accountEntries[@"dterzictest@gmail.com"];

    expect(entries1.count).to(equal(2));
    expect(entries2.count).to(equal(3));

}

- (void)testGetCalendarOwner {
    __block NSUInteger calendarListCallCount = 0;
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            // Have to use the calendarListCallCount because without valid authorization
            // there's no way to distinct requests per user (no Bearer in header fields)
            return [self responseWithJsonFile:(calendarListCallCount++ == 0) ? @"calendar_list_2.json" : @"calendar_list.json"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    expect([self.calendar getCalendarOwner:@"dterzictest@gmail.com"]).to(equal(@"dterzictest@gmail.com"));
    expect([self.calendar getCalendarOwner:@"dterzic@gmail.com"]).to(equal(@"dterzic@gmail.com"));
}


- (void)testLoadCalendarListForRoleSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        return [self responseWithJsonFile:@"calendar_list.json"];
    }];

    [self loadCalendarLists];
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
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else {
            return [self responseWithJsonFile:@"calendar_events.json"];
        }
    }];

    [self loadCalendarLists];

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
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else {
            return [self responseWithJsonFile:@"calendar_events.json"];
        }
    }];

    [self loadCalendarLists];

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

- (void)testGetCalendarEvent {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"testeventid"]) {
            return [self responseWithJsonFile:@"calendar_event.json"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];
    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *calendarEventExpectation = [[XCTestExpectation alloc] initWithDescription:@"Get calendar event expectation"];

    [self.calendar getEventForCalendar:@"dterzictest@gmail.com"
                               eventId:@"testeventid"
                               success:^(GCWCalendarEvent *event) {
        expect(event.identifier).to(equal(@"testeventid"));
        expect(event.summary).to(equal(@"Test event"));
        expect(event.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603809000]));
        expect(event.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603812600]));

        [calendarEventExpectation fulfill];

    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[calendarEventExpectation] timeout:10.0];
}

- (void)testAddCalendarEvent {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"events"]) {
            return [self responseWithJsonFile:@"calendar_event.json"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];
    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *newCalendarEventExpectation = [[XCTestExpectation alloc] initWithDescription:@"New calendar event expectation"];

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];

    [self.calendar addEvent:event
                 toCalendar:@"dterzictest@gmail.com"
                    success:^(NSString *eventId) {
        expect(eventId).to(equal(@"testeventid"));
        [newCalendarEventExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[newCalendarEventExpectation] timeout:10.0];
}

- (void)testDeleteCalendarEvent {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"testeventid"]) {
            return [HTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];
    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *deleteCalendarEventExpectation = [[XCTestExpectation alloc] initWithDescription:@"Delete calendar event expectation"];

    [self.calendar deleteEvent:@"testeventid"
                  fromCalendar:@"dterzictest@gmail.com"
                       success:^{
        [deleteCalendarEventExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[deleteCalendarEventExpectation] timeout:10.0];
}

- (void)testUpdateCalendarEvent {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"events"]) {
            return [self responseWithJsonFile:@"calendar_event.json"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];
    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *updateCalendarEventExpectation = [[XCTestExpectation alloc] initWithDescription:@"Update calendar event expectation"];

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];

    [self.calendar updateEvent:event
                    inCalendar:@"dterzictest@gmail.com"
                       success:^{
        [updateCalendarEventExpectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[updateCalendarEventExpectation] timeout:10.0];
}

@end

