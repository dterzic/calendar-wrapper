#import "CalendarTests.h"
#import "GCWCalendarService.h"

@interface MockCalendarServiceController : NSObject <CalendarServiceDelegate>

@property (nonatomic, assign) int created;
@property (nonatomic, assign) int updated;
@property (nonatomic, assign) int deleted;
@property (nonatomic, assign) int synced;

@end

@implementation MockCalendarServiceController

- (void)calendarServiceDidCreateEvent:(GCWCalendarEvent *)event {
    self.created++;
}

- (void)calendarServiceDidUpdateEvent:(GCWCalendarEvent *)event {
    self.updated++;
}

- (void)calendarServiceDidDeleteEvent:(NSString *)eventId forCalendar:(NSString *)calendarId {
    self.deleted++;
}

- (void)calendarServiceDidSyncEvent:(GCWCalendarEvent *)event {
    self.synced++;
}

@end

@interface CalendarServiceTests : CalendarTests

@property (nonatomic) GCWCalendarService *calendarService;
@property (nonatomic) MockCalendarServiceController *controller;
@property (nonatomic, readonly) id <CalendarServiceProtocol> calendarServiceDelegate;

@end

@implementation CalendarServiceTests

- (id<CalendarServiceProtocol>)calendarServiceDelegate {
    return (id<CalendarServiceProtocol>)self.calendarService;
}

+ (NSDateFormatter *)dateFormatter {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return dateFormatter;
}

- (HTTPStubsResponse *)responseWithEventJson {
    NSString *start = [[CalendarServiceTests dateFormatter] stringFromDate:[NSDate date]];
    NSString *end = [[CalendarServiceTests dateFormatter] stringFromDate:[NSDate dateWithTimeIntervalSinceNow:60]];

    return [self responseWithJson:@{ @"id": @"1",
                                     @"status": @"confirmed",
                                     @"summary": @"Test meeting1",
                                     @"start": @{
                                         @"dateTime": start,
                                     },
                                     @"end": @{
                                         @"dateTime": end,
                                     }
                                }
            ];
}

- (HTTPStubsResponse *)responseWithEventsJson {
    NSString *start = [[CalendarServiceTests dateFormatter] stringFromDate:[NSDate date]];
    NSString *end = [[CalendarServiceTests dateFormatter] stringFromDate:[NSDate dateWithTimeIntervalSinceNow:60]];

    return [self responseWithJson:@{@"items": @[
                                            @{
                                                @"id": @"1",
                                                @"status": @"confirmed",
                                                @"summary": @"Test meeting1",
                                                @"start": @{
                                                    @"dateTime": start,
                                                },
                                                @"end": @{
                                                    @"dateTime": end,
                                                }
                                            },
                                            @{
                                                @"id": @"2",
                                                @"status": @"cancelled",
                                                @"summary": @"Test meeting2",
                                                @"start": @{
                                                    @"dateTime": start,
                                                },
                                                @"end": @{
                                                    @"dateTime": end,
                                                }
                                            },
                                   ]}
            ];
}

- (void)setUp {
    [super setUp];

    self.controller = [[MockCalendarServiceController alloc] init];
    self.calendarService = [[GCWCalendarService alloc] initWithPresentingViewController:nil
                                                                               delegate:self.controller
                                                                               calendar:self.calendar];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCreateCalendarEventSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"events"]) {
            return [self responseWithEventJson];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Create calendar event expectation"];

    expect(self.controller.created).to(equal(0));

    NSDate *date = [NSDate date];
    [self.calendarServiceDelegate createEventForCalendar:@"dterzictest@gmail.com"
                                               withTitle:@"Test meeting1"
                                                location:@"Test location"
                                 attendeesEmailAddresses:@[@"test1@email.com"]
                                             description:@"Test description"
                                                    date:date
                                                duration:123
                                               important:YES
                                                 success:^(NSString *eventId) {
        expect(self.controller.created).to(equal(1));
        expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testUpdateCalendarEventsSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"events"]) {
            return [self responseWithEventJson];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Update calendar event expectation"];

    expect(self.controller.updated).to(equal(0));
    expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];

    [self.calendarServiceDelegate updateEvent:event
                                  forCalendar:@"dterzictest@gmail.com"
                                      success:^{
        expect(self.controller.updated).to(equal(1));
        expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testUpdateCalendarEventsPreliminaryConditionError {
    __block NSUInteger eventsCallCount = 0;
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"testeventid"]) {
            if (eventsCallCount++ == 0) {
                return [HTTPStubsResponse responseWithData:[NSData data] statusCode:412 headers:nil];
            } else {
                return [self responseWithEventJson];
            }
        } else {
            return [self responseWithUserInfoJson];
        }
    }];
    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Update calendar event expectation"];

    expect(self.controller.updated).to(equal(0));
    expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));

    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] init];
    event.identifier = @"testeventid";
    event.calendarId = @"dterzictest@gmail.com";

    [self.calendarServiceDelegate updateEvent:event
                                  forCalendar:@"dterzictest@gmail.com"
                                      success:^{
        expect(self.controller.updated).to(equal(1));
        expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testDeleteCalendarEventsSuccess {
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

    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Update calendar event expectation"];

    expect(self.controller.deleted).to(equal(0));
    expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));

    [self.calendarServiceDelegate deleteEvent:@"testeventid"
                                 fromCalendar:@"dterzictest@gmail.com"
                                      success:^{
        expect(self.controller.deleted).to(equal(1));
        expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));
        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

- (void)testSyncCalendarEventsSuccess {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"accounts.google.com"] || [request.URL.host isEqualToString:@"www.googleapis.com"];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.lastPathComponent isEqualToString:@"calendarList"]) {
            return [self responseWithJsonFile:@"calendar_list.json"];
        } else if ([request.URL.lastPathComponent isEqualToString:@"events"]) {
            return [self responseWithEventsJson];
        } else {
            return [self responseWithUserInfoJson];
        }
    }];

    [self loadCalendarLists];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Syncing calendar events expectation"];

    expect(self.controller.deleted).to(equal(0));
    expect(self.controller.synced).to(equal(0));
    expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(0));

    [self.calendarServiceDelegate syncEventsOnSuccess:^(BOOL hasChanged) {
        expect(hasChanged).to(beTrue());
        expect(self.controller.deleted).to(equal(1));
        expect(self.controller.synced).to(equal(1));
        expect(self.calendarServiceDelegate.calendarEvents.count).to(equal(1));

        GCWCalendarEvent *event = self.calendarServiceDelegate.calendarEvents.allValues[0];
        expect(event.identifier).to(equal(@"1"));
        expect(event.summary).to(equal(@"Test meeting1"));
        expect(event.status).to(equal(@"confirmed"));

        [expectation fulfill];
    } failure:^(NSError *error) {
    }];
    [self waitForExpectations:@[expectation] timeout:10.0];
}

@end
