//
//  KortforItem.swift
//  I Bike CPH
//
//  Created by Tobias Due Munk on 20/11/14.
//  Copyright (c) 2014 I Bike CPH. All rights reserved.
//

import Foundation
import CoreLocation


@objc class KortforItem: NSObject, SearchListItem {
    
    var type: SearchListItemType = .Kortfor
    var name: String
    var address: String = ""
    var street: String
    var number: String
    var order: Int = 2
    var zip: String
    var city: String
    var country: String = "Denmark"
    var location: CLLocation? = CLLocation()
    var relevance: Int = 0
    
    var distance: Double
    var isPlace: Bool
    var isFromStreetSearch: Bool = false
    
    init(jsonDictionary: AnyObject) {
        let json = JSON(jsonDictionary)
        
        let jsonProperties = json["properties"]
        // Street, name, address, city, zip
        if let streetName = jsonProperties["vej_navn"].string {
            street = streetName
        } else {
            street = jsonProperties["navn"].stringValue
        }
        if let postalArea = jsonProperties["postdistrikt_navn"].string {
            city = postalArea
        } else {
            city = jsonProperties["kommune_navn"].stringValue
        }
        zip = jsonProperties["postdistrikt_kode"].stringValue
        
        // Location
        let jsonGeometry = json["geometry"]
        var latitude: Double = 0
        var longitude: Double = 0
        if let ymin = jsonGeometry["ymin"].double {
            latitude = ymin
            if let ymax = json["properties"]["ymax"].double {
                latitude += ymax
                latitude /= 2
            }
            longitude = json["properties"]["xmin"].doubleValue
            if let ymax = json["properties"]["xmax"].double {
                longitude += ymax
                longitude /= 2
            }
        } else if let coordinates = jsonGeometry["coordinates"].array {
            latitude = coordinates[1].doubleValue
            longitude = coordinates[0].doubleValue
        } else if let boundingBox = json["bbox"].array {
            if count(boundingBox) > 3 {
                latitude = (boundingBox[1].doubleValue + boundingBox[3].doubleValue) / 2
                longitude = (boundingBox[0].doubleValue + boundingBox[2].doubleValue) / 2
            }
        }
        location = CLLocation(latitude: CLLocationDegrees(latitude), longitude: CLLocationDegrees(longitude))
        
        // Number, distance, isPlace
        number = jsonProperties["husnr"].stringValue
        distance = jsonProperties["afstand_afstand"].doubleValue
        isPlace = jsonProperties["kategori"].string != nil
        
        name = "\(street) \(number), \(zip) \(city)"
        address = name
    }
    
    override var description: String {
        return "Name: \(name), Address: \(address), Street: \(street), Number: \(number), Zip: \(zip), City: \(city), Country: \(country), Location: (\(location?.coordinate.latitude), \(location?.coordinate.longitude)), Order: \(order), Relevance: \(relevance), Distance: \(distance), isPlace: \(isPlace)"
    }
}
