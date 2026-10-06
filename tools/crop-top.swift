// 画像の上から指定の高さだけを切り出す(sips は切り出す位置を指定できないため)。
//   swift tools/crop-top.swift 入力.png 出力.png 高さ(px)
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 4, let height = Int(args[3]),
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil),
      let cropped = image.cropping(to: CGRect(x: 0, y: 0, width: image.width, height: min(height, image.height))),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { FileHandle.standardError.write("切り出せませんでした\n".data(using: .utf8)!); exit(1) }
CGImageDestinationAddImage(dest, cropped, nil)
exit(CGImageDestinationFinalize(dest) ? 0 : 1)
