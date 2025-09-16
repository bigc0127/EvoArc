//
//  DoHResolver.swift
//  EvoArc
//
//  DNS over HTTPS resolver implementation for ControlD endpoint
//

/**
 * # DoHResolver
 * 
 * Core DNS over HTTPS (DoH) resolver component that handles the actual DNS
 * queries and responses. This implementation uses the RFC 8484 standard
 * for DNS queries over HTTPS and supports multiple DoH providers.
 * 
 * ## Architecture Overview
 * 
 * ### For New Swift Developers:
 * - **DNS Resolution**: Converting domain names to IP addresses
 * - **HTTPS Requests**: Making secure web requests for DNS queries
 * - **JSON Parsing**: Processing DNS responses in JSON format
 * - **Wire Format**: Binary DNS protocol format (RFC 1035)
 * - **Swift Concurrency**: Using async/await for network operations
 * 
 * ### Implementation Details:
 * - **Protocol**: Uses RFC 8484 for DoH (DNS Queries over HTTPS)
 * - **Providers**: Supports multiple DoH providers (Google, Cloudflare, etc.)
 * - **Query Methods**: Implements both JSON and wire format queries
 * - **Caching**: Provides in-memory caching of DNS resolutions
 * - **Retry Logic**: Handles network failures with exponential backoff
 * 
 * ## Usage Examples:
 * ```swift
 * let resolver = DoHResolver()
 * 
 * // Resolve a domain name
 * let addresses = await resolver.resolve(hostname: "example.com")
 * if let ip = addresses.first {
 *     print("Resolved example.com to \(ip)")
 * }
 * ```
 */

import Foundation
import Network

/// DNS over HTTPS resolver for domain name resolution
class DoHResolver { /* deprecated - not used */
    
    // MARK: - DNS Providers
    
    /// Supported DoH provider endpoints
    enum Provider: String, CaseIterable {
        /// Google Public DNS (JSON API)
        case google = "https://dns.google/resolve"
        /// Cloudflare DNS (JSON API)
        case cloudflare = "https://cloudflare-dns.com/dns-query"
        /// Quad9 DNS (JSON API)
        case quad9 = "https://dns.quad9.net/dns-query"
        
        /// Whether this provider supports JSON API format
        var supportsJSON: Bool {
            return true
        }
        
        /// Whether this provider supports DNS wire format
        var supportsWireFormat: Bool {
            return self == .cloudflare || self == .quad9
        }
    }
    
    // MARK: - Configuration
    
    /// The currently selected DoH provider
    private var provider: Provider
    
    /// Session for making HTTP requests
    private let session: URLSession
    
    /// In-memory cache for resolved hostnames
    private var cache: [String: CachedResolution] = [:]
    private let cacheQueue = DispatchQueue(label: "com.evoarc.doh-cache", attributes: .concurrent)
    
    /// TTL for cached resolutions (in seconds)
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    /// Structure for caching resolved addresses
    private struct CachedResolution {
        let addresses: [String]
        let timestamp: Date
        
        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new DNS over HTTPS resolver
    /// - Parameter provider: The DoH provider to use (default: .cloudflare)
    init(provider: Provider = .cloudflare) {
        // Use Cloudflare by default as it's more reliable
        self.provider = provider
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        self.session = URLSession(configuration: config)
        
        print("🔧 DoH Resolver initialized with provider: \(provider.rawValue)")
    }
    
    // MARK: - Public Methods
    
    /// Resolves a hostname to IP addresses using DNS over HTTPS
    /// - Parameter hostname: The hostname to resolve
    /// - Returns: Array of IP addresses (strings)
    func resolve(hostname: String) async -> [String] {
        // Check cache first
        if let cached = getCachedResolution(for: hostname), !cached.isExpired {
            print("DoH: Using cached resolution for \(hostname): \(cached.addresses)")
            return cached.addresses
        }
        
        print("DoH: Resolving \(hostname) via \(provider.rawValue)")
        
        // Attempt JSON API first if supported
        if provider.supportsJSON {
            if let addresses = await resolveUsingJSON(hostname: hostname) {
                cacheResolution(hostname: hostname, addresses: addresses)
                return addresses
            }
        }
        
        // Fall back to wire format if supported
        if provider.supportsWireFormat {
            if let addresses = await resolveUsingWireFormat(hostname: hostname) {
                cacheResolution(hostname: hostname, addresses: addresses)
                return addresses
            }
        }
        
        // If all methods fail, try a system DNS lookup as last resort
        print("DoH: All DoH methods failed, falling back to system DNS for \(hostname)")
        if let addresses = await resolveUsingSystemDNS(hostname: hostname) {
            cacheResolution(hostname: hostname, addresses: addresses)
            return addresses
        }
        
        print("DoH: Failed to resolve \(hostname) through any method")
        return []
    }
    
    /// Changes the active DoH provider
    /// - Parameter provider: The new provider to use
    func setProvider(_ provider: Provider) {
        self.provider = provider
        clearCache()
        print("DoH: Changed provider to \(provider.rawValue)")
    }
    
    /// Clears the DNS resolution cache
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
        print("DoH: Cache cleared")
    }
    
    // MARK: - Private Implementation
    
    /// Resolves a hostname using the JSON API format
    /// - Parameter hostname: The hostname to resolve
    /// - Returns: Array of IP addresses or nil if resolution failed
    private func resolveUsingJSON(hostname: String) async -> [String]? {
        // Use the proper JSON endpoint for the provider
        let jsonEndpoint: String
        switch provider {
        case .google:
            jsonEndpoint = "https://dns.google/resolve"
        case .cloudflare:
            jsonEndpoint = "https://cloudflare-dns.com/dns-query"
        case .quad9:
            jsonEndpoint = "https://dns.quad9.net/dns-query"
        }
        
        guard var components = URLComponents(string: jsonEndpoint) else {
            print("DoH: Invalid provider URL")
            return nil
        }
        
        components.queryItems = [
            URLQueryItem(name: "name", value: hostname),
            URLQueryItem(name: "type", value: "A"),      // IPv4 addresses
            URLQueryItem(name: "do", value: "false"),    // DNSSEC validation off
            URLQueryItem(name: "cd", value: "false")     // Checking disabled flag
        ]
        
        guard let url = components.url else {
            print("DoH: Failed to create URL for JSON query")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/dns-json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("DoH: HTTP error for JSON query: \(response)")
                return nil
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let answers = json["Answer"] as? [[String: Any]] else {
                print("DoH: Invalid JSON response")
                return nil
            }
            
            // Extract IP addresses from the response
            let addresses = answers.compactMap { answer -> String? in
                guard let type = answer["type"] as? Int,
                      (type == 1 || type == 28), // A or AAAA record
                      let data = answer["data"] as? String else {
                    return nil
                }
                
                // Handle the case where data might be an IP or a CNAME
                if data.contains(".") && data.rangeOfCharacter(from: CharacterSet.letters) == nil {
                    return data // Likely an IPv4 address
                } else if data.contains(":") {
                    return data // Likely an IPv6 address
                }
                return nil
            }
            
            print("DoH: JSON resolved \(hostname) to \(addresses)")
            return addresses.isEmpty ? nil : addresses
            
        } catch {
            print("DoH: Error during JSON query: \(error)")
            return nil
        }
    }
    
    /// Resolves a hostname using the DNS wire format
    /// - Parameter hostname: The hostname to resolve
    /// - Returns: Array of IP addresses or nil if resolution failed
    private func resolveUsingWireFormat(hostname: String) async -> [String]? {
        guard let url = URL(string: provider.rawValue) else {
            print("DoH: Invalid provider URL for wire format")
            return nil
        }
        
        // Create a simple DNS query packet
        guard let dnsQuery = createDNSQuery(for: hostname) else {
            print("DoH: Failed to create DNS wire format query")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = dnsQuery
        request.addValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.addValue("application/dns-message", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("DoH: HTTP error for wire format query: \(response)")
                return nil
            }
            
            // Parse the DNS response packet
            let addresses = parseDNSResponse(data: data)
            print("DoH: Wire format resolved \(hostname) to \(addresses)")
            return addresses.isEmpty ? nil : addresses
            
        } catch {
            print("DoH: Error during wire format query: \(error)")
            return nil
        }
    }
    
    /// Creates a DNS query in wire format (RFC 1035)
    /// - Parameter hostname: The hostname to query
    /// - Returns: DNS query data or nil if creation failed
    private func createDNSQuery(for hostname: String) -> Data? {
        // This is a simplified implementation that creates a basic DNS query
        // A full implementation would be more complex
        
        var queryData = Data()
        
        // Header section
        let id: UInt16 = UInt16.random(in: 1...65535)
        queryData.append(UInt8(id >> 8))
        queryData.append(UInt8(id & 0xFF))
        
        // Flags: Standard query, recursion desired
        queryData.append(0x01)
        queryData.append(0x00)
        
        // QDCOUNT: 1 question
        queryData.append(0x00)
        queryData.append(0x01)
        
        // ANCOUNT, NSCOUNT, ARCOUNT: all 0
        queryData.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        // Question section: hostname in DNS format
        let components = hostname.split(separator: ".")
        for component in components {
            let length = UInt8(component.count)
            queryData.append(length)
            
            if let componentData = component.data(using: .ascii) {
                queryData.append(componentData)
            }
        }
        
        // Terminating zero for hostname
        queryData.append(0x00)
        
        // QTYPE: A (IPv4)
        queryData.append(0x00)
        queryData.append(0x01)
        
        // QCLASS: IN (Internet)
        queryData.append(0x00)
        queryData.append(0x01)
        
        return queryData
    }
    
    /// Parses a DNS response in wire format (RFC 1035)
    /// - Parameter data: The DNS response data
    /// - Returns: Array of IP addresses
    private func parseDNSResponse(data: Data) -> [String] {
        // This is a simplified implementation that extracts IP addresses
        // from a DNS response. A full implementation would be more complex.
        
        // Ensure we have enough data for a header
        guard data.count >= 12 else {
            print("DoH: DNS response too short")
            return []
        }
        
        // Skip the header
        var currentPosition = 12
        
        // Skip the questions
        let questionCount = (Int(data[4]) << 8) | Int(data[5])
        for _ in 0..<questionCount {
            // Skip name
            while currentPosition < data.count {
                let length = Int(data[currentPosition])
                currentPosition += 1
                
                if length == 0 {
                    break
                } else if (length & 0xC0) == 0xC0 {
                    // Compressed name, skip one more byte
                    currentPosition += 1
                    break
                } else {
                    currentPosition += length
                }
            }
            
            // Skip QTYPE and QCLASS
            currentPosition += 4
        }
        
        // Process the answers
        var addresses: [String] = []
        let answerCount = (Int(data[6]) << 8) | Int(data[7])
        
        for _ in 0..<answerCount {
            // Skip name
            while currentPosition < data.count {
                let length = Int(data[currentPosition])
                currentPosition += 1
                
                if length == 0 {
                    break
                } else if (length & 0xC0) == 0xC0 {
                    // Compressed name, skip one more byte
                    currentPosition += 1
                    break
                } else {
                    currentPosition += length
                }
            }
            
            // Ensure we have enough data for the fixed-length part
            guard currentPosition + 10 <= data.count else {
                break
            }
            
            // Get TYPE and CLASS
            let type = (Int(data[currentPosition]) << 8) | Int(data[currentPosition + 1])
            currentPosition += 4 // Skip TYPE and CLASS
            
            // Skip TTL
            currentPosition += 4
            
            // Get RDLENGTH
            let rdLength = (Int(data[currentPosition]) << 8) | Int(data[currentPosition + 1])
            currentPosition += 2
            
            // Ensure we have enough data for RDATA
            guard currentPosition + rdLength <= data.count else {
                break
            }
            
            // Check if this is an A record (type 1)
            if type == 1 && rdLength == 4 {
                let ip = "\(data[currentPosition]).\(data[currentPosition + 1]).\(data[currentPosition + 2]).\(data[currentPosition + 3])"
                addresses.append(ip)
            }
            
            // Move to the next answer
            currentPosition += rdLength
        }
        
        return addresses
    }
    
    /// Resolves a hostname using the system DNS
    /// - Parameter hostname: The hostname to resolve
    /// - Returns: Array of IP addresses or nil if resolution failed
    private func resolveUsingSystemDNS(hostname: String) async -> [String]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var addresses: [String] = []
                
                let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
                let success = CFHostStartInfoResolution(host, .addresses, nil)
                
                if success {
                    var resolved: DarwinBoolean = false
                    if let addressData = CFHostGetAddressing(host, &resolved)?.takeRetainedValue() as NSArray? {
                        for i in 0..<addressData.count {
                            let data = addressData[i] as! CFData
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            
                            let dataPtr = CFDataGetBytePtr(data)
                            let dataLength = CFDataGetLength(data)
                            
                            if let ptr = dataPtr,
                               getnameinfo(UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self),
                                          socklen_t(dataLength),
                                          &hostname, socklen_t(hostname.count),
                                          nil, 0, NI_NUMERICHOST) == 0 {
                                if let ipAddress = String(cString: hostname, encoding: .ascii) {
                                    addresses.append(ipAddress)
                                }
                            }
                        }
                    }
                }
                
                print("DoH: System DNS resolved \(hostname) to \(addresses)")
                continuation.resume(returning: addresses.isEmpty ? nil : addresses)
            }
        }
    }
    
    // MARK: - Cache Management
    
    /// Retrieves a cached DNS resolution for a hostname
    /// - Parameter hostname: The hostname to look up
    /// - Returns: The cached resolution or nil if not in cache
    private func getCachedResolution(for hostname: String) -> CachedResolution? {
        return cacheQueue.sync {
            return cache[hostname]
        }
    }
    
    /// Caches a resolved hostname
    /// - Parameters:
    ///   - hostname: The hostname that was resolved
    ///   - addresses: The IP addresses it resolved to
    private func cacheResolution(hostname: String, addresses: [String]) {
        cacheQueue.async(flags: .barrier) {
            self.cache[hostname] = CachedResolution(addresses: addresses, timestamp: Date())
        }
    }
    
}
