import SwiftUI
import DuoCore

struct FileTransferFailureText: View {
    let failure: FileTransferError
    var body: some View {
        switch failure {
        case .invalidFile: Text("Choose a regular file with a shorter name. Folders and links aren't supported.")
        case .tooLarge: Text("Choose a file that's 2 GB or smaller.")
        case .changed: Text("The file changed while sending. Try again after saving it.")
        case .cancelled: Text("Transfer cancelled.")
        case .busy: Text("Another transfer is running. Wait for it to finish.")
        case .timedOut: Text("The transfer timed out. Try again.")
        case .integrity: Text("The file didn't match the sender's copy. Try again.")
        case .storage: Text("Couldn't read or save the file. Check access and available space.")
        case .protocolViolation, .unavailable: Text("The transfer failed. Reconnect and try again.")
        }
    }
}
