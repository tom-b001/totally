//
//  CaptureFeedback.swift
//  Totally
//
//  Haptic + audio feedback for a successful, confident capture. Kept behind
//  a protocol so the confident-capture branching logic in HomeView can be
//  unit tested without touching UIKit/AudioToolbox.
//

import AudioToolbox
import UIKit

/// Signals to the user that an item was auto-added to the basket.
protocol CaptureFeedbackPlaying {
    func playAutoAddFeedback()
}

/// Default implementation: a success haptic plus a short system sound.
struct CaptureFeedback: CaptureFeedbackPlaying {
    /// The system sound ID for the standard "Tock" click, used as a light
    /// confirmation beep. See AudioServices system sound IDs.
    private static let autoAddSoundID: SystemSoundID = 1103

    func playAutoAddFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(Self.autoAddSoundID)
    }
}
