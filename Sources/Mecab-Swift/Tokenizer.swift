import mecab
import Foundation
import StringTools
import Dictionary

/**
A tokenizer /  morphological analyzer for Japanese
*/
public class Tokenizer{
    
    /**
    How to display found tokens in Japanese text
    */
   public enum Transliteration{
        case hiragana
        case katakana
        case romaji
    }

    public enum TokenizerError:Error{
        case initializationFailure(String)
        
        public var localizedDescription: String{
            switch self {
            case .initializationFailure(let error):
                return error
            }
        }
    }
    
    
    private let dictionary:DictionaryProviding
    
    fileprivate let _mecab:OpaquePointer!
    
    // 缓存结构，使用元组（text, transliteration）作为键，存储分词结果
    private var tokenCache: [String: [Annotation]] = [:]
    
    // 最大缓存大小
    private var maxCacheSize: Int = 1000
    
    /**
     The version of the underlying mecab engine.
     */
    public class var version:String{
        return String(cString: mecab_version(), encoding: .utf8) ?? ""
    }
    
    
    
    fileprivate let isSystemTokenizer:Bool
    fileprivate let isUnidicTokenizer:Bool

    #if canImport(CoreFoundation)
    fileprivate init(){
        self.isSystemTokenizer=true
        self.isUnidicTokenizer=true
        self.dictionary=SystemDictionary()
        _mecab=nil
    }
    
    
     /*
     The CoreFoundation CFStringTokenizer
     **/
    public static let systemTokenizer:Tokenizer = {
        return Tokenizer()
    }()
    #endif
    
    /**
     Initializes the Tokenizer.
     - parameters:
        - dictionary:  A Dictionary struct that encapsulates the dictionary and its positional information.
     - throws:
        * `TokenizerError`: Typically an error that indicates that the dictionary didn't exist or couldn't be opened.
     */
    public init(dictionary:DictionaryProviding, isUnidic:Bool=false, maxCacheSize: Int = 1000) throws{
        self.dictionary=dictionary
        self.isSystemTokenizer=false
        self.isUnidicTokenizer=isUnidic
        self.maxCacheSize = maxCacheSize

        let tokenizer=try dictionary.url.withUnsafeFileSystemRepresentation({path->OpaquePointer in
            guard let path=path,
                let dictPath=String(cString: path).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                //MeCab splits the commands by spaces, so we need to escape the path passed inti the function.
                //We replace the percent encoded space when opening the dictionary. This is mostly relevant when the dictionary os located inside a folder of which we cannot control the name, i.e. Application Support
                else{ throw TokenizerError.initializationFailure("URL Conversion Failed \(dictionary)")}
            
            guard let tokenizer=mecab_new2("-d \(dictPath)") else {
                let error=String(cString: mecab_strerror(nil), encoding: .utf8) ?? ""
                throw TokenizerError.initializationFailure("Opening Dictionary Failed \(dictionary) \(error)")
            }
            return tokenizer
        })
        
        _mecab=tokenizer
       
    }
    
    /**
     The fundamental function to tokenize Japanese text with an initialized `Tokenizer`
     - parameters:
        - text: A `string` that contains the text to tokenize.
        - transliteration : A `Transliteration` method. The text content of found tokens will be displayed using this.
     - returns: An array of `Annotation`, a struct that contains the found tokens (the token value, the reading, POS, etc.).
     */
    public func tokenize(text:String, transliteration:Transliteration = .hiragana)->[Annotation]{
        // 创建缓存键
        let cacheKey = text + String(transliteration.hashValue)
        
        // 检查缓存是否存在结果
        if let cachedResult = tokenCache[cacheKey] {
            return cachedResult
        }
        
        let result: [Annotation]
        if self.isSystemTokenizer{
            result = self.systemTokenizerTokenize(text: text, transliteration: transliteration)
        }
        else{
            result = mecabTokenize(text: text, transliteration: transliteration)
        }
        
        // 添加结果到缓存
        if result.count > 0 {
            // 如果缓存即将超过最大大小，移除最旧的条目
            if tokenCache.count >= maxCacheSize {
                if let firstKey = tokenCache.keys.first {
                    tokenCache.removeValue(forKey: firstKey)
                }
            }
            tokenCache[cacheKey] = result
        }
        
        return result
    }
    
    /**
     清除分词缓存
     */
    public func clearCache() {
        tokenCache.removeAll()
    }
    
    /**
     设置最大缓存大小
     - parameter size: 新的最大缓存大小
     */
    public func setMaxCacheSize(size: Int) {
        maxCacheSize = size
        // 如果当前缓存大小超过新的最大大小，移除最旧的条目
        while tokenCache.count > maxCacheSize {
            if let firstKey = tokenCache.keys.first {
                tokenCache.removeValue(forKey: firstKey)
            } else {
                break
            }
        }
    }
    
    fileprivate func mecabTokenize(text:String, transliteration:Transliteration = .hiragana)->[Annotation]{
        let tokens=text.precomposedStringWithCanonicalMapping.withCString({s->[Token] in
           var tokens=[Token]()
           var node=mecab_sparse_tonode(self._mecab, s)
           while true{
               guard let n = node else {break}
           
                   if let token=Token(node: n.pointee, tokenDescription: self.dictionary){
                       tokens.append(token)
                   }
               
                   node = UnsafePointer(n.pointee.next)
           }
           return tokens
       })
       
      
       var annotations=[Annotation]()
       var searchRange=text.startIndex..<text.endIndex
       for token in tokens{
           let searchString=token.original
           if searchString.isEmpty{
               continue
           }
           if let foundRange=text.range(of: searchString, options: [], range: searchRange, locale: nil){
               var annotation=Annotation(token: token, range: foundRange, transliteration: transliteration)
               annotation.isUniType = self.isUnidicTokenizer
               annotations.append(annotation)
               
               if foundRange.upperBound < text.endIndex{
                   searchRange=foundRange.upperBound..<text.endIndex
               }
           }
       }
   
       return annotations
    }
    
    
    /**
    A convenience function to tokenize text into `FuriganaAnnotations`.
     
     `FuriganaAnnotations` are meant for displaying furigana reading aids for Japanese Kanji characters, and consequently tokens that don't contain Kanji are skipped.
    - parameters:
       - text: A `string` that contains the text to tokenize.
       - transliteration : A `Transliteration` method. The text content of found tokens will be displayed using this.
       - options : Options to pass to the tokenizer
    - returns: An array of `FuriganaAnnotations`, which contain the reading o fthe token and the range of the token in the original text.
    */
    public func furiganaAnnotations(for text:String, transliteration:Transliteration = .hiragana, options:[Annotation.AnnotationOption] = [.kanjiOnly])->[FuriganaAnnotation]{
        
        return self.tokenize(text: text, transliteration: transliteration)
            .filter({$0.base.isEmpty == false})
            .compactMap({$0.furiganaAnnotation(options: options, for: text)})
    }
    
    /**
       A convenience function to add `<ruby>` tags to  text.
        
        `<ruby>` tags are added to all tokens that contain Kanji characters, regardless of whether they are on specific parts of an HTML document or not. This can potentially disrupt scripts or navigation.
       - parameters:
          - htmlText: A `string` that contains the text to tokenize.
          - transliteration: A `Transliteration` method. The text content of found tokens will be displayed using this.
          - options: Options to pass to the tokenizer
       - returns: A text with `<ruby>` annotations.
       */
    public func addRubyTags(to htmlText:String, transliteration:Transliteration = .hiragana, options:[Annotation.AnnotationOption] = [.kanjiOnly])->String{
        let furigana=self.furiganaAnnotations(for: htmlText, transliteration: transliteration, options: options)
        var outString=""
        var endIDX = htmlText.startIndex
        
        for annotation in furigana{
            outString += htmlText[endIDX..<annotation.range.lowerBound]
            
            let original = htmlText[annotation.range]
            let htmlRuby="<ruby>\(original)<rt>\(annotation.reading)</rt></ruby>"
            outString += htmlRuby
            endIDX = annotation.range.upperBound
        }
        
        outString += htmlText[endIDX..<htmlText.endIndex]
        
        return outString
    
    }
    
    deinit {
        mecab_destroy(_mecab)
    }
    
}


//if let lowerBound = outString.index(tokenRange.lowerBound, offsetBy: htmlRuby.count, limitedBy: outString.endIndex){
//    searchRange = lowerBound ..< outString.endIndex
//}
//else{
//    continue
//}






