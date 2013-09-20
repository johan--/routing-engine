//
//  SMGeocoder.m
//  I Bike CPH
//
//  Created by Ivan Pavlovic on 07/02/2013.
//  Copyright (C) 2013 City of Copenhagen.
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at 
//  http://mozilla.org/MPL/2.0/.
//

#import "SMGeocoder.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "SMLocationManager.h"
#import "NSString+URLEncode.h"


@implementation SMGeocoder

+ (void)geocode:(NSString*)str completionHandler:(void (^)(NSArray* placemarks, NSError* error)) handler {
    if (USE_APPLE_GEOCODER) {
        [SMGeocoder appleGeocode:str completionHandler:handler];
    } else {
        [SMGeocoder oiorestGeocode:str completionHandler:handler];
    }
}

+ (void)oiorestGeocode:(NSString*)str completionHandler:(void (^)(NSArray* placemarks, NSError* error)) handler{
    NSString * s = [NSString stringWithFormat:@"http://geo.oiorest.dk/adresser.json?q=%@", [str urlEncode]];
    NSURLRequest * req = [NSURLRequest requestWithURL:[NSURL URLWithString:s]];
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * response, NSData * data, NSError *error) {
        
        id res = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];//[[[SBJsonParser alloc] init] objectWithData:data];
        if ([res isKindOfClass:[NSArray class]] == NO) {
            res = @[res];
        }
        if (error) {
            handler(@[], error);
        } else if ([(NSArray*)res count] == 0) {
            handler(@[], [NSError errorWithDomain:NSOSStatusErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : @"Wrong data returned from the OIOREST"}]);
        } else {
            NSMutableArray * arr = [NSMutableArray array];
            for (NSDictionary * d in (NSArray*) res) {
                NSDictionary * dict = @{
                                        (NSString *)kABPersonAddressStreetKey : [NSString stringWithFormat:@"%@ %@", [[d objectForKey:@"vejnavn"] objectForKey:@"navn"], [d objectForKey:@"husnr"]],
                                        (NSString *)kABPersonAddressZIPKey : [[d objectForKey:@"postnummer"] objectForKey:@"nr"],
                                        (NSString *)kABPersonAddressCityKey : [[d objectForKey:@"kommune"] objectForKey:@"navn"],
                                        (NSString *)kABPersonAddressCountryKey : @"Denmark"
                                        };
                MKPlacemark * pl = [[MKPlacemark alloc]
                                    initWithCoordinate:CLLocationCoordinate2DMake([[[d objectForKey:@"wgs84koordinat"] objectForKey:@"bredde"] doubleValue], [[[d objectForKey:@"wgs84koordinat"] objectForKey:@"længde"] doubleValue])
                                    addressDictionary:dict];
                [arr addObject:pl];
            }
            handler(arr, nil);
        }
    }];
}

+ (void)appleGeocode:(NSString*)str completionHandler:(void (^)(NSArray* placemarks, NSError* error)) handler {
    CLGeocoder * cl = [[CLGeocoder alloc] init];
    [cl geocodeAddressString:str completionHandler:^(NSArray *placemarks, NSError *error) {
        NSMutableArray * ret = [NSMutableArray array];
        for (CLPlacemark * pl in placemarks) {
            if ([SMLocationManager instance].hasValidLocation) {
//                float searchRadius = GEOCODING_SEARCH_RADIUS;
//                if ([pl.location distanceFromLocation:[SMLocationManager instance].lastValidLocation] <= searchRadius) {
                    [ret addObject:[[MKPlacemark alloc] initWithPlacemark:pl]];
//                }
            } else {
                [ret addObject:[[MKPlacemark alloc] initWithPlacemark:pl]];
            }
        }
        handler(ret, error);
    }];
}

+ (void)appleReverseGeocode:(CLLocationCoordinate2D)coord completionHandler:(void (^)(NSDictionary * response, NSError* error)) handler {
    CLGeocoder * cl = [[CLGeocoder alloc] init];
    [cl reverseGeocodeLocation:[[CLLocation alloc] initWithLatitude:coord.latitude longitude:coord.longitude] completionHandler:^(NSArray *placemarks, NSError *error) {
        NSString * title = @"";
        NSString * subtitle = @"";
        NSMutableArray * arr = [NSMutableArray array];
        if ([placemarks count] > 0) {
            MKPlacemark * d = [placemarks objectAtIndex:0];
            title = [NSString stringWithFormat:@"%@", [[d addressDictionary] objectForKey:@"Street"]?[[d addressDictionary] objectForKey:@"Street"]:@""];
            subtitle = [NSString stringWithFormat:@"%@ %@", [[d addressDictionary] objectForKey:@"ZIP"]?[[d addressDictionary] objectForKey:@"ZIP"]:@"", [[d addressDictionary] objectForKey:@"City"]?[[d addressDictionary] objectForKey:@"City"]:@""];
            for (MKPlacemark* d in placemarks) {
                [arr addObject:@{
                 @"street" : [[d addressDictionary] objectForKey:@"Street"]?[[d addressDictionary] objectForKey:@"Street"]:@"",
                 @"house_number" : @"",
                 @"zip" : [[d addressDictionary] objectForKey:@"ZIP"]?[[d addressDictionary] objectForKey:@"ZIP"]:@"",
                 @"city" : [[d addressDictionary] objectForKey:@"City"]?[[d addressDictionary] objectForKey:@"City"]:@""
                 }];
            }
        }
        handler(@{@"title" : title, @"subtitle" : subtitle, @"near": arr}, nil);
    }];
}


+ (void)oiorestReverseGeocode:(CLLocationCoordinate2D)coord completionHandler:(void (^)(NSDictionary * response, NSError* error)) handler {
//    NSString* s = [NSString stringWithFormat:@"http://geo.oiorest.dk/adresser/%f,%f,%@.json", coord.latitude, coord.longitude, OIOREST_SEARCH_RADIUS];
    NSString* s = [NSString stringWithFormat:@"http://geo.oiorest.dk/adresser/%f,%f.json", coord.latitude, coord.longitude];
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:s]];
    
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error) {
            handler(@{}, error);
        } else {
            if (data) {
                NSString * s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                id res = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];//[[[SBJsonParser alloc] init] objectWithData:data];
                if (res == nil) {
                    handler(@{}, [NSError errorWithDomain:NSOSStatusErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Wrong data returned from the OIOREST: %@", s]}]);
                    return;
                }
                if ([res isKindOfClass:[NSArray class]] == NO) {
                    res = @[res];
                }
                NSMutableArray* arr = [NSMutableArray array];
                NSString* title = @"";
                NSString* subtitle = @"";
                if ([(NSArray*)res count] > 0) {
                    NSDictionary* d = [res objectAtIndex:0];
                    title = [NSString stringWithFormat:@"%@ %@", [[d objectForKey:@"vejnavn"] objectForKey:@"navn"], [d objectForKey:@"husnr"]];
                    subtitle = [NSString stringWithFormat:@"%@ %@", [[d objectForKey:@"postnummer"] objectForKey:@"nr"], [[d objectForKey:@"kommune"] objectForKey:@"navn"]];
                }
                for (NSDictionary* d in res) {
                    [arr addObject:@{
                     @"street" : [[d objectForKey:@"vejnavn"] objectForKey:@"navn"],
                     @"house_number" : [d objectForKey:@"husnr"],
                     @"zip" : [[d objectForKey:@"postnummer"] objectForKey:@"nr"],
                     @"city" : [[d objectForKey:@"kommune"] objectForKey:@"navn"]
                     }];
                }
                 handler(@{@"title" : title, @"subtitle" : subtitle, @"near": arr}, nil);
            } else {
                handler(@{}, [NSError errorWithDomain:NSOSStatusErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : @"Wrong data returned from the OIOREST"}]);
            }
        }
    }];
}

/**
 * use KMS to get coordinates at location.
 * we fetch 10 nearest coordinates and order by distance
 */
+ (void)kortReverseGeocode:(CLLocationCoordinate2D)coord completionHandler:(void (^)(NSDictionary * response, NSError* error)) handler {
    
    NSString* URLString= [[NSString stringWithFormat:@"http://kortforsyningen.kms.dk/?servicename=%@&hits=10&method=nadresse&geop=%lf,%lf&georef=EPSG:4326&georad=%d&outgeoref=EPSG:4326&login=%@&password=%@&geometry=false", KORT_SERVICE,
                           coord.longitude, coord.latitude, KORT_SEARCH_RADIUS, [SMRouteSettings sharedInstance].kort_username, [SMRouteSettings sharedInstance].kort_password] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    debugLog(@"Kort: %@", URLString);
    NSURLRequest * req = [NSURLRequest requestWithURL:[NSURL URLWithString:URLString]];
    
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error) {
            handler(@{}, error);
        } else {
            if (data) {
                NSString * s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                id res = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];//[[[SBJsonParser alloc] init] objectWithData:data];
                if (res == nil || [res isKindOfClass:[NSDictionary class]] == NO) {
                    handler(@{}, [NSError errorWithDomain:NSOSStatusErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Wrong data returned from the KORT: %@", s]}]);
                    return;
                }
                NSDictionary * json = (NSDictionary*)res;
                
                NSArray * x = [[json objectForKey:@"features"] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary * obj1, NSDictionary * obj2) {
                    return [[[[obj1 objectForKey:@"attributes"] objectForKey:@"afstand"] objectForKey:@"afstand"] compare:[[[obj2 objectForKey:@"attributes"] objectForKey:@"afstand"] objectForKey:@"afstand"]];
                }];
                
                NSMutableArray * arr = [NSMutableArray array];

                NSString* title = @"";
                NSString* subtitle = @"";
                if ([x count] > 0) {
                    NSDictionary* d = [[x objectAtIndex:0] objectForKey:@"attributes"];
                    title = [NSString stringWithFormat:@"%@ %@", [[d objectForKey:@"vej"] objectForKey:@"navn"], [d objectForKey:@"husnr"]];
                    subtitle = [NSString stringWithFormat:@"%@ %@", [[d objectForKey:@"postdistrikt"] objectForKey:@"kode"], [[d objectForKey:@"postdistrikt"] objectForKey:@"navn"]];
                }
                for (NSDictionary* d1 in x) {
                    NSDictionary* d = [d1 objectForKey:@"attributes"];
                    [arr addObject:@{
                                     @"street" : [[d objectForKey:@"vej"] objectForKey:@"navn"],
                                     @"house_number" : [d objectForKey:@"husnr"],
                                     @"zip" : [[d objectForKey:@"postdistrikt"] objectForKey:@"kode"],
                                     @"city" : [[d objectForKey:@"postdistrikt"] objectForKey:@"navn"]
                                     }];
                }
                handler(@{@"title" : title, @"subtitle" : subtitle, @"near": arr}, nil);
            } else {
                handler(@{}, [NSError errorWithDomain:NSOSStatusErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : @"Wrong data returned from the OIOREST"}]);
            }
        }
    }];
}

+ (void)reverseGeocode:(CLLocationCoordinate2D)coord completionHandler:(void (^)(NSDictionary * response, NSError* error)) handler {
//    if (USE_APPLE_GEOCODER) {
//        [SMGeocoder appleReverseGeocode:coord completionHandler:handler];
//    } else {
//        [SMGeocoder oiorestReverseGeocode:coord completionHandler:handler];
//    }
    [SMGeocoder kortReverseGeocode:coord completionHandler:handler];
}

@end