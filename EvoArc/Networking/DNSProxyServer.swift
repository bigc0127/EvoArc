//
//  DNSProxyServer.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import Network

/// Local DNS proxy server that redirects queries to ControlD's DoH endpoint
class DNSProxyServer {
    static let shared = DNSProxyServer()
    
    private var listener: NWListener?
    private let dohSession: URLSession
    private let queue = DispatchQueue(label: "com.evoarc.dnsproxy")
    
    // ControlD DoH endpoint
    private let dohURL = "https://freedns.controld.com/p2/dns-query"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        self.dohSession = URLSession(configuration: config)
    }
    
    /// Starts the local DNS proxy server
    func start(port: UInt16 = 5353) -> Bool {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        guard let port = NWEndpoint.Port(rawValue: port) else {
            print("Invalid port number")
            return false
        }
        
        do {
            listener = try NWListener(using: parameters, on: port)
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
            print("DNS proxy server started on port \(port)")
            return true
        } catch {
            print("Failed to start DNS proxy: \(error)")
            return false
        }
    }
    
    /// Handles incoming DNS connections
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleDNSQuery(data, connection: connection)
            }
            
            if isComplete {
                connection.cancel()
            } else if let error = error {
                print("Connection error: \(error)")
                connection.cancel()
            }
        }
    }
    
    /// Handles DNS query and forwards to DoH
    private func handleDNSQuery(_ queryData: Data, connection: NWConnection) {
        // Forward DNS query to ControlD's DoH endpoint
        var request = URLRequest(url: URL(string: dohURL)!)
        request.httpMethod = "POST"
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = queryData
        
        let task = dohSession.dataTask(with: request) { data, response, error in
            if let data = data {
                // Send DoH response back to client
                connection.send(content: data, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } else {
                // Send error response
                connection.cancel()
            }
        }
        
        task.resume()
    }
    
    /// Stops the DNS proxy server
    func stop() {
        listener?.cancel()
        listener = nil
    }
}
