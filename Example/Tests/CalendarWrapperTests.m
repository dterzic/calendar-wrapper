#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>

#import "CalendarTests.h"

static NSString *const kUserIDs = @"googleUserIDsKey";

@interface CalendarWrapperTests : CalendarTests

@end

@implementation CalendarWrapperTests

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

- (void)testLoadAuthorization_NoValidAuthorization {
    [self.userDefaults setObject:nil forKey:kUserIDs];
    [self.userDefaults synchronize];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load authorizations expectation"];

    self.authorizationManager.canAuthorize = YES;
    [self.calendar loadAuthorizationsOnSuccess:^{
    } failure:^(NSError *error) {
        expect(error.code).to(equal(-10001));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
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
    expect([self.calendar getCalendarOwner:@"sr.rs#holiday@group.v.calendar.google.com"]).to(equal(@"dterzictest@gmail.com"));
    expect([self.calendar getCalendarOwner:@"addressbook#contacts@group.v.calendar.google.com"]).to(equal(@"dterzictest@gmail.com"));

    expect([self.calendar getCalendarOwner:@"dterzic@gmail.com"]).to(equal(@"dterzic@gmail.com"));
    expect([self.calendar getCalendarOwner:@"rgordc83ks79c83gbp5i5da5c4@group.calendar.google.com"]).to(equal(@"dterzic@gmail.com"));
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

- (void)testLoadCalendarListForRoleErrorResponse {
    [self stubGoogleApisRequestWithError:400];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar list expectation"];

    [self.calendar loadCalendarListsForRole:@"test" success:^(NSDictionary *calendarList) {
    } failure:^(NSError *error) {
        expect(error.code).to(equal(400));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
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

- (void)testLoadCalendarEventsSuccess {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withJsonFile:@"calendar_events.json"];
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

- (void)testLoadCalendarEventsErrorResponse {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withError:400];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Load calendar events expectation"];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:1601503200];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:1604185199];
    [self.calendar getEventsListForCalendar:@"dterzictest@gmail.com"
                             startDate:startDate
                               endDate:endDate
                            maxResults:200
                               success:^(NSDictionary *events) {
    } failure:^(NSError *error) {
        expect(error.code).to(equal(400));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testSyncCalendarEventsSuccess {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withJsonFile:@"calendar_events.json"];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Syncing calendar events expectation"];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:1603753200];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:1604185199];
    [self.calendar syncEventsFrom:startDate
                          to:endDate
                          success:^(NSDictionary *syncedEvents, NSArray *removedEvents) {
        expect(syncedEvents.count).to(equal(2));

        GCWCalendarEvent *event1 = syncedEvents.allValues[0];
        expect(event1.summary).to(equal(@"Test meeting 2"));
        expect(event1.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603809000]));
        expect(event1.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603812600]));
        expect(event1.attendeesEmailAddresses.count).to(equal(2));
        expect(event1.attendeesEmailAddresses[0]).to(equal(@"dterzic@gmail.com"));
        expect(event1.attendeesEmailAddresses[1]).to(equal(@"dterzictest@gmail.com"));
        expect(event1.hangoutLink).to(equal(@"https://meet.google.com/hpr-bwei-rqc"));

        GCWCalendarEvent *event2 = syncedEvents.allValues[1];
        expect(event2.summary).to(equal(@"Test reccurring"));
        expect(event2.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603800000]));
        expect(event2.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603886400]));
        expect(event2.recurringEventId).to(equal(@"5nek4vfo0j9u8vn5kf2l0jufe0"));

        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testSyncCalendarEventsErrorResponse {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withError:400];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Syncing calendar events expectation"];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:1603753200];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:1604185199];
    [self.calendar syncEventsFrom:startDate
                          to:endDate
                          success:^(NSDictionary *syncedEvents, NSArray *removedEvents) {
    } failure:^(NSError *error) {
        expect(error.code).to(equal(400));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testGetCalendarEvent {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"testeventid" withJsonFile:@"calendar_event.json"];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Get calendar event expectation"];

    [self.calendar getEventForCalendar:@"dterzictest@gmail.com"
                               eventId:@"testeventid"
                               success:^(GCWCalendarEvent *event) {
        expect(event.identifier).to(equal(@"testeventid"));
        expect(event.summary).to(equal(@"Test event"));
        expect(event.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603809000]));
        expect(event.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1603812600]));

        [expectation fulfill];

    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testGetCalendarEventErrorResponse {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"testeventid" withError:400];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Get calendar event expectation"];

    [self.calendar getEventForCalendar:@"dterzictest@gmail.com"
                               eventId:@"testeventid"
                               success:^(GCWCalendarEvent *event) {
    } failure:^(NSError *error) {
        expect(error.code).to(equal(400));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testAddCalendarEvent {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withJsonFile:@"calendar_event.json"];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"New calendar event expectation"];

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];

    [self.calendar addEvent:event
                 toCalendar:@"dterzictest@gmail.com"
                    success:^(NSString *eventId) {
        expect(eventId).to(equal(@"testeventid"));
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testAddCalendarEventErrorResponse {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withError:400];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"New calendar event expectation"];

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];

    [self.calendar addEvent:event
                 toCalendar:@"dterzictest@gmail.com"
                    success:^(NSString *eventId) {
    } failure:^(NSError *error) {
        expect(error.code).to(equal(400));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
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

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Delete calendar event expectation"];

    [self.calendar deleteEvent:@"testeventid"
                  fromCalendar:@"dterzictest@gmail.com"
                       success:^{
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testDeleteCalendarEventErrorResponse {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"testeventid" withError:400];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Delete calendar event expectation"];

    [self.calendar deleteEvent:@"testeventid"
                  fromCalendar:@"dterzictest@gmail.com"
                       success:^{
    } failure:^(NSError *error) {
        expect(error.code).to(equal(400));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testUpdateCalendarEvent {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withJsonFile:@"calendar_event.json"];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Update calendar event expectation"];

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];

    [self.calendar updateEvent:event
                    inCalendar:@"dterzictest@gmail.com"
                       success:^{
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testUpdateCalendarEventErrorResponse {
    [self stubGoogleApisRequestIndentifiedByLastPathComponent:@"events" withError:400];

    [self.userDefaults setObject:@[@"dterzic@gmail.com", @"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Update calendar event expectation"];

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];

    [self.calendar updateEvent:event
                    inCalendar:@"dterzictest@gmail.com"
                       success:^{
    } failure:^(NSError *error) {
        expect(error.code).to(equal(400));
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testBatchAddEvents {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.path isEqualToString:@"/batch/calendar/v3"]) {
            return [self responseWithMultipartContentFile:@"batch_add.txt" boundary:@"batch_5oddruAmmQmbGT1DgIzuJ3icF9J60RDz"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self.userDefaults setObject:@[@"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Batch add calendar events expectation"];

    GCWCalendarEvent *event1 = [[GCWCalendarEvent alloc] init];
    event1.calendarId = @"dterzictest@gmail.com";
    GCWCalendarEvent *event2 = [[GCWCalendarEvent alloc] init];
    event2.calendarId = @"dterzictest@gmail.com";
    NSMutableArray *events = [NSMutableArray arrayWithObjects:event1, event2, nil];

    [self.calendar batchAddEvents:events
                          success:^(NSArray<GCWCalendarEvent *> *events) {
        GCWCalendarEvent *event1 = events[0];
        expect(event1.summary).to(equal(@"Test update 8"));
        expect(event1.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1605717000]));
        expect(event1.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1605720600]));
        expect(event1.status).to(equal("confirmed"));

        GCWCalendarEvent *event2 = events[1];
        expect(event2.summary).to(equal(@"Test update 81"));
        expect(event2.startDate).to(equal([NSDate dateWithTimeIntervalSince1970:1605803400]));
        expect(event2.endDate).to(equal([NSDate dateWithTimeIntervalSince1970:1605807000]));
        expect(event2.status).to(equal("confirmed"));

        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testBatchUpdateEvents {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.path isEqualToString:@"/batch/calendar/v3"]) {
            return [self responseWithMultipartContentFile:@"batch_update.txt" boundary:@"batch_UDQZmJHrEjzmjjjVB83P9xJE_9-ox97l"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self.userDefaults setObject:@[@"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Batch add calendar events expectation"];

    GCWCalendarEvent *event1 = [[GCWCalendarEvent alloc] init];
    event1.calendarId = @"dterzictest@gmail.com";
    GCWCalendarEvent *event2 = [[GCWCalendarEvent alloc] init];
    event2.calendarId = @"dterzictest@gmail.com";
    NSMutableArray *events = [NSMutableArray arrayWithObjects:event1, event2, nil];

    [self.calendar batchUpdateEvents:events
                             success:^{
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testBatchDeleteEvents {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.path isEqualToString:@"/batch/calendar/v3"]) {
            return [self responseWithMultipartContentFile:@"batch_delete.txt" boundary:@"batch_Slg_g56t3GK7Igt3koEC0SfZXH05Gcfc"];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self.userDefaults setObject:@[@"dterzictest@gmail.com"] forKey:kUserIDs];
    [self.userDefaults synchronize];

    [self loadAuthorizations];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Batch add calendar events expectation"];

    NSMutableArray *eventIds = [NSMutableArray arrayWithObjects:@"testEvent1", @"testEvent2", nil];
    NSMutableArray *calendarIds = [NSMutableArray arrayWithObjects:@"dterzictest@gmail.com", @"dterzictest@gmail.com", nil];

    [self.calendar batchDeleteEvents:eventIds
                       fromCalendars:calendarIds
                             success:^{
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

@end

