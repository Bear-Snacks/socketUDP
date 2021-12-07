//
//  ContentView.swift
//  SocketUDP
//
//  Created by Kevin Walchko on 12/4/21.
//

import SwiftUI
import Network

func sleeps(sec: Double){
    usleep(UInt32(sec * 1000000))
}

class UDPSocket {
    var connection: NWConnection?
    var msg: String = "None"
    
    init(ip: NWEndpoint.Host, port: NWEndpoint.Port) {
        
        self.connection = NWConnection(
            host: ip,
            port: port,
            using: .udp)
        
//        self.connection?.stateUpdateHandler = { (state) in
//            switch (state) {
//            case .ready:
//                print("UDPSocket: ready")
//            case .setup:
//                print("UDPSocket: setup")
//            case .cancelled:
//                print("UDPSocket: cancelled")
//            case .preparing:
//                print("UDPSocket: preparing")
//            default:
//                print("waiting or failed")
//
//            }
//        }
        self.connection?.start(queue: .global())
    }
    
    deinit {
        self.connection?.cancel()
    }
    
    func send(_ content: String) {
        let contentToSendUDP = content.data(using: String.Encoding.utf8)
        self.connection?.send(
            content: contentToSendUDP,
            completion: NWConnection.SendCompletion.contentProcessed({ NWError in
                if (NWError != nil) {
                    print("*** UDPSocket send() error: \(NWError!)")
                }
            }))
    }
    
    func receive() -> String {
        self.connection?.receiveMessage { (data, context, isComplete, error) in
            if (isComplete) {
                if (data != nil) {
                    self.msg = String(decoding: data!, as: UTF8.self)
                } else {
                    print("Data == nil")
                }
            }
        }
        return self.msg
    }
    
    func printAddresses() {
        var addrList : UnsafeMutablePointer<ifaddrs>?
        guard
            getifaddrs(&addrList) == 0,
            let firstAddr = addrList
        else { return }
        defer { freeifaddrs(addrList) }
        for cursor in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interfaceName = String(cString: cursor.pointee.ifa_name)
            let addrStr: String
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if
                let addr = cursor.pointee.ifa_addr,
                getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0,
                hostname[0] != 0
            {
                addrStr = String(cString: hostname)
            } else {
                addrStr = "?"
            }
            print(interfaceName, addrStr)
        }
        return
    }
}

class ViewModel: ObservableObject {
    @Published var msg: String = ""
    
    var interval: Double
    
    var socket: UDPSocket
    var count: Int = 0
    var timer = Timer()
    
    
    init(ip: NWEndpoint.Host, port: NWEndpoint.Port=9500, interval: Double){
        self.socket = UDPSocket(
            ip: ip,
            port: port
        )
        
//        self.socket.printAddresses()
        
        self.interval = interval
        self.timer = Timer.scheduledTimer(
            withTimeInterval: self.interval,
            repeats: true,
            block: { _ in
                self.update()
        })
    }
    
    func update() {
        socket.send("hello \(self.count)")
//        sleeps(sec: 0.1)
        let ans = self.socket.receive()
        print(">> from socket: \(ans)")
        self.msg = ans
        self.count += 1
    }
    
    deinit {
        self.timer.invalidate()
    }
}

struct ContentView: View {
    @ObservedObject var vm = ViewModel(
        ip: "10.0.1.116",
        port: 9500,
        interval: 1.0)
    
    var body: some View {
        Text(self.vm.msg)
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
