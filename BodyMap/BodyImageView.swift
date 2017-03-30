//
//  BodySystemImageView.swift
//  BodyMap
//
//  Created by Michael Miller on 3/29/17.
//  Copyright © 2017 Michael Miller. All rights reserved.
//

import UIKit

class BodyImageView: UIImageView {

    // View Style
    var system:BodySystem! {
        didSet {
            setStyle(system: system)
        }
    }
    
    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        style()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        style()
    }
    
    // MARK: Style
    private func style() {
        clipsToBounds = true
        contentMode = .center
    }
    
    // MARK: Superview layout
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
    
    // MARK: Sets the style
    private func setStyle(system: BodySystem) {
        
        // Get System
        backgroundColor = system.color
        image = system.icon
        
        // Tint the image
        image = image!.withRenderingMode(.alwaysTemplate)
        tintColor = UIColor.white
    }

}
