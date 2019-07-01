//
//  Message.swift
//  Ride
//
//  Created by Ben Mechen on 07/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation
import UIKit
import MessageKit

struct Message {
    let member: Member
    let text: String
    let messageId: String
    let date: Date
}

extension Message: MessageType {
    
    var sender: SenderType {
        return Sender(id: member.id, displayName: member.name)
    }
    
    var sentDate: Date {
        return date
    }
    
    var kind: MessageKind {
        return .text(text)
    }
}

struct Member {
    let id: String
    let name: String
}
