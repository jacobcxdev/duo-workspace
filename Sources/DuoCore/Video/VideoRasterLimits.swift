public enum VideoRasterLimits {
    public static let maximumAxis = 3840
    public static let maximumPixels = 8_294_400

    public static func contains(width: Int, height: Int) -> Bool {
        (240...maximumAxis).contains(width) && (240...maximumAxis).contains(height)
            && max(width, height) >= 320 && width % 2 == 0 && height % 2 == 0
            && width * height <= maximumPixels
    }
}
