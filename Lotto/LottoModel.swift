import SwiftData
import Foundation

@Model
class LottoModel{
    var lottoNumber: [Int] = []
    
    init(lottoNumber: [Int]) {
        self.lottoNumber = lottoNumber
    }
    
}
