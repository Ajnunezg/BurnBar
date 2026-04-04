// MARK: - MissionControl Module Refactoring
//
// The types originally defined in this file have been moved to the MissionControl/ subdirectory:
//
//   - BurnBarMissionControlError          -> MissionControl/MissionControlError.swift
//   - BurnBarMissionControlProjectionFile -> MissionControl/MissionControlProjectionFile.swift
//   - BurnBarMissionControlStore         -> MissionControl/MissionControlStore.swift
//   - BurnBarMissionControlTransport     -> MissionControl/MissionControlTransport.swift
//   - BurnBarLocalNotificationBridge     -> MissionControl/Bridges/LocalNotificationBridge.swift
//   - BurnBarTelegramBotBridge           -> MissionControl/Bridges/TelegramBotBridge.swift
//   - BurnBarEventKitBridge              -> MissionControl/Bridges/EventKitBridge.swift
//   - BurnBarMissionControlService       -> MissionControl/MissionControlService.swift
//
// All public types remain accessible under their original names within the OpenBurnBarDaemon module.
// This file is kept as a placeholder to preserve source compatibility.
