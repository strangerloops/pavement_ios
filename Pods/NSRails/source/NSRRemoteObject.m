/*
 
 _|_|_|    _|_|  _|_|  _|_|  _|  _|      _|_|           
 _|  _|  _|_|    _|    _|_|  _|  _|_|  _|_| 
 
 NSRRemoteObject.m
 
 Copyright (c) 2012 Dan Hassin.
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "NSRails.h"
#import "NSRRemoteObject.h"

#import <objc/runtime.h>


////////////////////////////////////////////////////////////////////////////////////////////////////

@interface NSRRemoteObject (private)

- (NSDictionary *) remoteDictionaryRepresentationWrapped:(BOOL)wrapped fromNesting:(BOOL)nesting;

- (BOOL) propertyIsTimestamp:(NSString *)property;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////


@implementation NSRRemoteObject

//Need these to be explicit when subclassing from NSManagedObject
@synthesize remoteID=_remoteID;
@synthesize remoteAttributes=_remoteAttributes;
@synthesize remoteDestroyOnNesting=_remoteDestroyOnNesting;

#pragma mark - Private

- (NSNumber *) primitiveRemoteID
{
    return _remoteID;
}

#pragma mark - Overrides

+ (NSRConfig *) config
{
    return [NSRConfig contextuallyRelevantConfig];
}

+ (NSString *) remoteModelName
{
    if (self == [NSRRemoteObject class]) {
        return nil;
    }
        
    NSString *class = NSStringFromClass(self);
    
    if ([self config].autoinflectsClassNames)
    {
        return [self stringByUnderscoringString:class ignoringPrefix:[self config].ignoresClassPrefixes];
    }
    else
    {
        return class;
    }
}

+ (NSString *) remoteControllerName
{
    NSString *singular = [self remoteModelName];
        
    if ([singular hasSuffix:@"y"] && ![singular hasSuffix:@"ey"]) {
        return [[singular substringToIndex:singular.length-1] stringByAppendingString:@"ies"];
    }
    
    if ([singular hasSuffix:@"s"]) {
        return [singular stringByAppendingString:@"es"];
    }
    
    return [singular stringByAppendingString:@"s"];
}

- (BOOL) propertyIsTimestamp:(NSString *)property
{
    return ([property isEqualToString:@"createdAt"] || [property isEqualToString:@"updatedAt"] ||
            [property isEqualToString:@"created_at"] || [property isEqualToString:@"updated_at"]);
}

- (BOOL) valueIsArray:(id)value
{
    return ([value isKindOfClass:[NSArray class]] || 
            [value isKindOfClass:[NSSet class]] || 
            [value isKindOfClass:[NSOrderedSet class]]);
}

- (BOOL) propertyIsDate:(NSString *)property
{
    //give rubymotion the _at dates for frees
    return ([self propertyIsTimestamp:property] ||
            [[self.class typeForProperty:property] isEqualToString:@"@\"NSDate\""]);
}

+ (NSString *) typeForProperty:(NSString *)prop
{
    objc_property_t property = class_getProperty(self, [prop UTF8String]);
    if (!property) {
        return nil;
    }
    
    // This will return some garbage like "Ti,GgetFoo,SsetFoo:,Vproperty"
    // See https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
    
    NSString *atts = @(property_getAttributes(property));
    
    for (NSString *att in [atts componentsSeparatedByString:@","])
        if ([att hasPrefix:@"T"]) {
            return [att substringFromIndex:1];
        }
    
    return nil;
}

+ (Class) typeClassForProperty:(NSString *)property
{
    NSString *propType = [[[self.class typeForProperty:property] stringByReplacingOccurrencesOfString:@"\"" withString:@""] stringByReplacingOccurrencesOfString:@"@" withString:@""];
    
    return NSClassFromString(propType);
}

- (NSMutableArray *) remoteProperties
{
    NSMutableArray *results = [NSMutableArray array];
    
    for (Class c = self.class; c != [NSRRemoteObject class]; c = c.superclass)
    {
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(c, &propertyCount);
        
        if (properties)
        {
            while (propertyCount--)
            {
                NSString *name = @(property_getName(properties[propertyCount]));
                // makes sure it's not primitive
                if ([[self.class typeForProperty:name] rangeOfString:@"@"].location != NSNotFound) {
                    [results addObject:name];
                }
            }
            
            free(properties);
        }
    }
    
    [results addObject:@"remoteID"];
    return results;
}

- (NSRRemoteObject *) objectUsedToPrefixRequest:(NSRRequest *)verb
{
    return nil;
}

- (BOOL) shouldOnlySendIDKeyForNestedObjectProperty:(NSString *)property
{
    return NO;
}

- (Class) nestedClassForProperty:(NSString *)property
{ 
    Class class = [self.class typeClassForProperty:property];
    return ([class isSubclassOfClass:[NSRRemoteObject class]] ? class : nil);
}

- (id) encodeValueForProperty:(NSString *)property remoteKey:(NSString **)remoteKey
{    
    if ([property isEqualToString:@"remoteID"]) {
        *remoteKey = @"id";
    }
    
    Class nestedClass = [self nestedClassForProperty:property];
    id val = [self valueForKey:property];
    
    if (nestedClass)
    {
        if ([self shouldOnlySendIDKeyForNestedObjectProperty:property])
        {
            if ([self valueIsArray:val])
            {
                NSString *singular = *remoteKey;
                if ([singular hasSuffix:@"ies"]) {
                    singular = [singular substringToIndex:singular.length-3];
                }
                else if ([singular hasSuffix:@"s"]) {
                    singular = [singular substringToIndex:singular.length-1];
                }
                
                *remoteKey = [singular stringByAppendingString:@"_ids"];
                return [val valueForKeyPath:@"@unionOfObjects.remoteID"];
            }
            else
            {
                *remoteKey = [*remoteKey stringByAppendingString:@"_id"];
                return [val remoteID];
            }
        }
        
        *remoteKey = [*remoteKey stringByAppendingString:@"_attributes"];
        
        if ([self valueIsArray:val])
        {
            NSMutableArray *new = [NSMutableArray arrayWithCapacity:[val count]];
            
            for (id element in val)
            {
                id encodedObj = [element remoteDictionaryRepresentationWrapped:NO fromNesting:YES];
                [new addObject:encodedObj];
            }
            
            return new;
        }
        
        return [val remoteDictionaryRepresentationWrapped:NO fromNesting:YES];
    }

    if ([val isKindOfClass:[NSDate class]])
    {
        return [[self.class config] stringFromDate:val];
    }

    return val;
}

- (NSString *) propertyForRemoteKey:(NSString *)remoteKey
{
    if ([remoteKey isEqualToString:@"id"]) {
        return @"remoteID";
    }

    NSString *property = remoteKey;
    if ([self.class config].autoinflectsPropertyNames) {
        property = [self.class stringByCamelizingString:property];
    }
    
    return ([self.remoteProperties containsObject:property] ? property : nil);
}

- (Class) containerClassForRelationProperty:(NSString *)property
{
    return [NSMutableArray class];
}

- (BOOL) shouldReplaceCollectionForProperty:(NSString *)property
{
    return YES;
}

- (void) decodeRemoteValue:(id)railsObject forRemoteKey:(NSString *)remoteKey
{
    NSString *property = [self propertyForRemoteKey:remoteKey];
    
    if (!property) {
        return;
    }

    Class nestedClass = [self nestedClassForProperty:property];
    
    id previousVal = [self valueForKey:property];
    id decodedObj = nil;
    
    if (railsObject)
    {
        if (nestedClass)
        {
            if ([self valueIsArray:railsObject])
            {
                decodedObj = [[[self containerClassForRelationProperty:property] alloc] init];
                                
                id previousArray = ([previousVal isKindOfClass:[NSSet class]] ? 
                                    [previousVal allObjects] :
                                    [previousVal isKindOfClass:[NSOrderedSet class]] ?
                                    [previousVal array] :
                                    previousVal);
                
                if (![self shouldReplaceCollectionForProperty:property])
                {
                    [decodedObj addObjectsFromArray:previousArray];
                }
                
                for (id railsElement in railsObject)
                {
                    id decodedElement;
                    
                    //see if there's a nester that matches this ID - we'd just have to update it w/this dict
                    NSNumber *railsID = railsElement[@"id"];
                    
                    //maybe the object is wrapped in a dict like {"post"=>{"something":"something"}}, so check to make sure
                    if (!railsID)
                    {
                        NSDictionary *innerDict = railsElement[[nestedClass remoteModelName]];
                        if ([railsElement count] == 1 && [innerDict isKindOfClass:[NSDictionary class]]) {
                            railsID = innerDict[@"id"];
                        }
                    }
                    
                    id existing = nil;
                    
                    if (railsID) {
                        existing = [[previousArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"remoteID == %@",railsID]] lastObject];
                    }
                    
                    if (!existing)
                    {
                        //didn't previously exist - make a new one
                        decodedElement = [nestedClass objectWithRemoteDictionary:railsElement];
                    }
                    else
                    {
                        //existed - simply update that one (recursively)
                        decodedElement = existing;
                        [decodedElement setPropertiesUsingRemoteDictionary:railsElement];
                    }
                    
                    if (!existing || [self shouldReplaceCollectionForProperty:property]) {
                        [decodedObj addObject:decodedElement];
                    }
                }
            }
            else
            {
                //if the nested object didn't exist before, make it & set it
                if (!previousVal)
                {
                    decodedObj = [nestedClass objectWithRemoteDictionary:railsObject];
                }
                //otherwise, keep the old object & update to whatever was given
                else
                {
                    decodedObj = previousVal;
                    [decodedObj setPropertiesUsingRemoteDictionary:railsObject];
                }
            }
        }
        else if ([self propertyIsDate:property])
        {
            decodedObj = [[self.class config] dateFromString:railsObject];
        }
        //otherwise, if not nested or anything, just use what we got (number, string, dictionary, array)
        else
        {
            decodedObj = railsObject;
        }
    }
    
    [self setValue:decodedObj forKey:property];
}

- (BOOL) shouldSendProperty:(NSString *)property whenNested:(BOOL)nested
{
    //don't include id if it's nil or on the main object (nested guys need their IDs)
    if ([property isEqualToString:@"remoteID"] && (!self.remoteID || !nested)) {
        return NO;
    }
    
    //don't include updated_at or created_at
    if ([self propertyIsTimestamp:property]) {
        return NO;
    }
    
    Class nestedClass = [self nestedClassForProperty:property];
    
    if (nestedClass && ![self shouldOnlySendIDKeyForNestedObjectProperty:property])
    {
        //this is recursion-protection. we don't want to include every nested class in this class because one of those nested class could nest us, causing infinite loop. of course, overridable
        if (nested)
        {
            return NO;
        }
        
        id val = [self valueForKey:property];

        //don't send if there's no val or empty (is okay on belongs_to bc we send a null id)
        if (!val || ([self valueIsArray:val] && [val count] == 0))
        {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Internal NSR stuff

- (void) setPropertiesUsingRemoteDictionary:(NSDictionary *)dict
{
    if (dict) {
        _remoteAttributes = dict;
    }
    
    //support JSON that comes in like {"post"=>{"something":"something"}}
    NSDictionary *innerDict = dict[[self.class remoteModelName]];
    if (dict.count == 1 && [innerDict isKindOfClass:[NSDictionary class]])
    {
        dict = innerDict;
    }
        
    for (NSString *remoteKey in dict)
    {
        id remoteObject = dict[remoteKey];
        if (remoteObject == [NSNull null]) {
            remoteObject = nil;
        }

        [self decodeRemoteValue:remoteObject forRemoteKey:remoteKey];
    }
}

- (NSDictionary *) remoteDictionaryRepresentationWrapped:(BOOL)wrapped
{
    return [self remoteDictionaryRepresentationWrapped:wrapped fromNesting:NO];
}

- (NSDictionary *) remoteDictionaryRepresentationWrapped:(BOOL)wrapped fromNesting:(BOOL)nesting
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    for (NSString *objcProperty in [self remoteProperties])
    {
        if (![self shouldSendProperty:objcProperty whenNested:nesting]) {
            continue;
        }
        
        NSString *remoteKey = objcProperty;
        if ([self.class config].autoinflectsPropertyNames) {
            remoteKey = [self.class stringByUnderscoringString:remoteKey ignoringPrefix:NO];
        }
        
        id remoteRep = [self encodeValueForProperty:objcProperty remoteKey:&remoteKey];
        if (!remoteRep) {
            remoteRep = [NSNull null];
        }
        
        BOOL JSONParsable = ([remoteRep isKindOfClass:[NSArray class]] ||
                             [remoteRep isKindOfClass:[NSDictionary class]] ||
                             [remoteRep isKindOfClass:[NSString class]] ||
                             [remoteRep isKindOfClass:[NSNumber class]] ||
                             [remoteRep isKindOfClass:[NSNull class]]);
        
        if (!JSONParsable)
        {
            [NSException raise:NSInvalidArgumentException format:@"Trying to encode property '%@' in class '%@', but the result (%@) was not JSON-encodable. Override -[NSRRemoteObject encodeValueForProperty:remoteKey:] if you want to encode a property that's not NSDictionary, NSArray, NSString, NSNumber, or NSNull. Remember to call super if it doesn't need custom encoding.",objcProperty, self.class, remoteRep];
        }
        
        
        dict[remoteKey] = remoteRep;
    }
    
    if (self.remoteDestroyOnNesting)
    {
        dict[@"_destroy"] = @YES;
    }
    
    if (wrapped) {
        return @{[self.class remoteModelName]: dict};
    }
    
    return dict;
}


+ (instancetype) objectWithRemoteDictionary:(NSDictionary *)dict
{
    NSRRemoteObject *obj = [[self alloc] init];
    [obj setPropertiesUsingRemoteDictionary:dict];
    return obj;
}

#pragma mark - Create

- (BOOL) remoteCreate:(NSError **)error
{
    NSDictionary *jsonResponse = [[NSRRequest requestToCreateObject:self] sendSynchronous:error];
    
    [self setPropertiesUsingRemoteDictionary:jsonResponse];
    return !!jsonResponse;
}

- (void) remoteCreateAsync:(NSRBasicCompletionBlock)completionBlock
{
    [[NSRRequest requestToCreateObject:self] sendAsynchronous:
     ^(id result, NSError *error) 
     {
         [self setPropertiesUsingRemoteDictionary:result];
         if (completionBlock) {
             completionBlock(error);
         }
     }];
}

#pragma mark Update

- (BOOL) remoteUpdate:(NSError **)error
{
    return !![[NSRRequest requestToUpdateObject:self] sendSynchronous:error];
}

- (void) remoteUpdateAsync:(NSRBasicCompletionBlock)completionBlock
{
    [[NSRRequest requestToUpdateObject:self] sendAsynchronous:
     ^(id result, NSError *error) 
     {
         if (completionBlock) {
             completionBlock(error);
         }
     }];
}

#pragma mark Replace

- (BOOL) remoteReplace:(NSError **)error
{
    return !![[NSRRequest requestToReplaceObject:self] sendSynchronous:error];
}

- (void) remoteReplaceAsync:(NSRBasicCompletionBlock)completionBlock
{
    [[NSRRequest requestToReplaceObject:self] sendAsynchronous:
     ^(id result, NSError *error) 
     {
         if (completionBlock) {
             completionBlock(error);
         }
     }];
}

#pragma mark Destroy

- (BOOL) remoteDestroy:(NSError **)error
{
    return !![[NSRRequest requestToDestroyObject:self] sendSynchronous:error];
}

- (void) remoteDestroyAsync:(NSRBasicCompletionBlock)completionBlock
{
    [[NSRRequest requestToDestroyObject:self] sendAsynchronous:
     ^(id result, NSError *error) 
     {
         if (completionBlock) {
             completionBlock(error);
         }
     }];
}

#pragma mark Get latest

- (BOOL) remoteFetch:(NSError **)error
{
    NSDictionary *jsonResponse = [[NSRRequest requestToFetchObject:self] sendSynchronous:error];
    
    if (jsonResponse) {
        [self setPropertiesUsingRemoteDictionary:jsonResponse];
    }
    
    return !!jsonResponse;
}

- (void) remoteFetchAsync:(NSRBasicCompletionBlock)completionBlock
{
    [[NSRRequest requestToFetchObject:self] sendAsynchronous:
     ^(id jsonRep, NSError *error) 
     {
         if (jsonRep) {
             [self setPropertiesUsingRemoteDictionary:jsonRep];
         }
         if (completionBlock) {
             completionBlock(error);
         }
     }];
}

#pragma mark Get specific object (class-level)

+ (instancetype) remoteObjectWithID:(NSNumber *)mID error:(NSError **)error
{
    NSDictionary *objData = [[NSRRequest requestToFetchObjectWithID:mID ofClass:self] sendSynchronous:error];
    
    return (objData ? [self objectWithRemoteDictionary:objData] : nil);
}

+ (void) remoteObjectWithID:(NSNumber *)mID async:(NSRFetchObjectCompletionBlock)completionBlock
{
    [[NSRRequest requestToFetchObjectWithID:mID ofClass:self] sendAsynchronous:
     ^(id jsonRep, NSError *error) 
     {
         id obj = (jsonRep ? [self objectWithRemoteDictionary:jsonRep] : nil);
         if (completionBlock) {
             completionBlock(obj, error);
         }
     }];
}

#pragma mark Get all objects (class-level)

+ (NSArray *) objectsWithRemoteDictionaries:(NSArray *)remoteDictionaries
{
    if ([remoteDictionaries isKindOfClass:[NSDictionary class]])
    {
        //probably has root in front of it - "posts":[{},{}]
        if ([remoteDictionaries count] == 1)
        {
            remoteDictionaries = [(NSDictionary *)remoteDictionaries allValues][0];
        }
    }
    
    if (![remoteDictionaries isKindOfClass:[NSArray class]]) {
        return nil;
    }

    NSMutableArray *array = [NSMutableArray array];
    
    for (NSDictionary *dict in remoteDictionaries)
    {
        if ([dict isKindOfClass:[NSDictionary class]])
        {
            NSRRemoteObject *obj = [self objectWithRemoteDictionary:dict];
            [array addObject:obj];
        }
    }
    
    return array;
}

+ (NSArray *) remoteAll:(NSError **)error
{
    return [self remoteAllViaObject:nil error:error];
}

+ (NSArray *) remoteAllViaObject:(NSRRemoteObject *)obj error:(NSError **)error
{
    id json = [[NSRRequest requestToFetchAllObjectsOfClass:self viaObject:obj] sendSynchronous:error];
    return [self objectsWithRemoteDictionaries:json];
}

+ (void) remoteAllAsync:(NSRFetchAllCompletionBlock)completionBlock
{
    [self remoteAllViaObject:nil async:completionBlock];
}

+ (void) remoteAllViaObject:(NSRRemoteObject *)obj async:(NSRFetchAllCompletionBlock)completionBlock
{
    [[NSRRequest requestToFetchAllObjectsOfClass:self viaObject:obj] sendAsynchronous:
     ^(id result, NSError *error) 
     {
         if (completionBlock) {
             completionBlock([self objectsWithRemoteDictionaries:result],error);
         }
     }];
}

#pragma mark - NSCoding

- (id) initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init])
    {
        self.remoteID = [aDecoder decodeObjectForKey:@"remoteID"];
        self.remoteDestroyOnNesting = [aDecoder decodeBoolForKey:@"remoteDestroyOnNesting"];
        _remoteAttributes = [aDecoder decodeObjectForKey:@"remoteAttributes"];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.remoteID forKey:@"remoteID"];
    [aCoder encodeObject:self.remoteAttributes forKey:@"remoteAttributes"];
    [aCoder encodeBool:self.remoteDestroyOnNesting forKey:@"remoteDestroyOnNesting"];
}


#pragma mark - Inflection helpers

+ (NSString *) stringByCamelizingString:(NSString *)string
{
    NSMutableString *camelized = [NSMutableString string];
    BOOL capitalizeNext = NO;
    for (int i = 0; i < string.length; i++) {
        NSString *str = [string substringWithRange:NSMakeRange(i, 1)];
        
        if ([str isEqualToString:@"_"]) {
            capitalizeNext = YES;
            continue;
        }
        
        if (capitalizeNext) {
            [camelized appendString:[str uppercaseString]];
            capitalizeNext = NO;
        }
        else {
            [camelized appendString:str];
        }
    }
    
    // replace items that end in Id with ID
    if ([camelized hasSuffix:@"Id"]) {
        [camelized replaceCharactersInRange:NSMakeRange(camelized.length - 2, 2) withString:@"ID"];
    }
    
    // replace items that end in Ids with IDs
    if ([camelized hasSuffix:@"Ids"]) {
        [camelized replaceCharactersInRange:NSMakeRange(camelized.length - 3, 3) withString:@"IDs"];
    }
    
    return camelized;
}

+ (NSString *) stringByUnderscoringString:(NSString *)string ignoringPrefix:(BOOL)stripPrefix
{
    NSCharacterSet *caps = [NSCharacterSet uppercaseLetterCharacterSet];
    
    NSMutableString *underscored = [NSMutableString string];
    BOOL isPrefix = YES;
    BOOL previousLetterWasCaps = NO;
    
    for (int i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        NSString *currChar = [NSString stringWithFormat:@"%C",c];
        if ([caps characterIsMember:c])
        {
            BOOL nextLetterIsCaps = (i+1 == string.length || [caps characterIsMember:[string characterAtIndex:i+1]]);
            
            //only add the delimiter if, it's not the first letter, it's not in the middle of a bunch of caps, and it's not a _ repeat
            if (i != 0 && !(previousLetterWasCaps && nextLetterIsCaps) && [string characterAtIndex:i-1] != '_')
            {
                if (isPrefix && stripPrefix) {
                    underscored = [NSMutableString string];
                }
                else {
                    [underscored appendString:@"_"];
                }
            }
            [underscored appendString:[currChar lowercaseString]];
            previousLetterWasCaps = YES;
        }
        else
        {
            isPrefix = NO;
            
            [underscored appendString:currChar];
            previousLetterWasCaps = NO;
        }
    }
    
    return underscored;
}

@end

