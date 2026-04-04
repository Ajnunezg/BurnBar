# OpenBurnBarOperating

Live operating-layer code belongs here.

- `OpenBurnBarOperatingModels.swift`: operating-layer DTOs, enums, and view-facing models
- `OpenBurnBarOperatingComposer.swift`: snapshot composition and summary-building logic
- `OpenBurnBarOperatingLayer.swift`: observable shell and lifecycle wiring
- `OpenBurnBarOperatingLayer+ControllerActions.swift`: controller-runtime refresh and question/followup actions
- `OpenBurnBarOperatingLayer+MissionActions.swift`: mission approval and direction override actions
- `OpenBurnBarSetupGuideBuilder.swift`: setup-guide copy and state mapping

The old monolithic reference copy is archived under [`docs/archive/legacy-operating-layer/`](../../../docs/archive/legacy-operating-layer/).
