import SwiftUI

extension View {
    /// Enables text selection where supported (iOS). No-op on Android, where
    /// Skip does not yet implement `textSelection`.
    func selectableText() -> some View {
        #if !SKIP
        return self.textSelection(.enabled)
        #else
        return self
        #endif
    }
}
