//
//  OpenClawWidgetLiveActivity.swift
//  OpenClawWidget
//
//  Created by openclaw on 2026/3/10.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OpenClawWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OpenClawWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OpenClawWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension OpenClawWidgetAttributes {
    fileprivate static var preview: OpenClawWidgetAttributes {
        OpenClawWidgetAttributes(name: "World")
    }
}

extension OpenClawWidgetAttributes.ContentState {
    fileprivate static var smiley: OpenClawWidgetAttributes.ContentState {
        OpenClawWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OpenClawWidgetAttributes.ContentState {
         OpenClawWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OpenClawWidgetAttributes.preview) {
   OpenClawWidgetLiveActivity()
} contentStates: {
    OpenClawWidgetAttributes.ContentState.smiley
    OpenClawWidgetAttributes.ContentState.starEyes
}
