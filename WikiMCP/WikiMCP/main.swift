//
//  main.swift
//  WikiMCP
//
//  Created by phoenix on 2025/12/15.
//

import Foundation
import ArgumentParser
import AppKit

struct WikiParser: ParsableCommand {
    func run() throws {
        
        Task {
            let ss = try await WikiAPIClient.shared.viewPage(url: "https://wiki.p1.cn/pages/viewpage.action?pageId=78389152")
            print(ss)
            
            let ret = try await WikiAPIClient.shared.search(query: "cocoapods")
            print(ret)
            
            let data = try await WikiAPIClient.shared.downloadImage(from: "https://wiki.p1.cn/download/attachments/78389152/CleanShot%202025-03-03%20at%2018.01.16@2x.jpg?version=1&modificationDate=1740996082665&api=v2")
            let image = NSImage(data: data)
            print(image)
        }
    }
}

//WikiParser.exit()
WikiParser.main()
RunLoop.main.run()
