//
//  Photo.h
//  Photomania
//
//  Created by Norimasa Nabeta on 2012/09/08.
//  Copyright (c) 2012年 Norimasa Nabeta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Photographer;

@interface Photo : NSManagedObject

@property (nonatomic, retain) NSString * imageURL;
@property (nonatomic, retain) NSString * subtitle;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * unique;
@property (nonatomic, retain) NSData * thumbnail;
@property (nonatomic, retain) NSString * thumbnailURL;
@property (nonatomic, retain) Photographer *whoTook;

@end
