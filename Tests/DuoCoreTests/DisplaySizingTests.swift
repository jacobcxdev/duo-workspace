import Foundation
import Testing
@testable import DuoCore

struct DisplaySizingTests {
    private let simulator = NativeDisplayInfo(pixels: DisplayPixelSize(width: 2007, height: 2853),
        pointWidth: 669, pointHeight: 951, nativeScale: 3)

    @Test func fullScreenUsesNativePixelsInsteadOfAssumingThreeTimesPoints() {
        let hardware = NativeDisplayInfo(pixels: DisplayPixelSize(width: 1878, height: 2670),
            pointWidth: 669, pointHeight: 951, nativeScale: 2670.0 / 951)
        #expect(hardware.pixels(viewportWidth: 951, viewportHeight: 669) == DisplayPixelSize(width: 2670, height: 1878))
        #expect(hardware.pixels(viewportWidth: 669, viewportHeight: 455) == DisplayPixelSize(width: 1878, height: 1277))
        #expect(hardware.pixels(viewportWidth: .nan, viewportHeight: 669) == nil)
    }

    @Test func automaticMatchMeasuresTheMediaPaneInsteadOfTheWholePanel() {
        let full = DesktopSizing.matchDisplay.desktop(shape: .automatic, viewportWidth: 669, viewportHeight: 951, display: simulator)
        let pane = DesktopSizing.matchDisplay.desktop(shape: .automatic, viewportWidth: 669, viewportHeight: 455, display: simulator)
        #expect(full == DesktopSize(width: 1002, height: 1426))
        #expect(pane == DesktopSize(width: 1002, height: 682))
    }

    @Test func fixedMatchKeepsItsSnapshotUntilExplicitlyUpdated() {
        let cover = NativeDisplayInfo(pixels: DisplayPixelSize(width: 1398, height: 2034), pointWidth: 466, pointHeight: 678, nativeScale: 3)
        for (width, height) in [(951.0, 669.0), (669, 951), (466, 678), (678, 466)] {
            #expect(DesktopSizing.matchDisplay.desktop(shape: .landscape16x9, viewportWidth: width, viewportHeight: height,
                display: cover, matchedDisplay: simulator.pixels) == DesktopSize(width: 1426, height: 802))
        }
        #expect(DesktopSizing.matchDisplay.desktop(shape: .landscape16x9, viewportWidth: 466, viewportHeight: 678,
            display: cover, matchedDisplay: cover.pixels) == DesktopSize(width: 1016, height: 572))
    }

    @Test func workspaceOptionsPreserveBoundsAndShape() throws {
        for shape in DesktopShape.allCases {
            for sizing in DesktopSizing.allCases {
                let desktop = try #require(sizing.desktop(shape: shape, viewportWidth: 951, viewportHeight: 669,
                    display: simulator, matchedDisplay: simulator.pixels))
                #expect(desktop.isValid)
                let ratio = shape.aspectRatio ?? 951.0 / 669
                #expect(abs(Double(desktop.width) / Double(desktop.height) - ratio) < 0.015)
            }
        }
        #expect(DesktopSizing.moreSpace.desktop(shape: .landscape16x9, viewportWidth: 466, viewportHeight: 678)
                == DesktopSize(width: 1440, height: 810))
        #expect(DesktopSizing.moreSpace.desktop(shape: .automatic, viewportWidth: 669, viewportHeight: 455.6667)
                == DesktopSize(width: 1200, height: 816))
    }

    @Test func maximumDetailSendsSourcePixelsWithoutUpscaling() {
        let portrait = StreamDimensions.forDesktop(DesktopSize(width: 1002, height: 1426), quality: .maximum)
        #expect(portrait.width == 2004 && portrait.height == 2852)
        let small = StreamDimensions.forSource(width: 640, height: 480, quality: .maximum)
        #expect(small.width == 640 && small.height == 480)
        let large = StreamDimensions.forSource(width: 7680, height: 4320, quality: .maximum)
        #expect(large.width * large.height <= 6_000_000)
        #expect(VideoRasterLimits.contains(width: large.width, height: large.height))
    }

    @Test(arguments: StreamQuality.allCases)
    func capturePreservesMacAspectAtEveryQuality(_ quality: StreamQuality) {
        let size = StreamDimensions.forSource(width: 3024, height: 1964, quality: quality)
        #expect(abs(Double(size.width) / Double(size.height) - 3024.0 / 1964.0) < 0.004)
        #expect(size.width * size.height <= quality.width * quality.height)
        #expect(size.width <= 3024 && size.height <= 1964)
        #expect(VideoRasterLimits.contains(width: size.width, height: size.height))
    }

    @Test func rasterLimitsAreSymmetricAndBoundDecodedMemory() {
        #expect(VideoRasterLimits.contains(width: 2004, height: 2852))
        #expect(VideoRasterLimits.contains(width: 2852, height: 2004))
        #expect(VideoRasterLimits.contains(width: 3840, height: 2160))
        #expect(VideoRasterLimits.contains(width: 2160, height: 3840))
        #expect(!VideoRasterLimits.contains(width: 3840, height: 3840))
        #expect(!VideoRasterLimits.contains(width: Int.max, height: Int.max))
        #expect(!VideoRasterLimits.contains(width: 2005, height: 2852))
    }
}
