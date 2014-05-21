//
//  ListViewController.m
//  OpenData
//
//  Created by Michael Walker on 5/13/14.
//  Copyright (c) 2014 Lazer-Walker. All rights reserved.
//

#import "ListViewController.h"
#import "DataProcessor.h"
#import "MovementPath.h"
#import "Stop.h"
#import "FoursquareVenue.h"
#import "Venue.h"
#import "VenueListViewController.h"

static NSString * const CellIdentifier = @"CellIdentifier";

@interface ListViewController ()
@property (strong, nonatomic) NSArray *data;
@end

@implementation ListViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (!self) return nil;

    self.title = @"List";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Process" style:UIBarButtonItemStylePlain target:self action:@selector(loadData)];

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.contentInset = UIEdgeInsetsMake(20, 0, self.tabBarController.tabBar.bounds.size.height, 0);
    DataProcessor *dataProcessor = [DataProcessor new];
    [dataProcessor fetchStaleDataWithCompletion:^(NSArray *stops, NSArray *paths) {
        NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"startTime" ascending:YES];
        self.data = [[stops arrayByAddingObjectsFromArray:paths] sortedArrayUsingDescriptors:@[descriptor]];
        [self.tableView reloadData];
    }];
}

#pragma mark - 
- (void)loadData {
    DataProcessor *dataProcessor = [DataProcessor new];
    [dataProcessor processDataWithCompletion:^(NSArray *stops, NSArray *paths) {
        NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"startTime" ascending:YES];
        self.data = [[stops arrayByAddingObjectsFromArray:paths] sortedArrayUsingDescriptors:@[descriptor]];
        [self.tableView reloadData];
    }];
}

- (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *_dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateStyle = NSDateFormatterShortStyle;
        _dateFormatter.timeStyle = NSDateFormatterShortStyle;
    });

    return _dateFormatter;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    id obj = self.data[indexPath.row];

    NSTimeInterval duration = [obj duration];
    NSInteger hours = duration / 60 / 60;
    NSInteger minutes = duration/60 - hours*60;
    NSInteger seconds = duration - minutes*60;
    NSString *timeString = [NSString stringWithFormat:@"%02lu:%02lu:%02lu", (long)hours, (long)minutes, (long)seconds];

    if ([obj isKindOfClass:Stop.class]) {
        Stop *stop = obj;
        if (stop.venue) {
            cell.textLabel.text = stop.venue.name;
            cell.textLabel.textColor = (stop.venueConfirmed.boolValue ? [UIColor blackColor] : [UIColor grayColor]);
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%f, %f", stop.coordinate.latitude, stop.coordinate.longitude];
        }

        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %@ (%@)", [self.dateFormatter stringFromDate:stop.startTime], [self.dateFormatter stringFromDate:stop.endTime], timeString];
    } else if ([obj isKindOfClass:MovementPath.class]){
        cell.textLabel.text = [NSString stringWithFormat:@"Moving for %@", timeString];
        cell.detailTextLabel.text = nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    Stop *stop = self.data[indexPath.row];
    if (![stop isKindOfClass:Stop.class]) return;

    VenueListViewController *venueList = [[VenueListViewController alloc] initWithStop:stop];

    venueList.didTapCancelButtonBlock = ^{
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    };

    venueList.didSelectVenueBlock = ^(Venue *venue) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];

        [MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
            Venue *oldVenue = stop.venue;
            if (oldVenue && oldVenue.stops.count == 1) {
                [oldVenue MR_deleteEntity];
            }

            stop.venue = venue;
            stop.venueConfirmed = @(YES);

            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } completion:nil];
    };

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:venueList];
    [self.navigationController presentViewController:navController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.data.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }

    return cell;
}


@end
