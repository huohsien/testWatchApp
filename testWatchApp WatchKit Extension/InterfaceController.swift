//
//  InterfaceController.swift
//  testWatchApp WatchKit Extension
//
//  Created by victor on 2020/7/4.
//  Copyright © 2020 VHHC Studio. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit

class InterfaceController: WKInterfaceController {
    
    @IBOutlet weak var bmpLabel: WKInterfaceLabel!
    
    private var healthStore = HKHealthStore()
    private var heartRateQuery: HKObserverQuery? = nil
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        print("awake")
        // Configure interface objects here.
        authorizeHealthKit()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        print("willActivate")
        //        startHeartRateQuery(quantityTypeIdentifier: .heartRate)
        subscribeToHeartBeatChanges()
        healthStore.execute(heartRateQuery!)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        print("didDeactivate")
        
    }
    
    func authorizeHealthKit() {
        let healthKitTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!]
        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { (success, error) in
            if success {
                print("heart rate authorization succeeded!")
            }
        }
    }
    
    func subscribeToHeartBeatChanges () {
        // Creating the sample for the heart rate
        let sampleType: HKSampleType! = HKObjectType.quantityType(forIdentifier: .heartRate)
        
        /// Creating an observer, so updates are received whenever HealthKit’s
        // heart rate data changes.
        self.heartRateQuery = HKObserverQuery.init(sampleType: sampleType, predicate: nil) { [weak self] _, _, error in
            
            guard error == nil else {
                print("error: ", error!.localizedDescription)
                return
            }
            
            /// When the completion is called, an other query is executed
            /// to fetch the latest heart rate
            self!.fetchLatestHeartRateSample(completion: { heartRate in
                
                /// The completion in called on a background thread, but we
                /// need to update the UI on the main.
                DispatchQueue.main.async {
                    
                    /// Updating the UI with the retrieved value
                    self?.bmpLabel.setText("\(Int(heartRate))")
                }
            })
        }
    }
    
    func fetchLatestHeartRateSample(completion: @escaping (_ heartRate: Double) -> Void) {
        
        /// Create sample type for the heart rate
        guard let sampleType = HKObjectType
            .quantityType(forIdentifier: .heartRate) else {
                completion(0)
                return
        }
        
        /// Predicate for specifiying start and end dates for the query
        let predicate = HKQuery
            .predicateForSamples(
                withStart: Date.distantPast,
                end: Date(),
                options: .strictEndDate)
        
        /// Set sorting by date.
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false)
        
        /// Create the query
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: Int(HKObjectQueryNoLimit),
            sortDescriptors: [sortDescriptor]) { (_, results, error) in
                
                guard error == nil else {
                    print("Error: \(error!.localizedDescription)")
                    return
                }
                var lastHeartRate = 0.0
                
                if results != nil {
                    for result in results! {
                        /// Converting the heart rate to bpm
                        let heartRateUnit = HKUnit(from: "count/min")

                        let sample = result as! HKQuantitySample

                        lastHeartRate = sample.quantity.doubleValue(for: heartRateUnit)
                    }
                }
                completion(lastHeartRate)
        }
        
        
        self.healthStore.execute(query)
    }
    
}

