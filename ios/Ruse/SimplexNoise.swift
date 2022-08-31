/*
 A speed-improved simplex noise algorithm for 2D. Based on public domain
 example code by Stefan Gustavson.
 
 http://staffwww.itn.liu.se/~stegu/simplexnoise/SimplexNoise.java
 
 This is free and unencumbered software released into the public domain.
 
 Anyone is free to copy, modify, publish, use, compile, sell, or
 distribute this software, either in source code form or as a compiled
 binary, for any purpose, commercial or non-commercial, and by any
 means.
 
 In jurisdictions that recognize copyright laws, the author or authors
 of this software dedicate any and all copyright interest in the
 software to the public domain. We make this dedication for the benefit
 of the public at large and to the detriment of our heirs and
 successors. We intend this dedication to be an overt act of
 relinquishment in perpetuity of all present and future rights to this
 software under copyright law.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 For more information, please refer to <http://unlicense.org>
 
 */

import Foundation
import SpriteKit

class SimplexNoise {

    private let grad3 : [Grad] = [
        Grad(x: 1, y: 1, z: 0), Grad(x: -1, y: 1, z: 0), Grad(x: 1, y: -1, z: 0), Grad(x: -1, y: -1, z: 0),
        Grad(x: 1, y: 0, z: 1), Grad(x: -1, y: 0, z: 1), Grad(x: 1, y: 0, z: -1), Grad(x: -1, y: 0, z: -1),
            Grad(x: 0, y: 1, z: 1), Grad(x: 0, y: -1, z: 1), Grad(x: 0, y: 1, z: -1), Grad(x: 0, y: -1, z: -1)
    ]
    
    private let p : [Int] = [151,160,137,91,90,15,   131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
        190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
        88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
        77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
        102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
        135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
        5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
        223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
        129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
        251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
        49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
        138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180]
    
    private var perm = Array(repeating: 0, count: 512)
    private var permMod12 = Array(repeating: 0, count: 512)
    
    init() {
        for i in 0..<512 {
            perm[i] = p[i & 255]
            permMod12[i] = perm[i] % 12
        }
    }
    
    private let F2 = 0.5 * (sqrt(3.0) - 1.0)
    private let G2 = (3.0 - sqrt(3.0)) / 6.0
    
    private func dot(g: Grad, x: Double, y: Double) -> Double {
        return g.x * x + g.y * y
    }
    
    private func fastfloor(x: Double) -> Int {
        let xi = Int(x)
        return x < Double(xi) ? xi - 1 : xi
    }
    
   func generatedNoise(chunk: CGPoint, octaves: Int, roughness: Double, scale: Double) -> [[Double]] {
        let width = Int(MapConstants.chunkSize.width)
        let height = Int(MapConstants.chunkSize.height)
        
        var noise = Array(count: width, repeatedValue: Array(count: height, repeatedValue: 0.0))
        
        var layerFrequency = scale
        var layerWeight = 1.0
        var weightSum = 0.0
        
        for _ in 0..<octaves {
            for i in 0..<noise.count {
                for j in 0..<noise[i].count {
                    let chunkPos = IsometricTilemap.translateFromChunkPosition(CGPoint(x: j, y: i), chunk: chunk)
                    noise[i][j] = noise2d(Double(chunkPos.x) * layerFrequency, y: Double(chunkPos.y) * layerFrequency) * layerWeight
                }
            }
            layerFrequency *= 2
            weightSum += layerWeight
            layerWeight *= roughness
        }
        
        for i in 0..<noise.count {
            for j in 0..<noise[i].count {
                noise[i][j] /= weightSum
                noise[i][j] = (noise[i][j] + 1) / 2
            }
        }
    
        return noise
    }
    
    func noise2d(x: Double, y: Double) -> Double {
        var n0, n1, n2: Double // noise from the three corners
        
        // skew the input space to determine the current simplex cell
        let s = (x + y) * F2 // hairy factor for 2D
        let i = fastfloor(x: (x + s))
        let j = fastfloor(x: (y + s))
        let t = Double(i + j) * G2
        
        // unskew the cell origins back to (x,y) space and
        // calculate the x/y distances from the cell origin
        let xorigin = Double(i) - t
        let yorigin = Double(j) - t
        let x0 = x - xorigin
        let y0 = y - yorigin
        
        // for 2D the simplex shape is an equilateral triangle
        // determine which simplex we are in
        var i1, j1 : Int // offsets for second (middle) corner of simplex in (i,j) coords
        if (x0 > y0) {
            // lower triangle, XY order: (0,0)->(1,0)->(1,1)
            i1 = 1
            j1 = 0
        } else {
            // upper triangle, YX order: (0,0)->(0,1)->(1,1)
            i1 = 0
            j1 = 1
        }
        // a step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
        // a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
        // c = (3-sqrt(3))/6
        let x1 = x0 - Double(i1) + G2 // offsets for middle corner in (x,y) unskewed coords
        let y1 = y0 - Double(j1) + G2
        let x2 = x0 - 1.0 + 2.0 * G2 // offsets for the last corner (x,y) unskewed coords
        let y2 = y0 - 1.0 + 2.0 * G2
        
        // work out the hashed gradient indices of the three simplex corners
        let ii = i & 255
        let jj = j & 255
        let gi0 = permMod12[ii + perm[jj]]
        let gi1 = permMod12[ii + i1 + perm[jj + j1]]
        let gi2 = permMod12[ii + 1 + perm[jj + 1]]
        
        // calculate the contribution from the three corners
        var t0 = 0.5 - x0 * x0 - y0 * y0
        if (t0 < 0) {
            n0 = 0.0
        } else {
            t0 *= t0
            n0 = t0 * t0 * dot(g: grad3[gi0], x: x0, y: y0) // (x,y) of grad3 used for 2D gradient
        }
        
        var t1 = 0.5 - x1 * x1 - y1 * y1
        if (t1 < 0) {
            n1 = 0.0
        } else {
            t1 *= t1
            n1 = t1 * t1 * dot(g: grad3[gi1], x: x1, y: y1)
        }
        
        var t2 = 0.5 - x2 * x2 - y2 * y2
        if (t2 < 0) {
            n2 = 0.0
        } else {
            t2 *= t2
            n2 = t2 * t2 * dot(g: grad3[gi2], x: x2, y: y2)
        }
        
        // add contributions from each corner to get the final noise
        // the result is scaled to return values in the interval [-1,1]
        return 70 * (n0 + n1 + n2)
    }
    
}

private struct Grad {
    let x, y, z: Double
}

