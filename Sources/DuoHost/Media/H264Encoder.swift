import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import DuoCore

public final class H264Encoder {
    public var onOutput: ((EncodedVideoFrame) -> Void)?
    public var onDiscard:(()->Void)?
    private var session:VTCompressionSession?
    private var sentSPS:Data?
    private let width:Int,height:Int
    private let frameDuration: CMTime
    public init(width:Int,height:Int,bitRate:Int = 6_000_000,framesPerSecond:Int = 30) throws {
        guard VideoRasterLimits.contains(width: width, height: height) else { throw WireError.oversized }
        self.width=width;self.height=height
        frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, framesPerSecond)))
        let status=VTCompressionSessionCreate(allocator:nil,width:Int32(width),height:Int32(height),codecType:kCMVideoCodecType_H264,
            encoderSpecification:[kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder:true] as CFDictionary,
            imageBufferAttributes:nil,compressedDataAllocator:nil,outputCallback:{ ref,_,status,_,sample in
                guard let ref else{return}
                let encoder = Unmanaged<H264Encoder>.fromOpaque(ref).takeUnretainedValue()
                guard status==noErr, let sample else{encoder.onDiscard?();return}
                encoder.output(sample)
            },refcon:Unmanaged.passUnretained(self).toOpaque(),compressionSessionOut:&session)
        guard status==noErr,let session else{throw NSError(domain:"DuoEncoder",code:Int(status))}
        VTSessionSetProperty(session,key:kVTCompressionPropertyKey_RealTime,value:kCFBooleanTrue)
        VTSessionSetProperty(session,key:kVTCompressionPropertyKey_AllowFrameReordering,value:kCFBooleanFalse)
        VTSessionSetProperty(session,key:kVTCompressionPropertyKey_ProfileLevel,value:kVTProfileLevel_H264_Main_AutoLevel)
        VTSessionSetProperty(session,key:kVTCompressionPropertyKey_AverageBitRate,value:min(20_000_000,max(1_000_000,bitRate)) as CFNumber)
        VTSessionSetProperty(session,key:kVTCompressionPropertyKey_ExpectedFrameRate,value:framesPerSecond as CFNumber)
        VTSessionSetProperty(session,key:kVTCompressionPropertyKey_MaxKeyFrameInterval,value:framesPerSecond as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(session)
    }
    public func encode(_ buffer:CVPixelBuffer,time:CMTime){
        guard let session else{return}
        let result = VTCompressionSessionEncodeFrame(session,imageBuffer:buffer,presentationTimeStamp:time,duration:frameDuration,frameProperties:nil,sourceFrameRefcon:nil,infoFlagsOut:nil)
        if result != noErr { onDiscard?() }
    }
    public func finish(){if let session{VTCompressionSessionCompleteFrames(session,untilPresentationTimeStamp:.invalid)}}
    private func output(_ sample:CMSampleBuffer){
        var emitted = false
        defer { if !emitted { onDiscard?() } }
        guard let format=CMSampleBufferGetFormatDescription(sample),let block=CMSampleBufferGetDataBuffer(sample) else{return}
        var p:UnsafePointer<UInt8>?,length=0,count=0
        guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,parameterSetIndex:0,parameterSetPointerOut:&p,parameterSetSizeOut:&length,parameterSetCountOut:&count,nalUnitHeaderLengthOut:nil)==noErr,let p else{return}
        let sps=Data(bytes:p,count:length)
        var configuration: VideoConfiguration?
        if sentSPS != sps {
            var q:UnsafePointer<UInt8>?,n=0
            guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,parameterSetIndex:1,parameterSetPointerOut:&q,parameterSetSizeOut:&n,parameterSetCountOut:nil,nalUnitHeaderLengthOut:nil)==noErr,let q else{return}
            configuration = VideoConfiguration(width:width,height:height,sps:sps,pps:Data(bytes:q,count:n))
        }
        let n=CMBlockBufferGetDataLength(block);guard n>0 && n<PacketDecoder.maximumPayload else{return}
        var data=Data(count:n)
        let status=data.withUnsafeMutableBytes{CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:n,destination:$0.baseAddress!)}
        if status==noErr {
            emitted = true
            if configuration != nil { sentSPS = sps }
            onOutput?(EncodedVideoFrame(configuration: configuration, data: data, time: sample.presentationTimeStamp.seconds))
        }
    }
    deinit{if let session{VTCompressionSessionInvalidate(session)}}
}
