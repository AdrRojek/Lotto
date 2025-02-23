import SwiftData
import Foundation

@Model
class LottoModel{
    var lottoNumber: [Int]
    var checked: Bool
    
    init(lottoNumber: [Int]) {
        self.lottoNumber = lottoNumber
        self.checked = false
    }
    
}
