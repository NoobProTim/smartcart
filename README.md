# 🛒 SmartCart

> Grocery price intelligence that learns what you buy.

SmartCart is an iOS app that scans your grocery receipts, tracks real price history per item per store, and alerts you when your personally-purchased items hit a genuine historical low — timed to when you actually need to restock.

---

## 🎯 The Problem

People don't know when their regularly-purchased grocery items are on sale. Existing apps require manual setup and don't learn personal purchase patterns.

**Core insight:** CamelCamelCamel for groceries — but personalised. The app learns what *you* buy, tracks real price history, and proactively alerts you when *your* items hit a genuine low at stores you actually shop at.

---

## 📱 Wireframes

All wireframes are self-contained clickable HTML files. Open in any browser — no build step required.

| Batch | Screens | File |
|---|---|---|
| **Batch 1** | Splash · Onboarding · Store Picker · Permissions | [`wireframes/batch1-onboarding.html`](wireframes/batch1-onboarding.html) |
| **Batch 2** | Home / Smart List · Receipt Scanner · Receipt Review · Confirm Sheet | [`wireframes/batch2-core-loop.html`](wireframes/batch2-core-loop.html) |
| **Batch 3** | Item Detail · Alert Sheet · Alerts / Deal Sheet | [`wireframes/batch3-item-detail-alerts.html`](wireframes/batch3-item-detail-alerts.html) |
| **Batch 4** | Settings · Empty Home · Empty Alerts | [`wireframes/batch4-settings-empty-states.html`](wireframes/batch4-settings-empty-states.html) |

> **Tip:** Use [GitHub Pages](https://pages.github.com/) or paste raw file URLs into [htmlpreview.github.io](https://htmlpreview.github.io/) to view them live in the browser.

---

## 🏗️ Tech Stack (planned)

| Layer | Choice |
|---|---|
| Platform | iOS-first (Native Swift) |
| UI | SwiftUI |
| Build tool | Claude Code + Xcode |
| Database | SQLite (on-device, SQLite.swift) |
| OCR | Apple Vision (on-device, free) |
| Price data | Flipp web endpoints + store flyer scraping |
| Charts | Swift Charts |
| Notifications | UserNotifications + BGAppRefreshTask |
| Infrastructure cost | $0/month |

---

## 🗄️ Data Model (9 tables)

`stores` · `items` · `user_items` · `purchase_history` · `price_history` · `flyer_sales` · `alert_log` · `user_stores` · `user_settings`

---

## 🔔 Alert Types

- **Type A — Historical Low:** Current price ≤ personal purchase history low
- **Type B — Sale Alert:** Item is on flyer sale at a tracked store
- **Type A+B — Combined:** Both conditions true simultaneously (highest priority)
- **Type C — Expiry Reminder:** Tracked sale ends within 48 hours, replenishment is due

---

## 🌍 Markets

- **Primary:** Canada (Flipp API coverage)
- **Secondary:** India (future)

---

## 👥 Build System

This project is built using a multi-agent AI system coordinated by an Orchestrator (Perplexity).

| Agent | Role |
|---|---|
| 📋 NOVA | Product & Requirements (PRD v1.2) |
| 🏗️ ATLAS | System Architecture & Tech Stack |
| ⚒️ FORGE | Code Scaffold & UI Screens |
| 🔍 PRISM | QA, UX & Edge Case Review |

---

*Built by Timothy · Kingston, Ontario, Canada*
