//
//  EmojiArtViewController.swift
//  EmojiArt
//
//  Created by Alex Yatsenko on 09.05.2020.
//  Copyright © 2020 Alexislog's Production. All rights reserved.
//

import UIKit

extension EmojiArt.EmojiInfo {
    
    init?(label: UILabel) {
        if let attributedText = label.attributedText,
            let font = attributedText.font {
            x = Int(label.center.x)
            y = Int(label.center.y)
            text = attributedText.string
            size = Int(font.pointSize)
        } else {
            return nil
        }
    }
}

final class EmojiArtViewController: UIViewController {
    
    private enum ImageSource {
        case remote(URL, UIImage)
        case local(Data, UIImage)
        
        var image: UIImage {
            switch self {
            case .remote(_, let image): return image
            case .local(_, let image): return image
            }
        }
    }
    
    // MARK: - Model
    
    private var emojiArt: EmojiArt? {
        get {
            if let imageSource = emojiArtBackgroundImage {
                let emojis = emojiArtView.subviews.compactMap { $0 as? UILabel }.compactMap { EmojiArt.EmojiInfo(label: $0) }
                switch imageSource {
                case .remote(let url, _): return EmojiArt(url: url, emojis: emojis)
                case .local(let imageData, _): return EmojiArt(imageData: imageData, emojis: emojis)
                }
            }
            return nil
        }
        set {
            emojiArtBackgroundImage = nil
            emojiArtView.subviews.compactMap { $0 as? UILabel }.forEach { $0.removeFromSuperview() }
            let imageData = newValue?.imageData
            let image = (imageData != nil) ? UIImage(data: imageData!) : nil
            if let url = newValue?.url {
                imageFetcherManager = ImageFetcherManager { (url, image) in
                    DispatchQueue.main.async {
                        if image == self.imageFetcherManager.backupImage {
                            self.emojiArtBackgroundImage = .local(imageData!, image)
                        } else {
                            self.emojiArtBackgroundImage = .remote(url, image)
                        }
                        self.addEmojisToView(from: newValue)
                    }
                }
                imageFetcherManager.backupImage = image
                imageFetcherManager.fetch(url)
            } else if image != nil {
                emojiArtBackgroundImage = .local(imageData!, image!)
                addEmojisToView(from: newValue)
            }
        }
    }
    
    lazy var emojiArtView = EmojiArtView()
    var document: EmojiArtDocument?
    private let notificationCenter = NotificationCenter.default
    private var documentObserver: NSObjectProtocol?
    private var emojiArtViewObserver: NSObjectProtocol?
    private var imageFetcherManager: ImageFetcherManager!
    private var emojis = "🐶🐭🦊🦋🐢🐸🐵🐞🐿🐇🐯".map { String($0) }
    private var addingEmoji = false
    private var suppressedWarnings = false
    private var alertPresentedCountWithURL = 0
    private var previousURL: URL?
    private var embeddedDocInfo: DocumentInfoViewController?
    
    private var emojiArtBackgroundImage: ImageSource? {
        didSet {
            emojiArtView.backgroundImage = emojiArtBackgroundImage?.image
            let size = emojiArtBackgroundImage?.image.size ?? CGSize.zero
            emojiArtView.frame = CGRect(origin: CGPoint.zero, size: size)
            scrollViewHeight?.constant = size.height
            scrollViewWidth?.constant = size.width
            scrollView.contentSize = size
            if let dropZone = self.dropZone, size.width > 0, size.height > 0 {
                scrollView.zoomScale = max(dropZone.bounds.width / size.width, dropZone.bounds.height / size.height)
            }
        }
    }
    
    // MARK: - Storyboard
        
    @IBOutlet private weak var cameraButton: UIBarButtonItem! {
        didSet {
            cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }
    @IBOutlet private weak var emojiCollectionView: UICollectionView! {
        didSet {
            emojiCollectionView.dataSource = self
            emojiCollectionView.delegate = self
            emojiCollectionView.dragDelegate = self
            emojiCollectionView.dropDelegate = self
            emojiCollectionView.dragInteractionEnabled = true
        }
    }
    @IBOutlet private weak var dropZone: UIView! {
        didSet {
            dropZone.addInteraction(UIDropInteraction(delegate: self))
        }
    }
    @IBOutlet private weak var scrollView: UIScrollView! {
        didSet {
            scrollView.delegate = self
            scrollView.minimumZoomScale = 0.1
            scrollView.maximumZoomScale = 5
            scrollView.addSubview(emojiArtView)
        }
    }
    
    @IBOutlet private weak var scrollViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var embeddedDocInfoHeight: NSLayoutConstraint!
    @IBOutlet private weak var embeddedDocInfoWidth: NSLayoutConstraint!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if document?.documentState != .normal {
            documentObserver = notificationCenter.addObserver(
                forName: UIDocument.stateChangedNotification,
                object: document,
                queue: .main,
                using: { _ in
                    if self.document?.documentState == .normal,
                        let docInfoVC = self.embeddedDocInfo {
                        docInfoVC.document = self.document
                        self.embeddedDocInfoWidth.constant = docInfoVC.preferredContentSize.width
                        self.embeddedDocInfoHeight.constant = docInfoVC.preferredContentSize.height
                    }
            })
            document?.open(completionHandler: { success in
                if success {
                    self.title = self.document?.localizedName
                    self.emojiArt = self.document?.emojiArt
                    self.emojiArtViewObserver = self.notificationCenter.addObserver(
                        forName: .emojiArtViewDidChange,
                        object: self.emojiArtView,
                        queue: .main,
                        using: { _ in
                            self.documentChanged()
                    }
                    )
                }
            })
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Document Info" {
            if let destinationVC = segue.destination.contents as? DocumentInfoViewController {
                destinationVC.document = document
                if let ppc = destinationVC.popoverPresentationController {
                    ppc.delegate = self
                }
            }
        } else if segue.identifier == "Embed Document Info" {
            embeddedDocInfo = segue.destination.contents as? DocumentInfoViewController
        }
    }
    
    @IBAction private func takeBackgroundPhoto(_ sender: UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @IBAction private func addEmoji() {
        addingEmoji = true
        emojiCollectionView.reloadSections(IndexSet(integer: 0))
    }
    
    @IBAction func closeDocument(_ sender: UIBarButtonItem? = nil) {
        if let observer = emojiArtViewObserver {
            notificationCenter.removeObserver(observer)
        }
        if document?.emojiArt != nil {
            document?.thumbnail = emojiArtView.snapshot
        }
        presentingViewController?.dismiss(animated: true) {
            self.document?.close()
        }
    }
    
    @IBAction private func closeDocument(by segue: UIStoryboardSegue) {
        closeDocument()
    }
    
    private func documentChanged() {
        document?.emojiArt = emojiArt
        if document?.emojiArt != nil {
            document?.updateChangeCount(.done)
        }
    }
    
    private func presentWarning(with title: String, message: String, for url: URL? = nil) {
        if suppressedWarnings, previousURL == url {
            alertPresentedCountWithURL += 1
            if alertPresentedCountWithURL == 3 {
                suppressedWarnings = false
                alertPresentedCountWithURL = 0
            }
        }
        guard !suppressedWarnings || url == nil else { return }
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK",
                                      style: .default))
        if url != nil {
            alert.addAction(UIAlertAction(title: "Stop Warning",
                                          style: .destructive,
                                          handler: { _ in
                                            self.suppressedWarnings = true
            }))
            previousURL = url
        }
        present(alert, animated: true)
    }
    
    private func addEmojisToView(from emojiArt: EmojiArt?) {
        emojiArt?.emojis.forEach {
            let attributedText = $0.text.attributedString(withTextStyle: .body, ofSize: CGFloat($0.size))
            self.emojiArtView.addLabel(with: attributedText, centeredAt: CGPoint(x: $0.x, y: $0.y))
        }
    }
}

    // MARK: - Camera

extension EmojiArtViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = ((info[.editedImage] ?? info[.originalImage]) as? UIImage)?.scaled(by: 0.25) {
            if let imageData = image.jpegData(compressionQuality: 1) {
                emojiArtBackgroundImage = .local(imageData, image)
                documentChanged()
            } else {
                presentWarning(with: "Input from camera failed",
                               message: "Something wrong with shot")
            }
        }
        picker.presentingViewController?.dismiss(animated: true)
    }
}

    // MARK: - UIScrollViewDelegate

extension EmojiArtViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return emojiArtView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollViewHeight.constant = scrollView.contentSize.height
        scrollViewWidth.constant = scrollView.contentSize.width
    }
}

    // MARK: - UICollectionView

extension EmojiArtViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : emojis.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath)
            if let emojiCell = cell as? EmojiCollectionViewCell {
                emojiCell.configure(with: emojis[indexPath.row])
            }
            return cell
        } else if addingEmoji {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiInputCell", for: indexPath)
            if let inputCell = cell as? TextFieldCollectionViewCell {
                inputCell.resignationHandler = { [weak self, unowned inputCell] in
                    if let text = inputCell.textField.text {
                        self?.emojis = (text.map { String($0) } + self!.emojis.uniquified)
                    }
                    self?.addingEmoji = false
                    self?.emojiCollectionView.reloadData()
                }
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddEmojiButtonCell", for: indexPath)
            return cell
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let inputCell = cell as? TextFieldCollectionViewCell {
            inputCell.textField.becomeFirstResponder()
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let cell = emojiCollectionView.visibleCells.first else { return CGSize(width: 80, height: 80) }
        if addingEmoji && indexPath.section == 0 {
            return CGSize(width: 300, height: cell.bounds.height)
        } else {
            return CGSize(width: cell.bounds.width, height: cell.bounds.height)
        }
    }
    
    // MARK: - UICollectionViewDragDelegate
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }
    
    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        guard !addingEmoji, let attributedString = (emojiCollectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell)?.label.attributedText else { return [] }
        let dragItem = UIDragItem(itemProvider: NSItemProvider(object: attributedString))
        dragItem.localObject = attributedString
        return [dragItem]
    }
    
    // MARK: - UICollectionViewDropDelegate
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let indexPath = destinationIndexPath, indexPath.section == 1 {
            let isSelf = session.localDragSession?.localContext as? UICollectionView == collectionView
            return UICollectionViewDropProposal(operation: isSelf ? .move : .copy, intent: .insertAtDestinationIndexPath)
        } else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                if let attributedString = item.dragItem.localObject as? NSAttributedString {
                    collectionView.performBatchUpdates({
                        emojis.remove(at: sourceIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        emojis.insert(attributedString.string, at: destinationIndexPath.item)
                        collectionView.insertItems(at: [destinationIndexPath])
                    })
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                }
            } else {
                let placeholderContext = coordinator.drop(
                    item.dragItem,
                    to: UICollectionViewDropPlaceholder(insertionIndexPath: destinationIndexPath, reuseIdentifier: "DropPlaceholderCell")
                )
                item.dragItem.itemProvider.loadObject(ofClass: NSAttributedString.self) { (provider, error) in
                    if let error = error {
                        print(error.localizedDescription)
                    }
                    DispatchQueue.main.async {
                        if let attributedString = provider as? NSAttributedString {
                            placeholderContext.commitInsertion { insertionIndexPath in
                                self.emojis.insert(attributedString.string, at: insertionIndexPath.item)
                            }
                        } else {
                            placeholderContext.deletePlaceholder()
                        }
                    }
                }
            }
        }
    }
}

    // MARK: - UIDropInteractionDelegate

extension EmojiArtViewController: UIDropInteractionDelegate {
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSURL.self) && session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        imageFetcherManager = ImageFetcherManager() { (url, image) in
            DispatchQueue.main.async {
                if image == self.imageFetcherManager.backupImage {
                    if let imageData = image.jpegData(compressionQuality: 1) {
                        self.emojiArtBackgroundImage = .local(imageData, image)
                        self.documentChanged()
                    } else {
                        self.presentWarning(with: "Image Transfer Failed",
                                                  message: "Couldn't transfer the dropped image from its source. \nShow this warning in the future?",
                                                  for: url)
                    }
                } else {
                    self.emojiArtBackgroundImage = .remote(url, image)
                    self.documentChanged()
                }
            }
        }
        
        session.loadObjects(ofClass: NSURL.self) { nsURLs in
            if let url = (nsURLs.first as? URL)?.imageURL {
                self.imageFetcherManager.fetch(url)
            }
        }
        session.loadObjects(ofClass: UIImage.self) { images in
            if let image = images.first as? UIImage {
                self.imageFetcherManager.backupImage = image
            }
        }
    }
}

    // MARK: - UIPopoverPresentationControllerDelegate

extension EmojiArtViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}
