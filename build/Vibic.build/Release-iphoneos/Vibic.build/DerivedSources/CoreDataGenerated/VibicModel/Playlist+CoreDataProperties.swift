//
//  Playlist+CoreDataProperties.swift
//  
//
//  Created by Dylan De Schryver on 12/18/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias PlaylistCoreDataPropertiesSet = NSSet

extension Playlist {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Playlist> {
        return NSFetchRequest<Playlist>(entityName: "Playlist")
    }

    @NSManaged public var createdDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var items: NSSet?

}

// MARK: Generated accessors for items
extension Playlist {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: PlaylistItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: PlaylistItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

extension Playlist : Identifiable {

}
