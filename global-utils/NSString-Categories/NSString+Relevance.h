//
//  NSString+Relevance.h
//  I Bike CPH
//
//  Created by Ivan Pavlovic on 19/03/2013.
//  Copyright (C) 2013 City of Copenhagen.  All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at 
//  http://mozilla.org/MPL/2.0/.
//

#import <Foundation/Foundation.h>

/**
 * \ingroup libs
 * Check string match for relevance
 */
@interface NSString (Relevance)

- (NSInteger)numberOfOccurenciesOfString:(NSString*)str;

@end
