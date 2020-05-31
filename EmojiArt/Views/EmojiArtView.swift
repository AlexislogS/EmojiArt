//
//  EmojiArtView.swift
//  EmojiArt
//
//  Created by Alex Yatsenko on 09.05.2020.
//  Copyright © 2020 Alexislog's Production. All rights reserved.
//

import UIKit

final class EmojiArtView: UIView {

    private let notificationCenter = NotificationCenter.default
    private var labelObservations = [UIView : NSKeyValueObservation]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addInteraction(UIDropInteraction(delegate: self))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var backgroundImage: UIImage? { didSet { setNeedsDisplay() } }
    
    override func draw(_ rect: CGRect) {
        backgroundImage?.draw(in: bounds)
    }

    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        if labelObservations[subview] != nil {
            labelObservations[subview] = nil
        }
    }
}

    // MARK: - UIDropInteractionDelegate

extension EmojiArtView: UIDropInteractionDelegate {
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: NSAttributedString.self) { providers in
            let dropPoint = session.location(in: self)
            for attributedString in providers as? [NSAttributedString] ?? [] {
                self.addLabel(with: attributedString, centeredAt: dropPoint)
                self.notificationCenter.post(name: .emojiArtViewDidChange, object: self)
            }
        }
    }
    
    func addLabel(with attributedString: NSAttributedString, centeredAt point: CGPoint) {
        let label = UILabel()
        label.backgroundColor = .clear
        label.attributedText = attributedString
        label.sizeToFit()
        label.center = point
        addEmojiGestureRecognizers(to: label)
        addSubview(label)
        labelObservations[label] = label.observe(\.center) { (_, _) in
            self.notificationCenter.post(name: .emojiArtViewDidChange, object: self)
        }
    }
}

    // MARK: - UIGestureRecognizer

extension EmojiArtView {
    
    private var selectedSubview: UIView? {
        get { return subviews.filter { $0.layer.borderWidth > 0 }.first }
        set {
            subviews.forEach { $0.layer.borderWidth = 0 }
            newValue?.layer.borderWidth = 1
            newValue != nil ? enableRecognizers() : disableRecognizers()
        }
    }
    
    func addEmojiGestureRecognizers(to view: UIView) {
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                         action: #selector(selectSubview(by:))))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self,
                                                         action: #selector(selectAndMoveSubview(by:))))
    }
    
    private func disableRecognizers() {
        if let scrollView = superview as? UIScrollView {
            scrollView.panGestureRecognizer.isEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
        }
        gestureRecognizers?.forEach { $0.isEnabled = false}
    }
    
    private func enableRecognizers() {
        if let scrollView = superview as? UIScrollView {
            scrollView.panGestureRecognizer.isEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false
        }
        if gestureRecognizers == nil || gestureRecognizers?.count == 0 {
            addGestureRecognizer(UITapGestureRecognizer(target: self,
            action: #selector(deselectSubview)))
            addGestureRecognizer(UIPinchGestureRecognizer(target: self,
                                                          action: #selector(resizeSelectedLabel(by:))))
        } else {
            gestureRecognizers?.forEach { $0.isEnabled = true }
        }
    }
    
    @objc private func selectSubview(by recognizer: UITapGestureRecognizer) {
        if recognizer.state == .recognized {
            selectedSubview = recognizer.view
        }
    }
    
    @objc private func deselectSubview() {
        selectedSubview = nil
    }
    
    @objc private func selectAndMoveSubview(by recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if selectedSubview != nil, recognizer.view != nil {
                selectedSubview = recognizer.view
            }
        case .changed, .ended:
            if selectedSubview != nil {
                recognizer.view?.center = recognizer.view!.center.offset(by: recognizer.translation(in: self))
                recognizer.setTranslation(CGPoint.zero, in: self)
            }
        default: break
        }
    }
    
    @objc private func resizeSelectedLabel(by recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .changed, .ended:
            if let label = selectedSubview as? UILabel {
                label.attributedText = label.attributedText?.withFontScaled(by: recognizer.scale)
                label.stretchToFit()
                recognizer.scale = 1
            }
        default: break
        }
    }
    
}
