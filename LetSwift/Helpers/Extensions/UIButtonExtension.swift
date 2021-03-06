//
//  UIButtonExtension.swift
//  LetSwift
//
//  Created by Marcin Chojnacki on 30.04.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit

extension UIButton {
    private enum Constants {
        static let minimumHitArea = CGSize(width: 50, height: 50)
    }
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let widthToAdd = max(Constants.minimumHitArea.width - bounds.width, 0)
        let heightToAdd = max(Constants.minimumHitArea.height - bounds.height, 0)
        let largerFrame = bounds.insetBy(dx: -widthToAdd / 2, dy: -heightToAdd / 2)
        
        return largerFrame.contains(point) ? self : nil
    }

    func showSpinner(_ shouldShow: Bool) {
        if shouldShow {
            setImage(UIImage(), for: [])

            let spinner = SpinnerView()
            spinner.image = #imageLiteral(resourceName: "WhiteSpinner")
            
            imageView?.addSubview(spinner)
            imageView?.clipsToBounds = false
            spinner.frame.origin.x -= 15.0
        } else {
            setImage(nil, for: [])
            imageView?.subviews.forEach { ($0 as? SpinnerView)?.removeFromSuperview() }
        }
    }
}
