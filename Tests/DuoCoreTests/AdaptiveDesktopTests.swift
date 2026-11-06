import Foundation
import Testing
@testable import DuoCore

struct AdaptiveDesktopTests {
    @Test func viewportShapesStayBoundedAndKeepTheirAspect() throws {
        for (w,h) in [(951.0,635.0),(669,917),(669,455),(466,644),(3200,1800)] {
            let desktop = try #require(DesktopSize.viewport(width: w, height: h))
            #expect(desktop.isValid)
            #expect(abs(Double(desktop.width) / Double(desktop.height) - w / h) < 0.015)
            for quality in StreamQuality.allCases {
                let stream = StreamDimensions.forDesktop(desktop, quality: quality)
                #expect(stream.width % 2 == 0 && stream.height % 2 == 0)
                #expect(stream.width * stream.height <= quality.width * quality.height)
                #expect(stream.width <= 3840 && stream.height <= 3840)
                #expect(abs(Double(stream.width) / Double(stream.height) - w / h) < 0.015)
            }
        }
    }

    @Test func smallPanesKeepTheirShapeAboveTheMacTwoXModeFloor() throws {
        for (width, height) in [(669.0, 455.6667), (466, 644), (951, 280), (500, 500)] {
            let desktop = try #require(DesktopSize.viewport(width: width, height: height))
            #expect(min(desktop.width, desktop.height) >= 526)
            #expect(max(desktop.width, desktop.height) >= 800)
            #expect(desktop.scale == 2)
            #expect(abs(Double(desktop.width) / Double(desktop.height) - width / height) < 0.015)
        }
    }

    @Test func invalidGeometryCannotAllocateAnUnboundedDisplay() {
        for (w,h) in [(Double.nan,600.0),(.infinity,600),(0,500),(500,0),(1e100,1),(80,1e10)] {
            #expect(DesktopSize.viewport(width: w, height: h) == nil)
        }
        #expect(!DesktopSize(width: Int.max, height: Int.max).isValid)
        #expect(!DesktopResizeRequest(revision: 0, desktop: DesktopSize(width: 900, height: 650)).isValid)
    }

    @Test func fixedDesktopShapesKeepTheirRatioAcrossDifferentPanes() throws {
        for shape in DesktopShape.allCases {
            let initial = try #require(shape.desktop(viewportWidth: 951, viewportHeight: 669))
            for (width, height) in [(951.0, 669.0), (669, 951), (669, 400), (466, 678), (80, 80), (3200, 1800)] {
                let desktop = try #require(shape.desktop(viewportWidth: width, viewportHeight: height))
                let expected = shape.aspectRatio ?? width / height
                if shape != .automatic { #expect(desktop == initial) }
                #expect(desktop.isValid)
                #expect(min(desktop.width, desktop.height) >= 526)
                #expect(max(desktop.width, desktop.height) >= 800)
                #expect(abs(Double(desktop.width) / Double(desktop.height) - expected) < 0.015)
                for quality in StreamQuality.allCases {
                    let stream = StreamDimensions.forDesktop(desktop, quality: quality)
                    #expect(stream.width * stream.height <= quality.width * quality.height)
                    #expect(abs(Double(stream.width) / Double(stream.height) - expected) < 0.015)
                }
            }
        }
    }

    @Test func fixedShapesWaitForValidViewportGeometry() {
        for shape in DesktopShape.allCases {
            for (width, height) in [(0.0, 669.0), (951, 0), (Double.nan, 669), (951, Double.infinity)] {
                #expect(shape.desktop(viewportWidth: width, viewportHeight: height) == nil)
            }
        }
    }

    @Test func adaptiveHelloCannotChangeAPhysicalDisplayOrExceedQualityBudget() {
        let desktop = DesktopSize(width: 900, height: 650)
        let stream = StreamDimensions.forDesktop(desktop, quality: .balanced)
        #expect(ClientHello(mode: .extend, width: stream.width, height: stream.height, quality: .balanced, desktop: desktop).isValid)
        #expect(!ClientHello(mode: .control, width: stream.width, height: stream.height, quality: .balanced, desktop: desktop).isValid)
        #expect(!ClientHello(mode: .extend, width: 3840, height: 3840, quality: .balanced, desktop: desktop).isValid)
        #expect(ClientHello(mode: .extend, width: 1600, height: 1000, quality: .balanced).isValid)
    }

    @Test func legacyApprovalDoesNotClaimResizeSupport() throws {
        let result = try JSONDecoder().decode(AuthorizationResult.self, from: Data(#"{"state":"approved","message":"Approved"}"#.utf8))
        #expect(result.supportsAdaptiveDisplay == nil)
    }
}
