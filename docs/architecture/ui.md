# UI

SwiftUI screens. Holds no business logic — reads state from the Basket domain
and asks the Scanner for captures.

## Screens

### Home / Basket (root)
- Big **remaining** figure at the top (e.g. "£12.34 left") measured against the
  budget; turns red / shows "over by £x" when `isOverBudget`.
- Running **total** and the **budget** (tap budget to edit).
- Scrollable **basket list**: each row = name, unit price, quantity with **+/−**
  steppers, line total. Swipe or tap to **edit/delete**.
- Prominent **Scan next item** button (bottom, thumb-reachable).
- **New trip** action (clears basket, confirms first).
- Empty state prompts to set a budget and scan the first item.

### Scan (camera, modal)
- Opens on **Scan next item**. Live camera with a target frame.
- On **confident capture**: beep/haptic, auto-dismiss, item appears in basket.
- On **low-confidence capture** or **failure**: dismiss to / overlay the
  **Confirm card**.

### Confirm card
- Pre-filled editable **name** and **price** from the low-confidence capture.
- **Add** commits it; **Cancel** discards. Only appears when the app is unsure.

### Row editor
- Edit **name**, **price**, **quantity**; **delete**. Reachable from any row.

## Rules

- The UI never constructs money math itself — it renders `Trip` values and calls
  domain operations.
- The UI never touches Vision/camera types — only `Scanner.scanNextItem()` and
  its `ScanResult`.
- All money is entered/edited in pounds-and-pence UI but stored as integer pence.
