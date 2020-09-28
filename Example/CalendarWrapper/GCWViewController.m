//
//  GCWViewController.m
//  CalendarWrapper
//
//  Created by Dusan Terzic on 07/05/2019.
//  Copyright (c) 2019 Dusan Terzic. All rights reserved.
//

#import "GCWViewController.h"
#import "GCWCalendar.h"
#import "GCWCalendarEvent.h"

static NSString * _Nonnull const kClientID = @"350629588452-bcbi20qrl4tsvmtia4ps4q16d8i9sc4l.apps.googleusercontent.com";

@interface GCWViewController () <GCWCalendarDelegate, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *defaultCalendarLabel;
@property (weak, nonatomic) IBOutlet UIButton *signInButton;
@property (weak, nonatomic) IBOutlet UIButton *loadButton;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UITableView *eventsTable;

@property (nonatomic) GCWCalendar *calendar;
@property (nonatomic, copy) NSDictionary *calendars;
@property (nonatomic, readonly) GTMAppAuthFetcherAuthorization *defaultAuthorization;
@property (nonatomic, readonly) NSString *defaultCalendarId;
@property (nonatomic, copy) NSString *calendarEventId;
@property (nonatomic, copy) NSDictionary *events;

@end

@implementation GCWViewController

+ (UIColor *)colorWithHex:(NSString *)hex {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    scanner.scanLocation = 1;
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

- (GTMAppAuthFetcherAuthorization *)defaultAuthorization {
    return self.calendar.authorizations[0];
}

- (NSString *)defaultCalendarId {
    return self.calendars.allKeys[0];
}

- (UIColor *)defaultCalendarBackgroundColor {
    GTLRCalendar_CalendarListEntry *calendar = self.calendars[self.defaultCalendarId];
    return [GCWViewController colorWithHex:calendar.backgroundColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillGoToBackground:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];

    self.calendar = [[GCWCalendar alloc] initWithClientId:kClientID presentingViewController:self delegate:self];
    [self.calendar loadAuthorizationsOnSuccess:^{
        [self loadCalendarList];
    } failure:^(NSError * error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.calendar doLoginOnSuccess:^{
                [self hideLogin];
            } failure:^(NSError * error) {
                [self showLogin];
            }];
        });
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)appWillGoToBackground:(NSNotification *)note {
    [self.calendar saveAuthorizations];
}

- (void)showAlertWithTitle:(NSString *)title description:(NSString *)description {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:description
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:ok];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:true completion:nil];
    });
}

- (void)showLogin {
    self.signInButton.hidden = false;
    self.defaultCalendarLabel.hidden = true;
    self.loadButton.hidden = true;
    self.addButton.hidden = true;
    self.deleteButton.hidden = true;
    self.logoutButton.hidden = true;
    self.eventsTable.hidden = true;
}

- (void)hideLogin {
    self.signInButton.hidden = true;
    if (self.calendars) {
        self.defaultCalendarLabel.hidden = false;
        self.loadButton.hidden = true;
        self.addButton.hidden = false;
        self.deleteButton.hidden = false;
        self.logoutButton.hidden = false;
        self.eventsTable.hidden = false;

        GTLRCalendar_CalendarListEntry *calendar = self.calendars[self.defaultCalendarId];
        self.defaultCalendarLabel.text = calendar.summary;
    } else {
        self.defaultCalendarLabel.hidden = true;
        self.loadButton.hidden = false;
        self.addButton.hidden = true;
        self.deleteButton.hidden = true;
        self.logoutButton.hidden = true;
        self.eventsTable.hidden = true;
    }
}

- (void)loadEvents {
    __weak GCWViewController *weakSelf = self;
    [self.calendar getEventsListForCalendar:self.defaultCalendarId
                                  startDate:[NSDate date]
                                    endDate:[NSDate dateWithTimeIntervalSinceNow:7 * 24 * 3600]
                                 maxResults:0
                                    success:^(NSDictionary *events) {
        self.events = events;
        [_eventsTable reloadData];
    } failure:^(NSError *error) {
        if (error.code == 1001) {
            [weakSelf showLogin];
        }
        [weakSelf showAlertWithTitle:@"Error" description:error.localizedDescription];
    }];
}

- (void)loadCalendarList {
    __weak GCWViewController *weakSelf = self;
    [self.calendar loadCalendarListsForRole:kGTLRCalendarMinAccessRoleOwner success:^(NSDictionary * calendars) {
        self.calendars = calendars;
        [self hideLogin];
        [self loadEvents];
    } failure:^(NSError * error) {
        if (error.code == 1001) {
            [weakSelf showLogin];
        }
        [weakSelf showAlertWithTitle:@"Error" description:error.localizedDescription];
    }];
}

- (IBAction)loadListClicked:(id)sender {
    [self loadCalendarList];
}

- (IBAction)addEventClicked:(id)sender {
    if (!self.calendars) {
        [self loadCalendarList];
        return;
    }
    GCWCalendarEvent *event = [GCWCalendar createEventWithTitle:@"Event title"
                                                       location:@"Infinite Loop, Cupertino, CA 95014, USA"
                                                    description:@"Test event"
                                                           date:[NSDate dateWithTimeIntervalSinceNow:3600] duration:30];
    __weak GCWViewController *weakSelf = self;
    [self.calendar addEvent:event
                 toCalendar:self.defaultCalendarId
                    success:^(NSString *eventId) {
        weakSelf.calendarEventId = eventId;
        [weakSelf loadEvents];
        [weakSelf showAlertWithTitle:@"Info" description:@"Calendar event added!"];
    } failure:^(NSError *error) {
        if (error.code == 1001) {
            [weakSelf showLogin];
        }
        [weakSelf showAlertWithTitle:@"Error" description:error.localizedDescription];
    }];
}

- (IBAction)deleteEventClicked:(id)sender {
    __weak GCWViewController *weakSelf = self;
    [self.calendar deleteEvent:self.calendarEventId
                  fromCalendar:self.defaultCalendarId
                       success:^{
        [weakSelf loadEvents];
        [weakSelf showAlertWithTitle:@"Info" description:@"Calendar event deleted!"];
    } failure:^(NSError *error) {
        if (error.code == 1001) {
            [weakSelf showLogin];
        }
        [weakSelf showAlertWithTitle:@"Error" description:error.localizedDescription];
    }];
}

- (IBAction)logoutClicked:(id)sender {
    self.calendars = nil;
    [self.calendar.authorizations removeObject:self.defaultAuthorization];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLogin];
        [self.calendar doLoginOnSuccess:^{
            [self hideLogin];
        } failure:^(NSError * error) {
            [self showLogin];
        }];
    });
}

- (void)calendarLoginRequired:(GCWCalendar *)calendar {
    [self showLogin];
}

// UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.events.allValues.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"cellIdentifier";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    GCWCalendarEvent *event = _events.allValues[indexPath.row];
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.text = [NSString stringWithFormat:@"%@\n%@", event.summary, event.location];
    cell.textLabel.textColor = [self defaultCalendarBackgroundColor];
    cell.backgroundColor = (indexPath.row % 2) ? UIColor.whiteColor : UIColor.lightGrayColor;

    return cell;
}

@end
