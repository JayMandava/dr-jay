import WidgetKit
import SwiftUI

@main
struct RoastieWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RoastieHomeWidget()
        AddHourSleepWidget()
        LogBottleWidget()
        RoastieLiveActivity()
    }
}
