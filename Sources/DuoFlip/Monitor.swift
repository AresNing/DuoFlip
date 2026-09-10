import Foundation

final class SensorMonitor {
    private let queue=DispatchQueue(label:"local.lid-motion.sensor",qos:.userInteractive)
    private var timer:DispatchSourceTimer?
    private let sensor=LidSensor()
    private var connected=false
    private var retryAfter=0.0
    var onSample:((LidSample)->Void)?
    var onError:((LocalizedMessage)->Void)?
    func start() { queue.async { [self] in
        guard timer == nil else { return }
        connected=false; retryAfter=0
        let timer=DispatchSource.makeTimerSource(queue:queue)
        timer.schedule(deadline:.now(),repeating:1.0/30.0,leeway:.milliseconds(2))
        timer.setEventHandler { [weak self] in self?.poll() }
        self.timer=timer; timer.resume()
    } }
    func stop() { queue.async { [self] in
        timer?.cancel(); timer=nil
        sensor.disconnect(); connected=false
    } }
    func restart() { stop(); start() }
    private func poll() {
        let now=ProcessInfo.processInfo.systemUptime
        guard now>=retryAfter else { return }
        do {
            if !connected { try sensor.connect(); connected=true }
            let sample=try sensor.read()
            DispatchQueue.main.async { [weak self] in self?.onSample?(sample) }
        } catch {
            sensor.disconnect(); connected=false; retryAfter=now+1
            let message=(error as? LidError)?.message ?? LocalizedMessage(verbatim:String(describing:error))
            DispatchQueue.main.async { [weak self] in self?.onError?(message) }
        }
    }
}

final class SessionLog {
    let directory:URL
    private let handle:FileHandle
    private let queue=DispatchQueue(label:"local.lid-motion.evidence",qos:.utility)
    private var lastFlush=0.0
    private var firstDate=ISO8601DateFormatter().string(from:Date())
    private(set) var samples=0
    private(set) var minimum=180.0
    private(set) var maximum=0.0
    private(set) var failures=0
    private(set) var wakeCount=0
    private(set) var sleepCount=0
    private var readTotal=0.0
    private var readMax=0.0
    private var renderTotal=0.0
    private var renderMax=0.0
    private var rendered=0
    private var lastCSV=0.0
    init(directory:URL) throws {
        self.directory=directory
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let stamp=Int(Date().timeIntervalSince1970)
        let csv=directory.appendingPathComponent("session-\(stamp).csv")
        FileManager.default.createFile(atPath:csv.path,contents:Data("uptime,mode,raw_angle,filtered_angle,progress,read_ms\n".utf8))
        handle=try FileHandle(forWritingTo:csv)
        try handle.seekToEnd()
    }
    func sample(_ sample:LidSample,filtered:Double,progress:Double,live:Bool) {
        samples+=1; minimum=min(minimum,sample.angle); maximum=max(maximum,sample.angle)
        readTotal+=sample.readMilliseconds; readMax=max(readMax,sample.readMilliseconds)
        if sample.timestamp-lastCSV>=0.095 {
            let row=String(format:"%.4f,%@,%.2f,%.3f,%.5f,%.4f\n",sample.timestamp,live ? "live":"manual",sample.angle,filtered,progress,sample.readMilliseconds)
            let data=Data(row.utf8)
            queue.async { [handle] in try? handle.write(contentsOf:data) }
            lastCSV=sample.timestamp
        }
    }
    func rendered(_ ms:Double) { rendered+=1; renderTotal+=ms; renderMax=max(renderMax,ms) }
    func event(_ event:String) {
        if event == "sleep" { sleepCount+=1 }
        if event == "wake" { wakeCount+=1 }
        if event.hasPrefix("error:") { failures+=1 }
        let data=Data(("# "+ISO8601DateFormatter().string(from:Date())+" "+event+"\n").utf8)
        queue.async { [handle] in try? handle.write(contentsOf:data) }
    }
    func flush(state:[String:Any],force:Bool=false) {
        let now=ProcessInfo.processInfo.systemUptime
        guard force || now-lastFlush>=0.5 else {return}
        lastFlush=now
        var data=state
        data["startedAt"]=firstDate; data["updatedAt"]=ISO8601DateFormatter().string(from:Date())
        data["sensorSamples"]=samples; data["minPhysicalAngle"]=samples>0 ? minimum:0; data["maxPhysicalAngle"]=maximum
        data["sensorMeanReadMs"]=readTotal/Double(max(1,samples)); data["sensorMaxReadMs"]=readMax
        data["renderedFrames"]=rendered; data["meanSubmitToGPUCompleteMs"]=renderTotal/Double(max(1,rendered)); data["maxSubmitToGPUCompleteMs"]=renderMax
        data["readErrors"]=failures; data["sleepEvents"]=sleepCount; data["wakeEvents"]=wakeCount
        guard let bytes=try? JSONSerialization.data(withJSONObject:data,options:[.prettyPrinted,.sortedKeys]) else {return}
        let url=directory.appendingPathComponent("current-session.json")
        queue.async { try? bytes.write(to:url,options:.atomic) }
    }
    func finish() { queue.sync { try? handle.synchronize(); try? handle.close() } }
}
