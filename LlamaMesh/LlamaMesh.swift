//
//  LlamaMesh.swift
//  LlamaMesh
//
//  Created by Carlo Rapisarda on 2024-11-20.
//

import Foundation
import ModelIO
import LLamaSwift

@Observable
class LlamaMesh {
    
    private var _model: (underlyingModel: LLamaSwift.Model, url: URL)?
    
    var isLoaded: Bool {
        _model != nil
    }
    
    var modelURL: URL? {
        _model?.url
    }
    
    var modelName: String? {
        Self.modelName(from: modelURL)
    }
    
    private var underlyingModel: LLamaSwift.Model? {
        _model?.underlyingModel
    }

    init () {
        
    }
    
    static func modelName(from url: URL?) -> String? {
        guard let url else { return nil }
        
        let lastPathComponent = url.lastPathComponent
        let name = lastPathComponent.components(separatedBy: ".").first ?? lastPathComponent
        return name
    }
    
    func unloadModel() {
        _model = nil
    }
    
    func reloadModel() throws {
        guard let modelURL else { return }
        try loadModel(url: modelURL)
    }
    
    func loadModel(url: URL) throws {
        unloadModel()
        
        let model = try Model(modelPath: url.path())
        self._model = (model, url)
        
        url.stopAccessingSecurityScopedResource()
    }
    
    func streamMesh(_ prompt: LlamaMeshPrompt, maxTokens: Int32 = 2024, temperature: Float = 0.8, seed: UInt32 = 1234) -> AsyncThrowingStream<LlamaMeshOutput, any Error> {
        guard let underlyingModel else {
            fatalError()
        }
        
        let llama = LLama(model: underlyingModel, temperature: temperature, seed: seed)
        
        var encodedPrompt = prompt.formatted
        if case .continue = prompt {
            encodedPrompt = "<|start_header_id|>user<|end_header_id|>Continue<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
        } else {
            try! underlyingModel.reinitContext(contextSize: UInt32(maxTokens))
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                var output = ""
                
                do {
                    for try await token in await llama.infer(prompt: encodedPrompt, maxTokens: maxTokens) {
                        output += token
                        let result = continuation.yield(LlamaMeshOutput(raw: output))
                        if case .terminated = result {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
