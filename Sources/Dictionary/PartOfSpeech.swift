//
//  PartOfSpeech.swift
//  
//
//  Created by Morten Bertz on 2021/06/22.
//

import Foundation

public enum PartOfSpeech:CustomStringConvertible{
    //["名詞", "助詞", "動詞", "助動詞", "副詞", "連体詞", "接頭詞", "感動詞", "接続詞", "形容詞"]
    
    case verb
    case particle
    case noun
    case adjective
    case adverb
    case attributive // 連体詞
    case prefix
    case interjection // 感動詞
    case conjunction // 接続詞
    case auxiliaryVerb // 助動詞
    case symbol
    case unknown

    
    public var description: String{
        switch self {
        case .verb:
            return "動詞"
        case .particle:
            return "助詞"
        case .noun:
            return "名詞"
        case .adjective:
            return "形容詞"
        case .adverb:
            return "副詞"
        case .attributive:
            return "連体詞"
        case .prefix:
            return "接頭詞"
        case .interjection:
            return "感動詞"
        case .conjunction:
            return "接続詞"
        case .auxiliaryVerb:
            return "助動詞"
        case .symbol:
            return "記号"
        case .unknown:
            return "未知"
        }
    }
}
