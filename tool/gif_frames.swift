// Takes a video of the iOS simulator (xcrun simctl io <device> recordVideo ...) and
// saves some of its frames as PNG files, to make a GIF for the README with
// tool/make_gif.py. Build with: swiftc -O tool/gif_frames.swift -o gif_frames
import AVFoundation
import AppKit

// Usage: frames <video.mp4> <outDir> <fps> <width> [startSeconds] [endSeconds]
let args = CommandLine.arguments
guard args.count >= 5 else { print("usage"); exit(1) }
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let outDir = args[2]
let fps = Double(args[3])!
let width = CGFloat(Double(args[4])!)
let duration = CMTimeGetSeconds(asset.duration)
let start = args.count > 5 ? Double(args[5])! : 0
let end = args.count > 6 ? min(Double(args[6])!, duration) : duration

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
if let track = asset.tracks(withMediaType: .video).first {
    let size = track.naturalSize
    generator.maximumSize = CGSize(width: width, height: width * size.height / size.width)
}
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

var t = start
var index = 0
while t < end {
    let time = CMTime(seconds: t, preferredTimescale: 600)
    if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: String(format: "%@/f_%04d.png", outDir, index)))
        }
    }
    index += 1
    t += 1.0 / fps
}
print("duration \(duration)s, frames \(index)")
