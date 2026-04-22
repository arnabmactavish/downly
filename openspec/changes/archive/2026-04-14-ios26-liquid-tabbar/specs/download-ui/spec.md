## MODIFIED Requirements

### Requirement: FloatingBottomNavBar deprecated
The `<HStack>` overlay implementation representing `FloatingBottomNavBar` SHALL be removed. Instead, the application SHALL adopt a native structural paradigm containing the same navigation elements mapped against a real native container capable of manifesting genuine iOS 26 Material properties.

#### Scenario: Native Layout Execution
- **WHEN** the structural layout container for the download context initializes
- **THEN** it SHALL NOT define a hardcoded `HStack` inside `.safeAreaInset(edge: .bottom)` to act as a false tab-bar placeholder
- **AND** it SHALL leverage native navigation structures configured cleanly with proper `.contentMargins` designed to support true material bleed-through properties underneath
