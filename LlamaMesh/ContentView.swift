//
//  ContentView.swift
//  LlamaMesh
//
//  Created by Carlo Rapisarda on 2024-11-19.
//

import SwiftUI
import SceneKit
import SceneKit.ModelIO

struct ContentView: View {
    
    @State var model = LlamaMesh()
    @State var scene: SCNScene?
    @State var coordinator = SceneCoordinator()
    
    @State var wireframe: Bool = false
    @State var shouldStopGenerating: Bool = false
    
    @State var isGenerating: Bool = false {
        didSet {
            if isGenerating {
                generationStartDate = .now
            } else {
                generationStopDate = .now
            }
        }
    }
    
    @State var showModelPicker: Bool = false
    
    @State var seed: UInt32 = 1234
    @State var temperature: Float = 0.8
    @State var maxTokens: Int32 = 2024
    
    @State var prompt: String = ""
    @State var lastGenerationSystemPrompt: String = ""
    
    @State var output: LlamaMeshOutput = .init(raw: "")
    
    @State var nTokens: Int = 0
    @State var generationStartDate: Date = .distantPast
    @State var generationStopDate: Date = .distantFuture
    
    var tokensPerSecond: Double {
        let endDate = isGenerating ? .now : generationStopDate
        let interval = endDate.timeIntervalSince(generationStartDate)
        return Double(nTokens) / max(0.0001, interval)
    }
    
    @State var selectedLocalModelURL: URL?
    
    var selectedLocalModelName: String {
        return LlamaMesh.modelName(from: selectedLocalModelURL) ?? "-"
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Selected Model: \(Text(selectedLocalModelName).monospaced())")
                
                Button("Choose") {
                    showModelPicker = true
                }
                
                Button(model.isLoaded ? "Reload" : "Load") {
                    loadOrReload()
                }
                .disabled(selectedLocalModelURL == nil)
            }
            
            HStack {
                HStack {
                    Text("Seed")
                    TextField("Seed", value: $seed, format: .number)
                }
                Divider()
                HStack {
                    Text("Temperature")
                    TextField("Temperature", value: $temperature, format: .number)
                }
                Divider()
                HStack {
                    Text("Max Tokens")
                    TextField("Max Tokens", value: $maxTokens, format: .number)
                }
            }
            .disabled(isGenerating)
            
            HStack {
                TextField("Prompt", text: $prompt)
                    .lineLimit(1)
                    .disabled(isGenerating)
                
                Button(isGenerating ? "Cancel" : "Generate") {
                    if isGenerating {
                        shouldStopGenerating = true
                    } else {
                        generate()
                    }
                }
                .disabled(shouldStopGenerating)
            }
            .disabled(model.isLoaded == false)
            
            Toggle("Render as wireframe", isOn: $wireframe)
            
            HStack {
                VStack(spacing: 8) {
                    if let scene {
                        SceneView(scene: scene, options: [
                            .allowsCameraControl,
                            .autoenablesDefaultLighting,
                            .rendersContinuously,
                            .jitteringEnabled,
                        ], delegate: coordinator)
                    } else if isGenerating == false {
                        Text("Write a prompt and generate 👆")
                        Text("\"Create a simple 3D model of a table in OBJ format.\"")
                            .font(.caption)
                            .italic()
                    }
                }
                .frame(width: 300, height: 300)
                .background(Color(white: 0.2))
                .blur(radius: isGenerating ? 4 : .zero)
                .overlay {
                    ProgressView()
                        .opacity(isGenerating ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .animation(.easeInOut, value: isGenerating)
                
                VStack(alignment: .leading) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Vertices: \(output.vertices)")
                            Text("Faces: \(output.faces)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                        
                        Spacer()
                        Divider()
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Tokens: \(nTokens)")
                            Text("TPS: ~\(Int(tokensPerSecond))")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack {
                                Text(output.cleanMessage)
                                    .font(.caption)
                                    .monospaced()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                Divider()
                                    .id("bottom")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(8)
                            .onChange(of: output.raw) { _, newValue in
                                proxy.scrollTo("bottom")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollClipDisabled()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
                .padding()
                .frame(width: 300, height: 300)
                .background(Color(white: 0.2))
            }
        }
        .fileImporter(
            isPresented: $showModelPicker,
            allowedContentTypes: [.init(filenameExtension: "gguf")!],
            onCompletion: { result in
                selectedLocalModelURL = try? result.get()
            }
        )
        .padding()
        .onChange(of: selectedLocalModelURL, initial: true) { oldValue, newValue in
            if oldValue != newValue {
                oldValue?.stopAccessingSecurityScopedResource()
                _ = newValue?.startAccessingSecurityScopedResource()
            }
            if newValue != model.modelURL {
                model.unloadModel()
            }
        }
        .onChange(of: wireframe) { _, newValue in
            if newValue {
                coordinator.debugOptions = [.renderAsWireframe]
            } else {
                coordinator.debugOptions = []
            }
        }
    }
    
    func loadOrReload() {
        isGenerating = true
        defer { isGenerating = false }
        
        if model.isLoaded {
            try? model.reloadModel()
        } else if let selectedLocalModelURL {
            try? model.loadModel(url: selectedLocalModelURL)
        }
    }
    
    func generate() {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanPrompt.isEmpty == false else {
            return
        }
        generate(from: .begin(systemPrompt: cleanPrompt))
    }
    
    func continueGenerating() {
        let rawOutput = output.raw
        let systemPrompt = lastGenerationSystemPrompt
        generate(from: .continue(
            systemPrompt: systemPrompt,
            rawOutput: rawOutput
        ))
    }
    
    func generate(from prompt: LlamaMeshPrompt) {
        guard isGenerating == false else {
            return
        }
        isGenerating = true
        
        let maxTokens = min(8192, max(128, maxTokens))
        self.maxTokens = maxTokens
        
        let temperature = min(1, max(0, temperature))
        self.temperature = temperature
        
        let seed = seed
        
        if case .begin(let systemPrompt) = prompt {
            lastGenerationSystemPrompt = systemPrompt
        }
        
        Task { @MainActor in
            defer {
                isGenerating = false
                shouldStopGenerating = false
            }
            
            var n = 0
            for try await output in model.streamMesh(
                prompt,
                maxTokens: maxTokens,
                temperature: temperature,
                seed: seed
            ) {
                n += 1
                print("Tokens: \(n)")
                
                if shouldStopGenerating {
                    print("Stopping")
                    break
                }
                
                self.nTokens = n
                self.output = output
                
                if n % 10 == 0 {
                    let asset = try! output.makeAsset()
                    let scene = SCNScene(mdlAsset: asset)
                    scene.background.contents = NSColor.gray
                    self.scene = scene
                }
            }
        }
    }
}

@Observable
class SceneCoordinator: NSObject, SCNSceneRendererDelegate {
    
    var showsStatistics: Bool = false
    var debugOptions: SCNDebugOptions = []
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.showsStatistics = self.showsStatistics
        renderer.debugOptions = self.debugOptions
    }
}

#Preview {
    ContentView()
}
