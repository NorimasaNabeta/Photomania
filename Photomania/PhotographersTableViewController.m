//
//  PhotographersTableViewController.m
//  Photomania
//
//  Created by CS193p Instructor.
//  Copyright (c) 2011 Stanford University. All rights reserved.
//

#import "PhotographersTableViewController.h"
#import "FlickrFetcher.h"
#import "Photographer.h"
#import "Photo+Flickr.h"

@implementation PhotographersTableViewController

@synthesize photoDatabase = _photoDatabase;

// 4. Stub this out (we didn't implement it at first)
// 13. Create an NSFetchRequest to get all Photographers and hook it up to our table via an NSFetchedResultsController
// (we inherited the code to integrate with NSFRC from CoreDataTableViewController)

- (void)setupFetchedResultsController // attaches an NSFetchRequest to this UITableViewController
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Photographer"];
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
    // no predicate because we want ALL the Photographers
                             
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                        managedObjectContext:self.photoDatabase.managedObjectContext
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:nil];
}

// 5. Create a Q to fetch Flickr photo information to seed the database
// 6. Take a timeout from this and go create the database model (Photomania.xcdatamodeld)
// 7. Create custom subclasses for Photo and Photographer
// 8. Create a category on Photo (Photo+Flickr) to add a "factory" method to create a Photo
// (go to Photo+Flickr for next step)
// 12. Use the Photo+Flickr category method to add Photos to the database (table will auto update due to NSFRC)

- (void)fetchFlickrDataIntoDocument:(UIManagedDocument *)document usingBlock:(void (^)(BOOL)) block
{
    dispatch_queue_t fetchQ = dispatch_queue_create("Flickr fetcher", NULL);
    dispatch_async(fetchQ, ^{
        NSArray *photos = [FlickrFetcher recentGeoreferencedPhotos];
        [document.managedObjectContext performBlock:^{ // perform in the NSMOC's safe thread (main thread)
            for (NSDictionary *flickrInfo in photos) {
                [Photo photoWithFlickrInfo:flickrInfo inManagedObjectContext:document.managedObjectContext];
                // table will automatically update due to NSFetchedResultsController's observing of the NSMOC
            }
            // should probably saveToURL:forSaveOperation:(UIDocumentSaveForOverwriting)completionHandler: here!
            // we could decide to rely on UIManagedDocument's autosaving, but explicit saving would be better
            // because if we quit the app before autosave happens, then it'll come up blank next time we run
            // this is what it would look like (ADDED AFTER LECTURE) ...
            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:NULL];
            // note that we don't do anything in the completion handler this time
            
        }];
        block(YES);
    });
    dispatch_release(fetchQ);
}

// 3. Open or create the document here and call setupFetchedResultsController
// #define __THREAD_RACE_GAUDE_1840__
// #define __THREAD_RACE_GAUDE_1845__
#ifdef __THREAD_RACE_GAUDE_1840__
- (void)useDocument
{
    //dispatch_queue_t syncQueue = dispatch_queue_create("sync thread call queue", NULL);
    static BOOL isOpening;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.photoDatabase.fileURL path]]) {
        // does not exist on disk, so create it
        [self.photoDatabase saveToURL:self.photoDatabase.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            [self setupFetchedResultsController];
            [self fetchFlickrDataIntoDocument:self.photoDatabase];
        }];
    } else if (self.photoDatabase.documentState == UIDocumentStateClosed) {
        // @1840 Rob Woodgate's solution.
        if (!isOpening) {
            isOpening = YES;
            [self.photoDatabase openWithCompletionHandler:^(BOOL success) {
                [self setupFetchedResultsController];
                isOpening = NO;
            }];
        } else {
            NSLog(@"Try again");
            [self performSelector:@selector(useDocument) withObject:nil afterDelay:1.0];
        }
    } else if (self.photoDatabase.documentState == UIDocumentStateNormal) {
        // already open and ready to use
        [self setupFetchedResultsController];
    }
}
#elif defined __THREAD_RACE_GAUDE_1845__
// *** NOT WRKING ***
// first (no file exists) -->OK
// second (trap) --> NG
- (void)useDocument
{
    dispatch_queue_t syncQueue = dispatch_queue_create("sync thread call queue", NULL);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.photoDatabase.fileURL path]]) {
        // does not exist on disk, so create it
        [self.photoDatabase saveToURL:self.photoDatabase.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            [self setupFetchedResultsController];
            [self fetchFlickrDataIntoDocument:self.photoDatabase usingBlock:^(BOOL success){
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.navigationItem.rightBarButtonItem = nil;
                });
            }];
        }];
    } else if (self.photoDatabase.documentState == UIDocumentStateClosed) {
        NSLog(@"now opening ...");

         // dispatch_sync(syncQueue, ^{
         //    [self.photoDatabase openWithCompletionHandler:^(BOOL success) {
         //         if (success) {
         //             dispatch_async(syncQueue, ^{
         //                 [self setupFetchedResultsController];
         //             });
         //         } else {
         //             NSLog(@"Could not open document at %@", self.photoDatabase.fileURL);
         //         }
         //     }];
         // });

        
        dispatch_async(syncQueue, ^{
           dispatch_suspend(syncQueue);
            // trap causes app to stop.
            [self.photoDatabase openWithCompletionHandler:^(BOOL success) {
                if (success) {
                    // dispatch_async(syncQueue, ^{
                        [self setupFetchedResultsController];
                    // });
                } else {
                    NSLog(@"Could not open document at %@", self.photoDatabase.fileURL);
                }
                dispatch_resume(syncQueue);
           }];
        });
    } else if (self.photoDatabase.documentState == UIDocumentStateNormal) {
        // already open and ready to use
        [self setupFetchedResultsController];
    }
    dispatch_release(syncQueue);
}

#else //#ifdef __THREAD_RACE_GAUDE__
// ORIGINAL
- (void)useDocument
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.photoDatabase.fileURL path]]) {
        // does not exist on disk, so create it
        [self.photoDatabase saveToURL:self.photoDatabase.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            [self setupFetchedResultsController];
            [self fetchFlickrDataIntoDocument:self.photoDatabase usingBlock:^(BOOL success){
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.navigationItem.rightBarButtonItem = nil;
                });
            }];
        }];
    } else if (self.photoDatabase.documentState == UIDocumentStateClosed) {
        // exists on disk, but we need to open it
        [self.photoDatabase openWithCompletionHandler:^(BOOL success) {
            [self setupFetchedResultsController];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.navigationItem.rightBarButtonItem = nil;
                [self.tableView reloadData];
            });
        }];
    } else if (self.photoDatabase.documentState == UIDocumentStateNormal) {
        // already open and ready to use
        [self setupFetchedResultsController];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.navigationItem.rightBarButtonItem = nil;
        });
    }
}

#endif //#ifdef __THREAD_RACE_GAUDE__

// 2. Make the photoDatabase's setter start using it

- (void)setPhotoDatabase:(UIManagedDocument *)photoDatabase
{
    if (_photoDatabase != photoDatabase) {
        _photoDatabase = photoDatabase;
        
        // @1840 Opening / passing UIManagedDocument
        // race condition test
        [self useDocument];
        // [self useDocument];
        
        // Shutterbug/FlickrPhotoTableViewController.m
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [spinner startAnimating];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
        
        // dispatch_queue_t downloadQueue = dispatch_queue_create("flickr downloader", NULL);
        // dispatch_async(downloadQueue, ^{
        //     NSArray *photos = [FlickrFetcher recentGeoreferencedPhotos];
        //     dispatch_async(dispatch_get_main_queue(), ^{
        //         self.navigationItem.rightBarButtonItem = sender;
        //         self.photos = photos;
        //     });
        // });
        // dispatch_release(downloadQueue);
        
    }
}

// 0. Create full storyboard and drag in CDTVC.[mh], FlickrFetcher.[mh] and ImageViewController.[mh]
// (0.5 would probably be "add a UIManagedDocument, photoDatabase, as this Controller's Model)
// 1. Add code to viewWillAppear: to create a default document (for demo purposes)

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!self.photoDatabase) {  // for demo purposes, we'll create a default database if none is set
        NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        url = [url URLByAppendingPathComponent:@"Default Photo Database"];
        // url is now "<Documents Directory>/Default Photo Database"
        self.photoDatabase = [[UIManagedDocument alloc] initWithFileURL:url]; // setter will create this for us on disk
    }
}

// 14. Load up our cell using the NSManagedObject retrieved using NSFRC's objectAtIndexPath:
// (go to PhotosByPhotographerViewController.h (header file) for next step)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Photographer Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // ask NSFetchedResultsController for the NSMO at the row in question
    Photographer *photographer = [self.fetchedResultsController objectAtIndexPath:indexPath];
    // Then configure the cell using it ...
    cell.textLabel.text = photographer.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d photos", [photographer.photos count]];
    
    return cell;
}

// 19. Support segueing from this table to any view controller that has a photographer @property.

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    Photographer *photographer = [self.fetchedResultsController objectAtIndexPath:indexPath];
    // be somewhat generic here (slightly advanced usage)
    // we'll segue to ANY view controller that has a photographer @property
    if ([segue.destinationViewController respondsToSelector:@selector(setPhotographer:)]) {
        // use performSelector:withObject: to send without compiler checking
        // (which is acceptable here because we used introspection to be sure this is okay)
        [segue.destinationViewController performSelector:@selector(setPhotographer:) withObject:photographer];
    }
}

@end
