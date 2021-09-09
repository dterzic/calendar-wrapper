#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWPerson : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *department;
@property (nonatomic, readonly) NSString *phoneNumber;
@property (nonatomic, readonly) NSString *phoneDesription;
@property (nonatomic, readonly) NSString *photoUrl;

- (instancetype)initWithPerson:(GTLRPeopleService_Person *)person;

@end
