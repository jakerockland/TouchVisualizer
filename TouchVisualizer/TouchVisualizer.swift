//
//  TouchVisualizer.swift
//  TouchVisualizer
//
//  Created by Alexis Gallagher on 2015-10-19.
//  Copyright © 2015 Alexis Gallagher. All rights reserved.
//

//
//  TouchDisplayingWindow.swift
//  TouchRecorderSpike
//
//  Created by Alexis Gallagher on 2015-10-09.
//  Copyright © 2015 Alexis Gallagher. All rights reserved.
//

import UIKit

/**
Like UIWindow, but displays an overlay view displaying active touches with force annotations.

@discussion

You can add this to an existing app for debugging purposes, or merely to dazzle and frighten.

There are two steps to using this: (1) configure your app to use this instead of UIWindow and (2) ensure to deactive it on devices that do not offer force properties API

To use this instead of UIWindow, override your app delegate's `window:UIWindow?` property with a computed property, where the setter's a no-op, and the getter returns a constant reference to an instance of this class.

To de-activate on non-force devices, set `forceActive=false`. Accessing force information on devices without force capability is "undefined" so this precuation is pedantically needed for defined behavior.

This class should not affect normal touch delivery at all.

This class tries to keep its own overlay subview in front but it does not take heroic measures to do so. So I'm not sure if this works in complex cases. It might fail if user code or system code does not anticipate another component modifying the existence or order of the key window's subviews.

KNOWN GOOD: iPhone 5 (iOS 9.0.2), iPhone 6 (iOS 9.0), Xcode 7.0.1

*/
class TouchDisplayingWindow: UIWindow
{
  // if the view should do anything (rather than behave like UIWindow)
  var active:Bool = true { didSet { overlayView.hidden = !active } }

  // if the view should display force information
  var forceActive:Bool  {
    get { return overlayView.shouldDisplayForce }
    set { overlayView.shouldDisplayForce = newValue }
  }

  private let overlayView = OverlayGraphicView(frame: CGRectZero)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  override func didAddSubview(subview: UIView) {
    super.didAddSubview(subview)
    self.bringSubviewToFront(overlayView)
  }
  
  private func setup() {
    overlayView.autoresizingMask = [.FlexibleWidth,.FlexibleHeight]
    overlayView.frame = self.bounds
    self.addSubview(overlayView)
  }
  
  override func sendEvent(event: UIEvent)
  {
    if self.active && event.type == .Touches {
      if let touches = event.touchesForWindow(self) {
        let activeTouches = touches.filter({[UITouchPhase.Began,.Stationary,.Moved].contains($0.phase)})
        overlayView.activeTouches = Set(activeTouches)
      }
      else {
        overlayView.activeTouches = Set()
      }
    }
    
    // forward events for processing as usual
    super.sendEvent(event)
  }
  
  override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
    let forceCapable = self.traitCollection.forceTouchCapability == .Available
    NSLog("window.forceCapable=\(forceCapable)")
  }

}

// view displaying info on active touches
private class OverlayGraphicView : UIView
{
  var shouldDisplayForce:Bool = true
  var shouldDisplayRadius:Bool = true
  var shouldDisplayRadiusError:Bool = true
  var shouldDisplayLegends:Bool = true
  
  var activeTouches:Set<UITouch> = Set() {
    didSet {
      setNeedsDisplay()
    }
  }
  
  let forceOverlayColor = UIColor.orangeColor()
  let radiusOverlayColor = UIColor.whiteColor()
  let radiusErrorColor = UIColor.lightGrayColor()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  private func setup() {
    backgroundColor = .clearColor()
    userInteractionEnabled = false
  }
  
  override func drawRect(rect: CGRect)
  {
    // draw force bubble
    let minimumRadius:CGFloat = 50
    let maximumRadius:CGFloat = 175
    
    for touch:UITouch in activeTouches {
      let centerPoint = touch.locationInView(self)
      let rawForce:Float = shouldDisplayForce ? Float(touch.force) : 0
      let fractionalForce:CGFloat = shouldDisplayForce ? (touch.force / touch.maximumPossibleForce)  : 0
      
      let majorRadius = touch.majorRadius
      let majorRadiusTolerance = touch.majorRadiusTolerance
      
      forceOverlayColor.setStroke()
      forceOverlayColor.colorWithAlphaComponent(0.2).setFill()
      let radius:CGFloat = fractionalForce * (maximumRadius - minimumRadius) + minimumRadius
      let circlePath = UIBezierPath(arcCenter: centerPoint, radius: radius, startAngle: CGFloat(0), endAngle: CGFloat(M_PI * 2.0), clockwise: true)
      circlePath.lineWidth = CGFloat(2)
      circlePath.stroke()
      circlePath.fill()
      
      if shouldDisplayRadius {
        radiusOverlayColor.setStroke()
        radiusOverlayColor.colorWithAlphaComponent(0.2).setFill()
        let circlePath = UIBezierPath(arcCenter: centerPoint, radius: majorRadius, startAngle: CGFloat(0), endAngle: CGFloat(M_PI * 2.0), clockwise: true)
        circlePath.lineWidth = CGFloat(2)
        circlePath.stroke()
        circlePath.fill()
      }
      
      if shouldDisplayRadiusError {
        let fingerRadiusPlusError = majorRadius + majorRadiusTolerance
        let fingerRadiusMinusError = majorRadius - majorRadiusTolerance
        radiusErrorColor.colorWithAlphaComponent(0.2).setFill()
        let outerFingerCirclePath = UIBezierPath(arcCenter: centerPoint, radius: fingerRadiusPlusError, startAngle: CGFloat(0), endAngle: CGFloat(M_PI * 2.0), clockwise: true)
        let innerFingerCirclePath = UIBezierPath(arcCenter: centerPoint, radius: fingerRadiusMinusError, startAngle: CGFloat(0), endAngle: CGFloat(M_PI * 2.0), clockwise: false)
        outerFingerCirclePath.appendPath(innerFingerCirclePath)
        outerFingerCirclePath.usesEvenOddFillRule = false
        outerFingerCirclePath.fill()
      }
      
      // labels
      
      if shouldDisplayForce && shouldDisplayLegends {
        // draw force string
        let textOrigin = CGPoint(x: centerPoint.x + 40, y: centerPoint.y - 70)
        let percentString = String(format:"f: %4.3f\u{2007}%2.0f%%",rawForce,Float(fractionalForce * 100))
        let textAttributes2 = numericalTextAttributesWithSize(16, color: forceOverlayColor)
        (percentString as NSString).drawAtPoint(textOrigin, withAttributes: textAttributes2)
      }
      
      if shouldDisplayRadius && shouldDisplayLegends {
        // draw force string
        let textOrigin = CGPoint(x: centerPoint.x + 40, y: centerPoint.y + 70)
        let percentString = String(format:"r: %2.1f",Float(majorRadius))
        let textAttributes = numericalTextAttributesWithSize(16, color: radiusOverlayColor)
        (percentString as NSString).drawAtPoint(textOrigin, withAttributes: textAttributes)
      }
    }
  }

  override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
    let forceCapable = self.traitCollection.forceTouchCapability == .Available
    NSLog("overlayview.forceCapable=\(forceCapable)")
  }

}

private func numericalTextAttributesWithSize(size:CGFloat,color:UIColor) -> [String:AnyObject] {
  let attributes = [
    NSFontAttributeName:UIFont.monospacedDigitSystemFontOfSize(size, weight: UIFontWeightMedium),
    NSForegroundColorAttributeName:color,
  ]
  return attributes
}

