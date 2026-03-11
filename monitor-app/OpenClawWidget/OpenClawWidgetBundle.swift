//
//  OpenClawWidgetBundle.swift
//  OpenClawWidget
//
//  Created by openclaw on 2026/3/10.
//

import WidgetKit
import SwiftUI

@main
struct OpenClawWidgetBundle: WidgetBundle {
    var body: some Widget {
        OpenClawWidget()
        OpenClawWidgetControl()
        OpenClawWidgetLiveActivity()
    }
}
