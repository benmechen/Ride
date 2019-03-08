//
//  SentRequestsViewController.swift
//  Ride
//
//  Created by Ben Mechen on 07/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import MessageKit
import MessageInputBar
import Firebase
import Crashlytics

class RequestsChatViewController: MessagesViewController {
    
//    override var canResignFirstResponder: Bool {return false}
    
    @IBOutlet weak var requestDeletedReceived: UILabel!
    @IBOutlet weak var requestDeletedSent: UILabel!
    @IBOutlet weak var receivedInput: UITextField!
    @IBOutlet weak var sentInput: UITextField!
    
    var request: Request? = nil
    var messages: [Message] = []
    var member: Member!
    var userName: String? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        while request == nil && userName == nil {
            print("Waiting for request")
        }
        
        self.navigationItem.title = userName
        
        self.messageInputBar.isHidden = true
        if self.receivedInput != nil {
            self.view.bringSubviewToFront(receivedInput)
        } else {
            self.view.bringSubviewToFront(sentInput)
        }
        
        if request == nil {
            return
        }
        
        if (request?.deleted)! {
            self.messageInputBar.isHidden = true
            if self.receivedInput != nil {
                self.receivedInput.isHidden = true
            } else {
                self.sentInput.isHidden = true
            }
            
            if requestDeletedReceived != nil {
                self.view.bringSubviewToFront(requestDeletedReceived)
            }
            if requestDeletedSent != nil {
                self.view.bringSubviewToFront(requestDeletedSent)
            }
        }
        
        member = Member(id: (mainUser?._userID)!, name: (mainUser?._userName)!)
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messageInputBar.delegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        
        if request?._driver == mainUser?._userID {
            RideDB?.child("Users").child((mainUser?._userID)!).child("requests").child("received").child((request?._id)!).setValue(false)
        } else {
            RideDB?.child("Users").child((mainUser?._userID)!).child("requests").child("sent").child((request?._id)!).setValue(false)
        }
        
        listenForMessagesForRequest((request?._id)!)
        self.view.bringSubviewToFront(messageInputBar)
        receivedInput.resignFirstResponder()
        messageInputBar.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.receivedInput != nil {
            self.receivedInput.isHidden = (request?.deleted)!
        } else {
            self.sentInput.isHidden = (request?.deleted)!
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.isHidden = false
        receivedInput.resignFirstResponder()
        messageInputBar.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        messageInputBar.isHidden = true
//        messageInputBar.resignFirstResponder()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    @IBAction func hideReceivedInput(_ sender: Any) {
        receivedInput.isHidden = true
//        receivedInput.isEditing = false
//        messageInputBar.becomeFirstResponder()
//        receivedInput.isEnabled = false
        
//        receivedInput.resignFirstResponder()
//        messageInputBar.becomeFirstResponder()
    }
    
    @IBAction func hideSentInput(_ sender: Any) {
        sentInput.isHidden = true
//        sentInput.resignFirstResponder()
//        self.becomeFirstResponder()
    }
    
    // MARK: - Private functions
    private func listenForMessagesForRequest(_ requestID: String) {
        let query = RideDB?.child("Requests").child(requestID).child("messages").queryOrdered(byChild: "date")
        
        query?.observe(.childAdded, with: { (snapshot) in
            if let value = snapshot.value as? [String: Any] {
                let interval = TimeInterval(exactly: value["date"] as! Int)
                let date = Date(timeIntervalSince1970: interval!)

                var name = ""

                if value["sender"] as? String == mainUser?._userID {
                    name = (mainUser?._userName)!
                } else {
                    name = self.userName!
                }

                let member = Member(id: value["sender"] as! String, name: name)
                
                let message = Message(member: member, text: value["message"] as! String, messageId: snapshot.key, date: date)

                self.messages.append(message)
            }
            
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToBottom()
        })
    }
}

extension RequestsChatViewController: MessagesDataSource {
    func numberOfSections(
        in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func currentSender() -> Sender {
        return Sender(id: member.id, displayName: member.name)
    }
    
    func messageForItem(
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func messageBottomLabelHeight(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        
        return 12
        
    }
    
    func messageBottomLabelAttributedText(
        for message: MessageType,
        at indexPath: IndexPath) -> NSAttributedString? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        return NSAttributedString(
            string: dateFormatter.string(from: message.sentDate),
            attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.lightGray])
    }
}

extension RequestsChatViewController: MessagesLayoutDelegate {
    func avatarSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return .zero
    }
    
    func heightForLocation(message: MessageType, at indexPath: IndexPath, with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 0
    }
}

extension RequestsChatViewController: MessagesDisplayDelegate {
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        
        avatarView.isHidden = true
        
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.textMessageSizeCalculator.incomingAvatarSize = .zero
            var labelAlignment = LabelAlignment(textAlignment: NSTextAlignment.right, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
            layout.setMessageOutgoingMessageBottomLabelAlignment(labelAlignment)
            labelAlignment = LabelAlignment(textAlignment: NSTextAlignment.left, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
            layout.setMessageIncomingMessageBottomLabelAlignment(labelAlignment)
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .primary : .incomingMessage
    }
}

extension RequestsChatViewController: MessageInputBarDelegate {
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {
        let newMessage = Message(member: member, text: text, messageId: UUID().uuidString, date: Date())
        
//        messages.append(newMessage)
        inputBar.inputTextView.text = ""
        send(newMessage)
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToBottom()
    }
    
    private func send(_ message: Message) {
        let dateStamp = message.date.timeIntervalSince1970
        let intDateStamp = Int(dateStamp)
        
        let messageJSON = ["sender": message.member.id,
                           "date": intDateStamp,
                           "message": message.text,] as [String : Any]
        RideDB?.child("Requests").child((request?._id)!).child("messages").child(message.messageId).setValue(messageJSON)
        
        if request?._driver == mainUser?._userID {
            RideDB?.child("Users").child((request?._sender)!).child("requests").child("sent").child((request?._id)!).setValue(true)
        } else {
            RideDB?.child("Users").child((request?._driver)!).child("requests").child("received").child((request?._id)!).setValue(true)
        }
    }
}


extension UIColor {
    
    static var primary: UIColor {
        return rideClickableRed
    }
    
    static var incomingMessage: UIColor {
        return UIColor(red: 230 / 255, green: 230 / 255, blue: 230 / 255, alpha: 1)
    }
    
}

