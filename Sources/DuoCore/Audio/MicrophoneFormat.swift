public enum MicrophoneFormat {
    public static let sampleRate = 48_000.0
    public static let channelCount: UInt32 = 1
    public static let bitsPerSample = 16
    public static let maximumFrames = 4096
    public static let bytesPerFrame = Int(channelCount) * bitsPerSample / 8
    public static let maximumPacketBytes = maximumFrames * bytesPerFrame
}
