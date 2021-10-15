//
//  SourceEditorCommand.swift
//  
//
//  Created by 谢东华 on 2021/10/14.
//

import Foundation
import XcodeKit

class MappableCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        let lines: [String] = invocation.buffer.lines.compactMap { "\($0)" }
        
        // 如果没有引入头文件，则添加 import ObjectMapper
        var foundationIndex = 0
        var isNeedImportObjectMapper = true
        for (i, line) in lines.enumerated() {
            if line.contains("import Foundation") {
                foundationIndex = i
            }
            if line.contains("import ObjectMapper") {
                isNeedImportObjectMapper = false
            }
        }
        if isNeedImportObjectMapper {
            invocation.buffer.lines.insert("import ObjectMapper", at: foundationIndex+1)            
        }
        
        var classModelImpl: [(Int, String)] = []
        
        let metadatas = Parser().parse(buffer: lines)
        
        for case let Metadata.model(range, elements) in metadatas {
            
            let modelBuffer = Array(lines[range])
            let pattern = ".*(struct|class)\\s+(\\w+)([^{\\n]*)"
            if let regex = try? Regex(string: pattern), let matche = regex.match(modelBuffer[0]) {
                
                let isStruct = matche.captures[0] == "struct"
                let modelName = matche.captures[1]!
                
                if matche.captures[0] == "class" {
                    let protocolStr = matche.captures[2]!.contains(":") ? ", Mappable " : ": Mappable "
                    var str = modelBuffer[0]
                    str.replaceSubrange(matche.range, with: matche.matchedString + protocolStr)
                    invocation.buffer.lines[range.lowerBound] = str
                }
                
                let initial = String(format: "\n\n\t%@init?(map: Map) {\n\n\t}", isStruct ? "" : "required ")
                
                var mapping = String(format: "\n\n\t%@func mapping(map: Map) {", isStruct ? "mutating " : "")
                for case let Metadata.property(lineNumber) in elements {
                    if let regex = try? Regex(string: "(.*)(let|var)\\s+(\\w+)\\s*:"),
                        let matche = regex.match(modelBuffer[lineNumber+1]) {
                        if matche.captures[0]?.contains("static") == false && matche.captures[1] == "var" {
                            let value = matche.captures[2]!
                            mapping += String(format: "\n\t\t%-20s <- map[\"%@\"]", (value as NSString).utf8String!, value)
                        }
                    }
                }
                mapping += "\n\t}"
                
                if isStruct {
                    let protocolImpl = String(format: "\n\nextension %@: Mappable {%@%@\n}", modelName, initial, mapping)
                    invocation.buffer.lines.add(protocolImpl)
                } else {
                    let protocolImpl = String(format: "%@%@", initial, mapping)
                    classModelImpl.append((range.upperBound-1, protocolImpl))
                }
            }
        }
    
        classModelImpl.sort { (args1, args2) -> Bool in return args1.0 > args2.0 }
        for (index, impl) in classModelImpl {
            invocation.buffer.lines.insert(impl, at: index)
        }   
        completionHandler(nil)
    }
}
