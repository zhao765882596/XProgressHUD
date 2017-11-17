//
//  ProgressHUD.swift
//  channel_sp
//
//  Created by ming on 2017/11/2.
//  Copyright © 2017年 TiandaoJiran. All rights reserved.
//

import UIKit
public enum ProgressHUDMode: Int {
    case indeterminate = 0     /// UIActivityIndicatorView.
    case determinate = 1    /// A round, pie-chart like, progress view.
    case determinateHorizontalBar = 2    /// Horizontal progress bar.
    case annularDeterminate = 3    /// Ring-shaped progress view.
    case customView = 4    /// Shows a custom view.
    case text = 5    /// Shows only labels.

}
public enum ProgressHUDAnimation: Int {
    case fade = 0
    case zoom = 1
    case zoomOut = 2
    case zoomIn = 3

}
public enum ProgressHUDBackgroundStyle: Int {
    case solidColor = 0
    case blur = 1
}
@objc public protocol ProgressHUDDelegate: NSObjectProtocol {
    @objc func hudWasHidden(hub: ProgressHUD)
}

public class ProgressHUD: UIView {

    public weak var delegate:ProgressHUDDelegate?

    public var completion: (() -> Void)?

    public var graceTime: TimeInterval = 0

    public var minShowTime: TimeInterval = 0

    public var removeFromSuperViewOnHide: Bool = true

    public var mode: ProgressHUDMode = .indeterminate {
        didSet {
            if oldValue != mode {
                updateIndicators()
            }
        }
    }

    public var progress: Double = 0.0 {
        didSet {
            if oldValue != progress {
                if indicator is BarProgressView {
                    (indicator as? BarProgressView)?.progress = progress
                }
                if indicator is RoundProgressView {
                    (indicator as? RoundProgressView)?.progress = progress
                }
            }
        }
    }

    public var contentColor: UIColor = UIColor.init(white: 0, alpha: 0.5) {
        didSet {
            if oldValue != contentColor && oldValue.isEqual(contentColor) {
                updateViews(color: contentColor)
                updateIndicators()
            }
        }
    }
    public var animationType: ProgressHUDAnimation = .fade

    public var offset: CGPoint = CGPoint.zero {
        didSet {
            if oldValue != offset {
                setNeedsUpdateConstraints()
            }
        }
    }

    public var margin: CGFloat = 20 {
        didSet {
            if oldValue != margin {
                setNeedsUpdateConstraints()
            }
        }
    }

    public var minSize: CGSize = CGSize.zero {
        didSet {
            if oldValue != minSize {
                setNeedsUpdateConstraints()
            }
        }
    }

    public var isSquare = false {
        didSet {
            if oldValue != isSquare {
                setNeedsUpdateConstraints()
            }
        }
    }

    public var areDefaultMotionEffectsEnabled = true {
        didSet {
            if oldValue != areDefaultMotionEffectsEnabled {
                updateBezelMotionEffects()
            }
        }
    }


    public var progressObject: Progress? {
        didSet {
            if oldValue != progressObject {
                setNSProgressDisplayLink(enabled: true)
            }
        }
    }

    public var bezelView = BackgroundView()

    public var backgroundView = BackgroundView()

    public var customView: UIView? {
        didSet {
            if oldValue != customView {
                if mode == .customView {
                    updateIndicators()
                }
            }
        }
    }


    public var label = UILabel()

    public var detailsLabel = UILabel()

    public var button = ProgressHUDRoundedButton.init(type: .custom)

    private var isUseAnimation = true

    private var hasFinished = false

    private var indicator: UIView?

    private var showStarted: Date?

    private var paddingConstraints: Array<NSLayoutConstraint> = []
    private var bezelConstraints: Array<NSLayoutConstraint> = []
    private var topSpacer = UIView()
    private var bottomSpacer = UIView()

    private var graceTimer: Timer?
    private var minShowTimer: Timer?
    private var hideDelayTimer: Timer?
    private var progressObjectDisplayLink: CADisplayLink? {
        willSet {
            if newValue != progressObjectDisplayLink {
                progressObjectDisplayLink?.invalidate()
            }
        }
        didSet {
            if oldValue != progressObjectDisplayLink {
                progressObjectDisplayLink?.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            }
        }
    }

// MARK: - 公开方法
    @discardableResult
    public class func showHUD(forView: UIView? = nil, animated: Bool = true) -> ProgressHUD? {
        var view = forView
        if view == nil {
            view = UIApplication.shared.keyWindow
        }
        let hub = ProgressHUD.init(view: view)
        hub.removeFromSuperViewOnHide = true
        view?.addSubview(hub)
        hub.show(animated: animated)
        return hub
    }
    @discardableResult
    public class func hideHUD(forView: UIView? = nil, animated: Bool = true) -> Bool {
        let hub = self.HUD(forView: forView)
        if hub != nil {
            hub?.removeFromSuperViewOnHide = true
            hub?.hide(animated: animated)
            return true
        }
        return false
    }
    @discardableResult
    public class func HUD(forView: UIView? = nil) -> ProgressHUD? {
        var view = forView
        if view == nil {
            view = UIApplication.shared.keyWindow
        }
        if view != nil {
            for subView in forView!.subviews {
                if subView is ProgressHUD {
                    return subView as? ProgressHUD
                }
            }
        }
        return nil
    }


    public convenience init(view: UIView?) {
        self.init(frame: view?.bounds ?? CGRect.zero)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func show(animated: Bool = true) {
        DispatchQueue.main.async {
            self.minShowTimer?.invalidate()
            self.minShowTimer = nil
            self.isUseAnimation = animated
            if self.graceTime > 0.0 {
                self.graceTimer = Timer.init(timeInterval: self.graceTime, target: self, selector: #selector(self.handleGraceTimer(timer:)), userInfo: nil, repeats: false)
                RunLoop.current.add(self.graceTimer!, forMode: RunLoopMode.commonModes)
            } else {
                self.show(usingAnimation: self.isUseAnimation)
            }
        }
    }
    public func hide(animated: Bool = true, afterDelay: TimeInterval = 0.0) {
        DispatchQueue.main.async {
            if afterDelay <= 0.0 {
                self.graceTimer?.invalidate()
                self.graceTimer = nil
                self.hasFinished = true
                if self.minShowTime > 0 && self.showStarted != nil {
                    let interv = Date().timeIntervalSince(self.showStarted!)
                    if interv < self.minShowTime {
                        self.minShowTimer = Timer.init(timeInterval: self.minShowTime - interv, target: self, selector: #selector(self.handleMinShowTimer(timer:)), userInfo: nil, repeats: false)
                        RunLoop.current.add(self.minShowTimer!, forMode: RunLoopMode.commonModes)
                    }
                } else {
                    self.hide(usingAnimation: self.isUseAnimation)
                }
            } else {
                self.hideDelayTimer = Timer.init(timeInterval: afterDelay, target: self, selector: #selector(self.handleHideTimer(timer:)), userInfo: animated, repeats: false)
                RunLoop.current.add(self.hideDelayTimer!, forMode: RunLoopMode.commonModes)
            }
        }
    }

}
extension ProgressHUD {
// MARK: - timer

    @objc func handleGraceTimer(timer: Timer) {
        if !hasFinished {
            show(usingAnimation: isUseAnimation)
        }
    }
    @objc func handleHideTimer(timer: Timer) {
        hide(animated: timer.userInfo as? Bool ?? false)
    }

    @objc func handleMinShowTimer(timer: Timer) {
        hide(usingAnimation: self.isUseAnimation)
    }
// MARK: - view UIViewHierarchy
    public override func didMoveToSuperview() {
        updateForCurrentOrientation(animated: false)
    }
// MARK: - Internal show & hide operations
    func show(usingAnimation: Bool) {
        bezelView.layer.removeAllAnimations()
        backgroundView.layer.removeAllAnimations()
        hideDelayTimer?.invalidate()
        hideDelayTimer = nil
        showStarted = Date()
        alpha = 1.0
        setNSProgressDisplayLink(enabled: true)
        if usingAnimation {
            update(animateIn: true,type:animationType, completion: nil)
        } else {
            backgroundView.alpha = 1.0
        }
    }
    func hide(usingAnimation: Bool) {
        if usingAnimation && showStarted != nil {
            showStarted = nil
            update(animateIn: false, type: animationType, completion: {[weak self] (isFinished) in
                self?.done()
            })
        } else {
            showStarted = nil
            bezelView.alpha = 1.0
            backgroundView.alpha = 1.0
            done()
        }
    }

    func update(animateIn: Bool,type: ProgressHUDAnimation, completion: ((Bool) -> Void)?) {
        var animationType = type

        if animationType == .zoom {
            animationType = animateIn ? .zoomIn : .zoomOut
        }
        let small = CGAffineTransform.init(scaleX: 0.5, y: 0.5)
        let large = CGAffineTransform.init(scaleX: 1.5, y: 1.5)
        if animateIn && bezelView.alpha == 0.0 && type == .zoomIn {
            bezelView.transform = small
        } else if animateIn && bezelView.alpha == 0.0 && type == .zoomOut {
            bezelView.transform = large
        }

        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .beginFromCurrentState, animations: {
            if animateIn {
                self.bezelView.transform = CGAffineTransform.identity
            } else if type == .zoomIn {
                self.bezelView.transform = large
            } else if type == .zoomOut {
                self.bezelView.transform = small
            }
            self.bezelView.alpha = animateIn ? 1.0 : 0.0
            self.backgroundView.alpha = animateIn ? 1.0 : 0.0

        }, completion: completion)
    }

    func done() {
        hideDelayTimer?.invalidate()
        setNSProgressDisplayLink(enabled: false)
        if hasFinished {
            alpha = 0.0
            if removeFromSuperViewOnHide {
                removeFromSuperview()
            }
        }
        if completion != nil {
            completion!()
        }
        if delegate?.responds(to: #selector(delegate?.hudWasHidden(hub:))) == true {
            delegate?.hudWasHidden(hub: self)
        }
    }
// MARK: - UI
    func setupViews() {
        backgroundView.frame = bounds
        backgroundView.backgroundColor = UIColor.clear
        backgroundView.style = .solidColor
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.alpha = 0.0
        addSubview(backgroundView)

        bezelView.translatesAutoresizingMaskIntoConstraints = false
        bezelView.layer.cornerRadius = 5.0
        bezelView.alpha = 0.0
        addSubview(bezelView)

        updateBezelMotionEffects()

        label.adjustsFontSizeToFitWidth = false
        label.textAlignment = .center
        label.textColor = contentColor
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.isOpaque = false
        label.backgroundColor = UIColor.clear
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .horizontal)
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .vertical)
        bezelView.addSubview(label)

        detailsLabel.adjustsFontSizeToFitWidth = false
        detailsLabel.textAlignment = .center
        detailsLabel.textColor = contentColor
        detailsLabel.font = UIFont.systemFont(ofSize: 12)
        detailsLabel.isOpaque = false
        detailsLabel.backgroundColor = UIColor.clear
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .horizontal)
        detailsLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .vertical)
        bezelView.addSubview(detailsLabel)

        button.titleLabel?.textAlignment = .center
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        button.setTitleColor(contentColor, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .vertical)
        bezelView.addSubview(button)

        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        topSpacer.isHidden = true
        bezelView.addSubview(topSpacer)

        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.isHidden = true
        bezelView.addSubview(bottomSpacer)
    }
    func updateIndicators() {
        let isActivityIndicator = indicator is UIActivityIndicatorView
        let isRoundIndicator = indicator is RoundProgressView
        if mode == .indeterminate {
            if !isActivityIndicator {
                indicator?.removeFromSuperview()
                let indicatorView = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
                indicatorView.startAnimating()
                indicator = indicatorView
                bezelView.addSubview(indicatorView)
            }
        } else if mode == .determinateHorizontalBar {
            indicator?.removeFromSuperview()
            indicator = BarProgressView()
            (indicator as? BarProgressView)?.progress = progress
            bezelView.addSubview(indicator!)
        } else if mode == .determinate || mode == .annularDeterminate {
            if !isRoundIndicator {

                indicator?.removeFromSuperview()
                indicator = RoundProgressView()
                bezelView.addSubview(indicator!)
            }
            (indicator as? RoundProgressView)?.progress = progress
            if mode == .annularDeterminate {
                (indicator as? RoundProgressView)?.isAnnular = true
            }
        } else if mode == .customView && customView != nil && customView != indicator {
            indicator?.removeFromSuperview()
            indicator = customView
            bezelView.addSubview(indicator!)
        } else if mode == .text {
            indicator?.removeFromSuperview()
            indicator = nil
        }
        indicator?.translatesAutoresizingMaskIntoConstraints = false

        indicator?.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .horizontal)
        indicator?.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 998.0), for: .vertical)
        updateViews(color: contentColor)
        setNeedsUpdateConstraints()
    }
    func updateViews(color: UIColor?) {
        guard let useColor = color else {
            return
        }
        label.textColor = useColor
        detailsLabel.textColor = useColor
        button.setTitleColor(useColor, for: .normal)

        if indicator is UIActivityIndicatorView {
            var appearance:UIActivityIndicatorView? = nil

            if #available(iOS 9.0, *) {
                appearance = UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [ProgressHUD.self])
            } else {
                appearance = UIActivityIndicatorView.appearance(for: self.traitCollection)
            }
            if appearance?.color == nil {
                (indicator as? UIActivityIndicatorView)?.color = useColor
            }
        } else if indicator is RoundProgressView {
            (indicator as? RoundProgressView)?.progressTintColor = useColor
            (indicator as? RoundProgressView)?.backgroundTintColor = useColor.withAlphaComponent(0.1)
        }  else if indicator is BarProgressView {

            (indicator as? BarProgressView)?.progressColor = useColor
            (indicator as? BarProgressView)?.lineColor = useColor.withAlphaComponent(0.1)
        } else {
            indicator?.tintColor = useColor
        }
    }
    func updateBezelMotionEffects() {
        if !bezelView.responds(to: #selector(bezelView.addMotionEffect(_:))) {
            return
        }
        if areDefaultMotionEffectsEnabled {
            let effectX = UIInterpolatingMotionEffect.init(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
            effectX.maximumRelativeValue = 10
            effectX.minimumRelativeValue = -10
            let effectY = UIInterpolatingMotionEffect.init(keyPath: "center.y", type: .tiltAlongVerticalAxis)
            effectY.maximumRelativeValue = 10
            effectY.minimumRelativeValue = -10
            let group = UIMotionEffectGroup()
            group.motionEffects = [effectX, effectY]
            bezelView.addMotionEffect(group)
        } else {
            for effect in bezelView.motionEffects {
                bezelView.removeMotionEffect(effect)
            }
        }
    }
    public override func layoutSubviews() {
        if !needsUpdateConstraints() {
            updateConstraints()
        }
        super.layoutSubviews()
    }
    public override func updateConstraints() {

        var subView = [topSpacer, label, detailsLabel, button, bottomSpacer]
        if indicator != nil {
            subView.insert(indicator!, at: 1)
        }
        removeConstraints(constraints)
        topSpacer.removeConstraints(topSpacer.constraints)
        bottomSpacer.removeConstraints(bottomSpacer.constraints)
        if bezelConstraints.count > 0 {
            bezelView.removeConstraints(bezelConstraints)
            bezelConstraints.removeAll()
        }
        var centeringConstraints: Array<NSLayoutConstraint> = []
        centeringConstraints.append(NSLayoutConstraint.init(item: bezelView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: offset.x))
        centeringConstraints.append(NSLayoutConstraint.init(item: bezelView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: offset.y))

        apply(priority: UILayoutPriority(rawValue: 998.0), constraints: centeringConstraints)
        addConstraints(centeringConstraints)

        var sideConstraints: Array<NSLayoutConstraint> = NSLayoutConstraint.constraints(withVisualFormat: "|-(>=margin)-[bezel]-(>=margin)-|", options: NSLayoutFormatOptions.init(rawValue: 0), metrics: ["margin": self.margin], views: ["bezel" : bezelView])
        sideConstraints.hub_append(array: NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=margin)-[bezel]-(>=margin)-|", options: NSLayoutFormatOptions.init(rawValue: 0), metrics: ["margin": self.margin], views: ["bezel" : bezelView]))
        apply(priority: UILayoutPriority(rawValue: 999.0), constraints: sideConstraints)
        addConstraints(sideConstraints)

        if minSize != CGSize.zero {
            let minSizeConstraints = [NSLayoutConstraint.init(item: bezelView, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: minSize.width),
                                      NSLayoutConstraint.init(item: bezelView, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: minSize.height)]
            apply(priority: UILayoutPriority(rawValue: 997.0), constraints: minSizeConstraints)
            bezelConstraints.hub_append(array: minSizeConstraints)
        }
        if isSquare {
            let square = NSLayoutConstraint.init(item: bezelView, attribute: .height, relatedBy: .equal, toItem: bezelView, attribute: .width, multiplier: 1.0, constant: 0)
            square.priority = UILayoutPriority(rawValue: 997.0)
            bezelConstraints.append(square)
        }


        topSpacer.addConstraint(NSLayoutConstraint.init(item: topSpacer, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: margin))
        bottomSpacer.addConstraint(NSLayoutConstraint.init(item: bottomSpacer, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: margin))

        bezelConstraints.append(NSLayoutConstraint.init(item: topSpacer, attribute: .height, relatedBy: .equal, toItem: bottomSpacer, attribute: .height, multiplier: 1.0, constant: 0.0))

        for i in 0 ..< subView.count {
            bezelConstraints.append(NSLayoutConstraint.init(item: subView[i], attribute: .centerX, relatedBy: .equal, toItem: bezelView, attribute: .centerX, multiplier: 1.0, constant: 0.0))
            bezelConstraints.hub_append(array: NSLayoutConstraint.constraints(withVisualFormat: "|-(>=margin)-[view]-(>=margin)-|", options: NSLayoutFormatOptions.alignAllTop, metrics: ["margin": self.margin], views: ["view" : subView[i]]))

            if i == 0 {
                bezelConstraints.append(NSLayoutConstraint.init(item: subView[i], attribute: .top, relatedBy: .equal, toItem: bezelView, attribute: .top, multiplier: 1.0, constant: 0.0))
            } else if i == subView.count - 1 {
                bezelConstraints.append(NSLayoutConstraint.init(item: subView[i], attribute: .bottom, relatedBy: .equal, toItem: bezelView, attribute: .bottom, multiplier: 1.0, constant: 0.0))
            }
            if i > 0 {
                let padding = NSLayoutConstraint.init(item: subView[i], attribute: .top, relatedBy: .equal, toItem: subView[i - 1], attribute: .bottom, multiplier: 1.0, constant: 0.0)
                bezelConstraints.append(padding)
                paddingConstraints.append(padding)
            }
        }
        bezelView.addConstraints(bezelConstraints)
        updatePaddingConstraints()
        super.updateConstraints()
    }
    func updatePaddingConstraints() {
        var hasVisibleAncestors = false

        for padding in paddingConstraints {
            let firstView = padding.firstItem as? UIView
            let secondView = padding.secondItem as? UIView
            let firstVisible = firstView?.isHidden == false && !(firstView?.intrinsicContentSize == CGSize.zero)
            let secondVisible = secondView?.isHidden == false && !(secondView?.intrinsicContentSize == CGSize.zero)

            padding.constant = firstVisible && (secondVisible || hasVisibleAncestors) ? 4.0 : 0.0
            hasVisibleAncestors = (hasVisibleAncestors || secondVisible )
        }
    }

    func apply(priority: UILayoutPriority, constraints: Array<NSLayoutConstraint>) {
        for constraint in constraints {
            constraint.priority = priority
        }
    }

// MARK: - NSProgress
    func setNSProgressDisplayLink(enabled: Bool) {
        if enabled && progressObject != nil {
            if progressObjectDisplayLink == nil {
                progressObjectDisplayLink = CADisplayLink.init(target: self, selector: #selector(self.updateProgressFromProgressObject))
            }

        } else {
            progressObjectDisplayLink = nil
        }

    }
    @objc func updateProgressFromProgressObject() {
        progress = progressObject?.fractionCompleted ?? 0
    }

    func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.statusBarOrientationDidChange(noti:)), name: NSNotification.Name.UIApplicationDidChangeStatusBarOrientation, object: nil)
    }
    @objc func statusBarOrientationDidChange(noti: Notification) {
        if superview != nil {
            updateForCurrentOrientation(animated: true)
        }
    }


    func updateForCurrentOrientation(animated: Bool) {
        guard let superView = self.superview else { return }
        frame = superView.bounds
    }

    func commonInit() {
        isOpaque = false
        backgroundColor = UIColor.clear
        alpha = 0.0
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.allowsGroupOpacity = false
        setupViews()
        updateIndicators()
        registerForNotifications()
    }
}



public class RoundProgressView: UIView {
    public var progress: Double = 0.0 {
        didSet {
            if oldValue != progress {
                setNeedsDisplay()
            }
        }
    }
    public var progressTintColor: UIColor = UIColor.white {
        didSet {
            if oldValue != progressTintColor && !oldValue.isEqual(progressTintColor) {
                setNeedsDisplay()
            }
        }
    }
    public var backgroundTintColor: UIColor = UIColor.white {
        didSet {
            if oldValue != backgroundTintColor && !oldValue.isEqual(backgroundTintColor) {
                setNeedsDisplay()
            }
        }
    }

    public var isAnnular: Bool = false
    public override var intrinsicContentSize: CGSize {
        return CGSize.init(width: 37, height: 37)
    }

    convenience init() {
        self.init(frame: CGRect.init(x: 0, y: 0, width: 37.0, height: 37.0))
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        if isAnnular {
            let processBackgroundPath = UIBezierPath()
            processBackgroundPath.lineWidth = 2.0
            processBackgroundPath.lineCapStyle  = .butt
            let center = CGPoint.init(x: bounds.midX, y: bounds.midY)
            let radius = (bounds.width - 2) * 0.5
            let startAngle = CGFloat(Double.pi * -0.5)
            var endAngle = CGFloat(Double.pi * 2) + startAngle
            processBackgroundPath.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            backgroundTintColor.set()
            processBackgroundPath.stroke()

            let processPath = UIBezierPath()
            processPath.lineCapStyle = .square
            processPath.lineWidth = 2.0
            endAngle = CGFloat(Double.pi * 2 * progress) + startAngle
            processPath.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            progressTintColor.set()
            processPath.stroke()
        } else {
            let circleRect = bounds.insetBy(dx: 1, dy: 1)
            let center = CGPoint.init(x: bounds.midX, y: bounds.midY)
            progressTintColor.setStroke()
            backgroundTintColor.setFill()
            context?.setLineWidth(2.0)
            context?.strokeEllipse(in: circleRect)

            let startAngle = CGFloat(Double.pi * -0.5)
            let processPath = UIBezierPath()
            processPath.lineCapStyle = .butt
            processPath.lineWidth = 4.0
            let radius = bounds.width  * 0.5 - processPath.lineWidth * 0.5
            let endAngle = CGFloat(Double.pi * 2 * progress) + startAngle
            processPath.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            context?.setBlendMode(.copy)
            progressTintColor.set()
            processPath.stroke()
        }
    }

}

public class BarProgressView: UIView {
    public var progress: Double = 0.0 {
        didSet {
            if oldValue != progress {
                setNeedsDisplay()
            }
        }
    }

    public var lineColor: UIColor = UIColor.white
    public var progressRemainingColor: UIColor = UIColor.clear {
        didSet {
            if oldValue != progressRemainingColor && !oldValue.isEqual(progressRemainingColor) {
                setNeedsDisplay()
            }
        }
    }

    public var progressColor: UIColor = UIColor.white {
        didSet {
            if oldValue != progressColor && !oldValue.isEqual(progressColor) {
                setNeedsDisplay()
            }
        }
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize.init(width: 120.0, height: 10)
    }


    convenience init() {
        self.init(frame: CGRect.init(x: 0, y: 0, width: 120.0, height: 20.0))
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = UIColor.clear
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineWidth(2.0)
        context?.setStrokeColor(lineColor.cgColor)
        context?.setFillColor(progressRemainingColor.cgColor)

        var radius = rect.height * 0.5 - 2
        context?.move(to: CGPoint.init(x: 2, y: rect.height * 0.5))
        context?.addArc(tangent1End: CGPoint.init(x: 2, y: 2), tangent2End: CGPoint.init(x: radius + 2, y: 2), radius: radius)
        context?.addLine(to: CGPoint.init(x: rect.width - radius - 2, y: 2))
        context?.addArc(tangent1End: CGPoint.init(x: rect.width - 2, y: 2), tangent2End: CGPoint.init(x: rect.width - 2, y: rect.height * 0.5), radius: radius)
        context?.addArc(tangent1End: CGPoint.init(x: rect.width - 2, y: rect.height - 2), tangent2End: CGPoint.init(x: rect.width - radius - 2, y: rect.height - 2), radius: radius)
        context?.addLine(to: CGPoint.init(x: radius + 2, y: rect.height - 2))
        context?.addArc(tangent1End: CGPoint.init(x: 2, y: rect.height - 2), tangent2End: CGPoint.init(x:  2, y: rect.height * 0.5), radius: radius)
        context?.fillPath()

        context?.move(to: CGPoint.init(x: 2, y: rect.height * 0.5))
        context?.addArc(tangent1End: CGPoint.init(x: 2, y: 2), tangent2End: CGPoint.init(x: radius + 2, y: 2), radius: radius)
        context?.addLine(to: CGPoint.init(x: rect.width - radius - 2, y: 2))
        context?.addArc(tangent1End: CGPoint.init(x: rect.width - 2, y: 2), tangent2End: CGPoint.init(x: rect.width - 2, y: rect.height * 0.5), radius: radius)
        context?.addArc(tangent1End: CGPoint.init(x: rect.width - 2, y: rect.height - 2), tangent2End: CGPoint.init(x: rect.width - radius - 2, y: rect.height - 2), radius: radius)
        context?.addLine(to: CGPoint.init(x: radius + 2, y: rect.height - 2))
        context?.addArc(tangent1End: CGPoint.init(x: 2, y: rect.height - 2), tangent2End: CGPoint.init(x: 2, y: rect.height * 0.5), radius: radius)
        context?.strokePath()

        context?.setFillColor(progressColor.cgColor)
        radius = radius - 2
        let amount = CGFloat(progress) * rect.width
        if amount >= radius + 4 && amount <= (rect.width - radius - 4) {
            context?.move(to: CGPoint.init(x: 4, y: rect.height * 0.5))
            context?.addArc(tangent1End: CGPoint.init(x: 4, y: 4), tangent2End: CGPoint.init(x: radius + 4, y: 4), radius: radius)
            context?.addLine(to: CGPoint.init(x: amount, y: 4))
            context?.addLine(to: CGPoint.init(x: amount, y: radius + 4))

            context?.move(to: CGPoint.init(x: 4, y: rect.height * 0.5))
            context?.addArc(tangent1End: CGPoint.init(x: 4, y: rect.height - 4), tangent2End: CGPoint.init(x: radius + 4, y: rect.height - 4), radius: radius)

            context?.addLine(to: CGPoint.init(x: amount, y: rect.height - 4))
            context?.addLine(to: CGPoint.init(x: amount, y: radius + 4))
            context?.fillPath()
        } else if amount > radius + 4 {
            let x = amount - rect.width - radius - 4
            context?.move(to: CGPoint.init(x: 4, y: rect.height * 0.5))
            context?.addArc(tangent1End: CGPoint.init(x: 4, y: 4), tangent2End: CGPoint.init(x: radius + 4, y: 4), radius: radius)
            context?.addLine(to: CGPoint.init(x: rect.width - radius - 4, y: 4))
            var angle = -acos(x / radius)
            if __inline_isnand(Double(angle)) == 0 {
                angle = 0
            }
            context?.addArc(center: CGPoint.init(x: rect.width - radius - 4, y: rect.height * 0.5), radius: radius, startAngle: CGFloat(Double.pi), endAngle: angle, clockwise: false)
            context?.addLine(to: CGPoint.init(x: amount, y: rect.height * 0.5))

            context?.move(to: CGPoint.init(x: 4, y: rect.height * 0.5))
            context?.addArc(tangent1End: CGPoint.init(x: 4, y: rect.height - 4), tangent2End: CGPoint.init(x: radius + 4, y: rect.height - 4), radius: radius)
            context?.addLine(to: CGPoint.init(x: rect.width - radius - 4, y: rect.height - 4))

            angle = acos(x / radius)
            if __inline_isnand(Double(angle)) == 0 {
                angle = 0
            }
            context?.addArc(center: CGPoint.init(x: rect.width - radius - 4, y: rect.height * 0.5), radius: radius, startAngle: CGFloat(-Double.pi), endAngle: angle, clockwise: true)
            context?.addLine(to: CGPoint.init(x: amount, y: rect.height * 0.5))
            context?.fillPath()
        } else if amount < radius + 4 && amount > 0 {
            context?.move(to: CGPoint.init(x: 4, y: rect.height * 0.5))
            context?.addArc(tangent1End: CGPoint.init(x: 4, y: 4), tangent2End: CGPoint.init(x: radius + 4, y: 4), radius: radius)
            context?.addLine(to: CGPoint.init(x: radius + 4, y: rect.height * 0.5))
            context?.move(to: CGPoint.init(x: 4, y: rect.height * 0.5))
            context?.addArc(tangent1End: CGPoint.init(x: 4, y: rect.height - 4), tangent2End: CGPoint.init(x: radius + 4, y: rect.height - 4), radius: radius)
            context?.addLine(to: CGPoint.init(x: radius + 4, y: rect.height * 0.5))
            context?.fillPath()
        }
    }
}

public class BackgroundView: UIView {
    private var effectView: UIVisualEffectView?
    public var blurEffectStyle: UIBlurEffectStyle = .light

    public var color: UIColor = UIColor.init(white: 0.8, alpha: 0.6) {
        didSet {
            if oldValue != color && !oldValue.isEqual(color) {
                backgroundColor = color
            }
        }
    }

    public var style: ProgressHUDBackgroundStyle = .blur {
        didSet {
            if oldValue != style {
                updateForBackgroundStyle()
            }
        }
    }
    public override var intrinsicContentSize: CGSize {
        return CGSize.zero
    }

    convenience init() {
        self.init(frame: CGRect.zero)
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        updateForBackgroundStyle()
    }
    func updateForBackgroundStyle() {
        if style == .blur {
            backgroundColor = color
            let effect = UIBlurEffect.init(style: .light)
            effectView = UIVisualEffectView.init(effect: effect)
            addSubview(effectView!)
            effectView?.frame = bounds
            effectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            layer.allowsGroupOpacity = false

        } else {
            effectView?.removeFromSuperview()
            effectView = nil
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }



}
public class ProgressHUDRoundedButton: UIButton {
    public override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? titleColor(for: .selected) : UIColor.clear
        }
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderWidth = 1.0
    }
    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = CGFloat(Int(self.bounds.height * 0.5))
    }
    public override var intrinsicContentSize: CGSize {
        if Int(allControlEvents.rawValue) == 0 {
            return CGSize.zero
        }
        let size = super.intrinsicContentSize
        return CGSize.init(width: size.width + 20, height: size.height)
    }
    public override func setTitleColor(_ color: UIColor?, for state: UIControlState) {
        super.setTitleColor(color, for: state)
        let bool = isHighlighted
        self.isHighlighted = bool
        layer.borderColor = color?.cgColor
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension Array {
    mutating func hub_append(array: Array<Element>) {
        for element in array {
            self.append(element)
        }
    }

}









