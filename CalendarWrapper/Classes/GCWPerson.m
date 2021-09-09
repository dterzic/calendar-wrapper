#import "GCWPerson.h"

@implementation GCWPerson

@synthesize name = _name;
@synthesize email = _email;
@synthesize title = _title;
@synthesize department = _department;
@synthesize phoneNumber = _phoneNumber;
@synthesize phoneDesription = _phoneDesription;
@synthesize photoUrl = _photoUrl;

- (instancetype)initWithPerson:(GTLRPeopleService_Person *)person {
    self = [super init];
    if (self) {
        GTLRPeopleService_Name *name = person.names[0];
        GTLRPeopleService_EmailAddress *emailAddress = person.emailAddresses[0];
        GTLRPeopleService_PhoneNumber *phone = person.phoneNumbers[0];
        GTLRPeopleService_Photo *photo = person.photos[0];
        GTLRPeopleService_Organization *organization = person.organizations[0];

        _name = [name.displayName copy];
        _email = [emailAddress.value copy];
        _title = [organization.title copy];
        _department = [organization.department copy];
        _phoneNumber = [phone.value copy];
        _phoneDesription = [phone.formattedType copy];
        _photoUrl = [photo.url copy];
    }
    return self;
}

@end
