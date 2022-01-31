#import "NSDictionary+GCWUserAccount.h"
#import "GCWUserAccount.h"

static NSString *const kCalendarUserAccountKey = @"calendarWrapperCalendarUserAccountKey";


@implementation NSDictionary (GCWUserAccount)

- (NSDictionary *)userAccounts {
    return self;
}

+ (NSDictionary *)unarchiveUserAccountsFrom:(NSDictionary *)archive {
    NSMutableDictionary *userAccounts = [NSMutableDictionary dictionary];

    [archive enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSData *data = (NSData *)obj;
        NSError *error = nil;
        NSSet *classes = [NSSet setWithObjects:GCWUserAccount.class, NSString.class, nil];
        GCWUserAccount *entry = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&error];
        if (error) {
            NSLog(@"Unarchive entry failed with error: %@", error);
        } else {
            [userAccounts setValue:entry forKey:key];
        }
    }];
    return [userAccounts copy];
}

- (NSDictionary *)archiveUserAccounts {
    NSMutableDictionary *archiveDictionary = [NSMutableDictionary dictionaryWithCapacity:self.count];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        GCWUserAccount *userAccount = (GCWUserAccount *)obj;
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:userAccount requiringSecureCoding:YES error:&error];
        if (error) {
            NSLog(@"Archive user account failed with error: %@", error);
        } else {
            [archiveDictionary setValue:data forKey:key];
        }
    }];
    return archiveDictionary;
}

@end
