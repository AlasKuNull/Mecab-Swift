//
//  File.swift
//  
//
//  Created by Morten Bertz on 2019/10/02.
//

import Foundation
import StringTools
import Dictionary

/**
 `Annotation`s encapsulate the information of the `Tokenizer`.
 - base: represents the string value of the token in the original text
 - reading: in case `base` contains Kanji characters, the reading if the characters. The reading is formatted according to `Transliteration`
 - partOfSpeech: A member of the `PartOfSpeech` enum.
 - dictionaryForm: in case of verbs or adjectives, the dictionary form of the token.
 */

public struct Annotation:Equatable, FuriganaAnnotating{
    
    public var isUniType:Bool=false
    public let base:String
    public let reading:String
    public let features:[String]
    public let partOfSpeech:PartOfSpeech
    public let range:Range<String.Index>
    public let dictionaryForm:String
    let transliteration:Tokenizer.Transliteration
    
    init(token:Token, range:Range<String.Index>, transliteration:Tokenizer.Transliteration) {
        self.init(base: token.original, reading: token.reading, features:token.features, range: range, dictionaryForm: token.dictionaryForm, transliteration: transliteration, POS: token.partOfSpeech)
    }
    
    init(base:String, reading:String, features: [String], range:Range<String.Index>, dictionaryForm:String, transliteration:Tokenizer.Transliteration, POS:PartOfSpeech = .unknown){
        self.base=base
        self.range=range
        self.partOfSpeech = POS
        self.transliteration = transliteration
        self.features = features
        switch transliteration {
        case .katakana:
            self.reading=reading
            self.dictionaryForm=dictionaryForm
        case .hiragana:
            self.reading=reading.hiraganaString
            self.dictionaryForm=dictionaryForm.hiraganaString
        case .romaji:
            self.reading=reading.romanizedString(method: .hepburn)
            self.dictionaryForm=dictionaryForm.romanizedString(method: .hepburn)
        }
        
    }
    
    /**
     Checks whether the `base` of the `Annotation` contains Kanji characters.
     */
    @inlinable public var containsKanji:Bool{
        return self.base.containsKanjiCharacters
    }
    
    /**
       A convenience function to create properly formatted `FuriganaAnnotations` from an `Annotation`
    - parameters:
           - string: the underlying text for which the `FuriganaAnnotation` should be generated. This parameter is required because some options can change the range of the token in the base text.
    - returns: A  `FuriganaAnnotation`.
    */
    public func furiganaAnnotation(for string:String)->FuriganaAnnotation{
         return FuriganaAnnotation(reading: self.reading , range: self.range)
    }
    
    
    
    public var pos: String {
        if isUniType {
            return features.first ?? ""
        }else{
            return partOfSpeech.description

        }
    }
    
    public var originalForm: String {
                
        if isUniType {
            if features.count >= 8 {
                return features[7]
            }
            return ""
        }else{
            return dictionaryForm

        }
    }
    
    public var pron: String {
        
        switch transliteration {
        case .katakana:
            if isUniType {
                if features.count >= 10 {
                    return features[9]
                }
                return ""
            }else{
                return reading

            }
        case .hiragana:
            if isUniType {
                if features.count >= 10 {
                    return features[9].hiraganaString
                }
                return ""
            }else{
                return reading.hiraganaString

            }

        case .romaji:
            if isUniType {
                if features.count >= 10 {
                    return features[9].romanizedString(method: .hepburn)
                }
                return ""
            }else{
                return reading.romanizedString(method: .hepburn)

            }
        }
    }


    
    /*
     let pos1 = fields[0]
     let pos2 = fields[1]
     let pos3 = fields[2]
     let pos4 = fields[3]
     let lemma = fields[7]
     let orth = fields[8]
     let pron = fields[9]
     
     let partOfSpeech = [pos1, pos2, pos3, pos4].filter { $0 != "*" }.joined(separator: "-").nilIfEmpty()
     let reading = pron != "*" ? pron.toHiragana() : nil
     let pronunciation = reading != nil ? reading!.toRomaji() : nil
     
     return TokenFeatures(
         surface: orth != "*" ? orth : "",
         partOfSpeech: partOfSpeech,
         originalForm: lemma != "*" ? lemma : nil,
         reading: reading,
         pronunciation: pronunciation
     )
     */

    
    /**
        A convenience function to create properly formatted `FuriganaAnnotations` from an `Annotation`
     - parameters:
            - options: `AnnotationOptions` how to format the `FuriganaAnnotations`
            - string: the underlying text for which the `FuriganaAnnotation` should be generated. This parameter is required because some options can change the range of the token in the base text.
     - returns: A  `FuriganaAnnotation`.
     */
    public func furiganaAnnotation(options:[AnnotationOption] = [.kanjiOnly], for string:String)->FuriganaAnnotation?{
        
         for case let AnnotationOption.filter(disallowed, strict) in options{
            let kanji=Set(self.base.kanjiCharacters)
            if strict == true, disallowed.isDisjoint(with: kanji) == false{
                return nil
            }
            else if strict == false, disallowed.isSuperset(of: kanji){
                return nil
            }
        }
        
        if options.contains(.kanjiOnly){
            guard self.containsKanji else{
                return nil
            }
            return self.furiganaAnnotation(for: string, kanjiOnly: true)
        }
        else{
            return FuriganaAnnotation(reading: self.reading , range: self.range)
        }
    }
}


extension Annotation:CustomStringConvertible{
    public var description: String{
        return "Base: \(base), reading: \(reading), POS: \(partOfSpeech)"
    }
}
