import CoreGraphics
import NuriDomain

/// Fixed places on the world, from the approved board (196 pt reference globe).
public enum WorldLayout {
    static let reference: CGFloat = 196

    public static func slot(for group: FoodGroup) -> CGRect {
        let r: CGRect = switch group {
        case .vegetables: CGRect(x: 18, y: 44, width: 86, height: 64)
        case .grains: CGRect(x: 100, y: 24, width: 70, height: 52)
        case .protein: CGRect(x: 66, y: 112, width: 96, height: 58)
        case .fruit: CGRect(x: 146, y: 86, width: 40, height: 40)
        case .legumesAndNuts: CGRect(x: 26, y: 130, width: 34, height: 30)
        case .dairyAndAlternatives: CGRect(x: 40, y: 18, width: 40, height: 26)
        }
        return CGRect(x: r.minX / reference, y: r.minY / reference, width: r.width / reference, height: r.height / reference)
    }
}
