import SwiftUI
import SpriteKit
import AVFoundation
import AudioToolbox // For system sounds
import CoreHaptics // For advanced haptics

// MARK: - Explosion Types
enum ExplosionType: CaseIterable {
    case normal
    case peony
    case willow
    case ring
}

// MARK: - Fireworks Scene
class FireworksScene: SKScene {
    // Game control states
    var fireworksPaused = false
    var shouldRestart = false
    var isSoundEnabled = true
    var isHapticsEnabled = true // New haptics toggle
    var countdownActive = false
    var countdownValue = 10
    
    // Haptics engine
    var hapticsEngine: CHHapticEngine?
    
    // Nodes
    var countdownLabel: SKLabelNode!
    var countdownTimer: Timer?
    
    // Particle textures
    let particleTextures = [
        SKTexture(imageNamed: "spark"),
        SKTexture(imageNamed: "star"),
        SKTexture(imageNamed: "circle")
    ]
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        scaleMode = .resizeFill
        
        // Setup countdown label
        countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        countdownLabel.fontSize = 70
        countdownLabel.fontColor = .white
        countdownLabel.position = CGPoint(x: view.bounds.width/2, y: view.bounds.height/2)
        countdownLabel.zPosition = 10
        countdownLabel.isHidden = true
        addChild(countdownLabel)
        
        // Setup haptics engine
        setupHaptics()
        
        startFireworks()
    }
    
    func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticsEngine = try CHHapticEngine()
            try hapticsEngine?.start()
        } catch {
            print("Haptics engine error: \(error)")
        }
    }
    
    func startFireworks() {
        removeAllActions()
        removeAllChildren()
        addChild(countdownLabel) // Re-add after removeAllChildren
        
        // Launch fireworks at random intervals
        run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: Double.random(in: 0.1...0.8)),
                SKAction.run { [weak self] in
                    if !(self?.fireworksPaused ?? true) {
                        self?.launchSingleFirework()
                    }
                }
            ])
        ), withKey: "fireworks")
    }
    
    func launchSingleFirework() {
        // Ensure scene has valid size
        guard size.width > 100, size.height > 100 else { return }
        
        // Create firework rocket
        let rocket = SKSpriteNode(color: .white, size: CGSize(width: 2, height: 6))
        rocket.position = CGPoint(
            x: CGFloat.random(in: 50...size.width-50),
            y: -20
        )
        rocket.name = "rocket"
        addChild(rocket)
        
        // Add rocket trail (optional)
        if let trail = SKEmitterNode(fileNamed: "RocketTrail") {
            trail.targetNode = self
            rocket.addChild(trail)
        }
        
        // Target position (random in upper 2/3 of screen)
        let targetY = CGFloat.random(in: size.height/3...size.height-100)
        let targetPoint = CGPoint(
            x: CGFloat.random(in: 50...size.width-50),
            y: targetY
        )
        
        // Choose explosion type
        let explosionType = ExplosionType.allCases.randomElement()!
        
        // Animate rocket flight
        let flightDuration = TimeInterval(targetY / 300)
        rocket.run(SKAction.sequence([
            SKAction.move(to: targetPoint, duration: flightDuration),
            SKAction.run { [weak self] in
                rocket.removeFromParent()
                self?.createExplosion(ofType: explosionType, at: targetPoint)
            }
        ]))
    }
    
    func createExplosion(ofType type: ExplosionType, at position: CGPoint) {
        if isSoundEnabled {
            playExplosionSound()
        }
        
        if isHapticsEnabled {
            triggerHapticFeedback(for: type)
        }
        
        switch type {
        case .normal:
            createNormalExplosion(at: position)
        case .peony:
            createPeonyExplosion(at: position)
        case .willow:
            createWillowExplosion(at: position)
        case .ring:
            createRingExplosion(at: position)
        }
    }
    
    func triggerHapticFeedback(for explosionType: ExplosionType) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        var intensity: Float = 0.7
        var sharpness: Float = 0.8
        var duration: Double = 0.3
        
        switch explosionType {
        case .peony:
            intensity = 0.9
            sharpness = 1.0
            duration = 0.5
        case .willow:
            intensity = 0.6
            sharpness = 0.5
            duration = 0.8
        case .ring:
            intensity = 0.8
            sharpness = 0.9
            duration = 0.4
        default:
            break
        }
        
        do {
            let pattern = try hapticPattern(intensity: intensity,
                                           sharpness: sharpness,
                                           duration: duration)
            try hapticsEngine?.start()
            
            // Create and start player
            let player = try hapticsEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)  // Start immediately
        } catch {
            print("Haptic pattern error: \(error)")
            // Fallback to simple vibration
            AudioServicesPlaySystemSound(1520)
        }
    }
    
    // UPDATED HAPTIC PATTERN CREATION
    func hapticPattern(intensity: Float, sharpness: Float, duration: Double) throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,  // Changed to continuous
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,  // Start immediately
            duration: duration  // Use specified duration
        )
        
        return try CHHapticPattern(events: [event], parameters: [])
    }
    
    func createNormalExplosion(at position: CGPoint) {
        let explosion = SKEmitterNode()
        explosion.particleTexture = particleTextures.randomElement() ?? SKTexture()
        explosion.particleBirthRate = 4000
        explosion.numParticlesToEmit = 1000
        explosion.particleLifetime = 1.5
        explosion.particleSpeed = 200
        explosion.particleSpeedRange = 50
        explosion.particleAlpha = 0.8
        explosion.particleAlphaSpeed = -0.7
        explosion.particleScale = 0.2
        explosion.particleScaleRange = 0.1
        explosion.particleScaleSpeed = -0.1
        explosion.particleRotationRange = .pi
        explosion.particleColorBlendFactor = 1
        explosion.particleColor = randomFireworkColor()
        explosion.position = position
        
        addAndRemoveEmitter(explosion)
    }
    
    func createPeonyExplosion(at position: CGPoint) {
        let explosion = SKEmitterNode()
        explosion.particleTexture = particleTextures.randomElement() ?? SKTexture()
        explosion.particleBirthRate = 5000
        explosion.numParticlesToEmit = 1500
        explosion.particleLifetime = 2.0
        explosion.particleSpeed = 180
        explosion.particleSpeedRange = 40
        explosion.particleAlpha = 0.9
        explosion.particleAlphaSpeed = -0.4
        explosion.particleScale = 0.25
        explosion.particleScaleRange = 0.15
        explosion.particleScaleSpeed = -0.05
        explosion.particleRotationRange = .pi
        explosion.particleColorBlendFactor = 1
        explosion.particleColor = randomFireworkColor()
        explosion.position = position
        
        // Peony effect - dense spherical burst
        explosion.emissionAngleRange = .pi * 2
        explosion.particlePositionRange = CGVector(dx: 5, dy: 5)
        
        addAndRemoveEmitter(explosion)
    }
    
    func createWillowExplosion(at position: CGPoint) {
        let explosion = SKEmitterNode()
        explosion.particleTexture = particleTextures.randomElement() ?? SKTexture()
        explosion.particleBirthRate = 3000
        explosion.numParticlesToEmit = 800
        explosion.particleLifetime = 4.0
        explosion.particleSpeed = 150
        explosion.particleSpeedRange = 30
        explosion.particleAlpha = 0.85
        explosion.particleAlphaSpeed = -0.2
        explosion.particleScale = 0.15
        explosion.particleScaleRange = 0.05
        explosion.particleScaleSpeed = -0.02
        explosion.particleRotationRange = .pi
        explosion.particleColorBlendFactor = 1
        explosion.particleColor = randomFireworkColor()
        explosion.position = position
        
        // Willow effect - particles fall slowly
        explosion.particleAction = SKAction.run {
            explosion.particlePositionRange.dx += 0.5
            explosion.particlePositionRange.dy += 0.5
            explosion.particleSpeed -= 1
        }
        
        // Add falling sparks
        let fallingSparks = SKEmitterNode()
        fallingSparks.particleTexture = particleTextures.first ?? SKTexture()
        fallingSparks.particleBirthRate = 200
        fallingSparks.particleLifetime = 3.0
        fallingSparks.particleSpeed = 50
        fallingSparks.particleAlpha = 0.7
        fallingSparks.particleAlphaSpeed = -0.5
        fallingSparks.particleScale = 0.1
        fallingSparks.particleColor = explosion.particleColor
        fallingSparks.position = position
        
        addAndRemoveEmitter(explosion)
        addAndRemoveEmitter(fallingSparks)
    }
    
    func createRingExplosion(at position: CGPoint) {
        let ringColor = randomFireworkColor()
        
        // Create multiple emitters in a ring pattern
        let ringSegments = 16
        let radius: CGFloat = 40.0
        
        for i in 0..<ringSegments {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(ringSegments))
            let emitter = SKEmitterNode()
            emitter.particleTexture = particleTextures.randomElement() ?? SKTexture()
            emitter.particleBirthRate = 400
            emitter.numParticlesToEmit = 100
            emitter.particleLifetime = 1.2
            emitter.particleSpeed = 200
            emitter.particleAlpha = 0.8
            emitter.particleAlphaSpeed = -0.8
            emitter.particleScale = 0.15
            emitter.particleScaleRange = 0.05
            emitter.particleColor = ringColor
            emitter.position = position
            
            // Directional particles
            emitter.emissionAngle = angle
            emitter.emissionAngleRange = .pi / 8
            
            // Position offset for ring effect
            let xOffset = radius * cos(angle)
            let yOffset = radius * sin(angle)
            emitter.position = CGPoint(x: position.x + xOffset, y: position.y + yOffset)
            
            addAndRemoveEmitter(emitter)
        }
    }
    
    func addAndRemoveEmitter(_ emitter: SKEmitterNode) {
        addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { emitter.particleBirthRate = 0 },
            SKAction.wait(forDuration: 3),
            SKAction.removeFromParent()
        ]))
    }
    
    func randomFireworkColor() -> SKColor {
        let colors: [SKColor] = [
            .systemRed, .systemGreen, .systemBlue, .systemYellow,
            .systemOrange, .systemPurple, .systemPink, .systemTeal
        ]
        return colors.randomElement()!
    }
    
    func playExplosionSound() {
        // Safe sound playback with fallback
        let explosionSounds = ["explosion1", "explosion2", "explosion3"]
        guard let soundFile = explosionSounds.randomElement() else {
            AudioServicesPlaySystemSound(1105) // Fallback system sound
            return
        }
        
        if let url = Bundle.main.url(forResource: soundFile, withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 0.3
                player.play()
            } catch {
                print("Error playing sound: \(error)")
                AudioServicesPlaySystemSound(1105) // Fallback system sound
            }
        } else {
            AudioServicesPlaySystemSound(1105) // Fallback system sound
        }
    }
    
    func playCountdownSound() {
        // Safe sound playback with fallback
        if let url = Bundle.main.url(forResource: "countdown", withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 0.5
                player.play()
            } catch {
                print("Error playing countdown sound: \(error)")
                AudioServicesPlaySystemSound(1103) // Fallback system sound
            }
        } else {
            AudioServicesPlaySystemSound(1103) // Fallback system sound
        }
    }
    
    func togglePause() {
        fireworksPaused.toggle()
        if fireworksPaused {
            removeAction(forKey: "fireworks")
        } else {
            startFireworks()
        }
    }
    
    func toggleSound() {
        isSoundEnabled.toggle()
    }
    
    func toggleHaptics() {
        isHapticsEnabled.toggle()
    }
    
    func startCountdown(seconds: Int) {
        // Stop any existing countdown
        countdownTimer?.invalidate()
        
        countdownValue = seconds
        countdownActive = true
        countdownLabel.isHidden = false
        
        if isSoundEnabled {
            playCountdownSound()
        }
        
        // Update label immediately
        countdownLabel.text = "\(countdownValue)"
        countdownLabel.setScale(1.0)
        countdownLabel.run(SKAction.scale(to: 1.2, duration: 0.1))
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.countdownValue -= 1
            
            if self.countdownValue > 0 {
                // Update display
                self.countdownLabel.text = "\(self.countdownValue)"
                self.countdownLabel.setScale(1.0)
                self.countdownLabel.run(SKAction.scale(to: 1.2, duration: 0.1))
                
                if self.isSoundEnabled {
                    self.playCountdownSound()
                }
            } else {
                // Countdown finished
                timer.invalidate()
                self.countdownLabel.text = "GO!"
                self.countdownLabel.run(SKAction.sequence([
                    SKAction.scale(to: 2.0, duration: 0.3),
                    SKAction.wait(forDuration: 1.0),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.run {
                        self.countdownLabel.isHidden = true
                        self.countdownLabel.alpha = 1.0
                        self.countdownLabel.setScale(1.0)
                    }
                ]))
                
                // Trigger special event
                self.triggerSpecialEvent()
                self.countdownActive = false
            }
        }
    }
    
    func triggerSpecialEvent() {
        // Create a grand finale with multiple fireworks
        let positions = [
            CGPoint(x: size.width * 0.2, y: size.height * 0.7),
            CGPoint(x: size.width * 0.5, y: size.height * 0.8),
            CGPoint(x: size.width * 0.8, y: size.height * 0.7)
        ]
        
        for (index, position) in positions.enumerated() {
            run(SKAction.sequence([
                SKAction.wait(forDuration: Double(index) * 0.3),
                SKAction.run { [weak self] in
                    self?.createExplosion(ofType: .peony, at: position)
                    self?.createExplosion(ofType: .ring, at: position)
                }
            ]))
        }
    }
    
    func restart() {
        shouldRestart = true
        startFireworks()
        shouldRestart = false
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - SwiftUI View
struct FireworksView: View {
    @State private var scene: FireworksScene = {
        let scene = FireworksScene()
        scene.scaleMode = .resizeFill
        return scene
    }()
    
    @State private var countdownSeconds: Int = 10
    
    var body: some View {
        ZStack(alignment: .bottom) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear {
                    scene.size = UIScreen.main.bounds.size
                }
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 20) {
                // Countdown Controls
                HStack {
                    TextField("Seconds", value: $countdownSeconds, formatter: NumberFormatter())
                        .frame(width: 50)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .padding(8)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                    
                    Button(action: {
                        scene.startCountdown(seconds: countdownSeconds)
                    }) {
                        Text("Start Countdown")
                            .padding(8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)
                
                // Control Buttons
                HStack(spacing: 30) {
                    ControlButton(
                        action: { scene.togglePause() },
                        icon: scene.fireworksPaused ? "play.fill" : "pause.fill"
                    )
                    
                    ControlButton(
                        action: { scene.toggleSound() },
                        icon: scene.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    )
                    
                    // New haptics toggle button
                    ControlButton(
                        action: { scene.toggleHaptics() },
                        icon: scene.isHapticsEnabled ? "hand.tap.fill" : "hand.tap"
                    )
                    
                    ControlButton(
                        action: { scene.restart() },
                        icon: "gobackward"
                    )
                }
            }
            .padding(.bottom, 40)
        }
    }
}

struct ControlButton: View {
    let action: () -> Void
    let icon: String
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .shadow(radius: 10)
        }
    }
}

// MARK: - App Entry
@main
struct FireworksApp: App {
    var body: some Scene {
        WindowGroup {
            FireworksView()
        }
    }
}
