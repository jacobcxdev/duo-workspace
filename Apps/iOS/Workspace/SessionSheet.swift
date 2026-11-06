import Foundation

struct SessionSheet: Identifiable, Equatable {
    enum Destination: Equatable { case session, files }
    let id = UUID()
    let destination: Destination
}
