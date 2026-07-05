import AetherEngine

/// Figure-dash placeholder for an unavailable value.
private let statsPlaceholder = "\u{2012}"

func formatResolution(width: Int, height: Int) -> String {
    guard width > 0, height > 0 else { return statsPlaceholder }
    return "\(width) \u{00D7} \(height)"
}

func videoFormatLabel(_ format: VideoFormat) -> String {
    switch format {
    case .sdr: return "SDR"
    case .hdr10: return "HDR10"
    case .hdr10Plus: return "HDR10+"
    case .dolbyVision: return "Dolby Vision"
    case .hlg: return "HLG"
    @unknown default: return statsPlaceholder
    }
}

/// HDR label refined with the Dolby Vision profile number when present ("Dolby Vision P5").
func hdrLabel(_ format: VideoFormat, dvProfile: Int?) -> String {
    if format == .dolbyVision, let profile = dvProfile {
        return "Dolby Vision P\(profile)"
    }
    return videoFormatLabel(format)
}

func formatMbps(_ value: Double?) -> String {
    guard let value else { return statsPlaceholder }
    return String(format: "%.1f Mbps", value)
}

func formatFps(_ value: Double?) -> String {
    guard let value else { return statsPlaceholder }
    return String(format: "%.1f fps", value)
}

func formatDroppedFrames(_ value: Int?) -> String {
    guard let value else { return statsPlaceholder }
    return "\(value)"
}

func formatSeconds(_ value: Double?) -> String {
    guard let value else { return statsPlaceholder }
    return String(format: "%.1f s", value)
}

func formatMemoryMB(_ mb: Int) -> String {
    "\(mb) MB"
}

func formatBackend(_ backend: PlaybackBackend) -> String {
    switch backend {
    case .native: return "Native (AVPlayer)"
    case .software: return "Software"
    case .audio: return "Audio"
    case .aether: return "Aether"
    case .none: return statsPlaceholder
    @unknown default: return statsPlaceholder
    }
}
