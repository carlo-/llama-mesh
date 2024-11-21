//
//  LlamaMeshPrompt.swift
//  LlamaMesh
//
//  Created by Carlo Rapisarda on 2024-11-21.
//

import Foundation

enum LlamaMeshPrompt {
    case begin(systemPrompt: String)
    case `continue`(systemPrompt: String, rawOutput: String)
    
    var formatted: String {
        switch self {
        case let .begin(systemPrompt):
            return Self.formatSystemPrompt(systemPrompt)
        case let .continue(systemPrompt, rawOutput):
            return Self.formatConversationContinuation(
                systemPrompt: systemPrompt,
                rawOutput: rawOutput
            )
        }
    }
    
    static private func formatSystemPrompt(_ systemPrompt: String) -> String {
        let prompt = """
<|begin_of_text|><|start_header_id|>system<|end_header_id|>
\(systemPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>
""".trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt
    }
    
    static private func formatConversationContinuation(systemPrompt: String, rawOutput: String) -> String {
        let formattedSystemPrompt = Self.formatSystemPrompt(systemPrompt)
        var cleanRawOutput = rawOutput
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanRawOutput.hasPrefix("<|eot_id|>") == false {
            cleanRawOutput += "<|eot_id|>"
        }
        
        let prompt = """
\(formattedSystemPrompt)\(cleanRawOutput)<|start_header_id|>user<|end_header_id|>Continue<|eot_id|><|start_header_id|>assistant<|end_header_id|>
""".trimmingCharacters(in: .whitespacesAndNewlines)
        
        print(prompt)
        return prompt
    }
}
