//
//  PlaylistItem+CoreDataProperties.swift
//  
//
//  Created by Dylan De Schryver on 12/18/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias PlaylistItemCoreDataPropertiesSet = NSSet

extension PlaylistItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistItem> {
        return NSFetchRequest<PlaylistItem>(entityName: "PlaylistItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var order: Int32
    @NSManaged public var playlist: Playlist?
    @NSManaged public var track: Track?

}

extension PlaylistItem : Identifiable {

}
