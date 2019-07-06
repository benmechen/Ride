//
//  SentRequestsViewController.swift
//  Ride
//
//  Created by Ben Mechen on 07/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import Firebase
import Crashlytics

class RequestsChatViewController: MessagesViewController {
    
//    override var canResignFirstResponder: Bool {return false}
    
    @IBOutlet weak var requestDeletedReceived: UILabel!
    @IBOutlet weak var requestDeletedSent: UILabel!
    @IBOutlet weak var sentInput: UITextField!
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var request: Request? = nil
    var messages: [Message] = []
    var member: Member!
    var userName: String? = nil
    override var canBecomeFirstResponder: Bool { return true }
    override var canResignFirstResponder: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
//        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
//        self.navigationController?.navigationBar.shadowImage = UIImage()
//        self.navigationController?.navigationBar.isTranslucent = true
//        self.navigationController?.view.backgroundColor = UIColor(named: "Main")
        
//        print("Setting nav to default")
//        self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
//        self.navigationController?.navigationBar.shadowImage = nil
//        self.navigationController?.navigationBar.isTranslucent = true
//        self.navigationController?.view.backgroundColor = UIColor(named: "Main")
        
        
        while request == nil && userName == nil {
            print("Waiting for request")
        }
        
        if request == nil {
            return
        }
        
        if (request?.deleted)! {
            self.messageInputBar.isHidden = true
            if self.sentInput != nil {
                self.sentInput.isHidden = true
            }
            
            if requestDeletedReceived != nil {
                self.view.bringSubviewToFront(requestDeletedReceived)
            }
            if requestDeletedSent != nil {
                self.view.bringSubviewToFront(requestDeletedSent)
            }
        }
        
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            self.member = Member(id: Auth.auth().currentUser!.uid, name: user!.name)
        })
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messageInputBar.delegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        
        listenForMessagesForRequest((request?._id)!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.sentInput != nil {
            self.sentInput.isHidden = request?.deleted ?? false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.becomeFirstResponder()
        self.messageInputBar.becomeFirstResponder()
        self.messageInputBar.isHidden = false
        self.messageInputBar.inputTextView.becomeFirstResponder()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
//    @IBAction func hideReceivedInput(_ sender: Any) {
//        receivedInput.isHidden = true
//        messageInputBar.inputTextView.becomeFirstResponder()
//    }
//
//    @IBAction func removeReceivedInputText(_ sender: Any) {
//        receivedInput.text = ""
//    }
    
    @IBAction func closeChat(_ sender: Any) {
        self.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func hideSentInput(_ sender: Any) {
        sentInput.isHidden = true
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    
    @IBAction func removeSentInputText(_ sender: Any) {
        sentInput.text = ""
    }
    
    // MARK: - Private functions
    private func listenForMessagesForRequest(_ requestID: String) {
        let query = RideDB.child("Requests").child(requestID).child("messages").queryOrdered(byChild: "date")

        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            query.observe(.childAdded, with: { (snapshot) in
                if let value = snapshot.value as? [String: Any] {
                    let interval = TimeInterval(exactly: value["date"] as! Int)
                    let date = Date(timeIntervalSince1970: interval!)

                    var name = ""

                    if value["sender"] as? String == Auth.auth().currentUser!.uid {
                        name = user!.name
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
        })
    }
}

extension RequestsChatViewController: MessagesDataSource {
    func currentSender() -> SenderType {
        return Sender(id: member.id, displayName: member.name)
    }
    
    func numberOfSections(
        in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
//    func currentSender() -> Sender {
//        return Sender(id: member.id, displayName: member.name)
//    }
    
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

extension RequestsChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
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
        RideDB.child("Requests").child((request?._id)!).child("messages").child(message.messageId).setValue(messageJSON)
        RideDB.child("Requests").child((request?._id)!).child("last_message").setValue(message.messageId)
        
        if request?._driver == Auth.auth().currentUser!.uid {
            RideDB.child("Users").child((request?._sender)!).child("requests").child("sent").child((request?._id)!).child("new").setValue(true)
        } else {
            RideDB.child("Users").child((request?._driver)!).child("requests").child("received").child((request?._id)!).child("new").setValue(true)
        }
    }
}

extension RequestsChatViewController: UserManagerClient {
    func setUserManager(_ userManager: UserManagerProtocol) {
        self.userManager = userManager
    }
}

extension UIColor {
    
    static var primary: UIColor {
        return UIColor(named: "Accent")!
    }
    
    static var incomingMessage: UIColor {
        return UIColor(red: 230 / 255, green: 230 / 255, blue: 230 / 255, alpha: 1)
    }
    
}




// MARK: Delete - First Responder Testing
extension UIView {
    var firstResponder: UIView? {
        guard !isFirstResponder else { return self }
        
        for subview in subviews {
            if let firstResponder = subview.firstResponder {
                return firstResponder
            }
        }
        
        return nil
    }
}

