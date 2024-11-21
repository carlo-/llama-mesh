//
//  LlamaMeshOutput.swift
//  LlamaMesh
//
//  Created by Carlo Rapisarda on 2024-11-21.
//

import ModelIO

struct LlamaMeshOutput {
    
    let raw: String
    
    var cleanMessage: String {
        raw
            .replacingOccurrences(of: "<|start_text_id|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var obj: String {
        Self.cleanObj(raw)
    }
    
    var vertices: Int {
        obj.filter { $0 == "v" }.count
    }
    
    var faces: Int {
        obj.filter { $0 == "f" }.count
    }
    
    func makeAsset() throws -> MDLAsset {
        try Self.objToAsset(obj)
    }
    
    static private func objToAsset(_ raw: String) throws -> MDLAsset {
        let url: URL = .temporaryDirectory.appendingPathComponent("\(UUID()).obj")
        let data = raw.data(using: .utf8)!
        try data.write(to: url)
        let asset = MDLAsset(url: url as URL)
        return asset
    }
    
    static private func cleanObj(_ rawInput: String) -> String {
        let comps1 = rawInput.components(separatedBy: "obj")
        if comps1.count >= 2 {
            let component = comps1[1]
            return component.components(separatedBy: "```").first ?? component
        }
        let comps2 = rawInput.components(separatedBy: "```")
        if comps2.count >= 2 {
            return comps2[1]
        }
        return rawInput
    }
}
