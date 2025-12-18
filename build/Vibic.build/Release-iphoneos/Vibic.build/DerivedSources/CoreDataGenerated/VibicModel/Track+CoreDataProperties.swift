//
//  Track+CoreDataProperties.swift
//  
//
//  Created by Dylan De Schryver on 12/18/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TrackCoreDataPropertiesSet = NSSet

extension Track {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Track> {
        return NSFetchRequest<Track>(entityName: "Track")
    }

    @NSManaged public var addedDate: Date?
    @NSManaged public var artist: String?
    @NSManaged public var artworkData: Data?
    @NSManaged public var duration: Double
    @NSManaged public var filePath: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var id: UUID?
    @NSManaged public var isStreamed: Bool
    @NSManaged public var tags: String?
    @NSManaged public var title: String?
    @NSManaged public var videoId: String?
    @NSManaged public var playlistItems: NSSet?

}

// MARK: Generated accessors for playlistItems
extension Track {

    @objc(addPlaylistItemsObject:)
    @NSManaged public func addToPlaylistItems(_ value: PlaylistItem)

    @objc(removePlaylistItemsObject:)
    @NSManaged public func removeFromPlaylistItems(_ value: PlaylistItem)

    @objc(addPlaylistItems:)
    @NSManaged public func addToPlaylistItems(_ values: NSSet)

    @objc(removePlaylistItems:)
    @NSManaged public func removeFromPlaylistItems(_ values: NSSet)

}

extension Track : Identifiable {

}
