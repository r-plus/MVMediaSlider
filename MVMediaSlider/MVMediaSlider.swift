/*
MVMediaSlider - Copyright (c) 2016 Andrea Bizzotto bizz84@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import UIKit

private extension NSDateComponentsFormatter {
    
    // http://stackoverflow.com/questions/4933075/nstimeinterval-to-hhmmss
    class func string(timeInterval timeInterval: NSTimeInterval, prefix: String = "", fallback: String = "0:00") -> String {
        
        let formatter = NSDateComponentsFormatter()
        formatter.zeroFormattingBehavior = .Pad
        formatter.allowedUnits = timeInterval >= 3600 ? [.Hour, .Minute, .Second] : [.Minute, .Second]
        let minusString = timeInterval >= 1.0 ? prefix : ""
        return minusString + (formatter.stringFromTimeInterval(timeInterval) ?? fallback)
    }
}

private extension UIView {
    
    func anchorToSuperview() {
        
        if let superview = self.superview {
            self.translatesAutoresizingMaskIntoConstraints = false
            
            superview.addConstraints([
                makeEqualityConstraint(attribute: .Left, toView: superview),
                makeEqualityConstraint(attribute: .Top, toView: superview),
                makeEqualityConstraint(attribute: .Right, toView: superview),
                makeEqualityConstraint(attribute: .Bottom, toView: superview)
            ])
        }
    }
    func makeEqualityConstraint(attribute attribute: NSLayoutAttribute, toView view: UIView) -> NSLayoutConstraint {

        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .Equal,
            toItem: view, attribute: attribute, multiplier: 1, constant: 0)
    }
}

@IBDesignable public class MVMediaSlider: UIControl {

    // MARK: IBOutlets
    @IBOutlet private var leftLabelHolder: UIView!
    @IBOutlet private var leftLabel: UILabel!

    @IBOutlet private var rightLabelHolder: UIView!
    @IBOutlet private var rightLabel: UILabel!
    
    @IBOutlet private var elapsedTimeView: UIView!
    @IBOutlet private var sliderView: UIView!
    
    @IBOutlet private var elapsedTimeViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var sliderWidthConstraint: NSLayoutConstraint!

    @IBOutlet private var topSeparatorView: UIView!
    @IBOutlet private var bottomSeparatorView: UIView!

    // MARK: UIControl touch handling variables
    private let DragCaptureDeltaX: CGFloat = 22
    
    public private(set) var draggingInProgress = false
    private var initialDragLocationX: CGFloat = 0
    private var initialSliderConstraintValue: CGFloat = 0

    // MARK: init
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        let bundle = NSBundle(forClass: MVMediaSlider.self)
            
        if let view = bundle.loadNibNamed("MVMediaSlider", owner: self, options: nil).first as? UIView {
            
            self.addSubview(view)
            
            view.anchorToSuperview()
        }

        setDefaultValues()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        setDefaultValues()
    }
    
    private func setDefaultValues() {
        
        elapsedViewColor = UIColor.grayColor()
        sliderColor = UIColor.darkGrayColor()
        elapsedTextColor = UIColor.whiteColor()
        remainingTextColor = UIColor.darkGrayColor()
        topSeparatorColor = UIColor.grayColor()
        bottomSeparatorColor = UIColor.grayColor()
    }

    // MARK: styling
    override public var backgroundColor: UIColor! {
        didSet {
            rightLabelHolder?.backgroundColor = self.backgroundColor
        }
    }
    @IBInspectable public var elapsedViewColor: UIColor? {
        get {
            return leftLabelHolder?.backgroundColor
        }
        set(newElapsedViewColor) {
            leftLabelHolder?.backgroundColor = newElapsedViewColor
            elapsedTimeView?.backgroundColor = newElapsedViewColor
            let _ = sliderView?.subviews.map { $0.backgroundColor = newElapsedViewColor }
        }
    }
    @IBInspectable public var sliderColor: UIColor? {
        get {
            return sliderView?.backgroundColor
        }
        set {
            sliderView?.backgroundColor = newValue
        }
    }
    @IBInspectable public var elapsedTextColor: UIColor? {
        get {
            return leftLabel?.textColor
        }
        set {
            leftLabel?.textColor = newValue ?? UIColor.grayColor()
        }
    }
    @IBInspectable public var remainingTextColor: UIColor? {
        get {
            return rightLabel?.textColor
        }
        set {
            rightLabel?.textColor = newValue ?? UIColor.darkGrayColor()
        }
    }
    
    @IBInspectable public var topSeparatorColor: UIColor? {
        get {
            return topSeparatorView?.backgroundColor
        }
        set {
            topSeparatorView?.backgroundColor = newValue
        }
    }
    @IBInspectable public var bottomSeparatorColor: UIColor? {
        get {
            return bottomSeparatorView?.backgroundColor
        }
        set {
            bottomSeparatorView?.backgroundColor = newValue
        }
    }
    
    public override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
    }
    
    // IBInspectable should support UIFont: http://www.openradar.me/22835760
    // @IBInspectable
    public var timersFont: UIFont! {
        didSet {
            leftLabel?.font = timersFont
            rightLabel?.font = timersFont
        }
    }
    
    // MARK: time management
    public var totalTime: NSTimeInterval? {
        didSet {
            updateView(currentTime: _currentTime, totalTime: _totalTime)
        }
    }
    public var currentTime: NSTimeInterval? {
        didSet {
            if !draggingInProgress {
                let currentTime = min(_currentTime, _totalTime)
                updateView(currentTime: currentTime, totalTime: _totalTime)
            }
        }
    }
    
    // MARK: internal methods
    private var _totalTime: NSTimeInterval {
        return totalTime ?? 0
    }
    
    private var _currentTime: NSTimeInterval {
        return currentTime ?? 0
    }
    
    private var availableSliderWidth: CGFloat {
        return self.frame.width - leftLabelHolder.frame.width - rightLabelHolder.frame.width - sliderView.frame.width
    }
    
    private func updateView(currentTime currentTime: NSTimeInterval, totalTime: NSTimeInterval) {
        
        let normalizedTime = totalTime > 0 ? currentTime / totalTime : 0
        elapsedTimeViewWidthConstraint?.constant = CGFloat(normalizedTime) * availableSliderWidth
        
        leftLabel?.text = NSDateComponentsFormatter.string(timeInterval: currentTime)
        
        let remainingTime = totalTime - currentTime
        rightLabel?.text = NSDateComponentsFormatter.string(timeInterval: remainingTime, prefix: "-")
    }

    // MARK: trait collection
    override public func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if draggingInProgress {
            cancelTrackingWithEvent(nil)
            draggingInProgress = false
        }
        updateView(currentTime: _currentTime, totalTime: _totalTime)
    }
}

extension MVMediaSlider {
    
    // MARK: UIControl subclassing
    override public func beginTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
        
        self.sendActionsForControlEvents(.TouchDown)

        let sliderCenterX = leftLabelHolder.frame.width + elapsedTimeViewWidthConstraint.constant + sliderView.bounds.width / 2
        
        let locationX = touch.locationInView(self).x
        
        let beginTracking = locationX > sliderCenterX - DragCaptureDeltaX && locationX < sliderCenterX + DragCaptureDeltaX
        if beginTracking {
            initialDragLocationX = locationX
            initialSliderConstraintValue = elapsedTimeViewWidthConstraint.constant
        }
        return beginTracking
    }
    
    override public func continueTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
        
        if !draggingInProgress {
            draggingInProgress = true
        }
        
        let newValue = sliderValue(touch)
        
        let seekTime = NSTimeInterval(newValue / availableSliderWidth) * _totalTime
        
        updateView(currentTime: seekTime, totalTime: _totalTime)
        
        return true
    }

    override public func endTrackingWithTouch(touch: UITouch?, withEvent event: UIEvent?) {
        
        self.sendActionsForControlEvents(.TouchUpInside)

        draggingInProgress = false

        guard let touch = touch else {
            updateView(currentTime: _currentTime, totalTime: _totalTime)
            return
        }
        
        let newValue = sliderValue(touch)
        
        currentTime = NSTimeInterval(newValue / availableSliderWidth) * _totalTime
        
        self.sendActionsForControlEvents(.ValueChanged)
    }
    
    private func sliderValue(touch: UITouch) -> CGFloat {
        
        let locationX = touch.locationInView(self).x
        
        let deltaX = locationX - initialDragLocationX
        
        let adjustedSliderValue = initialSliderConstraintValue + deltaX
        
        return max(0, min(adjustedSliderValue, availableSliderWidth))
    }
    
}
