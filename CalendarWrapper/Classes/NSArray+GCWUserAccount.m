#import "NSArray+GCWUserAccount.h"
#import "GCWUserAccount.h"

static NSString *const kCalendarUserAccountKey = @"calendarWrapperCalendarUserAccountKey";


@implementation NSArray (GCWUserAccount)

- (NSArray *)userAccounts {
    return self;
}

+ (NSArray *)unarchiveUserAccountsFrom:(NSArray *)archive {
    NSMutableArray *userAccounts = [NSMutableArray array];
    for (NSData *data in archive) {
        NSError *error = nil;
        NSKeyedUnarchiver *secureDecoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];

        if (error) {
            NSLog(@"NSArray: Unarchive user account failed with error: %@", error);
        } else {
            [secureDecoder setRequiresSecureCoding:YES];

            NSSet *classes = [NSSet setWithObjects:GCWUserAccount.class, NSString.class, nil];
            GCWUserAccount *userAccount = [secureDecoder decodeObjectOfClasses:classes forKey:kCalendarUserAccountKey];

            [userAccounts addObject:userAccount];
        }
    }
    return [userAccounts copy];
}

- (NSArray *)archiveUserAccounts {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (GCWUserAccount *userAccount in self) {
        NSKeyedArchiver *secureEncoder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

        [secureEncoder encodeObject:userAccount forKey:kCalendarUserAccountKey];
        [secureEncoder finishEncoding];

        NSData *data = [secureEncoder encodedData];

        [archiveArray addObject:data];
    }
    return archiveArray;
}

@end
