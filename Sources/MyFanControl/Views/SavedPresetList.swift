import FanCore
import SwiftUI

struct SavedPresetList: View {
  var store: FanStore
  var selectedID: UUID?
  var fanIDs: [Int]
  var select: (FanPreset) -> Void
  var newPreset: () -> Void
  @State private var pendingDelete: FanPreset?
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(L10n.t("preset.library")).font(.headline)
        Spacer()
        Button(action: newPreset) { Label(L10n.t("preset.new"), systemImage: "plus") }.disabled(
          store.busy)
      }
      if store.presets.isEmpty {
        Text(L10n.t("preset.emptyHint")).font(.callout).foregroundStyle(.secondary).padding(
          .vertical, 8)
      } else {
        ScrollView {
          LazyVStack(spacing: 6) {
            ForEach(store.presets) { preset in
              HStack(spacing: 8) {
                Button {
                  select(preset)
                } label: {
                  HStack {
                    Image(systemName: selectedID == preset.id ? "checkmark.circle.fill" : "circle")
                      .foregroundStyle(selectedID == preset.id ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                      Text(preset.name).fontWeight(.medium).lineLimit(1)
                      Text(preset.summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if fanIDs.allSatisfy({ store.active[$0] == preset }) {
                      Text(L10n.t("preset.inUse")).font(.caption).foregroundStyle(.green)
                    }
                  }.padding(9).contentShape(Rectangle())
                }.buttonStyle(.plain).background(
                  selectedID == preset.id
                    ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.04),
                  in: RoundedRectangle(cornerRadius: 7))
                Button(role: .destructive) {
                  pendingDelete = preset
                } label: {
                  Image(systemName: "trash").frame(width: 26, height: 30)
                }
                .buttonStyle(.borderless).help(L10n.t("Xóa preset")).accessibilityLabel(
                  L10n.f("preset.deleteNamed", preset.name))
              }
            }
          }
        }.frame(height: min(100, CGFloat(store.presets.count) * 58))
      }
    }
    .confirmationDialog(
      L10n.f("preset.confirmDelete", pendingDelete?.name ?? ""),
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible
    ) {
      Button(L10n.t("Xóa preset"), role: .destructive) {
        if let preset = pendingDelete { store.deletePreset(preset.id) }
        pendingDelete = nil
      }
      Button(L10n.t("schedule.close"), role: .cancel) { pendingDelete = nil }
    }
  }
}

extension FanPreset {
  var summary: String {
    switch mode {
    case .automatic: return L10n.t("Tự động hệ thống")
    case .fixed: return String(format: "%.0f RPM", rpm)
    case .sensor: return "\(sensor) · \(Int(start))–\(Int(full))°C"
    }
  }
}
