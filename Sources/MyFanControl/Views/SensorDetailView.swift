import FanCore
import SwiftUI

struct SensorDetailView: View {
  var sensor: Sensor
  private var info: SensorInfo { SensorCatalog.lookup(sensor.id) }
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(info.name).font(.callout.weight(.semibold))
        Text(sensor.id).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        Spacer()
      }
      Text(info.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(
        horizontal: false, vertical: true)
      if info.known {
        HStack(spacing: 5) {
          Text(L10n.t("sensors.community")).font(.caption2).foregroundStyle(.secondary)
          Link(L10n.t("sensors.source"), destination: URL(string: info.sourceURL)!).font(.caption2)
        }
      } else {
        Text(L10n.t("sensors.unknownNote")).font(.caption2).foregroundStyle(.orange)
      }
    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
  }
}
