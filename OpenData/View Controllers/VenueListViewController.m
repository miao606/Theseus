//
//  VenueListViewController.m
//  OpenData
//
//  Created by Michael Walker on 5/19/14.
//  Copyright (c) 2014 Lazer-Walker. All rights reserved.
//

#import "VenueListViewController.h"

#import "Stop.h"
#import "FoursquareClient.h"
#import "FoursquareVenue.h"
#import "Venue.h"

#import <UIImageView+WebCache.h>

static NSString * const CellIdentifier = @"cell";

typedef NS_ENUM(NSUInteger, TableSections) {
    TableSectionLocalResults,
    TableSectionRemoteResults,
    NumberOfTableSections
};

@interface VenueListViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) FoursquareClient *client;
@property (nonatomic, strong) NSArray *localResults;
@property (nonatomic, strong) NSArray *results;

@end

@implementation VenueListViewController

- (id)initWithStop:(Stop *)stop {
    self = [super init];
    if (!self) return nil;

    self.stop = stop;
    self.title = @"Select A Venue";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(didTapCancelButton)];

    self.results = [NSArray new];
    self.localResults = [NSArray new];

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self fetchLocalResults];
    [self fetchRemoteResults];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)fetchLocalResults {
    NSPredicate *nearby = [NSPredicate predicateWithFormat:@"(latitude > %@) AND (latitude < %@) AND (longitude > %@) AND (longitude < %@)", @(self.stop.coordinate.latitude - 0.1), @(self.stop.coordinate.latitude + 0.1), @(self.stop.coordinate.longitude - 0.1), @(self.stop.coordinate.longitude + 0.1)];
    NSArray *results = [Venue MR_findAllWithPredicate:nearby];
    self.localResults = [results sortedArrayUsingComparator:^NSComparisonResult(Venue *obj1, Venue *obj2) {
        NSNumber *distance1 = @([self.stop distanceFromCoordinate:obj1.coordinate]);
        NSNumber *distance2 = @([self.stop distanceFromCoordinate:obj2.coordinate]);
        return [distance1 compare:distance2];
    }];

    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:TableSectionLocalResults] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)fetchRemoteResults {
    self.client = [FoursquareClient new];
    [self.client fetchVenuesForCoordinate:self.stop.coordinate completion:^(NSArray *results, NSError *error) {
        NSArray *localFoursquareIds = [self.localResults valueForKey:@"foursquareId"];
        NSPredicate *blacklist = [NSPredicate predicateWithFormat:@"NOT (foursquareId IN %@)", localFoursquareIds];
        self.results = [results filteredArrayUsingPredicate:blacklist];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:TableSectionRemoteResults] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
}

- (void)didTapCancelButton {
    if (self.didTapCancelButtonBlock) {
        self.didTapCancelButtonBlock();
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return NumberOfTableSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == TableSectionLocalResults) {
        return self.localResults.count;
    } else if (section == TableSectionRemoteResults) {
        return self.results.count;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];

    Venue *venue;
    if (indexPath.section == TableSectionLocalResults) {
        venue = self.localResults[indexPath.row];
    } else if (indexPath.section == TableSectionRemoteResults) {
        FoursquareVenue *foursquareVenue = self.results[indexPath.row];
        venue = [Venue MR_findFirstByAttribute:@"foursquareId" withValue:foursquareVenue.foursquareId];
        if (!venue) {
            venue = [Venue MR_createEntity];
            [venue setupWithFoursquareVenue:foursquareVenue];
        }
    }

    if (self.didSelectVenueBlock) {
        self.didSelectVenueBlock(venue);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *titles = @{
     @(TableSectionLocalResults): @"Places You've Been Near Here",
     @(TableSectionRemoteResults): @"Nearby Foursquare Venues"
    };

    return titles[@(section)];
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == TableSectionLocalResults) {
        Venue *venue = self.localResults[indexPath.row];
        cell.textLabel.text = venue.name;
        cell.imageView.image = nil;
    } else if (indexPath.section == TableSectionRemoteResults) {
        FoursquareVenue *venue = self.results[indexPath.row];

        cell.textLabel.text = venue.name;
        [cell.imageView setImageWithURL:venue.iconURL];
    }
}

@end