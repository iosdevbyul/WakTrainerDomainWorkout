import Foundation
import Combine
import WakTrainerCoreModels
import WakTrainerServiceHealthKit
import WakTrainerServiceLocation
import WakTrainerFeatureTimer

@MainActor
public final class WorkoutSessionViewModel: ObservableObject {
    @Published public private(set) var currentSnapshot: HealthSnapshot = HealthSnapshot(heartRate: 0)
    @Published public private(set) var totalDistance: Double = 0
    @Published public private(set) var isSessionActive: Bool = false
    
    private let healthKitManager: any HealthKitManagerProtocol
    private let locationManager: any LocationManagerProtocol
    private let timerManager: any TimerManagerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private var healthTask: Task<Void, Never>?
    
    public init(
        healthKitManager: any HealthKitManagerProtocol = HealthKitManager(),
        locationManager: any LocationManagerProtocol = LocationManager(),
        timerManager: any TimerManagerProtocol = TimerManager()
    ) {
        self.healthKitManager = healthKitManager
        self.locationManager = locationManager
        self.timerManager = timerManager
    }
    
    public func startSession() async {
        do {
            let authorized = try await healthKitManager.requestAuthorization()
            guard authorized else { return }
            
            locationManager.requestLocationPermission()
            
            isSessionActive = true
            timerManager.start()
            locationManager.startTracking()
            
            healthTask = Task {
                for await snapshot in healthKitManager.startObservingData() {
                    self.currentSnapshot = snapshot
                }
            }
        } catch {
            print("Failed to start session: \(error.localizedDescription)")
        }
    }
    
    public func stopSession() async {
        isSessionActive = false
        timerManager.stop()
        locationManager.stopTracking()
        
        await healthKitManager.stopObservingData()
        healthTask?.cancel()
        healthTask = nil
    }
}
