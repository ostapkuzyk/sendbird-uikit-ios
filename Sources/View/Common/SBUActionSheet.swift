//
//  SBUActionSheet.swift
//  SendbirdUIKit
//
//  Created by Tez Park on 16/02/2020.
//  Copyright © 2020 Sendbird, Inc. All rights reserved.
//

import UIKit

/// This is a typealias for a closure that handles actions in an action sheet.
public typealias SBUActionSheetHandler = () -> Void

/// SBUActionSheetDelegate is a delegate that defines methods for handling action sheet events.
public protocol SBUActionSheetDelegate: NSObjectProtocol {
    func didSelectActionSheetItem(index: Int, identifier: Int)
    func didDismissActionSheet()
}

extension SBUActionSheetDelegate {
    /// This function is called when the action sheet is dismissed.
    public func didDismissActionSheet() {}
}

/// This class represents an item in an action sheet.
public class SBUActionSheetItem: SBUCommonItem {
    var completionHandler: SBUActionSheetHandler?
    
    /// initializer
    public override init(
        title: String? = nil,
        color: UIColor? = SBUColorSet.onLightTextHighEmphasis,
        image: UIImage? = nil,
        font: UIFont? = nil,
        tintColor: UIColor? = nil,
        textAlignment: NSTextAlignment = .left,
        tag: Int? = nil
    ) {
        super.init(
            title: title,
            color: color,
            image: image,
            font: font,
            tintColor: tintColor,
            textAlignment: textAlignment,
            tag: tag
        )
        self.completionHandler = nil
    }
    
    /// This function initializes actionSheet item.
    /// - Parameters:
    ///   - title: Title text
    ///   - color: Title color
    ///   - image: Item image
    ///   - font: Title font
    ///   - textAlignment: Title alignment
    ///   - tag: Item tag
    ///   - completionHandler: Item's completion handler
    public init(title: String? = nil,
                color: UIColor? = nil,
                image: UIImage? = nil,
                font: UIFont? = nil,
                textAlignment: NSTextAlignment = .left,
                tag: Int? = nil,
                completionHandler: SBUActionSheetHandler?) {
        super.init(
            title: title,
            color: color,
            image: image,
            font: font,
            textAlignment: textAlignment,
            tag: tag
        )
        self.completionHandler = completionHandler
    }
}

/// This class is used to create and manage action sheets in the application.
public class SBUActionSheet: NSObject {
    @SBUThemeWrapper(theme: SBUTheme.componentTheme)
    var theme: SBUComponentTheme
    
    static private let shared = SBUActionSheet()
    
    weak var delegate: SBUActionSheetDelegate?
    
    private var items: [SBUActionSheetItem] = []
    private var dismissHandler: (() -> Void)?
    
    private var safeAreaInset: UIEdgeInsets {
        self.window?.safeAreaInsets ?? .zero
    }
    
    var identifier: Int = -1
    var window: UIWindow?
    var baseView = UIView()
    var backgroundView = UIButton()
    
    let itemHeight: CGFloat = 56.0
    let bottomMargin: CGFloat = 48.0
    let sideMargin: CGFloat = 8.0
    let insideMargin: CGFloat = 16.0

    var prevOrientation: UIDeviceOrientation = .unknown
    
    var isShowing: Bool = false
    
    private override init() {
        super.init()
    }
    
    /// This static function shows the actionSheet.
    ///
    /// - Order
    ///   - item1
    ///   - item2
    ///   - item3
    ///   - cancel
    ///   
    /// See the example below for params generation.
    /// ```
    /// SBUActionSheet.show(
    ///     items: [
    ///         SBUActionSheetItem(title: TITLE1, image: IMAGE1),
    ///         SBUActionSheetItem(title: TITLE2, image: IMAGE2),
    ///     ],
    ///     cancelItem: SBUActionSheetItem(title: CANCEL_TITLE, image: CANCEL_IMAGE)
    /// )
    /// ```
    /// - Parameters:
    ///   - items: Item array
    ///   - cancelItem: Cancel item
    ///   - identifier: ActionSheet identifier
    ///   - oneTimetheme: One-time theme setting
    ///   - delegate: ActionSheet delegate
    public static func show(items: [SBUActionSheetItem],
                            cancelItem: SBUActionSheetItem,
                            identifier: Int = -1,
                            oneTimetheme: SBUComponentTheme? = nil,
                            delegate: SBUActionSheetDelegate? = nil,
                            dismissHandler: (() -> Void)? = nil) {
        self.shared.show(
            items: items,
            cancelItem: cancelItem,
            identifier: identifier,
            oneTimetheme: oneTimetheme,
            delegate: delegate,
            dismissHandler: dismissHandler
        )
    }
    
    /// This static function dismissed the actionSheet.
    public static func dismiss() {
        self.shared.dismiss()
    }

    private func show(items: [SBUActionSheetItem],
                      cancelItem: SBUActionSheetItem,
                      identifier: Int = -1,
                      oneTimetheme: SBUComponentTheme? = nil,
                      delegate: SBUActionSheetDelegate?,
                      dismissHandler: (() -> Void)?) {
        
        self.handleDismiss(isUserInitiated: false)
        
        self.prevOrientation = UIDevice.current.orientation
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        if let oneTimetheme = oneTimetheme {
            self.theme = oneTimetheme
        }
        
        self.window = UIApplication.shared.currentWindow
        guard let window = self.window else { return }
        self.identifier = identifier
        self.delegate = delegate
        self.items = items
        self.dismissHandler = dismissHandler
        
        baseView = UIView()
        backgroundView = UIButton()
        
        // Set backgroundView
        self.backgroundView.frame = window.bounds
        self.backgroundView.backgroundColor = theme.overlayColor
        self.backgroundView.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        
        // Set items
        let totalHeight = CGFloat(items.count + 1) * itemHeight + sideMargin + bottomMargin
        let itemWidth = window.frame.width - (sideMargin * 2) - (self.safeAreaInset.left + self.safeAreaInset.right)
        self.baseView.frame = CGRect(
            origin: CGPoint(x: sideMargin + self.safeAreaInset.left, y: window.frame.height - totalHeight),
            size: CGSize(width: itemWidth, height: totalHeight)
        )
        
        var itemOriginY: CGFloat = 0.0
        for index in 0..<items.count {
            let button = self.makeItems(
                item: items[index],
                separator: (index != items.count-1),
                isTop: (index == 0),
                isBottom: (index == items.count-1)
            )
            if let tag = items[index].tag {
                button.tag = tag
            } else {
                items[index].tag = index
                button.tag = index
            }
            var buttonFrame = button.frame
            buttonFrame.origin = CGPoint(x: 0, y: itemOriginY)
            button.frame = buttonFrame
            
            self.baseView.addSubview(button)
            
            itemOriginY += button.frame.height
        }

        itemOriginY += sideMargin

        let cancelButton = self.makeCancelItem(item: cancelItem)
        cancelButton.frame = CGRect(
            origin: CGPoint(x: 0, y: itemOriginY),
            size: cancelButton.frame.size
        )
        self.baseView.addSubview(cancelButton)

        // Add to window
        window.addSubview(self.backgroundView)
        window.addSubview(self.baseView)

        // Animation
        let baseFrame = self.baseView.frame
        self.baseView.frame = CGRect(
            origin: CGPoint(x: baseFrame.origin.x, y: window.frame.height),
            size: baseFrame.size
        )
        self.backgroundView.alpha = 0.0
        self.isShowing = true
        UIView.animate(withDuration: 0.1) {
            self.backgroundView.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.2, animations: {
                self.baseView.frame = baseFrame
                self.isShowing = false
            })
        }
    }
    
    @objc
    private func dismiss() {
        guard !isShowing else { return }

        self.handleDismiss(isUserInitiated: true)
    }
    
    @objc
    private func handleDismiss(isUserInitiated: Bool = true) {
        for subView in self.baseView.subviews {
            subView.removeFromSuperview()
        }
        
        self.backgroundView.removeFromSuperview()
        self.baseView.removeFromSuperview()
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil)
        
        if isUserInitiated {
            self.delegate?.didDismissActionSheet()
            let handler = self.dismissHandler
            self.dismissHandler = nil
            handler?()
        }
    }
    
    // MARK: Make Buttons
    private func makeItems(item: SBUActionSheetItem,
                           separator: Bool,
                           isTop: Bool,
                           isBottom: Bool) -> UIButton {
        
        let width: CGFloat = (self.window?.bounds.width ?? self.baseView.frame.width)
        let itemWidth: CGFloat = width - (self.sideMargin * 2) - (self.safeAreaInset.left + self.safeAreaInset.right)
        let itemButton = UIButton(
            frame: CGRect(
                origin: .zero,
                size: CGSize(width: itemWidth, height: self.itemHeight)
            )
        )
        
        itemButton.setBackgroundImage(
            UIImage.from(color: theme.backgroundColor),
            for: .normal
        )
        
        itemButton.setBackgroundImage(
            UIImage.from(color: theme.highlightedColor),
            for: .highlighted
        )
        
        itemButton.addTarget(self, action: #selector(onClickActionSheetButton), for: .touchUpInside)
        
        let titleLabel = UILabel()
        let imageView = UIImageView()

        // LTR
        // |-----------------------------------itemWidth------------------------------------|
        // |-self.insideMargin-|imageView|-self.insideMargin-|titleLabel|-self.insideMargin-|
        // titleLabel.width = itemWidth - self.insideMargin - imageView.width - self.insideMargin - self.insideMargin
        
        // RTL
        // |-----------------------------------itemWidth------------------------------------|
        // |-self.insideMargin-|titleLabel|-self.insideMargin-|imageView|-self.insideMargin-|
        
        let imageSize: CGFloat = 24.0
        
        var imageViewPosX: CGFloat = 0
        var titleLabelPosX: CGFloat = 0
        var titleLabelWidth: CGFloat = 0
        var textAlignment: NSTextAlignment = .left
        if UIView.appearance().semanticContentAttribute == .forceLeftToRight {
            textAlignment = .left
            titleLabelPosX = self.insideMargin
            if item.image != nil {
                imageViewPosX = itemWidth - self.insideMargin - imageSize
                titleLabelWidth = itemWidth - self.insideMargin - imageSize - self.insideMargin - self.insideMargin
            } else {
                titleLabelWidth = itemWidth - self.insideMargin - self.insideMargin
            }
        } else {
            textAlignment = .right
            imageViewPosX = self.insideMargin
            if item.image != nil {
                titleLabelPosX = self.insideMargin + imageSize + self.insideMargin
                titleLabelWidth = itemWidth - self.insideMargin - self.insideMargin - imageSize - self.insideMargin
            } else {
                titleLabelWidth = itemWidth - self.insideMargin - self.insideMargin
            }
        }

        if let image = item.image {
            imageView.frame = CGRect(
                origin: CGPoint(x: imageViewPosX, y: self.insideMargin),
                size: CGSize(width: imageSize, height: imageSize)
            )

            imageView.image = image
            itemButton.addSubview(imageView)
        }

        titleLabel.text = item.title
        titleLabel.font = item.font ?? theme.actionSheetTextFont
        titleLabel.textColor = item.color ?? theme.actionSheetTextColor
        titleLabel.textAlignment = textAlignment
        
        titleLabel.frame = CGRect(
            origin: CGPoint(x: titleLabelPosX, y: 0),
            size: CGSize(width: titleLabelWidth, height: self.itemHeight)
        )
        
        itemButton.addSubview(titleLabel)
        
        if separator {
            let separatorLine = UIView(
                frame: CGRect(
                    origin: CGPoint(x: 0.0, y: itemHeight - 0.5),
                    size: CGSize(width: itemWidth, height: 0.5)
                )
            )
            separatorLine.backgroundColor = theme.separatorColor
            itemButton.addSubview(separatorLine)
        }
        
        let rectShape = CAShapeLayer()
        rectShape.bounds = itemButton.frame
        rectShape.position = itemButton.center
        
        var corners: UIRectCorner = []
        if isTop {
            corners.update(with: [.topLeft, .topRight])
        }
        if isBottom {
            corners.update(with: [.bottomLeft, .bottomRight])
        }
        rectShape.path = UIBezierPath(
            roundedRect: itemButton.bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: 10, height: 10))
            .cgPath
        itemButton.layer.mask = rectShape
        
        return itemButton
    }
    
    private func makeCancelItem(item: SBUActionSheetItem) -> UIButton {
        let width: CGFloat = (self.window?.bounds.width ?? self.baseView.frame.width)
        let itemWidth: CGFloat = width - (self.sideMargin * 2) - (self.safeAreaInset.left + self.safeAreaInset.right)
        let itemButton = UIButton(
            frame: CGRect(
                origin: .zero,
                size: CGSize(width: itemWidth, height: self.itemHeight)
            )
        )
        
        itemButton.setBackgroundImage(
            UIImage.from(color: theme.backgroundColor),
            for: .normal
        )
        itemButton.setBackgroundImage(
            UIImage.from(color: theme.highlightedColor),
            for: .highlighted
        )
        
        itemButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        
        let titleLabel = UILabel()
        titleLabel.frame = CGRect(origin: .zero, size: CGSize(width: itemWidth, height: itemHeight))
        titleLabel.text = item.title
        titleLabel.font = item.font ?? theme.actionSheetTextFont
        titleLabel.textColor = item.color ?? theme.actionSheetItemColor
        titleLabel.textAlignment = .center
        
        itemButton.addSubview(titleLabel)
        
        let rectShape = CAShapeLayer()
        rectShape.bounds = itemButton.frame
        rectShape.position = itemButton.center
        rectShape.path = UIBezierPath(
            roundedRect: itemButton.bounds,
            byRoundingCorners: [.allCorners],
            cornerRadii: CGSize(width: 10, height: 10)
        ).cgPath
        itemButton.layer.mask = rectShape
        
        return itemButton
    }
    
    // MARK: Button action
    @objc
    private func onClickActionSheetButton(sender: UIButton) {
        self.dismiss()
        self.delegate?.didSelectActionSheetItem(
            index: sender.tag,
            identifier: self.identifier
        )
        
        let item = self.items.first(where: { $0.tag == sender.tag })
        item?.completionHandler?()
    }
    
    // MARK: Orientation
    @objc
    func orientationChanged(_ notification: NSNotification) {
        let currentOrientation = UIDevice.current.orientation
        
        if prevOrientation.isPortrait && currentOrientation.isLandscape ||
            prevOrientation.isLandscape && currentOrientation.isPortrait {
            dismiss()
        }

        self.prevOrientation = currentOrientation
    }
}
