import Foundation

public struct AppVersion: Comparable, Sendable {
  private let core: [Int]
  private let prerelease: [String]
  public init(_ tag: String) throws {
    let raw = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    let metadata = raw.split(separator: "+", omittingEmptySubsequences: false)
    let pieces = metadata[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
    func valid(_ value: Substring) -> Bool {
      !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }
    }
    let numbers = pieces[0].split(separator: ".", omittingEmptySubsequences: false)
    let pre = pieces.count == 2 ? pieces[1].split(separator: ".", omittingEmptySubsequences: false) : []
    guard metadata.count <= 2, numbers.count == 3,
      numbers.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } && ($0.count == 1 || $0.first != "0") && Int($0) != nil }),
      pre.allSatisfy(valid),
      pre.allSatisfy({ value in
        !value.utf8.allSatisfy { (48...57).contains($0) } || value.count == 1 || value.first != "0"
      }),
      metadata.count == 1 || metadata[1].split(separator: ".", omittingEmptySubsequences: false).allSatisfy(valid)
    else { throw FanError.invalid(L10n.t("update.invalidVersion")) }
    core = numbers.compactMap { Int($0) }
    prerelease = pre.map(String.init)
  }
  public static func == (a: Self, b: Self) -> Bool { a.core == b.core && a.prerelease == b.prerelease }
  public static func < (a: Self, b: Self) -> Bool {
    if a.core != b.core { return a.core.lexicographicallyPrecedes(b.core) }
    if a.prerelease.isEmpty { return false }
    if b.prerelease.isEmpty { return true }
    for (left, right) in zip(a.prerelease, b.prerelease) where left != right {
      let ln = left.utf8.allSatisfy { (48...57).contains($0) }
      let rn = right.utf8.allSatisfy { (48...57).contains($0) }
      if ln != rn { return ln }
      if ln, left.count != right.count { return left.count < right.count }
      return left < right
    }
    return a.prerelease.count < b.prerelease.count
  }
}
