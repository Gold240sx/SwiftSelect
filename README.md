# SwiftSelect

A powerful, customizable SwiftUI dropdown/multi-select component for iOS, macOS, tvOS, watchOS, and visionOS.

## Features

- ✅ **Multi-select support** - Select single or multiple options
- ✅ **Cross-platform** - Works on iOS, macOS, tvOS, watchOS, and visionOS
- ✅ **Customizable styling** - Flexible label and selector options
- ✅ **Search functionality** - Built-in search filtering
- ✅ **Async data loading** - Support for async data sources
- ✅ **Keyboard navigation** - Full keyboard support (arrow keys, enter, escape)
- ✅ **Haptic feedback** - Optional haptic and sound feedback
- ✅ **Multiple styles** - Connected or detached dropdown styles
- ✅ **Background options** - System, light, dark, or glass backgrounds
- ✅ **Absolute positioning** - Overlay positioning for complex layouts
- ✅ **Accessibility** - Full accessibility support

## Installation

### Swift Package Manager

Add SwiftSelect to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/Gold240sx/SwiftSelect.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File → Add Package Dependencies
2. Enter the URL: `https://github.com/Gold240sx/SwiftSelect.git`
3. Select version `1.0.0` or later

## Requirements

- iOS 13.0+
- macOS 14.0+
- tvOS 13.0+
- watchOS 6.0+
- visionOS 2.0+
- Swift 5.9+

## Usage

### Basic Example

```swift
import SwiftUI
import SwiftSelect

struct ContentView: View {
    @State private var selectedValues: Set<String> = []
    
    let options: [SelectOption] = [
        .init("Option 1", value: "option1"),
        .init("Option 2", value: "option2"),
        .init("Option 3", value: "option3")
    ]
    
    var body: some View {
        SwiftSelect(
            options: options,
            selectorOptions: .init(
                placeholder: "Select an option",
                isMultiSelect: true
            ),
            labelOptions: .init(
                label: "Choose Options",
                isRequired: true
            ),
            stateName: $selectedValues
        )
        .dropdownOverlay()
    }
}
```

### Advanced Example with Search

```swift
SwiftSelect(
    options: options,
    selectorOptions: .init(
        placeholder: "Search and select...",
        enableSearch: true,
        enableHaptics: true,
        isMultiSelect: true
    ),
    labelOptions: .init(
        label: "Select Items",
        sublabel: "Choose one or more items",
        showsInfoIcon: true,
        tooltipDescription: "Use search to filter options"
    ),
    stateName: $selectedValues
)
```

### Async Data Loading

```swift
SwiftSelect(
    optionsLoader: {
        // Load options asynchronously
        return await fetchOptionsFromAPI()
    },
    selectorOptions: .init(placeholder: "Loading..."),
    stateName: $selectedValues
)
```

## Icon Types

SwiftSelect supports multiple icon types for options. Use the following table to choose the right initializer:

| Icon Type | Initializer | Example |
|-----------|-------------|---------|
| **Emoji** | `emoji:` parameter | `.init("Apple", value: "apple", emoji: "🍎")` |
| **SF Symbol** | `icon:` parameter with `Image(systemName:)` | `.init("Settings", value: "settings", icon: Image(systemName: "gearshape.fill"))` |
| **Web Image** | `iconURL:` parameter | `.init("Logo", value: "logo", iconURL: "https://example.com/logo.png")` |
| **SVG from Web** | `iconURL:` parameter (SVG URL) | `.init("Icon", value: "icon", iconURL: "https://example.com/icon.svg")` |
| **Description** | `description:` parameter (works with any icon type) | `.init("Premium Plan", value: "premium", emoji: "⭐", description: "Get access to all features")` |

### Icon Examples

```swift
let options: [SelectOption] = [
    // Emoji icon
    .init("Apple", value: "apple", emoji: "🍎"),
    .init("Banana", value: "banana", emoji: "🍌"),
    
    // SF Symbol icon
    .init("Settings", value: "settings", icon: Image(systemName: "gearshape.fill")),
    .init("User", value: "user", icon: Image(systemName: "person.circle.fill")),
    
    // Web image (PNG, JPG, etc.)
    .init("Company Logo", value: "logo", iconURL: "https://example.com/logo.png"),
    
    // SVG from web (automatically handled via SDWebImageSVGCoder)
    .init("Brand Icon", value: "brand", iconURL: "https://example.com/brand-icon.svg"),
    
    // Options with description (works with any icon type)
    .init("Premium Plan", value: "premium", emoji: "⭐", description: "Get access to all features"),
    .init("Basic Plan", value: "basic", icon: Image(systemName: "star.fill"), description: "Essential features only"),
    .init("Enterprise", value: "enterprise", iconURL: "https://example.com/enterprise.svg", description: "Custom solutions for large teams"),
]
```

## Integration with ValidationKit

SwiftSelect works seamlessly with [ValidationKit](https://github.com/vapor/validation) or similar validation libraries. Here's a complete signup form example:

```swift
import SwiftUI
import SwiftSelect
import VaporValidation  // or your preferred validation library

struct SignupFormView: View {
    @State private var selectedInterests: Set<String> = []
    @State private var selectedCountry: Set<String> = []
    @State private var validationErrors: [String: String] = [:]
    
    let interestOptions: [SelectOption] = [
        .init("Technology", value: "tech", emoji: "💻"),
        .init("Design", value: "design", icon: Image(systemName: "paintbrush.fill")),
        .init("Business", value: "business", iconURL: "https://example.com/business-icon.svg"),
        .init("Science", value: "science", emoji: "🔬"),
    ]
    
    let countryOptions: [SelectOption] = [
        .init("United States", value: "us", emoji: "🇺🇸"),
        .init("Canada", value: "ca", emoji: "🇨🇦"),
        .init("United Kingdom", value: "uk", emoji: "🇬🇧"),
        .init("Australia", value: "au", emoji: "🇦🇺"),
    ]
    
    private var hasValidationErrors: Bool {
        !validationErrors.isEmpty
    }
    
    var body: some View {
        Form {
            Section {
                // Interests selector with validation
                SwiftSelect(
                    options: interestOptions,
                    selectorOptions: .init(
                        placeholder: "Select your interests",
                        isMultiSelect: true,
                        enableSearch: true
                    ),
                    labelOptions: .init(
                        label: "Interests",
                        isRequired: true
                    ),
                    errorMessage: validationErrors["interests"],
                    stateName: $selectedInterests
                )
                .onChange(of: selectedInterests) { _, _ in
                    validateInterests()
                }
                
                // Country selector with validation
                SwiftSelect(
                    options: countryOptions,
                    selectorOptions: .init(
                        placeholder: "Select your country",
                        isMultiSelect: false
                    ),
                    labelOptions: .init(
                        label: "Country",
                        isRequired: true
                    ),
                    errorMessage: validationErrors["country"],
                    stateName: $selectedCountry
                )
                .onChange(of: selectedCountry) { _, _ in
                    validateCountry()
                }
            }
            
            Section {
                Button("Submit") {
                    if validateForm() {
                        submitForm()
                    }
                }
                .disabled(hasValidationErrors)
            }
        }
        .dropdownOverlay()
    }
    
    private func validateInterests() {
        if selectedInterests.isEmpty {
            validationErrors["interests"] = "Please select at least one interest"
        } else if selectedInterests.count > 5 {
            validationErrors["interests"] = "Please select no more than 5 interests"
        } else {
            validationErrors.removeValue(forKey: "interests")
        }
    }
    
    private func validateCountry() {
        if selectedCountry.isEmpty {
            validationErrors["country"] = "Please select your country"
        } else {
            validationErrors.removeValue(forKey: "country")
        }
    }
    
    private func validateForm() -> Bool {
        validateInterests()
        validateCountry()
        return validationErrors.isEmpty
    }
    
    private func submitForm() {
        print("Interests: \(selectedInterests)")
        print("Country: \(selectedCountry)")
        // Submit to your backend
    }
}
```

### With ValidationKit Validators

If you're using ValidationKit's validator system:

```swift
import VaporValidation

struct SignupFormViewModel: ObservableObject {
    @Published var selectedInterests: Set<String> = []
    @Published var selectedCountry: Set<String> = []
    
    // Validation rules
    func validateInterests() throws {
        try Validator.validate(selectedInterests, at: "interests", is: .count(1...5))
    }
    
    func validateCountry() throws {
        try Validator.validate(selectedCountry, at: "country", is: .count(1...1))
    }
    
    func validate() throws {
        try validateInterests()
        try validateCountry()
    }
}

struct SignupFormView: View {
    @StateObject private var viewModel = SignupFormViewModel()
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            SwiftSelect(
                options: interestOptions,
                selectorOptions: .init(
                    placeholder: "Select interests",
                    isMultiSelect: true
                ),
                labelOptions: .init(label: "Interests", isRequired: true),
                errorMessage: errorMessage,
                stateName: $viewModel.selectedInterests
            )
            .onChange(of: viewModel.selectedInterests) { _, _ in
                do {
                    try viewModel.validateInterests()
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .dropdownOverlay()
    }
}
```

## Configuration

### SelectorOptions

- `placeholder: String` - Placeholder text when no selection
- `enableHaptics: Bool` - Enable haptic feedback (iOS)
- `enableSoundFeedback: Bool` - Enable sound feedback
- `enableSearch: Bool` - Enable search functionality
- `isAbsolute: Bool` - Use absolute positioning overlay
- `isMultiSelect: Bool` - Allow multiple selections
- `checkAll: Bool` - Show "Select All" option
- `checkAllTitleOverride: String?` - Custom "Select All" title

### LabelOptions

- `label: String?` - Main label text
- `sublabel: String?` - Subtitle text
- `isRequired: Bool` - Show required indicator
- `showsInfoIcon: Bool` - Show info icon
- `infoAction: (() -> Void)?` - Action for info icon
- `tooltipTitle: String?` - Tooltip title
- `tooltipDescription: String?` - Tooltip description
- `style: LabelStyleConfig` - Customize label styling

## Global Settings

You can configure global dropdown settings using the `dropdownSettings` environment:

```swift
ContentView()
    .environment(\.dropdownSettings, DropdownSettings(
        style: .connected,
        background: .glass,
        maxHeight: 300,
        isMultiSelect: true,
        enableSearch: true
    ))
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created by Michael Martell

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

# SwiftSelect
