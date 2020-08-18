//
//  GCWViewController.m
//  CalendarWrapper
//
//  Created by Dusan Terzic on 07/05/2019.
//  Copyright (c) 2019 Dusan Terzic. All rights reserved.
//

#import "GCWViewController.h"
#import "GCWCalendar.h"

static NSString * _Nonnull const kClientID = @"48568066200-or08ed9efloks9ci5494f8jmcogucg1t.apps.googleusercontent.com";

@interface GCWViewController () <GCWCalendarDelegate, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *defaultCalendarLabel;
@property (weak, nonatomic) IBOutlet GIDSignInButton *signInButton;
@property (weak, nonatomic) IBOutlet UIButton *loadButton;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UITableView *eventsTable;

@property (nonatomic) GCWCalendar *calendar;
@property (nonatomic, copy) NSDictionary *calendars;
@property (nonatomic, readonly) NSString *defaultCalendarId;
@property (nonatomic, copy) NSString *calendarEventId;
@property (nonatomic, copy) NSDictionary *events;

@end

@implementation GCWViewController

- (NSString *)defaultCalendarId {
    return self.calendars.allKeys[0];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.calendar = [[GCWCalendar alloc] initWithClientId:kClientID delegate:self];
    GIDSignIn.sharedInstance.presentingViewController = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

        self.defaultCalendarLabel.text = self.calendars[self.defaultCalendarId];
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
                                    endDate:[NSDate dateWithTimeIntervalSinceNow:7 * 24 * 3600] success:^(NSDictionary *events) {
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
    [self.calendar loadCalendarList:^(NSDictionary *calendars) {
        self.calendars = calendars;
        [self hideLogin];
        [self loadEvents];
    } failure:^(NSError *error) {
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
    GTLRCalendar_Event *event = [GCWCalendar createEventWithTitle:@"Event title"
                                                         location:@"Infinite Loop, Cupertino, CA 95014, USA"
                                                      description:@"Test event"
                                                             date:[NSDate dateWithTimeIntervalSinceNow:3600] duration:30];
    __weak GCWViewController *weakSelf = self;
    [self.calendar addEvent:event toCalendar:self.defaultCalendarId success:^(NSString *eventId) {
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
    [self.calendar deleteEvent:self.calendarEventId fromCalendar:self.defaultCalendarId success:^{
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
    [GIDSignIn.sharedInstance signOut];
    [self showLogin];
}

- (void)calendar:(GCWCalendar *)calendar didDisconnectWithUser:(GIDGoogleUser *)user withError:(NSError *)error {
    if (error) {
        [self showAlertWithTitle:@"Error" description:error.localizedDescription];
    } else {
        [self showAlertWithTitle:@"Info" description:@"Logout succeeded"];
    }
}

- (void)calendar:(GCWCalendar *)calendar didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error {
    if (error) {
        [self showLogin];
        [self showAlertWithTitle:@"Error" description:error.localizedDescription];
    } else {
        [self hideLogin];
    }
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
    GTLRCalendar_Event *event = _events.allValues[indexPath.row];
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.text = [NSString stringWithFormat:@"%@\n%@", event.summary, event.location];
    cell.backgroundColor = (indexPath.row % 2) ? UIColor.whiteColor : UIColor.lightGrayColor;

    return cell;
}

@end
