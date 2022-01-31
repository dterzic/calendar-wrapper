#import <Foundation/Foundation.h>

@class GCWUserAccount;

@interface NSDictionary (GCWUserAccount)

@property (nonatomic, readonly) NSDictionary <NSString *, GCWUserAccount *> *userAccounts;

+ (NSDictionary *)unarchiveUserAccountsFrom:(NSDictionary *)archive;
- (NSDictionary *)archiveUserAccounts;

@end
