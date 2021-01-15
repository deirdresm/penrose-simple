//
//  main.swift
//  penrose
//
//  Created by Deirdre Saoirse Moen on 1/13/21.
//

import Foundation
import CoreImage
import AppKit

enum TileShape: Int {
    case kite = 0, dart // first and second colors
    
    func next() -> TileShape { // fake Go's iota
        switch self {
        case .kite:
            return .dart
        case .dart:
            return .kite
        }
    }
}

extension Array where Element : Equatable {
    var distinct: [Element] {
        var uniqueValues: [Element] = []
        forEach { item in
            if !uniqueValues.contains(item) {
                uniqueValues.append(item)
            }
        }
        return uniqueValues
    }
}

struct Tile: Hashable {
    var tt:     TileShape // stores the int value of the tile shape
    var x:      Double
    var y:      Double
    var angle:  Double
    var size:   Double
    
    public static func < (lhs: Tile, rhs: Tile) -> Bool {
        return ((lhs.tt == rhs.tt) && (lhs.x == rhs.x) && (lhs.y == rhs.y) &&
                    (lhs.angle == rhs.angle) && (lhs.size == rhs.size))
    }

}

let goldenRatio = Double((1 + sqrt(5)) / 2.0) // golden ratio
let theta = Double.pi / 5.0          // 36 degrees in radians

// create tiles around the origin
func initialTiles(_ w: Int, _ h: Int) -> [Tile] {
    var initial = [Tile]()

    
    for a in stride(from: Double.pi / 2.0 + theta, to: 3.0 * Double.pi, by: 2.0 * theta) {
        let tile = Tile(tt: .kite, x: Double(w) / 2.0 , y: Double(h) / 2.0, angle: a, size: Double(w) / 2.5)
        initial.append(tile)
    }
    return initial
}

func deflateTiles(_ tiles: [Tile], _ gen: Int) -> [Tile] {
    if gen <= 0 {
        return tiles
    }
    var nextTiles = [Tile]()
    
    for tile in tiles {
        var nx: Double
        var ny: Double
        let size: Double = tile.size / goldenRatio
        let a = tile.angle
        
        if tile.tt == .dart {
            nextTiles.append(Tile(tt: TileShape.kite, x: tile.x, y: tile.y,
                                  angle: a + 5.0 * theta, size: size))
            var sign: Double = 1.0
            for _ in 0 ..< 2 {
                let nangle = a - 4.0 * theta * sign
                nx = tile.x + cos(nangle) * goldenRatio * tile.size
                ny = tile.y - sin(nangle) * goldenRatio * tile.size
                nextTiles.append(Tile(tt: TileShape.dart, x: nx, y: ny, angle: nangle, size: size))
                sign = sign * -1.0
            }
        } else {
            var sign: Double = 1.0
            for _ in 0 ..< 2 {
                nextTiles.append(Tile(tt: TileShape.dart, x: tile.x, y: tile.y,
                                      angle: a - 4.0 * theta * sign, size: size))
                nx = tile.x + cos(a - theta * sign) * goldenRatio * tile.size
                ny = tile.y - sin(a - theta * sign) * goldenRatio * tile.size
                let nangle = a + 3.0 * theta * sign
                nextTiles.append(Tile(tt: TileShape.kite, x: nx, y: ny, angle: nangle, size: size))
                sign = sign * -1.0
            }
         }
    }
    
    let currentTiles = nextTiles.distinct
    
    return deflateTiles(currentTiles, gen - 1)
}

func drawTiles(_ context: CGContext, _ tiles: [Tile]) -> CIImage {
    let strokeColor = NSColor.black.cgColor
    context.setStrokeColor(strokeColor)

    for tile in tiles {
        let dist: [[Double]] = [[goldenRatio, goldenRatio, goldenRatio],
                                 [-goldenRatio, -1, -goldenRatio]]
        var angle = tile.angle - theta
        let shapePath = CGMutablePath()
        
        context.beginPath()
        context.move(to: CGPoint(x: CGFloat(tile.x), y: CGFloat(tile.y)))
        
        for segment in 0..<3 {
            let x: CGFloat = CGFloat(tile.x + dist[tile.tt.rawValue][segment] * tile.size * cos(angle))
            let y: CGFloat = CGFloat(tile.y - dist[tile.tt.rawValue][segment] * tile.size * sin(angle))
            context.addLine(to: CGPoint(x: x, y: y))
            angle = angle + theta
        }
        context.closePath()
        
        // use UIColor on iOS, obviously, or Color on SwiftUI
        let color = tile.tt.rawValue == 0 ? NSColor.orange.cgColor : NSColor.yellow.cgColor
        context.setFillColor(color)
        context.drawPath(using: .fillStroke)
    }
    
    guard let cgimage = context.makeImage()
    else {
        fatalError("Couldn't create the image")
    }
    let image = CIImage(cgImage: cgimage)
    return image
}

func getDocumentsDirectory() -> URL {
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return urls[urls.count - 1]
}

// don't need a main function
let width = 700
let height = 450
let bytesPerPixel = 8
let bytesPerRow = bytesPerPixel * width
let generations = 5
var tiles: [Tile]
if let context = CGContext(data: nil, width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) {
    context.setFillColor(CGColor.white)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    
    tiles = initialTiles(width, height)
    let finalTiles = deflateTiles(tiles, generations)

    let image = drawTiles(context, finalTiles)

    let url = URL.init(fileURLWithPath: "penrose_tiling.png", isDirectory: false, relativeTo: getDocumentsDirectory())
    // TODO getting an IIOIOSurfaceWrapper warning
    do {
        let ciContext = CIContext()
        try ciContext.writePNGRepresentation(of: image,
            to: url,
            format: .BGRA8,
            colorSpace: CGColorSpaceCreateDeviceRGB())
    } catch {
        print("Error writing file.")
    }
    print("Tile count: \(finalTiles.count)")
}
