//
//  SineCurveView.swift
//  pavement
//
//  Created by Michael Hassin on 10/20/15.
//  Copyright © 2015 strangerware. All rights reserved.
//

import UIKit

class SineCurveView: UIView {

    var amplitude: Float
    
    init(frame: CGRect, amplitude: Float) {
        self.amplitude = amplitude
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        UIColor.whiteColor().setFill()
        UIRectFill(rect)
        let context = UIGraphicsGetCurrentContext();
        CGContextSetLineWidth(context, 1);
        CGContextSetLineJoin(context, CGLineJoin.Round);
        let width = Float(rect.size.width);
        for var x = Float(0.0); x < width; x += 0.5 {
            let y = (abs(amplitude - 1.0) * 11.1) * sinf(Float(2.0 * M_PI) * (x / width) * 5.0) + 30
            if x == 0 {
                CGContextMoveToPoint(context, CGFloat(x), CGFloat(y));
            }
            else {
                CGContextAddLineToPoint(context, CGFloat(x), CGFloat(y));
            }
        }
        CGContextStrokePath(context);
    }
}
