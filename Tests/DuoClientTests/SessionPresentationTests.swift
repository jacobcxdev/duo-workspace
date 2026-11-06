import Foundation
import Testing
@testable import DuoWorkspace

@MainActor
struct SessionPresentationTests {
    @Test func repeatedDismissAndReopenWaitsForThePriorPresentation() throws {
        let presentation = SessionPresentation()
        for _ in 0..<2 {
            presentation.showSession()
            let current = try #require(presentation.sheet)
            presentation.showSession()
            #expect(presentation.sheet?.id == current.id)
            presentation.dismiss()
            #expect(presentation.isDismissing)
            presentation.showSession()
            #expect(presentation.sheet == nil)
            #expect(presentation.didDismiss() == .none)
            let reopened = try #require(presentation.sheet)
            #expect(reopened.destination == .session)
            #expect(reopened.id != current.id)
            presentation.dismiss()
            #expect(presentation.didDismiss() == .none)
            #expect(presentation.sheet == nil && !presentation.isDismissing)
        }
    }

    @Test func offerDuringDismissalWaitsUntilTheSheetHasGone() throws {
        let presentation = SessionPresentation()
        presentation.showSession()
        let first = try #require(presentation.sheet?.id)
        presentation.dismiss()
        presentation.fileOfferChanged(available: true)
        #expect(presentation.sheet == nil && presentation.isDismissing)
        #expect(presentation.didDismiss() == .none)
        #expect(presentation.sheet?.destination == .files)
        #expect(presentation.sheet?.id != first)
    }

    @Test func offerCannotReplaceAnOpenSessionOrReappearAfterCancellation() throws {
        let presentation = SessionPresentation()
        presentation.showSession()
        let original = presentation.sheet?.id
        presentation.fileOfferChanged(available: true)
        #expect(presentation.sheet?.destination == .session && presentation.sheet?.id == original)
        presentation.dismiss()
        presentation.fileOfferChanged(available: true)
        presentation.fileOfferChanged(available: false)
        #expect(presentation.didDismiss() == .none)
        #expect(presentation.sheet == nil)
    }

    @Test func explicitSessionReopenTakesPriorityOverQueuedFilePanel() {
        let presentation = SessionPresentation()
        presentation.showSession(); presentation.dismiss()
        presentation.fileOfferChanged(available: true)
        presentation.showSession()
        #expect(presentation.didDismiss() == .none)
        #expect(presentation.sheet?.destination == .session)
    }

    @Test func macPickerStartsOnceAfterDismissalAndThenOffersCanOpenFiles() {
        let presentation = SessionPresentation()
        presentation.showSession()
        presentation.chooseFileOnMac()
        #expect(presentation.sheet == nil && presentation.isDismissing)
        presentation.chooseFileOnMac()
        #expect(presentation.didDismiss() == .chooseFileOnMac)
        #expect(presentation.didDismiss() == .none)
        presentation.fileOfferChanged(available: true)
        #expect(presentation.sheet?.destination == .files)
    }

    @Test func closingTheSessionCancelsDeferredPickerAndPanelRequests() {
        let presentation = SessionPresentation()
        presentation.showSession(); presentation.chooseFileOnMac()
        presentation.reset()
        #expect(presentation.didDismiss() == .none)
        #expect(presentation.sheet == nil)
        presentation.showSession(); presentation.dismiss()
        presentation.fileOfferChanged(available: true)
        presentation.reset()
        #expect(presentation.didDismiss() == .none)
        #expect(presentation.sheet == nil)
    }

    @Test func dismissalReconcilesAStalePresentationBinding() throws {
        let presentation = SessionPresentation()
        presentation.showSession()
        let original = try #require(presentation.sheet?.id)
        #expect(presentation.didDismiss() == .none)
        #expect(presentation.sheet == nil && !presentation.isDismissing)
        presentation.showSession()
        #expect(presentation.sheet?.id != original)
    }

    @Test func disconnectedFileSelectionReportsFailureInsteadOfSilentlyClosing() {
        let files = SessionFiles()
        #expect(!files.chooseOnMac())
        #expect(!files.choosingOnMac)
        #expect(files.message != nil)
    }
}
