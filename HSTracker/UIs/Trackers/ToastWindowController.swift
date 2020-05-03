//
//  ToastWindowController.swift
//  HSTracker
//
//  Created by Martin BONNIN on 03/05/2020.
//  Copyright © 2020 Benjamin Michotte. All rights reserved.
//

import Foundation

class ToastWindowController: OverWindowController {
    init() {
        let panel = NSPanel()
        panel.styleMask.insert(.borderless)
        super.init(window: panel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func windowWillLoad() {
        logger.debug("Martin: windowWillLoad")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        self.window!.backgroundColor = NSColor.init(red: 0x48/255.0, green: 0x7E/255.0, blue: 0xAA/255.0, alpha: 1)
    }
}
