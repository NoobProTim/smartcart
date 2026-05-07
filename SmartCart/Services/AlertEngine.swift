// AlertEngine.swift
import Foundation

final class AlertEngine {
    // 3-type alert system:
    // Type A: Historical Low (90-day rolling avg, 15% threshold)
    // Type B: Sale Alert (active flyer sale)
    // Type C: Flyer Expiry Reminder
    // A+B merge → Combined; priority sort; 3/day cap
}
