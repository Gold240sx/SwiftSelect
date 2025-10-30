import SwiftUI

@available(iOS 13.0, macOS 12.0, tvOS 13.0, watchOS 6.0, *)
struct SwiftSelectLabelHeader: View {
    let labelOptions: SwiftSelect.LabelOptions

    var body: some View {
        let hasLabel = (labelOptions.label ?? "").isEmpty == false
        let hasSublabel = (labelOptions.sublabel ?? "").isEmpty == false
        let shouldShowHeader = hasLabel || hasSublabel || labelOptions.isRequired || labelOptions.showsInfoIcon || labelOptions.infoOptions != nil

        Group {
            if shouldShowHeader {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if hasLabel, let text = labelOptions.label {
                            Text(text)
                                .font(labelOptions.style.font)
                                .fontWeight(labelOptions.style.fontWeight)
                                .foregroundColor(labelOptions.style.color)
                        }

                        if labelOptions.showsInfoIcon || labelOptions.infoOptions != nil {
                            InfoTooltipIcon(
                                title: labelOptions.tooltipTitle,
                                description: labelOptions.tooltipDescription ?? labelOptions.infoOptions?.text,
                                action: labelOptions.infoAction,
                                leadingIconName: labelOptions.infoOptions?.icon
                            )
                        }

                        Spacer(minLength: 4)

                        if labelOptions.isRequired {
                            Text("*")
                                .font(labelOptions.style.font)
                                .foregroundColor(labelOptions.style.asteriskColor)
                        }
                    }

                    if hasSublabel, let sub = labelOptions.sublabel {
                        Text(sub)
                            .font(labelOptions.style.sublabelFont)
                            .foregroundColor(labelOptions.style.sublabelColor)
                            .padding(2)
                    }
                }
            }
        }
    }
}
